require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.02

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

local ChampIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/17.png"

local gameTick = GameTimer()
Teemo.AutoLevelCheck = false
Teemo.LeftClickCheck = nil

-- GG PRED
local Q, R = {}, {}

--Main Menu
Teemo.Menu = MenuElement({type = MENU, id = "KillerTeemo", name = "Killer Teemo", leftIcon = ChampIcon})
Teemo.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

function Teemo:__init()
	self:LoadMenu()
	self:InitPred()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
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
	self.Menu.Drawings:MenuElement({id = "DrawBlind", name = "Draw Blind Duration", value = true})
	self.Menu.Drawings:MenuElement({id = "Debug", name = "Debug Drawings", type = MENU})
	
	-- debug.debug
	self.Menu.Drawings.Debug:MenuElement({id = "DrawParticles", name = "Draw Particles", value = false})
	
		
	self.Menu:MenuElement({id = "AutoLevel", name = "Auto Level Skills (E - Q - W)", value = false})
	self.Menu:MenuElement({id = "DisableInFountain", name = "Disable Orbwalker while in Fountain", value = true})
	
end

function Teemo:InitPred()
	Q = {Range = 680, Speed = 2500, Delay = 0.25}
	R = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.4, Range =  self:GetRRange(), Radius = 160, Speed = 1000, Collision = false}
end

function Teemo:GetPred(tbl)
	if(tbl == Q) then
		Q = {Range = 680, Speed = 2500, Delay = 0.25}
		return Q
	end
	
	if(tbl == R) then
		R = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.4, Range =  self:GetRRange(), Radius = 160, Speed = 1000, Collision = false}
		return R
	end
	
	return nil
end

function Teemo:Tick()
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
	
	if Game.IsOnTop() and self.Menu.AutoLevel:Value() then
		self:AutoLevel()
	end	
end


function Teemo:AutoLevel()
	if self.AutoLevelCheck then return end
	
	local level = myHero.levelData.lvl
	local levelPoints = myHero.levelData.lvlPts

	if (levelPoints == 0) or (level == 1) then return end
	if (Game.mapID == HOWLING_ABYSS and level <= 3) then return end
	--Order = E > Q > W
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
					Control.KeyDown(HK_E)
					Control.KeyUp(HK_E)
					Control.KeyUp(HK_LUS)
				elseif level == 2 or level == 8 or level == 10 or level == 12 or level == 13 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_Q)
					Control.KeyUp(HK_Q)
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


local RComboCD = 5
local RComboTimer = GameTimer()
function Teemo:Combo()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	

	if(self.Menu.Combo.UseIgnite:Value()) then
		local target = GetTarget(myHero.range)
		if(target and IsValid(target)) then
			local igniteDmg = 50 + (20 * myHero.levelData.lvl)
			
			local EDmg = ({14, 25, 36, 47, 58})[myHero:GetSpellData(_E).level] + (0.3 * myHero.ap)
			EDmg = CalcMagicalDamage(myHero, target, EDmg)
			
			local EDotDmg = ({6, 12, 18, 24, 30})[myHero:GetSpellData(_E).level] + (0.1 * myHero.ap)
			EDotDmg = CalcMagicalDamage(myHero, target, EDotDmg)

			if(target.health - igniteDmg - (EDmg*2) - (EDotDmg*4) <= 0) and (target.health - igniteDmg > 0) then
				UseIgnite(target)
				return
			end
		end
	end

	if(self.Menu.Combo.UseQ:Value() and Ready(_Q)) then
		self:GetPred(Q) --Update Data
		local target = GetTarget(Q.Range)
		if(target and IsValid(target)) then
			if(myHero.pos:DistanceTo(target.pos) < Q.Range) then
				Control.CastSpell(HK_Q, target)
				return
			end
		end
	end
	
	if(self.Menu.Combo.UseR:Value() and Ready(_R) and RComboTimer < GameTimer()) then
		self:GetPred(R) --Update Data
		local target = GetTarget(R.Range)
		if(target and IsValid(target)) then
			if(myHero.pos:DistanceTo(target.pos) < R.Range) then
				
				--Condition 1: A melee enemy is walking towards Teemo, place mushroom on yourself
				if(target.range <= 300 and myHero.pos:DistanceTo(target.pos) <= 500) then
					local checkRunDir = GetUnitRunDirection(myHero, target)
					if(checkRunDir == RUNNING_TOWARDS) then
						Control.CastSpell(HK_R, myHero)
						gameTick = GameTimer() + 0.2
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
							gameTick = GameTimer() + 0.2
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
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.Combo.UseQ:Value() and Ready(_Q) and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then
		self:GetPred(Q) --Update Data
		local target = GetTarget(Q.Range)
		if(myHero.pos:DistanceTo(target.pos) < Q.Range) then
			Control.CastSpell(HK_Q, target)
			return
		end
	end
