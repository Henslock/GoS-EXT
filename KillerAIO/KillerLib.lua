require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"

local kLibVersion = 2.14

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
	return sqrt(GetDistanceSqr(pos1, pos2))
end

function GetDistance2D(pos1, pos2)
	local pos2 = pos2 or myHero.pos
	local dx = pos1.x - pos2.x
	local dy = pos1.y - pos2.y
	return sqrt(dx * dx + dy * dy)
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
		local extrarange = bbox and unit.boundingRadius or 0
		if unit.distance < range + extrarange then
			table.insert(result, unit)
		end
	end
	return result
end

function GetAllyHeroes(range, bbox)
	local result = {}
	for _, unit in ipairs(Allies) do
		local extrarange = bbox and unit.boundingRadius or 0
		if unit.distance < range + extrarange then
			table.insert(result, unit)
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
            if BuffType == 5 or BuffType == 12 or BuffType == 22 or BuffType == 35 or BuffType == 25 or BuffType == 29 then
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
		
		if target then
			table.insert(results, target)
		end
    end
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
        local dot = (a.x * b.x + a.z * b.z)
        return dot
end

-- 3D dot product of two normalized vectors
function dotProduct3D( a, b )
        -- multiply the x's, multiply the y's, then add
        local dot = (a.x * b.x + a.y * b.y + a.z * b.z)
        return dot
end

function CalculateBoundingBoxAvg(targets, predDelay)
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

function UseIgnite(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2, unit)
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

function CalculateBestCirclePosition(targets, radius, edgeDetect, spellRange)

	local avgCastPos = CalculateBoundingBoxAvg(targets, 0.25)
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
			if(v:GetPrediction(math.huge, 0.25):DistanceTo(checkPos) >= radius + 5) then -- the +5 is to fix a precision issue
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
		if(dotProduct(meVec, pathVec) <= -0.5) then
			return RUNNING_AWAY
		else
			return RUNNING_TOWARDS
		end
	end
	return nil
end
