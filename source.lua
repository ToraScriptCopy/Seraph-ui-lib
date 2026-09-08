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
    Accent = colorFromHex("3B82F6"),
    Background = colorFromHex("111827"),
    BackgroundTransparency = 0.05,
    Outline = colorFromHex("64748B"),
    Text = colorFromHex("F8FAFC"),
    Placeholder = colorFromHex("94A3B8"),
    Button = colorFromHex("2563EB"),
    Icon = colorFromHex("CBD5E1"),
    Hover = colorFromHex("FFFFFF"),
    WindowBackground = colorFromHex("0F172A"),
    WindowShadow = colorFromHex("020617"),
    DialogBackground = colorFromHex("111827"),
    DialogBackgroundTransparency = 0.03,
    DialogTitle = colorFromHex("F8FAFC"),
    DialogContent = colorFromHex("CBD5E1"),
    DialogIcon = colorFromHex("93C5FD"),
    WindowTopbarButtonIcon = colorFromHex("CBD5E1"),
    WindowTopbarTitle = colorFromHex("F8FAFC"),
    WindowTopbarAuthor = colorFromHex("94A3B8"),
    WindowTopbarIcon = colorFromHex("93C5FD"),
    TabBackground = colorFromHex("1E293B"),
    TabTitle = colorFromHex("CBD5E1"),
    TabIcon = colorFromHex("94A3B8"),
    ElementBackground = colorFromHex("172033"),
    ElementTitle = colorFromHex("F8FAFC"),
    ElementDesc = colorFromHex("94A3B8"),
    ElementIcon = colorFromHex("CBD5E1"),
    PopupBackground = colorFromHex("111827"),
    PopupBackgroundTransparency = 0.02,
    PopupTitle = colorFromHex("F8FAFC"),
    PopupContent = colorFromHex("CBD5E1"),
    PopupIcon = colorFromHex("93C5FD"),
    Toggle = colorFromHex("2563EB"),
    ToggleBar = colorFromHex("E2E8F0"),
    Checkbox = colorFromHex("2563EB"),
    CheckboxIcon = colorFromHex("FFFFFF"),
    Slider = colorFromHex("3B82F6"),
    SliderThumb = colorFromHex("FFFFFF"),
    Danger = colorFromHex("EF4444"),
    Success = colorFromHex("22C55E"),
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
    "ToggleBar", "Checkbox", "CheckboxIcon", "Slider", "SliderThumb", "Danger", "Success",
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

function Seraph:ResolveIcon(source)
    if type(source) == "table" then
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
            else
                success, provided = pcall(function()
                    return self.IconProvider[source] or self.IconProvider[source:lower()]
                end)
            end
            if success and provided then
                return assetId(provided)
            end
        end
        return assetId(source)
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
    local icon = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = Seraph:ResolveIcon(source),
        Size = UDim2.fromOffset(size or 20, size or 20),
        ScaleType = Enum.ScaleType.Fit,
        ImageColor3 = self.Theme[role or "Icon"],
    }, parent)
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
        disconnectAll(self._connections)
        if self.Instance then
            self.Instance:Destroy()
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

