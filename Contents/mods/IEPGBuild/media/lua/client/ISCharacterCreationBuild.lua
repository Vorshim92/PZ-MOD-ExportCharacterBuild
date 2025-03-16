require "OptionScreens/CharacterCreationMain"

-- Store the original create function
local originalCreate = CharacterCreationMain.create

-- Override the create function to add our buttons
function CharacterCreationMain:create()
    -- Call the original create function
    originalCreate(self)
    
    -- Get the button height from existing buttons
    local buttonHgt = self.saveBuildButton:getHeight()
    
    -- First, remove the delete button from the panel
    self.presetPanel:removeChild(self.deleteBuildButton)
    
    -- Create IMPORT button
    self.importBuildButton = ISButton:new(self.saveBuildButton:getRight() + 10, self.saveBuildButton:getY(), 50, buttonHgt, getText("UI_characreation_BuildImport"), self, CharacterCreationMain.importBuild)
    self.importBuildButton:initialise()
    self.importBuildButton:instantiate()
    self.importBuildButton:setAnchorLeft(true)
    self.importBuildButton:setAnchorRight(false)
    self.importBuildButton:setAnchorTop(false)
    self.importBuildButton:setAnchorBottom(true)
    self.importBuildButton.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self.presetPanel:addChild(self.importBuildButton)
    
    -- Create EXPORT button
    self.exportBuildButton = ISButton:new(self.importBuildButton:getRight() + 10, self.importBuildButton:getY(), 50, buttonHgt, getText("UI_characreation_BuildExport"), self, CharacterCreationMain.exportBuild)
    self.exportBuildButton:initialise()
    self.exportBuildButton:instantiate()
    self.exportBuildButton:setAnchorLeft(true)
    self.exportBuildButton:setAnchorRight(false)
    self.exportBuildButton:setAnchorTop(false)
    self.exportBuildButton:setAnchorBottom(true)
    self.exportBuildButton.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self.presetPanel:addChild(self.exportBuildButton)
    
    -- Reposition DELETE button
    self.deleteBuildButton:setX(self.exportBuildButton:getRight() + 10)
    self.presetPanel:addChild(self.deleteBuildButton)
    
    -- Update panel width
    self.presetPanel:setWidth(self.deleteBuildButton:getRight())
    
    -- Clear previous button configuration
    self.presetPanel.joypadButtonsY = {}
    
    -- Re-insert all buttons in the correct order for joypad navigation
    self.presetPanel:insertNewLineOfButtons(self.savedBuilds, self.saveBuildButton, self.importBuildButton, self.exportBuildButton, self.deleteBuildButton)
    self.presetPanel.joypadIndex = 1
    self.presetPanel.joypadIndexY = 1
end

-- Add update function to handle button states
local originalPrerender = CharacterCreationMain.prerender
function CharacterCreationMain:prerender()
    originalPrerender(self)
    self.exportBuildButton:setEnable(self.savedBuilds.selected ~= 0)
    if self.exportBuildButton:isEnabled() then
        self.exportBuildButton.borderColor.a = 0.1
    end
end

