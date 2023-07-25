require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.35

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Annie will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Annie"

local AnniePassiveStacksBuff = "anniepassivestack"
local AnniePassivePrimedBuff = "anniepassiveprimed"
local AnnieTibbersBuff = "AnnieRController"
local AnnieIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/annie.png"

local COMBO_MODE_ALLIN = 1
local COMBO_MODE_SPAM = 2

local gameTick = GameTimer()

-- GG PRED
local Q = {Delay = 0.25, Range = 625}
local W = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.25, Radius = 200, Range = 600, Speed = math.huge, Collision = false}
local E = {Range = 800}
local R = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 600, Speed = math.huge, Collision = false}

local comboDamageData = {}

--Main Menu
Annie.Menu = MenuElement({type = MENU, id = "KillerAnnie", name = "Killer Annie"})
Annie.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

function Annie:__init()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	
	--Load AutoE Champ Spell Toggles
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		champName = args.charName
		enemy = args.unit
		self.Menu.AutoE.Ignore[champName]:MenuElement({id = enemy:GetSpellData(_Q).name, name = "Q", value = false})
		self.Menu.AutoE.Ignore[champName]:MenuElement({id = enemy:GetSpellData(_W).name, name = "W", value = false})
		self.Menu.AutoE.Ignore[champName]:MenuElement({id = enemy:GetSpellData(_E).name, name = "E", value = false})
		self.Menu.AutoE.Ignore[champName]:MenuElement({id = enemy:GetSpellData(_R).name, name = "R", value = false})
	end)

	self:UpdateGoSMenuAutoLevel()

end

