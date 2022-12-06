local Heroes = {"Annie"}

if not table.contains(Heroes, myHero.charName) then return end

require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"

scriptVersion = 1.16

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Annie will exit.")
    return
end

----------------------------------------------------
--|                    Checks                    |--
----------------------------------------------------

--[[

if not FileExist(COMMON_PATH .. "GamsteronPrediction.lua") then
	DownloadFileAsync("https://raw.githubusercontent.com/gamsteron/GOS-EXT/master/Common/GamsteronPrediction.lua", COMMON_PATH .. "GamsteronPrediction.lua", function() end)
	print("gamsteronPred. installed Press 2x F6")
	return
end

if not FileExist(COMMON_PATH .. "GGPrediction.lua") then
	DownloadFileAsync("https://raw.githubusercontent.com/gamsteron/GG/master/GGPrediction.lua", COMMON_PATH .. "GGPrediction.lua", function() end)
	print("GGPrediction installed Press 2x F6")
	return
end
--]]

-- [ AutoUpdate ]
--[[ 
do
    
    local Version = scriptVersion
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "KillerAnnie.lua",
            Url = ""
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "KillerAnnie.version",
            Url = ""
        }
    }
    
    local function AutoUpdate()

        local function DownloadFile(url, path, fileName)
            DownloadFileAsync(url, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
        local textPos = myHero.pos:To2D()
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            print("New Killer Annie Version - Please reload with F6")
        else
            print("| KILLER | Annie Loaded! Enjoy :)")
        end
    
    end
    
   --AutoUpdate()

end
--]]

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
                return true
            end
        end
    end
    return false
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
	elseif target.charName == "Malzahar" and HasBuff(t, "malzaharpassiveshield") then
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


----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Annie"

local AnniePassiveStacksBuff = "anniepassivestack"
local AnniePassivePrimedBuff = "anniepassiveprimed"
local AnnieTibbersBuff = "AnnieRController"
local AnnieIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/1.png"

local COMBO_MODE_ALLIN = 1
local COMBO_MODE_SPAM = 2

local gameTick = GameTimer()
Annie.AutoLevelCheck = false

-- GG PRED
local Q = {Delay = 0.25, Range = 625}
local W = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.25, Radius = 200, Range = 600, Speed = math.huge, Collision = false}
local E = {Range = 800}
local R = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 600, Speed = math.huge, Collision = false}

local comboDamageData = {}

