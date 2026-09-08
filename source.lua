--[=[
    Seraph UI Library
    A self-contained Roblox UI library for educational projects and local tooling.

    The file is intentionally dependency-free so it can be loaded with:
        local Seraph = loadstring(game:HttpGet(RAW_URL))()

    Seraph focuses on a real, accessible interface. It does not attempt to hide
    an interface from Roblox, an executor, or a security product.
]=]

local Services = setmetatable({}, {
    __index = function(self, serviceName)
        local service = game:GetService(serviceName)
        rawset(self, serviceName, service)
        return service
    end,
})

local Players = Services.Players
local LocalPlayer = Players.LocalPlayer
local HttpService = Services.HttpService
local TweenService = Services.TweenService
local UserInputService = Services.UserInputService
local RunService = Services.RunService
local SoundService = Services.SoundService

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return true
    end

    return pcall(callback, ...)
end

local function cloneTable(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, item in pairs(value) do
        result[key] = cloneTable(item)
    end
    return result
end

local function mergeTables(base, extra)
    local result = cloneTable(base or {})
    for key, value in pairs(extra or {}) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeTables(result[key], value)
        else
            result[key] = value
        end
    end
    return result
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function sanitizeName(value, fallback)
    local result = trim(value):gsub("[^%w_%-.]", "_")
    if result == "" then
        return fallback or "Seraph"
    end
    return result
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function round(value, decimals)
    local multiplier = 10 ^ (decimals or 0)
    return math.floor(value * multiplier + 0.5) / multiplier
end

local function colorFromHex(hex)
    hex = tostring(hex or ""):gsub("#", "")
    if #hex == 3 then
        hex = hex:sub(1, 1) .. hex:sub(1, 1) .. hex:sub(2, 2) .. hex:sub(2, 2) .. hex:sub(3, 3) .. hex:sub(3, 3)
    end

    local number = tonumber(hex, 16) or 0
    return Color3.fromRGB(
        bit32.rshift(number, 16) % 256,
        bit32.rshift(number, 8) % 256,
        number % 256
    )
end

local function color(value, fallback)
    if typeof(value) == "Color3" then
        return value
    end
    if type(value) == "string" then
        return colorFromHex(value)
    end
    return fallback or Color3.new(1, 1, 1)
end

local function assetId(value)
    if value == nil then
        return ""
    end

    if type(value) == "number" then
        return "rbxassetid://" .. tostring(value)
    end

    local text = tostring(value)
    if text:match("^rbxasset") or text:match("^https?://") then
        return text
    end
    if text:match("^%d+$") then
        return "rbxassetid://" .. text
    end
    return text
end

local function create(className, properties, parent)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        local success = pcall(function()
            instance[property] = value
        end)
        if not success then
            -- Optional properties differ slightly between Roblox environments.
        end
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, parent)
end

local function addStroke(parent, colorValue, transparency, thickness)
    return create("UIStroke", {
        Color = colorValue or Color3.new(1, 1, 1),
        Transparency = transparency == nil and 0.8 or transparency,
        Thickness = thickness or 1,
    }, parent)
end

local function addPadding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