function Annie:LoadMenu()                     	

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	if(myHero:GetSpellData(SUMMONER_1).name == "SummonerDot") or (myHero:GetSpellData(SUMMONER_2).name == "SummonerDot") then
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "Ignite Loaded", type = SPACE})
	else
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "Ignite Not Loaded", type = SPACE})
	end
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
	self.Menu.Combo:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
	self.Menu.Combo:MenuElement({name = " ", drop = {"-----------------------------"}})	
	self.Menu.Combo:MenuElement({id = "AABlock", name = "Smart AA Block in Combo", value = true})
	self.Menu.Combo:MenuElement({id = "RSettings", name = "Ult Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "NinjaCombo", name = "Ninja Burst Combo", type = MENU})
	
	--Ult Settings
	self.Menu.Combo.RSettings:MenuElement({id = "RStunCheck", name = "Initiate R on killable target ONLY if it Stuns", value = true, tooltip = "Disable this if you want to initiate a combo with Tibbers without requiring your passive"})
	self.Menu.Combo.RSettings:MenuElement({id = "RAoEKillCheck", name = "Use R in Enemy Cluster if one is Killable", value = true, tooltip = "A cluster is two or enemies stacked within R's radius"})
	self.Menu.Combo.RSettings:MenuElement({id = "RAoECheckStun", name = "Min Enemies to Auto R with Stun", value = 2, min = 2, max = 5, step = 1})
	self.Menu.Combo.RSettings:MenuElement({id = "RAoECheck", name = "Min Enemies to Auto R without Stun", value = 4, min = 2, max = 5, step = 1})
	self.Menu.Combo.RSettings:MenuElement({id = "DontSoloUlt", name = "Don't Use Solo R on...", type = MENU})
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		self.Menu.Combo.RSettings.DontSoloUlt:MenuElement({id = args.charName, name = args.charName, value = false})
	end)
	
	--Ninja Combo
	self.Menu.Combo.NinjaCombo:MenuElement({id = "UseFlash", name = "Use Smart Flash", value = true})
	self.Menu.Combo.NinjaCombo:MenuElement({id = "RequireStun", name = "Require Stun to Ninja", value = true})
	self.Menu.Combo.NinjaCombo:MenuElement({id = "Key", name = "Semi-manual Key", key = string.byte("Z")})
	
	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
	self.Menu.Harass:MenuElement({id = "UseW", name = "Follow up W on Stunned Target", value = true})
	self.Menu.Harass:MenuElement({id = "LastHit", name = "Last Hit with Q until you have Passive", value = true})
	self.Menu.Harass:MenuElement({id = "HoldQ", name = "Only Q enemy if you have Passive", value = false})
	self.Menu.Harass:MenuElement({id = "QMana", name = "Q Min Mana", value = 15, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Harass:MenuElement({id = "WMana", name = "W Min Mana", value = 30, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseQ", name = "Use Q in Last Hit", value = true})
	self.Menu.LastHit:MenuElement({id = "HoldQ", name = "Hold Q if has Passive and if Champs Nearby", value = true})
	self.Menu.LastHit:MenuElement({id = "TowerFarm", name = "Last Hit under tower regardless of Passive", value = true})
	self.Menu.LastHit:MenuElement({id = "UseW", name = "Use W in if Q or AA cant kill", value = true})
	self.Menu.LastHit:MenuElement({id = "WMana", name = "W Last Hit Min Mana", value = 40, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Clear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
	self.Menu.Clear:MenuElement({id = "WMana", name = "W Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear:MenuElement({id = "EMana", name = "E Min Mana", value = 15, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear:MenuElement({id = "ClearType", name = "Clear Logic",  value = 1, drop = {"Smart", "Use Abilities on Cooldown"}})
	
	-- Auto E
	self.Menu:MenuElement({id = "AutoE", name = "Auto E", type = MENU})
	self.Menu.AutoE:MenuElement({id = "Self", name = "Use on Self", value = true})
	self.Menu.AutoE:MenuElement({id = "Allies", name = "Use on Allies", value = true})
	self.Menu.AutoE:MenuElement({id = "Humanizer", name = "Humanized Delay", value = true})
	self.Menu.AutoE:MenuElement({id = "EMana", name = "Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.AutoE:MenuElement({id = "Ignore", name = "Ignore Champion Abilities", type = MENU})
	
	self.Menu:MenuElement({id = "AutoStacks", name = "Auto Build Stacks in Base", value = true})
	
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		self.Menu.AutoE.Ignore:MenuElement({id = args.charName, name = args.charName, type = MENU})
		--[[
		self.Menu.AutoE.Ignore[args.charName]:MenuElement({id = args:GetSpellData(_Q).name, name = "Q", value = false})
		self.Menu.AutoE.Ignore[args.charName]:MenuElement({id = args:GetSpellData(_W).name, name = "W", value = false})
		self.Menu.AutoE.Ignore[args.charName]:MenuElement({id = args:GetSpellData(_E).name, name = "E", value = false})
		self.Menu.AutoE.Ignore[args.charName]:MenuElement({id = args:GetSpellData(_R).name, name = "R", value = false})
		--]]
	end)
	
	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.KillSteal:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.KillSteal:MenuElement({id = "UseR", name = "Use R if Q & W on CD", value = true, tooltip = "Goomba stomp"})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQW", name = "Draw Q & W Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawKillable", name = "Draw Killable Enemies", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawNinjaComboStatus", name = "Draw Ninja Combo Status", value = true})
	self.Menu.Drawings:MenuElement({id = "DamageHPBar", name = "Damage HP Bar", type = MENU})
	self.Menu.Drawings:MenuElement({id = "Debug", name = "Debug Drawings", type = MENU})
	
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "DrawDamageHPBar", name = "Draw Full Combo Damage", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "YOffset", name = "Y Offset", value = 60, min = -100, max = 100, step = 5})
	--debug
	self.Menu.Drawings.Debug:MenuElement({id = "DrawUltClusters", name = "Draw Ult Clusters", value = false})
	
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

	self.Menu:MenuElement({id = "DisableInFountain", name = "Disable Orbwalker while in Fountain", value = true})
	
end

function Annie:UpdateGoSMenuAutoLevel()
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

function Annie:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Annie:Tick()
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
	
	self:AABlock()
	self:QStatusUpdate()
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
	self:AutoE()
	self:ManualSpells()
	self:AutoStack()
	self:UpdateComboDamage()
	
	if(self.Menu.Combo.NinjaCombo.Key:Value()) then
		self:NinjaCombo()
	end
	
	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end

local dataTick = GameTimer()

function Annie:UpdateComboDamage()

	if(dataTick > GameTimer()) then return end
	
	local enemies = GetEnemyHeroes(3000)
	if(#enemies > 0) then
		for _, enemy in pairs(enemies) do
			if(enemy and enemy.valid and IsValid(enemy)) then
				comboDamageData[enemy.name] = self:GetTotalDamage(enemy)
			end
		end
		
		dataTick = GameTimer() + 0.5
	end
end

local QTick = GameTimer()
local AnnieQTarg = nil
local AnnieQActive = false

function Annie:QStatusUpdate()

	local spell = nil
	if(myHero.activeSpell.name == "AnnieQ") and QTick + 1 < GameTimer() then
		spell = myHero.activeSpell
		AnnieQTarg = spell.target
		local start = Vector(spell.startPos)
		local endPos = Vector(spell.placementPos)
		local totalTime = (endPos:DistanceTo(start) / 1400 + spell.windup)
		QTick = GameTimer() + totalTime
	end
	
	if(QTick > GameTimer()) then
		AnnieQActive = true
	else
		AnnieQTarg = nil
		AnnieQActive = false
	end

end

function Annie:HasTibbers()
    return myHero:GetSpellData(_R).name == AnnieTibbersBuff
end

function Annie:DebugCluster()
	local RBuffer = 30
	local target = GetTarget(R.Range + R.Radius + 3000)
	
	if(target and IsValid(target) and target ~= nil) then
		local searchrange = R.Range + R.Radius - RBuffer
		local canFlash = false
		if self.Menu.Combo.NinjaCombo.UseFlash:Value()  then--and self.Menu.Combo.NinjaCombo.Key:Value() then
			canFlash = CanFlash()
		end
		if canFlash == true then
			searchrange = R.Range + R.Radius +400 - RBuffer
		end
		local nearbyEnemies = GetEnemiesAtPos(searchrange, R.Radius*2 -RBuffer, target.pos, target)
		local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius - RBuffer, true)
		if(myHero.pos:DistanceTo(bestPos) < R.Range + RBuffer + 400 + R.Radius + 1000) then
			DrawCircle(bestPos, R.Radius -RBuffer, 1, DrawColor(85, 255, 255, 255)) --(Alpha, R, G, B)
		end

	end
end

function Annie:CalculateBestCirclePosition(targets, radius, edgeDetect)

	local avgCastPos = CalculateBoundingBoxAvg(targets, math.huge, 0.25)
	local newCluster = {}
	local distantEnemies = {}

	for _, enemy in pairs(targets) do
		if(enemy.pos:DistanceTo(avgCastPos) > radius) then
			table.insert(distantEnemies, enemy)
		else
			table.insert(newCluster, enemy)
		end
	end
	
	if(#distantEnemies > 0) then
		local closestDistantEnemy = nil
		local closestDist = 10000
		for _, distantEnemy in pairs(distantEnemies) do
			local dist = distantEnemy.pos:DistanceTo(avgCastPos)
			if( dist < closestDist ) then
				closestDistantEnemy = distantEnemy
				closestDist = dist
			end
		end
		if(closestDistantEnemy ~= nil) then
			table.insert(newCluster, closestDistantEnemy)
		end
		
		--Recursion, we are discarding the furthest target and recalculating the best position
		if(#newCluster ~= #targets) then
			return self:CalculateBestCirclePosition(newCluster, radius)
		end
	end
	
	if(edgeDetect) and myHero.pos:DistanceTo(avgCastPos) > R.Range then

		local checkPos = myHero.pos:Extended(avgCastPos, R.Range)
		local furthestTarget = FindFurthestTargetFromMe(newCluster)
		local fakeMyHeroPos = avgCastPos:Extended(myHero.pos, R.Range + radius - 50)
		if(furthestTarget ~= nil) then
			fakeMyHeroPos = avgCastPos:Extended(myHero.pos, R.Range + radius - furthestTarget.pos:DistanceTo(avgCastPos))
		end

		if(myHero.pos:DistanceTo(avgCastPos) >= fakeMyHeroPos:DistanceTo(avgCastPos)) then
			checkPos = fakeMyHeroPos:Extended(avgCastPos, R.Range)
		end
		
		local hitAllCheck = true
		for _, v in pairs(newCluster) do
			if(v:GetPrediction(math.huge, 0.25):DistanceTo(checkPos) >= radius + 5) then -- the +5 is to fix a precision issue
				hitAllCheck = false
			end
		end
		
		if hitAllCheck then 
			return checkPos, #newCluster, newCluster
		end

	end
	
	return avgCastPos, #targets, targets
end

function Annie:GetPassiveStacks()
	return GetBuffData(myHero, AnniePassiveStacksBuff).count
end

function Annie:GetRawAbilityDamage(spell)
	if(spell == "Q") then
		 return ({70, 105, 140, 175, 210})[myHero:GetSpellData(_Q).level] + (0.75 * myHero.ap)
	end
	
	if(spell == "W") then
		return ({70, 115, 160, 205, 250})[myHero:GetSpellData(_W).level] + (0.85 * myHero.ap)
	end
	
	if(spell == "R") then
		return ({150, 275, 400})[myHero:GetSpellData(_R).level] + (0.75 * myHero.ap)
	end
	
	return 0
end

function Annie:HasStunBuff()
	return HasBuff(myHero, AnniePassivePrimedBuff)
end

function Annie:Combo()
	
	local currComboMode = nil
	local target = GetTarget(R.Range + R.Radius)
	
	if(target == nil or not target.valid or not IsValid(target)) then return end
	if(myHero.isChanneling) then return end
	
	local isKillable, igniteOverkillCheck = self:IsKillable(target)
	
	if(isKillable and IsImmobile(target) >= 0.5) and not igniteOverkillCheck then --A stunned killable target will be ignited
		UseIgnite(target)
	end
	
	if(isKillable and Ready(_Q) == false and Ready(_W) == false and Ready(_R) == false) then --A stunned killable target will be ignited
		UseIgnite(target)
	end
	
	--Ignore using R on champions that are isolated
	local ignoreChamp = false
	if(self.Menu.Combo.RSettings.DontSoloUlt[target.charName]:Value()) then
		local nearbyEnemies = GetEnemiesAtPos(R.Range + R.Radius, R.Radius*2, target.pos,target)
		local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius)
		if(count == 1) then
			ignoreChamp = true
		end
	end
	
	--Auto R Check
	if(Ready(_R) and self:HasTibbers() == false and self.Menu.Combo.UseR:Value() and ignoreChamp == false) then
		local RBuffer = 30
		
		if(target and IsValid(target) and target ~= nil) then
			local nearbyEnemies = GetEnemiesAtPos(R.Range + R.Radius -RBuffer, R.Radius*2 -RBuffer, target.pos, target)
			local bestPos, count, targets = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius, true)
			
			--Cluster AoE kill check
			if(self.Menu.Combo.RSettings.RAoEKillCheck:Value()) then
				if(count >= 2) then
					for _, target in pairs(targets) do
						if(self:IsKillable(target)) then
							if(self.Menu.Combo.RSettings.RStunCheck:Value() and self:IsHoldingPassiveMode()) then
								Control.CastSpell(HK_R, bestPos)
								return
							elseif(self.Menu.Combo.RSettings.RStunCheck:Value() == false) then
								Control.CastSpell(HK_R, bestPos)
								return
							end
						end
					end
				end
			end
			
			--Stun check
			if(count >= self.Menu.Combo.RSettings.RAoECheckStun:Value()) and self:IsHoldingPassiveMode() then
				if(self:GetPassiveStacks() == 3) then
					if(myHero.pos:DistanceTo(bestPos) < R.Range) then
						Control.CastSpell(HK_E)
						Control.CastSpell(HK_R, bestPos)
						return
					end
				else
					if(myHero.pos:DistanceTo(bestPos) < R.Range) then
						Control.CastSpell(HK_R, bestPos)
						return
					end
				end
			elseif(count >= self.Menu.Combo.RSettings.RAoECheck:Value()) then
				if(myHero.pos:DistanceTo(bestPos) < R.Range) then
					Control.CastSpell(HK_R, bestPos)
					return
				end	
			end
		end
	end
	
	-- Change how we combo based on our dynamic combo mode
	if(Ready(_Q) and Ready(_W) and Ready(_R) and self:HasTibbers() == false and self:IsKillable(target) and self.Menu.Combo.UseR:Value()) and (self:CantKill(target, true, true, false))==false then
		if(self.Menu.Combo.RSettings.RStunCheck:Value() and self:IsHoldingPassiveMode()) and ignoreChamp == false then
			currComboMode = COMBO_MODE_ALLIN
		elseif(self.Menu.Combo.RSettings.RStunCheck:Value() == false) and ignoreChamp == false then --If we have the setting to not require a stun then we can still all in
			currComboMode = COMBO_MODE_ALLIN
		else
			currComboMode = COMBO_MODE_SPAM
		end
	else
		currComboMode = COMBO_MODE_SPAM
	end
	
	--Q and W
	if(currComboMode == COMBO_MODE_SPAM) then
		
		if(self.Menu.Combo.UseQ:Value() and Ready(_Q) and myHero.pos:DistanceTo(target.pos) < Q.Range) then
			Control.CastSpell(HK_Q, target)
			return
		end
		
		if(self.Menu.Combo.UseW:Value() and Ready(_W) and myHero.pos:DistanceTo(target.pos) < W.Range) then
			Control.CastSpell(HK_W, target)
			return
		end
		
		--Use R in spam mode if it can kill / stun
		if(self.Menu.Combo.UseR:Value() and Ready(_R) and self:HasTibbers()==false and myHero.pos:DistanceTo(target.pos) < R.Range and ignoreChamp == false) then
			if(self:IsKillable(target)) and (self:CantKill(target, true, true, false))==false then
				Control.CastSpell(HK_R, target)
			end
		end	
		
	elseif(currComboMode == COMBO_MODE_ALLIN) then -- Engage with Tibbers and Ignite if we can full combo
		
		local RBuffer = 30
		local nearbyEnemies = GetEnemiesAtPos(R.Range + R.Radius -RBuffer, R.Radius*2 -RBuffer, target.pos, target)
		local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius, true)
		
		if(self:GetPassiveStacks() == 3) then
			if(myHero.pos:DistanceTo(bestPos) < R.Range) then
				Control.CastSpell(HK_E)
				Control.CastSpell(HK_R, bestPos)
			end
		else
			if(myHero.pos:DistanceTo(bestPos) < R.Range) then
				Control.CastSpell(HK_R, bestPos)
			end
		end
		
	end
	
end

function Annie:IsHoldingPassiveMode() -- Check to see if we meet our passive mode conditions; either you have your stun, or you have 3 stacks and an E
	local isHolding = false

	if self:HasStunBuff() or (self:GetPassiveStacks() >= 3 and Ready(_E)) then isHolding = true end
	
	return isHolding
end

function Annie:Harass()
	
	if(self.Menu.Harass.LastHit:Value() and Ready(_Q)) then
		if(gameTick > GameTimer()) then return end
		
		local shouldQLastHit = true
		
		if(self:HasStunBuff()) then
			shouldQLastHit = false
		else
			shouldQLastHit = true
		end
		
		if(shouldQLastHit) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) then
					local QDam = getdmg("Q", minion, myHero)
					
					if (minion.health + 5 < QDam) then
						Control.CastSpell(HK_Q, minion)
						gameTick = GameTimer() + 0.33
					end
				end
			end
		end
		
	end
	
	-- Q
	local target = GetTarget(Q.Range)
	if(target ~= nil and IsValid(target)) then
		
		if(Ready(_Q) and self.Menu.Harass.UseQ:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then
			if(self.Menu.Harass.HoldQ:Value()) then
				if(self:GetPassiveStacks() == 3) and Ready(_E) then
					Control.CastSpell(HK_Q, target)
					Control.CastSpell(HK_E)
				elseif(self:HasStunBuff()) then
					Control.CastSpell(HK_Q, target)
				end
			else
				Control.CastSpell(HK_Q, target)
			end
		end
		
		if(Ready(_W) and self.Menu.Harass.UseW:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.WMana:Value() / 100)) then
			if(IsImmobile(target) >= 1.0) then
				Control.CastSpell(HK_W, target)
			end
		end	
	end
end

function Annie:LastHit()

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) -- Q range is the same as W range
	local canonMinion = GetCanonMinion(minions)
	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	if(Ready(_Q) and self.Menu.LastHit.UseQ:Value()) then
		
		--Passive mode check
		local shouldLastHit = true
		
		if(self.Menu.LastHit.HoldQ:Value()) then
		
			if(self:HasStunBuff()) then
				shouldLastHit = false
			end
	
			--If we are under tower, we can use our abilities
			if(self.Menu.LastHit.TowerFarm:Value()) then
				if(IsUnderFriendlyTurret(myHero)) then shouldLastHit = true end
				if(GetEnemyCount(2000, myHero) == 0) then shouldLastHit= true end
			end
		end
		
		--Prioritize the canon minion if its low
		if(canonMinion ~= nil) and IsValid(canonMinion) then
			local QDam = getdmg("Q", canonMinion, myHero)
			local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay+(myHero.pos:DistanceTo(canonMinion.pos)/1400))
			
			if ((hp > 0) and (hp + (canonMinion.health*0.05) < QDam) or (canonMinion.health + 5 < QDam)) and shouldLastHit then
				Control.CastSpell(HK_Q, canonMinion)
			end
		end
		
		for i = 1, #minions do
			local minion = minions[i]
			if IsValid(minion) then
				local QDam = getdmg("Q", minion, myHero)
				local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay+(myHero.pos:DistanceTo(minion.pos)/1400))
				
				if ((hp > 0) and (hp + (minion.health*0.05) < QDam) or (minion.health + 5 < QDam)) and shouldLastHit then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
	
	if(Ready(_Q)==false and Ready(_W) and self.Menu.LastHit.UseW:Value()) then
		if((myHero.mana / myHero.maxMana) >= (self.Menu.LastHit.WMana:Value() / 100)) then
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) then
					local WDam = getdmg("W", minion, myHero)
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, W.Delay)
					
					if (hp < 0) then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
	