function Annie:__init()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Annie:LoadMenu()                     	
	--Main Menu
	self.Menu = MenuElement({type = MENU, id = "KillerAnnie", name = "Killer Annie", leftIcon = AnnieIcon})
	self.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})
	
	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	if(myHero:GetSpellData(SUMMONER_1).name == "SummonerDot") or (myHero:GetSpellData(SUMMONER_2).name == "SummonerDot") then
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "Ignite Loaded", type = SPACE})
	else
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "Ignite Not Loaded", type = SPACE})
	end
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
	self.Menu.Combo:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
	self.Menu.Combo:MenuElement({name = " ", drop = {"-----------------------------"}})	
	self.Menu.Combo:MenuElement({id = "AABlock", name = "Smart AA Block in Combo", value = true})
	self.Menu.Combo:MenuElement({id = "RSettings", name = "Ult Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "NinjaCombo", name = "Ninja Burst Combo", type = MENU})
	
	--Ult Settings
	self.Menu.Combo.RSettings:MenuElement({id = "RStunCheck", name = "Initiate R on killable target ONLY if it Stuns", value = true, tooltip = "Disable this if you want to initiate a combo with Tibbers without requiring your passive"})
	self.Menu.Combo.RSettings:MenuElement({id = "RAoEKillCheck", name = "Use R in Enemy Cluster if one is Killable", value = true, tooltip = "A cluster is two or enemies stacked within R's radius"})
	self.Menu.Combo.RSettings:MenuElement({id = "RAoECheckStun", name = "Min Enemies to Auto R with Stun", value = 2, min = 2, max = 5, step = 1})
	self.Menu.Combo.RSettings:MenuElement({id = "RAoECheck", name = "Min Enemies to Auto R without Stun", value = 4, min = 2, max = 5, step = 1})
	self.Menu.Combo.RSettings:MenuElement({id = "DontSoloUlt", name = "Don't Use Solo R on...", type = MENU})
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		self.Menu.Combo.RSettings.DontSoloUlt:MenuElement({id = args.charName, name = args.charName, value = false})
	end)
	
	--Ninja Combo
	self.Menu.Combo.NinjaCombo:MenuElement({id = "UseFlash", name = "Use Smart Flash", value = true})
	self.Menu.Combo.NinjaCombo:MenuElement({id = "RequireStun", name = "Require Stun to Ninja", value = true})
	self.Menu.Combo.NinjaCombo:MenuElement({id = "Key", name = "Semi-manual Key", key = string.byte("Z")})
	
	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
	self.Menu.Harass:MenuElement({id = "UseW", name = "Follow up W on Stunned Target", value = true})
	self.Menu.Harass:MenuElement({id = "LastHit", name = "Last Hit with Q until you have Passive", value = true})
	self.Menu.Harass:MenuElement({id = "HoldQ", name = "Only Q enemy if you have Passive", value = false})
	self.Menu.Harass:MenuElement({id = "QMana", name = "Q Min Mana", value = 15, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Harass:MenuElement({id = "WMana", name = "W Min Mana", value = 30, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseQ", name = "Use Q in Last Hit", value = true})
	self.Menu.LastHit:MenuElement({id = "HoldQ", name = "Hold Q if has Passive and if Champs Nearby", value = true})
	self.Menu.LastHit:MenuElement({id = "TowerFarm", name = "Last Hit under tower regardless of Passive", value = true})
	self.Menu.LastHit:MenuElement({id = "UseW", name = "Use W in if Q or AA cant kill", value = true})
	self.Menu.LastHit:MenuElement({id = "WMana", name = "W Last Hit Min Mana", value = 40, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Clear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
	self.Menu.Clear:MenuElement({id = "WMana", name = "W Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear:MenuElement({id = "EMana", name = "E Min Mana", value = 15, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear:MenuElement({id = "ClearType", name = "Clear Logic",  value = 1, drop = {"Smart", "Use Abilities on Cooldown"}})
	
	-- Auto E
	self.Menu:MenuElement({id = "AutoE", name = "Auto E", type = MENU})
	self.Menu.AutoE:MenuElement({id = "Self", name = "Use on Self", value = true})
	self.Menu.AutoE:MenuElement({id = "Allies", name = "Use on Allies", value = true})
	self.Menu.AutoE:MenuElement({id = "Humanizer", name = "Humanized Delay", value = true})
	self.Menu.AutoE:MenuElement({id = "EMana", name = "Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.AutoE:MenuElement({id = "Ignore", name = "Ignore Champion Abilities", type = MENU})
	
	self.Menu:MenuElement({id = "AutoStacks", name = "Auto Build Stacks in Base", value = true})
	
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		self.Menu.AutoE.Ignore:MenuElement({id = args.charName, name = args.charName, type = MENU})
		self.Menu.AutoE.Ignore[args.charName]:MenuElement({id = args.charName.. "Q", name = "Q", value = false})
		self.Menu.AutoE.Ignore[args.charName]:MenuElement({id = args.charName.. "W", name = "W", value = false})
		self.Menu.AutoE.Ignore[args.charName]:MenuElement({id = args.charName.. "E", name = "E", value = false})
		self.Menu.AutoE.Ignore[args.charName]:MenuElement({id = args.charName.. "R", name = "R", value = false})
	end)
	
	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.KillSteal:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.KillSteal:MenuElement({id = "UseR", name = "Use R if Q & W on CD", value = true, tooltip = "Goomba stomp"})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQW", name = "Draw Q & W Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawKillable", name = "Draw Killable Enemies", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawNinjaComboStatus", name = "Draw Ninja Combo Status", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawUltClusters", name = "Draw Ult Clusters", value = false})
	self.Menu.Drawings:MenuElement({id = "DrawChampTracker", name = "Draw Proximity Champion Tracker", value = false})
	
	self.Menu:MenuElement({id = "AutoLevel", name = "Auto Level Skills (Q - W - E)", value = false})
	
end

function Annie:Tick()
	if(MyHeroNotReady()) then return end
	
	self:AABlock()
	
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
	
	self:KillSteal()
	self:AutoE()
	self:ManualSpells()
	self:AutoStack()
	self:UpdateComboDamage()
	
	if(self.Menu.Combo.NinjaCombo.Key:Value()) then
		self:NinjaCombo()
	end
	
	if Game.IsOnTop() and self.Menu.AutoLevel:Value() then
		self:AutoLevel()
	end	
end

local dataTick = GameTimer()

function Annie:UpdateComboDamage()

	if(dataTick > GameTimer()) then return end
	
	local enemies = GetEnemyHeroes(3000)
	if(#enemies > 0) then
		for _, enemy in pairs(enemies) do
			if(enemy and enemy.valid and IsValid(enemy)) then
				comboDamageData[enemy.name] = self:GetTotalDamage(enemy)
			end
		end
		
		dataTick = GameTimer() + 0.5
	end
end

function Annie:HasTibbers()
    return myHero:GetSpellData(_R).name == AnnieTibbersBuff
end

function Annie:DebugCluster()
	local RBuffer = 30
	local target = GetTarget(R.Range + R.Radius + 3000)
	
	if(target and IsValid(target) and target ~= nil) then
		local searchrange = R.Range + R.Radius - RBuffer
		local canFlash = false
		if self.Menu.Combo.NinjaCombo.UseFlash:Value()  then--and self.Menu.Combo.NinjaCombo.Key:Value() then
			
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" and Ready(SUMMONER_1) then
				canFlash = true
				flashSlot = HK_SUMMONER_1
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" and Ready(SUMMONER_2) then
				canFlash = true
				flashSlot = HK_SUMMONER_2
			end
		end
		if canFlash == true then
			searchrange = R.Range + R.Radius +400 - RBuffer
		end
		local nearbyEnemies = GetEnemiesAtPos(searchrange, R.Radius*2 -RBuffer, target.pos, target)
		local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius - RBuffer, true)
		if(myHero.pos:DistanceTo(bestPos) < R.Range + RBuffer + 400 + R.Radius + 1000) then
			DrawCircle(bestPos, R.Radius -RBuffer, 1, DrawColor(85, 255, 255, 255)) --(Alpha, R, G, B)
		end

	end
end

function Annie:CalculateBestCirclePosition(targets, radius, edgeDetect)

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
			return self:CalculateBestCirclePosition(newCluster, radius)
		end
	end
	
	if(edgeDetect) and myHero.pos:DistanceTo(avgCastPos) > R.Range then

		local checkPos = myHero.pos:Extended(avgCastPos, R.Range)
		local furthestTarget = FindFurthestTargetFromMe(newCluster)
		local fakeMyHeroPos = avgCastPos:Extended(myHero.pos, R.Range + radius - 50)
		if(furthestTarget ~= nil) then
			fakeMyHeroPos = avgCastPos:Extended(myHero.pos, R.Range + radius - furthestTarget.pos:DistanceTo(avgCastPos))
		end

		if(myHero.pos:DistanceTo(avgCastPos) >= fakeMyHeroPos:DistanceTo(avgCastPos)) then
			checkPos = fakeMyHeroPos:Extended(avgCastPos, R.Range)
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

function Annie:AutoLevel()
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

function Annie:GetPassiveStacks()
	return GetBuffData(myHero, AnniePassiveStacksBuff).count
end

function Annie:HasStunBuff()
	return HasBuff(myHero, AnniePassivePrimedBuff)
end

function Annie:Combo()
	
	local currComboMode = nil
	local target = GetTarget(R.Range + R.Radius)
	
	if(target == nil or not target.valid or not IsValid(target)) then return end
	if(myHero.isChanneling) then return end
	
	local isKillable, igniteOverkillCheck = self:IsKillable(target)
	
	if(isKillable and IsImmobile(target) >= 0.5) and not igniteOverkillCheck then --A stunned killable target will be ignited
		UseIgnite(target)
	end
	
	if(isKillable and Ready(_Q) == false and Ready(_W) == false and Ready(_R) == false) then --A stunned killable target will be ignited
		UseIgnite(target)
	end
	
	--Ignore using R on champions that are isolated
	local ignoreChamp = false
	if(self.Menu.Combo.RSettings.DontSoloUlt[target.charName]:Value()) then
		local nearbyEnemies = GetEnemiesAtPos(R.Range + R.Radius, R.Radius*2, target.pos,target)
		local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius)
		if(count == 1) then
			ignoreChamp = true
		end
	end
	
	--Auto R Check
	if(Ready(_R) and self:HasTibbers() == false and self.Menu.Combo.UseR:Value() and ignoreChamp == false) then
		local RBuffer = 30
		
		if(target and IsValid(target) and target ~= nil) then
			local nearbyEnemies = GetEnemiesAtPos(R.Range + R.Radius -RBuffer, R.Radius*2 -RBuffer, target.pos, target)
			local bestPos, count, targets = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius, true)
			
			--Cluster AoE kill check
			if(self.Menu.Combo.RSettings.RAoEKillCheck:Value()) then
				if(count >= 2) then
					for _, target in pairs(targets) do
						if(self:IsKillable(target)) then
							if(self.Menu.Combo.RSettings.RStunCheck:Value() and self:IsHoldingPassiveMode()) then
								Control.CastSpell(HK_R, bestPos)
								return
							elseif(self.Menu.Combo.RSettings.RStunCheck:Value() == false) then
								Control.CastSpell(HK_R, bestPos)
								return
							end
						end
					end
				end
			end
			
			--Stun check
			if(count >= self.Menu.Combo.RSettings.RAoECheckStun:Value()) and self:IsHoldingPassiveMode() then
				if(self:GetPassiveStacks() == 3) then
					if(myHero.pos:DistanceTo(bestPos) < R.Range) then
						Control.CastSpell(HK_E)
						Control.CastSpell(HK_R, bestPos)
						return
					end
				else
					if(myHero.pos:DistanceTo(bestPos) < R.Range) then
						Control.CastSpell(HK_R, bestPos)
						return
					end
				end
			elseif(count >= self.Menu.Combo.RSettings.RAoECheck:Value()) then
				if(myHero.pos:DistanceTo(bestPos) < R.Range) then
					Control.CastSpell(HK_R, bestPos)
					return
				end	
			end
		end
	end
	
	-- Change how we combo based on our dynamic combo mode
	if(Ready(_Q) and Ready(_W) and Ready(_R) and self:HasTibbers() == false and self:IsKillable(target) and self.Menu.Combo.UseR:Value()) and (self:CantKill(target, true, true, false))==false then
		if(self.Menu.Combo.RSettings.RStunCheck:Value() and self:IsHoldingPassiveMode()) and ignoreChamp == false then
			currComboMode = COMBO_MODE_ALLIN
		elseif(self.Menu.Combo.RSettings.RStunCheck:Value() == false) and ignoreChamp == false then --If we have the setting to not require a stun then we can still all in
			currComboMode = COMBO_MODE_ALLIN
		else
			currComboMode = COMBO_MODE_SPAM
		end
	else
		currComboMode = COMBO_MODE_SPAM
	end
	
	--Q and W
	if(currComboMode == COMBO_MODE_SPAM) then
		
		if(self.Menu.Combo.UseQ:Value() and Ready(_Q) and myHero.pos:DistanceTo(target.pos) < Q.Range) then
			Control.CastSpell(HK_Q, target)
			return
		end
		
		if(self.Menu.Combo.UseW:Value() and Ready(_W) and myHero.pos:DistanceTo(target.pos) < W.Range) then
			Control.CastSpell(HK_W, target)
			return
		end
		
		--Use R in spam mode if it can kill / stun
		if(self.Menu.Combo.UseR:Value() and Ready(_R) and self:HasTibbers()==false and myHero.pos:DistanceTo(target.pos) < R.Range and ignoreChamp == false) then
			if(self:IsKillable(target)) and (self:CantKill(target, true, true, false))==false then
				Control.CastSpell(HK_R, target)
			end
		end	
		
	elseif(currComboMode == COMBO_MODE_ALLIN) then -- Engage with Tibbers and Ignite if we can full combo
		
		local RBuffer = 30
		local nearbyEnemies = GetEnemiesAtPos(R.Range + R.Radius -RBuffer, R.Radius*2 -RBuffer, target.pos, target)
		local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius)

		if(self:GetPassiveStacks() == 3) then
			if(myHero.pos:DistanceTo(target.pos) < R.Range) then
				Control.CastSpell(HK_E)
				Control.CastSpell(HK_R, bestPos)
			end
		else
			if(myHero.pos:DistanceTo(target.pos) < R.Range) then
				Control.CastSpell(HK_R, bestPos)
			end
		end
		
	end
	
end

function Annie:IsHoldingPassiveMode() -- Check to see if we meet our passive mode conditions; either you have your stun, or you have 3 stacks and an E
	local isHolding = false

	if self:HasStunBuff() or (self:GetPassiveStacks() >= 3 and Ready(_E)) then isHolding = true end
	
	return isHolding
end

function Annie:Harass()
	
	if(self.Menu.Harass.LastHit:Value() and Ready(_Q)) then
		if(gameTick > GameTimer()) then return end
		
		local shouldQLastHit = true
		
		if(self:HasStunBuff()) then
			shouldQLastHit = false
		else
			shouldQLastHit = true
		end
		
		if(shouldQLastHit) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) then
					local QDam = getdmg("Q", minion, myHero)
					
					if (minion.health + 5 < QDam) then
						Control.CastSpell(HK_Q, minion)
						gameTick = GameTimer() + 0.33
					end
				end
			end
		end
		
	end
	
	-- Q
	local target = GetTarget(Q.Range)
	if(target ~= nil and IsValid(target)) then
		
		if(Ready(_Q) and self.Menu.Harass.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then
			if(self.Menu.Harass.HoldQ:Value()) then
				if(self:GetPassiveStacks() == 3) and Ready(_E) then
					Control.CastSpell(HK_Q, target)
					Control.CastSpell(HK_E)
				elseif(self:HasStunBuff()) then
					Control.CastSpell(HK_Q, target)
				end
			else
				Control.CastSpell(HK_Q, target)
			end
		end
		
		if(Ready(_W) and self.Menu.Harass.UseW:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.WMana:Value() / 100)) then
			if(IsImmobile(target) >= 1.0) then
				Control.CastSpell(HK_W, target)
			end
		end	
	end
end

function Annie:LastHit()

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) -- Q range is the same as W range
	local canonMinion = GetCanonMinion(minions)
	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	if(Ready(_Q) and self.Menu.LastHit.UseQ:Value()) then
		
		--Passive mode check
		local shouldLastHit = true
		
		if(self.Menu.LastHit.HoldQ:Value()) then
		
			if(self:HasStunBuff()) then
				shouldLastHit = false
			end
	
			--If we are under tower, we can use our abilities
			if(self.Menu.LastHit.TowerFarm:Value()) then
				if(IsUnderFriendlyTurret(myHero)) then shouldLastHit = true end
				if(GetEnemyCount(2000, myHero) == 0) then shouldLastHit= true end
			end
		end
		
		--Prioritize the canon minion if its low
		if(canonMinion ~= nil) and IsValid(canonMinion) then
			local QDam = getdmg("Q", canonMinion, myHero)
			local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay+(myHero.pos:DistanceTo(canonMinion.pos)/1400))
			
			if ((hp > 0) and (hp + (canonMinion.health*0.05) < QDam) or (canonMinion.health + 5 < QDam)) and shouldLastHit then
				Control.CastSpell(HK_Q, canonMinion)
			end
		end
		
		for i = 1, #minions do
			local minion = minions[i]
			if IsValid(minion) then
				local QDam = getdmg("Q", minion, myHero)
				local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay+(myHero.pos:DistanceTo(minion.pos)/1400))
				
				if ((hp > 0) and (hp + (minion.health*0.05) < QDam) or (minion.health + 5 < QDam)) and shouldLastHit then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
	
	if(Ready(_Q)==false and Ready(_W) and self.Menu.LastHit.UseW:Value()) then
		if((myHero.mana / myHero.maxMana) >= (self.Menu.LastHit.WMana:Value() / 100)) then
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) then
					local WDam = getdmg("W", minion, myHero)
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, W.Delay)
					
					if (hp < 0) then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
	
end

function Annie:Clear()
	
	if(self.Menu.Clear.UseQ:Value() == false and self.Menu.Clear.UseW:Value() == false) then return end
	if(not Ready(_Q) and not Ready(_W)) then return end
	
	local SMART_CLEAR = 1
	local SPAM_CLEAR = 2
	local clearMode = self.Menu.Clear.ClearType:Value()
	
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) -- Q range is the same as W range
	local canonMinion = GetCanonMinion(minions)

	if(clearMode == SPAM_CLEAR) then
		if(Ready(_Q) and self.Menu.Clear.UseQ:Value()) then
			
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				Control.CastSpell(HK_Q, canonMinion)
			else
				for i = 1, #minions do
					local minion = minions[i]
					if IsValid(minion) then
						Control.CastSpell(HK_Q, minion)
					end
				end
			end
		end
		
		if(Ready(_W) and self.Menu.Clear.UseW:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.WMana:Value() / 100)) then
			
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				Control.CastSpell(HK_W, canonMinion)
			else
				for i = 1, #minions do
					local minion = minions[i]
					if IsValid(minion) then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
		
		return
	end
	
	if(clearMode == SMART_CLEAR) then

		if(Ready(_W) and self.Menu.Clear.UseW:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.WMana:Value() / 100)) then
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local WDam = getdmg("W", canonMinion, myHero)
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, W.Delay)
				
				if (hp > 0) and (hp + (canonMinion.health*0.08) < WDam) or (canonMinion.health + 10 < WDam) then
					Control.CastSpell(HK_W, canonMinion)
					return
				end
			end
			
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) then
					local WDam = getdmg("W", minion, myHero)
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, W.Delay)
					
					--Different logic for jungle minions
					if(minion.team == TEAM_JUNGLE) then
						local clusterJgMinions = GetMinionsAroundMinion(W.Range, 350, minion)
						local clusterJgPos = AverageClusterPosition(clusterJgMinions)
						if(clusterPos ~= nil) then
							Control.CastSpell(HK_W, clusterPos)
							return
						else
							Control.CastSpell(HK_W, minion)
							return
						end
					end
					
					if (hp > 0) and (hp + (minion.health*0.05) < WDam) or (minion.health + 5 < WDam) then
						if(myHero.pos:DistanceTo(minion.pos) > 75) then -- Dont try to point blank your W
							local clusterMinions = GetMinionsAroundMinion(W.Range, 350, minion)
							if(#clusterMinions >= 2) then
								Control.CastSpell(HK_W, minion)
								return
							end
						end
					else
						if(myHero.pos:DistanceTo(minion.pos) > 75) then -- Dont try to point blank your W
							local clusterMinions = GetMinionsAroundMinion(W.Range, 350, minion) --This will try to cast W on clusters of minions evenly
							if(#clusterMinions >= 3) then
								local clusterPos = AverageClusterPosition(clusterMinions)
								if(clusterPos ~= nil) then
									Control.CastSpell(HK_W, clusterPos)
									return
								else
									Control.CastSpell(HK_W, minion)
									return
								end
							end
						end
					end
					
				end
			end
		end
		
		if(Ready(_E) and self.Menu.Clear.UseE:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.EMana:Value() / 100)) then
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) then
					if(minion.team == TEAM_JUNGLE) then
						if(minion.attackData.target ~= 0) then
							if(minion.attackData.target == myHero.handle) then
								Control.CastSpell(HK_E)
							end
						end
					end
				end
			end
		end
		
		if(Ready(_Q) and self.Menu.Clear.UseQ:Value()) then
			local minionTarget = nil
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local QDam = getdmg("Q", canonMinion, myHero)
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay+(myHero.pos:DistanceTo(canonMinion.pos)/1400))
				
				if (hp > 0) and (hp + (canonMinion.health*0.05) < QDam) or (canonMinion.health + 5 < QDam) then
					Control.CastSpell(HK_Q, canonMinion)
					return
				end
			end
			
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) then
					local QDam = getdmg("Q", minion, myHero)
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay+(myHero.pos:DistanceTo(minion.pos)/1400))
					local AAdmg = _G.SDK.Damage:GetAutoAttackDamage(myHero, minion)
					if (hp > 0) and (hp + (minion.health*0.05) < QDam) or (minion.health + 5 < QDam) then
						minionTarget = minion
						break
					end
					
					if(hp - QDam >= AAdmg) and minion.team == 300 then
						minionTarget = minion
					end
				end
			end
			
			if(minionTarget ~= nil) then
				Control.CastSpell(HK_Q, minionTarget)
				return
			end
			
		end
		
	end