local function addList(parent, direction, padding, horizontalAlignment)
    return create("UIListLayout", {
        FillDirection = direction or Enum.FillDirection.Vertical,
        Padding = UDim.new(0, padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = horizontalAlignment or Enum.HorizontalAlignment.Left,
    }, parent)
end

local function tween(instance, properties, duration, style, direction)
    local info = TweenInfo.new(
        duration or 0.18,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    local animation = TweenService:Create(instance, info, properties)
    animation:Play()
    return animation
end

local function disconnectAll(connections)
    for _, connection in ipairs(connections or {}) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
end

local function connectInput(instance, callback)
    local connection = instance.InputBegan:Connect(callback)
    return connection
end

local function normalizeKey(key)
    if typeof(key) == "EnumItem" then
        return key.Name
    end
    if type(key) == "string" then
        return key:gsub("^Enum%.KeyCode%.", "")
    end
    return "Unknown"
end

local function findValue(list, value)
    for index, item in ipairs(list) do
        if item == value then
            return index
        end
    end
    return nil
end

local function getGuiParent()
    local success, hiddenUi = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
        return nil
    end)
    if success and hiddenUi then
        return hiddenUi
    end

    if LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") then
        return LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end

    return Services.CoreGui
end

local function enumKeyCode(name)
    if typeof(name) == "EnumItem" then
        return name
    end
    if type(name) == "string" and Enum.KeyCode[name] then
        return Enum.KeyCode[name]
    end
    return Enum.KeyCode.Unknown
end

local function encodeJson(value)
    local success, result = pcall(function()
        return HttpService:JSONEncode(value)
    end)
    if success then
        return result
    end
    return "{}"
end

local function decodeJson(value)
    local success, result = pcall(function()
        return HttpService:JSONDecode(value)
    end)
    if success then
        return result
    end
    return nil
end

-- Minimal Base64 implementation used for optional config sealing.
local Base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64Encode(input)
    local output = {}
    local index = 1
    while index <= #input do
        local a = input:byte(index) or 0
        local b = input:byte(index + 1) or 0
        local c = input:byte(index + 2) or 0
        local triple = a * 65536 + b * 256 + c
        local first = math.floor(triple / 262144) % 64 + 1
        local second = math.floor(triple / 4096) % 64 + 1
        local third = math.floor(triple / 64) % 64 + 1
        local fourth = triple % 64 + 1
        output[#output + 1] = Base64Alphabet:sub(first, first)
        output[#output + 1] = Base64Alphabet:sub(second, second)
        output[#output + 1] = index + 1 <= #input and Base64Alphabet:sub(third, third) or "="
        output[#output + 1] = index + 2 <= #input and Base64Alphabet:sub(fourth, fourth) or "="
        index = index + 3
    end
    return table.concat(output)
end

local function base64Decode(input)
    input = input:gsub("[^%w%+/=]", "")
    local output = {}
    for index = 1, #input, 4 do
        local a = Base64Alphabet:find(input:sub(index, index), 1, true) or 1
        local b = Base64Alphabet:find(input:sub(index + 1, index + 1), 1, true) or 1
        local cChar = input:sub(index + 2, index + 2)
        local dChar = input:sub(index + 3, index + 3)
        local c = cChar == "=" and 0 or (Base64Alphabet:find(cChar, 1, true) or 1)
        local d = dChar == "=" and 0 or (Base64Alphabet:find(dChar, 1, true) or 1)
        local triple = (a - 1) * 262144 + (b - 1) * 4096 + (c - 1) * 64 + (d - 1)
        output[#output + 1] = string.char(math.floor(triple / 65536) % 256)
        if cChar ~= "=" then
            output[#output + 1] = string.char(math.floor(triple / 256) % 256)
        end
        if dChar ~= "=" then
            output[#output + 1] = string.char(triple % 256)
        end
    end
    return table.concat(output)
end

local function xorString(value, key)
    key = tostring(key or "Seraph")
    if key == "" then
        key = "Seraph"
    end

    local output = table.create(#value)
    for index = 1, #value do
        local left = value:byte(index)
        local right = key:byte(((index - 1) % #key) + 1)
        output[index] = string.char(bit32.bxor(left, right))
    end
    return table.concat(output)
end

local ArxProtect = {}
ArxProtect.__index = ArxProtect

function ArxProtect:Seal(value, key)
    local text = type(value) == "string" and value or encodeJson(value)
    return "SRP1." .. base64Encode(xorString(text, key or "Seraph"))
end

function ArxProtect:Unseal(value, key)
    if type(value) ~= "string" or not value:match("^SRP1%.") then
        return value
    end

    local encoded = value:sub(6)
    local success, result = pcall(function()
        return xorString(base64Decode(encoded), key or "Seraph")
    end)
    if success then
        return result
    end
    return nil
end

function ArxProtect:SealTable(value, key)
    return self:Seal(encodeJson(value), key)
end

function ArxProtect:UnsealTable(value, key)
    local decoded = self:Unseal(value, key)
    return decodeJson(decoded)
end

function ArxProtect:Describe()
    return {
        Name = "ArxProtect",
        Version = "1.0.0",
        Scope = "configuration-state",
        Note = "This module seals local configuration data. It is not an anti-detection or anti-analysis system.",
    }
end

local DefaultTheme = {
    Name = "Seraph Dark",
    Accent = colorFromHex("2196F3"),
    Background = colorFromHex("191919"),
    BackgroundTransparency = 0,
    Outline = colorFromHex("323232"),
    Text = colorFromHex("F5F5F5"),
    Placeholder = colorFromHex("8A8A8A"),
    Button = colorFromHex("323232"),
    Icon = colorFromHex("BDBDBD"),
    Hover = colorFromHex("2A2A2A"),
    WindowBackground = colorFromHex("191919"),
    WindowShadow = colorFromHex("000000"),
    DialogBackground = colorFromHex("1F1F1F"),
    DialogBackgroundTransparency = 0,
    DialogTitle = colorFromHex("F5F5F5"),
    DialogContent = colorFromHex("BDBDBD"),
    DialogIcon = colorFromHex("64B5F6"),
    WindowTopbarButtonIcon = colorFromHex("BDBDBD"),
    WindowTopbarTitle = colorFromHex("F5F5F5"),
    WindowTopbarAuthor = colorFromHex("8A8A8A"),
    WindowTopbarIcon = colorFromHex("64B5F6"),
    TabBackground = colorFromHex("1F1F1F"),
    TabTitle = colorFromHex("BDBDBD"),
    TabIcon = colorFromHex("8A8A8A"),
    ElementBackground = colorFromHex("1F1F1F"),
    ElementTitle = colorFromHex("F5F5F5"),
    ElementDesc = colorFromHex("9E9E9E"),
    ElementIcon = colorFromHex("BDBDBD"),
    PopupBackground = colorFromHex("1F1F1F"),
    PopupBackgroundTransparency = 0.02,
    PopupTitle = colorFromHex("F5F5F5"),
    PopupContent = colorFromHex("BDBDBD"),
    PopupIcon = colorFromHex("64B5F6"),
    Toggle = colorFromHex("2196F3"),
    ToggleBar = colorFromHex("F5F5F5"),
    Checkbox = colorFromHex("2196F3"),
    CheckboxIcon = colorFromHex("FFFFFF"),
    Slider = colorFromHex("2196F3"),
    SliderThumb = colorFromHex("FFFFFF"),
    Danger = colorFromHex("F44336"),
    Success = colorFromHex("4CAF50"),
    Warning = colorFromHex("FFC107"),
}

local LightTheme = mergeTables(DefaultTheme, {
    Name = "Seraph Light",
    Accent = colorFromHex("2563EB"),
    Background = colorFromHex("F1F5F9"),
    Outline = colorFromHex("CBD5E1"),
    Text = colorFromHex("0F172A"),
    Placeholder = colorFromHex("64748B"),
    Button = colorFromHex("2563EB"),
    Icon = colorFromHex("475569"),
    Hover = colorFromHex("0F172A"),
    WindowBackground = colorFromHex("F8FAFC"),
    WindowShadow = colorFromHex("64748B"),
    DialogBackground = colorFromHex("FFFFFF"),
    DialogTitle = colorFromHex("0F172A"),
    DialogContent = colorFromHex("475569"),
    DialogIcon = colorFromHex("2563EB"),
    WindowTopbarButtonIcon = colorFromHex("475569"),
    WindowTopbarTitle = colorFromHex("0F172A"),
    WindowTopbarAuthor = colorFromHex("64748B"),
    WindowTopbarIcon = colorFromHex("2563EB"),
    TabBackground = colorFromHex("E2E8F0"),
    TabTitle = colorFromHex("334155"),
    TabIcon = colorFromHex("64748B"),
    ElementBackground = colorFromHex("FFFFFF"),
    ElementTitle = colorFromHex("0F172A"),
    ElementDesc = colorFromHex("64748B"),
    ElementIcon = colorFromHex("475569"),
    PopupBackground = colorFromHex("FFFFFF"),
    PopupTitle = colorFromHex("0F172A"),
    PopupContent = colorFromHex("475569"),
    PopupIcon = colorFromHex("2563EB"),
    ToggleBar = colorFromHex("CBD5E1"),
    CheckboxIcon = colorFromHex("FFFFFF"),
    SliderThumb = colorFromHex("FFFFFF"),
})

local MidnightTheme = mergeTables(DefaultTheme, {
    Name = "Seraph Midnight",
    Accent = colorFromHex("8B5CF6"),
    Button = colorFromHex("7C3AED"),
    Toggle = colorFromHex("7C3AED"),
    Slider = colorFromHex("8B5CF6"),
    WindowBackground = colorFromHex("09090B"),
    Background = colorFromHex("18181B"),
    ElementBackground = colorFromHex("27272A"),
    TabBackground = colorFromHex("27272A"),
})

local ThemeColorKeys = {
    "Accent", "Background", "Outline", "Text", "Placeholder", "Button", "Icon", "Hover",
    "WindowBackground", "WindowShadow", "DialogBackground", "DialogTitle", "DialogContent", "DialogIcon",
    "WindowTopbarButtonIcon", "WindowTopbarTitle", "WindowTopbarAuthor", "WindowTopbarIcon",
    "TabBackground", "TabTitle", "TabIcon", "ElementBackground", "ElementTitle", "ElementDesc",
    "ElementIcon", "PopupBackground", "PopupTitle", "PopupContent", "PopupIcon", "Toggle",
    "ToggleBar", "Checkbox", "CheckboxIcon", "Slider", "SliderThumb", "Danger", "Success", "Warning",
}

local function normalizeTheme(theme)
    local result = mergeTables(DefaultTheme, theme)
    for _, key in ipairs(ThemeColorKeys) do
        if type(result[key]) == "string" then
            result[key] = colorFromHex(result[key])
        end
    end
    return result
end

local Seraph = {
    Name = "Seraph",
    Version = "1.0.0",
    -- ImageLabel.Image must receive the texture/image ID. The asset ID is
    -- kept only as a legacy reference and is never used for the default logo.
    LogoTextureId = 17332630292,
    LogoTexture = "rbxassetid://17332630292",
    LogoAsset = "rbxassetid://17332630292",
    LogoAssetId = 17332630310,
    Themes = {
        [DefaultTheme.Name] = DefaultTheme,
        [LightTheme.Name] = LightTheme,
        [MidnightTheme.Name] = MidnightTheme,
    },
    Icons = {},
    IconProvider = nil,
    Windows = {},
    ArxProtect = ArxProtect,
}

function Seraph:AddTheme(theme)
    assert(type(theme) == "table", "Seraph:AddTheme expects a table")
    assert(theme.Name and trim(theme.Name) ~= "", "Seraph:AddTheme requires a Name")
    self.Themes[theme.Name] = normalizeTheme(theme)
    return self.Themes[theme.Name]
end

function Seraph:GetTheme(name)
    if type(name) == "table" then
        return normalizeTheme(name)
    end
    return self.Themes[name or DefaultTheme.Name] or self.Themes[DefaultTheme.Name]
end

function Seraph:RegisterIcon(name, source)
    assert(type(name) == "string", "Seraph:RegisterIcon requires a name")
    self.Icons[name:lower()] = source
    return source
end

Seraph.RegisterLucideIcon = Seraph.RegisterIcon

function Seraph:SetIconProvider(provider)
    assert(type(provider) == "function" or type(provider) == "table", "Seraph:SetIconProvider expects a function or table")
    self.IconProvider = provider
    return provider
end

function Seraph:UseLucide(provider)
    return self:SetIconProvider(provider)
end

function Seraph:RegisterIcons(iconMap)
    assert(type(iconMap) == "table", "Seraph:RegisterIcons expects a table")
    for name, source in pairs(iconMap) do
        self:RegisterIcon(name, source)
    end
    return self
end

function Seraph:LoadIcons(options)
    options = options or {}
    if self.IconRuntime then
        return self.IconRuntime
    end

    local loader = loadstring
    if type(loader) ~= "function" then
        return nil, "loadstring is unavailable"
    end

    local url = options.URL or self.IconURL
    local request = game.HttpGetAsync or game.HttpGet
    if type(request) ~= "function" then
        return nil, "game:HttpGet is unavailable"
    end

    local success, source = pcall(function()
        return request(game, url)
    end)
    if not success then
        return nil, source
    end

    local loadSuccess, runtime = pcall(function()
        return loader(source)()
    end)
    if not loadSuccess or type(runtime) ~= "table" then
        return nil, runtime or "icon runtime returned an invalid value"
    end

    if runtime.SetIconsType then
        pcall(runtime.SetIconsType, options.Type or "lucide")
    end
    for packName, iconsData in pairs(self._customIconPacks or {}) do
        if runtime.AddIcons then
            pcall(runtime.AddIcons, packName, iconsData)
        end
    end
    self.IconRuntime = runtime
    self.IconProvider = runtime
    return runtime
end

function Seraph:SetIconType(iconType)
    if self.IconRuntime and type(self.IconRuntime.SetIconsType) == "function" then
        self.IconRuntime.SetIconsType(iconType)
    end
    return self
end

function Seraph:AddIcons(packName, iconsData)
    if self.IconRuntime and type(self.IconRuntime.AddIcons) == "function" then
        self.IconRuntime.AddIcons(packName, iconsData)
    else
        self._customIconPacks = self._customIconPacks or {}
        self._customIconPacks[packName] = iconsData
    end
    return self
end

Seraph.IconURL = "https://raw.githubusercontent.com/Footagesus/Icons/46d30c19ba7bc601d6ec794a48dc3a89568b1eec/Main-v2.lua"

function Seraph:ResolveIcon(source)
    if type(source) == "table" then
        if source.Icon then
            return self:ResolveIcon(source.Icon)
        end
        if source.AssetId or source.Id then
            return assetId(source.AssetId or source.Id)
        end
        if source.Source then
            return self:ResolveIcon(source.Source)
        end
        if source.Name then
            return self:ResolveIcon(source.Name)
        end
    end

    if source == nil then
        return self.LogoAsset
    end

    if type(source) == "string" then
        local registered = self.Icons[source:lower()]
        if registered then
            return assetId(registered)
        end
        if self.IconProvider then
            local success, provided
            if type(self.IconProvider) == "function" then
                success, provided = pcall(self.IconProvider, source)
            elseif type(self.IconProvider.GetIcon) == "function" then
                success, provided = pcall(self.IconProvider.GetIcon, source)
            else
                success, provided = pcall(function()
                    return self.IconProvider[source] or self.IconProvider[source:lower()]
                end)
            end
            if success and provided then
                return assetId(provided)
            end
        end
        if source:match("^rbxasset") or source:match("^https?://") or source:match("^%d+$") then
            return assetId(source)
        end
        return self.LogoAsset
    end

    return assetId(source)
end

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

function Window:_bind(instance, property, role)
    local value = self.Theme[role]
    if value ~= nil then
        pcall(function()
            instance[property] = value
        end)
    end
    self._bindings[#self._bindings + 1] = {
        Instance = instance,
        Property = property,
        Role = role,
    }
    return instance
end

function Window:_textLabel(parent, text, size, colorRole, properties)
    local settings = mergeTables({
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = self.Theme[colorRole or "Text"],
        Font = Enum.Font.Gotham,
        TextSize = size or 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        AutoLocalize = false,
    }, properties or {})
    local label = create("TextLabel", settings, parent)
    self:_bind(label, "TextColor3", colorRole or "Text")
    return label
end

function Window:_icon(parent, source, size, role)
    if type(source) == "table" and source.Icon and Seraph.IconRuntime and type(Seraph.IconRuntime.Image) == "function" then
        local success, iconObject = pcall(Seraph.IconRuntime.Image, {
            Icon = source.Icon,
            Type = source.Type,
            Colors = source.Colors or {self.Theme[role or "Icon"]},
            Size = UDim2.fromOffset(size or 20, size or 20),
        })
        if success and type(iconObject) == "table" and iconObject.IconFrame then
            local iconFrame = iconObject.IconFrame
            iconFrame.Parent = parent
            iconFrame.Size = UDim2.fromOffset(size or 20, size or 20)
            iconFrame.BackgroundTransparency = 1
            return iconFrame
        end
    end
    local resolved = Seraph:ResolveIcon(source)
    local image = resolved
    local metadata
    if type(resolved) == "table" then
        image = resolved[1] or resolved.Image
        metadata = resolved[2] or resolved.Metadata
    end
    local icon = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = image or "",
        Size = UDim2.fromOffset(size or 20, size or 20),
        ScaleType = Enum.ScaleType.Fit,
        ImageColor3 = self.Theme[role or "Icon"],
    }, parent)
    if metadata then
        if metadata.ImageRectSize then
            icon.ImageRectSize = metadata.ImageRectSize
        end
        if metadata.ImageRectPosition then
            icon.ImageRectOffset = metadata.ImageRectPosition
        elseif metadata.ImageRectOffset then
            icon.ImageRectOffset = metadata.ImageRectOffset
        end
    end
    self:_bind(icon, "ImageColor3", role or "Icon")
    return icon
end

function Window:_color(role)
    return self.Theme[role] or self.Theme.Text
end

function Window:_newElement(kind, row, value, callback)
    local element = {
        Window = self,
        Kind = kind,
        Instance = row,
        Value = value,
        Callback = callback,
        Flag = nil,
        _connections = {},
    }

    function element:Get()
        return self.Value
    end

    function element:Set(nextValue, silent)
        if self._setValue then
            self._setValue(nextValue, silent)
        else
            self.Value = nextValue
            if not silent then
                safeCall(self.Callback, nextValue)
            end
        end
        return self
    end

    function element:Destroy()
        if self._destroyed then
            return
        end
        self._destroyed = true
        disconnectAll(self._connections)
        self.Window:_unregisterElement(self)
        if self.Instance then
            pcall(function()
                self.Instance:Destroy()
            end)
        end
    end

    function element:_setFlag(flag)
        if flag and trim(flag) ~= "" then
            self.Flag = tostring(flag)
            self.Window._flags[self.Flag] = self
        end
    end

    return element
end

function Window:_unregisterElement(element)
    if not element then
        return
    end
    if element.Flag and self._flags[element.Flag] == element then
        self._flags[element.Flag] = nil
    end
    for _, list in ipairs({self._elements, self._searchEntries}) do
        for index = #list, 1, -1 do
            if list[index] == element then
                table.remove(list, index)
            end
        end
    end
    if element.Section and element.Section.Elements then
        for index = #element.Section.Elements, 1, -1 do
            if element.Section.Elements[index] == element then
                table.remove(element.Section.Elements, index)
            end
        end
    end
    if self._searchQuery ~= nil then
        self:_applySearch(self._searchQuery)
    end
end

function Window:_registerElement(element, options)
    if options and options.Flag then
        element:_setFlag(options.Flag)
    end
    local tagText = options and options.Tag
    if type(tagText) == "table" then
        tagText = tagText.Text or tagText.Title or ""
    end
    element.SearchText = string.lower(table.concat({
        tostring(options and options.Title or ""),
        tostring(options and (options.Desc or options.Description) or ""),
        tostring(tagText or ""),
    }, " "))
    element.Section = options and options.Section or element.Section
    if element.Instance then
        element.Instance.MouseEnter:Connect(function()
            if element.Section then
                element.Section.Window:_setActiveSection(element.Section)
            end
        end)
    end
    self._elements[#self._elements + 1] = element
    self._searchEntries[#self._searchEntries + 1] = element
    if element.Section and element.Section.Refresh then
        task.defer(function()
            if element.Section and element.Section.Instance and element.Section.Instance.Parent then
                element.Section:Refresh()
            end
        end)
    end
    if self._searchQuery ~= nil then
        self:_applySearch(self._searchQuery)
    end
    return element
end

function Window:_setActiveSection(section)
    if not section or not section.Tab then
        return
    end
    section.Tab._activeSection = section
    self:_updateBreadcrumb(section.Tab, section)
end

function Window:_updateBreadcrumb(tab, section)
    if not self.Breadcrumb then
        return
    end
    tab = tab or self._activeTab
    section = section or (tab and tab._activeSection)
    local pieces = {self.Title}
    if section and section.Title and trim(section.Title) ~= "" then
        pieces[#pieces + 1] = section.Title
    end
    if tab and tab.Title then
        pieces[#pieces + 1] = tab.Title
    end
    self.Breadcrumb.Text = "https://seraph.local/" .. table.concat(pieces, "/")
end

function Window:_applySearch(query)
    query = string.lower(trim(query or ""))
    self._searchQuery = query
    local tabNameMatches = {}
    local matchedTabs = {}
    for _, tab in ipairs(self._tabs) do
        tabNameMatches[tab] = query == "" or string.find(string.lower(tab.Title or tab.Name or ""), query, 1, true) ~= nil
    end

    for _, element in ipairs(self._searchEntries) do
        local match = query == "" or tabNameMatches[element.Tab] or string.find(element.SearchText or "", query, 1, true) ~= nil
        if element.Instance and element.Instance.Parent then
            element.Instance.Visible = match
        end
        if match and element.Tab then
            matchedTabs[element.Tab] = true
        end
    end

    for _, section in ipairs(self._sections) do
        if section.Instance and section.Instance.Parent then
            local sectionMatch = query == "" or string.find(string.lower(section.Title or ""), query, 1, true) ~= nil
            local anyVisible = sectionMatch
            if sectionMatch and query ~= "" then
                for _, element in ipairs(section.Elements) do
                    if element.Instance and element.Instance.Parent then
                        element.Instance.Visible = true
                    end
                end
            else
                for _, element in ipairs(section.Elements) do
                    if element.Instance and element.Instance.Visible then
                        anyVisible = true
                        break
                    end
                end
            end
            if sectionMatch and section.Tab then
                matchedTabs[section.Tab] = true
            end
            section.Instance.Visible = anyVisible
        end
    end

    for _, tab in ipairs(self._tabs) do
        tab.Button.Visible = query == "" or tabNameMatches[tab] == true or matchedTabs[tab] == true
    end
end

function Window:_row(section, options, height)
    local row = create("Frame", {
        BackgroundColor3 = self:_color("ElementBackground"),
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or 56),
        AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
        LayoutOrder = options and options.LayoutOrder or 0,
    }, section.Content)
    addCorner(row, 10)
    self:_bind(row, "BackgroundColor3", "ElementBackground")
    row.MouseEnter:Connect(function()
        tween(row, {BackgroundColor3 = self:_color("Hover")}, 0.12)
    end)
    row.MouseLeave:Connect(function()
        tween(row, {BackgroundColor3 = self:_color("ElementBackground")}, 0.16)
    end)

    local content = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    }, row)
    addPadding(content, 12, 12, 9, 9)
    local rowLayout = addList(content, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    local hasIcon = options and options.Icon ~= nil
    if hasIcon then
        local iconHolder = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(24, 24),
            LayoutOrder = 1,
        }, content)
        local icon = self:_icon(iconHolder, options.Icon, options.IconSize or 20, "ElementIcon")
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromScale(0.5, 0.5)
    end

    local textHolder = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, hasIcon and -176 or -142, 1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
    }, content)
    local textLayout = addList(textHolder, Enum.FillDirection.Vertical, 2)
    textLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    local titleLine = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
    }, textHolder)
    local titleLabel = self:_textLabel(titleLine, options and options.Title or "Element", 14, "ElementTitle", {
        Size = UDim2.new(1, -10, 1, 0),
        Font = Enum.Font.GothamMedium,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    if options and options.Tag then
        local tagOptions = type(options.Tag) == "table" and options.Tag or {Text = options.Tag}
        local tagText = tagOptions.Text or tagOptions.Title or ""
        local tagWidth = clamp(#tostring(tagText) * 7 + 18, 44, 96)
        local side = string.lower(tostring(tagOptions.Side or "right"))
        if side == "left" then
            titleLabel.Position = UDim2.fromOffset(tagWidth + 8, 0)
            titleLabel.Size = UDim2.new(1, -tagWidth - 18, 1, 0)
        elseif side == "center" then
            titleLabel.Size = UDim2.new(1, -tagWidth - 18, 1, 0)
        else
            titleLabel.Size = UDim2.new(1, -tagWidth - 10, 1, 0)
        end
        local tagLabel = self:_textLabel(titleLine, tostring(tagText), 10, "Accent", {
            AnchorPoint = side == "left" and Vector2.new(0, 0.5) or Vector2.new(1, 0.5),
            Position = side == "left" and UDim2.fromOffset(0, 10) or (side == "center" and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(1, 0, 0.5, 0)),
            Size = UDim2.fromOffset(tagWidth, 18),
            TextXAlignment = Enum.TextXAlignment.Center,
            BackgroundColor3 = color(tagOptions.Color or tagOptions.BackgroundColor, self:_color("Accent")),
            BackgroundTransparency = tonumber(tagOptions.Transparency) or 0,
            TextColor3 = color(tagOptions.TextColor, self:_color("Text")),
        })
        addCorner(tagLabel, 5)
        if not tagOptions.Color and not tagOptions.BackgroundColor then
            self:_bind(tagLabel, "BackgroundColor3", "Accent")
        end
        if not tagOptions.TextColor then
            self:_bind(tagLabel, "TextColor3", "Text")
        end
    end

    local description = options and (options.Desc or options.Description)
    if description and tostring(description) ~= "" then
        self:_textLabel(textHolder, tostring(description), 11, "ElementDesc", {
            Size = UDim2.new(1, 0, 0, 18),
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end

    local control = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(108, height and height - 18 or 38),
        LayoutOrder = 2,
    }, content)

    return row, content, textHolder, titleLabel, control
end

function Window:_closePopups()
    disconnectAll(self._popupConnections)
    self._popupConnections = {}
    for _, popup in ipairs(self._popups) do
        if popup and popup.Parent then
            popup:Destroy()
        end
    end
    self._popups = {}
end

function Window:_popupFrame(width, height)
    self:_closePopups()
    local popup = create("Frame", {
        BackgroundColor3 = self:_color("PopupBackground"),
        BackgroundTransparency = self.Theme.PopupBackgroundTransparency or 0,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(width or 220, height or 200),
        ZIndex = 50,
    }, self.ScreenGui)
    addCorner(popup, 10)
    addStroke(popup, self:_color("Outline"), 0.65, 1)
    self:_bind(popup, "BackgroundColor3", "PopupBackground")
    self._popups[#self._popups + 1] = popup
    return popup
end

function Window:_positionPopup(popup, anchor)
    local function update()
        if not popup.Parent or not anchor.Parent then
            return
        end
        local position = anchor.AbsolutePosition
        local size = anchor.AbsoluteSize
        local screenSize = self.ScreenGui.AbsoluteSize
        local x = position.X
        local y = position.Y + size.Y + 5
        local bounds = self.Main.AbsolutePosition
        local boundsSize = self.Main.AbsoluteSize
        local minX = math.max(8, bounds.X + 8)
        local maxX = math.min(screenSize.X - popup.AbsoluteSize.X - 8, bounds.X + boundsSize.X - popup.AbsoluteSize.X - 8)
        if maxX < minX then
            maxX = minX
        end
        x = clamp(x, minX, maxX)
        if y + popup.AbsoluteSize.Y > screenSize.Y - 8 or y + popup.AbsoluteSize.Y > bounds.Y + boundsSize.Y - 8 then
            y = position.Y - popup.AbsoluteSize.Y - 5
        end
        local minY = math.max(8, bounds.Y + 8)
        local maxY = math.min(screenSize.Y - popup.AbsoluteSize.Y - 8, bounds.Y + boundsSize.Y - popup.AbsoluteSize.Y - 8)
        if maxY < minY then
            maxY = minY
        end
        popup.Position = UDim2.fromOffset(x, clamp(y, minY, maxY))
    end
    update()
    local connection = RunService.RenderStepped:Connect(update)
    table.insert(self._popupConnections, connection)
end

function Window:_makePopupButton(parent, text, layoutOrder)
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self:_color("TabBackground"),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 30),
        Text = text,
        TextColor3 = self:_color("PopupContent"),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = layoutOrder or 0,
        ZIndex = 52,
    }, parent)
    addCorner(button, 6)
    addPadding(button, 10, 8, 0, 0)
    self:_bind(button, "BackgroundColor3", "TabBackground")
    self:_bind(button, "TextColor3", "PopupContent")
    button.MouseEnter:Connect(function()
        tween(button, {BackgroundTransparency = 0}, 0.1)
    end)
    button.MouseLeave:Connect(function()
        tween(button, {BackgroundTransparency = 0.15}, 0.1)
    end)
    return button
end

function Window:RefreshTheme()
    for _, binding in ipairs(self._bindings) do
        if binding.Instance and binding.Instance.Parent then
            local value = self.Theme[binding.Role]
            if value ~= nil then
                pcall(function()
                    binding.Instance[binding.Property] = value
                end)
            end
        end
    end
    return self
end

function Window:SetTheme(theme)
    self.Theme = Seraph:GetTheme(theme)
    return self:RefreshTheme()
end

function Window:AddTheme(theme)
    local result = Seraph:AddTheme(theme)
    self:SetTheme(result)
    return result
end

function Window:_showTab(tab)
    for _, item in ipairs(self._tabs) do
        local active = item == tab
        item.Page.Visible = active
        if active then
            item.Button.BackgroundColor3 = self:_color("Accent")
            item.Button.TextColor3 = self:_color("Text")
            item.Icon.ImageColor3 = self:_color("Text")
        else
            item.Button.BackgroundColor3 = self:_color("TabBackground")
            item.Button.TextColor3 = self:_color("TabTitle")
            item.Icon.ImageColor3 = self:_color("TabIcon")
        end
    end
    self._activeTab = tab
    self:_updateBreadcrumb(tab, tab._activeSection)
end

function Window:_createTabButton(tab, options)
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self:_color("TabBackground"),
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        Size = self.TabMode == "Top" and UDim2.fromOffset(132, 38) or UDim2.new(1, 0, 0, 40),
        Text = "",
        LayoutOrder = #self._tabs + 1,
    }, self.TabList)
    addCorner(button, 8)
    local icon = self:_icon(button, options.Icon, 18, "TabIcon")
    icon.Position = UDim2.fromOffset(11, 10)
    local label = self:_textLabel(button, options.Title or options.Name or "Tab", 12, "TabTitle", {
        Position = UDim2.fromOffset(38, 0),
        Size = UDim2.new(1, -45, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    button.MouseEnter:Connect(function()
        if self._activeTab ~= tab then
            tween(button, {BackgroundTransparency = 0}, 0.12)
        end
    end)
    button.MouseLeave:Connect(function()
        if self._activeTab ~= tab then
            tween(button, {BackgroundTransparency = 0.12}, 0.12)
        end
    end)
    button.Activated:Connect(function()
        self:_showTab(tab)
    end)
    return button, icon, label
end

function Window:Tab(options)
    options = type(options) == "string" and {Title = options} or (options or {})
    local page = create("ScrollingFrame", {
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarImageColor3 = self:_color("Accent"),
        ScrollBarThickness = 4,
        Size = UDim2.new(1, -14, 1, -14),
        Position = UDim2.fromOffset(7, 7),
        Visible = false,
        ZIndex = 2,
    }, self.Pages)
    local pagePadding = addPadding(page, 2, 8, 2, 8)
    local pageList = addList(page, Enum.FillDirection.Vertical, 10)
    pageList.HorizontalAlignment = Enum.HorizontalAlignment.Left
    pageList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, pageList.AbsoluteContentSize.Y + 18)
    end)

    local tab = setmetatable({
        Window = self,
        Page = page,
        PageList = pageList,
        Sections = {},
        Name = options.Name or options.Title or ("Tab" .. tostring(#self._tabs + 1)),
        Title = options.Title or options.Name or ("Tab" .. tostring(#self._tabs + 1)),
        _activeSection = nil,
    }, Tab)
    tab.Button, tab.Icon, tab.Label = self:_createTabButton(tab, options)
    self._tabs[#self._tabs + 1] = tab
    if not self._activeTab then
        self:_showTab(tab)
    end
    return tab
end

Window.CreateTab = Window.Tab
Window.AddTab = Window.Tab

function Tab:TabSection(title)
    if self.Window.TabMode ~= "Left" then
        return nil
    end
    local label = self.Window:_textLabel(self.Window.TabList, string.upper(tostring(title or "")), 10, "ElementDesc", {
        Size = UDim2.new(1, 0, 0, 22),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = #self.Window._tabs + 1,
    })
    addPadding(label, 6, 0, 8, 0)
    return label
end

function Tab:Section(options)
    options = type(options) == "string" and {Title = options} or (options or {})
    local sectionFrame = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = options.LayoutOrder or (#self.Sections + 1),
    }, self.Page)
    local title = options.Title or options.Name
    local sectionHeader
    if title and trim(title) ~= "" then
        sectionHeader = self.Window:_textLabel(sectionFrame, title, 13, "Text", {
            Size = UDim2.new(1, 0, 0, 22),
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Active = true,
        })
    end

    local content = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, title and 28 or 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, sectionFrame)
    addList(content, Enum.FillDirection.Vertical, 8)
    local contentPadding = addPadding(content, 0, 0, title and 6 or 0, 0)

    local section = setmetatable({
        Window = self.Window,
        Tab = self,
        Instance = sectionFrame,
        Content = content,
        Elements = {},
        Title = title or "",
        Collapsed = false,
        Header = sectionHeader,
        Collapsible = options.Collapsible == true,
    }, Section)
    if sectionHeader then
        if section.Collapsible then
            sectionHeader.Text = "▾ " .. section.Title
        end
        sectionHeader.MouseEnter:Connect(function()
            self.Window:_setActiveSection(section)
        end)
        if section.Collapsible then
            sectionHeader.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    section:SetCollapsed(not section.Collapsed)
                end
            end)
        end
    end
    self.Sections[#self.Sections + 1] = section
    self.Window._sections[#self.Window._sections + 1] = section
    if not self._activeSection then
        self._activeSection = section
    end
    if self.Window._activeTab == self then
        self.Window:_updateBreadcrumb(self, self._activeSection)
    end
    if section.Collapsible and options.Collapsed then
        section:SetCollapsed(true)
    end
    return section
end

function Section:Focus()
    self.Window:_setActiveSection(self)
    return self
end

function Section:SetCollapsed(collapsed)
    if not self.Collapsible then
        return self
    end
    local nextCollapsed = collapsed == true
    if self.Collapsed == nextCollapsed then
        return self
    end
    local content = self.Content
    local expandedHeight = math.max(content.AbsoluteSize.Y, self._expandedHeight or 0)
    if expandedHeight <= 0 then
        expandedHeight = 1
    end
    self.Collapsed = nextCollapsed
    content.Visible = true
    content.AutomaticSize = Enum.AutomaticSize.None
    if nextCollapsed then
        self._expandedHeight = expandedHeight
        tween(content, {Size = UDim2.new(1, 0, 0, 0)}, 0.24, Enum.EasingStyle.Exponential)
    else
        local targetHeight = self._expandedHeight or expandedHeight
        content.Size = UDim2.new(1, 0, 0, 0)
        tween(content, {Size = UDim2.new(1, 0, 0, targetHeight)}, 0.28, Enum.EasingStyle.Exponential)
        task.delay(0.3, function()
            if content.Parent and not self.Collapsed then
                content.AutomaticSize = Enum.AutomaticSize.Y
            end
        end)
    end
    if self.Header then
        self.Header.Text = (self.Collapsed and "▸ " or "▾ ") .. self.Title
    end
    return self
end

function Section:Toggle()
    return self:SetCollapsed(not self.Collapsed)
end

function Section:Refresh()
    self.Content.AutomaticSize = Enum.AutomaticSize.Y
    self._expandedHeight = math.max(self.Content.AbsoluteSize.Y, self._expandedHeight or 0)
    if self.Collapsed then
        self.Content.AutomaticSize = Enum.AutomaticSize.None
        self.Content.Size = UDim2.new(1, 0, 0, 0)
    end
    return self
end

function Section:Clear()
    local elements = {}
    for index, element in ipairs(self.Elements) do
        elements[index] = element
    end
    for _, element in ipairs(elements) do
        if type(element) == "table" and element.Destroy then
            element:Destroy()
        elseif typeof(element) == "Instance" and element.Parent then
            element:Destroy()
        end
    end
    for _, child in ipairs(self.Content:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
    self.Elements = {}
    self.Window:_applySearch(self.Window._searchQuery or "")
    return self
end

function Section:Destroy()
    self:Clear()
    for index = #self.Tab.Sections, 1, -1 do
        if self.Tab.Sections[index] == self then
            table.remove(self.Tab.Sections, index)
        end
    end
    for index = #self.Window._sections, 1, -1 do
        if self.Window._sections[index] == self then
            table.remove(self.Window._sections, index)
        end
    end
    if self.Instance and self.Instance.Parent then
        self.Instance:Destroy()
    end
    return self
end

Tab.AddSection = Tab.Section

function Section:_finish(element, options)
    options = options or {}
    element.Section = self
    element.Tab = self.Tab
    options.Section = self
    self.Elements[#self.Elements + 1] = element
    return self.Window:_registerElement(element, options)
end

function Section:Toggle(options)
    options = options or {}
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)
    local track = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("Toggle"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(46, 24),
        Text = "",
    }, control)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(track, 12)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = self.Window:_color("ToggleBar"),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
    }, track)
    addCorner(knob, 9)
    self.Window:_bind(knob, "BackgroundColor3", "ToggleBar")

    local current = options.Default
    if current == nil then
        current = options.Value
    end
    current = current == true
    local element = self.Window:_newElement("Toggle", row, current, options.Callback)
    element.Control = track
    element._setValue = function(selfElement, value, silent)
        value = value == true
        selfElement.Value = value
        tween(knob, {Position = value and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)}, 0.16)
        tween(track, {BackgroundColor3 = selfElement.Window:_color(value and "Toggle" or "TabBackground")}, 0.16)
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end
    local toggleConnection = track.Activated:Connect(function()
        element:Set(not element.Value)
    end)
    element._connections[#element._connections + 1] = toggleConnection
    track.MouseEnter:Connect(function()
        tween(track, {Size = UDim2.fromOffset(50, 26)}, 0.12, Enum.EasingStyle.Quint)
    end)
    track.MouseLeave:Connect(function()
        tween(track, {Size = UDim2.fromOffset(46, 24)}, 0.12, Enum.EasingStyle.Quint)
    end)
    element:_setValue(current, true)
    return self:_finish(element, options)
end

function Section:Checkbox(options)
    options = mergeTables(options or {}, {Kind = "Checkbox"})
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)
    local box = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("Checkbox"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(24, 24),
        Text = "",
    }, control)
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(box, 6)
    self.Window:_bind(box, "BackgroundColor3", "Checkbox")
    local check = self.Window:_textLabel(box, "✓", 16, "CheckboxIcon", {
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Visible = false,
        Font = Enum.Font.GothamBold,
    })
    local current = options.Default == true or options.Value == true
    local element = self.Window:_newElement("Checkbox", row, current, options.Callback)
    element._setValue = function(selfElement, value, silent)
        value = value == true
        selfElement.Value = value
        check.Visible = value
        box.BackgroundTransparency = value and 0 or 0.55
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end
    box.Activated:Connect(function()
        element:Set(not element.Value)
    end)
    element:_setValue(current, true)
    return self:_finish(element, options)
end

function Section:Button(options)
    options = options or {}
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("Button"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(108, 34),
        Text = options.ButtonText or options.Text or "Run",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
    }, control)
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(button, 8)
    self.Window:_bind(button, "BackgroundColor3", "Button")
    self.Window:_bind(button, "TextColor3", "Text")
    button.MouseEnter:Connect(function()
        tween(button, {BackgroundColor3 = self.Window:_color("Accent")}, 0.12)
    end)
    button.MouseLeave:Connect(function()
        tween(button, {BackgroundColor3 = self.Window:_color("Button")}, 0.12)
    end)
    local element = self.Window:_newElement("Button", row, false, options.Callback)
    element.Activate = function()
        safeCall(element.Callback)
    end
    button.Activated:Connect(element.Activate)
    element.Control = button
    return self:_finish(element, options)
end

function Section:Slider(options)
    options = options or {}
    local minimum = tonumber(options.Min or options.Minimum) or 0
    local maximum = tonumber(options.Max or options.Maximum) or 100
    local increment = tonumber(options.Rounding or options.Step or options.Increment) or 1
    if increment <= 0 then
        increment = 1
    end
    local initial = tonumber(options.Default or options.Value)
    if initial == nil then
        initial = minimum
    end
    initial = clamp(initial, minimum, maximum)
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 86)
    control.Size = UDim2.fromOffset(176, 68)
    local valueLabel = self.Window:_textLabel(control, "", 11, "ElementDesc", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(82, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local bar = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 29),
        Size = UDim2.new(1, 0, 0, 10),
        Text = "",
    }, control)
    addCorner(bar, 5)
    self.Window:_bind(bar, "BackgroundColor3", "TabBackground")
    local fill = create("Frame", {
        BackgroundColor3 = self.Window:_color("Slider"),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
    }, bar)
    addCorner(fill, 3)
    self.Window:_bind(fill, "BackgroundColor3", "Slider")
    local thumb = create("TextButton", {
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self.Window:_color("SliderThumb"),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        Text = "",
    }, bar)
    addCorner(thumb, 11)
    addStroke(thumb, self.Window:_color("Slider"), 0.2, 1)
    self.Window:_bind(thumb, "BackgroundColor3", "SliderThumb")
    local minLabel = self.Window:_textLabel(control, tostring(minimum), 10, "ElementDesc", {
        Position = UDim2.fromOffset(0, 46),
        Size = UDim2.fromOffset(70, 18),
    })
    local maxLabel = self.Window:_textLabel(control, tostring(maximum), 10, "ElementDesc", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 46),
        Size = UDim2.fromOffset(70, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local element = self.Window:_newElement("Slider", row, initial, options.Callback)
    element.Control = bar
    local function setFromPercent(percent, silent)
        percent = clamp(percent, 0, 1)
        local rawValue = minimum + (maximum - minimum) * percent
        local nextValue = minimum + round((rawValue - minimum) / increment, 0) * increment
        nextValue = clamp(nextValue, minimum, maximum)
        local normalized = (nextValue - minimum) / math.max(0.0001, maximum - minimum)
        element.Value = nextValue
        fill.Size = UDim2.new(normalized, 0, 1, 0)
        thumb.Position = UDim2.new(normalized, 0, 0.5, 0)
        local formatted = tostring(nextValue)
        if type(options.Format) == "function" then
            local ok, result = pcall(options.Format, nextValue)
            if ok and result ~= nil then
                formatted = tostring(result)
            end
        elseif options.Suffix then
            formatted = formatted .. tostring(options.Suffix)
        end
        valueLabel.Text = formatted
        if not silent then
            safeCall(element.Callback, nextValue)
        end
    end
    element._setValue = function(selfElement, value, silent)
        value = tonumber(value) or minimum
        local percent = (clamp(value, minimum, maximum) - minimum) / math.max(0.0001, maximum - minimum)
        setFromPercent(percent, silent)
    end
    local dragging = false
    local function update(input)
        local x = input.Position.X - bar.AbsolutePosition.X
        setFromPercent(x / math.max(1, bar.AbsoluteSize.X))
    end
    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end
    bar.InputBegan:Connect(beginDrag)
    thumb.InputBegan:Connect(beginDrag)
    local sliderChangedConnection = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    local sliderEndedConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    element._connections[#element._connections + 1] = sliderChangedConnection
    element._connections[#element._connections + 1] = sliderEndedConnection
    thumb.MouseEnter:Connect(function()
        tween(thumb, {Size = UDim2.fromOffset(26, 26)}, 0.12, Enum.EasingStyle.Back)
    end)
    thumb.MouseLeave:Connect(function()
        tween(thumb, {Size = UDim2.fromOffset(22, 22)}, 0.12, Enum.EasingStyle.Quint)
    end)
    element:_setValue(initial, true)
    element.Min = minimum
    element.Max = maximum
    element.Increment = increment
    return self:_finish(element, options)
end

function Section:Input(options)
    options = options or {}
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)
    local box = create("TextBox", {
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ClearTextOnFocus = options.ClearTextOnFocus == true,
        PlaceholderText = options.Placeholder or "Type here",
        PlaceholderColor3 = self.Window:_color("Placeholder"),
        Text = tostring(options.Default or options.Value or ""),
        TextColor3 = self.Window:_color("Text"),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        Size = UDim2.fromOffset(145, 34),
    }, control)
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(box, 8)
    addPadding(box, 10, 8, 0, 0)
    self.Window:_bind(box, "BackgroundColor3", "TabBackground")
    self.Window:_bind(box, "PlaceholderColor3", "Placeholder")
    self.Window:_bind(box, "TextColor3", "Text")
    local element = self.Window:_newElement("Input", row, box.Text, options.Callback)
    element.Control = box
    element._setValue = function(selfElement, value, silent)
        value = tostring(value or "")
        selfElement.Value = value
        box.Text = value
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end
    box.FocusLost:Connect(function()
        element:Set(box.Text)
    end)
    return self:_finish(element, options)
end

function Section:Dropdown(options)
    options = options or {}
    local values = options.Values or options.Options or {}
    local function copyValues(source)
        local result = {}
        for index, value in ipairs(source or {}) do
            result[index] = value
        end
        return result
    end
    values = copyValues(values)
    local function displayValue(value)
        if type(value) == "table" then
            return tostring(value.Name or value.Title or value.Text or value.Value or "Select")
        end
        if typeof(value) == "Instance" then
            return value.Name
        end
        return tostring(value or "Select")
    end
    local initial = options.Default
    if initial == nil then
        initial = options.Value
    end
    if initial == nil then
        initial = values[1]
    end
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(145, 34),
        Text = displayValue(initial),
        TextColor3 = self.Window:_color("Text"),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, control)
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(button, 8)
    addPadding(button, 10, 24, 0, 0)
    self.Window:_bind(button, "BackgroundColor3", "TabBackground")
    self.Window:_bind(button, "TextColor3", "Text")
    local arrow = self.Window:_textLabel(button, "▾", 14, "Icon", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(14, 20),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local element = self.Window:_newElement("Dropdown", row, initial, options.Callback)
    element.Values = values
    element.Control = button
    element.DisplayValue = displayValue
    element._setValue = function(selfElement, value, silent)
        selfElement.Value = value
        button.Text = displayValue(value)
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end
    local function openDropdown()
        local rowHeight = 34
        local searchHeight = 0
        if options.Searchable == true or (#values > 8 and options.Searchable ~= false) then
            searchHeight = 38
        end
        local popupHeight = math.min(330, 18 + searchHeight + math.max(1, #values) * rowHeight + 10)
        local popup = self.Window:_popupFrame(248, popupHeight)
        self.Window:_positionPopup(popup, button)
        addPadding(popup, 8, 8, 8, 8)
        local searchBox
        if searchHeight > 0 then
            searchBox = create("TextBox", {
                BackgroundColor3 = self.Window:_color("ElementBackground"),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ClearTextOnFocus = false,
                PlaceholderText = "Search options",
                PlaceholderColor3 = self.Window:_color("Placeholder"),
                Text = "",
                TextColor3 = self.Window:_color("PopupContent"),
                TextSize = 11,
                Font = Enum.Font.Gotham,
                Position = UDim2.fromOffset(8, 8),
                Size = UDim2.new(1, -16, 0, 30),
                ZIndex = 53,
            }, popup)
            addCorner(searchBox, 7)
            addPadding(searchBox, 10, 8, 0, 0)
            self.Window:_bind(searchBox, "BackgroundColor3", "ElementBackground")
            self.Window:_bind(searchBox, "PlaceholderColor3", "Placeholder")
            self.Window:_bind(searchBox, "TextColor3", "PopupContent")
        end
        local list = create("ScrollingFrame", {
            Active = true,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Position = UDim2.fromOffset(8, 10 + searchHeight),
            ScrollBarImageColor3 = self.Window:_color("Accent"),
            ScrollBarThickness = 3,
            Size = UDim2.new(1, -16, 1, -18 - searchHeight),
            ZIndex = 52,
        }, popup)
        local listLayout = addList(list, Enum.FillDirection.Vertical, 5)
        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 6)
        end)
        local function render(filter)
            for _, child in ipairs(list:GetChildren()) do
                if child:IsA("GuiButton") then
                    child:Destroy()
                end
            end
            filter = string.lower(trim(filter or ""))
            local shown = 0
            for index, value in ipairs(values) do
                local text = displayValue(value)
                if filter == "" or string.find(string.lower(text), filter, 1, true) then
                    shown = shown + 1
                    local optionButton = self.Window:_makePopupButton(list, text, index)
                    optionButton.Size = UDim2.new(1, -6, 0, rowHeight)
                    local selectedMark = self.Window:_textLabel(optionButton, "", 12, "Accent", {
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, -8, 0.5, 0),
                        Size = UDim2.fromOffset(18, 18),
                        TextXAlignment = Enum.TextXAlignment.Center,
                        ZIndex = 54,
                    })
                    selectedMark.Text = element.Value == value and "✓" or ""
                    optionButton.Activated:Connect(function()
                        element:Set(value)
                        self.Window:_closePopups()
                    end)
                end
            end
            if shown == 0 then
                local empty = self.Window:_textLabel(list, "No options", 11, "PopupContent", {
                    Size = UDim2.new(1, -6, 0, rowHeight),
                    TextXAlignment = Enum.TextXAlignment.Center,
                })
                empty.LayoutOrder = 1
            end
        end
        if searchBox then
            searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                render(searchBox.Text)
            end)
        end
        render("")
        element._openPopup = popup
        return popup
    end
    element.Open = openDropdown
    element.UpdateDropdown = function(selfElement, nextValues, nextValue, silent)
        if type(nextValues) == "table" and (nextValues.Values or nextValues.Options) then
            nextValue = nextValues.Default or nextValues.Value or nextValue
            nextValues = nextValues.Values or nextValues.Options
        end
        values = copyValues(nextValues or {})
        selfElement.Values = values
        if nextValue == nil then
            nextValue = values[1]
        end
        selfElement:Set(nextValue, silent == true)
        if selfElement._openPopup then
            self.Window:_closePopups()
        end
        return selfElement
    end
    element.DropdownUpdate = element.UpdateDropdown
    element.Update = element.UpdateDropdown
    local dropdownConnection = button.Activated:Connect(function()
        openDropdown()
    end)
    element._connections[#element._connections + 1] = dropdownConnection
    button.MouseEnter:Connect(function()
        tween(button, {BackgroundColor3 = self.Window:_color("Hover")}, 0.12)
        tween(arrow, {Rotation = 8}, 0.12, Enum.EasingStyle.Quint)
    end)
    button.MouseLeave:Connect(function()
        tween(button, {BackgroundColor3 = self.Window:_color("TabBackground")}, 0.16)
        tween(arrow, {Rotation = 0}, 0.12, Enum.EasingStyle.Quint)
    end)
    element:_setValue(initial, true)
    return self:_finish(element, options)
end

function Section:DropDownPlayersAuto(options)
    options = options or {}
    local function toValue(player)
        if type(options.Format) == "function" then
            local ok, result = pcall(options.Format, player)
            if ok and result ~= nil then
                return result
            end
        end
        local valueType = string.lower(tostring(options.ValueType or "Name"))
        if valueType == "userid" or valueType == "user_id" then
            return player.UserId
        end
        if valueType == "player" or valueType == "instance" then
            return player
        end
        return player.Name
    end
    local function getValues()
        local result = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if options.IncludeLocalPlayer ~= false or player ~= LocalPlayer then
                result[#result + 1] = toValue(player)
            end
        end
        table.sort(result, function(left, right)
            return tostring(left) < tostring(right)
        end)
        return result
    end
    local dropdownOptions = mergeTables(options, {
        Values = getValues(),
        Searchable = options.Searchable ~= false,
    })
    local element = self:Dropdown(dropdownOptions)
    element.AutoPlayers = true
    element.RefreshPlayers = function(selfElement, silent)
        local nextValues = getValues()
        local current = selfElement.Value
        local nextValue = current
        local exists = false
        for _, value in ipairs(nextValues) do
            if value == current then
                exists = true
                break
            end
        end
        if not exists then
            nextValue = nextValues[1]
        end
        selfElement:UpdateDropdown(nextValues, nextValue, silent ~= false)
        return selfElement
    end
    element.GetPlayer = function(selfElement)
        local value = selfElement.Value
        if options.ValueType and string.lower(tostring(options.ValueType)) == "player" then
            return value
        end
        if value == nil then
            return nil
        end
        if options.ValueType and string.lower(tostring(options.ValueType)) == "userid" then
            return Players:GetPlayerByUserId(tonumber(value) or -1)
        end
        return Players:FindFirstChild(tostring(value))
    end
    element._connections[#element._connections + 1] = Players.PlayerAdded:Connect(function()
        element:RefreshPlayers(true)
    end)
    element._connections[#element._connections + 1] = Players.PlayerRemoving:Connect(function()
        element:RefreshPlayers(true)
    end)
    return element
end

Section.DropdownPlayersAuto = Section.DropDownPlayersAuto

function Section:MultiDropdown(options)
    options = options or {}
    local values = options.Values or options.Options or {}
    local normalizedValues = {}
    for index, value in ipairs(values) do
        normalizedValues[index] = value
    end
    values = normalizedValues
    local function displayValue(value)
        if type(value) == "table" then
            return tostring(value.Name or value.Title or value.Text or value.Value or "Select")
        end
        if typeof(value) == "Instance" then
            return value.Name
        end
        return tostring(value or "Select")
    end
    local initial = options.Default or options.Value or {}
    local selected = {}
    for _, value in ipairs(initial) do
        selected[value] = true
    end
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(145, 34),
        TextColor3 = self.Window:_color("Text"),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, control)
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(button, 8)
    addPadding(button, 10, 24, 0, 0)
    self.Window:_bind(button, "BackgroundColor3", "TabBackground")
    self.Window:_bind(button, "TextColor3", "Text")
    local element = self.Window:_newElement("MultiDropdown", row, {}, options.Callback)
    element.Values = values
    element.Control = button
    local function selectedArray()
        local result = {}
        for _, value in ipairs(values) do
            if selected[value] then
                result[#result + 1] = value
            end
        end
        return result
    end
    local function updateText()
        local current = selectedArray()
        if #current == 0 then
            button.Text = "Select"
        elseif #current == 1 then
            button.Text = displayValue(current[1])
        else
            button.Text = tostring(#current) .. " selected"
        end
        element.Value = current
    end
    element._setValue = function(selfElement, value, silent)
        selected = {}
        for _, item in ipairs(value or {}) do
            selected[item] = true
        end
        updateText()
        if not silent then
            safeCall(selfElement.Callback, selfElement.Value)
        end
    end
    button.Activated:Connect(function()
        local popup = self.Window:_popupFrame(240, math.min(320, 54 + math.max(1, #values) * 34))
        self.Window:_positionPopup(popup, button)
        addPadding(popup, 8, 8, 8, 8)
        local list = addList(popup, Enum.FillDirection.Vertical, 5)
        for index, value in ipairs(values) do
            local optionButton = self.Window:_makePopupButton(popup, "", index)
            local optionLabel = self.Window:_textLabel(optionButton, displayValue(value), 12, "PopupContent", {
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -42, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 54,
            })
            local checkLabel = self.Window:_textLabel(optionButton, "", 14, "Accent", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 54,
            })
            local function refresh()
                checkLabel.Text = selected[value] and "✓" or ""
            end
            refresh()
            optionButton.Activated:Connect(function()
                selected[value] = not selected[value]
                refresh()
                updateText()
                safeCall(element.Callback, element.Value)
            end)
        end
        local done = self.Window:_makePopupButton(popup, "Done", #values + 1)
        done.BackgroundColor3 = self.Window:_color("Button")
        done.Activated:Connect(function()
            self.Window:_closePopups()
        end)
    end)
    element.UpdateDropdown = function(selfElement, nextValues, nextValue, silent)
        if type(nextValues) == "table" and (nextValues.Values or nextValues.Options) then
            nextValue = nextValues.Default or nextValues.Value or nextValue
            nextValues = nextValues.Values or nextValues.Options
        end
        values = {}
        for index, value in ipairs(nextValues or {}) do
            values[index] = value
        end
        selfElement.Values = values
        selected = {}
        for _, value in ipairs(nextValue or {}) do
            selected[value] = true
        end
        updateText()
        if not silent then
            safeCall(selfElement.Callback, selfElement.Value)
        end
        return selfElement
    end
    element.DropdownUpdate = element.UpdateDropdown
    element.Update = element.UpdateDropdown
    element:_setValue(initial, true)
    return self:_finish(element, options)
end

function Section:Keybind(options)
    options = options or {}
    local initial = options.Default or options.Value or options.Key or "Unknown"
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(110, 34),
        Text = normalizeKey(initial),
        TextColor3 = self.Window:_color("Text"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
    }, control)
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(button, 8)
    self.Window:_bind(button, "BackgroundColor3", "TabBackground")
    self.Window:_bind(button, "TextColor3", "Text")
    local element = self.Window:_newElement("Keybind", row, normalizeKey(initial), options.Callback)
    element.Control = button
    element.Listening = false
    element._setValue = function(selfElement, value, silent)
        value = normalizeKey(value)
        selfElement.Value = value
        button.Text = value
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end
    button.Activated:Connect(function()
        element.Listening = true
        button.Text = "Press key"
    end)
    element._inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not element.Listening then
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            element.Listening = false
            element:Set(input.KeyCode.Name)
        end
    end)
    element._connections[#element._connections + 1] = element._inputConnection
    if options.OnPress then
        element._pressConnection = UserInputService.InputBegan:Connect(function(input, processed)
            if processed or element.Listening then
                return
            end
            if input.KeyCode.Name == normalizeKey(element.Value) then
                safeCall(options.OnPress, element.Value)
            end
        end)
        element._connections[#element._connections + 1] = element._pressConnection
    end
    return self:_finish(element, options)
end

function Section:Colorpicker(options)
    options = options or {}
    local initial = color(options.Default or options.Value, self.Window:_color("Accent"))
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)
    local swatch = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = initial,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(46, 28),
        Text = "",
    }, control)
    swatch.AnchorPoint = Vector2.new(1, 0.5)
    swatch.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(swatch, 8)
    local element = self.Window:_newElement("Colorpicker", row, initial, options.Callback)
    element.Control = swatch
    element._setValue = function(selfElement, value, silent)
        value = color(value, initial)
        selfElement.Value = value
        swatch.BackgroundColor3 = value
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end
    swatch.Activated:Connect(function()
        local hue, saturation, value = Color3.toHSV(element.Value)
        local popup = self.Window:_popupFrame(286, 280)
        self.Window:_positionPopup(popup, swatch)
        local title = self.Window:_textLabel(popup, "Color", 12, "PopupTitle", {
            Position = UDim2.fromOffset(14, 10),
            Size = UDim2.new(1, -28, 0, 18),
            Font = Enum.Font.GothamMedium,
            ZIndex = 53,
        })
        local map = create("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(14, 34),
            Size = UDim2.fromOffset(194, 142),
            Text = "",
            ZIndex = 52,
        }, popup)
        addCorner(map, 8)
        local whiteOverlay = create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 53,
        }, map)
        create("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }, whiteOverlay)
        local blackOverlay = create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 54,
        }, map)
        create("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0),
            }),
        }, blackOverlay)
        local mapPoint = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Position = UDim2.new(saturation, 0, 1 - value, 0),
            Size = UDim2.fromOffset(12, 12),
            ZIndex = 55,
        }, map)
        addCorner(mapPoint, 6)
        addStroke(mapPoint, Color3.new(0, 0, 0), 0.15, 2)

        local hueBar = create("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(218, 34),
            Size = UDim2.fromOffset(18, 142),
            Text = "",
            ZIndex = 52,
        }, popup)
        addCorner(hueBar, 9)
        create("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.34, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.51, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.68, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.85, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
            }),
        }, hueBar)
        local huePoint = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Position = UDim2.new(0.5, 0, hue, 0),
            Size = UDim2.fromOffset(26, 4),
            ZIndex = 55,
        }, hueBar)
        addCorner(huePoint, 2)
        local preview = create("Frame", {
            BackgroundColor3 = element.Value,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(250, 34),
            Size = UDim2.fromOffset(22, 142),
            ZIndex = 52,
        }, popup)
        addCorner(preview, 8)

        local hexValue = self.Window:_textLabel(popup, "", 11, "PopupContent", {
            Position = UDim2.fromOffset(14, 188),
            Size = UDim2.fromOffset(92, 18),
            ZIndex = 53,
        })
        local function toHex(colorValue)
            return string.format("#%02X%02X%02X", math.floor(colorValue.R * 255 + 0.5), math.floor(colorValue.G * 255 + 0.5), math.floor(colorValue.B * 255 + 0.5))
        end
        local function syncColor(silent)
            local nextColor = Color3.fromHSV(hue, saturation, value)
            element:Set(nextColor, silent)
            map.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
            mapPoint.Position = UDim2.new(saturation, 0, 1 - value, 0)
            huePoint.Position = UDim2.new(0.5, 0, hue, 0)
            preview.BackgroundColor3 = nextColor
            hexValue.Text = toHex(nextColor)
        end
        local function updateMap(input)
            saturation = clamp((input.Position.X - map.AbsolutePosition.X) / math.max(1, map.AbsoluteSize.X), 0, 1)
            value = clamp(1 - (input.Position.Y - map.AbsolutePosition.Y) / math.max(1, map.AbsoluteSize.Y), 0, 1)
            syncColor(false)
        end
        local function updateHue(input)
            hue = clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / math.max(1, hueBar.AbsoluteSize.Y), 0, 1)
            syncColor(false)
        end
        local mapDragging = false
        local hueDragging = false
        map.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                mapDragging = true
                updateMap(input)
            end
        end)
        hueBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                hueDragging = true
                updateHue(input)
            end
        end)
        local pickerChanged = UserInputService.InputChanged:Connect(function(input)
            if mapDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateMap(input)
            elseif hueDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateHue(input)
            end
        end)
        local pickerEnded = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                mapDragging = false
                hueDragging = false
            end
        end)
        self.Window._popupConnections[#self.Window._popupConnections + 1] = pickerChanged
        self.Window._popupConnections[#self.Window._popupConnections + 1] = pickerEnded
        syncColor(true)
        local hexInput = create("TextBox", {
            BackgroundColor3 = self.Window:_color("ElementBackground"),
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            PlaceholderText = "#RRGGBB",
            Text = toHex(element.Value),
            TextColor3 = self.Window:_color("PopupContent"),
            TextSize = 11,
            Font = Enum.Font.Gotham,
            Position = UDim2.fromOffset(112, 182),
            Size = UDim2.fromOffset(124, 28),
            ZIndex = 53,
        }, popup)
        addCorner(hexInput, 7)
        addPadding(hexInput, 8, 8, 0, 0)
        self.Window:_bind(hexInput, "BackgroundColor3", "ElementBackground")
        self.Window:_bind(hexInput, "TextColor3", "PopupContent")
        hexInput.FocusLost:Connect(function()
            local hex = hexInput.Text:gsub("#", "")
            if #hex == 6 and tonumber(hex, 16) then
                local number = tonumber(hex, 16)
                element:Set(Color3.fromRGB(bit32.rshift(number, 16) % 256, bit32.rshift(number, 8) % 256, number % 256))
                hue, saturation, value = Color3.toHSV(element.Value)
                syncColor(true)
            else
                hexInput.Text = toHex(element.Value)
            end
        end)
    end)
    swatch.MouseEnter:Connect(function()
        tween(swatch, {Size = UDim2.fromOffset(50, 30)}, 0.12, Enum.EasingStyle.Quint)
    end)
    swatch.MouseLeave:Connect(function()
        tween(swatch, {Size = UDim2.fromOffset(46, 28)}, 0.12, Enum.EasingStyle.Quint)
    end)
    element:_setValue(initial, true)
    return self:_finish(element, options)
end

Section.ColorPicker = Section.Colorpicker

function Section:_color(role)
    return self.Window:_color(role)
end

function Section:Divider(options)
    options = options or {}
    local divider = create("Frame", {
        BackgroundColor3 = self.Window:_color("Outline"),
        BackgroundTransparency = options.Transparency or 0.55,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, options.Thickness or 1),
        LayoutOrder = options.LayoutOrder or (#self.Elements + 1),
    }, self.Content)
    self.Window:_bind(divider, "BackgroundColor3", "Outline")
    self.Elements[#self.Elements + 1] = divider
    return divider
end

function Section:Space(options)
    options = type(options) == "number" and {Size = options} or (options or {})
    local spacer = create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, options.Size or 10),
        LayoutOrder = options.LayoutOrder or (#self.Elements + 1),
    }, self.Content)
    self.Elements[#self.Elements + 1] = spacer
    return spacer
end

function Section:Paragraph(options)
    options = type(options) == "string" and {Content = options} or (options or {})
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, {
        Title = options.Title or "",
        Desc = options.Content or options.Text or options.Desc,
        Tag = options.Tag,
    }, options.Height or 62)
    control:Destroy()
    textHolder.Size = UDim2.new(1, -24, 1, 0)
    local element = self.Window:_newElement("Paragraph", row, options.Content or options.Text or "", options.Callback)
    return self:_finish(element, options)
