require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.08

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Gangplank will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

--=============--

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
		if(myHero:GetSpellData(_Q).currentCd) > 0 or myHero.activeSpell.name == myHero:GetSpellData(_Q).name and myHero:GetSpellData(_Q).cd ~= 0 then
			self.QDidCast = true
			local spell = myHero:GetSpellData(_Q)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.WDidCast == false) then
		if(myHero:GetSpellData(_W).currentCd) > 0 or myHero.activeSpell.name == myHero:GetSpellData(_W).name and myHero:GetSpellData(_W).cd ~= 0 then
			self.WDidCast = true
			local spell = myHero:GetSpellData(_W)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.EDidCast == false) then
		if(myHero.activeSpell.name == myHero:GetSpellData(_E).name) then
			self.EDidCast = true
			local spell = myHero:GetSpellData(_E)
			local delay = (myHero.activeSpell.castEndTime - GameTimer())
			DelayAction(function()
				for i, Emit in pairs(self.OnSpellCastCallback) do
					Emit(spell)
				end
			end, delay)
		end
	end
	
	if(self.RDidCast == false) then
		if(myHero:GetSpellData(_R).currentCd) > 0 or myHero.activeSpell.name == myHero:GetSpellData(_R).name and myHero:GetSpellData(_R).cd ~= 0 then
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
	if(Ready(_E) and myHero.activeSpell.name ~= myHero:GetSpellData(_E).name) then 
		self.EDidCast = false 
	end
	if(Ready(_R)) then self.RDidCast = false end
end

local function OnSpellCast(fn)
    if not _SPELLCAST_START then
        _G.SpellCast = SpellCast()
    end
    table.insert(SpellCast.OnSpellCastCallback, fn)
end

----------------------------------------------------

local colorTheme = 
{
[1] =	{	--Default
				["q"] = {r = 80, g = 215, b = 255},
				["e"] = {r = 215, g = 215, b = 215},
				["barrelvis"] = {r = 175, g = 175, b = 175},
				["prowlersactive"] = {r = 255, g = 25, b = 55},
				["prowlersinactive"] = {r = 215, g = 25, b = 55},
				["passive"] = {r = 255, g = 95, b = 5}
			},
[2] =	{	-- Red
				["q"] = {r = 255, g = 23, b = 23},
				["e"] = {r = 255, g = 108, b = 57},
				["barrelvis"] = {r = 255, g = 35, b = 85},
				["prowlersactive"] = {r = 255, g = 25, b = 55},
				["prowlersinactive"] = {r = 215, g = 25, b = 55},
				["passive"] = {r = 255, g = 95, b = 5}
			},
[3] =	{	-- Fusion Purple
				["q"] = {r = 255, g = 33, b = 151},
				["e"] = {r = 255, g = 33, b = 245},
				["barrelvis"] = {r = 191, g = 94, b = 255},
				["prowlersactive"] = {r = 252, g = 51, b = 255},
				["prowlersinactive"] = {r = 179, g = 62, b = 181},
				["passive"] = {r = 70, g = 0, b = 255}
			},
[4] =	{	-- Lime
				["q"] = {r = 0, g = 255, b = 95},
				["e"] = {r = 80, g = 255, b = 0},
				["barrelvis"] = {r = 200, g = 255, b = 0},
				["prowlersactive"] = {r = 212, g = 255, b = 0},
				["prowlersinactive"] = {r = 143, g = 163, b = 56},
				["passive"] = {r = 183, g = 255, b = 0}
			},
[5] =	{	-- Aqua
				["q"] = {r = 48, g = 165, b = 255},
				["e"] = {r = 48, g = 235, b = 255},
				["barrelvis"] = {r = 95, g = 255, b = 250},
				["prowlersactive"] = {r = 84, g = 113, b = 255},
				["prowlersinactive"] = {r = 55, g = 61, b = 250},
				["passive"] = {r = 38, g = 251, b = 255}
			},
[6] =	{	-- Gold
				["q"] = {r = 255, g = 162, b = 0},
				["e"] = {r = 255, g = 225, b = 0},
				["barrelvis"] = {r = 95, g = 255, b = 250},
				["prowlersactive"] = {r = 255, g = 162, b = 0},
				["prowlersinactive"] = {r = 163, g = 128, b = 23},
				["passive"] = {r = 255, g = 220, b = 38}
			},
[7] =	{	-- Ikea
				["q"] = {r = 245, g = 255, b = 0},
				["e"] = {r = 2, g = 223, b = 235},
				["barrelvis"] = {r = 2, g = 223, b = 235},
				["prowlersactive"] = {r = 245, g = 255, b = 0},
				["prowlersinactive"] = {r = 163, g = 138, b = 21},
				["passive"] = {r = 0, g = 213, b = 255}
			}
}

local function GetThemeColor(themeType)
	local index = Gangplank.Menu.Drawings.ColorTheme:Value()
	local theme = colorTheme[index]
	if(theme) then
		local tType = string.lower(themeType)
		if(theme[tType]) then
			return (theme[tType])
		else
			return ({r = 255, g = 255, b = 255}) --Default
		end
	else
		return ({r = 255, g = 255, b = 255}) --Default
	end
end

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Gangplank"

local ChampIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/41.png"

local gameTick = GameTimer()
Gangplank.AutoLevelCheck = false

-- GG PRED
local Q = {Delay = 0.25, Range = 625, Speed = 2600}
local E = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 330, Range = 1000, Speed = math.huge, Collision = false}
local EStaggered = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 330, Range = 1000, Speed = 2400, Collision = false}
local R = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 580, Range = math.huge, Speed = math.huge, Collision = false}
local RStaggered = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.25, Radius = 580, Range = math.huge, Speed = math.huge, Collision = false}

Gangplank.BarrelData = {}
Gangplank.ComboDamageData = {}
Gangplank.barrelAATarget = nil
Gangplank.barrelAAoptionalHP = nil
Gangplank.barrelQTarget = nil

--[[
GANGPLANK Item IDS
(Most commonly used items with Gangplank)

3057 = SHEEN
3078 = TRIFORCE
7018 = INFINITY FORCE (Upgraded Triforce)
3508 = ESSENCE REAVER
6675 = NAVORI QUICKBLADES
6693 = PROWLERS CLAW
7000 = SANDSHRIKES CLAW (Upgraded Prowlers Claw)
6676 = THE COLLECTOR
3036 = LORD DOMINIKS REGARDS
--]]

local ITEM_SHEEN = 3057
local ITEM_TRIFORCE = 3078
local ITEM_INFINITYFORCE = 7018
local ITEM_ESSENCEREAVER = 3508
local ITEM_NAVORI = 6675
local ITEM_PROWLERSCLAW = 6693
local ITEM_SANDSHRIKESCLAW = 7000
local ITEM_COLLECTOR = 6676
local ITEM_DOMINIKS = 3036

local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6,}

--Main Menu
Gangplank.Menu = MenuElement({type = MENU, id = "KillerGangplank", name = "Killer Gangplank", leftIcon = ChampIcon})
Gangplank.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})
Gangplank.AARange = 225
Gangplank.ComboKey = 32
Gangplank.Ping = 0


Gangplank.BaseAS = 0.658
Gangplank.ASRatio = 0.69

function Gangplank:__init()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	--Custom Callbacks
	OnSpellCast(function(spell) self:OnSpellCast(spell) end)
	StrafePred()
	_G.SDK.Orbwalker:OnPreAttack(function(...) Gangplank:OnPreAttack(...) end)
	
	DelayAction(function()
		self.ComboKey = _G.SDK.Menu.Orbwalker.Keys.Combo:Key()
	end, 0.05)
end

