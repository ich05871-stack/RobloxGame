--!nocheck
-- Minimaler Nachbau der Roblox-API, damit HouseModel.lua außerhalb von Studio mit der Luau-CLI läuft.
-- Enthält nur, was HouseModel.lua und export.luau benutzen.

local V = {}
V.__index = function(v, k)
	if k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Cross" then
		return function(a, b)
			return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	end
	error("Vector3 has no member " .. tostring(k))
end
V.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
V.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b)
	return Vector3.new(a.X / b, a.Y / b, a.Z / b)
end

Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

-- CFrame als Position p plus Spalten x (RightVector), y (UpVector), z (-LookVector)
local C = {}
local function cframe(p, x, y, z)
	return setmetatable({ p = p, x = x, y = y, z = z }, C)
end
local function rotate(cf, v)
	return cf.x * v.X + cf.y * v.Y + cf.z * v.Z
end
C.__index = function(cf, k)
	if k == "Position" then
		return cf.p
	elseif k == "Inverse" then
		return function(self)
			-- Transponierte der Rotation, Position zurückgedreht
			local x = Vector3.new(self.x.X, self.y.X, self.z.X)
			local y = Vector3.new(self.x.Y, self.y.Y, self.z.Y)
			local z = Vector3.new(self.x.Z, self.y.Z, self.z.Z)
			local inv = cframe(Vector3.new(), x, y, z)
			return cframe(-rotate(inv, self.p), x, y, z)
		end
	end
	error("CFrame has no member " .. tostring(k))
end
C.__mul = function(a, b)
	if getmetatable(b) == C then
		return cframe(a.p + rotate(a, b.p), rotate(a, b.x), rotate(a, b.y), rotate(a, b.z))
	end
	return a.p + rotate(a, b)
end

CFrame = {}
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return cframe(x, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
	end
	return cframe(Vector3.new(x or 0, y or 0, z or 0), Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return cframe(Vector3.new(), Vector3.new(1, 0, 0), Vector3.new(0, c, s), Vector3.new(0, -s, c))
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return cframe(Vector3.new(), Vector3.new(c, 0, -s), Vector3.new(0, 1, 0), Vector3.new(s, 0, c))
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return cframe(Vector3.new(), Vector3.new(c, s, 0), Vector3.new(-s, c, 0), Vector3.new(0, 0, 1))
end
function CFrame.Angles(a, b, c)
	return rx(a) * ry(b) * rz(c)
end
function CFrame.fromMatrix(p, vx, vy, vz)
	return cframe(p, vx, vy, vz or vx:Cross(vy).Unit)
end
function CFrame.lookAt(at, target, up)
	local look = (target - at).Unit
	local right = look:Cross(up or Vector3.yAxis).Unit
	return cframe(at, right, right:Cross(look), -look)
end

Color3 = {}
function Color3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end

-- Enum-Werte wie in der Roblox-API (für die .rbxmx-Ausgabe)
local function enum(enumName, items)
	local result = {}
	for name, value in items do
		result[name] = { Name = name, Value = value }
	end
	return setmetatable(result, {
		__index = function(_, k)
			error(tostring(k) .. " is not a valid member of Enum " .. enumName)
		end,
	})
end
Enum = {
	Material = enum("Material", {
		SmoothPlastic = 272,
		Neon = 288,
		Wood = 512,
		Slate = 800,
		Concrete = 816,
		Limestone = 820,
		Pavement = 836,
		Brick = 848,
		Metal = 1088,
		Grass = 1280,
		LeafyGrass = 1284,
		Glass = 1568,
		ClayRoofTiles = 2307,
		Plaster = 2310,
	}),
	PartType = enum("PartType", { Ball = 0, Block = 1, Cylinder = 2 }),
	SurfaceType = enum("SurfaceType", { Smooth = 0 }),
}

local instanceMethods = {}
function instanceMethods.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function instanceMethods.GetDescendants(self)
	local result = {}
	for _, child in rawget(self, "_children") do
		table.insert(result, child)
		for _, d in child:GetDescendants() do
			table.insert(result, d)
		end
	end
	return result
end
function instanceMethods.PivotTo(self, target)
	local delta = target * self.WorldPivot:Inverse()
	for _, d in self:GetDescendants() do
		if d.CFrame then
			d.CFrame = delta * d.CFrame
		end
	end
	self.WorldPivot = target
end

local I = {}
I.__index = function(inst, k)
	local props = rawget(inst, "_props")
	if props[k] ~= nil then
		return props[k]
	end
	return instanceMethods[k]
end
I.__newindex = function(inst, k, v)
	if k == "Parent" then
		table.insert(rawget(v, "_children"), inst)
	end
	rawget(inst, "_props")[k] = v
end

Instance = {}
function Instance.new(className)
	local inst = setmetatable({ _props = {}, _children = {} }, I)
	rawget(inst, "_props").ClassName = className
	rawget(inst, "_props").Name = className
	return inst
end

-- Deterministischer Zufall (gleiches Haus bei jedem Build)
Random = {}
function Random.new(seed)
	local state = seed
	local function nextFloat()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextNumber = function(_, a, b)
			return a + (b - a) * nextFloat()
		end,
		NextInteger = function(_, a, b)
			return a + math.floor(nextFloat() * (b - a + 1))
		end,
	}
end
