require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"

local kLibVersion = 2.40

-- [ AutoUpdate ]
do

	local KILLER_PATH = COMMON_PATH.."KillerAIO/"
	local KILLER_LIB = "KillerLib.lua"
	local KILLER_VERSION = "KillerLib.version"
	local gitHub = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/KillerAIO/"
    
    local function AutoUpdate()
	
		local function FileExists(path)
			local file = io.open(path, "r")
			if file ~= nil then 
				io.close(file) 
				return true 
			else 
				return false 
			end
		end
		
		local function DownloadFile(path, fileName)
			local startTime = os.clock()
			DownloadFileAsync(gitHub .. fileName, path .. fileName, function() end)
			repeat until os.clock() - startTime > 3 or FileExists(path .. fileName)
		end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(KILLER_PATH, KILLER_VERSION)
        local NewVersion = tonumber(ReadFile(KILLER_PATH, KILLER_VERSION))
        if NewVersion > kLibVersion then
            DownloadFile(KILLER_PATH, KILLER_LIB)
            print("New Killer Library Update - Please reload with F6")
        end
    end
	
   AutoUpdate()
end
----------------------------------------------------
--|                   		UTILITY					             |--
----------------------------------------------------
-- VARS --
print("Killer Libs Loaded [ver. "..kLibVersion.."]")
heroes = false
wClock = 0
clock = os.clock
Latency = Game.Latency
ping = Latency() * 0.001
foundAUnit = false
_movementHistory = {}
TEAM_ALLY = myHero.team
TEAM_ENEMY = 300 - myHero.team
TEAM_JUNGLE = 300
wClock = 0
_OnVision = {}
sqrt = math.sqrt
MathHuge = math.huge
TableInsert = table.insert
TableRemove = table.remove
GameTimer = Game.Timer
Allies, Enemies, Turrets, FriendlyTurrets, Units = {}, {}, {}, {}, {}
DrawRect = Draw.Rect
DrawLine = Draw.Line
DrawCircle = Draw.Circle
DrawColor = Draw.Color
DrawText = Draw.Text
ControlSetCursorPos = Control.SetCursorPos
ControlKeyUp = Control.KeyUp
ControlKeyDown = Control.KeyDown
GameCanUseSpell = Game.CanUseSpell
GameHeroCount = Game.HeroCount
GameHero = Game.Hero
GameMinionCount = Game.MinionCount
GameMinion = Game.Minion
GameTurretCount = Game.TurretCount
GameTurret = Game.Turret
GameIsChatOpen = Game.IsChatOpen
castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}

HITCHANCE_IMPOSSIBLE = 0
HITCHANCE_COLLISION = 1
HITCHANCE_NORMAL = 2
HITCHANCE_HIGH = 3
HITCHANCE_IMMOBILE = 4

MINION_CANON = 0
MINION_MELEE = 1
MINION_CASTER = 2

RUNNING_AWAY = -1
RUNNING_TOWARDS = 1

LEAGUE_ARENA = 30 --map ID

_G.LATENCY = 0.05

--== Strafe Prediction==--

class("StrafePred")

StrafePred.WaypointData = {}
StrafePred.NewPosData = {}
StrafePred.StandingData = {}

function StrafePred:__init()
    _G._STRAFEPRED_START = true
    self.OnStrafePredCallback = {}
    Callback.Add("Tick", function() self:OnTick() end)
	
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local enemyUnit = args.unit
		self.WaypointData[enemyUnit.handle] = {}
		self.NewPosData[enemyUnit.handle] = {x = 0, z = 0}
		self.StandingData[enemyUnit.handle] = GameTimer()
		
	end)
	
end
 
local waypointLimit = 4
local strafeMargin = 0.5 --The closer this value is to 1, the more strict the strafe check will be
local stutterDistMargin = 125

function StrafePred:OnTick()	
	for _, unit in pairs(Enemies) do
		if(unit.valid and IsValid(unit)) then
			if(unit.pathing.hasMovePath) and (self.NewPosData[unit.handle])  then
				local newPos = self.NewPosData[unit.handle]
				self.StandingData[unit.handle] = GameTimer()
				if(unit.pathing.endPos.x ~= newPos.x and unit.pathing.endPos.z ~= newPos.z ) then
					self.NewPosData[unit.handle] = unit.pathing.endPos
					local endPosVec = Vector(unit.pathing.endPos.x, unit.pos.y, unit.pathing.endPos.z)
					local startPosVec = Vector(unit.pathing.startPos.x, unit.pos.y, unit.pathing.startPos.z)
					local nVec = Vector(endPosVec - startPosVec):Normalized()

					if(self.WaypointData[unit.handle] ~= nil or self.WaypointData[unit.handle]) then
						self:AddWaypointData(unit, {nVec, GameTimer(), unit.pos})
					end
					
				end
			end
		end
	end

	for _, unit in pairs(Allies) do
		if(unit.valid and IsValid(unit)) then
			if(unit.pathing.hasMovePath)  then
				self.StandingData[unit.handle] = GameTimer()
			end
		end
	end

	if(myHero.valid and IsValid(myHero)) then
		if(myHero.pathing.hasMovePath)  then
			self.StandingData[myHero.handle] = GameTimer()
		end
	end
	
end

