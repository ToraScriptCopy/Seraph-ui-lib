-- Seraph example
local RAW_URL = "https://raw.githubusercontent.com/ToraScriptCopy/Seraph-ui-lib/main/source.lua"
local Seraph = loadstring(game:HttpGet(RAW_URL))()

Seraph:AddTheme({
    Name = "Ocean Glass",
    Accent = Color3.fromRGB(14, 165, 233),
    Button = Color3.fromRGB(2, 132, 199),
    Toggle = Color3.fromRGB(14, 165, 233),
    Slider = Color3.fromRGB(56, 189, 248),
    WindowBackground = Color3.fromRGB(8, 18, 32),
    Background = Color3.fromRGB(12, 30, 50),
    ElementBackground = Color3.fromRGB(16, 40, 64),
    TabBackground = Color3.fromRGB(18, 48, 76),
    Text = Color3.fromRGB(240, 249, 255),
    ElementDesc = Color3.fromRGB(148, 204, 230),
})

-- A registered icon can be a Roblox asset ID, rbxassetid URL, or any icon
-- source your own icon provider exposes. The same registry accepts Lucide
-- names after you map them to an asset in your project.
Seraph:RegisterIcon("home", 17332630310)
Seraph:RegisterLucideIcon("settings", 17332630310)

local Window = Seraph:CreateWindow({
    Title = "Seraph Browser",
    Author = "Material Design 3 example",
    Icon = "home",
    Theme = "Ocean Glass",
    TabMode = "Left", -- use "Top" for top tabs
    ToggleKey = Enum.KeyCode.RightShift,
    Folder = "SeraphDemo",
    RootFolder = "Workspace",
    Size = {X = 780, Y = 570},
    Tag = {Text = "v1.0", Side = "right"},
    ConfigProtection = true,
    ConfigKey = "seraph-demo-config-key",
    AutoSealConfig = true,
})

local Home = Window:Tab({
    Name = "Home",
    Title = "Home",
    Icon = "home",
})

-- Tab:Section and Section:Section are both supported. Tab-level elements
-- are placed into an implicit default section.
Home:TabSection("Workspace")
local Controls = Home:Section({Title = "Controls"})

local ToggleElement = Controls:Toggle({
    Title = "Enable notifications",
    Desc = "This element is registered through a flag.",
    Default = true,
    Flag = "ToggleElement",
    Callback = function(value)
        print("Toggle Changed: " .. tostring(value))
    end,
})

local SliderElement = Controls:Slider({
    Title = "Opacity",
    Desc = "A numeric value with a configurable increment.",
    Min = 0,
    Max = 100,
    Default = 85,
    Step = 5,
    Flag = "OpacitySlider",
    Callback = function(value)
        print("Opacity: " .. tostring(value))
    end,
})

local DropdownElement = Controls:Dropdown({
    Title = "Browser profile",
    Values = {"Personal", "Work", "Testing"},
    Default = "Personal",
    Flag = "Profile",
})

local MultiDropdownElement = Controls:MultiDropdown({
    Title = "Allowed sites",
    Values = {"Docs", "GitHub", "Roblox", "Local"},
    Default = {"Docs", "GitHub"},
    Flag = "AllowedSites",
})

local KeybindElement = Controls:Keybind({
    Title = "Quick toggle",
    Desc = "Press a key to run the callback.",
    Default = Enum.KeyCode.F,
    Flag = "QuickToggleKey",
    OnPress = function(key)
        print("Pressed: " .. tostring(key))
    end,
})

Controls:Input({
    Title = "Search",
    Placeholder = "Enter a query",
    Flag = "SearchQuery",
    Callback = function(value)
        print("Search: " .. value)
    end,
})

Controls:Colorpicker({
    Title = "Accent color",
    Default = Color3.fromRGB(14, 165, 233),
    Flag = "AccentColor",
})

Controls:Button({
    Title = "Open popup",
    ButtonText = "Show",
    Callback = function()
        Window:Popup({
            Title = "Seraph popup",
            Content = "This is a functional dialog with callback buttons.",
            Buttons = {
                {
                    Text = "Accept",
                    Primary = true,
                    Callback = function()
                        Window:Notify({
                            Title = "Accepted",
                            Content = "The popup action ran successfully.",
                            Type = "Success",
                        })
                    end,
                },
                {Text = "Cancel"},
            },
        })
    end,
})

Controls:Divider()
Controls:Space(8)
Controls:Paragraph({
    Title = "About this example",
    Content = "Seraph uses a browser-like window, compact Material-inspired surfaces, top or side tabs, and a theme registry that can be extended at runtime.",
    Tag = "Info",
})

local Media = Window:Tab({
    Name = "Media",
    Title = "Media",
    Icon = "settings",
})

Media:Section({Title = "Music"}):Music({
    Title = "Playlist",
    Desc = "Music and game volume use separate sliders.",
    Playlist = {
        {Id = 1843529634, Name = "Track one"},
        {Id = 1843529603, Name = "Track two"},
    },
    AutoPlay = false,
    AutoPlayNext = true,
    AllowReorder = true,
})

local CodeTab = Window:Tab({
    Name = "Code",
    Title = "Code",
    Icon = "settings",
})

CodeTab:Code({
    Title = "Read-only code block",
    Code = "local value = true\nprint(value)",
    Editable = false,
})

local ConfigManager = Window.ConfigManager
local myConfig = ConfigManager:CreateConfig("config1")

-- Flag-based registration: every element with Flag is included automatically.
-- Explicit registration also works for elements without a Flag.
myConfig:Register("toggleNameExample", ToggleElement)
myConfig:Register("sliderExample", SliderElement)
myConfig:Register("profileExample", DropdownElement)
myConfig:Register("sitesExample", MultiDropdownElement)
myConfig:Register("keybindExample", KeybindElement)

-- Both calls are safe when file APIs are unavailable; they return false and
-- show a notification instead of stopping the UI.
myConfig:Save()
myConfig:Load()

-- To switch themes later:
-- Window:SetTheme("Seraph Light")
-- Window:SetTheme("Seraph Midnight")
-- Window:SetTheme("Ocean Glass")
