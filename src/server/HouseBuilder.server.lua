-- Stellt das Haus beim Spielstart in den Workspace, außer es wurde schon im Studio platziert.
local HouseModel = require(script.Parent.HouseModel)

-- Außerhalb des Zombie-Spawnkreises (Radius 60), die Vorderseite zeigt zur Spielfeldmitte.
local HOUSE_PIVOT = CFrame.new(0, 0, -90)

if not workspace:FindFirstChild("Haus") then
	local house = HouseModel.new()
	house:PivotTo(HOUSE_PIVOT)
	house.Parent = workspace
end
