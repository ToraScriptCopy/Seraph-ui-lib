--[[
    Seraph UI Library - Comprehensive Example
    Demonstrates:
    - Fixed and fully responsive Toggles
    - Modern Sliders with visual progress and editable numeric input
    - Accordion Dropdowns with live search filtering
    - MultiDropdowns with tag chips and individual removals
    - DropDownPlayersAuto with automated PlayerAdded / PlayerRemoving tracking
    - Full visual Colorpicker studio with 2D HSV canvas and Hex/RGB boxes
    - Collapsible Sections with smooth animated height & chevron rotation
    - Dynamic runtime UI capabilities: elements can be spawned, destroyed, modified, and toggled on-the-fly
    - Spotify-style Music player card with non-overlapping controls
    - Browser Omnibox Search bar without awkward protocols
    - Config Manager with encryption and flag auto-binding
]]

local Seraph
local function loadLibrary()
    if pcall(function() return readfile and readfile("source.lua") end) then
        local content = readfile("source.lua")
        if content and #content > 0 then
            return loadstring(content)()
        end
    end
    local RAW_URL = "https://raw.githubusercontent.com/ToraScriptCopy/Seraph-ui-lib/refs/heads/main/source.lua"
    local ok, res = pcall(function()
        return game:HttpGet(RAW_URL)
    end)
    if ok and res then
        return loadstring(res)()
    end
    error("Unable to load Seraph source.lua")
end

Seraph = loadLibrary()

-- Optional external icon runtime (lucide, solar, craft, etc.)
pcall(function()
    Seraph:LoadIcons({Type = "lucide"})
end)

local Window = Seraph:CreateWindow({
    Title = "Seraph Studio",
    Author = "Advanced UI Showcase",
    TabMode = "Left", -- "Left" or "Top"
    ToggleKey = Enum.KeyCode.RightShift,
    Folder = "SeraphDemo",
    RootFolder = "Workspace",
    Size = {X = 780, Y = 570},
    Tag = {Text = "v2.0", Side = "right"},
    SearchEnabled = true,
    SearchPlaceholder = "Search controls, features...",
    ConfigProtection = false,
})

----------------------------------------------------------------------
-- TAB 1: CONTROLS & REBUILT WIDGETS
----------------------------------------------------------------------
local ControlsTab = Window:Tab({
    Name = "Controls",
    Title = "Controls",
    Icon = "lucide:sliders",
})

ControlsTab:TabSection("Interactive Controls")

local MainSection = ControlsTab:Section({
    Title = "Core Widgets",
    Collapsible = true,
})

-- 1. Working Toggles (Click entire row or switch, smooth knob animation)
local Toggle1 = MainSection:Toggle({
    Title = "Auto Sprint",
    Desc = "Entire row is clickable. Updates instantly without errors.",
    Default = true,
    Flag = "AutoSprint",
    Callback = function(state)
        print("[Toggle] Auto Sprint:", state)
    end,
})

local Toggle2 = MainSection:Toggle({
    Title = "Silent Aim",
    Desc = "Secondary feature toggle with state callback.",
    Default = false,
    Flag = "SilentAim",
    Callback = function(state)
        print("[Toggle] Silent Aim:", state)
    end,
})

-- 2. Modern Sliders (Full-width bar, animated progress fill, expanding thumb, editable number box)
local WalkSpeedSlider = MainSection:Slider({
    Title = "WalkSpeed Multiplier",
    Desc = "Drag the thumb or click the number box to type directly.",
    Min = 16,
    Max = 200,
    Default = 28,
    Step = 1,
    Flag = "WalkSpeed",
    Callback = function(value)
        print("[Slider] WalkSpeed set to:", value)
    end,
})

local FovSlider = MainSection:Slider({
    Title = "Field of View",
    Desc = "Adjust camera field of view angle.",
    Min = 60,
    Max = 120,
    Default = 90,
    Step = 2,
    Flag = "CameraFOV",
    Callback = function(value)
        print("[Slider] FOV set to:", value)
    end,
})

-- 3. Modern Accordion Dropdowns with live search filtering
local TargetDropdown = MainSection:Dropdown({
    Title = "Hitbox Target",
    Desc = "Click to expand inline menu. Type in the search box to filter.",
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "Random"},
    Default = "Head",
    Flag = "HitboxTarget",
    Callback = function(selected)
        print("[Dropdown] Target selected:", selected)
    end,
})

-- 4. MultiDropdown with tag chips & individual removal buttons
local ESPTagsDropdown = MainSection:MultiDropdown({
    Title = "ESP Visual Elements",
    Desc = "Select multiple tags. Click a chip 'x' or the list row to toggle.",
    Values = {"Box", "Name", "Health Bar", "Distance", "Tracer", "Chams", "Skeleton"},
    Default = {"Box", "Name", "Distance"},
    Flag = "ESPTags",
    Callback = function(selectedList)
        print("[MultiDropdown] Selected tags:", table.concat(selectedList, ", "))
    end,
})

