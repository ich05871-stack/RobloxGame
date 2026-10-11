-- Baut das Haus aus der Konzeptgrafik komplett aus Parts (ohne Assets):
-- Haupthaus mit Satteldach und Schornstein, Ziergiebel mit Rundbogentür und Rundfenster,
-- Garage mit Seitentür, Ecksteine, Regenrinnen und ein Garten mit Bäumen und Büschen.
-- Lokale Achsen: Vorderseite zeigt nach +Z, von vorne gesehen ist rechts +X, Rasen-Oberkante bei Y = 0.
-- Wird nicht ins Spiel übertragen: build.sh erzeugt daraus src/workspace/Haus.rbxmx.

local HouseModel = {}

-- Neuere Materialien (Plaster, ClayRoofTiles, ...) mit Fallback, falls es sie nicht gibt
local function material(name, fallback)
	local ok, result = pcall(function()
		return Enum.Material[name]
	end)
	return if ok then result else fallback
end

local Colors = {
	Wall = Color3.fromRGB(232, 200, 130),
	Stone = Color3.fromRGB(208, 200, 184),
	Plinth = Color3.fromRGB(150, 145, 135),
	Roof = Color3.fromRGB(205, 72, 45),
	RoofRow = Color3.fromRGB(165, 50, 32),
	Trim = Color3.fromRGB(238, 232, 215),
	Brick = Color3.fromRGB(170, 65, 45),
	Glass = Color3.fromRGB(70, 145, 200),
	Wood = Color3.fromRGB(120, 70, 40),
	WoodDark = Color3.fromRGB(95, 55, 30),
	Gold = Color3.fromRGB(215, 175, 70),
	GarageDoor = Color3.fromRGB(235, 228, 210),
	GarageGroove = Color3.fromRGB(200, 192, 175),
	Grass = Color3.fromRGB(95, 165, 60),
	Path = Color3.fromRGB(175, 170, 160),
	Leaves = { Color3.fromRGB(70, 140, 45), Color3.fromRGB(85, 160, 55), Color3.fromRGB(60, 125, 40) },
	Trunk = Color3.fromRGB(105, 75, 50),
	Metal = Color3.fromRGB(45, 45, 50),
	Pipe = Color3.fromRGB(160, 160, 165),
	Pot = Color3.fromRGB(185, 100, 60),
	Hose = Color3.fromRGB(60, 140, 70),
	Bin = Color3.fromRGB(45, 85, 50),
	Rock = Color3.fromRGB(140, 140, 135),
	LampGlow = Color3.fromRGB(255, 210, 120),
	Flowers = { Color3.fromRGB(250, 215, 60), Color3.fromRGB(235, 90, 70), Color3.fromRGB(250, 240, 230) },
}

local Materials = {
	Wall = material("Plaster", Enum.Material.SmoothPlastic),
	Stone = material("Limestone", Enum.Material.Slate),
	Roof = material("ClayRoofTiles", Enum.Material.Slate),
	Grass = material("LeafyGrass", Enum.Material.Grass),
	Paving = material("Pavement", Enum.Material.Concrete),
	Brick = Enum.Material.Brick,
	Wood = Enum.Material.Wood,
	Glass = Enum.Material.Glass,
	Metal = Enum.Material.Metal,
	Leaves = Enum.Material.Grass,
	Smooth = Enum.Material.SmoothPlastic,
}

-- Zylinderachse aus der Wand heraus (für Rundfenster und Türbogen)
local AXIS_OUT = CFrame.Angles(0, math.pi / 2, 0)
-- Zylinderachse senkrecht nach oben
local AXIS_UP = CFrame.Angles(0, 0, math.pi / 2)

local function newPart(className, parent, size, cframe, color, mat, shape)
	local part = Instance.new(className)
	part.Anchored = true
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = mat or Materials.Smooth
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function block(parent, size, cframe, color, mat)
	return newPart("Part", parent, size, cframe, color, mat)
end

local function wedge(parent, size, cframe, color, mat)
	return newPart("WedgePart", parent, size, cframe, color, mat)
end

-- Die Zylinderachse ist die lokale X-Achse von `cframe`
local function cylinder(parent, length, diameter, cframe, color, mat)
	return newPart("Part", parent, Vector3.new(length, diameter, diameter), cframe, color, mat, Enum.PartType.Cylinder)
