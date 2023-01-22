local Heroes = {"Syndra"}

if not table.contains(Heroes, myHero.charName) then return end

require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"

scriptVersion = 1.04

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Syndra will exit.")
    return
end

----------------------------------------------------
--|                    Checks                    |--
----------------------------------------------------


-- [ AutoUpdate ]
do
    
	local Version = scriptVersion
	local gitHub = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/Champions/"
    local Files = {
	
        Lua = {
            Path = SCRIPT_PATH,
            Name = "KillerSyndra.lua",
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "KillerSyndra.version",
        }
		
    }
    
    local function AutoUpdate()
        local function DownloadFile(path, fileName)
            DownloadFileAsync(gitHub .. fileName, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Path, Files.Version.Name)
        local textPos = myHero.pos:To2D()
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Path, Files.Lua.Name)
            print("New Killer Syndra Version - Please reload with F6")
        else
            print("| KILLER | Syndra Loaded! Enjoy :)")
        end
    end
	
   AutoUpdate()
end
----------------------------------------------------
--|                   		UTILITY					             |--
----------------------------------------------------

-- VARS --

local heroes = false
local wClock = 0
local clock = os.clock
local Latency = Game.Latency
local ping = Latency() * 0.001
local foundAUnit = false
local _movementHistory = {}
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team
local TEAM_JUNGLE = 300
local wClock = 0
local _OnVision = {}
local sqrt = math.sqrt
local MathHuge = math.huge
local TableInsert = table.insert
local TableRemove = table.remove
local GameTimer = Game.Timer
local Allies, Enemies, Turrets, FriendlyTurrets, Units = {}, {}, {}, {}, {}
local Orb
local DrawRect = Draw.Rect
local DrawLine = Draw.Line
local DrawCircle = Draw.Circle
local DrawColor = Draw.Color
local DrawText = Draw.Text
local ControlSetCursorPos = Control.SetCursorPos
local ControlKeyUp = Control.KeyUp
local ControlKeyDown = Control.KeyDown
local GameCanUseSpell = Game.CanUseSpell
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameTurretCount = Game.TurretCount
local GameTurret = Game.Turret
local GameIsChatOpen = Game.IsChatOpen
local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
_G.LATENCY = 0.05


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
local function GetTarget(unit)
	return TargetSelector:GetTarget(unit, 1)

end

TargetSelector = _G.SDK.TargetSelector


local function CheckWall(from, to, distance)
    local pos1 = to + (to - from):Normalized() * 50
    local pos2 = pos1 + (to - from):Normalized() * (distance - 50)
    local point1 = Point(pos1.x, pos1.z)
    local point2 = Point(pos2.x, pos2.z)
    if MapPosition:intersectsWall(LineSegment(point1, point2)) then
        return true
    end
    return false
end


local function EnemyHeroes()
    local _EnemyHeroes = {}
    for i = 1, GameHeroCount() do
        local unit = GameHero(i)
        if unit.isEnemy then
            TableInsert(_EnemyHeroes, unit)
        end
    end
    return _EnemyHeroes
end


local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

local function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and GameCanUseSpell(spell) == 0
end

local function GetDistanceSqr(pos1, pos2)
	local pos2 = pos2 or myHero.pos
	local dx = pos1.x - pos2.x
	local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
	return dx * dx + dz * dz
end

local function GetDistance(pos1, pos2)
	return sqrt(GetDistanceSqr(pos1, pos2))
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

local function SetAttack(bool)
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

local function SetMovement(bool)
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

local function CheckLoadedEnemies()
	local count = 0
	for i, unit in ipairs(Enemies) do
        if unit and unit.isEnemy then
		count = count + 1
		end
	end
	return count
end

local function GetEnemyHeroes()
	return Enemies
end

local function GetEnemyTurrets()
	return Turrets
end

local function GetFriendlyTurrets()
	return FriendlyTurrets
end

local function GetEnemyHeroes(range, bbox)
	local result = {}
	for _, unit in ipairs(Enemies) do
		local extrarange = bbox and unit.boundingRadius or 0
		if unit.distance < range + extrarange then
			table.insert(result, unit)
		end
	end
	return result
end

local function IsUnderTurret(unit)
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

local function IsUnderFriendlyTurret(unit)
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

local function GetTurretDamage()
	local minutes = math.min(Game.Timer()/60, 14)
	return 162 + (13 * math.floor(minutes))
end

local function IsInFountain()
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

local function HasBuff(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)	

		if buff.name == buffname and buff.count > 0 then 
			return true
		end
	end
	return false
end

local function HasBuffType(unit, type)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.type == type then
            return true
        end
    end
    return false
end

local function GetBuffData(unit, buffname)
	for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return buff
		end
	end
	return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

local function IsRecalling(unit)
	local buff = GetBuffData(unit, "recall")
	if buff and buff.duration > 0 then
		return true, GameTimer() - buff.startTime
	end
    return false
end

function IsImmobile(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 29 or buff.name == "recall" then
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

local function ClosestPointOnLineSegment(p, p1, p2)
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

local function IsInRange(v1, v2, range)
	v1 = v1.pos or v1
	v2 = v2.pos or v2
	local dx = v1.x - v2.x
	local dz = (v1.z or v1.y) - (v2.z or v2.y)
	if dx * dx + dz * dz <= range * range then
		return true
	end
	return false
end

local function GetEnemyCount(range, pos)
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

local function GetEnemyCountAtPos(checkrange, range, pos)
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

local function GetEnemiesAtPos(checkrange, range, pos,target)
    local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(checkrange)
	local results = {}
    for i = 1, #enemies do 
        local enemy = enemies[i]
        local Range = range * range
        if GetDistanceSqr(pos, enemy.pos) < Range and IsValid(enemy) and enemy ~= target then
			table.insert(results, enemy)
        end
		
		if target then
			table.insert(results, target)
		end
    end
    return results
end

local function GetMinionCount(checkrange, range, pos)
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

local function GetMinionsAroundMinion(checkrange, range, minion)
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

local function GetCanonMinion(minions)
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

local function AverageClusterPosition(targets)
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
        local dot = (a.x * b.x + a.z * b.z)
        return dot
end

local function CalculateBoundingBoxAvg(targets, predDelay)
	local highestX, lowestX, highestZ, lowestZ = 0, math.huge, 0, math.huge
	local avg = {x = 0, y = 0, z = 0}
	for k, v in pairs(targets) do
		local vPos = v.pos
		if(predDelay > 0) then
			vPos = v:GetPrediction(math.huge, predDelay)
		end
		
		if(vPos.x >= highestX) then
			highestX = v.pos.x
		end
		
		if(vPos.z >= highestZ) then
			highestZ = v.pos.z
		end
		
		if(vPos.x < lowestX) then
			lowestX = v.pos.x
		end
		
		if(vPos.z < lowestZ) then
			lowestZ = v.pos.z
		end
	end
	
	local vec1 = Vector(highestX, myHero.pos.y, highestZ)
	local vec2 = Vector(highestX, myHero.pos.y, lowestZ)
	local vec3 = Vector(lowestX, myHero.pos.y, highestZ)
	local vec4 = Vector(lowestX, myHero.pos.y, lowestZ)
	
	avg = (vec1 + vec2 + vec3 + vec4) /4
	
	return avg
end

local function FindFurthestTargetFromMe(targets)	
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

local function MyHeroNotReady()
    return myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or IsRecalling(myHero)
end

local function CheckDmgItems(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}) do
        if myHero:GetItemData(j).itemID == itemID then 
			return j, (myHero:GetSpellData(j).currentCd == 0)
		end
    end
    return nil
end

