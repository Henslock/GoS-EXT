require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.03

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Ezreal will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Ezreal"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/ezreal.png"

local gameTick = GameTimer()

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 1100, Radius = 60, Speed = 1950}
local W = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 1100, Radius = 80, Speed = 1600}
local R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1, Range = 20000, Radius = 160, Speed = 2000}

--Main Menu
Ezreal.Menu = MenuElement({type = MENU, id = "KillerEzreal", name = "Killer Ezreal", leftIcon=ChampIcon})
Ezreal.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

Ezreal.WTarget = {}

Ezreal.lastEFake = 0
Ezreal.ECTLRBuffer = 0
Ezreal.RShootBuffer = 0
Ezreal.LastChatOpenTimer = 0

function Ezreal:__init()
	self:LoadMenu()

	table.insert(_G.SDK.OnTick, function()
		if not _G.SDK.IsRecalling(myHero) then
			self:Tick()
		end
	end)

	table.insert(_G.SDK.OnDraw, function()
		self:Draw()
	end)

	_G.SDK.Orbwalker:OnPreAttack(function(...) Ezreal:OnPreAttack(...) end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) Ezreal:OnPostAttack(...) end)

	table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
		self:OnWndMsg(msg, wParam)
	end)

	self:UpdateGoSMenuAutoLevel()
end

function Ezreal:LoadMenu()                  	
	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseQObstructing", name = "Use Q on Minion in the Way if Low CD", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "W Mode", value = 2, drop = {"Disabled", "Combo", "Require Toggle"}})
	self.Menu.Combo:MenuElement({id = "ToggleW", name = "Toggle W Key", key = 20, toggle = true})

	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})

	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseQCanon", name = "Use Q on Cannon", value = true})
	self.Menu.LastHit:MenuElement({id = "UseQRange", name = "Use Q to Hit Out of Range", value = true})
	self.Menu.LastHit:MenuElement({id = "UseQTower", name = "Use Q to Kill Under Tower", value = true})
	self.Menu.LastHit:MenuElement({id = "UseQLastHit", name = "Use Q to Last Hit in AA Range", value = true})
	self.Menu.LastHit:MenuElement({id = "MinimumManaQ", name = "Minimum Mana to Q", value = 20, min = 0, max = 100, step = 5, identifier = "%"})

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "Lane", name = "Lane", type = MENU})
	self.Menu.Clear:MenuElement({id = "Jungle", name = "Jungle", type = MENU})
	self.Menu.Clear:MenuElement({id = "UseWTower", name = "Use W on Tower", value = true})

	-- Lane Clear
	self.Menu.Clear.Lane:MenuElement({id = "UseQCanon", name = "Use Q on Cannon", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "UseQClear", name = "Use Q to Clear", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "SpamQSupers", name = "Spam Q on Super Minions", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "ManaConservation", name = "Early-Game Mana Conservation", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "MinimumManaQ", name = "Minimum Mana to Q", value = 25, min = 0, max = 100, step = 5, identifier = "%"})

	-- Jungle Clear
	self.Menu.Clear.Jungle:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "UseW", name = "Use W on Epic Monsters", value = true})

	-- Killsteal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true})

	-- E
	self.Menu:MenuElement({id = "ESettings", name = "E Settings", type = MENU})
	self.Menu.ESettings:MenuElement({id = "EKey", name = "E Fake Key", key = string.byte("A")})
	self.Menu.ESettings:MenuElement({id = "SemiManualE", name = "Semi-manual E", value = true})

	-- Auto Q 
	self.Menu:MenuElement({id = "AutoQ", name = "Auto Q Settings", type = MENU})
	self.Menu.AutoQ:MenuElement({id = "AutoQImmobile", name = "Auto Q Immobile", value = true})
	self.Menu.AutoQ:MenuElement({id = "AutoQHigh", name = "Auto Q High Hitchance", value = true})
	self.Menu.AutoQ:MenuElement({id = "AutoQBushCheck", name = "Dont Auto Q in Bushes", value = true})
	self.Menu.AutoQ:MenuElement({id = "AutoQToggle", name = "Auto Q Toggle", key = string.byte("C"), toggle = true})
	self.Menu.AutoQ:MenuElement({id = "MinimumManaQ", name = "Minimum Mana to Auto Q", value = 35, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.AutoQ:MenuElement({id = "MinimumHPQ", name = "Minimum HP to Auto Q", value = 50, min = 0, max = 100, step = 5, identifier = "%"})

	-- R settings
	self.Menu:MenuElement({id = "RSettings", name = "R Settings", type = MENU})
	self.Menu.RSettings:MenuElement({id = "UseType", name = "Use Type", value = 2, drop = {"None", "Combo", "Auto"}})
	self.Menu.RSettings:MenuElement({name = "============", type = SPACE})
	self.Menu.RSettings:MenuElement({id = "DontUse", name = "Dont Use if Enemies in X Range", value = 800, min = 0, max = 1200, step = 5})
	self.Menu.RSettings:MenuElement({id = "EnemyCountCheck", name = "Use if it hits at least X enemies", value = 3, min = 1, max = 5, step = 1})
	self.Menu.RSettings:MenuElement({id = "TimeToHit", name = "Use When Time to Hit is < X (sec)", value = 3, min = 0, max = 10, step = 0.5})
	self.Menu.RSettings:MenuElement({id = "Killsteal", name = "Use if 1 Target will Die", value = true})
	self.Menu.RSettings:MenuElement({name = "============", type = SPACE})
	self.Menu.RSettings:MenuElement({id = "RSM", name = "R Semi-Manual", type = MENU})

	-- R Semi-Manual
	self.Menu.RSettings.RSM:MenuElement({id = "Key", name = "Semi-Manual Key", key = string.byte("Z")})
	self.Menu.RSettings.RSM:MenuElement({id = "EnemyCountCheck", name = "Use if it hits at least X enemies", value = 1, min = 1, max = 5, step = 1})
	self.Menu.RSettings.RSM:MenuElement({id = "TimeToHit", name = "Use When Time to Hit is < X (sec)", value = 3, min = 0, max = 10, step = 0.5})
	self.Menu.RSettings.RSM:MenuElement({id = "RequireOnScreen", name = "Require on Screen", value = true})

	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q & W Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawAutoQ", name = "Draw Auto Q Status", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawWToggle", name = "Draw W Toggle Status", value = true})

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

