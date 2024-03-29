require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.17

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Illaoi will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Illaoi"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/illaoi.png"

local gameTick = GameTimer()
Illaoi.AutoLevelCheck = false

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.75, Range = 800, Radius = 100, Speed = 2900, Collision = false}
local W = {Delay = 0, Range = 450}
local E = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 950, Radius = 50, Speed = 1900, Collision = true, MaxCollision = 1, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
local R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 475, Speed = math.huge}

Illaoi.ComboDamageData = {}

--Main Menu
Illaoi.Menu = MenuElement({type = MENU, id = "KillerIllaoi", name = "Killer Illaoi", leftIcon = ChampIcon})
Illaoi.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

function Illaoi:__init()
	self:LoadMenu()

	table.insert(_G.SDK.OnTick, function()
		self:Tick()
	end)

	table.insert(_G.SDK.OnDraw, function()
		self:Draw()
	end)

	--Custom Callbacks
	_G.SDK.Orbwalker:OnPreAttack(function(...) Illaoi:OnPreAttack(...) end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) Illaoi:OnPostAttack(...) end)

	self:UpdateGoSMenuAutoLevel()
end

function Illaoi:LoadMenu()                     	

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "QAoE", name = "Prioritize Using Q for AoE", value = true})
	self.Menu.Combo:MenuElement({id = "SemiManualE", name = "Semi-Manual E", key = string.byte("Z")})
	self.Menu.Combo:MenuElement({id = "RSettings", name = "R Settings", type = MENU})

	--R Settings
	self.Menu.Combo.RSettings:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.Combo.RSettings:MenuElement({id = "MinEnemies", name = "Min Enemies to Auto R", value = 2, min = 1, max = 5, step = 1, identifier = " Enemies"})
	self.Menu.Combo.RSettings:MenuElement({id = "DuelR", name = "Duel with R if it Kills", value = true})
	self.Menu.Combo.RSettings:MenuElement({name = " ", drop = {"--- ULTRA R = Flash + R ---"}})
	self.Menu.Combo.RSettings:MenuElement({id = "UltraR", name = "Use Ultra R in Combo", value = true})
	self.Menu.Combo.RSettings:MenuElement({id = "SemiUltraR", name = "Semi-Manual Ultra R", key = string.byte("C")})
	self.Menu.Combo.RSettings:MenuElement({id = "ComboUltraRNumTargets", name = "Combo Ultra R Min Enemies", value = 4, min = 3, max = 5, step = 1, identifier = " Enemies"})
	self.Menu.Combo.RSettings:MenuElement({id = "UltraRNumTargets", name = "Semi-Manual Ultra R Min Enemies", value = 3, min = 1, max = 5, step = 1, identifier = " Enemies"})

	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "QMana", name = "Q Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "ChampCheck", name = "Use Abilities When No Champions Around", value = true})
	self.Menu.Clear:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear:MenuElement({id = "QCount", name = "Use Q to hit X Minions", value = 3, min = 1, max = 5, step = 1, identifier = " Minions"})
	self.Menu.Clear:MenuElement({id = "JungleSettings", name = "Jungle Settings", type = MENU})

	--Jungle Settings
	self.Menu.Clear.JungleSettings:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear.JungleSettings:MenuElement({id = "UseW", name = "Use W", value = true})

	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true})

	--Immobile
	self.Menu:MenuElement({id = "AutoEImmobile", name = "Auto E Immobile", value = true})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawW", name = "Draw W Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawE", name = "Draw E Range", value = true})
	--self.Menu.Drawings:MenuElement({id = "DrawSpirit", name = "Draw Spirit", value = true})
	self.Menu.Drawings:MenuElement({id = "DamageHPBar", name = "Damage HP Bar", type = MENU})

	self.Menu.Drawings.DamageHPBar:MenuElement({id = "DrawDamageHPBar", name = "Draw Full Combo Damage", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "AlwaysShow", name = "Always Show Damage Bar", value = false})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "YOffset", name = "Y Offset", value = 60, min = -100, max = 100, step = 5})
		
	self.Menu:MenuElement({id = "DisableInFountain", name = "Disable Orbwalker while in Fountain", value = true})
	