end

function Annie:Clear()
	
	if(self.Menu.Clear.UseQ:Value() == false and self.Menu.Clear.UseW:Value() == false) then return end
	if(not Ready(_Q) and not Ready(_W)) then return end	
	if(myHero.isChanneling) then return end
	
	local SMART_CLEAR = 1
	local SPAM_CLEAR = 2
	local clearMode = self.Menu.Clear.ClearType:Value()
	
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) -- Q range is the same as W range
	local canonMinion = GetCanonMinion(minions)
	
	if(clearMode == SPAM_CLEAR) then
		if(Ready(_Q) and self.Menu.Clear.UseQ:Value()) then
			
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				Control.CastSpell(HK_Q, canonMinion)
			else
				for i = 1, #minions do
					local minion = minions[i]
					if IsValid(minion) then
						Control.CastSpell(HK_Q, minion)
					end
				end
			end
		end
		
		if(Ready(_W) and self.Menu.Clear.UseW:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.WMana:Value() / 100)) then
			
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				Control.CastSpell(HK_W, canonMinion)
			else
				for i = 1, #minions do
					local minion = minions[i]
					if IsValid(minion) then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
		
		return
	end
	
	if(clearMode == SMART_CLEAR) then

		if(Ready(_W) and self.Menu.Clear.UseW:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.WMana:Value() / 100)) then
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local WDam = getdmg("W", canonMinion, myHero)
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, W.Delay)
				if(AnnieQActive == false) and (AnnieQTarg ~= canonMinion) then
					if (hp > 0) and (hp + (canonMinion.health*0.08) < WDam) or (canonMinion.health + 10 < WDam) then
						Control.CastSpell(HK_W, canonMinion)
						return
					end
				end
			end
			
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) then
					local WDam = getdmg("W", minion, myHero)
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, W.Delay)
					
					--Different logic for jungle minions
					if(minion.team == TEAM_JUNGLE) then
						local clusterJgMinions = GetMinionsAroundMinion(W.Range, 350, minion)
						local clusterJgPos = AverageClusterPosition(clusterJgMinions)
						if(clusterPos ~= nil) then
							Control.CastSpell(HK_W, clusterPos)
							return
						else
							Control.CastSpell(HK_W, minion)
							return
						end
					end
					
					if (hp > 0) and (hp + (minion.health*0.05) < WDam) or (minion.health + 5 < WDam) then
						if(myHero.pos:DistanceTo(minion.pos) > 75) then -- Dont try to point blank your W
							local clusterMinions = GetMinionsAroundMinion(W.Range, 350, minion)
							if(#clusterMinions >= 2) then
								Control.CastSpell(HK_W, minion)
								return
							end
						end
					else
						if(myHero.pos:DistanceTo(minion.pos) > 75) then -- Dont try to point blank your W
							local clusterMinions = GetMinionsAroundMinion(W.Range, 350, minion) --This will try to cast W on clusters of minions evenly
							if(#clusterMinions >= 3) then
								local clusterPos = AverageClusterPosition(clusterMinions)
								if(clusterPos ~= nil) then
									Control.CastSpell(HK_W, clusterPos)
									return
								else
									Control.CastSpell(HK_W, minion)
									return
								end
							end
						end
					end
					
				end
			end
		end
		
		if(Ready(_E) and self.Menu.Clear.UseE:Value() and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.EMana:Value() / 100)) then
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) then
					if(minion.team == TEAM_JUNGLE) then
						if(minion.attackData.target ~= 0) then
							if(minion.attackData.target == myHero.handle) then
								Control.CastSpell(HK_E)
							end
						end
					end
				end
			end
		end
		
		if(Ready(_Q) and self.Menu.Clear.UseQ:Value()) then
			local minionTarget = nil
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local QDam = getdmg("Q", canonMinion, myHero)
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay+(myHero.pos:DistanceTo(canonMinion.pos)/1400))
				
				if (hp > 0) and (hp + (canonMinion.health*0.05) < QDam) or (canonMinion.health + 5 < QDam) then
					Control.CastSpell(HK_Q, canonMinion)
					return
				end
			end
			
			for i = 1, #minions do
				local minion = minions[i]
				if IsValid(minion) then
					local QDam = getdmg("Q", minion, myHero)
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay+(myHero.pos:DistanceTo(minion.pos)/1400))
					local AAdmg = _G.SDK.Damage:GetAutoAttackDamage(myHero, minion)
					if (hp > 0) and (hp + (minion.health*0.05) < QDam) or (minion.health + 5 < QDam) then
						minionTarget = minion
						break
					end
					
					if(hp - QDam >= AAdmg) and minion.team == 300 then
						minionTarget = minion
					end
				end
			end
			
			if(minionTarget ~= nil) then
				Control.CastSpell(HK_Q, minionTarget)
				return
			end
			
		end
		
	end