local function CalcMagicalDamage(source, target, amount, time)
    local passiveMod = 0
    
    local totalMR = target.magicResist + target.bonusMagicResist
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

local function UseIgnite(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2, unit)
	end
end

local function CanUseSummoner(unit, name)
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
local function GetExtendedSpellPrediction(target, spellData)
	local isExtended = false
	local extendedSpellData = {Type = spellData.Type, Delay = spellData.Delay, Range = spellData.Range + spellData.Radius, Radius = spellData.Radius, Speed = spellData.Speed, Collision = spellData.Collision}
	local spellPred = GGPrediction:SpellPrediction(extendedSpellData)
	spellPred:GetPrediction(target, myHero)
	--Get the extended predicted position, and the cast range of the spell
	local predVec = Vector(spellPred.CastPosition.x, myHero.pos.y, spellPred.CastPosition.z)
	if(myHero.pos:DistanceTo(predVec) < spellData.Range) then
		return spellPred, isExtended
	end
	local defaultRangeVec = (predVec - myHero.pos):Normalized() * spellData.Range + myHero.pos
	
	--Find the difference between these two points as a vector to create a line, and then find a perpendicular bisecting line at the extended cast position using this line
	local vec = (predVec - defaultRangeVec):Normalized() * 100 + myHero.pos
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
	local halfVec = Vector((intersections[0][1] + intersections[1][1]) /2, myHero.pos.y, (intersections[0][3] + intersections[1][3])/2)
	
	local preciseCircRadius = intVec:DistanceTo(predVec)
	local preciseSpellData = {Type = spellData.Type, Delay = spellData.Delay, Range = spellData.Range + spellData.Radius, Radius = preciseCircRadius, Speed = spellData.Speed, Collision = spellData.Collision}
	local preciseSpellPred = GGPrediction:SpellPrediction(preciseSpellData)
	isExtended = true
	preciseSpellPred:GetPrediction(target, myHero)
	
	return preciseSpellPred, isExtended
end

class("SpellCast")
 
 
function SpellCast:__init()
    _G._SPELLCAST_START = true
    self.OnSpellCastCallback = {}
    Callback.Add("Tick", function() self:OnTick() end)
end
 
SpellCast.QDidCast = false
SpellCast.WDidCast = false
SpellCast.EDidCast = false
SpellCast.RDidCast = false
 
function SpellCast:OnTick()
	
	if(self.QDidCast == false) then
		if(myHero:GetSpellData(_Q).currentCd) > 0 and myHero:GetSpellData(_Q).cd ~= 0 then
			self.QDidCast = true
			local spell = myHero:GetSpellData(_Q)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.WDidCast == false) then
		if(myHero:GetSpellData(_W).currentCd) > 0 and myHero:GetSpellData(_W).cd ~= 0 then
			self.WDidCast = true
			local spell = myHero:GetSpellData(_W)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.EDidCast == false) then
		if(myHero:GetSpellData(_E).currentCd) > 0 and myHero:GetSpellData(_E).cd ~= 0 then
			self.EDidCast = true
			local spell = myHero:GetSpellData(_E)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.RDidCast == false) then
		if(myHero:GetSpellData(_R).currentCd) > 0 and myHero:GetSpellData(_R).cd ~= 0 then
			self.RDidCast = true
			local spell = myHero:GetSpellData(_R)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	self:UpdateSpellChecks()
end

function SpellCast:UpdateSpellChecks()
	if(Ready(_Q)) then self.QDidCast = false end
	if(Ready(_W)) then self.WDidCast = false end
	if(Ready(_E)) then self.EDidCast = false end
	if(Ready(_R)) then self.RDidCast = false end
end

local function OnSpellCast(fn)
    if not _SPELLCAST_START then
        _G.SpellCast = SpellCast()
    end
    table.insert(SpellCast.OnSpellCastCallback, fn)
end

class("StrafePred")

StrafePred.WaypointData = {}
StrafePred.NewPosData = {}

function StrafePred:__init()
    _G._STAFEPRED_START = true
    self.OnStrafePredCallback = {}
    Callback.Add("Tick", function() self:OnTick() end)
	
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local enemyUnit = args.unit
		self.WaypointData[enemyUnit.handle] = {}
		self.NewPosData[enemyUnit.handle] = {x = 0, z = 0}
		
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
			
			--[[
			DrawCircle((pos1), 5, 20)
			DrawCircle((pos2), 5, 20)
			DrawCircle((pos3), 5, 20)
			DrawCircle((pos4), 5, 20)
			DrawCircle(avgPos, 5, 20, DrawColor(255, 255, 0, 0))
			--]]
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

local function OnChampStrafe(fn)
    if not _STAFEPRED_START then
        _G.StrafePred = StrafePred()
    end
    table.insert(StrafePred.OnStrafePredCallback, fn)
end

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Syndra"

local SyndraIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/134.png"

local gameTick = GameTimer()
Syndra.AutoLevelCheck = false

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.7, Range = 800, Radius = 175, Speed = math.huge, Collision = false}
local W = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.2, Radius = 225, Range = 950, Speed = 1450, Collision = false}
local E = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.25, Radius = 150, Range = 700, Speed = 2500, Collision = false}
local QE = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 1200, Speed = 2000, Collision = GGPrediction.COLLISION_YASUOWALL}
local R = {Range = 675, Collision = GGPrediction.COLLISION_YASUOWALL}

local QPremium = {speed = math.huge, range = 800, delay = 0.7, radius = 210, collision = {nil}, type = "circular"}

--Main Menu
Syndra.Menu = MenuElement({type = MENU, id = "KillerSyndra", name = "Killer Syndra", leftIcon = SyndraIcon})
Syndra.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

Syndra.OrbData = {}
Syndra.PreOrbData = {}
Syndra.ComboDamageData = {}

Syndra.InterruptableSpells = {
        ["CaitlynAceintheHole"] = {Name = "Caitlyn", displayname = "R | Ace in the Hole", spellname = "CaitlynAceintheHole"},
        ["Crowstorm"] = {Name = "FiddleSticks", displayname = "R | Crowstorm", spellname = "Crowstorm"},
        ["DrainChannel"] = {Name = "FiddleSticks", displayname = "W | Drain", spellname = "DrainChannel"},
        ["GalioIdolOfDurand"] = {Name = "Galio", displayname = "R | Idol of Durand", spellname = "GalioIdolOfDurand"},
        ["ReapTheWhirlwind"] = {Name = "Janna", displayname = "R | Monsoon", spellname = "ReapTheWhirlwind"},
        ["KarthusFallenOne"] = {Name = "Karthus", displayname = "R | Requiem", spellname = "KarthusFallenOne"},
        ["KatarinaR"] = {Name = "Katarina", displayname = "R | Death Lotus", spellname = "KatarinaR"},
        ["LucianR"] = {Name = "Lucian", displayname = "R | The Culling", spellname = "LucianR"},
        ["AlZaharNetherGrasp"] = {Name = "Malzahar", displayname = "R | Nether Grasp", spellname = "AlZaharNetherGrasp"},
        ["Meditate"] = {Name = "MasterYi", displayname = "W | Meditate", spellname = "Meditate"},
        ["MissFortuneBulletTime"] = {Name = "MissFortune", displayname = "R | Bullet Time", spellname = "MissFortuneBulletTime"},
        ["AbsoluteZero"] = {Name = "Nunu", displayname = "R | Absoulte Zero", spellname = "AbsoluteZero"},
        ["PantheonRJump"] = {Name = "Pantheon", displayname = "R | Jump", spellname = "PantheonRJump"},
        ["PantheonRFall"] = {Name = "Pantheon", displayname = "R | Fall", spellname = "PantheonRFall"},
        ["ShenStandUnited"] = {Name = "Shen", displayname = "R | Stand United", spellname = "ShenStandUnited"},
        ["Destiny"] = {Name = "TwistedFate", displayname = "R | Destiny", spellname = "Destiny"},
        ["UrgotSwap2"] = {Name = "Urgot", displayname = "R | Hyper-Kinetic Position Reverser", spellname = "UrgotSwap2"},
        ["VarusQ"] = {Name = "Varus", displayname = "Q | Piercing Arrow", spellname = "VarusQ"},
        ["VelkozR"] = {Name = "Velkoz", displayname = "R | Lifeform Disintegration Ray", spellname = "VelkozR"},
        ["InfiniteDuress"] = {Name = "Warwick", displayname = "R | Infinite Duress", spellname = "InfiniteDuress"},
        ["XerathLocusOfPower2"] = {Name = "Xerath", displayname = "R | Rite of the Arcane", spellname = "XerathLocusOfPower2"},
        ["JhinR"] = {displayname = "R | Curtain Call", spellname = "JhinR"},
}