end

function Illaoi:UpdateGoSMenuAutoLevel()

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
			UpdateInfo()
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

function Illaoi:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Illaoi:Tick()
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

	--Reset W AA resetting outside of Combo mode
	if(mode ~= "Combo") then
		Illaoi.HoldW = false
	end

	self:UpdateComboDamage()
	self:KillSteal()
	self:HoverESpiritCheck()
	self:ScanESpirit()

	if(self.Menu.Combo.SemiManualE:Value()) then
		self:SemiManualE()
	end

	if(self.Menu.Combo.RSettings.SemiUltraR:Value() and self.Menu.Combo.RSettings.UseR:Value()) then
		self:SemiManualUltraR()
	end

	if(self.Menu.AutoEImmobile:Value()) then
		self:AutoEImmobile()
	end
	
	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end


Illaoi.HoldW = false
function Illaoi:OnPreAttack(args)
	DelayAction(function ()
		Illaoi.HoldW = false
	end, myHero.attackData.windUpTime)

	if myHero.range > 300 then
        local targets = {}
        for _, enemy in ipairs(Enemies) do
            if IsValid(enemy) and enemy.distance <= W.Range  then
                table.insert(targets, enemy)
            end
        end
        if #targets > 0 then
            table.sort(targets, _G.SDK.TargetSelector.CurrentSort)
            args.Target = targets[1]
            return
        end
    end
end

function Illaoi:OnPostAttack(args)
	Illaoi.HoldW = false
end

function Illaoi:IsUnitFleeing(unit)
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

function Illaoi:HasWActive()
	return HasBuff(myHero, "IllaoiW")
end

function Illaoi:HasRActive()
	return HasBuff(myHero, "IllaoiR")
end

function Illaoi:GetSpellbladeDamage(target)
   local hasItem, slot = HasItem({Item.Sheen, Item.IcebornGauntlet, Item.DivineSunderer})
   if(hasItem) then
	   return GetItemDamage(myHero:GetItemData(slot).itemID, target)
   end

   return 0
end

local canEScan = true
local eTar = nil
function Illaoi:ScanESpirit()
	if(Ready(_E)) then
		canEScan = true
	end
	if(Ready(_E) == false) and canEScan then
		for i = 0, myHero.buffCount do
			local buff = myHero:GetBuff(i)	
			if buff.count > 0 and buff.name:lower():find("illaoiespirittimervisual") then 
				canEScan = false
				DelayAction(function()
					self:CheckE()
				end, 0.25)
			end
		end
	end

	--Populate GGOrbwalker with the spirit
	if(Ready(_E) == false) then
		if(eTar ~= nil and eTar.alive and eTar.team == TEAM_ENEMY and self:IsUnitASpirit(eTar)) then
			_G.SDK.Cached:AddCachedHero(eTar)
		end
	end
	if(eTar ~= nil)then
		if(eTar.targetable == false) then eTar = nil end
	end
end

function Illaoi:CheckE()
	if (Game.mapID == SUMMONERS_RIFT) then
		for i = 0, 7250 do
			local obj = Game.Object(i)
			if(obj and obj.team == TEAM_ENEMY and not obj.dead and obj.type == "AIMinionClient" and obj.maxMana > 0) then
				for _, enemy in ipairs(Enemies) do
					if(obj.charName == enemy.charName) then
						eTar = obj
						return
					end
				end
			end
		end
	else -- Howling Abyss
		local objCount = Game.ObjectCount()
		for i = 1, objCount do
			local obj = Game.Object(i)
			if(obj and obj.team == TEAM_ENEMY and not obj.dead and obj.type == "AIMinionClient" and obj.maxMana > 0) then
				for _, enemy in ipairs(Enemies) do
					if(obj.charName == enemy.charName) then
						eTar = obj
						return
					end
				end
			end
		end
	end