end

function Annie:KillSteal()
	if(gameTick > GameTimer()) then return end
	
	if(self.Menu.KillSteal.UseQ:Value() == false and self.Menu.KillSteal.UseW:Value() == false and self.Menu.KillSteal.UseR:Value() == false) then return end
	if(myHero.isChanneling) then return end
	local target = GetTarget(R.Range + R.Radius)
	if(target ~= nil and IsValid(target)) then
		
		--Q KS
		if(Ready(_Q) and self.Menu.KillSteal.UseQ:Value()) then
			if(myHero.pos:DistanceTo(target.pos) < Q.Range) then
				local QDam = getdmg("Q", target, myHero)
				if(QDam > target.health) then
					Control.CastSpell(HK_Q, target)
				end
			end
		end
		
		--W KS
		if(Ready(_W) and self.Menu.KillSteal.UseW:Value()) then
			if(myHero.pos:DistanceTo(target.pos) < W.Range) then
				local WDam = getdmg("W", target, myHero)
				if(WDam > target.health) then
					Control.CastSpell(HK_W, target)
				end
			end
		end
		
		local ignoreChamp = false
		if(self.Menu.Combo.RSettings.DontSoloUlt[target.charName] ~= nil) then
			if(self.Menu.Combo.RSettings.DontSoloUlt[target.charName]:Value()) then
				local nearbyEnemies = GetEnemiesAtPos(R.Range + R.Radius, R.Radius *2, target.pos,target)
				local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius)
				if(count == 1) then
					ignoreChamp = true
				end
			end
		end
		
		--R KS
		if(Ready(_R) and self:HasTibbers()== false and self.Menu.KillSteal.UseR:Value()) and ignoreChamp == false and (self:CantKill(target, true, true, false))==false then
			if (Ready(_Q) == false and Ready(_W) == false) then
				local RBuffer = 30
				local RDam = getdmg("R", target, myHero)
				if(target.health - RDam <= 0) and (myHero.pos:DistanceTo(target.pos) < R.Range + R.Radius - RBuffer) then
					if(myHero.pos:DistanceTo(target.pos) < R.Range) then
						local nearbyEnemies = GetEnemiesAtPos(R.Range + R.Radius -RBuffer, R.Radius*2 -RBuffer, target.pos,target)
						local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius)
						if(count >= 2) then
							Control.CastSpell(HK_R, bestPos)
						else
							Control.CastSpell(HK_R, target.pos)
						end
					else --If the target is killable but outside of our R Range, we can clip them at the edge of our R Radius
						Control.CastSpell(HK_R, target.pos:Extended(myHero.pos, R.Radius - RBuffer))
					end
				end
			end
		end
		
	end