-- Add the import function
function CharacterCreationMain:importBuild()
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    
    -- Create a custom panel for import instead of ISTextBox
    local panel = ISPanel:new(screenW / 2 - 225, screenH / 2 - 125, 450, 250)
    panel:initialise()
    panel:addToUIManager()
    panel:setAlwaysOnTop(true)
    panel.backgroundColor = {r=0, g=0, b=0, a=0.9}
    panel.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    
    -- Add title
    local titleLabel = ISLabel:new(0, 10, 30, getText("UI_characreation_BuildImportPrompt"), 1, 1, 1, 1, UIFont.Medium, true)
    titleLabel:setX((panel.width - titleLabel.width) / 2)
    panel:addChild(titleLabel)
    
    -- Add text area for paste
    local textArea = ISTextEntryBox:new("", 20, 40, panel.width - 40, 150)
    textArea:initialise()
    textArea:instantiate()
    textArea:setMultipleLine(true)
    panel:addChild(textArea)
    
    -- Definizione dimensioni pulsanti
    local buttonWidth = 100
    local buttonHeight = 25
    local buttonY = panel.height - 40
    local spacing = 10
    
    -- Calcolo posizione per tre pulsanti equidistanti
    local totalButtonsWidth = buttonWidth * 3 + spacing * 2
    local startX = (panel.width - totalButtonsWidth) / 2
    
    -- Aggiunta del pulsante PASTE
    local pasteButton = ISButton:new(startX, buttonY, buttonWidth, buttonHeight, getText("UI_characreation_Paste"), panel, function()
        local clipboardText = Clipboard.getClipboard()
        if clipboardText and clipboardText ~= "" then
            textArea:setText(clipboardText)
        end
    end)
    pasteButton:initialise()
    pasteButton:instantiate()
    pasteButton.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    panel:addChild(pasteButton)
    
    -- Add import button
    local importButton = ISButton:new(startX + buttonWidth + spacing, buttonY, buttonWidth, buttonHeight, getText("UI_characreation_BuildImport"), panel, function()
        local importCode = textArea:getText()
        if importCode and importCode ~= "" then
            local success, message = self:processImportCode(importCode)
            if success then
                self:showImportResult(true, message)
            else
                self:showImportResult(false, message)
            end
            panel:removeFromUIManager()
        else
            self:showImportResult(false, "Import code is empty")
            panel:removeFromUIManager()
        end
    end)
    importButton:initialise()
    importButton:instantiate()
    panel:addChild(importButton)
    
    -- Add cancel button
    local cancelButton = ISButton:new(startX + (buttonWidth + spacing) * 2, buttonY, buttonWidth, buttonHeight, getText("UI_btn_cancel"), panel, function()
        panel:removeFromUIManager()
    end)
    cancelButton:initialise()
    cancelButton:instantiate()
    panel:addChild(cancelButton)
    
    -- Add close button at top right
    local closeButton = ISButton:new(panel.width - 25, 5, 20, 20, "X", panel, function()
        panel:removeFromUIManager()
    end)
    closeButton:initialise()
    closeButton:instantiate()
    panel:addChild(closeButton)
    
    -- Handle joypad focus if needed
    local joypadData = JoypadState.getMainMenuJoypad() or CoopCharacterCreation.getJoypad()
    if joypadData then
        joypadData.focus = panel
        updateJoypadFocus(joypadData)
    end
end

-- Process the import code
function CharacterCreationMain:processImportCode(code)
    -- Check if code is valid
    if not code or code == "" then
        return false, "Import code is empty"
    end
    
    -- Try to extract build name and data from the imported string
    -- Expected format: "BuildName:data..."
    local buildName, buildData
    
    -- First check if the code contains a valid format
    if string.find(code, ":") then
        -- Contains a properly formatted build
        buildName, buildData = string.match(code, "([^:]+):(.+)")
        
        -- Trim whitespace
        if buildName then
            buildName = buildName:match("^%s*(.-)%s*$")
        end
    else
        -- Just data, assign default name
        buildData = code
        buildName = "Imported Build"
    end
    
    if not buildData or buildData == "" then
        return false, "Invalid build data format"
    end
    
    -- Check if name already exists and generate a unique one if needed
    local builds = CharacterCreationMain.readSavedOutfitFile()
    local originalName = buildName
    local counter = 1
    
    while builds[buildName] do
        buildName = originalName .. " " .. counter
        counter = counter + 1
    end
    
    -- Add to the builds list
    builds[buildName] = buildData
    CharacterCreationMain.writeSaveFile(builds)
    
    -- Refresh the saved builds dropdown
    self.savedBuilds.options = {}
    for key,_ in pairs(builds) do
        self.savedBuilds:addOption(key)
    end
    
    -- Select the newly imported build
    local index = 1
    for i, name in ipairs(self.savedBuilds.options) do
        if name == buildName then
            index = i
            break
        end
    end
    
    self.savedBuilds.selected = index
    self:loadOutfit(self.savedBuilds)
    
    return true, "Build imported successfully as '" .. buildName .. "'"
end

