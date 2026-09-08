# Seraph

Seraph
Основные цели библиотеки:

- аккуратное окно с логотипом, заголовком, автором, тегом, перемещением и изменением размера;
- вкладки слева или сверху;
- синие, белые и тёмные стандартные темы;
- runtime-регистрация собственных тем и иконок;
- реально работающие контролы и конфиги;
- понятный API, который можно использовать как через `Tab:Toggle(...)`, так и через явный `Section`.

## Быстрый старт

Опубликуйте `source.lua` в репозитории и подставьте его raw URL:

```lua
local Seraph = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToraScriptCopy/Seraph-ui-lib/main/source.lua"))()

local Window = Seraph:CreateWindow({
    Title = "My Seraph Window",
    Author = "My project",
    TabMode = "Left", -- "Left" или "Top"
    ToggleKey = Enum.KeyCode.RightShift,
})

local Tab = Window:Tab({
    Title = "Main",
    Icon = 17332630310,
})

Tab:Toggle({
    Title = "Enabled",
    Default = true,
    Callback = function(value)
        print(value)
    end,
})
```

Доступны псевдонимы `Seraph.CreateWindow`, `Seraph.Create` и `Seraph.Window`.

## Структура окна

```lua
local Window = Seraph:CreateWindow({
    Title = "Seraph Browser",
    Author = "Project name",
    Icon = 17332630292,
    Theme = "Seraph Dark",
    TabMode = "Left",
    Size = {X = 780, Y = 570},
    MinSize = {X = 520, Y = 360},
    Folder = "MyWindow",
    RootFolder = "Workspace",
    Tag = {Text = "BETA", Side = "right"},
})

local Tab = Window:Tab({
    Name = "Dashboard",
    Title = "Dashboard",
    Icon = 17332630310,
})

Tab:TabSection("Navigation") -- только для TabMode = "Left"
local Section = Tab:Section({Title = "Settings"})
```

`Side` у тега принимает `left`, `center` или `right`. У отдельного элемента можно указать `Tag = "Info"` или `Tag = {Text = "Info"}`.

Методы элементов доступны напрямую у вкладки и у секции:

```lua
Tab:Toggle({...})
Section:Toggle({...})
```

Если элемент создан через `Tab:Toggle`, библиотека помещает его в неявную default-секцию.

## Элементы

Поддерживаются:

`Toggle`, `Checkbox`, `Button`, `Slider`, `Keybind`, `Dropdown`, `MultiDropdown`, `Colorpicker`, `Input`, `Popup`, `Notify`, `Divider`, `Space`, `Paragraph`, `Code`, `Music`, `Section`, `TabSection`, `Tag`.

### Toggle

```lua
local toggle = Section:Toggle({
    Title = "Toggle",
    Desc = "Config Test Toggle",
    Default = false,
    Flag = "ToggleElement",
    Callback = function(value)
        print("Toggle Changed: " .. tostring(value))
    end,
})

toggle:Set(true)
local current = toggle:Get()
```

### Slider

```lua
local slider = Section:Slider({
    Title = "Opacity",
    Min = 0,
    Max = 100,
    Default = 50,
    Step = 5,
    Flag = "Opacity",
})
```

Поддерживаются поля `Min`/`Minimum`, `Max`/`Maximum`, `Step`/`Rounding`, `Default`/`Value`.

### Dropdown и MultiDropdown

```lua
local dropdown = Section:Dropdown({
    Title = "Profile",
    Values = {"Personal", "Work", "Testing"},
    Default = "Personal",
})

local multi = Section:MultiDropdown({
    Title = "Sites",
    Values = {"Docs", "GitHub", "Roblox"},
    Default = {"Docs", "GitHub"},
})
```

`Options` является псевдонимом `Values`. Для `MultiDropdown` значение callback — массив выбранных значений.

### Keybind

