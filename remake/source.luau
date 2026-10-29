--[[
	MacLib v2.0
	-----------------------------------------------------------------------
	A rewrite of MacLib with the same public API, plus:

	  WINDOW
	  * Working macOS traffic lights (red = exit, yellow = minimize, green = maximize / restore)
	    with hover glyphs, press feedback and disabled states
	  * Pop-in / pop-out window animations, smooth dragging, double-click topbar to maximize
	  * Sliding tab indicator, animated tab transitions, staggered section fade-in
	  * Themes + live accent colour (Window:SetTheme / Window:SetAccent), animated recolouring
	  * Optional sidebar tab search (Settings.TabSearch = true)
	  * Tooltips (Tooltip = "text" on any element)

	  ELEMENTS
	  * Button  : ripple click effect, hover slide, optional Description
	  * Toggle  : accent pill, stretchy knob, optional Description
	  * Slider  : accent fill, growing knob, Step support, typed input, animated
	  * Input   : accent focus ring, cleaner character filters
	  * Keybind : listening state, Escape to clear, no accidental re-trigger
	  * Dropdown: animated open/close, staggered options, scrollable list, search,
	              click-outside to close, single + multi select
	  * Colorpicker: animated modal, wheel / value bar / RGB / hex / alpha
	  * NEW ProgressBar element, optional section titles

	  FEEDBACK
	  * Notifications: Info / Success / Warning / Error types, progress timer, slide-in/out,
	    stack collapses smoothly
	  * Dialogs: animated backdrop + pop, horizontal buttons, Primary / Destructive styles

	  FIXES vs v1
	  * Keybind blacklist typo, UpdateName on Slider/Keybind assigning a variable instead of Text,
	    Slider text-box fallback bug, Colorpicker SetAlpha property bug, number -> Text assignments,
	    config functions returning a string instead of (false, reason), mojibake check characters,
	    notifications/dialogs not scaling with UIScale, listeners never disconnected on Unload,
	    mouse-position mismatch with ScreenInsets.None

	Usage is identical to v1 (see MacLib:Demo() at the bottom).
]]

local MacLib = {
	Options = {},
	Folder = "Maclib",
	Version = "2.0.0",
	GetService = function(service)
		return cloneref and cloneref(game:GetService(service)) or game:GetService(service)
	end,
}

--// Services
local TweenService = MacLib.GetService("TweenService")
local RunService = MacLib.GetService("RunService")
local HttpService = MacLib.GetService("HttpService")
local ContentProvider = MacLib.GetService("ContentProvider")
local UserInputService = MacLib.GetService("UserInputService")
local Lighting = MacLib.GetService("Lighting")
local Players = MacLib.GetService("Players")
local Debris = MacLib.GetService("Debris")

--// Variables
local isStudio = RunService:IsStudio()
local LocalPlayer = Players.LocalPlayer

local Auto = Enum.AutomaticSize
local TXA = Enum.TextXAlignment
local TYA = Enum.TextYAlignment
local FillDir = Enum.FillDirection
local HAlign = Enum.HorizontalAlignment
local VAlign = Enum.VerticalAlignment
local Weight = Enum.FontWeight
local Ease = Enum.EasingStyle
local EDir = Enum.EasingDirection

local CHECK = "\u{2713}"
local CROSS = "\u{2715}"
local DOT = "\u{2022}"

local CONTROLS_H = 38
local INFO_H = 64
local USER_H = 64
local TOPBAR_H = 56

local assets = {
	interFont = "rbxassetid://12187365364",
	userInfoBlurred = "rbxassetid://18824089198",
	buttonImage = "rbxassetid://10709791437",
	searchIcon = "rbxassetid://86737463322606",
	colorWheel = "rbxassetid://2849458409",
	colorTarget = "rbxassetid://73265255323268",
	grid = "rbxassetid://121484455191370",
	globe = "rbxassetid://108952102602834",
	transform = "rbxassetid://90336395745819",
	dropdown = "rbxassetid://18865373378",
}

MacLib.Themes = {
	Dark = {
		Accent = Color3.fromRGB(10, 132, 255),
		Background = Color3.fromRGB(15, 15, 15),
		Surface = Color3.fromRGB(24, 24, 26),
	},
	Midnight = {
		Accent = Color3.fromRGB(110, 108, 255),
		Background = Color3.fromRGB(10, 12, 22),
		Surface = Color3.fromRGB(18, 21, 36),
	},
	Rose = {
		Accent = Color3.fromRGB(255, 55, 95),
		Background = Color3.fromRGB(17, 13, 15),
		Surface = Color3.fromRGB(28, 21, 24),
	},
	Forest = {
		Accent = Color3.fromRGB(48, 209, 88),
		Background = Color3.fromRGB(12, 16, 13),
		Surface = Color3.fromRGB(20, 26, 22),
	},
	Amber = {
		Accent = Color3.fromRGB(255, 159, 10),
		Background = Color3.fromRGB(17, 15, 12),
		Surface = Color3.fromRGB(28, 24, 19),
	},
}

--// Helpers ---------------------------------------------------------------

local function Play(instance, time, props, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Ease.Quint, direction or EDir.Out),
		props
	)
	tween:Play()
	return tween
end

-- Kept for backwards compatibility with v1 (returns an un-played tween)
local function Tween(instance, tweeninfo, propertytable)
	return TweenService:Create(instance, tweeninfo, propertytable)
end

local GUI_CLASSES = {
	Frame = true, TextLabel = true, TextButton = true, TextBox = true,
	ImageLabel = true, ImageButton = true, ScrollingFrame = true, CanvasGroup = true,
}
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function F(weight)
	return Font.new(assets.interFont, weight or Weight.Regular, Enum.FontStyle.Normal)
end

-- Instance factory with sane defaults (transparent, borderless, Inter font, white text)
local function New(class, props, children)
	local inst = Instance.new(class)
	if GUI_CLASSES[class] then
		inst.BorderSizePixel = 0
		inst.BackgroundColor3 = Color3.new(1, 1, 1)
		inst.BackgroundTransparency = 1
	end
	if TEXT_CLASSES[class] then
		inst.FontFace = F()
		inst.TextColor3 = Color3.new(1, 1, 1)
		inst.TextSize = 13
		inst.Text = ""
		if class ~= "TextBox" then
			inst.RichText = true
		end
	end
	if class == "TextButton" or class == "ImageButton" then
		inst.AutoButtonColor = false
	end
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				inst[k] = v
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function Corner(radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

local function Stroke(transparency, color)
	return New("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Color3.new(1, 1, 1),
		Transparency = transparency or 0.9,
	})
end

local function Pad(l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0),
	})
end

local function List(padding, direction, halign, valign)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = direction or FillDir.Vertical,
		HorizontalAlignment = halign or HAlign.Left,
		VerticalAlignment = valign or VAlign.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

local function MouseXY()
	return UserInputService:GetMouseLocation()
end

local function IsInside(guiObject, position)
	local p, s = guiObject.AbsolutePosition, guiObject.AbsoluteSize
	return position.X >= p.X and position.X <= p.X + s.X and position.Y >= p.Y and position.Y <= p.Y + s.Y
end

local function GetGui()
	local gui = Instance.new("ScreenGui")
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2147483647

	local parent
	if isStudio then
		parent = LocalPlayer:WaitForChild("PlayerGui")
	elseif gethui then
		parent = gethui()
	else
		parent = MacLib.GetService("CoreGui")
	end
	gui.Parent = parent
	return gui
end

local function FilterText(kind, value, limit)
	local result = value
	if type(kind) == "function" then
		result = kind(value)
	elseif kind == "Numeric" then
		local negative = value:sub(1, 1) == "-"
		local digits = value:gsub("[^%d]", "")
		result = (negative and "-" or "") .. digits
	elseif kind == "Alphabetic" then
		result = (value:gsub("[^a-zA-Z ]", ""))
	elseif kind == "AlphaNumeric" then
		result = (value:gsub("[^a-zA-Z0-9]", ""))
	end
	if limit then
		result = result:sub(1, limit)
	end
	return result
end

local function KeyName(bind)
	if bind == nil then
		return "None"
	end
	return bind.Name
end

--// Config system ----------------------------------------------------------

local function ConfigAvailable()
	return (not isStudio) and writefile and readfile and isfile and isfolder and makefolder and listfiles and true or false
end

local function BuildFolderTree()
	if not ConfigAvailable() then
		return false
	end
	for _, path in ipairs({ MacLib.Folder, MacLib.Folder .. "/settings" }) do
		if not isfolder(path) then
			makefolder(path)
		end
	end
	return true
end

local function Color3ToHex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function HexToColor3(hex)
	hex = hex:gsub("#", "")
	if #hex == 3 then
		hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
	end
	if #hex ~= 6 then
		return nil
	end
	local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(r, g, b)
end

local ClassParser = {
	Toggle = {
		Save = function(flag, data)
			return { type = "Toggle", flag = flag, state = data.State and true or false }
		end,
		Load = function(flag, data)
			if MacLib.Options[flag] and data.state ~= nil then
				MacLib.Options[flag]:UpdateState(data.state)
			end
		end,
	},
	Slider = {
		Save = function(flag, data)
			return { type = "Slider", flag = flag, value = data.Value and tostring(data.Value) or false }
		end,
		Load = function(flag, data)
			if MacLib.Options[flag] and data.value then
				MacLib.Options[flag]:UpdateValue(data.value)
			end
		end,
	},
	Input = {
		Save = function(flag, data)
			return { type = "Input", flag = flag, text = data.Text }
		end,
		Load = function(flag, data)
			if MacLib.Options[flag] and type(data.text) == "string" then
				MacLib.Options[flag]:UpdateText(data.text)
			end
		end,
	},
	Keybind = {
		Save = function(flag, data)
			local bind = data.Bind
			return {
				type = "Keybind",
				flag = flag,
				bind = typeof(bind) == "EnumItem" and bind.Name or nil,
				bindType = typeof(bind) == "EnumItem" and tostring(bind.EnumType) or nil,
			}
		end,
		Load = function(flag, data)
			if MacLib.Options[flag] and data.bind then
				local enum = (data.bindType == "Enum.UserInputType") and Enum.UserInputType or Enum.KeyCode
				local item = enum[data.bind]
				if item then
					MacLib.Options[flag]:Bind(item)
				end
			end
		end,
	},
	Dropdown = {
		Save = function(flag, data)
			return { type = "Dropdown", flag = flag, value = data.Value }
		end,
		Load = function(flag, data)
			if MacLib.Options[flag] and data.value then
				MacLib.Options[flag]:UpdateSelection(data.value)
			end
		end,
	},
	Colorpicker = {
		Save = function(flag, data)
			return { type = "Colorpicker", flag = flag, color = Color3ToHex(data.Color), alpha = data.Alpha or nil }
		end,
		Load = function(flag, data)
			if MacLib.Options[flag] and data.color then
				local color = HexToColor3(data.color)
				if color then
					MacLib.Options[flag]:SetColor(color)
					if data.alpha then
						MacLib.Options[flag]:SetAlpha(data.alpha)
					end
				end
			end
		end,
	},
}

function MacLib:SetFolder(Folder)
	MacLib.Folder = Folder
	BuildFolderTree()
end

function MacLib:SaveConfig(Path)
	if not ConfigAvailable() then
		return false, "Config system unavailable."
	end
	if not Path or Path == "" then
		return false, "Please select a config file."
	end
	BuildFolderTree()

	local data = { objects = {} }
	for flag, option in pairs(MacLib.Options) do
		local parser = ClassParser[option.Class]
		if parser and not option.IgnoreConfig then
			table.insert(data.objects, parser.Save(flag, option))
		end
	end

	local success, encoded = pcall(HttpService.JSONEncode, HttpService, data)
	if not success then
		return false, "Unable to encode into JSON data"
	end

	writefile(MacLib.Folder .. "/settings/" .. Path .. ".json", encoded)
	return true
end

function MacLib:LoadConfig(Path)
	if not ConfigAvailable() then
		return false, "Config system unavailable."
	end
	if not Path or Path == "" then
		return false, "Please select a config file."
	end

	local file = MacLib.Folder .. "/settings/" .. Path .. ".json"
	if not isfile(file) then
		return false, "Invalid file"
	end

	local success, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(file))
	if not success or type(decoded) ~= "table" or type(decoded.objects) ~= "table" then
		return false, "Unable to decode JSON data."
	end

	for _, option in ipairs(decoded.objects) do
		local parser = ClassParser[option.type]
		if parser then
			task.spawn(parser.Load, option.flag, option)
		end
	end
	return true
end

function MacLib:RefreshConfigList()
	if not ConfigAvailable() then
		return {}
	end
	if not (isfolder(MacLib.Folder) and isfolder(MacLib.Folder .. "/settings")) then
		return {}
	end

	local out = {}
	for _, file in ipairs(listfiles(MacLib.Folder .. "/settings")) do
		local name = file:match("([^/\\]+)%.json$")
		if name and name ~= "options" then
			table.insert(out, name)
		end
	end
	return out
end

function MacLib:LoadAutoLoadConfig()
	if not ConfigAvailable() then
		return false
	end
	local path = MacLib.Folder .. "/settings/autoload.txt"
	if not isfile(path) then
		return false
	end

	local name = readfile(path)
	local success, err = MacLib:LoadConfig(name)
	local window = MacLib.CurrentWindow
	if window then
		window:Notify({
			Title = "Interface",
			Description = success and string.format("Autoloaded config: %q", name) or ("Error loading autoload config: " .. tostring(err)),
			Type = success and "Success" or "Error",
		})
	end
	return success
end

--// Library ---------------------------------------------------------------