end

function Section:Label(options)
    options = type(options) == "string" and {Content = options} or (options or {})
    return self:Paragraph(options)
end

function Section:Status(options)
    options = type(options) == "string" and {Title = options} or (options or {})
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 52)
    local statusColor = color(options.Color, self.Window:_color(options.State == "Error" and "Danger" or (options.State == "Success" and "Success" or "Accent")))
    local dot = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = statusColor,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(11, 11),
    }, control)
    addCorner(dot, 6)
    local statusText = self.Window:_textLabel(control, options.Status or options.State or "Ready", 11, "ElementDesc", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        Size = UDim2.fromOffset(82, 20),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local element = self.Window:_newElement("Status", row, options.Status or options.State or "Ready", options.Callback)
    element.Control = statusText
    element._setValue = function(selfElement, value, silent)
        local nextText = type(value) == "table" and (value.Text or value.Status or value.State) or tostring(value or "Ready")
        selfElement.Value = nextText
        statusText.Text = nextText
        if type(value) == "table" and value.Color then
            dot.BackgroundColor3 = color(value.Color, statusColor)
        end
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end
    element:Set(options.Status or options.State or "Ready", true)
    return self:_finish(element, options)
end

function Section:Progress(options)
    options = options or {}
    local minimum = tonumber(options.Min or options.Minimum) or 0
    local maximum = tonumber(options.Max or options.Maximum) or 100
    local initial = clamp(tonumber(options.Default or options.Value) or minimum, minimum, maximum)
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 72)
    control.Size = UDim2.fromOffset(145, 46)
    local valueLabel = self.Window:_textLabel(control, "", 11, "ElementDesc", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(54, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local track = create("Frame", {
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 29),
        Size = UDim2.new(1, 0, 0, 7),
    }, control)
    addCorner(track, 4)
    self.Window:_bind(track, "BackgroundColor3", "TabBackground")
    local fill = create("Frame", {
        BackgroundColor3 = self.Window:_color("Accent"),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
    }, track)
    addCorner(fill, 4)
    self.Window:_bind(fill, "BackgroundColor3", "Accent")
    local element = self.Window:_newElement("Progress", row, initial, options.Callback)
    element.Min = minimum
    element.Max = maximum
    element.Control = track
    element._setValue = function(selfElement, value, silent)
        local nextValue = clamp(tonumber(value) or minimum, minimum, maximum)
        selfElement.Value = nextValue
        local percent = (nextValue - minimum) / math.max(0.0001, maximum - minimum)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        valueLabel.Text = tostring(round(nextValue, 1))
        if not silent then
            safeCall(selfElement.Callback, nextValue)
        end
    end
    element:Set(initial, true)
    return self:_finish(element, options)
end

function Section:Code(options)
    options = type(options) == "string" and {Code = options} or (options or {})
    local row = create("Frame", {
        BackgroundColor3 = self.Window:_color("ElementBackground"),
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, options.Height or 145),
        LayoutOrder = options.LayoutOrder or (#self.Elements + 1),
    }, self.Content)
    addCorner(row, 10)
    addStroke(row, self.Window:_color("Outline"), 0.82, 1)
    self.Window:_bind(row, "BackgroundColor3", "ElementBackground")
    local header = self.Window:_textLabel(row, options.Title or "Code", 12, "ElementTitle", {
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -86, 0, 22),
        Font = Enum.Font.GothamMedium,
    })
    local copy = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("Button"),
        BorderSizePixel = 0,
        Position = UDim2.new(1, -68, 0, 7),
        Size = UDim2.fromOffset(56, 24),
        Text = "Copy",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 10,
        Font = Enum.Font.GothamMedium,
    }, row)
    addCorner(copy, 6)
    self.Window:_bind(copy, "BackgroundColor3", "Button")
    self.Window:_bind(copy, "TextColor3", "Text")
    local editor = create("TextBox", {
        BackgroundColor3 = self.Window:_color("Background"),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        MultiLine = true,
        Text = options.Code or options.Text or "",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 12,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = false,
        TextEditable = options.Editable == true,
        Position = UDim2.fromOffset(10, 38),
        Size = UDim2.new(1, -20, 1, -48),
    }, row)
    addCorner(editor, 7)
    addPadding(editor, 9, 9, 8, 8)
    self.Window:_bind(editor, "BackgroundColor3", "Background")
    self.Window:_bind(editor, "TextColor3", "Text")
    local element = self.Window:_newElement("Code", row, editor.Text, options.Callback)
    element.Control = editor
    element._setValue = function(selfElement, value, silent)
        selfElement.Value = tostring(value or "")
        editor.Text = selfElement.Value
        if not silent then
            safeCall(selfElement.Callback, selfElement.Value)
        end
    end
    copy.Activated:Connect(function()
        if type(setclipboard) == "function" then
            pcall(setclipboard, editor.Text)
            self.Window:Notify({Title = "Code copied", Content = "The code was copied to the clipboard.", Duration = 2})
        else
            self.Window:Notify({Title = "Clipboard unavailable", Content = "Your environment does not expose setclipboard.", Duration = 3})
        end
    end)
    if options.Editable then
        editor.FocusLost:Connect(function()
            element:Set(editor.Text)
        end)
    end
    return self:_finish(element, options)