function Ezreal:UpdateGoSMenuAutoLevel()
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

function Ezreal:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Ezreal:Tick()

	if Game.IsChatOpen() then
		self.LastChatOpenTimer = os.clock()
	end

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

	self:ELogic()
	self:KillSteal()
	self:FlushWTarget()
	self:RLogic()

	if(self.Menu.AutoQ.AutoQToggle:Value()) then
		if(self.Menu.AutoQ.AutoQImmobile:Value()) then
			self:AutoQImmobile()
		end

		if(self.Menu.AutoQ.AutoQHigh:Value()) then
			self:AutoQHighHitchance()
		end
	end

	if(self.Menu.RSettings.RSM.Key:Value()) then
		self:SemiRLogic()
	end

	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end

function Ezreal:OnPreAttack(args)
    if GetMode() == "Combo" then
		local enemies = GetEnemyHeroes(_G.SDK.Data:GetAutoAttackRange(myHero))
		if(#enemies >= 2) then
			local wTar = self:GetWTarget(enemies)
			if (IsValid(wTar)) then
				args.Target = wTar
			end
		end
    end
end

function Ezreal:OnPostAttack(args)
    if GetMode() == "Combo" then
		if(Ready(_W)) then
			local canCast = false
	
			if(self.Menu.Combo.UseW:Value() == 2) then
				canCast = true
			end
	
			if(self.Menu.Combo.UseW:Value() == 3) and self.Menu.Combo.ToggleW:Value() then
				canCast = true
			end
	
			if(canCast) then
				local tar = GetTarget(W.Range)
				if(IsValid(tar)) then
					CastPredictedSpell({Hotkey = HK_W, Target = tar, SpellData = W})
					self.WTarget = {hero = tar, time = GameTimer() + 0.75}
				end
			end
		end
	
		if(self.Menu.Combo.UseQ:Value() and Ready(_Q)) then
			local tar = GetTarget(Q.Range)
			local wTars = GetEnemyHeroes(Q.Range)
	
			if(#wTars > 1) then
				local wTar = self:GetWTarget(wTars)
	
				if(wTar) then
					tar = wTar
				end
			end
	
			if(IsValid(tar)) then
	
				local shouldCastNormal = true
				local dist = GetDistance(myHero, tar)
				if(self.Menu.Combo.UseQObstructing:Value()) then
					if(myHero.levelData.lvl >= 11 and myHero:GetSpellData(_Q).cd < 2.5) then
						shouldCastNormal = false
					end
				end
	
				if(shouldCastNormal) then
					local check = CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, maxCollision = 1, GGPred = true, KillerPred = true})
					local qDmg = self:GetRawAbilityDamage("Q")
					qDmg = CalcPhysicalDamage(myHero, tar, qDmg)
					if(tar.health - qDmg < 0) and check then
						self.RShootBuffer = GameTimer() + Q.Delay + (dist/Q.Speed)
					end
				else
					local check = CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, maxCollision = 2, GGPred = true, KillerPred = true})
					local qDmg = self:GetRawAbilityDamage("Q")
					qDmg = CalcPhysicalDamage(myHero, tar, qDmg)
					if(tar.health - qDmg < 0) and check then
						self.RShootBuffer = GameTimer() + Q.Delay + (dist/Q.Speed)
					end			
				end
			end
		end
    end
