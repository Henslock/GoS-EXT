require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.00

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Hwei will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

--[[HEALTH DELTA CLASS]]--

class("HealthDelta")

HealthDelta.deltaHP = 0
local cachedHP = 0
local tickRate = 0.25
local tick = GameTimer()

function HealthDelta:__init()
	if(IsValid(myHero)) then
		cachedHP = myHero.health
	end
    Callback.Add("Tick", function() self:OnTick() end)
end

function HealthDelta:OnTick()

	if(myHero.health == myHero.maxHealth) or (myHero.dead or myHero.health == 0) then 
		HealthDelta.deltaHP = 0 
	end

	if(math.abs(myHero.health - cachedHP) > 10) then
		HealthDelta.deltaHP = (myHero.health - cachedHP)
	end

	if(tick < GameTimer()) then
		HealthDelta.deltaHP = (HealthDelta.deltaHP + (myHero.health - cachedHP))/2

		tick = GameTimer() + tickRate
		cachedHP = myHero.health
	end
end

function HealthDelta:GetHPDelta()
	return HealthDelta.deltaHP
end

HealthDelta()

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Hwei"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/hwei.png"

-- GG PRED

--Q
local QQ = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 1100, Radius = 85, Speed = 1900}
local QW = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.075, Range = 1900, Radius = 205, Speed = math.huge}
local QE = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.7, Range = 1200, Radius = 200, Speed = 1100}

--W
local WW = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.3, Range = 550, Radius = 350, Speed = math.huge}

--E
local EQ = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 1025, Radius = 85, Speed = 1200}
local EW = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Range = 925, Radius = 350, Speed = 1600}
local EE = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.627, Range = 800, Radius = 145, Speed = math.huge}

local R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 1250, Radius = 80, Speed = 1600}

local comboRange = QQ.Range - 150

Hwei.CachedCDs = {
	[_Q] = {0, GameTimer(), 0},
	[_W] = {0, GameTimer(), 0},
	[_E] = {0, GameTimer(), 0},
	[_R] = {0, GameTimer(), 0},
}

Hwei.CachedRanks = {
	[_Q] = 0,
	[_W] = 0,
	[_E] = 0,
	[_R] = 0,	
}

Hwei.WEBuffer = GameTimer()
Hwei.QBuffer = GameTimer()
Hwei.EBuffer = GameTimer()
Hwei.RBuffer = GameTimer()

Hwei.EEDidCast = GameTimer()
Hwei.QEDidCast = GameTimer()
Hwei.QQDidCast = GameTimer()
Hwei.EEPos = nil
Hwei.QEPos = nil
Hwei.QQPos = nil
Hwei.CastingStateBuffer = GameTimer()

Hwei.TempRTarget = nil

Hwei.InterruptableSpells = {
	["CaitlynAceintheHole"] = {Name = "Caitlyn", displayname = "R | Ace in the Hole", spellname = "CaitlynAceintheHole"},
	["FiddleSticksR"] = {Name = "FiddleSticks", displayname = "R | Crowstorm", spellname = "Crowstorm"},
	["FiddleSticksW"] = {Name = "FiddleSticks", displayname = "W | Drain", spellname = "DrainChannel"},
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
	["VarusQ"] = {Name = "Varus", displayname = "Q | Piercing Arrow", spellname = "VarusQ"},
	["VelkozR"] = {Name = "Velkoz", displayname = "R | Lifeform Disintegration Ray", spellname = "VelkozR"},
	["InfiniteDuress"] = {Name = "Warwick", displayname = "R | Infinite Duress", spellname = "InfiniteDuress"},
	["XerathLocusOfPower2"] = {Name = "Xerath", displayname = "R | Rite of the Arcane", spellname = "XerathLocusOfPower2"},
	["JhinR"] = {displayname = "R | Curtain Call", spellname = "JhinR"},
}

--Main Menu
Hwei.Menu = MenuElement({type = MENU, id = "KillerHwei", name = "Killer Hwei", leftIcon=ChampIcon})
Hwei.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

function Hwei:__init()
	self:LoadMenu()
	
	Callback.Add("Tick", function() self:CacheQWDamage() end)
	Callback.Add("Draw", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)

	_G.SDK.Orbwalker:OnPreAttack(function(...) Hwei:OnPreAttack(...) end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) Hwei:OnPostAttack(...) end)

	self:UpdateGoSMenuAutoLevel()
end

function Hwei:LoadMenu()

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "SmartEPop", name = "Smart Pop Passive with E", value = true})
	self.Menu.Combo:MenuElement({id = "SmartEKS", name = "Finish Target with E if Q is Down",  value = true})
	self.Menu.Combo:MenuElement({id = "UseWEStrengthen", name = "Use WE to Strengthen Abilities", value = true})
	self.Menu.Combo:MenuElement({id = "UseWE", name = "Use WE in AA Range", value = true})
	self.Menu.Combo:MenuElement({id = "RSettings", name = "R Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "QWSettings", name = "QW Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "QESettings", name = "QE Settings", type = MENU})
	self.Menu.Combo:MenuElement({name = "=================", type = SPACE})
	self.Menu.Combo:MenuElement({id = "EnablePrioritySwapping", name = "Enable Combo Priority Swapping", value = false})
	self.Menu.Combo:MenuElement({id = "ToggleEQPriority", name = "Toggle EQ Priority in Combo Mode", toggle = true, key = 20, value = false})

		-- R Settings
		self.Menu.Combo.RSettings:MenuElement({id = "UseRToKill", name = "Use R to Kill", value = true})
		self.Menu.Combo.RSettings:MenuElement({id = "ROverkillProtection", name = "Overkill Protection", value = true})
		self.Menu.Combo.RSettings:MenuElement({id = "RCCCheck", name = "Require CC or Close-Proximity Before Casting", value = true})
		self.Menu.Combo.RSettings:MenuElement({id = "UseRAoE", name = "Use R on # Targets", value = 3, min = 1, max = 5})
		self.Menu.Combo.RSettings:MenuElement({id = "Key", name = "Semi-Manual Key", key = string.byte("Z")})
		self.Menu.Combo.RSettings:MenuElement({id = "LogicCheck", name = "Semi-Manual Targetting Type", value = 1, drop = {"Best Target", "Nearest To Cursor"}})
		self.Menu.Combo.RSettings:MenuElement({id = "UseLategameRHardCC", name = "Use Lv.3 R on Hard CC'd Targets", value = true})

		-- QW Settings
		self.Menu.Combo.QWSettings:MenuElement({id = "UseQW", name = "Enable QW in Combo", value = true})
		self.Menu.Combo.QWSettings:MenuElement({id = "PopPassive", name = "Use QW to Pop Passive", value = true})
		self.Menu.Combo.QWSettings:MenuElement({id = "UseCC", name = "Use QW on CCd", value = true})
		self.Menu.Combo.QWSettings:MenuElement({id = "LategamePoke", name = "Lategame Harass", value = true})
		self.Menu.Combo.QWSettings:MenuElement({id = "LevelCheck", name = "Lategame Min Level", value = 13, min = 1, max = 18, step = 1})
		self.Menu.Combo.QWSettings:MenuElement({id = "LategamePokeMana", name = "Lategame Harass Min Mana", value = 60, min = 0, max = 100, step = 5, identifier = "%"})
		self.Menu.Combo.QWSettings:MenuElement({id = "Finisher", name = "Use to Kill Priority Target", value = true})
		self.Menu.Combo.QWSettings:MenuElement({id = "RCombo", name = "Combo with R", value = true})

		-- QE Settings
		self.Menu.Combo.QESettings:MenuElement({id = "UseQE", name = "Enable QE in Combo", value = true})
		self.Menu.Combo.QESettings:MenuElement({id = "UseQEtoKill", name = "(Minion Blocked) Use QE if it Kills", value = true})
		self.Menu.Combo.QESettings:MenuElement({id = "UseQEHardCC", name = "Use QE on Hard CCd Targets", value = true})
		self.Menu.Combo.QESettings:MenuElement({id = "UseQELategame", name = "Use QE through Minions Lategame", value = true})
		self.Menu.Combo.QESettings:MenuElement({id = "LevelCheck", name = "Lategame Min Level", value = 11, min = 1, max = 18, step = 1})
		self.Menu.Combo.QESettings:MenuElement({id = "UseQEAoE", name = "Use QE to AoE", value = true})
		self.Menu.Combo.QESettings:MenuElement({id = "UseQEAoEMinCount", name = "Minimum # of Targets to AoE", value = 3, min = 1, max = 5})

	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "UseWEStrengthen", name = "Use WE to Strengthen Harass", value = true})
	self.Menu.Harass:MenuElement({id = "EnableLategameSniping", name = "Convert into QW Sniping Lategame", value = true})
	self.Menu.Harass:MenuElement({id = "LevelCheck", name = "Convert at Level:", value = 11, min = 1, max = 18, step = 1})

	-- Last Hit
	--self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	--self.Menu.Clear:MenuElement({id = "Lane", name = "Lane", type = MENU})
	self.Menu.Clear:MenuElement({id = "Jungle", name = "Jungle", type = MENU})

		-- Jungle Clear
		self.Menu.Clear.Jungle:MenuElement({id = "UseQE", name = "Use QE", value = true})
		self.Menu.Clear.Jungle:MenuElement({id = "UseWE", name = "Use WE", value = true})
		self.Menu.Clear.Jungle:MenuElement({id = "UseEE", name = "Use EE", value = true})

	-- Flee
	self.Menu:MenuElement({id = "Flee", name = "Flee", type = MENU})
	self.Menu.Flee:MenuElement({id = "UseWQ", name = "Use WQ to Flee", value = true})

	-- Semi-Manual EW
	self.Menu:MenuElement({id = "SMEW", name = "Semi-Manual EW", type = MENU})
	self.Menu.SMEW:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.SMEW:MenuElement({id = "Key", name = "Semi-Manual Key", key = string.byte("C")})
	self.Menu.SMEW:MenuElement({id = "LogicCheck", name = "Semi-Manual Targetting Type", value = 2, drop = {"Best Target", "On Cursor"}})


	-- E Interrupter
	self.Menu:MenuElement({id = "EInterrupter", name = "E Interrupter", type = MENU})
	self.Menu.EInterrupter:MenuElement({id = "UseE", name = "Use E Interrupter",  value = true})
	self.Menu.EInterrupter:MenuElement({id = "HumanizedDelay", name = "Humanized Delay", value = 180, min = 0, max = 1000, step = 10, identifier = "(ms)"})
	self.Menu.EInterrupter:MenuElement({id = "InterruptSpells", name = "Spells to Interrupt", type = MENU})

	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local hero = args.unit
		local charName = args.charName
		--Add interruptible spells
		for spell, args in pairs(self.InterruptableSpells) do
			if(charName == args.Name) then
				self.Menu.EInterrupter.InterruptSpells:MenuElement({id = spell, name = charName .. " - ".. args.displayname, value = true})
			end
		end
	end)

	-- Killsteal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "SmartQKS", name = "Smart Q Kill Steal",  value = true})

	-- Auto Cast
	self.Menu:MenuElement({id = "AutoCast", name = "Auto Cast", type = MENU})
	self.Menu.AutoCast:MenuElement({id = "AntiMeleeEQ", name = "Anti Melee EQ",  value = true})
	self.Menu.AutoCast:MenuElement({id = "AntiDashEQ", name = "Anti Dash EQ",  value = true})
	self.Menu.AutoCast:MenuElement({id = "SmartQCC", name = "QW on Distant CC'd Targets",  value = true})
	self.Menu.AutoCast:MenuElement({id = "SmartECC", name = "Smart E on CC'd Targets",  value = true})
	self.Menu.AutoCast:MenuElement({id = "QWRecall", name = "Use QW on Recalling Targets",  value = true})
	self.Menu.AutoCast:MenuElement({id = "WWSettings", name = "WW Shield Settings", type = MENU})

		-- WW Settings
		self.Menu.AutoCast.WWSettings:MenuElement({id = "WWSave", name = "WW To Save Yourself",  value = true})
		self.Menu.AutoCast.WWSettings:MenuElement({name = "=============",  type = SPACE})
		self.Menu.AutoCast.WWSettings:MenuElement({id = "MinimumHP", name = "Minimum HP% to Consider Using", value = 30, min = 0, max = 100, step = 5, identifier = "%"})
		self.Menu.AutoCast.WWSettings:MenuElement({id = "EnemyCheck", name = "Require No Enemies Around",  value = true})
		self.Menu.AutoCast.WWSettings:MenuElement({id = "TowerCheck", name = "Override if Under Ally Tower",  value = true})


	-- Bonus Semi-manual Keys
	self.Menu:MenuElement({id = "BonusSemiKeys", name = "Bonus Semi-Manual Keys", type = MENU})
	self.Menu.BonusSemiKeys:MenuElement({id = "QE", name = "QE", type = MENU})
	self.Menu.BonusSemiKeys:MenuElement({id = "EQ", name = "EQ", type = MENU})
	self.Menu.BonusSemiKeys:MenuElement({id = "EE", name = "EE", type = MENU})

		--QE
		self.Menu.BonusSemiKeys.QE:MenuElement({id = "Enabled", name = "Enabled",  value = false})
		self.Menu.BonusSemiKeys.QE:MenuElement({id = "Key", name = "Semi-Manual Key", key = string.byte("S")})

		--EQ
		self.Menu.BonusSemiKeys.EQ:MenuElement({id = "Enabled", name = "Enabled",  value = false})
		self.Menu.BonusSemiKeys.EQ:MenuElement({id = "Key", name = "Semi-Manual Key", key = 103})
		self.Menu.BonusSemiKeys.EQ:MenuElement({id = "LogicCheck", name = "Semi-Manual Targetting Type", value = 2, drop = {"Best Target", "Near Cursor"}})

		--EE
		self.Menu.BonusSemiKeys.EE:MenuElement({id = "Enabled", name = "Enabled",  value = false})
		self.Menu.BonusSemiKeys.EE:MenuElement({id = "Key", name = "Semi-Manual Key", key = 104})
		self.Menu.BonusSemiKeys.EE:MenuElement({id = "LogicCheck", name = "Semi-Manual Targetting Type", value = 2, drop = {"Best Target", "Near Cursor"}})

	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawComboRange", name = "Draw Combo Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawQW", name = "Draw QW Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = false})
	self.Menu.Drawings:MenuElement({id = "DrawEQPriority", name = "Draw EQ Priority Toggle", value = false})
	self.Menu.Drawings:MenuElement({id = "DrawEWHelper", name = "Draw EW Helper", value = false})
	self.Menu.Drawings:MenuElement({id = "DrawE", name = "Draw E", value = 1, drop = {"Disabled", "EQ", "EW", "EE"}})
	self.Menu.Drawings:MenuElement({id = "DrawR", name = "Draw R Range", value = true})
	self.Menu.Drawings:MenuElement({id = "EnableDebugMenu", name = "Enable Debug Menu", value = false})

	--AutoLeveler	
	self.Menu:MenuElement({id = "AutoLevel", name = "Auto Leveler", type = MENU})
	self.Menu.AutoLevel:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.AutoLevel:MenuElement({id = "StartingLevel", name = "Start Using At Level:", value = 3, min = 2, max = 18, step = 1})
	self.Menu.AutoLevel:MenuElement({id = "FirstSkill", name = "First Skill Priority", drop = {"Q", "W", "E"}, value = 1, callback = 
	function ()
		DelayEvent(function()
			if(self.Menu.AutoLevel.FirstSkill:Value() == self.Menu.AutoLevel.SecondSkill:Value()) then
				if(self.Menu.AutoLevel.SecondSkill:Value() == 3) then
					self.Menu.AutoLevel.SecondSkill:Value(1)
				else
					self.Menu.AutoLevel.SecondSkill:Value(self.Menu.AutoLevel.FirstSkill:Value() + 1)
				end
			end
			self:UpdateGoSMenuAutoLevel()
		end, 0.15)
	end})

	self.Menu.AutoLevel:MenuElement({id = "SecondSkill", name = "Second Skill Priority", drop = {"Q", "W", "E"}, value = 3, callback = 
	function ()
		DelayEvent(function()
			if(self.Menu.AutoLevel.FirstSkill:Value() == self.Menu.AutoLevel.SecondSkill:Value()) then
				if(self.Menu.AutoLevel.FirstSkill:Value() == 3) then
					self.Menu.AutoLevel.FirstSkill:Value(1)
				else
					self.Menu.AutoLevel.FirstSkill:Value(self.Menu.AutoLevel.SecondSkill:Value() + 1)
				end
			end
			self:UpdateGoSMenuAutoLevel()
		end, 0.15)
	end})
	self.Menu.AutoLevel:MenuElement({id = "InfoText", name = " "})

	self.Menu:MenuElement({id = "DisableInFountain", name = "Disable Orbwalker while in Fountain", value = true})
	