end

function Section:Music(options)
    options = options or {}
    local playlist = options.Playlist or options.Tracks or options.MusicIds or {}
    if type(playlist) ~= "table" then
        playlist = {playlist}
    end
    local normalizedPlaylist = {}
    for _, track in ipairs(playlist) do
        if type(track) == "table" then
            normalizedPlaylist[#normalizedPlaylist + 1] = {
                Id = assetId(track.Id or track.AssetId or track.SoundId),
                Name = track.Name or track.Title or tostring(track.Id or track.AssetId or track.SoundId),
            }
        else
            normalizedPlaylist[#normalizedPlaylist + 1] = {
                Id = assetId(track),
                Name = tostring(track),
            }
        end
    end
    if #normalizedPlaylist == 0 then
        normalizedPlaylist[1] = {Id = "", Name = "No tracks"}
    end

    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, options.Height or 300)
    control:Destroy()
    textHolder.Size = UDim2.new(1, -24, 1, 0)
    local playerArea = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 44),
        Size = UDim2.new(1, -24, 0, 92),
    }, row)
    local trackLabel = self.Window:_textLabel(playerArea, "", 11, "ElementDesc", {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -100, 0, 20),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local back = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 26),
        Size = UDim2.fromOffset(28, 28),
        Text = "‹",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 18,
        Font = Enum.Font.GothamMedium,
    }, playerArea)
    local play = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("Button"),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(34, 26),
        Size = UDim2.fromOffset(62, 28),
        Text = "Play",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
    }, playerArea)
    local nextButton = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(102, 26),
        Size = UDim2.fromOffset(28, 28),
        Text = "›",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 18,
        Font = Enum.Font.GothamMedium,
    }, playerArea)
    local autoNext = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(140, 26),
        Size = UDim2.fromOffset(92, 28),
        Text = "Auto next",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 10,
        Font = Enum.Font.GothamMedium,
    }, playerArea)
    for _, button in ipairs({back, play, nextButton}) do
        addCorner(button, 7)
        self.Window:_bind(button, "TextColor3", "Text")
    end
    self.Window:_bind(back, "BackgroundColor3", "TabBackground")
    self.Window:_bind(play, "BackgroundColor3", "Button")
    self.Window:_bind(nextButton, "BackgroundColor3", "TabBackground")
    addCorner(autoNext, 7)
    self.Window:_bind(autoNext, "BackgroundColor3", "TabBackground")
    self.Window:_bind(autoNext, "TextColor3", "Text")
    local volumeBar = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Position = UDim2.new(1, -155, 0, 57),
        Size = UDim2.fromOffset(145, 6),
        Text = "",
    }, playerArea)
    addCorner(volumeBar, 3)
    self.Window:_bind(volumeBar, "BackgroundColor3", "TabBackground")
    local volumeFill = create("Frame", {
        BackgroundColor3 = self.Window:_color("Slider"),
        BorderSizePixel = 0,
        Size = UDim2.new(0.7, 0, 1, 0),
    }, volumeBar)
    addCorner(volumeFill, 3)
    self.Window:_bind(volumeFill, "BackgroundColor3", "Slider")
    local volumeLabel = self.Window:_textLabel(playerArea, "70%", 10, "ElementDesc", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 43),
        Size = UDim2.fromOffset(45, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local musicLabel = self.Window:_textLabel(playerArea, "Music", 10, "ElementDesc", {
        Position = UDim2.new(1, -155, 0, 43),
        Size = UDim2.fromOffset(50, 18),
    })
    local gameBar = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Position = UDim2.new(1, -155, 0, 83),
        Size = UDim2.fromOffset(145, 6),
        Text = "",
    }, playerArea)
    addCorner(gameBar, 3)
    self.Window:_bind(gameBar, "BackgroundColor3", "TabBackground")
    local gameFill = create("Frame", {
        BackgroundColor3 = self.Window:_color("Accent"),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }, gameBar)
    addCorner(gameFill, 3)
    self.Window:_bind(gameFill, "BackgroundColor3", "Accent")
    local gameLabel = self.Window:_textLabel(playerArea, "Game 100%", 10, "ElementDesc", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 69),
        Size = UDim2.fromOffset(70, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local gameTitle = self.Window:_textLabel(playerArea, "Game", 10, "ElementDesc", {
        Position = UDim2.new(1, -155, 0, 69),
        Size = UDim2.fromOffset(50, 18),
    })

    local playlistTitle = self.Window:_textLabel(row, "Playlist", 11, "ElementDesc", {
        Position = UDim2.fromOffset(12, 141),
        Size = UDim2.new(1, -24, 0, 18),
        Font = Enum.Font.GothamMedium,
    })
    local playlistFrame = create("ScrollingFrame", {
        Active = true,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Position = UDim2.fromOffset(12, 163),
        ScrollBarImageColor3 = self.Window:_color("Accent"),
        ScrollBarThickness = 3,
        Size = UDim2.new(1, -24, 1, -175),
        ZIndex = 4,
    }, row)
    addCorner(playlistFrame, 8)
    self.Window:_bind(playlistFrame, "BackgroundColor3", "TabBackground")
    local playlistLayout = addList(playlistFrame, Enum.FillDirection.Vertical, 4)
    addPadding(playlistFrame, 6, 6, 6, 6)

    local musicSound = Instance.new("Sound")
    musicSound.Name = "SeraphMusic"
    musicSound.Volume = 0.7
    musicSound.Looped = false
    musicSound.Parent = SoundService
    local element = self.Window:_newElement("Music", row, 1, options.Callback)
    element.Control = musicSound
    element.Playlist = normalizedPlaylist
    element.CurrentIndex = 1
    element.Volume = 0.7
    element.Playing = false
    element.AutoPlayNext = options.AutoPlayNext ~= false
    element.AllowReorder = options.AllowReorder == true
    element._gameVolume = 1
    element._gameSoundVolumes = {}
    element.PlaylistFrame = playlistFrame

    local renderPlaylist
    local function updateTrackLabel()
        local track = normalizedPlaylist[element.CurrentIndex]
        trackLabel.Text = (track and track.Name or "No tracks") .. "  " .. tostring(element.CurrentIndex) .. "/" .. tostring(#normalizedPlaylist)
        if renderPlaylist then
            renderPlaylist()
        end
    end
    local function setGameVolume(value)
        element._gameVolume = clamp(value, 0, 1)
        for sound, original in pairs(element._gameSoundVolumes) do
            if sound and sound.Parent then
                sound.Volume = original * element._gameVolume
            else
                element._gameSoundVolumes[sound] = nil
            end
        end
        gameFill.Size = UDim2.new(element._gameVolume, 0, 1, 0)
        gameLabel.Text = "Game " .. tostring(math.floor(element._gameVolume * 100 + 0.5)) .. "%"
    end
    local function snapshotGameSounds()
        for _, descendant in ipairs(game:GetDescendants()) do
            if descendant:IsA("Sound") and descendant ~= musicSound and element._gameSoundVolumes[descendant] == nil then
                element._gameSoundVolumes[descendant] = descendant.Volume
                descendant.Volume = descendant.Volume * element._gameVolume
            end
        end
    end
    local function setTrack(index, autoplay)
        if #normalizedPlaylist == 0 then
            return
        end
        element.CurrentIndex = ((index - 1) % #normalizedPlaylist) + 1
        local track = normalizedPlaylist[element.CurrentIndex]
        musicSound:Stop()
        musicSound.SoundId = track.Id
        musicSound.Volume = element.Volume
        updateTrackLabel()
        if autoplay and track.Id ~= "" then
            snapshotGameSounds()
            musicSound:Play()
            element.Playing = true
            play.Text = "Pause"
            safeCall(element.Callback, track)
        else
            element.Playing = false
            play.Text = "Play"
        end
    end

    renderPlaylist = function()
        for _, child in ipairs(playlistFrame:GetChildren()) do
            if child:IsA("GuiButton") or child.Name == "EmptyPlaylist" then
                child:Destroy()
            end
        end
        for index, track in ipairs(normalizedPlaylist) do
            local trackButton = create("TextButton", {
                AutoButtonColor = false,
                BackgroundColor3 = index == element.CurrentIndex and self.Window:_color("Accent") or self.Window:_color("ElementBackground"),
                BackgroundTransparency = index == element.CurrentIndex and 0 or 0.08,
                BorderSizePixel = 0,
                Size = UDim2.new(1, -6, 0, 34),
                Text = "",
                LayoutOrder = index,
                ZIndex = 5,
            }, playlistFrame)
            addCorner(trackButton, 7)
            local iconSource = options.TrackIcon or (Seraph.IconRuntime and "lucide:music-2")
            if iconSource then
                local trackIcon = self.Window:_icon(trackButton, iconSource, 16, "Icon")
                trackIcon.Position = UDim2.fromOffset(9, 9)
            else
                self.Window:_textLabel(trackButton, "♪", 16, "Icon", {
                    Position = UDim2.fromOffset(9, 5),
                    Size = UDim2.fromOffset(16, 24),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 6,
                })
            end
            local nameLabel = self.Window:_textLabel(trackButton, tostring(track.Name), 11, "Text", {
                Position = UDim2.fromOffset(34, 0),
                Size = UDim2.new(1, -80, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 6,
            })
            local numberLabel = self.Window:_textLabel(trackButton, string.format("%02d", index), 10, "ElementDesc", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(28, 18),
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 6,
            })
            if index == element.CurrentIndex then
                nameLabel.TextColor3 = self.Window:_color("Text")
                numberLabel.TextColor3 = self.Window:_color("Text")
            end
            trackButton.MouseEnter:Connect(function()
                tween(trackButton, {BackgroundTransparency = index == element.CurrentIndex and 0 or 0}, 0.12)
            end)
            trackButton.MouseLeave:Connect(function()
                tween(trackButton, {BackgroundTransparency = index == element.CurrentIndex and 0 or 0.08}, 0.16)
            end)
            trackButton.Activated:Connect(function()
                setTrack(index, true)
            end)
        end
        if #normalizedPlaylist == 0 then
            local empty = self.Window:_textLabel(playlistFrame, "Playlist is empty", 11, "ElementDesc", {
                Name = "EmptyPlaylist",
                Size = UDim2.new(1, -6, 0, 34),
                TextXAlignment = Enum.TextXAlignment.Center,
                LayoutOrder = 1,
            })
            empty.Name = "EmptyPlaylist"
        end
    end

    autoNext.Activated:Connect(function()
        element.AutoPlayNext = not element.AutoPlayNext
        autoNext.Text = element.AutoPlayNext and "Auto next: ON" or "Auto next: OFF"
        tween(autoNext, {BackgroundColor3 = element.AutoPlayNext and self.Window:_color("Accent") or self.Window:_color("TabBackground")}, 0.14)
    end)
    element.SetAutoPlayNext = function(_, enabled)
        element.AutoPlayNext = enabled == true
        autoNext.Text = element.AutoPlayNext and "Auto next: ON" or "Auto next: OFF"
        return element
    end
    element.Play = function()
        local track = normalizedPlaylist[element.CurrentIndex]
        if track and track.Id ~= "" then
            snapshotGameSounds()
            musicSound:Play()
            element.Playing = true
            play.Text = "Pause"
        end
    end
    element.Pause = function()
        musicSound:Pause()
        element.Playing = false
        play.Text = "Play"
    end
    element.Stop = function()
        musicSound:Stop()
        element.Playing = false
        play.Text = "Play"
    end
    element.Next = function()
        setTrack(element.CurrentIndex + 1, true)
    end
    element.Previous = function()
        setTrack(element.CurrentIndex - 1, true)
    end
    element.SetVolume = function(_, value)
        element.Volume = clamp(tonumber(value) or 0.7, 0, 1)
        musicSound.Volume = element.Volume
        volumeFill.Size = UDim2.new(element.Volume, 0, 1, 0)
        volumeLabel.Text = tostring(math.floor(element.Volume * 100 + 0.5)) .. "%"
    end
    element.MoveTrack = function(_, fromIndex, toIndex)
        fromIndex = tonumber(fromIndex) or 1
        toIndex = tonumber(toIndex) or 1
        if not element.AllowReorder or not normalizedPlaylist[fromIndex] or not normalizedPlaylist[toIndex] then
            return false
        end
        local item = table.remove(normalizedPlaylist, fromIndex)
        table.insert(normalizedPlaylist, toIndex, item)
        element.CurrentIndex = clamp(element.CurrentIndex, 1, #normalizedPlaylist)
        updateTrackLabel()
        renderPlaylist()
        return true
    end
    element.AddTrack = function(_, track)
        if type(track) == "table" then
            normalizedPlaylist[#normalizedPlaylist + 1] = {
                Id = assetId(track.Id or track.AssetId or track.SoundId),
                Name = track.Name or track.Title or tostring(track.Id or track.AssetId or track.SoundId),
            }
        else
            normalizedPlaylist[#normalizedPlaylist + 1] = {Id = assetId(track), Name = tostring(track)}
        end
        element.Playlist = normalizedPlaylist
        updateTrackLabel()
        return element
    end
    element.RemoveTrack = function(_, index)
        index = tonumber(index)
        if not index or not normalizedPlaylist[index] then
            return false
        end
        table.remove(normalizedPlaylist, index)
        if #normalizedPlaylist > 0 then
            element.CurrentIndex = clamp(element.CurrentIndex, 1, #normalizedPlaylist)
        else
            element.CurrentIndex = 1
        end
        updateTrackLabel()
        return true
    end
    element.Destroy = function(selfElement)
        if selfElement._destroyed then
            return
        end
        selfElement._destroyed = true
        selfElement:Stop()
        for sound, original in pairs(selfElement._gameSoundVolumes) do
            if sound and sound.Parent then
                sound.Volume = original
            end
        end
        selfElement._gameSoundVolumes = {}
        musicSound:Destroy()
        disconnectAll(selfElement._connections)
        selfElement.Window:_unregisterElement(selfElement)
        if selfElement.Instance then
            selfElement.Instance:Destroy()
        end
    end
    musicSound.Ended:Connect(function()
        if element.AutoPlayNext then
            element:Next()
        else
            element.Playing = false
            play.Text = "Play"
        end
    end)
    play.Activated:Connect(function()
        if element.Playing then
            element:Pause()
        else
            element:Play()
        end
    end)
    back.Activated:Connect(element.Previous)
    nextButton.Activated:Connect(element.Next)
    local dragging = false
    local gameDragging = false
    local function volumeFromInput(input)
        local percent = clamp((input.Position.X - volumeBar.AbsolutePosition.X) / math.max(1, volumeBar.AbsoluteSize.X), 0, 1)
        element:SetVolume(percent)
    end
    volumeBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            volumeFromInput(input)
        end
    end)
    gameBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            gameDragging = true
            local percent = clamp((input.Position.X - gameBar.AbsolutePosition.X) / math.max(1, gameBar.AbsoluteSize.X), 0, 1)
            setGameVolume(percent)
        end
    end)
    local volumeChangedConnection = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            volumeFromInput(input)
        end
        if gameDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local percent = clamp((input.Position.X - gameBar.AbsolutePosition.X) / math.max(1, gameBar.AbsoluteSize.X), 0, 1)
            setGameVolume(percent)
        end
    end)
    local volumeEndedConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            gameDragging = false
        end
    end)
    element._connections[#element._connections + 1] = volumeChangedConnection
    element._connections[#element._connections + 1] = volumeEndedConnection
    element:SetVolume(element.Volume)
    setGameVolume(element._gameVolume)
    setTrack(1, options.AutoPlay == true)
    autoNext.Text = element.AutoPlayNext and "Auto next: ON" or "Auto next: OFF"
    renderPlaylist()
    return self:_finish(element, options)
end

Section.MusicPlayer = Section.Music

function Section:Tag(options)
    options = type(options) == "string" and {Text = options} or (options or {})
    return self:Paragraph({
        Title = options.Title or "Tag",
        Content = options.Text or options.Content or "",
        Tag = options,
        Height = options.Height or 54,
    })
end

local function serializeValue(value)
    local valueType = typeof(value)
    if valueType == "Color3" then
        return {
            __seraphType = "Color3",
            R = value.R,
            G = value.G,
            B = value.B,
        }
    end
    if valueType == "EnumItem" then
        return {
            __seraphType = "EnumItem",
            EnumType = tostring(value.EnumType),
            Name = value.Name,
        }
    end
    if type(value) == "table" then
        local result = {}
        for key, item in pairs(value) do
            if type(key) == "string" or type(key) == "number" then
                result[key] = serializeValue(item)
            end
        end
        return result
    end
    if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
        return value
    end
    return nil
end

local function deserializeValue(value)
    if type(value) ~= "table" then
        return value
    end
    if value.__seraphType == "Color3" then
        return Color3.new(tonumber(value.R) or 1, tonumber(value.G) or 1, tonumber(value.B) or 1)
    end
    if value.__seraphType == "EnumItem" and value.EnumType == "Enum.KeyCode" then
        return enumKeyCode(value.Name)
    end
    local result = {}
    for key, item in pairs(value) do
        result[key] = deserializeValue(item)
    end
    return result
end

local function executorFunction(name)
    local environments = {}
    pcall(function()
        if type(getgenv) == "function" then
            environments[#environments + 1] = getgenv()
        end
    end)
    pcall(function()
        if type(getfenv) == "function" then
            environments[#environments + 1] = getfenv(0)
        end
    end)
    environments[#environments + 1] = _G
    for _, environment in ipairs(environments) do
        local value = rawget(environment, name)
        if type(value) == "function" then
            return value
        end
    end
    return nil
end

local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager:_path(name)
    return self.BaseFolder .. "/" .. sanitizeName(name, "config") .. ".json"
end

function ConfigManager:_ensureFolders()
    local makeFolder = executorFunction("makefolder")
    if not makeFolder then
        return false
    end

    local parts = {}
    for part in tostring(self.BaseFolder):gmatch("[^/]+") do
        parts[#parts + 1] = part
    end
    local current = ""
    for _, part in ipairs(parts) do
        current = current == "" and part or current .. "/" .. part
        pcall(makeFolder, current)
    end
    return true
end

function ConfigManager:_collect(config)
    local values = {}
    for flag, element in pairs(self.Window._flags) do
        if element and element.Get then
            local value = element:Get()
            if element.Kind ~= "Button" and element.Kind ~= "Music" then
                values[flag] = serializeValue(value)
            end
        end
    end
    for name, element in pairs(config.Entries) do
        if element and element.Get then
            values[name] = serializeValue(element:Get())
        end
    end
    return values
end

function ConfigManager:_apply(values, config)
    for name, value in pairs(values or {}) do
        local element = self.Window._flags[name] or config.Entries[name]
        if element and element.Set then
            safeCall(function()
                element:Set(deserializeValue(value), true)
            end)
        end
    end
end

function ConfigManager:CreateConfig(name)
    local config = {
        Manager = self,
        Name = sanitizeName(name, "config"),
        Entries = {},
    }
    setmetatable(config, {
        __index = {
            Register = function(configObject, entryName, element)
                assert(type(entryName) == "string", "Config:Register expects a string name")
                assert(type(element) == "table" and element.Get and element.Set, "Config:Register expects a Seraph element")
                configObject.Entries[entryName] = element
                return configObject
            end,
            Unregister = function(configObject, entryName)
                configObject.Entries[entryName] = nil
                return configObject
            end,
            Save = function(configObject)
                return configObject.Manager:_save(configObject)
            end,
            Load = function(configObject)
                return configObject.Manager:_load(configObject)
            end,
            Delete = function(configObject)
                return configObject.Manager:_delete(configObject)
            end,
            Exists = function(configObject)
                local isFile = executorFunction("isfile")
                if not isFile then
                    return false
                end
                local success, exists = pcall(isFile, configObject.Manager:_path(configObject.Name))
                return success and exists == true
            end,
            GetPath = function(configObject)
                return configObject.Manager:_path(configObject.Name)
            end,
        },
    })
    self.Configs[config.Name] = config
    self.Current = config
    self:_ensureFolders()
    return config
end

function ConfigManager:_save(config)
    local writeFile = executorFunction("writefile")
    if not writeFile then
        self.Window:Notify({
            Title = "Config unavailable",
            Content = "This environment does not expose writefile.",
            Type = "Warning",
        })
        return false, "writefile is unavailable"
    end

    self:_ensureFolders()
    local values = self:_collect(config)
    local payload = encodeJson({
        Version = 1,
        Library = "Seraph",
        SavedAt = os.time(),
        Values = values,
    })
    if self.Protection.Enabled then
        payload = ArxProtect:Seal(payload, self.Protection.Key)
    end
    local success, errorMessage = pcall(writeFile, self:_path(config.Name), payload)
    if not success then
        self.Window:Notify({Title = "Config save failed", Content = tostring(errorMessage), Type = "Error"})
        return false, errorMessage
    end
    return true
end

function ConfigManager:_load(config)
    local readFile = executorFunction("readfile")
    local isFile = executorFunction("isfile")
    if not readFile or not isFile then
        self.Window:Notify({
            Title = "Config unavailable",
            Content = "This environment does not expose readfile/isfile.",
            Type = "Warning",
        })
        return false, "readfile or isfile is unavailable"
    end

    local path = self:_path(config.Name)
    local existsSuccess, exists = pcall(isFile, path)
    if not existsSuccess or not exists then
        return false, "config does not exist"
    end
    local readSuccess, payload = pcall(readFile, path)
    if not readSuccess then
        return false, payload
    end
    if tostring(payload):match("^SRP1%.") then
        payload = ArxProtect:Unseal(payload, self.Protection.Key)
    end
    local decoded = decodeJson(payload)
    if not decoded or type(decoded) ~= "table" then
        return false, "invalid config data"
    end
    self:_apply(decoded.Values or decoded, config)
    return true
end

function ConfigManager:_delete(config)
    local deleteFile = executorFunction("delfile")
    if not deleteFile then
        return false, "delfile is unavailable"
    end
    local success, errorMessage = pcall(deleteFile, self:_path(config.Name))
    return success, errorMessage
end

function ConfigManager:List()
    local listFiles = executorFunction("listfiles")
    if not listFiles then
        local names = {}
        for name in pairs(self.Configs) do
            names[#names + 1] = name
        end
        table.sort(names)
        return names
    end
    local success, files = pcall(listFiles, self.BaseFolder)
    if not success or type(files) ~= "table" then
        return {}
    end
    local result = {}
    for _, path in ipairs(files) do
        local name = tostring(path):match("([^/\\]+)%.json$")
        if name then
            result[#result + 1] = name
        end
    end
    table.sort(result)
    return result
end

function ConfigManager:SetProtection(options)
    options = options or {}
    self.Protection.Enabled = options.Enabled == true
    self.Protection.Key = tostring(options.Key or self.Protection.Key or "Seraph")
    self.Protection.AutoSeal = options.AutoSeal == true
    self.Protection.Interval = math.max(1, tonumber(options.Interval) or 30)
    if not self.Protection.AutoSeal then
        self._autoSealRunning = false
    elseif not self._autoSealRunning then
        self._autoSealRunning = true
        task.spawn(function()
            while self._autoSealRunning and self.Window._alive do
                task.wait(self.Protection.Interval)
                if self.Protection.AutoSeal and self.Current then
                    self:_save(self.Current)
                end
            end
        end)
    end
    return self
end

function ConfigManager:Destroy()
    self._autoSealRunning = false
end

function Window:SetTag(text, options)
    options = type(options) == "string" and {Side = options} or (options or {})
    self._tag.Text = tostring(text or "")
    self._tag.Visible = trim(text) ~= ""
    local side = string.lower(options.Side or "right")
    if side == "left" then
        self._tag.AnchorPoint = Vector2.new(0, 0.5)
        self._tag.Position = UDim2.new(0.46, 0, 0.5, 0)
    elseif side == "center" then
        self._tag.AnchorPoint = Vector2.new(0.5, 0.5)
        self._tag.Position = UDim2.new(0.58, 0, 0.5, 0)
    else
        self._tag.AnchorPoint = Vector2.new(0.5, 0.5)
        self._tag.Position = UDim2.new(0.76, 0, 0.5, 0)
    end
    return self._tag
end

Window.AddTag = Window.SetTag

function Window:SetLogo(textureId)
    local source = textureId or Seraph.LogoTexture
    local oldLogo = self.Logo
    local position = oldLogo and oldLogo.Position or UDim2.fromOffset(72, 16)
    local anchorPoint = oldLogo and oldLogo.AnchorPoint or Vector2.new(0, 0)
    if oldLogo and oldLogo.Parent then
        oldLogo:Destroy()
    end

    local logo = self:_icon(self.Header, source, 26, "WindowTopbarIcon")
    logo.Position = position
    logo.AnchorPoint = anchorPoint
    self.Logo = logo
    self.LogoSource = source
    return logo
end

Window.SetLogoTexture = Window.SetLogo

function Window:Notify(options)
    options = type(options) == "string" and {Content = options} or (options or {})
    local duration = tonumber(options.Duration) or 4
    local toastHeight = options.Height or 74
    local toast = create("Frame", {
        BackgroundColor3 = self:_color("PopupBackground"),
        BackgroundTransparency = self.Theme.PopupBackgroundTransparency or 0,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(300, toastHeight),
        Position = UDim2.new(1, 320, 1, -90),
        AnchorPoint = Vector2.new(1, 1),
        ZIndex = 70,
    }, self.NotificationHolder)
    addCorner(toast, 10)
    addStroke(toast, self:_color("Outline"), 0.6, 1)
    self:_bind(toast, "BackgroundColor3", "PopupBackground")
    local bar = create("Frame", {
        BackgroundColor3 = options.Type == "Error" and self:_color("Danger") or (options.Type == "Success" and self:_color("Success") or self:_color("Accent")),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(4, toastHeight),
        ZIndex = 71,
    }, toast)
    local function removeToast()
        for index, item in ipairs(self._notifications) do
            if item == toast then
                table.remove(self._notifications, index)
                break
            end
        end
        for index, item in ipairs(self._notifications) do
            if item and item.Parent then
                local target = UDim2.new(1, -14, 1, -14 - ((index - 1) * (toastHeight + 8)))
                tween(item, {Position = target}, 0.16)
            end
        end
    end
    table.insert(self._notifications, 1, toast)
    addCorner(bar, 2)
    local title = self:_textLabel(toast, options.Title or "Seraph", 13, "PopupTitle", {
        Position = UDim2.fromOffset(16, 9),
        Size = UDim2.new(1, -28, 0, 20),
        Font = Enum.Font.GothamMedium,
        ZIndex = 71,
    })
    local content = self:_textLabel(toast, options.Content or options.Message or "", 11, "PopupContent", {
        Position = UDim2.fromOffset(16, 31),
        Size = UDim2.new(1, -28, 0, 34),
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 71,
    })
    local close = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -26, 0, 8),
        Size = UDim2.fromOffset(18, 18),
        Text = "×",
        TextColor3 = self:_color("PopupContent"),
        TextSize = 14,
        Font = Enum.Font.Gotham,
        ZIndex = 72,
    }, toast)
    close.Activated:Connect(function()
        if toast.Parent then
            tween(toast, {Position = UDim2.new(1, 320, 1, -90)}, 0.18)
            task.delay(0.2, function()
                if toast.Parent then
                    toast:Destroy()
                end
                removeToast()
            end)
        end
    end)
    tween(toast, {Position = UDim2.new(1, -14, 1, -14)}, 0.25)
    for index = 2, #self._notifications do
        local item = self._notifications[index]
        if item and item.Parent then
            tween(item, {Position = UDim2.new(1, -14, 1, -14 - ((index - 1) * (toastHeight + 8)))}, 0.2)
        end
    end
    task.delay(duration, function()
        if toast.Parent then
            tween(toast, {Position = UDim2.new(1, 320, 1, -90)}, 0.22)
            task.delay(0.25, function()
                if toast.Parent then
                    toast:Destroy()
                end
                removeToast()
            end)
        end
    end)
    return toast
end

function Window:Popup(options)
    options = options or {}
    local overlay = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self:_color("WindowShadow"),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        ZIndex = 80,
    }, self.ScreenGui)
    local dialog = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self:_color("DialogBackground"),
        BackgroundTransparency = self.Theme.DialogBackgroundTransparency or 0,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(options.Width or 360, options.Height or 210),
        ZIndex = 81,
    }, overlay)
    addCorner(dialog, 14)
    addStroke(dialog, self:_color("Outline"), 0.55, 1)
    self:_bind(dialog, "BackgroundColor3", "DialogBackground")
    local icon = self:_icon(dialog, options.Icon, 24, "DialogIcon")
    icon.Position = UDim2.fromOffset(18, 18)
    local title = self:_textLabel(dialog, options.Title or "Seraph", 16, "DialogTitle", {
        Position = UDim2.fromOffset(52, 16),
        Size = UDim2.new(1, -72, 0, 26),
        Font = Enum.Font.GothamMedium,
        ZIndex = 82,
    })
    local body = self:_textLabel(dialog, options.Content or options.Message or "", 12, "DialogContent", {
        Position = UDim2.fromOffset(20, 57),
        Size = UDim2.new(1, -40, 0, 74),
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 82,
    })
    local buttons = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 20, 1, -56),
        Size = UDim2.new(1, -40, 0, 36),
        ZIndex = 82,
    }, dialog)
    local buttonList = addList(buttons, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
    buttonList.VerticalAlignment = Enum.VerticalAlignment.Center
    local closeDialog = function()
        if overlay.Parent then
            overlay:Destroy()
        end
    end
    local actionList = options.Buttons or {
        {Text = "Close", Callback = options.Callback},
    }
    for index, action in ipairs(actionList) do
        local actionButton = create("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = action.Primary and self:_color("Button") or self:_color("TabBackground"),
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(action.Width or 92, 34),
            Text = action.Text or action.Title or (index == 1 and "Close" or "Action"),
            TextColor3 = self:_color("Text"),
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            ZIndex = 83,
        }, buttons)
        addCorner(actionButton, 8)
        actionButton.Activated:Connect(function()
            safeCall(action.Callback, closeDialog)
            if action.Close ~= false then
                closeDialog()
            end
        end)
    end
    if options.CloseOnOverlay ~= false then
        overlay.Activated:Connect(closeDialog)
    end
    return {
        Instance = overlay,
        Close = closeDialog,
    }