-- 5. DropDownPlayersAuto: automatically tracks players joining and leaving
local PlayerDropdown = MainSection:DropDownPlayersAuto({
    Title = "Player Selector (Auto-Updating)",
    Desc = "Automatically syncs on PlayerAdded & PlayerRemoving without code boilerplate.",
    IncludeLocalPlayer = true,
    Flag = "TargetPlayer",
    Callback = function(playerName)
        print("[PlayerDropdown] Target player chosen:", playerName)
    end,
})

-- 6. Modern Colorpicker: full visual HSV palette studio
local ESPColorpicker = MainSection:Colorpicker({
    Title = "Chams Color",
    Desc = "Expand to open 2D SV palette canvas, Hue slider, and Hex/RGB inputs.",
    Default = Color3.fromRGB(0, 200, 255),
    Flag = "ChamsColor",
    Callback = function(col)
        print("[Colorpicker] Color changed to RGB:", math.floor(col.R*255), math.floor(col.G*255), math.floor(col.B*255))
    end,
})

local SubSection = ControlsTab:Section({
    Title = "Additional Utilities",
    Collapsible = true,
})

SubSection:Keybind({
    Title = "Menu Toggle Key",
    Desc = "Press keybind to reassign.",
    Default = Enum.KeyCode.RightShift,
    Flag = "MenuBind",
    OnPress = function(key)
        print("[Keybind] Pressed:", key)
    end,
})

SubSection:Input({
    Title = "Custom Webhook URL",
    Desc = "Input arbitrary string parameter.",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "WebhookURL",
    Callback = function(text)
        print("[Input] Webhook:", text)
    end,
})

SubSection:Button({
    Title = "Interactive Modal Dialog",
    Desc = "Displays a Seraph Popup with action callbacks.",
    ButtonText = "Open Popup",
    Callback = function()
        Window:Popup({
            Title = "Confirm Action",
            Content = "All Seraph UI components have been completely upgraded with responsive animations and runtime dynamism.",
            Buttons = {
                {
                    Text = "Proceed",
                    Primary = true,
                    Callback = function()
                        Window:Notify({
                            Title = "Action Executed",
                            Content = "The requested action completed successfully.",
                            Type = "Success",
                        })
                    end,
                },
                {Text = "Dismiss"},
            },
        })
    end,
})

----------------------------------------------------------------------
-- TAB 2: DYNAMIC RUNTIME UI
----------------------------------------------------------------------
local DynamicTab = Window:Tab({
    Name = "Dynamic UI",
    Title = "Dynamic UI",
    Icon = "lucide:sparkles",
})

DynamicTab:TabSection("Runtime Modification")

local DynamicSection = DynamicTab:Section({
    Title = "Live Script Mutators",
    Desc = "Add, remove, and alter elements on-the-fly while the script is running.",
    Collapsible = true,
})

-- Live status label updated every second via :SetTitle() and :SetDesc()
local LiveStatus = DynamicSection:Paragraph({
    Title = "Live Clock: Starting...",
    Content = "Waiting for ticker loop...",
    Tag = "Live",
})

task.spawn(function()
    local counter = 0
    while true do
        task.wait(1)
        counter = counter + 1
        pcall(function()
            if LiveStatus and LiveStatus.SetTitle then
                LiveStatus:SetTitle("Live Clock: " .. os.date("%X"))
                LiveStatus:SetDesc("Runtime elapsed: " .. tostring(counter) .. "s | Active dynamic widgets: working")
            end
        end)
    end
end)

local dynamicElements = {}
local elementCounter = 0