-- Show import result
function CharacterCreationMain:showImportResult(success, message)
    local text = message or (success and getText("UI_characreation_BuildImportSuccess") or getText("UI_characreation_BuildImportFailed"))
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    
    local modal = ISModalDialog:new(screenW / 2 - 175, screenH / 2 - 75, 350, 150, text, false, self, nil)
    modal:initialise()
    modal:addToUIManager()
end

-- Add the export function
function CharacterCreationMain:exportBuild()
    -- Get the selected build
    local buildName = self.savedBuilds.options[self.savedBuilds.selected]
    local builds = CharacterCreationMain.readSavedOutfitFile()
    local buildData = builds[buildName]
    
    if buildData then
        -- Format the export code to include the build name
        local exportCode = buildName .. ":" .. buildData
        
        -- Pre-process the text to ensure it wraps properly:
        -- Insert spaces after each semicolon to help the text wrapping algorithm
        local formattedCode = exportCode:gsub(";", "; ")
        
        -- Display the export code
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        
        -- Create a custom dialog for export
        local panel = ISPanel:new(screenW / 2 - 225, screenH / 2 - 125, 450, 250)
        panel:initialise()
        panel:addToUIManager()
        panel:setAlwaysOnTop(true)
        panel.backgroundColor = {r=0, g=0, b=0, a=0.9}
        panel.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
        
        -- Add title
        local titleLabel = ISLabel:new(0, 10, 30, getText("UI_characreation_BuildExportTitle"), 1, 1, 1, 1, UIFont.Medium, true)
        titleLabel:setX((panel.width - titleLabel.width) / 2)
        panel:addChild(titleLabel)
        
        -- Create a text box that properly wraps text using ISTextBox
        local textPanel = ISPanel:new(20, 40, panel.width - 40, 150)
        textPanel:initialise()
        textPanel.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
        textPanel.backgroundColor = {r=0.1, g=0.1, b=0.1, a=1}
        panel:addChild(textPanel)
        
        -- Create a richtext panel for displaying the export code
        local richText = ISRichTextPanel:new(20, 40, panel.width - 40, 150)
        -- Key settings for proper text wrapping
        richText.autosetheight = false
        richText.clip = true
        richText.maxLineWidth = textPanel.width - 20
        richText:initialise()
        richText:setAnchorTop(true)
        richText:setAnchorLeft(true)
        richText:setAnchorRight(true)
        richText:setMargins(10, 10, 10, 10)
        -- Set the text and force pagination
        richText:setText(formattedCode)
        richText:paginate()
        -- Add scrollbars for long content
        richText:addScrollBars()
        panel:addChild(richText)
        
        -- Create a button panel to ensure proper centering
        local buttonPanel = ISPanel:new(0, panel.height - 40, panel.width, 40)
        buttonPanel:initialise()
        buttonPanel.backgroundColor = {r=0, g=0, b=0, a=0}
        buttonPanel.borderColor = {r=0, g=0, b=0, a=0}
        panel:addChild(buttonPanel)
        
        -- Add copy button to the button panel
        local buttonWidth = 100
        local buttonHeight = 25
        local copyButton = ISButton:new((buttonPanel.width - buttonWidth) / 2, (buttonPanel.height - buttonHeight) / 2, 
                                       buttonWidth, buttonHeight, 
                                       getText("UI_characreation_Copy"), buttonPanel, function()
            Clipboard.setClipboard(exportCode)
            
            -- Show a confirmation
            local confirmModal = ISModalDialog:new(screenW / 2 - 175, screenH / 2 - 75, 350, 150, 
                                                 getText("UI_characreation_BuildExportCopied"), false, nil, nil)
            confirmModal:initialise()
            confirmModal:addToUIManager()
            
            panel:removeFromUIManager()
        end)
        copyButton:initialise()
        copyButton:instantiate()
        buttonPanel:addChild(copyButton)
        
        -- Add close button
        local closeButton = ISButton:new(panel.width - 25, 5, 20, 20, "X", panel, function()
            panel:removeFromUIManager()
        end)
        closeButton:initialise()
        closeButton:instantiate()
        panel:addChild(closeButton)
    end
end