end

function Illaoi:IsUnitASpirit(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)	

		if buff.count > 0 and buff.name:lower() == "illaoiespirit" then 
			return true
		end
	end

	return false
end

function Illaoi:Combo()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	--Reset hold W if we have no targets near our AA range 
	local meleeTar = GetTarget(_G.SDK.Data:GetAutoAttackRange(myHero) + 50)
	if(not meleeTar or IsValid(meleeTar) == false or self:HasRActive()) then
		Illaoi.HoldW = false
	end

	if(self.Menu.Combo.RSettings.UltraR:Value() and self.Menu.Combo.RSettings.UseR:Value()) then
		if(Ready(_R)) then
			local flashRange = 400			
			local canFlash, flashSlot = CanFlash()

			if(canFlash) then
				local tar = GetTarget(R.Radius + flashRange + 1000)
				if(IsValid(tar)) then
					local RBuffer = 30
					local searchrange = (flashRange + R.Radius -RBuffer)

					local nearbyEnemies = GetEnemiesAtPos(searchrange, R.Radius*2 - RBuffer, tar.pos, tar)
					local bestPos, count = CalculateBestCirclePosition(nearbyEnemies, R.Radius-RBuffer, false)

					if(count >= self.Menu.Combo.RSettings.ComboUltraRNumTargets:Value()) then
						if(myHero.pos:DistanceTo(bestPos) < searchrange) and (myHero.pos:DistanceTo(tar.pos) > R.Radius) then
							_G.SDK.Orbwalker:SetMovement(false)
							_G.Control.CastSpell(HK_R)
							_G.Control.CastSpell(flashSlot, bestPos)
							_G.SDK.Orbwalker:SetMovement(true)
						end
					end
				end
			end
		end
	end

	--R
	if(self.Menu.Combo.RSettings.UseR:Value()) then
		if(Ready(_R)) then
			--AoE Logic
			local enemies = GetEnemyHeroes(R.Radius)
			local enemyCount = #enemies
			if(enemyCount >= 2) then
				if(eTar and IsValid(eTar)) then
					if(GetDistance(eTar, myHero) < R.Radius) then
						enemyCount = enemyCount + 1
					end
				end
			end

			if(enemyCount >= self.Menu.Combo.RSettings.MinEnemies:Value()) then
				Control.CastSpell(HK_R)
				return
			end

			--Dueling R
			if(self.Menu.Combo.RSettings.DuelR:Value()) then
				local nearbyEnemies = GetEnemyHeroes(1000)
				local enemies = GetEnemyHeroes(R.Radius -75)
				if(#nearbyEnemies == 1 and #enemies == 1) then
					local enemy = enemies[1]
					if(enemy and IsValid(enemy) and self:IsUnitASpirit(enemy) == false) then
						local RPrediction = GGPrediction:SpellPrediction(R)
						RPrediction:GetPrediction(enemy, myHero)
						if RPrediction:CanHit(HITCHANCE_HIGH) then
							if self:ShouldUseR(enemy) then
								Control.CastSpell(HK_R)
								return	
							end
						end
					end
				end
			end
		end
	end
	
	--E
	if(self.Menu.Combo.UseE:Value()) then
		if(Ready(_E)) then
			local tar = GetTarget(Q.Range)
			if(tar and IsValid(tar) and tar.toScreen.onScreen) then

				local shouldUseE = true
				local fleeCheck = self:IsUnitFleeing(tar) and GetDistance(myHero, tar) <= W.Range
				local WCheck = false
				local hpCheck = ((tar.health / tar.maxHealth) <= 0.20 and GetDistance(myHero, tar) <= W.Range)
				if(GetDistance(myHero, tar) <= W.Range + 150 and ((myHero:GetSpellData(_W).cd - myHero:GetSpellData(_W).currentCd) <= 1 or Ready(_W))) then
					WCheck = true
				end

				if(WCheck or fleeCheck or hpCheck) then
					shouldUseE = false
				end

				if(shouldUseE) then
					CastPredictedSpell({Hotkey = HK_E, Target = tar, SpellData = E, maxCollision = 1})
				end
			end
		end
	end

	--W
	if(self.Menu.Combo.UseW:Value()) then

		local AAEndTimer = 	math.max(myHero.attackData.endTime-Game.Timer(), 0)
		if((myHero:GetSpellData(_W).currentCd <= 0.2 and AAEndTimer <= 0.5 and AAEndTimer > 0) or (IsValid(meleeTar) and AAEndTimer == 0 and Ready(_W)) and self:HasRActive() == false) then
			Illaoi.HoldW = true
		end

		if(Ready(_W) and Illaoi.HoldW == false) then
			local tar = GetTarget(W.Range)
			if(tar and IsValid(tar) and tar.toScreen.onScreen) then
				Control.CastSpell(HK_W, tar)
				Illaoi.HoldW = false
				return
			end
		end
	end

	--Q
	if(self.Menu.Combo.UseQ:Value()) then
		if(Ready(_Q)) then
			local tar = GetTarget(Q.Range -30)
			if(tar and IsValid(tar) and tar.toScreen.onScreen) then
				local isStrafing, avgPos = StrafePred:IsStrafing(tar)
				local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(tar)
				
				--We don't want to use Q on spirits, we'd rather use it on an actual champion ideally
				if(self:IsUnitASpirit(tar)) then
					local nearbyEnemies = {}
					for _, enemy in ipairs(GetEnemyHeroes(Q.Range - 30)) do
						if(enemy and IsValid(enemy)) then
							table.insert(nearbyEnemies, enemy)
						end
					end
					if(#nearbyEnemies > 0) then
						table.sort(nearbyEnemies, _G.SDK.TargetSelector.CurrentSort)
						tar = nearbyEnemies[1]
					end
				end

				if(self.Menu.Combo.QAoE:Value()) then
					--If two targets, see if we can land a Q on both
					--If 3 targets, we are going to raycast to the furthest target and collect all targest along the path, and then average a position to cast to.
					local furthestTar, nextFurthestTar = nil, nil
					local enemies = GetEnemyHeroes(Q.Range - 15)
					
					--2 Target logic
					if(#enemies == 2) then
						if(IsValid(enemies[1]) and IsValid(enemies[2])) then
							local avgCastPos = CalculateBoundingBoxAvg(enemies, math.huge, 0.25)
							local buffer = Q.Radius
							local point = ClosestPointOnLineSegment(enemies[1].pos, myHero.pos, myHero.pos:Extended(avgCastPos, Q.Range))
							local point2 = ClosestPointOnLineSegment(enemies[2].pos, myHero.pos, myHero.pos:Extended(avgCastPos, Q.Range))
							if(GetDistance(enemies[1], point) < buffer and GetDistance(enemies[2], point2) < buffer) then
								Control.CastSpell(HK_Q, avgCastPos)
								gameTick = GameTimer() + 0.2
								return							
							end
						end
					--3+ Target logic
					elseif(#enemies > 2) then
						--Find the furthest target and the next furthest target
						local validTargets = {}
						for _, enemy in ipairs(enemies) do
							if(enemy and IsValid(enemy)) then
								local dist = GetDistance(myHero, enemy)
								table.insert(validTargets, {enemy, dist})
							end
						end
						if(#validTargets > 0) then
							table.sort(validTargets, function(a, b) return a[2] > b[2] end )
						end

						if(validTargets[1][1] and validTargets[2][1]) then
							local isWall, collisionObjects1, collisionCount1 = GGPrediction:GetCollision(myHero.pos, validTargets[1][1].pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_ENEMYHERO})
							local isWall, collisionObjects2, collisionCount2 = GGPrediction:GetCollision(myHero.pos, validTargets[2][1].pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_ENEMYHERO})
							if(collisionCount1 > 0 and collisionCount2 > 0 ) then
								if(collisionCount1 > collisionCount2) then
									local avgCastPos = CalculateBoundingBoxAvg(collisionObjects1, math.huge, 0.25)
									Control.CastSpell(HK_Q, avgCastPos)
									return
								else
									local avgCastPos = CalculateBoundingBoxAvg(collisionObjects2, math.huge, 0.25)
									Control.CastSpell(HK_Q, avgCastPos)
									return
								end
							end
						end
					end
				end

				if(isStrafing) then
					if(avgPos:DistanceTo(myHero.pos) < Q.Range) then
						Control.CastSpell(HK_Q, avgPos)
						gameTick = GameTimer() + 0.2
						return
					end
				end
				if(isStutterDancing) then
					if(avgPos2:DistanceTo(myHero.pos) < Q.Range) then
						Control.CastSpell(HK_Q, avgPos2)
						gameTick = GameTimer() + 0.2
						return
					end
				end

				local newQ = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.75, Range = 800, Radius = 100, Speed = 2900}
				local QPrediction = GGPrediction:SpellPrediction(newQ)
				QPrediction:GetPrediction(tar, myHero)
				if QPrediction.CastPosition and QPrediction:CanHit(HITCHANCE_HIGH) then
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
					return
				end

				--E Logic
				if(tar.type == "AIMinionClient") then
					Control.CastSpell(HK_Q, tar)
					gameTick = GameTimer() + 0.2
					return			
				end
			end
		end
	end

end

function Illaoi:Harass()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	--Q
	if(self.Menu.Harass.UseQ:Value()) then
		if(Ready(_Q) and (myHero.mana / myHero.maxMana) * 100 >= self.Menu.Harass.QMana:Value() ) then
			local tar = GetTarget(Q.Range)
			if(tar and IsValid(tar) and tar.toScreen.onScreen) then
				CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q})
			end
		end
	end
