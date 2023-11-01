require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.18

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Karthus will exit.")
    return
end


-- [ AutoUpdate ]

UpdateMyHeroScript()

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Karthus"

local PassiveBuff = "KarthusDeathDefiedBuff"
local KarthusIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/karthus.png"

local UltableChamps = {}
local MIATimer = 5

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.1, Radius = 160, Range = 875, Speed = math.huge, Collision = false}
local W = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.3, Radius = 75, Range = 1000, Speed = math.huge, Collision = false}
local E = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 550, Range = 0, Speed = math.huge, Collision = false}

Karthus.Menu = MenuElement({type = MENU, id = "KillerKarthus", name = "Killer Karthus", leftIcon = KarthusIcon})
Karthus.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

Karthus.Window = { x = Game.Resolution().x * 0.5 + 200, y = Game.Resolution().y * 0.5 }
Karthus.AllowMove = nil

function Karthus:__init()
	self:LoadMenu()
	self:LoadUltTrackerData()

	table.insert(_G.SDK.OnTick, function()
		self:Tick()
	end)

	table.insert(_G.SDK.OnDraw, function()
		self:Draw()
	end)

	table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
		self:OnWndMsg(msg, wParam)
	end)

	_G.SDK.Orbwalker:OnPreAttack(function(...) Karthus:OnPreAttack(...) end)

	self.Window = { x = self.Menu.Drawings.HPosXY:Value()[1], y = self.Menu.Drawings.HPosXY:Value()[2] }
end


function Karthus:LoadUltTrackerData()
	
	DelayEvent(function()
	
		for k, v in pairs (Enemies) do
			UltableChamps[v.name] = {champ = v.charName, ultdmg = 0, timelastspotted = 0, killable = false, mia = false}
		end
		print("KILLER Karthus: Loaded Ult Tracker Data")
	end, 2)
	
end