end

function Hwei:UpdateGoSMenuAutoLevel()
	self.Menu.AutoLevel.InfoText:Remove()
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	local thirdSkill = 0
	local enumTable = {1, 2, 3}
	enumTable[firstSkill] = nil
	enumTable[secondSkill] = nil
	for k, v in pairs(enumTable) do
		thirdSkill = v
	end

	local finalString = "Skill Priority:    " .. FetchQWEByValue(firstSkill) .. " -> " .. FetchQWEByValue(secondSkill) .. " -> " .. FetchQWEByValue(thirdSkill)
	self.Menu.AutoLevel:MenuElement({id = "InfoText", name = " ", drop = {finalString}})
end

function Hwei:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Hwei:Tick()
	if(self.Menu.DisableInFountain:Value()) then
		if(IsInFountain() or myHero.dead) then
			_G.SDK.Orbwalker:SetMovement(false)
		else
			_G.SDK.Orbwalker:SetMovement(true)
		end
	else
		_G.SDK.Orbwalker:SetMovement(true)
	end

	if(MyHeroNotReady()) then return end
	
	self:UpdateCachedCDs()
	self:UpdateCachedRanks()
	self:TrackSpellPlacement()
	self:AutoCast()
	self:Killsteal()

	local mode = GetMode()
	if(mode == "Combo") then
		self:Combo()
	elseif(mode == "Harass") then
		self:Harass()
	elseif(mode == "LastHit") then
		self:LastHit()
	elseif(mode == "LaneClear") then
		self:Clear()
	elseif(mode == "Flee") then
		self:Flee()
	end
	
	-- Semi Manual Keys 
	if(self.Menu.SMEW.Enabled:Value() and self.Menu.SMEW.Key:Value()) then
		self:EWSemiManual()
	end

	if(self.Menu.Combo.RSettings.Key:Value()) then
		self:RSemiManual()
	end

	if(self.Menu.BonusSemiKeys.QE.Enabled:Value() and self.Menu.BonusSemiKeys.QE.Key:Value()) then
		self:QESemiManual()
	end

	if(self.Menu.BonusSemiKeys.EQ.Enabled:Value() and self.Menu.BonusSemiKeys.EQ.Key:Value()) then
		self:EQSemiManual()
	end

	if(self.Menu.BonusSemiKeys.EE.Enabled:Value() and self.Menu.BonusSemiKeys.EE.Key:Value()) then
		self:EESemiManual()
	end
	--

	if(self.Menu.EInterrupter.UseE:Value()) then
		self:EInterrupter()
	end

	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end

function Hwei:UpdateCachedCDs()
	if(myHero:GetSpellData(_Q).name == "HweiQ") then
		self.CachedCDs[_Q] = {myHero:GetSpellData(_Q).currentCd, GameTimer(), myHero:GetSpellData(_Q).currentCd}
		self.CachedCDs[_W] = {myHero:GetSpellData(_W).currentCd, GameTimer(), myHero:GetSpellData(_W).currentCd}
		self.CachedCDs[_E] = {myHero:GetSpellData(_E).currentCd, GameTimer(), myHero:GetSpellData(_E).currentCd}
		self.CachedCDs[_R] = {myHero:GetSpellData(_R).currentCd, GameTimer(), myHero:GetSpellData(_R).currentCd}
	else
		self.CachedCDs[_Q][1] = math.max(self.CachedCDs[_Q][3] - (GameTimer() - self.CachedCDs[_Q][2]), 0)
		self.CachedCDs[_W][1] = math.max(self.CachedCDs[_W][3] - (GameTimer() - self.CachedCDs[_W][2]), 0)
		self.CachedCDs[_E][1] = math.max(self.CachedCDs[_E][3] - (GameTimer() - self.CachedCDs[_E][2]), 0)
		self.CachedCDs[_R][1] = math.max(self.CachedCDs[_R][3] - (GameTimer() - self.CachedCDs[_R][2]), 0)
	end
end

function Hwei:UpdateCachedRanks()
	if(myHero:GetSpellData(_Q).name == "HweiQ") then
		self.CachedRanks[_Q] = myHero:GetSpellData(_Q).level
		self.CachedRanks[_W] = myHero:GetSpellData(_W).level
		self.CachedRanks[_E] = myHero:GetSpellData(_E).level
		self.CachedRanks[_R] = myHero:GetSpellData(_R).level
	end
end

function Hwei:TrackSpellPlacement()
	if myHero.activeSpell.name == "HweiEE" then
		self.EEDidCast = GameTimer()
		self.EEPos = {Vector(myHero.activeSpell.placementPos), myHero.pos}
	end

	if myHero.activeSpell.name == "HweiQE" then
		self.QEDidCast = GameTimer()
		self.QEPos = myHero.pos:Extended(Vector(myHero.activeSpell.placementPos), QE.Range - 50)
	end

	if myHero.activeSpell.name == "HweiQQ" then
		self.QQDidCast = GameTimer()
		self.QQPos = myHero.pos:Extended(Vector(myHero.activeSpell.placementPos), 875)
	end

	self:UpdateSpellChecks()
end
function Hwei:UpdateSpellChecks()
	if (GameTimer() - self.EEDidCast > 0.75) then
		self.EEPos = nil
	end

	if (GameTimer() - self.QQDidCast > 0.6) then
		self.QQPos = nil
	end

	if (GameTimer() - self.QEDidCast > 2.25) then
		self.QEPos = nil
	end

	if self.TempRTarget then
		if not IsValid(self.TempRTarget.tar) then
			self.TempRTarget = nil
			return
		end 

		if (GameTimer() - self.TempRTarget.time > 1.25) then
			self.TempRTarget = nil
			return
		end
	end
end

function Hwei:FetchECastPos()
	if(self.EEPos and self.EEPos[1]) then
		return self.EEPos[1]
	end
	return nil
end

function Hwei:IsUnitInEE(unit)
	if IsValid(unit) then
		if(self.EEPos and self.EEPos[1]) then
			local ePos = self.EEPos[1]
			local line = Vector(self.EEPos[2] - ePos):Normalized()
			local lineL = Vector(line.z, line.y, -line.x)
			local lineR = Vector(line.z, line.y, -line.x)
			local rotLineL1 = lineL:Rotated(0, math.rad(22.5), 0)*335 + ePos
			local rotLineR1 = lineR:Rotated(0, math.rad(157.5), 0)*335 + ePos
			local rotLineL2 = lineL:Rotated(0, math.rad(-22.5), 0)*335 + ePos
			local rotLineR2 = lineR:Rotated(0, math.rad(202.5), 0)*335 + ePos

			local predPos = GetPredictedPathPosition(unit, 0.277)
			if not predPos then
				predPos = unit.pos
			end

			local point, isOnSegment = ClosestPointOnLineSegment(predPos, rotLineL1, rotLineR2)
			if(isOnSegment) and GetDistance(point, predPos) < EE.Radius then
				return true
			end

			local point2, isOnSegment2 = ClosestPointOnLineSegment(predPos, rotLineR1, rotLineL2)
			if(isOnSegment2) and GetDistance(point2, predPos) < EE.Radius then
				return true
			end
		end
	end
	return false
end

function Hwei:FetchQECastPos()
	return self.QEPos
end

function Hwei:Ready(slot)
	if self.CachedRanks[slot] == 0 then return false end

	if(Ready(slot)) then
		if(self.CachedCDs[slot][1] <= 0) then
			return true
		end
	end

	return false
end

function Hwei:GetCastingState()
	local sp = myHero:GetSpellData(_Q).name
	local states = {
		["HweiQ"] = 0,
		["HweiQQ"] = 1,
		["HweiWQ"] = 2,
		["HweiEQ"] = 3,
	}
	if(states[sp]) then
		return states[sp]
	else
		return 0
	end

	return 0
end

function Hwei:SetCastingState(state)
	if(self:GetCastingState() == state) then return true end
	if(self.CastingStateBuffer > GameTimer()) then return false end

	local hk_states = {
		[0] = HK_R,
		[1] = HK_Q,
		[2] = HK_W,
		[3] = HK_E,
	}
	if(myHero:GetSpellData(_Q).name == "HweiQ") then
		Control.KeyDown(hk_states[state])
		Control.KeyUp(hk_states[state])

		self.CastingStateBuffer = GameTimer() + 0.1
		return true
	end

	if(myHero:GetSpellData(_Q).name ~= "HweiQ") then
		Control.KeyDown(hk_states[0])
		Control.KeyUp(hk_states[0])
		Control.KeyDown(hk_states[state])
		Control.KeyUp(hk_states[state])
		self.CastingStateBuffer = GameTimer() + 0.1
		return true
	end

	return false