end

function Annie:KillSteal()
	if(gameTick > GameTimer()) then return end
	
	if(self.Menu.KillSteal.UseQ:Value() == false and self.Menu.KillSteal.UseW:Value() == false and self.Menu.KillSteal.UseR:Value() == false) then return end
	if(myHero.isChanneling) then return end
	local target = GetTarget(R.Range + R.Radius)
	if(target ~= nil and IsValid(target)) then
		
		--Q KS
		if(Ready(_Q) and self.Menu.KillSteal.UseQ:Value()) then
			if(myHero.pos:DistanceTo(target.pos) < Q.Range) then
				local QDam = getdmg("Q", target, myHero)
				if(QDam > target.health) then
					Control.CastSpell(HK_Q, target)
				end
			end
		end
		
		--W KS
		if(Ready(_W) and self.Menu.KillSteal.UseW:Value()) then
			if(myHero.pos:DistanceTo(target.pos) < W.Range) then
				local WDam = getdmg("W", target, myHero)
				if(WDam > target.health) then
					Control.CastSpell(HK_W, target)
				end
			end
		end
		
		local ignoreChamp = false
		if(self.Menu.Combo.RSettings.DontSoloUlt[target.charName] ~= nil) then
			if(self.Menu.Combo.RSettings.DontSoloUlt[target.charName]:Value()) then
				local nearbyEnemies = GetEnemiesAtPos(R.Range + R.Radius, R.Radius *2, target.pos,target)
				local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius)
				if(count == 1) then
					ignoreChamp = true
				end
			end
		end
		
		--R KS
		if(Ready(_R) and self:HasTibbers()== false and self.Menu.KillSteal.UseR:Value()) and ignoreChamp == false and (self:CantKill(target, true, true, false))==false then
			if (Ready(_Q) == false and Ready(_W) == false) then
				local RBuffer = 30
				local RDam = getdmg("R", target, myHero)
				if(target.health - RDam <= 0) and (myHero.pos:DistanceTo(target.pos) < R.Range + R.Radius - RBuffer) then
					if(myHero.pos:DistanceTo(target.pos) < R.Range) then
						local nearbyEnemies = GetEnemiesAtPos(R.Range + R.Radius -RBuffer, R.Radius*2 -RBuffer, target.pos,target)
						local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius)
						if(count >= 2) then
							Control.CastSpell(HK_R, bestPos)
						else
							Control.CastSpell(HK_R, target.pos)
						end
					else --If the target is killable but outside of our R Range, we can clip them at the edge of our R Radius
						Control.CastSpell(HK_R, target.pos:Extended(myHero.pos, R.Radius - RBuffer))
					end
				end
			end
		end
		
	end