end
function Ezreal:OnWndMsg(msg, wParam)
	if wParam == self.Menu.ESettings.EKey:Key() then
		self.lastEFake = os.clock()
	end

	if wParam == HK_LUS then
		self.ECTLRBuffer = GetTickCount()
	end
end

function Ezreal:FlushWTarget()
	if(self.WTarget.hero) then
		if not IsValid(self.WTarget.hero) then
			self.WTarget = {}
			return
		end

		if(self.WTarget.time >= GameTimer()) then
			self.WTarget = {}
			return
		end
	end
end

function Ezreal:Combo()
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(Ready(_W)) then
		local canCast = false

		if(self.Menu.Combo.UseW:Value() == 2) then
			canCast = true
		end

		if(self.Menu.Combo.UseW:Value() == 3) and self.Menu.Combo.ToggleW:Value() then
			canCast = true
		end

		if(canCast) then
			local tar = GetTarget(W.Range)
			if(IsValid(tar)) then
				if(GetDistance(myHero, tar) > _G.SDK.Data:GetAutoAttackRange(myHero, tar)) then
					local check = CastPredictedSpell({Hotkey = HK_W, Target = tar, SpellData = W, maxCollision = 1, collisionRadiusOverride = Q.Radius, GGPred = true, KillerPred = false})
					if(check) then
						self.WTarget = {hero = tar, time = GameTimer() + 0.75}
					end
				end
			end
		end
	end

	if(self.Menu.Combo.UseQ:Value() and Ready(_Q)) then
		local tar = GetTarget(Q.Range)
		local wTars = GetEnemyHeroes(Q.Range)

		if(#wTars > 1) then
			local wTar = self:GetWTarget(wTars)

			if(wTar) then
				tar = wTar
			end
		end

		if(IsValid(tar)) then
			if(GetDistance(myHero, tar) > _G.SDK.Data:GetAutoAttackRange(myHero, tar)) then
				local shouldCastNormal = true
				local dist = GetDistance(myHero, tar)
				if(self.Menu.Combo.UseQObstructing:Value()) then
					if(myHero.levelData.lvl >= 11 and myHero:GetSpellData(_Q).cd < 2.5) then
						shouldCastNormal = false
					end
				end

				if(shouldCastNormal) then
					local check = CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, maxCollision = 1, GGPred = true, KillerPred = false})
					local qDmg = self:GetRawAbilityDamage("Q")
					qDmg = CalcPhysicalDamage(myHero, tar, qDmg)
					if(tar.health - qDmg < 0) and check then
						self.RShootBuffer = GameTimer() + Q.Delay + (dist/Q.Speed)
					end
				else
					local check = CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, maxCollision = 2, GGPred = true, KillerPred = false})
					local qDmg = self:GetRawAbilityDamage("Q")
					qDmg = CalcPhysicalDamage(myHero, tar, qDmg)
					if(tar.health - qDmg < 0) and check then
						self.RShootBuffer = GameTimer() + Q.Delay + (dist/Q.Speed)
					end			
				end
			end
		end
	end
end
function Ezreal:Harass()
	if(gameTick > GameTimer()) then return end	
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.Harass.UseQ:Value() and Ready(_Q)) then
		local tar = GetTarget(Q.Range)
		local wTars = GetEnemyHeroes(Q.Range)

		if(#wTars > 1) then
			local wTar = self:GetWTarget(wTars)
			if(wTar) then
				tar = wTar
			end
		end

		if(IsValid(tar)) then
			CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, maxCollision = 1})
		end
	end

end

function Ezreal:AngleQPos(minion1, minion2, radius)
	local dirVec = (minion1.pos - minion2.pos):Normalized()
	local newPos = minion1.pos + (dirVec * radius)
	
	return newPos
end