function Window:_registerElement(element, options)
    if options and options.Flag then
        element:_setFlag(options.Flag)
    end
    self._elements[#self._elements + 1] = element
    return element
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
    addStroke(row, self:_color("Outline"), 0.82, 1)
    self:_bind(row, "BackgroundColor3", "ElementBackground")

    local content = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    }, row)
    addPadding(content, 12, 12, 9, 9)
    local rowLayout = addList(content, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    local textHolder = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -130, 1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, content)
    local textLayout = addList(textHolder, Enum.FillDirection.Vertical, 2)
    textLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    local titleLine = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
    }, textHolder)
    local titleLabel = self:_textLabel(titleLine, options and options.Title or "Element", 14, "ElementTitle", {
        Size = UDim2.new(1, -80, 1, 0),
        Font = Enum.Font.GothamMedium,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    if options and options.Tag then
        local tagText = type(options.Tag) == "table" and options.Tag.Text or options.Tag
        local tagLabel = self:_textLabel(titleLine, tostring(tagText), 10, "Accent", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(70, 18),
            TextXAlignment = Enum.TextXAlignment.Center,
            BackgroundColor3 = self:_color("Accent"),
            BackgroundTransparency = 0.1,
            TextColor3 = self:_color("Text"),
        })
        addCorner(tagLabel, 5)
        self:_bind(tagLabel, "BackgroundColor3", "Accent")
        self:_bind(tagLabel, "TextColor3", "Text")
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
        if x + popup.AbsoluteSize.X > screenSize.X then
            x = screenSize.X - popup.AbsoluteSize.X - 8
        end
        if y + popup.AbsoluteSize.Y > screenSize.Y then
            y = position.Y - popup.AbsoluteSize.Y - 5
        end
        popup.Position = UDim2.fromOffset(math.max(8, x), math.max(8, y))
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
    if title and trim(title) ~= "" then
        self.Window:_textLabel(sectionFrame, title, 13, "Text", {
            Size = UDim2.new(1, 0, 0, 22),
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
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
    }, Section)
    self.Sections[#self.Sections + 1] = section
    return section
end

Tab.AddSection = Tab.Section

function Section:_finish(element, options)
    self.Elements[#self.Elements + 1] = element
    return self.Window:_registerElement(element, options or {})
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
    self.Window:_bind(track, "BackgroundColor3", "Toggle")
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
    connectInput(track, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            element:Set(not element.Value)
        end
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
    local increment = tonumber(options.Rounding or options.Step) or 1
    local initial = tonumber(options.Default or options.Value)
    if initial == nil then
        initial = minimum
    end
    initial = clamp(initial, minimum, maximum)
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 72)
    control.Size = UDim2.fromOffset(145, 54)
    local valueLabel = self.Window:_textLabel(control, "", 11, "ElementDesc", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(60, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local bar = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 29),
        Size = UDim2.new(1, 0, 0, 6),
        Text = "",
    }, control)
    addCorner(bar, 3)
    self.Window:_bind(bar, "BackgroundColor3", "TabBackground")
    local fill = create("Frame", {
        BackgroundColor3 = self.Window:_color("Slider"),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
    }, bar)
    addCorner(fill, 3)
    self.Window:_bind(fill, "BackgroundColor3", "Slider")
    local thumb = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self.Window:_color("SliderThumb"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(16, 16),
    }, bar)
    addCorner(thumb, 8)
    self.Window:_bind(thumb, "BackgroundColor3", "SliderThumb")
    local element = self.Window:_newElement("Slider", row, initial, options.Callback)
    local function setFromPercent(percent, silent)
        percent = clamp(percent, 0, 1)
        local rawValue = minimum + (maximum - minimum) * percent
        local nextValue = round(rawValue / increment, 0) * increment
        nextValue = clamp(nextValue, minimum, maximum)
        local normalized = (nextValue - minimum) / math.max(0.0001, maximum - minimum)
        element.Value = nextValue
        fill.Size = UDim2.new(normalized, 0, 1, 0)
        thumb.Position = UDim2.new(normalized, 0, 0.5, 0)
        valueLabel.Text = tostring(nextValue)
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
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
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
    local initial = options.Default or options.Value or values[1]
    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 56)
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window:_color("TabBackground"),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(145, 34),
        Text = tostring(initial or "Select"),
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
    element._setValue = function(selfElement, value, silent)
        selfElement.Value = value
        button.Text = tostring(value or "Select")
        if not silent then
            safeCall(selfElement.Callback, value)
        end
    end
    button.Activated:Connect(function()
        local popup = self.Window:_popupFrame(220, math.min(300, 46 + math.max(1, #values) * 34))
        self.Window:_positionPopup(popup, button)
        addPadding(popup, 8, 8, 8, 8)
        local list = addList(popup, Enum.FillDirection.Vertical, 5)
        for index, value in ipairs(values) do
            local optionButton = self.Window:_makePopupButton(popup, tostring(value), index)
            optionButton.Activated:Connect(function()
                element:Set(value)
                self.Window:_closePopups()
            end)
        end
    end)
    element:_setValue(initial, true)
    return self:_finish(element, options)
end

function Section:MultiDropdown(options)
    options = options or {}
    local values = options.Values or options.Options or {}
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
        button.Text = #current == 0 and "Select" or table.concat(current, ", ")
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
            local checkLabel = self.Window:_textLabel(optionButton, "", 12, "PopupContent", {
                Size = UDim2.new(1, 0, 1, 0),
            })
            local function refresh()
                checkLabel.Text = (selected[value] and "[x] " or "[ ] ") .. tostring(value)
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
    addStroke(swatch, self:_color("Outline"), 0.4, 1)
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
        local popup = self.Window:_popupFrame(250, 155)
        self.Window:_positionPopup(popup, swatch)
        addPadding(popup, 12, 12, 12, 12)
        local layout = addList(popup, Enum.FillDirection.Vertical, 7)
        local inputs = {}
        local function channel(value)
            return math.floor(clamp(value, 0, 1) * 255 + 0.5)
        end
        local channels = {
            {Name = "Red", Value = channel(initial.R)},
            {Name = "Green", Value = channel(initial.G)},
            {Name = "Blue", Value = channel(initial.B)},
        }
        for index, data in ipairs(channels) do
            local input = create("TextBox", {
                BackgroundColor3 = self.Window:_color("TabBackground"),
                BorderSizePixel = 0,
                ClearTextOnFocus = false,
                PlaceholderText = data.Name,
                Text = tostring(data.Value),
                TextColor3 = self.Window:_color("PopupContent"),
                TextSize = 12,
                Font = Enum.Font.Gotham,
                Size = UDim2.new(1, 0, 0, 26),
                LayoutOrder = index,
            }, popup)
            addCorner(input, 6)
            addPadding(input, 8, 8, 0, 0)
            self.Window:_bind(input, "BackgroundColor3", "TabBackground")
            self.Window:_bind(input, "TextColor3", "PopupContent")
            inputs[index] = input
        end
        local apply = self.Window:_makePopupButton(popup, "Apply", 5)
        apply.BackgroundColor3 = self.Window:_color("Button")
        apply.Activated:Connect(function()
            local red = clamp(tonumber(inputs[1].Text) or 0, 0, 255)
            local green = clamp(tonumber(inputs[2].Text) or 0, 0, 255)
            local blue = clamp(tonumber(inputs[3].Text) or 0, 0, 255)
            element:Set(Color3.fromRGB(red, green, blue))
            self.Window:_closePopups()
        end)
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

    local row, content, textHolder, titleLabel, control = self.Window:_row(self, options, 150)
    control:Destroy()
    textHolder.Size = UDim2.new(1, -24, 1, 0)
    local playerArea = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 44),
        Size = UDim2.new(1, -24, 0, 98),
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
    for _, button in ipairs({back, play, nextButton}) do
        addCorner(button, 7)
        self.Window:_bind(button, "TextColor3", "Text")
    end
    self.Window:_bind(back, "BackgroundColor3", "TabBackground")
    self.Window:_bind(play, "BackgroundColor3", "Button")
    self.Window:_bind(nextButton, "BackgroundColor3", "TabBackground")
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

    local function updateTrackLabel()
        local track = normalizedPlaylist[element.CurrentIndex]
        trackLabel.Text = (track and track.Name or "No tracks") .. "  " .. tostring(element.CurrentIndex) .. "/" .. tostring(#normalizedPlaylist)
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
        return true
    end
    element.Destroy = function(selfElement)
        selfElement:Stop()
        for sound, original in pairs(selfElement._gameSoundVolumes) do
            if sound and sound.Parent then
                sound.Volume = original
            end
        end
        selfElement._gameSoundVolumes = {}
        musicSound:Destroy()
        disconnectAll(selfElement._connections)
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
        self._tag.Position = UDim2.fromOffset(118, 28)
    elseif side == "center" then
        self._tag.AnchorPoint = Vector2.new(0.5, 0.5)
        self._tag.Position = UDim2.new(0.5, 0, 0.5, 0)
    else
        self._tag.AnchorPoint = Vector2.new(0, 0.5)
        self._tag.Position = UDim2.fromOffset(260, 28)
    end
    return self._tag
end

Window.AddTag = Window.SetTag

function Window:Notify(options)
    options = type(options) == "string" and {Content = options} or (options or {})
    local duration = tonumber(options.Duration) or 4
    local toast = create("Frame", {
        BackgroundColor3 = self:_color("PopupBackground"),
        BackgroundTransparency = self.Theme.PopupBackgroundTransparency or 0,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(300, options.Height or 74),
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
        Size = UDim2.fromOffset(4, 74),
        ZIndex = 71,
    }, toast)
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
            end)
        end
    end)
    tween(toast, {Position = UDim2.new(1, -14, 1, -14)}, 0.25)
    task.delay(duration, function()
        if toast.Parent then
            tween(toast, {Position = UDim2.new(1, 320, 1, -90)}, 0.22)
            task.delay(0.25, function()
                if toast.Parent then
                    toast:Destroy()
                end
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
    self.ResizeHandle.Visible = not self._minimized
    self.Main.Size = self._minimized and UDim2.new(0, self._size.X.Offset, 0, 56) or self._size
    self.Shadow.Size = self._minimized and UDim2.fromOffset(self._size.X.Offset + 18, 74) or UDim2.fromOffset(self._size.X.Offset + 18, self._size.Y.Offset + 18)
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
    for _, element in ipairs(self._elements) do
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
    "MultiDropdown",
    "Keybind",
    "Colorpicker",
    "ColorPicker",
    "Divider",
    "Space",
    "Paragraph",
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
    local window = setmetatable({
        Name = options.Name or options.Title or "Seraph",
        Title = options.Title or "Seraph",
        Author = options.Author or "Material UI",
        Folder = sanitizeName(options.Folder or options.Name or options.Title or "Seraph", "Seraph"),
        RootFolder = sanitizeName(options.RootFolder or "Workspace", "Workspace"),
        TabMode = normalizeTabMode(options.TabMode or options.TabStyle or "Left"),
        Theme = Seraph:GetTheme(options.Theme),
        _size = normalizeWindowSize(options.Size),
        _minSize = normalizeWindowSize(options.MinSize or {X = 520, Y = 360}),
        _alive = true,
        _connections = {},
        _bindings = {},
        _tabs = {},
        _elements = {},
        _flags = {},
        _popups = {},
        _popupConnections = {},
        _minimized = false,
    }, Window)
    table.insert(Seraph.Windows, window)

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
        Size = window._size + UDim2.fromOffset(18, 18),
        ZIndex = 0,
    }, screenGui)
    addCorner(shadow, 18)
    window:_bind(shadow, "BackgroundColor3", "WindowShadow")
    window.Shadow = shadow

    local main = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = window:_color("WindowBackground"),
        BackgroundTransparency = window.Theme.BackgroundTransparency or 0,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = window._size,
        ClipsDescendants = true,
        ZIndex = 1,
    }, screenGui)
    addCorner(main, 16)
    addStroke(main, window:_color("Outline"), 0.72, 1)
    window:_bind(main, "BackgroundColor3", "WindowBackground")
    window.Main = main

    local header = create("Frame", {
        BackgroundColor3 = window:_color("Background"),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 56),
        ZIndex = 3,
    }, main)
    window:_bind(header, "BackgroundColor3", "Background")
    local logo = window:_icon(header, options.Icon or Seraph.LogoAsset, 30, "WindowTopbarIcon")
    logo.Position = UDim2.fromOffset(16, 13)
    local title = window:_textLabel(header, window.Title, 15, "WindowTopbarTitle", {
        Position = UDim2.fromOffset(56, 8),
        Size = UDim2.new(0.52, -56, 0, 22),
        Font = Enum.Font.GothamMedium,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })
    local author = window:_textLabel(header, window.Author, 10, "WindowTopbarAuthor", {
        Position = UDim2.fromOffset(57, 30),
        Size = UDim2.new(0.52, -57, 0, 16),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })
    local tag = window:_textLabel(header, "", 10, "Accent", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromOffset(260, 28),
        Size = UDim2.fromOffset(84, 22),
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundColor3 = window:_color("Accent"),
        BackgroundTransparency = 0.1,
        TextColor3 = window:_color("Text"),
        Visible = false,
        ZIndex = 4,
    })
    addCorner(tag, 6)
    window:_bind(tag, "BackgroundColor3", "Accent")
    window:_bind(tag, "TextColor3", "Text")
    window._tag = tag

    local minimizeButton = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -72, 0, 16),
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
        Position = UDim2.new(1, -40, 0, 16),
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

    local body = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 56),
        Size = UDim2.new(1, 0, 1, -56),
        ZIndex = 2,
    }, main)
    window.Body = body

    local tabList
    local pages
    if window.TabMode == "Left" then
        tabList = create("ScrollingFrame", {
            Active = true,
            BackgroundColor3 = window:_color("Background"),
            BackgroundTransparency = 0.18,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Position = UDim2.fromOffset(10, 10),
            ScrollBarImageColor3 = window:_color("Accent"),
            ScrollBarThickness = 3,
            Size = UDim2.new(0, 154, 1, -20),
            ZIndex = 3,
        }, body)
        addCorner(tabList, 12)
        addPadding(tabList, 8, 8, 10, 10)
        local tabLayout = addList(tabList, Enum.FillDirection.Vertical, 7)
        tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabList.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 22)
        end)
        pages = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(174, 10),
            Size = UDim2.new(1, -184, 1, -20),
            ZIndex = 2,
        }, body)
    else
        tabList = create("ScrollingFrame", {
            Active = true,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Position = UDim2.fromOffset(10, 8),
            ScrollBarThickness = 0,
            ScrollingDirection = Enum.ScrollingDirection.X,
            Size = UDim2.new(1, -20, 0, 42),
            ZIndex = 3,
        }, body)
        local tabLayout = addList(tabList, Enum.FillDirection.Horizontal, 8)
        tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabList.CanvasSize = UDim2.fromOffset(tabLayout.AbsoluteContentSize.X + 18, 0)
        end)
        pages = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 58),
            Size = UDim2.new(1, -20, 1, -68),
            ZIndex = 2,
        }, body)
    end
    window.TabList = tabList
    window.Pages = pages
    window:_bind(tabList, "BackgroundColor3", "Background")

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
            shadow.Size = UDim2.fromOffset(width + 18, height + 18)
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