end

function Illaoi:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	if(Ready(_W) == false) then
		if(self:HasWActive()) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(W.Range)

			for i = 1, #minions do
				local minion = minions[i]
				if(minion and IsValid(minion)) then
					local WDam = self:GetRawAbilityDamage("W", minion)
					
					if minion.health + 25 - WDam <= 0 then
						Control.Attack(minion)
					end
				end
			end
		end
	end

end

function Illaoi:Clear()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	local champCheck = true
	if(self.Menu.Clear.ChampCheck:Value()) then
		local numEnemies = GetEnemyCount(1500, myHero)
		if(numEnemies ~= 0) then
			champCheck = false
		end
	end

	if(champCheck) then

		if(self.Menu.Clear.UseW:Value()) then
			if(Ready(_W)) then
				local minions = _G.SDK.ObjectManager:GetEnemyMinions(W.Range)
				for i = 1, #minions do
					local minion = minions[i]
					if(minion and IsValid(minion) and minion.team ~= TEAM_JUNGLE) then
						local WDam = self:GetRawAbilityDamage("W", minion)
						
						if minion.health + 25 - WDam <= 0 then
							Control.CastSpell(HK_W)
							Control.Attack(minion)
							return
						end
					end
				end
			end
		end

		if(self.Menu.Clear.UseQ:Value()) then
			if(Ready(_Q)) then
				local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
				for i = 1, #minions do
					local minion = minions[i]
					if(minion and IsValid(minion) and minion.team ~= TEAM_JUNGLE) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
						if(collisionCount >= self.Menu.Clear.QCount:Value()) then
							local QDam = self:GetRawAbilityDamage("Q")
							local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
							if ((hp > 0) and (hp - QDam <= 0)) then --We want to make sure at least one minion dies
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


	if(self.Menu.Clear.JungleSettings.UseQ:Value()) then
		if(Ready(_Q)) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
			for i = 1, #minions do
				local minion = minions[i]
				if(minion and IsValid(minion) and minion.team == TEAM_JUNGLE) then
					Control.CastSpell(HK_Q, minion)
					return
				end
			end
		end
	end

	if(self.Menu.Clear.JungleSettings.UseW:Value()) then
		if(Ready(_W)) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(W.Range)
			for i = 1, #minions do
				local minion = minions[i]
				if(minion and IsValid(minion) and minion.team == TEAM_JUNGLE) then
					Control.CastSpell(HK_W, minion)
					return
				end
			end
		end
	end

