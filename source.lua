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
            self:_setValue(nextValue, silent)
        else
            self.Value = nextValue
            if not silent then
                safeCall(self.Callback, nextValue)
            end
        end
        return self
    end

    function element:SetTitle(title)
        self.Title = tostring(title or "")
        if self.TitleLabel and self.TitleLabel.Parent then
            self.TitleLabel.Text = self.Title
        end
        if self.Options then
            self.Options.Title = self.Title
        end
        return self
    end

    function element:SetDesc(desc)
        self.Desc = desc
        if self.DescLabel and self.DescLabel.Parent then
            local text = tostring(desc or "")
            self.DescLabel.Text = text
            self.DescLabel.Visible = text ~= ""
        end
        if self.Options then
            self.Options.Desc = desc
            self.Options.Description = desc
        end
        return self
    end

    function element:SetVisible(visible)
        if self.Instance and self.Instance.Parent then
            self.Instance.Visible = visible == true
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
    element.Remove = element.Destroy

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
    if tab and tab.Title and trim(tab.Title) ~= "" then
        pieces[#pieces + 1] = tab.Title
    end
    if section and section.Title and trim(section.Title) ~= "" then
        pieces[#pieces + 1] = section.Title
    end
    self.Breadcrumb.Text = table.concat(pieces, "  ›  ")
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

    local descLabel = nil
    local description = options and (options.Desc or options.Description)
    if description and tostring(description) ~= "" then
        descLabel = self:_textLabel(textHolder, tostring(description), 11, "ElementDesc", {
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

    row.TitleLabel = titleLabel
    row.DescLabel = descLabel

    return row, content, textHolder, titleLabel, control, descLabel
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
    local targetSize = UDim2.fromOffset(width or 220, height or 200)
    local popup = create("Frame", {
        BackgroundColor3 = self:_color("PopupBackground"),
        BackgroundTransparency = self.Theme.PopupBackgroundTransparency or 0,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(targetSize.X.Offset, 0),
        ZIndex = 50,
    }, self.ScreenGui)
    addCorner(popup, 10)
    addStroke(popup, self:_color("Outline"), 0.65, 1)
    self:_bind(popup, "BackgroundColor3", "PopupBackground")
    self._popups[#self._popups + 1] = popup
    tween(popup, {Size = targetSize}, 0.2, Enum.EasingStyle.Exponential)
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
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
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
    local isCollapsible = options.Collapsible ~= false
    local sectionHeader = nil
    local chevron = nil
    local headerButton = nil

    if title and trim(title) ~= "" then
        headerButton = create("TextButton", {
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 26),
            Text = "",
            Active = true,
        }, sectionFrame)

        sectionHeader = self.Window:_textLabel(headerButton, title, 13, "Text", {
            Position = UDim2.fromOffset(0, 2),
            Size = UDim2.new(1, -30, 1, -4),
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        if isCollapsible then
            chevron = self.Window:_textLabel(headerButton, "▾", 14, "ElementDesc", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -4, 0.5, 0),
                Size = UDim2.fromOffset(20, 20),
                TextXAlignment = Enum.TextXAlignment.Center,
            })
            headerButton.MouseEnter:Connect(function()
                tween(chevron, {TextColor3 = self.Window:_color("Accent")}, 0.15)
            end)
            headerButton.MouseLeave:Connect(function()
                tween(chevron, {TextColor3 = self.Window:_color("ElementDesc")}, 0.15)
            end)
        end
    end

    local content = create("Frame", {
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Position = UDim2.fromOffset(0, title and 30 or 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, sectionFrame)
    local contentLayout = addList(content, Enum.FillDirection.Vertical, 8)
    local contentPadding = addPadding(content, 0, 0, title and 4 or 0, 0)

    local section = setmetatable({
        Window = self.Window,
        Tab = self,
        Instance = sectionFrame,
        Content = content,
        ContentLayout = contentLayout,
        Elements = {},
        Title = title or "",
        Collapsed = false,
        Header = sectionHeader,
        HeaderButton = headerButton,
        Chevron = chevron,
        Collapsible = isCollapsible,
    }, Section)

    if headerButton and isCollapsible then
        headerButton.Activated:Connect(function()
            section:SetCollapsed(not section.Collapsed)
        end)
    end
    if headerButton then
        headerButton.MouseEnter:Connect(function()
            self.Window:_setActiveSection(section)
        end)
    end

    self.Sections[#self.Sections + 1] = section
    self.Window._sections[#self.Window._sections + 1] = section
    if not self._activeSection then
        self._activeSection = section
    end
    if self.Window._activeTab == self then
        self.Window:_updateBreadcrumb(self, self._activeSection)
    end
    if isCollapsible and options.Collapsed then
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
    local layout = self.ContentLayout
    local currentHeight = (layout and layout.AbsoluteContentSize.Y or content.AbsoluteSize.Y)
    if currentHeight > 0 then
        self._expandedHeight = currentHeight + 8
    end
    local expandedHeight = self._expandedHeight or 120

    self.Collapsed = nextCollapsed

    if self.Chevron then
        tween(self.Chevron, {Rotation = nextCollapsed and -90 or 0}, 0.24, Enum.EasingStyle.Quart)
    end

    if nextCollapsed then
        content.AutomaticSize = Enum.AutomaticSize.None
        content.Size = UDim2.new(1, 0, 0, content.AbsoluteSize.Y)
        tween(content, {Size = UDim2.new(1, 0, 0, 0)}, 0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        task.delay(0.28, function()
            if self.Collapsed and content.Parent then
                content.Visible = false
            end
        end)
    else
        content.Visible = true
        content.AutomaticSize = Enum.AutomaticSize.None
        content.Size = UDim2.new(1, 0, 0, 0)
        tween(content, {Size = UDim2.new(1, 0, 0, expandedHeight)}, 0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        task.delay(0.3, function()
            if content.Parent and not self.Collapsed then
                content.AutomaticSize = Enum.AutomaticSize.Y
            end
        end)
    end
    return self
end

function Section:Refresh()
    self.Content.AutomaticSize = Enum.AutomaticSize.Y
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
    element.Options = options
    if element.Instance then
        if not element.TitleLabel and element.Instance.TitleLabel then
            element.TitleLabel = element.Instance.TitleLabel
        end
        if not element.DescLabel and element.Instance.DescLabel then
            element.DescLabel = element.Instance.DescLabel
        end
    end
    self.Elements[#self.Elements + 1] = element
    return self.Window:_registerElement(element, options)
end

function Section:Toggle(options)
    if options == nil and self.Collapsible then
        return self:SetCollapsed(not self.Collapsed)
    end
    options = type(options) == "string" and {Title = options} or (options or {})
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)
    
    local track = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(46, 24),
        Text = "",
        Active = false,
    }, control)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(track, 12)
    addStroke(track, self.Window:_color("Outline"), 0.5, 1)

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

    element._setValue = function(selfOrVal, valOrSilent, maybeSilent)
        local selfElement = (type(selfOrVal) == "table" and selfOrVal.Kind) and selfOrVal or element
        local value = (selfElement == selfOrVal) and valOrSilent or selfOrVal
        local silent = (selfElement == selfOrVal) and maybeSilent or valOrSilent
        value = value == true
        selfElement.Value = value
        tween(knob, {
            Position = value and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
        }, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        tween(track, {
            BackgroundColor3 = selfElement.Window:_color(value and "Toggle" or "TabBackground"),
        }, 0.2)
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end

    local clickOverlay = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.fromScale(1, 1),
        Text = "",
        ZIndex = 5,
    }, row)

    clickOverlay.Activated:Connect(function()
        element:Set(not element.Value)
    end)
    clickOverlay.MouseEnter:Connect(function()
        tween(row, {BackgroundColor3 = self.Window:_color("Hover")}, 0.14)
        tween(track, {Size = UDim2.fromOffset(48, 25)}, 0.14, Enum.EasingStyle.Quart)
    end)
    clickOverlay.MouseLeave:Connect(function()
        tween(row, {BackgroundColor3 = self.Window:_color("ElementBackground")}, 0.18)
        tween(track, {Size = UDim2.fromOffset(46, 24)}, 0.18, Enum.EasingStyle.Quart)
    end)

    element:_setValue(current, true)
    return self:_finish(element, options)
end

function Section:Checkbox(options)
    options = type(options) == "string" and {Title = options} or (options or {})
    options = mergeTables(options, {Kind = "Checkbox"})
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)

    local box = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("Checkbox"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(24, 24),
        Text = "",
        Active = false,
    }, control)
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(box, 6)
    addStroke(box, self.Window:_color("Outline"), 0.5, 1)
    self.Window:_bind(box, "BackgroundColor3", "Checkbox")

    local check = self.Window:_textLabel(box, "✓", 15, "CheckboxIcon", {
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Visible = false,
        Font = Enum.Font.GothamBold,
    })

    local current = options.Default == true or options.Value == true
    local element = self.Window:_newElement("Checkbox", row, current, options.Callback)

    element._setValue = function(selfOrVal, valOrSilent, maybeSilent)
        local selfElement = (type(selfOrVal) == "table" and selfOrVal.Kind) and selfOrVal or element
        local value = (selfElement == selfOrVal) and valOrSilent or selfOrVal
        local silent = (selfElement == selfOrVal) and maybeSilent or valOrSilent
        value = value == true
        selfElement.Value = value
        check.Visible = value
        box.BackgroundTransparency = value and 0 or 0.7
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end

    local clickOverlay = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.fromScale(1, 1),
        Text = "",
        ZIndex = 5,
    }, row)
    clickOverlay.Activated:Connect(function()
        element:Set(not element.Value)
    end)
    clickOverlay.MouseEnter:Connect(function()
        tween(row, {BackgroundColor3 = self.Window:_color("Hover")}, 0.14)
    end)
    clickOverlay.MouseLeave:Connect(function()
        tween(row, {BackgroundColor3 = self.Window:_color("ElementBackground")}, 0.18)
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
    options = type(options) == "string" and {Title = options} or (options or {})
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

    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 68)
    control.Size = UDim2.fromOffset(88, 26)

    local valueBox = create("TextBox", {
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(78, 24),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = self.Window:_color("Accent"),
        ClearTextOnFocus = false,
        ClipsDescendants = true,
    }, control)
    addCorner(valueBox, 6)
    addStroke(valueBox, self.Window:_color("Outline"), 0.5, 1)
    self.Window:_bind(valueBox, "BackgroundColor3", "TabBackground")
    self.Window:_bind(valueBox, "TextColor3", "Accent")

    local sliderContainer = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 1, -18),
        Size = UDim2.new(1, -24, 0, 12),
        ZIndex = 3,
    }, row)

    local bar = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, -3),
        Size = UDim2.new(1, 0, 0, 6),
        Text = "",
        ZIndex = 4,
    }, sliderContainer)
    addCorner(bar, 3)
    addStroke(bar, self.Window:_color("Outline"), 0.5, 1)
    self.Window:_bind(bar, "BackgroundColor3", "TabBackground")

    local fill = create("Frame", {
        BackgroundColor3 = self.Window:_color("Slider"),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = 5,
    }, bar)
    addCorner(fill, 3)
    self.Window:_bind(fill, "BackgroundColor3", "Slider")

    local thumb = create("TextButton", {
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self.Window:_color("SliderThumb"),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        Text = "",
        ZIndex = 6,
    }, bar)
    addCorner(thumb, 8)
    addStroke(thumb, self.Window:_color("Slider"), 0.15, 2)
    self.Window:_bind(thumb, "BackgroundColor3", "SliderThumb")

    local element = self.Window:_newElement("Slider", row, initial, options.Callback)
    element.Control = bar
    element.Min = minimum
    element.Max = maximum
    element.Increment = increment

    local function formatValue(val)
        local formatted = tostring(val)
        if type(options.Format) == "function" then
            local ok, result = pcall(options.Format, val)
            if ok and result ~= nil then
                formatted = tostring(result)
            end
        elseif options.Suffix then
            formatted = formatted .. tostring(options.Suffix)
        end
        return formatted
    end

    local function setFromPercent(percent, silent)
        percent = clamp(percent, 0, 1)
        local rawValue = minimum + (maximum - minimum) * percent
        local nextValue = minimum + round((rawValue - minimum) / increment, 0) * increment
        nextValue = clamp(nextValue, minimum, maximum)
        local normalized = (nextValue - minimum) / math.max(0.0001, maximum - minimum)
        element.Value = nextValue
        tween(fill, {Size = UDim2.new(normalized, 0, 1, 0)}, 0.12, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
        tween(thumb, {Position = UDim2.new(normalized, 0, 0.5, 0)}, 0.12, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
        valueBox.Text = formatValue(nextValue)
        if not silent then
            safeCall(element.Callback, nextValue)
        end
    end

    element._setValue = function(selfOrVal, valOrSilent, maybeSilent)
        local selfElement = (type(selfOrVal) == "table" and selfOrVal.Kind) and selfOrVal or element
        local value = (selfElement == selfOrVal) and valOrSilent or selfOrVal
        local silent = (selfElement == selfOrVal) and maybeSilent or valOrSilent
        value = tonumber(value) or minimum
        local percent = (clamp(value, minimum, maximum) - minimum) / math.max(0.0001, maximum - minimum)
        setFromPercent(percent, silent)
    end

    local dragging = false
    local function update(input)
        local barWidth = math.max(1, bar.AbsoluteSize.X)
        local relativeX = input.Position.X - bar.AbsolutePosition.X
        setFromPercent(relativeX / barWidth)
    end

    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            tween(thumb, {Size = UDim2.fromOffset(20, 20)}, 0.15, Enum.EasingStyle.Back)
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
            if dragging then
                dragging = false
                tween(thumb, {Size = UDim2.fromOffset(16, 16)}, 0.15, Enum.EasingStyle.Quart)
            end
        end
    end)
    element._connections[#element._connections + 1] = sliderChangedConnection
    element._connections[#element._connections + 1] = sliderEndedConnection

    thumb.MouseEnter:Connect(function()
        if not dragging then
            tween(thumb, {Size = UDim2.fromOffset(18, 18)}, 0.12, Enum.EasingStyle.Back)
        end
    end)
    thumb.MouseLeave:Connect(function()
        if not dragging then
            tween(thumb, {Size = UDim2.fromOffset(16, 16)}, 0.12, Enum.EasingStyle.Quart)
        end
    end)

    valueBox.FocusLost:Connect(function()
        local rawText = valueBox.Text:gsub("[^%d%.%-]", "")
        local parsed = tonumber(rawText)
        if parsed then
            element:Set(parsed)
        else
            valueBox.Text = formatValue(element.Value)
        end
    end)

    element:_setValue(initial, true)
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
    options = type(options) == "string" and {Title = options} or (options or {})
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

    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 52)
    row.ClipsDescendants = true

    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(150, 32),
        Text = "",
    }, control)
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(button, 8)
    addStroke(button, self.Window:_color("Outline"), 0.5, 1)
    self.Window:_bind(button, "BackgroundColor3", "TabBackground")

    local buttonText = self.Window:_textLabel(button, displayValue(initial), 12, "Text", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -34, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local arrow = self.Window:_textLabel(button, "▾", 14, "ElementDesc", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(16, 20),
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local dropdownFrame = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 52),
        Size = UDim2.new(1, -20, 0, 0),
        Visible = false,
        ZIndex = 4,
    }, row)

    local searchBox = nil
    local hasSearch = options.Searchable == true or (#values > 6 and options.Searchable ~= false)
    local searchOffset = 0
    if hasSearch then
        searchOffset = 36
        searchBox = create("TextBox", {
            BackgroundColor3 = self.Window:_color("TabBackground"),
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            PlaceholderText = "Search...",
            PlaceholderColor3 = self.Window:_color("Placeholder"),
            Text = "",
            TextColor3 = self.Window:_color("Text"),
            TextSize = 11,
            Font = Enum.Font.Gotham,
            Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 0, 28),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5,
        }, dropdownFrame)
        addCorner(searchBox, 6)
        addStroke(searchBox, self.Window:_color("Outline"), 0.5, 1)
        addPadding(searchBox, 8, 8, 0, 0)
        self.Window:_bind(searchBox, "BackgroundColor3", "TabBackground")
        self.Window:_bind(searchBox, "TextColor3", "Text")
    end

    local list = create("ScrollingFrame", {
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Position = UDim2.fromOffset(0, searchOffset),
        ScrollBarImageColor3 = self.Window:_color("Accent"),
        ScrollBarThickness = 3,
        Size = UDim2.new(1, 0, 1, -searchOffset),
        ZIndex = 5,
    }, dropdownFrame)
    local listLayout = addList(list, Enum.FillDirection.Vertical, 4)
    addPadding(list, 2, 4, 4, 4)

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 8)
    end)

    local element = self.Window:_newElement("Dropdown", row, initial, options.Callback)
    element.Values = values
    element.Control = button
    element.DisplayValue = displayValue
    local isOpen = false

    local function renderOptions(filter)
        filter = string.lower(trim(filter or ""))
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("GuiButton") then
                child:Destroy()
            end
        end
        local count = 0
        for index, val in ipairs(element.Values) do
            local text = displayValue(val)
            if filter == "" or string.find(string.lower(text), filter, 1, true) then
                count = count + 1
                local isSelected = (element.Value == val)
                local opt = create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = isSelected and self.Window:_color("Accent") or self.Window:_color("TabBackground"),
                    BackgroundTransparency = isSelected and 0.15 or 0.4,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 28),
                    Text = "",
                    LayoutOrder = index,
                    ZIndex = 6,
                }, list)
                addCorner(opt, 6)

                local optLabel = self.Window:_textLabel(opt, text, 12, isSelected and "Text" or "PopupContent", {
                    Position = UDim2.fromOffset(10, 0),
                    Size = UDim2.new(1, -36, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 7,
                })

                if isSelected then
                    self.Window:_textLabel(opt, "✓", 13, "Accent", {
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, -8, 0.5, 0),
                        Size = UDim2.fromOffset(18, 18),
                        TextXAlignment = Enum.TextXAlignment.Center,
                        ZIndex = 7,
                    })
                end

                opt.MouseEnter:Connect(function()
                    if element.Value ~= val then
                        tween(opt, {BackgroundColor3 = self.Window:_color("Hover"), BackgroundTransparency = 0.1}, 0.12)
                    end
                end)
                opt.MouseLeave:Connect(function()
                    if element.Value ~= val then
                        tween(opt, {BackgroundColor3 = self.Window:_color("TabBackground"), BackgroundTransparency = 0.4}, 0.12)
                    end
                end)

                opt.Activated:Connect(function()
                    element:Set(val)
                    element:Toggle(false)
                end)
            end
        end
    end

    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            renderOptions(searchBox.Text)
        end)
    end

    element._setValue = function(selfOrVal, valOrSilent, maybeSilent)
        local selfElement = (type(selfOrVal) == "table" and selfOrVal.Kind) and selfOrVal or element
        local value = (selfElement == selfOrVal) and valOrSilent or selfOrVal
        local silent = (selfElement == selfOrVal) and maybeSilent or valOrSilent
        selfElement.Value = value
        buttonText.Text = displayValue(value)
        if isOpen then
            renderOptions(searchBox and searchBox.Text or "")
        end
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end

    function element:Toggle(open)
        if open == nil then
            open = not isOpen
        end
        if isOpen == open then
            return
        end
        isOpen = open
        tween(arrow, {Rotation = isOpen and 180 or 0}, 0.22, Enum.EasingStyle.Quart)

        if isOpen then
            renderOptions(searchBox and searchBox.Text or "")
            dropdownFrame.Visible = true
            local targetListHeight = math.clamp(#element.Values * 32 + (hasSearch and 40 or 10), 40, 180)
            dropdownFrame.Size = UDim2.new(1, -20, 0, targetListHeight)
            tween(row, {Size = UDim2.new(1, 0, 0, 56 + targetListHeight + 8)}, 0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        else
            tween(row, {Size = UDim2.new(1, 0, 0, 52)}, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            task.delay(0.24, function()
                if not isOpen and dropdownFrame.Parent then
                    dropdownFrame.Visible = false
                end
            end)
        end
    end

    function element:Refresh(nextValues, nextValue, silent)
        if type(nextValues) == "table" and (nextValues.Values or nextValues.Options) then
            nextValue = nextValues.Default or nextValues.Value or nextValue
            nextValues = nextValues.Values or nextValues.Options
        end
        element.Values = copyValues(nextValues or {})
        local found = false
        for _, v in ipairs(element.Values) do
            if v == (nextValue or element.Value) then
                found = true
                break
            end
        end
        local chosen = found and (nextValue or element.Value) or element.Values[1]
        element:Set(chosen, silent == true)
        if isOpen then
            renderOptions(searchBox and searchBox.Text or "")
            local targetListHeight = math.clamp(#element.Values * 32 + (hasSearch and 40 or 10), 40, 180)
            dropdownFrame.Size = UDim2.new(1, -20, 0, targetListHeight)
            tween(row, {Size = UDim2.new(1, 0, 0, 56 + targetListHeight + 8)}, 0.2, Enum.EasingStyle.Quart)
        end
        return element
    end
    element.UpdateDropdown = element.Refresh
    element.DropdownUpdate = element.Refresh
    element.dropdownUpdate = element.Refresh
    element.Update = element.Refresh

    button.Activated:Connect(function()
        element:Toggle()
    end)
    button.MouseEnter:Connect(function()
        tween(button, {BackgroundColor3 = self.Window:_color("Hover")}, 0.12)
    end)
    button.MouseLeave:Connect(function()
        tween(button, {BackgroundColor3 = self.Window:_color("TabBackground")}, 0.14)
    end)

    element:_setValue(initial, true)
    return self:_finish(element, options)
end

function Section:DropDownPlayersAuto(options)
    options = type(options) == "string" and {Title = options} or (options or {})
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

    local function getPlayerList()
        local result = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if options.IncludeLocalPlayer ~= false or player ~= LocalPlayer then
                result[#result + 1] = toValue(player)
            end
        end
        table.sort(result, function(a, b)
            return tostring(a):lower() < tostring(b):lower()
        end)
        if #result == 0 then
            result[1] = "None"
        end
        return result
    end

    local initialValues = getPlayerList()
    local dropdownOptions = mergeTables(options, {
        Values = initialValues,
        Default = options.Default or initialValues[1],
        Searchable = options.Searchable ~= false,
    })

    local element = self:Dropdown(dropdownOptions)
    element.AutoPlayers = true

    element.RefreshPlayers = function(selfElement, silent)
        local nextValues = getPlayerList()
        local current = selfElement.Value
        local exists = false
        for _, v in ipairs(nextValues) do
            if v == current then
                exists = true
                break
            end
        end
        local nextChoice = exists and current or nextValues[1]
        selfElement:Refresh(nextValues, nextChoice, silent == true)
        return selfElement
    end

    element.GetPlayer = function(selfElement)
        local val = selfElement.Value
        if typeof(val) == "Instance" and val:IsA("Player") then
            return val
        end
        if val == nil or val == "None" then
            return nil
        end
        if options.ValueType and string.lower(tostring(options.ValueType)) == "userid" then
            return Players:GetPlayerByUserId(tonumber(val) or -1)
        end
        return Players:FindFirstChild(tostring(val))
    end

    local addedConn = Players.PlayerAdded:Connect(function()
        task.defer(function()
            element:RefreshPlayers(true)
        end)
    end)
    local removedConn = Players.PlayerRemoving:Connect(function(leavingPlayer)
        task.defer(function()
            local leavingVal = toValue(leavingPlayer)
            local current = element.Value
            if current == leavingVal then
                element:RefreshPlayers(false)
            else
                element:RefreshPlayers(true)
            end
        end)
    end)

    element._connections[#element._connections + 1] = addedConn
    element._connections[#element._connections + 1] = removedConn

    return element
end

Section.DropdownPlayersAuto = Section.DropDownPlayersAuto

function Section:MultiDropdown(options)
    options = type(options) == "string" and {Title = options} or (options or {})
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

    local initial = options.Default or options.Value or {}
    local selected = {}
    for _, value in ipairs(initial) do
        selected[value] = true
    end

    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 52)
    row.ClipsDescendants = true

    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(150, 32),
        Text = "",
    }, control)
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(button, 8)
    addStroke(button, self.Window:_color("Outline"), 0.5, 1)
    self.Window:_bind(button, "BackgroundColor3", "TabBackground")

    local buttonText = self.Window:_textLabel(button, "Select", 12, "Text", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -34, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local arrow = self.Window:_textLabel(button, "▾", 14, "ElementDesc", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(16, 20),
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local dropdownFrame = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 52),
        Size = UDim2.new(1, -20, 0, 0),
        Visible = false,
        ZIndex = 4,
    }, row)

    local list = create("ScrollingFrame", {
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Position = UDim2.fromOffset(0, 0),
        ScrollBarImageColor3 = self.Window:_color("Accent"),
        ScrollBarThickness = 3,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 5,
    }, dropdownFrame)
    local listLayout = addList(list, Enum.FillDirection.Vertical, 4)
    addPadding(list, 2, 4, 4, 4)

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 8)
    end)

    local element = self.Window:_newElement("MultiDropdown", row, {}, options.Callback)
    element.Values = values
    element.Control = button
    local isOpen = false

    local function selectedArray()
        local result = {}
        for _, v in ipairs(element.Values) do
            if selected[v] then
                result[#result + 1] = v
            end
        end
        return result
    end

    local function updateSummary()
        local arr = selectedArray()
        element.Value = arr
        if #arr == 0 then
            buttonText.Text = "None"
        elseif #arr == 1 then
            buttonText.Text = displayValue(arr[1])
        else
            buttonText.Text = tostring(#arr) .. " selected"
        end
    end

    local function renderOptions()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("GuiButton") then
                child:Destroy()
            end
        end
        for index, val in ipairs(element.Values) do
            local text = displayValue(val)
            local isSelected = (selected[val] == true)
            local opt = create("TextButton", {
                AutoButtonColor = false,
                BackgroundColor3 = isSelected and self.Window:_color("Accent") or self.Window:_color("TabBackground"),
                BackgroundTransparency = isSelected and 0.2 or 0.4,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 28),
                Text = "",
                LayoutOrder = index,
                ZIndex = 6,
            }, list)
            addCorner(opt, 6)

            local optLabel = self.Window:_textLabel(opt, text, 12, isSelected and "Text" or "PopupContent", {
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -36, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 7,
            })

            local checkmark = self.Window:_textLabel(opt, isSelected and "✓" or "", 13, "Accent", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 7,
            })

            opt.MouseEnter:Connect(function()
                if not selected[val] then
                    tween(opt, {BackgroundColor3 = self.Window:_color("Hover"), BackgroundTransparency = 0.1}, 0.12)
                end
            end)
            opt.MouseLeave:Connect(function()
                if not selected[val] then
                    tween(opt, {BackgroundColor3 = self.Window:_color("TabBackground"), BackgroundTransparency = 0.4}, 0.12)
                end
            end)

            opt.Activated:Connect(function()
                selected[val] = not selected[val]
                local nowSelected = selected[val]
                checkmark.Text = nowSelected and "✓" or ""
                tween(opt, {
                    BackgroundColor3 = nowSelected and self.Window:_color("Accent") or self.Window:_color("TabBackground"),
                    BackgroundTransparency = nowSelected and 0.2 or 0.4,
                }, 0.15)
                updateSummary()
                safeCall(element.Callback, element.Value)
            end)
        end
    end

    element._setValue = function(selfOrVal, valOrSilent, maybeSilent)
        local selfElement = (type(selfOrVal) == "table" and selfOrVal.Kind) and selfOrVal or element
        local value = (selfElement == selfOrVal) and valOrSilent or selfOrVal
        local silent = (selfElement == selfOrVal) and maybeSilent or valOrSilent
        selected = {}
        for _, item in ipairs(value or {}) do
            selected[item] = true
        end
        updateSummary()
        if isOpen then
            renderOptions()
        end
        if not silent then
            safeCall(selfElement.Callback, selfElement.Value)
        end
    end

    function element:Toggle(open)
        if open == nil then
            open = not isOpen
        end
        if isOpen == open then
            return
        end
        isOpen = open
        tween(arrow, {Rotation = isOpen and 180 or 0}, 0.22, Enum.EasingStyle.Quart)

        if isOpen then
            renderOptions()
            dropdownFrame.Visible = true
            local targetListHeight = math.clamp(#element.Values * 32 + 10, 40, 180)
            dropdownFrame.Size = UDim2.new(1, -20, 0, targetListHeight)
            tween(row, {Size = UDim2.new(1, 0, 0, 56 + targetListHeight + 8)}, 0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        else
            tween(row, {Size = UDim2.new(1, 0, 0, 52)}, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            task.delay(0.24, function()
                if not isOpen and dropdownFrame.Parent then
                    dropdownFrame.Visible = false
                end
            end)
        end
    end

    function element:Refresh(nextValues, nextValue, silent)
        if type(nextValues) == "table" and (nextValues.Values or nextValues.Options) then
            nextValue = nextValues.Default or nextValues.Value or nextValue
            nextValues = nextValues.Values or nextValues.Options
        end
        element.Values = copyValues(nextValues or {})
        selected = {}
        for _, item in ipairs(nextValue or {}) do
            selected[item] = true
        end
        updateSummary()
        if isOpen then
            renderOptions()
            local targetListHeight = math.clamp(#element.Values * 32 + 10, 40, 180)
            dropdownFrame.Size = UDim2.new(1, -20, 0, targetListHeight)
            tween(row, {Size = UDim2.new(1, 0, 0, 56 + targetListHeight + 8)}, 0.2, Enum.EasingStyle.Quart)
        end
        if not silent then
            safeCall(element.Callback, element.Value)
        end
        return element
    end
    element.UpdateDropdown = element.Refresh
    element.DropdownUpdate = element.Refresh
    element.dropdownUpdate = element.Refresh
    element.Update = element.Refresh

    button.Activated:Connect(function()
        element:Toggle()
    end)
    button.MouseEnter:Connect(function()
        tween(button, {BackgroundColor3 = self.Window:_color("Hover")}, 0.12)
    end)
    button.MouseLeave:Connect(function()
        tween(button, {BackgroundColor3 = self.Window:_color("TabBackground")}, 0.14)
    end)

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
    options = type(options) == "string" and {Title = options} or (options or {})
    local initial = color(options.Default or options.Value, self.Window:_color("Accent"))
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 52)
    row.ClipsDescendants = true

    local swatchBtn = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = initial,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(50, 26),
        Text = "",
    }, control)
    swatchBtn.AnchorPoint = Vector2.new(1, 0.5)
    swatchBtn.Position = UDim2.new(1, 0, 0.5, 0)
    addCorner(swatchBtn, 7)
    addStroke(swatchBtn, self.Window:_color("Outline"), 0.5, 1)

    local studio = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 52),
        Size = UDim2.new(1, -20, 0, 170),
        Visible = false,
        ZIndex = 4,
    }, row)

    local hue, saturation, value = Color3.toHSV(initial)
    local isOpen = false

    local svMap = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(4, 4),
        Size = UDim2.new(1, -76, 0, 115),
        Text = "",
        ZIndex = 5,
    }, studio)
    addCorner(svMap, 8)
    addStroke(svMap, self.Window:_color("Outline"), 0.5, 1)

    local whiteOverlay = create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 6,
    }, svMap)
    addCorner(whiteOverlay, 8)
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
        ZIndex = 7,
    }, svMap)
    addCorner(blackOverlay, 8)
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, blackOverlay)

    local svCursor = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.new(saturation, 0, 1 - value, 0),
        Size = UDim2.fromOffset(12, 12),
        ZIndex = 8,
    }, svMap)
    addCorner(svCursor, 6)
    addStroke(svCursor, Color3.new(0, 0, 0), 0.2, 2)

    local hueSlider = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.new(1, -62, 0, 4),
        Size = UDim2.fromOffset(20, 115),
        Text = "",
        ZIndex = 5,
    }, studio)
    addCorner(hueSlider, 8)
    addStroke(hueSlider, self.Window:_color("Outline"), 0.5, 1)

    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
    }, hueSlider)

    local hueCursor = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, hue, 0),
        Size = UDim2.fromOffset(26, 4),
        ZIndex = 8,
    }, hueSlider)
    addCorner(hueCursor, 2)
    addStroke(hueCursor, Color3.new(0, 0, 0), 0.25, 1)

    local previewBox = create("Frame", {
        BackgroundColor3 = initial,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -34, 0, 4),
        Size = UDim2.fromOffset(30, 115),
        ZIndex = 5,
    }, studio)
    addCorner(previewBox, 8)
    addStroke(previewBox, self.Window:_color("Outline"), 0.5, 1)

    local bottomBar = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 4, 0, 126),
        Size = UDim2.new(1, -8, 0, 30),
        ZIndex = 5,
    }, studio)

    local hexBox = create("TextBox", {
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.GothamMedium,
        PlaceholderText = "#FFFFFF",
        PlaceholderColor3 = self.Window:_color("Placeholder"),
        Position = UDim2.fromOffset(0, 2),
        Size = UDim2.fromOffset(88, 26),
        Text = "#FFFFFF",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 11,
        ZIndex = 6,
    }, bottomBar)
    addCorner(hexBox, 6)
    addStroke(hexBox, self.Window:_color("Outline"), 0.5, 1)
    self.Window:_bind(hexBox, "BackgroundColor3", "TabBackground")
    self.Window:_bind(hexBox, "TextColor3", "Text")

    local function makeRgbBox(posX, labelText)
        local frame = create("Frame", {
            BackgroundColor3 = self.Window:_color("TabBackground"),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(posX, 2),
            Size = UDim2.fromOffset(54, 26),
            ZIndex = 6,
        }, bottomBar)
        addCorner(frame, 6)
        addStroke(frame, self.Window:_color("Outline"), 0.5, 1)
        self.Window:_bind(frame, "BackgroundColor3", "TabBackground")

        local lbl = self.Window:_textLabel(frame, labelText, 10, "ElementDesc", {
            Position = UDim2.fromOffset(4, 0),
            Size = UDim2.fromOffset(12, 26),
            ZIndex = 7,
        })

        local tb = create("TextBox", {
            BackgroundTransparency = 1,
            ClearTextOnFocus = false,
            Font = Enum.Font.GothamMedium,
            Position = UDim2.fromOffset(16, 0),
            Size = UDim2.new(1, -18, 1, 0),
            Text = "255",
            TextColor3 = self.Window:_color("Text"),
            TextSize = 11,
            ZIndex = 7,
        }, frame)
        self.Window:_bind(tb, "TextColor3", "Text")
        return tb
    end

    local rBox = makeRgbBox(96, "R")
    local gBox = makeRgbBox(156, "G")
    local bBox = makeRgbBox(216, "B")

    local element = self.Window:_newElement("Colorpicker", row, initial, options.Callback)
    element.Control = swatchBtn

    local function toHex(c)
        return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
    end

    local function syncVisuals(nextColor, silent)
        element.Value = nextColor
        swatchBtn.BackgroundColor3 = nextColor
        previewBox.BackgroundColor3 = nextColor
        svMap.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        svCursor.Position = UDim2.new(clamp(saturation, 0, 1), 0, clamp(1 - value, 0, 1), 0)
        hueCursor.Position = UDim2.new(0.5, 0, clamp(hue, 0, 1), 0)
        hexBox.Text = toHex(nextColor)
        rBox.Text = tostring(math.floor(nextColor.R * 255 + 0.5))
        gBox.Text = tostring(math.floor(nextColor.G * 255 + 0.5))
        bBox.Text = tostring(math.floor(nextColor.B * 255 + 0.5))
        if not silent then
            safeCall(element.Callback, nextColor)
        end
    end

    element._setValue = function(selfOrVal, valOrSilent, maybeSilent)
        local selfElement = (type(selfOrVal) == "table" and selfOrVal.Kind) and selfOrVal or element
        local nextVal = (selfElement == selfOrVal) and valOrSilent or selfOrVal
        local silent = (selfElement == selfOrVal) and maybeSilent or valOrSilent
        local nextColor = color(nextVal, initial)
        hue, saturation, value = Color3.toHSV(nextColor)
        syncVisuals(nextColor, silent)
    end

    function element:Toggle(open)
        if open == nil then
            open = not isOpen
        end
        if isOpen == open then
            return
        end
        isOpen = open

        if isOpen then
            studio.Visible = true
            syncVisuals(element.Value, true)
            tween(row, {Size = UDim2.new(1, 0, 0, 230)}, 0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        else
            tween(row, {Size = UDim2.new(1, 0, 0, 52)}, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            task.delay(0.24, function()
                if not isOpen and studio.Parent then
                    studio.Visible = false
                end
            end)
        end
    end

    local svDragging = false
    local hueDragging = false

    local function updateSv(input)
        local mapWidth = math.max(1, svMap.AbsoluteSize.X)
        local mapHeight = math.max(1, svMap.AbsoluteSize.Y)
        local relX = clamp((input.Position.X - svMap.AbsolutePosition.X) / mapWidth, 0, 1)
        local relY = clamp((input.Position.Y - svMap.AbsolutePosition.Y) / mapHeight, 0, 1)
        saturation = relX
        value = 1 - relY
        local nextColor = Color3.fromHSV(hue, saturation, value)
        syncVisuals(nextColor, false)
    end

    local function updateHue(input)
        local hueHeight = math.max(1, hueSlider.AbsoluteSize.Y)
        hue = clamp((input.Position.Y - hueSlider.AbsolutePosition.Y) / hueHeight, 0, 1)
        local nextColor = Color3.fromHSV(hue, saturation, value)
        syncVisuals(nextColor, false)
    end

    svMap.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            svDragging = true
            updateSv(input)
        end
    end)
    hueSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            hueDragging = true
            updateHue(input)
        end
    end)

    local inputChangedConn = UserInputService.InputChanged:Connect(function(input)
        if svDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSv(input)
        elseif hueDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateHue(input)
        end
    end)
    local inputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            svDragging = false
            hueDragging = false
        end
    end)
    element._connections[#element._connections + 1] = inputChangedConn
    element._connections[#element._connections + 1] = inputEndedConn

    hexBox.FocusLost:Connect(function()
        local raw = hexBox.Text:gsub("#", "")
        if #raw == 6 and tonumber(raw, 16) then
            local num = tonumber(raw, 16)
            local parsedColor = Color3.fromRGB(bit32.rshift(num, 16) % 256, bit32.rshift(num, 8) % 256, num % 256)
            hue, saturation, value = Color3.toHSV(parsedColor)
            syncVisuals(parsedColor, false)
        else
            hexBox.Text = toHex(element.Value)
        end
    end)

    local function onRgbChanged()
        local r = clamp(tonumber(rBox.Text) or 0, 0, 255)
        local g = clamp(tonumber(gBox.Text) or 0, 0, 255)
        local b = clamp(tonumber(bBox.Text) or 0, 0, 255)
        local parsedColor = Color3.fromRGB(r, g, b)
        hue, saturation, value = Color3.toHSV(parsedColor)
        syncVisuals(parsedColor, false)
    end
    rBox.FocusLost:Connect(onRgbChanged)
    gBox.FocusLost:Connect(onRgbChanged)
    bBox.FocusLost:Connect(onRgbChanged)

    swatchBtn.Activated:Connect(function()
        element:Toggle()
    end)
    swatchBtn.MouseEnter:Connect(function()
        tween(swatchBtn, {Size = UDim2.fromOffset(54, 28)}, 0.12, Enum.EasingStyle.Quart)
    end)
    swatchBtn.MouseLeave:Connect(function()
        tween(swatchBtn, {Size = UDim2.fromOffset(50, 26)}, 0.12, Enum.EasingStyle.Quart)
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
    options = type(options) == "string" and {Title = options} or (options or {})
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

    local cardHeight = tonumber(options.Height) or 330
    local card = create("Frame", {
        BackgroundColor3 = self.Window:_color("ElementBackground"),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, cardHeight),
        LayoutOrder = options.LayoutOrder or (#self.Elements + 1),
        ClipsDescendants = true,
    }, self.Content)
    addCorner(card, 10)
    addStroke(card, self.Window:_color("Outline"), 0.5, 1)
    addPadding(card, 12, 12, 12, 12)
    self.Window:_bind(card, "BackgroundColor3", "ElementBackground")

    local cardLayout = addList(card, Enum.FillDirection.Vertical, 8)

    local hero = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 52),
        LayoutOrder = 1,
    }, card)

    local albumArt = create("Frame", {
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(48, 48),
        Position = UDim2.fromOffset(0, 2),
    }, hero)
    addCorner(albumArt, 8)
    addStroke(albumArt, self.Window:_color("Outline"), 0.5, 1)
    self.Window:_bind(albumArt, "BackgroundColor3", "TabBackground")

    local musicIconSource = options.Icon or "lucide:music-2"
    local albumIcon = self.Window:_icon(albumArt, musicIconSource, 22, "Accent")
    albumIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    albumIcon.Position = UDim2.fromScale(0.5, 0.5)

    local metaHolder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(58, 4),
        Size = UDim2.new(1, -210, 0, 44),
    }, hero)

    local trackTitle = self.Window:_textLabel(metaHolder, "Track Title", 13, "Text", {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 20),
        Font = Enum.Font.GothamMedium,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local trackStatus = self.Window:_textLabel(metaHolder, "Spotify Player • Paused", 10, "ElementDesc", {
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 16),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local transport = create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(144, 38),
    }, hero)
    local transportLayout = addList(transport, Enum.FillDirection.Horizontal, 6)
    transportLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    local autoNextBtn = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(26, 26),
        Text = "↻",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        LayoutOrder = 1,
    }, transport)
    addCorner(autoNextBtn, 6)
    self.Window:_bind(autoNextBtn, "BackgroundColor3", "TabBackground")
    self.Window:_bind(autoNextBtn, "TextColor3", "Text")

    local prevBtn = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(28, 28),
        Text = "⏮",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        LayoutOrder = 2,
    }, transport)
    addCorner(prevBtn, 7)
    self.Window:_bind(prevBtn, "BackgroundColor3", "TabBackground")
    self.Window:_bind(prevBtn, "TextColor3", "Text")

    local playBtn = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("Accent"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(36, 36),
        Text = "▶",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        LayoutOrder = 3,
    }, transport)
    addCorner(playBtn, 18)
    self.Window:_bind(playBtn, "BackgroundColor3", "Accent")

    local nextBtn = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(28, 28),
        Text = "⏭",
        TextColor3 = self.Window:_color("Text"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        LayoutOrder = 4,
    }, transport)
    addCorner(nextBtn, 7)
    self.Window:_bind(nextBtn, "BackgroundColor3", "TabBackground")
    self.Window:_bind(nextBtn, "TextColor3", "Text")

    local volRow = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        LayoutOrder = 2,
    }, card)

    local volIcon = self.Window:_textLabel(volRow, "🔊", 11, "ElementDesc", {
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.fromOffset(18, 16),
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local volBar = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(26, 7),
        Size = UDim2.new(1, -78, 0, 6),
        Text = "",
    }, volRow)
    addCorner(volBar, 3)
    addStroke(volBar, self.Window:_color("Outline"), 0.5, 1)
    self.Window:_bind(volBar, "BackgroundColor3", "TabBackground")

    local volFill = create("Frame", {
        BackgroundColor3 = self.Window:_color("Accent"),
        BorderSizePixel = 0,
        Size = UDim2.new(0.7, 0, 1, 0),
    }, volBar)
    addCorner(volFill, 3)
    self.Window:_bind(volFill, "BackgroundColor3", "Accent")

    local volLabel = self.Window:_textLabel(volRow, "70%", 10, "ElementDesc", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(44, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local tableHeader = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        LayoutOrder = 3,
    }, card)

    self.Window:_textLabel(tableHeader, "#", 10, "ElementDesc", {
        Position = UDim2.fromOffset(6, 0),
        Size = UDim2.fromOffset(24, 20),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    self.Window:_textLabel(tableHeader, "TITLE", 10, "ElementDesc", {
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -40, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local listFrame = create("ScrollingFrame", {
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarImageColor3 = self.Window:_color("Accent"),
        ScrollBarThickness = 3,
        Size = UDim2.new(1, 0, 1, -120),
        LayoutOrder = 4,
        ZIndex = 4,
    }, card)
    local listLayout = addList(listFrame, Enum.FillDirection.Vertical, 3)

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 8)
    end)

    local musicSound = Instance.new("Sound")
    musicSound.Name = "SeraphMusic"
    musicSound.Volume = 0.7
    musicSound.Looped = false
    musicSound.Parent = SoundService

    local element = self.Window:_newElement("Music", card, 1, options.Callback)
    element.Control = musicSound
    element.Playlist = normalizedPlaylist
    element.CurrentIndex = 1
    element.Volume = 0.7
    element.Playing = false
    element.AutoPlayNext = options.AutoPlayNext ~= false
    element.AllowReorder = options.AllowReorder == true
    element._gameVolume = 1
    element._gameSoundVolumes = {}
    element.PlaylistFrame = listFrame

    local renderPlaylist = nil

    local function updateTrackInfo()
        local track = normalizedPlaylist[element.CurrentIndex]
        trackTitle.Text = track and track.Name or "No tracks"
        if element.Playing then
            trackStatus.Text = string.format("Playing • %d/%d", element.CurrentIndex, #normalizedPlaylist)
            trackStatus.TextColor3 = self.Window:_color("Success")
            playBtn.Text = "⏸"
        else
            trackStatus.Text = string.format("Paused • %d/%d", element.CurrentIndex, #normalizedPlaylist)
            trackStatus.TextColor3 = self.Window:_color("ElementDesc")
            playBtn.Text = "▶"
        end
        if renderPlaylist then
            renderPlaylist()
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
        if autoplay and track.Id ~= "" then
            musicSound:Play()
            element.Playing = true
            safeCall(element.Callback, track)
        else
            element.Playing = false
        end
        updateTrackInfo()
    end

    renderPlaylist = function()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("GuiButton") or child.Name == "EmptyPlaylist" then
                child:Destroy()
            end
        end
        for index, track in ipairs(normalizedPlaylist) do
            local isCurrent = (index == element.CurrentIndex)
            local item = create("TextButton", {
                AutoButtonColor = false,
                BackgroundColor3 = isCurrent and self.Window:_color("Accent") or self.Window:_color("TabBackground"),
                BackgroundTransparency = isCurrent and 0.15 or 0.6,
                BorderSizePixel = 0,
                Size = UDim2.new(1, -4, 0, 30),
                Text = "",
                LayoutOrder = index,
                ZIndex = 5,
            }, listFrame)
            addCorner(item, 6)

            local numLabel = self.Window:_textLabel(item, tostring(index), 11, isCurrent and "Accent" or "ElementDesc", {
                Position = UDim2.fromOffset(4, 0),
                Size = UDim2.fromOffset(24, 30),
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 6,
            })

            local nameLbl = self.Window:_textLabel(item, tostring(track.Name), 11, isCurrent and "Text" or "PopupContent", {
                Position = UDim2.fromOffset(32, 0),
                Size = UDim2.new(1, -72, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd,
                Font = isCurrent and Enum.Font.GothamMedium or Enum.Font.Gotham,
                ZIndex = 6,
            })

            if isCurrent and element.Playing then
                local wave = self.Window:_textLabel(item, "●", 10, "Success", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.fromOffset(18, 18),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 6,
                })
            end

            item.MouseEnter:Connect(function()
                if index ~= element.CurrentIndex then
                    tween(item, {BackgroundColor3 = self.Window:_color("Hover"), BackgroundTransparency = 0.2}, 0.12)
                    numLabel.Text = "▶"
                end
            end)
            item.MouseLeave:Connect(function()
                if index ~= element.CurrentIndex then
                    tween(item, {BackgroundColor3 = self.Window:_color("TabBackground"), BackgroundTransparency = 0.6}, 0.12)
                    numLabel.Text = tostring(index)
                end
            end)
            item.Activated:Connect(function()
                setTrack(index, true)
            end)
        end
    end

    element.SetVolume = function(_, val)
        element.Volume = clamp(tonumber(val) or 0.7, 0, 1)
        musicSound.Volume = element.Volume
        volFill.Size = UDim2.new(element.Volume, 0, 1, 0)
        volLabel.Text = tostring(math.floor(element.Volume * 100 + 0.5)) .. "%"
    end

    element.Play = function()
        local track = normalizedPlaylist[element.CurrentIndex]
        if track and track.Id ~= "" then
            musicSound:Play()
            element.Playing = true
            updateTrackInfo()
        end
    end
    element.Pause = function()
        musicSound:Pause()
        element.Playing = false
        updateTrackInfo()
    end
    element.Stop = function()
        musicSound:Stop()
        element.Playing = false
        updateTrackInfo()
    end
    element.Next = function()
        setTrack(element.CurrentIndex + 1, true)
    end
    element.Previous = function()
        setTrack(element.CurrentIndex - 1, true)
    end

    playBtn.Activated:Connect(function()
        if element.Playing then
            element:Pause()
        else
            element:Play()
        end
    end)
    prevBtn.Activated:Connect(element.Previous)
    nextBtn.Activated:Connect(element.Next)

    autoNextBtn.Activated:Connect(function()
        element.AutoPlayNext = not element.AutoPlayNext
        autoNextBtn.BackgroundColor3 = element.AutoPlayNext and self.Window:_color("Accent") or self.Window:_color("TabBackground")
    end)

    musicSound.Ended:Connect(function()
        if element.AutoPlayNext then
            element:Next()
        else
            element.Playing = false
            updateTrackInfo()
        end
    end)

    local volDragging = false
    local function updateVol(input)
        local barWidth = math.max(1, volBar.AbsoluteSize.X)
        local relX = clamp((input.Position.X - volBar.AbsolutePosition.X) / barWidth, 0, 1)
        element:SetVolume(relX)
    end

    volBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            volDragging = true
            updateVol(input)
        end
    end)

    local volMoveConn = UserInputService.InputChanged:Connect(function(input)
        if volDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateVol(input)
        end
    end)
    local volEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            volDragging = false
        end
    end)
    element._connections[#element._connections + 1] = volMoveConn
    element._connections[#element._connections + 1] = volEndConn

    element.Destroy = function(selfElement)
        if selfElement._destroyed then
            return
        end
        selfElement._destroyed = true
        selfElement:Stop()
        musicSound:Destroy()
        disconnectAll(selfElement._connections)
        selfElement.Window:_unregisterElement(selfElement)
        if card and card.Parent then
            card:Destroy()
        end
    end

    element:SetVolume(element.Volume)
    setTrack(1, options.AutoPlay == true)
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
    self._tag.Size = UDim2.fromOffset(clamp(#tostring(text or "") * 7 + 24, 58, 126), 22)
    if options.Color or options.BackgroundColor then
        self._tag.BackgroundColor3 = color(options.Color or options.BackgroundColor, self:_color("Accent"))
    else
        self._tag.BackgroundColor3 = self:_color("Accent")
    end
    if options.TextColor then
        self._tag.TextColor3 = color(options.TextColor, self:_color("Text"))
    else
        self._tag.TextColor3 = self:_color("Text")
    end
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
    if self.Shadow and self.Shadow.Visible then
        self.Shadow.Size = self._minimized and UDim2.fromOffset(self._size.X.Offset + 24, 82) or UDim2.fromOffset(self._size.X.Offset + 24, self._size.Y.Offset + 24)
    end
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
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = size,
        Visible = false,
        ZIndex = 0,
    }, screenGui)
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
    addCorner(main, 14)
    addStroke(main, window:_color("Outline"), 0.5, 1)
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
    local searchStroke = addStroke(searchSurface, window:_color("Outline"), 0.65, 1)
    window:_bind(searchSurface, "BackgroundColor3", "ElementBackground")
    local searchIcon
    if options.SearchIcon or Seraph.IconRuntime then
        searchIcon = window:_icon(searchSurface, options.SearchIcon or "search", 15, "Icon")
        searchIcon.Position = UDim2.fromOffset(10, 7)
    else
        searchIcon = window:_textLabel(searchSurface, "⌕", 16, "Icon", {
            Position = UDim2.fromOffset(8, 3),
            Size = UDim2.fromOffset(18, 24),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end
    local searchBox = create("TextBox", {
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        PlaceholderText = options.SearchPlaceholder or "Search features or tabs...",
        PlaceholderColor3 = window:_color("Placeholder"),
        Text = "",
        TextColor3 = window:_color("Text"),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        Position = UDim2.fromOffset(32, 0),
        Size = UDim2.new(1, -60, 1, 0),
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
        Position = UDim2.new(1, -26, 0, 3),
        Size = UDim2.fromOffset(22, 24),
        Text = "×",
        TextColor3 = window:_color("Placeholder"),
        TextSize = 15,
        Font = Enum.Font.GothamMedium,
        Visible = false,
        ZIndex = 6,
    }, searchSurface)
    searchClear.Activated:Connect(function()
        searchBox.Text = ""
        searchClear.Visible = false
        window:_applySearch("")
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

    searchBox.Focused:Connect(function()
        tween(searchStroke, {Color = window:_color("Accent"), Transparency = 0.15}, 0.15)
        tween(searchSurface, {BackgroundColor3 = blend(window:_color("ElementBackground"), window:_color("Accent"), 0.08)}, 0.15)
    end)
    searchBox.FocusLost:Connect(function()
        tween(searchStroke, {Color = window:_color("Outline"), Transparency = 0.65}, 0.15)
        tween(searchSurface, {BackgroundColor3 = window:_color("ElementBackground")}, 0.15)
    end)

    local breadcrumb = window:_textLabel(toolbar, window.Title, 11, "ElementDesc", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromOffset(362, 22),
        Size = UDim2.new(1, -390, 0, 24),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })
    window.Breadcrumb = breadcrumb
    window._connections[#window._connections + 1] = searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchClear.Visible = (searchBox.Text ~= "")
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
            if shadow and shadow.Visible then
                shadow.Position = main.Position
            end
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
            if shadow and shadow.Visible then
                shadow.Size = UDim2.fromOffset(width + 24, height + 24)
            end
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