local avoidQMinionHandle = 0
function Ezreal:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(myHero.mana / myHero.maxMana < self.Menu.LastHit.MinimumManaQ:Value() / 100) then
		return
	end

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
	local avoidQMinion
	if(myHero.activeSpell.isAutoAttack) then
		avoidQMinionHandle = myHero.activeSpell.target
	end

	if(self.Menu.LastHit.UseQCanon:Value() and Ready(_Q)) then
		local canonMinion = GetCanonMinion(minions)
		
		if(canonMinion ~= nil) and IsValid(canonMinion) then

			local check = true
			if(avoidQMinionHandle == canonMinion.handle) then
				if(canonMinion.health - myHero.totalDamage < 0) then
					check = false
				end

				local lhTar = _G.SDK.HealthPrediction:GetLastHitTarget()
				if(lhTar and lhTar.handle == canonMinion.handle) then
					check = false
				end
			end

			if(check) then
				local QDam = self:GetRawAbilityDamage("Q")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (myHero.pos:DistanceTo(canonMinion.pos)/2000))
				
				if ((hp > 0) and (canonMinion.health - QDam <= 0)) then
					Control.CastSpell(HK_Q, canonMinion)
					return
				end
			end
		end
	end

	if(self.Menu.LastHit.UseQLastHit:Value() and Ready(_Q)) then
		local canLastHit = myHero.levelData.lvl >= 6 or self:HasManaItem() or (myHero.mana/myHero.maxMana >= 0.5)
		if(canLastHit) then
			for _, minion in pairs(minions) do
				if(minion and IsValid(minion)) then

					local check = true
					if(avoidQMinionHandle == minion.handle) then
						if(minion.health - myHero.totalDamage < 0) then
							check = false
						end
		
						local lhTar = _G.SDK.HealthPrediction:GetLastHitTarget()
						if(lhTar and lhTar.handle == minion.handle) then
							check = false
						end
					end

					if(GetDistance(myHero, minion) <= _G.SDK.Data:GetAutoAttackRange(myHero) and check) then
						local hp = _G.SDK.HealthPrediction:GetPrediction(minion, (GetDistance(myHero, minion)/2000))
						if(minion.health - self:GetRawAbilityDamage("Q") < 0 and hp > 0) then
							local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION},  minion.networkID)
							if(collisionCount == 0) then
								Control.CastSpell(HK_Q, minion)
								return
							end

							if(collisionCount == 1) then
								local frontCheck = (self:IsUnitInFront(minion, collisionObjects[1]) > -0.5)
								if (GetDistance(collisionObjects[1], minion) <= Q.Radius + minion.boundingRadius) and frontCheck then
									local castPos = self:AngleQPos(minion, collisionObjects[1], Q.Radius*0.85)
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

	if(self.Menu.LastHit.UseQRange:Value() and Ready(_Q)) then
		for _, minion in pairs(minions) do
			if(minion and IsValid(minion)) then
				if(GetDistance(myHero, minion) <= Q.Range and GetDistance(myHero, minion) >= _G.SDK.Data:GetAutoAttackRange(myHero) + 75) then
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, (GetDistance(myHero, minion)/2000))
					if(minion.health - self:GetRawAbilityDamage("Q") < 0 and hp > 0) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION},  minion.networkID)
						if(collisionCount == 0) then
							Control.CastSpell(HK_Q, minion)
							return
						end

						if(collisionCount == 1) then
							if (GetDistance(collisionObjects[1], minion) <= Q.Radius + minion.boundingRadius) then
								local castPos = self:AngleQPos(minion, collisionObjects[1], Q.Radius*0.75)
								Control.CastSpell(HK_Q, castPos)
								return
							end
						end
					end
				end
			end
		end
	end

	if(self.Menu.LastHit.UseQTower:Value() and Ready(_Q)) then
		for _, minion in pairs(minions) do
			if(minion and IsValid(minion)) then
				if(GetDistance(myHero, minion) <= Q.Range and IsUnderFriendlyTurret(minion)) then
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, (GetDistance(myHero, minion)/2000))
					if(minion.health - self:GetRawAbilityDamage("Q") < 0 and hp > 0) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION},  minion.networkID)
						if(collisionCount == 0) then
							Control.CastSpell(HK_Q, minion)
							return
						end

						if(collisionCount == 1) then
							if (GetDistance(collisionObjects[1], minion) <= Q.Radius + minion.boundingRadius) then
								local castPos = self:AngleQPos(minion, collisionObjects[1], Q.Radius*0.75)
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

function Ezreal:Clear()
	if(gameTick > GameTimer()) then return end	
	if not (IsValid(myHero)) or myHero.isChanneling then return end

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

	if(self.Menu.Clear.UseWTower:Value()) then
		if(Ready(_W)) then
			local t = GetClosestEnemyTurret()
			if(IsValid(t)) then
				if(GetDistance(myHero.pos, t.pos) < _G.SDK.Data:GetAutoAttackRange(myHero)) then
					Control.CastSpell(HK_W, t.pos)
				end
			end
		end
	end
end

local jungleWMonsters = 
{
	["SRU_Baron"]= 1,
	["SRU_RiftHerald"]= 1,
	["SRU_Dragon_Elder"]= 1,
	["SRU_Dragon_Water"]= 1,
	["SRU_Dragon_Fire"]= 1,
	["SRU_Dragon_Earth"]= 1,
	["SRU_Dragon_Air"]= 1,
	["SRU_Dragon_Ruined"]= 1,
	["SRU_Dragon_Chemtech"]= 1,
	["SRU_Dragon_Hextech"]= 1
}

