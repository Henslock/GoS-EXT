require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.22

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Veigar will exit.")
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

SpellCast.QCastData = nil
SpellCast.WCastData = nil
SpellCast.ECastData = nil
SpellCast.RCastData = nil
function SpellCast:OnTick()
	
	if(myHero.activeSpell.name == myHero:GetSpellData(_Q).name) then
		self.QCastData = myHero.activeSpell
	end

	if(myHero.activeSpell.name == myHero:GetSpellData(_W).name) then
		self.WCastData = myHero.activeSpell
	end

	if(myHero.activeSpell.name == myHero:GetSpellData(_E).name) then
		self.ECastData = myHero.activeSpell
	end

	if(myHero.activeSpell.name == myHero:GetSpellData(_R).name) then
		self.RCastData = myHero.activeSpell
	end

	if(self.QDidCast == false) then
		if(myHero:GetSpellData(_Q).currentCd) > 0 and myHero:GetSpellData(_Q).cd ~= 0 then
			self.QDidCast = true
			local spell = myHero:GetSpellData(_Q)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell, self.QCastData)
			end
			self.QCastData = nil
		end
	end
	
	if(self.WDidCast == false) then
		if(myHero:GetSpellData(_W).currentCd) > 0 and myHero:GetSpellData(_W).cd ~= 0 then
			self.WDidCast = true
			local spell = myHero:GetSpellData(_W)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell, self.WCastData)
			end
			self.WCastData = nil
		end
	end
	
	if(self.EDidCast == false) then
		if(myHero:GetSpellData(_E).currentCd) > 0 and myHero:GetSpellData(_E).cd ~= 0 then
			self.EDidCast = true
			local spell = myHero:GetSpellData(_E)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell, self.ECastData)
			end
			self.ECastData = nil
		end
	end
	
	if(self.RDidCast == false) then
		if(myHero:GetSpellData(_R).currentCd) > 0 and myHero:GetSpellData(_R).cd ~= 0 then
			self.RDidCast = true
			local spell = myHero:GetSpellData(_R)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell, self.RCastData)
			end
			self.RCastData = nil
		end
	end
	
	self:UpdateSpellChecks()
end

function SpellCast:UpdateSpellChecks()
	if(Ready(_Q)) then self.QDidCast = false; self.QCastData = nil end
	if(Ready(_W)) then self.WDidCast = false; self.WCastData = nil end
	if(Ready(_E)) then self.EDidCast = false; self.ECastData = nil end
	if(Ready(_R)) then self.RDidCast = false; self.RCastData = nil end
end

local function OnSpellCast(fn)
    if not _SPELLCAST_START then
        _G.SpellCast = SpellCast()
    end
    table.insert(SpellCast.OnSpellCastCallback, fn)
end

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Veigar"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/veigar.png"

local gameTick = GameTimer()

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 990, Radius = 70, Speed = 2200, Collision = true, MaxCollision = 2, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
local W = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.47, Radius = 240, Range = 950, Speed = math.huge, Collision = false}
local E = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.75, Radius = 390, Range = 700, Speed = math.huge, Collision = false}
local EEdge = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.80, Radius = 30, Range = 1100, Speed = math.huge, Collision = false}
local R = {Range = 650, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}

Veigar.EData = {}
Veigar.PreEData = {}
Veigar.ComboDamageData = {}

--Main Menu
Veigar.Menu = MenuElement({type = MENU, id = "KillerVeigar", name = "Killer Veigar", leftIcon = ChampIcon})
Veigar.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

Veigar.InterruptableSpells = {
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

function Veigar:__init()
	self:LoadMenu()

	table.insert(_G.SDK.OnTick, function()
		self:Tick()
	end)

	table.insert(_G.SDK.OnDraw, function()
		self:Draw()
	end)

	--Custom Callbacks
	OnSpellCast(function(spell, spellCastData) self:OnSpellCast(spell, spellCastData) end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) Veigar:OnPreAttack(...) end)

	self:UpdateGoSMenuAutoLevel()
end

