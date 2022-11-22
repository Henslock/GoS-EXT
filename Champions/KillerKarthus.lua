local Heroes = {"Karthus"}

if not table.contains(Heroes, myHero.charName) then return end

require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"

scriptVersion = 1.03

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Karthus will exit.")
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

if not FileExist(COMMON_PATH .. "PremiumPrediction.lua") then
	DownloadFileAsync("https://raw.githubusercontent.com/Ark223/GoS-Scripts/master/PremiumPrediction.lua", COMMON_PATH .. "PremiumPrediction.lua", function() end)
	print("PremiumPred. installed Press 2x F6")
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
            Name = "KillerKarthus.lua",
            Url = ""
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "KillerKarthus.version",
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
            print("New Killer Karthus Version - Please reload with F6")
        else
            print("| KILLER | Karthus Loaded! Enjoy :)")
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
    return {x = ax + t * bxax, z = az + t * bzaz}, true
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

local function MyHeroNotReady()
    return myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or IsRecalling(myHero)
end

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Karthus"

local PassiveBuff = "KarthusDeathDefiedBuff"
local KarthusIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/30.png"
local KarthusQIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/KarthusQ.png"
local KarthusWIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/KarthusW.png"
local KarthusEIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/KarthusE.png"
local KarthusRIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/KarthusR.png"

local UltableChamps = {}
local MIATimer = 5

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1, Radius = 160, Range = 875, Speed = math.huge, Collision = false}
local W = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.3, Radius = 75, Range = 1000, Speed = math.huge, Collision = false}
local E = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 550, Range = 0, Speed = math.huge, Collision = false}

-- PREMIUM PRED
local QPremium = {speed = MathHuge, range = 875, delay = 1, radius = 160, collision = {nil}, type = "circular"}
local WPremium = {speed = MathHuge, range = 1000, delay = 0.3, radius = 75, collision = {nil}, type = "circular"}
local EPremium= {speed = MathHuge, range = 0, delay =0, radius = 550, collision = {nil}, type = "circular"}

Karthus.Window = { x = Game.Resolution().x * 0.5 + 200, y = Game.Resolution().y * 0.5 }
Karthus.AllowMove = nil

function Karthus:__init()
	self:LoadMenu()
	self:LoadUltTrackerData()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end


function Karthus:LoadUltTrackerData()
	
	DelayAction(function()
	
	for k, v in pairs (Enemies) do
		UltableChamps[v.name] = {champ = v.charName, ultdmg = 0, timelastspotted = 0, killable = false, mia = false}
	end
	print("KILLER Karthus: Loaded Ult Tracker Data")
	end, 
	4)
	
end