function Gangplank:LoadMenu()                     	

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	if(myHero:GetSpellData(SUMMONER_1).name == "SummonerDot") or (myHero:GetSpellData(SUMMONER_2).name == "SummonerDot") then
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "Ignite Loaded", type = SPACE})
	else
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "Ignite Not Loaded", type = SPACE})
	end
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "UseIgnite", name = "Use Ignite", value = true})
	self.Menu.Combo:MenuElement({id = "EModules", name = "E Logic", type = MENU})
	self.Menu.Combo:MenuElement({id = "RDuel", name = "R Dueling", type = MENU})
	self.Menu.Combo:MenuElement({id = "PhantomBarrelKey", name = "Phantom Barrel Combo", key = string.byte("Z")})
	self.Menu.Combo:MenuElement({id = "TripleBarrelKey", name = "Triple Barrel Semi-Manual", key = string.byte("C")})
	self.Menu.Combo:MenuElement({id = "ClampPBMovement", name = "Phantom Barrel Movement Assist", value = true})
	--NOTE** In patch 13.10, Prowler's claw lost its leap ability, and is no longer used on Gangplank
	--self.Menu.Combo:MenuElement({id = "ProwlersSettings", name = "Prowlers Claw Settings", type = MENU})
	
	--R Dueling
	self.Menu.Combo.RDuel:MenuElement({id = "UseR", name = "Use R to Duel", value = true})
	self.Menu.Combo.RDuel:MenuElement({id = "RequireIgnite", name = "Combo with Ignite", value = true})
	
	--E Logic
	self.Menu.Combo.EModules:MenuElement({name = " ", drop = {"Barrel Attack Priority: Melee > Q"}})
	self.Menu.Combo.EModules:MenuElement({id = "TeamfightOverride", name = "[Use All Available Barrels in Teamfights]", value = true})
	self.Menu.Combo.EModules:MenuElement({id = "EChain", name = "Auto Chain Barrels", value = true})
	self.Menu.Combo.EModules:MenuElement({id = "HoldQ", name = "Hold Q for Barrels", value = true})
	self.Menu.Combo.EModules:MenuElement({id = "AutoQ", name = "Q/AA Barrels that will hit Enemies", value = true})
	self.Menu.Combo.EModules:MenuElement({id = "AutoQChain", name = "Q/AA Chains that will hit Enemies", value = true})
	self.Menu.Combo.EModules:MenuElement({id = "AutoECC", name = "Use E on CC'd Enemies", value = true})
	self.Menu.Combo.EModules:MenuElement({id = "EMelee", name = "Use E on Enemies in Melee Range", value = true})
	self.Menu.Combo.EModules:MenuElement({id = "EClusters", name = "Use E on Enemy Clusters [Lv. 13+]", value = true})
	self.Menu.Combo.EModules:MenuElement({id = "EFleeing", name = "Use E on Fleeing Enemies [Lv. 13+]", value = true})
	
	--Prowlers Claw Settings
	--self.Menu.Combo.ProwlersSettings:MenuElement({id = "UseProwlersClaw", name = "Auto Use Prowlers Claw", value = true})
	--self.Menu.Combo.ProwlersSettings:MenuElement({id = "SemiManualProwler", name = "Use Semi-manual Prowlers", value = true})
	
	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
	
	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "SmartQ", name = "Smart Q Farm", value = true})
	self.Menu.LastHit:MenuElement({id = "MinimumMana", name = "Minimum Mana to Q", value = 40, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "SmartQ", name = "Smart Q Farm", value = true})
	self.Menu.Clear:MenuElement({id = "MinimumMana", name = "Minimum Mana to Q", value = 40, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear:MenuElement({id = "UseE", name = "Place Barrels", value = true})
	self.Menu.Clear:MenuElement({id = "UseQAA", name = "Use Q/AA on Barrels", value = true})
	self.Menu.Clear:MenuElement({id = "SaveAttack", name = "Only Attack Barrels if no Enemies Nearby", value = true})
	self.Menu.Clear:MenuElement({id = "MinBarrels", name = "Minimum Barrels to Keep", value = 2, min = 0, max = 5, step = 1, identifier = " Barrels"})
	self.Menu.Clear:MenuElement({id = "MinMinions", name = "Minimum Minions to Kill with Barrels", value = 1, min = 0, max = 5, step = 1, identifier = " Minions"})
	
	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true})
	
	--Auto W
	self.Menu:MenuElement({id = "AutoWMenu", name = "Auto W", type = MENU})
	self.Menu.AutoWMenu:MenuElement({id = "Cleanse", name = "Use to Cleanse", value = true})
	self.Menu.AutoWMenu:MenuElement({id = "Humanizer", name = "Cleanse Humanized Delay", value = true})
	self.Menu.AutoWMenu:MenuElement({id = "Heal", name = "Auto Heal", value = false})
	self.Menu.AutoWMenu:MenuElement({id = "HealthPercent", name = "Minimum Health Percent to W", value = 25, min = 0, max = 90, step = 5, identifier = "%"})
	
	--Auto R
	self.Menu:MenuElement({id = "AutoRMenu", name = "Auto R", type = MENU})
	self.Menu.AutoRMenu:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.AutoRMenu:MenuElement({id = "OnScreenCheck", name = "Require Target to be On Screen", value = true})
	self.Menu.AutoRMenu:MenuElement({id = "RExecute", name = "Use R to Execute (Collectors Support)", value = true})
	self.Menu.AutoRMenu:MenuElement({id = "RTeamFights", name = "Use R in Team Fights", value = true, tooltip = "At least 3 enemies, with 1 ally near you!"})
	
	--
	self.Menu:MenuElement({id = "AutoPrimeBarrels", name = "AA Barrels to Ready Them [Lv. 1~6]", value = true, tooltip = "Will stop doing this at level 7"})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "ColorTheme", name = "Color Theme",  value = 1, drop = {"Default", "Red", "Fusion Purple", "Lime", "Aqua", "Gold", "Ikea"}})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawE", name = "Draw E Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawPassive", name = "Draw Passive", value = true})
	self.Menu.Drawings:MenuElement({id = "BarrelPlacementVis", name = "Barrel Placement Visualizer", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawPhantomUI", name = "Draw Phantom Barrel UI",  value = 1, drop = {"Modern", "Legacy", "Disabled"}})
	--self.Menu.Drawings:MenuElement({id = "DrawProwlers", name = "Draw Prowlers Leap Range", value = true})
	self.Menu.Drawings:MenuElement({id = "Debug", name = "Debug Drawings", type = MENU})
	
	--Barrel Placement Visualizer
	self.Menu.Drawings.BarrelPlacementVis:MenuElement({id = "DrawBarrelVisualizer", name = "Draw Barrel Placement Visualizer", value = false})
	self.Menu.Drawings.BarrelPlacementVis:MenuElement({id = "RequireCombo", name = "Require Combo Mode", value = true})
	self.Menu.Drawings.BarrelPlacementVis:MenuElement({id = "OuterRing", name = "Draw Outer Ring", value = true})
	self.Menu.Drawings.BarrelPlacementVis:MenuElement({id = "InnerRing", name = "Draw Inner Ring", value = true})
	self.Menu.Drawings.BarrelPlacementVis:MenuElement({id = "Lines", name = "Draw Connecting Lines", value = true})
	self.Menu.Drawings.BarrelPlacementVis:MenuElement({id = "Alpha", name = "Transparency", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- debug.debug
	self.Menu.Drawings.Debug:MenuElement({id = "DrawBarrels", name = "Draw Barrels", value = true})
	self.Menu.Drawings.Debug:MenuElement({id = "DrawParticles", name = "Draw Particles", value = false})
	self.Menu.Drawings.Debug:MenuElement({id = "DrawObjects", name = "Draw Objects", value = false})
		
	self.Menu:MenuElement({id = "AutoLevel", name = "Auto Level Skills (Q - E - W)", value = false})
	self.Menu:MenuElement({id = "DisableInFountain", name = "Disable Orbwalker while in Fountain", value = true})
	self.Menu:MenuElement({id = "ExtraReactionTime", name = "Extra Reaction Time Delay [ms]", value = 0, min = 0, max = 500, step = 5})
	
end


function Gangplank:Tick()
	if(MyHeroNotReady()) then return end
	
	if(self.Menu.DisableInFountain:Value()) then
		if(IsInFountain()) then
			_G.SDK.Orbwalker:SetMovement(false)
		else
			_G.SDK.Orbwalker:SetMovement(true)
		end
	else
		_G.SDK.Orbwalker:SetMovement(true)
	end
	
	self.Ping = (_G.SDK.Menu.Main.Latency:Value() - 5)/1000
	
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
	
	self:UpdateBarrels()
	self:KillSteal()
	self:ManualKeys()
	self:AABarrelTick()
	self:QBarrelTick()
	self:TripleBarrelForceETick()
	
	if (self.Menu.AutoRMenu.UseR:Value()) then
		self:AutoR()
	end
	
	if (self.Menu.AutoPrimeBarrels:Value() and myHero.levelData.lvl < 13) then
		self:PrimeBarrels()
	end
	
	if (self.Menu.Combo.PhantomBarrelKey:Value()) then
		--Fallback 
		if(myHero.activeSpell.name == "GangplankQ" or myHero.activeSpell.name == "GangplankQWrapper" or myHero.activeSpell.name == "GangplankQProceed" or myHero.activeSpell.name == "GangplankQProceedCrit") then
			self.canPlacePhantomE = true
		end

		self:PhantomCombo()
	else
		self.canDoPhantomCombo = false
		self.canPlacePhantomE = false
		_G.SDK.Orbwalker.ForceMovement = nil
	end
	
	if (self.Menu.Combo.TripleBarrelKey:Value()) then
		self:TripleBarrelSemiManual()
	end
	
	if (self.Menu.AutoWMenu.Cleanse:Value()) then
		self:AutoWCleanse()
	end
	
	if (self.Menu.AutoWMenu.Heal:Value()) then
		self:AutoWHeal()
	end
	
	if Game.IsOnTop() and self.Menu.AutoLevel:Value() then
		self:AutoLevel()
	end	
end

function Gangplank:OnSpellCast(spell)
	if spell.name == "GangplankE" then
        DelayAction(function()
            self:CheckBarrels(GameTimer() - 0.03)
        end, 0.03)
	end
	
	if spell.name == "GangplankQ" or spell.name == "GangplankQWrapper" or spell.name == "GangplankQProceed" or spell.name == "GangplankQProceedCrit" then
        Gangplank.canPlacePhantomE = true
	end
end

function Gangplank:IsChannelingQ()
	local spell = myHero.activeSpell.name
	if(spell == "GangplankQ" or spell == "GangplankQWrapper" or spell == "GangplankQProceed" or spell == "GangplankQProceedCrit") then
		return true
	end
	return false
end

function Gangplank:OnPreAttack(args)
    if GetMode()=="Combo" then
		if(_G.SDK.Orbwalker.ForceTarget ~= nil) then
			--This allows us to make the orbwalker AA barrels
			Control.KeyUp(self.ComboKey)
			args.Target = _G.SDK.Orbwalker.ForceTarget
			DelayAction(function()
			Control.KeyDown(self.ComboKey)
			end, 0.01)
		else
			-- The code will delay your AA so that it can AA a barrel instead if you are contesting it with another enemy
			local tar = args.Target
			if(tar and IsValid(tar)) then
				local proximityBarrels = self:GetBarrelsAroundUnit(tar, E.Radius)
				if(#proximityBarrels > 0) then
					for _, barrel in ipairs(proximityBarrels) do
						local dist = GetDistance(myHero, barrel.barrelObj)
						if(self:IsBarrelBehindUnit(barrel, tar) == false) then
							if dist < _G.SDK.Data:GetAutoAttackRange(myHero)+75 then
								if(self:GetBarrelHealth(barrel, (1 / (self.BaseAS+((myHero.attackSpeed-1) * self.ASRatio))) + ((_G.SDK.Menu.Main.Latency:Value() + 15)/1000)) == 1) then
									args.Process = false
									
									--Q weaving
									--[[
									if(self.Menu.Combo.UseQ:Value()) then
										if(Ready(_Q) and self:GetBarrelHealth(barrel, Q.Delay + 0.1) > 1 and  myHero.levelData.lvl >= 7) then
											Control.CastSpell(HK_Q, tar)
										end
									end
									--]]
								end
							end                        
						end
					end
				end
				
				
                if myHero:GetSpellData(_Q).currentCd<0.8 and (myHero:GetSpellData(_E).ammo>0 or (myHero:GetSpellData(_E).ammo==0 and myHero:GetSpellData(_E).currentCd>0))  then
                    local proximityBarrels = self:GetBarrelsAroundUnit(myHero, Q.Range)
                    if#proximityBarrels >= 1 then 
                        for _, barrel in ipairs(proximityBarrels) do
                            if(self:GetBarrelHealth(barrel, E.Delay + Q.Delay + GetDistance(myHero, barrel.barrelObj)/Q.Speed + ((1 /(self.BaseAS+((myHero.attackSpeed-1) * self.ASRatio)))-E.Delay-Q.Delay)) == 1)  and GetDistance(barrel.barrelObj, tar.pos)<E.Radius*2.66 and self:HasPassive() == false  then
                            args.Process = false
                            end
                        end
                    end
                end     
			end
			Control.KeyDown(self.ComboKey)
		end
    end
end

-- Make sure we don't have duplicate barrels in our database
function Gangplank:CheckExistingBarrel(obj)
	for _, barrel in pairs(self.BarrelData) do
		if(barrel.barrelObj.networkID == obj.networkID) then
			return true
		end
	end
	return false
end

function Gangplank:CheckBarrels(passedAge)
	local barrels = self:GetBarrelObjects()
	for _, barrel in pairs(barrels) do
		if barrel and self:CheckExistingBarrel(barrel) == false then
			self.BarrelData[#self.BarrelData + 1] = {barrelObj = barrel, age = passedAge, connections = {}}
		end
	end
	
	--Adding connections
	self:UpdateBarrelConnections()
end

function Gangplank:UpdateBarrelConnections()
	local barrelConnections = {}
	for k, barrel in ipairs(self.BarrelData) do
		local subChildren = {}
		--Find connected barrels, per barrel
		for _, subBarrel in ipairs(self.BarrelData) do
			if(barrel.barrelObj.handle ~= subBarrel.barrelObj.handle) then
				if(GetDistance(subBarrel.barrelObj, barrel.barrelObj) <= (E.Radius*2 + 30)) then
					table.insert(subChildren, subBarrel)
				end
			end
		end
		
		if(#subChildren >= 1) then
			local barrelUnit = {index = k, barrelObj = barrel.barrelObj, age = barrel.age, connections = subChildren}
			table.insert(barrelConnections, barrelUnit)
		end
	end
	
	--Update our original data barrel data to add connections now
	for i = 1, #barrelConnections do
		local connection = barrelConnections[i]
		self.BarrelData[connection.index] = {barrelObj = connection.barrelObj, age = connection.age, connections = connection.connections}
	end
end

function Gangplank:UpdateBarrels()
	for i = #self.BarrelData, 1, -1 do
		local barrel = self.BarrelData[i].barrelObj
		if(barrel == nil or barrel.dead or not barrel.valid) then
			table.remove(self.BarrelData, i)
		end
	end
	
	--Retroactive barrel age updating
	local currPos, currAge = self:GetCurrentBarrelPlacementPos(0.25)
	if(currPos ~= nil) then
		for _, barrel in ipairs(self.BarrelData) do
			if(GetDistance(barrel.barrelObj, currPos) <= 2) and currAge < barrel.age then
				barrel.age = currAge
			end
		end
	end
end

function Gangplank:GetSpellbladeDamage()
	 for _, item in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}) do
        local id = myHero:GetItemData(item).itemID
		if(id == ITEM_SHEEN or id == ITEM_TRIFORCE or id == ITEM_INFINITYFORCE or id == ITEM_ESSENCEREAVER) then --Spellblade Procs
			if(myHero:GetSpellData(item).currentCd == 0) then

				if(id == ITEM_SHEEN) then -- SHEEN
					return myHero.baseDamage
				end
				
				if(id == ITEM_TRIFORCE) then -- TRIFORCE
					return myHero.baseDamage * 2
				end
				
				if(id == ITEM_INFINITYFORCE) then -- INFINITY FORCE
					return myHero.baseDamage * 2
				end
				
				if(id == ITEM_ESSENCEREAVER) then -- ESSENCE REAVER
					return myHero.baseDamage + (myHero.bonusDamage * 0.4)
				end
				
			end
		end
    end
	return 0
end

function Gangplank:HasNavori()
	 for _, item in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}) do
        local id = myHero:GetItemData(item).itemID
		if(id == ITEM_NAVORI) then
			return true
		end
    end
	return false
end

function Gangplank:HasEssenceReaver()
	 for _, item in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}) do
        local id = myHero:GetItemData(item).itemID
		if(id == ITEM_ESSENCEREAVER) then
			return true
		end
    end
	return false
end

function Gangplank:HasCollector()
	 for _, item in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}) do
        local id = myHero:GetItemData(item).itemID
		if(id == ITEM_COLLECTOR) then
			return true
		end
    end
	return false
end

--[[
function Gangplank:HasProwlers()
    for i = ITEM_1, ITEM_7 do
		local id = myHero:GetItemData(i).itemID
        if id == ITEM_PROWLERSCLAW or id == ITEM_SANDSHRIKESCLAW then
			if(myHero:GetSpellData(i).currentCd == 0) then
				return true, i
			else
				return false
			end
        end
    end
	return false
end
--]]

function Gangplank:HasPassive()
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.count > 0 and buff.name:lower():find("gangplankpassiveattack") then
			return true
		end
    end
	return false
end

function Gangplank:GetBarrelCharges()
	return myHero:GetSpellData(_E).ammo
end

function Gangplank:IsBarrelOnUnit(unit)
	for _, barrel in ipairs(self.BarrelData) do
		if(GetDistance(barrel.barrelObj, unit) < E.Radius) then
			return true
		end
	end
	
	return false
end

function Gangplank:GetBarrelsAroundUnit(unit, range)
	local barrels = {}
	for _, barrel in ipairs(self.BarrelData) do
		if(GetDistance(barrel.barrelObj, unit) < range) then
			local barrelUnit = {barrelObj = barrel.barrelObj, age = barrel.age, connections = barrel.connections}
			table.insert(barrels, barrelUnit)
		end
	end
	
	return barrels
end

function Gangplank:GetBarrelsAroundPosition(position, range)
	local barrels = {}
	for _, barrel in ipairs(self.BarrelData) do
		if(GetDistance(barrel.barrelObj, position) < range) then
			local barrelUnit = {barrelObj = barrel.barrelObj, age = barrel.age, connections = barrel.connections}
			table.insert(barrels, barrelUnit)
		end
	end
	
	return barrels
end