end

function Hwei:CanSetCastingState()
	if(self.CastingStateBuffer > GameTimer()) then return false end
	return true
end

function Hwei:CastSpell(state, spell_slot, pos)
	if not (IsValid(myHero)) or myHero.isChanneling then return false end
	if not self:CanSetCastingState() then return false end
	
	pos = pos or nil 
	if(pos) then
		self:SetCastingState(state)
		Control.CastSpell(spell_slot, pos)
		return true
	else
		self:SetCastingState(state)
		Control.CastSpell(spell_slot)
		return true
	end

	return false
end

function Hwei:CastPredictedSpell(state, spell_slot, args)
	if not (IsValid(myHero)) or myHero.isChanneling then return false end
	if not self:CanSetCastingState() then return false end

	args.ReturnPos = true
	local didCastPos = CastPredictedSpell(args)
	if(didCastPos ~= nil and didCastPos ~= false) then
		self:SetCastingState(state)
		Control.CastSpell(spell_slot, didCastPos)
		return true
	end

	return false
end

function Hwei:CastBestEPos(args)
	if not (IsValid(myHero)) or myHero.isChanneling then return false end
	if not self:CanSetCastingState() then return false end

	--[[
		It is easier to land our EE if we make sure if the larger intersecting area of the two rectangle hitboxes.
		Generally speaking, we check both the left and right positions, and choose the best option.
		If either option aren't within our casting range, we'll default to the normal cast position.
		We will prefer casting at the position that results in the target being dragged to us.
	]]--

	args.ReturnPos = true
	local didCastPos = CastPredictedSpell(args)
	if(didCastPos ~= nil and didCastPos ~= false) then
		didCastPos = Vector(didCastPos)
		--Generate our casting positions that will yield the most Area from EE
		local line = Vector(myHero.pos - didCastPos):Normalized()
		local lineL = Vector(line.z, line.y, -line.x)
		local lineR = Vector(line.z, line.y, -line.x)
		local rotLineL = lineL:Rotated(0, math.rad(22.5), 0)*135 + didCastPos
		local rotLineR = lineR:Rotated(0, math.rad(157.5), 0)*135 + didCastPos

		if(GetDistance(myHero, rotLineL) <= EE.Range and GetDistance(myHero, rotLineR) <= EE.Range) and GetDistance(myHero, args.Target) <= EE.Range + EE.Radius then
			local closetPos = rotLineL
			if(GetDistance(myHero, rotLineL) < GetDistance(myHero, rotLineR)) then
				closetPos = rotLineR
			end

			local qePos = self:FetchQECastPos()
			if(qePos) then
				local point, isOnSegment = ClosestPointOnLineSegment(rotLineL, myHero.pos, qePos)
				if(isOnSegment) and GetDistance(point, rotLineL) < QE.Radius then
					closetPos = point
				end

				local point, isOnSegment = ClosestPointOnLineSegment(rotLineR, myHero.pos, qePos)
				if(isOnSegment) and GetDistance(point, rotLineR) < QE.Radius then
					closetPos = point
				end
			end

			self:SetCastingState(3)
			Control.CastSpell(HK_E, closetPos)
			return true
		else
			if(GetDistance(myHero, args.Target) <= EE.Range + EE.Radius*0.5) then
				self:SetCastingState(3)
				Control.CastSpell(HK_E, didCastPos)
				return true
			else
				return false
			end
		end
	end

	return false
end

function Hwei:OnPreAttack(args)
	if(GetMode() == "Combo") then
		if(self:Ready(_W) and self.Menu.Combo.UseWE:Value()) then
			self:CastWE()
		end
	end
end

function Hwei:OnPostAttack(args)
end