function Veigar:LoadMenu()                     	

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "EverfrostSettings", name = "Everfrost Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "WSettings", name = "W Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.Combo:MenuElement({id = "OverkillRProtection", name = "Enable R Overkill Protection", value = true})
	self.Menu.Combo:MenuElement({id = "SmartAABlock", name = "Smart AA Block", value = true})
	self.Menu.Combo:MenuElement({id = "SemiManualE", name = "Semi-manual E", key = string.byte("Z")})

	-- Everfrost Settings
	self.Menu.Combo.EverfrostSettings:MenuElement({id = "UseEverfrost", name = "Use Everfrost", value = true})
	self.Menu.Combo.EverfrostSettings:MenuElement({id = "AntiMelee", name = "Anti-Melee Peel", value = true})
	self.Menu.Combo.EverfrostSettings:MenuElement({id = "AutoCC", name = "Use on Immobile", value = true})
	self.Menu.Combo.EverfrostSettings:MenuElement({id = "BringToUlt", name = "Use to Bring into Ult Kill Range", value = true})
	self.Menu.Combo.EverfrostSettings:MenuElement({id = "Killsteal", name = "Killsteal", value = true})
	self.Menu.Combo.EverfrostSettings:MenuElement({id = "AoE", name = "AoE 3+ Targets in Combo", value = true})
	
	self.Menu.Combo.WSettings:MenuElement({id = "UseW", name = "Use W in Cage", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "UseWNormal", name = "Use W while E is on CD", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "WPeel", name = "Use W to Peel Off Melee", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "WFleeing", name = "Use W on Fleeing Targets", value = true})
	
	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "KillCannon", name = "Prioritize Canon Minion", value = true})
	self.Menu.Harass:MenuElement({id = "QMana", name = "Q Min Mana", value = 10, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Harass:MenuElement({id = "UseW", name = "Use W on Enemies Going for Last Hit", value = true})
	self.Menu.Harass:MenuElement({id = "WMana", name = "W Min Mana", value = 30, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseQ", name = "Use Q", value = true})
	
	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Clear:MenuElement({id = "WMana", name = "W Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear:MenuElement({id = "ChampCheck", name = "Only Use W When No Enemies Around", value = true})
	self.Menu.Clear:MenuElement({id = "LevelCheck", name = "Only Use W After Level", value = 7, min = 1, max = 18, step = 1})
	self.Menu.Clear:MenuElement({id = "LogicCheck", name = "Logic: ", value = 1, drop = {"OR", "AND"}})
	
	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.KillSteal:MenuElement({id = "OverkillRProtection", name = "Enable R Overkill Protection", value = true})
	self.Menu.KillSteal:MenuElement({id = "RBlacklist", name = "R Killsteal Blacklist (Unless Solo)", type = MENU})
	
	self.Menu:MenuElement({id = "AutoW", name = "Auto W on Immobile", value = true})
	self.Menu:MenuElement({id = "AutoE", name = "Auto E to Stop Dangerous Channels", value = true})
	self.Menu:MenuElement({id = "AutoECC", name = "Auto E on CC'd Targets", value = true})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQW", name = "Draw Q & W Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawE", name = "Draw E Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawKillableTargets", name = "Draw Killable Targets", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawQMinions", name = "Draw Killable Minions with Q", value = false})
	self.Menu.Drawings:MenuElement({id = "DamageHPBar", name = "Damage HP Bar", type = MENU})
	self.Menu.Drawings:MenuElement({id = "Debug", name = "Debug Drawings", type = MENU})
	
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "DrawDamageHPBar", name = "Draw Full Combo Damage", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "YOffset", name = "Y Offset", value = 60, min = -100, max = 100, step = 5})
	-- debug.debug
	self.Menu.Drawings.Debug:MenuElement({id = "DrawParticles", name = "Draw Particles", value = false})
		
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
	self.Menu.AutoLevel:MenuElement({id = "SecondSkill", name = "Second Skill Priority", drop = {"Q", "W", "E"}, value = 2, callback = 
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
	--

	self.Menu:MenuElement({id = "DisableInFountain", name = "Disable Orbwalker while in Fountain", value = true})
	
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local hero = args.unit
		local charName = args.charName
		--Add R blacklist champs
		self.Menu.KillSteal.RBlacklist:MenuElement({id = charName, name = charName, value = false})
	end)
	
end

function Veigar:UpdateGoSMenuAutoLevel()
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

function Veigar:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Veigar:Tick()
	if(self.Menu.DisableInFountain:Value()) then
		if(IsInFountain() or not myHero.alive) then
			_G.SDK.Orbwalker:SetMovement(false)
		else
			_G.SDK.Orbwalker:SetMovement(true)
		end
	else
		_G.SDK.Orbwalker:SetMovement(true)
	end
	
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
	
	self:UpdateEData()
	self:UpdateComboDamage()
	self:KillSteal()

	if(self.Menu.Combo.EverfrostSettings.UseEverfrost:Value()) then
		self:EverfrostLogic()
	end

	if(self.Menu.AutoW:Value()) then
		self:AutoWImmobile()
	end
	
	if(self.Menu.AutoE:Value()) then
		self:EInterrupter()
	end
	
	if(self.Menu.AutoECC:Value()) then
		self:EInterrupterCC()
	end
	
	if(self.Menu.Combo.SemiManualE:Value()) then
		self:SemiManualE()
	end
	
	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end

function Veigar:OnPreAttack(args)
    if GetMode()=="Combo" and Ready(_Q) then
		if (myHero.mana / myHero.maxMana) >= 0.08 and self.Menu.Combo.SmartAABlock:Value() then
       		args.Process = false
		end
    end

	if(self.Menu.Combo.SemiManualE:Value()) then
		args.Process = false
	end
end

function Veigar:OnSpellCast(spell, spellCastData)
	if spell.name == "VeigarEventHorizon" then
		self.PreEData = {pos = Vector(spellCastData.placementPos), age = GameTimer()}
		DelayAction(function()
            self:CheckE()
        end, E.Delay+0.05)
	end
end

function Veigar:CheckExistingE(obj)
	for _, e in pairs(self.EData) do
		if(e.networkID == obj.networkID) then
			return true
		end
	end
	return false
end

function Veigar:CheckE()
	local particleCount = Game.ParticleCount()
	for i = particleCount, 1, -1 do
		local obj = Game.Particle(i)
		local nameCheck = obj.name:lower():find("_e_cage_green")
		if obj and obj.type == "obj_GeneralParticleEmitter" and nameCheck and self:CheckExistingE(obj) == false then
			self.EData[#self.EData + 1] = obj
		end
	end
end

function Veigar:UpdateEData()
	for i = #self.EData, 1, -1 do
		local e = self.EData[i]
		if(e.type ~= "obj_GeneralParticleEmitter") then
			table.remove(self.EData, i)
		end
	end
end

function Veigar:Combo()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	--Q
	if(self.Menu.Combo.UseQ:Value()) then
		if(Ready(_Q)) then
			local target = GetTarget(Q.Range -25)
			if(target and IsValid(target) and target.toScreen.onScreen) then
				CastPredictedSpell({Hotkey = HK_Q, Target = target, SpellData = Q, maxCollision = 2, GGPred = true, collisionRadiusOverride = Q.Radius + 15})
			end
		end
	end
	
	--W
	if(self.Menu.Combo.WSettings.UseW:Value()) then
		if(Ready(_W)) then
			local target = GetTarget(W.Range + W.Radius -10)
			if(target and IsValid(target) and target.toScreen.onScreen) then
				local isInside, eObj = self:IsUnitInsideE(target)
				if(isInside and eObj and IsImmobile(target) <= 0) then
				
					local isStrafing, avgPos = StrafePred:IsStrafing(target)
					local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
					if(isStrafing) then
						if(avgPos:DistanceTo(myHero.pos) < W.Range) then
							Control.CastSpell(HK_W, avgPos)
							gameTick = GameTimer() + 0.2
							return
						end
					end
					if(isStutterDancing) then
						if(avgPos2:DistanceTo(myHero.pos) < W.Range) then
							Control.CastSpell(HK_W, avgPos2)
							gameTick = GameTimer() + 0.2
							return
						end
					end
					local WPrediction, isExtended = GetExtendedSpellPrediction(target, W)
					if WPrediction:CanHit(HITCHANCE_NORMAL) then
						if(isExtended) then
							local castPos = myHero.pos:Extended(WPrediction.CastPosition, W.Range)
							Control.CastSpell(HK_W, castPos)
							gameTick = GameTimer() + 0.2
							return
						else
							--Smart placement of W
							local distCheck = (eObj.pos:DistanceTo(target.pos))
							if(distCheck <= 135) then
								Control.CastSpell(HK_W, target.pos)
								gameTick = GameTimer() + 0.2
								return
							else
								local placementPos = eObj.pos:Extended(target.pos, E.Radius/2 - 35)
								Control.CastSpell(HK_W, placementPos)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end
					
				end
			end
		end
	end
	
	--W Melee Peel
	if(self.Menu.Combo.WSettings.WPeel:Value()) then
		if(Ready(_W)) then
			local target = GetTarget(W.Radius + 100)
			if(target and IsValid(target) and target.range <= 200 and target.toScreen.onScreen) then
				local isInside = self:IsUnitInsideE(target)
				if not (isInside) then
			
					Control.CastSpell(HK_W, myHero.pos:Extended(target.pos, GetDistance(myHero, target)/2))
					return
				end
			end
		end
	end
	
	--W Fleeing
	if(self.Menu.Combo.WSettings.WFleeing:Value()) then
		if(Ready(_W)) then
			local target = GetTarget(W.Range)
			if(target and IsValid(target) and target.toScreen.onScreen) then
				local checkRunDir = GetUnitRunDirection(myHero, target)
				local isInside, eObj = self:IsUnitInsideE(target)
				if(checkRunDir == RUNNING_AWAY and isInside == false) then
					--Conditions where someone may be fleeing
					
					--Target is less than 20% HP
					local condition1 = (target.health / target.maxHealth) <= 0.2 
					
					--You have 30% more HP than the target and they are less than 40% HP
					local condition2 = (myHero.health / myHero.maxHealth) - (target.health / target.maxHealth)>= 0.3 and (target.health / target.maxHealth) <= 0.4
					
					if(condition1 or condition2) then
						local WPrediction = GetExtendedSpellPrediction(target, W)
						if WPrediction:CanHit(HITCHANCE_HIGH) then
							Control.CastSpell(HK_W, WPrediction.CastPosition)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
			end
		end
	end
	
	--W Normal
	if(self.Menu.Combo.WSettings.UseWNormal:Value()) then
		if(Ready(_W) and (Ready(_E) == false or myHero:GetSpellData(_E).cd < 3.5)) then
			if not ((myHero:GetSpellData(_E).cd - myHero:GetSpellData(_E).currentCd) <= E.Delay) then

				local target = GetTarget(W.Range + W.Radius * 0.5)
				if(target and IsValid(target) and target.toScreen.onScreen) then
					local isInside = self:IsUnitInsideE(target)
					local preInside = self:IsUnitInsidePreE(target)
					if(isInside == false and preInside == false) then
						local ECurrCD = myHero:GetSpellData(_E).currentCd
						local WTotalCD = myHero:GetSpellData(_W).cd
						if(ECurrCD > WTotalCD) then --Only use W if your E is on CD
							CastPredictedSpell({Hotkey = HK_W, Target = target, SpellData = W, ExtendedCheck = true, GGPred = true, KillerPred = false})
							return
						end
					end
				end

			end
		end
	end
	
	--E
	if(self.Menu.Combo.UseE:Value()) then
		if(Ready(_E)) then
			local target = GetTarget(E.Range + E.Radius*0.5)

			if(target and IsValid(target) and target.toScreen.onScreen) then
				local check = CastPredictedSpell({Hotkey = HK_E, Target = target, SpellData = E, ExtendedCheck = true, KillerPred = false, GGPred = true})
				if(check) then
					gameTick = GameTimer() + 0.2
				end
			end
		end
	end

	--R
	if(self.Menu.Combo.UseR:Value()) then
		if(Ready(_R)) then
			local target = GetTarget(R.Range)
			if(target and IsValid(target) and target.toScreen.onScreen) then
				if(self:IsKillable(target) and (CantKill(target, true, true, false, true))==false) then
					if(self.Menu.Combo.OverkillRProtection:Value()) then
						if(self:ROverkillCheck(target) == false) then --Use R if it's not an overkill
							Control.CastSpell(HK_R, target)
							gameTick = GameTimer() + 0.2
							return
						end
					else
						Control.CastSpell(HK_R, target)
						gameTick = GameTimer() + 0.2
						return
					end
				end
			end
		end
	end
end

function Veigar:Harass()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) --Just do 1 check for optimization
	local canonMinion = GetCanonMinion(minions)
	
	--Q
	if(self.Menu.Harass.UseQ:Value()) then
		if(Ready(_Q) and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then
		
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local QDam = self:GetRawAbilityDamage("Q")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (myHero.pos:DistanceTo(canonMinion.pos)/Q.Speed))
				
				if ((hp > 0) and (canonMinion.health + (canonMinion.health*0.05) - QDam <= 0)) then
					Control.CastSpell(HK_Q, canonMinion)
					gameTick = GameTimer() + 0.2
					return
				end
			end
			
			local target = GetTarget(Q.Range)
			if(IsValid(target)) then
				CastPredictedSpell({Hotkey = HK_Q, Target = target, SpellData = Q, maxCollision = 2, collisionRadiusOverride = Q.Radius + 15})
			end
		end
	end
	
	--W
	if(self.Menu.Harass.UseW:Value()) then
		if(Ready(_W)) then
			local tar = GetTarget(W.Range)
			if(tar and IsValid(tar)) then
				local fMinions = _G.SDK.ObjectManager:GetAllyMinions(W.Range + 400) --Just do 1 check for optimization
				for i = 1, #fMinions do
					local minion = fMinions[i]
					if(minion and IsValid(minion)) then
						local hp = _G.SDK.HealthPrediction:GetPrediction(minion, W.Delay)
						if(hp - tar.totalDamage <= 20) and (tar.pos:DistanceTo(minion.pos) <= tar.range) then
							local healthDiff = (minion.health ~= hp)
							if(healthDiff) and (tar.activeSpell.isAutoAttack == false) then
								Control.CastSpell(HK_W, tar)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end
				end
			end
		end
	end
	
end

local avoidQMinionHandle = 0

function Veigar:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(myHero.activeSpell.isAutoAttack) then
		avoidQMinionHandle = myHero.activeSpell.target
	end
	
	--Q	
	if(self.Menu.LastHit.UseQ:Value()) then
		if(Ready(_Q)) then
		
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) --Just do 1 check for optimization
			local canonMinion = GetCanonMinion(minions)
			
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local QDam = self:GetRawAbilityDamage("Q")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (myHero.pos:DistanceTo(canonMinion.pos)/Q.Speed))
				
				if ((hp > 0) and (hp + (canonMinion.health*0.015) - QDam <= 0)) then
					Control.CastSpell(HK_Q, canonMinion)
					gameTick = GameTimer() + 0.2
					return
				end
			end
			
			for i = 1, #minions do
				local minion = minions[i]
				if(minion and IsValid(minion)) then
					--This is to prevent us Q'ing a target we are going to kill with an AA 
					local check = true
					if(avoidQMinionHandle == minion.handle) then
						if _G.SDK.HealthPrediction:GetLastHitTarget() then
							if _G.SDK.HealthPrediction:GetLastHitTarget().handle == minion.handle then
								check = false
							end
						end
					end
					if(myHero.pos:DistanceTo(minion.pos) <= Q.Range and check) then
						self:StandardLastHit(minion)
					end
				end
			end
		end
	end
	
end

function Veigar:StandardLastHit(minion)
	local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, minion.networkID)
	if(collisionCount <= Q.MaxCollision) then
		local QDam = self:GetRawAbilityDamage("Q")
		local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay + (myHero.pos:DistanceTo(minion.pos)/Q.Speed))
		if ((hp > 0) and (hp + 25 - QDam < 0)) then
			Control.CastSpell(HK_Q, minion)
			gameTick = GameTimer() + 0.2
			return
		end
	end