function Gangplank:GetChainBarrels()
	local chainBarrels = {}
	
	for _, barrel in ipairs(self.BarrelData) do
		if(#barrel.connections >= 1) then
			local barrelUnit = {barrelObj = barrel.barrelObj, age = barrel.age, connections = barrel.connections}
			table.insert(chainBarrels, barrelUnit)
		end
	end

	return chainBarrels
end

function Gangplank:IsBarrelOnAnyUnit()
	local currBarrel = self:GetCurrentBarrelPlacementPos(0.25)
	
	if(currBarrel) then
		for _, enemy in ipairs(Enemies) do
			if(enemy and IsValid(enemy)) then
				if GetDistance(currBarrel, enemy) < E.Radius then
					return true, enemy
				end
			end
		end
	end
	
	for _, enemy in ipairs(Enemies) do
		if(GetDistance(enemy, myHero) < E.Range -10) then
			for k, barrel in ipairs(self.BarrelData) do
				if(enemy and IsValid(enemy)) then
					if GetDistance(barrel.barrelObj, enemy) < E.Radius then
						return true, enemy
					end
				end
			end
		end
	end

	return false
end

function Gangplank:IsBarrelChainOnUnit(chainBarrels, unit)
	for _, barrel in ipairs(chainBarrels) do
		if(GetDistance(barrel.barrelObj, unit) < E.Radius + 30) then
			return true, barrel
		end
	end
	
	return false
end

function Gangplank:IsBarrelChainOnPosition(chainBarrels, position)
	for _, barrel in ipairs(chainBarrels) do
		if(GetDistance(barrel.barrelObj, position) < E.Radius + 30) then
			return true, barrel
		end
	end
	
	return false
end

--This is a helper function that gets us the depth distance between two barrels.
--For example if there was 4 barrels, and barrel1 was at the start of the chain, and barrel2 was at the end, the depth would be 3. Because barrel2 is 3 barrels away from barrel1
function Gangplank:GetChainDepth(barrel1, barrel2)
	if(barrel1.connections and barrel2.connections) then
		--First depth check, see if the two barrels share connections
		if(barrel1.barrelObj.networkID == barrel2.barrelObj.networkID) then
			return 0
		end
		
		for _, barrel in ipairs(barrel1.connections) do
			if barrel.barrelObj.networkID == barrel2.barrelObj.networkID then
				return 1
			end
		end
		
		--Second depth check, see if a connecting barrel is shared amongst both barrels
		for _, barrel1Connection in ipairs(barrel1.connections) do
			for _, barrel2Connection in ipairs(barrel2.connections) do
				if(barrel1Connection.barrelObj.networkID == barrel2Connection.barrelObj.networkID) then
					return 2
				end
			end
		end
		
		--Last depth check is an assumption that our barrel chain has 4 or more barrels (unrealistic typically during game play)
		return 3
	end
	
	return 0
end

function Gangplank:GetNextBarrelTick(barrel)
	local tickRate = 2
	if(myHero.levelData.lvl >= 7) then
		tickRate = 1
	end
	if(myHero.levelData.lvl >= 13) then
		tickRate = 0.5
	end
	
	local age = barrel.age
	local TICK_ONE = age + tickRate
	local TICK_TWO = age + (tickRate*2)
	
	if(GameTimer() < TICK_ONE) then
		return TICK_ONE
	else
		return TICK_TWO
	end
end

function Gangplank:GetBarrelHealth(barrel, delay)
	if(barrel) then
		delay = delay or 0
		local hp = barrel.barrelObj.health
		local age = barrel.age
		
		if(delay == 0 or hp <= 1) then
			return hp
		else
			local delayTime = GameTimer() + delay
			--Get the barrels health after a delayed period
			if(delayTime >= self:GetNextBarrelTick(barrel)) then
				return math.max(hp - 1, 1)
			else
				return hp
			end
		end
	end
	return 0
end

Gangplank.lastStoredBarrelPlacementPos = nil
function Gangplank:GetCurrentBarrelPlacementPos(scanTime)
	--[[
	scanTime is a variable that will allow you to see what the CurrentBarrelPlacementPos is up to a certain period of time.
	For example, if I use 3 for scanTime, I can see the result up to 3 seconds after the last recorded position.
	It's basically temporary history data.
	--]]
	scanTime = scanTime or 0
	
	if(myHero.activeSpell.name == "GangplankE") then
		self.lastStoredBarrelPlacementPos = {pos = myHero.activeSpell.placementPos, age =  myHero.activeSpell.castEndTime, scantimer = GameTimer()}
		return self.lastStoredBarrelPlacementPos.pos, self.lastStoredBarrelPlacementPos.age
	end
	
	if(scanTime > 0) and self.lastStoredBarrelPlacementPos ~= nil then
		if(GameTimer() - self.lastStoredBarrelPlacementPos.scantimer <= scanTime) then
			return self.lastStoredBarrelPlacementPos.pos, self.lastStoredBarrelPlacementPos.age
		else
			return nil
		end
	end
	
	return nil
end

function Gangplank:GetClosestBarrelToUnit(unit)
	local closestPos = math.huge
	local closestBarrel = nil
	for _, barrel in ipairs(self.BarrelData) do
		local distCheck = GetDistance(barrel.barrelObj, unit)
		if(distCheck <= closestPos) then
			closestBarrel = barrel
			closestPos = distCheck
		end
	end
	return closestBarrel
end

--This version will only check for AoE potential around the orbwalkers target
function Gangplank:GetPossibleAOEBarrel(tar, connectingBarrel)
	local barrel = connectingBarrel
	if(connectingBarrel.barrelObj ~= nil) then
		barrel = connectingBarrel.barrelObj
	end
	local enemyCluster = GetEnemiesAtPos(E.Range - 10, E.Radius, tar.pos, tar)
	if(#enemyCluster >= 2) then
		local bestAoEPos = CalculateBestCirclePosition(enemyCluster, E.Radius*0.66, false, E.Range - 10, E.Speed, E.Delay)
		if(bestAoEPos) then
			local dist = GetDistance(barrel, bestAoEPos)
			local distanceToPlacement = math.min(dist, (E.Radius - 15)*2)
			local placementVec = barrel.pos:Extended(bestAoEPos, distanceToPlacement)

			for _, enemy in ipairs(enemyCluster) do
				if(GetDistance(enemy, placementVec) > E.Radius*0.66) then
					return false, nil
				end
			end

			return true, bestAoEPos
		end
	end
	
	return false, nil
end

--This version will consider all possible AoE situations, regardless of who the orbwalker wants to hit
function Gangplank:GetPossibleAOEBarrel2(tar, connectingBarrel)
	if(_G.SDK.TargetSelector.Selected ~= nil) then return end
	
	local barrel = connectingBarrel
	if(connectingBarrel.barrelObj ~= nil) then
		barrel = connectingBarrel.barrelObj
	end
	
	local enemyCluster = nil
	for _, enemy in ipairs(Enemies) do
		if(GetDistance(enemy, myHero) < E.Range - 10) or enemy.networkID ~= tar.networkID then
			enemyCluster = GetEnemiesAtPos(E.Range - 10, E.Radius, enemy.pos, enemy)
			if(#enemyCluster >= 2) then
				local bestAoEPos = CalculateBestCirclePosition(enemyCluster, E.Radius*0.66, false, E.Range - 10, E.Speed, E.Delay)
				if(bestAoEPos) then
					local dist = GetDistance(barrel, bestAoEPos)
					local distanceToPlacement = math.min(dist, (E.Radius - 7.5)*2)
					local placementVec = barrel.pos:Extended(bestAoEPos, distanceToPlacement)

					for _, enemy in ipairs(enemyCluster) do
						if(GetDistance(enemy, placementVec) > E.Radius*0.66) then
							return false, nil
						end
					end

					return true, bestAoEPos
				end
			end
		end
	end
	
	return false, nil
end

function Gangplank:IsBarrelBehindUnit(barrel, unit)
	local barrelObj = barrel.barrelObj
	
	local backwardVec = {x = 0, y = -1} --Behind
	local dirVec = (barrelObj.pos:ToScreen() - unit.pos:ToScreen()):Normalized()
	local res = dotProduct(dirVec, backwardVec)
	local dist = GetDistance(barrelObj, unit)
	local maxDist = 225
	--Barrels become easier to attack when they are lower on the screen pos
	if(res >= 0.8 and dist <= maxDist and dist > unit.boundingRadius) then
		local bPos = barrelObj.pos:ToScreen()
		local yRatio = bPos.y / Game.Resolution().y
		local distRatio = (dist - unit.boundingRadius)/(maxDist - unit.boundingRadius)
		local check = (math.min(yRatio + distRatio*0.8, 1)) >= 1.0
		if(check) then return false end
	end
	
	--Barrels that are overlapping the unit but positionally behind it should be considered always behind the target
	if(res >= 0.25  and dist < unit.boundingRadius) then
		return true
	end
	
	if(res >= 0.75 and dist <= maxDist) then
		return true
	else
		return false
	end
	
	return false
end

function Gangplank:IsUnitFleeing(unit)
	if(unit and IsValid(unit) and unit.toScreen.onScreen) then
		local checkRunDir = GetUnitRunDirection(myHero, unit)
		if(checkRunDir == RUNNING_AWAY) then
			--Conditions where someone may be fleeing
			
			--Target is less than 20% HP
			local condition1 = (unit.health / unit.maxHealth) <= 0.2 
			
			--You have 30% more HP than the target and they are less than 40% HP
			local condition2 = (myHero.health / myHero.maxHealth) - (unit.health / unit.maxHealth)>= 0.3 and (unit.health / unit.maxHealth) <= 0.4
			
			if(condition1 or condition2) then
				return true
			end
		end
	end
	
	return false
end

function Gangplank:IsInTeamfight()
	--Team fights for this would be considered at least 2 enemies and 1 nearby ally
	local enemies = GetEnemyHeroes(E.Range)
	if(#enemies >= 2) then
		--Ally check
		local allies = GetAllyHeroes(Q.Range + 175)
		if(#allies >= 1) then
			return true
		end
	end
	
	return false
end

function Gangplank:AABarrelTick()
	--We don't want Q Barrel Tick and AA Barrel Tick happening simultaneously
	if(self.barrelQTarget ~= nil) then
		self.barrelAATarget = nil
		_G.SDK.Orbwalker.ForceTarget	= nil
		return 
	end
	
	if(self.barrelAATarget == nil) then 
		_G.SDK.Orbwalker.ForceTarget	= nil
		return 
	end
	
	if(GetDistance(self.barrelAATarget, myHero) > self.AARange) then
		Control.KeyDown(self.ComboKey)
		self.barrelAATarget = nil
		_G.SDK.Orbwalker.ForceTarget	= nil
		Control.KeyUp(self.ComboKey)
	end
	
	if(self.barrelAATarget.health == 0 or not self.barrelAATarget.valid) then 
		self.barrelAATarget = nil
		_G.SDK.Orbwalker.ForceTarget	= nil
		return 
	end
	
	if(Control.IsKeyDown(self.ComboKey) == false and self.barrelAATarget ~= nil) then
		Control.KeyUp(self.ComboKey)
		return
	end
	
	if(self.barrelAATarget ~= nil) then
		if(self.barrelAAoptionalHP ~= nil) then
			if(self.barrelAATarget.health == self.barrelAAoptionalHP) then
				Control.KeyUp(self.ComboKey)
				_G.SDK.Orbwalker.ForceTarget	= self.barrelAATarget
				Control.KeyDown(self.ComboKey)
			else
				self.barrelAATarget = nil
				_G.SDK.Orbwalker.ForceTarget	= nil			
			end
		else
			Control.KeyUp(self.ComboKey)
			_G.SDK.Orbwalker.ForceTarget	= self.barrelAATarget
			Control.KeyDown(self.ComboKey)
		end
	else
		Control.KeyDown(self.ComboKey)
		self.barrelAATarget = nil
		_G.SDK.Orbwalker.ForceTarget	= nil
		Control.KeyUp(self.ComboKey)
	end
end

function Gangplank:QBarrelTick()

	--We don't want Q Barrel Tick and AA Barrel Tick happening simultaneously
	if(self.barrelAATarget ~= nil) then
		self.barrelQTarget = nil
		return 
	end
	if(self.barrelQTarget == nil) then return end
	if(self.barrelQTarget.health == 0 or not self.barrelQTarget.valid) then 
		self.barrelQTarget = nil
		return 
	end
	
	if(Ready(_Q) == false) then
		self.barrelQTarget = nil
		return
	end
	
	if(Control.IsKeyDown(self.ComboKey) == false and self.barrelQTarget ~= nil) then
		Control.KeyUp(self.ComboKey)
		return
	end

	if(self.barrelQTarget and self:IsChannelingQ() == false) then
		Control.KeyUp(self.ComboKey)
		Control.CastSpell(HK_Q, self.barrelQTarget)
		Control.KeyDown(self.ComboKey)
	else
		Control.KeyDown(self.ComboKey)
		self.barrelQTarget = nil
	end
end

Gangplank.forceEData = {pos = nil, barrel = nil, tar = nil}
Gangplank.canPlaceE = false
function Gangplank:TripleBarrelForceETick()
	if(GetMode() == "Combo" or self.Menu.Combo.TripleBarrelKey:Value()) then		
		if(myHero.activeSpell.name == "GangplankE") then
			self.forceEData = {pos = nil, barrel = nil, tar = nil}
			self.canPlaceE = false
			return
		end
		
		if(self.canPlaceE)then
			local barrel = self.forceEData.barrel
			local target = self.forceEData.tar
			--Do a second pass check on the position to make sure we can't get a better one
			local distCheck = GetDistance(barrel, target)
			local distanceToPlacement = math.min(distCheck, (E.Radius - 10)*2)
			local secondPos = barrel.pos:Extended(target.pos, distanceToPlacement)
			if(GetDistance(secondPos, myHero) <= E.Range - 10) then
				self.forceEData = {pos = secondPos, barrel = self.forceEData.barrel, tar = self.forceEData.tar}
			end
			
			--AoECheck
			local canAoE, AoEPos = self:GetPossibleAOEBarrel2(target, barrel)
			if(canAoE) then
				local distCheck = GetDistance(barrel, AoEPos)
				local distanceToPlacement = math.min(distCheck, (E.Radius - 10)*2)
				local secondPos = barrel.pos:Extended(AoEPos, distanceToPlacement)
				if(GetDistance(secondPos, myHero) <= E.Range - 10) then
					self.forceEData = {pos = secondPos, barrel = self.forceEData.barrel, tar = self.forceEData.tar}
				end
			end

			Control.CastSpell(HK_E, self.forceEData.pos)
		end
		
		if(self.forceEData.pos and self.forceEData.barrel and self.forceEData.tar and IsValid(self.forceEData.tar)) then
			if(myHero.activeSpell.name == "GangplankQ" or myHero.activeSpell.name == "GangplankQWrapper" or myHero.activeSpell.name == "GangplankQProceed" or myHero.activeSpell.name == "GangplankQProceedCrit") then
				self.canPlaceE = true
			end
		else
			self.forceEData = {pos = nil, barrel = nil, tar = nil}
			self.canPlaceE = false
			return
		end
	else
		self.canPlaceE = false
		self.forceEData = {pos = nil, barrel = nil, tar = nil}
	end
end

function Gangplank:SetTripleBarrelForceE(position, connectingBarrel, target)
	self.forceEData.pos = position
	self.forceEData.barrel = connectingBarrel
	self.forceEData.tar = target
end

function Gangplank:SetAABarrel(barrel, optionalHP)
	if(barrel) then
		self.barrelAATarget = barrel.barrelObj
		self.barrelAAoptionalHP = optionalHP
	else
		self.barrelAATarget = nil
	end
end

function Gangplank:SetQBarrel(barrel)
	self.barrelQTarget = barrel.barrelObj
end

function Gangplank:AutoLevel()
	if self.AutoLevelCheck then return end
	
	local level = myHero.levelData.lvl
	local levelPoints = myHero.levelData.lvlPts

	if (levelPoints == 0) or (level == 1) then return end
	if (Game.mapID == HOWLING_ABYSS and level <= 3) then return end
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

function Gangplank:Combo()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) then return end
	local tar = GetTarget(E.Range + E.Radius -10) --E Range target
	local tarQRange = GetTarget(Q.Range) --Q Range target
	local isFleeing = false
	local extraReaction = self.Menu.ExtraReactionTime:Value() / 1000
	
	local teamfightOverride = false
	if(self.Menu.Combo.EModules.TeamfightOverride:Value()) then
		if(self:IsInTeamfight()) then
			teamfightOverride = true
		end
	end
	
	if(self.Menu.Combo.UseIgnite:Value()) then
		local igniteTarget = GetTarget(590)
		if(igniteTarget and IsValid(igniteTarget)) then

			local igniteDmg = 50 + (20 * myHero.levelData.lvl)
			local dmgCheck = self:GetQDamage()
			local phsDmg = CalcPhysicalDamage(myHero, igniteTarget, dmgCheck)

			if(Ready(_Q)) then
				if(igniteTarget.health - igniteDmg - phsDmg <= 0) and igniteTarget.health - igniteDmg >= 0 then
					UseIgnite(igniteTarget)
				end
				
				--Collector support
				if(self:HasCollector()) then
					if(igniteTarget.health - igniteDmg - phsDmg <= igniteTarget.maxHealth*0.05) and igniteTarget.health - igniteDmg >= igniteTarget.maxHealth*0.05 then
						UseIgnite(igniteTarget)
					end
				end
			else
				-- Melee Ignite support
				if(GetDistance(igniteTarget, myHero) <= self.AARange) then
					if(igniteTarget.health - igniteDmg - myHero.totalDamage*2 <= 0) and igniteTarget.health - igniteDmg >= 0 then
						UseIgnite(igniteTarget)
					end
				end
			end

		end
	end
	
	--Local Fleeing check
	if(Ready(_E)) then
		if(self:IsUnitFleeing(tar)) then
			isFleeing = true
		end
	end

	if(self.Menu.Combo.RDuel.UseR:Value()) then
		if(Ready(_R)) then
			self:RDuel(tar)
		end
	end

	--Holding Q for barrels
	local holdingQ = false

	if(self.Menu.Combo.EModules.HoldQ:Value()) then
		if(tar and IsValid(tar)) then
			local proximityBarrels = self:GetBarrelsAroundUnit(myHero, E.Range)
			local proximityEnemyBarrels = self:GetBarrelsAroundUnit(tar, E.Range)
			local currBarrelPlacement = self:GetCurrentBarrelPlacementPos(0.25)
			local eCheck = self:GetCurrentBarrelPlacementPos(1)
			
			if(#proximityEnemyBarrels > 0) then
				holdingQ = true
			end
			
			--Current barrel placement
			if(currBarrelPlacement) then
				if GetDistance(currBarrelPlacement, tar.pos) < E.Radius then
					holdingQ = true
				end
			end
			
			if(eCheck ~= nil and myHero.levelData.lvl >= 7) then
				holdingQ = true
			end
			
			if(#proximityBarrels > 0) and myHero:GetSpellData(_E).ammo >= 1 then
				for _, barrel in ipairs(proximityBarrels) do
					if((self:GetBarrelHealth(barrel, 1) <= 2) or myHero.levelData.lvl >= 13) and GetDistance(tar, barrel.barrelObj) <= E.Radius*2.5 then
						holdingQ = true
						break
					end
				end
			end
		end
	end
							
	--Q or AA Barrels on Enemies
	if(self.Menu.Combo.EModules.AutoQ:Value()) then
		if(tar and IsValid(tar)) then
			local proximityBarrels = self:GetBarrelsAroundUnit(tar, E.Radius)
			local anyUnitBarrelCheck, anyUnit = self:IsBarrelOnAnyUnit()
			if(anyUnitBarrelCheck) then
				if(IsValid(anyUnit)) then
					tar = anyUnit
					proximityBarrels = self:GetBarrelsAroundUnit(tar, E.Radius)
				end
			end
			
			if(#proximityBarrels > 0) then
				for _, barrel in ipairs(proximityBarrels) do
					local dist = GetDistance(myHero, barrel.barrelObj)
					if(self:IsBarrelBehindUnit(barrel, tar) == false) then
						if dist < Q.Range and (dist > self.AARange or ((myHero.attackData.endTime-Game.Timer())>(Q.Delay + (GetDistance(myHero, barrel.barrelObj)/Q.Speed)-myHero.attackData.windUpTime) and myHero.activeSpell.name~="GangplankBasicAttack" and myHero.activeSpell.name~="GangplankCritAttack")) and Ready(_Q) then
							--Pred Check
							local delayAmnt = Q.Delay + GetDistance(myHero, barrel.barrelObj)/Q.Speed
							local Delay = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = delayAmnt, Radius = tar.boundingRadius, Range = 1000, Speed = math.huge, Collision = false}
							local Pred = GGPrediction:SpellPrediction(Delay) --Get the targets predicted position
							local predCheck = true
							Pred:GetPrediction(tar, myHero)
							if(Pred.CastPosition) then
								if(GetDistance(barrel.barrelObj, Pred.CastPosition) > E.Radius) then
									predCheck = false
								end
							end
							--
							if(self:GetBarrelHealth(barrel, Q.Delay + dist/Q.Speed + self.Ping - extraReaction) == 1) and predCheck then
								self:SetQBarrel(barrel)
								return
							end
							
						elseif(dist < self.AARange) then
							--Pred Check
							local delayAmnt = myHero.attackData.windUpTime
							local Delay = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = delayAmnt, Radius = tar.boundingRadius, Range = 1000, Speed = math.huge, Collision = false}
							local Pred = GGPrediction:SpellPrediction(Delay) --Get the targets predicted position
							local predCheck = true
							Pred:GetPrediction(tar, myHero)
							if(Pred.CastPosition) then
								if(GetDistance(barrel.barrelObj, Pred.CastPosition) > E.Radius) then
									predCheck = false
								end
							end
							--
							if(self:GetBarrelHealth(barrel, myHero.attackData.windUpTime + self.Ping - extraReaction) == 1) and predCheck then
								self:SetAABarrel(barrel)
								return
							end
							
						else --
					
							--Pred Check
							local delayAmnt = Q.Delay + GetDistance(myHero, barrel.barrelObj)/Q.Speed
							local Delay = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = delayAmnt, Radius = tar.boundingRadius, Range = 1000, Speed = math.huge, Collision = false}
							local Pred = GGPrediction:SpellPrediction(Delay) --Get the targets predicted position
							local predCheck = true
							Pred:GetPrediction(tar, myHero)
							if(Pred.CastPosition) then
								if(GetDistance(barrel.barrelObj, Pred.CastPosition) > E.Radius) then
									predCheck = false
								end
							end
							--
							
							if(self:GetBarrelHealth(barrel, Q.Delay + dist/Q.Speed + self.Ping - extraReaction) == 1 and Ready(_Q)) and predCheck then
								if(dist < Q.Range) then
									self:SetQBarrel(barrel)
									return
								end
							end	
							
						end
					else
						if(self:GetBarrelHealth(barrel) == 1 and Ready(_Q)) then
	
							--Pred Check
							local delayAmnt = Q.Delay + GetDistance(myHero, barrel.barrelObj)/Q.Speed
							local Delay = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = delayAmnt, Radius = tar.boundingRadius, Range = 1000, Speed = math.huge, Collision = false}
							local Pred = GGPrediction:SpellPrediction(Delay) --Get the targets predicted position
							local predCheck = true
							Pred:GetPrediction(tar, myHero)
							if(Pred.CastPosition) then
								if(GetDistance(barrel.barrelObj, Pred.CastPosition) > E.Radius) then
									predCheck = false
								end
							end
							--
							
							if(dist < Q.Range) and predCheck then
								self:SetQBarrel(barrel)
								return
							end
						end						
					end
				end
			end
		end
	end
	
	--Q or AA Chain Barrels on Enemies QUICKATTACK
	if(self.Menu.Combo.EModules.AutoQChain:Value()) then
		if(tar and IsValid(tar)) then
		
			local anyUnitBarrelCheck, anyUnit = self:IsBarrelOnAnyUnit()
			if(anyUnitBarrelCheck) then
				if(IsValid(anyUnit)) then
					tar = anyUnit
				end
			end
			
			local meleeBarrels = self:GetBarrelsAroundUnit(myHero, self.AARange)
			local QBarrels = self:GetBarrelsAroundUnit(myHero, Q.Range)
			local lastCastBarrelPos = self:GetCurrentBarrelPlacementPos()
			local lastCastBarrelPosVec = Vector(lastCastBarrelPos)
			--AA
			if(#meleeBarrels == 1 and lastCastBarrelPos ~= nil) then
				if(GetDistance(lastCastBarrelPosVec, tar) <= E.Radius) then
					local barrel = meleeBarrels[1]
					local EPrediction = GGPrediction:SpellPrediction(E) --Chain barrels have a delay to their explosion
					EPrediction:GetPrediction(tar, myHero)
					if EPrediction.CastPosition then
						if(GetDistance(lastCastBarrelPosVec, barrel.barrelObj) <= E.Radius*2.6 and self:GetBarrelHealth(barrel, myHero.attackData.windUpTime - extraReaction) == 1) then
							self:SetAABarrel(barrel)
							return
						end
					end
				end
			end
			
			--Q
			if(#QBarrels == 1 and #meleeBarrels == 0 and lastCastBarrelPos ~= nil) then
				if(GetDistance(tar, lastCastBarrelPosVec) <= E.Radius) then
					local barrel = QBarrels[1]
					local EPrediction = GGPrediction:SpellPrediction(EStaggered) --Chain barrels have a delay to their explosion
					EPrediction:GetPrediction(tar, myHero)
					if EPrediction.CastPosition then
						if(GetDistance(lastCastBarrelPosVec, barrel.barrelObj) <= E.Radius*2.6 and self:GetBarrelHealth(barrel, Q.Delay + GetDistance(myHero, barrel.barrelObj)/Q.Speed + self.Ping - extraReaction) == 1) then
							self:SetQBarrel(barrel)
							return
						end
					end
				end
			end
		end
	end
	
	--Q or AA Chain Barrels on Enemies
	if(self.Menu.Combo.EModules.AutoQChain:Value()) then
		if(tar and IsValid(tar)) then
		
			local anyUnitBarrelCheck, anyUnit = self:IsBarrelOnAnyUnit()
			if(anyUnitBarrelCheck) then
				if(IsValid(anyUnit)) then
					tar = anyUnit
				end
			end
			
			local chainBarrels = self:GetChainBarrels()
			if(#chainBarrels > 1) then
				local EPrediction, isExtended = GetExtendedSpellPrediction(tar, EStaggered)
				if EPrediction.CastPosition and EPrediction:CanHit(HITCHANCE_NORMAL) then
					local castPos = EPrediction.CastPosition
					if(isExtended) then
						local vec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
						castPos = myHero.pos:Extended(vec, E.Range-15)
					end
					if(self:IsBarrelChainOnPosition(chainBarrels, castPos)) then
						local firstBarrel = nil 	--Furthest away from the target
						local secondBarrel = nil --Second in the triple barrel chain
						if(#chainBarrels >= 2) then
							if(GetDistance(chainBarrels[1].barrelObj, tar) > GetDistance(chainBarrels[2].barrelObj, tar)) then
								firstBarrel = chainBarrels[1]
								secondBarrel = chainBarrels[2]
							else
								firstBarrel = chainBarrels[2]
								secondBarrel = chainBarrels[1]			
							end
						end
						
						--First check if we can hit the second barrel instead if its at (or going to be) 1HP
						if(secondBarrel ~= nil) then
							local dist = GetDistance(myHero, secondBarrel.barrelObj)
							if(dist < Q.Range and dist > self.AARange and Ready(_Q)) then
								if(self:GetBarrelHealth(secondBarrel, Q.Delay + dist/Q.Speed + self.Ping - extraReaction) == 1) then
									self:SetQBarrel(secondBarrel)
									return
								end
							elseif(dist < Q.Range and dist < self.AARange) then
								if(self:GetBarrelHealth(secondBarrel, myHero.attackData.windUpTime - extraReaction) == 1) then
									self:SetAABarrel(secondBarrel)
									return
								end
							end
						end
						
						--Q/AA a barrel if someone is on the chain
						for _, barrel in ipairs(chainBarrels) do
							local dist = GetDistance(myHero, barrel.barrelObj)
							if(dist < Q.Range and dist > self.AARange and Ready(_Q)) then
								if(self:GetBarrelHealth(barrel, Q.Delay + dist/Q.Speed + self.Ping - extraReaction) == 1) then
									self:SetQBarrel(barrel)
									return
								end
							elseif(dist < Q.Range and dist < self.AARange) then
								if(self:GetBarrelHealth(barrel, myHero.attackData.windUpTime - extraReaction) == 1) then
									self:SetAABarrel(barrel)
									return
								end
							end
						end
						
					end
				end
			end
		end
	end
	
	--E MODULES
	if(self.Menu.Combo.UseE:Value() and Ready(_E)) then

		--E on melee enemies
		if(self.Menu.Combo.EModules.EMelee:Value() and isFleeing == false and myHero.levelData.lvl >= 2) then
			if(tarQRange and IsValid(tarQRange)) then
				local chargesCheck = false
				local passiveCheck = true
				if(self:GetBarrelCharges() >= 2 or teamfightOverride) then
					chargesCheck = true
				end
				--Late game we can use melee barrels when we have navoris and our charge is close to coming up
				if(self:GetBarrelCharges() == 1 and self:HasNavori() and myHero:GetSpellData(_E).ammoCurrentCd <= 3) then
					chargesCheck = true
				end
				
				--This logic should let use get our passive AA out before we use a barrel
				if(self:HasPassive() == true and GetDistance(myHero, tarQRange) <= self.AARange) then
					passiveCheck = false
				else
					passiveCheck = true
				end
				
				if(chargesCheck and passiveCheck and IsUnderTurret(myHero) == false) then
					if(GetDistance(myHero, tarQRange) <= self.AARange + 150) then -- Slight extra buffer
					
						local EPrediction = GGPrediction:SpellPrediction(EStaggered)
						EPrediction:GetPrediction(tarQRange, myHero)
						if EPrediction.CastPosition then
							local proximityBarrels = self:GetBarrelsAroundUnit(myHero, E.Radius*2)
							local currentEPos = self:GetCurrentBarrelPlacementPos()
							local overstackingCheck = false
							if(currentEPos) then
								if(GetDistance(currentEPos, EPrediction.CastPosition) <= E.Radius*2) then
									overstackingCheck = true
								end
							end
							if(#proximityBarrels == 0 and overstackingCheck == false) then
								--Place a barrel
								local predVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
								local forwardVec = predVec:Extended(myHero.pos, -100)
								
								--Behind check
								local backwardVec = {x = 0, y = -1} --Behind
								local dirVec = (forwardVec:ToScreen() - tarQRange.pos:ToScreen()):Normalized()
								local res = dotProduct(dirVec, backwardVec)
								--Barrels become easier to attack when they are lower on the screen pos
								if(res >= 0.75) then
									forwardVec = Vector(forwardVec.x, forwardVec.y, forwardVec.z - 275)
								end
								
								Control.CastSpell(HK_E, forwardVec)
								return
							end
						end
					end
				end
			end
		end
		
		--E on enemy clusters
		if(self.Menu.Combo.EModules.EClusters:Value() and (self:GetBarrelCharges() >= 2) or teamfightOverride) and myHero.activeSpell.name ~= "GangplankE" then
			if(tar and IsValid(tar)) then
				local nearbyEnemies = GetEnemiesAtPos(E.Range + E.Radius -10, (E.Radius*2), tar.pos, tar)
				if(#nearbyEnemies >= 2) then
					local bestPos, count = CalculateBestCirclePosition(nearbyEnemies, E.Radius, true, E.Range, E.Speed, E.Delay)
					local proximityBarrels = self:GetBarrelsAroundPosition(bestPos, E.Radius*2.5)
					local nearbyBarrels = self:GetBarrelsAroundUnit(myHero, Q.Range)
					local currentEPos = self:GetCurrentBarrelPlacementPos()
					local overstackingCheck = false
					if(currentEPos) then
						if(GetDistance(currentEPos, bestPos) <= E.Radius*2.5) then
							overstackingCheck = true
						end
					end
					if(#proximityBarrels == 0 and #nearbyBarrels == 0) and myHero.levelData.lvl >= 13 then --This is best used at level 13 with faster barrels
						if(GetDistance(myHero, bestPos) < Q.Range + 150) then 
							Control.CastSpell(HK_E, bestPos)
						end
					end
				end
			end
		end

		--E on CC'd targets
		if(self.Menu.Combo.EModules.AutoECC:Value() and (self:GetBarrelCharges() >= 2 or teamfightOverride)) then
			if(tar and IsValid(tar) and tar.toScreen.onScreen) then
				local proximityBarrels = self:GetBarrelsAroundUnit(tar, E.Radius)
				if(#proximityBarrels == 0) then
					--Interrupt them if they are channeling an interruptible spell
					if(IsHardCCd(tar) >= 0.75) then
						local EPrediction, isExtended = GetExtendedSpellPrediction(tar, E)
						if EPrediction:CanHit(HITCHANCE_NORMAL) then
							local castVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
							Control.CastSpell(HK_E, castVec)
							return
						end
					end
				end
			end
		end
		
		--E on Fleeing Targets
		if(self.Menu.Combo.EModules.EFleeing:Value() and self:GetBarrelCharges() >= 2) then
			if(tar and IsValid(tar) and tar.toScreen.onScreen and isFleeing and myHero.ms >= (tar.ms-10)) then
				if(myHero.levelData.lvl >= 13) then --Only do this with faster tick rate barrels, default is LEVEL 13
					local check = GetUnitRunDirection(tar, myHero) --Gets my run direction relative to the enemy
					local dist = GetDistance(myHero, tar)
					local minDist = self.AARange + 125
					
					if(check == RUNNING_TOWARDS and dist < E.Range - 200 and dist >= minDist) then
						local maxRange = myHero.pos:Extended(tar.pos, E.Range - 10)
						local proximityBarrels = self:GetBarrelsAroundPosition(maxRange, E.Radius * 3)
						local castedBarrelPos = self:GetCurrentBarrelPlacementPos()
						local isOverlapping = false
						if(castedBarrelPos ~= nil) then
							if(GetDistance(castedBarrelPos, tar) > E.Radius * 3 ) then
								isOverlapping = true
							end
						end
						if(#proximityBarrels == 0) and isOverlapping == false then
							local wallCheck = CheckWall(myHero.pos, tar.pos, 1000)
							if(wallCheck == false) then
								Control.CastSpell(HK_E, maxRange)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end
				end
			end
		end
		
		--E Chain Q Barrels
		if(self.Menu.Combo.EModules.EChain:Value() and self:GetBarrelCharges() >= 1 and myHero:GetSpellData(_Q).currentCd <= 0.25) then
			if(tar and IsValid(tar)) then
				local proximityBarrels = self:GetBarrelsAroundUnit(myHero, Q.Range)
				local proximityMeleeBarrels = self:GetBarrelsAroundUnit(myHero, self.AARange)
				local barrelsNearTarget = self:GetBarrelsAroundUnit(tar, E.Radius)
				if(#proximityBarrels >= 1 and #proximityMeleeBarrels == 0 and #barrelsNearTarget == 0) then --First check to see if there are any barrels near us to Q
					for _, barrel in ipairs(proximityBarrels) do
						
						local delayAmnt = E.Delay + Q.Delay + 0.33 + GetDistance(myHero, barrel.barrelObj)/Q.Speed + self.Ping
						local EDelayed = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = delayAmnt, Radius = tar.boundingRadius, Range = 990, Speed = math.huge, Collision = false}
						local EPrediction = GGPrediction:SpellPrediction(EDelayed) --Get the targets predicted position
						EPrediction:GetPrediction(tar, myHero)
						if EPrediction.CastPosition and EPrediction:CanHit(HITCHANCE_HIGH) then
							local castPos = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
							
							--castPos overrides
							local isStrafing, avgPos = StrafePred:IsStrafing(tar)
							if(isStrafing) then
								castPos = avgPos
							end
							
							--AoECheck
							local canAoE, AoEPos = self:GetPossibleAOEBarrel2(tar, barrel)
							if(canAoE) then
								castPos = AoEPos
							end
	
							local currentEPos = self:GetCurrentBarrelPlacementPos()
							local overstackingCheck = false
							if(currentEPos) then
								if(GetDistance(currentEPos, castPos) <= E.Radius*2) then
									overstackingCheck = true
								end
							end
							
							if(self:GetBarrelHealth(barrel, E.Delay + Q.Delay + GetDistance(myHero, barrel.barrelObj)/Q.Speed + self.Ping - extraReaction) == 1) and overstackingCheck == false then
								--We now need to see if we can chain our proximity barrel to the enemy predicted position
								local distCheck = GetDistance(barrel.barrelObj, castPos)
								if(distCheck <= (E.Radius*2.6)) then
									local distanceToPlacement = math.max(math.min(distCheck, (E.Radius - 16)*2), E.Radius*1.60)
									local placementVec = barrel.barrelObj.pos:Extended(castPos, distanceToPlacement)
									if(GetDistance(placementVec, myHero) <= E.Range -10) then
										Control.CastSpell(HK_E, placementVec)
										return
									else
										--Try a closer range in case our extended one goes too far
										distanceToPlacement = math.min(distCheck, (E.Radius - 7.5)*2)
										placementVec = barrel.barrelObj.pos:Extended(castPos, distanceToPlacement)
										if(GetDistance(placementVec, myHero) <= E.Range -10) then
											Control.CastSpell(HK_E, placementVec)
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

		--E Chain AA Barrels (Places a barrel that you AA)
		if(self.Menu.Combo.EModules.EChain:Value() and self:GetBarrelCharges() >= 1 and myHero.attackData.state == STATE_ATTACK) then
			if(tar and IsValid(tar)) then
				local proximityBarrels = self:GetBarrelsAroundUnit(myHero, self.AARange)
				local barrelsNearTarget = self:GetBarrelsAroundUnit(tar, E.Radius)
				if(#proximityBarrels >= 1 and #barrelsNearTarget == 0) then --First check to see if there are any barrels near us to Q
					local delayAmnt = E.Delay + myHero.attackData.windUpTime + 0.33 + self.Ping
					local EDelayed = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = delayAmnt, Radius = tar.boundingRadius, Range = 990, Speed = math.huge, Collision = false}
					local EPrediction = GGPrediction:SpellPrediction(EDelayed) --Get the targets predicted position
					EPrediction:GetPrediction(tar, myHero)
					if EPrediction.CastPosition and EPrediction:CanHit(HITCHANCE_HIGH) then
						for _, barrel in ipairs(proximityBarrels) do
							local castPos = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
							local isStrafing, avgPos = StrafePred:IsStrafing(tar)
							if(isStrafing) then
								castPos = avgPos
							end
							
							--AoECheck
							local canAoE, AoEPos = self:GetPossibleAOEBarrel2(tar, barrel)
							if(canAoE) then
								castPos = AoEPos
							end
							
							local currentEPos = self:GetCurrentBarrelPlacementPos()
							local overstackingCheck = false
							if(currentEPos) then
								if(GetDistance(currentEPos, castPos) <= E.Radius*2) then
									overstackingCheck = true
								end
							end
							
							if(self:GetBarrelHealth(barrel, E.Delay + myHero.attackData.windUpTime + self.Ping - extraReaction) == 1) and overstackingCheck == false then
								--We now need to see if we can chain our proximity barrel to the enemy predicted position
								local distCheck = GetDistance(barrel.barrelObj, castPos)
								if(distCheck <= (E.Radius*2.6)) then
									local distanceToPlacement = math.max(math.min(distCheck, (E.Radius - 7.5)*2), E.Radius*1.60)
									local placementVec = barrel.barrelObj.pos:Extended(castPos, distanceToPlacement)
									if(GetDistance(placementVec, myHero) <= E.Range -10) then
										Control.CastSpell(HK_E, placementVec)
										return
									end
								end
							end
							
						end
					end
				end
			end
		end
		
		--Triple Barrel Combo
		if(self.Menu.Combo.EModules.EChain:Value() and self:GetBarrelCharges() >= 1 and Ready(_Q)) then
			if(tar and IsValid(tar)) then
				local chain = self:GetChainBarrels()
				if(#chain==2) then
					local firstBarrel = nil 	--Furthest away from the target
					local secondBarrel = nil --Second in the triple barrel chain
					
					--Assign by distance
					if(GetDistance(chain[1].barrelObj, tar) > GetDistance(chain[2].barrelObj, tar)) then
						firstBarrel = chain[1]
						secondBarrel = chain[2]
					else
						firstBarrel = chain[2]
						secondBarrel = chain[1]			
					end
					
					local barrelPosCheck = self:GetBarrelsAroundUnit(tar, E.Radius)
					local firstBarrelDist = GetDistance(myHero, firstBarrel.barrelObj)
					local secondBarrelDist = GetDistance(myHero, secondBarrel.barrelObj)
					local tarDist = GetDistance(myHero, tar)
					
					if(#barrelPosCheck == 0) and firstBarrelDist <= Q.Range then
						if(self:GetBarrelHealth(secondBarrel, Q.Delay + secondBarrelDist/Q.Speed + self.Ping - extraReaction) > 1) or (tarDist >= E.Range and tarDist < E.Range + E.Radius) then
							if(secondBarrelDist > Q.Range or tarDist > Q.Range + 50) then
								if(self:GetBarrelHealth(firstBarrel, Q.Delay + firstBarrelDist/Q.Speed + self.Ping - extraReaction) == 1) then
									local delayAmnt = Q.Delay + 0.66 + firstBarrelDist/Q.Speed + self.Ping
									local EDelayed = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = delayAmnt, Radius = tar.boundingRadius, Range = 1000 + E.Radius, Speed = math.huge, Collision = false}
									local EPrediction, isExtended = GetExtendedSpellPrediction(tar, EDelayed)
									if EPrediction.CastPosition and EPrediction:CanHit(HITCHANCE_HIGH) then
										local castPos = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
										
										if(isExtended) then
											local vec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
											castPos = myHero.pos:Extended(vec, E.Range - 20)
										end
							
										local isStrafing, avgPos = StrafePred:IsStrafing(tar)
										if(isStrafing) then
											castPos = avgPos
										end
										
										
										--We now need to see if we can chain our proximity barrel to the enemy predicted position
										local distCheck = GetDistance(secondBarrel.barrelObj, castPos)
										if(distCheck <= (E.Radius*2.75)) then
											local distanceToPlacement = math.min(distCheck, (E.Radius - 7.5)*2)
											local placementVec = secondBarrel.barrelObj.pos:Extended(castPos, distanceToPlacement)
											if(GetDistance(myHero, placementVec) < E.Range - 10) and GetDistance(placementVec, tar) <= E.Radius*0.85 then
												self:SetQBarrel(firstBarrel)
												self:SetTripleBarrelForceE(placementVec, secondBarrel.barrelObj, tar)
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
	
	if(self.Menu.Combo.UseQ:Value() and Ready(_Q) and holdingQ == false) then
		if(tarQRange and IsValid(tarQRange)) then
			local passiveCheck = true
			if(self:HasPassive() and GetDistance(myHero, tarQRange) <= self.AARange + 75) then
				passiveCheck = false
			end
			
			if(GetDistance(myHero, tarQRange) <= Q.Range -15) and passiveCheck and self:CantKill(tarQRange, false, false, true) == false then
				Control.CastSpell(HK_Q, tarQRange)
				return
			end
		end
	end
	
	--[[
	if(self.Menu.Combo.ProwlersSettings.UseProwlersClaw:Value()) then
		local hasProwlers, slot = self:HasProwlers()
		if(hasProwlers) then
			local tar = GetTarget(1000)
			if(tar and IsValid(tar)) then
				if(GetDistance(myHero, tar) <= 500) then
					Control.CastSpell(ItemHotKey[slot], tar)
					return
				end
			end
		end
	end
	
	if(self.Menu.Combo.ProwlersSettings.SemiManualProwler:Value()) then
		local hasProwlers, slot = self:HasProwlers()
		if(hasProwlers) then
			local tar = GetTarget(500) --Prowlers Claw Range
			if(tar and IsValid(tar)) then
				if(Control.IsKeyDown(ItemHotKey[slot])) then
					Control.CastSpell(ItemHotKey[slot], tar)
					return
				end
			end
		end
	end
	--]]

end

function Gangplank:AutoR()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) then return end
	
	if(Ready(_R)) then
		for _, enemy in pairs (Enemies) do
			if(enemy and IsValid(enemy)) then
				local screenCheck = true
				if(self.Menu.AutoRMenu.OnScreenCheck:Value()) then
					if(enemy.toScreen.onScreen) then
						screenCheck = true
					else
						screenCheck = false
					end
				end
				
				if(self.Menu.AutoRMenu.RExecute:Value() and screenCheck) then
					--We should not cast this if the player is nearby, or an ally is nearby
					local shouldCast = true
					if(GetDistance(myHero, enemy) <= E.Range - 150) then
						shouldCast = false
					end
					
					if(HasBuff(enemy, "SummonerDot")) then
						shouldCast = false
					end
					
					for _, ally in ipairs(Allies) do
						if(ally.toScreen.onScreen) then
							if(GetDistance(ally, enemy) <= 900) then
								shouldCast = false
							end
						end
					end
					
					if(shouldCast) then
						local RWaveDmg = self:GetRDamagePerWave()
						local RDmg = CalcMagicalDamage(myHero, enemy, RWaveDmg) * 3
						if(self:HasCollector()) then
							if(enemy.health - RWaveDmg <= 0) then
								if(self.Menu.AutoRMenu.OnScreenCheck:Value()) then
									Control.CastSpell(HK_R, enemy)
								else
									local enemyPos = enemy.pos:ToMM()
									Control.CastSpell(HK_R, enemyPos.x, enemyPos.y)
								end
							end
						else
							if(enemy.health - RWaveDmg <= enemy.maxHealth*0.05) then
								if(self.Menu.AutoRMenu.OnScreenCheck:Value()) then
									Control.CastSpell(HK_R, enemy)
								else
									local enemyPos = enemy.pos:ToMM()
									Control.CastSpell(HK_R, enemyPos.x, enemyPos.y)
								end
							end			
						end
					end
				end
			end
		end
		
		--Team fights worth casting this for would be considered at least 3 enemies and 1 nearby ally
		if(self.Menu.AutoRMenu.RTeamFights:Value()) then
			local enemies = GetEnemyHeroes(E.Range)
			if(#enemies >= 2) then
				local tar = GetTarget(Q.Range)
				if(tar and IsValid(tar)) then
					local screenCheck = true
					if(self.Menu.AutoRMenu.OnScreenCheck:Value()) then
						if(tar.toScreen.onScreen) then
							screenCheck = true
						else
							screenCheck = false
						end
					end
					
					--Ally check
					local allies = GetAllyHeroes(Q.Range)
					if(#allies >= 1) and screenCheck then
						local bestPos, count = CalculateBestCirclePosition(enemies, R.Radius, false, R.Range, math.huge, R.Delay)
						
						if(bestPos and count >= 2) then
							if(self.Menu.AutoRMenu.OnScreenCheck:Value()) then
								Control.CastSpell(HK_R, bestPos)
							else
								local bestPosMM = bestPos:ToMM()
								Control.CastSpell(HK_R, bestPosMM.x, bestPosMM.y)
							end
						end
					end
				end
			end
		end
		
	end
end

function Gangplank:RDuel()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) then return end
	
	local scanRadius = 1500
	local enemies = GetEnemyHeroes(scanRadius)
	local allies = GetAllyHeroes(scanRadius)
	if(#enemies == 1 and #allies == 0) then
		local target = enemies[1]
		if(target and IsValid(target)) then
			--[[
			
			R DUELING:
			
			A series of conditions must be met in order to logically use R to duel.
			The first condition is that it has to be a 1V1 with no other champions around within a scan radius.
			Condition 2: You are within melee range with a small additional buffer, the ult will let you close the gap.
			Condition 3: Your passive is up
			Condition 4: A collective of your Ult + Passive + Auto Attack + Ignite (if available) will kill your target
			Condition 5: You will not OVERKILL, an overkill is defined as the total damage exceeding 50% of their current HP.
								For example, if your combo in total does 1100 damage, and the target has 600HP, that is a 83% Overkill
								If your combo does 1000 damage and the target has 800 remaining HP, that is a 25% overkill and is valid.
			Condition 6: You are above a certain HP% threshold (30%)
			
			R and Ignite can be cast on the same frame, so it's just up the user to auto-attack once to do the entire combo.
			--]]
			if(GetDistance(myHero, target) <= self.AARange + 200) and self:HasPassive() and (myHero.health/myHero.maxHealth >= 0.3) then --Conditions 2, 3, and 6
				local igniteDmg = 0
				if(HasIgnite() and self.Menu.Combo.RDuel.RequireIgnite:Value()) then
					igniteDmg = 50 + (20 * myHero.levelData.lvl)
				end
				local passiveDamage = (200/17 * (myHero.levelData.lvl - 1) + 50) + myHero.bonusDamage + ((myHero.critChance * 100) * 2)
				local AADamage = myHero.totalDamage
				local ultDmg = self:GetRDamagePerWave()
				AADamage = CalcPhysicalDamage(myHero, target, AADamage)
				ultDmg = CalcMagicalDamage(myHero, target, ultDmg) * 3
				
				if(self:HasNavori()) then
					local bonusDmgMod = 1 + (myHero.critChance / 5)
					passiveDamage = passiveDamage * bonusDmgMod
					igniteDmg = igniteDmg * bonusDmgMod
					ultDmg = ultDmg * bonusDmgMod
				end
				local totalDamage = (passiveDamage + ultDmg + igniteDmg + AADamage)
				local overKillCheck = (totalDamage / target.health) >= 1.5
				if(self:HasCollector()) then
					if(overKillCheck == false and target.health - totalDamage <= target.maxHealth*0.05) then
						Control.CastSpell(HK_R, target)
						return
					end
				else
					if(overKillCheck == false and target.health - totalDamage <= 0) then
						Control.CastSpell(HK_R, target)
						UseIgnite(target)
						return
					end
				end
			end
		end
	end
	
end

function Gangplank:Harass()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	if(Ready(_Q) and self.Menu.Harass.UseQ:Value()) then
		local target = GetTarget(Q.Range)
		if(target ~= nil and IsValid(target)) then
			Control.CastSpell(HK_Q, target)
		end
	end
	
end

local avoidQMinionHandle = 0
function Gangplank:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	if(myHero.activeSpell.name:find("GangplankBasicAttack") or myHero.activeSpell.name:find("GangplankCritAttack")) then
		avoidQMinionHandle = myHero.activeSpell.target
	end
	
	if(self.Menu.LastHit.SmartQ:Value() and Ready(_Q)) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) --Just do 1 check for optimization
		local canonMinion = GetCanonMinion(minions)
		
		--Prioritize the canon minion if its low
		if(canonMinion ~= nil) and IsValid(canonMinion) then
			local QDam = self:GetQDamage()
			local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (GetDistance(myHero, canonMinion)/Q.Speed))
			
			if ((hp > 0) and (canonMinion.health + (canonMinion.health*0.05) - QDam <= 0)) and GetDistance(myHero, canonMinion) <= Q.Range and GetDistance(myHero, canonMinion) >= self.AARange + 75 then
				Control.CastSpell(HK_Q, canonMinion)
				gameTick = GameTimer() + 0.2
				return
			end
		end
		
		if(myHero.mana / myHero.maxMana) >= (self.Menu.LastHit.MinimumMana:Value() / 100) then
			for i = 1, #minions do
				local minion = minions[i]
				if(minion and IsValid(minion)) then
					local check = true
					if(avoidQMinionHandle == minion.handle) then
						if _G.SDK.HealthPrediction:GetLastHitTarget().handle == minion.handle then
							check = false
						end
					end
					if(GetDistance(myHero, minion) <= Q.Range and GetDistance(myHero, minion) >= (self.AARange + 75) and check) then
						self:StandardLastHit(minion)
					end
				end
			end
		end
	end
	
end

function Gangplank:StandardLastHit(minion)
	local QDam = self:GetQDamage()
	local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay + (GetDistance(myHero, minion)/Q.Speed))
	if ((hp > 0) and (minion.health + 10 - QDam <= 0) and minion.health/minion.maxHealth <= 0.5) then
		Control.CastSpell(HK_Q, minion)
		gameTick = GameTimer() + 0.2
		return
	end
end

function Gangplank:Clear()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	if(myHero.activeSpell.name:find("GangplankBasicAttack") or myHero.activeSpell.name:find("GangplankCritAttack")) then
		avoidQMinionHandle = myHero.activeSpell.target
	end
	
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(E.Range)
	local canonMinion = GetCanonMinion(minions)
	local extraReaction = self.Menu.ExtraReactionTime:Value() / 1000
	--Barrel Attacking
	if(self.Menu.Clear.UseQAA:Value()) then
		local canAttackCheck = true
		
		if(self.Menu.Clear.SaveAttack:Value()) then
			local checkTarget = GetTarget(E.Radius + E.Range)
			if(checkTarget and IsValid(checkTarget)) then
				canAttackCheck = false
			end
		end
		
		local proximityBarrels = self:GetBarrelsAroundUnit(myHero, Q.Range)
		if(#proximityBarrels >= 1 and canAttackCheck) then
			--Fetch # killable minions first
			local numKillableMinions = 0
			for i = 1, #minions do
				local minion = minions[i]
				if(minion and IsValid(minion)) then
					local qDam = self:GetQDamage()
					if(minion.health - qDam <= 0) or minion.team == TEAM_JUNGLE then
						numKillableMinions = numKillableMinions + 1
					end
				end
			end
			
			for i = 1, #minions do
				local minion = minions[i]
				if(minion and IsValid(minion)) then

					local lastHitCheck = false
					if(numKillableMinions >= self.Menu.Clear.MinMinions:Value()) or minion.team == TEAM_JUNGLE then
						lastHitCheck = true
					end
					
					for _, barrel in ipairs(proximityBarrels) do
						if(GetDistance(barrel.barrelObj, minion) <= E.Radius) and lastHitCheck then
							--AA
							if(GetDistance(barrel.barrelObj, myHero) <= self.AARange) then
								_G.SDK.Orbwalker.ForceTarget = barrel.barrelObj
								_G.SDK.Orbwalker:Attack(barrel.barrelObj)
								return
							else
							--Q
								if(Ready(_Q) and self:GetBarrelHealth(barrel, Q.Delay + GetDistance(barrel.barrelObj, myHero)/Q.Speed + self.Ping - extraReaction) == 1) then
									Control.CastSpell(HK_Q, barrel.barrelObj)
									return
								end
							end
							
						end
					end
				end
			end
		end
	end
	
	if(self.Menu.Clear.SmartQ:Value() and Ready(_Q)) then
		--Prioritize the canon minion if its low, and we have Essence Reaver
		if(canonMinion ~= nil) and IsValid(canonMinion) then
			local QDam = self:GetQDamage()
			local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (GetDistance(myHero, canonMinion)/Q.Speed))
			
			if ((hp > 0) and (canonMinion.health + (canonMinion.health*0.05) - QDam <= 0) and GetDistance(myHero, canonMinion) <= Q.Range) and self:HasEssenceReaver() then
				Control.CastSpell(HK_Q, canonMinion)
				gameTick = GameTimer() + 0.2
				return
			end
		end
		
		if(myHero.mana / myHero.maxMana) >= (self.Menu.Clear.MinimumMana:Value() / 100) then
			for i = 1, #minions do
				local minion = minions[i]
				if(minion and IsValid(minion)) then
					if(GetDistance(myHero, minion) <= Q.Range) then
						if(minion.team == TEAM_JUNGLE) then
							self:JungleClear(minion)
						else
							local check = true
							if(avoidQMinionHandle == minion.handle) then
								if _G.SDK.HealthPrediction:GetLastHitTarget().handle == minion.handle then
									check = false
								end
							end
							if(check) then
								self:StandardClear(minion)
							end
						end
					end
				end
			end
		end
	end
	
	--Barrel Clearing
	if(self.Menu.Clear.UseE:Value() and Ready(_E) and self:GetBarrelCharges() > self.Menu.Clear.MinBarrels:Value()) then
		for i = 1, #minions do
			local minion = minions[i]
			if(minion and IsValid(minion) and minion.pathing.hasMovePath == false) then
				if(minion.team == TEAM_JUNGLE and GetDistance(myHero, minion) <= Q.Range) then
					if(minion.health > self:GetQDamage() + myHero.totalDamage) and minion.name:lower():find("sru_crab")==nil then
						local proximityBarrels = self:GetBarrelsAroundUnit(minion, E.Radius + (E.Radius/2))
						if(#proximityBarrels == 0) then
							local placementVec = minion.pos:Extended(myHero.pos, 100)
							local currBarrelPos = self:GetCurrentBarrelPlacementPos(1)
							if(currBarrelPos) then
								if(GetDistance(currBarrelPos, placementVec) <= E.Radius) then
									Control.CastSpell(HK_E, placementVec)
									return
								end
							else
								Control.CastSpell(HK_E, clusterPos)
								return
							end
						end
					end
				else
					local clusterMinions = GetMinionsAroundMinion(E.Range, E.Radius, minion)
					if(#clusterMinions >= 3) then
						local clusterPos = AverageClusterPosition(clusterMinions)
						if(clusterPos ~= nil) then
							local proximityBarrels = self:GetBarrelsAroundPosition(clusterPos, E.Radius + (E.Radius/2))
							if(#proximityBarrels == 0) then
								local currBarrelPos = self:GetCurrentBarrelPlacementPos(1)
								if(currBarrelPos) then
									if(GetDistance(currBarrelPos, clusterPos) <= E.Radius) then
										Control.CastSpell(HK_E, clusterPos)
										return
									end
								else
									Control.CastSpell(HK_E, clusterPos)
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

function Gangplank:StandardClear(minion)	
	local QDam = self:GetQDamage()
	local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay + (GetDistance(myHero, minion)/Q.Speed))
	local essenceCheck = self:HasEssenceReaver()

	if ((hp > 0) and (minion.health + 10 - QDam <= 0)) then
		if(essenceCheck) then
			Control.CastSpell(HK_Q, minion)
			gameTick = GameTimer() + 0.2
			return
		else
			if(GetDistance(myHero, minion) >= self.AARange +75) and minion.health/minion.maxHealth <= 0.7 then
				Control.CastSpell(HK_Q, minion)
				gameTick = GameTimer() + 0.2
				return
			end
		end
	end
end

function Gangplank:JungleClear(minion)
	Control.CastSpell(HK_Q, minion)
end

local phantomBarrelPlacementPos = nil
local phantomBarrelTarget = nil
local phantomBarrelEnemy = nil
Gangplank.canPlacePhantomE = false
Gangplank.canDoPhantomCombo = false
function Gangplank:PhantomCombo()
	
	if not (myHero.valid or IsValid(myHero)) then return end
	local tar = GetTarget(E.Range+E.Radius) --E Range target
	local extraReaction = self.Menu.ExtraReactionTime:Value() / 1000
	--[[
	The Phantom Combo is when Gangplank uses Q on a max-range barrel, and places a connecting barrel before the Q lands.
	This results in the connecting barrel going off almost instantly and gives the opponent no time to react.
	--]]
	if(self.canDoPhantomCombo == true) then
		_G.SDK.Orbwalker.ForceMovement = nil
		self:ExecutePhantomCombo(phantomBarrelPlacementPos, phantomBarrelTarget, phantomBarrelEnemy)
	else
		_G.SDK.Orbwalker:Orbwalk()
		local meleeTar = GetTarget(self.AARange)
		if(meleeTar and IsValid(meleeTar)) then
			_G.SDK.Orbwalker:Attack(meleeTar)
		end
		--Q Barrels that the target is on
		local canMagnet = true
		if(myHero:GetSpellData(_Q).currentCd < 0.25) then
			if(tar and IsValid(tar)) then
				local barrelsNearTarget = self:GetBarrelsAroundUnit(tar, E.Radius)
				if(#barrelsNearTarget == 1) then
					canMagnet = false
					local barrel = barrelsNearTarget[1]
					local dist = GetDistance(myHero, barrel.barrelObj)
					local delayAmnt = Q.Delay + GetDistance(myHero, barrel.barrelObj)/Q.Speed + self.Ping
					local Delay = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = delayAmnt, Radius = tar.boundingRadius, Range = 1000, Speed = math.huge, Collision = false}
					local Pred = GGPrediction:SpellPrediction(Delay) --Get the targets predicted position
					local predCheck = true
					Pred:GetPrediction(tar, myHero)
					if(Pred.CastPosition) then
						if(GetDistance(barrel.barrelObj, Pred.CastPosition) > E.Radius) then
							predCheck = false
						end
					end
					--
					if(dist <= Q.Range - 10) then
						if(self:GetBarrelHealth(barrel, Q.Delay + dist/Q.Speed + self.Ping - extraReaction) == 1) and predCheck then
							Control.CastSpell(HK_Q, barrel.barrelObj)
							return
						end
					end
				end
			end
		end
		
		if(Ready(_E)) then
		
			--Magnet movement
			if(self.Menu.Combo.ClampPBMovement:Value() and canMagnet) then
				local proximityBarrels = self:GetBarrelsAroundUnit(myHero, Q.Range + 125)
				if(#proximityBarrels == 1) then
					local barrel = proximityBarrels[1]
					local magnetHoverDist = 15
					local extendedPos = barrel.barrelObj.pos:Extended(myHero.pos:Extended(Game.mousePos(), 200), Q.Range + magnetHoverDist)
					_G.SDK.Orbwalker.ForceMovement = extendedPos
				else
					_G.SDK.Orbwalker.ForceMovement = nil
				end
			else
				_G.SDK.Orbwalker.ForceMovement = nil
			end
			--E Chain Barrels
			if(self:GetBarrelCharges() >= 1) then
				if(tar and IsValid(tar)) then
					local proximityBarrels = self:GetBarrelsAroundUnit(myHero, Q.Range + 125)
					local barrelsNearTarget = self:GetBarrelsAroundUnit(tar, E.Radius)
					if(#proximityBarrels >= 1 and #barrelsNearTarget == 0) then --First check to see if there are any barrels near us to Q
						
						local EPrediction, isExtended = GetExtendedSpellPrediction(tar, EStaggered) --Get the targets predicted position
						if EPrediction.CastPosition and EPrediction:CanHit(HITCHANCE_HIGH) then
							local castPos = EPrediction.CastPosition
							if(isExtended) then
								local vec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
								castPos = myHero.pos:Extended(vec, E.Range-15)
							end
							for _, barrel in ipairs(proximityBarrels) do
								local heroDist = GetDistance(myHero, barrel.barrelObj)
								if(heroDist <= Q.Range +125 and heroDist >= Q.Range) then -- THIS ONLY WORKS IF ITS CAST AT THE MAX Q RANGE
									if(self:GetBarrelHealth(barrel, Q.Delay + heroDist/Q.Speed + self.Ping - extraReaction) == 1) then
										local distCheck = GetDistance(barrel.barrelObj, castPos)
										if(distCheck <= (E.Radius*2.5)) then
											local distanceToPlacement = math.min(distCheck, (E.Radius - 7.5)*2)
											local placementVec = barrel.barrelObj.pos:Extended(castPos, distanceToPlacement)
											if(GetDistance(myHero, placementVec) < E.Range) and GetDistance(placementVec, tar) <= E.Radius*0.75 then 
												--The second GetDistance call assures that our placed E isn't too close to the edge
												--We can do the combo!
												phantomBarrelPlacementPos = placementVec
												phantomBarrelTarget = barrel.barrelObj
												phantomBarrelEnemy = tar
												self.canDoPhantomCombo = true
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
	
end

function Gangplank:ExecutePhantomCombo(position, barrelTarget, target)
	_G.SDK.Orbwalker.ForceMovement = nil
	if(target and IsValid(target)) then
		if(Ready(_Q) and self:IsChannelingQ() == false) then
			Control.CastSpell(HK_Q, barrelTarget)
		end
		
		if(Ready(_E) and self:IsChannelingQ() and self.canPlacePhantomE == true) then
			--Do a second pass check on the position to make sure we can't get a better one
			local distCheck = GetDistance(target, barrelTarget)
			local distanceToPlacement = math.min(distCheck, (E.Radius - 7.5)*2)
			local secondPos = barrelTarget.pos:Extended(target.pos, distanceToPlacement)
			if(GetDistance(secondPos, myHero) <= E.Range - 10) then
				local barrelCheck = self:GetBarrelsAroundPosition(secondPos, E.Radius+15)
				if(#barrelCheck == 0) then
					position = secondPos
				end
			end
			
			--AoECheck
			local canAoE, AoEPos = self:GetPossibleAOEBarrel(target, barrelTarget)
			if(canAoE) then
				--Do a second pass check on the position to make sure we can't get a better one
				local distCheck = GetDistance(AoEPos, barrelTarget)
				local distanceToPlacement = math.min(distCheck, (E.Radius - 7.5)*2)
				local secondPos = barrelTarget.pos:Extended(AoEPos, distanceToPlacement)
				if(GetDistance(secondPos, myHero) <= E.Range - 10) then
					position = secondPos
				end
			end
							
			local proximityBarrels = self:GetBarrelsAroundUnit(target, E.Radius+15)
			if(#proximityBarrels == 0) then
				Control.CastSpell(HK_E, position)
			end
		end
		
		if(myHero.activeSpell.name == "GangplankE") then
			self.canPlacePhantomE = false
			self.canDoPhantomCombo = false
			return
		end
	else
		self.canPlacePhantomE = false
		self.canDoPhantomCombo = false
		return
	end

end

function Gangplank:TripleBarrelSemiManual()
	if not (myHero.valid or IsValid(myHero)) then return end
	
	local tar = GetTarget(E.Range + E.Radius - 10)
	local extraReaction = self.Menu.ExtraReactionTime:Value() / 1000
	
	--Second barrel placement
	if(Ready(_E) and Ready(_Q) and self:GetBarrelCharges() >= 2) then
		if(tar and IsValid(tar)) then
			local proximityBarrels = self:GetBarrelsAroundUnit(myHero, E.Range)
			if(#proximityBarrels == 1) then
				local barrel = proximityBarrels[1]
				local barrelDist = GetDistance(myHero, barrel.barrelObj)
				local barrelTarDist = GetDistance(tar, barrel.barrelObj)

				local barrelPosCheck = self:GetBarrelsAroundUnit(tar, E.Radius)
				
				if(#barrelPosCheck == 0) and barrelDist <= Q.Range then
					if(self:GetBarrelHealth(barrel, E.Delay + Q.Delay + 0.24 + self.Ping - extraReaction) == 1) then
						local delayAmnt = Q.Delay + 0.66 + 0.24 + self.Ping
						local EDelayed = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = delayAmnt, Radius = tar.boundingRadius, Range = 1000 + E.Radius, Speed = math.huge, Collision = false}
						local EPrediction, isExtended = GetExtendedSpellPrediction(tar, EDelayed)

						if EPrediction.CastPosition then
							local castPos = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
							if(isExtended) then
								local vec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
								castPos = myHero.pos:Extended(vec, E.Range - 20)
							end

							local placementVec = barrel.barrelObj.pos:Extended(castPos, (E.Radius)*2)
							local distCheck = GetDistance(placementVec, castPos)
							if(distCheck <= (E.Radius*2.75)) then
								local currBarrelPosCheck = self:GetCurrentBarrelPlacementPos(0.5)
								local currCheck = true
								if(currBarrelPosCheck ~= nil) then
									if(GetDistance(placementVec, currBarrelPosCheck) <= E.Radius) then
										currCheck = false
									end
								end
								if(GetDistance(myHero, placementVec) < E.Range - 10) and currCheck then
									Control.CastSpell(HK_E, placementVec)
								end
							end

						end
					end
				end
			end
		end
	end
	
	--Triple Barrel Combo
	if(self:GetBarrelCharges() >= 1 and Ready(_Q)) then
		if(self:GetBarrelCharges() >= 1) then
			if(tar and IsValid(tar)) then
				local chain = self:GetChainBarrels()
				if(#chain==2) then

					local firstBarrel = nil 	--Furthest away from the target
					local secondBarrel = nil --Second in the triple barrel chain
					
					--Assign by distance
					if(GetDistance(chain[1].barrelObj, tar) > GetDistance(chain[2].barrelObj, tar)) then
						firstBarrel = chain[1]
						secondBarrel = chain[2]
					else
						firstBarrel = chain[2]
						secondBarrel = chain[1]			
					end
					local barrelPosCheck = self:GetBarrelsAroundUnit(tar, E.Radius)
					local firstBarrelDist = GetDistance(myHero, firstBarrel.barrelObj)
					local secondBarrelDist = GetDistance(myHero, secondBarrel.barrelObj)
					local tarDist = GetDistance(myHero, tar)

					if(#barrelPosCheck == 0) and firstBarrelDist <= Q.Range then
						if(self:GetBarrelHealth(firstBarrel, Q.Delay + firstBarrelDist/Q.Speed + self.Ping - extraReaction) == 1) then
							local delayAmnt = Q.Delay + 0.66 + firstBarrelDist/Q.Speed + self.Ping
							local EDelayed = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = delayAmnt, Radius = tar.boundingRadius, Range = 1000 + E.Radius, Speed = math.huge, Collision = false}
							local EPrediction, isExtended = GetExtendedSpellPrediction(tar, EDelayed)
							if EPrediction.CastPosition and EPrediction:CanHit(HITCHANCE_HIGH) then
								local castPos = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
								
								if(isExtended) then
									local vec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
									castPos = myHero.pos:Extended(vec, E.Range - 10)
								end
					
								local isStrafing, avgPos = StrafePred:IsStrafing(tar)
								if(isStrafing) then
									castPos = avgPos
								end
								--We now need to see if we can chain our proximity barrel to the enemy predicted position
								local distCheck = GetDistance(secondBarrel.barrelObj, castPos)
								if(distCheck <= (E.Radius*2.75)) then
									local distanceToPlacement = math.min(distCheck, (E.Radius - 10)*2)
									local placementVec = secondBarrel.barrelObj.pos:Extended(castPos, distanceToPlacement)
									if(GetDistance(myHero, placementVec) < E.Range - 10) and GetDistance(placementVec, tar) <= E.Radius*0.75 then
										Control.CastSpell(HK_Q, firstBarrel.barrelObj)
										self:SetTripleBarrelForceE(placementVec, secondBarrel.barrelObj, tar)
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	--Fallback Q for 2-chain
	if(Ready(_Q)) then
		if(tar and IsValid(tar)) then
			local chainBarrels = self:GetChainBarrels()
			if(#chainBarrels > 1) then
				local EPrediction, isExtended = GetExtendedSpellPrediction(tar, EStaggered)
				if EPrediction.CastPosition and EPrediction:CanHit(HITCHANCE_NORMAL) then
					local castPos = EPrediction.CastPosition

					if(self:IsBarrelChainOnPosition(chainBarrels, castPos)) then
						local firstBarrel = nil 	--Furthest away from the target
						local secondBarrel = nil --Second in the triple barrel chain
						if(#chainBarrels == 2) then
							if(GetDistance(chainBarrels[1].barrelObj, tar) > GetDistance(chainBarrels[2].barrelObj, tar)) then
								firstBarrel = chainBarrels[1]
								secondBarrel = chainBarrels[2]
							else
								firstBarrel = chainBarrels[2]
								secondBarrel = chainBarrels[1]			
							end
						end

						--Q/AA a barrel if someone is on the chain
						for _, barrel in ipairs(chainBarrels) do
							local dist = GetDistance(myHero, barrel.barrelObj)
							if(dist < Q.Range) then
								if(self:GetBarrelHealth(barrel, Q.Delay + dist/Q.Speed + self.Ping - extraReaction) == 1) then
									Control.CastSpell(HK_Q, barrel.barrelObj)
									return
								end
							end
						end
						
					end
				end
			end
		end
	end
	
	_G.SDK.Orbwalker:Orbwalk()
end

function Gangplank:KillSteal()
	if(gameTick > GameTimer()) then return end
	
	if(self.Menu.KillSteal.UseQ:Value()) then
		if(Ready(_Q)) then
			local enemies = GetEnemyHeroes(Q.Range)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
						if(self:CantKill(enemy, true, true, false)==false) then
							local dmgCheck = self:GetQDamage()
							local phsDmg = CalcPhysicalDamage(myHero, enemy, dmgCheck)
							if(self:HasCollector()) then --Execute at 5%
								if(enemy.health - phsDmg <= enemy.maxHealth*0.05) then
									Control.CastSpell(HK_Q, enemy)
								end
							else
								if(enemy.health - phsDmg <= 0) then
									Control.CastSpell(HK_Q, enemy)
								end
							end
						end
					end
				end
			end
		end
	end
	
end

function Gangplank:PrimeBarrels()
	if(myHero.levelData.lvl >= 7) then return end
	
	local enemy = GetTarget(Q.Range)
	if(enemy == nil or IsValid(enemy) == false) then
		local proximityBarrels = self:GetBarrelsAroundUnit(myHero, self.AARange)
		if(#proximityBarrels == 1) then
			local barrel = proximityBarrels[1]
			local dist = GetDistance(myHero, barrel.barrelObj)
			if(dist < self.AARange) then
				if(self:GetBarrelHealth(barrel, 0.75) == 3) then
					if(GetMode() == "Combo") then
						self:SetAABarrel(barrel, 3)
						return
					end
				else
					return
				end
			end
		end
	end
end

function Gangplank:AutoECC()
	if(Ready(_E) and self:GetBarrelCharges() >= 1) then
		local enemy = GetTarget(E.Range + E.Radius -10)
		local proximityBarrels = self:GetBarrelsAroundUnit(enemy, E.Radius)
		if(#proximityBarrels == 0) then
			if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
				--Interrupt them if they are channeling an interruptible spell
				if(IsHardCCd(enemy) >= 0.75) then
					local EPrediction, isExtended = GetExtendedSpellPrediction(enemy, E)
					if EPrediction:CanHit(HITCHANCE_NORMAL) then
						local castVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
						Control.CastSpell(HK_E, castVec)
						return
					end
				end
			end
		end
	end
end

function Gangplank:AutoWCleanse()
	local delayAmnt = 0

	--Don't look sussy
	for i = 0, myHero.buffCount do
		local buff = myHero:GetBuff(i)	
		if((buff.name:lower() == "mordekaiserr_statstealenemy" or buff.name:lower() == "mordekaiserr") and buff.count > 0) then
			return
		end
	end
	
	if(self.Menu.AutoWMenu.Humanizer:Value()) then
		delayAmnt = assert(math.max(math.random(150 - self.Ping, 275  - self.Ping), 0))
	end
	
	if(Ready(_W) and (IsHardCCd(myHero) >= 0.5)) then
		DelayAction(function()
			Control.CastSpell(HK_W)					
		end, delayAmnt/1000)
		return
	end
end

function Gangplank:AutoWHeal()
	local hpPercent = self.Menu.AutoWMenu.HealthPercent:Value()
	if(Ready(_W) and myHero.health/myHero.maxHealth <= (hpPercent / 100) and myHero.toScreen.onScreen and IsRecalling(myHero) == false) then
		Control.CastSpell(HK_W)	
	end
end

function Gangplank:CantKill(unit, kill, ss, aa)
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

function Gangplank:GetQDamage()
	local totalDmg = 0
	if(Ready(_Q)) then
		local rawQ = ({10, 40, 70, 100, 130})[myHero:GetSpellData(_Q).level] + (1.0 * myHero.totalDamage)
		
		if(self:HasNavori()) then
			local bonusDmg = 1 + (myHero.critChance / 5)
			rawQ = rawQ * bonusDmg
		end
		local spellbladeDmg = self:GetSpellbladeDamage()
		
		totalDmg = totalDmg + rawQ + spellbladeDmg
	end
	
	return totalDmg
end

function Gangplank:GetRDamagePerWave()
	local totalDmg = 0
	if(Ready(_R)) then
		local rawR = ({40, 70, 100})[myHero:GetSpellData(_R).level] + (0.1 * myHero.ap)
		
		if(self:HasNavori()) then
			local bonusDmg = 1 + (myHero.critChance / 5)
			rawR = rawR * bonusDmg
		end
		
		totalDmg = totalDmg + rawR
	end
	
	return totalDmg
end

function Gangplank:GetBarrelObjects()
	local barrels = {}
	if (Game.mapID == SUMMONERS_RIFT) then
		for i = 0, 7250 do
			local obj = Game.Object(i)
			if obj and not obj.dead and obj.charName == ("GangplankBarrel") then
				table.insert(barrels, obj)
			end
		end
	else -- Howling Abyss
		local objCount = Game.ObjectCount()
		for i = 1, objCount do
			local obj = Game.Object(i)
			if obj and not obj.dead and obj.charName == ("GangplankBarrel") then
				table.insert(barrels, obj)
			end
		end
	end
	
	return barrels
end

function Gangplank:ManualKeys()
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

local alphaLerp = 0
local ERangeSizeLerp = E.Range
function Gangplank:Draw()
	if myHero.dead then return end
	
	if(self.Menu.Drawings.DrawQ:Value()) then
		local color = GetThemeColor("Q")
		if(Ready(_Q)) then
			--DrawCircle(myHero, Q.Range, 2, DrawColor(65, 80, 215, 255)) --(Alpha, R, G, B)
			DrawCircle(myHero, Q.Range, 2, DrawColor(65, color.r, color.g, color.b)) --(Alpha, R, G, B)
		else
			DrawCircle(myHero, Q.Range, 1, DrawColor(15, color.r, color.g, color.b)) --(Alpha, R, G, B)
		end
	end
	
	if(self.Menu.Combo.PhantomBarrelKey:Value()) then
		local uiType = self.Menu.Drawings.DrawPhantomUI:Value()
		if(uiType == 2) then -- Legacy
			DrawCircle(myHero, Q.Range + 50, 3, DrawColor(35, 215, 215, 215)) --(Alpha, R, G, B)
			DrawCircle(myHero, Q.Range + 100, 2, DrawColor(25, 215, 215, 215)) --(Alpha, R, G, B)
			DrawCircle(myHero, Q.Range + 150, 1, DrawColor(15, 215, 215, 215)) --(Alpha, R, G, B)
			DrawCircle(myHero, Q.Range, 5, DrawColor(25, 150, 235, 255)) --(Alpha, R, G, B)
		end
		
		if(uiType == 1) then -- Modern
			local color = GetThemeColor("Q")
			DrawCircle(myHero, ERangeSizeLerp, 1, DrawColor(65*alphaLerp, color.r, color.g, color.b)) --(Alpha, R, G, B)
			if(Ready(_Q) and Ready(_E)) then
				self:DrawPhantomBarrelUI()
			end
			DrawCircle(myHero, Q.Range, 5, DrawColor(25*alphaLerp, 150, 235, 255)) --(Alpha, R, G, B)
			ERangeSizeLerp = Lerp(ERangeSizeLerp, E.Range + E.Radius, 0.03)
			alphaLerp = Lerp(alphaLerp, 1, 0.05)
		end
	else
		ERangeSizeLerp = E.Range
		alphaLerp = 0
	end
	
	if(self.Menu.Drawings.BarrelPlacementVis.DrawBarrelVisualizer:Value() and Ready(_E)) then
		self:DrawBarrelVisualizer()
	end
	
	if(self.Menu.Drawings.DrawE:Value()) then
		local color = GetThemeColor("E")
		DrawCircle(myHero, E.Range, 1, DrawColor(50, color.r, color.g, color.b)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Drawings.DrawPassive:Value()) then
		if(self:HasPassive()) then
			local color = GetThemeColor("Passive")
			DrawCircle(myHero, self.AARange, 3, DrawColor(255, color.r, color.g, color.b)) --(Alpha, R, G, B)
		end
	end
	
	--[[
	if(self.Menu.Drawings.DrawProwlers:Value()) then
		self:DrawProwlersLeap()
	end
	--]]

	if(self.Menu.Drawings.Debug.DrawBarrels:Value()) then
		self:DrawBarrels()
	end
	
	if(self.Menu.Drawings.Debug.DrawParticles:Value()) then
		local particleCount = Game.ParticleCount()
		for i = particleCount, 1, -1 do
			local p = Game.Particle(i)
			if p and p.type == "obj_GeneralParticleEmitter" and p.name:lower():find("aoe_green") then
				DrawText(p.name, 18, p.pos:To2D())
				DrawText(p.networkID, 18, p.pos:To2D() + Vector(0, 20, 0))
			end
		end
	end
	
	if(self.Menu.Drawings.Debug.DrawObjects:Value()) then
		local barrels = self:GetBarrelObjects()
		for _, barrel in pairs(barrels) do
			if barrel and not barrel.dead and barrel.valid then
				DrawText(barrel.name, 18, barrel.pos:To2D())
				DrawText(barrel.networkID, 18, barrel.pos:To2D() + Vector(0, 20, 0))
			end
		end
	end
end

function Gangplank:DrawPhantomBarrelUI()
	local proximityBarrels = self:GetBarrelsAroundUnit(myHero, E.Range + E.Radius)
	local extraReaction = self.Menu.ExtraReactionTime:Value() / 1000
	if(#proximityBarrels >= 1) then
		local barrel = proximityBarrels[1]
		local shouldDraw = true
		local target = GetTarget(E.Range + E.Radius)
		if(target and IsValid(target)) then
			local closestBarrel = self:GetClosestBarrelToUnit(target)
			barrel = closestBarrel
			
			if(GetDistance(barrel.barrelObj, target) <= E.Radius) then
				shouldDraw = false
			end
		end
		
		if(shouldDraw) then
			local xPlacement = myHero.pos:Extended(barrel.barrelObj.pos, Q.Range)
			local UIColor = {a = 255 * alphaLerp, r = 210, g = 145, b = 145}
			local shouldDrawLines = true
			local size = 5
			local line1Start = Vector(xPlacement.x +25, myHero.pos.y, xPlacement.z - 25)
			local line1End = Vector(xPlacement.x -25, myHero.pos.y, xPlacement.z + 25)
			local line2Start = Vector(xPlacement.x - 25, myHero.pos.y, xPlacement.z - 25)
			local line2End = Vector(xPlacement.x + 25, myHero.pos.y, xPlacement.z + 25)
			
			if(GetDistance(myHero, barrel.barrelObj) >= Q.Range) then
				UIColor = {a = 255 * alphaLerp, r = 235, g = 245, b = 65}
			end
			
			local dist = GetDistance(myHero, barrel.barrelObj)
			if(dist >= Q.Range and dist <= Q.Range + 125 or self.canPlacePhantomE == true) then
				shouldDrawLines = false
				UIColor = {a = 255 * alphaLerp, r = 245, g = 245, b = 245}
				
				xPlacement = barrel.barrelObj.pos
				line1Start = Vector(xPlacement.x +25, myHero.pos.y, xPlacement.z - 25)
				line1End = Vector(xPlacement.x -25, myHero.pos.y, xPlacement.z + 25)
				line2Start = Vector(xPlacement.x - 25, myHero.pos.y, xPlacement.z - 25)
				line2End = Vector(xPlacement.x + 25, myHero.pos.y, xPlacement.z + 25)
			
				if(self:GetBarrelHealth(barrel, Q.Delay + dist/Q.Speed + self.Ping - extraReaction) == 1) then
					shouldDrawLines = false
					size = 8
					UIColor = {a = 255 * alphaLerp, r = 75, g = 245, b = 65}
				end
			end
		
			DrawLine(line1Start:To2D(), line1End:To2D(), size, DrawColor(255*alphaLerp, UIColor.r, UIColor.g, UIColor.b))
			DrawLine(line2Start:To2D(), line2End:To2D(), size, DrawColor(255*alphaLerp, UIColor.r, UIColor.g, UIColor.b))
			
			if(shouldDrawLines) then
				self:DrawDotLines(barrel.barrelObj.pos, xPlacement, E.Range, UIColor)
			end
		end
	end
end

function Gangplank:DrawBarrelVisualizer()
	if(self.Menu.Drawings.BarrelPlacementVis.RequireCombo:Value()) then
		if(GetMode() == "Combo" or self.Menu.Combo.TripleBarrelKey:Value() or self.Menu.Combo.PhantomBarrelKey:Value()) then
			--We're gucci
		else
			return
		end
	end
	
	local tar = GetTarget(E.Range + E.Radius)
	if(tar and IsValid(tar)) then
		local nearbyBarrel = self:GetClosestBarrelToUnit(tar)
		local currBarrelPos = self:GetCurrentBarrelPlacementPos(0.25)
		
		local currBarrelCheck = true
		if(currBarrelPos ~= nil) then
			if(GetDistance(tar, currBarrelPos) <= E.Radius) then
				currBarrelCheck = false
			end
		end
		
		if(nearbyBarrel ~= nil) then
			if(GetDistance(tar, nearbyBarrel.barrelObj) > E.Radius) and currBarrelCheck then
				
				local dist = GetDistance(nearbyBarrel.barrelObj, tar)
				local distanceToPlacement = math.min(dist, (E.Radius - 7.5)*2)			
				local placementVec = nearbyBarrel.barrelObj.pos:Extended(tar.pos, distanceToPlacement)
				
				--AoECheck
				local canAoE, AoEPos = self:GetPossibleAOEBarrel2(tar, nearbyBarrel)
				if(canAoE) then
					dist = GetDistance(nearbyBarrel.barrelObj, AoEPos)
					distanceToPlacement = math.min(dist, (E.Radius - 7.5)*2)
					placementVec = nearbyBarrel.barrelObj.pos:Extended(AoEPos, distanceToPlacement)
				end
				local color = GetThemeColor("BarrelVis")
				local alphaMult = self.Menu.Drawings.BarrelPlacementVis.Alpha:Value() / 100
				local UIColor = {a = 200 * alphaMult, r = color.r, g = color.g, b = color.b}
				
				if(self.Menu.Drawings.BarrelPlacementVis.OuterRing:Value()) then
					DrawCircle(placementVec, E.Radius, 1, DrawColor(200 * alphaMult, color.r*0.75, color.g*0.75, color.b*0.75))
				end
				
				if(self.Menu.Drawings.BarrelPlacementVis.InnerRing:Value()) then
					DrawCircle(placementVec, E.Radius*0.66, 5, DrawColor(215 * alphaMult, color.r, color.g, color.b))
				end
				
				if(self.Menu.Drawings.BarrelPlacementVis.Lines:Value()) then
					DrawCircle(placementVec + Vector(0, 20, 0), 2, 10, DrawColor(255 * alphaMult, color.r, color.g, color.b)) -- Center dot
					self:DrawDotLines(nearbyBarrel.barrelObj.pos, placementVec, E.Range, UIColor, 10)
				end
			end
		end
	end
end

function Gangplank:DrawDotLines(pos1, pos2, visibleRange, color, lineCount)
	if(pos1 and pos2) then
		local dist = GetDistance(pos1, pos2)
		local lineAmount = lineCount or 5
		local ratio = dist/visibleRange
		local lineLength = visibleRange / lineAmount
		local offsetSpeed = 100
		for i = 0, lineAmount do
			local offset = ((os.clock() * offsetSpeed) % visibleRange)
			local minDist, maxDist = 0, 0
			if(i ~= 0) then
				maxDist = (lineLength*ratio*i + (lineLength/2)*ratio + offset) % dist
				minDist = math.min((lineLength*ratio*i + offset) % dist, maxDist)
			else
				maxDist = (0 + offset) % dist
				minDist = math.min((lineLength/2)*ratio + offset, maxDist)
			end
			local lineStart = pos1:Extended(pos2, minDist)
			local lineEnd = pos1:Extended(pos2, maxDist)
			DrawLine(lineStart:To2D(), lineEnd:To2D(), 5, DrawColor(color.a, color.r, color.g, color.b))
		end
	end
end

function Gangplank:DrawBarrels()
	for _, barrelTbl in ipairs(self.BarrelData) do
		DrawCircle(barrelTbl.barrelObj.pos + Vector(0, 20, 0), E.Radius, 4, DrawColor(255, 150, 65, 215)) --(Alpha, R, G, B)
	end
end

--[[
function Gangplank:DrawProwlersLeap()
	if(self:HasProwlers()) then
		local tar = GetTarget(E.Range)
		if(tar and IsValid(tar)) then
			local dist = math.min(GetDistance(myHero, tar), 500)
			local lineEnd = myHero.pos:Extended(tar.pos, dist)
			if(GetDistance(myHero, tar) <= 500) then
				local color = GetThemeColor("ProwlersActive")
				DrawLine(myHero.pos:To2D(), lineEnd:To2D(), 4, DrawColor(255, color.r, color.g, color.b))
				DrawCircle(lineEnd, 10, 5,  DrawColor(255, color.r, color.g, color.b))
			else
				local color = GetThemeColor("ProwlersInactive")
				DrawLine(myHero.pos:To2D(), lineEnd:To2D(), 2, DrawColor(155, color.r, color.g, color.b))
				DrawCircle(lineEnd, 10, 5,  DrawColor(155, color.r, color.g, color.b))
			end
		end
	end
end
--]]

function Gangplank:DrawKillReticle(unit)
	local reticleRadius = 75
	local speed = 135
	local newPos = Vector(unit.pos.x, unit.pos.y + 15, unit.pos.z)
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


Gangplank()
LoadUnits()