function Karthus:LoadMenu()                     	
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
	self.Menu.Harass:MenuElement({id = "QIsolated", name = "Only Q if Isolated", value = false})
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
	self.Menu.Clear:MenuElement({id = "DisableESoloMinion", name = "Toggle off E for Solo Minion", value = true})
	
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
	self.Menu.Prediction:MenuElement({id = "WHitChance", name = "W Hit Chance",  value = 1, drop = {"Normal", "High", "Immobile"}})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawW", name = "Draw W", value = false})
	self.Menu.Drawings:MenuElement({id = "DrawHealthTracker", name = "Draw Health Tracker", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawChampTracker", name = "Draw Proximity Champion Tracker", value = false})
	self.Menu.Drawings:MenuElement({id = "HPosXY", name = "============", value = {Game.Resolution().x * 0.5 + 200, Game.Resolution().y * 0.5}, type = SPACE})
	self.Menu.Drawings:MenuElement({id = "ResetWindowPos", name = "[ Reset Health Tracker Pos ]", type = MENU, callback =
	function ()
		self.Window = { x = Game.Resolution().x * 0.5 + 200, y = Game.Resolution().y * 0.5 }
	end})

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

function Karthus:UpdateGoSMenuAutoLevel()
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

function Karthus:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Karthus:Tick()

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
	
	self:AutoRCheck()
	self:AutoWCheck()
	self:AutoQCheck()

	if(self.Menu.Combo.SemiW:Value()) then
		self:SemiManualW()
	end
	
	if Game.IsOnTop() and self.Menu.AutoLevel:Value() then
		self:AutoLevel()
	end

	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end
end

local gameTick = GameTimer()

function Karthus:CanQ()
	if(myHero.activeSpell.valid and myHero.activeSpell.name == "KarthusQ") or myHero.isChanneling then return false end
	return myHero:GetSpellData(_Q).ammo == 2 and myHero.mana > myHero:GetSpellData(_Q).mana
end

function Karthus:OnPreAttack(args)

    if GetMode() == "LaneClear" then
		local QManaCheck =  (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.QMana:Value() / 100)
		local EManaCheck =  (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.EMana:Value() / 100)
		if(Karthus.Menu.Clear.AABlock:Value() and (QManaCheck or EManaCheck)) then --If the setting is enabled and we have enough mana for Q OR E
			args.Process = false
		end
    end

	if(myHero.levelData.lvl >= Karthus.Menu.Combo.DisableAALevel:Value()) then
		if(GetMode() == "Combo") and (myHero.mana / myHero.maxMana) >= 0.05 then
			args.Process = false
		end
	end

	if Karthus.Menu.LastHit.UseQ:Value() then
		if(myHero.levelData.lvl >= Karthus.Menu.LastHit.DisableAALevel:Value()) then
			if(GetMode() == "LastHit") and (myHero.mana / myHero.maxMana) >= 0.05 then
				args.Process = false
			end
		end
	end

end

function Karthus:Combo()
	if(myHero.isChanneling) then return end
	
	-- Q
	local target = GetTarget(Q.Range + Q.Radius*0.5) --Extend out of the Q range a little bit
	if(IsValid(target)) then
		if(self:CanQ() and self.Menu.Combo.UseQ:Value()) then
			CastPredictedSpell({Hotkey = HK_Q, Target = target, SpellData = Q, ExtendedCheck = true, collisionRadiusOverride = Q.Radius - 35})
		end
	end
	
	--W
	local target = GetTarget(W.Range)
	if(IsValid(target)) then
	
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
	if HasBuff(myHero, "KarthusDefile") and not self:IsPassiveDead() and (GetEnemyCount(E.Radius + EDisableBuffer, myHero) == 0) then 
		Control.CastSpell(HK_E)
		return
	end
end

function Karthus:Harass()
	
	if(gameTick > GameTimer()) then return end --This is to prevent the mouse from spasming out
	
	-- Q
	local target = GetTarget(Q.Range + Q.Radius*0.5) --Extend out of the Q range a little bit
	if(target ~= nil and IsValid(target)) then
		if(self:CanQ() and self.Menu.Harass.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then

			local shouldCast = true
			if(self.Menu.Harass.QIsolated:Value()) then
				local tarPredPos = GGPrediction:SpellPrediction(Q)
				tarPredPos:GetPrediction(target, myHero)
				tarPredPos = tarPredPos.CastPosition or target.pos

				local nearbyMinions = GetMinionsAroundPosition(Q.Range + Q.Radius, Q.Radius + 15, tarPredPos)
				if(#nearbyMinions > 0) then
					shouldCast = false
				end
			end

			if(shouldCast) then
				CastPredictedSpell({Hotkey = HK_Q, Target = target, SpellData = Q, ExtendedCheck = true})
			end
		end
	end
	
end

function Karthus:LastHit()
	if(gameTick > GameTimer()) then return end
	if(myHero.isChanneling) then return end
	
	if(self:CanQ() and self.Menu.LastHit.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.LastHit.QMana:Value() / 100)) then
	    local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
		for _, minion in pairs(minions) do
			local ShouldAA = false
			local ShouldAngleQ = false
			if IsValid(minion) then
				if(self.Menu.LastHit.UseAA:Value() and myHero.levelData.lvl < self.Menu.LastHit.DisableAALevel:Value() and myHero.pos:DistanceTo(minion.pos) < myHero.range) and not IsUnderFriendlyTurret(myHero) then
					--If the minion is in AA range and we have the setting enabled, skip it!
					if not (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then
						ShouldAA = true
					end
				end
				
				local qPred = GGPrediction:SpellPrediction(Q)
				qPred:GetPrediction(minion, myHero)
				if qPred.CastPosition and ShouldAA == false then
					
					local QDam = self:GetRawAbilityDamage("Q")
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
					local IsolatedQDam = QDam * 1.75 -- It normally is double the damage, but we are giving ourselves a window to operate within for consistency
				
					if (hp > 0) and (hp + (minion.health*0.1) < IsolatedQDam) or (minion.health + 10 < IsolatedQDam) then -- First check to see if the minions health can be killed by isolated Q
						
						local castPos = qPred.CastPosition
						local shouldUseIsolated = false
						local onComingMinionCheck = false
						
						local clusterMinions = GetTableMinionsAroundMinion(minions, Q.Radius + 30, minion)
						if(#clusterMinions == 1) then
							local nearbyMinions = GetTableMinionsAroundMinion(minions, 450, minion)
							if(#nearbyMinions > 1) then
								onComingMinionCheck = self:OnComingMinionCheck(minion, nearbyMinions)
							end
						end
						
						if(#clusterMinions == 0) or not onComingMinionCheck and (GetEnemyCountAtPos(Q.Range + Q.Radius, Q.Radius + 250, minion.pos) == 0) then
							shouldUseIsolated = true
						end

						if(shouldUseIsolated) then
							if(#clusterMinions == 1) then
								local angledPos = self:AngleQPos(minion, clusterMinions[1], Q.Radius)
								castPos = angledPos
							end
						end
						
						if(shouldUseIsolated) and not onComingMinionCheck and GetDistance(myHero, castPos) < Q.Range - 10 then
							Control.CastSpell(HK_Q, castPos)
							return
						else
							if (hp > 0) and (hp + (minion.health*0.12) < QDam) or (minion.health + 12 < QDam) and GetDistance(myHero, castPos) < Q.Range - 10 then
								Control.CastSpell(HK_Q, castPos)
								return
							end
						end
					end
					
				end
			end
		end
	end
	
end

function Karthus:AngleQPos(minion1, minion2, radius)
	local dirVec = (minion1.pos - minion2.pos):Normalized()
	local newPos = minion1.pos + (dirVec * radius)
	
	return newPos
end

function Karthus:OnComingMinionCheck(minion, minions)
	for k, _nearbyMinion in pairs(minions) do
		local pred = GGPrediction:SpellPrediction(Q)
		pred:GetPrediction(minion, myHero)
		if(pred.CastPos) then
			local dist =  minion.pos.DistanceTo(Vector(pred.CastPos))
			if dist <= Q.Radius then
				return true
			end
		end
	end
	return false
end

function Karthus:Clear()
	
	if(gameTick > GameTimer()) then return end --This is to prevent the mouse from spasming out

	local QManaCheck =  (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.QMana:Value() / 100)
	local EManaCheck =  (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.EMana:Value() / 100)

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
	local highPrioMinions = {}
	local canonMinion = nil
	local killableMinion = nil
	
	if(self.Menu.Clear.PrioCanon:Value()) then
		canonMinion = GetCanonMinion(minions)
	end

	if(canonMinion and IsValid(canonMinion) and canonMinion.health/canonMinion.maxHealth <= 0.3) then
		if(self:CanQ() and self.Menu.Clear.UseQ:Value() and QManaCheck) then
			local QDam = self:GetRawAbilityDamage("Q")
			local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay)

			local clusterMinions = GetTableMinionsAroundMinion(minions, Q.Radius + 30, canonMinion)
			if(#clusterMinions == 0) then
				QDam = QDam * 2
			end

			if(canonMinion.health - QDam < 0 and hp > 0) then
				Control.CastSpell(HK_Q, canonMinion)
				return
			end
		end
	end

	for _, minion in pairs(minions) do
		if(IsValid(minion)) then
			local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
			local QDam = self:GetRawAbilityDamage("Q")
			if( hp > 0 and minion.health - (QDam*2) < 0 and (minion.health - hp > 0 or minion.health - QDam < 0)) then
				table.insert(highPrioMinions, minion)
			end
		end
	end

	--Focus on clearing these minions first.
	if(#highPrioMinions > 0) then
		for _, minion in pairs(highPrioMinions) do
			if(self:CanQ() and self.Menu.Clear.UseQ:Value() and QManaCheck) then
				
				local pred = GGPrediction:SpellPrediction(Q)
				pred:GetPrediction(minion, myHero)
				if pred.CastPosition and GetDistance(myHero, pred.CastPosition) < Q.Range - 10 then
					local QDam = self:GetRawAbilityDamage("Q")
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
					local castPos = pred.CastPosition

					local shouldUseIsolated = false
					local onComingMinionCheck = false
					
					local clusterMinions = GetTableMinionsAroundMinion(minions, Q.Radius + 30, minion)
					if(#clusterMinions == 1) then
						local nearbyMinions = GetTableMinionsAroundMinion(minions, 450, minion)
						if(#nearbyMinions > 1) then
							onComingMinionCheck = self:OnComingMinionCheck(minion, nearbyMinions)
						end
					end
					
					if(#clusterMinions == 0) or not onComingMinionCheck and (GetEnemyCountAtPos(Q.Range + Q.Radius, Q.Radius + 250, minion.pos) == 0) then
						shouldUseIsolated = true
					end
					
					if(shouldUseIsolated) then
						if(#clusterMinions == 1) then
							local angledPos = self:AngleQPos(minion, clusterMinions[1], Q.Radius)
							QDam = QDam * 1.85
							castPos = angledPos
						end
					end

					if hp - QDam < 0 and GetDistance(myHero, castPos) < Q.Range - 10 then
						Control.CastSpell(HK_Q, castPos)
						return
					end

				end
			end
		end
	end
	
	for _, minion in pairs(minions) do
		
		if killableMinion then minion = killableMinion end

		if(canonMinion and IsValid(canonMinion) and canonMinion.health/canonMinion.maxHealth <= 0.3) then
			minion = canonMinion 
		end

		if(IsValid(minion)) then
			
			-- Q
			if(self:CanQ() and self.Menu.Clear.UseQ:Value() and QManaCheck) and #highPrioMinions == 0 then
				local pred = GGPrediction:SpellPrediction(Q)
				pred:GetPrediction(minion, myHero)
				if pred.CastPosition and GetDistance(myHero, pred.CastPosition) < Q.Range - 10 then
					local QDam = self:GetRawAbilityDamage("Q")
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
					local hpDifferential = minion.health - hp --Incoming damage
					local canQ = true
					local castPos = pred.CastPosition

					if(hp > 0) then
						local shouldUseIsolated = false
						local onComingMinionCheck = false
						
						local clusterMinions = GetTableMinionsAroundMinion(minions, Q.Radius + 30, minion)
						if(#clusterMinions == 1) then

							--On coming minion check
							local nearbyMinions = GetTableMinionsAroundMinion(minions, 450, minion)
							if(#nearbyMinions > 1) then
								onComingMinionCheck = self:OnComingMinionCheck(minion, nearbyMinions)
							end
						end
						
						if(#clusterMinions == 0) or not onComingMinionCheck and (GetEnemyCountAtPos(Q.Range + Q.Radius, Q.Radius + 250, minion.pos) == 0) then
							shouldUseIsolated = true
						end
						
						
						if(shouldUseIsolated) then
							if(#clusterMinions == 1) then
								local angledPos = self:AngleQPos(minion, clusterMinions[1], Q.Radius)
								QDam = QDam * 1.85
								castPos = angledPos
							end
						end

						if(hpDifferential > 0) then
							if hp - QDam < 0 and GetDistance(myHero, castPos) < Q.Range - 10 then
								Control.CastSpell(HK_Q, castPos)
								return
							end
						end


						if ((hpDifferential == 0 or (hp - QDam)/minion.maxHealth >= 0.4)) and GetDistance(myHero, castPos) < Q.Range - 10 then
							Control.CastSpell(HK_Q, castPos)
							return
						end
					end

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
	if(self.Menu.Clear.DisableESoloMinion:Value()) then
		if HasBuff(myHero, "KarthusDefile") and (GetMinionCount(E.Radius + EDisableBuffer, E.Radius, myHero.pos) == 1) then
			local isJungleCreep = false
			for _, minion in pairs(minions) do
				if(minion.team == TEAM_JUNGLE) and GetDistance(minion, myHero) < E.Radius + EDisableBuffer then
					isJungleCreep = true
					break
				end
			end

			if not isJungleCreep then
				Control.CastSpell(HK_E)
				gameTick = GameTimer() + 0.25
				return
			end
		end
	else
		if HasBuff(myHero, "KarthusDefile") and (GetMinionCount(E.Radius + EDisableBuffer, E.Radius, myHero.pos) == 0) then 
			Control.CastSpell(HK_E)
			gameTick = GameTimer() + 0.25
			return
		end
	end

end

function Karthus:IsPassiveDead()
	return HasBuff(myHero, PassiveBuff)
end


function Karthus:AutoRCheck()
	-- Zombie check
	if (self.Menu.AutoR.AutoRDead:Value() and self:IsPassiveDead() and Ready(_R)) then
		for k, v in pairs(Enemies) do
			if (v and v.valid and v.alive) then
				local ultableChamp = UltableChamps[v.name]
				if(ultableChamp ~= nil) then
					if(ultableChamp.killable) then
						DelayAction(function () Control.CastSpell(HK_R) end, 0.25)
						break
					end
				end
			end
		end
	end

	--Alive check	
	if(IsUnderTurret(myHero)) then return end -- Extra check to make sure we don't ult under tower
	local enemiesNearby = GetEnemyCount(1750, myHero)
	if (self.Menu.AutoR.AutoRAlive:Value() and Ready(_R) and enemiesNearby == 0 and not IsUnderTurret(myHero)) then
		for k, v in pairs(Enemies) do
			if (v and v.valid and v.alive) then
				local ultableChamp = UltableChamps[v.name]
				if(ultableChamp ~= nil) then
					if(ultableChamp.killable) then
						Control.CastSpell(HK_R)
						break
					end
				end
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
				
				local tarHpRatio = target.health / math.floor(target.maxHealth)
				local myHpRatio = myHero.health / math.floor(myHero.maxHealth)
				local hpPercentLeadCheck = (myHpRatio- tarHpRatio > 0.2) -- If you have a health lead on the target, try positioning the wall slightly behind them
				if hpPercentLeadCheck then
					local castPos = Vector(WPrediction.CastPosition):Extended(myHero.pos, -target.boundingRadius)
					Control.CastSpell(HK_W, castPos)
					gameTick = GameTimer() + 0.2
				else
					Control.CastSpell(HK_W, WPrediction.CastPosition)
					gameTick = GameTimer() + 0.2
				end
				
			end
		end
	end
end

function Karthus:GetRawAbilityDamage(spell)
	if(spell == "Q") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		return ({43, 61, 79, 97, 115})[myHero:GetSpellData(_Q).level] + (myHero.ap * 0.35)
	end
	if(spell == "E") then
		if myHero:GetSpellData(_E).level == 0 then return 0 end
		return ({7.5, 12.5, 17.5, 22.5, 27.5})[myHero:GetSpellData(_E).level] + (myHero.ap * 0.05)
	end
	if(spell == "R") then
		if myHero:GetSpellData(_R).level == 0 then return 0 end
		return ({200, 350, 500})[myHero:GetSpellData(_R).level] + (0.75 * myHero.ap)
	end
	return 0
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

local TrackerColors = {
	Grey = DrawColor(215, 23, 23, 23),
	GreyFaded = DrawColor(55, 255, 255, 255),
	Black = DrawColor(255, 0, 0, 0),
	White = DrawColor(255, 255, 255, 255),
	Green = DrawColor(255, 0, 255, 125),
	GreenFaded = DrawColor(55, 0, 255, 125),
	Red = DrawColor(255, 255, 75, 135),
	CriticalRed = DrawColor(255, 255, 0, 135),
	SoftRed = DrawColor(255, 255, 115, 165),
	MIARed = DrawColor(55, 255, 85, 185),
}

function Karthus:DrawHealthTracker()
	if not (myHero.networkID)then return end
	if (Game.Timer() <= 1) then return end
	if self.AllowMove then
		self.Window = { x = cursorPos.x + self.AllowMove.x, y = cursorPos.y + self.AllowMove.y }
		self.Menu.Drawings.HPosXY:Value({self.Window.x, self.Window.y})
	end
	
	local rectHeight = 30 + (#Enemies*20) + 8
	
	Draw.Rect(self.Window.x, self.Window.y, 300, rectHeight, TrackerColors.Grey)
	Draw.Text("Health Tracker", 18, self.Window.x + 10, self.Window.y + 5, TrackerColors.White)
	
	local yOffset = 0
	
	
	
	local barWidth = 180
	local barOffset = 100
	local miaCheck = false
	for k, v in pairs(Enemies) do

		local hpRatio = v.health / math.floor(v.maxHealth)
		local RDmg = 0 
		
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
			Draw.Rect(self.Window.x + barOffset, self.Window.y + 39 + yOffset, barWidth, 8, TrackerColors.Black)
			Draw.Rect(self.Window.x + barOffset, self.Window.y + 39 + yOffset, barWidth * hpRatio -1, 8, IsValid(v) and TrackerColors.Green or TrackerColors.GreenFaded)
			if(RDmg > v.health) then
				Draw.Rect(self.Window.x + barOffset + (barWidth * hpRatio) - (barWidth * ultDmgRatio), self.Window.y + 39 + yOffset, barWidth * ultDmgRatio, 8, TrackerColors.CriticalRed)
			else
				Draw.Rect(self.Window.x + barOffset + (barWidth * hpRatio) - (barWidth * ultDmgRatio), self.Window.y + 39 + yOffset, barWidth * ultDmgRatio, 8, IsValid(v) and TrackerColors.SoftRed or TrackerColors.MIARed)
			end
		else
			Draw.Rect(self.Window.x + barOffset, self.Window.y + 39 + yOffset, barWidth, 8, TrackerColors.GreyFaded)
		end
		
		-- Name
		local name = v.charName
		if(name:find("Practice")) then
			name = "Dummy"
		end
		if(not miaCheck and v.alive) then
			if(RDmg > v.health) then
				Draw.Text(name, 17, self.Window.x + 10, self.Window.y + 35 + yOffset, TrackerColors.Red)
			else
				Draw.Text(name, 17, self.Window.x + 10, self.Window.y + 35 + yOffset, TrackerColors.Green)
			end
		else
			Draw.Text(name, 17, self.Window.x + 10, self.Window.y + 35 + yOffset, TrackerColors.GreyFaded)
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

			local RDmg = self:GetRawAbilityDamage("R")
			RDmg = CalcMagicalDamage(myHero, enemy, RDmg)

			UltableChamps[enemy.name].ultdmg = RDmg
			local Hp = enemy.health + (6 * enemy.hpRegen)
			if Hp <= RDmg and  not (CantKill(enemy, true, true, false)) then
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


Karthus()
LoadUnits()