end

function Veigar:Clear()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
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

function Veigar:LaneClear(minions)
	local canonMinion = GetCanonMinion(minions)
	if(myHero.activeSpell.isAutoAttack) then
		avoidQMinionHandle = myHero.activeSpell.target
	end

	--Q
	if(self.Menu.Clear.UseQ:Value()) then
		if(Ready(_Q)) then
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, canonMinion.pos, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, canonMinion.networkID)
				if(collisionCount <= Q.MaxCollision) then
					local QDam = self:GetRawAbilityDamage("Q")
					local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (myHero.pos:DistanceTo(canonMinion.pos)/Q.Speed))
					
					--This is to prevent us Q'ing a target we are going to kill with an AA 
					local check = true
					if(avoidQMinionHandle == canonMinion.handle) then
						local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, (GetDistance(myHero, canonMinion)/myHero.attackData.projectileSpeed))
						if(hp - (myHero.totalDamage) < 0) then
							check = false
						end
					end
					
					if ((hp > 0) and (hp + (canonMinion.health*0.015) - QDam <= 0) and check) then
						Control.CastSpell(HK_Q, canonMinion)
						gameTick = GameTimer() + 0.2
						return
					end
				end
			end
					
			for _, minion in pairs(minions) do
				if(minion and IsValid(minion)) then
					
					--This is to prevent us Q'ing a target we are going to kill with an AA 
					local check = true
					if(avoidQMinionHandle == minion.handle) then
						local hp = _G.SDK.HealthPrediction:GetPrediction(minion, (GetDistance(myHero, minion)/myHero.attackData.projectileSpeed))
						if(hp - (myHero.totalDamage) < 0) then
							check = false
						end
					end
					
					if(myHero.pos:DistanceTo(minion.pos) <= Q.Range and check) then
						
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, minion.networkID)
						if(collisionCount <= Q.MaxCollision) then
							local QDam = self:GetRawAbilityDamage("Q")
							local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay + (myHero.pos:DistanceTo(minion.pos)/Q.Speed))
							if ((hp > 0) and (hp + 15 - QDam <= 0)) then
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
	

	local shouldUseW = true

	local champCheck, levelCheck = true, true
	if(self.Menu.Clear.ChampCheck:Value()) then
		local numEnemies = GetEnemyCount(1500, myHero)
		if(numEnemies ~= 0) then
			champCheck = false
		end
	end

	if(myHero.levelData.lvl < self.Menu.Clear.LevelCheck:Value()) then
		levelCheck = false
	end

	if(self.Menu.Clear.LogicCheck:Value() == 1) then
		-- OR
		shouldUseW = champCheck or levelCheck
	else
		-- AND
		shouldUseW = champCheck and levelCheck
	end

	--W
	if(self.Menu.Clear.UseW:Value() and shouldUseW) then
		if(Ready(_W) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.WMana:Value() / 100)) then
			for i = 1, #minions do		
				local minion = minions[i]
				if IsValid(minion) then
					if(myHero.pos:DistanceTo(minion.pos) < W.Range) then
						local clusterMinions = GetMinionsAroundMinion(W.Range, W.Radius, minion)
						if(#clusterMinions >= 2) then
							local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
							Control.CastSpell(HK_W, clusterMinionsAvgPos)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
			end
		end
	end
end

function Veigar:JungleClear(minions)		
	--Q
	if(self.Menu.Clear.UseQ:Value()) then
		if(Ready(_Q)) then
			for _, minion in pairs(minions) do
				if(IsValid(minion)) then
					local pred = GGPrediction:SpellPrediction(Q)
					pred:GetPrediction(minion, myHero)
					if pred.CastPosition and GetDistance(myHero, pred.CastPosition) < Q.Range then
						Control.CastSpell(HK_Q, pred.CastPosition)
					end
				end
			end
		end
	end
	
	--W
	if(self.Menu.Clear.UseW:Value()) then
		if(Ready(_W) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.WMana:Value() / 100)) then
			for _, minion in pairs(minions) do		
				if IsValid(minion) then
					local pred = GGPrediction:SpellPrediction(W)
					pred:GetPrediction(minion, myHero)
					if pred.CastPosition and GetDistance(myHero, pred.CastPosition) < W.Range then
						Control.CastSpell(HK_W, pred.CastPosition)
					end
				end
			end
		end
	end