end

function Illaoi:KillSteal()
	if(gameTick > GameTimer()) then return end
	
	--Q
	if(self.Menu.KillSteal.UseQ:Value()) then
		if(Ready(_Q)) and not myHero.isChanneling then
			local enemies = GetEnemyHeroes(Q.Range)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy.valid and IsValid(enemy) and enemy.toScreen.onScreen) then
						local isKillable = false
						local QDmg = self:GetRawAbilityDamage("Q")
						QDmg = CalcPhysicalDamage(myHero, enemy, QDmg)
						isKillable = (enemy.health - QDmg < 0)
						if(isKillable and (self:CantKill(enemy, true, true, false))==false) then
							local QPrediction = GGPrediction:SpellPrediction(Q)
							QPrediction:GetPrediction(enemy, myHero)
							if QPrediction.CastPosition and QPrediction:CanHit(HITCHANCE_HIGH) then
								Control.CastSpell(HK_Q, QPrediction.CastPosition)
								return
							end
						end
					end
				end
			end
		end
	end

end

function Illaoi:SemiManualE()
	_G.SDK.Orbwalker:Orbwalk()
	if(gameTick > GameTimer()) then return end	

	--E
	if(Ready(_E)) then
		local tar = GetTarget(E.Range - 15)
		if(IsValid(tar) and tar.toScreen.onScreen) then	
			CastPredictedSpell({Hotkey = HK_E, Target = tar, SpellData = E, maxCollision = 1})
		end
	end