end

local function ball(parent, diameter, position, color, mat)
	return newPart("Part", parent, Vector3.one * diameter, CFrame.new(position), color, mat, Enum.PartType.Ball)
end

local function decor(part)
	part.CanCollide = false
	return part
end

local function group(parent, name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- CFrame auf einer Wand: X = nach rechts (vom Betrachter aus), Y = nach oben, Z = aus der Wand heraus.
-- `center` liegt in der Wandfläche auf Bodenhöhe.
local function wallFace(center, normal)
	return CFrame.lookAt(center, center - normal)
end

-- Satteldach mit Ziegelreihen, Firstkappe und Ortgangbrettern.
-- `base` liegt mittig auf Traufhöhe, der First verläuft entlang der lokalen X-Achse.
local function gableRoof(parent, base, length, span, height, opts)
	opts = opts or {}
	local half = span / 2
	local overhang = 1.2
	local width = length + 1.6
	local thickness = 0.7
	local slopeLen = math.sqrt(height * height + half * half)
	local tileLen = slopeLen + overhang

	-- Giebeldreiecke in Wandfarbe
	local fillSize = Vector3.new(length, height, half)
	wedge(parent, fillSize, base * CFrame.new(0, height / 2, -half / 2), Colors.Wall, Materials.Wall)
	wedge(parent, fillSize, base * CFrame.new(0, height / 2, half / 2) * CFrame.Angles(0, math.pi, 0), Colors.Wall, Materials.Wall)

	local ridge = Vector3.new(0, height, 0)
	for _, side in { 1, -1 } do
		local down = Vector3.new(0, -height, side * half).Unit
		local normal = Vector3.new(0, half, side * height).Unit
		-- Punkt auf der Dachfläche: `dist` den Hang hinunter, `lift` senkrecht zur Fläche
		local function onSlope(dist, lift)
			return base * CFrame.fromMatrix(ridge + down * dist + normal * lift, Vector3.xAxis, normal)
		end

		block(parent, Vector3.new(width, thickness, tileLen), onSlope(tileLen / 2, thickness / 2), Colors.Roof, Materials.Roof)
		for dist = 1.2, tileLen - 0.2, 1.5 do
			block(parent, Vector3.new(width, 0.22, 0.4), onSlope(dist, thickness + 0.08), Colors.RoofRow, Materials.Roof)
		end
		for _, x in { -1, 1 } do
			local edge = onSlope(tileLen / 2, -0.25) * CFrame.new(x * (width / 2 - 0.2), 0, 0)
			block(parent, Vector3.new(0.35, 0.6, tileLen), edge, Colors.Trim)
		end
		if (side == 1 and opts.gutterFront) or (side == -1 and opts.gutterBack) then
			cylinder(parent, width, 0.55, onSlope(tileLen - 0.25, -0.2), Colors.Pipe, Materials.Metal)
		end
	end

	cylinder(parent, width + 0.2, 1.1, base * CFrame.new(0, height + thickness * 0.75, 0), Colors.RoofRow, Materials.Roof)
end

-- Ecksteine an einer senkrechten Hauskante; sx/sz zeigen von der Ecke nach außen
local function quoins(parent, cornerX, cornerZ, sx, sz, fromY, toY)
	local blockHeight, gap, stick = 1.1, 0.15, 0.18
	local y, i = fromY, 0
	while y + blockHeight <= toY do
		local a, b = 1.8, 1.1
		if i % 2 == 1 then
			a, b = 1.1, 1.8
		end
		local position = Vector3.new(cornerX - sx * (a / 2 - stick), y + blockHeight / 2, cornerZ - sz * (b / 2 - stick))
		block(parent, Vector3.new(a, blockHeight, b), CFrame.new(position), Colors.Stone, Materials.Stone)
		y += blockHeight + gap
		i += 1
	end
end

-- Rechteckfenster; y = Unterkante der Glasfläche
local function window(parent, face, x, y, w, h, muntins)
	local t = 0.5
	local function at(px, py, pz)
		return face * CFrame.new(x + px, y + py, pz)
	end
	block(parent, Vector3.new(w, h, 0.2), at(0, h / 2, 0), Colors.Glass, Materials.Glass).Reflectance = 0.15
	block(parent, Vector3.new(w + 2 * t, t, 0.4), at(0, h + t / 2, 0.2), Colors.Trim, Materials.Stone)
	block(parent, Vector3.new(t, h, 0.4), at(-(w + t) / 2, h / 2, 0.2), Colors.Trim, Materials.Stone)
	block(parent, Vector3.new(t, h, 0.4), at((w + t) / 2, h / 2, 0.2), Colors.Trim, Materials.Stone)
	-- Fensterbank
	block(parent, Vector3.new(w + 1.4, 0.4, 0.9), at(0, -0.2, 0.45), Colors.Stone, Materials.Stone)
	if muntins then
		block(parent, Vector3.new(0.2, h, 0.16), at(0, h / 2, 0.15), Colors.Trim)
		block(parent, Vector3.new(w, 0.2, 0.16), at(0, h * 0.55, 0.15), Colors.Trim)
	end
end

local function roundWindow(parent, face, x, y, d)
	cylinder(parent, 0.35, d + 1, face * CFrame.new(x, y, 0.175) * AXIS_OUT, Colors.Trim, Materials.Stone)
	cylinder(parent, 0.5, d, face * CFrame.new(x, y, 0.2) * AXIS_OUT, Colors.Glass, Materials.Glass).Reflectance = 0.15
	block(parent, Vector3.new(d, 0.18, 0.12), face * CFrame.new(x, y, 0.5), Colors.Trim)
	block(parent, Vector3.new(0.18, d, 0.12), face * CFrame.new(x, y, 0.5), Colors.Trim)
end

-- Holztür mit Steinrahmen; y = Unterkante, arched = Rundbogen oben
local function door(parent, face, x, y, w, h, arched)
	local t = 0.6
	local function at(px, py, pz)
		return face * CFrame.new(x + px, y + py, pz)
	end
	block(parent, Vector3.new(w, h, 0.35), at(0, h / 2, 0.175), Colors.Wood, Materials.Wood)
	block(parent, Vector3.new(t, h, 0.25), at(-(w + t) / 2, h / 2, 0.125), Colors.Stone, Materials.Stone)
	block(parent, Vector3.new(t, h, 0.25), at((w + t) / 2, h / 2, 0.125), Colors.Stone, Materials.Stone)
	if arched then
		cylinder(parent, 0.35, w, at(0, h, 0.175) * AXIS_OUT, Colors.Wood, Materials.Wood)
		cylinder(parent, 0.25, w + 2 * t, at(0, h, 0.125) * AXIS_OUT, Colors.Stone, Materials.Stone)
	else
		block(parent, Vector3.new(w + 2 * t, t, 0.25), at(0, h + t / 2, 0.125), Colors.Stone, Materials.Stone)
	end
	-- Füllungen, Klinke und Briefschlitz
	block(parent, Vector3.new(w * 0.3, h * 0.55, 0.1), at(-w * 0.22, h * 0.42, 0.4), Colors.WoodDark, Materials.Wood)
	block(parent, Vector3.new(w * 0.3, h * 0.55, 0.1), at(w * 0.22, h * 0.42, 0.4), Colors.WoodDark, Materials.Wood)
	ball(parent, 0.45, at(w / 2 - 0.55, h * 0.48, 0.45).Position, Colors.Gold, Materials.Metal)
	block(parent, Vector3.new(1, 0.25, 0.1), at(0, h * 0.8, 0.4), Colors.Gold, Materials.Metal)
end

-- Sektionaltor mit Fensterreihe; y = Unterkante
local function garageDoor(parent, face, x, y, w, h)
	local t = 0.6
	local function at(px, py, pz)
		return face * CFrame.new(x + px, y + py, pz)
	end
	block(parent, Vector3.new(w, h, 0.5), at(0, h / 2, 0.1), Colors.GarageDoor)
	block(parent, Vector3.new(t, h + t, 0.6), at(-(w + t) / 2, (h + t) / 2, 0.15), Colors.Stone, Materials.Stone)
	block(parent, Vector3.new(t, h + t, 0.6), at((w + t) / 2, (h + t) / 2, 0.15), Colors.Stone, Materials.Stone)
	block(parent, Vector3.new(w + 2 * t, t, 0.6), at(0, h + t / 2, 0.15), Colors.Stone, Materials.Stone)
	for i = 1, 3 do
		block(parent, Vector3.new(w - 0.2, 0.12, 0.1), at(0, h * i / 4, 0.38), Colors.GarageGroove)
	end
	local paneWidth = (w - 1) / 4
	for i = 0, 3 do
		local pane = block(parent, Vector3.new(paneWidth - 0.4, h / 4 - 0.8, 0.1), at(-w / 2 + 0.5 + paneWidth * (i + 0.5), h * 7 / 8, 0.38), Colors.Glass, Materials.Glass)
		pane.Reflectance = 0.15
	end
end

-- Wandlaterne mit Licht; y = Mitte des Glases
local function lantern(parent, face, x, y)
	local function at(py, pz)
		return face * CFrame.new(x, y + py, pz)
	end
	decor(block(parent, Vector3.new(0.3, 0.3, 0.7), at(0.6, 0.35), Colors.Metal, Materials.Metal))
	decor(block(parent, Vector3.new(1, 0.25, 1), at(0.75, 0.9), Colors.Metal, Materials.Metal))
	decor(block(parent, Vector3.new(0.9, 0.2, 0.9), at(-0.65, 0.9), Colors.Metal, Materials.Metal))
	local glow = decor(block(parent, Vector3.new(0.7, 1.1, 0.7), at(0, 0.9), Colors.LampGlow, Enum.Material.Neon))
	local light = Instance.new("PointLight")
	light.Color = Colors.LampGlow
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = glow
end

-- Blumenkasten vor der Fensterbank; y = Unterkante des Fensters
local function flowerBox(parent, face, x, y, w, rng)
	local function at(px, py, pz)
		return face * CFrame.new(x + px, y + py, pz)
	end
	block(parent, Vector3.new(w + 0.6, 0.8, 0.9), at(0, -0.6, 1.35), Colors.Wood, Materials.Wood)
	decor(block(parent, Vector3.new(w + 0.4, 0.3, 0.7), at(0, -0.1, 1.35), Colors.Leaves[1], Materials.Leaves))
	for px = -w / 2, w / 2, 0.55 do
		local flower = at(px, 0.25, 1.35 + rng:NextNumber(-0.2, 0.2)).Position
		decor(ball(parent, 0.5, flower, Colors.Flowers[rng:NextInteger(1, #Colors.Flowers)]))
	end
end

local function leafColor(rng)
	return Colors.Leaves[rng:NextInteger(1, #Colors.Leaves)]
end

local function bush(parent, position, size, rng)
	for _ = 1, 4 do
		local offset = Vector3.new(rng:NextNumber(-0.5, 0.5) * size, 0, rng:NextNumber(-0.4, 0.4) * size)
		local d = size * rng:NextNumber(0.6, 0.9)
		decor(ball(parent, d, position + offset + Vector3.new(0, d * 0.35, 0), leafColor(rng), Materials.Leaves))
	end
end

local function tree(parent, position, height, rng)
	cylinder(parent, height, 1.4, CFrame.new(position + Vector3.new(0, height / 2, 0)) * AXIS_UP, Colors.Trunk, Materials.Wood)
	local crown = position + Vector3.new(0, height + 1, 0)
	decor(ball(parent, 8, crown, leafColor(rng), Materials.Leaves))
	decor(ball(parent, 5.5, crown + Vector3.new(0, 3.2, 0), leafColor(rng), Materials.Leaves))
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 3.2, rng:NextNumber(-1.5, 1.5), math.sin(angle) * 3.2)
		decor(ball(parent, rng:NextNumber(4.5, 6), crown + offset, leafColor(rng), Materials.Leaves))
	end
end

local function pottedPlant(parent, position, rng)
	cylinder(parent, 1.4, 1.4, CFrame.new(position + Vector3.new(0, 0.7, 0)) * AXIS_UP, Colors.Pot, Enum.Material.Slate)
	decor(ball(parent, 1.8, position + Vector3.new(0, 2, 0), leafColor(rng), Materials.Leaves))
end

local function downpipe(parent, x, z, top)
	cylinder(parent, top, 0.45, CFrame.new(x, top / 2, z) * AXIS_UP, Colors.Pipe, Materials.Metal)
end

function HouseModel.new()
	local rng = Random.new(7)
	local house = Instance.new("Model")
	house.Name = "Haus"

	local building = group(house, "Gebaeude")
	local roofs = group(house, "Daecher")
	local details = group(house, "Details")
	local garden = group(house, "Garten")

	-- Rasenplatte unter dem ganzen Grundstück
	block(garden, Vector3.new(62, 0.4, 46), CFrame.new(7, -0.2, 3), Colors.Grass, Materials.Grass).Name = "Rasen"

	-- Baukörper: Haupthaus 30 x 22, Ziergiebel vorne links, Garage rechts
	block(building, Vector3.new(30, 13, 22), CFrame.new(0, 6.5, 0), Colors.Wall, Materials.Wall).Name = "Haupthaus"
	block(building, Vector3.new(12, 13, 2), CFrame.new(-7.5, 6.5, 12), Colors.Wall, Materials.Wall).Name = "Ziergiebel"
	block(building, Vector3.new(14, 10, 20), CFrame.new(22, 5, 1), Colors.Wall, Materials.Wall).Name = "Garage"
	-- Sockel
	block(building, Vector3.new(30.4, 1.2, 22.4), CFrame.new(0, 0.6, 0), Colors.Plinth, Enum.Material.Concrete)
	block(building, Vector3.new(12.4, 1.2, 2), CFrame.new(-7.5, 0.6, 12.2), Colors.Plinth, Enum.Material.Concrete)
	block(building, Vector3.new(14.2, 1.2, 20.4), CFrame.new(22.1, 0.6, 1), Colors.Plinth, Enum.Material.Concrete)

	-- Dächer
	gableRoof(roofs, CFrame.new(0, 13, 0), 30, 22, 8, { gutterBack = true })
	gableRoof(roofs, CFrame.new(-7.5, 13, 7.5) * CFrame.Angles(0, math.pi / 2, 0), 11, 12, 7)
	gableRoof(roofs, CFrame.new(22, 10, 1), 14, 20, 4.5, { gutterFront = true, gutterBack = true })

	-- Schornstein auf der vorderen Dachfläche
	block(roofs, Vector3.new(2.8, 8, 2.8), CFrame.new(5, 21, 2.5), Colors.Brick, Materials.Brick).Name = "Schornstein"
	block(roofs, Vector3.new(3.4, 0.6, 3.4), CFrame.new(5, 25.3, 2.5), Colors.Stone, Materials.Stone)
	block(roofs, Vector3.new(1.4, 0.4, 1.4), CFrame.new(5, 25.8, 2.5), Colors.Metal, Materials.Metal)

	-- Ecksteine und Pilaster zwischen Haupthaus und Garage
	quoins(details, -13.5, 13, -1, 1, 1.2, 13)
	quoins(details, -1.5, 13, 1, 1, 1.2, 13)
	quoins(details, -15, 11, -1, 1, 1.2, 13)
	quoins(details, -15, -11, -1, -1, 1.2, 13)
	quoins(details, 15, -11, 1, -1, 1.2, 13)
	quoins(details, 29, 11, 1, 1, 1.2, 10)
	quoins(details, 29, -9, 1, -1, 1.2, 10)
	block(details, Vector3.new(1.4, 11.8, 0.4), CFrame.new(15, 7.1, 11.1), Colors.Stone, Materials.Stone)

	-- Fallrohre
	downpipe(details, -15.4, 8.9, 12.8)
	downpipe(details, -12.9, -11.4, 12.8)
	downpipe(details, 29.4, 8.9, 9.8)
	downpipe(details, 27, -9.4, 9.8)

	local frontGable = wallFace(Vector3.new(-7.5, 0, 13), Vector3.zAxis)
	local frontMain = wallFace(Vector3.new(0, 0, 11), Vector3.zAxis)
	local frontGarage = wallFace(Vector3.new(22, 0, 11), Vector3.zAxis)
	local backMain = wallFace(Vector3.new(0, 0, -11), -Vector3.zAxis)
	local leftMain = wallFace(Vector3.new(-15, 0, 0), -Vector3.xAxis)
	local rightMain = wallFace(Vector3.new(15, 0, 0), Vector3.xAxis)
	local rightGarage = wallFace(Vector3.new(29, 0, 1), Vector3.xAxis)

	-- Vorderseite: Haustür mit Rundbogen, Treppe, Laterne, Rundfenster im Giebel
	door(details, frontGable, 0, 1.6, 4.2, 6.4, true)
	block(details, Vector3.new(6.4, 1.6, 1.4), frontGable * CFrame.new(0, 0.8, 0.7), Colors.Stone, Materials.Stone)
	block(details, Vector3.new(6.4, 0.8, 1.2), frontGable * CFrame.new(0, 0.4, 2), Colors.Stone, Materials.Stone)
	lantern(details, frontGable, -3.9, 6)
	roundWindow(details, frontGable, 0, 15.6, 3.2)

	-- Sprossenfenster mit Blumenkasten und Schlauchtrommel
	window(details, frontMain, 7.5, 4.5, 4.6, 5, true)
	flowerBox(details, frontMain, 7.5, 4.5, 4.6, rng)
	cylinder(details, 0.6, 1.6, frontMain * CFrame.new(1.2, 2.4, 0.3) * AXIS_OUT, Colors.Hose, Materials.Smooth)
	cylinder(details, 0.8, 0.7, frontMain * CFrame.new(1.2, 2.4, 0.4) * AXIS_OUT, Colors.Pipe, Materials.Metal)

	garageDoor(details, frontGarage, 0, 0.15, 10, 8)

	-- Rückseite und Seiten
	window(details, backMain, 0, 5, 5, 5)
	window(details, leftMain, 0, 5.5, 4.4, 4.6)
	roundWindow(details, rightMain, 0, 18, 2.4)
	door(details, rightGarage, 4.5, 1.2, 3.4, 6.8, false)
	block(details, Vector3.new(4.6, 1.2, 1.2), rightGarage * CFrame.new(4.5, 0.6, 0.6), Colors.Stone, Materials.Stone)
	lantern(details, rightGarage, 7.6, 5.5)
	window(details, rightGarage, -4.5, 4.5, 3.6, 3.6)

	-- Garten: Plattenweg, Einfahrt, Pflanzen, Mülltonne, Steine
	for z = 16.8, 24.5, 2.2 do
		block(garden, Vector3.new(3.8, 0.15, 1.8), CFrame.new(-7.5, 0.075, z), Colors.Path, Enum.Material.Slate)
	end
	block(garden, Vector3.new(11, 0.15, 14.6), CFrame.new(22, 0.075, 18.3), Colors.Path, Materials.Paving).Name = "Einfahrt"

	pottedPlant(garden, Vector3.new(-3.5, 0, 13.8), rng)
	for _, spot in
		{
			{ Vector3.new(-13.2, 0, 14.8), 2.6 },
			{ Vector3.new(-1.2, 0, 14.8), 2.2 },
			{ Vector3.new(3.6, 0, 12.6), 2.4 },
			{ Vector3.new(12.6, 0, 12.6), 2.6 },
			{ Vector3.new(-5, 0, -12.6), 2.6 },
			{ Vector3.new(7, 0, -12.6), 2.4 },
			{ Vector3.new(-16.6, 0, 6), 2.6 },
			{ Vector3.new(-16.6, 0, -6), 2.4 },
			{ Vector3.new(30.6, 0, 5.5), 2.4 },
			{ Vector3.new(30.6, 0, -7.4), 2.2 },
		}
	do
		bush(garden, spot[1], spot[2], rng)
	end
	tree(garden, Vector3.new(-20, 0, 9), 11, rng)
	tree(garden, Vector3.new(35, 0, -14), 10, rng)

	block(garden, Vector3.new(2, 3, 2), CFrame.new(25, 1.5, -10.6), Colors.Bin, Materials.Smooth).Name = "Muelltonne"
	block(garden, Vector3.new(2.3, 0.3, 2.3), CFrame.new(25, 3.15, -10.6), Colors.Bin, Materials.Smooth)
	for _, rock in { Vector3.new(-19, 0, 20), Vector3.new(14, 0, 22), Vector3.new(32, 0, 16), Vector3.new(-21, 0, -12), Vector3.new(31.5, 0, -1) } do
		decor(ball(garden, rng:NextNumber(0.8, 1.4), rock, Colors.Rock, Enum.Material.Slate))
	end

	-- Drehpunkt: Mitte der Rasenplatte, Unterseite
	house.WorldPivot = CFrame.new(7, -0.4, 3)
	return house
end

return HouseModel
