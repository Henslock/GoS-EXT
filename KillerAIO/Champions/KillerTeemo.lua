require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.10

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Teemo will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()


-------------------------------------------------------
-- Most of these locations are credited to WRAIO --
-------------------------------------------------------

local shroomSpots = {
Vector(1170, 0, 12320),
Vector(1671, 0, 13000),
Vector(2742, 0, 4959),
Vector(2997, 0, 7597),
Vector(2807, 0, 11909),
Vector(2247, 0, 11847),
Vector(2875, 0, 12553),
Vector(2400, 0, 13511),
Vector(3157, 0, 7206),
Vector(3548, 0, 9286),
Vector(3752, 0, 9437),
Vector(3067, 0, 10899),
Vector(3857, 0, 11358),
Vector(3900, 0, 12829),
Vector(4972, 0, 2882),
Vector(4698, 0, 6140),
Vector(4750, 0, 7211),
Vector(4749, 0, 8022),
Vector(4703, 0, 10063),
Vector(4467, 0, 11841),
Vector(5716, 0, 3505),
Vector(6546, 0, 4723),
Vector(6200, 0, 9288),
Vector(6019, 0, 10405),
Vector(6800, 0, 11558),
Vector(6780, 0, 13011),
Vector(7968, 0, 2197),
Vector(7973, 0, 3362),
Vector(7117, 0, 3100),
Vector(7225, 0, 6216),
Vector(7768, 0, 11808),
Vector(7252, 0, 12546),
Vector(8619, 0, 5622),
Vector(8280, 0, 10245),
Vector(9222, 0, 2129),
Vector(9702, 0, 6319),
Vector(9371, 0, 11445),
Vector(9845, 0, 12060),
Vector(10900, 0, 1970),
Vector(10407, 0, 3091),
Vector(10097, 0, 4972),
Vector(10081, 0, 6590),
Vector(10070, 0, 7299),
Vector(11700, 0, 2036),
Vector(11866, 0, 3186),
Vector(11024, 0, 3883),
Vector(11866, 0, 3186),
Vector(11730, 0, 4091),
Vector(11230, 0, 5575),
Vector(11627, 0, 7103),
Vector(11873, 0, 7530),
Vector(12225, 0, 1292),
Vector(12987, 0, 2028),
Vector(12827, 0, 3131),
Vector(12611, 0, 5318),
Vector(12133, 0, 8821),
Vector(12063, 0, 9974),
Vector(13499, 0, 2837),
Vector(5672, 0, 12696),
Vector(2334, 0, 9710),
Vector(9428, 0, 5612),
Vector(8544, 0, 4808)
}

local nearbyShroomSpots = {}

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Teemo"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/teemo.png"

Teemo.LeftClickCheck = nil

-- GG PRED
local Q = {Range = 680, Speed = 2500, Delay = 0.25}
local R = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.4, Range = 600, Radius = 160, Speed = 1000}

--Main Menu
Teemo.Menu = MenuElement({type = MENU, id = "KillerTeemo", name = "Killer Teemo", leftIcon = ChampIcon})
Teemo.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

function Teemo:__init()
	self:LoadMenu()

	table.insert(_G.SDK.OnTick, function()
		self:Tick()
	end)

	table.insert(_G.SDK.OnDraw, function()
		self:Draw()
	end)

	table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
		self:OnWndMsg(msg, wParam)
	end)

	_G.SDK.Orbwalker:OnPostAttack(function(...) Teemo:OnPostAttack(...) end)

	self:UpdateGoSMenuAutoLevel()
end

