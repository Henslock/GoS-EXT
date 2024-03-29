require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.18

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Syndra will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

----------------------------------------------------
--|                    Checks                    |--
----------------------------------------------------

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

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Syndra"

local SyndraIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/syndra.png"

local gameTick = GameTimer()
Syndra.AutoLevelCheck = false

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.6, Range = 800, Radius = 175, Speed = math.huge, Collision = false}
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

function Syndra:__init()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	--Custom Callbacks
	OnSpellCast(function(spell) self:OnSpellCast(spell) end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) Syndra:OnPreAttack(...) end)

	self:UpdateGoSMenuAutoLevel()
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
	self.Menu.KillSteal:MenuElement({id = "UseE", name = "Use E", value = true})
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
	self.Menu.Drawings:MenuElement({id = "DamageHPBar", name = "Damage HP Bar", type = MENU})
	self.Menu.Drawings:MenuElement({id = "Debug", name = "Debug Drawings", type = MENU})
	
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "DrawDamageHPBar", name = "Draw Full Combo Damage", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "YOffset", name = "Y Offset", value = 60, min = -100, max = 100, step = 5})
	
	-- Debug
	self.Menu.Drawings.Debug:MenuElement({id = "DrawOrbs", name = "Draw Orbs", value = true})
	self.Menu.Drawings.Debug:MenuElement({id = "DrawELines", name = "Draw E Lines", value = true})
	self.Menu.Drawings.Debug:MenuElement({id = "DrawParticles", name = "Draw Particles", value = false})
	
	-- Prediction
	self.Menu:MenuElement({id = "Prediction", name = "Prediction", type = MENU})
	self.Menu.Prediction:MenuElement({id = "QHitChance", name = "Q Hit Chance",  value = 2, drop = {"Normal", "High", "Immobile"}})
	self.Menu.Prediction:MenuElement({id = "WHitChance", name = "W Hit Chance",  value = 2, drop = {"Normal", "High", "Immobile"}})
	self.Menu.Prediction:MenuElement({id = "EHitChance", name = "E Hit Chance",  value = 2, drop = {"Normal", "High", "Immobile"}})
		
	self.Menu:MenuElement({id = "DisableInFountain", name = "Disable Orbwalker while in Fountain", value = true})
	
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

function Syndra:UpdateGoSMenuAutoLevel()

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
			UpdateInfo()
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
			UpdateInfo()
		end, 0.15)
	end})
	self.Menu.AutoLevel:MenuElement({id = "InfoText", name = " "})
	--
	
	function UpdateInfo()
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
end

function Syndra:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end


function Syndra:Tick()
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
	
	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
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
		local nameCheck = obj.name:lower():find("_q_lv5_idle") or obj.name:lower():find("_q_2021_idle") or obj.name:lower():find("_q_idle")
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
        DelayEvent(function()
            self:CheckOrbs()
        end, 0.75)
	end
	
	if spell.name == "SyndraR" or spell.name == "SyndraRUpgrade" then
        DelayEvent(function()
            self:CheckOrbs()
        end, 1.75)
	end
end

function Syndra:GetRawAbilityDamage(spell)
	if(spell == "Q") then
		 return ({75, 110, 145, 180, 215})[myHero:GetSpellData(_Q).level] + (0.7 * myHero.ap)
	end
	
	if(spell == "W") then
		return ({70, 110, 150, 190, 230})[myHero:GetSpellData(_W).level] + (0.7 * myHero.ap)
	end

	if(spell == "E") then
		return ({75, 115, 155, 195, 235})[myHero:GetSpellData(_E).level] + (0.45 * myHero.ap)
	end
	
	if(spell == "R") then
		local spheres = myHero:GetSpellData(_R).ammo
		local sphereDmg = (({90, 130, 170})[myHero:GetSpellData(_R).level] + 0.17 * myHero.ap)
		return sphereDmg * spheres
	end
	
	return 0
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