function Ezreal:JungleClear(minions)
	if(self.Menu.Clear.Jungle.UseQ:Value() and Ready(_Q)) then
		for _, minion in pairs(minions) do
			if(GetDistance(myHero, minion) <= 800) then
				local qPred = GGPrediction:SpellPrediction(Q)
				qPred:GetPrediction(minion, myHero)
				if qPred.CastPosition and qPred:CanHit(HITCHANCE_NORMAL) then
					Control.CastSpell(HK_Q, qPred.CastPosition)
					break
				end	
			end
		end
	end

	if(self.Menu.Clear.Jungle.UseW:Value() and Ready(_W)) then
		for _, minion in pairs(minions) do
			if(GetDistance(myHero, minion) <= 800) and jungleWMonsters[minion.charName]==1 then
				local wPred = GGPrediction:SpellPrediction(W)
				wPred:GetPrediction(minion, myHero)
				if wPred.CastPosition and wPred:CanHit(HITCHANCE_NORMAL) then
					Control.CastSpell(HK_W, wPred.CastPosition)
					break
				end	
			end
		end
	end
end

function Ezreal:LaneClear(minions)
	local earlyManaConservationCheck = false -- Will turn into TRUE if we need to conserve mana.

	if(myHero.mana / myHero.maxMana < self.Menu.Clear.Lane.MinimumManaQ:Value() / 100) then
		return
	end

	if(myHero.activeSpell.isAutoAttack) then
		avoidQMinionHandle = myHero.activeSpell.target
	end

	if(self.Menu.Clear.Lane.ManaConservation:Value()) then
		--[[
			Early-game Mana Conservation:
			Ezreal has mana issues early game until he gets rolling with items, so I minimize the amount he should use his Q in farming.
			Typically after a certain level, its fine to start using Q a lot more.
			It's also fine to start using Q once we have a mana item like tear.
			We also will want to use Q to clear minions that we can't reach under the enemy tower.
		]]
		if(self:HasManaItem() == false) then
			earlyManaConservationCheck = true
		end

		if(myHero.levelData.lvl >= 6) then
			earlyManaConservationCheck = false
		end
	end

	if(self.Menu.Clear.Lane.UseQCanon:Value() and Ready(_Q)) then
		local canonMinion = GetCanonMinion(minions)
		--Prioritize the canon minion if its low
		if(canonMinion and IsValid(canonMinion)) then
			
			local QDam = self:GetRawAbilityDamage("Q")
			local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, (GetDistance(myHero, canonMinion)/2000))
			if(canonMinion.health - self:GetRawAbilityDamage("Q") < 0 and hp > 0) then
				local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, canonMinion.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION},  canonMinion.networkID)
				if(collisionCount == 0) then
					if _G.SDK.Cursor.Step == 0 then
						Control.CastSpell(HK_Q, canonMinion)
						return
					end
				end
			end
		end
	end

	if(self.Menu.Clear.Lane.UseQClear:Value() and Ready(_Q)) then
		for _, minion in pairs(minions) do

			--This is to prevent us Q'ing a target we are going to kill with an AA 
			local check = true
			if(avoidQMinionHandle == minion.handle) then
				local hp = _G.SDK.HealthPrediction:GetPrediction(minion, (GetDistance(myHero, minion)/myHero.attackData.projectileSpeed))
				if(hp - (myHero.totalDamage) < 0) then
					check = false
				end
			end

			if(GetDistance(myHero, minion) <= (Q.Range - 50) and check) then
				local hp = _G.SDK.HealthPrediction:GetPrediction(minion, (GetDistance(myHero, minion)/2000))
				if(minion.health - self:GetRawAbilityDamage("Q") < 0 and hp > 0) then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION},  minion.networkID)
					if(collisionCount == 0) then

						--Check if its under a tower:
						if(IsUnderTurret(minion) or IsUnderFriendlyTurret(minion)) then
							if _G.SDK.Cursor.Step == 0 then
								Control.CastSpell(HK_Q, minion)
								return
							end
						else
							if not earlyManaConservationCheck then
								if _G.SDK.Cursor.Step == 0 then
									Control.CastSpell(HK_Q, minion)
									return
								end
							end
						end
					end

					if(collisionCount == 1) then
						local frontCheck = (self:IsUnitInFront(minion, collisionObjects[1]) > -0.5)
						if (GetDistance(collisionObjects[1], minion) <= Q.Radius + minion.boundingRadius) and frontCheck then
							local castPos = self:AngleQPos(minion, collisionObjects[1], Q.Radius*0.75)
							--Check if its under a tower:
							if(IsUnderTurret(minion) or IsUnderFriendlyTurret(minion)) then
								if _G.SDK.Cursor.Step == 0 then
									Control.CastSpell(HK_Q, castPos)
									return
								end
							else
								if not earlyManaConservationCheck then
									if _G.SDK.Cursor.Step == 0 then
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
	end

	if(self.Menu.Clear.Lane.SpamQSupers:Value() and Ready(_Q)) then
		for _, minion in pairs(minions) do
			if(GetDistance(myHero, minion) <= (Q.Range - 50)) then
				if(minion.charName == "SRU_ChaosMinionSuper" or minion.charName == "SRU_OrderMinionSuper" or minion.charName == "HA_ChaosMinionSuper" or minion.charName == "HA_OrderMinionSuper") then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION},  minion.networkID)
					if(collisionCount == 0) then
						--Check if its under a tower:
						if(IsUnderTurret(minion) or IsUnderFriendlyTurret(minion)) then
							if _G.SDK.Cursor.Step == 0 then
								Control.CastSpell(HK_Q, minion)
								return
							end
						else
							if not earlyManaConservationCheck then
								if _G.SDK.Cursor.Step == 0 then
									Control.CastSpell(HK_Q, minion)
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