function Syndra:__init()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	--Custom Callbacks
	OnSpellCast(function(spell) self:OnSpellCast(spell) end)
	StrafePred()
	_G.SDK.Orbwalker:OnPreAttack(function(...) Syndra:OnPreAttack(...) end)
end

function Syndra:LoadMenu()                     	

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E to Stun", value = true})
	self.Menu.Combo:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.Combo:MenuElement({id = "AntiMeleeE", name = "Anti-Melee E", value = true})
	self.Menu.Combo:MenuElement({id = "SmartAABlock", name = "Smart AA Block", value = true})
	self.Menu.Combo:MenuElement({id = "QEKey", name = "Semi-manual QE Stun", key = string.byte("Z")})
	
	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Harass:MenuElement({id = "QCanon", name = "Last Hit Q on Canon Minion", value = true})
	self.Menu.Harass:MenuElement({id = "QMana", name = "Q Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Harass:MenuElement({id = "WMana", name = "W Min Mana", value = 35, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.LastHit:MenuElement({id = "QMode", name = "Q Mode",  value = 2, drop = {"Always Last Hit", "Only Last Hit if AA Cant Kill"}})
	self.Menu.LastHit:MenuElement({id = "PrioritizeCanon", name = "Prioritize Canon Minion", value = true})
	self.Menu.LastHit:MenuElement({id = "AssistedW", name = "Use W to Farm Under Turret", value = true})
	self.Menu.LastHit:MenuElement({id = "QMana", name = "Q Min Mana", value = 15, min = 0, max = 100, step = 5, identifier = "%"})
	

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Clear:MenuElement({id = "QMana", name = "Q Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear:MenuElement({id = "WMana", name = "W Min Mana", value = 35, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.KillSteal:MenuElement({id = "RBlacklist", name = "R Killsteal Blacklist (Unless Solo)", type = MENU})

	self.Menu:MenuElement({id = "EInterrupter", name = "E Interrupter", type = MENU})
	self.Menu.EInterrupter:MenuElement({id = "UseE", name = "Use E Interrupter",  value = true})
	self.Menu.EInterrupter:MenuElement({id = "HumanizedDelay", name = "Humanized Delay", value = 180, min = 0, max = 1000, step = 10, identifier = "(ms)"})
	self.Menu.EInterrupter:MenuElement({id = "InterruptSpells", name = "Spells to Interrupt", type = MENU})
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawW", name = "Draw W Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawQE", name = "Draw QE Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawKillableTargets", name = "Draw Killable Targets", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawChampTracker", name = "Draw Champ Tracker", value = true})
	self.Menu.Drawings:MenuElement({id = "Debug", name = "Debug Drawings", type = MENU})
	
	-- Debug
	self.Menu.Drawings.Debug:MenuElement({id = "DrawOrbs", name = "Draw Orbs", value = true})
	self.Menu.Drawings.Debug:MenuElement({id = "DrawELines", name = "Draw E Lines", value = true})
	self.Menu.Drawings.Debug:MenuElement({id = "DrawParticles", name = "Draw Particles", value = false})
	
	-- Prediction
	self.Menu:MenuElement({id = "Prediction", name = "Prediction", type = MENU})
	self.Menu.Prediction:MenuElement({id = "QHitChance", name = "Q Hit Chance",  value = 2, drop = {"Normal", "High", "Immobile"}})
	self.Menu.Prediction:MenuElement({id = "WHitChance", name = "W Hit Chance",  value = 2, drop = {"Normal", "High", "Immobile"}})
	self.Menu.Prediction:MenuElement({id = "EHitChance", name = "E Hit Chance",  value = 2, drop = {"Normal", "High", "Immobile"}})
		
	self.Menu:MenuElement({id = "AutoLevel", name = "Auto Level Skills (Q - W - E)", value = false})

	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local hero = args.unit
		local charName = args.charName
		--Add R blacklist champs
		self.Menu.KillSteal.RBlacklist:MenuElement({id = charName, name = charName, value = false})
		--Add interruptible spells
		for spell, args in pairs(self.InterruptableSpells) do
			if(charName == args.Name) then
				self.Menu.EInterrupter.InterruptSpells:MenuElement({id = spell, name = charName .. " - ".. args.displayname, value = true})
			end
		end
	end)
end


function Syndra:Tick()
	if(MyHeroNotReady()) then return end

	local mode = GetMode()
	if(mode == "Combo") then
		self:Combo()
	elseif(mode == "Harass") then
		self:Harass()
	elseif(mode == "LastHit") then
		self:LastHit()
	elseif(mode == "LaneClear") then
		self:Clear()
	end
	
	self:UpdateOrbs()
	self:UpdateComboDamage()
	self:KillSteal()
	
	if(self.Menu.EInterrupter.UseE:Value()) then
		self:EInterrupter()
	end
	
	if(self.Menu.Combo.SmartAABlock:Value()) then
		self:SmartAABlock()
	end
	
	if(self.Menu.Combo.QEKey:Value()) then
		self:SemiManualStun()
	end
	
	if Game.IsOnTop() and self.Menu.AutoLevel:Value() then
		self:AutoLevel()
	end	
end

function Syndra:OnPreAttack(args)
    if GetMode()=="Combo" and (Ready(_Q) or Ready(_W)) then
        args.Process = false
    end
end

-- Make sure we don't have duplicate orbs in our database
function Syndra:CheckExistingOrb(obj)
	for _, orb in pairs(self.OrbData) do
		if(orb.orbObj.networkID == obj.networkID) then
			return true
		end
	end
	return false
end

function Syndra:CheckExistingPreOrb(obj)
	for _, orb in pairs(self.PreOrbData) do
		if(orb.networkID == obj.networkID) then
			return true
		end
	end
	return false
end

--Searching for orbs on the map
function Syndra:CheckOrbs()

	local particleCount = Game.ParticleCount()
	for i = particleCount, 1, -1 do
		local obj = Game.Particle(i)
		local nameCheck = obj.name:lower():find("_q_lv5_idle") or obj.name:lower():find("_q_2021_idle")
		if obj and obj.type == "obj_GeneralParticleEmitter" and nameCheck and self:CheckExistingOrb(obj) == false then
			self.OrbData[#self.OrbData + 1] = {orbObj = obj, age = GameTimer()}
		end
	end
	
end

function Syndra:CheckSpawningOrbs()
	local particleCount = Game.ParticleCount()
	for i = particleCount, 1, -1 do
		local obj = Game.Particle(i)
		if obj and obj.type == "obj_GeneralParticleEmitter" and obj.name:find("_aoe_gather") and self:CheckExistingPreOrb(obj) == false then
			self.PreOrbData[#self.PreOrbData + 1] = {obj, GameTimer() + Q.Delay}
		end
	end
end

function Syndra:UpdateOrbs()
	for i = #self.OrbData, 1, -1 do
		local orb = self.OrbData[i].orbObj
		if(orb.type ~= "obj_GeneralParticleEmitter") then
			table.remove(self.OrbData, i)
		end
	end
	
	for i = #self.PreOrbData, 1, -1 do
		local preorb = self.PreOrbData[i]
		if(GameTimer() >= preorb[2]) then
			table.remove(self.PreOrbData, i)
		end
	end
end


function Syndra:OnSpellCast(spell)
	if spell.name == "SyndraQ" or spell.name == "SyndraQUpgrade" then
		self:CheckSpawningOrbs()
        DelayAction(function()
            self:CheckOrbs()
        end, 0.75)
	end
	
	if spell.name == "SyndraR" or spell.name == "SyndraRUpgrade" then
        DelayAction(function()
            self:CheckOrbs()
        end, 1.75)
	end
end

function Syndra:GetGrabObject()

	-- Priority = Orbs > Minions > Jungle Creeps
	local range = W.Range
	local obj = nil
	if(#self.OrbData > 0) then
		local oldestOrbAge = GameTimer()
		for _, orb in pairs(self.OrbData) do
			if(myHero.pos:DistanceTo(orb.orbObj.pos) < range) then
				if(orb.age <= oldestOrbAge) then
					obj = orb.orbObj
					oldestOrbAge = orb.age
				end
			end
		end
		
		if(obj ~= nil) then return obj end
	end
	
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(W.Range)
	if(#minions > 0) then
		for i = 1, #minions do
			local minion = minions[i]
			if IsValid(minion) then
				obj = minion
				break
			end
		end
		
		if(obj ~= nil) then return obj end
	end
	
	return obj
end

function Syndra:AutoLevel()
	if self.AutoLevelCheck then return end
	
	local level = myHero.levelData.lvl
	local levelPoints = myHero.levelData.lvlPts

	if (levelPoints == 0) or (level == 1) then return end
	if (Game.mapID == HOWLING_ABYSS and level <= 3) then return end
	--Order = Q > W > E
	if(levelPoints >0) then
		self.AutoLevelCheck = true
		DelayAction(function()				
				
				if level == 6 or level == 11 or level == 16 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_R)
					Control.KeyUp(HK_R)
					Control.KeyUp(HK_LUS)
				elseif level == 1 or level == 4 or level == 5 or level == 7 or level == 9 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_Q)
					Control.KeyUp(HK_Q)
					Control.KeyUp(HK_LUS)
				elseif level == 2 or level == 8 or level == 10 or level == 12 or level == 13 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_W)
					Control.KeyUp(HK_W)
					Control.KeyUp(HK_LUS)
				elseif level == 3 or level == 14 or level == 15 or level == 17 or level == 18 then				
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_E)
					Control.KeyUp(HK_E)
					Control.KeyUp(HK_LUS)
				end
		
			self.AutoLevelCheck = false
		end, 0.5)
	end
end

function Syndra:Combo()
	if(myHero.isChanneling) then return end
	if(gameTick > GameTimer()) then return end	
	
	-- Q
	if(Ready(_Q) and self.Menu.Combo.UseQ:Value()) then
		local target = GetTarget(Q.Range + Q.Radius*2)
		if(target ~= nil and IsValid(target)) then
		
			if(myHero.pos:DistanceTo(target.pos) < Q.Range + Q.Radius) then
				
				
				local isStrafing, avgPos = StrafePred:IsStrafing(target)
				local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
				if(isStrafing) then
					Control.CastSpell(HK_Q, avgPos)
					return
				end
				
				if(isStutterDancing) then
					Control.CastSpell(HK_Q, avgPos2)
					return
				end
				
				local QPrediction, isExtended = GetExtendedSpellPrediction(target, Q)
				if QPrediction:CanHit(self.Menu.Prediction.QHitChance:Value()) then
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
					return
				end
		
			end
		end
	end
	
	-- W
	if(Ready(_W) and self.Menu.Combo.UseW:Value()) then
		local target = GetTarget(W.Range) 
		if(target ~= nil and IsValid(target)) then
			if(myHero:GetSpellData(_W).name == "SyndraW") then
				local obj = self:GetGrabObject()
				if(obj ~= nil and myHero.pos:DistanceTo(obj.pos) < W.Range - 25) then
					Control.CastSpell(HK_W, obj.pos)
					gameTick = GameTimer() + 0.05 -- To prevent you from casting W at your mouse cursor instead of target
					return
				else
					return
				end
				
			elseif(myHero:GetSpellData(_W).name == "SyndraWCast") then
			
				local WPrediction = GGPrediction:SpellPrediction(W)
				WPrediction:GetPrediction(target, myHero)
				if WPrediction.CastPosition and WPrediction:CanHit(self.Menu.Prediction.WHitChance:Value()) then
					Control.CastSpell(HK_W, WPrediction.CastPosition)
					return
				end
			end
		end
	end
	
	-- E to stun
	if(Ready(_E) and self.Menu.Combo.UseE:Value()) then
		local target = GetTarget(QE.Range) 
		if(target ~= nil and IsValid(target)) then
			
			for _, orb in pairs(self.OrbData) do
				if(myHero.pos:DistanceTo(orb.orbObj.pos) < E.Range and myHero.pos:DistanceTo(orb.orbObj.pos) >= 175) then --Don't try to E orbs we are directly on top of, massive accuracy issues
					local trueOrbPos = self:GetTrueOrbPos(orb.orbObj)
					local dirVec = (trueOrbPos - myHero.pos):Normalized() * QE.Range
					local finalVec = myHero.pos + dirVec
					
					local QEPrediction = GGPrediction:SpellPrediction(QE)
					QEPrediction:GetPrediction(target, myHero)
					if QEPrediction:CanHit(2) then
						local finalPos = QEPrediction.CastPosition
						local point, isOnSegment = ClosestPointOnLineSegment(finalPos, myHero.pos, finalVec)						
						if isOnSegment then
							local distCheck = GetDistance(finalPos, point)
							if distCheck < QE.Radius then
								Control.CastSpell(HK_E, QEPrediction.CastPosition)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end
				end
			end
		end
	end
	
	-- R
	if(Ready(_R) and self.Menu.Combo.UseR:Value()) then		
		local target = GetTarget(R.Range)
		if(target ~= nil and IsValid(target)) then
			if(self:IsKillable(target) and (self:CantKill(target, true, true, false))==false) then
				Control.CastSpell(HK_R, target)
			end
		end
	end
	
	--Anti-melee
	local meleeTarget = GetTarget(250)
	if(meleeTarget ~= nil and IsValid(meleeTarget)) then
		if(Ready(_E) and self.Menu.Combo.UseE:Value() and self.Menu.Combo.AntiMeleeE:Value()) then
			--If we also have our Q up, we might as well go for the free stun
			if(Ready(_Q) and self.Menu.Combo.UseQ:Value()) then
				Control.CastSpell(HK_Q, meleeTarget.pos)
				DelayAction(function()
					Control.CastSpell(HK_E, meleeTarget.pos)
				end, 0.15)
			else
				Control.CastSpell(HK_E, meleeTarget.pos)
			end
		end
	end
end

function Syndra:Harass()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	
	if(self.Menu.Harass.QCanon:Value()) then
		if(Ready(_Q)) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) -- Q range is the same as W range
			local canonMinion = GetCanonMinion(minions)
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local QDam = getdmg("Q", canonMinion, myHero)
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay)
				
				if ((hp > 0) and (hp + (canonMinion.health*0.05) < QDam) or (canonMinion.health + 5 < QDam)) then
					Control.CastSpell(HK_Q, canonMinion)
				end
			end
		end
	end
	
	-- Q
	if(Ready(_Q) and self.Menu.Harass.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then
		local target = GetTarget(Q.Range + Q.Radius*2) 
		if(target ~= nil and IsValid(target)) then
			if(myHero.pos:DistanceTo(target.pos) < Q.Range + Q.Radius) then
			
				local isStrafing, avgPos = StrafePred:IsStrafing(target)
				local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
				if(isStrafing) then
					Control.CastSpell(HK_Q, avgPos)
					return
				end
				
				if(isStutterDancing) then
					Control.CastSpell(HK_Q, avgPos2)
					return
				end
				
				local QPrediction, isExtended = GetExtendedSpellPrediction(target, Q)
				if QPrediction:CanHit(self.Menu.Prediction.QHitChance:Value()) then
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
				end
		
			end
		end
	end
	
	-- W
	if(Ready(_W) and self.Menu.Harass.UseW:Value()) then
		local target = GetTarget(W.Range) 
		if(target ~= nil and IsValid(target)) then
			if(myHero:GetSpellData(_W).name == "SyndraW") then
				if((myHero.mana / myHero.maxMana) >= (self.Menu.Harass.WMana:Value() / 100)) then
					local obj = self:GetGrabObject()
					if(obj ~= nil) then
						Control.CastSpell(HK_W, obj.pos)
						gameTick = GameTimer() + 0.2
					else
						return
					end
				end
				
			elseif(myHero:GetSpellData(_W).name == "SyndraWCast") then
				local WPrediction = GGPrediction:SpellPrediction(W)
				WPrediction:GetPrediction(target, myHero)
				if WPrediction.CastPosition and WPrediction:CanHit(self.Menu.Prediction.WHitChance:Value()) then
					Control.CastSpell(HK_W, WPrediction.CastPosition)
					gameTick = GameTimer() + 0.2
				end
			end
		end
	end
	
end

function Syndra:LastHit()
	if(gameTick > GameTimer()) then return end --This is to prevent the mouse from spasming out
	
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(W.Range) --Just do 1 check for optimization
	local canonMinion = GetCanonMinion(minions)
	
	if(#minions == 0) then
		if(myHero:GetSpellData(_W).name == "SyndraWCast") then
			Control.CastSpell(HK_W)
		end
	end
	
	--Assisted W for farming under tower
	if(self.Menu.LastHit.AssistedW:Value()) then
		if(Ready(_W) and (myHero.mana / myHero.maxMana) >= (self.Menu.LastHit.QMana:Value() / 100)) then
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) and myHero.pos:DistanceTo(minion.pos) <= Q.Range then -- Normally i'd do W range here, but for sake of consistent range I am just sticking with Q
					--Under tower last hitting
					local isUnderTurret, turretUnit = IsUnderFriendlyTurret(minion)
					if(isUnderTurret) then
						if(turretUnit.targetID == minion.networkID) then
						
							if(myHero:GetSpellData(_W).name == "SyndraWCast") then
								Control.CastSpell(HK_W, minion)
							end
							--Active turret target
							local QDam = getdmg("Q", minion, myHero)
							local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
							local turrDmg = (GetTurretDamage())
							
							--Check if our Q is up
							if(Ready(_Q) == false and myHero:GetSpellData(_Q).currentCd >= 0.6) then
								if(hp - turrDmg <= 0 and minion.health - myHero.totalDamage > 0) then
									if(myHero:GetSpellData(_W).name == "SyndraW") then
										Control.CastSpell(HK_W, minion)
									end
								end
							end
							
							--Use W if our Q wont kill the minion but the turret will
							if(Ready(_Q)) then
								if(hp - QDam > 0 and hp - turrDmg <= 0 ) then
									if(myHero:GetSpellData(_W).name == "SyndraW") then
										Control.CastSpell(HK_W, minion)
									end
								end
							end
						else
							local turrDmg = (GetTurretDamage())
							if(minion.health - turrDmg > 0 and minion.health - turrDmg < myHero.totalDamage*2) then
								_G.SDK.Orbwalker:Attack(minion)
							end
						end
					else
						--For instances where you are holding a minion and the others arent under tower
						if(myHero:GetSpellData(_W).name == "SyndraWCast") then
							Control.CastSpell(HK_W, minion)
						end
					end	
				end
			end
		end
	end
	
	if(Ready(_Q) and self.Menu.LastHit.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.LastHit.QMana:Value() / 100)) then
		--Prioritize the canon minion if its low
		if(self.Menu.LastHit.PrioritizeCanon:Value()) then
			if(canonMinion ~= nil) and IsValid(canonMinion) and myHero.pos:DistanceTo(canonMinion.pos) <= Q.Range then
			
				local prediction = _G.PremiumPrediction:GetPrediction(myHero, canonMinion, QPremium)
				if prediction.CastPos and prediction.HitChance >= 0.15 then
					local QDam = getdmg("Q", canonMinion, myHero)
					local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay)
					
					if ((hp > 0) and (hp + canonMinion.health*0.07 - QDam <= 0)) then
						Control.CastSpell(HK_Q, prediction.CastPos)
					end
				end
				
			end
		end
		
		if(self.Menu.LastHit.QMode:Value() == 1) or IsUnderFriendlyTurret(myHero) then 
			--Always LastHit
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) and myHero.pos:DistanceTo(minion.pos) <= Q.Range then
				
					--Under tower last hitting
					local isUnderTurret, turretUnit = IsUnderFriendlyTurret(minion)
					if(isUnderTurret) then
						if(turretUnit.targetID == minion.networkID) then
							--Active turret target
							local QDam = getdmg("Q", minion, myHero)
							local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
							local turrDmg = (GetTurretDamage())
							
							--If a Q will kill the target, do it.
							if ((hp > 0) and (hp + (minion.health*0.05) < QDam) or (minion.health + 5 < QDam)) then
								Control.CastSpell(HK_Q, minion)
							end
						end
					else
						local prediction = _G.PremiumPrediction:GetPrediction(myHero, minion, QPremium)
						if prediction.CastPos and prediction.HitChance >= 0.15 then
							local QDam = getdmg("Q", minion, myHero)
							local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
							
							if ((hp > 0) and (hp + (minion.health*0.05) < QDam) or (minion.health + 5 < QDam)) then
								Control.CastSpell(HK_Q, prediction.CastPos)
							end
						end
					end
					
				end
			end
			
		elseif(self.Menu.LastHit.QMode:Value() == 2) then 
		--Only LastHit if cant get the AA kill
			
			for i = 1, #minions do
				local minion = minions[i]
				
				--This first block will Q minions outside of your AA range and slightly ahead if they are killable and dying
				if IsValid(minion) and myHero.pos:DistanceTo(minion.pos) <= Q.Range and myHero.pos:DistanceTo(minion.pos) > myHero.range + 75 then
					local prediction = _G.PremiumPrediction:GetPrediction(myHero, minion, QPremium)
					if prediction.CastPos and prediction.HitChance >= 0.15 then
						local QDam = getdmg("Q", minion, myHero)
						local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay + 0.5)
						if (hp < 0) then
							Control.CastSpell(HK_Q, prediction.CastPos)
							return
						end
					end
				end
				
				--This second block will Q minions that are dying while you are AA'ing another minion
				if IsValid(minion) and myHero.pos:DistanceTo(minion.pos) <= myHero.range then
					if(myHero.attackData.state == STATE_WINDDOWN) then
					
						local tar = _G.SDK.Orbwalker:GetTarget(myHero)
						if(tar ~= nil) then
							if(tar.networkID ~= minion.networkID) then
								local prediction = _G.PremiumPrediction:GetPrediction(myHero, minion, QPremium)
								if prediction.CastPos and prediction.HitChance >= 0.15 then
									local QDam = getdmg("Q", minion, myHero)
									local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay + 0.5)
									if ((hp < 0) or (hp + (minion.health*0.05) < QDam*0.9) or (minion.health + 5 < QDam*0.9)) then
										Control.CastSpell(HK_Q, prediction.CastPos)
										return
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
end

