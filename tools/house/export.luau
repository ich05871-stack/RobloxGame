--!nocheck
-- Wird von build.sh hinter RobloxMock.luau und HouseModel.lua gehängt und gibt das Haus als .rbxmx aus.

-- Vor dem Startpunkt, die Vorderseite zeigt zur Spielfeldmitte
local HOUSE_PIVOT = CFrame.new(0, 0, -40)

local house = HouseModel.new()
house:PivotTo(HOUSE_PIVOT)

local function num(n)
	local s = string.format("%.6f", n)
	s = s:gsub("0+$", "")
	s = s:gsub("%.$", "")
	return if s == "-0" then "0" else s
end

local function escape(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local encoders = {
	string = function(v)
		return escape(v)
	end,
	bool = function(v)
		return tostring(v)
	end,
	float = num,
	token = function(v)
		return tostring(v.Value)
	end,
	Vector3 = function(v)
		return `<X>{num(v.X)}</X><Y>{num(v.Y)}</Y><Z>{num(v.Z)}</Z>`
	end,
	-- R00..R22 sind die Zeilen der Rotationsmatrix, die Spalten sind Right-, Up- und Back-Vektor
	CoordinateFrame = function(cf)
		local p, x, y, z = cf.p, cf.x, cf.y, cf.z
		return `<X>{num(p.X)}</X><Y>{num(p.Y)}</Y><Z>{num(p.Z)}</Z>`
			.. `<R00>{num(x.X)}</R00><R01>{num(y.X)}</R01><R02>{num(z.X)}</R02>`
			.. `<R10>{num(x.Y)}</R10><R11>{num(y.Y)}</R11><R12>{num(z.Y)}</R12>`
			.. `<R20>{num(x.Z)}</R20><R21>{num(y.Z)}</R21><R22>{num(z.Z)}</R22>`
	end,
	Color3 = function(c)
		return `<R>{num(c.R)}</R><G>{num(c.G)}</G><B>{num(c.B)}</B>`
	end,
	Color3uint8 = function(c)
		local function byte(f)
			return math.floor(f * 255 + 0.5)
		end
		return string.format("%.0f", 0xFF000000 + byte(c.R) * 65536 + byte(c.G) * 256 + byte(c.B))
	end,
}

-- { Eigenschaft im Mock, XML-Typ, Name in der Datei }
local partProps = {
	{ "Name", "string", "Name" },
	{ "Anchored", "bool", "Anchored" },
	{ "CanCollide", "bool", "CanCollide" },
	{ "CFrame", "CoordinateFrame", "CFrame" },
	{ "Size", "Vector3", "size" },
	{ "Color", "Color3uint8", "Color3uint8" },
	{ "Material", "token", "Material" },
	{ "Shape", "token", "shape" },
	{ "Reflectance", "float", "Reflectance" },
	{ "TopSurface", "token", "TopSurface" },
	{ "BottomSurface", "token", "BottomSurface" },
}
local classProps = {
	Model = { { "Name", "string", "Name" } },
	Part = partProps,
	WedgePart = partProps,
	PointLight = {
		{ "Name", "string", "Name" },
		{ "Color", "Color3", "Color" },
		{ "Range", "float", "Range" },
		{ "Brightness", "float", "Brightness" },
	},
}

local lines = { '<roblox version="4">' }
local nextRef = 0

local function write(inst, depth)
	local indent = string.rep("\t", depth)
	nextRef += 1
	table.insert(lines, `{indent}<Item class="{inst.ClassName}" referent="RBX{nextRef}">`)
	table.insert(lines, `{indent}\t<Properties>`)
	for _, prop in assert(classProps[inst.ClassName], inst.ClassName) do
		local key, xmlType, xmlName = prop[1], prop[2], prop[3]
		local value = inst[key]
		if value ~= nil then
			table.insert(lines, `{indent}\t\t<{xmlType} name="{xmlName}">{encoders[xmlType](value)}</{xmlType}>`)
		end
	end
	table.insert(lines, `{indent}\t</Properties>`)
	for _, child in inst:GetChildren() do
		write(child, depth + 1)
	end
	table.insert(lines, `{indent}</Item>`)
end

write(house, 1)
table.insert(lines, "</roblox>")
print(table.concat(lines, "\n"))