```lua
local keybind = Section:Keybind({
    Title = "Quick action",
    Default = Enum.KeyCode.F,
    OnPress = function(keyName)
        print("Pressed " .. keyName)
    end,
})
```

### Input, Colorpicker, Code

```lua
Section:Input({
    Title = "Search",
    Placeholder = "Enter text",
    Callback = function(value) print(value) end,
})

Section:Colorpicker({
    Title = "Accent",
    Default = Color3.fromRGB(59, 130, 246),
})

Section:Code({
    Title = "Snippet",
    Code = "print('hello')",
    Editable = false,
})
```

`Code` имеет кнопку Copy, если окружение предоставляет `setclipboard`.

### Notify и Popup

```lua
Window:Notify({
    Title = "Saved",
    Content = "The configuration was written.",
    Type = "Success",
    Duration = 3,
})

Window:Popup({
    Title = "Confirm",
    Content = "Continue?",
    Buttons = {
        {Text = "Yes", Primary = true, Callback = function() print("yes") end},
        {Text = "No"},
    },
})
```

### Music

Музыкальный элемент поддерживает один трек или плейлист, порядок, previous/next, autoplay следующего трека, отдельную громкость музыки и отдельную громкость игровых `Sound`-объектов:

```lua
local music = Section:Music({
    Title = "Playlist",
    Playlist = {
        {Id = 1843529634, Name = "Track one"},
        {Id = 1843529603, Name = "Track two"},
    },
    AutoPlay = false,
    AutoPlayNext = true,
    AllowReorder = true,
})

music:Play()
music:SetVolume(0.65)
music:Next()
music:MoveTrack(2, 1)
```

Игровая громкость сохраняет исходные значения громкости найденных `Sound`-объектов и применяет к ним коэффициент. Новые звуки, созданные игрой позже, не добавляются автоматически до следующего запуска snapshot-логики.

## Иконки

Иконка может быть:

- числовым asset ID;
- строкой `"rbxassetid://123"`;
- строкой с URL, если среда допускает такой Image source;
- таблицей `{AssetId = 123}` или `{Id = 123}`;
- именем, предварительно зарегистрированным через `RegisterIcon`.

```lua
Seraph:RegisterIcon("home", 17332630310)
Seraph:RegisterLucideIcon("settings", "rbxassetid://17332630292")

local Window = Seraph:CreateWindow({Icon = "home"})
```

Для реального внешнего Lucide-пакета можно передать таблицу или resolver-функцию:

```lua
local Lucide = {
    home = 17332630310,
    settings = 17332630292,
}

Seraph:UseLucide(Lucide)
-- или: Seraph:SetIconProvider(function(name) return Lucide[name] end)
```

`RegisterLucideIcon` — совместимый реестр имён. Библиотека не скачивает сторонний Lucide runtime и не делает фиктивное распознавание имён: конкретное имя должно быть сопоставлено с реальным Roblox image asset в вашем проекте. Это позволяет подключить любой Lucide-адаптер через одну таблицу регистраций.

Логотип по умолчанию настроен на предоставленные asset IDs: `17332630310` и `17332630292`.

## Темы

Встроены `Seraph Dark`, `Seraph Light` и `Seraph Midnight`. Новая тема наследуется от тёмной и может переопределить только нужные поля:

```lua
Seraph:AddTheme({
    Name = "My Theme",
    Accent = Color3.fromHex("#18181B"),
    Background = Color3.fromHex("#101010"),
    BackgroundTransparency = 0,
    Outline = Color3.fromHex("#FFFFFF"),
    Text = Color3.fromHex("#FFFFFF"),
    Placeholder = Color3.fromHex("#7A7A7A"),
    Button = Color3.fromHex("#52525B"),
    Icon = Color3.fromHex("#A1A1AA"),
    WindowBackground = Color3.fromHex("#101010"),
    WindowShadow = Color3.fromHex("#000000"),
    ElementBackground = Color3.fromHex("#202020"),
    ElementTitle = Color3.fromHex("#FFFFFF"),
    ElementDesc = Color3.fromHex("#A1A1AA"),
    Toggle = Color3.fromHex("#52525B"),
    ToggleBar = Color3.fromHex("#FFFFFF"),
    Slider = Color3.fromHex("#52525B"),
    SliderThumb = Color3.fromHex("#FFFFFF"),
})

Window:SetTheme("My Theme")
```