function Syndra:Clear()
	if(gameTick > GameTimer()) then return end --This is to prevent the mouse from spasming out
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(W.Range + 100)
	local canonMinion = GetCanonMinion(minions)
	
	local Wtarget = nil
	
	--Prioritize the canon minion if its low
	if(self.Menu.Clear.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.QMana:Value() / 100)) then
		if(Ready(_Q)) then
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local QDam = getdmg("Q", canonMinion, myHero)
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay)

				if (hp > 0) and (hp + (canonMinion.health*0.05) < QDam) or (canonMinion.health + 15 < QDam) then
					Control.CastSpell(HK_Q, canonMinion)
					gameTick = GameTimer() + 0.2
					return
				end
			end
		end
	end
	
	--Fetch a W target. This is typically either a canon minion or the minion that has the lowest HP or is actively getting hit
	if(Ready(_W) and myHero:GetSpellData(_W).name == "SyndraW") then
		for i = 1, #minions do		
			local minion = minions[i]
			
			-- Check if a canon is alive, and if it is, that is our target
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				Wtarget = canonMinion
				break
			end
			
			-- Init a W target
			if(Wtarget == nil or IsValid(Wtarget)==false) then
				Wtarget = minion
			end

			if IsValid(minion) then
				local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
				if(hp <= Wtarget.health) then
					Wtarget = minion
				end
			end
		end
	end
	
	-- W -> Q minion combo. We scoop up a nearby minion, canon if possible, and throw it into a cluster of minions and follow up with a Q
	if(self.Menu.Clear.UseW:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.WMana:Value() / 100)) then
		if(Ready(_Q) and Ready(_W)) then
			if(Wtarget ~= nil and IsValid(Wtarget) and #minions >= 2) then
				if(myHero:GetSpellData(_W).name == "SyndraW") and myHero.pos:DistanceTo(Wtarget.pos) < W.Range then
					Control.CastSpell(HK_W, Wtarget)
				end
			end
			
			if(myHero:GetSpellData(_W).name == "SyndraWCast") then
			
				for i = 1, #minions do		
					local minion = minions[i]
					if IsValid(minion) then
						if(myHero.pos:DistanceTo(minion.pos) < W.Range) then
							local clusterMinions = GetMinionsAroundMinion(W.Range, W.Radius, minion)
							if(#clusterMinions >= 1) then
								local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
								Control.CastSpell(HK_W, clusterMinionsAvgPos)
								if(self.Menu.Clear.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.QMana:Value() / 100)) then
									DelayAction(function()
										Control.CastSpell(HK_Q, clusterMinionsAvgPos)
										gameTick = GameTimer() + 0.2
									end, 0.25)
								end
								return
							end
						end
					end
				end
				
			end
		end
	end
	
	--Toss a minion away if its the last one, or just at the last minion
	if(self.Menu.Clear.UseW:Value()) then
		if(myHero:GetSpellData(_W).name == "SyndraWCast") then
			if(#minions == 0) then
				Control.CastSpell(HK_W, cursorPos)
			end
			
			if(#minions == 1) then
				for i = 1, #minions do		
					local minion = minions[i]
					if IsValid(minion) and myHero.pos:DistanceTo(minion.pos) < W.Range  then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
	
	-- When using Q to clear, we want to make sure it lines up with our W, so we check to see if it's up or not. If the user has set to not use W in clear mode, we ignore this logic.
	local WCheck = false
	if(self.Menu.Clear.UseW:Value() == false) then
		WCheck = true
	elseif(self.Menu.Clear.UseW:Value() == true) then
		if(not Ready(_W)) then
			WCheck = true
		else
			WCheck = false
		end
	end
	
	--Q Clusters of minions, Q minions that will die out of AA range, or Q minions if they are alone
	if(self.Menu.Clear.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.QMana:Value() / 100)) then
		if(Ready(_Q) and WCheck) then
			for i = 1, #minions do		
				local minion = minions[i]
				if IsValid(minion) then
					-- Q clusters
					if(myHero.pos:DistanceTo(minion.pos) < Q.Range) then
						local clusterMinions = GetMinionsAroundMinion(Q.Range, Q.Radius, minion)
						if(#clusterMinions >= 2) then
							local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
							Control.CastSpell(HK_Q, clusterMinionsAvgPos)
							gameTick = GameTimer() + 0.2
							return
						end
					end
					
					-- Q to kill out of range minions
					if(myHero.pos:DistanceTo(minion.pos) < Q.Range and myHero.pos:DistanceTo(minion.pos) > myHero.range) then
						local QDam = getdmg("Q", minion, myHero)
						local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
						if (hp > 0) and (hp + (minion.health*0.05) < QDam) or (minion.health + 15 < QDam) then
							Control.CastSpell(HK_Q, minion)
							gameTick = GameTimer() + 0.2
							return
						end	
					end
					
				end
			end
		end
	end
	
	-- Q alone minions
	if(self.Menu.Clear.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.QMana:Value() / 100)) then
		if(Ready(_Q) and #minions == 1) then
			for i = 1, #minions do		
				local minion = minions[i]
				if IsValid(minion) then
					if(myHero.pos:DistanceTo(minion.pos) < Q.Range) then
						local QDam = getdmg("Q", minion, myHero)
						local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
						local hpBuffer = 120
						
						if (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then --Try to hold off your Q so you can last hit canon's easier
							--If we can kill the canon, kill it.
							if(hp - QDam <= 0) then
								Control.CastSpell(HK_Q, minion)
								gameTick = GameTimer() + 0.2
								return
							end
							--Otherwise only Q it if the outcome health won't put the canon too low. We want to make sure we can last hit with Q
							if(minion.health - hp >= 50) then --Check if it's actively being attacked
								local hpCheck = minion.maxHealth * 0.5
								if(hp - QDam >= hpCheck) then
									Control.CastSpell(HK_Q, minion)
									gameTick = GameTimer() + 0.2
									return
								end
							end
						else --All other types of minions
							if (hp - QDam > hpBuffer) or (hp - QDam <= 0) then -- Prevent close calls
								Control.CastSpell(HK_Q, minion)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end
				end
			end
		end
	end
	
	--Q jungle minions
	if(self.Menu.Clear.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.QMana:Value() / 100)) then
		if(Ready(_Q)) then
			for i = 1, #minions do		
				local minion = minions[i]
				if IsValid(minion) and minion.team == TEAM_JUNGLE then
					if(myHero.pos:DistanceTo(minion.pos) < Q.Range) then
						Control.CastSpell(HK_Q, minion)
						gameTick = GameTimer() + 0.2
						return
					end
				end
			end
		end
	end
	
end

function Syndra:KillSteal()
	if(gameTick > GameTimer()) then return end
	
	
	--R
	if(self.Menu.KillSteal.UseR:Value()) then
		if(Ready(_R)) and not myHero.isChanneling then
			local enemies = GetEnemyHeroes(1200)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy.valid and IsValid(enemy)) then
						if(self:IsKillable(enemy) and (self:CantKill(enemy, true, true, false))==false) then
							if(#enemies == 1) then --We can KS on solo targets
								if(myHero.pos:DistanceTo(enemy.pos) < R.Range) then
									Control.CastSpell(HK_R, enemy)
									return
								end
							else --If the KS'able target is in a group, lets make sure he's not on an R blacklist
								
								if(self.Menu.KillSteal.RBlacklist[enemy.charName]) then
									if(self.Menu.KillSteal.RBlacklist[enemy.charName]:Value() == false) then
										if(myHero.pos:DistanceTo(enemy.pos) < R.Range) then
											Control.CastSpell(HK_R, enemy)
											return
										end
									end
								end
								
							end
						end
					end
				end
			end
		end
	end
	
end

function Syndra:EInterrupter()
	if(Ready(_E)) then
		local enemies = GetEnemyHeroes(E.Range)
		if(#enemies > 0) then
			for _, enemy in pairs (enemies) do
				if(enemy.valid and IsValid(enemy)) then

					--Interrupt them if they are channeling an interruptible spell
					local spell = enemy.activeSpell
					if(spell and spell.valid and self.InterruptableSpells[spell.name]) then
						if(self.Menu.EInterrupter.InterruptSpells[spell.name]) then
							if(self.Menu.EInterrupter.InterruptSpells[spell.name]:Value() == true) then
								DelayAction(function()
									Control.CastSpell(HK_E, enemy.pos)
								end, (self.Menu.EInterrupter.HumanizedDelay:Value() /1000))
							end
						end
					end
					
				end
			end
		end
	end
end

function Syndra:SemiManualStun()
	
	_G.SDK.Orbwalker:Orbwalk()
	
	if(gameTick > GameTimer()) then return end	

	--First check for existing orbs
	if(Ready(_E) and (myHero.mana / myHero.maxMana) >= 0.2) then
		local target = GetTarget(QE.Range) 
		if(target ~= nil and IsValid(target)) then

			for _, orb in pairs(self.OrbData) do
				if(myHero.pos:DistanceTo(orb.orbObj.pos) < E.Range and myHero.pos:DistanceTo(orb.orbObj.pos) >= 175) then --Don't try to E orbs we are directly on top of, massive accuracy issues
					local trueOrbPos = self:GetTrueOrbPos(orb.orbObj)
					local dirVec = (trueOrbPos - myHero.pos):Normalized() * QE.Range
					local finalVec = myHero.pos + dirVec
					
					--First check strafing/stutter dancing
					local isStrafing, avgPos = StrafePred:IsStrafing(target)
					local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
					if(isStrafing or isStutterDancing) then
						local finalPos = 0
						if(avgPos2 ~= nil) then 
							finalPos = avgPos2
						else
							finalPos = avgPos
						end
						local point, isOnSegment = ClosestPointOnLineSegment(finalPos, myHero.pos, finalVec)						
						if isOnSegment then
							local distCheck = GetDistance(finalPos, point)
							if distCheck < QE.Radius then
								Control.CastSpell(HK_E, finalPos)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end
					
					local QEPrediction = GGPrediction:SpellPrediction(QE)
					QEPrediction:GetPrediction(target, myHero)
					if QEPrediction:CanHit(2) then
						local finalPos = QEPrediction.CastPosition
						local point, isOnSegment = ClosestPointOnLineSegment(finalPos, myHero.pos, finalVec)						
						if isOnSegment then
							local distCheck = GetDistance(finalPos, point)
							if distCheck < QE.Radius then
								Control.CastSpell(HK_E, QEPrediction.CastPosition)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end
				end
			end
		end
	end
	
	--If Q and E are up, place a Q in our path so we can E follow up
	if(Ready(_Q) and Ready(_E) and (myHero.mana / myHero.maxMana) >= 0.2) then
		local target = GetTarget(QE.Range - 100)
		if(target and IsValid(target)) then
			--Start by predicting your own movement
			local myHeroQE = QE
			myHeroQE.Delay = 0.15
			local MePred = GGPrediction:SpellPrediction(myHeroQE)
			MePred:GetPrediction(myHero, myHero)
			if(MePred.CastPosition) then
				local myHeroCalcPos = Vector(MePred.CastPosition.x, myHero.pos.y, MePred.CastPosition.z)
				
				local QESpecial = QE
				QESpecial.Delay = 0.60 --Preorbs have a larger delay before they start moving, hacky fix
				local QEPrediction = GGPrediction:SpellPrediction(QESpecial)
				QEPrediction:GetPrediction(target, myHeroCalcPos)
				
				local isStrafing, avgPos = StrafePred:IsStrafing(target)
				local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
				if(isStrafing or isStutterDancing) then
					local finalPos = 0
					if(avgPos2 ~= nil) then 
						finalPos = avgPos2
					else
						finalPos = avgPos
					end
					if(myHeroCalcPos:DistanceTo(target.pos) >= myHero.range) then
						local Qvec = Vector(finalPos.x, myHero.pos.y, finalPos.z)
						local QDirVec = (Qvec - myHeroCalcPos):Normalized() * Q.Range /2
						finalPos = QDirVec + myHeroCalcPos
					end
					Control.CastSpell(HK_Q, finalPos)
					DelayAction(function()
						Control.CastSpell(HK_E, finalPos)
						return
					end, 0.15)
				end
				
				if QEPrediction.CastPosition then
					local finalPos = QEPrediction.CastPosition
					if(myHeroCalcPos:DistanceTo(target.pos) >= myHero.range) then
						local Qvec = Vector(QEPrediction.CastPosition.x, myHero.pos.y, QEPrediction.CastPosition.z)
						local QDirVec = (Qvec - myHeroCalcPos):Normalized() * Q.Range /2
						finalPos = QDirVec + myHeroCalcPos
					end
					Control.CastSpell(HK_Q, finalPos)
					DelayAction(function()
						Control.CastSpell(HK_E, finalPos)
						return
					end, 0.15)
				end
				
			end
		end
	end
	
end

function Syndra:SmartAABlock()
	local mode = GetMode()
	
	if(mode == "LaneClear") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Flee") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Harass") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "LastHit") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Combo") then
		if (myHero.mana / myHero.maxMana) >= 0.08 and self.Menu.Combo.SmartAABlock:Value() and (Ready(_Q) or Ready(_W)) then
			_G.SDK.Orbwalker:SetAttack(false)
		else
			_G.SDK.Orbwalker:SetAttack(true)
		end
	end
end

function Syndra:ManualSpells()
	--Quality of life addition so that we can still cast spells in orbwalker modes
	local mode = GetMode()
	local modeCheck = (mode == "Combo" or mode == "LaneClear" or mode == "Flee" or mode == "Harass" or mode == "LastHit")
	if(not modeCheck) then return end
	
	if(Control.IsKeyDown(HK_E)) then
		if(Ready(_E)) then
			Control.CastSpell(HK_E)
		end
	end
	
	if(Control.IsKeyDown(HK_Q)) then
		if(Ready(_Q)) then
			Control.CastSpell(HK_Q)
		end
	end
	
	if(Control.IsKeyDown(HK_W)) then
		if(Ready(_W)) then
			Control.CastSpell(HK_W)
		end
	end
	
	if(Control.IsKeyDown(HK_R)) then
		if(Ready(_R)) then
			Control.CastSpell(HK_R)
		end
	end
end

function Syndra:CantKill(unit, kill, ss, aa)
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

local dataTick = GameTimer()
function Syndra:UpdateComboDamage()

	if(dataTick > GameTimer()) then return end
	
	local enemies = GetEnemyHeroes(3000)
	if(#enemies > 0) then
		for _, enemy in pairs(enemies) do
			if(enemy and enemy.valid and IsValid(enemy)) then
				self.ComboDamageData[enemy.networkID] = self:GetTotalDamage(enemy)
			end
		end
		
		dataTick = GameTimer() + 0.25
	end
end

function Syndra:IsKillable(unit)
	local isKillable = false
	local igniteOverkill = false
	local igniteDmg = 50 + (20 * myHero.levelData.lvl)

	if(self.ComboDamageData[unit.networkID] ~= nil) then	
		local dmg = self.ComboDamageData[unit.networkID]
		if(self:HasRExecute() == true) then
			if(unit.health - dmg <= unit.maxHealth*0.15) then
				isKillable = true
			end
		end
		if(unit.health - dmg <= 0) then
			isKillable = true
		end
		
		if(unit.health - dmg <= 0) and (unit.health - (dmg - igniteDmg) <= 0) then
			if(CanUseSummoner(myHero, "SummonerDot")) then
				igniteOverkill = true
			end
		end
	end
	return isKillable, igniteOverkill
end

function Syndra:HasRExecute()
	for i = 0, myHero.buffCount do
		local buff = myHero:GetBuff(i)
		if(buff.name:lower() == ("syndrapassiverupgrade")) then
			return true
		end
	end
end

function Syndra:HasElectrocute(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count>0 and buff.name:lower():find("electrocute.lua") then
			return true
        end
    end
    return false
end

function Syndra:GetTotalDamage(unit)
	local totalDmg = 0
	local dmgBuffer = 80
	if(Ready(_R)) then
		totalDmg = totalDmg + getdmg("R", unit, myHero)
	end
	
	if self:HasElectrocute(myHero) then
		local baseDmg = 30+(150/(17*(myHero.levelData.lvl)))
		local bonusDmg = (myHero.ap * 0.25)+(myHero.bonusDamage*0.4)
		local value = baseDmg + bonusDmg 
		local ElecDmg=_G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL , value )
		totalDmg= totalDmg + ElecDmg
	end
	
	--6655 = Ludens
	local ludensCheck, ludensIsUp = CheckDmgItems(6655)
	if(ludensCheck and ludensIsUp) then
		local ludensDmg = 100 + (myHero.ap * 0.1)
		local ludensCalcDmg = CalcMagicalDamage(myHero, unit, ludensDmg)
		
		totalDmg = totalDmg + ludensCalcDmg
	end

	return totalDmg - dmgBuffer
end

function Syndra:GetTrueOrbPos(orb)
	return orb.pos + Vector(0, -50, 0)
end

function Syndra:Draw()
	if myHero.dead then return end
	
	if(self.Menu.Drawings.DrawKillableTargets:Value()) then
		self:DrawKillable()
	end
	
	if(self.Menu.Drawings.DrawQ:Value()) then
		DrawCircle(myHero, Q.Range, 1, DrawColor(50, 80, 215, 255)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Drawings.DrawW:Value()) then
		DrawCircle(myHero, W.Range, 1, DrawColor(50, 150, 65, 215)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Drawings.DrawQE:Value()) then
		DrawCircle(myHero, QE.Range, 1, DrawColor(40, 195, 85, 1155)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Drawings.DrawChampTracker:Value()) then
		-- Draw lines connecting to enemy champions
		for k, v in pairs(Enemies) do
			local distMax = 3000
			local distMin = W.Range
			if(v and IsValid(v) and myHero.pos.DistanceTo(v.pos) <= distMax and myHero.pos.DistanceTo(v.pos) > distMin) then
				local lineAlphaVal = ((myHero.pos.DistanceTo(v.pos) - distMin) / (distMax - distMin)) * 0.9
				DrawLine(myHero.pos:To2D(), v.pos:To2D(), 1, DrawColor(300 * lineAlphaVal, 255, 0, 0))
			end
		end
	end
	
	if(self.Menu.Drawings.Debug.DrawOrbs:Value()) then
		self:DrawOrbs()
	end
	
	if(self.Menu.Drawings.Debug.DrawELines:Value()) then
		self:DrawELines()
	end
	
	if(self.Menu.Drawings.Debug.DrawParticles:Value()) then
		local particleCount = Game.ParticleCount()
		for i = particleCount, 1, -1 do
			local obj = Game.Particle(i)
			if obj and obj.type == "obj_GeneralParticleEmitter" and obj.name:find("Syndra") and self:CheckExistingOrb(obj) == false then
				DrawText(obj.name, 18, obj.pos:To2D())
			end
		end
	end
end

function Syndra:DrawKillable()
	local enemies = GetEnemyHeroes(3000)
	if(#enemies > 0) then
		for _, enemy in pairs(enemies) do
			if(enemy.valid and IsValid(enemy)) then
				if(self:IsKillable(enemy)) then
					self:DrawKillReticle(enemy)
				end
			end
		end
	end
end

function Syndra:DrawKillReticle(unit)
	local reticleRadius = 75
	local speed = 135
	DrawCircle(unit, reticleRadius, 2, DrawColor(255, 255, 25, 25))
	local angle = ((GetTickCount() / 1000) % 360) * speed
	
	local vec1 = (Vector(math.cos(math.rad(angle)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle)) + unit.pos.z) - unit.pos):Normalized()
	local vec2 = (Vector(math.cos(math.rad(angle + 90)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 90)) + unit.pos.z) - unit.pos):Normalized()
	local vec3 = (Vector(math.cos(math.rad(angle + 180)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 180)) + unit.pos.z) - unit.pos):Normalized()
	local vec4 = (Vector(math.cos(math.rad(angle + 270)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 270)) + unit.pos.z) - unit.pos):Normalized()
	
	DrawLine((unit.pos + (vec1 * (reticleRadius - 20))):To2D(), (unit.pos + (vec1 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 25, 25))
	DrawLine((unit.pos + (vec2 * (reticleRadius - 20))):To2D(), (unit.pos + (vec2 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 25, 25))
	DrawLine((unit.pos + (vec3 * (reticleRadius - 20))):To2D(), (unit.pos + (vec3 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 25, 25))
	DrawLine((unit.pos + (vec4 * (reticleRadius - 20))):To2D(), (unit.pos + (vec4 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 25, 25))
end

function Syndra:DrawOrbs()

	for _, preorb in ipairs(self.PreOrbData) do
		local ratio = (preorb[2] - GameTimer()) / Q.Delay
		local inverse = (ratio - 1) * -1
		DrawCircle(preorb[1].pos, 200 * ratio, 1, DrawColor((195 * inverse) + 40, 225, 65, 225)) --(Alpha, R, G, B)
	end
	
	for _, orb in ipairs(self.OrbData) do
		local newPos = self:GetTrueOrbPos(orb.orbObj)
		DrawCircle(newPos, 150, 1, DrawColor(50, 150, 65, 215)) --(Alpha, R, G, B)
	end
end

function Syndra:DrawELines()
	for _, preorbs in pairs(self.PreOrbData) do
		local orb = preorbs[1]
		if(myHero.pos:DistanceTo(orb.pos) < E.Range) then
			local dirVec = (orb.pos - myHero.pos):Normalized() * QE.Range
			local finalVec = myHero.pos + dirVec
			DrawLine(orb.pos:To2D(), finalVec:To2D(), 1, DrawColor(140, 215, 25, 255))
		end
	end
	
	for _, orb in pairs(self.OrbData) do
		if(myHero.pos:DistanceTo(orb.orbObj.pos) < E.Range) then
			local newOrbsPos = self:GetTrueOrbPos(orb.orbObj)
			local dirVec = (newOrbsPos - myHero.pos):Normalized() * QE.Range
			local finalVec = myHero.pos + dirVec
			DrawLine(newOrbsPos:To2D(), finalVec:To2D(), 1, DrawColor(140, 215, 25, 255))
		end
	end
end

Callback.Add("Load", function()	
	if table.contains(Heroes, myHero.charName) then	
		_G[myHero.charName]()
		LoadUnits()
	end
end)