end

function Illaoi:SemiManualUltraR()
	_G.SDK.Orbwalker:Orbwalk()
	if(gameTick > GameTimer()) then return end	

	if(self.Menu.Combo.RSettings.UltraR:Value()) then
		if(Ready(_R)) then
			local flashRange = 400			
			local canFlash, flashSlot = CanFlash()

			if(canFlash) then
				local tar = GetTarget(R.Radius + flashRange + 1000)
				if(IsValid(tar)) then
					local RBuffer = 30
					local searchrange = (flashRange + R.Radius -RBuffer)

					local nearbyEnemies = GetEnemiesAtPos(searchrange, R.Radius*2 - RBuffer, tar.pos, tar)
					local bestPos, count = CalculateBestCirclePosition(nearbyEnemies, R.Radius-RBuffer, false)

					if(count >= self.Menu.Combo.RSettings.UltraRNumTargets:Value()) then
						if(myHero.pos:DistanceTo(bestPos) < searchrange) and (myHero.pos:DistanceTo(tar.pos) > R.Radius) then
							_G.SDK.Orbwalker:SetMovement(false)
							_G.Control.CastSpell(HK_R)
							_G.Control.CastSpell(flashSlot, bestPos)
							_G.SDK.Orbwalker:SetMovement(true)
						end
					end
				end
			end
		end
	end

end

function Illaoi:AutoEImmobile()
	if(Ready(_E)) then
		local target = GetTarget(E.Range - 10)
		if(target ~= nil and IsValid(target)) then
			local EPrediction = GGPrediction:SpellPrediction(E)
			EPrediction:GetPrediction(target, myHero)
			if EPrediction.CastPosition and EPrediction:CanHit(HITCHANCE_IMMOBILE) then
				Control.CastSpell(HK_E, EPrediction.CastPosition)
				return
			end
			
			if(IsImmobile(target) >= 1.0) then
				local EPrediction = GGPrediction:SpellPrediction(E)
				EPrediction:GetPrediction(target, myHero)
				if EPrediction.CastPosition and EPrediction:CanHit(HITCHANCE_HIGH) then
					Control.CastSpell(HK_E, EPrediction.CastPosition)
					return
				end
			end
		end
	end