end

local everfrostData = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 70, Range = 850, Angle = 28, Speed = math.huge}
function Veigar:EverfrostLogic()

	local HasEverfrost, iSlot = self:HasEverfrost()
	local enemies = GetEnemyHeroes(everfrostData.Range - 25)

	if(GetMode() == "Combo") then

		--AoE logic
		if(self.Menu.Combo.EverfrostSettings.AoE:Value()) then
			if(HasEverfrost) then
				if _G.SDK.Cursor.Step > 0 then
					return
				end

				if #enemies >= 3 then
					local bestPos, count = CalculateBestLinePosition(enemies, 380, everfrostData.Range, everfrostData.Speed, everfrostData.Delay)
					local check = true
					for _, enemy in ipairs(enemies) do
						if(IsValid(enemy)) then
							if not IsInCone(enemy, bestPos, everfrostData.Range, everfrostData.Angle) then
								check = false
							end
						end
					end

					if(check) then
						Control.CastSpell(ItemHotKey[iSlot], bestPos)
						return
					end
				end
			end
		end
	end

	--Anti-melee
	local function AntiMeleeEverfrost()
		if(HasEverfrost) then
			if _G.SDK.Cursor.Step > 0 then
				return
			end

			if #enemies > 0 then
				table.sort(enemies, function(a, b)
					return a.health + (a.totalDamage * 2) + (a.attackSpeed * 100)
						> b.health + (b.totalDamage * 2) + (b.attackSpeed * 100)
				end)
				for _, enemy in ipairs(enemies) do
					if(IsValid(enemy)) then
						if IsFacing(enemy) and GetDistance(myHero, enemy) < 400 then
							Control.CastSpell(ItemHotKey[iSlot], enemy.pos)
							return
						end
					end
				end
			end
		end
	end

	local function AutoCC()
		if(HasEverfrost) then
			if _G.SDK.Cursor.Step > 0 then
				return
			end

			if #enemies > 0 then
				for _, enemy in ipairs(enemies) do
					if(IsValid(enemy)) then
						if IsImmobile(enemy) >= 0.75 and GetDistance(enemy, myHero) <= everfrostData.Range then
							Control.CastSpell(ItemHotKey[iSlot], enemy.pos)
							return
						end
					end
				end
			end
		end
	end

	local function Killsteal()
		if(HasEverfrost) then
			if _G.SDK.Cursor.Step > 0 then
				return
			end

			if #enemies > 0 then
				for _, enemy in ipairs(enemies) do
					if(IsValid(enemy)) then
						local pred = GGPrediction:SpellPrediction(everfrostData)
						pred:GetPrediction(enemy, myHero)
						if pred.CastPosition and GetDistance(myHero, pred.CastPosition) < Q.Range - 25 then
							local everfrostDmg = GetItemDamage(Item.Everfrost)
							everfrostDmg = CalcMagicalDamage(myHero, enemy, everfrostDmg)
							if(enemy.health - everfrostDmg < 0) then
								Control.CastSpell(ItemHotKey[iSlot], enemy.pos)
								return
							end
						end
					end
				end
			end
		end
	end

	local function BringIntoUltRange()
		if(HasEverfrost and Ready(_R)) then
			if _G.SDK.Cursor.Step > 0 then
				return
			end

			if #enemies > 0 then
				for _, enemy in ipairs(enemies) do
					if(IsValid(enemy) and CantKill(enemy, true, true, false, true)==false) then
						local pred = GGPrediction:SpellPrediction(everfrostData)
						pred:GetPrediction(enemy, myHero)
						if pred.CastPosition and GetDistance(myHero, pred.CastPosition) < Q.Range - 25 then
							local everfrostDmg = GetItemDamage(Item.Everfrost)
							everfrostDmg = CalcMagicalDamage(myHero, enemy, everfrostDmg)
							local RDmg = self:GetRDamage(enemy)
							if(enemy.health - RDmg > 0 and enemy.health - everfrostDmg - RDmg <= 0) then
								Control.CastSpell(ItemHotKey[iSlot], enemy.pos)
								return
							end
						end
					end
				end
			end
		end
	end

	if(self.Menu.Combo.EverfrostSettings.AntiMelee:Value()) then
		AntiMeleeEverfrost()
	end

	if(self.Menu.Combo.EverfrostSettings.AutoCC:Value()) then
		AutoCC()
	end

	if(self.Menu.Combo.EverfrostSettings.Killsteal:Value()) then
		Killsteal()
	end

	if(self.Menu.Combo.EverfrostSettings.BringToUlt:Value()) then
		BringIntoUltRange()
	end