end

function Annie:AutoE()
	local mana = (self.Menu.AutoE.EMana:Value() / 100)
	if self.Menu.AutoE.Self:Value() == false and self.Menu.AutoE.Allies:Value()==false then return end
	if not ((myHero.mana / myHero.maxMana) >= (self.Menu.AutoE.EMana:Value() / 100)) then return end
	if not Ready(_E) then return end
	
	local targets = GetEnemyHeroes(2500)
	local allies = _G.SDK.ObjectManager:GetAllyHeroes(E.Range)
	for _, unit in ipairs(targets) do
		local ePos = unit.pos
		local eSpell = unit.activeSpell
		if(eSpell and eSpell.valid and unit.isChanneling) then
			local delayAmnt = 0
			if(self.Menu.AutoE.Ignore[unit.charName][eSpell.name]) then
				if(self.Menu.AutoE.Ignore[unit.charName][eSpell.name]:Value()) then return end --If the enemy is casting a spell we have set to ignore, then don't shield
			end
			
			if(self.Menu.AutoE.Humanizer:Value()) then
				delayAmnt = assert(math.random(100, 300))
			end
			--Check on self
			if(self.Menu.AutoE.Self:Value()) then
				if(eSpell.target == myHero.handle) then
					DelayAction(function()
						Control.CastSpell(HK_E)					
					end, delayAmnt/1000)
					return
				end
				
                local CastPos = eSpell.startPos
                local PlacementPos = eSpell.placementPos
                local Width = 100
                if eSpell.width > 0 then
                    Width = eSpell.width
                end
				if(CastPos and PlacementPos) then
					local VCastPos = Vector(CastPos.x, CastPos.y, CastPos.z)
					local VPlacementPos = Vector(PlacementPos.x, PlacementPos.y, PlacementPos.z)
				    local CastDirection = Vector((VCastPos - VPlacementPos):Normalized())
                    local PlacementPos2 = VCastPos - CastDirection * eSpell.range
					
					local point, isOnSegment = ClosestPointOnLineSegment(myHero.pos, VPlacementPos, VCastPos)
					if isOnSegment then
						local distCheck = GetDistance(myHero.pos, point)
						if distCheck < Width*2 + myHero.boundingRadius then
							DelayAction(function()
								Control.CastSpell(HK_E)					
							end, delayAmnt/1000)
							return
						end
					end
				end
			end
			
			--Check on allies
			if(self.Menu.AutoE.Allies:Value()) then
				for _, ally in ipairs(allies) do
					if(eSpell.target == ally.handle) then
						DelayAction(function()
							Control.CastSpell(HK_E, ally)					
						end, delayAmnt/1000)
						return
					end
				end
			end
		end
	end