function Hwei:Combo()
	if not (IsValid(myHero)) or myHero.isChanneling then return end
	if(GameTimer() < self.WEBuffer) then return end

	-- R Logic
	if(self:Ready(_R)) then
		if self.Menu.Combo.RSettings.UseRToKill:Value() then
			local tar = GetTarget(R.Range - 50)
			local isOverkill, shouldCheck, safetyCheck = false, false, true
			shouldCheck = self.Menu.Combo.RSettings.ROverkillProtection:Value()

			if(self.Menu.Combo.RSettings.RCCCheck:Value()) then
				if(IsValid(tar)) then
					if(IsImmobile(tar) > 0.5 or GetDistance(tar, myHero) < _G.SDK.Data:GetAutoAttackRange(myHero)) then
						safetyCheck = true
					else
						safetyCheck = false
					end
				end
			end

			if(IsValid(tar) and CantKill(tar, true, false, false, true) == false and GetDistance(myHero, tar) <= R.Range-100) and safetyCheck then

				local hasHorizon = 	self:HasHorizonFocus()
				-- R Cast at a range
				local totalDMG = 0
				totalDMG = totalDMG + self:GetRawAbilityDamage("R")
				if(HasArcaneComet()) then
					totalDMG = totalDMG + GetArcaneCometDamage()
				end
				if(self:HasLudens()) then
					local ludensDmg = GetItemDamage(Item.LudensTempest)
					totalDMG = totalDMG + ludensDmg
				end
				if(self:HasLiandrys()) then
					local liandryDmg = GetItemDamage(Item.LiandrysAnguish, tar)
					totalDMG = totalDMG + liandryDmg
				end
				if(self:HasWEBuff()) then
					totalDMG = totalDMG + self:GetRawAbilityDamage("WE")
				end
				if(self:HasPassiveMark(tar)) then
					totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
				end

				totalDMG = CalcMagicalDamage(myHero, tar, totalDMG)

				if(hasHorizon) then
					totalDMG = totalDMG * 1.1
				end

				if(tar.health - totalDMG <= 0) then

					if(shouldCheck) then
						isOverkill = self:IsROverkill(tar, totalDMG)
					end

					if not isOverkill then
						local ePos = self:FetchECastPos()
						if(ePos ~= nil and ePos ~= false and self:IsUnitInEE(tar)) then --Cast R where the EE will take the target
							self:CastSpell(0, HK_R, ePos)
							SendDebugMsg("Execution R (EE Position) at " .. tar.charName)
							return
						else
							self:CastR({Target = tar, SpellData = R})
							SendDebugMsg("Execution R at " .. tar.charName)
							return
						end
					end
				end

				-- Account for being able to cast WE
				if(self:Ready(_W)) then
					local WEDmg = self:GetRawAbilityDamage("WE")
					WEDmg = CalcMagicalDamage(myHero, tar, WEDmg)

					if tar.health - (totalDMG + WEDmg) <= 0 then
						if(shouldCheck) then
							isOverkill = self:IsROverkill(tar, totalDMG)
						end

						if not isOverkill then
							self:CastWE()
							local ePos = self:FetchECastPos()
							if(ePos ~= nil and ePos ~= false and self:IsUnitInEE(tar)) then --Cast R where the EE will take the target
								self:CastSpell(0, HK_R, ePos)
								SendDebugMsg("Execution R (EE Position) at " .. tar.charName)
								return
							else
								self:CastR({Target = tar, SpellData = R})
								SendDebugMsg("Execution R at " .. tar.charName)
								return
							end
						end
					end
				end

				------------------------
				-- R Cast in Combo Range
				if(GetDistance(myHero, tar) <= comboRange) then
					local QQDmg, EDmg, WEDmg = 0, 0, 0
					if(self:Ready(_Q)) then
						QQDmg = self:GetRawAbilityDamage("QQ", tar)
						QQDmg = CalcMagicalDamage(myHero, tar, QQDmg)
						if hasHorizon then QQDmg = QQDmg * 1.1 end
						totalDMG = totalDMG + QQDmg
					end

					if(self:Ready(_E)) then
						EDmg = self:GetRawAbilityDamage("E")
						EDmg = CalcMagicalDamage(myHero, tar, EDmg)
						if hasHorizon then EDmg = EDmg * 1.1 end
						totalDMG = totalDMG + EDmg
					end

					if(self:Ready(_W)) then
						WEDmg = self:GetRawAbilityDamage("WE")
						WEDmg = CalcMagicalDamage(myHero, tar, WEDmg)
						if hasHorizon then WEDmg = WEDmg * 1.1 end
						totalDMG = totalDMG + (WEDmg*3)
					end

					if(self:HasLudens()) then
						--Ludens will actually pop twice in the full combo, extra damage!
						local ludensDmg = GetItemDamage(Item.LudensTempest)
						ludensDmg = CalcMagicalDamage(myHero, tar, ludensDmg)
						totalDMG = totalDMG + ludensDmg
					end
					
					local passiveDmg = self:GetRawAbilityDamage("Passive")
					passiveDmg = CalcMagicalDamage(myHero, tar, passiveDmg)
					if hasHorizon then passiveDmg = passiveDmg * 1.1 end
					totalDMG = totalDMG + (passiveDmg)

					if tar.health - totalDMG <= 0 then
						if(shouldCheck) then
							isOverkill = self:IsROverkill(tar, totalDMG)
						end

						if not isOverkill then
							local ePos = self:FetchECastPos()
							if(ePos ~= nil and ePos ~= false and self:IsUnitInEE(tar)) then --Cast R where the EE will take the target
								self:CastSpell(0, HK_R, ePos)
								SendDebugMsg("Execution R (Combo Range)(EE Position) at " .. tar.charName)
								return
							else
								self:CastR({Target = tar, SpellData = R})
								SendDebugMsg("Execution R (Combo Range) at " .. tar.charName)
								return
							end
						end
					end
				end

			end
		end

		if self.Menu.Combo.RSettings.UseRAoE:Value() then
			local tar = GetTarget(R.Range - 50)
			if(IsValid(tar) and CantKill(tar, true, false, false, true) == false and GetDistance(myHero, tar) <= R.Range-100) then
				local nearbyEnemies = GetEnemiesAtPos(R.Range + 500, 500, tar.pos, tar)
				local bestPos, count, targets = CalculateBestCirclePosition(nearbyEnemies, 350, false, R.Range, R.Speed, R.Delay)
			

				if(count >= self.Menu.Combo.RSettings.UseRAoE:Value()) then
					self:CastSpell(0, HK_R, bestPos)
					SendDebugMsg("Casting R AoE")
					return
				end

			end
		end

		if self.Menu.Combo.RSettings.UseLategameRHardCC:Value() then
			if(self.CachedRanks[_R] == 3) then
				local enemies = GetEnemyHeroes(R.Range - 50)
				local shouldCheck = self.Menu.Combo.RSettings.ROverkillProtection:Value()
				for _, enemy in ipairs(enemies) do
					if(IsValid(enemy) and enemy.pos:To2D().onScreen and CantKill(enemy, true, false, false) == false) then
						if(IsHardCCd(enemy) > 0.75) then
							if(shouldCheck) then
								local isOverkill = self:IsROverkill(tar, totalDMG)
								if not isOverkill then
									self:CastR({Target = enemy, SpellData = R, UseHeroCollision = true})
									SendDebugMsg("Casting Lategame R on Hard CCd enemy " .. enemy.charName)
									return
								end
							else
								self:CastR({Target = enemy, SpellData = R, UseHeroCollision = true})
								SendDebugMsg("Casting Lategame R on Hard CCd enemy " .. enemy.charName)
								return
							end
						end
					end
				end
			end
		end

	end

	-- Q Logic, Bread and Butter
	if(self:Ready(_Q) and self.Menu.Combo.UseQ:Value()) then
		--QQ
		local tar = GetTarget(comboRange)

		local rTar, rDuration = self:FetchValidRTarget()
		if rTar and IsValid(rTar) then
			if GetDistance(myHero, rTar) <= comboRange then
				tar = rTar
			end
		else
			rTar = nil
		end

		if(IsValid(tar)) then
			--Check QE Logic first
			if(self.Menu.Combo.QESettings.UseQE:Value()) then
				if(self.Menu.Combo.QESettings.UseQEAoE:Value()) then

					local enemies = GetEnemyHeroes(comboRange)
					if #enemies >= self.Menu.Combo.QESettings.UseQEAoEMinCount:Value() then
						local bestPos, count = CalculateBestLinePosition(enemies, QE.Radius - 30, comboRange-75, QE.Speed, QE.Delay)
						local check = true

						if(bestPos) then
							for _, enemy in ipairs(enemies) do
								if not (IsValid(enemy)) then
									check = false
									break
								end
							end
						end

						if(check) and count >= self.Menu.Combo.QESettings.UseQEAoEMinCount:Value() then
							if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
								self:CastWE()
								return
							end

							local didCast = self:CastSpell(1, HK_E, bestPos) --Casting QE
							if didCast then SendDebugMsg("Casting QE for AoE"); return end
						end
					end

				end

				if(self.Menu.Combo.QESettings.UseQEHardCC:Value()) then
					if(IsHardCCd(tar) > 1) then
						if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
							self:CastWE()
						end

						self:CastQE({Target = tar, SpellData = QE})
					end
				end
			end
			--QQ Logic

			--We should hold off using our bread and butter Q combo if we can kil with QW on an ult target
			local shouldHoldQ = false
			if rTar and GetDistance(rTar, myHero) > comboRange then
				local totalDMG = 0
				totalDMG = totalDMG + self:GetRawAbilityDamage("R")
				if(HasArcaneComet()) then
					totalDMG = totalDMG + GetArcaneCometDamage()
				end
				if(self:HasLudens()) then
					local ludensDmg = GetItemDamage(Item.LudensTempest)
					totalDMG = totalDMG + ludensDmg
				end
				if(self:HasLiandrys()) then
					local liandryDmg = GetItemDamage(Item.LiandrysAnguish, rTar)
					totalDMG = totalDMG + liandryDmg
				end
				if(self:HasWEBuff() or (self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true}))) then
					totalDMG = totalDMG + self:GetRawAbilityDamage("WE")
				end
				totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
				totalDMG = CalcMagicalDamage(myHero, rTar, totalDMG)

				totalDMG = totalDMG + CalcMagicalDamage(myHero, rTar, self:GetRawFutureQWDamage(rTar, rTar.health - totalDMG)) --Factor in hitting QW after our combo

				if(rTar.health - totalDMG <= 0) then
					shouldHoldQ = true
				end
			end

			if (not shouldHoldQ) then
				local castPos = CastPredictedSpell({Target = tar, SpellData = QQ, maxCollision = 1, CheckSplashCollision = true, SplashCollisionRadius = 200, ReturnPos = true})
				if(castPos) then
					if(GetDistance(myHero, castPos) <= comboRange) then
						--WE Usage
						if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
							if(self:Ready(_E)) then
								if GetDistance(tar, myHero) <= EE.Range + EE.Radius*0.25 and not shouldntCast then --Account for holding EE
									self:CastWE()
									return
								end
							else
								self:CastWE()
								return
							end
						end

						local shouldWaitForE = false
						if( self.Menu.Combo.UseE:Value()) then
							if(self:Ready(_E)) then
								shouldWaitForE = true
								local shouldUseEQ, shouldntCast = false, false

								if GetDistance(tar, myHero) <= EE.Range + EE.Radius*0.25 then
									if(self.Menu.Combo.EnablePrioritySwapping:Value() and self.Menu.Combo.ToggleEQPriority:Value()) then
										shouldntCast = true
										shouldWaitForE = false
									end

									--Check for conditions to cast EQ
									if(GetDistance(tar, myHero) <= _G.SDK.Data:GetAutoAttackRange(myHero)) then
										shouldUseEQ = true
									end
									local path = tar.pathing
									if path and path.isDashing and tar.posTo then
										if GetDistance(myHero.pos, tar.posTo) < 400 and IsFacing(tar) then
											shouldUseEQ = true
										end
									end
									if path and not path.hasMovePath and tar.isChanneling and IsFacing(tar) then
										if(tar.activeSpell.valid) and math.abs(GameTimer() - tar.activeSpell.castEndTime) > 0.5 then
											shouldUseEQ = true
										end
									end
									if IsImmobile(tar) > 0.5 then
										shouldUseEQ = true
									end
									
									--If we can AoE with EE, we should forego this logic
									local enemyCheck = GetEnemiesAtPos(comboRange, EE.Radius*2, tar.pos, tar)
									if(#enemyCheck >= 2) then
										shouldUseEQ = false
									end
									
									if(shouldUseEQ) then
										local didCast = self:CastEQ({Target = tar, SpellData = EQ})
										if didCast then SendDebugMsg("Casting EQ (QQ Combo) at " .. tar.charName); return end
									else
										if(not shouldntCast) then
											local didCast = self:CastEE({Target = tar, SpellData = EE, ExtendedCheck = true})
											if didCast then SendDebugMsg("Casting EE (QQ Combo) at " .. tar.charName); return end
										end
									end
								end
							end
						end

						if(shouldWaitForE == false) then
							local ePos = self:FetchECastPos()
							if(ePos ~= nil and ePos ~= false and self:IsUnitInEE(tar)) then --Cast Q where the EE will take the target
								local didCast = self:CastSpell(1, HK_Q, ePos)
								if didCast then SendDebugMsg("Casting QQ at EE Pos"); return end
							else
								local didCast = self:CastQQ({Target = tar, SpellData = QQ})
								if didCast then SendDebugMsg("Casting QQ at " .. tar.charName); return end
							end
						end
					end
				else
					--Secondary QE Logic
					--QE if it Kills
					if(self.Menu.Combo.QESettings.UseQE:Value()) then
						if(self.Menu.Combo.QESettings.UseQEtoKill:Value()) then
							--[[
								There's a couple ways we can use QE to kill:
								1. The raw damage with WE may be enough to kill someone
								2. If we are in AA range with WE, we can QE -> AA and kill with passive 
								3. QE into EE (and also WE) may be sufficient damage to kill as well 

								QE is incredibly easy to react to. So option 1 may only be worth pursuing if they are CC'd 
							]]
							--Option 1:
							if (self:Ready(_W) or self:HasWEBuff()) and (GetDistance(myHero, tar) <= comboRange) and GetDistance(myHero, tar) > _G.SDK.Data:GetAutoAttackRange(myHero) then
								if(IsImmobile(tar) >= 0.75) then
									local hasHorizon = 	self:HasHorizonFocus()

									local totalDMG = 0
									totalDMG = totalDMG + self:GetRawAbilityDamage("QE") * 0.65 -- Damper, assuming the target won't take the full damage
									if(HasArcaneComet()) then
										totalDMG = totalDMG + GetArcaneCometDamage()
									end
									if(self:HasLudens()) then
										local ludensDmg = GetItemDamage(Item.LudensTempest)
										totalDMG = totalDMG + ludensDmg
									end
									if(self:HasLiandrys()) then
										local liandryDmg = GetItemDamage(Item.LiandrysAnguish, tar)
										totalDMG = totalDMG + liandryDmg
									end

									totalDMG = totalDMG + self:GetRawAbilityDamage("WE")

									if(self:HasPassiveMark(tar)) then
										totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
									end
					
									totalDMG = CalcMagicalDamage(myHero, tar, totalDMG)
					
									if(hasHorizon) then
										totalDMG = totalDMG * 1.1
									end

									if(tar.health - totalDMG < 0) then
										self:CastQE({Target = tar, SpellData = QE})
										SendDebugMsg("Casting QE to kill (Option 1) on " .. tar.charName)
										return
									end
								end
							end

							--Option 2:
							if (self:Ready(_W) or self:HasWEBuff()) and GetDistance(myHero, tar) <= _G.SDK.Data:GetAutoAttackRange(myHero) then
								local hasHorizon = 	self:HasHorizonFocus()

								local totalDMG = 0
								totalDMG = totalDMG + self:GetRawAbilityDamage("QE") * 0.65 -- Damper, assuming the target won't take the full damage
								if(HasArcaneComet()) then
									totalDMG = totalDMG + GetArcaneCometDamage()
								end
								if(self:HasLudens()) then
									local ludensDmg = GetItemDamage(Item.LudensTempest)
									totalDMG = totalDMG + ludensDmg
								end
								if(self:HasLiandrys()) then
									local liandryDmg = GetItemDamage(Item.LiandrysAnguish, tar)
									totalDMG = totalDMG + liandryDmg
								end

								totalDMG = totalDMG + self:GetRawAbilityDamage("WE")
								totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
				
								totalDMG = CalcMagicalDamage(myHero, tar, totalDMG)
				
								if(hasHorizon) then
									totalDMG = totalDMG * 1.1
								end

								if(tar.health - totalDMG < 0) then
									if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
										self:CastWE()
										return
									end

									self:CastQE({Target = tar, SpellData = QE})
									SendDebugMsg("Casting QE to kill (Option 2) on " .. tar.charName)
									return
								end
							end

							--Option 3:
							if (self:Ready(_E)) and GetDistance(myHero, tar) <= EE.Range then
								local hasHorizon = 	self:HasHorizonFocus()

								local totalDMG = 0
								totalDMG = totalDMG + self:GetRawAbilityDamage("QE") * 0.65 -- Damper, assuming the target won't take the full damage
								totalDMG = totalDMG + self:GetRawAbilityDamage("E")
								if(HasArcaneComet()) then
									totalDMG = totalDMG + GetArcaneCometDamage()
								end
								if(self:HasLudens()) then
									local ludensDmg = GetItemDamage(Item.LudensTempest)
									totalDMG = totalDMG + ludensDmg
								end
								if(self:HasLiandrys()) then
									local liandryDmg = GetItemDamage(Item.LiandrysAnguish, tar)
									totalDMG = totalDMG + liandryDmg
								end

								if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value()) then
									totalDMG = totalDMG + self:GetRawAbilityDamage("WE")
								end

								totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
				
								totalDMG = CalcMagicalDamage(myHero, tar, totalDMG)
				
								if(hasHorizon) then
									totalDMG = totalDMG * 1.1
								end

								if(tar.health - totalDMG < 0) then
									if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
										self:CastWE()
									end

									self:CastQE({Target = tar, SpellData = QE})
									SendDebugMsg("Casting QE to kill (Option 3) on " .. tar.charName)
									return
								end
							end

						end
					end
					--Lategame QE
					if(self.Menu.Combo.QESettings.UseQE:Value()) then
						if(self.Menu.Combo.QESettings.UseQELategame:Value()) then
							if(myHero.levelData.lvl >= self.Menu.Combo.QESettings.LevelCheck:Value()) then
								if(GetDistance(myHero, tar) <= EE.Range) then
									if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
										self:CastWE()
									end
									
									self:CastQE({Target = tar, SpellData = QE})
									SendDebugMsg("Casting QE Lategame - Collision Blocked on " ..tar.charName)
									return
								end
							end
						end
					end

				end
			end
		end
	end
	
	-- E 
	if( self.Menu.Combo.UseE:Value()) then
		if(self:Ready(_E) and self.Menu.Combo.SmartEPop:Value()) then
			local tar = GetTarget(comboRange)
			if(IsValid(tar) and self:HasPassiveMark(tar)) then

				if(GetDistance(tar, myHero) <= EE.Range + EE.Radius*0.25) then

					local shouldUseEQ, shouldntCast = false, false
					if(self.Menu.Combo.EnablePrioritySwapping:Value() and self.Menu.Combo.ToggleEQPriority:Value()) then
						shouldntCast = true
					end
					--Check for conditions to cast EQ
					if(GetDistance(tar, myHero) <= _G.SDK.Data:GetAutoAttackRange(myHero)) then
						shouldUseEQ = true
					end
					local path = tar.pathing
					if path and path.isDashing and tar.posTo then
						if GetDistance(myHero.pos, tar.posTo) < 400 and IsFacing(tar) then
							shouldUseEQ = true
						end
					end
					if path and not path.hasMovePath and tar.isChanneling and IsFacing(tar) then
						if(tar.activeSpell.valid) and math.abs(GameTimer() - tar.activeSpell.castEndTime) > 0.5 then
							shouldUseEQ = true
						end
					end
					if IsImmobile(tar) > 0.5 then
						shouldUseEQ = true
					end

					--If we can AoE with EE, we should forego this logic
					local enemyCheck = GetEnemiesAtPos(comboRange, EE.Radius*2, tar.pos, tar)
					if(#enemyCheck >= 2) then
						shouldUseEQ = false
					end


					if(shouldUseEQ) then
						local didCast = self:CastEQ({Target = tar, SpellData = EQ, maxCollision = 1})
						if didCast then SendDebugMsg("Casting EQ SmartEPop on " .. tar.charName); return end
					else
						if(not shouldntCast) then
							local didCast = self:CastEE({Target = tar, SpellData = EE, ExtendedCheck = true})
							if didCast then SendDebugMsg("Casting EE SmartEPop on " .. tar.charName); return end
						end
					end
				end
			end
		end

		-- Finisher E if Q is down
		if(self:Ready(_E) and self.Menu.Combo.SmartEKS:Value() and not self:Ready(_Q)) then
			local tar = GetTarget(comboRange)
			if(IsValid(tar)) then
				if(GetDistance(tar, myHero) <= EE.Range + EE.Radius*0.25) then
					local hasHorizon = 	self:HasHorizonFocus()
					-- R Cast at a range
					local totalDMG = 0
					totalDMG = totalDMG + self:GetRawAbilityDamage("E")
					if(HasArcaneComet()) then
						totalDMG = totalDMG + GetArcaneCometDamage()
					end
					if(self:HasLudens()) then
						local ludensDmg = GetItemDamage(Item.LudensTempest)
						totalDMG = totalDMG + ludensDmg
					end
					if(self:HasLiandrys()) then
						local liandryDmg = GetItemDamage(Item.LiandrysAnguish, tar)
						totalDMG = totalDMG + liandryDmg
					end
					if(self:HasPassiveMark(tar)) then
						totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
					end
	
					totalDMG = CalcMagicalDamage(myHero, tar, totalDMG)
	
					if(hasHorizon) then
						totalDMG = totalDMG * 1.1
					end

					if(tar.health - totalDMG < 0) then
						local didCast = self:CastEE({Target = tar, SpellData = EE, ExtendedCheck = true})
						if didCast then SendDebugMsg("Casting EE Finisher on " .. tar.charName); return end
					end
				end
			end
		end

		--Suck enemies into QE if its active
		if(self:Ready(_E) and not self:Ready(_Q)) then
			local tar = GetTarget(EE.Range + EE.Radius*0.25)
			if(IsValid(tar)) then
				if(GetDistance(tar, myHero) <= EE.Range + EE.Radius*0.25) then
					local qePos = self:FetchQECastPos()
					if(qePos) then
						local point, isOnSegment = ClosestPointOnLineSegment(tar.pos, myHero.pos, qePos)
						if(isOnSegment) and GetDistance(point, tar.pos) < 290 then -- 335 units is the diagonal reach of EE on one side.
							local didCast = self:CastEE({Target = tar, SpellData = EE, ExtendedCheck = true})
							if didCast then SendDebugMsg("Casting EE to Drag into QE on " .. tar.charName); return end
						end
					end
				end
			end
		end

	end

	-- QW
	if(self:Ready(_Q)) then
		if(self.Menu.Combo.UseQ:Value() and self.Menu.Combo.QWSettings.UseQW:Value()) then
			local tar = GetTarget(QW.Range + QW.Radius*0.2)

			if(self.Menu.Combo.QWSettings.RCombo:Value()) then
				local enemies = GetEnemyHeroes(QW.Range + QW.Radius*0.2)
				for _, enemy in ipairs(enemies) do
					if(IsValid(enemy) and enemy.pos:To2D().onScreen) then
						local hasDebuff, duration = self:HasUltDebuff(enemy)

						local shouldCast = true 
						local castPos = CastPredictedSpell({Target = enemy, SpellData = QQ, maxCollision = 1, CheckSplashCollision = true, SplashCollisionRadius = 200, ReturnPos = true})
						if(castPos and GetDistance(myHero, enemy) < comboRange) then
							shouldCast = false --This means that we can just cast QQ instead
						else
							shouldCast = true
						end

						if(hasDebuff and shouldCast) then
							if(duration < 0.85) then
								
								if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
									self:CastWE()
									return
								end

								local didCast = self:CastQW({Target = enemy, SpellData = QW, ExtendedCheck = true})
								if didCast then SendDebugMsg("Casting QW with R Combo on " .. enemy.charName); return end
							end
						end
					end
				end
			end

			if(self.Menu.Combo.QWSettings.PopPassive:Value()) then

				if(IsValid(tar) and self:HasPassiveMark(tar) and not self:HasUltDebuff(tar) and tar.pos:To2D().onScreen and self:FetchValidRTarget()==nil) then
					local shouldCast = false 

					if(GetDistance(tar, myHero) > comboRange) then
						if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true}) ) then
							self:CastWE()
							return
						end

						local didCast = self:CastQW({Target = tar, SpellData = QW, ExtendedCheck = true})
						if didCast then SendDebugMsg("Casting QW to Pop Passive on " .. tar.charName); return end
					end
				end
			end

			if(self.Menu.Combo.QWSettings.UseCC:Value()) then

				if(IsValid(tar) and not self:HasUltDebuff(tar) and tar.pos:To2D().onScreen) then
					if(IsImmobile(tar) >= 0.5) then
						local shouldCast = true 
						local castPos = CastPredictedSpell({Target = tar, SpellData = QQ, maxCollision = 1, CheckSplashCollision = true, SplashCollisionRadius = 200, ReturnPos = true})
						if(castPos) then
							shouldCast = false --This means that we can just cast QQ instead
						else
							shouldCast = true
						end

						if(GetDistance(tar, myHero) > comboRange) then
							shouldCast = true
						end

						if(shouldCast) then
							if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
								self:CastWE()
								return
							end

							local ePos = self:FetchECastPos()
							if(ePos ~= nil and ePos ~= false and self:IsUnitInEE(tar)) then --Cast QW where the EE will take the target
								self:CastSpell(1, HK_W, ePos)
								SendDebugMsg("Casting QW on CC Target, BIAS to EE: " .. tar.charName)
								return
							else
								local didCast = self:CastQW({Target = tar, SpellData = QW, ExtendedCheck = true})
								if didCast then SendDebugMsg("Casting QW on CC Target: " .. tar.charName); return end
							end
						end
					end
				end
			end

			if(self.Menu.Combo.QWSettings.LategamePoke:Value()) then

				if(IsValid(tar) and not self:HasUltDebuff(tar) and tar.pos:To2D().onScreen and self:FetchValidRTarget()==nil) then
					if(GetDistance(tar, myHero) > comboRange) then
						if(myHero.levelData.lvl >= self.Menu.Combo.QWSettings.LevelCheck:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Combo.QWSettings.LategamePokeMana:Value() / 100)) then
							local totalDMG = self:GetCachedQWDamage(tar)
							if(totalDMG/tar.maxHealth >= 0.25 or tar.health/tar.maxHealth <= 0.7) or tar.isChanneling then
								local shouldCast = false
								if IsImmobile(tar) > 0.5 or (not tar.pathing.hasMovePath and tar.isChanneling) or tar.health/tar.maxHealth <= 0.3 then
									shouldCast = true
								end

								if shouldCast then
									if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
										self:CastWE()
										return
									end

									local didCast = self:CastQW({Target = tar, SpellData = QW, ExtendedCheck = true})
									if didCast then SendDebugMsg("Casting QW Late Game Poke on " .. tar.charName); return end
								end
							end
						end
					end
				end
			end

			if(self.Menu.Combo.QWSettings.Finisher:Value()) then

				if(IsValid(tar) and tar.pos:To2D().onScreen) then
					if(GetDistance(tar, myHero) > comboRange) then
						if(tar.health - self:GetCachedQWDamage(tar) < 0) then
							if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
								self:CastWE()
								return
							end

							local didCast = self:CastQW({Target = tar, SpellData = QW, ExtendedCheck = true})
							if didCast then SendDebugMsg("Casting QW Finisher on " .. tar.charName); return end
						end
					end
				end
			end
		end
	end