end

function Annie:AutoE()
	local mana = (self.Menu.AutoE.EMana:Value() / 100)
	if self.Menu.AutoE.Self:Value() == false and self.Menu.AutoE.Allies:Value()==false then return end
	if not ((myHero.mana / myHero.maxMana) >= (self.Menu.AutoE.EMana:Value() / 100)) then return end
	if not Ready(_E) then return end
	
	local targets = GetEnemyHeroes(2500)
	local allies = _G.SDK.ObjectManager:GetAllyHeroes(E.Range)
	for _, unit in ipairs(targets) do
		local ePos = unit.pos
		local eSpell = unit.activeSpell
		if(eSpell and eSpell.valid and unit.isChanneling) then
			local delayAmnt = 0
			if(self.Menu.AutoE.Ignore[unit.charName][eSpell.name]) then
				if(self.Menu.AutoE.Ignore[unit.charName][eSpell.name]:Value()) then return end --If the enemy is casting a spell we have set to ignore, then don't shield
			end
			
			if(self.Menu.AutoE.Humanizer:Value()) then
				delayAmnt = assert(math.random(100, 300))
			end
			--Check on self
			if(self.Menu.AutoE.Self:Value()) then
				if(eSpell.target == myHero.handle) then
					DelayAction(function()
						Control.CastSpell(HK_E)					
					end, delayAmnt/1000)
					return
				end
				
                local CastPos = eSpell.startPos
                local PlacementPos = eSpell.placementPos
                local Width = 100
                if eSpell.width > 0 then
                    Width = eSpell.width
                end
				if(CastPos and PlacementPos) then
					local VCastPos = Vector(CastPos.x, CastPos.y, CastPos.z)
					local VPlacementPos = Vector(PlacementPos.x, PlacementPos.y, PlacementPos.z)
				    local CastDirection = Vector((VCastPos - VPlacementPos):Normalized())
                    local PlacementPos2 = VCastPos - CastDirection * eSpell.range
					
					local point, isOnSegment = ClosestPointOnLineSegment(myHero.pos, VPlacementPos, VCastPos)
					if isOnSegment then
						local distCheck = GetDistance(myHero.pos, point)
						if distCheck < Width*2 + myHero.boundingRadius then
							DelayAction(function()
								Control.CastSpell(HK_E)					
							end, delayAmnt/1000)
							return
						end
					end
				end
			end
			
			--Check on allies
			if(self.Menu.AutoE.Allies:Value()) then
				for _, ally in ipairs(allies) do
					if(eSpell.target == ally.handle) then
						DelayAction(function()
							Control.CastSpell(HK_E, ally)					
						end, delayAmnt/1000)
						return
					end
				end
			end
		end
	end