end

function Annie:ManualSpells()
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

function Annie:AutoStack()
	if not (self.Menu.AutoStacks:Value()) then return end
	if not (Game.IsOnTop()) then return end
	if(IsInFountain()) then
		local enemiesNearby = GetEnemyCount(3000, myHero)
		if(enemiesNearby == 0) then
			local shouldCast = true

			if(self:HasStunBuff()) then
				shouldCast = false
			end
			
			if(myHero.mana / myHero.maxMana) >= 0.5 then
				--Use W and E to auto set up passive
				if(Ready(_W) and shouldCast) then
					Control.CastSpell(HK_W)
					return
				end
				
				if(Ready(_E) and shouldCast) then
					Control.CastSpell(HK_E)
					return
				end
			end
		end
	end
end

function Annie:AABlock()
	local mode = GetMode()
	local level = myHero.levelData.lvl
	
	if(mode == "LaneClear") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Flee") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Harass") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "LastHit") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Combo") then
		if (myHero.mana / myHero.maxMana) >= 0.05 and self.Menu.Combo.AABlock:Value() and Ready(_Q) then
			_G.SDK.Orbwalker:SetAttack(false)
		else
			_G.SDK.Orbwalker:SetAttack(true)
		end
	end
	
end

function Annie:IsKillable(unit)
	local isKillable = false
	local igniteOverkill = false
	local igniteDmg = 50 + (20 * myHero.levelData.lvl)
	
	if(comboDamageData[unit.name] ~= nil) then	
		local dmg = comboDamageData[unit.name]
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

