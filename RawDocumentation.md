# Seraph Raw Documentation

## Purpose

Seraph is a dependency-free Roblox/Luau UI library loaded from one raw `source.lua` file. It provides a browser-like Material-inspired window, dark/light themes, side or top tabs, functional controls, music playback, notifications, dialogs, and local configuration files.

## Load

```lua
local Seraph = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToraScriptCopy/Seraph-ui-lib/main/source.lua"))()
```

## Create a window

```lua
local Window = Seraph:CreateWindow({
    Title = "Seraph",
    Author = "Project",
    Icon = 17332630292,
    Theme = "Seraph Dark",
    TabMode = "Left", -- Left or Top
    ToggleKey = Enum.KeyCode.RightShift,
    Size = {X = 720, Y = 520},
    Folder = "MyWindow",
    RootFolder = "Workspace",
    Tag = {Text = "BETA", Side = "right"},
})
```

Window methods: `Tab`, `CreateTab`, `AddTab`, `Notify`, `Popup`, `SetTheme`, `AddTheme`, `SetTag`, `Toggle`, `SetVisible`, `Minimize`, `BindKey`, `Destroy`, `ConfigureProtection`.

## Tabs and sections

```lua
local Tab = Window:Tab({Title = "Main", Icon = 17332630310})
Tab:TabSection("Group") -- sidebar mode only
local Section = Tab:Section({Title = "Controls"})
```

Every element can be called on `Tab` or `Section`. Tab-level calls use an implicit default section.

## Elements

Methods:

`Toggle`, `Checkbox`, `Button`, `Slider`, `Input`, `Dropdown`, `MultiDropdown`, `Keybind`, `Colorpicker`, `Code`, `Music`, `Paragraph`, `Divider`, `Space`, `Tag`.

Common fields: `Title`, `Desc`, `Tag`, `Default`, `Value`, `Flag`, `Callback`, `LayoutOrder`.

Examples:

```lua
local toggle = Section:Toggle({
    Title = "Toggle",
    Default = false,
    Flag = "ToggleFlag",
    Callback = function(value) print(value) end,
})

local slider = Section:Slider({
    Title = "Speed",
    Min = 0,
    Max = 100,
    Step = 5,
    Default = 50,
})

Section:Dropdown({Title = "Mode", Values = {"A", "B"}, Default = "A"})
Section:MultiDropdown({Title = "Features", Values = {"A", "B"}, Default = {"A"}})
Section:Input({Title = "Name", Placeholder = "Text"})
Section:Keybind({Title = "Hotkey", Default = Enum.KeyCode.F})
Section:Colorpicker({Title = "Color", Default = Color3.fromRGB(59, 130, 246)})
Section:Code({Title = "Code", Code = "print('ok')", Editable = false})
```

Element methods: `Get`, `Set`, `Destroy`. Keybind supports `OnPress`. Button supports `Activate`. Music supports `Play`, `Pause`, `Stop`, `Next`, `Previous`, `SetVolume`, `MoveTrack`.

## Music

```lua
local player = Section:Music({
    Title = "Playlist",
    Playlist = {
        {Id = 1843529634, Name = "Track one"},
        {Id = 1843529603, Name = "Track two"},
    },
    AutoPlay = false,
    AutoPlayNext = true,
    AllowReorder = true,
})
```

The player includes play/pause, previous/next, music volume, game-volume control, and optional playlist reordering. Game-volume changes snapshot existing `Sound` objects and exclude the Seraph music sound.

## Icons

```lua
Seraph:RegisterIcon("home", 17332630310)
Seraph:RegisterLucideIcon("settings", "rbxassetid://17332630292")
local Window = Seraph:CreateWindow({Icon = "home"})
```

An external Lucide table or resolver can be used:

```lua
Seraph:UseLucide({home = 17332630310, settings = 17332630292})
-- or Seraph:SetIconProvider(function(name) return Lucide[name] end)
```

Accepted icon sources: numeric asset IDs, `rbxassetid://` strings, URLs, `{Id = ...}`, `{AssetId = ...}`, and registered names. Lucide support is an asset-name registry; map Lucide names to real Roblox image assets in your project.

## Themes

Built-in themes: `Seraph Dark`, `Seraph Light`, `Seraph Midnight`.

```lua
Seraph:AddTheme({
    Name = "Custom",
    Accent = Color3.fromRGB(14, 165, 233),
    WindowBackground = Color3.fromRGB(8, 18, 32),
    ElementBackground = Color3.fromRGB(16, 40, 64),
    Text = Color3.fromRGB(240, 249, 255),
})
Window:SetTheme("Custom")
```

Theme roles include: `Accent`, `Background`, `BackgroundTransparency`, `Outline`, `Text`, `Placeholder`, `Button`, `Icon`, `Hover`, `WindowBackground`, `WindowShadow`, all `Dialog*`, `WindowTopbar*`, `Tab*`, `Element*`, `Popup*`, `Toggle`, `ToggleBar`, `Checkbox`, `CheckboxIcon`, `Slider`, `SliderThumb`, `Danger`, `Success`.

## Configs

Flags are automatically available to config save/load. Explicit registration is also supported.

```lua
local ToggleElement = Tab:Toggle({Title = "Toggle", Flag = "ToggleElement"})
local myConfig = Window.ConfigManager:CreateConfig("config1")
myConfig:Register("toggleNameExample", ToggleElement)
myConfig:Save()
myConfig:Load()
```

Default path:

```text
Workspace/Seraph/{Window.Folder}/config/config1.json
```

The manager checks executor file functions and fails safely when file access is unavailable.

## ArxProtect

ArxProtect is limited to local configuration sealing. It is not an anti-detection, anti-analysis, hierarchy-hiding, or security-bypass system.

```lua
local Window = Seraph:CreateWindow({
    ConfigProtection = true,
    ConfigKey = "local-key",
    AutoSealConfig = true,
    ConfigProtectionInterval = 30,
})

Window:ConfigureProtection({
    Enabled = true,
    Key = "local-key",
    AutoSeal = true,
    Interval = 30,
})
```

Public methods: `Seraph.ArxProtect:Seal`, `Unseal`, `SealTable`, `UnsealTable`, `Describe`.

The key is client-side and reversible. Do not store secrets. Use server-side authorization for sensitive actions.
