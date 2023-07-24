----- Written by Hightail 2023 ---------

--[[

NOTE: This will output its data to a file called OutputMapData.lua (LOLEXT\Scripts\Common\OutputMapData.lua)
If you don't have this file, create one.

How to use:
Load into your map of choice and select your editing mode.
You can brush in new data points by holding the brush key (Z by default) and holding left click.
You can erase data points by holding the brush key (C by default) and holding left click.

Once you are finished, click "Save Data" in your menu. This will output your data to OutputMapData.lua
"Reset to Live Data" will reset your data to the CURRENT live data from MapPosition. When swapping maps, it's a good idea to press this first.
"Load Output Data" will load the current data from OutputMapData.lua

For best and most accurate results, make sure you are on the same Y-axis as where you are painting!

Enjoy!

]]

DrawRect = Draw.Rect
DrawLine = Draw.Line
DrawCircle = Draw.Circle
DrawColor = Draw.Color
DrawText = Draw.Text
modf = math.modf

local function GetDistanceSqr(pos1, pos2)
	local pos2 = pos2 or myHero.pos
	local dx = pos1.x - pos2.x
	local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
	return dx * dx + dz * dz
end

local function GetDistance(pos1, pos2)
	local a = pos1.pos or pos1
	local b = pos2.pos or pos2
	return math. sqrt(GetDistanceSqr(a, b))
end

local function FileExists(path)
	local file = io.open(path, "r")
	if file ~= nil then 
		io.close(file) 
		return true 
	else 
		return false 
	end
end

--[[ DELAY ACTION ]]--

if not unpack then unpack = table.unpack end
local delayedActions, delayedActionsExecuter = {}, nil
local function DelayEvent(func, delay, args) --delay in seconds
	if not delayedActionsExecuter then
		function delayedActionsExecuter()
			for t, funcs in pairs(delayedActions) do
				if t <= os.clock() then
					for _, f in ipairs(funcs) do f.func(unpack(f.args or {})) end
					delayedActions[t] = nil
				end
			end
		end
		Callback.Add("Tick", delayedActionsExecuter)
	end
	local t = os.clock() + (delay or 0)
	if delayedActions[t] then table.insert(delayedActions[t], { func = func, args = args })
	else delayedActions[t] = { { func = func, args = args } }
	end
end