Ezreal.ShouldUseE = false
function Ezreal:ELogic()
	local timer = GetTickCount()
	if self.LastE and timer < self.LastE + 1000 then
		return
	end
	if timer < self.LastChatOpenTimer + 1000 then
		return
	end

	if timer <= self.ECTLRBuffer + 1000 then
		return
	end

	if(self.Menu.ESettings.SemiManualE:Value() and Ready(_E)) then
		if _G.SDK.Cursor.Step == 0 and self.ShouldUseE and not myHero.isChanneling then

			if
			(
				not Control.IsKeyDown(HK_LUS)
				and not Game.IsChatOpen()
				and Game.IsOnTop()
			)
			then
				Control.CastSpell(HK_E, myHero.pos:Extended((Game.mousePos()), 600))
			else
				self.ShouldUseE = false
			end
		end

		if(Control.IsKeyDown(HK_E)) then
			if self.ShouldUseE == false then
				self.ShouldUseE = true
			end
		end
	else
		self.ShouldUseE = false
	end

	if self.EHelper ~= nil then
		if _G.SDK.Cursor.Step == 0 then
			_G.SDK.Cursor:Add(self.EHelper, myHero.pos:Extended(Vector(Game.mousePos()), 600))
			self.EHelper = nil
		end

		return
	end
	if
		not (
			os.clock() < self.lastEFake + 0.5
			and Ready(_E)
			and not Control.IsKeyDown(HK_LUS)
			and not myHero.dead
			and not Game.IsChatOpen()
			and Game.IsOnTop()
		)
	then
		return
	end

	self.LastE = timer
	if _G.SDK.Cursor.Step == 0 then
		_G.SDK.Cursor:Add(HK_E, myHero.pos:Extended(Vector(Game.mousePos()), 600))
		return
	end
	
	self.EHelper = HK_E
end