end

function Illaoi:HoverESpiritCheck()
	--This is a fallback method that will auto-add our E Spirit to GGOrbwalker if we mouse over the spirit.
	local hoverTar = Game.GetUnderMouseObject()
	if(hoverTar) then
		if(hoverTar.team == TEAM_ENEMY and hoverTar.type == "AIMinionClient" and hoverTar.maxMana > 0) then
			for _, enemy in ipairs(Enemies) do
				if(hoverTar.charName == enemy.charName) then
					_G.SDK.Cached:AddCachedHero(hoverTar)
					eTar = hoverTar
				end
			end
		end
	end
end

local dataTick = GameTimer()
function Illaoi:UpdateComboDamage()
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

function Illaoi:IsKillable(unit)
	local isKillable = false

	if(self.ComboDamageData[unit.networkID] ~= nil) then	
		local dmg = self.ComboDamageData[unit.networkID]
		if(unit.health - dmg <= 0 and (self:CantKill(unit, true, true, false)==false)) then
			isKillable = true
		end
	end
	return isKillable
end

function Illaoi:GetTotalDamage(unit)
	if(unit == nil or IsValid(unit) == false) then return 0 end
	local totalDmg = 0
	
	if(Ready(_R)) then
		local rDmg = self:GetRawAbilityDamage("R")
		rDmg = CalcPhysicalDamage(myHero, unit, rDmg)
		totalDmg = totalDmg + rDmg
	end

	if(Ready(_Q)) then
		local qDmg = self:GetRawAbilityDamage("Q")
		if(Ready(_R)) then
			
			qDmg = qDmg * 3 --We make the assumption that if we use R, at least 2 tentacles will hit
		end
		qDmg = CalcPhysicalDamage(myHero, unit, qDmg)
		totalDmg = totalDmg + qDmg
	end

	if(Ready(_W)) then
		local wDmg = self:GetRawAbilityDamage("W", unit)
		wDmg = CalcPhysicalDamage(myHero, unit, wDmg)
		totalDmg = totalDmg + wDmg
	end
	
	--Add an extra AA because its most likely you'll hit at least twice
	local AADmg = CalcPhysicalDamage(myHero, unit, myHero.totalDamage)
	totalDmg = totalDmg + AADmg

	return totalDmg
end

function Illaoi:ShouldUseR(unit)
	if(self:ROverkillCheck(unit) == true) then return false end
	if(unit == nil or not IsValid(unit)) then return false end

	local QDmg = CalcPhysicalDamage(myHero, unit, self:GetRawAbilityDamage("Q") * 3)
	local WDmg = CalcPhysicalDamage(myHero, unit, self:GetRawAbilityDamage("W", unit))
	local RDmg = CalcPhysicalDamage(myHero, unit, self:GetRawAbilityDamage("R"))
	local AADmg = CalcPhysicalDamage(myHero, unit, myHero.totalDamage)

	local totalDmg = QDmg + WDmg + RDmg + AADmg
	if(unit.health - totalDmg <= 0) then
		return true
	end
end

function Illaoi:ROverkillCheck(unit)
	--An overkill occurs when a target is extremely low HP, and we could have simply finished them off with a Q or W
	--We'll check to see if the unit is within R range since this determines if we should ultimately use R or not
	if(myHero.pos:DistanceTo(unit.pos) <= R.Radius) then
		local QCheck = (myHero:GetSpellData(_Q).cd - myHero:GetSpellData(_W).currentCd) <= 1
		local WCheck = (myHero:GetSpellData(_W).cd - myHero:GetSpellData(_W).currentCd) <= 1
		local QDmg = CalcPhysicalDamage(myHero, unit, self:GetRawAbilityDamage("Q"))
		local WDmg = CalcPhysicalDamage(myHero, unit, self:GetRawAbilityDamage("W", unit))
		if(Ready(_Q) or QCheck and unit.health - QDmg < 0) then
			return true
		end

		if(Ready(_W) or WCheck and unit.health - WDmg < 0) then
			return true
		end
	end
	
	return false