Доступны все роли из пользовательского примера: `Accent`, `Background`, `Outline`, `Text`, `Placeholder`, `Button`, `Icon`, `Hover`, `WindowBackground`, `WindowShadow`, `Dialog*`, `WindowTopbar*`, `Tab*`, `Element*`, `Popup*`, `Toggle`, `ToggleBar`, `Checkbox`, `CheckboxIcon`, `Slider`, `SliderThumb`. Дополнительно используются `Danger` и `Success` для уведомлений.

## ConfigManager

Каждый элемент с `Flag` автоматически попадает в `Window._flags` и сохраняется конфигом. Элемент можно зарегистрировать явно:

```lua
local ToggleElement = Tab:Toggle({
    Title = "Toggle",
    Flag = "ToggleElement",
    Callback = function(value)
        print(value)
    end,
})

local ConfigManager = Window.ConfigManager
local myConfig = ConfigManager:CreateConfig("config1")

myConfig:Register("toggleNameExample", ToggleElement)
myConfig:Save()
myConfig:Load()
```

Доступны методы `Register`, `Unregister`, `Save`, `Load`, `Delete`, `Exists`, `GetPath`, а у менеджера — `List`.

По умолчанию файлы создаются в дереве:

```text
Workspace/
└── Seraph/
    └── {Window.Folder}/
        └── config/
            └── config1.json
```

Фактическая возможность создания файлов зависит от окружения. Библиотека проверяет наличие `makefolder`, `writefile`, `readfile`, `isfile`, `listfiles`, `delfile` и не падает, если они недоступны.

## ArxProtect: безопасный режим

В библиотеку включён `Seraph.ArxProtect` для локального запечатывания JSON конфигураций. Это простая reversible-защита состояния на основе XOR+Base64, предназначенная для сокрытия случайного чтения конфигов, а не для криптографической безопасности.

```lua
local Window = Seraph:CreateWindow({
    ConfigProtection = true,
    ConfigKey = "private-key",
    AutoSealConfig = true,
    ConfigProtectionInterval = 30,
})

Window:ConfigureProtection({
    Enabled = true,
    Key = "private-key",
    AutoSeal = true,
    Interval = 30,
})
```

`ArxProtect:Seal`, `Unseal`, `SealTable`, `UnsealTable` доступны напрямую. Ключ находится на клиенте, поэтому этот режим не заменяет серверную валидацию и не должен использоваться для хранения секретов.

Намеренно не реализованы механизмы скрытия UI от обнаружения, обхода анализа, маскировки иерархии или защиты от средств безопасности. В Roblox клиентский интерфейс всегда доступен клиенту, а попытка обходить анализ создаёт небезопасное и ненадёжное поведение. Для защиты данных используйте серверную авторизацию, RemoteEvent-проверки и минимизацию чувствительных значений на клиенте.

## Управление окном

```lua
Window:Toggle()
Window:SetVisible(true)
Window:Minimize()
Window:SetTag("BETA", {Side = "center"})
Window:BindKey(Enum.KeyCode.RightShift, function(window)
    window:Toggle()
end)
Window:Destroy()
Seraph:DestroyAll()
```

## Файлы

- `source.lua` — библиотека, готовая для публикации как raw-файл.
- `example.lua` — полный пример с темой, вкладками, элементами, музыкой и конфигом.
- `README.md` — подробная документация для GitHub.
- `RawDocumentation.md` — компактная структурированная документация.
- `RawDocumentation.txt` — plain-text версия документации.