local function tableCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[tableCopy(orig_key)] = tableCopy(orig_value)
        end
        setmetatable(copy, tableCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


--Ordering Tables from Lua Wiki
function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end

function orderedNext(t, state)
    local key = nil
    if state == nil then
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        for i = 1, getTableSize(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    t.__orderedIndex = nil
    return
end

function orderedPairs(t)
    return orderedNext, t, nil
end

function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end


----------------------------------------

local mapID = Game.mapID
local reverse
local walls, bushes, water
local bWalls, bBushes, bWater

local mapData2

if mapID == HOWLING_ABYSS then
	local mapData = require 'MapPositionData_HA'
	walls, bushes, water = mapData[1], mapData[2], {}
	reverse = true
elseif mapID == SUMMONERS_RIFT then
	local mapData = require 'MapPositionData_SR'
	walls, bushes, water = mapData[1], mapData[2], mapData[3]
else
	walls, bushes, water = {}, {}, {}
	print("No Map Data")
end

local mapDevTool
mapDevTool = {

	AllowDraw = nil,
	CachedNodeData = nil,
	ForceReload = false,
	GoSMenuToggle = true,
	yOffset = 0,

	BackupData = function (self)
		bWalls = tableCopy(walls)
		bBushes = tableCopy(bushes)
		bWater = tableCopy(water)
	end,

	ResetData = function (self)
		print("Reset to Default Map Data")
		walls = tableCopy(bWalls)
		bushes = tableCopy(bBushes)
		water = tableCopy(bWater)
		self.CachedNodeData = self:FetchActiveDataType()
	end,

	SaveData = function (self)
		print("Saved Map Data")

		local path = COMMON_PATH .. "OutputMapData.lua"
		local f = io.open(path, "w")
		if f then
			local dataString = self:GenerateDataString()
			f:write(dataString)
			f:close()
			self:ForceUserReload()
		end

		print("Saved to Common/OutputMapData.lua")
	end,

	LoadOuputData = function (self)
		print("Loaded Output Data")
		mapData2 = require 'OutputMapData'
		if(mapData2[1]) then
			walls = mapData2[1]
		end
		if(mapData2[2]) then
			bushes = mapData2[2]
		end
		if(mapData2[3]) then
			water = mapData2[3]
		end
		self.CachedNodeData = self:FetchActiveDataType()
	end,

	GenerateDataString = function (self)

		local wallRes = self:StringBuilder(walls, "walls")
		local bushRes = self:StringBuilder(bushes, "bushes")
		local waterRes = self:StringBuilder(water, "water")

		local finalOut = wallRes .. bushRes .. waterRes .. "\nreturn{walls, bushes, water}"
		return finalOut
	end,

	StringBuilder = function (self, tbl, name)
		local c1 = 0
		local indexData = {}
		for i, dat in orderedPairs(tbl) do

			indexData[c1] = "["..i.."]={"
			local subData = {}
			local c2 = 1
			for k, _ in orderedPairs(dat) do
				subData[c2]="["..k.."]=1,"
				c2 = c2 + 1
			end
			local subRes = table.concat(subData)
			indexData[c1] = indexData[c1] .. subRes .. "},"
			c1 = c1 + 1
		end

		local res = table.concat(indexData)
		res = "local " .. name .. " = {" .. res .. "}\n"

		return res
	end,

	ForceUserReload = function (self)
		self.ForceReload = true
	end,

	Init = function (self)
		self.Menu = MenuElement({ id = "MDev", name = "Map Dev Tool", type = MENU })
		self:BackupData()
		self:LoadMenus()
		self:LoadOuputData()
		self.CachedNodeData = self:FetchActiveDataType()

		Callback.Add("Tick", function() self:Tick() end)
		Callback.Add("Draw", function() self:Draw() end)
	end,

	LoadMenus = function (self)
		self.Menu:MenuElement({ id = "DrawNodes", name = "Draw Data Nodes", value = true});
		self.Menu:MenuElement({ id = "DataType", name = "Data Type", value = 1, drop = {"Wall Data", "Bush Data"}, callback = 
		function ()
			DelayEvent(function()
				if(self.Menu.DataType:Value() == 1) then
					self.CachedNodeData = walls
				else
					self.CachedNodeData = bushes
				end
			end, 0.05)
		end})

		self.Menu:MenuElement({ id = "BrushSize", name = "Brush Size", value = 35, min = 5, max = 100, step = 5 })
		self.Menu:MenuElement({ id = "DrawKey", name = "Draw Key", key = string.byte("Z")})
		self.Menu:MenuElement({ id = "ClearKey", name = "Clear Key", key = string.byte("C")})
		self.Menu:MenuElement({ id = "ResetData", name = "Reset to Live Data", type = MENU, onclick  =
		function()
			self:ResetData()
		end})
		self.Menu:MenuElement({ id = "SaveData", name = "Save Data", type = MENU, onclick  =
		function()
			self:SaveData()
		end})
		self.Menu:MenuElement({ id = "LoadData", name = "Load Output Data", type = MENU, onclick  =
		function()
			self:LoadOuputData()
		end})
	end,

	FetchActiveDataType = function (self)
		if(self.Menu.DataType:Value() == 1) then
			return walls
		end

		if(self.Menu.DataType:Value() == 2) then
			return bushes
		end

		return nil
	end,

	Tick = function (self)
		if mapID == HOWLING_ABYSS then
			self.yOffset = -178
		elseif mapID == SUMMONERS_RIFT then
			self.yOffset = myHero.pos.y
		else
			self.yOffset = 0
		end
	end,

	OnWndMsg = function(self, msg, wParam)
		self.AllowDraw = msg == 513
			and wParam == 0
			and self.Menu.DrawNodes:Value()
		or nil

		if(Control.IsKeyDown(HK_MENU)) then
			self.GoSMenuToggle = not self.GoSMenuToggle
		end
	end,

	Draw = function (self)
		if(self.ForceReload) then
			local textVecPos = myHero.pos:To2D() + {x=-100, y=50}
			local textVecPos2 = myHero.pos:To2D() + {x=-100, y=75}
			DrawText("SAVE COMPLETE!", 28, textVecPos, DrawColor(255, 100, 255, 100))
			DrawText("Please Reload with F6", 22, textVecPos2, DrawColor(255, 235, 235, 235))
			return
		end
		local brushSize = self.Menu.BrushSize:Value()
		DrawCircle(Game.mousePos(), brushSize, 1, DrawColor(125, 255, 255, 255))

		local col = DrawColor(255, 255, 255, 255)
		if(self.Menu.DrawKey:Value()) then
			col = DrawColor(255, 0, 255, 0)
		end

		if(self.Menu.ClearKey:Value()) then
			col = DrawColor(255, 255, 0, 0)
		end

		if(self.Menu.DrawNodes:Value()) then
			self:DrawMapNodes()

			local textVecPos = myHero.pos:To2D() + {x=-75, y=50}
			if(self.Menu.DataType:Value() == 1) then
				DrawText("Editing Wall Data", 22, textVecPos, col)

				if(mapID == HOWLING_ABYSS) then
					local textVecPos2 = myHero.pos:To2D() + {x=-115, y=75}
					DrawText("Note: Howling Abyss Wall Data is Inverted", 16, textVecPos2, col)
				end
			else
				DrawText("Editing Bush Data", 22, textVecPos, col)
			end
		end
	end,

	DrawMapNodes = function (self)
		local pos = Game.mousePos()
		local cPos = Game.cursorPos()	
		local brushRange = self.Menu.BrushSize:Value()
	
		local nodeX = modf((pos.x or pos.pos.x) * .03030303) 
		local nodeY = modf((pos.z or pos.pos.z or pos.y or pos.pos.y) * .03030303)
	
		local dataType = self:FetchActiveDataType()

		if(dataType) then
			for i = nodeX-25, nodeX+25 do
				for j = nodeY-25, nodeY+25 do
					local b = self.CachedNodeData[i]
		
					local convertVec = Vector({x = i * 33, y = self.yOffset, z = j *33})
					convertVec = convertVec:To2D()
		
					local vec2 = Vector({x = i*33,y = self.yOffset, z = j *33})			
					local alphaFalloff = math.max(1 - (GetDistance(pos, vec2)/1000), 0)
					if(self.GoSMenuToggle) then
						alphaFalloff = math.max(alphaFalloff - 0.5, 0)
					end
		
					if(b and b[j]) then
						DrawRect(convertVec.x, convertVec.y, 5, 5, DrawColor(255 * (math.min(alphaFalloff * 1.2, 1)), 0, 255, 0))
					else
						DrawRect(convertVec.x, convertVec.y, 5, 5, DrawColor(45 * alphaFalloff, 255, 255, 255))
					end
		
					if(math.abs(cPos.x - convertVec.x) < brushRange and math.abs(cPos.y - convertVec.y) < brushRange) then
						if(GetDistance(convertVec, cPos) < brushRange) then
							if(b and b[j]) then
								DrawRect(convertVec.x, convertVec.y, 5, 5, DrawColor(255, 255, 0, 255))
							else
								DrawRect(convertVec.x, convertVec.y, 5, 5, DrawColor(255, 255, 255, 255))
							end

							if(self.AllowDraw) and self.Menu.DrawKey:Value() then
								self:EnableDataNode(i, j)
							end

							if(self.AllowDraw) and self.Menu.ClearKey:Value() then
								self:ClearDataNode(i, j)
							end
						end
					end
		
				end
			end
		end
	end,

	EnableDataNode = function (self, x, y)
		if(self.CachedNodeData) then
			if(self.CachedNodeData[x]) then
				if not self.CachedNodeData[x][y] then
					self.CachedNodeData[x][y] = 1
				end
			else
				self.CachedNodeData[x] = {}
			end
		end
	end,

	ClearDataNode = function (self, x, y)
		if(self.CachedNodeData) then
			if(self.CachedNodeData[x]) then
				if self.CachedNodeData[x][y] then
					self.CachedNodeData[x][y] = nil
				end
			else
				self.CachedNodeData[x] = {}
			end
		end
	end,	
}


Callback.Add("Load", function()
	if(FileExists(COMMON_PATH .. "OutputMapData.lua")) then
		mapData2 = require 'OutputMapData'
		mapDevTool:Init()
	else
		local File = io.open(COMMON_PATH.. "OutputMapData.lua", "w")
		if not File then 
			print("Can't create OutputMapData file. Path not valid.")
			return
		end
		File:write("return {}")
		File:close()

		print("OutputMapData.lua was missing. Created the file! Please reload with F6")
	end
end)


table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
	mapDevTool:OnWndMsg(msg, wParam)
end)