end

function Annie:ManualSpells()
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

function Annie:AutoStack()
	if not (self.Menu.AutoStacks:Value()) then return end
	if not (Game.IsOnTop()) then return end
	if(IsInFountain()) then
		local enemiesNearby = GetEnemyCount(3000, myHero)
		if(enemiesNearby == 0) then
			local shouldCast = true

			if(self:HasStunBuff()) then
				shouldCast = false
			end
			
			if(myHero.mana / myHero.maxMana) >= 0.5 then
				--Use W and E to auto set up passive
				if(Ready(_W) and shouldCast) then
					Control.CastSpell(HK_W)
					return
				end
				
				if(Ready(_E) and shouldCast) then
					Control.CastSpell(HK_E)
					return
				end
			end
		end
	end
end

function Annie:AABlock()
	local mode = GetMode()
	local level = myHero.levelData.lvl
	
	if(mode == "LaneClear") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Flee") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Harass") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "LastHit") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Combo") then
		if (myHero.mana / myHero.maxMana) >= 0.05 and self.Menu.Combo.AABlock:Value() and Ready(_Q) then
			_G.SDK.Orbwalker:SetAttack(false)
		else
			_G.SDK.Orbwalker:SetAttack(true)
		end
	end
	
end

function Annie:IsKillable(unit)
	local isKillable = false
	local igniteOverkill = false
	local igniteDmg = 50 + (20 * myHero.levelData.lvl)
	
	if(comboDamageData[unit.name] ~= nil) then	
		local dmg = comboDamageData[unit.name]
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