end

function Veigar:KillSteal()
	if(gameTick > GameTimer()) then return end
	
	--R
	if(self.Menu.KillSteal.UseR:Value()) then
		if(Ready(_R)) then
			local enemies = GetEnemyHeroes(1500)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
						if(self:IsKillable(enemy) and (CantKill(enemy, true, true, false, true)==false)) then
							local isOverkill = false
							if(self.Menu.KillSteal.OverkillRProtection:Value()) then
								isOverkill = self:ROverkillCheck(enemy)
							end

							if(#enemies == 1) then --We can KS on solo targets
							
								if(myHero.pos:DistanceTo(enemy.pos) < R.Range) and not isOverkill then
									Control.CastSpell(HK_R, enemy)
									gameTick = GameTimer() + 0.2
									return
								end
								
							else --If the KS'able target is in a group, lets make sure he's not on an R blacklist
							
								if(self.Menu.KillSteal.RBlacklist[enemy.charName]) then
									if(self.Menu.KillSteal.RBlacklist[enemy.charName]:Value() == false) then
										if(myHero.pos:DistanceTo(enemy.pos) < R.Range) and not isOverkill then
											Control.CastSpell(HK_R, enemy)
											gameTick = GameTimer() + 0.2
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

function Veigar:AutoWImmobile()
	if(Ready(_W)) then
		local target = GetTarget(W.Range + W.Radius -10)
		if(target ~= nil and IsValid(target)) then
			local WPrediction, isExtended = GetExtendedSpellPrediction(target, W)
			if WPrediction:CanHit(HITCHANCE_IMMOBILE) then
				CastPredictedSpell({Hotkey = HK_W, Target = target, SpellData = W, ExtendedCheck = true})
			end
			
			if(IsImmobile(target) >= 1.0) then
				CastPredictedSpell({Hotkey = HK_W, Target = target, SpellData = W, ExtendedCheck = true})
			end
		end
	end
end

function Veigar:SemiManualE()
	_G.SDK.Orbwalker:Orbwalk()
	
	if(gameTick > GameTimer()) then return end	

	if(Ready(_E) and myHero.activeSpell.name ~= "VeigarE") then
		local target = GetTarget(E.Range + E.Radius*0.5)
		if(target and IsValid(target)) then
			local check = CastPredictedSpell({Hotkey = HK_E, Target = target, SpellData = E, ExtendedCheck = true})
			if(check) then
				gameTick = GameTimer() + 0.2
			end
		end
	end

end

function Veigar:EInterrupter()
	if(Ready(_E)) then
		local enemies = GetEnemyHeroes(E.Range + E.Radius)
		if(#enemies > 0) then
			for _, enemy in pairs (enemies) do
				if(enemy.valid and IsValid(enemy)) then

					--Interrupt them if they are channeling an interruptible spell
					local spell = enemy.activeSpell
					if(spell and spell.valid and self.InterruptableSpells[spell.name]) then
						local EPrediction, isExtended = GetExtendedSpellPrediction(enemy, EEdge)
						if EPrediction:CanHit(HITCHANCE_NORMAL) then
							if(isExtended) then
								local castVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
								local offsetVec = castVec:Extended(myHero.pos, E.Radius-65)
								Control.CastSpell(HK_E, offsetVec)
								return
							else
								local castVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
								local offsetVec = castVec:Extended(myHero.pos, E.Radius-65)
								Control.CastSpell(HK_E, offsetVec)
								return
							end
						end
					end
					
				end
			end
		end
	end
end

function Veigar:EInterrupterCC()
	if(Ready(_E)) then
		local enemy = GetTarget(E.Range + E.Radius -10)
		if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
			--Interrupt them if they are channeling an interruptible spell
			if(IsImmobile(enemy) >= E.Delay) then
				local EPrediction, isExtended = GetExtendedSpellPrediction(enemy, EEdge)
				if EPrediction:CanHit(HITCHANCE_NORMAL) then
					if(isExtended) then
						local castVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
						local offsetVec = castVec:Extended(myHero.pos, E.Radius-65)
						Control.CastSpell(HK_E, offsetVec)
						return
					else
						local castVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
						local offsetVec = castVec:Extended(myHero.pos, E.Radius-65)
						Control.CastSpell(HK_E, offsetVec)
						return
					end
				end
			end
		end
	end
end

function Veigar:IsUnitInsideE(unit)
	if(self.EData) then
		for _, e in pairs(self.EData) do
			if(unit.pos:DistanceTo(e.pos) <= E.Radius) then
				return true, e
			end
		end
	end

	return false
end

function Veigar:IsUnitInsidePreE(unit)
	if(self.PreEData) then
		if(GameTimer() - self.PreEData.age <= E.Delay + 0.1) then
			if(unit.pos:DistanceTo(self.PreEData.pos) <= E.Radius) then
				return true
			end
		end
	end

	return false
end
function Veigar:HasEverfrost()
	return HasItem({Item.EternalWinter, Item.Everfrost})
end

function Veigar:ROverkillCheck(unit)
	--An overkill occurs when a target is extremely low HP, and we could have simply finished them off with a Q
	--We'll check to see if the unit is within R range since this determines if we should ultimately use R or not
	if(myHero.pos:DistanceTo(unit.pos) <= R.Range) then
		local QCheck = (myHero:GetSpellData(_Q).cd - myHero:GetSpellData(_Q).currentCd) <= 0.5
		if(Ready(_Q) or QCheck) and unit.health <= (self:GetRawAbilityDamage("Q")*0.65) then
			return true
		end
	end
	
	return false
end

function Veigar:GetRawAbilityDamage(spell)
	if(spell == "Q") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		local apRatio = ({45, 50, 55, 60, 65})[myHero:GetSpellData(_Q).level] / 100
		return ({80, 120, 160, 200, 240})[myHero:GetSpellData(_Q).level] + (apRatio * myHero.ap)
	end
	
	if(spell == "W") then
		if myHero:GetSpellData(_W).level == 0 then return 0 end
		local apRatio = ({70, 80, 90, 100, 110})[myHero:GetSpellData(_W).level] / 100
		return ({100, 150, 200, 250, 300})[myHero:GetSpellData(_W).level] + (apRatio * myHero.ap)
	end
	
	return 0
end

function Veigar:GetRDamage(unit)
	local apRatio = ({65, 70, 75})[myHero:GetSpellData(_R).level] / 100
	local baseAmnt = ({175, 250, 325})[myHero:GetSpellData(_R).level] + (apRatio * myHero.ap)
	local ratioMult = (math.min(1 -(unit.health / unit.maxHealth), 0.667) / 0.667)
	return CalcMagicalDamage(myHero, unit, baseAmnt + (baseAmnt * ratioMult))
end

local dataTick = GameTimer()
function Veigar:UpdateComboDamage()
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

function Veigar:IsKillable(unit)
	local isKillable = false
	local igniteOverkill = false
	local igniteDmg = 50 + (20 * myHero.levelData.lvl)

	if(self.ComboDamageData[unit.networkID] ~= nil) then	
		local dmg = self.ComboDamageData[unit.networkID]
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

function Veigar:GetTotalDamage(unit)
	local totalDmg = 0
	
	if(Ready(_R)) then
		totalDmg = totalDmg + self:GetRDamage(unit)
		totalDmg = totalDmg - 15 --Slight buffer
	end
	
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
		local igniteDmg = 50 + (20 * myHero.levelData.lvl)
		totalDmg = totalDmg + igniteDmg
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
		local igniteDmg = 50 + (20 * myHero.levelData.lvl)
		totalDmg = totalDmg + igniteDmg
	end
	
	if HasElectrocute() then
		local elecDmg = GetElectrocuteDamage()
		elecDmg = CalcMagicalDamage(myHero, unit, elecDmg)
		totalDmg = totalDmg + elecDmg
	end
	
	if(HasItem(Item.LudensTempest)) then
		local ludensDmg = GetItemDamage(Item.LudensTempest)
		ludensDmg = CalcMagicalDamage(myHero, unit, ludensDmg)
		totalDmg = totalDmg + ludensDmg
	end
	
	return totalDmg
end

function Veigar:GetTotalComboDamage(unit)
	local totalDmg = 0
	
	if(Ready(_Q)) then
		local QDmg = self:GetRawAbilityDamage("Q")
		QDmg = CalcMagicalDamage(myHero, unit, QDmg)
		totalDmg = totalDmg + QDmg
	end
	
	if(Ready(_W)) then
		local WDmg = self:GetRawAbilityDamage("W")
		WDmg = CalcMagicalDamage(myHero, unit, WDmg)
		totalDmg = totalDmg + WDmg
	end
	
	if(HasItem(Item.LudensTempest)) then
		local ludensDmg = GetItemDamage(Item.LudensTempest)
		ludensDmg = CalcMagicalDamage(myHero, unit, ludensDmg)
		totalDmg = totalDmg + ludensDmg
	end

	if(self:HasEverfrost()) then
		local everfrostDmg = GetItemDamage(Item.Everfrost)
		everfrostDmg = CalcMagicalDamage(myHero, unit, everfrostDmg)
		
		totalDmg = totalDmg + everfrostDmg
	end
	
	if(Ready(_R)) then
		local apRatio = ({65, 70, 75})[myHero:GetSpellData(_R).level] / 100
		local baseAmnt = ({175, 250, 325})[myHero:GetSpellData(_R).level] + (apRatio * myHero.ap)
		local ratioMult = (math.min(1 -((unit.health - totalDmg) / unit.maxHealth), 0.667) / 0.667)
		local RDmg = CalcMagicalDamage(myHero, unit, baseAmnt + (baseAmnt * ratioMult))
		totalDmg = totalDmg + RDmg
	end
	
	return totalDmg
end

local alphaLerp = 0
function Veigar:Draw()
	if myHero.dead then return end
	
	if(self.Menu.Drawings.DrawQW:Value()) then
		DrawCircle(myHero, Q.Range, 1, DrawColor(50, 80, 215, 255)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Drawings.DrawE:Value()) then
		DrawCircle(myHero, E.Range, 1, DrawColor(50, 170, 55, 225)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Drawings.DrawKillableTargets:Value()) then
		self:DrawKillable()
	end
	
	if(self.Menu.Drawings.DamageHPBar.DrawDamageHPBar:Value()) then
		self:DrawDamageHPBars()
		local mode = GetMode()
		if(mode == "Combo") then
			alphaLerp = math.max(alphaLerp - 0.1, 0)
		else
			alphaLerp = math.min(alphaLerp + 0.1, 1)
		end
	end
	
	if(self.Menu.Drawings.DrawQMinions:Value()) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
		for i = 1, #minions do
			local minion = minions[i]
			if(minion and IsValid(minion)) then
				local QDam = self:GetRawAbilityDamage("Q")
				if (minion.health + 10 - QDam <= 0) then
					DrawCircle(minion, 25, 8, DrawColor(255, 35, 175, 255))
				end
			end
		end
	end
	
	if(self.Menu.Drawings.Debug.DrawParticles:Value()) then
		local particleCount = Game.ParticleCount()
		for i = particleCount, 1, -1 do
			local obj = Game.Particle(i)
			if obj and obj.type == "obj_GeneralParticleEmitter" and obj.name:find("Veigar") then
				DrawText(obj.name, 18, obj.pos:To2D())
			end
		end
	end
end

function Veigar:DrawKillable()
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

function Veigar:DrawDamageHPBars()

	for _, enemy in pairs(Enemies) do
		if(enemy.valid and IsValid(enemy)) then
			if(enemy.toScreen.onScreen) then
				if(Ready(_Q) or Ready(_W) or Ready(_R)) then
					local bar = enemy.pos:To2D()
					local barLength = 150
					local barHeight = 4
					local barOffset = self.Menu.Drawings.DamageHPBar.YOffset:Value()
					local hpRatio = (enemy.health / enemy.maxHealth)
					local dmg = self:GetTotalComboDamage(enemy)
					local dmgRatio = (dmg / enemy.maxHealth)
					if(enemy.health - dmg <= 0) then
						dmgRatio = hpRatio
					end
					--Bar BG
					Draw.Rect(bar.x - (barLength/2) -3, bar.y + barOffset - 3, barLength +6, barHeight + 6, DrawColor(225 * alphaLerp, 0, 0, 0))
					
					--Health bar
					Draw.Rect(bar.x - (barLength/2), bar.y + barOffset, barLength * (hpRatio - 0.02), barHeight, DrawColor(255 * alphaLerp, 55, 255, 115))
				
					--Damage bar
					Draw.Rect(bar.x - (barLength/2) + (barLength * hpRatio) - (barLength * dmgRatio), bar.y + barOffset, barLength * dmgRatio, barHeight, DrawColor(255 * alphaLerp, 255, 45, 115))
				end
			end
		end
	end
end

function Veigar:DrawKillReticle(unit)
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

Veigar()
LoadUnits()