function MacLib:Window(Settings)
	Settings = Settings or {}
	local WindowFunctions = { Settings = Settings }
	MacLib.CurrentWindow = WindowFunctions

	local connections = {}
	local function Connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(connections, connection)
		return connection
	end

	local unloaded = false
	local windowState = true
	local maximized = false
	local userScale = Settings.Scale or 1
	local acrylicBlur = Settings.AcrylicBlur ~= false
	local onUnloadCallback

	----------------------------------------------------------------------
	-- Theme
	----------------------------------------------------------------------
	local Theme = {}
	do
		local preset = MacLib.Themes[Settings.Theme or "Dark"] or MacLib.Themes.Dark
		for k, v in pairs(preset) do
			Theme[k] = v
		end
		if Settings.Accent then
			Theme.Accent = Settings.Accent
		end
	end

	local Bound, Listeners = {}, {}

	local function Bind(inst, prop, key)
		inst[prop] = Theme[key]
		local entry = { inst, prop, key }
		Bound[entry] = true
		inst.Destroying:Connect(function()
			Bound[entry] = nil
		end)
	end

	-- fn(instant) is called now and whenever the theme changes
	local function OnTheme(owner, fn)
		Listeners[fn] = true
		owner.Destroying:Connect(function()
			Listeners[fn] = nil
		end)
		fn(true)
	end

	local function ApplyTheme(newTheme)
		for k, v in pairs(newTheme) do
			Theme[k] = v
		end
		for entry in pairs(Bound) do
			Play(entry[1], 0.35, { [entry[2]] = Theme[entry[3]] })
		end
		for fn in pairs(Listeners) do
			task.spawn(fn, false)
		end
	end

	----------------------------------------------------------------------
	-- Root, notifications, tooltip
	----------------------------------------------------------------------
	local macLib = GetGui()
	macLib.Name = "MacLib"
	macLib.Enabled = false

	local notifications = New("Frame", {
		Name = "Notifications",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = macLib,
	}, {
		List(8, FillDir.Vertical, HAlign.Right, VAlign.Bottom),
		Pad(14, 14, 14, 14),
	})

	local tooltipLabel = New("TextLabel", {
		Name = "Text",
		AutomaticSize = Auto.XY,
		TextSize = 12,
		TextTransparency = 1,
		ZIndex = 101,
	})
	local tooltip = New("Frame", {
		Name = "Tooltip",
		AutomaticSize = Auto.XY,
		BackgroundColor3 = Color3.fromRGB(30, 30, 33),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 100,
		Parent = macLib,
	}, { Corner(6), Stroke(0.85), Pad(9, 5, 9, 5), tooltipLabel })

	local tipToken = 0
	local function AttachTooltip(inst, text)
		if not text then
			return
		end
		inst.MouseEnter:Connect(function()
			tipToken = tipToken + 1
			local mine = tipToken
			task.delay(0.45, function()
				if mine ~= tipToken or unloaded then
					return
				end
				tooltipLabel.Text = text
				tooltip.Visible = true
				Play(tooltip, 0.2, { BackgroundTransparency = 0.05 })
				Play(tooltipLabel, 0.2, { TextTransparency = 0.1 })
			end)
		end)
		inst.MouseLeave:Connect(function()
			tipToken = tipToken + 1
			tooltip.Visible = false
			tooltip.BackgroundTransparency = 1
			tooltipLabel.TextTransparency = 1
		end)
	end

	Connect(RunService.RenderStepped, function()
		if tooltip.Visible then
			local m = MouseXY()
			local vp = macLib.AbsoluteSize
			local size = tooltip.AbsoluteSize
			local x = math.min(m.X + 14, vp.X - size.X - 6)
			local y = math.min(m.Y + 18, vp.Y - size.Y - 6)
			tooltip.Position = UDim2.fromOffset(x, y)
		end
	end)

	----------------------------------------------------------------------
	-- Base window
	----------------------------------------------------------------------
	local animValue = Instance.new("NumberValue")
	animValue.Value = 0.88

	local baseUIScale = New("UIScale", { Scale = userScale * 0.88 })
	Connect(animValue.Changed, function(v)
		baseUIScale.Scale = userScale * v
	end)

	local function baseTransparency()
		return acrylicBlur and 0.05 or 0
	end

	local base = New("Frame", {
		Name = "Base",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = Settings.Size or UDim2.fromOffset(868, 650),
		BackgroundTransparency = 1,
		Parent = macLib,
	}, { baseUIScale, Corner(12), Stroke(0.88) })
	Bind(base, "BackgroundColor3", "Background")

	local function Ripple(host, scaleOverride)
		local m = MouseXY()
		local ap = host.AbsolutePosition
		local s = scaleOverride or baseUIScale.Scale
		local size = math.max(host.AbsoluteSize.X, host.AbsoluteSize.Y) / s * 2.4
		local circle = New("Frame", {
			Name = "Ripple",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((m.X - ap.X) / s, (m.Y - ap.Y) / s),
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 0.86,
			ZIndex = 2,
			Parent = host,
		}, { Corner(999) })
		Play(circle, 0.6, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 })
		Debris:AddItem(circle, 0.65)
	end

	----------------------------------------------------------------------
	-- Sidebar
	----------------------------------------------------------------------
	local sidebarWidth = Settings.SidebarWidth or 250
	local defaultSidebarWidth = sidebarWidth

	local sidebar = New("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, sidebarWidth, 1, 0),
		Parent = base,
	})

	local sidebarDivider = New("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundTransparency = 0.9,
		Parent = sidebar,
	})

	local dividerInteract = New("TextButton", {
		Name = "DividerInteract",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 8, 1, 0),
		ZIndex = 5,
		Parent = sidebarDivider,
	})

	local content = New("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(sidebarWidth, 0),
		Size = UDim2.new(1, -sidebarWidth, 1, 0),
		ClipsDescendants = true,
		Parent = base,
	})

	local function SetSidebarWidth(width)
		sidebarWidth = width
		sidebar.Size = UDim2.new(0, width, 1, 0)
		content.Position = UDim2.fromOffset(width, 0)
		content.Size = UDim2.new(1, -width, 1, 0)
	end

	do
		local resizing, startX, startWidth = false, 0, 0
		local mouse = LocalPlayer and LocalPlayer:GetMouse()

		dividerInteract.MouseEnter:Connect(function()
			Play(sidebarDivider, 0.2, { BackgroundTransparency = 0.7 })
			if mouse then
				mouse.Icon = "rbxasset://SystemCursors/SizeEW"
			end
		end)
		dividerInteract.MouseLeave:Connect(function()
			if not resizing then
				Play(sidebarDivider, 0.2, { BackgroundTransparency = 0.9 })
				if mouse then
					mouse.Icon = ""
				end
			end
		end)
		dividerInteract.MouseButton1Down:Connect(function()
			if maximized and false then
				return
			end
			resizing = true
			startX = MouseXY().X
			startWidth = sidebarWidth
		end)
		Connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and resizing then
				resizing = false
				Play(sidebarDivider, 0.2, { BackgroundTransparency = 0.9 })
				if mouse then
					mouse.Icon = ""
				end
			end
		end)
		Connect(UserInputService.InputChanged, function(input)
			if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = (MouseXY().X - startX) / baseUIScale.Scale
				local width = startWidth + delta
				local maxWidth = base.AbsoluteSize.X / baseUIScale.Scale - 320
				if math.abs(width - defaultSidebarWidth) < 14 then
					width = defaultSidebarWidth
				else
					width = math.clamp(width, 150, math.max(180, maxWidth))
				end
				SetSidebarWidth(width)
			end
		end)
	end

	----------------------------------------------------------------------
	-- Traffic lights
	----------------------------------------------------------------------
	local controls = New("Frame", {
		Name = "WindowControls",
		Size = UDim2.new(1, 0, 0, CONTROLS_H),
		Parent = sidebar,
	}, { List(8, FillDir.Horizontal, HAlign.Left, VAlign.Center), Pad(15, 0, 0, 0) })

	New("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 0.92,
		Parent = controls,
	})

	local lights = {}
	local hoverCount = 0

	local function SetGlyphs(show)
		for _, light in pairs(lights) do
			Play(light.glyph, 0.15, { TextTransparency = show and 0.25 or 1 })
		end
	end

	local function MakeLight(name, color, order, glyph, callback)
		local disabled = Settings.DisabledWindowControls and table.find(Settings.DisabledWindowControls, name) and true or false
		local button = New("TextButton", {
			Name = name,
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = disabled and Color3.fromRGB(72, 72, 74) or color,
			BackgroundTransparency = 0,
			LayoutOrder = order,
			Parent = controls,
		}, { Corner(999), Stroke(0.88) })

		local glyphLabel = New("TextLabel", {
			Name = "Glyph",
			Size = UDim2.fromScale(1, 1),
			Text = glyph,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(40, 20, 20),
			TextTransparency = 1,
			FontFace = F(Weight.Bold),
			Parent = button,
		})

		lights[name] = { button = button, glyph = glyphLabel }

		if disabled then
			button.Active = false
			button.Interactable = false
			glyphLabel.Visible = false
			return
		end

		button.MouseEnter:Connect(function()
			hoverCount = hoverCount + 1
			SetGlyphs(true)
		end)
		button.MouseLeave:Connect(function()
			hoverCount = math.max(0, hoverCount - 1)
			task.defer(function()
				if hoverCount == 0 then
					SetGlyphs(false)
				end
			end)
			Play(button, 0.15, { BackgroundColor3 = color })
		end)
		button.MouseButton1Down:Connect(function()
			Play(button, 0.1, { BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.3) })
		end)
		button.MouseButton1Up:Connect(function()
			Play(button, 0.15, { BackgroundColor3 = color })
		end)
		button.MouseButton1Click:Connect(callback)
	end

	----------------------------------------------------------------------
	-- Title / info
	----------------------------------------------------------------------
	local information = New("Frame", {
		Name = "Information",
		Position = UDim2.fromOffset(0, CONTROLS_H),
		Size = UDim2.new(1, 0, 0, INFO_H),
		Parent = sidebar,
	}, {
		New("Frame", {
			Name = "Divider",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundTransparency = 0.92,
		}),
	})

	local titleFrame = New("Frame", {
		Name = "TitleFrame",
		Size = UDim2.new(1, -42, 1, 0),
		Parent = information,
	}, { List(3, FillDir.Vertical, HAlign.Left, VAlign.Center), Pad(22, 0, 0, 0) })

	local title = New("TextLabel", {
		Name = "Title",
		FontFace = F(Weight.SemiBold),
		Text = Settings.Title or "",
		TextSize = 17,
		TextTransparency = 0.05,
		TextTruncate = Enum.TextTruncate.SplitWord,
		TextXAlignment = TXA.Left,
		AutomaticSize = Auto.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = titleFrame,
	})

	local subtitle = New("TextLabel", {
		Name = "Subtitle",
		FontFace = F(Weight.Medium),
		Text = Settings.Subtitle or "",
		TextSize = 12,
		TextTransparency = 0.65,
		TextTruncate = Enum.TextTruncate.SplitWord,
		TextXAlignment = TXA.Left,
		AutomaticSize = Auto.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = titleFrame,
	})

	local globalSettingsButton = New("ImageButton", {
		Name = "GlobalSettingsButton",
		Image = assets.globe,
		ImageTransparency = 0.5,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		Parent = information,
	})

	globalSettingsButton.MouseEnter:Connect(function()
		Play(globalSettingsButton, 0.2, { ImageTransparency = 0.15, Rotation = 20 }, Ease.Back)
	end)
	globalSettingsButton.MouseLeave:Connect(function()
		Play(globalSettingsButton, 0.2, { ImageTransparency = 0.5, Rotation = 0 })
	end)

	----------------------------------------------------------------------
	-- Tab list area (+ optional search)
	----------------------------------------------------------------------
	local tabAreaTop = CONTROLS_H + INFO_H + (Settings.TabSearch and 44 or 0)

	local tabSearchBox
	if Settings.TabSearch then
		local searchFrame = New("Frame", {
			Name = "TabSearch",
			Position = UDim2.fromOffset(12, CONTROLS_H + INFO_H + 8),
			Size = UDim2.new(1, -24, 0, 30),
			BackgroundTransparency = 0.94,
			Parent = sidebar,
		}, { Corner(8), Stroke(0.93) })

		New("ImageLabel", {
			Image = assets.searchIcon,
			ImageColor3 = Color3.fromRGB(180, 180, 180),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(12, 12),
			Parent = searchFrame,
		})

		tabSearchBox = New("TextBox", {
			Name = "SearchBox",
			PlaceholderText = "Search tabs...",
			PlaceholderColor3 = Color3.fromRGB(150, 150, 150),
			ClearTextOnFocus = false,
			FontFace = F(Weight.Medium),
			TextColor3 = Color3.fromRGB(210, 210, 210),
			TextXAlignment = TXA.Left,
			Size = UDim2.fromScale(1, 1),
			Parent = searchFrame,
		}, { Pad(28, 0, 8, 0) })
	end

	local tabSwitchers = New("Frame", {
		Name = "TabSwitchers",
		Position = UDim2.fromOffset(0, tabAreaTop),
		Size = UDim2.new(1, 0, 1, -(tabAreaTop + USER_H)),
		ClipsDescendants = true,
		Parent = sidebar,
	})

	local indicatorPill = New("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(3, 16),
		BackgroundTransparency = 0,
	}, { Corner(999) })
	Bind(indicatorPill, "BackgroundColor3", "Accent")

	local indicator = New("Frame", {
		Name = "Indicator",
		BackgroundTransparency = 0.93,
		Visible = false,
		ZIndex = 1,
		Parent = tabSwitchers,
	}, { Corner(8), Stroke(0.93), indicatorPill })

	local tabListLayout = List(12)
	local tabScroll = New("ScrollingFrame", {
		Name = "TabSwitchersScrollingFrame",
		AutomaticCanvasSize = Auto.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.8,
		BottomImage = "",
		TopImage = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = tabSwitchers,
	}, { tabListLayout, Pad(10, 6, 10, 8) })

	----------------------------------------------------------------------
	-- User info
	----------------------------------------------------------------------
	local userInfo = New("Frame", {
		Name = "UserInfo",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, USER_H),
		Parent = sidebar,
	}, {
		New("Frame", {
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundTransparency = 0.92,
		}),
	})

	local userInner = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		Parent = userInfo,
	}, { List(10, FillDir.Horizontal, HAlign.Left, VAlign.Center), Pad(20, 0, 10, 0) })

	local headshotImage, isReady = "", false
	pcall(function()
		headshotImage, isReady = Players:GetUserThumbnailAsync(
			LocalPlayer.UserId,
			Enum.ThumbnailType.AvatarBust,
			Enum.ThumbnailSize.Size48x48
		)
	end)

	local headshot = New("ImageLabel", {
		Name = "Headshot",
		Size = UDim2.fromOffset(34, 34),
		Image = (isReady and headshotImage) or "rbxassetid://0",
		Parent = userInner,
	}, { Corner(999), Stroke(0.88) })

	local userText = New("Frame", {
		Name = "UserAndDisplayFrame",
		LayoutOrder = 1,
		Size = UDim2.new(1, -50, 0, 34),
		Parent = userInner,
	}, { List(1, FillDir.Vertical, HAlign.Left, VAlign.Center) })

	local displayName = New("TextLabel", {
		Name = "DisplayName",
		FontFace = F(Weight.SemiBold),
		Text = LocalPlayer.DisplayName,
		TextSize = 13,
		TextTransparency = 0.1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = TXA.Left,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = userText,
	})

	local username = New("TextLabel", {
		Name = "Username",
		FontFace = F(Weight.Medium),
		Text = "@" .. LocalPlayer.Name,
		TextSize = 12,
		TextTransparency = 0.65,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = TXA.Left,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Parent = userText,
	})

	----------------------------------------------------------------------
	-- Topbar
	----------------------------------------------------------------------
	local topbar = New("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, TOPBAR_H),
		Parent = content,
	}, {
		New("Frame", {
			Name = "Divider",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundTransparency = 0.92,
		}),
	})

	local currentTabText = New("TextLabel", {
		Name = "CurrentTab",
		FontFace = F(Weight.SemiBold),
		TextSize = 17,
		TextTransparency = 0.15,
		TextTruncate = Enum.TextTruncate.SplitWord,
		TextXAlignment = TXA.Left,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		Size = UDim2.new(0.8, 0, 0, 22),
		Parent = topbar,
	})

	local moveIcon = New("ImageButton", {
		Name = "MoveIcon",
		Image = assets.transform,
		ImageTransparency = 0.7,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0.5, 0),
		Size = UDim2.fromOffset(15, 15),
		Visible = not Settings.DragStyle or Settings.DragStyle == 1,
		Parent = topbar,
	})

	local moveInteract = New("TextButton", {
		Name = "Interact",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		Parent = moveIcon,
	})

	moveInteract.MouseEnter:Connect(function()
		Play(moveIcon, 0.2, { ImageTransparency = 0.35, Size = UDim2.fromOffset(17, 17) }, Ease.Back)
	end)
	moveInteract.MouseLeave:Connect(function()
		Play(moveIcon, 0.2, { ImageTransparency = 0.7, Size = UDim2.fromOffset(15, 15) })
	end)

	----------------------------------------------------------------------
	-- Dragging (smoothed) + double click to maximize
	----------------------------------------------------------------------
	do
		local dragging, dragStart, startPos = false, nil, nil

		local function beginDrag(input)
			if maximized then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			dragging = true
			dragStart = input.Position
			startPos = base.Position
			local changed
			changed = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					changed:Disconnect()
				end
			end)
		end

		if not Settings.DragStyle or Settings.DragStyle == 1 then
			moveInteract.InputBegan:Connect(beginDrag)
		else
			sidebar.InputBegan:Connect(beginDrag)
			topbar.InputBegan:Connect(beginDrag)
		end

		Connect(UserInputService.InputChanged, function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				Play(base, 0.08, {
					Position = UDim2.new(
						startPos.X.Scale, startPos.X.Offset + delta.X,
						startPos.Y.Scale, startPos.Y.Offset + delta.Y
					),
				}, Ease.Sine)
			end
		end)
		Connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)

		local lastClick = 0
		topbar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local now = os.clock()
				if now - lastClick < 0.3 and lights.Maximize and lights.Maximize.button.Interactable then
					WindowFunctions:SetMaximized(not maximized)
				end
				lastClick = now
			end
		end)
	end

	----------------------------------------------------------------------
	-- Global settings popup
	----------------------------------------------------------------------
	local hasGlobalSetting = false
	local globalSettingsScale = New("UIScale", { Scale = 0.001 })
	local globalSettings = New("Frame", {
		Name = "GlobalSettings",
		AutomaticSize = Auto.XY,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(sidebarWidth - 10, CONTROLS_H + INFO_H - 18),
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 40,
		Parent = base,
	}, { Corner(10), Stroke(0.88), Pad(0, 8, 0, 8), List(2), globalSettingsScale })
	Bind(globalSettings, "BackgroundColor3", "Surface")

	local globalOpen = false
	local globalHover = false

	local function ToggleGlobalSettings(state)
		if state == globalOpen then
			return
		end
		globalOpen = state
		if state then
			globalSettings.Position = UDim2.fromOffset(sidebarWidth - 10, CONTROLS_H + INFO_H - 18)
			globalSettings.Visible = true
			Play(globalSettingsScale, 0.35, { Scale = 1 }, Ease.Back)
		else
			Play(globalSettingsScale, 0.2, { Scale = 0.001 })
			task.delay(0.2, function()
				if not globalOpen then
					globalSettings.Visible = false
				end
			end)
		end
	end

	globalSettingsButton.MouseButton1Click:Connect(function()
		if hasGlobalSetting then
			ToggleGlobalSettings(not globalOpen)
		end
	end)
	globalSettings.MouseEnter:Connect(function()
		globalHover = true
	end)
	globalSettings.MouseLeave:Connect(function()
		globalHover = false
	end)
	Connect(UserInputService.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and globalOpen and not globalHover then
			task.defer(function()
				if not globalHover then
					ToggleGlobalSettings(false)
				end
			end)
		end
	end)

	----------------------------------------------------------------------
	-- Acrylic blur (glass parts + depth of field)
	----------------------------------------------------------------------
	local blurParts = {}
	local DepthOfField

	do
		for _, v in ipairs(Lighting:GetChildren()) do
			if v:IsA("DepthOfFieldEffect") and v:HasTag("MacLibBlur") then
				DepthOfField = v
				break
			end
		end
		if not DepthOfField then
			DepthOfField = Instance.new("DepthOfFieldEffect")
			DepthOfField.FarIntensity = 0
			DepthOfField.FocusDistance = 51.6
			DepthOfField.InFocusRadius = 50
			DepthOfField.NearIntensity = 1
			DepthOfField.Name = HttpService:GenerateGUID(false)
			DepthOfField:AddTag("MacLibBlur")
		end

		local wedgeName = HttpService:GenerateGUID(false)
		local blurFrame = New("Frame", {
			Name = HttpService:GenerateGUID(false),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.97, 0.97),
			Parent = base,
		})

		local sz = 0.2
		local function DrawTriangle(v1, v2, v3, p0, p1)
			local s1 = (v1 - v2).Magnitude
			local s2 = (v2 - v3).Magnitude
			local s3 = (v3 - v1).Magnitude
			local smax = math.max(s1, s2, s3)
			local A, B, C
			if s1 == smax then
				A, B, C = v1, v2, v3
			elseif s2 == smax then
				A, B, C = v2, v3, v1
			else
				A, B, C = v3, v1, v2
			end

			local para = ((B - A).X * (C - A).X + (B - A).Y * (C - A).Y + (B - A).Z * (C - A).Z) / (A - B).Magnitude
			local perp = math.sqrt(math.max(0, (C - A).Magnitude ^ 2 - para * para))
			local difPara = (A - B).Magnitude - para

			local st = CFrame.new(B, A)
			local za = CFrame.Angles(math.pi / 2, 0, 0)
			local cf0 = st

			local topLook = (cf0 * za).LookVector
			local midPoint = A + CFrame.new(A, B).LookVector * para
			local neededLook = CFrame.new(midPoint, C).LookVector
			local dot = math.clamp(topLook.X * neededLook.X + topLook.Y * neededLook.Y + topLook.Z * neededLook.Z, -1, 1)

			local ac = CFrame.Angles(0, 0, math.acos(dot))
			cf0 = cf0 * ac
			if ((cf0 * za).LookVector - neededLook).Magnitude > 0.01 then
				cf0 = cf0 * CFrame.Angles(0, 0, -2 * math.acos(dot))
			end
			cf0 = cf0 * CFrame.new(0, perp / 2, -(difPara + para / 2))

			local cf1 = st * ac * CFrame.Angles(0, math.pi, 0)
			if ((cf1 * za).LookVector - neededLook).Magnitude > 0.01 then
				cf1 = cf1 * CFrame.Angles(0, 0, 2 * math.acos(dot))
			end
			cf1 = cf1 * CFrame.new(0, perp / 2, difPara / 2)

			if not p0 then
				p0 = Instance.new("Part")
				p0.FormFactor = Enum.FormFactor.Custom
				p0.TopSurface = Enum.SurfaceType.Smooth
				p0.BottomSurface = Enum.SurfaceType.Smooth
				p0.Anchored = true
				p0.CanCollide = false
				p0.CanQuery = false
				p0.CanTouch = false
				p0.CastShadow = false
				p0.Material = Enum.Material.Glass
				p0.Size = Vector3.new(sz, sz, sz)
				p0.Name = HttpService:GenerateGUID(false)
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Wedge
				mesh.Name = wedgeName
				mesh.Parent = p0
			end
			p0[wedgeName].Scale = Vector3.new(0, perp / sz, para / sz)
			p0.CFrame = cf0

			if not p1 then
				p1 = p0:Clone()
			end
			p1[wedgeName].Scale = Vector3.new(0, perp / sz, difPara / sz)
			p1.CFrame = cf1

			return p0, p1
		end

		local function DrawQuad(v1, v2, v3, v4, parts)
			parts[1], parts[2] = DrawTriangle(v1, v2, v3, parts[1], parts[2])
			parts[3], parts[4] = DrawTriangle(v3, v2, v4, parts[3], parts[4])
		end

		local function Hide()
			for _, part in pairs(blurParts) do
				part.Parent = nil
			end
			DepthOfField.Enabled = false
			DepthOfField.Parent = nil
		end

		local function Update()
			local camera = workspace.CurrentCamera
			if unloaded or not acrylicBlur or not camera or not base.Visible or not macLib.Enabled then
				Hide()
				return
			end

			local tl = blurFrame.AbsolutePosition
			local br = tl + blurFrame.AbsoluteSize
			local tr, bl = Vector2.new(br.X, tl.Y), Vector2.new(tl.X, br.Y)
			local depth = 0.95

			local o1 = camera:ViewportPointToRay(tl.X, tl.Y, depth).Origin
			if o1.X ~= o1.X then
				return
			end

			if not DepthOfField.Parent then
				DepthOfField.Parent = Lighting
			end
			DepthOfField.Enabled = true

			DrawQuad(
				o1,
				camera:ViewportPointToRay(tr.X, tr.Y, depth).Origin,
				camera:ViewportPointToRay(bl.X, bl.Y, depth).Origin,
				camera:ViewportPointToRay(br.X, br.Y, depth).Origin,
				blurParts
			)

			for _, part in pairs(blurParts) do
				part.Transparency = 0.98
				part.BrickColor = BrickColor.new("Institutional white")
				part.Parent = camera
			end
		end

		Connect(RunService.RenderStepped, Update)
		WindowFunctions._hideBlur = Hide
	end

	----------------------------------------------------------------------
	-- Show / hide / maximize
	----------------------------------------------------------------------
	local visToken = 0
	local function SetVisible(state)
		windowState = state
		visToken = visToken + 1
		local mine = visToken
		if state then
			base.Visible = true
			Play(base, 0.3, { BackgroundTransparency = baseTransparency() })
			Play(animValue, 0.5, { Value = 1 }, Ease.Back)
		else
			Play(base, 0.25, { BackgroundTransparency = 1 })
			Play(animValue, 0.25, { Value = 0.85 }, Ease.Quint, EDir.In)
			task.delay(0.26, function()
				if mine == visToken and not windowState then
					base.Visible = false
				end
			end)
		end
	end

	local restoreState
	function WindowFunctions:SetMaximized(state)
		if state == maximized or unloaded then
			return
		end
		maximized = state
		if state then
			restoreState = { Size = base.Size, Position = base.Position }
			local vp = macLib.AbsoluteSize
			Play(base, 0.55, {
				Size = UDim2.fromOffset((vp.X - 36) / userScale, (vp.Y - 36) / userScale),
				Position = UDim2.fromScale(0.5, 0.5),
			}, Ease.Quint)
		elseif restoreState then
			Play(base, 0.55, restoreState, Ease.Quint)
		end
	end

	function WindowFunctions:GetMaximized()
		return maximized
	end

	MakeLight("Exit", Color3.fromRGB(250, 93, 86), 1, "\u{00D7}", function()
		if Settings.ConfirmExit == false then
			WindowFunctions:Unload()
			return
		end
		WindowFunctions:Dialog({
			Title = Settings.Title,
			Description = "Are you sure you want to exit the menu? You will lose any unsaved configurations.",
			Buttons = {
				{ Name = "Confirm", Style = "Destructive", Callback = function() WindowFunctions:Unload() end },
				{ Name = "Cancel" },
			},
		})
	end)
	MakeLight("Minimize", Color3.fromRGB(252, 190, 57), 2, "\u{2013}", function()
		WindowFunctions:ToggleMenu()
	end)
	MakeLight("Maximize", Color3.fromRGB(51, 199, 74), 3, "+", function()
		WindowFunctions:SetMaximized(not maximized)
	end)

	-- v1 compat: exit/minimize/maximize buttons were named like this
	WindowFunctions.Controls = lights

	----------------------------------------------------------------------
	-- Tabs
	----------------------------------------------------------------------
	local tabs = {}
	local tabIndex = 0
	local currentTabInfo
	local tabButtons = {}

	local function MoveIndicator(button, animate)
		if not button or not button.Parent then
			return
		end
		local s = baseUIScale.Scale
		local rel = (button.AbsolutePosition - tabSwitchers.AbsolutePosition) / s
		local pos = UDim2.fromOffset(rel.X, rel.Y)
		local size = UDim2.fromOffset(button.AbsoluteSize.X / s, button.AbsoluteSize.Y / s)
		if animate and indicator.Visible then
			Play(indicator, 0.45, { Position = pos, Size = size }, Ease.Quint)
		else
			indicator.Position = pos
			indicator.Size = size
		end
		indicator.Visible = button.Visible
	end

	local function RefreshIndicator()
		if currentTabInfo then
			MoveIndicator(currentTabInfo.button, false)
		end
	end

	tabScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(RefreshIndicator)
	tabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		task.defer(RefreshIndicator)
	end)
	sidebar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(RefreshIndicator)
	end)

	local function SelectTab(info)
		if currentTabInfo == info then
			return
		end
		local previous = currentTabInfo
		currentTabInfo = info

		for _, t in pairs(tabs) do
			local selected = t == info
			Play(t.nameLabel, 0.3, { TextTransparency = selected and 0.05 or 0.5 })
			if t.image then
				Play(t.image, 0.3, { ImageTransparency = selected and 0.05 or 0.5 })
			end
		end

		task.spawn(function()
			RunService.RenderStepped:Wait()
			MoveIndicator(info.button, previous ~= nil)
		end)

		if previous then
			previous.content.Parent = nil
		end
		info.content.Parent = content
		currentTabText.Text = info.name

		info.scroll.Position = UDim2.fromOffset(0, 22)
		Play(info.scroll, 0.55, { Position = UDim2.fromOffset(0, 0) })

		for i, sec in ipairs(info.sections) do
			sec.frame.BackgroundTransparency = 1
			sec.stroke.Transparency = 1
			task.delay(0.045 * math.min(i, 8), function()
				Play(sec.frame, 0.45, { BackgroundTransparency = 0.96 })
				Play(sec.stroke, 0.45, { Transparency = 0.94 })
			end)
		end
	end

	if tabSearchBox then
		tabSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
			local term = tabSearchBox.Text:lower()
			for _, t in pairs(tabs) do
				t.button.Visible = term == "" or t.name:lower():find(term, 1, true) ~= nil
			end
			task.defer(RefreshIndicator)
		end)
	end

	function WindowFunctions:TabGroup()
		local GroupFunctions = {}

		local group = New("Frame", {
			Name = "TabGroup",
			AutomaticSize = Auto.Y,
			Size = UDim2.fromScale(1, 0),
			LayoutOrder = #tabScroll:GetChildren(),
			Parent = tabScroll,
		}, { List(4), Pad(0, 0, 0, 6) })

		New("Frame", {
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundTransparency = 0.93,
			LayoutOrder = 99999,
			Parent = group,
		})

		function GroupFunctions:Tab(TabSettings)
			local TabFunctions = { Settings = TabSettings }
			tabIndex = tabIndex + 1

			local button = New("TextButton", {
				Name = "TabSwitcher",
				Size = UDim2.new(1, 0, 0, 36),
				LayoutOrder = tabIndex,
				BackgroundTransparency = 1,
				Parent = group,
			}, {
				Corner(8),
				List(10, FillDir.Horizontal, HAlign.Left, VAlign.Center),
				Pad(14, 0, 10, 0),
			})

			local image
			if TabSettings.Image then
				image = New("ImageLabel", {
					Name = "TabImage",
					Image = TabSettings.Image,
					ImageTransparency = 0.5,
					Size = UDim2.fromOffset(18, 18),
					Parent = button,
				})
			end

			local nameLabel = New("TextLabel", {
				Name = "TabSwitcherName",
				FontFace = F(Weight.Medium),
				Text = TabSettings.Name,
				TextSize = 15,
				TextTransparency = 0.5,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = TXA.Left,
				Size = UDim2.new(1, image and -28 or 0, 1, 0),
				LayoutOrder = 1,
				Parent = button,
			})

			-- Tab content
			local elements = New("Frame", {
				Name = "Elements",
				Position = UDim2.fromOffset(0, TOPBAR_H),
				Size = UDim2.new(1, 0, 1, -TOPBAR_H),
				ClipsDescendants = true,
			})

			local scroll = New("ScrollingFrame", {
				Name = "ElementsScrolling",
				AutomaticCanvasSize = Auto.Y,
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 2,
				ScrollBarImageTransparency = 0.6,
				BottomImage = "",
				TopImage = "",
				Size = UDim2.fromScale(1, 1),
				Parent = elements,
			}, { Pad(14, 14, 12, 16), List(14, FillDir.Horizontal) })

			local left = New("Frame", {
				Name = "Left",
				AutomaticSize = Auto.Y,
				Size = UDim2.new(0.5, -7, 0, 0),
				Parent = scroll,
			}, { List(14) })

			local right = New("Frame", {
				Name = "Right",
				AutomaticSize = Auto.Y,
				Size = UDim2.new(0.5, -7, 0, 0),
				LayoutOrder = 1,
				Parent = scroll,
			}, { List(14) })

			local info = {
				name = TabSettings.Name,
				button = button,
				nameLabel = nameLabel,
				image = image,
				content = elements,
				scroll = scroll,
				sections = {},
			}
			tabs[button] = info
			table.insert(tabButtons, button)

			button.MouseEnter:Connect(function()
				if currentTabInfo ~= info then
					Play(nameLabel, 0.2, { TextTransparency = 0.25 })
					if image then
						Play(image, 0.2, { ImageTransparency = 0.25 })
					end
					Play(button, 0.2, { BackgroundTransparency = 0.97 })
				end
			end)
			button.MouseLeave:Connect(function()
				if currentTabInfo ~= info then
					Play(nameLabel, 0.2, { TextTransparency = 0.5 })
					if image then
						Play(image, 0.2, { ImageTransparency = 0.5 })
					end
				end
				Play(button, 0.2, { BackgroundTransparency = 1 })
			end)
			button.MouseButton1Click:Connect(function()
				SelectTab(info)
			end)

			function TabFunctions:Select()
				SelectTab(info)
			end

			task.defer(function()
				if not currentTabInfo then
					SelectTab(info)
				end
			end)

			------------------------------------------------------------------
			-- Sections
			------------------------------------------------------------------
			function TabFunctions:Section(SecSettings)
				SecSettings = SecSettings or {}
				local SectionFunctions = {}

				local secStroke = Stroke(0.94)
				local section = New("Frame", {
					Name = "Section",
					AutomaticSize = Auto.Y,
					Size = UDim2.fromScale(1, 0),
					BackgroundTransparency = 0.96,
					ClipsDescendants = true,
					Parent = SecSettings.Side == "Right" and right or left,
				}, { Corner(10), secStroke, List(10), Pad(18, 18, 16, 18) })

				table.insert(info.sections, { frame = section, stroke = secStroke })

				local secTitle = SecSettings.Title or SecSettings.Name
				if secTitle then
					New("TextLabel", {
						Name = "SectionTitle",
						Text = secTitle,
						FontFace = F(Weight.SemiBold),
						TextSize = 12,
						TextTransparency = 0.55,
						TextXAlignment = TXA.Left,
						Size = UDim2.new(1, 0, 0, 16),
						LayoutOrder = -1,
						Parent = section,
					})
				end

				-- Standard row: name (+ description) on the left, control on the right
				local function MakeRow(o)
					local row = New("Frame", {
						Name = o.Class,
						AutomaticSize = Auto.Y,
						Size = UDim2.new(1, 0, 0, o.Height or 36),
						ClipsDescendants = o.Clip or false,
						Parent = section,
					})
					local padX = o.PadX or 0
					local leftFrame = New("Frame", {
						Name = "Left",
						AutomaticSize = Auto.Y,
						Position = UDim2.fromOffset(padX, 0),
						Size = UDim2.new(1, -((o.Reserve or 0) + padX), 0, 0),
						Parent = row,
					}, { List(1), Pad(0, 9, 0, 9 + (o.ExtraBottom or 0)) })

					local nameLabel = New("TextLabel", {
						Name = "Name",
						Text = o.Name or "",
						TextTransparency = 0.3,
						TextWrapped = true,
						TextXAlignment = TXA.Left,
						AutomaticSize = Auto.Y,
						Size = UDim2.new(1, 0, 0, 18),
						Parent = leftFrame,
					})

					local descLabel
					if o.Desc then
						descLabel = New("TextLabel", {
							Name = "Description",
							Text = o.Desc,
							TextSize = 11,
							TextTransparency = 0.65,
							TextWrapped = true,
							TextXAlignment = TXA.Left,
							AutomaticSize = Auto.Y,
							Size = UDim2.new(1, 0, 0, 0),
							LayoutOrder = 1,
							Parent = leftFrame,
						})
					end

					AttachTooltip(row, o.Tooltip)
					return row, nameLabel, descLabel
				end

				local function Register(F_, Flag)
					if Flag then
						MacLib.Options[Flag] = F_
					end
					return F_
				end

				-- Button -------------------------------------------------
				function SectionFunctions:Button(S, Flag)
					local BF = { Settings = S, Class = "Button" }
					local row, nameLabel = MakeRow({
						Class = "Button", Name = S.Name, Desc = S.Description,
						Reserve = 34, PadX = 12, Clip = true, Tooltip = S.Tooltip,
					})
					row.BackgroundTransparency = 0.94
					row.Name = "Button"
					New("UICorner", { CornerRadius = UDim.new(0, 8), Parent = row })
					local rowStroke = Stroke(0.93)
					rowStroke.Parent = row

					local icon = New("ImageLabel", {
						Name = "ButtonImage",
						Image = assets.buttonImage,
						ImageTransparency = 0.5,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -12, 0.5, 0),
						Size = UDim2.fromOffset(15, 15),
						Parent = row,
					})

					local interact = New("TextButton", {
						Name = "ButtonInteract",
						Size = UDim2.fromScale(1, 1),
						ZIndex = 3,
						Parent = row,
					})

					interact.MouseEnter:Connect(function()
						Play(row, 0.2, { BackgroundTransparency = 0.89 })
						Play(nameLabel, 0.2, { TextTransparency = 0.05 })
						Play(icon, 0.25, { ImageTransparency = 0.15, Position = UDim2.new(1, -9, 0.5, 0) })
					end)
					interact.MouseLeave:Connect(function()
						Play(row, 0.25, { BackgroundTransparency = 0.94 })
						Play(nameLabel, 0.25, { TextTransparency = 0.3 })
						Play(icon, 0.25, { ImageTransparency = 0.5, Position = UDim2.new(1, -12, 0.5, 0) })
					end)
					interact.MouseButton1Down:Connect(function()
						Play(row, 0.1, { BackgroundTransparency = 0.84 })
						Ripple(row)
					end)
					interact.MouseButton1Up:Connect(function()
						Play(row, 0.2, { BackgroundTransparency = 0.89 })
					end)
					interact.MouseButton1Click:Connect(function()
						if S.Callback then
							task.spawn(S.Callback)
						end
					end)

					function BF:UpdateName(Name) nameLabel.Text = Name end
					function BF:SetVisibility(State) row.Visible = State end
					return Register(BF, Flag)
				end

				-- Toggle -------------------------------------------------
				function SectionFunctions:Toggle(S, Flag)
					local TF = { Settings = S, IgnoreConfig = false, Class = "Toggle", State = S.Default and true or false }
					local row, nameLabel = MakeRow({
						Class = "Toggle", Name = S.Name, Desc = S.Description, Reserve = 54, Tooltip = S.Tooltip,
					})

					local track = New("Frame", {
						Name = "Track",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(40, 22),
						BackgroundTransparency = 0,
						BackgroundColor3 = Color3.fromRGB(62, 62, 66),
						Parent = row,
					}, { Corner(999), Stroke(0.9) })

					local knob = New("Frame", {
						Name = "Knob",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 2, 0.5, 0),
						Size = UDim2.fromOffset(18, 18),
						BackgroundTransparency = 0,
						ZIndex = 2,
						Parent = track,
					}, { Corner(999) })

					local interact = New("TextButton", {
						Name = "Interact",
						Size = UDim2.fromScale(1, 1),
						ZIndex = 3,
						Parent = row,
					})

					local pressed = false
					local function KnobProps(state)
						local w = pressed and 24 or 18
						return {
							Size = UDim2.fromOffset(w, 18),
							Position = UDim2.new(0, state and (40 - 2 - w) or 2, 0.5, 0),
						}
					end

					local function Visuals(state, instant)
						local trackColor = state and Theme.Accent or Color3.fromRGB(62, 62, 66)
						local props = KnobProps(state)
						if instant then
							track.BackgroundColor3 = trackColor
							knob.Size = props.Size
							knob.Position = props.Position
							nameLabel.TextTransparency = state and 0.12 or 0.3
						else
							Play(track, 0.25, { BackgroundColor3 = trackColor })
							Play(knob, 0.3, props, Ease.Back)
							Play(nameLabel, 0.25, { TextTransparency = state and 0.12 or 0.3 })
						end
					end

					OnTheme(row, function(instant)
						Visuals(TF.State, instant)
					end)

					local function SetState(state, fire)
						TF.State = state
						Visuals(state, false)
						if fire and S.Callback then
							task.spawn(S.Callback, state)
						end
					end

					interact.MouseButton1Down:Connect(function()
						pressed = true
						Play(knob, 0.15, KnobProps(TF.State))
					end)
					Connect(UserInputService.InputEnded, function(input)
						if pressed and input.UserInputType == Enum.UserInputType.MouseButton1 then
							pressed = false
							Play(knob, 0.2, KnobProps(TF.State), Ease.Back)
						end
					end)
					interact.MouseEnter:Connect(function()
						if not TF.State then
							Play(nameLabel, 0.2, { TextTransparency = 0.12 })
						end
					end)
					interact.MouseLeave:Connect(function()
						if not TF.State then
							Play(nameLabel, 0.2, { TextTransparency = 0.3 })
						end
					end)
					interact.MouseButton1Click:Connect(function()
						pressed = false
						SetState(not TF.State, true)
					end)

					function TF:Toggle() SetState(not TF.State, true) end
					function TF:UpdateState(State, silent) SetState(State and true or false, not silent) end
					function TF:GetState() return TF.State end
					function TF:UpdateName(Name) nameLabel.Text = Name end
					function TF:SetVisibility(State) row.Visible = State end
					return Register(TF, Flag)
				end

				-- Slider -------------------------------------------------
				function SectionFunctions:Slider(S, Flag)
					local SF = { Settings = S, IgnoreConfig = false, Class = "Slider" }
					local min, max = S.Minimum or 0, S.Maximum or 100
					local row, nameLabel = MakeRow({
						Class = "Slider", Name = S.Name, Desc = S.Description,
						Reserve = 70, Height = 52, ExtraBottom = 16, Tooltip = S.Tooltip,
					})

					local valueBox = New("TextBox", {
						Name = "SliderValue",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 0, 0, 7),
						Size = UDim2.fromOffset(60, 22),
						BackgroundTransparency = 0.94,
						TextSize = 12,
						TextTransparency = 0.1,
						ClearTextOnFocus = false,
						ClipsDescendants = true,
						Parent = row,
					}, { Corner(5), Stroke(0.92), Pad(3, 0, 3, 0) })

					local track = New("Frame", {
						Name = "SliderBar",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 0, 1, -15),
						Size = UDim2.new(1, 0, 0, 4),
						BackgroundTransparency = 0.88,
						Parent = row,
					}, { Corner(999) })

					local fill = New("Frame", {
						Name = "Fill",
						Size = UDim2.fromScale(0, 1),
						BackgroundTransparency = 0,
						Parent = track,
					}, { Corner(999) })
					Bind(fill, "BackgroundColor3", "Accent")

					local knob = New("Frame", {
						Name = "SliderHead",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(14, 14),
						BackgroundTransparency = 0,
						ZIndex = 2,
						Parent = track,
					}, { Corner(999), Stroke(0.8, Color3.new(0, 0, 0)) })

					local hit = New("TextButton", {
						Name = "Hit",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, 8, 0, 26),
						ZIndex = 3,
						Parent = track,
					})

					local displayMethods = {
						Hundredths = function(v) return string.format("%.2f", v) end,
						Tenths = function(v) return string.format("%.1f", v) end,
						Round = function(v, p) return p and string.format("%." .. p .. "f", v) or tostring(math.round(v)) end,
						Degrees = function(v, p) return (p and string.format("%." .. p .. "f", v) or tostring(v)) .. "\u{00B0}" end,
						Percent = function(v, p)
							local pct = (v - min) / math.max(1e-9, max - min) * 100
							return p and (string.format("%." .. p .. "f", pct) .. "%") or (tostring(math.round(pct)) .. "%")
						end,
						Value = function(v, p) return p and string.format("%." .. p .. "f", v) or tostring(math.floor(v * 1000 + 0.5) / 1000) end,
					}
					local display = displayMethods[S.DisplayMethod] or displayMethods.Value

					local dragging = false

					local function Quantize(v)
						v = math.clamp(v, min, max)
						if S.Step and S.Step > 0 then
							v = min + math.floor((v - min) / S.Step + 0.5) * S.Step
							v = math.clamp(v, min, max)
						elseif S.Precision then
							local m = 10 ^ S.Precision
							v = math.floor(v * m + 0.5) / m
						end
						return v
					end

					local function SetValue(v, silent, instant)
						v = Quantize(v)
						SF.Value = v
						local pct = (max == min) and 0 or (v - min) / (max - min)
						local info = TweenInfo.new(instant and 0 or 0.1, Ease.Sine)
						TweenService:Create(fill, info, { Size = UDim2.fromScale(pct, 1) }):Play()
						TweenService:Create(knob, info, { Position = UDim2.fromScale(pct, 0.5) }):Play()
						valueBox.Text = (S.Prefix or "") .. display(v, S.Precision) .. (S.Suffix or "")
						if not silent and S.Callback then
							task.spawn(S.Callback, v)
						end
					end

					local function FromMouse()
						local x = MouseXY().X
						local pct = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
						SetValue(min + pct * (max - min))
					end

					SetValue(S.Default or min, true, true)

					local function Grow(state)
						Play(knob, 0.2, { Size = state and UDim2.fromOffset(18, 18) or UDim2.fromOffset(14, 14) }, Ease.Back)
					end

					hit.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							dragging = true
							Grow(true)
							Play(nameLabel, 0.2, { TextTransparency = 0.1 })
							FromMouse()
						end
					end)
					hit.MouseEnter:Connect(function()
						if not dragging then Grow(true) end
					end)
					hit.MouseLeave:Connect(function()
						if not dragging then Grow(false) end
					end)
					Connect(UserInputService.InputChanged, function(input)
						if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							FromMouse()
						end
					end)
					Connect(UserInputService.InputEnded, function(input)
						if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
							dragging = false
							Grow(IsInside(hit, MouseXY()))
							Play(nameLabel, 0.2, { TextTransparency = 0.3 })
							if S.onInputComplete then
								task.spawn(S.onInputComplete, SF.Value)
							end
						end
					end)

					valueBox.Focused:Connect(function()
						Play(valueBox, 0.2, { BackgroundTransparency = 0.88 })
					end)
					valueBox.FocusLost:Connect(function()
						Play(valueBox, 0.2, { BackgroundTransparency = 0.94 })
						local text = valueBox.Text:gsub((S.Prefix or ""):gsub("%p", "%%%0"), "", 1)
						local number, isPercent = text:match("^%s*(%-?%d+%.?%d*)%s*(%%?)")
						if number then
							local value = tonumber(number)
							if isPercent == "%" then
								value = min + (value / 100) * (max - min)
							end
							SetValue(value)
						else
							SetValue(SF.Value, true, true)
						end
						if S.onInputComplete then
							task.spawn(S.onInputComplete, SF.Value)
						end
					end)

					function SF:UpdateName(Name) nameLabel.Text = Name end
					function SF:SetVisibility(State) row.Visible = State end
					function SF:UpdateValue(Value)
						local n = tonumber(Value)
						if n then SetValue(n, true) end
					end
					function SF:GetValue() return SF.Value end
					return Register(SF, Flag)
				end

				-- Input --------------------------------------------------
				function SectionFunctions:Input(S, Flag)
					local IF = { Settings = S, IgnoreConfig = false, Class = "Input", Text = "" }
					local width = S.Width or 150
					local row, nameLabel = MakeRow({
						Class = "Input", Name = S.Name, Desc = S.Description,
						Reserve = width + 12, Tooltip = S.Tooltip,
					})

					local boxStroke = Stroke(0.9)
					local box = New("TextBox", {
						Name = "InputBox",
						PlaceholderText = S.Placeholder or "",
						PlaceholderColor3 = Color3.fromRGB(130, 130, 130),
						ClearTextOnFocus = false,
						TextSize = 12,
						TextTransparency = 0.1,
						TextXAlignment = TXA.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ClipsDescendants = true,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(width, 26),
						BackgroundTransparency = 0.94,
						Parent = row,
					}, { Corner(6), boxStroke, Pad(9, 0, 9, 0) })

					local function Apply(text)
						local filtered = FilterText(S.AcceptedCharacters, text, S.CharacterLimit)
						if filtered ~= text then
							box.Text = filtered
						end
						IF.Text = filtered
						return filtered
					end

					box.Focused:Connect(function()
						Play(boxStroke, 0.2, { Color = Theme.Accent, Transparency = 0.25 })
						Play(box, 0.2, { BackgroundTransparency = 0.9 })
					end)
					box.FocusLost:Connect(function()
						Play(boxStroke, 0.2, { Color = Color3.new(1, 1, 1), Transparency = 0.9 })
						Play(box, 0.2, { BackgroundTransparency = 0.94 })
						local text = Apply(box.Text)
						if S.Callback then
							task.spawn(S.Callback, text)
						end
					end)
					box:GetPropertyChangedSignal("Text"):Connect(function()
						local text = Apply(box.Text)
						if S.onChanged then
							task.spawn(S.onChanged, text)
						end
					end)

					box.Text = FilterText(S.AcceptedCharacters, S.Default or "", S.CharacterLimit)
					IF.Text = box.Text

					function IF:UpdateName(Name) nameLabel.Text = Name end
					function IF:SetVisibility(State) row.Visible = State end
					function IF:GetInput() return box.Text end
					function IF:UpdatePlaceholder(Placeholder) box.PlaceholderText = Placeholder end
					function IF:UpdateText(Text)
						box.Text = Apply(Text)
						if S.Callback then
							task.spawn(S.Callback, IF.Text)
						end
					end
					return Register(IF, Flag)
				end

				-- Keybind ------------------------------------------------
				function SectionFunctions:Keybind(S, Flag)
					local KF = { Settings = S, IgnoreConfig = false, Class = "Keybind", Bind = S.Default }
					local row, nameLabel = MakeRow({
						Class = "Keybind", Name = S.Name, Desc = S.Description, Reserve = 110, Tooltip = S.Tooltip,
					})

					local boxStroke = Stroke(0.9)
					local box = New("TextButton", {
						Name = "BinderBox",
						Text = KeyName(KF.Bind),
						TextSize = 12,
						TextTransparency = 0.15,
						AutomaticSize = Auto.X,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(44, 24),
						BackgroundTransparency = 0.94,
						Parent = row,
					}, { Corner(6), boxStroke, Pad(10, 0, 10, 0) })

					local listening, listenConn = false, nil
					local lastBound = 0

					local function Stop()
						listening = false
						if listenConn then
							listenConn:Disconnect()
							listenConn = nil
						end
						Play(boxStroke, 0.2, { Color = Color3.new(1, 1, 1), Transparency = 0.9 })
						box.Text = KeyName(KF.Bind)
					end

					box.MouseEnter:Connect(function()
						if not listening then Play(box, 0.2, { BackgroundTransparency = 0.9 }) end
					end)
					box.MouseLeave:Connect(function()
						Play(box, 0.2, { BackgroundTransparency = 0.94 })
					end)

					box.MouseButton1Click:Connect(function()
						if listening then
							Stop()
							return
						end
						listening = true
						box.Text = "..."
						Play(boxStroke, 0.2, { Color = Theme.Accent, Transparency = 0.2 })

						listenConn = UserInputService.InputBegan:Connect(function(input)
							local t = input.UserInputType
							local isKey = t == Enum.UserInputType.Keyboard
							local isMouse = t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3
							if not (isKey or isMouse) then
								return
							end
							local value = isKey and input.KeyCode or t

							if S.Blacklist and (table.find(S.Blacklist, value)) then
								Stop()
								return
							end

							if value == Enum.KeyCode.Escape then
								KF.Bind = nil
							else
								KF.Bind = value
								if S.onBinded then
									task.spawn(S.onBinded, value)
								end
							end
							lastBound = os.clock()
							Stop()
						end)
					end)

					Connect(UserInputService.InputBegan, function(input)
						if listening or os.clock() - lastBound < 0.2 or not KF.Bind then
							return
						end
						if UserInputService:GetFocusedTextBox() then
							return
						end
						if input.KeyCode == KF.Bind or input.UserInputType == KF.Bind then
							if S.Callback then
								task.spawn(S.Callback, KF.Bind)
							end
							if S.onBindHeld then
								task.spawn(S.onBindHeld, true, KF.Bind)
							end
						end
					end)
					Connect(UserInputService.InputEnded, function(input)
						if listening or not KF.Bind then
							return
						end
						if input.KeyCode == KF.Bind or input.UserInputType == KF.Bind then
							if S.onBindHeld then
								task.spawn(S.onBindHeld, false, KF.Bind)
							end
						end
					end)

					function KF:Bind(Key)
						KF.Bind = Key
						box.Text = KeyName(Key)
					end
					function KF:Unbind()
						KF.Bind = nil
						box.Text = KeyName(nil)
					end
					function KF:GetBind() return KF.Bind end
					function KF:UpdateName(Name) nameLabel.Text = Name end
					function KF:SetVisibility(State) row.Visible = State end

					-- note: the method above shadows the field of the same name on purpose in v1;
					-- the current bind is stored in KF.CurrentBind for config saving
					return Register(KF, Flag)
				end

				-- Dropdown -----------------------------------------------
				function SectionFunctions:Dropdown(S, Flag)
					local DF = { Settings = S, IgnoreConfig = false, Class = "Dropdown" }
					local multi = S.Multi and true or false
					local Selected, OptionObjs, order = {}, {}, {}
					local open = false
					local counter = 0
					local searchEnabled = S.Search and true or false

					local dropdown = New("Frame", {
						Name = "Dropdown",
						Size = UDim2.new(1, 0, 0, 36),
						BackgroundTransparency = 0.96,
						ClipsDescendants = true,
						Parent = section,
					}, { Corner(8), Stroke(0.93) })

					local header = New("TextButton", {
						Name = "Interact",
						Size = UDim2.new(1, 0, 0, 36),
						Parent = dropdown,
					})
					AttachTooltip(header, S.Tooltip)

					local nameLabel = New("TextLabel", {
						Name = "DropdownName",
						Text = S.Name,
						TextTransparency = 0.3,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = TXA.Left,
						Position = UDim2.fromOffset(14, 0),
						Size = UDim2.new(0.5, -14, 0, 36),
						Parent = header,
					})

					local valueLabel = New("TextLabel", {
						Name = "Value",
						Text = "None",
						TextSize = 12,
						TextTransparency = 0.55,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = TXA.Right,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -34, 0, 0),
						Size = UDim2.new(0.5, -22, 0, 36),
						Parent = header,
					})

					local chevron = New("ImageLabel", {
						Name = "DropdownImage",
						Image = assets.dropdown,
						ImageTransparency = 0.5,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -12, 0, 18),
						Size = UDim2.fromOffset(14, 14),
						Parent = header,
					})

					local body = New("Frame", {
						Name = "Body",
						Position = UDim2.fromOffset(8, 40),
						Size = UDim2.new(1, -16, 0, 0),
						Parent = dropdown,
					})

					local searchBox
					if searchEnabled then
						local searchFrame = New("Frame", {
							Name = "Search",
							Size = UDim2.new(1, 0, 0, 28),
							BackgroundTransparency = 0.94,
							Parent = body,
						}, { Corner(6) })
						New("ImageLabel", {
							Image = assets.searchIcon,
							ImageColor3 = Color3.fromRGB(180, 180, 180),
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, 10, 0.5, 0),
							Size = UDim2.fromOffset(12, 12),
							Parent = searchFrame,
						})
						searchBox = New("TextBox", {
							Name = "SearchBox",
							PlaceholderText = "Search...",
							PlaceholderColor3 = Color3.fromRGB(150, 150, 150),
							ClearTextOnFocus = false,
							TextColor3 = Color3.fromRGB(210, 210, 210),
							TextXAlignment = TXA.Left,
							Size = UDim2.fromScale(1, 1),
							Parent = searchFrame,
						}, { Pad(28, 0, 8, 0) })
					end

					local optList = List(3)
					local optionsScroll = New("ScrollingFrame", {
						Name = "Options",
						Position = UDim2.fromOffset(0, searchEnabled and 34 or 0),
						Size = UDim2.new(1, 0, 0, 0),
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Auto.Y,
						ScrollBarThickness = 2,
						ScrollBarImageTransparency = 0.6,
						BottomImage = "",
						TopImage = "",
						Parent = body,
					}, { optList })

					local function ContentHeight()
						return math.min(optList.AbsoluteContentSize.Y / baseUIScale.Scale, S.MaxHeight or 170)
					end
					local function OpenHeight()
						return 40 + (searchEnabled and 34 or 0) + ContentHeight() + 8
					end
					local function Resize()
						optionsScroll.Size = UDim2.new(1, 0, 0, ContentHeight())
						if open then
							Play(dropdown, 0.25, { Size = UDim2.new(1, 0, 0, OpenHeight()) })
						end
					end
					optList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(Resize)

					local function SelectedText()
						if #Selected == 0 then
							return "None"
						end
						return table.concat(Selected, ", ")
					end

					local function Refresh()
						for name, o in pairs(OptionObjs) do
							local selected = table.find(Selected, name) ~= nil
							Play(o.NameLabel, 0.2, { TextTransparency = selected and 0.05 or 0.5 })
							Play(o.Check, 0.2, { TextTransparency = selected and 0 or 1 })
							Play(o.Button, 0.2, { BackgroundTransparency = selected and 0.94 or 1 })
						end
						valueLabel.Text = SelectedText()
						DF.Value = multi and Selected or Selected[1]
					end

					local function Fire()
						if not S.Callback then
							return
						end
						if multi then
							local ret = {}
							for _, n in ipairs(Selected) do
								ret[n] = true
							end
							task.spawn(S.Callback, ret)
						elseif Selected[1] then
							task.spawn(S.Callback, Selected[1])
						end
					end

					local function SetOpen(state)
						if open == state then
							return
						end
						open = state
						Play(chevron, 0.3, { Rotation = state and -90 or 0, ImageTransparency = state and 0.15 or 0.5 }, Ease.Back)
						Play(dropdown, 0.35, { Size = UDim2.new(1, 0, 0, state and OpenHeight() or 36) })
						Play(nameLabel, 0.2, { TextTransparency = state and 0.1 or 0.3 })
						if state then
							for i, name in ipairs(order) do
								local o = OptionObjs[name]
								if o then
									local target = table.find(Selected, name) and 0.05 or 0.5
									o.NameLabel.TextTransparency = 1
									task.delay(0.02 * math.min(i, 10), function()
										Play(o.NameLabel, 0.3, { TextTransparency = target })
									end)
								end
							end
						end
					end

					header.MouseEnter:Connect(function()
						Play(dropdown, 0.2, { BackgroundTransparency = 0.93 })
					end)
					header.MouseLeave:Connect(function()
						Play(dropdown, 0.2, { BackgroundTransparency = 0.96 })
					end)
					header.MouseButton1Click:Connect(function()
						SetOpen(not open)
					end)

					Connect(UserInputService.InputBegan, function(input)
						if open and input.UserInputType == Enum.UserInputType.MouseButton1 then
							if not IsInside(dropdown, MouseXY()) then
								SetOpen(false)
							end
						end
					end)

					if searchBox then
						searchBox:GetPropertyChangedSignal("Text"):Connect(function()
							local term = searchBox.Text:lower()
							for name, o in pairs(OptionObjs) do
								o.Button.Visible = term == "" or name:lower():find(term, 1, true) ~= nil
							end
						end)
					end

					local function AddOption(index, name)
						if OptionObjs[name] then
							return
						end
						counter = counter + 1
						table.insert(order, name)

						local button = New("TextButton", {
							Name = "Option",
							Size = UDim2.new(1, 0, 0, 30),
							LayoutOrder = counter,
							Parent = optionsScroll,
						}, { Corner(6) })

						local optName = New("TextLabel", {
							Name = "OptionName",
							Text = name,
							TextTransparency = 0.5,
							TextTruncate = Enum.TextTruncate.AtEnd,
							TextXAlignment = TXA.Left,
							Position = UDim2.fromOffset(10, 0),
							Size = UDim2.new(1, -36, 1, 0),
							Parent = button,
						})

						local check = New("TextLabel", {
							Name = "Checkmark",
							Text = CHECK,
							TextTransparency = 1,
							TextSize = 14,
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -10, 0.5, 0),
							Size = UDim2.fromOffset(16, 16),
							Parent = button,
						})
						Bind(check, "TextColor3", "Accent")

						OptionObjs[name] = { Index = index, Button = button, NameLabel = optName, Check = check }

						button.MouseEnter:Connect(function()
							if not table.find(Selected, name) then
								Play(button, 0.15, { BackgroundTransparency = 0.95 })
								Play(optName, 0.15, { TextTransparency = 0.25 })
							end
						end)
						button.MouseLeave:Connect(function()
							if not table.find(Selected, name) then
								Play(button, 0.15, { BackgroundTransparency = 1 })
								Play(optName, 0.15, { TextTransparency = 0.5 })
							end
						end)

						button.MouseButton1Click:Connect(function()
							local isSelected = table.find(Selected, name) ~= nil
							if multi then
								if isSelected then
									if S.Required and #Selected <= 1 then
										return
									end
									table.remove(Selected, table.find(Selected, name))
								else
									table.insert(Selected, name)
								end
							else
								if isSelected then
									if S.Required then
										SetOpen(false)
										return
									end
									Selected = {}
								else
									Selected = { name }
								end
							end
							Refresh()
							Fire()
							if not multi and S.CloseOnSelect ~= false then
								SetOpen(false)
							end
						end)
					end

					local function AddAll(options)
						for i = 1, #options do
							AddOption(i, options[i])
						end
					end

					if S.Options then
						AddAll(S.Options)
					end

					local function ApplyDefault(default)
						Selected = {}
						if default ~= nil then
							if type(default) == "number" then
								for name, o in pairs(OptionObjs) do
									if o.Index == default then
										Selected = { name }
									end
								end
							elseif type(default) == "string" then
								if OptionObjs[default] then
									Selected = { default }
								end
							elseif type(default) == "table" then
								for _, name in ipairs(default) do
									if OptionObjs[name] then
										table.insert(Selected, name)
										if not multi then
											break
										end
									end
								end
							end
						end
					end

					ApplyDefault(S.Default)
					Refresh()
					Resize()

					function DF:UpdateName(New_) nameLabel.Text = New_ end
					function DF:SetVisibility(State) dropdown.Visible = State end
					function DF:UpdateSelection(newSelection)
						if newSelection == nil then
							return
						end
						ApplyDefault(newSelection)
						Refresh()
						Fire()
					end
					function DF:GetSelected() return Selected end
					function DF:InsertOptions(newOptions)
						if not newOptions then
							return
						end
						DF.Settings.Options = newOptions
						AddAll(newOptions)
						Resize()
					end
					function DF:ClearOptions()
						for _, o in pairs(OptionObjs) do
							o.Button:Destroy()
						end
						OptionObjs, Selected, order = {}, {}, {}
						Refresh()
						Resize()
					end
					function DF:GetOptions()
						local status = {}
						for name in pairs(OptionObjs) do
							status[name] = table.find(Selected, name) ~= nil
						end
						return status
					end
					function DF:RemoveOptions(remove)
						if not remove then
							return
						end
						for _, name in ipairs(remove) do
							local o = OptionObjs[name]
							if o then
								local idx = table.find(Selected, name)
								if idx then
									table.remove(Selected, idx)
								end
								local oi = table.find(order, name)
								if oi then
									table.remove(order, oi)
								end
								o.Button:Destroy()
								OptionObjs[name] = nil
							end
						end
						Refresh()
						Resize()
					end
					function DF:IsOption(optionName)
						if not optionName then
							return false
						end
						return OptionObjs[optionName] ~= nil
					end
					return Register(DF, Flag)
				end

				-- Colorpicker --------------------------------------------
				function SectionFunctions:Colorpicker(S, Flag)
					local CF = { Settings = S, IgnoreConfig = false, Class = "Colorpicker" }
					local isAlpha = S.Alpha ~= nil
					CF.Color = S.Default or Color3.new(1, 1, 1)
					CF.Alpha = isAlpha and S.Alpha or nil

					local row, nameLabel = MakeRow({
						Class = "Colorpicker", Name = S.Name, Desc = S.Description, Reserve = 44, Tooltip = S.Tooltip,
					})

					local swatchBG = New("ImageLabel", {
						Name = "NewColor",
						Image = assets.grid,
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(500, 500),
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(28, 22),
						Parent = row,
					}, { Corner(6), Stroke(0.85) })

					local swatch = New("Frame", {
						Name = "Color",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = CF.Color,
						BackgroundTransparency = isAlpha and (CF.Alpha or 0) or 0,
						Parent = swatchBG,
					}, { Corner(6) })

					local swatchButton = New("TextButton", {
						Name = "Interact",
						Size = UDim2.fromScale(1, 1),
						Parent = swatch,
					})

					swatchButton.MouseEnter:Connect(function()
						Play(swatchBG, 0.2, { Size = UDim2.fromOffset(32, 24) }, Ease.Back)
					end)
					swatchButton.MouseLeave:Connect(function()
						Play(swatchBG, 0.2, { Size = UDim2.fromOffset(28, 22) })
					end)

					-- Modal ------------------------------------------------
					local WHEEL, R = 160, 80
					local overlay = New("Frame", {
						Name = "ColorPickerOverlay",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.new(0, 0, 0),
						Visible = false,
						Active = true,
						ZIndex = 50,
						Parent = base,
					}, { Corner(12) })

					local promptScale = New("UIScale", { Scale = 0.9 })
					local prompt = New("Frame", {
						Name = "Prompt",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(350, 0),
						AutomaticSize = Auto.Y,
						BackgroundTransparency = 0,
						Parent = overlay,
					}, { promptScale, Corner(14), Stroke(0.88), Pad(18, 18, 18, 18), List(14) })
					Bind(prompt, "BackgroundColor3", "Surface")

					New("TextLabel", {
						Name = "Header",
						Text = S.Name,
						FontFace = F(Weight.SemiBold),
						TextSize = 17,
						TextTransparency = 0.1,
						TextXAlignment = TXA.Left,
						Size = UDim2.new(1, 0, 0, 22),
						Parent = prompt,
					})

					local mid = New("Frame", {
						Name = "Mid",
						Size = UDim2.new(1, 0, 0, WHEEL),
						LayoutOrder = 1,
						Parent = prompt,
					})

					local wheel = New("ImageButton", {
						Name = "Wheel",
						Image = assets.colorWheel,
						Size = UDim2.fromOffset(WHEEL, WHEEL),
						Parent = mid,
					})
					local ring = New("ImageLabel", {
						Name = "Target",
						Image = assets.colorTarget,
						ImageColor3 = Color3.new(0, 0, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(22, 22),
						Parent = wheel,
					})

					local inputsFrame = New("Frame", {
						Name = "Inputs",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(1, -WHEEL - 16, 1, 0),
						Parent = mid,
					}, { List(5) })

					local function MakeField(label, order, default)
						local fr = New("Frame", {
							Size = UDim2.new(1, 0, 0, 26),
							LayoutOrder = order,
							Parent = inputsFrame,
						})
						New("TextLabel", {
							Text = label,
							TextTransparency = 0.5,
							TextXAlignment = TXA.Left,
							Size = UDim2.new(0, 40, 1, 0),
							Parent = fr,
						})
						local box = New("TextBox", {
							Text = default,
							ClearTextOnFocus = false,
							TextSize = 12,
							TextTransparency = 0.1,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.new(1, -44, 1, 0),
							BackgroundTransparency = 0.94,
							Parent = fr,
						}, { Corner(5), Stroke(0.9) })
						return box
					end

					local hexBox = MakeField("Hex", 0, "#FFFFFF")
					local redBox = MakeField("Red", 1, "255")
					local greenBox = MakeField("Green", 2, "255")
					local blueBox = MakeField("Blue", 3, "255")
					local alphaBox = isAlpha and MakeField("Alpha", 4, "0") or nil

					local bar = New("Frame", {
						Name = "Value",
						Size = UDim2.new(1, 0, 0, 14),
						BackgroundTransparency = 0,
						LayoutOrder = 2,
						Parent = prompt,
					}, {
						Corner(7),
						Stroke(0.9),
						New("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
								ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
							}),
						}),
					})

					local barTrack = New("Frame", {
						Name = "Track",
						Position = UDim2.fromOffset(7, 0),
						Size = UDim2.new(1, -14, 1, 0),
						Parent = bar,
					})
					local barKnob = New("Frame", {
						Name = "Slide",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(14, 20),
						BackgroundTransparency = 0,
						Parent = barTrack,
					}, { Corner(999), Stroke(0.4, Color3.new(0, 0, 0)) })

					local wells = New("Frame", {
						Name = "Wells",
						Size = UDim2.new(1, 0, 0, 26),
						LayoutOrder = 3,
						Parent = prompt,
					}, { List(10, FillDir.Horizontal) })

					local function MakeWell(order)
						local bg = New("ImageLabel", {
							Image = assets.grid,
							ScaleType = Enum.ScaleType.Tile,
							TileSize = UDim2.fromOffset(500, 500),
							Size = UDim2.new(0.5, -5, 1, 0),
							LayoutOrder = order,
							Parent = wells,
						}, { Corner(7), Stroke(0.88) })
						return New("Frame", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 0,
							Parent = bg,
						}, { Corner(7) })
					end
					local oldWell = MakeWell(0)
					local newWell = MakeWell(1)

					local buttonsRow = New("Frame", {
						Name = "Buttons",
						Size = UDim2.new(1, 0, 0, 34),
						LayoutOrder = 4,
						Parent = prompt,
					}, { List(8, FillDir.Horizontal) })

					local function MakePromptButton(text, order, primary)
						local b = New("TextButton", {
							Text = text,
							FontFace = F(Weight.Medium),
							TextSize = 14,
							TextTransparency = primary and 0 or 0.3,
							Size = UDim2.new(0.5, -4, 1, 0),
							BackgroundTransparency = primary and 0 or 0.92,
							LayoutOrder = order,
							Parent = buttonsRow,
						}, { Corner(8) })
						if primary then
							Bind(b, "BackgroundColor3", "Accent")
						end
						b.MouseEnter:Connect(function()
							Play(b, 0.15, { BackgroundTransparency = primary and 0.15 or 0.85 })
						end)
						b.MouseLeave:Connect(function()
							Play(b, 0.15, { BackgroundTransparency = primary and 0 or 0.92 })
						end)
						return b
					end
					local cancelButton = MakePromptButton("Cancel", 0, false)
					local confirmButton = MakePromptButton("Confirm", 1, true)

					-- State -------------------------------------------------
					local hue, sat, val, alphaVal = 0, 0, 1, (isAlpha and CF.Alpha or 0)
					hue, sat, val = CF.Color:ToHSV()

					local function Sync(skipInputs)
						local c = Color3.fromHSV(hue, sat, val)
						newWell.BackgroundColor3 = c
						newWell.BackgroundTransparency = isAlpha and alphaVal or 0
						bar.BackgroundColor3 = Color3.fromHSV(hue, sat, 1)
						barKnob.Position = UDim2.fromScale(1 - val, 0.5)
						local len, phi = sat * R, hue * 2 * math.pi
						ring.Position = UDim2.new(0.5, -len * math.cos(phi), 0.5, len * math.sin(phi))
						if not skipInputs then
							local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
							hexBox.Text = string.format("#%02X%02X%02X", r, g, b)
							redBox.Text, greenBox.Text, blueBox.Text = tostring(r), tostring(g), tostring(b)
							if alphaBox then
								alphaBox.Text = tostring(math.floor(alphaVal * 100 + 0.5) / 100)
							end
						end
					end

					local function ApplySwatch()
						swatch.BackgroundColor3 = CF.Color
						swatch.BackgroundTransparency = isAlpha and (CF.Alpha or 0) or 0
					end

					local function LoadFromSettings()
						hue, sat, val = CF.Color:ToHSV()
						alphaVal = isAlpha and (CF.Alpha or 0) or 0
						oldWell.BackgroundColor3 = CF.Color
						oldWell.BackgroundTransparency = isAlpha and alphaVal or 0
						Sync()
					end

					-- Opening / closing -------------------------------------
					local busy = false
					local function Show(state)
						if busy then
							return
						end
						busy = true
						if state then
							LoadFromSettings()
							overlay.BackgroundTransparency = 1
							promptScale.Scale = 0.9
							overlay.Visible = true
							Play(overlay, 0.25, { BackgroundTransparency = 0.45 })
							Play(promptScale, 0.4, { Scale = 1 }, Ease.Back)
							task.delay(0.1, function() busy = false end)
						else
							Play(overlay, 0.2, { BackgroundTransparency = 1 })
							Play(promptScale, 0.2, { Scale = 0.9 })
							task.delay(0.2, function()
								overlay.Visible = false
								busy = false
							end)
						end
					end

					swatchButton.MouseButton1Click:Connect(function()
						Show(true)
					end)
					cancelButton.MouseButton1Click:Connect(function()
						Show(false)
					end)
					confirmButton.MouseButton1Click:Connect(function()
						CF.Color = Color3.fromHSV(hue, sat, val)
						CF.Alpha = isAlpha and alphaVal or nil
						ApplySwatch()
						Show(false)
						if S.Callback then
							task.spawn(S.Callback, CF.Color, isAlpha and CF.Alpha)
						end
					end)

					-- Interaction -------------------------------------------
					local wheelDown, barDown = false, false

					local function UpdateWheel()
						local mouse = MouseXY()
						local center = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
						local d = (mouse - center) / baseUIScale.Scale
						if d.Magnitude > R then
							d = d.Unit * R
						end
						local phi = math.atan2(-d.Y, d.X)
						hue = (phi + math.pi) / (2 * math.pi)
						sat = math.clamp(d.Magnitude / R, 0, 1)
						Sync()
					end

					local function UpdateBar()
						local frac = math.clamp((MouseXY().X - barTrack.AbsolutePosition.X) / math.max(1, barTrack.AbsoluteSize.X), 0, 1)
						val = 1 - frac
						Sync()
					end

					wheel.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							wheelDown = true
							Play(ring, 0.15, { Size = UDim2.fromOffset(28, 28) }, Ease.Back)
							UpdateWheel()
						end
					end)
					bar.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							barDown = true
							UpdateBar()
						end
					end)
					Connect(UserInputService.InputEnded, function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							if wheelDown then
								Play(ring, 0.2, { Size = UDim2.fromOffset(22, 22) }, Ease.Back)
							end
							wheelDown, barDown = false, false
						end
					end)
					Connect(UserInputService.InputChanged, function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
							if wheelDown then
								UpdateWheel()
							elseif barDown then
								UpdateBar()
							end
						end
					end)

					local function FromRGB()
						local r = math.clamp(tonumber(redBox.Text) or 0, 0, 255)
						local g = math.clamp(tonumber(greenBox.Text) or 0, 0, 255)
						local b = math.clamp(tonumber(blueBox.Text) or 0, 0, 255)
						hue, sat, val = Color3.fromRGB(r, g, b):ToHSV()
						Sync()
					end
					redBox.FocusLost:Connect(FromRGB)
					greenBox.FocusLost:Connect(FromRGB)
					blueBox.FocusLost:Connect(FromRGB)
					hexBox.FocusLost:Connect(function()
						local color = HexToColor3(hexBox.Text)
						if color then
							hue, sat, val = color:ToHSV()
						end
						Sync()
					end)
					if alphaBox then
						alphaBox.FocusLost:Connect(function()
							alphaVal = math.clamp(tonumber(alphaBox.Text) or 0, 0, 1)
							Sync()
						end)
					end

					for _, box in ipairs({ hexBox, redBox, greenBox, blueBox, alphaBox }) do
						box.Focused:Connect(function()
							Play(box, 0.2, { BackgroundTransparency = 0.88 })
						end)
						box.FocusLost:Connect(function()
							Play(box, 0.2, { BackgroundTransparency = 0.94 })
						end)
					end

					Sync()

					function CF:UpdateName(New_) nameLabel.Text = New_ end
					function CF:SetVisibility(State) row.Visible = State end
					function CF:SetColor(color3)
						CF.Color = color3
						ApplySwatch()
						if overlay.Visible then
							LoadFromSettings()
						end
						if S.Callback then
							task.spawn(S.Callback, CF.Color, isAlpha and CF.Alpha)
						end
					end
					function CF:SetAlpha(alpha)
						CF.Alpha = alpha
						ApplySwatch()
						if overlay.Visible then
							LoadFromSettings()
						end
					end
					return Register(CF, Flag)
				end

				-- ProgressBar (new) --------------------------------------
				function SectionFunctions:ProgressBar(S, Flag)
					local PF = { Settings = S, IgnoreConfig = true, Class = "ProgressBar" }
					local min, max = S.Minimum or 0, S.Maximum or 100
					local row, nameLabel = MakeRow({
						Class = "ProgressBar", Name = S.Name, Desc = S.Description,
						Reserve = 60, Height = 52, ExtraBottom = 16, Tooltip = S.Tooltip,
					})

					local valueLabel = New("TextLabel", {
						Name = "Value",
						TextSize = 12,
						TextTransparency = 0.4,
						TextXAlignment = TXA.Right,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 0, 0, 9),
						Size = UDim2.fromOffset(60, 18),
						Parent = row,
					})

					local track = New("Frame", {
						Name = "Track",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 0, 1, -15),
						Size = UDim2.new(1, 0, 0, 6),
						BackgroundTransparency = 0.9,
						ClipsDescendants = true,
						Parent = row,
					}, { Corner(999) })

					local fill = New("Frame", {
						Size = UDim2.fromScale(0, 1),
						BackgroundTransparency = 0,
						Parent = track,
					}, { Corner(999) })
					Bind(fill, "BackgroundColor3", "Accent")

					function PF:Set(value, instant)
						value = math.clamp(value, min, max)
						PF.Value = value
						local pct = (max == min) and 0 or (value - min) / (max - min)
						if instant then
							fill.Size = UDim2.fromScale(pct, 1)
						else
							Play(fill, 0.5, { Size = UDim2.fromScale(pct, 1) })
						end
						valueLabel.Text = (S.Prefix or "") .. tostring(math.round(pct * 100)) .. "%" .. (S.Suffix or "")
					end
					function PF:Get() return PF.Value end
					function PF:UpdateName(Name) nameLabel.Text = Name end
					function PF:SetVisibility(State) row.Visible = State end
					PF:Set(S.Default or min, true)
					return Register(PF, Flag)
				end

				-- Text elements ------------------------------------------
				function SectionFunctions:Header(S, Flag)
					local HF = { Settings = S }
					local header = New("Frame", {
						Name = "Header",
						AutomaticSize = Auto.Y,
						Size = UDim2.fromScale(1, 0),
						Parent = section,
					}, { Pad(0, 0, 0, 4) })
					local text = New("TextLabel", {
						Name = "HeaderText",
						Text = S.Text or S.Name or "",
						FontFace = F(Weight.SemiBold),
						TextSize = 16,
						TextTransparency = 0.15,
						TextWrapped = true,
						TextXAlignment = TXA.Left,
						AutomaticSize = Auto.Y,
						Size = UDim2.fromScale(1, 0),
						Parent = header,
					})
					function HF:UpdateName(New_) text.Text = New_ end
					function HF:SetVisibility(State) header.Visible = State end
					return Register(HF, Flag)
				end

				function SectionFunctions:Label(S, Flag)
					local LF = { Settings = S }
					local label = New("Frame", {
						Name = "Label",
						AutomaticSize = Auto.Y,
						Size = UDim2.new(1, 0, 0, 20),
						Parent = section,
					})
					local text = New("TextLabel", {
						Name = "LabelText",
						Text = S.Text or S.Name or "",
						TextTransparency = 0.45,
						TextWrapped = true,
						TextXAlignment = TXA.Left,
						AutomaticSize = Auto.Y,
						Size = UDim2.fromScale(1, 0),
						Parent = label,
					})
					function LF:UpdateName(New_) text.Text = New_ end
					function LF:SetVisibility(State) label.Visible = State end
					return Register(LF, Flag)
				end

				function SectionFunctions:SubLabel(S, Flag)
					local SF2 = { Settings = S }
					local frame = New("Frame", {
						Name = "SubLabel",
						AutomaticSize = Auto.Y,
						Size = UDim2.new(1, 0, 0, 0),
						Parent = section,
					})
					local text = New("TextLabel", {
						Name = "SubLabelText",
						Text = S.Text or S.Name or "",
						TextSize = 12,
						TextTransparency = 0.7,
						TextWrapped = true,
						TextXAlignment = TXA.Left,
						AutomaticSize = Auto.Y,
						Size = UDim2.fromScale(1, 0),
						Parent = frame,
					})
					function SF2:UpdateName(New_) text.Text = New_ end
					function SF2:SetVisibility(State) frame.Visible = State end
					return Register(SF2, Flag)
				end

				function SectionFunctions:Paragraph(S, Flag)
					local PF = { Settings = S }
					local paragraph = New("Frame", {
						Name = "Paragraph",
						AutomaticSize = Auto.Y,
						Size = UDim2.new(1, 0, 0, 38),
						Parent = section,
					}, { List(5) })
					local headerLabel = New("TextLabel", {
						Name = "ParagraphHeader",
						Text = S.Header or "",
						FontFace = F(Weight.Medium),
						TextSize = 15,
						TextTransparency = 0.25,
						TextWrapped = true,
						TextXAlignment = TXA.Left,
						AutomaticSize = Auto.Y,
						Size = UDim2.fromScale(1, 0),
						Parent = paragraph,
					})
					local bodyLabel = New("TextLabel", {
						Name = "ParagraphBody",
						Text = S.Body or "",
						TextTransparency = 0.5,
						TextWrapped = true,
						TextXAlignment = TXA.Left,
						AutomaticSize = Auto.Y,
						Size = UDim2.fromScale(1, 0),
						LayoutOrder = 1,
						Parent = paragraph,
					})
					function PF:UpdateHeader(New_) headerLabel.Text = New_ end
					function PF:UpdateBody(New_) bodyLabel.Text = New_ end
					function PF:SetVisibility(State) paragraph.Visible = State end
					return Register(PF, Flag)
				end

				function SectionFunctions:Divider()
					local DivF = {}
					local divider = New("Frame", {
						Name = "Divider",
						Size = UDim2.new(1, 0, 0, 1),
						BackgroundTransparency = 0.92,
						Parent = section,
					})
					function DivF:Remove() divider:Destroy() end
					function DivF:SetVisibility(State) divider.Visible = State end
					return DivF
				end

				function SectionFunctions:Spacer()
					local SpF = {}
					local spacer = New("Frame", {
						Name = "Spacer",
						Size = UDim2.new(1, 0, 0, 6),
						Parent = section,
					})
					function SpF:Remove() spacer:Destroy() end
					function SpF:SetVisibility(State) spacer.Visible = State end
					return SpF
				end

				return SectionFunctions
			end

			------------------------------------------------------------------
			-- Config section
			------------------------------------------------------------------
			function TabFunctions:InsertConfigSection(Side)
				local configSection = TabFunctions:Section({ Side = Side or "Left", Title = "Configs" })

				if not ConfigAvailable() then
					configSection:Label({ Text = "Config system unavailable in this environment." })
					return "Config system unavailable."
				end
				BuildFolderTree()

				local inputPath, selectedConfig = nil, nil

				configSection:Input({
					Name = "Config Name",
					Placeholder = "Name",
					AcceptedCharacters = "All",
					Callback = function(input)
						inputPath = input
					end,
				})

				local configSelection = configSection:Dropdown({
					Name = "Select Config",
					Multi = false,
					Required = false,
					Search = true,
					Options = MacLib:RefreshConfigList(),
					Callback = function(Value)
						selectedConfig = Value
					end,
				})

				local function refreshList()
					configSelection:ClearOptions()
					configSelection:InsertOptions(MacLib:RefreshConfigList())
				end

				configSection:Button({
					Name = "Create Config",
					Callback = function()
						if not inputPath or string.gsub(inputPath, " ", "") == "" then
							WindowFunctions:Notify({ Title = "Interface", Description = "Config name cannot be empty.", Type = "Warning" })
							return
						end
						local success, returned = MacLib:SaveConfig(inputPath)
						if not success then
							WindowFunctions:Notify({ Title = "Interface", Description = "Unable to save config: " .. tostring(returned), Type = "Error" })
							return
						end
						WindowFunctions:Notify({ Title = "Interface", Description = string.format("Created config %q", inputPath), Type = "Success" })
						refreshList()
					end,
				})

				configSection:Button({
					Name = "Load Config",
					Callback = function()
						local success, returned = MacLib:LoadConfig(selectedConfig)
						if not success then
							WindowFunctions:Notify({ Title = "Interface", Description = "Unable to load config: " .. tostring(returned), Type = "Error" })
							return
						end
						WindowFunctions:Notify({ Title = "Interface", Description = string.format("Loaded config %q", selectedConfig), Type = "Success" })
					end,
				})

				configSection:Button({
					Name = "Overwrite Config",
					Callback = function()
						local success, returned = MacLib:SaveConfig(selectedConfig)
						if not success then
							WindowFunctions:Notify({ Title = "Interface", Description = "Unable to overwrite config: " .. tostring(returned), Type = "Error" })
							return
						end
						WindowFunctions:Notify({ Title = "Interface", Description = string.format("Overwrote config %q", selectedConfig), Type = "Success" })
					end,
				})

				configSection:Button({
					Name = "Refresh Config List",
					Callback = refreshList,
				})

				local autoloadLabel
				configSection:Button({
					Name = "Set as autoload",
					Callback = function()
						if not selectedConfig then
							WindowFunctions:Notify({ Title = "Interface", Description = "Select a config first.", Type = "Warning" })
							return
						end
						writefile(MacLib.Folder .. "/settings/autoload.txt", selectedConfig)
						autoloadLabel:UpdateName("Autoload config: " .. selectedConfig)
						WindowFunctions:Notify({ Title = "Interface", Description = string.format("Set %q as autoload", selectedConfig), Type = "Success" })
					end,
				})

				autoloadLabel = configSection:Label({ Text = "Autoload config: None" })
				if isfile(MacLib.Folder .. "/settings/autoload.txt") then
					autoloadLabel:UpdateName("Autoload config: " .. readfile(MacLib.Folder .. "/settings/autoload.txt"))
				end
			end

			return TabFunctions
		end

		return GroupFunctions
	end

	----------------------------------------------------------------------
	-- Global settings
	----------------------------------------------------------------------
	function WindowFunctions:GlobalSetting(S)
		hasGlobalSetting = true
		local GF = {}
		local state = S.Default and true or false

		local item = New("TextButton", {
			Name = "GlobalSetting",
			Size = UDim2.fromOffset(210, 32),
			Parent = globalSettings,
		}, { Pad(14, 0, 14, 0) })

		local itemName = New("TextLabel", {
			Name = "SettingName",
			Text = S.Name,
			TextTransparency = 0.5,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = TXA.Left,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, -26, 1, 0),
			Parent = item,
		})

		local check = New("TextLabel", {
			Name = "Checkmark",
			Text = CHECK,
			TextSize = 14,
			TextTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(16, 16),
			Parent = item,
		})
		Bind(check, "TextColor3", "Accent")

		local function Visual(on)
			Play(check, 0.25, { TextTransparency = on and 0 or 1 })
			Play(itemName, 0.25, { TextTransparency = on and 0.1 or 0.5 })
		end
		Visual(state)

		item.MouseEnter:Connect(function()
			Play(item, 0.15, { BackgroundTransparency = 0.95 })
		end)
		item.MouseLeave:Connect(function()
			Play(item, 0.15, { BackgroundTransparency = 1 })
		end)
		item.MouseButton1Click:Connect(function()
			state = not state
			Visual(state)
			if S.Callback then
				task.spawn(S.Callback, state)
			end
		end)

		function GF:UpdateName(NewName) itemName.Text = NewName end
		function GF:UpdateState(NewState)
			state = NewState and true or false
			Visual(state)
		end
		return GF
	end

	----------------------------------------------------------------------
	-- Notifications
	----------------------------------------------------------------------
	local notifyColors = {
		Success = Color3.fromRGB(48, 209, 88),
		Warning = Color3.fromRGB(255, 159, 10),
		Error = Color3.fromRGB(255, 69, 58),
	}
	local notifyGlyphs = { Info = "i", Success = CHECK, Warning = "!", Error = CROSS }

	function WindowFunctions:Notify(S)
		S = S or {}
		local NF = {}
		local width = S.SizeX or 290
		local nType = S.Type
		local color = nType and (notifyColors[nType] or Theme.Accent) or nil
		local lifetime = S.Lifetime or 3

		local wrapper = New("Frame", {
			Name = "Notification",
			AutomaticSize = Auto.Y,
			Size = UDim2.fromOffset(width, 0),
			Parent = notifications,
		})

		local card = New("Frame", {
			Name = "Card",
			AutomaticSize = Auto.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.fromOffset(width + 40, 0),
			BackgroundColor3 = Theme.Surface,
			BackgroundTransparency = 0,
			ClipsDescendants = true,
			Parent = wrapper,
		}, { Corner(12), Stroke(0.88) })

		local textArea = New("Frame", {
			Name = "Text",
			AutomaticSize = Auto.Y,
			Size = UDim2.fromScale(1, 0),
			Parent = card,
		}, { List(3), Pad(color and 48 or 16, 13, 36, 15) })

		local titleLabel = New("TextLabel", {
			Name = "NotificationTitle",
			Text = S.Title or "",
			FontFace = F(Weight.SemiBold),
			TextTransparency = 0.1,
			TextXAlignment = TXA.Left,
			TextWrapped = true,
			AutomaticSize = Auto.Y,
			Size = UDim2.fromScale(1, 0),
			Parent = textArea,
		})
		local descLabel = New("TextLabel", {
			Name = "NotificationDescription",
			Text = S.Description or "",
			TextSize = 12,
			TextTransparency = 0.45,
			TextXAlignment = TXA.Left,
			TextWrapped = true,
			AutomaticSize = Auto.Y,
			Size = UDim2.fromScale(1, 0),
			LayoutOrder = 1,
			Parent = textArea,
		})

		if color then
			local iconCircle = New("Frame", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(14, 13),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = color,
				BackgroundTransparency = 0.8,
				Parent = card,
			}, { Corner(999) })
			New("TextLabel", {
				Text = notifyGlyphs[nType] or "i",
				FontFace = F(Weight.Bold),
				TextSize = 13,
				TextColor3 = color,
				Size = UDim2.fromScale(1, 1),
				Parent = iconCircle,
			})
			Play(iconCircle, 0.6, { Size = UDim2.fromOffset(22, 22) }, Ease.Elastic)
		end

		local progress
		if lifetime ~= 0 then
			progress = New("Frame", {
				Name = "Progress",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 2),
				BackgroundColor3 = color or Theme.Accent,
				BackgroundTransparency = 0.35,
				Parent = card,
			})
		end

		local closing = false
		local function Dismiss()
			if closing then
				return
			end
			closing = true
			local out = Play(card, 0.35, { Position = UDim2.fromOffset(width + 40, 0) }, Ease.Quint, EDir.In)
			out.Completed:Wait()
			if not wrapper.Parent then
				return
			end
			wrapper.AutomaticSize = Auto.None
			wrapper.Size = UDim2.fromOffset(width, wrapper.AbsoluteSize.Y)
			wrapper.ClipsDescendants = true
			local collapse = Play(wrapper, 0.25, { Size = UDim2.fromOffset(width, 0) })
			collapse.Completed:Wait()
			wrapper:Destroy()
		end

		if S.Style == "Confirm" or S.Style == "Cancel" then
			local closeButton = New("TextButton", {
				Name = "Interactable",
				Text = S.Style == "Confirm" and CHECK or CROSS,
				TextSize = 15,
				TextTransparency = 0.3,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 8),
				Size = UDim2.fromOffset(24, 24),
				Parent = card,
			}, { Corner(6) })
			closeButton.MouseEnter:Connect(function()
				Play(closeButton, 0.15, { BackgroundTransparency = 0.88, TextTransparency = 0 })
			end)
			closeButton.MouseLeave:Connect(function()
				Play(closeButton, 0.15, { BackgroundTransparency = 1, TextTransparency = 0.3 })
			end)
			closeButton.MouseButton1Click:Connect(function()
				task.spawn(Dismiss)
				if S.Callback then
					task.spawn(S.Callback)
				end
			end)
		end

		Play(card, 0.55, { Position = UDim2.fromOffset(0, 0) }, Ease.Back)

		if progress then
			Play(progress, lifetime, { Size = UDim2.new(0, 0, 0, 2) }, Ease.Linear)
			task.delay(lifetime, Dismiss)
		end

		function NF:UpdateTitle(New_) titleLabel.Text = New_ end
		function NF:UpdateDescription(New_) descLabel.Text = New_ end
		function NF:Resize(X)
			width = X or 290
			wrapper.Size = UDim2.fromOffset(width, 0)
		end
		function NF:Cancel() Dismiss() end
		return NF
	end

	function WindowFunctions:SetNotificationsState(State)
		notifications.Visible = State
	end
	function WindowFunctions:GetNotificationsState()
		return notifications.Visible
	end

	----------------------------------------------------------------------
	-- Dialog
	----------------------------------------------------------------------
	function WindowFunctions:Dialog(S)
		S = S or {}
		local DiF = {}
		local buttons = S.Buttons or { { Name = "OK" } }

		local overlay = New("Frame", {
			Name = "Dialog",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			Active = true,
			ZIndex = 60,
			Parent = base,
		}, { Corner(12) })

		local promptScale = New("UIScale", { Scale = 0.85 })
		local prompt = New("Frame", {
			Name = "Prompt",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(S.Width or 320, 0),
			AutomaticSize = Auto.Y,
			BackgroundTransparency = 0,
			Parent = overlay,
		}, { promptScale, Corner(14), Stroke(0.88), Pad(20, 20, 20, 18), List(16) })
		Bind(prompt, "BackgroundColor3", "Surface")

		local textBlock = New("Frame", {
			Name = "Text",
			AutomaticSize = Auto.Y,
			Size = UDim2.fromScale(1, 0),
			Parent = prompt,
		}, { List(8) })

		local titleLabel = New("TextLabel", {
			Name = "ParagraphHeader",
			Text = S.Title or "",
			FontFace = F(Weight.SemiBold),
			TextSize = 17,
			TextTransparency = 0.05,
			TextWrapped = true,
			TextXAlignment = TXA.Left,
			AutomaticSize = Auto.Y,
			Size = UDim2.fromScale(1, 0),
			Parent = textBlock,
		})
		local descLabel = New("TextLabel", {
			Name = "ParagraphBody",
			Text = S.Description or "",
			TextSize = 13,
			TextTransparency = 0.45,
			TextWrapped = true,
			TextXAlignment = TXA.Left,
			AutomaticSize = Auto.Y,
			Size = UDim2.fromScale(1, 0),
			LayoutOrder = 1,
			Parent = textBlock,
		})

		local row = New("Frame", {
			Name = "Interactions",
			Size = UDim2.new(1, 0, 0, 36),
			LayoutOrder = 1,
			Parent = prompt,
		}, { List(8, FillDir.Horizontal) })

		local closed = false
		local function Close()
			if closed then
				return
			end
			closed = true
			Play(overlay, 0.2, { BackgroundTransparency = 1 })
			Play(promptScale, 0.2, { Scale = 0.85 }, Ease.Quint, EDir.In)
			task.delay(0.22, function()
				overlay:Destroy()
			end)
		end

		local n = #buttons
		for i, v in ipairs(buttons) do
			local style = v.Style or (i == 1 and n > 1 and "Primary" or "Default")
			local baseColor = style == "Destructive" and Color3.fromRGB(255, 69, 58) or nil
			local button = New("TextButton", {
				Name = "Button",
				Text = v.Name,
				FontFace = F(Weight.Medium),
				TextSize = 14,
				TextTransparency = style == "Default" and 0.3 or 0,
				BackgroundTransparency = style == "Default" and 0.92 or 0,
				Size = UDim2.new(1 / n, -math.ceil(8 * (n - 1) / n), 1, 0),
				LayoutOrder = i,
				ClipsDescendants = true,
				Parent = row,
			}, { Corner(9) })

			if style == "Primary" then
				Bind(button, "BackgroundColor3", "Accent")
			elseif style == "Destructive" then
				button.BackgroundColor3 = baseColor
			end

			local idleTransparency = style == "Default" and 0.92 or 0
			local hoverTransparency = style == "Default" and 0.84 or 0.15
			button.MouseEnter:Connect(function()
				Play(button, 0.15, { BackgroundTransparency = hoverTransparency })
			end)
			button.MouseLeave:Connect(function()
				Play(button, 0.15, { BackgroundTransparency = idleTransparency })
			end)
			button.MouseButton1Down:Connect(function()
				Ripple(button)
			end)
			button.MouseButton1Click:Connect(function()
				if closed then
					return
				end
				if v.Callback then
					task.spawn(v.Callback)
				end
				Close()
			end)
		end

		Play(overlay, 0.25, { BackgroundTransparency = 0.45 })
		Play(promptScale, 0.45, { Scale = 1 }, Ease.Back)

		function DiF:UpdateTitle(New_) titleLabel.Text = New_ end
		function DiF:UpdateDescription(New_) descLabel.Text = New_ end
		function DiF:Cancel() Close() end
		return DiF
	end

	----------------------------------------------------------------------
	-- Window API
	----------------------------------------------------------------------
	function WindowFunctions:UpdateTitle(NewTitle) title.Text = NewTitle end
	function WindowFunctions:UpdateSubtitle(NewSubtitle) subtitle.Text = NewSubtitle end

	function WindowFunctions:SetState(State) SetVisible(State) end
	function WindowFunctions:GetState() return windowState end

	local MenuKeybind = Settings.Keybind or Enum.KeyCode.RightControl

	function WindowFunctions:ToggleMenu()
		local state = not windowState
		SetVisible(state)
		WindowFunctions:Notify({
			Title = Settings.Title,
			Description = (state and "Maximized " or "Minimized ") .. "the menu. Use " .. tostring(MenuKeybind.Name) .. " to toggle it.",
			Lifetime = 4,
		})
	end

	function WindowFunctions:SetKeybind(Keycode) MenuKeybind = Keycode end

	Connect(UserInputService.InputEnded, function(input, gpe)
		if gpe then
			return
		end
		if input.KeyCode == MenuKeybind then
			WindowFunctions:ToggleMenu()
		end
	end)

	function WindowFunctions:SetAcrylicBlurState(State)
		acrylicBlur = State and true or false
		Play(base, 0.3, { BackgroundTransparency = baseTransparency() })
	end
	function WindowFunctions:GetAcrylicBlurState() return acrylicBlur end

	local showUserInfo = Settings.ShowUserInfo ~= false
	local function ApplyUserInfo(state)
		showUserInfo = state
		if state then
			headshot.Image = (isReady and headshotImage) or "rbxassetid://0"
			username.Text = "@" .. LocalPlayer.Name
			displayName.Text = LocalPlayer.DisplayName
		else
			headshot.Image = assets.userInfoBlurred
			username.Text = "@" .. string.rep(".", #LocalPlayer.Name)
			displayName.Text = string.rep(".", #LocalPlayer.DisplayName)
		end
	end
	ApplyUserInfo(showUserInfo)
	function WindowFunctions:SetUserInfoState(State) ApplyUserInfo(State) end
	function WindowFunctions:GetUserInfoState() return showUserInfo end

	function WindowFunctions:SetSize(Size) base.Size = Size end
	function WindowFunctions:GetSize() return base.Size end

	function WindowFunctions:SetScale(Scale)
		userScale = Scale
		baseUIScale.Scale = userScale * animValue.Value
	end
	function WindowFunctions:GetScale() return userScale end

	function WindowFunctions:SetTheme(nameOrTable)
		local theme = type(nameOrTable) == "string" and MacLib.Themes[nameOrTable] or nameOrTable
		if type(theme) == "table" then
			ApplyTheme(theme)
		end
	end
	function WindowFunctions:SetAccent(color) ApplyTheme({ Accent = color }) end
	function WindowFunctions:GetTheme() return Theme end

	function WindowFunctions.onUnloaded(callback)
		onUnloadCallback = callback
	end

	function WindowFunctions:Unload()
		if unloaded then
			return
		end
		if onUnloadCallback then
			task.spawn(onUnloadCallback)
		end
		unloaded = true
		if WindowFunctions._hideBlur then
			WindowFunctions._hideBlur()
		end
		for _, part in pairs(blurParts) do
			part:Destroy()
		end
		if DepthOfField then
			DepthOfField.Parent = nil
		end
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
		animValue:Destroy()

		-- outro
		Play(animValue, 0, {})
		Play(base, 0.25, { BackgroundTransparency = 1 })
		Play(baseUIScale, 0.3, { Scale = userScale * 0.8 }, Ease.Quint, EDir.In)
		task.delay(0.32, function()
			macLib:Destroy()
		end)
	end

	----------------------------------------------------------------------
	-- Finish: preload, enable, intro animation
	----------------------------------------------------------------------
	local assetList = {}
	for _, assetId in pairs(assets) do
		table.insert(assetList, assetId)
	end
	pcall(function()
		ContentProvider:PreloadAsync(assetList)
	end)

	macLib.Enabled = true
	windowState = true
	Play(base, 0.4, { BackgroundTransparency = baseTransparency() })
	Play(animValue, 0.65, { Value = 1 }, Ease.Back)

	return WindowFunctions
end

--// Demo ---------------------------------------------------------------------

function MacLib:Demo()
	local Window = MacLib:Window({
		Title = "Maclib Demo",
		Subtitle = "This is a subtitle.",
		Size = UDim2.fromOffset(868, 650),
		DragStyle = 1,
		DisabledWindowControls = {},
		ShowUserInfo = true,
		Keybind = Enum.KeyCode.RightControl,
		AcrylicBlur = true,
		TabSearch = true,
		Theme = "Dark",
	})

	Window:GlobalSetting({
		Name = "UI Blur",
		Default = Window:GetAcrylicBlurState(),
		Callback = function(bool)
			Window:SetAcrylicBlurState(bool)
			Window:Notify({ Title = Window.Settings.Title, Description = (bool and "Enabled" or "Disabled") .. " UI Blur", Lifetime = 4 })
		end,
	})
	Window:GlobalSetting({
		Name = "Notifications",
		Default = Window:GetNotificationsState(),
		Callback = function(bool)
			Window:SetNotificationsState(bool)
			Window:Notify({ Title = Window.Settings.Title, Description = (bool and "Enabled" or "Disabled") .. " Notifications", Lifetime = 4 })
		end,
	})
	Window:GlobalSetting({
		Name = "Show User Info",
		Default = Window:GetUserInfoState(),
		Callback = function(bool)
			Window:SetUserInfoState(bool)
		end,
	})

	local group = Window:TabGroup()
	local mainTab = group:Tab({ Name = "Demo", Image = "rbxassetid://18821914323" })
	local themeTab = group:Tab({ Name = "Themes", Image = "rbxassetid://10734950309" })
	local settingsTab = group:Tab({ Name = "Settings", Image = "rbxassetid://10734950309" })

	local left = mainTab:Section({ Side = "Left", Title = "Controls" })

	left:Header({ Name = "Header #1" })
	left:Button({
		Name = "Button",
		Description = "Click for a dialog",
		Tooltip = "Opens an animated dialog",
		Callback = function()
			Window:Dialog({
				Title = Window.Settings.Title,
				Description = "Lorem ipsum odor amet, consectetuer adipiscing elit. Eros vestibulum aliquet mattis, ex platea nunc.",
				Buttons = {
					{ Name = "Confirm", Callback = function() print("Confirmed!") end },
					{ Name = "Cancel" },
				},
			})
		end,
	})
	left:Input({
		Name = "Input",
		Placeholder = "Type here",
		AcceptedCharacters = "All",
		Callback = function(input)
			Window:Notify({ Title = Window.Settings.Title, Description = "Successfully set input to " .. input, Type = "Success" })
		end,
		onChanged = function(input) print("Input is now " .. input) end,
	}, "Input")
	left:Slider({
		Name = "Slider",
		Default = 50,
		Minimum = 0,
		Maximum = 100,
		DisplayMethod = "Percent",
		Precision = 0,
		Callback = function(Value) print("Changed to " .. Value) end,
	}, "Slider")
	left:Toggle({
		Name = "Toggle",
		Description = "Flip the switch",
		Default = false,
		Callback = function(value)
			Window:Notify({
				Title = Window.Settings.Title,
				Description = (value and "Enabled " or "Disabled ") .. "Toggle",
				Type = value and "Success" or "Info",
			})
		end,
	}, "Toggle")
	left:Keybind({
		Name = "Keybind",
		Callback = function(binded)
			Window:Notify({ Title = "Demo Window", Description = "Pressed keybind - " .. tostring(binded.Name), Lifetime = 3 })
		end,
		onBinded = function(bind)
			Window:Notify({ Title = "Demo Window", Description = "Bound keybind to - " .. tostring(bind.Name), Lifetime = 3, Type = "Info" })
		end,
	}, "Keybind")

	local right = mainTab:Section({ Side = "Right", Title = "Pickers" })
	right:Colorpicker({
		Name = "Colorpicker",
		Default = Color3.fromRGB(0, 255, 255),
		Callback = function(color) print("Color: ", color) end,
	}, "Colorpicker")

	local alphaPicker = right:Colorpicker({
		Name = "Transparency Colorpicker",
		Default = Color3.fromRGB(255, 0, 0),
		Alpha = 0,
		Callback = function(color, alpha) print("Color: ", color, " Alpha: ", alpha) end,
	}, "TransparencyColorpicker")

	local rainbowConnection
	local hue = 0
	right:Toggle({
		Name = "Rainbow",
		Default = false,
		Callback = function(value)
			if value then
				rainbowConnection = RunService.RenderStepped:Connect(function(dt)
					hue = (hue + dt * 0.1) % 1
					alphaPicker:SetColor(Color3.fromHSV(hue, 1, 1))
				end)
			elseif rainbowConnection then
				rainbowConnection:Disconnect()
				rainbowConnection = nil
			end
		end,
	}, "RainbowToggle")

	local fruits = { "Apple", "Banana", "Orange", "Grapes", "Pineapple", "Mango", "Strawberry", "Blueberry", "Watermelon", "Peach" }
	local single = right:Dropdown({
		Name = "Dropdown",
		Multi = false,
		Required = true,
		Options = fruits,
		Default = 1,
		Callback = function(Value) print("Dropdown changed: " .. tostring(Value)) end,
	}, "Dropdown")
	local multi = right:Dropdown({
		Name = "Multi Dropdown",
		Search = true,
		Multi = true,
		Required = false,
		Options = fruits,
		Default = { "Apple", "Orange" },
		Callback = function(Value)
			local picked = {}
			for name in pairs(Value) do table.insert(picked, name) end
			print("Multidropdown changed:", table.concat(picked, ", "))
		end,
	}, "MultiDropdown")
	right:Button({
		Name = "Update Selection",
		Callback = function()
			single:UpdateSelection("Grapes")
			multi:UpdateSelection({ "Banana", "Pineapple" })
		end,
	})

	local extras = mainTab:Section({ Side = "Left", Title = "Extras" })
	local bar = extras:ProgressBar({ Name = "Progress", Default = 0 })
	extras:Button({
		Name = "Animate progress",
		Callback = function()
			bar:Set(0, true)
			task.wait(0.05)
			bar:Set(100)
		end,
	})
	extras:Divider()
	extras:Paragraph({ Header = "Paragraph", Body = "Paragraph body. Lorem ipsum odor amet, consectetuer adipiscing elit." })
	extras:Label({ Text = "Label. Lorem ipsum odor amet, consectetuer adipiscing elit." })
	extras:SubLabel({ Text = "Sub-Label. Lorem ipsum odor amet, consectetuer adipiscing elit." })

	local themes = themeTab:Section({ Side = "Left", Title = "Appearance" })
	local names = {}
	for name in pairs(MacLib.Themes) do table.insert(names, name) end
	table.sort(names)
	themes:Dropdown({
		Name = "Theme",
		Options = names,
		Default = "Dark",
		Callback = function(name) Window:SetTheme(name) end,
	})
	themes:Colorpicker({
		Name = "Accent",
		Default = Window:GetTheme().Accent,
		Callback = function(color) Window:SetAccent(color) end,
	})
	themes:Slider({
		Name = "UI Scale",
		Default = 1,
		Minimum = 0.6,
		Maximum = 1.4,
		Step = 0.05,
		Callback = function(v) Window:SetScale(v) end,
	})
	local notifySection = themeTab:Section({ Side = "Right", Title = "Notifications" })
	for _, kind in ipairs({ "Info", "Success", "Warning", "Error" }) do
		notifySection:Button({
			Name = kind .. " notification",
			Callback = function()
				Window:Notify({ Title = kind, Description = "This is a " .. kind:lower() .. " notification.", Type = kind, Lifetime = 4 })
			end,
		})
	end

	MacLib:SetFolder("Maclib")
	settingsTab:InsertConfigSection("Left")

	Window.onUnloaded(function()
		print("Unloaded!")
	end)

	mainTab:Select()
	MacLib:LoadAutoLoadConfig()
end

return MacLib