function StrafePred:AddWaypointData(unit, tbl)
	local uName = unit.handle
	for i = #self.WaypointData[uName], 1, -1 do
		self.WaypointData[uName][i + 1] = self.WaypointData[uName][i]
	end
	if(#self.WaypointData[uName] > waypointLimit) then
		table.remove(self.WaypointData[uName], waypointLimit + 1)
	end
	self.WaypointData[uName][1] = tbl
end

function StrafePred:IsStrafing(tar)
	local tName = tar.handle
	if(tar.pathing.hasMovePath == false) then return false end
	if(self.WaypointData[tName] ~= nil or self.WaypointData[tName]) then
		if(#self.WaypointData[tName] == waypointLimit) then
			--Dot product check
			local res1 = dotProduct(self.WaypointData[tName][1][1], self.WaypointData[tName][2][1])
			local res2 = dotProduct(self.WaypointData[tName][1][1], self.WaypointData[tName][3][1])
			local res3 = dotProduct(self.WaypointData[tName][1][1], self.WaypointData[tName][4][1])
			local timebetweenWaypoints = self.WaypointData[tName][1][2] - self.WaypointData[tName][2][2] -- Time between waypoint update
			local lastWaypointTime = GameTimer() - self.WaypointData[tName][1][2] --Time between last waypoint and game time
			
			local pos1 = self.WaypointData[tName][1][3]
			local pos2 = self.WaypointData[tName][2][3]
			local pos3 = self.WaypointData[tName][3][3]
			local pos4 = self.WaypointData[tName][4][3]
			local avgPos = (pos1+pos2+pos3+pos4)/4

			if(res1 <= -strafeMargin and res2 >= strafeMargin and res3 <= -strafeMargin and timebetweenWaypoints <= 0.70 and lastWaypointTime <= 0.7) then
				return true, avgPos
			else
				return false
			end
		end
	else
		return false
	end
	
	return false
end

function StrafePred:IsStutterDancing(tar)
	local tName = tar.handle
	if(tar.pathing.hasMovePath == false) then return false end
	if(self.WaypointData[tName] ~= nil or self.WaypointData[tName]) then
		if(#self.WaypointData[tName] == waypointLimit) then

			local pos1 = self.WaypointData[tName][1][3]
			local pos2 = self.WaypointData[tName][2][3]
			local pos3 = self.WaypointData[tName][3][3]
			local pos4 = self.WaypointData[tName][4][3]
			local avgPos = (pos1+pos2+pos3+pos4)/4
			

			local timebetweenWaypoints = self.WaypointData[tName][1][2] - self.WaypointData[tName][2][2] -- Time between waypoint update
			local lastWaypointTime = GameTimer() - self.WaypointData[tName][1][2] --Time between last waypoint and game time
			
			if(tar.pos:DistanceTo(avgPos) <= stutterDistMargin and tar.pos:DistanceTo(pos4) <= stutterDistMargin and timebetweenWaypoints <= 0.90 and lastWaypointTime <= 1 ) then
				return true, avgPos
			end
		end
	else
		return false
	end
	
	return false
end

function StrafePred:GetIdleStandingTime(tar)
	if(self.StandingData[tar.handle] == nil or self.StandingData[tar.handle] == {}) then
		self.StandingData[tar.handle] = GameTimer()
	end

	if(IsValid(tar)) then
		if(self.StandingData[tar.handle] ~= nil) then
			local result = GameTimer() - self.StandingData[tar.handle]
			if(result <= 0.1) then result = 0 end
			return result
		end
	end
	return 0
end

local function OnChampStrafe(fn)
    if not _STRAFEPRED_START then
        _G.StrafePred = StrafePred()
    end
    table.insert(StrafePred.OnStrafePredCallback, fn)
end

StrafePred()

--[[ DELAY ACTION ]]--

if not unpack then unpack = table.unpack end
local delayedActions, delayedActionsExecuter = {}, nil
function DelayEvent(func, delay, args) --delay in seconds
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


-- [[AUTO LEVELER]] --

function GenerateSkillPriority(input1, input2)

	local input3 = 0
	local enumTable = {1, 2, 3}
	enumTable[input1] = nil
	enumTable[input2] = nil
	for k, v in pairs(enumTable) do
		input3 = v
	end

	local skillPriority = {
		["firstSkill"] = FetchQWESkillOrder(input1),
		["secondSkill"] = FetchQWESkillOrder(input2),
		["thirdSkill"] = FetchQWESkillOrder(input3)
	}

	return skillPriority
end

function FetchQWEByValue(input)
	if(input == 1) then
		return "Q"
	end
	if(input == 2) then
		return "W"
	end
	return "E"
end

function FetchQWESkillOrder(input)
	if(input == 1) then
		return {_Q, HK_Q}
	end
	if(input == 2) then
		return {_W, HK_W}
	end
	return {_E, HK_E}
end

local AutoLevelCheck = false
function AutoLeveler(skillPriority)
	if AutoLevelCheck then return end
	
	local level = myHero.levelData.lvl
	local levelPoints = myHero.levelData.lvlPts

	if (levelPoints == 0) or (level == 1) then return end
	if (Game.mapID == HOWLING_ABYSS and level <= 3) then return end
	if (Game.mapID == LEAGUE_ARENA) then return end
	--[[
	Rules:
	- Prioritize Ult when it's attainable [6, 11, 16]
	- Make sure we have at least one rank of every ability by level 3
	- Funnel skill points into the primary skill, and if we cannot, overflow to the secondary
	- A skill cannot be leveled up if it's level will be greater than HALF of our champion level ROUNDED UP
	--]]
	if(levelPoints > 0) then
		local rLevel = myHero:GetSpellData(_R).level

		if (rLevel == 0 and level >= 6) or (rLevel == 1 and level >= 11) or (rLevel == 2 and level >= 16) then
			AutoLevelCheck = true
			DelayEvent(function()		
				Control.KeyDown(HK_LUS)
				Control.KeyDown(HK_R)
				Control.KeyUp(HK_R)
				Control.KeyUp(HK_LUS)
				AutoLevelCheck = false
			end, math.random(0.1, 0.15))
			return
		end

		local firstSkill = myHero:GetSpellData(skillPriority["firstSkill"][1])
		local secondSkill = myHero:GetSpellData(skillPriority["secondSkill"][1])
		local thirdSkill = myHero:GetSpellData(skillPriority["thirdSkill"][1])

		--First 3 skill levels
		if(firstSkill.level == 0) then
			AutoLevelCheck = true
			local cachedLevel = firstSkill.level
			DelayEvent(function()
				if(cachedLevel == firstSkill.level) then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(skillPriority["firstSkill"][2])
					Control.KeyUp(skillPriority["firstSkill"][2])
					Control.KeyUp(HK_LUS)
				end
				DelayEvent(function()
					AutoLevelCheck = false
				end, 0.05)
			end, math.random(0.1, 0.15))
			return
		end
		if(secondSkill.level == 0) then
			AutoLevelCheck = true
			local cachedLevel = secondSkill.level
			DelayEvent(function()
				if(cachedLevel == secondSkill.level) then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(skillPriority["secondSkill"][2])
					Control.KeyUp(skillPriority["secondSkill"][2])
					Control.KeyUp(HK_LUS)
				end
				DelayEvent(function()
					AutoLevelCheck = false
				end, 0.05)
			end, math.random(0.1, 0.15))
			return
		end
		if(thirdSkill.level == 0) then
			AutoLevelCheck = true
			local cachedLevel = thirdSkill.level
			DelayEvent(function()
				if(cachedLevel == thirdSkill.level) then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(skillPriority["thirdSkill"][2])
					Control.KeyUp(skillPriority["thirdSkill"][2])
					Control.KeyUp(HK_LUS)
				end
				DelayEvent(function()
					AutoLevelCheck = false
				end, 0.05)
			end, math.random(0.1, 0.15))
			return
		end


		-- Standard leveling
		if(firstSkill.level ~= 5) then
			if(firstSkill.level + 1 <= math.ceil(level/2)) then
				AutoLevelCheck = true
				local cachedLevel = firstSkill.level
				DelayEvent(function()
					if(cachedLevel == firstSkill.level) then
						Control.KeyDown(HK_LUS)
						Control.KeyDown(skillPriority["firstSkill"][2])
						Control.KeyUp(skillPriority["firstSkill"][2])
						Control.KeyUp(HK_LUS)
					end
					AutoLevelCheck = false
				end, math.random(0.1, 0.15))
				return
			end
		end

		if(secondSkill.level ~= 5) then
			if(secondSkill.level + 1 <= math.ceil(level/2)) then
				AutoLevelCheck = true
				local cachedLevel = secondSkill.level
				DelayEvent(function()
					if(cachedLevel == secondSkill.level) then
						Control.KeyDown(HK_LUS)
						Control.KeyDown(skillPriority["secondSkill"][2])
						Control.KeyUp(skillPriority["secondSkill"][2])
						Control.KeyUp(HK_LUS)
					end
					AutoLevelCheck = false
				end, math.random(0.1, 0.15))
				return
			end
		end

		if(thirdSkill.level ~= 5) then
			if(thirdSkill.level + 1 <= math.ceil(level/2)) then
				AutoLevelCheck = true
				local cachedLevel = thirdSkill.level
				DelayEvent(function()	
					if(cachedLevel == thirdSkill.level) then
						Control.KeyDown(HK_LUS)
						Control.KeyDown(skillPriority["thirdSkill"][2])
						Control.KeyUp(skillPriority["thirdSkill"][2])
						Control.KeyUp(HK_LUS)
					end
					AutoLevelCheck = false
				end, math.random(0.1, 0.15))
				return
			end
		end
	else
		AutoLevelCheck = false
	end
end


-- UTILITY FUNCTIONS --

function LoadUnits()
	for i = 1, GameHeroCount() do
		local unit = GameHero(i); Units[i] = {unit = unit, spell = nil}
		if unit.team ~= myHero.team then TableInsert(Enemies, unit)
		elseif unit.team == myHero.team and unit ~= myHero then TableInsert(Allies, unit) end
	end
	for i = 1, Game.TurretCount() do
		local turret = Game.Turret(i)
		if turret and turret.isEnemy then TableInsert(Turrets, turret) end
		if turret and not turret.isEnemy then TableInsert(FriendlyTurrets, turret) end
	end

end


local TargetSelector
function GetTarget(unit)
	return TargetSelector:GetTarget(unit, 1)

end

TargetSelector = _G.SDK.TargetSelector


function CheckWall(from, to, distance)
    local pos1 = to + (to - from):Normalized() * 50
    local pos2 = pos1 + (to - from):Normalized() * (distance - 50)
    local point1 = Point(pos1.x, pos1.z)
    local point2 = Point(pos2.x, pos2.z)
    if MapPosition:intersectsWall(LineSegment(point1, point2)) then
        return true
    end
    return false
end


function EnemyHeroes()
    local _EnemyHeroes = {}
    for i = 1, GameHeroCount() do
        local unit = GameHero(i)
        if unit.isEnemy then
            TableInsert(_EnemyHeroes, unit)
        end
    end
    return _EnemyHeroes
end


function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and GameCanUseSpell(spell) == 0
end

function GetDistanceSqr(pos1, pos2)
	local pos2 = pos2 or myHero.pos
	local dx = pos1.x - pos2.x
	local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
	return dx * dx + dz * dz
end

function GetDistance(pos1, pos2)
	local a = pos1.pos or pos1
	local b = pos2.pos or pos2
	return sqrt(GetDistanceSqr(a, b))
end

function GetDistance2D(pos1, pos2)
	local pos2 = pos2 or myHero.pos
	local dx = pos1.x - pos2.x
	local dy = pos1.y - pos2.y
	return sqrt(dx * dx + dy * dy)
end

function Lerp(a, b, t)
	return (a + ((b - a)*t))
end

function GetClosestPointToCursor(tbl)
	local closestPoint = nil
	local closestDist = math.huge
	for i = 1, #tbl do
		point = tbl[i]
		local dist = GetDistance2D(point:To2D(), cursorPos)
		if(dist <= closestDist) then	
			closestPoint = point
			closestDist = dist
		end
	end
	return closestPoint
end

function GetTarget(range) 
	if _G.SDK then
		if myHero.ap > myHero.totalDamage then
			return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
		else
			return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
		end
	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetTarget(range)
	end
end

function GetMode()   
    if _G.SDK then
        return 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "LaneClear"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] and "LaneClear"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and "LastHit"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and "Flee"
		or nil
    
	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetMode()
	end
	return nil
end

function SetAttack(bool)
	if _G.EOWLoaded then
		EOW:SetAttacks(bool)
	elseif _G.SDK then                                                        
		_G.SDK.Orbwalker:SetAttack(bool)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetAttack(bool)	
	else
		GOS.BlockAttack = not bool
	end

end

function SetMovement(bool)
	if _G.EOWLoaded then
		EOW:SetMovements(bool)
	elseif _G.SDK then
		_G.SDK.Orbwalker:SetMovement(bool)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetMovement(bool)	
	else
		GOS.BlockMovement = not bool
	end
end

function CheckLoadedEnemies()
	local count = 0
	for i, unit in ipairs(Enemies) do
        if unit and unit.isEnemy then
		count = count + 1
		end
	end
	return count
end

function GetEnemyHeroes()
	return Enemies
end

function GetEnemyTurrets()
	return Turrets
end

function GetFriendlyTurrets()
	return FriendlyTurrets
end

function GetClosestFriendlyTurret()
	local closestTurret = nil
	local closestDist = math.huge
	for _, turret in pairs(FriendlyTurrets) do
		if(turret and IsValid(turret) and not turret.dead) then
			local checkDist = myHero.pos:DistanceTo(turret.pos)
			if(checkDist <= closestDist) then
				closestDist = checkDist
				closestTurret = turret
			end
		end
	end
	return closestTurret
end

function GetEnemyMinionsUnderTurret(turret)
	local turretMinions = {}
	if(turret and IsValid(turret) and not turret.dead) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(750 + myHero.range)
		for _, minion in pairs(minions) do
			if(minion and IsValid(minion)) then
				if(minion.pos:DistanceTo(turret.pos) < (turret.boundingRadius + 750 + minion.boundingRadius / 2 + 100)) then
					table.insert(turretMinions, minion)
				end
			end
		end
	end
	return turretMinions
end

local targetCachedNetID = 0
local cachedTarget = nil

function GetTurretMinionTarget(turret, minions)
	if(turret.targetID == targetCachedNetID) then
		return cachedTarget
	end
	for _, minion in pairs(minions) do
		if(turret.targetID == minion.networkID) then
			targetCachedNetID = minion.networkID
			cachedTarget = minion
			return cachedTarget
		end
	end
	return nil
end

function GetEnemyHeroes(range, bbox)
	local result = {}
	for _, unit in ipairs(Enemies) do
		if(IsValid(unit)) then
			local extrarange = bbox and unit.boundingRadius or 0
			if unit.distance < range + extrarange then
				table.insert(result, unit)
			end
		end
	end
	return result
end

function GetAllyHeroes(range, bbox)
	local result = {}
	for _, unit in ipairs(Allies) do
		if(IsValid(unit)) then
			local extrarange = bbox and unit.boundingRadius or 0
			if unit.distance < range + extrarange then
				table.insert(result, unit)
			end
		end
	end
	return result
end

function IsUnderTurret(unit)
	for i, turret in ipairs(GetEnemyTurrets()) do
        local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
        if not turret.dead then 
            if turret.pos:DistanceTo(unit.pos) < range then
                return true
            end
        end
    end
    return false
end

function IsPositionUnderTurret(pos)
	for i, turret in ipairs(GetEnemyTurrets()) do
        local range = (turret.boundingRadius + 750)
        if not turret.dead then 
            if turret.pos:DistanceTo(pos) < range then
                return true
            end
        end
    end
    return false
end

function IsUnderFriendlyTurret(unit)
	for i, turret in ipairs(GetFriendlyTurrets()) do
        local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
        if not turret.dead then 
            if turret.pos:DistanceTo(unit.pos) < range then
                return true, turret
            end
        end
    end
    return false
end

function GetTurretDamage()
	local minutes = math.min(Game.Timer()/60, 14)
	return 162 + (13 * math.floor(minutes))
end

function IsInFountain()
	local map = Game.mapID
	local posSR_Blue, posSR_Red, posHA_Blue, posHA_Red = {x = 410, y = 180, z = 416}, {x = 14296, y = 171, z = 14386}, {x = 1081, y = -130, z = 1195}, {x = 11721, y = -130, z = 11515}
	local team = myHero.team
	-- 100 = BLUE || 200 = RED
	if(map == HOWLING_ABYSS) then
		if(team == 100) then 	-- Blue
			return (myHero.pos:DistanceTo(Vector(posHA_Blue)) <= 575)
		elseif(team == 200) then								-- Red
			return (myHero.pos:DistanceTo(Vector(posHA_Red)) <= 575)
		end
	end
	
	if(map == SUMMONERS_RIFT) then
		if(team == 100) then 	-- Blue
			return (myHero.pos:DistanceTo(Vector(posSR_Blue)) <= 800)
		elseif(team == 200) then								-- Red
			return (myHero.pos:DistanceTo(Vector(posSR_Red)) <= 800)
		end
	end
	
	return false
end

function HasBuff(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)	

		if buff.name == buffname and buff.count > 0 then 
			return true
		end
	end
	return false
end

function HasBuffType(unit, type)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.type == type then
            return true
        end
    end
    return false
end

function GetBuffData(unit, buffname)
	for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return buff
		end
	end
	return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

function IsRecalling(unit)
	if(unit.activeSpell.valid) then
		if(unit.activeSpell.name == "recall") then
			return true 
		end
	end

	local buff = GetBuffData(unit, "recall")
	if buff and buff.duration > 0 then
		return true, GameTimer() - buff.startTime
	end
    return false
end

function IsImmobile(unit, recallOption)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 12 or BuffType == 11 or BuffType == 22 or BuffType == 35 or BuffType == 25 or BuffType == 29 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
			
			if(recallOption) then
				if(buff.name == "recall") then
					local BuffDuration = buff.duration
					if BuffDuration > MaxDuration then
						MaxDuration = BuffDuration
					end
				end
			end
        end
    end
    return MaxDuration
end

function IsHardCCd(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 10 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 35 or BuffType == 34 or BuffType == 25 or BuffType == 29 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsCleanse(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 31 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsChainable(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 31 or BuffType == 10 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function ClosestPointOnLineSegment(p, p1, p2)
    local px = p.x
    local pz = p.z
    local ax = p1.x
    local az = p1.z
    local bx = p2.x
    local bz = p2.z
    local bxax = bx - ax
    local bzaz = bz - az
	
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    if (t < 0) then
        return p1, false
    end
    if (t > 1) then
        return p2, false
    end
	local result = {x = ax + t * bxax, z = az + t * bzaz}
    return result, true
end

function IsInRange(v1, v2, range)
	v1 = v1.pos or v1
	v2 = v2.pos or v2
	local dx = v1.x - v2.x
	local dz = (v1.z or v1.y) - (v2.z or v2.y)
	if dx * dx + dz * dz <= range * range then
		return true
	end
	return false
end

function GetEnemyCount(range, pos)
    local pos = pos.pos
	local count = 0
	for i = 1, GameHeroCount() do 
	local hero = GameHero(i)
	local Range = range * range
		if hero.team ~= TEAM_ALLY and GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
		count = count + 1
		end
	end
	return count
end

function GetEnemyCountAtPos(checkrange, range, pos)
    local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(checkrange)
    local count = 0
    for i = 1, #enemies do 
        local enemy = enemies[i]
        local Range = range * range
        if GetDistanceSqr(pos, enemy.pos) < Range and IsValid(enemy) then
            count = count + 1
        end
    end
    return count
end

function GetEnemiesAtPos(checkrange, range, pos, target)
    local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(checkrange)
	local results = {}
    for i = 1, #enemies do 
        local enemy = enemies[i]
        local Range = range * range
        if GetDistanceSqr(pos, enemy.pos) < Range and IsValid(enemy) and enemy ~= target then
			table.insert(results, enemy)
        end
    end
	
	table.insert(results, target)
    return results
end

function GetMinionCount(checkrange, range, pos)
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(checkrange)
    local count = 0
    for i = 1, #minions do 
        local minion = minions[i]
        local Range = range * range
        if GetDistanceSqr(pos, minion.pos) < Range and IsValid(minion) then
            count = count + 1
        end
    end
    return count
end

function GetMinionsAroundMinion(checkrange, range, minion)
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(checkrange)
	local results = {}
    for i = 1, #minions do 
        local m = minions[i]
        local Range = range * range
        if GetDistanceSqr(minion.pos, m.pos) < Range and IsValid(minion) and (m ~= minion) then
			table.insert(results, m)
        end
    end
	return results
end

function GetCanonMinion(minions)
	for i = 1, #minions do
		local minion = minions[i]
		if(IsValid(minion)) then
			if (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then
				return minion
			end
		end
	end
	
	return nil
end

function GetMinionByHandle(handle)
	local cachedminions = _G.SDK.ObjectManager:GetMinions()
	for i = 1, #cachedminions do
		local obj = cachedminions[i]
		if(obj.handle == handle) then
			return obj
		end
	end
	
	return nil
end

function GetMinionType(minion)
	if (minion.charName:find("ChaosMinionSiege")  or minion.charName:find("OrderMinionSiege")) then
		return MINION_CANON
	end
	
	if (minion.charName:find("ChaosMinionRanged")  or minion.charName:find("OrderMinionRanged")) then
		return MINION_CASTER
	end
	
	if (minion.charName:find("ChaosMinionMelee")  or minion.charName:find("OrderMinionMelee")) then
		return MINION_MELEE
	end
	
	return -1
end

function GetMinionTurretDamage(minion)
	if(GetMinionType(minion) == MINION_CASTER) then
		return minion.maxHealth * 0.7
	end

	if(GetMinionType(minion) == MINION_MELEE) then
		return minion.maxHealth * 0.45
	end
	
	return GetTurretDamage()
end

function AverageClusterPosition(targets)
	local finalPos = {x = 0, z = 0}
	for _, target in pairs(targets) do
		finalPos.x = finalPos.x + target.pos.x
		finalPos.z = finalPos.z + target.pos.z
	end
	
	finalPos.x = finalPos.x / #targets
	finalPos.z = finalPos.z / #targets
	
	local point = Vector(finalPos.x, myHero.pos.y, finalPos.z)
	return point
end

-- 2D dot product of two normalized vectors
function dotProduct( a, b )
        -- multiply the x's, multiply the y's, then add
		local mag1 = a
		local mag2 = b
		mag1.y = a.y or a.z or 0
		mag2.y = b.y or b.z or 0
        local dot = (mag1.x * mag2.x + mag1.y * mag2.y)
        return dot
end

-- 3D dot product of two normalized vectors
function dotProduct3D( a, b )
        -- multiply the x's, multiply the y's, then add
        local dot = (a.x * b.x + a.y * b.y + a.z * b.z)
        return dot
end

function CalculateBoundingBoxAvg(targets, predSpeed, predDelay)
	local highestX, lowestX, highestZ, lowestZ = 0, math.huge, 0, math.huge
	local avg = {x = 0, y = 0, z = 0}
	for k, v in pairs(targets) do
		local vPos = v.pos
		if(predDelay) then
			if(predDelay > 0) then
				vPos = v:GetPrediction(predSpeed, predDelay)
			end
		end
		
		if(vPos.x >= highestX) then
			highestX = vPos.x
		end
		
		if(vPos.z >= highestZ) then
			highestZ = vPos.z
		end
		
		if(vPos.x < lowestX) then
			lowestX = vPos.x
		end
		
		if(vPos.z < lowestZ) then
			lowestZ = vPos.z
		end
	end
	
	local vec1 = Vector(highestX, myHero.pos.y, highestZ)
	local vec2 = Vector(highestX, myHero.pos.y, lowestZ)
	local vec3 = Vector(lowestX, myHero.pos.y, highestZ)
	local vec4 = Vector(lowestX, myHero.pos.y, lowestZ)
	
	avg = (vec1 + vec2 + vec3 + vec4) /4
	
	return avg
end

function FindFurthestTargetFromMe(targets)	
	local furthestTarget = targets[1]
	local furthestDist = 0
	for _, target in pairs(targets) do
		local dist = myHero.pos:DistanceTo(target.pos)
		if(dist >= furthestDist) then
			furthestTarget = target
			furthestDist = dist
		end
	end
	
	return furthestTarget
end

function MyHeroNotReady()
    return myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or IsRecalling(myHero)
end

function CheckDmgItems(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}) do
        if myHero:GetItemData(j).itemID == itemID then 
			return j, (myHero:GetSpellData(j).currentCd == 0)
		end
    end
    return nil
end

function CalcMagicalDamage(source, target, amount, time)
    local passiveMod = 0
    
    local totalMR = target.magicResist

    if totalMR < 0 then
        passiveMod = 2 - 100 / (100 - totalMR)
    elseif totalMR * source.magicPenPercent - source.magicPen < 0 then
        passiveMod = 1
    else
        passiveMod = 100 / (100 + totalMR * source.magicPenPercent - source.magicPen)
    end

    local dmg = math.max(math.floor(passiveMod * amount), 0)
    
    if target.charName == "Kassadin" then
        dmg = dmg * 0.85
	elseif target.charName == "Malzahar" and HasBuff(target, "malzaharpassiveshield") then
		dmg = dmg * 0.1
    end
    
    if HasBuff(target, "cursedtouch") then
        dmg = dmg + amount * 0.1
    end
    return dmg
end

function CalcPhysicalDamage(source, target, amount)
    local armorPenetrationPercent = source.armorPenPercent
    local armorPenetrationFlat = source.armorPen * (0.6 + 0.4 * source.levelData.lvl / 18)
    local bonusArmorPenetrationMod = source.bonusArmorPenPercent

    local armor = target.armor
    local bonusArmor = target.bonusArmor
    local value

    if armor < 0 then
        value = 2 - 100 / (100 - armor)
    elseif armor * armorPenetrationPercent - bonusArmor *
        (1 - bonusArmorPenetrationMod) - armorPenetrationFlat < 0 then
        value = 1
    else
        value = 100 / (100 + armor * armorPenetrationPercent - bonusArmor *
                    (1 - bonusArmorPenetrationMod) - armorPenetrationFlat)
    end
	
	local final = math.max(math.floor(value * amount), 0)
	return final
end

function HasIgnite()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
		return true
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
		return true
	end
	
	return false
end

function HasElectrocute()
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.count>0 and buff.name:lower():find("electrocute.lua") then
			return true
        end
    end

	return false
end

function UseIgnite(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2, unit)
	end
end

function CanFlash()
	local slot = nil
	local hasFlash = false
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" or myHero:GetSpellData(SUMMONER_1).name == "SummonerCherryFlash" then
		slot = SUMMONER_1
		hasFlash = true
	end
	if myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" or myHero:GetSpellData(SUMMONER_2).name == "SummonerCherryFlash" then
		slot = SUMMONER_2
		hasFlash = true
	end

	if not hasFlash then
		return false
	end
	if myHero:GetSpellData(slot).currentCd > 0 or myHero:GetSpellData(slot).name == "SummonerCherryFlash_CD" then
		return false
	end
	if GameCanUseSpell(slot) ~= 0 then
		return false
	end

	if(Ready(slot) == false) then
		return false
	end

	return true
end

function UseFlash(pos)
	local castAtPos = false
	if(pos) then castAtPos = true end

	if myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" or myHero:GetSpellData(SUMMONER_1).name == "SummonerCherryFlash" then
		if(castAtPos) then
			if(GetDistance(myHero, pos) > 400) then
				pos = myHero.pos:Extended(pos, 400)
			end
 			Control.CastSpell(HK_SUMMONER_1, pos)
		else
			Control.CastSpell(HK_SUMMONER_1)
		end
	end
	if myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" or myHero:GetSpellData(SUMMONER_2).name == "SummonerCherryFlash" then
		if(castAtPos) then
			if(GetDistance(myHero, pos) > 400) then
				pos = myHero.pos:Extended(pos, 400)
			end
			Control.CastSpell(HK_SUMMONER_2, pos)
		else
			Control.CastSpell(HK_SUMMONER_2)
		end
	end
end

function CanUseSummoner(unit, name)
	if myHero:GetSpellData(SUMMONER_1).name == name and Ready(SUMMONER_1) then
		return true
	elseif myHero:GetSpellData(SUMMONER_2).name == name and Ready(SUMMONER_2) then
		return true
	end
	
	return false
end

function GetCircleIntersectionPoints(p1, p2, center, radius)
	local sect = {[0] = {0, 0, 0}, [1] = {0, 0, 0}}
	local dp = {x = 0, y = 0, z = 0}
    local a, b, c
    local bb4ac
    local mu1
    local mu2
	
     dp.x   = p2.x - p1.x
     dp.z   = p2.z - p1.z

     a = dp.x * dp.x + dp.z * dp.z
     b = 2 * (dp.x * (p1.x - center.x) + dp.z * (p1.z - center.z))
     c = center.x* center.x + center.z * center.z
     c = c + p1.x * p1.x + p1.z * p1.z
     c = c - 2 * (center.x * p1.x + center.z * p1.z)
     c = c - radius * radius
     bb4ac  = b * b - 4 * a * c
     if(math.abs(a) < 0 or bb4ac < 0) then
         return sect
     end
	
     mu1 = (-b + math.sqrt(bb4ac)) / (2 * a)
     mu2 = (-b - math.sqrt(bb4ac)) / (2 * a)
	 
     sect[0] = {p1.x + mu1 * (p2.x - p1.x), 0, p1.z + mu1 * (p2.z - p1.z)}
     sect[1] = {p1.x + mu2 * (p2.x - p1.x), 0, p1.z + mu2 * (p2.z - p1.z)}
     
     return sect;
end

--This is a helper function that will use GGPrediction to find a suitable area to cast area spells outside of their default range - AKA edge casting
function GetExtendedSpellPrediction(target, spellData)
	local isExtended = false
	local extendedSpellData = {Type = spellData.Type, Delay = spellData.Delay, Range = spellData.Range + spellData.Radius, Radius = spellData.Radius, Speed = spellData.Speed, Collision = spellData.Collision}
	local spellPred = GGPrediction:SpellPrediction(extendedSpellData)
	local predVec = Vector(0, 0, 0)
	spellPred:GetPrediction(target, myHero)
	--Get the extended predicted position, and the cast range of the spell
	if(spellPred.CastPosition) then
		predVec = Vector(spellPred.CastPosition.x, myHero.pos.y, spellPred.CastPosition.z)
		if(myHero.pos:DistanceTo(predVec) < spellData.Range) then
			return spellPred, isExtended
		end
	end
	local defaultRangeVec = (predVec - myHero.pos):Normalized() * spellData.Range + myHero.pos
	--DrawCircle(testVec, 150, 3)
	--Find the difference between these two points as a vector to create a line, and then find a perpendicular bisecting line at the extended cast position using this line
	--local vec = (predVec - defaultRangeVec):Normalized() * 100 + myHero.pos
	local vecNormal = (predVec - defaultRangeVec):Normalized()
	local perp = Vector(vecNormal.z, 0, -vecNormal.x) * spellData.Radius + predVec
	local negPerp = Vector(-vecNormal.z, 0, vecNormal.x) * spellData.Radius + predVec

	--Find the points of intersection from our bisecting line to the radius of our spell at its cast range. 
	-- We can use this data to find a more precise circle, and make sure that our prediction will hit that.
	-- If our prediction hits the precise circle, that means our spell will hit if its extended
	-- This is really difficult to explain but much easier to visualize with diagrams
	local intersections = GetCircleIntersectionPoints(perp, negPerp, defaultRangeVec, spellData.Radius)
	
	--We only need one of the intersection points to form our precise circle
	local intVec = Vector(intersections[0][1], myHero.pos.y, intersections[0][3])
	--local halfVec = Vector((intersections[0][1] + intersections[1][1]) /2, myHero.pos.y, (intersections[0][3] + intersections[1][3])/2)
	
	local preciseCircRadius = intVec:DistanceTo(predVec)
	local preciseSpellData = {Type = spellData.Type, Delay = spellData.Delay, Range = spellData.Range + spellData.Radius, Radius = preciseCircRadius, Speed = spellData.Speed, Collision = spellData.Collision}
	local preciseSpellPred = GGPrediction:SpellPrediction(preciseSpellData)
	isExtended = true
	preciseSpellPred:GetPrediction(target, myHero)

	return preciseSpellPred, isExtended
end

function CalculateBestCirclePosition(targets, radius, edgeDetect, spellRange, spellSpeed, spellDelay)
	local avgCastPos = CalculateBoundingBoxAvg(targets, spellSpeed, spellDelay)
	local newCluster = {}
	local distantEnemies = {}

	for _, enemy in pairs(targets) do
		if(enemy.pos:DistanceTo(avgCastPos) > radius) then
			table.insert(distantEnemies, enemy)
		else
			table.insert(newCluster, enemy)
		end
	end
	
	if(#distantEnemies > 0) then
		local closestDistantEnemy = nil
		local closestDist = 10000
		for _, distantEnemy in pairs(distantEnemies) do
			local dist = distantEnemy.pos:DistanceTo(avgCastPos)
			if( dist < closestDist ) then
				closestDistantEnemy = distantEnemy
				closestDist = dist
			end
		end
		if(closestDistantEnemy ~= nil) then
			table.insert(newCluster, closestDistantEnemy)
		end
		
		--Recursion, we are discarding the furthest target and recalculating the best position
		if(#newCluster ~= #targets) then
			return CalculateBestCirclePosition(newCluster, radius)
		end
	end
	
	if(edgeDetect) and myHero.pos:DistanceTo(avgCastPos) > spellRange then

		local checkPos = myHero.pos:Extended(avgCastPos, spellRange)
		local furthestTarget = FindFurthestTargetFromMe(newCluster)
		local fakeMyHeroPos = avgCastPos:Extended(myHero.pos, spellRange + radius - 50)
		if(furthestTarget ~= nil) then
			fakeMyHeroPos = avgCastPos:Extended(myHero.pos, spellRange + radius - furthestTarget.pos:DistanceTo(avgCastPos))
		end

		if(myHero.pos:DistanceTo(avgCastPos) >= fakeMyHeroPos:DistanceTo(avgCastPos)) then
			checkPos = fakeMyHeroPos:Extended(avgCastPos, spellRange)
		end
		
		local hitAllCheck = true
		for _, v in pairs(newCluster) do
			if(v:GetPrediction(math.huge, spellDelay):DistanceTo(checkPos) >= radius + 5) then -- the +5 is to fix a precision issue
				hitAllCheck = false
			end
		end
		
		if hitAllCheck then 
			return checkPos, #newCluster, newCluster
		end

	end
	
	return avgCastPos, #targets, targets
end

--Checks to see if a unit is running towards or away from the target
function GetUnitRunDirection(unit, target)
	if(target.pathing.hasMovePath) then
		local meVec = (unit.pos - target.pos):Normalized()
		local pathVec = (target.pathing.endPos - target.pos):Normalized()
		if(dotProduct3D(meVec, pathVec) <= -0.5) then
			return RUNNING_AWAY
		else
			return RUNNING_TOWARDS
		end
	end
	return nil
end

function CantKill(unit, kill, ss, aa)
	--set kill to true if you dont want to waste on undying/revive targets
	--set ss to true if you dont want to cast on spellshield
	--set aa to true if ability applies onhit (yone q, ez q etc)
	
	for i = 0, unit.buffCount do
	
		local buff = unit:GetBuff(i)
		if buff.name:lower():find("kayler") and buff.count==1 then
			return true
		end
	
		if buff.name:lower():find("undyingrage") and (unit.health<100 or kill) and buff.count==1 then
			return true
		end
		if buff.name:lower():find("kindredrnodeathbuff") and (kill or (unit.health / unit.maxHealth)<0.11) and buff.count==1  then
			return true
		end	
		if buff.name:lower():find("chronoshift") and kill and buff.count==1 then
			return true
		end			
		
		if  buff.name:lower():find("willrevive") and (unit.health / unit.maxHealth) >= 0.5 and kill and buff.count==1 then
			return true
		end

		if  buff.name:lower():find("morganae") and ss and buff.count==1 then
			return true
		end
		
		if (buff.name:lower():find("fioraw") or buff.name:lower():find("pantheone")) and buff.count==1 then
			return true
		end
		
		if  buff.name:lower():find("jaxcounterstrike") and aa and buff.count==1  then
			return true
		end
		
		if  buff.name:lower():find("nilahw") and aa and buff.count==1  then
			return true
		end
		
		if  buff.name:lower():find("shenwbuff") and aa and buff.count==1  then
			return true
		end	
	end
	
	if HasBuffType(unit, 4) and ss then
		return true
	end
	
	return false
end

function GetPrediction(target, spell_speed, casting_delay)
	local caster_position = myHero.pos
	local target_position = target.pos
	local direction_vector = target.dir
	local movement_speed = target.ms

	if(target.pathing.hasMovePath) then
		direction_vector = (target.pathing.endPos - target.pos):Normalized()
	end
	
	-- Normalize direction_vector
	local magnitude = math.sqrt(direction_vector.x^2 + direction_vector.z^2)
	local normalized_direction_vector = {x = direction_vector.x / magnitude, z = direction_vector.z / magnitude}
	
	-- Target velocity vector
	local target_velocity = {x = normalized_direction_vector.x * movement_speed, z = normalized_direction_vector.z * movement_speed}

	-- If the spell_speed is math.huge (i.e., the spell travels instantaneously), return the predicted target_position after casting_delay
	if spell_speed == math.huge then
		return {x = target_position.x + target_velocity.x * casting_delay, z = target_position.z + target_velocity.z * casting_delay}
	end

	-- Calculate difference in positions
	local delta_position = {x = target_position.x - caster_position.x, z = target_position.z - caster_position.z}

	-- Quadratic equation coefficients
	local a = (target_velocity.x^2 + target_velocity.z^2) - spell_speed^2
	local b = 2 * (delta_position.x * target_velocity.x + delta_position.z * target_velocity.z)
	local c = delta_position.x^2 + delta_position.z^2

	-- Discriminant
	local discriminant = b^2 - 4*a*c

	-- If the discriminant is negative, no real solution exists
	if discriminant < 0 then
		return nil
	end

	-- Find the two possible solutions
	local t1 = (-b + math.sqrt(discriminant)) / (2 * a)
	local t2 = (-b - math.sqrt(discriminant)) / (2 * a)

	-- We want the smallest positive t (if it exists)
	local t = nil
	if t1 > 0 and t2 > 0 then
		t = math.min(t1, t2)
	elseif t1 > 0 then
		t = t1
	elseif t2 > 0 then
		t = t2
	end

	if t == nil then
		return nil
	end

	-- Compute the interception point
	local interception_point = {
		x = target_position.x + target_velocity.x * t,
		y = target_position.y,
		z = target_position.z + target_velocity.z * t
	}

	return interception_point
end


function CastPredictedSpell(hotkey, target, SpellData, extendedCheck, maxCollision, collisionWidthOverride)
	if(not IsValid(myHero) or myHero.dead) then return end
	if(SpellData.Range == nil) then return end

	SpellData.Speed = SpellData.Speed or math.huge
	SpellData.Delay = SpellData.Delay or 0
	maxCollision = maxCollision or 0
	collisionWidthOverride = collisionWidthOverride or SpellData.Radius or 0
	local collisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}
	if(IsValid(target) and CantKill(target, true, true, false)==false) then
		local isStrafing, avgPos = StrafePred:IsStrafing(target)
		local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
		
		if(isStrafing) then
			if(avgPos:DistanceTo(myHero.pos) < SpellData.Range) then
				if(maxCollision > 0) then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, avgPos, SpellData.Speed, SpellData.Delay, collisionWidthOverride, collisionTypes, target.networkID)
					if(collisionCount < maxCollision) then
						Control.CastSpell(hotkey, avgPos)
						return true
					end
				else
					Control.CastSpell(hotkey, avgPos)
					return true
				end
			end
		end
		if(isStutterDancing) then
			if(avgPos2:DistanceTo(myHero.pos) < SpellData.Range) then
				if(maxCollision > 0) then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, avgPos2, SpellData.Speed, SpellData.Delay, collisionWidthOverride, collisionTypes, target.networkID)
					if(collisionCount < maxCollision) then
						Control.CastSpell(hotkey, avgPos2)
						return true
					end
				else
					Control.CastSpell(hotkey, avgPos2)
					return true
				end
			end
		end
		
		if(extendedCheck) then
			local SpellPrediction, isExtended = GetExtendedSpellPrediction(target, SpellData)
			if SpellPrediction:CanHit(HITCHANCE_HIGH) then
				Control.CastSpell(hotkey, SpellPrediction.CastPosition)
				return
			end
		else
			local SpellPrediction = GGPrediction:SpellPrediction(SpellData)
			SpellPrediction:GetPrediction(target, myHero)
			if SpellPrediction.CastPosition and SpellPrediction:CanHit(HITCHANCE_HIGH) then
				if(GetDistance(SpellPrediction.CastPosition, myHero.pos) <= SpellData.Range - 50) then

					if(maxCollision > 0) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, SpellPrediction.CastPosition, SpellData.Speed, SpellData.Delay, collisionWidthOverride, collisionTypes, target.networkID)
						if(collisionCount < maxCollision) then
							Control.CastSpell(hotkey, SpellPrediction.CastPosition)
							return true
						end
					else
						Control.CastSpell(hotkey, SpellPrediction.CastPosition)
						return true
					end

				end
			end
		end

		--If pred still doesn't want to go, we'll just use KillerLib pred
		local enemyPredPos = Vector(GetPrediction(target, SpellData.Speed, SpellData.Delay))
		if(enemyPredPos) then
			if(GetDistance(enemyPredPos, myHero.pos) <= SpellData.Range - 50) then
				if(maxCollision > 0) then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, enemyPredPos, SpellData.Speed, SpellData.Delay, collisionWidthOverride, collisionTypes, target.networkID)
					if(collisionCount < maxCollision) then
						Control.CastSpell(hotkey, enemyPredPos)
						return true
					end
				else
					Control.CastSpell(hotkey, enemyPredPos)
					return true
				end
			end
		end
	end

	return false
end