end

function Illaoi:GetRawAbilityDamage(spell, target)
	if(spell == "Q") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		local QMultiplier = ({1.1, 1.15, 1.2, 1.25, 1.3})[myHero:GetSpellData(_Q).level]
		return QMultiplier * ((myHero.levelData.lvl*10) + (1.2 * myHero.totalDamage) + (0.4 * myHero.ap))
	end
	
	if(spell == "W") then
		if myHero:GetSpellData(_W).level == 0 then return 0 end
		if(target and IsValid(target)) then
			local bonusADPercent = myHero.totalDamage * 0.04 + ({3, 3.5, 4, 4.5, 5})[myHero:GetSpellData(_W).level]
			return target.maxHealth * (bonusADPercent / 100) + myHero.totalDamage + self:GetSpellbladeDamage(target) + 1
		else
			return 0
		end
	end

	if(spell == "R") then
		if myHero:GetSpellData(_R).level == 0 then return 0 end
		return ({150, 250, 350})[myHero:GetSpellData(_R).level] + (myHero.bonusDamage * 0.5)
	end
	
	return 0
end

function Illaoi:CantKill(unit, kill, ss, aa)
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

function Illaoi:ManualKeys()
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
function Illaoi:Draw()
	if myHero.dead then return end
	
	--[[
	if(self.Menu.Drawings.DrawSpirit:Value()) then
		if(eTar ~= nil and IsValid(eTar)) then
			DrawCircle(eTar.pos, 150, 3, DrawColor(255, 46, 255, 140))
		end
	end
	--]]

	if(self.Menu.Drawings.DrawQ:Value()) then
		if(myHero:GetSpellData(_Q).level > 0) then
			if(myHero:GetSpellData(_Q).currentCd == 0 and myHero.activeSpell.name ~= "IllaoiQ") then
				DrawCircle(myHero, Q.Range, 1, DrawColor(140, 120, 255, 215))
			else
				DrawCircle(myHero, Q.Range, 1, DrawColor(35, 120, 255, 215))
			end
		end
	end

	if(self.Menu.Drawings.DrawW:Value()) then
		if(myHero:GetSpellData(_W).level > 0) then
			DrawCircle(myHero, W.Range, 1, DrawColor(35, 80, 80, 80))
		end
	end

	if(self.Menu.Drawings.DrawE:Value()) then
		if(myHero:GetSpellData(_E).level > 0) then
			if(Ready(_E) and myHero.activeSpell.name ~= "IllaoiE") then
				DrawCircle(myHero, E.Range, 1, DrawColor(75, 140, 205, 255))
			else
				DrawCircle(myHero, E.Range, 1, DrawColor(35, 140, 205, 255))
			end
		end
	end

	if(self.Menu.Drawings.DamageHPBar.DrawDamageHPBar:Value()) then
		self:DrawDamageHPBars()
		local mode = GetMode()
		if(self.Menu.Drawings.DamageHPBar.AlwaysShow:Value()) then
			alphaLerp = 1
		else
			if(mode == "Combo") then
				alphaLerp = math.max(alphaLerp - 0.1, 0)
			else
				alphaLerp = math.min(alphaLerp + 0.1, 1)
			end
		end
	end
end

function Illaoi:DrawDamageHPBars()
	
	for _, enemy in pairs(Enemies) do
		if(enemy.valid and IsValid(enemy)) then
			if(enemy.toScreen.onScreen) then
				if(Ready(_Q) or Ready(_W) or Ready(_R)) then
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

Illaoi()
LoadUnits()