function Teemo:LoadMenu()                     	

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	if(myHero:GetSpellData(SUMMONER_1).name == "SummonerDot") or (myHero:GetSpellData(SUMMONER_2).name == "SummonerDot") then
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "Ignite Loaded", type = SPACE})
	else
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "Ignite Not Loaded", type = SPACE})
	end
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseR", name = "Smart R", value = true})
	self.Menu.Combo:MenuElement({id = "UseIgnite", name = "Use Ignite", value = true})
	
	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "QMana", name = "Q Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseQ", name = "Use Q on Canon Minion", value = true})
	self.Menu.LastHit:MenuElement({id = "TowerFarm", name = "Tower Farm Assist", value = true})
	
	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q on Canon Minion", value = true})
	self.Menu.Clear:MenuElement({id = "UseR", name = "Use R on Clusters", value = true})
	self.Menu.Clear:MenuElement({id = "KeepMushrooms", name = "Minimum Shrooms to Keep", value = 1, min = 0, max = 5, step = 1})
	
	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true})
	
	self.Menu:MenuElement({id = "AutoQ", name = "Auto Q Melee Champions", value = true})
	self.Menu:MenuElement({id = "AutoRCC", name = "Auto R on Immobile", value = true})
	self.Menu:MenuElement({id = "MushroomMode", name = "Mushroom Assistant", key = string.byte("Z"), tooltip = "Hover over a spot and left click to place the mushroom"})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawR", name = "Draw R Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawBlind", name = "Draw Blind Duration", value = true})
	self.Menu.Drawings:MenuElement({id = "Debug", name = "Debug Drawings", type = MENU})
	
	--AutoLeveler	
	self.Menu:MenuElement({id = "AutoLevel", name = "Auto Leveler", type = MENU})
	self.Menu.AutoLevel:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.AutoLevel:MenuElement({id = "StartingLevel", name = "Start Using At Level:", value = 3, min = 2, max = 18, step = 1})
	self.Menu.AutoLevel:MenuElement({id = "FirstSkill", name = "First Skill Priority", drop = {"Q", "W", "E"}, value = 3, callback = 
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

function Teemo:UpdateGoSMenuAutoLevel()
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

function Teemo:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Teemo:Tick()
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

	self:KillSteal()
	
	if(self.Menu.AutoQ:Value()) then
		self:AutoQ()
	end
	
	if(self.Menu.AutoRCC:Value()) then
		self:AutoR()
	end
	
	if(self.Menu.MushroomMode:Value()) then
		self:MushroomAssistant()
	end
	
	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end
function Teemo:OnPostAttack(args)
    if GetMode() == "Combo" then
		if(self.Menu.Combo.UseQ:Value() and Ready(_Q)) then
			local tar = GetTarget(Q.Range)
			if(IsValid(tar)) then 
				Control.CastSpell(HK_Q, tar)
				return
			end
		end
    end
end

local RComboCD = 5
local RComboTimer = GameTimer()
function Teemo:Combo()
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	

	if(self.Menu.Combo.UseIgnite:Value()) then
		local target = GetTarget(_G.SDK.Data:GetAutoAttackRange(myHero))
		if(target and IsValid(target)) then
			local igniteDmg = GetIgniteDamage()
			
			local EDmg = self:GetRawAbilityDamage("E")
			EDmg = CalcMagicalDamage(myHero, target, EDmg)
			
			local EDotDmg = self:GetRawAbilityDamage("EDot")
			EDotDmg = CalcMagicalDamage(myHero, target, EDotDmg)

			if(target.health - igniteDmg - (EDmg*2) - (EDotDmg*4) <= 0) and (target.health - igniteDmg > 0) then
				UseIgnite(target)
				return
			end
		end
	end

	if(self.Menu.Combo.UseQ:Value() and Ready(_Q)) then
		local target = GetTarget(Q.Range)
		if(target and IsValid(target)) then
			if(GetDistance(myHero, target) <= Q.Range and GetDistance(myHero, target) > _G.SDK.Data:GetAutoAttackRange(myHero)) then
				Control.CastSpell(HK_Q, target)
				return
			end
		end
	end
	
	if(self.Menu.Combo.UseR:Value() and Ready(_R) and RComboTimer < GameTimer()) then
		local target = GetTarget(self:GetRRange())
		if(target and IsValid(target)) then
			if(myHero.pos:DistanceTo(target.pos) < self:GetRRange()) then
				
				--Condition 1: A melee enemy is walking towards Teemo, place mushroom on yourself
				if(target.range <= 300 and myHero.pos:DistanceTo(target.pos) <= 500) then
					local checkRunDir = GetUnitRunDirection(myHero, target)
					if(checkRunDir == RUNNING_TOWARDS) then
						Control.CastSpell(HK_R, myHero)
						RComboTimer = GameTimer() + RComboCD
						return
					end
				end
				
				--Condition 2: A target is fleeing at low HP and you can cut off their path with a mushroom
				local checkRunDir = GetUnitRunDirection(myHero, target)
				if(checkRunDir == RUNNING_AWAY) then
					--Target is less than 20% HP
					local condition1 = (target.health / target.maxHealth) <= 0.2 
					--You have 30% more HP than the target and they are less than 40% HP
					local condition2 = (myHero.health / myHero.maxHealth) - (target.health / target.maxHealth)>= 0.3 and (target.health / target.maxHealth) <= 0.4
					if(condition1 or condition2) then
						local RPrediction = GetExtendedSpellPrediction(target, R)
						if RPrediction:CanHit(HITCHANCE_HIGH) then
							Control.CastSpell(HK_R, RPrediction.CastPosition)
							RComboTimer = GameTimer() + RComboCD
							return
						end
					end
				end
				
			end
		end
	end
	
end

function Teemo:Harass()
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.Combo.UseQ:Value() and Ready(_Q) and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then
		local target = GetTarget(Q.Range)
		if(IsValid(target)) then
			if(myHero.pos:DistanceTo(target.pos) < Q.Range) then
				Control.CastSpell(HK_Q, target)
				return
			end
		end
	end
end

function Teemo:LastHit()
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	--Q
	if(self.Menu.LastHit.UseQ:Value()) then
		--Turret last hitting
		if(self.Menu.LastHit.TowerFarm:Value()) then
			local closestTurret = GetClosestFriendlyTurret()
			local numTurretMinions = 0
			if(closestTurret ~= nil) then
				local turretMinions = GetEnemyMinionsUnderTurret(closestTurret)
				if(#turretMinions > 0) then
					numTurretMinions = #turretMinions
					self:TurretLastHit(closestTurret, turretMinions)
				end
			end
		end
			
		if(Ready(_Q)) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
			local canonMinion = GetCanonMinion(minions)
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local QDam = self:GetRawAbilityDamage("Q")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (myHero.pos:DistanceTo(canonMinion.pos)/Q.Speed))
				
				if ((hp > 0) and (canonMinion.health + (canonMinion.health*0.02) - QDam <= 0)) then
					Control.CastSpell(HK_Q, canonMinion)
					return
				end
			end
		end
	end
end

local LHFocusTarget = nil
function Teemo:TurretLastHit(turret, minions)
	local currentTurretTarget = GetTurretMinionTarget(turret, minions)
	local turrDmg = GetTurretDamage()
	local QDam = self:GetRawAbilityDamage("Q")
	local EDam = self:GetRawAbilityDamage("E")
	--Farming under tower follows a set of general rules that can dynamically change based on minion HP and other variables.
	--This is my approach to successfully farm under tower and get as many last hits as possible
	
	if(LHFocusTarget ~= nil) then
		if(IsValid(LHFocusTarget)) then
			_G.SDK.Orbwalker:Attack(LHFocusTarget)
		else
			LHFocusTarget = nil
		end
	end
	
	for i = 1, #minions do
		local minion = minions[i]
		if(minion and IsValid(minion)) then
			if(myHero.pos:DistanceTo(minion.pos) <= myHero.range) then
				--Condition 1: Kill caster minions while the canon is being focused
				if(currentTurretTarget ~= nil) then
					if(GetMinionType(currentTurretTarget) == MINION_CANON) and (currentTurretTarget.health - turrDmg > 0) then
						if(GetMinionType(minion) == MINION_CASTER) then
							_G.SDK.Orbwalker:Attack(minion)
						end
					end
				end
				
				--Condition 5: If we can Q -> AA to kill a caster minion before the tower hits, then do it (assuming we just can't AA to kill)
				if(currentTurretTarget ~= nil) then
					if(GetMinionType(currentTurretTarget) ~= MINION_CANON) then
						if(GetMinionType(minion) == MINION_CASTER) and (minion.health - myHero.totalDamage - EDam - QDam <= 0) and Ready(_Q) then
							local AAWillKill = (minion.health - EDam - myHero.totalDamage <= 0)
							if AAWillKill == false and (minion.health / minion.maxHealth <= 0.7) then
								if(GameTimer() - turret.activeSpell.castEndTime) <= 0.5 then
									LHFocusTarget = minion
									Control.CastSpell(HK_Q, minion)
								end
							end
						end
					end
				end
				
			end
		end
	end

	if(myHero.pos:DistanceTo(currentTurretTarget.pos) <= Q.Range) then
		if(currentTurretTarget ~= nil) then
			
			local AAWillKill = (currentTurretTarget.health - EDam - myHero.totalDamage <= 0)
			--Condition 2: Q to kill canon minion
			if(GetMinionType(currentTurretTarget) == MINION_CANON) and (currentTurretTarget.health - QDam < 0) and Ready(_Q) then
				Control.CastSpell(HK_Q, currentTurretTarget)
				return
			end
			
			--Condition 3: Q to kill caster minion if its being focused, assuming we can't just AA it
			if(GetMinionType(currentTurretTarget) == MINION_CASTER) and (currentTurretTarget.health - QDam < 0) and AAWillKill == false and Ready(_Q) then
				Control.CastSpell(HK_Q, currentTurretTarget)
				return
			end
			
			--Condition 4: AA caster minions who are near full hp if the tower has only just begun targetting them and an AA + tower shot wont kill the minion
			if(GetMinionType(currentTurretTarget) == MINION_CASTER) and (currentTurretTarget.health - myHero.totalDamage - EDam - GetMinionTurretDamage(currentTurretTarget) > 0) then
				if(GameTimer() - turret.activeSpell.castEndTime) <= 0.7 then
					LHFocusTarget = currentTurretTarget
					return
				end
			end
		end
	end

end

local RClearCD = 7
local RClearTimer = GameTimer()
function Teemo:Clear()
	if not (IsValid(myHero)) or myHero.isChanneling then return end
	
	--Q
	if(self.Menu.Clear.UseQ:Value()) then
		if(Ready(_Q)) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
			local canonMinion = GetCanonMinion(minions)
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local QDam = self:GetRawAbilityDamage("Q")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (myHero.pos:DistanceTo(canonMinion.pos)/Q.Speed))
				
				if ((hp > 0) and (canonMinion.health + (canonMinion.health*0.02) - QDam <= 0)) then
					Control.CastSpell(HK_Q, canonMinion)
					return
				end
			end
		end
	end
	
	--R
	if(self.Menu.Clear.UseR:Value() and RClearTimer < GameTimer()) then
		if(Ready(_R) and myHero:GetSpellData(_R).ammo > self.Menu.Clear.KeepMushrooms:Value()) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self:GetRRange())
			for _, minion in pairs(minions) do		
				if IsValid(minion) then
					if(myHero.pos:DistanceTo(minion.pos) < self:GetRRange()) then
						local clusterMinions = GetMinionsAroundMinion(self:GetRRange(), R.Radius, minion)
						if(#clusterMinions >= 3) then
							local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
							Control.CastSpell(HK_R, clusterMinionsAvgPos)
							RClearTimer = GameTimer() + RClearCD
							return
						end
					end
				end
			end
		end
	end
	
end

function Teemo:KillSteal()
	if(self.Menu.KillSteal.UseQ:Value()) then
		if(Ready(_Q)) and not myHero.isChanneling then
			local enemies = GetEnemyHeroes(Q.Range)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy.valid and IsValid(enemy)) then
						local isKillable = false
						local QDmg = self:GetRawAbilityDamage("Q")
						QDmg = CalcMagicalDamage(myHero, enemy, QDmg)
						isKillable = (enemy.health - QDmg < 0)
						if(isKillable and (CantKill(enemy, true, true, false))==false) then
							Control.CastSpell(HK_Q, enemy)
							return
						end
					end
				end
			end
		end
	end
end

function Teemo:AutoQ()
	--Auto Q won't work if you are in stealth
	if(self:HasStealthBuff()) then return end
	--Anti-melee
	if(Ready(_Q)) then
		local meleeTarget = GetTarget(300)
		if(meleeTarget and IsValid(meleeTarget)) then
			Control.CastSpell(HK_Q, meleeTarget)
			return
		end
	end
end

local RCC_CD = 7
local RCC_Timer = GameTimer()
function Teemo:AutoR()
	if(RCC_Timer > GameTimer()) then return end	
	
	if(Ready(_R)) then
		local enemy = GetTarget(self:GetRRange())
		if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
			if(IsImmobile(enemy) >= 0.5) then
				local RPrediction = GGPrediction:SpellPrediction(R)
				RPrediction:GetPrediction(enemy, myHero)
				if RPrediction.CastPosition and RPrediction:CanHit(HITCHANCE_HIGH) then
					Control.CastSpell(HK_R, RPrediction.CastPosition)
					RCC_Timer = GameTimer() + RCC_CD
					return
				end
			end
		end
	end
end

function Teemo:MushroomAssistant()
	if(Game.mapID == SUMMONERS_RIFT) then
		self:UpdateNearbyShroomSpots()
		
		if(Ready(_R)) then
			if(self.LeftClickCheck) and self.targetSpot ~= nil then
				--Placing nearby mushroom
				Control.CastSpell(HK_R, self.targetSpot)
			end
		end
	end
end

local checkTick = GameTimer()
function Teemo:UpdateNearbyShroomSpots()
	if(checkTick > GameTimer()) then return end
	nearbyShroomSpots = {}
	for i = 1, #shroomSpots do
		spot = shroomSpots[i]
		if(spot:To2D().onScreen) then
			if(myHero.pos:DistanceTo(spot) <= 1800) then
				table.insert(nearbyShroomSpots, spot)
				checkTick = GameTimer() + 0.2
			end
		end
	end
end

function Teemo:GetRawAbilityDamage(spell)
	if(spell == "Q") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		return ({80, 125, 170, 215, 260})[myHero:GetSpellData(_Q).level] + (0.8 * myHero.ap)
	end

	if(spell == "E") then
		if myHero:GetSpellData(_E).level == 0 then return 0 end
		return ({14, 25, 36, 47, 58})[myHero:GetSpellData(_E).level] + (0.3 * myHero.ap)
	end

	if(spell == "EDot") then
		if myHero:GetSpellData(_E).level == 0 then return 0 end
		return ({6, 12, 18, 24, 30})[myHero:GetSpellData(_E).level] + (0.1 * myHero.ap)
	end

	if(spell == "EJungle") then
		if myHero:GetSpellData(_E).level == 0 then return 0 end
		return ({21, 37.5, 54, 70.5, 87})[myHero:GetSpellData(_E).level] + (0.45 * myHero.ap) --Damage to monsters
	end

	if(spell == "EDotJungle") then
		if myHero:GetSpellData(_E).level == 0 then return 0 end
		return ({9, 18, 27, 36, 45})[myHero:GetSpellData(_E).level] + (0.15 * myHero.ap) --Damage to monsters
	end
	
	return 0
end

function Teemo:GetRRange()
	if(myHero:GetSpellData(_R).level == 0) then return 600 end
	
	return ({600, 750, 900})[myHero:GetSpellData(_R).level]
end

function Teemo:HasStealthBuff()
	return HasBuff(myHero, "camouflagestealth")
end

function Teemo:OnWndMsg(msg, wParam)
	self.LeftClickCheck = msg == 513
			and wParam == 0
			or nil
end

function Teemo:Draw()
	if myHero.dead then return end

	if(self.Menu.Drawings.DrawQ:Value()) then
		if(Ready(_Q)) then
			DrawCircle(myHero, Q.Range, 1, DrawColor(150, 80, 215, 255)) --(Alpha, R, G, B)
		else
			DrawCircle(myHero, Q.Range, 1, DrawColor(50, 80, 215, 255)) --(Alpha, R, G, B)
		end
	end

	if(self.Menu.Drawings.DrawR:Value()) then
		if(Ready(_R)) then
			DrawCircle(myHero, self:GetRRange(), 1, DrawColor(150, 120, 215, 125)) --(Alpha, R, G, B)
		else
			DrawCircle(myHero, self:GetRRange(), 1, DrawColor(50, 120, 215, 125)) --(Alpha, R, G, B)
		end
	end
	
	if(self.Menu.Drawings.DrawBlind:Value()) then
		if(Ready(_Q) == false) then
			self:DrawBlindBar()
		end
	end
	
	if(self.Menu.MushroomMode:Value()) then
		self:DrawMushroomSpots()
	end
end

function Teemo:DrawBlindBar()
	for _, enemy in pairs(Enemies) do
		if(enemy.valid and IsValid(enemy)) then
			if(enemy.toScreen.onScreen) then
				local bar = enemy.pos:To2D()
				local barLength = 150
				local barHeight = 4
				local barOffset = 80
				local buff = GetBuffData(enemy, "BlindingDart")
				local blindDuration = 1 - ((GameTimer() - buff.startTime) / (buff.expireTime - buff.startTime))
				if(blindDuration >= 0 and blindDuration <= 1.0) then
					--Bar BG
					Draw.Rect(bar.x - (barLength/2) -3, bar.y + barOffset - 3, barLength +6, barHeight + 6, DrawColor(225, 0, 0, 0))
					
					--Blind Duration
					Draw.Rect(bar.x - (barLength/2), bar.y + barOffset, barLength * blindDuration, barHeight, DrawColor(255, 155, 155, 155))
				end
			end
		end
	end
end

Teemo.targetSpot = nil
function Teemo:DrawMushroomSpots()
	if(#nearbyShroomSpots == 0) then return end
	
	local heroPos = myHero.pos:To2D()
	DrawText("[Left Click] To Place", 18, heroPos.x - 65, heroPos.y + 50)
	
	local closestPoint = self:GetClosestPointToCursor(nearbyShroomSpots)
	for i = 1, #nearbyShroomSpots do
		spot = nearbyShroomSpots[i]

			if(spot == closestPoint) then
				DrawCircle(spot, R.Radius/2 , 3, DrawColor(255, 125, 255, 65))
				self.targetSpot = spot
			else
				DrawCircle(spot, R.Radius/2 , 3, DrawColor(175, 255, 255, 255))
			end

	end
end

function Teemo:GetClosestPointToMe(tbl)
	local closestPoint = nil
	local closestDist = math.huge
	for i = 1, #tbl do
		point = tbl[i]
		local dist = GetDistance(point, myHero.pos)
		if(dist <= closestDist) then	
			closestPoint = point
			closestDist = dist
		end
	end
	return closestPoint
end

function Teemo:GetClosestPointToCursor(tbl)
	local closestPoint = nil
	local closestDist = math.huge
	for i = 1, #tbl do
		point = tbl[i]
		local dist = GetDistance(point, Game.mousePos())
		if(dist <= closestDist) then	
			closestPoint = point
			closestDist = dist
		end
	end
	return closestPoint
end

Teemo()
LoadUnits()