function Karthus:LoadMenu()                     	
	--Main Menu
	self.Menu = MenuElement({type = MENU, id = "KillerKarthus", name = "Killer Karthus", leftIcon = KarthusIcon})
	self.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})
	
	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
	self.Menu.Combo:MenuElement({name = " ", drop = {"-----------------------------"}})	
	self.Menu.Combo:MenuElement({id = "SemiW", name = "Semi Manual W Key", key = string.byte("Z")})
	self.Menu.Combo:MenuElement({id = "EMana", name = "Disable E Below Mana", value = 30, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Combo:MenuElement({id = "WLogicSettings", name = "W Logic Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "DisableAALevel", name = "Disable AA After Level", value = 9, min = 1, max = 18, step = 1})
	
	-- W Combo Logic
	self.Menu.Combo.WLogicSettings:MenuElement({id = "WImmobile", name = "Auto Use W on Immobile", value = true})
	self.Menu.Combo.WLogicSettings:MenuElement({id = "WStandingStill", name = "Auto Use W on Standing Still Champs", value = false})
	self.Menu.Combo.WLogicSettings:MenuElement({id = "WMeleePeel", name = "Auto Use W for Melee Peel", value = true})
	self.Menu.Combo.WLogicSettings:MenuElement({id = "WHealth", name = "Use W When HP is Below % in Combo", value = 65, min = 1, max = 100, step = 1, identifier = "%"})
	
	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
	self.Menu.Harass:MenuElement({id = "QMana", name = "Q Min Mana", value = 30, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseQ", name = "Use Q in Last Hit", value = true})
	self.Menu.LastHit:MenuElement({id = "UseAA", name = "Prioritize AA over Q if in Melee Range", value = false})
	self.Menu.LastHit:MenuElement({id = "DisableAALevel", name = "Disable Last Hit AA After Level", value = 8, min = 1, max = 18, step = 1})
	self.Menu.LastHit:MenuElement({id = "QMana", name = "Q Min Mana", value = 10, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Clear:MenuElement({name = " ", drop = {"-----------------------------"}})
	self.Menu.Clear:MenuElement({id = "AABlock", name = "Disable AA in Clear Mode", value = true})
	self.Menu.Clear:MenuElement({id = "PrioCanon", name = "Prioritize Canon Minion", value = true})
	self.Menu.Clear:MenuElement({id = "QMana", name = "Q Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear:MenuElement({id = "EMana", name = "E Min Mana", value = 30, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear:MenuElement({id = "EHitCount", name = "E Min Hitcount", value = 3, min = 1, max = 7, step = 1})
	
	-- Auto R
	self.Menu:MenuElement({id = "AutoR", name = "Auto R Settings", type = MENU})
	self.Menu.AutoR:MenuElement({id = "AutoRDead", name = "Cast While Zombie If It Kills", value = false})
	self.Menu.AutoR:MenuElement({id = "AutoRAlive", name = "Cast In Safe Position If It Kills", value = false})
	
	-- Auto Q
	self.Menu:MenuElement({id = "AutoQ", name = "Auto Q Settings", type = MENU})
	self.Menu.AutoQ:MenuElement({id = "AutoQ", name = "Auto Q on very high hit chance", value = true})
	self.Menu.AutoQ:MenuElement({id = "AutoQMana", name = "Auto Q min mana", value = 30, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.AutoQ:MenuElement({id = "AutoQHPCheck", name = "Disable if HP below", value = 40, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Prediction
	self.Menu:MenuElement({id = "Prediction", name = "Prediction", type = MENU})
	self.Menu.Prediction:MenuElement({id = "QHitChance", name = "Q Hit Chance",  value = 1, drop = {"Normal", "High", "Immobile"}})
	self.Menu.Prediction:MenuElement({id = "WHitChance", name = "W Hit Chance",  value = 1, drop = {"Normal", "High", "Immobile"}})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawW", name = "Draw W", value = false})
	self.Menu.Drawings:MenuElement({id = "DrawHealthTracker", name = "Draw Health Tracker", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawChampTracker", name = "Draw Proximity Champion Tracker", value = false})
	
	self.Menu:MenuElement({id = "AutoLevel", name = "Auto Level Skills (Q - E - W)", value = false})
	
end

function Karthus:Tick()
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
	
	self:AABlock()
	self:AutoRCheck()
	self:AutoWCheck()
	self:AutoQCheck()
	
	if(self.Menu.Combo.SemiW:Value()) then
		self:SemiManualW()
	end
	
	if Game.IsOnTop() and self.Menu.AutoLevel:Value() then
		self:AutoLevel()
	end	
end

Karthus.AutoLevelCheck = false
function Karthus:AutoLevel()
	if self.AutoLevelCheck then return end
	
	local level = myHero.levelData.lvl
	local levelPoints = myHero.levelData.lvlPts

	if (levelPoints == 0) or (level == 1) then return end	
	--Order = Q > E > W
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
					Control.KeyDown(HK_E)
					Control.KeyUp(HK_E)
					Control.KeyUp(HK_LUS)
				elseif level == 3 or level == 14 or level == 15 or level == 17 or level == 18 then				
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_W)
					Control.KeyUp(HK_W)
					Control.KeyUp(HK_LUS)
				end
		
			self.AutoLevelCheck = false
		end, 0.5)
	end
end

local gameTick = GameTimer()

function Karthus:CanQ()
	return myHero:GetSpellData(_Q).ammo == 2
end

function Karthus:Combo()
	
	if(gameTick > GameTimer()) then return end --This is to prevent the mouse from spasming out
	
	-- Q
	local target = GetTarget(Q.Range + 50) --Extend out of the Q range a little bit
	if(target ~= nil and IsValid(target)) then
		if(self:CanQ() and self.Menu.Combo.UseQ:Value()) then
			local QPrediction = GGPrediction:SpellPrediction(Q)
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(self.Menu.Prediction.QHitChance:Value()) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
				gameTick = GameTimer() + 0.2
			end
		end
	end
	
	--W
	local target = GetTarget(W.Range)
	if(target ~= nil and IsValid(target)) then
	
		local hpRatio = (target.health / target.maxHealth)
		local hpCheck = self.Menu.Combo.WLogicSettings.WHealth:Value()
		
		if(Ready(_W) and self.Menu.Combo.UseW:Value() and (hpRatio <= (hpCheck/100)) ) then
			local WPrediction = GGPrediction:SpellPrediction(W)
			WPrediction:GetPrediction(target, myHero)
			if WPrediction.CastPosition and WPrediction:CanHit(self.Menu.Prediction.WHitChance:Value()) then
				Control.CastSpell(HK_W, WPrediction.CastPosition)
			end
			
			if(myHero.pos:DistanceTo(target.pos) < 800) then
				local castPos = target.pos:Extended(myHero.pos, -150)
				Control.CastSpell(HK_W, castPos)
			end
			
			if(IsImmobile(target) >= 0.5) then
				Control.CastSpell(HK_W, target.pos)
			end

		end
	end
	
	-- E
	if(Ready(_E) and self.Menu.Combo.UseE:Value()) then
		if((myHero.mana / myHero.maxMana) >= (self.Menu.Combo.EMana:Value() / 100) ) then
			if(GetEnemyCount(E.Radius, myHero) > 0) and not HasBuff(myHero, "KarthusDefile") then
				Control.CastSpell(HK_E)
			end
		end
	end
		
	
	-- Disable your E if there are no enemies nearby
	local EDisableBuffer = 100
	if HasBuff(myHero, "KarthusDefile") and (GetEnemyCount(E.Radius + EDisableBuffer, myHero) == 0) then 
		Control.CastSpell(HK_E)
		return
	end
end

function Karthus:Harass()
	
	if(gameTick > GameTimer()) then return end --This is to prevent the mouse from spasming out
	
	-- Q
	local target = GetTarget(Q.Range + 25) --Extend out of the Q range a little bit
	if(target ~= nil and IsValid(target)) then
		if(self:CanQ() and self.Menu.Harass.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then
			local QPrediction = GGPrediction:SpellPrediction(Q)
			QPrediction:GetPrediction(target, myHero)
			if QPrediction.CastPosition and QPrediction:CanHit(self.Menu.Prediction.QHitChance:Value()) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
				gameTick = GameTimer() + 0.2
			end
		end
	end
	
end

function Karthus:LastHit()
	if(gameTick > GameTimer()) then return end --This is to prevent the mouse from spasming out
	
	if(self:CanQ() and self.Menu.LastHit.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.LastHit.QMana:Value() / 100)) then
	    local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
		for i = 1, #minions do
			local minion = minions[i]
			local ShouldAA = false
			local ShouldAngleQ = false
			if IsValid(minion) then
			
				if(self.Menu.LastHit.UseAA:Value() and myHero.levelData.lvl < self.Menu.LastHit.DisableAALevel:Value() and myHero.pos:DistanceTo(minion.pos) < myHero.range) and not IsUnderFriendlyTurret(myHero) then
					--If the minion is in AA range and we have the setting enabled, skip it!
					if not (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then
						ShouldAA = true
					end
				end
				
				local prediction = _G.PremiumPrediction:GetPrediction(myHero, minion, QPremium)
				if prediction.CastPos and prediction.HitChance >= 0.25 and ShouldAA == false then
					local QDam = getdmg("Q", minion, myHero, 2, myHero:GetSpellData(_Q).level)
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
					
					local clusterMinions = GetMinionsAroundMinion((Q.Range + Q.Radius + 25), Q.Radius + 20, minion)
					if(#clusterMinions == 1) then
						ShouldAngleQ = true
					end
					
					if(GetMinionCount(Q.Range + Q.Radius, Q.Radius + 25, minion.pos) == 1) or ShouldAngleQ and (GetEnemyCountAtPos(Q.Range + Q.Radius, Q.Radius + 200, minion.pos) == 0) then
						QDam = QDam * 1.75 -- Your Q does double damage, but were giving ourselves a buffer window to make sure the minion is properly executed
					end
					
					if (hp + (minion.health*0.1) < QDam) or (minion.health + 10 < QDam) then
						if(ShouldAngleQ) then
							local angledPos = self:AngleQPos(minion, clusterMinions[1], Q.Radius + 20)
							Control.CastSpell(HK_Q, angledPos)
							gameTick = GameTimer() + 0.1
							return
						else
							Control.CastSpell(HK_Q, prediction.CastPos)
							gameTick = GameTimer() + 0.1
							return
						end
					end
					
				end
			end
		end
	end
	
end

function Karthus:AngleQPos(minion1, minion2, radius)
	local dist = math.abs(math.sqrt(math.pow(minion1.pos.x - minion2.pos.x, 2) + math.pow(minion1.pos.y - minion2.pos.y, 2)))
	local offset = dist - radius
	local newPos = minion1.pos:Extended(minion2.pos, offset - 8)
	--DrawLine(minion1.pos:To2D(), minion2.pos:To2D(), 10, DrawColor(255, 255, 255, 255))
	--DrawCircle(newPos, radius, 4, DrawColor(255, 255, 255, 255)) --(Alpha, R, G, B)
	
	return newPos
end

function Karthus:Clear()
	
	if(gameTick > GameTimer()) then return end --This is to prevent the mouse from spasming out

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range + 25)
	local canonMinion = nil
	
	if(self.Menu.Clear.PrioCanon:Value()) then
		for i = 1, #minions do
			local minion = minions[i]
			if(IsValid(minion)) then
				if (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then
					canonMinion = minion
				end
			end
		end
	end
	
	for i = 1, #minions do
		local minion = minions[i]
		
		if(canonMinion ~= nil) then minion = canonMinion end -- Prioritize Canon
		if(IsValid(minion)) then
			
			local QManaCheck =  (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.QMana:Value() / 100)
			local EManaCheck =  (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.EMana:Value() / 100)
			
			-- Q
			if(self:CanQ() and self.Menu.Clear.UseQ:Value() and QManaCheck) then
				local prediction = _G.PremiumPrediction:GetPrediction(myHero, minion, QPremium)
				if prediction.CastPos and prediction.HitChance >= 0.15 then
					Control.CastSpell(HK_Q, prediction.CastPos)
					gameTick = GameTimer() + 0.25
				end
			end
			
			-- E
			if(Ready(_E) and self.Menu.Clear.UseE:Value() and EManaCheck) then
				local minionCount = GetMinionCount(E.Radius, E.Radius,  myHero.pos)
				local ECheck = HasBuff(myHero, "KarthusDefile")
				
				if(minionCount >= self.Menu.Clear.EHitCount:Value()) and not ECheck then
					Control.CastSpell(HK_E)
					gameTick = GameTimer() + 0.25
				end
				
				if(minionCount == 0) and ECheck then --Disable E if there are no minions around
					Control.CastSpell(HK_E)
					gameTick = GameTimer() + 0.25
				end
			end
			
		end
	end
	
	-- Disable your E if there are no minions nearby
	local EDisableBuffer = 50
	if HasBuff(myHero, "KarthusDefile") and (GetMinionCount(E.Radius + EDisableBuffer, E.Radius, myHero.pos) == 0) then 
		Control.CastSpell(HK_E)
		return
	end

end

function Karthus:AABlock()
	local mode = GetMode()
	local level = myHero.levelData.lvl
	local modeCheck = (mode == "Combo" or mode == "LaneClear" or mode == "Flee" or mode == "Harass" or mode == "LastHit")
	if(not modeCheck) then _G.SDK.Orbwalker:SetAttack(true) return end
	
	if(level >= self.Menu.Combo.DisableAALevel:Value()) then
		if(mode == "Combo") and (myHero.mana / myHero.maxMana) >= 0.05 then
			_G.SDK.Orbwalker:SetAttack(false)
		end
	end
	
	if(level >= self.Menu.LastHit.DisableAALevel:Value()) then
		if(mode == "LastHit") and (myHero.mana / myHero.maxMana) >= 0.05 then
			_G.SDK.Orbwalker:SetAttack(false)
		end
	end
	
	local QManaCheck =  (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.QMana:Value() / 100)
	local EManaCheck =  (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.EMana:Value() / 100)
	if(self.Menu.Clear.AABlock:Value() and (QManaCheck or EManaCheck)) then --If the setting is enabled and we have enough mana for Q OR E
		if(mode == "LaneClear") then
			_G.SDK.Orbwalker:SetAttack(false)
		end
	end
end

function Karthus:AutoRCheck()
	-- Zombie check
	if (self.Menu.AutoR.AutoRDead:Value() and HasBuff(myHero, PassiveBuff) and Ready(_R)) then
		for k, v in pairs(UltableChamps) do
			if(v.killable) then
				Control.CastSpell(HK_R)
				break
			end
		end
	end
	
	--Alive check
	local enemiesNearby = GetEnemyCount(1200, myHero)
	if (self.Menu.AutoR.AutoRAlive:Value() and Ready(_R) and enemiesNearby == 0 and not IsUnderTurret(myHero)) then
		for k, v in pairs(UltableChamps) do
			if(v.killable) then
				Control.CastSpell(HK_R)
				break
			end
		end
	end
	
end

function Karthus:AutoWCheck()
	--W
	local target = GetTarget(W.Range)
	if(target ~= nil and IsValid(target)) then
		if(Ready(_W) and self.Menu.Combo.UseW:Value()) then
		
			if(self.Menu.Combo.WLogicSettings.WImmobile:Value()) then
				if(IsImmobile(target) >= 0.5) then
					Control.CastSpell(HK_W, target.pos)
				end
			end
			
			if(self.Menu.Combo.WLogicSettings.WStandingStill:Value()) then
				local WPrediction = GGPrediction:SpellPrediction(W)
				WPrediction:GetPrediction(target, myHero)
				if WPrediction.CastPosition and WPrediction:CanHit(4) then
					Control.CastSpell(HK_W, WPrediction.CastPosition)
				end
			end
			
		end
	end
	
	local meleeTarget = GetTarget(350)
	if(meleeTarget ~= nil and IsValid(meleeTarget)) then
		if(Ready(_W) and self.Menu.Combo.UseW:Value() and self.Menu.Combo.WLogicSettings.WMeleePeel:Value()) then
			--If the melee champ is directly on top of us, cast it on ourselves.
			--If there's some distance between Karthus and the champion, try to cast it on the champion
			if myHero.pos.DistanceTo(meleeTarget.pos) <= 100 then
				Control.CastSpell(HK_W, myHero.pos)
			else
				Control.CastSpell(HK_W, meleeTarget.pos)
			end
		end
	end
end

function Karthus:AutoQCheck()
	--Q
	if((myHero.health / myHero.maxHealth) <= self.Menu.AutoQ.AutoQHPCheck:Value() / 100) then return end
	
	local target = GetTarget(Q.Range)
	if(target ~= nil and IsValid(target)) then
		if(self:CanQ() and self.Menu.AutoQ.AutoQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.AutoQ.AutoQMana:Value() / 100)) then

			local QPrediction = GGPrediction:SpellPrediction(Q)
			QPrediction:GetPrediction(target, myHero)
			if QPrediction.CastPosition and QPrediction:CanHit(4) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
				return
			end
			
			if(IsImmobile(target) >= 0.5) then
				local QPrediction = GGPrediction:SpellPrediction(Q)
				QPrediction:GetPrediction(target, myHero)
				if QPrediction.CastPosition and QPrediction:CanHit(3) then
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
					return
				end
			end

		end
	end
end

function Karthus:SemiManualW()
	_G.SDK.Orbwalker:Orbwalk()
	if(gameTick > GameTimer()) then return end --This is to prevent the mouse from spasming out
	--W
	local target = GetTarget(W.Range)
	if(target ~= nil and IsValid(target)) then
		if(Ready(_W) and self.Menu.Combo.UseW:Value()) then
			local WPrediction = GGPrediction:SpellPrediction(W)
			WPrediction:GetPrediction(target, myHero)
			if WPrediction.CastPosition and WPrediction:CanHit(2) then
				Control.CastSpell(HK_W, WPrediction.CastPosition)
				gameTick = GameTimer() + 0.2
			end
		end
	end
end

function Karthus:IsInStatusBox(pt)
	return pt.x >= self.Window.x
		and pt.x <= self.Window.x + 186
		and pt.y >= self.Window.y
		and pt.y <= self.Window.y + 68
end

function Karthus:OnWndMsg(msg, wParam)
	self.AllowMove = msg == 513
			and wParam == 0
			and self:IsInStatusBox(cursorPos)
			and { x = self.Window.x - cursorPos.x, y = self.Window.y - cursorPos.y }
		or nil
end

function Karthus:Draw()
if myHero.dead then return end

	if(self.Menu.Drawings.DrawQ:Value()) then
		DrawCircle(myHero, Q.Range, 1, DrawColor(50, 80, 215, 255)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Drawings.DrawW:Value()) then
		DrawCircle(myHero, W.Range, 1, DrawColor(50, 145, 80, 255)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Drawings.DrawChampTracker:Value()) then
		-- Draw lines connecting to enemy champions
		for k, v in pairs(Enemies) do
			local distMax = 3000
			local distMin = Q.Range
			if(v and IsValid(v) and myHero.pos.DistanceTo(v.pos) <= distMax and myHero.pos.DistanceTo(v.pos) > distMin) then
				local lineAlphaVal = ((myHero.pos.DistanceTo(v.pos) - distMin) / (distMax - distMin)) * 0.9
				DrawLine(myHero.pos:To2D(), v.pos:To2D(), 1, DrawColor(300 * lineAlphaVal, 255, 0, 0))
			end
		end
	end
	
	-- Ult kill tracker
	self:RCheck()
	
	if(self.Menu.Drawings.DrawHealthTracker:Value()) then
		self:DrawHealthTracker()
	end
end

function Karthus:DrawHealthTracker()
	if not (myHero.networkID)then return end
	if (Game.Timer() <= 1) then return end
	if Karthus.AllowMove then
		Karthus.Window = { x = cursorPos.x + Karthus.AllowMove.x, y = cursorPos.y + Karthus.AllowMove.y }
	end
	
	local rectHeight = #Enemies * 30
	
	Draw.Rect(self.Window.x, self.Window.y, 300, rectHeight, Draw.Color(224, 23, 23, 23))
	Draw.Text("Health Tracker", 18, self.Window.x + 10, self.Window.y + 5, DrawColor(255, 255, 255, 255))
	
	local yOffset = 0
	
	
	
	local barWidth = 180
	local barOffset = 100
	local miaCheck = false
	for k, v in pairs(Enemies) do

		local hpRatio = v.health / math.floor(v.maxHealth)
		local RDmg = 0 --getdmg("R", v, myHero)
		
		if(UltableChamps[v.name] ~= nil) then
			miaCheck = ((GetTickCount() - UltableChamps[v.name].timelastspotted) / 1000 >= MIATimer)
			RDmg = UltableChamps[v.name].ultdmg 
		end
		
		local ultDmgRatio = RDmg / v.maxHealth
		
		if(ultDmgRatio > hpRatio) then
			ultDmgRatio = hpRatio
		end
		
		
		--HealthBarDraws
		if(not miaCheck and v.alive) then
			Draw.Rect(self.Window.x + barOffset, self.Window.y + 39 + yOffset, barWidth, 8, DrawColor(255, 0, 0, 0))
			Draw.Rect(self.Window.x + barOffset, self.Window.y + 39 + yOffset, barWidth * hpRatio -1, 8, IsValid(v) and DrawColor(255, 0, 255, 125) or DrawColor(55, 0, 255, 125))
			if(RDmg > v.health) then
				Draw.Rect(self.Window.x + barOffset + (barWidth * hpRatio) - (barWidth * ultDmgRatio), self.Window.y + 39 + yOffset, barWidth * ultDmgRatio, 8, (IsValid(v) or not miaCheck) and DrawColor(255, 255, 0, 125) or DrawColor(75, 255, 0, 125))
			else
				Draw.Rect(self.Window.x + barOffset + (barWidth * hpRatio) - (barWidth * ultDmgRatio), self.Window.y + 39 + yOffset, barWidth * ultDmgRatio, 8, IsValid(v) and DrawColor(200, 225, 55, 125) or DrawColor(35, 255, 0, 125))
			end
		else
			Draw.Rect(self.Window.x + barOffset, self.Window.y + 39 + yOffset, barWidth, 8, DrawColor(55, 255, 255, 255))
		end
		
		-- Name

		if(not miaCheck and v.alive) then
			if(RDmg > v.health) then
				Draw.Text(v.charName, 17, self.Window.x + 10, self.Window.y + 35 + yOffset, DrawColor(255, 255, 75, 135))
			else
				Draw.Text(v.charName, 17, self.Window.x + 10, self.Window.y + 35 + yOffset, DrawColor(255, 55, 255, 155))
			end
		else
			Draw.Text(v.charName, 17, self.Window.x + 10, self.Window.y + 35 + yOffset, DrawColor(125, 255, 255, 255))
		end
		
		yOffset = yOffset + 20
	end

end

local pulseRCheck = 0

function Karthus:RCheck()
	for k,v in pairs(Enemies) do
		if(UltableChamps[v.name] == nil) then return end
		if(IsValid(v)) then
			UltableChamps[v.name].timelastspotted = GetTickCount()
			UltableChamps[v.name].mia = false
		end
	end
	
	if(pulseRCheck > GameTimer()) then return end
	pulseRCheck = GameTimer() + 0.25
	
	for _, enemy in pairs(Enemies) do
		local miaCheck = ((GetTickCount() - UltableChamps[enemy.name].timelastspotted) / 1000 >= MIATimer)	
		
		if(IsValid(enemy)) then
			UltableChamps[enemy.name].timelastspotted = GetTickCount()
			local RDmg = getdmg("R", enemy, myHero)
			UltableChamps[enemy.name].ultdmg = RDmg
			local Hp = enemy.health + (6 * enemy.hpRegen)
			if Hp <= RDmg and  not (self:CantKill(enemy, true, true, false)) then
				UltableChamps[enemy.name].killable = true
			else
				UltableChamps[enemy.name].killable = false
			end	
		end
		
		if(enemy.visible == false) then
			UltableChamps[enemy.name].mia = true
		end
		
		if(miaCheck) then
			UltableChamps[enemy.name].killable = false
		end
		
		if(enemy.dead or enemy.health <= 0 or not enemy.isTargetable) then
			UltableChamps[enemy.name].killable = false
		end
	end
	
end

function Karthus:CantKill(unit, kill, ss, aa)
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
		
		if  buff.name:lower():find("willrevive") and kill and buff.count==1 then
			return true
		end

		if  buff.name:lower():find("morganae") and ss and not aa and buff.count==1 then
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
	
Callback.Add("Load", function()	
	if table.contains(Heroes, myHero.charName) then	
		_G[myHero.charName]()
		LoadUnits()
		
		if Karthus.OnWndMsg then
			table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
				Karthus:OnWndMsg(msg, wParam)
			end)
		end
	end
end)