function Ezreal:RLogic()

	if not Ready(_R) then return end
	if(myHero.isChanneling or myHero.dead) then return end

	local modeType = self.Menu.RSettings.UseType:Value()
	local comboCheck = false

	if(modeType == 1) then --Disabled
		return
	end

	if(modeType == 2) then --Disabled
		if(GetMode() == "Combo") then
			comboCheck = true
		end
	end

	if(modeType == 3 or comboCheck) then
		-- R Logic.
		local RMaxTime = self.Menu.RSettings.TimeToHit:Value() - Q.Delay
		local searchRange = Q.Speed * RMaxTime

		local AAEnemies = GetEnemyHeroes(self.Menu.RSettings.DontUse:Value())
		if(#AAEnemies > 0) then
			return
		end
		
		local enemies = GetEnemyHeroes(searchRange)
		if(#enemies >= self.Menu.RSettings.EnemyCountCheck:Value()) then
			local bestPos, count = CalculateBestLinePosition(enemies, R.Radius, R.Range, R.Speed, R.Delay)
			if(count >= self.Menu.RSettings.EnemyCountCheck:Value()) then
				if _G.SDK.Cursor.Step == 0 then
					local distances = {700, 500, 300}
					for _, distance in ipairs(distances) do
						local extendedPosition = myHero.pos:Extended(bestPos, distance)
						if extendedPosition:ToScreen().onScreen then
							Control.CastSpell(HK_R, extendedPosition)      
							return 
						end
					end
				end
			end
		end

		if(self.Menu.RSettings.Killsteal:Value() and not Ready(_Q)) then
			for _, enemy in pairs(enemies) do
				if(IsValid(enemy) and Vector(enemy.pos):To2D().onScreen) then
					local RDmg = self:GetRawAbilityDamage("R")
					RDmg = CalcMagicalDamage(myHero, enemy, RDmg)
					if(enemy.health - RDmg < 0) and (GameTimer() > self.RShootBuffer) then
						if _G.SDK.Cursor.Step == 0 then
							CastPredictedSpell({Hotkey = HK_R, Target = enemy, SpellData = R, GGPred = true, KillerPred = false})
						end
					end
				end
			end
		end
	end
end

function Ezreal:SemiRLogic()
	if not Ready(_R) then return end
	if(myHero.isChanneling or myHero.dead) then return end

	-- R Logic.
	local RMaxTime = self.Menu.RSettings.RSM.TimeToHit:Value() - Q.Delay
	local searchRange = Q.Speed * RMaxTime

	local tar = GetTarget(searchRange)
	if(IsValid(tar) and tar == _G.SDK.TargetSelector.Selected) then
		if _G.SDK.Cursor.Step == 0 then
			CastPredictedSpell({Hotkey = HK_R, Target = tar, SpellData = R, GGPred = true, KillerPred = false})
		end
	end
	
	local enemies = GetEnemyHeroes(searchRange)
	if(self.Menu.RSettings.RSM.RequireOnScreen:Value()) then
		local onScreenEnemies = {}
		for _, enemy in ipairs(enemies) do
			if enemy.pos:To2D().onScreen then
				table.insert(onScreenEnemies, enemy)
			end
		end

		enemies = onScreenEnemies
	end

	if(#enemies >= self.Menu.RSettings.RSM.EnemyCountCheck:Value()) then
		local bestPos, count = CalculateBestLinePosition(enemies, R.Radius, R.Range, R.Speed, R.Delay)
		if(count >= self.Menu.RSettings.RSM.EnemyCountCheck:Value()) then
			if _G.SDK.Cursor.Step == 0 then
				local distances = {700, 500, 300}
				for _, distance in ipairs(distances) do
					local extendedPosition = myHero.pos:Extended(bestPos, distance)
					if extendedPosition:ToScreen().onScreen then
						Control.CastSpell(HK_R, extendedPosition)      
						return 
					end
				end
			end
		end
	end

end

function Ezreal:AutoQImmobile()

	if not Ready(_Q) then return end
	if(myHero.isChanneling or myHero.dead) then return end
	
	if(myHero.mana / myHero.maxMana < self.Menu.AutoQ.MinimumManaQ:Value() / 100) then
		return
	end

	if(myHero.health / myHero.maxHealth < self.Menu.AutoQ.MinimumHPQ:Value() / 100) then
		return
	end

	if(self.Menu.AutoQ.AutoQBushCheck:Value()) then
		if(MapPosition:inBush(myHero.pos)) then
			return
		end
	end

	if(Ready(_Q)) then
		local target = GetTarget(Q.Range)
		if(IsValid(target)) then			
			if(IsImmobile(target) >= 1.0) then
				local didCast = CastPredictedSpell({Hotkey = HK_Q, Target = target, SpellData = Q, maxCollision = 1})
				if(didCast) then
					self.RShootBuffer = GameTimer() + Q.Delay + (GetDistance(myHero, target)/Q.Speed)
				end
			end
		end
	end
end

function Ezreal:AutoQHighHitchance()

	if not Ready(_Q) then return end
	if(myHero.isChanneling or myHero.dead) then return end

	if(myHero.mana / myHero.maxMana < self.Menu.AutoQ.MinimumManaQ:Value() / 100) then
		return
	end

	if(myHero.health / myHero.maxHealth < self.Menu.AutoQ.MinimumHPQ:Value() / 100) then
		return
	end

	if(self.Menu.AutoQ.AutoQBushCheck:Value()) then
		if(MapPosition:inBush(myHero.pos)) then
			return
		end
	end

	if(Ready(_Q) and not IsUnderTurret(myHero)) then
		local target = GetTarget(Q.Range)
		if(IsValid(target)) then
			
			if(GetMode() == "Combo" and GetDistance(myHero, target) <= _G.SDK.Data:GetAutoAttackRange(myHero, target)) then
				return
			end
			
			local didCast = CastPredictedSpell({Hotkey = HK_Q, Target = target, SpellData = Q, maxCollision = 1, KillerPred = false, GGPred = true})
			if(didCast) then
				self.RShootBuffer = GameTimer() + Q.Delay + (GetDistance(myHero, target)/Q.Speed)
			end
		end
	end
end

function Ezreal:IsUnitInFront(unit1, unit2)
	local meVec = (myHero.pos - unit1.pos):Normalized()
	local u2Vec = (unit1.pos - unit2.pos):Normalized()
	local res = dotProduct3D(meVec, u2Vec)
	return (res)
end

function Ezreal:KillSteal()
	--Q
	if(self.Menu.KillSteal.UseQ:Value()) then
		if(Ready(_Q)) then
			local enemies = GetEnemyHeroes(Q.Range)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy)) then
						if((CantKill(enemy, true, true, false)==false)) then
							local QDmg = self:GetRawAbilityDamage("Q")
							QDmg = CalcPhysicalDamage(myHero, enemy, QDmg)
							if(enemy.health - QDmg < 0) then
								local didCast = CastPredictedSpell({Hotkey = HK_Q, Target = enemy, SpellData = Q, maxCollision = 1, KillerPred = false, GGPred = true, UseHeroCollision = true})
								if(didCast) then
									self.RShootBuffer = GameTimer() + Q.Delay + (GetDistance(myHero, enemy)/Q.Speed)
								end
							end
						end
					end
				end
			end
		end
	end

end

function Ezreal:GetWTarget(enemies)
	for _, enemy in pairs(enemies) do
		if(HasBuff(enemy, "ezrealwattach") and IsValid(enemy)) then
			return enemy
		end
	end

	return nil
end

function Ezreal:HasManaItem()
	return HasItem({Item.TearoftheGoddess, Item.SeraphsEmbrace, Item.Muramana, Item.Manamune, Item.ArchangelsStaff})
end

function Ezreal:GetSpellbladeDamage()
	local hasItem, slot = HasItem({Item.Sheen, Item.TrinityForce, Item.InfinityForce, Item.EssenceReaver})
	if(hasItem) then
		return GetItemDamage(myHero:GetItemData(slot).itemID)
	end

	return 0
end

function Ezreal:GetRawAbilityDamage(spell, tar)
	if(spell == "Q") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		return ({20, 45, 70, 95, 120})[myHero:GetSpellData(_Q).level] + (1.30 * myHero.totalDamage) + (0.15 * myHero.ap) + self:GetSpellbladeDamage()
	end

	if(spell == "W") then
		if myHero:GetSpellData(_W).level == 0 then return 0 end
		local bonusAPScaling = ({0.7, 0.75, 0.8, 0.85, 0.9})[myHero:GetSpellData(_W).level]
		return ({80, 135, 190, 245, 300})[myHero:GetSpellData(_W).level] + (0.6 * myHero.totalDamage) + (bonusAPScaling * myHero.ap)
	end

	if(spell == "E") then
		if myHero:GetSpellData(_E).level == 0 then return 0 end
		return ({80, 130, 180, 230, 280})[myHero:GetSpellData(_E).level] + (0.5 * myHero.totalDamage) + (0.75 * myHero.ap)
	end
	
	if(spell == "R") then
		if myHero:GetSpellData(_R).level == 0 then return 0 end
		return ({350, 500, 650})[myHero:GetSpellData(_R).level] + (0.5 * myHero.totalDamage) + (0.45 * myHero.ap)
	end

	return 0
end


-- [[ DRAWINGS ]] --

function Ezreal:Draw()
	if myHero.dead then return end

	if(self.Menu.Drawings.DrawQ:Value()) then
		DrawCircle(myHero, Q.Range, 1, DrawColor(155, 39, 180, 227)) --(Alpha, R, G, B)
	end

	if(self.Menu.Drawings.DrawAutoQ:Value()) then
		local fontSize = 24
		local pos = {x = myHero.pos:To2D().x - fontSize - 35, y = myHero.pos:To2D().y + 45}
		if(self.Menu.AutoQ.AutoQToggle:Value()) then
			DrawText("Auto Q Enabled", fontSize, Vector(pos), DrawColor(255, 80, 255, 80))
		else
			DrawText("Auto Q Disabled", fontSize, Vector(pos), DrawColor(155, 255, 80, 80))
		end
	end

	if(self.Menu.Drawings.DrawWToggle:Value()) then
		if(self.Menu.Combo.UseW:Value() == 3) and self.Menu.Combo.ToggleW:Value() then
			local fontSize = 20
			local pos = {x = myHero.pos:To2D().x - fontSize - 5, y = myHero.pos:To2D().y + 75}
			if(self.Menu.Combo.ToggleW:Value()) then
				DrawText("W Enabled", fontSize, Vector(pos), DrawColor(255, 80, 255, 80))
			else
				DrawText("W Disabled", fontSize, Vector(pos), DrawColor(155, 255, 80, 80))
			end
		else
			local fontSize = 20
			local pos = {x = myHero.pos:To2D().x - fontSize - 45, y = myHero.pos:To2D().y + 75}
			DrawText("W not in Toggle Mode", fontSize, Vector(pos), DrawColor(155, 155, 155, 155))
		end
	end

end


Ezreal()
LoadUnits()