end

function Hwei:Harass()
	if not (IsValid(myHero)) or myHero.isChanneling then return end
	if(GameTimer() < self.WEBuffer) then return end

	if(self.Menu.Harass.UseQ:Value()) then
		if(self:Ready(_Q)) then

			local tar = GetTarget(comboRange)
			if(IsValid(tar)) then
				--QQ Logic
				local castPos = CastPredictedSpell({Target = tar, SpellData = QQ, maxCollision = 1, CheckSplashCollision = true, SplashCollisionRadius = 200, ReturnPos = true})
				if(castPos) then
					if(GetDistance(myHero, castPos) <= comboRange and GetDistance(myHero, tar) <= comboRange) then
						if(self:Ready(_W) and self.Menu.Harass.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
							self:CastWE()
							return
						end						

						local didCast = self:CastQQ({Target = tar, SpellData = QQ})
						if didCast then SendDebugMsg("Harass QQ at " .. tar.charName); return end
					else
						local qwTar = GetTarget(QW.Range)
						if(IsValid(qwTar)) then
							if(self.Menu.Harass.EnableLategameSniping:Value() and myHero.levelData.lvl >= self.Menu.Harass.LevelCheck:Value()) then
								if(GetDistance(myHero, qwTar) > comboRange) then
									if(self:Ready(_W) and self.Menu.Harass.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
										self:CastWE()
										return
									end						
		
									local didCast = self:CastQW({Target = qwTar, SpellData = QW, ExtendedCheck = true})
									if didCast then SendDebugMsg("Harass QW Lategame Sniping at " .. tar.charName); return end
								end
							end
						end
					end
				else
					local qwTar = GetTarget(QW.Range)
					if(IsValid(qwTar)) then
						if(self.Menu.Harass.EnableLategameSniping:Value() and myHero.levelData.lvl >= self.Menu.Harass.LevelCheck:Value()) then
							if(GetDistance(myHero, qwTar) > comboRange) then
								if(self:Ready(_W) and self.Menu.Harass.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
									self:CastWE()
									return
								end						

								local didCast = self:CastQW({Target = qwTar, SpellData = QW, ExtendedCheck = true})
								if didCast then SendDebugMsg("Harass QW Lategame Sniping at " .. tar.charName); return end
							end
						end
					end
				end
			end

			--QW Sniping
			if(self.Menu.Harass.EnableLategameSniping:Value() and myHero.levelData.lvl >= self.Menu.Harass.LevelCheck:Value()) then
				local qwTar = GetTarget(QW.Range)
				if(IsValid(qwTar)) then
					if(GetDistance(myHero, qwTar) > comboRange) then
						if(self:Ready(_W) and self.Menu.Harass.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
							self:CastWE()
							return
						end						

						local didCast = self:CastQW({Target = qwTar, SpellData = QW, ExtendedCheck = true})
						if didCast then SendDebugMsg("Harass QW Lategame Sniping at " .. tar.charName); return end
					end
				end
			end

		end
	end
end

function Hwei:LastHit()
	if not (IsValid(myHero)) or myHero.isChanneling then return end

end

function Hwei:Clear()
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(QQ.Range)
	local jungleMinions = {}
	local laneMinions = {}
	for i = 1, #minions do
		local minion = minions[i]
		if(IsValid(minion) and minion.pos:ToScreen().onScreen) then
			if(minion.team == TEAM_JUNGLE) then
				table.insert(jungleMinions, minion)
			else
				table.insert(laneMinions, minion)
			end
		end
	end

	if(#jungleMinions > 0) and (#laneMinions == 0) and IsUnderFriendlyTurret(myHero) == false and IsUnderTurret(myHero) == false then
		self:JungleClear(jungleMinions)
	end

	if(#laneMinions > 0) then
		self:LaneClear(laneMinions)
	end
end

function Hwei:JungleClear(minions)

	if(#minions == 1) then
		if(minions[1].health < myHero.totalDamage*2) then
			-- Don't waste abilities on almost dead mobs
			return 
		end
	end


	if(self.Menu.Clear.Jungle.UseQE:Value() and self:Ready(_Q)) then
		if(minions[1].charName == "Sru_Crab" and #minions == 1) then --Scuttle Crab is really the only monster we want to use QQ on because it moves.
			if(self.Menu.Clear.Jungle.UseWE:Value() and self:Ready(_W)) then
				self:CastWE()
				return
			end

			local qPred = GGPrediction:SpellPrediction(QQ)
			qPred:GetPrediction(minions[1], myHero)
			if qPred.CastPosition and qPred:CanHit(HITCHANCE_NORMAL) then
				if Vector(qPred.CastPosition):To2D().onScreen then
					self:CastSpell(1, HK_Q, qPred.CastPosition)
					return
				end
			end	
		
		else
			local bestPos, count = CalculateBestLinePosition(minions, QE.Radius, EE.Range, QE.Speed, QE.Delay)
			if(bestPos) and GetDistance(bestPos, myHero.pos) < EE.Range then
				if(self.Menu.Clear.Jungle.UseWE:Value() and self:Ready(_W)) then
					self:CastWE()
					return
				end
	
				self:CastSpell(1, HK_E, bestPos)
				return
			end
		end
	end

	if(self.Menu.Clear.Jungle.UseEE:Value() and self:Ready(_E)) then
		
		local bestPos, count = CalculateBestCirclePosition(minions, EE.Radius+75, false, EE.Range, EE.Speed, EE.Delay)
		if(bestPos) and GetDistance(bestPos, myHero.pos) < EE.Range then
			if(self.Menu.Clear.Jungle.UseWE:Value() and self:Ready(_W)) then
				self:CastWE()
				return
			end

			self:CastSpell(3, HK_E, bestPos)
			return
		end
	end
end

function Hwei:LaneClear(minions)
end

function Hwei:Flee()
	if not (IsValid(myHero)) or myHero.isChanneling then return end
	if IsInFountain() then return end
	if(self.Menu.Flee.UseWQ:Value()) then
		if(self:Ready(_W)) then
			self:CastWQ()
		end
	end
end

function Hwei:FetchValidRTarget()
	if(self.TempRTarget and IsValid(self.TempRTarget.tar)) then
		return self.TempRTarget.tar
	end

	for _, enemy in ipairs(Enemies) do
		if IsValid(enemy) then
			if(self:HasUltDebuff(enemy)) then
				return enemy
			end
		end
	end

	return nil
end

function Hwei:CastQQ(args)
	if(self.QBuffer < GameTimer()) then
		args.Hotkey = HK_Q
		local didCast = self:CastPredictedSpell(1, HK_Q, args)
		if(didCast) then
			self.QBuffer = GameTimer() + 0.1
		end
		return didCast
	end	
	return false
end

function Hwei:CastQW(args)
	if(self.QBuffer < GameTimer()) then
		args.Hotkey = HK_W
		args.CheckTerrain = true
		local didCast = self:CastPredictedSpell(1, HK_W, args)
		if(didCast) then
			self.QBuffer = GameTimer() + 0.1
		end
		return didCast
	end	
	return false
end

function Hwei:CastQE(args)
	if(self.QBuffer < GameTimer()) then
		args.Hotkey = HK_E
		local didCast = self:CastPredictedSpell(1, HK_E, args)
		if(didCast) then
			self.QBuffer = GameTimer() + 0.1
		end
		return didCast
	end	
	return false
end

function Hwei:CastWQ()
	return self:CastSpell(2, HK_Q)
end
function Hwei:CastWW(pos)
	if not pos then
		return self:CastSpell(2, HK_W)
	else
		return self:CastSpell(2, HK_W, pos)
	end
end

function Hwei:CastWE()
	local didCast = self:CastSpell(2, HK_E)
	if(didCast) then
		self.WEBuffer = GameTimer() + 0.06
	end
	return didCast
end

function Hwei:CastEQ(args)
	if(self.EBuffer < GameTimer()) then
		args.Hotkey = HK_Q
		local didCast = self:CastPredictedSpell(3, HK_Q, args)
		if(didCast) then
			self.EBuffer = GameTimer() + 0.1
		end
		return didCast
	end	
	return false
end

function Hwei:CastEW(args)
	if(self.EBuffer < GameTimer()) then
		args.Hotkey = HK_W
		local didCast = self:CastPredictedSpell(3, HK_W, args)
		if(didCast) then
			self.EBuffer = GameTimer() + 0.1
		end
		return didCast
	end	
	return false
end

function Hwei:CastEE(args)
	if(self.EBuffer < GameTimer()) then
		args.Hotkey = HK_E
		local didCast = self:CastBestEPos(args)
		if(didCast) then
			self.EBuffer = GameTimer() + 0.1
		end
		return didCast
	end	
	return false
end

function Hwei:CastR(args)
	if(self.RBuffer < GameTimer()) then
		args.Hotkey = HK_R
		local didCast = self:CastPredictedSpell(0, HK_R, args)
		if(didCast) then
			if(args.Target) then
				self.TempRTarget = {tar = args.Target, time = GameTimer()}
			end
			self.RBuffer = GameTimer() + 0.1
		end
		return didCast
	end
	return false
end

Hwei.CachedQWDmg = {}
Hwei.CachedQWTick = GameTimer()

function Hwei:GetCachedQWDamage(unit)
	if unit and self.CachedQWDmg[unit.networkID] then
		return self.CachedQWDmg[unit.networkID]
	end 
	return 0
end

function Hwei:CacheQWDamage()
	if self.CachedQWTick > GameTimer() then return end

	for _, enemy in ipairs(Enemies) do
		if(IsValid(enemy)) then
			local totalDMG = 0

			totalDMG = totalDMG + self:GetRawAbilityDamage("QW", enemy)
			if(HasArcaneComet()) then
				totalDMG = totalDMG + GetArcaneCometDamage()
			end
			if(self:HasLudens()) then
				local ludensDmg = GetItemDamage(Item.LudensTempest)
				totalDMG = totalDMG + ludensDmg
			end
			if(self:HasLiandrys()) then
				local liandryDmg = GetItemDamage(Item.LiandrysAnguish, enemy)
				totalDMG = totalDMG + liandryDmg
			end
			if(self:HasWEBuff() or (self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true}))) then
				totalDMG = totalDMG + self:GetRawAbilityDamage("WE")
			end
			if(self:HasPassiveMark(enemy)) then
				totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
			end

			totalDMG = CalcMagicalDamage(myHero, enemy, totalDMG)

			if(self:HasHorizonFocus()) then
				totalDMG = totalDMG * 1.1
			end
			
			self.CachedQWDmg[enemy.networkID] = totalDMG
		end
	end

	self.CachedQWTick = GameTimer() + 0.2
end

function Hwei:IsActiveQQ(unit)
	--This is mostly logic for your R Overkill check. It's to see if you are actively flinging a Q at a target that would die from it.

	if(self.QQPos) then
		local dp = dotProduct(Vector(unit.pos - myHero.pos):Normalized(), Vector(self.QQPos - myHero.pos):Normalized())
		if dp > 0.75 then
			return true
		end
	end

	return false
end

function Hwei:IsROverkill(unit, damageAmnt)
	--[[

	Conditions for an Overkill:
	- There are other allies near the target, and the target is below a certain %HP threshold.
	- Your Q or E are up, you are within range of the target, and they will kill the target.
	]]
	if(IsValid(unit)) then
		local allies = GetAllyHeroes(QQ.Range)
		if(#allies >= 1) then
			local isAllyNear = false
			for _, ally in ipairs(allies) do
				if(ally.range > 300) then -- Ranged Ally
					if(GetDistance(ally, unit) <= 700) then
						--Ally is near target.
						isAllyNear = true
						break;
					end 
				else -- Melee Ally
					if(GetDistance(ally, unit) <= 400) then
						--Ally is near target.
						isAllyNear = true
						break;
					end 
				end
			end

			if(isAllyNear) then
				if(unit.health/unit.maxHealth <= 0.20) then
					return true --Overkill
				end
			end
		end

		local QQDmg, EDmg, PassiveDmg = 0, 0, 0
		if(self:Ready(_Q) and GetDistance(myHero, unit) < QQ.Range - 125) or self:IsActiveQQ(unit) then
			QQDmg = self:GetRawAbilityDamage("QQ", unit)
			QQDmg = CalcMagicalDamage(myHero, unit, QQDmg)
		end

		if(self:Ready(_E) and GetDistance(myHero, unit) < EE.Range) or self:IsUnitInEE(unit) then
			EDmg = self:GetRawAbilityDamage("E", unit)
			EDmg = CalcMagicalDamage(myHero, unit, EDmg)
		end

		if(self:HasPassiveMark(unit)) then
			PassiveDmg = self:GetRawAbilityDamage("Passive")
			PassiveDmg = CalcMagicalDamage(myHero, unit, PassiveDmg)
		end

		if(unit.health - (QQDmg + EDmg + PassiveDmg) <= 0) then
			return true
		end

		if(unit.health/unit.maxHealth < 0.05) then
			return true
		end

	end

	return false
end

function Hwei:RSemiManual()
	if not (IsValid(myHero)) or myHero.isChanneling then return end
	_G.SDK.Orbwalker:Orbwalk()

	if(self:Ready(_R)) then
		local type = self.Menu.Combo.RSettings.LogicCheck:Value()
		if(type == 1) then --Best Target
			local tar = GetTarget(R.Range)
			if(IsValid(tar)) then
				self:CastR({Target = tar, SpellData = R})
				SendDebugMsg("Semi-Manual R on " .. tar.charName)
				return
			end
		else
			-- Near Cursor
			local enemies = GetEnemyHeroes(R.Range)
			local closestUnit = GetClosestUnitToCursor(enemies)
			if IsValid(closestUnit) then
				self:CastR({Target = closestUnit, SpellData = R})
				SendDebugMsg("Semi-Manual towards Cursor")
				return
			end
		end
	end
end

function Hwei:EWSemiManual()
	if not (IsValid(myHero)) or myHero.isChanneling then return end
	_G.SDK.Orbwalker:Orbwalk()

	if(self:Ready(_E)) then
		local type = self.Menu.SMEW.LogicCheck:Value()
		if(type == 1) then --Best Target
			local tar = GetTarget(EW.Range + EW.Radius - 75)
			if(IsValid(tar)) then
				self:CastEW({Target = tar, SpellData = R, ExtendedCheck = true})
				SendDebugMsg("Semi-Manual EW on " .. tar.charName)
			end
		else
			if(GetDistance(myHero, Game.mousePos()) < EW.Range) then
				self:CastSpell(3, HK_W, Game.mousePos())
				SendDebugMsg("Semi-Manual EW towards Cursor")
			else
				DrawCircle(Game.mousePos(), EW.Radius, 5, DrawColor(55, 255, 255, 255))
				DrawLine(myHero.pos:Extended(Game.mousePos(), EW.Range):To2D(), Game.mousePos():To2D(), 2, DrawColor(155, 255, 255, 255))
			end
		end
	end
end

function Hwei:QESemiManual()
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(self:Ready(_Q)) then
		local enemies = GetEnemyHeroes(comboRange)
		local bestPos, count = CalculateBestLinePosition(enemies, QE.Radius - 30, comboRange, QE.Speed, QE.Delay)
		local check = true

		if(bestPos) then
			for _, enemy in ipairs(enemies) do
				if not (IsValid(enemy)) then
					check = false
					break
				end
			end
		end

		if(check and count > 0) then
			local didCast = self:CastSpell(1, HK_E, bestPos) --Casting QE
			if didCast then SendDebugMsg("Semi-Manual QE"); return end
		end
	end
end

function Hwei:EQSemiManual()
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(self:Ready(_E)) then
		local type = self.Menu.BonusSemiKeys.EQ.LogicCheck:Value()
		if(type == 1) then --Best Target
			local tar = GetTarget(comboRange)
			if(IsValid(tar)) then
				self:CastEQ({Target = tar, SpellData = EQ, maxCollision = 1})
				SendDebugMsg("Semi-Manual EQ on " .. tar.charName)
			end
		else --Nearest to cursor
			local enemies = GetEnemyHeroes(EQ.Range)
			local closestUnit = GetClosestUnitToCursor(enemies)
			if IsValid(closestUnit) then
				self:CastEQ({Target = closestUnit, SpellData = EQ, maxCollision = 1})
				SendDebugMsg("Semi-Manual EQ towards Cursor")
				return
			end
		end
	end
end

function Hwei:EESemiManual()
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(self:Ready(_E)) then
		local type = self.Menu.BonusSemiKeys.EE.LogicCheck:Value()
		if(type == 1) then --Best Target
			local tar = GetTarget(comboRange)
			if(IsValid(tar)) then
				self:CastEE({Target = tar, SpellData = EE})
				SendDebugMsg("Semi-Manual EE on " .. tar.charName)
			end
		else --Nearest to cursor
			local enemies = GetEnemyHeroes(EE.Range)
			local closestUnit = GetClosestUnitToCursor(enemies)
			if IsValid(closestUnit) then
				self:CastEE({Target = closestUnit, SpellData = EE})
				SendDebugMsg("Semi-Manual EE towards Cursor")
				return
			end
		end
	end
end

function Hwei:EInterrupter()
	if(self:Ready(_E)) then
		local enemies = GetEnemyHeroes(EQ.Range)
		if(#enemies > 0) then
			for _, enemy in pairs (enemies) do
				if(IsValid(enemy)) then

					--Interrupt them if they are channeling an interruptible spell
					local spell = enemy.activeSpell
					if(spell and spell.valid and self.InterruptableSpells[spell.name]) then
						if(self.Menu.EInterrupter.InterruptSpells[spell.name]) then
							if(self.Menu.EInterrupter.InterruptSpells[spell.name]:Value() == true) then
								if(GetDistance(myHero, enemy)>= EE.Range) then
									self:CastEQ({Target = enemy, SpellData = EQ, maxCollision = 1})
									SendDebugMsg("E-Interrupter EQ on " .. enemy.charName .. ", STOPPED : " .. spell.name)
								else
									self:CastEE({Target = enemy, SpellData = EE})
									SendDebugMsg("E-Interrupter EE on " .. enemy.charName .. ", STOPPED : " .. spell.name)
								end
							end
						end
					end
				end
			end
		end
	end
end

function Hwei:AutoCast()
	if not (IsValid(myHero)) or myHero.isChanneling then return end
	if(GameTimer() < self.WEBuffer) then return end

	--Anti-melee
	if(self:Ready(_E) and self.Menu.AutoCast.AntiMeleeEQ:Value()) then
		--[[
		local meleeTarget = GetTarget(350)
		if(IsValid(meleeTarget)) then
			self:CastEQ({Target = meleeTarget, SpellData = EQ})
			SendDebugMsg("Anti-Melee EQ on " .. meleeTarget.charName)
			return
		end
		--]]
		local enemies = GetEnemyHeroes(350)
		for i = 1, #enemies do
			local enemy = enemies[i]
			if(IsValid(enemy)) then
				self:CastEQ({Target = meleeTarget, SpellData = EQ})
				SendDebugMsg("Anti-Melee EQ on " .. meleeTarget.charName)
				return
			end
		end
	end

	--Anti-dash
	if(self:Ready(_E) and self.Menu.AutoCast.AntiDashEQ:Value()) then
		local enemies = GetEnemyHeroes(850)
		for i = 1, #enemies do
			local enemy = enemies[i]
			if(IsValid(enemy)) then
				local path = enemy.pathing
				if path and path.isDashing and enemy.posTo then
					if GetDistance(myHero.pos, enemy.posTo) < 400 and IsFacing(enemy) then
						self:CastEQ({Target = enemy, SpellData = EQ, maxCollision = 1})
						SendDebugMsg("Anti-Dash EQ on " .. enemy.charName)
						return
					end
				end
			end
		end
	end

	-- QW CC'd
	if(self:Ready(_Q) and self.Menu.AutoCast.SmartQCC:Value()) then
		local enemies = GetEnemyHeroes(QW.Range + QW.Radius*0.2)
		for _, enemy in ipairs(enemies) do
			if(IsValid(enemy) and enemy.pos:To2D().onScreen) then
				if(GetDistance(enemy, myHero) >= comboRange) then
					if(IsHardCCd(enemy) > 0.75) then

						if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
							self:CastWE()
							return
						end

						DelayEvent(function ()
							if(IsValid(enemy) and enemy.pos:To2D().onScreen) then
								if(GetDistance(enemy, myHero) >= comboRange) then
									if(self:Ready(_Q)) then

										self:CastQW({Target = enemy, SpellData = QW, ExtendedCheck = true})
										SendDebugMsg("Using QW on CC'd Target: " .. enemy.charName)
										return
									end
								end
							end
						end, 0.15)
					end
				end
			end
		end
	end

	--Smart E CC'd
	--This uses either EQ or EW depending on conditions
	if(self:Ready(_E) and self.Menu.AutoCast.SmartECC:Value()) then
		local enemies = GetEnemyHeroes(EW.Range + EW.Radius - 50)
		for _, enemy in ipairs(enemies) do
			if(IsValid(enemy) and enemy.pos:To2D().onScreen) then
				if(IsHardCCd(enemy) > 0.5) then
					local castPos = CastPredictedSpell({Target = enemy, SpellData = EQ, maxCollision = 1, ReturnPos = true, UseHeroCollision = true})
					if(castPos) then
						self:CastSpell(3, HK_Q, castPos)
						SendDebugMsg("Using EQ on CC'd Target: " .. enemy.charName)
						return
					else
						self:CastEW({Target = enemy, SpellData = EW, ExtendedCheck = true})
						SendDebugMsg("Using EW on CC'd Target: " .. enemy.charName)
						return
					end
				end
			end
		end
	end

	--Anti recall
	if(self:Ready(_Q) and self.Menu.AutoCast.QWRecall:Value()) then
		local enemies = GetEnemyHeroes(QW.Range + QW.Radius*0.2)
		for _, enemy in ipairs(enemies) do
			if(IsValid(enemy) and enemy.pos:To2D().onScreen) then
				if(IsRecalling(enemy)) then
					DelayEvent(function ()
						if(self:Ready(_Q) and IsRecalling(enemy)) then
							self:CastQW({Target = enemy, SpellData = QW, ExtendedCheck = true})
							SendDebugMsg("STOPPED RECALL on " .. enemy.charName)
							return
						end
					end, 0.5)
				end
			end
		end
	end

	--WW Logic
	if(self:Ready(_W) and self.Menu.AutoCast.WWSettings.WWSave:Value()) then
		if(myHero.health/myHero.maxHealth <= self.Menu.AutoCast.WWSettings.MinimumHP:Value()/100) and HealthDelta:GetHPDelta() < -10 then

			if(self.Menu.AutoCast.WWSettings.EnemyCheck:Value()) then

				if(self.Menu.AutoCast.WWSettings.TowerCheck:Value()) then
					if(IsUnderFriendlyTurret(myHero)) then
						self:CastWW(myHero.pos)
						return
					end
				end

				local enemies = GetEnemyHeroes(QQ.Range)
				if #enemies == 0 then
					self:CastWW(myHero.pos)
					return
				end
			else
				self:CastWW(myHero.pos)
				return
			end
		end
	end
end

function Hwei:Killsteal()
	if not (IsValid(myHero)) or myHero.isChanneling then return end
	if(GameTimer() < self.WEBuffer) then return end
	--[[
	We choose between QQ and QW. We don't want to spam QW or use it on a target really far away if there is a target nearby fighting us.

	We will QQ if:
	- There is no Collision (including heroes)
	- If it will kill with passive proc

	We will QW if:
	- We cannot QQ while in QQ range 
	- QW has a very high chance of hitting 
	- There isn't a target on us (that isn't the KS target)
	- If it will kill with passive proc
	- We can combo it with R

	Check QQ in the priority stack first.
	]]--

	if(self.Menu.KillSteal.SmartQKS:Value()) then
		if(self:Ready(_Q)) then
			local hasWE = false

			local enemies = GetEnemyHeroes(QW.Range)
			if(#enemies > 0) then
				if(self:HasWEBuff() or (self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true}))) then
					hasWE = true
				end
			end

			for _, enemy in ipairs(enemies) do
				if(IsValid(enemy) and enemy.pos:To2D().onScreen) then

					--[[
						Optimization:
						We should not be doing complicated calculations and collision checks per tick for every enemy.
						Instead, we should only consider champions that could be KS'd.
						If someone's health is below the RAW damage of a QQ + WE or QW + WE, they are worth evaluating if they can 
						be killed.
					]]


					local checkQQdmg = 0
					local checkQWdmg = 0
					local checkRPopdmg = 0

					if(hasWE) then
						checkQQdmg = checkQQdmg + self:GetRawAbilityDamage("WE")
						checkQWdmg = checkQWdmg + self:GetRawAbilityDamage("WE")
						checkRPopdmg = checkRPopdmg + self:GetRawAbilityDamage("WE")
					end

					checkQQdmg = checkQQdmg + self:GetRawAbilityDamage("QQ", enemy)
					checkQWdmg = checkQWdmg + self:GetRawAbilityDamage("QW", enemy)
					checkRPopdmg = checkRPopdmg + self:GetRawAbilityDamage("RPop")

					if(enemy.health - checkQQdmg < 0 and GetDistance(enemy, myHero) < QQ.Range) or (enemy.health - checkQWdmg < 0) then
						if(GetDistance(enemy, myHero) < QQ.Range) then
							local castPos = CastPredictedSpell({Target = enemy, SpellData = QQ, maxCollision = 1, CheckSplashCollision = true, SplashCollisionRadius = 200, UseHeroCollision = true, ReturnPos = true})
							if(castPos) then
								if(GetDistance(myHero, castPos) < comboRange) then
									local totalDMG = 0
									totalDMG = totalDMG + self:GetRawAbilityDamage("QQ", enemy)
									if(HasArcaneComet()) then
										totalDMG = totalDMG + GetArcaneCometDamage()
									end
									if(self:HasLudens()) then
										local ludensDmg = GetItemDamage(Item.LudensTempest)
										totalDMG = totalDMG + ludensDmg
									end
									if(self:HasLiandrys()) then
										local liandryDmg = GetItemDamage(Item.LiandrysAnguish, enemy)
										totalDMG = totalDMG + liandryDmg
									end
									if(self:HasWEBuff() or (self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true}))) then
										totalDMG = totalDMG + self:GetRawAbilityDamage("WE")
									end
									if(self:HasPassiveMark(enemy)) then
										totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
									end
			
									totalDMG = CalcMagicalDamage(myHero, enemy, totalDMG)
			
					
									if(enemy.health - totalDMG <= 0) then
										if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
											self:CastWE()
											return
										end
			
										self:CastQQ({Target = enemy, SpellData = QQ})
										SendDebugMsg("QQ Killsteal on " .. enemy.charName)
										return
									end	
								end
							else
								--Check for QW in combo range.
								if enemy.isChanneling or IsImmobile(enemy) > 0.5 or self:HasUltDebuff(enemy) then
									-- Do damage calcs to see if its worth casting:
									local totalDMG = 0
									totalDMG = totalDMG + self:GetRawAbilityDamage("QW", enemy)
									if(HasArcaneComet()) then
										totalDMG = totalDMG + GetArcaneCometDamage()
									end
									if(self:HasLudens()) then
										local ludensDmg = GetItemDamage(Item.LudensTempest)
										totalDMG = totalDMG + ludensDmg
									end
									if(self:HasLiandrys()) then
										local liandryDmg = GetItemDamage(Item.LiandrysAnguish, enemy)
										totalDMG = totalDMG + liandryDmg
									end
									if(self:HasWEBuff() or (self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true}))) then
										totalDMG = totalDMG + self:GetRawAbilityDamage("WE")
									end
									if(self:HasPassiveMark(enemy)) then
										totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
									end
		
									totalDMG = CalcMagicalDamage(myHero, enemy, totalDMG)
		
									if(enemy.health - totalDMG <= 0) then
										if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
											self:CastWE()
										end
	
										self:CastQW({Target = enemy, SpellData = QW, ExtendedCheck = true})
										SendDebugMsg("QW Killsteal on " .. enemy.charName)
										return
									end
								end

							end
						end
						
						if(GetDistance(myHero, enemy) > comboRange) then
							local nearbyEnemies = GetEnemyHeroes(475)
							if(#nearbyEnemies == 0) then
								if enemy.isChanneling or IsImmobile(enemy) > 0.5 or self:HasUltDebuff(enemy) then
									-- Do damage calcs to see if its worth casting:
									local totalDMG = 0
									totalDMG = totalDMG + self:GetRawAbilityDamage("QW", enemy)
									if(HasArcaneComet()) then
										totalDMG = totalDMG + GetArcaneCometDamage()
									end
									if(self:HasLudens()) then
										local ludensDmg = GetItemDamage(Item.LudensTempest)
										totalDMG = totalDMG + ludensDmg
									end
									if(self:HasLiandrys()) then
										local liandryDmg = GetItemDamage(Item.LiandrysAnguish, enemy)
										totalDMG = totalDMG + liandryDmg
									end
									if(self:HasWEBuff() or (self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value())) then
										totalDMG = totalDMG + self:GetRawAbilityDamage("WE")
									end
									if(self:HasPassiveMark(enemy)) then
										totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
									end
		
									totalDMG = CalcMagicalDamage(myHero, enemy, totalDMG)
		
									if(enemy.health - totalDMG <= 0) then
										if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
											self:CastWE()
										end
	
										self:CastQW({Target = enemy, SpellData = QW, ExtendedCheck = true})
										SendDebugMsg("QW Killsteal on " .. enemy.charName)
										return
									end
								end
							end
						end

					end

					--Go for the R combo
					if(GetDistance(enemy, myHero) > comboRange) and (enemy.health - checkRPopdmg - checkQWdmg < 0) then
						local hasDebuff, duration = self:HasUltDebuff(enemy)
						if(hasDebuff) then
							if(duration < 0.85) then
								
								-- Do damage calcs to see if its worth casting:
								local totalDMG = 0
								totalDMG = totalDMG + self:GetRawAbilityDamage("QW", enemy)
								totalDMG = totalDMG + self:GetRawAbilityDamage("RPop")
								if(HasArcaneComet()) then
									totalDMG = totalDMG + GetArcaneCometDamage()
								end
								if(self:HasLudens()) then
									local ludensDmg = GetItemDamage(Item.LudensTempest)
									totalDMG = totalDMG + ludensDmg
								end
								if(self:HasLiandrys()) then
									local liandryDmg = GetItemDamage(Item.LiandrysAnguish, enemy)
									totalDMG = totalDMG + liandryDmg
								end
								if(self:HasWEBuff() or (self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value())) then
									totalDMG = totalDMG + self:GetRawAbilityDamage("WE")
								end
								if(self:HasPassiveMark(enemy)) then
									totalDMG = totalDMG + self:GetRawAbilityDamage("Passive")
								end
	
								totalDMG = CalcMagicalDamage(myHero, enemy, totalDMG)

								if(enemy.health - totalDMG <= 0) then
									if(self:Ready(_W) and self.Menu.Combo.UseWEStrengthen:Value() and self:CanAffordManaCost({Q = true, W = true})) then
										self:CastWE()
										return
									end

									local didCast = self:CastQW({Target = enemy, SpellData = QW})
									if didCast then SendDebugMsg("Casting KILLSTEAL QW with R Combo on " .. enemy.charName); return end
								end

							end
						end
					end
					
				end
			end

		end
	end
end

function Hwei:HasPassiveMark(unit)
	if(HasBuff(unit, "HweiSignature")) then
		return true
	end

	return false
end

function Hwei:HasUltDebuff(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)	

		if buff.name == "HweiRDespair" and buff.count > 0 then 
			return true, buff.expireTime - GameTimer()
		end
	end

	return false, 0
end

function Hwei:HasWEBuff()
	if(HasBuff(myHero, "HweiWEBuffCounter")) then
		return true
	end

	return false
end

function Hwei:HasLudens()
	return HasItem({Item.LudensTempest})
end

function Hwei:HasHorizonFocus()
	return HasItem({Item.HorizonFocus})
end
function Hwei:HasLiandrys()
	return HasItem({Item.LiandrysAnguish})
end

function Hwei:GetRawAbilityDamage(spell, tar)
	if(spell == "QQ") then
		if self.CachedRanks[_Q] == 0 then return 0 end
		return ({60, 90, 120, 150, 180})[self.CachedRanks[_Q]] + (myHero.ap * 0.7) + (({0.04, 0.05, 0.06, 0.07, 0.08})[self.CachedRanks[_Q]] * tar.maxHealth)
	end
	
	if(spell == "QW") then
		if self.CachedRanks[_Q] == 0 then return 0 end
		local dmg = (({80, 100, 120, 140, 160})[self.CachedRanks[_Q]] + (myHero.ap * 0.25))
		local multiplier = ({100, 137.5, 175, 212.5, 250})[self.CachedRanks[_Q]] * (1 - tar.health/tar.maxHealth)
		return (dmg * (1 + multiplier/100))
	end

	if(spell == "QE") then
		if self.CachedRanks[_Q] == 0 then return 0 end
		return ({70, 140, 210, 280, 350})[self.CachedRanks[_Q]] + (myHero.ap * 0.925)
	end

	if(spell == "WE") then
		if self.CachedRanks[_W] == 0 then return 0 end
		return ({25, 35, 45, 55, 65})[self.CachedRanks[_W]] + (myHero.ap * 0.2)
	end

	if(spell == "E") then
		if self.CachedRanks[_E] == 0 then return 0 end
		return ({60, 90, 120, 150, 180})[self.CachedRanks[_E]] + (myHero.ap * 0.6)
	end

	if(spell == "R") then
		if self.CachedRanks[_R] == 0 then return 0 end
		return ({230, 360, 490})[self.CachedRanks[_R]] + (myHero.ap * 0.95)
	end

	if(spell == "RPop") then
		if self.CachedRanks[_R] == 0 then return 0 end
		return ({200, 300, 400})[self.CachedRanks[_R]] + (myHero.ap * 0.8)
	end

	if(spell == "Passive") then
		return 35 + (145 / 17 * (myHero.levelData.lvl -1)) + (myHero.ap * 0.3)
	end

	return 0
end

function Hwei:GetRawFutureQWDamage(tar, health)
	health = math.max(health, 1)

	if self.CachedRanks[_Q] == 0 then return 0 end
	local dmg = (({80, 100, 120, 140, 160})[self.CachedRanks[_Q]] + (myHero.ap * 0.25))
	local multiplier = ({100, 137.5, 175, 212.5, 250})[self.CachedRanks[_Q]] * (1 - health/tar.maxHealth)
	return (dmg * (1 + multiplier/100))
end

function Hwei:GetAbilityManaCost(spell)
	if(spell == "Q") then
		if self.CachedRanks[_Q] == 0 then return 0 end
		return ({80, 90, 100, 110, 120})[self.CachedRanks[_Q]]
	end
	
	if(spell == "W") then
		if self.CachedRanks[_W] == 0 then return 0 end
		return ({90, 95, 100, 105, 110})[self.CachedRanks[_W]]
	end

	if(spell == "E") then
		if self.CachedRanks[_E] == 0 then return 0 end
		return ({50, 55, 60, 65, 70})[self.CachedRanks[_E]]
	end

	if(spell == "R") then
		if self.CachedRanks[_R] == 0 then return 0 end
		return 100
	end

	return 0
end

function Hwei:CanAffordManaCost(args)
	local QCost = args.Q and self:GetAbilityManaCost("Q") or 0
	local WCost = args.W and self:GetAbilityManaCost("W") or 0
	local ECost = args.E and self:GetAbilityManaCost("E") or 0
	local RCost = args.R and self:GetAbilityManaCost("R") or 0

	local totalCost = QCost + WCost + ECost + RCost

	if(myHero.mana >= totalCost) then
		return true
	end

	return false
end



-- [[ DRAWINGS ]] --

local qcolA = Vector(0, 255, 174)
local qcolB = Vector(0, 209, 237)

local eRangeTbl = {
	[2] = EQ.Range,
	[3] = EW.Range,
	[4] = EE.Range,
}

function Hwei:Draw()
	if myHero.dead then return end
	--[[
	DEBUGGING: Showing correct positions for casting circular spells inside walls.

	local mPos = Game.mousePos()
	if(MapPosition:inWall(mPos) == nil) then
		local radius = 215
		local accuracy = 8

		local tbl = {}
		for i = 1, accuracy do
			local vec = Vector(0, 0, 1):Rotated(0, math.rad((360/accuracy) * i), 0) * radius
			local intersectionPoint = MapPosition:getIntersectionPoint3D(mPos, mPos + vec)
			if(intersectionPoint) then

				local closestPt = ClosestPointOnLineSegment(intersectionPoint, mPos, mPos + vec)
				closestPt = Vector(closestPt.x, intersectionPoint.y, closestPt.z)
				DrawCircle(Vector(closestPt), 5, 5, DrawColor(255, 0, 255, 0))

				if((closestPt -(mPos+vec)) ~= Vector(0,0,0)) then
					table.insert(tbl, (closestPt -(mPos+vec)):Normalized()*GetDistance(mPos+vec, closestPt)*0.75)
				end
			else
				DrawCircle(mPos + vec, 5, 5, DrawColor(255, 255, 0, 0))
			end

			DrawLine(mPos:To2D(), (mPos + vec):To2D())
		end

		if #tbl > 0 then
			local finalVec = Vector(0, 0, 0)
			for _, data in ipairs(tbl) do
				finalVec = finalVec + data
			end
			finalVec = finalVec/#tbl

			DrawCircle(mPos + finalVec, radius, 5, DrawColor(255, 255, 255, 0))
			DrawCircle(mPos, radius, 3, DrawColor(55, 255, 255, 255))
		else
			DrawCircle(mPos, radius, 3)
		end
	end

	--]]

	--[[
	
	DEBUGGING: Showing EE hitbox lines

	local ePos = self:FetchECastPos()
	if(ePos) then
		DrawCircle(ePos, 50, 3, DrawColor(255, 255, 0, 0))

		local line = Vector(self.EEPos[2] - ePos):Normalized()
		local lineL = Vector(line.z, line.y, -line.x)
		local lineR = Vector(line.z, line.y, -line.x)
		local rotLineL1 = lineL:Rotated(0, math.rad(22.5), 0)*350 + ePos
		local rotLineR1 = lineR:Rotated(0, math.rad(157.5), 0)*350 + ePos
		local rotLineL2 = lineL:Rotated(0, math.rad(-22.5), 0)*350 + ePos
		local rotLineR2 = lineR:Rotated(0, math.rad(202.5), 0)*350 + ePos

		DrawLine(rotLineL1:To2D(), rotLineR2:To2D(), 3)
		DrawLine(rotLineL2:To2D(), rotLineR1:To2D(), 3)
	end
	--]]

	if(self.Menu.Drawings.DrawComboRange:Value()) then
		if(self:Ready(_Q)) then
			local tick = math.abs((math.cos((GetTickCount() / 1000) * 3) + 1)/2)
			local res = qcolA:Lerp(qcolB, tick)
			res = {r = math.floor(res.x), g = math.floor(res.y), b = math.floor(res.z)}
			DrawCircle(myHero, comboRange, 3, DrawColor(255, res.r, res.g, res.b)) --(Alpha, R, G, B)
		else
			DrawCircle(myHero, comboRange, 1, DrawColor(15, 255, 255, 255)) --(Alpha, R, G, B)	
		end
	end

	if(self.Menu.Drawings.DrawEWHelper:Value()) then
		if(self:Ready(_E)) then
			DrawCircle(Game.mousePos(), EW.Radius, 0.5, DrawColor(25, 255, 255, 255)) --(Alpha, R, G, B)
		end
	end

	if(self.Menu.Drawings.DrawQ:Value()) then
		if(self:Ready(_Q)) then
			DrawCircle(myHero, QQ.Range, 1, DrawColor(255, 25, 180, 237)) --(Alpha, R, G, B)
		else
			DrawCircle(myHero, QQ.Range, 1, DrawColor(15, 255, 255, 255)) --(Alpha, R, G, B)	
		end
	end

	if(self.Menu.Drawings.DrawQW:Value()) then
		DrawCircle(myHero, QW.Range, 1, DrawColor(35, 255, 255, 255)) --(Alpha, R, G, B)	
	end

	if(self.Menu.Drawings.DrawE:Value() ~= 1) then
		if(self.Menu.SMEW.Enabled:Value() and self.Menu.SMEW.Key:Value()) then
			DrawCircle(myHero, EW.Range, 1, DrawColor(155, 227, 3, 252)) --(Alpha, R, G, B)
		else
			DrawCircle(myHero, eRangeTbl[self.Menu.Drawings.DrawE:Value()], 1, DrawColor(155, 227, 3, 252)) --(Alpha, R, G, B)
		end
	end

	if(self.Menu.Drawings.DrawR:Value()) then
		if(self:Ready(_R)) then
			DrawCircle(myHero, R.Range, 1, DrawColor(255, 245, 215, 66)) --(Alpha, R, G, B)
		else
			DrawCircle(myHero, R.Range, 1, DrawColor(15, 255, 255, 255)) --(Alpha, R, G, B)
		end
	end

	if(self.Menu.Drawings.DrawEQPriority:Value()) then

		local fontSize = 20
		local pos = {x = myHero.pos:To2D().x - fontSize - 65, y = myHero.pos:To2D().y + 50}

		if(self.Menu.Combo.EnablePrioritySwapping:Value()) then
			if(self.Menu.Combo.ToggleEQPriority:Value()) then
				DrawText("[Combo] EQ Priority", fontSize, Vector(pos), DrawColor(255, 240, 143, 255))
			else
				DrawText("[Combo] Standard", fontSize, Vector(pos), DrawColor(255, 148, 253, 255))
			end
		else
			DrawText("Logic Module Disabled", fontSize, Vector(pos), DrawColor(155, 125, 125, 125))
		end
	end

	if(self.Menu.Drawings.EnableDebugMenu:Value()) then
		DebugMenu()
	end
end

local chatLog = {}
local maxMsgs = 12
local posx, posy, sizex, sizey = GameResolution.x - 600, 80, 600, 200
local msgSize = 16
function SendDebugMsg(msg)
	local function checkDuplicate(input)
		for _, v in ipairs(chatLog) do
			if(v[1] == input) then
				if(GameTimer() - v[2] < 1.5) then
					return true
				end
			end
		end
		return false
	end

	if(checkDuplicate(msg) == false) then
		local dtbl = {msg, GameTimer()}
		table.insert(chatLog, 1, dtbl)
	end

	if #chatLog > maxMsgs then
		table.remove(chatLog, 10)
	end

end

function DebugMenu()
	DrawRect(posx, posy, sizex, sizey, DrawColor(185, 0, 0, 0))

	local function formatTime( t )
		local minutes = math.floor( (t)/60 )
		local seconds = math.floor( (t)- minutes*60 )
		if minutes<10 then
			minutes = "0" .. minutes
		end
		if seconds<10 then
			seconds = "0" .. seconds
		end
		return minutes .. ":" .. seconds
	end

	if(#chatLog > 0) then
		local offset = 0
		local alphaReduce = 0
		for index, msg in ipairs(chatLog) do
			if(index == 1) then
				alphaReduce = 0
			else
				alphaReduce = 75
			end
			DrawText("["..formatTime(msg[2])	.."]", msgSize, posx + 4, posy + offset + 4, DrawColor(255 - alphaReduce, 215, 155, 185))
			DrawText(msg[1], msgSize, posx + 60, posy + offset + 4, DrawColor(255 - alphaReduce, 255, 255, 255))
			offset = offset + msgSize
		end
	end
end

Hwei()
LoadUnits()