end

Window.ShowPopup = Window.Popup

function Window:Minimize()
    self._minimized = not self._minimized
    self.Body.Visible = not self._minimized
    self.Toolbar.Visible = not self._minimized
    self.ResizeHandle.Visible = not self._minimized
    self.Main.Size = self._minimized and UDim2.new(0, self._size.X.Offset, 0, 58) or self._size
    self.Shadow.Size = self._minimized and UDim2.fromOffset(self._size.X.Offset + 24, 82) or UDim2.fromOffset(self._size.X.Offset + 24, self._size.Y.Offset + 24)
    self.MinimizeButton.Text = self._minimized and "+" or "—"
    return self._minimized
end

function Window:Toggle()
    self.ScreenGui.Enabled = not self.ScreenGui.Enabled
    return self.ScreenGui.Enabled
end

function Window:SetVisible(visible)
    self.ScreenGui.Enabled = visible == true
    return self
end

function Window:Search(query)
    query = tostring(query or "")
    if self.SearchBox then
        self.SearchBox.Text = query
    else
        self:_applySearch(query)
    end
    return self
end

function Window:SetSearchEnabled(enabled)
    self.SearchEnabled = enabled == true
    if self.SearchSurface then
        self.SearchSurface.Visible = self.SearchEnabled
    end
    return self
