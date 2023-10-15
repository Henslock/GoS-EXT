require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.08

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Azir will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

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
		if(myHero:GetSpellData(_E).currentCd) > 0 or myHero.activeSpell.name == myHero:GetSpellData(_E).name and myHero:GetSpellData(_E).cd ~= 0 then
			self.EDidCast = true
			local spell = myHero:GetSpellData(_E)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
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
	if(Ready(_Q) and myHero.activeSpell.name ~= myHero:GetSpellData(_Q).name) then 
		self.QDidCast = false 
	end
	if(Ready(_W) and myHero.activeSpell.name ~= myHero:GetSpellData(_W).name) then 
		self.WDidCast = false 
	end
	if(Ready(_E) and myHero.activeSpell.name ~= myHero:GetSpellData(_E).name) then 
		self.EDidCast = false 
	end
	if(Ready(_R) and myHero.activeSpell.name ~= myHero:GetSpellData(_R).name) then 
		self.RDidCast = false 
	end
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

class "Azir"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/azir.png"

local gameTick = GameTimer()

-- GG PRED
local SoldierRadius = 350
local TetherRange = 740
local MaxEngageRange = 1250
local Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 740, Radius = 260, Speed = 2000}
local W = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Range = 525, Radius = SoldierRadius}
local E = {Range = 1100, Radius = 85, Speed = 1700}
local R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Range = 400, Radius = 750, Speed = 2200}


Azir.SoldierData = {}
Azir.ComboDamageData = {}

Azir.EngagePosition = nil
Azir.RTravelPos = nil
Azir.PassiveTurret = nil

--Main Menu
Azir.Menu = MenuElement({type = MENU, id = "KillerAzir", name = "Killer Azir", leftIcon = ChampIcon})
Azir.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})


function Azir:__init()
	self:LoadMenu()
	
	table.insert(_G.SDK.OnTick, function()
		self:Tick()
	end)

	table.insert(_G.SDK.OnDraw, function()
		self:Draw()
	end)

	--Custom Callbacks
	OnSpellCast(function(spell) self:OnSpellCast(spell) end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) Azir:OnPostAttack(...) end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) Azir:OnPreAttack(...) end)

	self:UpdateGoSMenuAutoLevel()

	--Setup passive turret on reload
	for i = 1, Game.TurretCount() do
		local turret = Game.Turret(i)
		if turret and turret.name == "Obelisk" then 
			self.PassiveTurret = turret
		end
	end
end