DynamicSection:Button({
    Title = "Add Dynamic Toggle",
    Desc = "Creates a new Toggle element right now at runtime.",
    ButtonText = "+ Add Toggle",
    Callback = function()
        elementCounter = elementCounter + 1
        local currentNum = elementCounter
        local newToggle = DynamicSection:Toggle({
            Title = "Dynamic Toggle #" .. tostring(currentNum),
            Desc = "Created at runtime at " .. os.date("%X"),
            Default = false,
            Callback = function(val)
                print("[Dynamic Toggle #" .. currentNum .. "] State:", val)
            end,
        })
        dynamicElements[#dynamicElements + 1] = newToggle
        Window:Notify({
            Title = "Element Spawned",
            Content = "Added Dynamic Toggle #" .. tostring(currentNum),
            Type = "Success",
        })
    end,
})

DynamicSection:Button({
    Title = "Add Dynamic Button",
    Desc = "Creates a new Button element right now at runtime.",
    ButtonText = "+ Add Button",
    Callback = function()
        elementCounter = elementCounter + 1
        local currentNum = elementCounter
        local newBtn = DynamicSection:Button({
            Title = "Dynamic Button #" .. tostring(currentNum),
            Desc = "Click to trigger dynamic callback",
            ButtonText = "Fire #" .. tostring(currentNum),
            Callback = function()
                Window:Notify({
                    Title = "Dynamic Callback",
                    Content = "You clicked dynamic button #" .. tostring(currentNum),
                    Type = "Info",
                })
            end,
        })
        dynamicElements[#dynamicElements + 1] = newBtn
        Window:Notify({
            Title = "Element Spawned",
            Content = "Added Dynamic Button #" .. tostring(currentNum),
            Type = "Success",
        })
    end,
})

DynamicSection:Button({
    Title = "Remove Last Added Element",
    Desc = "Calls :Destroy() on the most recently added element.",
    ButtonText = "— Remove Last",
    Callback = function()
        if #dynamicElements > 0 then
            local lastElement = table.remove(dynamicElements, #dynamicElements)
            if lastElement and lastElement.Destroy then
                lastElement:Destroy()
                Window:Notify({
                    Title = "Element Destroyed",
                    Content = "Removed element dynamically. Canvas resized.",
                    Type = "Warn",
                })
            end
        else
            Window:Notify({
                Title = "Nothing to Remove",
                Content = "Spawn some dynamic elements first.",
                Type = "Info",
            })
        end
    end,
})

-- Secret panel demonstrating element:SetVisible()
local SecretPanel = DynamicSection:Paragraph({
    Title = "Secret Developer Diagnostic",
    Content = "This paragraph can be toggled visible/hidden dynamically at runtime.",
    Tag = "Diagnostic",
})

DynamicSection:Toggle({
    Title = "Toggle Secret Diagnostic Visibility",
    Desc = "Demonstrates element:SetVisible() dynamically.",
    Default = true,
    Callback = function(visible)
        SecretPanel:SetVisible(visible)
    end,
})

----------------------------------------------------------------------
-- TAB 3: MEDIA (SPOTIFY-STYLE MUSIC PLAYER)
----------------------------------------------------------------------
local MediaTab = Window:Tab({
    Name = "Media",
    Title = "Media",
    Icon = "lucide:music",
})

local MusicSection = MediaTab:Section({
    Title = "Spotify Audio Studio",
    Collapsible = false,
})

MusicSection:Music({
    Title = "Seraph Lo-Fi Chill",
    Desc = "Spotify-style audio player with non-overlapping transport controls.",
    Playlist = {
        {Id = 1843529634, Name = "Midnight Drive", Artist = "SynthWave", Album = "Neon Dreams"},
        {Id = 1843529603, Name = "Starlight Serenade", Artist = "Acoustic Vibes", Album = "Cosmos"},
        {Id = 1843485743, Name = "Retro Arcade", Artist = "8-Bit Hero", Album = "Pixel Quest"},
    },
    AutoPlay = false,
    AutoPlayNext = true,
    AllowReorder = true,
})

----------------------------------------------------------------------
-- TAB 4: CONFIGURATION
----------------------------------------------------------------------
local ConfigTab = Window:Tab({
    Name = "Config",
    Title = "Config",
    Icon = "lucide:folder-cog",
})

local ConfigSection = ConfigTab:Section({
    Title = "Profile Storage",
    Collapsible = false,
})

local ConfigManager = Window.ConfigManager
local activeConfig = ConfigManager:CreateConfig("default_profile")

ConfigSection:Button({
    Title = "Save Current Profile",
    Desc = "Serializes all flags to local config storage.",
    ButtonText = "Save Config",
    Callback = function()
        local ok = activeConfig:Save()
        if ok then
            Window:Notify({
                Title = "Config Saved",
                Content = "Saved current flag states to default_profile.",
                Type = "Success",
            })
        end
    end,
})

ConfigSection:Button({
    Title = "Load Saved Profile",
    Desc = "Restores all flagged element values.",
    ButtonText = "Load Config",
    Callback = function()
        local ok = activeConfig:Load()
        if ok then
            Window:Notify({
                Title = "Config Loaded",
                Content = "Restored flag states from default_profile.",
                Type = "Info",
            })
        end
    end,
})

ConfigSection:Divider()

ConfigSection:Paragraph({
    Title = "About Seraph 2.0",
    Content = "Seraph features native Roblox automatic sizing, resilient element manipulation, inline expandable dropdowns and palettes, search omnibox, and full player auto-tracking.",
})

Window:Notify({
    Title = "Seraph Loaded",
    Content = "Welcome to Seraph Studio! Press RightShift to toggle window.",
    Type = "Success",
    Duration = 5,
})