end

function Teemo:LastHit()
	if(gameTick > GameTimer()) then return end	
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
					gameTick = GameTimer() + 0.2
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
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
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
					gameTick = GameTimer() + 0.2
					return
				end
			end
		end
	end
	
	--R
	if(self.Menu.Clear.UseR:Value() and RClearTimer < GameTimer()) then
		if(Ready(_R) and myHero:GetSpellData(_R).ammo > self.Menu.Clear.KeepMushrooms:Value()) then
			self:GetPred(R)
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(R.Range)
			for i = 1, #minions do		
				local minion = minions[i]
				if IsValid(minion) then
					if(myHero.pos:DistanceTo(minion.pos) < R.Range) then
						local clusterMinions = GetMinionsAroundMinion(R.Range, R.Radius, minion)
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
	if(gameTick > GameTimer()) then return end
	
	--Q
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
						if(isKillable and (self:CantKill(enemy, true, true, false))==false) then
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
	if(gameTick > GameTimer()) then return end	
	--Anti-melee
	if(Ready(_Q)) then
		local meleeTarget = GetTarget(300)
		if(meleeTarget ~= nil and IsValid(meleeTarget)) then
			Control.CastSpell(HK_Q, meleeTarget.pos)
			gameTick = GameTimer() + 0.2
			return
		end
	end
end

local RCC_CD = 7
local RCC_Timer = GameTimer()
function Teemo:AutoR()
	if(RCC_Timer > GameTimer()) then return end	
	
	if(Ready(_R)) then
		self:GetPred(R)
		local enemy = GetTarget(R.Range)
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
		_G.SDK.Orbwalker:Orbwalk()
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
		 return ({80, 125, 170, 215, 260})[myHero:GetSpellData(_Q).level] + (0.8 * myHero.ap)
	end

	if(spell == "E") then
		 return ({21, 37.5, 54, 70.5, 87})[myHero:GetSpellData(_E).level] + (0.45 * myHero.ap) --Damage to monsters
	end
	
	return 0
end

function Teemo:GetRRange()
	if(myHero:GetSpellData(_R).level == 0) then return 600 end
	
	return ({600, 750, 900})[myHero:GetSpellData(_R).level]
end

function Teemo:CantKill(unit, kill, ss, aa)
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

function Teemo:OnWndMsg(msg, wParam)
	self.LeftClickCheck = msg == 513
			and wParam == 0
			or nil
end

function Teemo:Draw()
	if myHero.dead then return end
	
	if(self.Menu.Drawings.DrawQ:Value()) then
		if(Ready(_Q)) then
			DrawCircle(myHero, self:GetPred(Q).Range, 1, DrawColor(150, 80, 215, 255)) --(Alpha, R, G, B)
		else
			DrawCircle(myHero, self:GetPred(Q).Range, 1, DrawColor(50, 80, 215, 255)) --(Alpha, R, G, B)
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

	if(self.Menu.Drawings.Debug.DrawParticles:Value()) then
		local particleCount = Game.ParticleCount()
		for i = particleCount, 1, -1 do
			local obj = Game.Particle(i)
			if obj and obj.type == "obj_GeneralParticleEmitter" and obj.name:find("Teemo") then
				DrawText(obj.name, 18, obj.pos:To2D())
			end
		end
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
	
	local closestPoint = self:GetClosestPointToMe(nearbyShroomSpots)	
	for i = 1, #nearbyShroomSpots do
		spot = nearbyShroomSpots[i]
		if(myHero.pos:DistanceTo(spot) > R.Range) or Ready(_R) == false then
			DrawCircle(spot, R.Radius/2 , 3, DrawColor(105, 125, 125, 125))
		else
			if(spot == closestPoint) then
				DrawCircle(spot, R.Radius/2 , 3, DrawColor(255, 125, 255, 65))
				self.targetSpot = spot
			else
				DrawCircle(spot, R.Radius/2 , 3, DrawColor(175, 255, 255, 255))
			end
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

Teemo()
LoadUnits()

if Teemo.OnWndMsg then
	table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
		Teemo:OnWndMsg(msg, wParam)
	end)
end