function Syndra:Combo()
	if(myHero.isChanneling) then return end
	if(gameTick > GameTimer()) then return end	
	
	-- Q
	if(Ready(_Q) and self.Menu.Combo.UseQ:Value()) then
		local target = GetTarget(Q.Range + Q.Radius*2)
		if(IsValid(target)) then
		
			if(myHero.pos:DistanceTo(target.pos) < Q.Range + Q.Radius) then
				CastPredictedSpell({Hotkey = HK_Q, Target = target, SpellData = Q, ExtendedCheck = true})
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
				if(myHero.pos:DistanceTo(orb.orbObj.pos) < E.Range and myHero.pos:DistanceTo(orb.orbObj.pos) >= 150) then --Don't try to E orbs we are directly on top of, massive accuracy issues
					local trueOrbPos = self:GetTrueOrbPos(orb.orbObj)
					local dirVec = (trueOrbPos - myHero.pos):Normalized() * QE.Range
					local finalVec = myHero.pos + dirVec
					

					local finalPos = target:GetPrediction(QE.Speed, QE.Delay)
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
			end
		end
	end
	
	-- R
	if(Ready(_R) and self.Menu.Combo.UseR:Value()) then		
		local target = GetTarget(R.Range)
		if(target ~= nil and IsValid(target)) then
			if(self:IsKillable(target) and (CantKill(target, true, true, false, true))==false) then
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
				DelayEvent(function()
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
				local QDam = self:GetRawAbilityDamage("Q")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay)
				
				if ((hp > 0) and (hp + (canonMinion.health*0.05) < QDam) or (canonMinion.health + 5 < QDam)) then
					Control.CastSpell(HK_Q, canonMinion)
				end
			end
		end
	end
	
	-- Q
	if(Ready(_Q) and self.Menu.Harass.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then
		local target = GetTarget(Q.Range + Q.Radius) 
		if(IsValid(target)) then
			if(myHero.pos:DistanceTo(target.pos) < Q.Range + Q.Radius) then
				CastPredictedSpell({Hotkey = HK_Q, Target = target, SpellData = Q, ExtendedCheck = true})
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
							local QDam = self:GetRawAbilityDamage("Q")
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
					local QDam = self:GetRawAbilityDamage("Q")
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
							local QDam = self:GetRawAbilityDamage("Q")
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
							local QDam = self:GetRawAbilityDamage("Q")
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
						local QDam = self:GetRawAbilityDamage("Q")
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
									local QDam = self:GetRawAbilityDamage("Q")
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
				local QDam = self:GetRawAbilityDamage("Q")
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
									DelayEvent(function()
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
						local QDam = self:GetRawAbilityDamage("Q")
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
						local QDam = self:GetRawAbilityDamage("Q")
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
						if(self:IsKillable(enemy) and (CantKill(enemy, true, true, false, true))==false) then
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

	--E
	if(self.Menu.KillSteal.UseE:Value()) then
		if(Ready(_E)) then
			local enemies = GetEnemyHeroes(E.Range)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
						if(CantKill(enemy, true, true, false)==false) then
							local eDmg = self:GetRawAbilityDamage("E")
							eDmg = CalcMagicalDamage(myHero, enemy, eDmg)

							if(enemy.health - eDmg <= 0) then
								Control.CastSpell(HK_E, enemy)
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
								DelayEvent(function()
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
					

					local finalPos = target:GetPrediction(QE.Speed, QE.Delay)
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
					DelayEvent(function()
						Control.CastSpell(HK_E, finalPos)
						return
					end, 0.15)
				end
				

				local finalPos = target:GetPrediction(QE.Speed, QE.Delay)
				if(myHeroCalcPos:DistanceTo(target.pos) >= myHero.range) then
					local Qvec = Vector(finalPos.x, myHero.pos.y, finalPos.z)
					local QDirVec = (Qvec - myHeroCalcPos):Normalized() * Q.Range /2
					finalPos = QDirVec + myHeroCalcPos
				end
				Control.CastSpell(HK_Q, finalPos)
				DelayEvent(function()
					Control.CastSpell(HK_E, finalPos)
					return
				end, 0.15)

				
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
        elseif (unit.health - dmg <= (30 + 20 * myHero.levelData.lvl)) and (CanUseSummoner(myHero, "SummonerDot")) == false  then
            local igndmg = math.floor(_G.SDK.BuffManager:GetBuffDuration(unit, "summonerdot")) * (10+4 * myHero.levelData.lvl)
            if(unit.health - dmg <= igndmg) then
                isKillable = true
            end
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
		local rDmg = self:GetRawAbilityDamage("R")
		rDmg = CalcMagicalDamage(myHero, unit, rDmg)
		totalDmg = totalDmg + rDmg
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

function Syndra:GetTotalComboDamage(unit)
	local totalDmg = 0
	local dmgBuffer = 80

	if(Ready(_Q)) then
		local QDmg = self:GetRawAbilityDamage("Q")
		QDmg = CalcMagicalDamage(myHero, unit, QDmg)
		totalDmg = totalDmg + QDmg
	end
	
	if(Ready(_W)) then
		local splinters = GetBuffData(myHero, "syndrapassivestacks")
		local WDmg = self:GetRawAbilityDamage("W")
		local bonusDmg = 0
		if(splinters.stacks >= 60) then
			local bonusPercent = ((myHero.ap / 50) + 12)/100
			bonusDmg = (WDmg * (1 + bonusPercent)) - WDmg -- Bonus true damage
		end
		WDmg = CalcMagicalDamage(myHero, unit, WDmg)
		totalDmg = totalDmg + WDmg + bonusDmg
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
	
	if(Ready(_R)) then
		local RDmg = self:GetRawAbilityDamage("R")
		RDmg = CalcMagicalDamage(myHero, unit, RDmg)
		totalDmg = totalDmg + RDmg
	end

	return totalDmg - dmgBuffer
end

function Syndra:GetTrueOrbPos(orb)
	return orb.pos + Vector(0, -50, 0)
end

local alphaLerp = 0
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
	
	if(self.Menu.Drawings.DamageHPBar.DrawDamageHPBar:Value()) then
		self:DrawDamageHPBars()
		local mode = GetMode()
		if(mode == "Combo") then
			alphaLerp = math.max(alphaLerp - 0.1, 0)
		else
			alphaLerp = math.min(alphaLerp + 0.1, 1)
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

function Syndra:DrawDamageHPBars()
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

Syndra()
LoadUnits()