function Annie:HasElectrocute(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count>0 and buff.name:lower():find("electrocute.lua") then
			return true
        end
    end
    return false
end

function Annie:GetTotalDamage(unit)
	local totalDmg = 0
	
	if(Ready(_Q)) then
		totalDmg = totalDmg + getdmg("Q", unit, myHero)
	end
	
	if(Ready(_W)) then
		totalDmg = totalDmg + getdmg("W", unit, myHero)
	end
	
	if(Ready(_R) and not self:HasTibbers()) then
		totalDmg = totalDmg + getdmg("R", unit, myHero)
		
		--[[
		local TibbersAA = ((myHero:GetSpellData(_R).level * 25) + 25) + 0.15 * myHero.ap
		local TibbersAOE = ((myHero:GetSpellData(_R).level * 20) + (0.12 * myHero.ap))
		local TibbersAAdmg = CalcMagicalDamage(myHero, unit, TibbersAA)
		local TibbersAOEdmg = CalcMagicalDamage(myHero, unit, TibbersAOE)
		--]]
	end
	
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
		local igniteDmg = 50 + (20 * myHero.levelData.lvl)
		totalDmg = totalDmg + igniteDmg
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
		local igniteDmg = 50 + (20 * myHero.levelData.lvl)
		totalDmg = totalDmg + igniteDmg
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
	
	local AAdmg = getdmg("AA", unit, myHero)
	
	totalDmg = totalDmg + AAdmg
	
	return totalDmg
end

function Annie:GetTotalComboDamage(unit)
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
	
	if(Ready(_R) and not self:HasTibbers()) then
		local RDmg = self:GetRawAbilityDamage("R")
		RDmg = CalcMagicalDamage(myHero, unit, RDmg)
		totalDmg = totalDmg + RDmg
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
	
	return totalDmg
end

function Annie:NinjaCombo()
	_G.SDK.Orbwalker:Orbwalk()
	local flashRange = 400
	local shouldNinja = false
	
	local canFlash = false
	
	--Flash Check
	if(self.Menu.Combo.NinjaCombo.UseFlash:Value()) then
		canFlash = CanFlash()
	end
	
	if(Ready(_R) and self:HasTibbers() == false and Ready(_Q) and Ready(_W)) then
		if(self.Menu.Combo.NinjaCombo.RequireStun:Value()) then
			if self:HasStunBuff() or (self:GetPassiveStacks() >= 3 and Ready(_E)) then
				shouldNinja = true
			end
		else
			shouldNinja = true
		end
	end
	
	local target = GetTarget(R.Range + flashRange + R.Radius + 1000)
	if(target and target.valid and IsValid(target)) then
	
		if(shouldNinja) then
			local RBuffer = 30
			local searchrange=(R.Range + R.Radius -RBuffer)
			if canFlash then
				searchrange=(R.Range + R.Radius +flashRange - RBuffer)
			end		

			local nearbyEnemies = GetEnemiesAtPos(searchrange, R.Radius*2 -RBuffer, target.pos, target)
			local bestPos, count = self:CalculateBestCirclePosition(nearbyEnemies, R.Radius-RBuffer, true)

			if(canFlash) then
				if(myHero.pos:DistanceTo(bestPos) < R.Range + flashRange -50) and (myHero.pos:DistanceTo(target.pos) > R.Range) then
					_G.SDK.Orbwalker:SetMovement(false)
					_G.Control.CastSpell(HK_E)
					_G.Control.CastSpell(HK_R, bestPos)
					UseFlash()
					_G.SDK.Orbwalker:SetMovement(true)
				end
			end
		
			if self:GetPassiveStacks() == 3 and Ready(_E) then
				Control.CastSpell(HK_E)
			end
			
			if(myHero.pos:DistanceTo(bestPos) < R.Range + RBuffer) and Ready(_R) then
				Control.CastSpell(HK_R, bestPos)
			end
			
		end
		
		if(self:HasTibbers()) then
			if(myHero.pos:DistanceTo(target.pos) < 600) then --Ignite range
				UseIgnite(target)
			end
			
			if(self.Menu.Combo.UseW:Value() and Ready(_W) and myHero.pos:DistanceTo(target.pos) < W.Range) then
				Control.CastSpell(HK_W, target)
			end
			
			if(self.Menu.Combo.UseQ:Value() and Ready(_Q) and myHero.pos:DistanceTo(target.pos) < Q.Range) then
				Control.CastSpell(HK_Q, target)
			end
		end
		
	end
	
	
end

function Annie:CantKill(unit, kill, ss, aa)
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

local alphaLerp = 0
function Annie:Draw()
	if myHero.dead then return end
	--self:DebugWallIntersection()

	if(self.Menu.Drawings.Debug.DrawUltClusters:Value()) then
		self:DebugCluster()
	end
	
	if(self.Menu.Drawings.DrawQW:Value()) then
		DrawCircle(myHero, Q.Range, 1, DrawColor(50, 80, 215, 255)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Combo.NinjaCombo.Key:Value() and self.Menu.Drawings.DrawNinjaComboStatus:Value()) then
		if(self:HasTibbers()) then return end
		DrawCircle(myHero, R.Range + R.Radius + 400, 1, DrawColor(20, 255, 255, 255)) --(Alpha, R, G, B)
		local heroPos = myHero.pos:To2D()
		
		if Ready(_R) and self:HasTibbers() == false and Ready(_Q) and Ready(_W) then
			if (self.Menu.Combo.NinjaCombo.RequireStun:Value()) then 
				if(self:HasStunBuff() or (self:GetPassiveStacks() ==3 and Ready(_E))) then
					DrawText("Ninja: [READY]", 18, heroPos + Vector(-35, 50, 0), DrawColor(255, 55, 250, 110))
				else
					DrawText("Ninja: [NOT READY]", 18, heroPos + Vector(-55, 50, 0), DrawColor(255, 255, 100, 120))
				end
			else
				DrawText("Ninja: [READY]", 18, heroPos + Vector(-35, 50, 0), DrawColor(255, 55, 250, 110))
			end
		else
			DrawText("Ninja: [NOT READY]", 18, heroPos + Vector(-55, 50, 0), DrawColor(255, 255, 100, 120))
		end
	end
	
	if(self.Menu.Drawings.DrawKillable:Value()) then
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
end

function Annie:DrawDamageHPBars()
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

function Annie:DrawKillable()
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

function Annie:DrawKillReticle(unit)
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

require "MapPositionGOS"

function Annie:DebugWallIntersection()
	local p1 = myHero.pos:To2D()
	local p2 = Game.cursorPos()
	local mousePos = Game.mousePos()
	DrawLine(p1, p2, 1)

	if(MapPosition:intersectsWall(myHero.pos, mousePos)) then
		DrawCircle(mousePos, 50, 1, DrawColor(255, 255, 0, 0))

		local point = (MapPosition:getIntersectionPoint3D(myHero.pos, mousePos))
		if(point) then
			DrawCircle(point, 50, 1, DrawColor(255, 0, 255, 0))
		end
	else
		DrawCircle(mousePos, 50, 1)
	end
end

Annie()
LoadUnits()