function Annie:HasElectrocute(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count>0 and buff.name:lower():find("electrocute.lua") then
			return true
        end
    end
    return false
end

function Annie:GetTotalDamage(unit)
	local totalDmg = 0
	
	if(Ready(_Q)) then
		totalDmg = totalDmg + getdmg("Q", unit, myHero)
	end
	
	if(Ready(_W)) then
		totalDmg = totalDmg + getdmg("W", unit, myHero)
	end
	
	if(Ready(_R) and not self:HasTibbers()) then
		totalDmg = totalDmg + getdmg("R", unit, myHero)
		
		local TibbersAA = ((myHero:GetSpellData(_R).level * 25) + 25) + 0.15 * myHero.ap
		local TibbersAOE = ((myHero:GetSpellData(_R).level * 20) + (0.12 * myHero.ap))
		local TibbersAAdmg = CalcMagicalDamage(myHero, unit, TibbersAA)
		local TibbersAOEdmg = CalcMagicalDamage(myHero, unit, TibbersAOE)
	end
	
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
		local igniteDmg = 50 + (20 * myHero.levelData.lvl)
		totalDmg = totalDmg + igniteDmg
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
		local igniteDmg = 50 + (20 * myHero.levelData.lvl)
		totalDmg = totalDmg + igniteDmg
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
	
	local AAdmg = getdmg("AA", unit, myHero)
	
	totalDmg = totalDmg + AAdmg
	
	return totalDmg
end

function Annie:NinjaCombo()
	_G.SDK.Orbwalker:Orbwalk()
	local flashRange = 400
	local shouldNinja = false
	
	local flashSlot = nil
	local canFlash = false
	
	--Flash Check
	if(self.Menu.Combo.NinjaCombo.UseFlash:Value()) then
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" and Ready(SUMMONER_1) then
			canFlash = true
			flashSlot = HK_SUMMONER_1
		elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" and Ready(SUMMONER_2) then
			canFlash = true
			flashSlot = HK_SUMMONER_2
		end
	end
	
	if(Ready(_R) and self:HasTibbers() == false and Ready(_Q) and Ready(_W)) then
		if(self.Menu.Combo.NinjaCombo.RequireStun:Value()) then
			if self:HasStunBuff() or (self:GetPassiveStacks() >= 3 and Ready(_E)) then
				shouldNinja = true
			end
		else
			shouldNinja = true
		end
	end
	
	local target = GetTarget(R.Range + flashRange + R.Radius + 1000)
	if(target and target.valid and IsValid(target)) then
	
		if(shouldNinja) then
			local RBuffer = 30
			local searchrange=(R.Range + R.Radius -RBuffer)
			if canFlash then
				searchrange=(R.Range + R.Radius +flashRange - RBuffer)
			end		

			local nearbyEnemies = GetEnemiesAtPos(searchrange, R.Radius*2 -RBuffer, target.pos,target)
			local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius-RBuffer, true)

			if(flashSlot ~= nil and canFlash) then
				if(myHero.pos:DistanceTo(bestPos) < R.Range + flashRange -50) and (myHero.pos:DistanceTo(target.pos) > R.Range) then
					
					_G.SDK.Orbwalker:SetMovement(false)
					_G.Control.CastSpell(HK_E)
					_G.Control.CastSpell(HK_R, bestPos)
					_G.Control.CastSpell(flashSlot)
					_G.SDK.Orbwalker:SetMovement(true)
				end
			end
		
			if self:GetPassiveStacks() == 3 and Ready(_E) then
				Control.CastSpell(HK_E)
			end
			
			
			if(myHero.pos:DistanceTo(bestPos) < R.Range - RBuffer) and Ready(_R) then
				Control.CastSpell(HK_R, bestPos)
			end
			
		end
		
		if(self:HasTibbers()) then
			if(myHero.pos:DistanceTo(target.pos) < 600) then --Ignite range
				UseIgnite(target)
			end
			
			if(self.Menu.Combo.UseW:Value() and Ready(_W) and myHero.pos:DistanceTo(target.pos) < W.Range) then
				Control.CastSpell(HK_W, target)
			end
			
			if(self.Menu.Combo.UseQ:Value() and Ready(_Q) and myHero.pos:DistanceTo(target.pos) < Q.Range) then
				Control.CastSpell(HK_Q, target)
			end
		end
		
	end
	
	