function Azir:LoadMenu()                     	
	-- Ult priority
	self.Menu:MenuElement({id = "UltPrio", name = "Ult Priority List", type = MENU})
	self.Menu.UltPrio:MenuElement({id = "Prio1", name = "1. Towards a Terrain Trap", value = true})
	self.Menu.UltPrio:MenuElement({id = "Prio2",name = "2. Towards Ally Tower", value = true})
	self.Menu.UltPrio:MenuElement({id = "Prio3",name = "3. Towards Team Cluster", value = true})
	self.Menu.UltPrio:MenuElement({id = "Prio4",name = "4. Towards Healthiest/Tankiest Ally", value = true})
	self.Menu.UltPrio:MenuElement({name = "5. Towards Engage Position", type = SPACE})
	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "Killsteal", name = "Combo Killsteal Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "AutoQ", name = "Auto Q to Reposition Soldiers", value = true})
	self.Menu.Combo:MenuElement({id = "SemiManualQ", name = "Semi-manual Q", key = string.byte("S")})
	self.Menu.Combo:MenuElement({id = "WSettings", name = "W Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseSmartR", name = "Use Smart R Combo", value = true})
	self.Menu.Combo:MenuElement({id = "SmartRSettings", name = "Smart R Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "RMeleePeel", name = "R Melee Champ Peel", type = MENU})
	self.Menu.Combo:MenuElement({id = "ToggleFlash", name = "Toggle Flash Usage for R", toggle = 20, value = false})
	self.Menu.Combo:MenuElement({name = "----- INSEC ULT SETTINGS -----", type = SPACE})
	self.Menu.Combo:MenuElement({id = "RPull", name = "R Shuffle Combo", key = string.byte("Z")})
	self.Menu.Combo:MenuElement({id = "Revenant", name = "R Revenant Combo", key = string.byte("C")})

	-- W Settings
	self.Menu.Combo.WSettings:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "WQCombo", name = "Use W if you can Q into AA Range", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "WTowerCheck", name = "Don't Use W under Tower Unless Short CD", value = false})

	-- Killsteal Settings
	self.Menu.Combo.Killsteal:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo.Killsteal:MenuElement({id = "UseE", name = "Use E to Bodyslam", value = true})
	self.Menu.Combo.Killsteal:MenuElement({id = "UseEAlone", name = "Only use E if Target is Alone", value = true})

	-- Smart R Settings
	self.Menu.Combo.SmartRSettings:MenuElement({id = "AvoidTower", name = "Don't Use Smart R Under Enemy Tower", value = true})
	self.Menu.Combo.SmartRSettings:MenuElement({id = "UseSmartRSolo", name = "Use On Solo Killable Target", value = true})
	self.Menu.Combo.SmartRSettings:MenuElement({id = "UseSmartRKillableInGroup", name = "Use On Killable Target in a Group", value = false})
	self.Menu.Combo.SmartRSettings:MenuElement({id = "UseE", name = "Use E to Gapclose on Killable Target", value = true})
	self.Menu.Combo.SmartRSettings:MenuElement({id = "TurretR", name = "Use to Shove Enemy Under Ally Turret", value = true})
	self.Menu.Combo.SmartRSettings:MenuElement({id = "UseSmartRGroup", name = "Use Smart R On Enemy Groups", value = true})
	self.Menu.Combo.SmartRSettings:MenuElement({id = "UseSmartRGroupAmnt", name = "Min # of Enemies to Use on Group", value = 3, min = 0, max = 5, step = 1})
	self.Menu.Combo.SmartRSettings:MenuElement({id = "ShouldPush", name = "Push Away if Azir's HP is Low", value = true})
	self.Menu.Combo.SmartRSettings:MenuElement({id = "PushCheck", name = "Push Away if Azir's HP is Below:", value = 30, min = 0, max = 100, step = 5, identifier = "%"})


	-- R Melee Peel
	self.Menu.Combo.RMeleePeel:MenuElement({id = "Enabled", name = "Enabled", value = true})
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local charName = args.charName
		self.Menu.Combo.RMeleePeel:MenuElement({id = charName, name = charName, value = true})
	end)

	-- Flee
	self.Menu:MenuElement({id = "Flee", name = "Flee", type = MENU})
	self.Menu.Flee:MenuElement({id = "InsecFlee", name = "Use Smart Insec Flee", value = true})
	self.Menu.Flee:MenuElement({id = "InsecFleeNoQ", name = "Use W->E if Q is on CD", value = true})

	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "MinionHarass", name = "Soldier Harass Through Minions", value = true})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "UseQAA", name = "Use AA -> Q Quick Harass", value = true})
	self.Menu.Harass:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Harass:MenuElement({id = "KeepSoldier", name = "Keep One Soldier Minimum", value = true})
	self.Menu.Harass:MenuElement({id = "MinimumManaQ", name = "Minimum Mana to Q", value = 30, min = 0, max = 100, step = 5, identifier = "%"})

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "Lane", name = "Lane", type = MENU})
	self.Menu.Clear:MenuElement({id = "Jungle", name = "Jungle", type = MENU})

	-- Lane Clear
	self.Menu.Clear.Lane:MenuElement({id = "UseQReposition", name = "Use Q to Reposition", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "UseQCanon", name = "Use Q to Last Hit Canon", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "UseW", name = "Use W on Minion Clusters", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "WLevelReq", name = "Don't Use W until Level", value = 6, min = 1, max = 18, step = 1})
	self.Menu.Clear.Lane:MenuElement({id = "QLevelReq", name = "Don't Use Q Reposition until Level", value = 6, min = 1, max = 18, step = 1})
	self.Menu.Clear.Lane:MenuElement({id = "WSoldierLevelReq", name = "Keep At Least 1 Soldier Charge Until Level: ", value = 9, min = 1, max = 18, step = 1})
	self.Menu.Clear.Lane:MenuElement({id = "MinimumManaQ", name = "Minimum Mana to Q", value = 50, min = 0, max = 100, step = 5, identifier = "%"})

	-- Jungle Clear
	self.Menu.Clear.Jungle:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "StackW", name = "Stack Multiple Soldiers", value = true})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawSoldiers", name = "Draw Soldiers", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawAzirTurretRange", name = "Draw Azir Turret Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawSoldierTether", name = "Draw Soldier Tether", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawSoldierTetherRadius", name = "Draw Soldier Tether Radius", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawRevenantUI", name = "Draw Revenant UI", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawFlashText", name = "Draw Flash Combo Text", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawE", name = "Draw E Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DamageHPBar", name = "Damage HP Bar", type = MENU})

	-- Damage HP Bar
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "DrawDamageHPBar", name = "Draw Combo Damage", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "YOffset", name = "Y Offset", value = 60, min = -100, max = 100, step = 5})
	self.Menu.Drawings.DamageHPBar:MenuElement({name = "--- Damage Calculation Settings ---", type = SPACE})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "CalcQ", name = "Calculate Q", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "CalcW", name = "Calculate W", value = 2, min = 0, max = 5, step = 1})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "CalcE", name = "Calculate E", value = false})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "CalcR", name = "Calculate R", value = true})

	--AutoLeveler	
	self.Menu:MenuElement({id = "AutoLevel", name = "Auto Leveler", type = MENU})
	self.Menu.AutoLevel:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.AutoLevel:MenuElement({id = "StartingLevel", name = "Start Using At Level:", value = 3, min = 2, max = 18, step = 1})
	self.Menu.AutoLevel:MenuElement({id = "FirstSkill", name = "First Skill Priority", drop = {"Q", "W", "E"}, value = 2, callback = 
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

	self.Menu.AutoLevel:MenuElement({id = "SecondSkill", name = "Second Skill Priority", drop = {"Q", "W", "E"}, value = 1, callback = 
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

function Azir:UpdateGoSMenuAutoLevel()
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

function Azir:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Azir:Tick()
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
	elseif(mode == "Flee") then
		--self:Flee()
	elseif(mode == "Harass") then
		self:Harass()
	elseif(mode == "LastHit") then
		self:LastHit()
	elseif(mode == "LaneClear") then
		self:Clear()
	end

	self:UpdateSoldiers()
	self:ManualKeys()
	self:UpdateComboDamage()
	self:CheckAzirTurret()
	self:HoverAzirTurretCheck()

	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end

function Azir:OnSpellCast(spell)
	if spell.name == "AzirW" then
        self:ScanSoldiers()
	end

	if spell.name == "AzirR" then
		--Reset revenant vars
		self.RevenantEngagePos = nil
		self.RevenantTarSoldier = nil
		self.RevenantQFollowup = false
	end
end

function Azir:OnPreAttack(args)
end

function Azir:OnPostAttack(args)
	if(GetMode() == "Harass") then
		if(self.Menu.Harass.UseQAA:Value() and Ready(_Q)) then
			if(myHero.mana / myHero.maxMana) >= (self.Menu.Harass.MinimumManaQ:Value() / 100) then
				local tar = GetTarget(Q.Range + SoldierRadius*0.75) --Extend the range a bit. We just need the soldier to get into AA range, so the Q doesn't have to necessarily land right on the target.
				if(IsValid(tar)) then
					local nearbySoldiers = self:GetSoldiersNearUnit(tar)
					if(self:IsSoldierOnUnit(tar) and #nearbySoldiers > 0) then
						Control.CastSpell(HK_Q, tar.pos)
					end
				end
			end
		end
	end
end

function Azir:Combo()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	--Smart R
	local function SmartR()
		if(self.Menu.Combo.UseSmartR:Value()) then
			if(Ready(_R)) then
				--Tower check
				if(self.Menu.Combo.SmartRSettings.AvoidTower:Value()) then
					if(IsUnderTurret(myHero)) then return end
				end
				--Use on killable target either solo or group
				if(self.Menu.Combo.SmartRSettings.UseSmartRSolo:Value() or self.Menu.Combo.SmartRSettings.UseSmartRKillableInGroup:Value()) then
					local tar = GetTarget(MaxEngageRange)
					local canUseE = Ready(_E) and self.Menu.Combo.SmartRSettings.UseE:Value()
					local groupCheck = true

					--If we have the group killable check disabled, we dont want to use this logic.
					if(self.Menu.Combo.SmartRSettings.UseSmartRKillableInGroup:Value() == false) then
						local nearbyEnemies = GetEnemyHeroes(1400)
						if(#nearbyEnemies > 1) then
							groupCheck = false
						end
					end

					if(IsValid(tar) and groupCheck) then

						--[[
							First check if the target is killable.
							When a solo target is ulted, typically you will have a W placed at their ending location followed by at least two AA's.
							If a solider is already up, we'll Q him to the new position.
							We need to check to see if these spells are up because they do affect our killable check.
						]]--
						local totalDmg = self:GetRawAbilityDamage("R")
						if(Ready(_W)) then
							totalDmg = totalDmg + (self:GetRawAbilityDamage("W")*2)
						end
						if(Ready(_Q)) and self:GetSoldierCount() >= 1 then
							totalDmg = totalDmg + self:GetRawAbilityDamage("Q")
						end

						totalDmg = CalcMagicalDamage(myHero, tar, totalDmg)

						local ludensCheck, ludensIsUp = CheckDmgItems(6655)
						if(ludensCheck and ludensIsUp) then
							local ludensDmg = 100 + (myHero.ap * 0.1)
							local ludensCalcDmg = CalcMagicalDamage(myHero, tar, ludensDmg)
							
							totalDmg = totalDmg + ludensCalcDmg
						end

						if(tar.health - totalDmg <= 0) then
							local ultCastPos = self:GenerateRPriorityPosition(myHero.pos)
							local predData = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Range = 400, Radius = 100, Speed = 3200}
							local tarPredPos = GGPrediction:SpellPrediction(predData)
							tarPredPos:GetPrediction(tar, myHero)
							tarPredPos = tarPredPos.CastPosition or tar.pos

							--E check to see if we can engage
							if(canUseE) then
								local soldier = self:GetClosestSoldierFromPos(tarPredPos)
								if(soldier and GetDistance(soldier.pos, tarPredPos) <= 300) and IsPositionUnderTurret(soldier.pos)==false then --Smallest range for ult is 300
									--Check for collision
									local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(soldier.pos, myHero.pos, 3000, 0, myHero.boundingRadius, {GGPrediction.COLLISION_ENEMYHERO})
									if(collisionCount <= 1) then
										Control.CastSpell(HK_E, soldier)
									end
								end
							end

							if(ultCastPos) then
								local dir = (ultCastPos - myHero.pos):Normalized()
								ultCastPos = myHero.pos + (dir*400)

								if(self:IsPointInRRectangle(tarPredPos, myHero.pos, dir, 20)) then
									if(not (myHero.pathing and myHero.pathing.isDashing)) then
										Control.CastSpell(HK_R, ultCastPos)
									end
								end
							end
						end
					end
				end

				--Push a target under Ally Turret
				if(self.Menu.Combo.SmartRSettings.TurretR:Value()) then
					local closestTurret = self.PassiveTurret or GetClosestFriendlyTurret()
					if(closestTurret) then
						local tar = GetTarget(E.Range)
						local nearbyEnemies = GetEnemyHeroes(E.Range)
						if(#nearbyEnemies == 1 and IsValid(tar)) then
							local boundingRadius = tar.boundingRadius or 0
							local maxShoveRange = (closestTurret.boundingRadius + 750 + boundingRadius / 2) + 650

							-- First, let's check to see if our Ult will bring them under tower, we also don't want to be too close to our tower when we do this.
							if(GetDistance(myHero.pos, closestTurret.pos) >= 450 and GetDistance(tar.pos, closestTurret.pos) <= maxShoveRange) then
								local dir = (closestTurret.pos - myHero.pos):Normalized()
								local ultCastPos = myHero.pos + (dir*400)

								--Next, let's check the health of the enemy to make sure this is worth doing.
								--[[
									We'll use a simple set of rules to decide if it's worth it, use if any of these are true:
									1. The target is less than 50% HP AND has less HP than Azir
									2. The target's combo damage would bring them under 30% HP
									3. The difference in %HP between you and the target is more than 40%
								]]--
								local rule1, rule2, rule3 = false, false, false
								rule1 = tar.health < myHero.health and (tar.health/tar.maxHealth <= 0.5)
								if(self.ComboDamageData[tar.networkID]) then
									rule2 = ((tar.health - self.ComboDamageData[tar.networkID])/tar.maxHealth) <= 0.3
								end
								rule3 = ((myHero.health/myHero.maxHealth) - (tar.health/tar.maxHealth)) >= 0.4

								if(rule1 or rule2 or rule3) then
									--Last thing to check is if there are any minions nearby, we want the enemy to take turret hits - not the minions!
									local turretMinions = GetEnemyMinionsUnderTurret(closestTurret)
									if(#turretMinions == 0) then
										--Use E to gapclose
										if(Ready(_E)) then
											local closestSoldier = self:GetClosestSoldierFromPos(tar.pos)
											if(closestSoldier and GetDistance(closestSoldier.pos, tar.pos)  <= 250 and IsPositionUnderTurret(closestSoldier.pos)==false) then
												Control.CastSpell(HK_E, closestSoldier)
											end
										end

										if(self:IsPointInRRectangle(tar.pos, myHero.pos, dir)) then
											Control.CastSpell(HK_R, ultCastPos)
										end
									end
								end

							end
						end
					end
				end

				--Push away if you are below a health threshold
				if(self.Menu.Combo.SmartRSettings.ShouldPush:Value()) then
					if(myHero.health / myHero.maxHealth <= self.Menu.Combo.SmartRSettings.PushCheck:Value()/100) then
						local tar = GetTarget(R.Range - 25)
						if(IsValid(tar)) then
							local tarPredPos = GetPrediction(tar, 2200, 0.25)
							if(tarPredPos) then
								if(GetDistance(myHero, tarPredPos) <= R.Range - 25) then
									Control.CastSpell(HK_R, tarPredPos)
								end
							end
						end
					end
				end

				--Use R on enemy groups
				if(self.Menu.Combo.SmartRSettings.UseSmartRGroup:Value()) then
					local enemies = GetEnemyHeroes(R.Range)
					local ultCastPos = self:GenerateRPriorityPosition(myHero.pos)
					if not ultCastPos then return end
					local dir = (ultCastPos - myHero.pos):Normalized()
					ultCastPos = myHero.pos + (dir*400)
					local canUltHit = true
					if(#enemies > 0) then
						for _, enemy in pairs (enemies) do
							if(IsValid(enemy)) then
								local predData = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Range = 400, Radius = 100, Speed = 2200}
								local tarPredPos = GGPrediction:SpellPrediction(predData)
								tarPredPos:GetPrediction(enemy, myHero)
								tarPredPos = tarPredPos.CastPosition or enemy.pos
								if(tarPredPos) then
									if(self:IsPointInRRectangle(tarPredPos, myHero.pos, dir) == false) then
										canUltHit = false
										break;
									end
								end
							end
						end

						if(canUltHit) and #enemies >= self.Menu.Combo.SmartRSettings.UseSmartRGroupAmnt:Value() then
							Control.CastSpell(HK_R, ultCastPos)
						end
					end

				end

			end
		end
	end
	SmartR()

	--Melee Peel R
	if(self.Menu.Combo.RMeleePeel.Enabled:Value()) then
		if(Ready(_R)) then
			local enemies = GetEnemyHeroes(375)
			if(#enemies > 0) then
				for _, enemy in pairs(enemies) do
					if(IsValid(enemy) and enemy.range <= 250 and GetDistance(myHero, enemy) <= 200) then
						if(self.Menu.Combo.RMeleePeel[enemy.charName]) then
							if(self.Menu.Combo.RMeleePeel[enemy.charName]:Value()) then
								-- We can cast
								local ultCastPos = self:GenerateRPriorityPosition(myHero.pos)
								if(ultCastPos) then
									local dir = (ultCastPos - myHero.pos):Normalized()
									ultCastPos = myHero.pos + (dir*400)
									Control.CastSpell(HK_R, ultCastPos)
									print("Azir Ult Melee Peel!")
								end
							end
						end
					end
				end
			end
		end
	end

	--Auto Q
	if(self.Menu.Combo.AutoQ:Value()) then
		local tar = GetTarget(Q.Range + SoldierRadius*0.75) --Extend the range a bit. We just need the soldier to get into AA range, so the Q doesn't have to necessarily land right on the target.
		self:RepositionQOnUnit(tar)
	end

	--Semi-manual Q
	if(self.Menu.Combo.SemiManualQ:Value()) then
		local tar = GetTarget(Q.Range + SoldierRadius*0.75) --Extend the range a bit. We just need the soldier to get into AA range, so the Q doesn't have to necessarily land right on the target.
		self:AttackQOnUnit(tar)
	end

	--W Placement
	if(self.Menu.Combo.WSettings.UseW:Value()) then
		if(Ready(_W)) then
			-- Our W placement depends on our settings
			local searchRange = W.Range + SoldierRadius*0.75
			if(Ready(_Q) and self.Menu.Combo.WSettings.WQCombo:Value()) then
				searchRange = Q.Range + SoldierRadius*0.75
			end

			local tar = GetTarget(searchRange) --Extend the range a bit. We just need the soldier to get into AA range, so the Q doesn't have to necessarily land right on the target.
			if(IsValid(tar)) then
				local WDelay = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 525, Radius = 100, Speed = 2000}
				local WPred = GGPrediction:SpellPrediction(WDelay) --Get the targets predicted position
				WPred:GetPrediction(tar, myHero)
				local predPos = Vector(WPred.CastPosition.x, tar.pos.y, WPred.CastPosition.z) or tar.pos
				if(tar.pathing and tar.pathing.isDashing) then
					predPos = tar.pathing.endPos
				end
				if(predPos) then
					if(GetDistance(myHero.pos, predPos) <= searchRange and GetDistance(myHero.pos, tar.pos) <= searchRange) then

						local dist = math.min(GetDistance(myHero, predPos), W.Range)
						local castPos = myHero.pos:Extended(predPos, dist)
						if(self:IsSoldierOnPosition(castPos) == false) then

							local towerCheck = true	
							if(self.Menu.Combo.WSettings.WTowerCheck:Value()) then
								if(IsUnderTurret(castPos) and myHero:GetSpellData(_W).level >= 4) then
									towerCheck = false
								end
							end

							Control.CastSpell(HK_W, castPos)
						end

					end
				end
			end
		end
	end

	--Killsteal Settings
	local function KillSteal()
		--Q
		if(self.Menu.Combo.Killsteal.UseQ:Value()) then
			if(Ready(_Q)) then
				local enemies = GetEnemyHeroes(1500)
				if(#enemies > 0) then
					for _, enemy in pairs (enemies) do
						if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
							if(CantKill(enemy, true, false, false)==false) then
								if(GetDistance(myHero, enemy) <= Q.Range + SoldierRadius*0.75) then

									local dmg = self:GetRawAbilityDamage("Q")
									local sCount = self:GetSoldierCount()
									if(sCount > 1) then
										dmg = dmg + self:GetRawAbilityDamage("W")
										dmg = dmg + (self:GetRawAbilityDamage("W")* 0.25 * (sCount - 1))
									else
										dmg = dmg + self:GetRawAbilityDamage("W")
									end
									dmg = CalcMagicalDamage(myHero, enemy, dmg)
									if(enemy.health - dmg <= 0) then
										self:AttackQOnUnit(enemy)
									end
								end
							end
						end
					end
				end
			end
		end

		--E Bodyslam
		if(self.Menu.Combo.Killsteal.UseE:Value()) then
			if(Ready(_E)) then
				local enemies = GetEnemyHeroes(1650)
				local enemyCheck = false

				--If we have UseEAlone on, we only want to E if there's 1 target.
				if(self.Menu.Combo.Killsteal.UseEAlone:Value()) then
					if(#enemies == 1) then
						enemyCheck = true
					end
				else
					if(#enemies > 0) then
						enemyCheck = true
					end
				end

				if(enemyCheck) then
					for _, enemy in pairs (enemies) do
						if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
							if(CantKill(enemy, true, false, false)==false) then
								local soldier = self:GetClosestSoldierFromPos(enemy.pos)
								if(soldier and GetDistance(myHero, soldier) <= E.Range) then
									local dmg = self:GetRawAbilityDamage("E")
									dmg = CalcMagicalDamage(myHero, enemy, dmg)
									if(enemy.health - dmg <= 0) then
										--Check for collision
										local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(soldier.pos, myHero.pos, 3000, 0, myHero.boundingRadius, {GGPrediction.COLLISION_ENEMYHERO})
										if(collisionCount == 1) and not IsUnderTurret(enemy) then
											Control.CastSpell(HK_E, soldier)
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
	KillSteal()
end

function Azir:Flee()
	if not (myHero.valid or IsValid(myHero)) then return end

	if(self.Menu.Flee.InsecFlee:Value()) then
		self:SmartFlee()
	end
end

function Azir:Harass()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	--This code will allow us to poke enemy champions by auto attacking a minion in the direct line of sight
	if(self.Menu.Harass.MinionHarass:Value()) then
		local target = GetTarget(TetherRange + 450) --Max range a soldier's spear will hit is 450
		if(IsValid(target)) then
			--Check to see if the direction vector of us hitting the minion intersects with the enemy champion
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(TetherRange + SoldierRadius)
			if(#minions > 0) then
				for i = 1, #minions do
					local minion = minions[i]
					if(minion and IsValid(minion)) then
						--Check with each soldier
						for _, soldier in ipairs(self.SoldierData) do
							if(GetDistance(myHero.pos, soldier.pos) <= TetherRange) then
								local diffVec = soldier.pos + (minion.pos - soldier.pos):Normalized() * 450
								local point, isOnSegment = ClosestPointOnLineSegment(target.pos, soldier.pos, diffVec)
								if(isOnSegment) then
									local distCheck = GetDistance(target.pos, point)
									if distCheck < 75 then
										--Good to use it!
										_G.SDK.Orbwalker:Attack(minion)
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

	if(self.Menu.Harass.UseW:Value()) then
		if(Ready(_W)) then
			local shouldW = true
			if(self.Menu.Harass.KeepSoldier:Value()) then
				if(self:GetSoldierCharges() <= 1) then
					shouldW = false
				end
			end

			if(shouldW) then
				local tar = GetTarget(W.Range + SoldierRadius*0.75)
				if(IsValid(tar)) then
					if(self:IsSoldierOnUnit(tar) == false) then
						local WDelay = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Range = 525, Radius = SoldierRadius, Speed = math.huge}
						local WPred = GGPrediction:SpellPrediction(WDelay) --Get the targets predicted position
						WPred:GetPrediction(tar, myHero)
						if(WPred.CastPosition) then
							if(GetDistance(myHero.pos, WPred.CastPosition) >= W.Range) then
								Control.CastSpell(HK_W, myHero.pos:Extended(WPred.CastPosition, W.Range))
							else
								Control.CastSpell(HK_W, WPred.CastPosition)
							end
						end
					end
				end
			end
		end
	end

	if(self.Menu.Harass.UseQ:Value()) then
		if(Ready(_Q)) then
			if(myHero.mana / myHero.maxMana) >= (self.Menu.Harass.MinimumManaQ:Value() / 100) then
				local tar = GetTarget(Q.Range + SoldierRadius*0.75) --Extend the range a bit. We just need the soldier to get into AA range, so the Q doesn't have to necessarily land right on the target.
				self:RepositionQOnUnit(tar)
			end
		end
	end
end

function Azir:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
end

function Azir:Clear()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(W.Range + SoldierRadius)
	local jungleMinions = {}
	local laneMinions = {}
	for i = 1, #minions do
		local minion = minions[i]
		if(IsValid(minion)) then
			if(minion.team == TEAM_JUNGLE) then
				table.insert(jungleMinions, minion)
			else
				table.insert(laneMinions, minion)
			end
		end
	end

	if(#jungleMinions > 0) and IsUnderFriendlyTurret(myHero) == false and IsUnderTurret(myHero) == false then
		self:JungleClear(jungleMinions)
	end

	if(#laneMinions > 0) then
		self:LaneClear(laneMinions)
	end
end

function Azir:JungleClear(minions)
	for _, minion in pairs(minions) do
		if(self.Menu.Clear.Jungle.UseW:Value()) then
			if(Ready(_W)) then
				local clusterMinions = GetMinionsAroundMinion(W.Range, W.Radius, minion)
				--Putting our soldier in groups of minions
				if(#clusterMinions >= 1) then 
					local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
					if(self.Menu.Clear.Jungle.StackW:Value()) then
						Control.CastSpell(HK_W, clusterMinionsAvgPos)
						return
					else
						if(self:IsSoldierOnPosition(clusterMinionsAvgPos) == false) then
							Control.CastSpell(HK_W, clusterMinionsAvgPos)
							return
						end
					end
				else
				--Putting our soldier on one minion
					if(self.Menu.Clear.Jungle.StackW:Value()) then
						Control.CastSpell(HK_W, minion.pos)
						return
					else
						if(self:IsSoldierOnPosition(minion.pos) == false) then
							Control.CastSpell(HK_W, minion.pos)
							return
						end
					end
				end
			end
		end

		if(self.Menu.Clear.Jungle.UseQ:Value()) then
			if(Ready(_Q) and self:GetSoldierCount() >= 1) then
				--[[
				Use our Q in the following situations:
				1. Reposition our W with Q to be on the target.
				2. Last hit a minion
				3. Dash through and hit at least 3 minions
				--]]

				--#1
				local clusterMinions = GetMinionsAroundMinion(W.Range, W.Radius, minion)
				if(#clusterMinions >= 1) then 
					local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
					local distanceData = self:GetSoldierDistancesFromPosition(clusterMinionsAvgPos)
					for _, data in pairs(distanceData) do
						if(data[2] > SoldierRadius + 75) then
							Control.CastSpell(HK_Q, clusterMinionsAvgPos)
							return
						end
					end
				else
					local distanceData = self:GetSoldierDistancesFromPosition(minion.pos)
					for _, data in pairs(distanceData) do
						if(data[2] > SoldierRadius + 75) then
							Control.CastSpell(HK_Q, minion.pos)
							return
						end
					end
				end

				--#2
				local QDam = self:GetRawAbilityDamage("Q")
				if(minion.health - QDam < 0) then
					Control.CastSpell(HK_Q, minion.pos)
				end

				--#3
				-- We're going to bias this to move the soldier towards the player
				for _, soldier in ipairs(self.SoldierData) do
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(soldier.pos, myHero.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION})
					if(collisionCount >= 3) then
						local closestMinion = minion
						for _, obj in ipairs(collisionObjects) do
							if(GetDistance(obj.pos, myHero.pos) <= GetDistance(closestMinion.pos, myHero.pos)) then
								closestMinion = obj
							end
						end

						--Start using this on minions with less than 75% HP. This is so that we don't immediately try to Q when we pull a pack of monsters because this may mess up our W positioning.
						if(closestMinion.health / closestMinion.maxHealth <= 0.75) then
							Control.CastSpell(HK_Q, closestMinion.pos)
							return
						end
					end
				end
			end
		end
	end
end

function Azir:LaneClear(minions)
	local soldierIsOnMinions = self:IsSoldierOnMinions(minions)
	local canonMinion = GetCanonMinion(minions)

	for _, minion in pairs(minions) do
		if(self.Menu.Clear.Lane.UseW:Value()) then
			if(myHero.levelData.lvl >= self.Menu.Clear.Lane.WLevelReq:Value()) then
				if(Ready(_W)) then
					local clusterMinions = GetMinionsAroundMinion(W.Range + SoldierRadius, W.Radius, minion)
					--Putting our soldier in groups of minions
					if(#clusterMinions >= 2) then 
						local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
						local shouldW = true

						if(myHero.levelData.lvl < self.Menu.Clear.Lane.WSoldierLevelReq:Value()) then
							if(self:GetSoldierCharges() <= 1) then
								shouldW = false
							end
						end

						if(self:IsSoldierOnPosition(clusterMinionsAvgPos) == false) and shouldW then
							Control.CastSpell(HK_W, clusterMinionsAvgPos)
							return
						end
					end
				end
			end
		end

		--Reposition if your W isnt on any minions
		if(self.Menu.Clear.Lane.UseQReposition:Value()) then
			if(myHero.levelData.lvl >= self.Menu.Clear.Lane.QLevelReq:Value()) then
				if(myHero.mana/myHero.maxMana >= self.Menu.Clear.Lane.MinimumManaQ:Value()/100) then
					if(Ready(_Q) and self:GetSoldierCount() >= 1) then
						if(soldierIsOnMinions == false) then
							local clusterMinions = GetMinionsAroundMinion(W.Range, W.Radius + SoldierRadius, minion)
							if(#clusterMinions >= 1) then 
								local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
								Control.CastSpell(HK_Q, clusterMinionsAvgPos)
								return
							else
								Control.CastSpell(HK_Q, minion.pos)
								return
							end
						end
					end
				end
			end
		end

		--Last hit canon with Q
		if(self.Menu.Clear.Lane.UseQCanon:Value()) then
			if(myHero.mana/myHero.maxMana >= self.Menu.Clear.Lane.MinimumManaQ:Value()/100) then
				if(Ready(_Q) and self:GetSoldierCount() >= 1) then

					--Prioritize the canon minion if its low
					if(canonMinion ~= nil) and IsValid(canonMinion) then
						local closestSolider = self:GetClosestSoldierFromPos(canonMinion.pos)
						if(closestSolider ~= nil) then
							local QDam = self:GetRawAbilityDamage("Q")
							local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (GetDistance(closestSolider.pos, canonMinion.pos)/Q.Speed))
							if ((hp > 0) and (canonMinion.health + (canonMinion.maxHealth * 0.05)  - QDam <= 0)) then
								Control.CastSpell(HK_Q, canonMinion)
								return
							end
						end
					end

				end
			end
		end
	end
end

local shouldECast, ECastPos = false, nil

function Azir:AutoEDodge()

	if(shouldECast) and ECastPos ~= nil then
		Control.CastSpell(HK_E, ECastPos)
		if(myHero.pathing and myHero.pathing.isDashing) or Ready(_E) == false then
			shouldECast = false
			ECastPos = nil
		end
	end

	if not Ready(_E) then return end

	local targets = GetEnemyHeroes(2500)
	for _, unit in ipairs(targets) do
		local ePos = unit.pos
		local eSpell = unit.activeSpell
		if(eSpell and eSpell.valid and unit.isChanneling) then

			local canDodge = true
			local dangerousSpell = false
			if(myHero.health / myHero.maxHealth > self.Menu.AutoEDodge.MinHP:Value()/100) then
				canDodge = false
			end

			local CastPos = eSpell.startPos
			local PlacementPos = eSpell.placementPos
			local Width = eSpell.width

			if(CastPos and PlacementPos and (eSpell.width > 0 and canDodge) or dangerousSpell) then
				local VCastPos = Vector(CastPos.x, CastPos.y, CastPos.z)
				local VPlacementPos = Vector(PlacementPos.x, PlacementPos.y, PlacementPos.z)
				local CastDirection = Vector((VCastPos - VPlacementPos):Normalized())
				local PlacementPos2 = VCastPos - CastDirection * eSpell.range
				local point, isOnSegment = ClosestPointOnLineSegment(myHero.pos, PlacementPos2, VCastPos)

				--Linear Skillshots
				if isOnSegment and eSpell.width > 0 then
					local distCheck = GetDistance(myHero.pos, point)
					if distCheck < Width*2 + myHero.boundingRadius then

						--First check to see if we have an existing W we can hop to!
						for _, soldier in ipairs(self.SoldierData) do
							local sPoint, sIsOnSegment = ClosestPointOnLineSegment(soldier.pos, PlacementPos2, VCastPos)
							if(GetDistance(soldier.pos, sPoint) > Width*2 + myHero.boundingRadius) then
								Control.CastSpell(HK_E, soldier.pos)
								return
							end
						end

						if(Ready(_W)) then
							local perpendicularLine =  Vector(CastDirection.z, 0, -CastDirection.x)
							local perpendicularLineNeg =  Vector(-CastDirection.z, 0, CastDirection.x)
							local castPos = nil

							--[[
							We need to generate a cast position for Azir to jump to. Some important considerations:
							1. We should bias this towards our mouse, unless our mouse is directly at an angle towards the enemy spell, in which case we will just bias it perpendicularly
							2. We need to check for wall collision
							3. We should not auto dodge under tower, that's a bad idea
							--]]

							local mouseDot = dotProduct3D(Vector(myHero.pos - unit.pos):Normalized(), Vector(myHero.pos - Game.mousePos()):Normalized())
							local p1 = (myHero.pos + (perpendicularLine * W.Range))
							local p2 = (myHero.pos + (perpendicularLineNeg * W.Range))
							local p1bad, p2bad = false, false
							if MapPosition:intersectsWall(myHero.pos, p1) or IsPositionUnderTurret(p1) then
								p1bad = true
							end

							if MapPosition:intersectsWall(myHero.pos, p2) or IsPositionUnderTurret(p2) then
								p2bad = true
							end
							
							--If our mouse is aimed towards the champion, we want to bias moving perpendicular, favouring our mouse angle. This logic changes if there is a wall adjacent.
							if(mouseDot >= 0) then 
								if(GetDistance(Game.mousePos(), p1) < GetDistance(Game.mousePos(), p2)) then
									if(p1bad == false) then
										castPos = p1
									else
										if(p2bad == false) then
											castPos = p2
										end	
									end
								else
									if(p2bad == false) then
										castPos = p2
									else
										if(p1bad == false) then
											castPos = p1
										end	
									end
								end
							else
								--If our mouse is aimed away from the enemy, we are going to dash towards our mouse direction assuming it won't hit a wall.
								--We are also going to make sure that the position we dash to is safe, if it's not - we will offset it by the width of the spell against the line isOnSegment
								local travelPos = (myHero.pos + (Vector(Game.mousePos() - myHero.pos):Normalized() * W.Range))

								--If our travelPos is still on the spell's width, we can extend the vector between the line point and the travel pos to be further out so we don't get hit
								local sPoint, sIsOnSegment = ClosestPointOnLineSegment(travelPos, PlacementPos2, VCastPos)
								if(sIsOnSegment) then
									sPoint = Vector(sPoint.x, travelPos.y, sPoint.z)
									if(GetDistance(sPoint, travelPos) <= Width*2 + myHero.boundingRadius) then
										travelPos = sPoint:Extended(travelPos, Width*2 + myHero.boundingRadius + 100)
									end
								end
								castPos = travelPos
							end
							if(castPos ~= nil) then
								Control.CastSpell(HK_W, castPos)
								DelayEvent(function() 
									shouldECast = true
									ECastPos = castPos
								end, 0.02)
							end
							return
						end
					end
				end

			end

		end
	end
end

function Azir:GenerateRPriorityPosition(checkFromPos)
	--Based on a priority system, this will indicate which direction we want to send our ultimate towards.

	--[[ 
		PRIORITY:
		1. Towards a Terrain Trap
		2. Towards Ally Tower
		3. Towards Team Cluster
		4. Towards Healthiest/Tankiest Ally
		5. Towards Engage Direction
	]]

	-- #1
	if(self.Menu.UltPrio.Prio1:Value()) then
		local canTrap, trapPos = self:CanUltTrapAtPoint(checkFromPos)
		if(canTrap) then
			--print("Trapping" ..GameTimer())
			return trapPos
		end
	end
	
	if(self.Menu.UltPrio.Prio2:Value()) then
		local function FetchClosestTurret()
			local azirTurr, friendlyTurr = nil, nil

			local function FetchAzirTurret()
				-- #2 (Azir Turret)
				if(self.PassiveTurret and not self.PassiveTurret.dead) then
					if(GetDistance(self.PassiveTurret, checkFromPos) <= 3000) then

						--We're comfortable ulting towards the tower if there's a clear line of sight from us towards it.
						--We're also comfortable ulting towards the tower if it will knock enemies under it across walls.
						local intersectCheck = MapPosition:getIntersectionPoint3D(checkFromPos, self.PassiveTurret.pos)
						if GetDistance(intersectCheck, self.PassiveTurret.pos) <= 400 or not intersectCheck then
							return self.PassiveTurret
						end

						if(intersectCheck) then
							local dirCastPos = checkFromPos:Extended(self.PassiveTurret.pos, 650)
							if(GetDistance(self.PassiveTurret, dirCastPos) <= 1000 and self:HasWallFailure(checkFromPos, dirCastPos, 325) == false) then
								return self.PassiveTurret
							end
						end
					end		
				end
			end

			local function FetchFriendlyTurret()
				-- #2
				local closestTurret = GetClosestFriendlyTurret()
				if(closestTurret) then
					if(GetDistance(closestTurret, checkFromPos) <= 3000) then

						--We're comfortable ulting towards the tower if there's a clear line of sight from us towards it.
						--We're also comfortable ulting towards the tower if it will knock enemies under it across walls.
						local intersectCheck = MapPosition:getIntersectionPoint3D(checkFromPos, closestTurret.pos)
						if GetDistance(intersectCheck, closestTurret.pos) <= 400 or not intersectCheck then
							return closestTurret
						end

						if(intersectCheck) then
							local dirCastPos = checkFromPos:Extended(closestTurret.pos, 650)
							if(GetDistance(closestTurret, dirCastPos) <= 1000 and self:HasWallFailure(checkFromPos, dirCastPos, 325) == false) then
								return closestTurret
							end
						end
					end
				end
			end

			azirTurr = FetchAzirTurret()
			friendlyTurr = FetchFriendlyTurret()
			if(azirTurr and friendlyTurr) then
				if(GetDistance(azirTurr.pos, checkFromPos) <= GetDistance(friendlyTurr.pos, checkFromPos)) then
					return azirTurr
				else
					return friendlyTurr
				end
			else
				if(azirTurr) then
					return azirTurr
				else
					return friendlyTurr
				end
			end

			return nil
		end

		local towerResult = FetchClosestTurret()
		if(towerResult) then
			return towerResult.pos
		end
	end

	-- #3
	local allies = GetAllyHeroes(2100)
	if(#allies >= 1) then
		local bestPos, count = CalculateBestCirclePosition(allies, 450, false)
		if(count >= 2) and (self.Menu.UltPrio.Prio3:Value()) then
			return bestPos
		end

		-- #4
		if(self.Menu.UltPrio.Prio4:Value()) then
			local tankiestAlly = nil
			for _, ally in ipairs(allies) do
				if(ally.health / ally.maxHealth >= 0.5 and ally.health > myHero.health) then
					if(tankiestAlly == nil) then tankiestAlly = ally end

					if(ally.health > tankiestAlly.health) then
						tankiestAlly = ally
					end
				end
			end

			if(IsValid(tankiestAlly)) then
				return tankiestAlly.pos
			end
		end
	end

	-- #5
	if(self.EngagePosition) then
		--print("Casting at engage")
		return self.EngagePosition
	end

	return nil
end

local azirTowerTick = GameTimer()
function Azir:CheckAzirTurret()
	if(azirTowerTick < GameTimer()) then
		if(myHero.activeSpell.valid and myHero.activeSpell.name == "AzirTowerClickChannel") then
			azirTowerTick = GameTimer() + 1
			DelayEvent(function()
				for i = 1, Game.TurretCount() do
					local turret = Game.Turret(i)
					if turret and turret.name == "Obelisk" then 
						self.PassiveTurret = turret
					end
				end
			end, 1)
		end
	end

	if(not self.PassiveTurret or self.PassiveTurret.dead or self.PassiveTurret.name ~= "Obelisk") then
		self.PassiveTurret = nil
	end
end

function Azir:HoverAzirTurretCheck()
	--This is a fallback method to track azir turrets if for some reason our other function doesn't catch it.
	local hoverTar = Game.GetUnderMouseObject()
	if(hoverTar) then
		if(self.PassiveTurret == nil) then
			if not hoverTar.dead and hoverTar.name == "Obelisk" then 
				self.PassiveTurret = hoverTar
			end
		end
	end
end

function Azir:CanUltTrapAtPoint(point)
	local precision = 12 --The higher the number, the more angular checks we do
	local directions = {
	(Vector(math.cos(math.rad(0)), 0, math.sin(math.rad(0))) ):Normalized()
	}

	for i = 1, precision do
		local angle = (360/precision) * i
		local dirAngle = (Vector(math.cos(math.rad(angle)), 0, math.sin(math.rad(angle))) ):Normalized()
		table.insert(directions, dirAngle)
	end

	for _, dir in pairs(directions) do
		local pos1 = point + (dir*400)

		local vecNormal = (point - pos1):Normalized()
		local perp = Vector(vecNormal.z, 0, -vecNormal.x) * (self:GetRRadius()+75) + pos1
		local negPerp = Vector(-vecNormal.z, 0, vecNormal.x) * (self:GetRRadius()+75) + pos1

		local perpIntersect, negPerpIntersect = MapPosition:getIntersectionPoint3D(pos1, perp), MapPosition:getIntersectionPoint3D(pos1, negPerp)
	
		if(perpIntersect and negPerpIntersect and not MapPosition:inWall(pos1)) then
			local intersect = MapPosition:getIntersectionPoint3D(pos1, pos1+(dir*600))
			if(intersect) then
				local dist = GetDistance(intersect, pos1)
				if(dist > 200) then

					local precisionPass = true
					local checkVecs = {
						dir:Rotated(0, math.rad(22.5), 0):Normalized() * (dist+150) + pos1,
						dir:Rotated(0, math.rad(45), 0):Normalized() * (dist+150) + pos1,
						dir:Rotated(0, math.rad(67.5), 0):Normalized() * (dist+150) + pos1,
						dir:Rotated(0, math.rad(-22.5), 0):Normalized() * (dist+150) + pos1,
						dir:Rotated(0, math.rad(-45), 0):Normalized() * (dist+150) + pos1,
						dir:Rotated(0, math.rad(-67.5), 0):Normalized() * (dist+150) + pos1,
					}
					for _, checkVec in pairs(checkVecs) do
						local angleIntersect = MapPosition:getIntersectionPoint3D(pos1, checkVec)
						if(not angleIntersect) then
							precisionPass = false
							break;
						end
					end

					if(precisionPass) then
						--[[
						DrawCircle(intersect, 50, 3, DrawColor(255, 0, 255, 0))
						DrawLine(point:To2D(), pos1:To2D())
						DrawLine(pos1:To2D(), perp:To2D())
						DrawLine(pos1:To2D(), negPerp:To2D())

						for _, checkVec in pairs(checkVecs) do
							local angleIntersect = MapPosition:getIntersectionPoint3D(pos1, checkVec)
							if(angleIntersect) then
								DrawLine(pos1:To2D(), angleIntersect:To2D())
							end
						end
						--]]
						return true, pos1
					end
				end
			end
		end
	end

	return false
end

function Azir:IsPointInRRectangle(point, castPos, directionVec, buffer)
	local ultBuffer = buffer or 0
	local sPos = castPos + (directionVec*-(285-ultBuffer))
	local ePos = castPos + (directionVec*(365-ultBuffer))

	local p, isOnSegment = ClosestPointOnLineSegment(point, sPos, ePos)
	if(isOnSegment) then
		if(GetDistance(p, point) <= self:GetRRadius() - 50) then
			return true
		end
	end

	return false
end

Azir.ShouldRFlash = false
function Azir:RPullCombo()
	_G.SDK.Orbwalker:Orbwalk()
	local flashRange = 400
	local flashEnabled = self.Menu.Combo.ToggleFlash:Value()
	local dashingCheck = myHero.pathing and myHero.pathing.isDashing
	local GGOrbwalkerTarget = _G.SDK.TargetSelector.Selected
	if(Ready(_R)) then

		--R Casting
		local tarRangeCheck, nearbyEnemiesRangeCheck = 0, 0
		if(flashEnabled) then
			tarRangeCheck = MaxEngageRange + flashRange
			nearbyEnemiesRangeCheck = MaxEngageRange + flashRange + self:GetRRadius()
		else
			tarRangeCheck = MaxEngageRange
			nearbyEnemiesRangeCheck = MaxEngageRange + self:GetRRadius()
		end

		local tar = GetTarget(tarRangeCheck)
		if(not IsValid(tar)) then return end
		-- Generate a targets predicted position after R's delay
		local predData = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Range = 400, Radius = 100, Speed = 2200}
		local tarPredPos = GGPrediction:SpellPrediction(predData)
		tarPredPos:GetPrediction(tar, myHero)
		tarPredPos = tarPredPos.CastPosition or tar.pos

		local nearbyEnemies = GetEnemiesAtPos(nearbyEnemiesRangeCheck, self:GetRRadius(), tarPredPos, tar)
		local bestPos, count, newCluster
		if(#nearbyEnemies > 1) then
			bestPos, count, newCluster = CalculateBestCirclePosition(nearbyEnemies, self:GetRRadius(), false, R.Range, R.Speed, R.Delay)
		end

		-- R USAGE
		if(IsValid(tar)) then
			local pos = nil
			if(self.RTravelPos ~= nil) then
				if(bestPos) then
					pos = self:GenerateRPriorityPosition(bestPos)
				else
					pos = self:GenerateRPriorityPosition(self.RTravelPos)
				end
			else
				pos = self:GenerateRPriorityPosition(myHero.pos)
			end

			if(bestPos) then
				if(not dashingCheck or GetDistance(myHero, bestPos) <= 175) then
					if(self.EngagePosition == nil) then
						self.EngagePosition = bestPos:Extended(myHero.pos, GetDistance(myHero, bestPos) + 100)
					end
		
					if(pos) then
						local dir = (pos - myHero.pos):Normalized()
						pos = myHero.pos + (dir*400)
						local rectCheck = false
						for _, enemy in ipairs(newCluster) do --Make sure at least one enemy is in the ult rectangle so we dont waste
							if(self:IsPointInRRectangle(enemy.pos, myHero.pos, dir)) then
								rectCheck = true
							end

							if(GGOrbwalkerTarget and IsValid(GGOrbwalkerTarget)) then
								--If our GGOrbwalker Selected Target is also in our ult range, we can ult!
								if(self:IsPointInRRectangle(GGOrbwalkerTarget.pos, myHero.pos, dir)) then
									rectCheck = true
									break;
								else
									rectCheck = false
									break;
								end
							else
								--Check if at least our standard target is in the ult range
								if(self:IsPointInRRectangle(tar.pos, myHero.pos, dir)) then
									rectCheck = true
									break;
								end
							end
						end

						if(rectCheck) then
							Control.CastSpell(HK_R, pos)
							self.RTravelPos = nil
						end

					end	
				end	
			else
				if(not dashingCheck or GetDistance(myHero, tar.pos) <= 200) then
					if(self.EngagePosition == nil) then
						self.EngagePosition = tar.pos:Extended(myHero.pos, GetDistance(myHero, tar) + 100)
					end
		
					if(pos) then
						local dir = (pos - myHero.pos):Normalized()
						pos = myHero.pos + (dir*400)
						local rectCheck = self:IsPointInRRectangle(tar.pos, myHero.pos, dir, 20)
						if(rectCheck) then
							Control.CastSpell(HK_R, pos)
							self.RTravelPos = nil
						end
					end
				end
			end
		end

		if(flashEnabled) then
			if(self.RTravelPos ~= nil) and CanFlash() then
				if(bestPos) then
					if(GetDistance(myHero, bestPos) <= flashRange + 150 and GetDistance(myHero, bestPos) >= 150) and GetDistance(self.RTravelPos, bestPos) >= 200 then
						UseFlash(bestPos)
						return
					end		
				else
					if(GetDistance(myHero, tar) <= flashRange + 150 and GetDistance(myHero, tar) >= 100) and GetDistance(self.RTravelPos, tar) >= 200 then
						UseFlash(tar.pos)
						return
					end
				end
			end
		end


		-- There are two ways we can engage: W - > E, and W -> E -> Q 
		-- Largely it matters the distance we are from the target on which engage we use.
		if(IsValid(tar)) then
			
			--Use E to fly on top of enemies via soldier
			if(Ready(_E) and GetDistance(tar, myHero) <= E.Range) then
				local nearbySoldiers = self:GetSoldiersNearUnit(tar)
				for _, soldier in pairs(nearbySoldiers) do
					if(soldier) then
						if(GetDistance(soldier, tar) <= 150) then
							self.EngagePosition = myHero.pos
							self.RTravelPos = soldier.pos
							Control.CastSpell(HK_E, soldier.pos)
							break;
						end
					end
				end
			end

			-- Use Q to travel for long distance enemies
			if(Ready(_Q)) then
				if(#self:GetSoldiersNearUnit(myHero) >= 1) then
					if (myHero.pathing and myHero.pathing.isDashing) and (GetDistance(myHero.pos, myHero.pathing.endPos) < SoldierRadius - 75) then
						if(bestPos) then
							if(GetDistance(myHero.pathing.endPos, bestPos) >= 300) then
								local maxQTravelVec = Vector( myHero.pos:Extended(bestPos, math.min(Q.Range, GetDistance(myHero, bestPos))) )

								--We need to check for collision because our E will slam into enemies
								local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, maxQTravelVec, 2000, 0, myHero.boundingRadius, {GGPrediction.COLLISION_ENEMYHERO})
								if(collisionCount >= 1) then
									local closestTar = nil
									for _, obj in pairs(collisionObjects) do
										if(closestTar == nil) then closestTar = obj end
										
										if(GetDistance(obj, myHero) <= GetDistance(closestTar, myHero)) then
											closestTar = obj
										end
									end

									if(IsValid(closestTar)) then
										maxQTravelVec = closestTar.pos:Extended(myHero.pos, closestTar.boundingRadius)
									end
								end
								self.RTravelPos = maxQTravelVec
								Control.CastSpell(HK_Q, bestPos)
							end
						else
							if(GetDistance(myHero.pathing.endPos, tar) >= 300) then
								local maxQTravelVec = Vector( myHero.pos:Extended(tar.pos, math.min(Q.Range, GetDistance(myHero, tar))) )
								self.RTravelPos = maxQTravelVec
								Control.CastSpell(HK_Q, tar)
							end
						end
					end
				end
			end


			-- W and E usage
			local targetPos = tar.pos
			if(IsValid(tar)) then
				targetPos = tarPredPos
			end
			if(bestPos) then
				targetPos = bestPos
			end

			if(Ready(_Q) and GetDistance(targetPos, myHero.pos) >= W.Range + 150 and GetDistance(targetPos, myHero.pos) < tarRangeCheck - 50) then

				--Q Range check based on if we are using flash or not
				local QRangeCheck = flashEnabled and (Q.Range + flashRange) or Q.Range -- Ternary operator 

				if(Ready(_E) and not (myHero.pathing and myHero.pathing.isDashing)) then
					local nearbySoldiers = self:GetSoldiersNearPosition(targetPos)
					if(bestPos) then
						for _, soldier in pairs(nearbySoldiers) do
							if(soldier) then
								if(GetDistance(soldier, bestPos) <= QRangeCheck and GetDistance(soldier, myHero) >= SoldierRadius) then
									self.EngagePosition = myHero.pos
									Control.CastSpell(HK_E, soldier.pos)
									break;
								end
							end
						end
					else
						for _, soldier in pairs(nearbySoldiers) do
							if(soldier) then
								if(GetDistance(soldier.pos, targetPos) <= QRangeCheck and GetDistance(soldier, myHero) >= SoldierRadius) then
									self.EngagePosition = myHero.pos
									Control.CastSpell(HK_E, soldier.pos)
									break;
								end
							end
						end
					end
				end

				--Place W and E if we have our Q up
				if(Ready(_W) and Ready(_E) and not (myHero.pathing and myHero.pathing.isDashing)) then
					local placementVec = myHero.pos:Extended(targetPos, W.Range)
					if(self:IsSoldierOnPosition(placementVec) == false and self:HasWallFailure(myHero.pos, placementVec, SoldierRadius) == false) then
						Control.CastSpell(HK_W, placementVec)
						return
					end
				end
			else
				--If we DON'T have our Q up
				if(Ready(_W) and Ready(_E) and GetDistance(targetPos, myHero.pos) < W.Range + 150) then
					if(self:IsSoldierOnPosition(targetPos) == false and self:HasWallFailure(myHero.pos, targetPos, SoldierRadius) == false) then
						Control.CastSpell(HK_W, targetPos)
						return
					end
				end
			end

		end
	else
		self.EngagePosition = nil
		self.RTravelPos = nil
	end
end

Azir.RevenantEngagePos = nil
Azir.RevenantTarSoldier = nil
Azir.RevenantQFollowup = false
function Azir:RevenantCombo()
	_G.SDK.Orbwalker:Orbwalk()
	if(Ready(_R)) then

		local tar = GetTarget(MaxEngageRange)
		if(not IsValid(tar)) then return end

		local nearbyEnemies = GetEnemiesAtPos(MaxEngageRange + self:GetRRadius(), self:GetRRadius(), tar.pos, tar)
		local bestPos, count, newCluster
		if(#nearbyEnemies > 1) then
			bestPos, count, newCluster = CalculateBestCirclePosition(nearbyEnemies, self:GetRRadius(), false, R.Range, R.Speed, R.Delay)
		end

		--We need to see if a revenant combo is possible first before we try to do that!
		--[[
		If we are trying to do it against a single target:
			- There has to be a direct line of sight between the solider and the player
			- The soldier has to be near the enemy, and behind it
			- The enemy cannot be pathing in the direction of the line of sight to the soldier

		If we are trying against a group:
			- We check the best position in the cluster
			- There has to be a direct line of sight between the solider and the player
			- The soldier has to be at the best position or behind it
			- We ideally want to at least grab one person with our R

		]]

		--Check to see if we can do the revenant:
		local canDoRevenant = false
		local targetPos = tar.pos
		local drawRevUI = self.Menu.Drawings.DrawRevenantUI:Value()
		local targetSoldier = self.RevenantTarSoldier
		if(bestPos) then
			targetPos = bestPos
		end
		local nearbySoldiers = self:GetSoldiersNearPosition(targetPos)
		
		--The combo
		if(self.RevenantEngagePos) then
			if(self.RevenantQFollowup) then
				local dirVec = myHero.pos:Extended(self.RevenantEngagePos, 200)
				if(bestPos and self:IsPointInRRectangle(bestPos, myHero.pos, (self.RevenantEngagePos - myHero.pos):Normalized())) then
					Control.CastSpell(HK_R, dirVec)
				end

				if(self:IsPointInRRectangle(tar.pos, myHero.pos, (self.RevenantEngagePos - myHero.pos):Normalized())) then
					Control.CastSpell(HK_R, dirVec)
				end

				if(GetDistance(myHero, tar.pos) <= 350) then
					Control.CastSpell(HK_R, dirVec)
				end
			end

			--Use E to fly to soldier pos
			if(Ready(_E) and targetSoldier and GetDistance(targetSoldier, myHero) <= E.Range) then
				Control.CastSpell(HK_E, targetSoldier.pos)
			end
			

			--Use Q to return back to engage pos
			if(Ready(_Q)) then
				if ((myHero.pathing and myHero.pathing.isDashing) and (GetDistance(myHero, myHero.pathing.endPos)) < (E.Speed * Q.Delay) + (_G.LATENCY/1000)*E.Speed) then
					Control.CastSpell(HK_Q, self.RevenantEngagePos)
					self.RevenantQFollowup = true
				end
			end
		end

		--Check if the combo is possible
		if(self.RevenantEngagePos == nil or self.RevenantTarSoldier == nil) then
			local ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Range = 1100, Radius = myHero.boundingRadius, Speed = 2800}
			local GGOrbwalkerTarget = _G.SDK.TargetSelector.Selected
			if(bestPos and _G.SDK.TargetSelector.Selected == nil) then
				--Multi target:
				for _, soldier in pairs(nearbySoldiers) do
					if(GetDistance(soldier, myHero) <= E.Range and GetDistance(soldier, myHero) >= SoldierRadius*2) then

						local hitsAnEnemy = false
						local hasLineOfSight = true
						
						for _, enemy in pairs(Enemies) do
							if(IsValid(enemy) and GetDistance(enemy, myHero) <= 1800) then
								--Find the target's predicted position 
								local EPred = GGPrediction:SpellPrediction(ESpell) --Get the targets predicted position
								EPred:GetPrediction(enemy, myHero)
								local tarCheckPos = EPred.CastPosition or Vector(tar.pos.x, 0, tar.pos.z)
								

								--Check if there's a clear line of sight
								local point, isOnSegment = ClosestPointOnLineSegment(tarCheckPos, myHero.pos, soldier.pos)
								if GetDistance(tarCheckPos, point) >= 160 then
									if(GetDistance(tarCheckPos, soldier) <= (self:GetRRadius())-50) then
										hitsAnEnemy = true
									end
								else
									hasLineOfSight = false
								end
							end
						end

						if(hasLineOfSight and hitsAnEnemy and GetDistance(myHero, soldier) >= GetDistance(myHero, bestPos) - 100) then
							canDoRevenant = true
							self.RevenantTarSoldier = soldier
							break;
						end

					end
				end

			else
				--Single target:
				for _, soldier in pairs(nearbySoldiers) do
					if(GetDistance(soldier, myHero) <= E.Range and GetDistance(soldier, myHero) >= SoldierRadius*2) then

						--Find the target's predicted position 
						local EPred = GGPrediction:SpellPrediction(ESpell) --Get the targets predicted position
						EPred:GetPrediction(tar, myHero)
						local tarCheckPos = EPred.CastPosition or Vector(tar.pos.x, 0, tar.pos.z)
						local point, isOnSegment = ClosestPointOnLineSegment(tarCheckPos, myHero.pos, soldier.pos)

						if(GetDistance(tarCheckPos, point) <= (self:GetRRadius())-50) then

							if(drawRevUI) then
								if GetDistance(tarCheckPos, point) >= 150 then
									DrawCircle(Vector(point), 150, 1, DrawColor(125, 255, 255, 255))
								else
									DrawCircle(Vector(point), 150, 2, DrawColor(255, 255, 0, 0))
								end
								DrawCircle(Vector(tarCheckPos), 2, 10, DrawColor(255, 255, 255, 255))
								DrawCircle(Vector(tarCheckPos), 5, 5, DrawColor(255, 255, 255, 255))
	
								local point3D = Vector(point.x, myHero.pos.y, point.z)
	
								local dirVec = (myHero.pos - soldier.pos):Normalized()
								local perp =  point3D + (Vector(dirVec.z, dirVec.y, -dirVec.x))*self:GetRRadius()
								local negPerp =  point3D + (Vector(-dirVec.z, dirVec.y, dirVec.x))*self:GetRRadius()
								DrawLine(point3D:To2D(), perp:To2D(), 3, DrawColor(255, 218, 224, 34))
								DrawLine(point3D:To2D(), negPerp:To2D(), 3, DrawColor(255, 218, 224, 34))
							end

							--Check if there's a clear line of sight
							if GetDistance(tarCheckPos, point) >= 160 and GetDistance(myHero, soldier) - 100 >= GetDistance(myHero, tarCheckPos) then
								canDoRevenant = true
								self.RevenantTarSoldier = soldier
								break;
							end
						end
					end
				end
			end
		end

		if(canDoRevenant and self.RevenantTarSoldier) then
			self.RevenantEngagePos = myHero.pos
		end
		-- End of check
	else
		self.RevenantEngagePos = nil
		self.RevenantQFollowup = false
	end
end

function Azir:GetRRadius()
	return (({6, 7, 8})[myHero:GetSpellData(_R).level] * 125)/2
end

local azirWBaseDamage = {
	[1] = 0,
	[2] = 0,
	[3] = 0,
	[4] = 0,
	[5] = 0,
	[6] = 0,
	[7] = 0,
	[8] = 0,
	[9] = 0,
	[10] = 2,
	[11] = 7,
	[12] = 12,
	[13] = 17,
	[14] = 32,
	[15] = 47,
	[16] = 62,
	[17] = 77,
	[18] = 92,
}

function Azir:GetRawAbilityDamage(spell)
	if(spell == "Q") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		return ({60, 80, 100, 120, 140})[myHero:GetSpellData(_Q).level] + (0.35 * myHero.ap)
	end
	
	if(spell == "W") then
		if myHero:GetSpellData(_W).level == 0 then return 0 end
		return ({50, 67, 84, 101, 118})[myHero:GetSpellData(_W).level] + (0.6 * myHero.ap) + azirWBaseDamage[myHero.levelData.lvl]
	end

	if(spell == "E") then
		if myHero:GetSpellData(_E).level == 0 then return 0 end
		return ({60, 100, 140, 180, 220})[myHero:GetSpellData(_E).level] + (0.4 * myHero.ap)
	end
	
	if(spell == "R") then
		if myHero:GetSpellData(_R).level == 0 then return 0 end
		return ({200, 400, 600})[myHero:GetSpellData(_R).level] + (0.75 * myHero.ap)
	end

	return 0
end

function Azir:RepositionQOnUnit(unit)
	if(Ready(_Q)) then
		if(IsValid(unit)) then
			local nearbySoldiers = self:GetSoldiersNearUnit(unit)
			if(self:IsSoldierOnUnit(unit) == false and #nearbySoldiers > 0) then
				local QDelay = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 740, Radius = 260, Speed = 2400}
				local QPred = GGPrediction:SpellPrediction(QDelay) --Get the targets predicted position
				QPred:GetPrediction(unit, myHero)
				if(QPred.CastPosition) then
					if(GetDistance(myHero.pos, QPred.CastPosition) <= Q.Range + SoldierRadius*0.75) then
						Control.CastSpell(HK_Q, QPred.CastPosition)
					end
				end
			end
			
			--If a soldier is on our target, but we are out of tether range, Q them into range so we can AA
			local tetherRange = TetherRange
			if(myHero.range == 575) then --Lethal tempo grants us 50 attack range, Azir's default attack range is 525.
				tetherRange = 800
			end

			local isSoldierOnUnit, soldierUnit = self:IsSoldierOnUnit(unit)
			if(isSoldierOnUnit and #nearbySoldiers > 0) then
				if(GetDistance(soldierUnit, myHero) >= tetherRange) then
					local QDelay = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 740, Radius = 260, Speed = 2400}
					local QPred = GGPrediction:SpellPrediction(QDelay) --Get the targets predicted position
					QPred:GetPrediction(unit, myHero)
					if(QPred.CastPosition) then
						if(GetDistance(myHero.pos, QPred.CastPosition) <= Q.Range + SoldierRadius*0.75) then
							local clampPos = myHero.pos:Extended(QPred.CastPosition, Q.Range - 150)
							Control.CastSpell(HK_Q, clampPos)
						end
					end			
				end
			end
		end
	end
end

function Azir:AttackQOnUnit(unit)
	if(Ready(_Q) and self:GetSoldierCount() > 0) then
		if(IsValid(unit)) then
			local closestSoldier = self:GetClosestSoldierFromPos(unit.pos)
			local QDelay = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 740, Radius = 100, Speed = 2000}
			local QPred = GGPrediction:SpellPrediction(QDelay) --Get the targets predicted position
			QPred:GetPrediction(unit, closestSoldier)
			if(QPred.CastPosition) then
				if(GetDistance(myHero.pos, QPred.CastPosition) <= Q.Range + SoldierRadius*0.75) then
					Control.CastSpell(HK_Q, QPred.CastPosition)
				end
			end
		end
	end
end

function Azir:GetSoldiersAroundMouse()
    local soldiers = {}
	local mousePos = Game.mousePos()
	if(#self.SoldierData > 0) then
		for i = 1, #self.SoldierData do
			local soldier = self.SoldierData[i]
			if soldier and GetDistance(soldier.pos, myHero.pos) <= E.Range and (GetDistance(soldier.pos, mousePos) < 400 or GetDistance(soldier.pos, myHero.pos:Extended(mousePos, 575)) < 400) then
				table.insert(soldiers, soldier)
			end
		end
	end

    return soldiers
end

function Azir:GetSoldierCount()
	return #self.SoldierData
end

function Azir:GetSoldierCharges()
	return myHero:GetSpellData(_W).ammo
end

function Azir:GetSoldiersNearUnit(unit)
	local soldiers = {}
	for _, soldier in ipairs(self.SoldierData) do
		if(GetDistance(unit.pos, soldier.pos) <= 1450) then
			table.insert(soldiers, soldier)
		end
	end

	return soldiers
end

function Azir:GetSoldiersNearPosition(pos)
	local soldiers = {}
	for _, soldier in ipairs(self.SoldierData) do
		if(GetDistance(pos, soldier.pos) <= 1450) then
			table.insert(soldiers, soldier)
		end
	end

	return soldiers
end

function Azir:GetClosestSoldierFromPos(pos)	
	if(#self.SoldierData) == 0 then return nil end
	local closestSoldier = self.SoldierData[1]

	for _, soldier in ipairs(self.SoldierData) do
		if(GetDistance(soldier.pos, pos) <= GetDistance(closestSoldier.pos, pos)) then
			closestSoldier = soldier
		end
	end

	return closestSoldier
end

function Azir:GetSoldierDistancesFromPosition(pos)
	local distances = {}
	
	if(#self.SoldierData) == 0 then return distances end

	for _, soldier in ipairs(self.SoldierData) do
		local data = {soldier, GetDistance(soldier, pos)}
		table.insert(distances, data)
	end

	return distances
end

function Azir:IsSoldierOnUnit(unit)
	for _, soldier in ipairs(self.SoldierData) do
		if(GetDistance(soldier, unit) <= SoldierRadius) then
			return true, soldier
		end
	end

	return false
end

function Azir:IsSoldierOnMinions(minions)
	local minionsOnSolider = {}
	for _, soldier in ipairs(self.SoldierData) do
		for _, minion in ipairs(minions) do
			if(GetDistance(soldier, minion) <= SoldierRadius) then
				table.insert(minionsOnSolider, minion)
			end
		end
	end

	if(#minionsOnSolider >= 1) then
		return true, minionsOnSolider 
	end

	return false, minionsOnSolider
end

function Azir:IsSoldierOnPosition(pos)
	if(#self.SoldierData) == 0 then return false end

	for _, soldier in ipairs(self.SoldierData) do
		if(GetDistance(soldier, pos) <= SoldierRadius) then
			return true, soldier
		end
	end

	return false
end

-- This function will let you know if the intended position you want to place your spell will go over a wall or not
function Azir:HasWallFailure(startPos, placementPos, radius)
	if(not MapPosition:inWall(placementPos)) then return false end
	
	local wallIntersect = MapPosition:getIntersectionPoint3D(startPos, placementPos)
	if(wallIntersect) then
		local maxRangeVec = startPos:Extended(placementPos, GetDistance(startPos, placementPos) + radius)
		
		if(MapPosition:inWall(maxRangeVec)) then return true end --If our extended vector is inside the wall then its just too thick

		local invWallIntersect = MapPosition:getIntersectionPoint3D(maxRangeVec, placementPos) --Check backwards to figure out length of wall
		if(invWallIntersect) then
			--If our placement position INSIDE THE WALL is closer to our intersection than it is end outside of it, we have a wall failure.
			if(GetDistance(placementPos, wallIntersect) <= GetDistance(placementPos, invWallIntersect)) then
				return true
			end
		end
	end

	return false
end

function Azir:SmartFlee()
	local mousePos = Game.mousePos()
	local wPos = myHero.pos + (mousePos - myHero.pos):Normalized() * W.Range
	local qPos = myHero.pos + (mousePos - myHero.pos):Normalized() * E.Range

	local mouseSoldiers = self:GetSoldiersAroundMouse()
	if Ready(_E) and #mouseSoldiers > 0 then 
		Control.CastSpell(HK_E)    
		return           
	end

	if Ready(_Q) and Ready(_W) and Ready(_E) and #mouseSoldiers == 0 then
		Control.CastSpell(HK_W, wPos) 
	end

	if(self.Menu.Flee.InsecFleeNoQ:Value()) then
		if not Ready(_Q) and Ready(_W) and Ready(_E) and #mouseSoldiers == 0 then
			Control.CastSpell(HK_W, wPos) 
		end
	end
	
	if Ready(_Q) and (myHero.pathing and myHero.pathing.isDashing) and (GetDistance(myHero.pos, myHero.pathing.endPos) < 200 + ((_G.LATENCY/1000)*E.Speed)) then	
		Control.CastSpell(HK_Q, qPos)
	end
end

function Azir:ManualKeys()
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

function Azir:UpdateSoldiers()
	for i = #self.SoldierData, 1, -1 do
		local soldier = self.SoldierData[i]
		if(soldier == nil or soldier.dead or GetDistance(myHero.pos, soldier.pos) >= 2000 or soldier.charName ~= "AzirSoldier") then
			table.remove(self.SoldierData, i)
		end
	end
end

function Azir:ScanSoldiers()
	local soldiers = self:GetSoldierObjects()
	for _, soldier in ipairs(soldiers) do
		if soldier and self:CheckExistingSoldier(soldier) == false then
			self.SoldierData[#self.SoldierData + 1] = soldier
		end
	end
end

function Azir:GetSoldierObjects()
	local soldiers = {}
	if (Game.mapID == SUMMONERS_RIFT) then
		for i = 0, 7250 do
			local obj = Game.Object(i)
			if obj and not obj.dead and obj.name == ("AzirSoldier") then
				table.insert(soldiers, obj)
			end
		end
	else -- Howling Abyss
		local objCount = Game.ObjectCount()
		for i = 1, objCount do
			local obj = Game.Object(i)
			if obj and not obj.dead and obj.name == ("AzirSoldier") then
				table.insert(soldiers, obj)
			end
		end
	end
	
	return soldiers
end

function Azir:CheckExistingSoldier(obj)
	for _, soldier in pairs(self.SoldierData) do
		if(soldier.networkID == obj.networkID) then
			return true
		end
	end
	return false
end

local dataTick = GameTimer()
function Azir:UpdateComboDamage()
	if(dataTick > GameTimer()) then return end
	local enemies = GetEnemyHeroes(3000)
	if(#enemies > 0) then
		for _, enemy in pairs(enemies) do
			if(IsValid(enemy)) then
				self.ComboDamageData[enemy.networkID] = self:GetTotalDamage(enemy)
			end
		end
		dataTick = GameTimer() + 0.25
	end
end

function Azir:GetTotalDamage(unit)
	local totalDmg = 0

	--Q
	if(self.Menu.Drawings.DamageHPBar.CalcQ:Value()) then
		if(Ready(_Q) or myHero.activeSpell.name == "AzirQ") then
			local QDmg = self:GetRawAbilityDamage("Q")
			QDmg = CalcMagicalDamage(myHero, unit, QDmg)
			totalDmg = totalDmg + QDmg
		end
	end

	--W
	if(self.Menu.Drawings.DamageHPBar.CalcW:Value() > 0) then
		if(Ready(_W) or self:GetSoldierCount() > 0) then
			local WDmg = self:GetRawAbilityDamage("W")
			WDmg = CalcMagicalDamage(myHero, unit, WDmg)
			local WAmnt = self.Menu.Drawings.DamageHPBar.CalcW:Value()
			totalDmg = totalDmg + (WDmg * WAmnt)
		end
	end

	--E
	if(self.Menu.Drawings.DamageHPBar.CalcE:Value()) then
		if(Ready(_E) or myHero.activeSpell.name == "AzirE") then
			local EDmg = self:GetRawAbilityDamage("E")
			EDmg = CalcMagicalDamage(myHero, unit, EDmg)
			totalDmg = totalDmg + EDmg
		end
	end

	--R
	if(self.Menu.Drawings.DamageHPBar.CalcR:Value()) then
		if(Ready(_R)) then
			local RDmg = self:GetRawAbilityDamage("R")
			RDmg = CalcMagicalDamage(myHero, unit, RDmg)
			totalDmg = totalDmg + RDmg
		end
	end

	--Ludens
	local ludensCheck, ludensIsUp = CheckDmgItems(6655)
	if(ludensCheck and ludensIsUp) then
		local ludensDmg = 100 + (myHero.ap * 0.1)
		ludensDmg = CalcMagicalDamage(myHero, unit, ludensDmg)
		
		totalDmg = totalDmg + ludensDmg
	end

	--Liandrys
	local liandrysCheck = CheckDmgItems(6653)
	if(liandrysCheck) then
		local liandrysBurnDmg = 50 + (myHero.ap * 0.06) + (unit.maxHealth*0.04)
		liandrysBurnDmg = CalcMagicalDamage(myHero, unit, liandrysBurnDmg)
		
		totalDmg = totalDmg + liandrysBurnDmg
	end


	return totalDmg
end

-- [[ DRAWINGS ]] --

local tetherLerp = 0
local alphaLerp = 0
function Azir:Draw()
	if myHero.dead then return end

	if(self.Menu.Drawings.DrawAzirTurretRange:Value()) then
		if(self.PassiveTurret and not self.PassiveTurret.dead and IsValid(myHero)) then
			DrawCircle(self.PassiveTurret, (self.PassiveTurret.boundingRadius + 750 + myHero.boundingRadius / 2), 3, DrawColor(125, 255, 228, 56))
		end
	end

	--This combo logic is put in draw intentionally to make use of the higher tick rate. I realize this is a bad practice usually.
	if(not Game.IsChatOpen()) then
		if(self.Menu.Combo.Revenant:Value()) then
			self:RevenantCombo()
		else
			--Reset revenant vars
			self.RevenantEngagePos = nil
			self.RevenantTarSoldier = nil
			self.RevenantQFollowup = false
		end

		if(self.Menu.Combo.RPull:Value()) then
			self:RPullCombo()
		end
	end

	local mode = GetMode()
	if(mode == "Flee") then
		self:Flee()
	end

	if(self.Menu.Drawings.DrawSoldiers:Value()) then
		self:DrawSoldiers()
	end

	if(self.Menu.Drawings.DrawSoldierTether:Value()) then 
		self:DrawSoldierTether()

		if(GetMode() ~= nil) then
			tetherLerp = Lerp(tetherLerp, 1, 0.05)
		else
			tetherLerp = 0
		end
	end

	if(self.Menu.Drawings.DrawSoldierTetherRadius:Value()) then
		DrawCircle(myHero, 740, 1, DrawColor(20 * tetherLerp, 255, 255, 255)) --(Alpha, R, G, B)
		if(self.Menu.Drawings.DrawSoldierTether:Value() == false) then
			tetherLerp = 1
		end
	end

	if(self.Menu.Drawings.DrawE:Value()) then
		if(Ready(_E)) then
			DrawCircle(myHero, E.Range, 1, DrawColor(75, 235, 177, 52)) --(Alpha, R, G, B)
		else
			DrawCircle(myHero, E.Range, 1, DrawColor(15, 235, 177, 52)) --(Alpha, R, G, B)
		end
	end

	if(self.Menu.Flee.InsecFlee:Value()) then
		if(GetMode() == "Flee") then
			if(Ready(_E) == false and myHero:GetSpellData(_E).currentCd <= 10 and (myHero:GetSpellData(_E).level > 0 and myHero:GetSpellData(_Q).level > 0)) then
				local fontSize = 55
				local eCD = string.format("%.1f", myHero:GetSpellData(_E).currentCd)
				local pos = {x = myHero.pos:To2D().x - fontSize + 24, y = myHero.pos:To2D().y + 50}
				DrawText(eCD, fontSize, Vector(pos), DrawColor(255, 255, 80, 80))
			end
		end
	end

	if(self.Menu.Drawings.DrawFlashText:Value()) then
		local fontSize = 20
		local pos = {x = myHero.pos:To2D().x - fontSize - 65, y = myHero.pos:To2D().y + 30}
		if(self.Menu.Combo.ToggleFlash:Value()) then
			if(CanFlash()) then
				DrawText("Flash Combo Enabled", fontSize, Vector(pos), DrawColor(255, 80, 255, 80))
			else
				pos = {x = myHero.pos:To2D().x - fontSize - 25, y = myHero.pos:To2D().y + 30}
				DrawText("Flash On CD", fontSize, Vector(pos), DrawColor(85, 80, 80, 80))
			end
		else
			DrawText("Flash Combo Disabled", fontSize, Vector(pos), DrawColor(85, 80, 80, 80))
		end
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
end

function Azir:DrawDotLines(pos1, pos2, visibleRange, color, lineCount)
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

function Azir:DrawSoldiers()
	for _, soldier in ipairs(self.SoldierData) do
		DrawCircle(soldier.pos, SoldierRadius, 2, DrawColor(155, 150, 65, 215)) --(Alpha, R, G, B)
	end
end

function Azir:DrawSoldierTether()
	local UIColor = {a = 255 * tetherLerp, r = 255, g = 215, b = 110}
	local tetherRange = TetherRange
	if(myHero.range == 575) then --Lethal tempo grants us 50 attack range, Azir's default attack range is 525.
		tetherRange = 800
	end
	for _, soldier in ipairs(self.SoldierData) do
		if(GetDistance(soldier, myHero) >= tetherRange) then
			local pos1 = myHero.pos:Extended(soldier.pos, tetherRange)
			self:DrawDotLines(pos1, soldier.pos, E.Range, UIColor, 6)
			DrawCircle(pos1, 5, 3, DrawColor(UIColor.a, UIColor.r, UIColor.g, UIColor.b))
			DrawCircle(soldier.pos, 5, 2, DrawColor(UIColor.a, UIColor.r, UIColor.g, UIColor.b))
		else
			DrawCircle(soldier.pos, 2, 15, DrawColor(255 * tetherLerp, 255, 255, 255))
			DrawCircle(soldier.pos, 8, 5, DrawColor(255 * tetherLerp, 255, 255, 255))
		end
	end
end

function Azir:DrawDamageHPBars()
	for _, enemy in pairs(Enemies) do
		if(enemy.valid and IsValid(enemy)) then
			if(enemy.toScreen.onScreen) then
				if(Ready(_Q) or Ready(_W) or Ready(_E) or Ready(_R)) then
					local bar = enemy.pos:To2D()
					local barLength = 150
					local barHeight = 4
					local barOffset = self.Menu.Drawings.DamageHPBar.YOffset:Value()
					local hpRatio = (enemy.health / enemy.maxHealth)
					local dmg = self:GetTotalDamage(enemy)
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

Azir()
LoadUnits()