end

function Window:Refresh()
    for _, section in ipairs(self._sections) do
        if section and section.Refresh then
            section:Refresh()
        end
    end
    self:_applySearch(self.SearchBox and self.SearchBox.Text or self._searchQuery or "")
    return self
end

Window.RefreshElements = Window.Refresh

function Window:ConfigureProtection(options)
    self.ConfigManager:SetProtection(options)
    return self
end

function Window:CreateConfig(name)
    return self.ConfigManager:CreateConfig(name)
end

function Window:Destroy()
    if not self._alive then
        return
    end
    self._alive = false
    self.ConfigManager:Destroy()
    self:_closePopups()
    disconnectAll(self._connections)
    local elements = {}
    for index, element in ipairs(self._elements) do
        elements[index] = element
    end
    for _, element in ipairs(elements) do
        if element and element.Destroy then
            pcall(function()
                element:Destroy()
            end)
        end
    end
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
    for index, window in ipairs(Seraph.Windows) do
        if window == self then
            table.remove(Seraph.Windows, index)
            break
        end
    end
end

function Window:BindKey(key, callback)
    local keyCode = enumKeyCode(key)
    local connection = UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == keyCode then
            safeCall(callback, self)
        end
    end)
    self._connections[#self._connections + 1] = connection
    return connection
end

function Tab:_defaultSection()
    if not self._defaultSectionObject then
        self._defaultSectionObject = self:Section({LayoutOrder = 1})
    end
    return self._defaultSectionObject
end

for _, methodName in ipairs({
    "Toggle",
    "Checkbox",
    "Button",
    "Slider",
    "Input",
    "Dropdown",
    "DropDownPlayersAuto",
    "DropdownPlayersAuto",
    "MultiDropdown",
    "Keybind",
    "Colorpicker",
    "ColorPicker",
    "Divider",
    "Space",
    "Paragraph",
    "Label",
    "Status",
    "Progress",
    "Code",
    "Music",
    "MusicPlayer",
    "Tag",
}) do
    Tab[methodName] = function(self, options)
        local section = self:_defaultSection()
        return section[methodName](section, options)
    end
end

local function normalizeWindowSize(value)
    if typeof(value) == "UDim2" then
        return value
    end
    if type(value) == "table" then
        return UDim2.fromOffset(tonumber(value.X or value.Width) or 720, tonumber(value.Y or value.Height) or 520)
    end
    return UDim2.fromOffset(720, 520)
end

local function normalizeTabMode(value)
    value = string.lower(tostring(value or "Left"))
    if value == "top" or value == "horizontal" or value == "topbar" then
        return "Top"
    end
    return "Left"
end

function Seraph:CreateWindow(options)
    options = options or {}
    local size = normalizeWindowSize(options.Size)
    local window = setmetatable({
        Name = options.Name or options.Title or "Seraph",
        Title = options.Title or "Seraph",
        Author = options.Author or "Material UI 3",
        Folder = sanitizeName(options.Folder or options.Name or options.Title or "Seraph", "Seraph"),
        RootFolder = sanitizeName(options.RootFolder or "Workspace", "Workspace"),
        TabMode = normalizeTabMode(options.TabMode or options.TabStyle or "Left"),
        Theme = Seraph:GetTheme(options.Theme),
        _size = size,
        _minSize = normalizeWindowSize(options.MinSize or {X = 640, Y = 420}),
        _alive = true,
        _connections = {},
        _bindings = {},
        _tabs = {},
        _sections = {},
        _elements = {},
        _searchEntries = {},
        _flags = {},
        _popups = {},
        _popupConnections = {},
        _notifications = {},
        _minimized = false,
        SearchEnabled = options.SearchEnabled ~= false,
    }, Window)
    table.insert(Seraph.Windows, window)

    if options.Icons then
        Seraph:SetIconProvider(options.Icons)
    end
    if options.LoadIcons then
        Seraph:LoadIcons({Type = options.IconType or "lucide"})
    end
    if options.IconType and Seraph.IconRuntime and Seraph.IconRuntime.SetIconsType then
        pcall(Seraph.IconRuntime.SetIconsType, options.IconType)
    end

    local screenGui = create("ScreenGui", {
        Name = "SeraphUI_" .. tostring(math.random(100000, 999999)),
        DisplayOrder = options.DisplayOrder or 25,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, getGuiParent())
    window.ScreenGui = screenGui

    local shadow = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = window:_color("WindowShadow"),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size.X.Offset + 24, size.Y.Offset + 24),
        ZIndex = 0,
    }, screenGui)
    addCorner(shadow, 20)
    window:_bind(shadow, "BackgroundColor3", "WindowShadow")
    window.Shadow = shadow

    local main = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = window:_color("WindowBackground"),
        BackgroundTransparency = window.Theme.BackgroundTransparency or 0,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = size,
        ClipsDescendants = false,
        ZIndex = 1,
    }, screenGui)
    addCorner(main, 16)
    create("UISizeConstraint", {
        MinSize = Vector2.new(window._minSize.X.Offset, window._minSize.Y.Offset),
        MaxSize = Vector2.new(1280, 900),
    }, main)
    window:_bind(main, "BackgroundColor3", "WindowBackground")
    window.Main = main

    local header = create("Frame", {
        BackgroundColor3 = window:_color("Background"),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 58),
        ZIndex = 3,
    }, main)
    window:_bind(header, "BackgroundColor3", "Background")
    window.Header = header

    local trafficColors = {
        {Color = "Danger", X = 16},
        {Color = "Warning", X = 32},
        {Color = "Success", X = 48},
    }
    for _, dot in ipairs(trafficColors) do
        local traffic = create("Frame", {
            BackgroundColor3 = window:_color(dot.Color),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(dot.X, 23),
            Size = UDim2.fromOffset(8, 8),
            ZIndex = 4,
        }, header)
        addCorner(traffic, 4)
        window:_bind(traffic, "BackgroundColor3", dot.Color)
    end

    local logoSource = options.LogoTextureId or options.LogoTexture or options.Icon or Seraph.LogoTexture
    local logo = window:_icon(header, logoSource, 26, "WindowTopbarIcon")
    logo.Position = UDim2.fromOffset(72, 16)
    window.Logo = logo
    window.LogoSource = logoSource
    local title = window:_textLabel(header, window.Title, 15, "WindowTopbarTitle", {
        Position = UDim2.fromOffset(108, 9),
        Size = UDim2.new(0.48, -108, 0, 22),
        Font = Enum.Font.GothamMedium,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })
    local author = window:_textLabel(header, window.Author, 10, "WindowTopbarAuthor", {
        Position = UDim2.fromOffset(109, 32),
        Size = UDim2.new(0.48, -109, 0, 16),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })
    local tag = window:_textLabel(header, "", 10, "Accent", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.55, 0, 0.5, 0),
        Size = UDim2.fromOffset(86, 22),
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundColor3 = window:_color("Accent"),
        BackgroundTransparency = 0.04,
        TextColor3 = window:_color("Text"),
        Visible = false,
        ZIndex = 4,
    })
    addCorner(tag, 7)
    window:_bind(tag, "BackgroundColor3", "Accent")
    window:_bind(tag, "TextColor3", "Text")
    window._tag = tag

    local minimizeButton = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -72, 0, 17),
        Size = UDim2.fromOffset(24, 24),
        Text = "—",
        TextColor3 = window:_color("WindowTopbarButtonIcon"),
        TextSize = 16,
        Font = Enum.Font.GothamMedium,
        ZIndex = 4,
    }, header)
    local closeButton = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -40, 0, 17),
        Size = UDim2.fromOffset(24, 24),
        Text = "×",
        TextColor3 = window:_color("WindowTopbarButtonIcon"),
        TextSize = 16,
        Font = Enum.Font.GothamMedium,
        ZIndex = 4,
    }, header)
    window:_bind(minimizeButton, "TextColor3", "WindowTopbarButtonIcon")
    window:_bind(closeButton, "TextColor3", "WindowTopbarButtonIcon")
    minimizeButton.Activated:Connect(function()
        window:Minimize()
    end)
    closeButton.Activated:Connect(function()
        window:Destroy()
    end)
    window.MinimizeButton = minimizeButton

    local toolbar = create("Frame", {
        BackgroundColor3 = window:_color("Background"),
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 58),
        Size = UDim2.new(1, 0, 0, 44),
        ZIndex = 3,
    }, main)
    window:_bind(toolbar, "BackgroundColor3", "Background")
    window.Toolbar = toolbar

    local searchSurface = create("Frame", {
        BackgroundColor3 = window:_color("ElementBackground"),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(14, 7),
        Size = UDim2.fromOffset(334, 30),
        ZIndex = 4,
    }, toolbar)
    addCorner(searchSurface, 8)
    addStroke(searchSurface, window:_color("Outline"), 0.65, 1)
    window:_bind(searchSurface, "BackgroundColor3", "ElementBackground")
    local searchIcon
    if options.SearchIcon or Seraph.IconRuntime then
        searchIcon = window:_icon(searchSurface, options.SearchIcon or "search", 16, "Icon")
        searchIcon.Position = UDim2.fromOffset(9, 7)
    else
        searchIcon = window:_textLabel(searchSurface, "⌕", 17, "Icon", {
            Position = UDim2.fromOffset(9, 3),
            Size = UDim2.fromOffset(16, 24),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end
    local protocol = window:_textLabel(searchSurface, "https://", 11, "Accent", {
        Position = UDim2.fromOffset(31, 0),
        Size = UDim2.fromOffset(44, 30),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
    })
    local searchBox = create("TextBox", {
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        PlaceholderText = options.SearchPlaceholder or "Search or enter a route",
        PlaceholderColor3 = window:_color("Placeholder"),
        Text = "",
        TextColor3 = window:_color("Text"),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        Position = UDim2.fromOffset(77, 0),
        Size = UDim2.new(1, -107, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
    }, searchSurface)
    window:_bind(searchBox, "PlaceholderColor3", "Placeholder")
    window:_bind(searchBox, "TextColor3", "Text")
    searchSurface.Visible = window.SearchEnabled
    window.SearchSurface = searchSurface
    window.SearchBox = searchBox
    local searchClear = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -30, 0, 3),
        Size = UDim2.fromOffset(24, 24),
        Text = "×",
        TextColor3 = window:_color("Placeholder"),
        TextSize = 15,
        Font = Enum.Font.Gotham,
        ZIndex = 6,
    }, searchSurface)
    searchClear.Activated:Connect(function()
        searchBox.Text = ""
        searchBox:CaptureFocus()
    end)
    searchClear.MouseEnter:Connect(function()
        tween(searchClear, {TextColor3 = window:_color("Text")}, 0.1)
    end)
    searchClear.MouseLeave:Connect(function()
        tween(searchClear, {TextColor3 = window:_color("Placeholder")}, 0.1)
    end)
    window:_bind(searchClear, "TextColor3", "Placeholder")
    window.SearchClear = searchClear

    local breadcrumb = window:_textLabel(toolbar, "https://seraph.local/" .. window.Title, 11, "ElementDesc", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromOffset(362, 22),
        Size = UDim2.new(1, -390, 0, 24),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })
    window.Breadcrumb = breadcrumb
    window._connections[#window._connections + 1] = searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        window:_applySearch(searchBox.Text)
    end)

    local body = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 102),
        Size = UDim2.new(1, 0, 1, -102),
        ZIndex = 2,
    }, main)
    window.Body = body

    local tabList
    local pages
    if window.TabMode == "Left" then
        tabList = create("ScrollingFrame", {
            Active = true,
            BackgroundColor3 = window:_color("ElementBackground"),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Position = UDim2.fromOffset(12, 10),
            ScrollBarImageColor3 = window:_color("Accent"),
            ScrollBarThickness = 3,
            Size = UDim2.new(0, 176, 1, -22),
            ZIndex = 3,
        }, body)
        addCorner(tabList, 12)
        addStroke(tabList, window:_color("Outline"), 0.72, 1)
        addPadding(tabList, 8, 8, 10, 10)
        window:_bind(tabList, "BackgroundColor3", "ElementBackground")
        local tabLayout = addList(tabList, Enum.FillDirection.Vertical, 6)
        tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabList.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 22)
        end)
        pages = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(200, 10),
            Size = UDim2.new(1, -212, 1, -22),
            ZIndex = 2,
        }, body)
    else
        tabList = create("ScrollingFrame", {
            Active = true,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Position = UDim2.fromOffset(12, 8),
            ScrollBarThickness = 0,
            ScrollingDirection = Enum.ScrollingDirection.X,
            Size = UDim2.new(1, -24, 0, 42),
            ZIndex = 3,
        }, body)
        local tabLayout = addList(tabList, Enum.FillDirection.Horizontal, 8)
        tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabList.CanvasSize = UDim2.fromOffset(tabLayout.AbsoluteContentSize.X + 18, 0)
        end)
        pages = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 58),
            Size = UDim2.new(1, -24, 1, -68),
            ZIndex = 2,
        }, body)
    end
    window.TabList = tabList
    window.Pages = pages

    local notificationHolder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 65,
    }, screenGui)
    window.NotificationHolder = notificationHolder

    local resizeHandle = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, 0, 1, 0),
        Size = UDim2.fromOffset(20, 20),
        Text = "",
        ZIndex = 5,
    }, main)
    window.ResizeHandle = resizeHandle

    local dragging = false
    local dragStart
    local startPosition
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    window._connections[#window._connections + 1] = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
            shadow.Position = main.Position
        end
    end)

    local resizing = false
    local resizeStart
    local resizeSize
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            resizeStart = input.Position
            resizeSize = main.AbsoluteSize
        end
    end)
    resizeHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end)
    window._connections[#window._connections + 1] = UserInputService.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - resizeStart
            local width = math.max(window._minSize.X.Offset, resizeSize.X + delta.X)
            local height = math.max(window._minSize.Y.Offset, resizeSize.Y + delta.Y)
            window._size = UDim2.fromOffset(width, height)
            main.Size = window._size
            shadow.Size = UDim2.fromOffset(width + 24, height + 24)
        end
    end)

    window.ConfigManager = setmetatable({
        Window = window,
        RootFolder = window.RootFolder,
        LibraryFolder = "Seraph",
        Folder = window.Folder,
        BaseFolder = window.RootFolder .. "/Seraph/" .. window.Folder .. "/config",
        Configs = {},
        Current = nil,
        Protection = {
            Enabled = options.ConfigProtection == true,
            Key = tostring(options.ConfigKey or "Seraph"),
            AutoSeal = false,
            Interval = 30,
        },
        _autoSealRunning = false,
    }, ConfigManager)
    window.Config = window.ConfigManager

    if options.ConfigProtection then
        window.ConfigManager:SetProtection({
            Enabled = true,
            Key = options.ConfigKey,
            AutoSeal = options.AutoSealConfig == true,
            Interval = options.ConfigProtectionInterval,
        })
    end

    if options.Tag then
        if type(options.Tag) == "table" then
            window:SetTag(options.Tag.Text or options.Tag.Title or "", options.Tag)
        else
            window:SetTag(options.Tag)
        end
    end
    if options.ToggleKey then
        window:BindKey(options.ToggleKey, function()
            window:Toggle()
        end)
    end

    return window
end

Seraph.Create = Seraph.CreateWindow
Seraph.Window = Seraph.CreateWindow

function Seraph:DestroyAll()
    local windows = {}
    for index, window in ipairs(self.Windows) do
        windows[index] = window
    end
    for _, window in ipairs(windows) do
        if window and window.Destroy then
            window:Destroy()
        end
    end
end

return Seraph