end

function Annie:CantKill(unit, kill, ss, aa)
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

function Annie:Draw()
	if myHero.dead then return end
	
	if(self.Menu.Drawings.DrawUltClusters:Value()) then
		self:DebugCluster()
	end
	
	if(self.Menu.Drawings.DrawQW:Value()) then
		DrawCircle(myHero, Q.Range, 1, DrawColor(50, 80, 215, 255)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Combo.NinjaCombo.Key:Value() and self.Menu.Drawings.DrawNinjaComboStatus:Value()) then
		if(self:HasTibbers()) then return end
		DrawCircle(myHero, R.Range + R.Radius + 400, 1, DrawColor(20, 255, 255, 255)) --(Alpha, R, G, B)
		local heroPos = myHero.pos:To2D()
		
		if Ready(_R) and self:HasTibbers() == false and Ready(_Q) and Ready(_W) then
			if (self.Menu.Combo.NinjaCombo.RequireStun:Value()) then 
				if(self:HasStunBuff() or (self:GetPassiveStacks() ==3 and Ready(_E))) then
					DrawText("Ninja: [READY]", 18, heroPos + Vector(-35, 50, 0), DrawColor(255, 55, 250, 110))
				else
					DrawText("Ninja: [NOT READY]", 18, heroPos + Vector(-55, 50, 0), DrawColor(255, 255, 100, 120))
				end
			else
				DrawText("Ninja: [READY]", 18, heroPos + Vector(-35, 50, 0), DrawColor(255, 55, 250, 110))
			end
		else
			DrawText("Ninja: [NOT READY]", 18, heroPos + Vector(-55, 50, 0), DrawColor(255, 255, 100, 120))
		end
	end
	
	if(self.Menu.Drawings.DrawChampTracker:Value()) then
		-- Draw lines connecting to enemy champions
		for k, v in pairs(Enemies) do
			local distMax = 3000
			local distMin = R.Range
			if(v and IsValid(v) and myHero.pos.DistanceTo(v.pos) <= distMax and myHero.pos.DistanceTo(v.pos) > distMin) then
				local lineAlphaVal = ((myHero.pos.DistanceTo(v.pos) - distMin) / (distMax - distMin)) * 0.9
				DrawLine(myHero.pos:To2D(), v.pos:To2D(), 1, DrawColor(300 * lineAlphaVal, 255, 0, 0))
			end
		end
	end
	
	if(self.Menu.Drawings.DrawKillable:Value()) then
		local enemies = GetEnemyHeroes(2000)
		if(enemies ~= nil) then
			for _, enemy in pairs(enemies) do
				if(enemy and enemy.valid and IsValid(enemy)) then
					if(self:IsKillable(enemy)) then
						DrawCircle(enemy, 100, 10, DrawColor(180, 255, 0, 155)) --(Alpha, R, G, B)
					end
				end
			end
		end
	end
end
	
Callback.Add("Load", function()	
	if table.contains(Heroes, myHero.charName) then	
		_G[myHero.charName]()
		LoadUnits()
	end
end)
