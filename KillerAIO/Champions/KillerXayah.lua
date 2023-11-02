require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.01

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Xayah will exit.")
    return
end

-- [ AutoUpdate ]

--UpdateMyHeroScript()

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Xayah"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/xayah.png"

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 1100, Radius = 50, Speed = 3000}
local R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1.5, Range = 1000, Radius = 200, Angle = 14, StartOffset = 150, Speed = 2600}

--Main Menu
Xayah.Menu = MenuElement({type = MENU, id = "KillerXayah", name = "Killer Xayah", leftIcon=ChampIcon})
Xayah.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

Xayah.FeatherData = {}
Xayah.PreFeatherData = {}
Xayah.DumbFeatherData = {}

Xayah.QDidCast = false
Xayah.RDidCast = false
Xayah.CachedHUDAmmo = 0

function Xayah:__init()
	self:LoadMenu()

	table.insert(_G.SDK.OnTick, function()
		self:TrackFeatherCreation()
		self:Tick()
	end)

	table.insert(_G.SDK.OnDraw, function()
		self:Draw()
	end)

	_G.SDK.Orbwalker:OnPreAttack(function(...) Xayah:OnPreAttack(...) end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) Xayah:OnPostAttack(...) end)

	self:UpdateGoSMenuAutoLevel()
end

function Xayah:LoadMenu()
	
	self.Menu:MenuElement({id = "MasterEToggle", name = "Master Toggle E", key = 20, toggle = true})

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Combo:MenuElement({id = "UseERoot", name = "Use E to Root", value = true})
	self.Menu.Combo:MenuElement({id = "UseERootMelee", name = "E Root Adaptive Melee Spacing", value = true})
	self.Menu.Combo:MenuElement({id = "EKey", name = "Toggle E Rooting", key = string.byte("C"), toggle = true})
	self.Menu.Combo:MenuElement({id = "RSettings", name = "R Settings", type = MENU})

	-- R Settings
	self.Menu.Combo.RSettings:MenuElement({id = "Key", name = "Semi-Manual Key", key = string.byte("Z")})
	self.Menu.Combo.RSettings:MenuElement({name = "------------", type = SPACE})
	self.Menu.Combo.RSettings:MenuElement({id = "RAoE", name = "Use R to AoE", value = true})
	self.Menu.Combo.RSettings:MenuElement({id = "RAoECount", name = "Use if it hits at least X enemies", value = 4, min = 1, max = 5, step = 1, identifier = " Enemies"})
	self.Menu.Combo.RSettings:MenuElement({name = "------------", type = SPACE})

	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "AAHarass", name = "Hit Enemy with Feather through Minions", value = true})
	self.Menu.Harass:MenuElement({id = "QRoot", name = "Cast Q if it will lead to a Root", value = true})
	self.Menu.Harass:MenuElement({id = "UseERoot", name = "Use E if it Can Root", value = true})

	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseQCanon", name = "Use Q on Distant Canon Minion", value = true})

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "Lane", name = "Lane", type = MENU})
	self.Menu.Clear:MenuElement({id = "Jungle", name = "Jungle", type = MENU})

	-- Lane Clear
	self.Menu.Clear.Lane:MenuElement({id = "ChampCheck", name = "Only Use Skills When No Enemies Around", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "LevelCheck", name = "Only Use Skills After Level", value = 10, min = 1, max = 18, step = 1})
	self.Menu.Clear.Lane:MenuElement({id = "LogicCheck", name = "Logic: ", value = 1, drop = {"OR", "AND"}})
	self.Menu.Clear.Lane:MenuElement({name = "=================", type = SPACE})
	self.Menu.Clear.Lane:MenuElement({id = "UseQ", name = "Use Q to Kill Distant Minions", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "UseEClusters", name = "Use E if Kills X Minions", value = 3, min = 1, max = 6, step = 1})
	self.Menu.Clear.Lane:MenuElement({id = "UseECanon", name = "Use E to Kill Canon", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "QMana", name = "Q Min Mana", value = 35, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear.Lane:MenuElement({id = "EMana", name = "E Min Mana", value = 35, min = 0, max = 100, step = 5, identifier = "%"})

	-- Jungle Clear
	self.Menu.Clear.Jungle:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "UseESteal", name = "Save E on Dragon/Baron to Steal", value = true})

	-- Auto E
	self.Menu:MenuElement({id = "AutoE", name = "Auto E", type = MENU})
	self.Menu.AutoE:MenuElement({id = "KillSteal", name = "Kill Steal", value = true})
	self.Menu.AutoE:MenuElement({id = "KillStealOverkill", name = "Kill Steal Overkill Protection", value = true})
	self.Menu.AutoE:MenuElement({name = "------------", type = SPACE})
	self.Menu.AutoE:MenuElement({id = "AutoEOnXFeathers", name = "Use if X Feathers Hit Target", value = true})
	self.Menu.AutoE:MenuElement({id = "AutoEOnXFeathersCount", name = "Feather Count: ", value = 5, min = 1, max = 8, step = 1, identifier = " Feathers"})
	self.Menu.AutoE:MenuElement({name = "------------", type = SPACE})
	self.Menu.AutoE:MenuElement({id = "AutoERoot", name = "Use to Root at least X enemies", value = true})
	self.Menu.AutoE:MenuElement({id = "AutoERootCount", name = "Enemy Count", value = 2, min = 1, max = 5, step = 1})
	self.Menu.AutoE:MenuElement({name = "------------", type = SPACE})
	self.Menu.AutoE:MenuElement({id = "EDistantEnemies", name = "Use on Distant Enemies", value = true})
	self.Menu.AutoE:MenuElement({id = "EDistantEnemiesHPAmnt", name = "If they take at least X% Damage", value = 25, min = 5, max = 100, step = 5, identifier = "%"})

	-- Auto R
	self.Menu:MenuElement({id = "AutoR", name = "Auto R", type = MENU})
	self.Menu.AutoR:MenuElement({id = "AntiMeleeR", name = "Anti-Melee R", value = true})
	self.Menu.AutoR:MenuElement({id = "AntiMeleeBlacklist", name = "Anti-Melee Blacklist", type = MENU})
	self.Menu.AutoR:MenuElement({id = "AntiMeleeRHPCheck", name = "Min HP% Before Checking Anti-Melee", value = 50, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.AutoR:MenuElement({id = "AntiDashR", name = "Anti-Dash R", value = true})
	self.Menu.AutoR:MenuElement({id = "AntiDashRHPCheck", name = "Min HP% Before Checking Anti-Dash", value = 50, min = 0, max = 100, step = 5, identifier = "%"})

	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local hero = args.unit
		local charName = args.charName
		if(hero.range <= 250) then
			self.Menu.AutoR.AntiMeleeBlacklist:MenuElement({id = charName, name = charName, value = false})
		end
	end)

	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "Feathers", name = "Feather Drawings", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawERoot", name = "Draw E Root Status", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawMasterEStatus", name = "Draw Master E Status", value = true})


	--Feathers
	self.Menu.Drawings.Feathers:MenuElement({id = "DrawFeathers", name = "Draw Feathers", value = true})
	self.Menu.Drawings.Feathers:MenuElement({id = "DrawPreFeathers", name = "Draw Pre-Feathers", value = false})
	self.Menu.Drawings.Feathers:MenuElement({id = "DrawHitLines", name = "Draw Hit Lines", value = true})

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

	--self.Menu:MenuElement({id = "Angle", name = "Angle", value = 30, min = 1, max = 90, step = 1, identifier = " Degrees"})
	--self.Menu:MenuElement({id = "StartPos", name = "Start Offset", value = 0, min = 0, max = 500, step = 5})
	
end

function Xayah:UpdateGoSMenuAutoLevel()
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

function Xayah:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Xayah:Tick()
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

	self:ManualKeys()
	self:UpdatePreFeatherData()
	self:UpdateFeatherData()
	self:UpdateQDelay()
	self:AutoE()
	self:AutoR()

	if(self.Menu.Combo.RSettings.Key:Value()) then
		self:RSemiManual()
	end

	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end

function Xayah:TrackFeatherCreation()
	if(self.QDidCast == false) then
		if(myHero:GetSpellData(_Q).currentCd) > 0.1 or myHero.activeSpell.name == myHero:GetSpellData(_Q).name and myHero:GetSpellData(_Q).cd ~= 0 then
			self.QDidCast = true
			self:OnPreFeatherCreated()
			--Comes in delay of two feathers
			DelayEvent(function()
				self:OnFeatherCreated()

				DelayEvent(function()
					self:OnFeatherCreated()
				end, 0.15 + (_G.LATENCY/1000))

			end, 0.825 + (_G.LATENCY/1000))
		end
	end

	if(self.RDidCast == false) then
		if(myHero:GetSpellData(_R).currentCd) > 0.1 or myHero.activeSpell.name == myHero:GetSpellData(_R).name and myHero:GetSpellData(_R).cd ~= 0 then
			self.RDidCast = true
			DelayEvent(function()
				self:OnPreFeatherCreated()
			end, 1 + (_G.LATENCY/1000))
			DelayEvent(function()
				self:OnFeatherCreated()
			end, 1.35 + (_G.LATENCY/1000))
		end
	end

	--Hud Ammo
	if not (myHero.hudAmmo == 0 and self.CachedHUDAmmo >= 2) then
		if(myHero.hudAmmo < self.CachedHUDAmmo) then
			self:OnPreFeatherCreated()
			DelayEvent(function()
				self:OnFeatherCreated()
			end, 0.25 + (_G.LATENCY/1000) + 0.08)
			self.CachedHUDAmmo = myHero.hudAmmo
		end

		if(myHero.hudAmmo > self.CachedHUDAmmo) then
			self.CachedHUDAmmo = myHero.hudAmmo
		end
	end

	if(myHero.hudAmmo == 0) then self.CachedHUDAmmo = 0 end

	self:UpdateSpellChecks()
end

function Xayah:UpdateSpellChecks()
	if(Ready(_Q) and myHero.activeSpell.name ~= myHero:GetSpellData(_Q).name) then 
		self.QDidCast = false 
	end

	if(Ready(_R) and myHero.activeSpell.name ~= myHero:GetSpellData(_R).name) then 
		self.RDidCast = false 
	end
end

function Xayah:OnFeatherCreated()
	self:SearchFeathers()
end

function Xayah:OnPreFeatherCreated()
	if myHero.activeSpell.name == myHero:GetSpellData(_Q).name then
		--Workaround, sometimes the missiles don't get detected
		self.DumbFeatherData[#self.DumbFeatherData + 1] = {EndPos = myHero.pos:Extended(Vector(myHero.activeSpell.placementPos), Q.Range+25), Age = GameTimer()}
		self.DumbFeatherData[#self.DumbFeatherData + 2] = {EndPos = myHero.pos:Extended(Vector(myHero.activeSpell.placementPos), Q.Range+25), Age = GameTimer()}
	else
		self:SearchFeatherMissiles()
	end
end

function Xayah:CheckIfFeatherString(obj)
	return obj.name:lower():find("xayah") and obj.name:lower():find("dagger") and obj.name:lower():find("indicator") and not obj.name:lower():find("ready")
end

function Xayah:CheckExistingFeather(obj)
	for _, feather in pairs(self.FeatherData) do
		if(feather.networkID == obj.networkID) then
			return true
		end
	end
	return false
end

function Xayah:CheckExistingFeatherMissile(obj)
	for _, feather in ipairs(self.PreFeatherData) do
		if(feather.Feather and feather.Feather.networkID == obj.networkID) then
			return true
		end
	end
	return false
end

function Xayah:SearchFeathers()
	for i = 1, Game.ParticleCount() do
		local obj = Game.Particle(i)
		if obj and self:CheckIfFeatherString(obj) then
			if (self:CheckExistingFeather(obj) == false) then
				table.insert(self.FeatherData, obj)
			end
		end
	end
end

function Xayah:SearchFeatherMissiles()
	for i = 1, Game.MissileCount() do
		local missile = Game.Missile(i)
        if missile.missileData and not self:CheckExistingFeatherMissile(missile) then
            if missile.missileData.name:find("XayahQMissile1") or missile.missileData.name:find("XayahQMissile2") then
				self.PreFeatherData[#self.PreFeatherData + 1] = {Feather = missile, EndPos = Vector(missile.missileData.endPos), Age = GameTimer()}
            elseif missile.missileData.name:find("XayahRMissile") then
				local correctedEndPos = Vector(missile.missileData.endPos.x, myHero.pos.y, missile.missileData.endPos.z)
				local correctedStartPos = Vector(missile.missileData.startPos.x, myHero.pos.y, missile.missileData.startPos.z)
				self.PreFeatherData[#self.PreFeatherData + 1] = {Feather = missile, EndPos = (correctedStartPos):Extended(correctedEndPos, 1100), Age = GameTimer()}
            elseif missile.missileData.name:find("XayahPassiveAttack") then
				local correctedEndPos = Vector(missile.missileData.endPos.x, myHero.pos.y, missile.missileData.endPos.z)
				local correctedStartPos = Vector(missile.missileData.startPos.x, myHero.pos.y, missile.missileData.startPos.z)
				self.PreFeatherData[#self.PreFeatherData + 1] = {Feather = missile, EndPos = (correctedStartPos):Extended(correctedEndPos, 1000), Age = GameTimer()}
            end
        end
	end
end

function Xayah:UpdateFeatherData()
	for i = #self.FeatherData, 1, -1 do
		local feather = self.FeatherData[i]
		if(feather.type ~= "obj_GeneralParticleEmitter") or not feather or not self:CheckIfFeatherString(feather) then
			table.remove(self.FeatherData, i)
		end
	end
end

function Xayah:UpdatePreFeatherData()
	for i = #self.PreFeatherData, 1, -1 do
		local feather = self.PreFeatherData[i].Feather
		if not self:CheckExistingFeatherMissile(feather) or not feather or feather.dead or GameTimer() - self.PreFeatherData[i].Age > 1 then
			table.remove(self.PreFeatherData, i)
		end
	end

	for i = #self.DumbFeatherData, 1, -1 do
		if GameTimer() - self.DumbFeatherData[i].Age > 0.75 then
			table.remove(self.DumbFeatherData, i)
		end
	end
end

function Xayah:OnPreAttack(args)
	if(self:IsUlting()) then
		args.Process = false
	end

	if(GetMode() == "Combo") then
		if(self.Menu.Combo.UseW:Value() and Ready(_W)) then
			Control.CastSpell(HK_W)
		end
	end
end

function Xayah:OnPostAttack(args)
    if GetMode() == "Combo" then
		if(self.Menu.Combo.UseQ:Value() and Ready(_Q)) then
			local tar = GetTarget(_G.SDK.Data:GetAutoAttackRange(myHero))
			if(IsValid(tar)) then
				CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, GGPred = false, KillerPred = true})
			end
		end
    end
end

function Xayah:Combo()
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.Combo.UseQ:Value() and Ready(_Q)) then
		local tar = GetTarget(Q.Range - 75)
		local AATar = GetTarget(_G.SDK.Data:GetAutoAttackRange(myHero))
		if(IsValid(tar)) then
			if(IsValid(AATar)) then
				--
			else
				if(GetDistance(myHero, tar) > _G.SDK.Data:GetAutoAttackRange(myHero, tar)) then
					CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, GGPred = false, KillerPred = true})
				end
			end
		end
	end

	if(self.Menu.Combo.UseERoot:Value() and Ready(_E)) then
		if(self.Menu.MasterEToggle:Value()) then
			local tar = GetTarget(Q.Range + 100)
			if(IsValid(tar)) then

				local useMeleeSpacing = false 
				if(self.Menu.Combo.UseERootMelee:Value()) then
					if(tar.range <= 200) then
						useMeleeSpacing = true
					end
				end

				if(not useMeleeSpacing) then
					local hits = self:GetTotalFeathersHit(tar)
					if(hits >= 3) then
						Control.CastSpell(HK_E)
						return
					end
				else
					local hits = self:GetTotalFeathersHit(tar)
					if(hits >= 3) then
						if(GetDistance(tar, myHero) <= tar.range + myHero.boundingRadius + 100) or self:IsUnitFleeing(tar) or GetDistance(tar, myHero) >= _G.SDK.Data:GetAutoAttackRange(myHero) + 100 then
							Control.CastSpell(HK_E)
							return
						end
					end
				end
			end
		end
	end

	--R AoE
	if(self.Menu.Combo.RSettings.RAoE:Value() and Ready(_R)) then
		local enemies = GetEnemyHeroes(R.Range - 25)
		if #enemies >= self.Menu.Combo.RSettings.RAoECount:Value() then
			local bestPos, count = CalculateBestLinePosition(enemies, 500, R.Range, R.Speed, 0.5)
			local check = true
			if(bestPos) then
				for _, enemy in ipairs(enemies) do
					if(IsValid(enemy)) then
						if not IsInCone(enemy, bestPos, R.Range, R.Angle, R.StartOffset) then
							check = false
						end
					end
				end
			end
			if(check) then
				Control.CastSpell(HK_R, bestPos)
				return
			end
		end
	end

end

function Xayah:Harass()
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.Harass.AAHarass:Value()) then
		if(myHero.hudAmmo > 0) then
			local AAFeather = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 	myHero.attackData.windUpTime, Range = 1000, Radius = 60, Speed = 4000}
			local target = GetTarget(AAFeather.Range)
			if(target and IsValid(target)) then

				local AAPrediction = GGPrediction:SpellPrediction(AAFeather)
				AAPrediction:GetPrediction(target, myHero)
				if AAPrediction:CanHit(HITCHANCE_NORMAL) then
					
					--Check to see if the direction vector of us hitting the minion intersects with the enemy champion
					local minions = _G.SDK.ObjectManager:GetEnemyMinions(_G.SDK.Data:GetAutoAttackRange(myHero))
					if(#minions > 0) then
						for _, minion in ipairs(minions) do
							if(minion and IsValid(minion)) then
								local diffVec = myHero.pos + (minion.pos - myHero.pos):Normalized() * AAFeather.Range
								local point, isOnSegment = ClosestPointOnLineSegment(target.pos, myHero.pos, diffVec)						
								if isOnSegment then
									local distCheck = GetDistance(target.pos, point)
									if distCheck < AAFeather.Radius then
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

	if(self.Menu.Harass.QRoot:Value() and Ready(_Q)) then
		local tar = GetTarget(Q.Range - 75)
		if(IsValid(tar)) then
			local hits = self:GetTotalFeathersHit(tar)
			if(hits >= 1) then
				CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, GGPred = false, KillerPred = true})
			end
		end
	end

	if(self.Menu.Harass.UseERoot:Value() and Ready(_E)) then
		if(self.Menu.MasterEToggle:Value()) then
			local tar = GetTarget(Q.Range)
			if(IsValid(tar)) then
				local hits = self:GetTotalFeathersHit(tar)
				if(hits >= 3) then
					Control.CastSpell(HK_E)
				end
			end
		end
	end
end

local avoidQMinionHandle = 0
function Xayah:LastHit()
	if not (IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.LastHit.UseQCanon:Value() and Ready(_Q)) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
		if(#minions > 0) then
			local canonMinion = GetCanonMinion(minions)
			if(canonMinion) and IsValid(canonMinion) then
				local QDam = self:GetRawAbilityDamage("Q")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (myHero.pos:DistanceTo(canonMinion.pos)/Q.Speed))
				
				if ((hp > 0) and (canonMinion.health - QDam <= 0) and GetDistance(myHero, canonMinion) >= _G.SDK.Data:GetAutoAttackRange(myHero) + 100) then
					Control.CastSpell(HK_Q, canonMinion.pos)
					return
				end
			end
		end
	end

end

function Xayah:Clear()
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

function Xayah:CalculateDragonMitigation()
	--Hacky fix.
	--[[
		First dragon spawns at 5 mins, assuming they are perfectly killed the next one would be at 10 mins and provide the 7% mitigation.
		This assumes all dragons will be killed by 25mins, if they aren't then the mitigation will act as a buffer.
	]]
	local bonus = math.min(math.floor(math.max(0, GameTimer() - 300) / 300) * 7, 28)
	return bonus/100
end

function Xayah:JungleClear(minions)
	if(self.Menu.Clear.Jungle.UseQ:Value() and Ready(_Q)) then
		for _, minion in pairs(minions) do
			if(GetDistance(myHero, minion) <= Q.Range*0.75 and minion.pos:To2D().onScreen) then
				local qPred = GGPrediction:SpellPrediction(Q)
				qPred:GetPrediction(minion, myHero)
				if qPred.CastPosition and qPred:CanHit(HITCHANCE_NORMAL) then
					if Vector(qPred.CastPosition):To2D().onScreen then
						Control.CastSpell(HK_Q, qPred.CastPosition)
						break
					end
				end	
			end
		end
	end

	if(self.Menu.Clear.Jungle.UseW:Value() and Ready(_W)) then
		for _, minion in pairs(minions) do
			if(GetDistance(myHero, minion) <= _G.SDK.Data:GetAutoAttackRange(myHero) and minion.pos:To2D().onScreen) then
				Control.CastSpell(HK_W)
			end
		end
	end

	if(self.Menu.Clear.Jungle.UseE:Value() and Ready(_E)) then
		if(self.Menu.MasterEToggle:Value()) then
			for _, minion in pairs(minions) do

				local shouldKS = false
				if (self.Menu.Clear.Jungle.UseESteal:Value()) then
					if(jungleWMonsters[minion.charName]==1) then
						shouldKS = true
					end
				end
				if not shouldKS then
					local EDmg = self:CalculateEDamage(minion)
					local AADmg = myHero.totalDamage
					EDmg = CalcPhysicalDamage(myHero, minion, EDmg)
					AADmg = CalcPhysicalDamage(myHero, minion, AADmg)
					if(minion.health - EDmg - AADmg < 0 or ((EDmg+AADmg)/minion.maxHealth >= 0.4 and self:HasNavori())) then
						Control.CastSpell(HK_E)
					end
				else
					local EDmg, Hits = self:CalculateEDamage(minion)
					EDmg = CalcPhysicalDamage(myHero, minion, EDmg)

					if(minion.charName ~= "SRU_Baron" or minion.charName ~= "SRU_RiftHerald") then
						EDmg = EDmg * (1 - self:CalculateDragonMitigation())
					end

					if(minion.health - EDmg < 0) or (minion.health/minion.maxHealth>= 0.6 and Hits >= 5) then
						Control.CastSpell(HK_E)
					end
				end
			end
		end
	end
end

function Xayah:LaneClear(minions)
	local shouldUseClearSkills = true

	local champCheck, levelCheck = true, true
	if(self.Menu.Clear.Lane.ChampCheck:Value()) then
		local enemies = GetEnemyHeroes(1500)
		if(#enemies ~= 0) then
			champCheck = false
		end
	end

	if(myHero.levelData.lvl < self.Menu.Clear.Lane.LevelCheck:Value()) then
		levelCheck = false
	end

	if(self.Menu.Clear.Lane.LogicCheck:Value() == 1) then
		-- OR
		shouldUseClearSkills = champCheck or levelCheck
	else
		-- AND
		shouldUseClearSkills = champCheck and levelCheck
	end

	if(shouldUseClearSkills == false) then return end

	if(self.Menu.Clear.Lane.UseEClusters:Value()) then
		if(self.Menu.MasterEToggle:Value()) then
			if(Ready(_E) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.Lane.EMana:Value() / 100)) then
				local killCount = 0
				local requiredKillCount = self.Menu.Clear.Lane.UseEClusters:Value()
				if(#minions >= requiredKillCount) then
					for _, minion in ipairs(minions) do
						local EDmg = self:CalculateEDamage(minion)
						EDmg = EDmg * 0.5
						if(minion.health - EDmg < 0) then
							killCount = killCount + 1
						end
					end

					if killCount >= requiredKillCount then
						Control.CastSpell(HK_E)
						return
					end
				end
			end
		end
	end

	if(self.Menu.Clear.Lane.UseECanon:Value()) then
		if(self.Menu.MasterEToggle:Value()) then
			if (Ready(_E) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.Lane.EMana:Value() / 100)) then
				local canonMinion = GetCanonMinion(minions)
				
				if(canonMinion) and IsValid(canonMinion) then
					local EDmg = self:CalculateEDamage(canonMinion)
					EDmg = EDmg * 0.5
					
					if canonMinion.health + 30 - EDmg <= 0 then
						Control.CastSpell(HK_E)
						return
					end
				end
			end
		end
	end

	if(self.Menu.Clear.Lane.UseQ:Value()) then
		if(Ready(_Q) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.Lane.QMana:Value() / 100)) then
			for _, minion in ipairs(minions) do
				if(GetDistance(myHero, minion) >= _G.SDK.Data:GetAutoAttackRange(myHero) + 150) then
					local QDmg = self:GetRawAbilityDamage("Q")
					if(minion.health - QDmg < 0) then
						Control.CastSpell(HK_Q, minion.pos)
					end
				end
			end
		end
	end
end

function Xayah:RSemiManual()
	if not Ready(_R) then return end
	if myHero.dead then return end

	-- R Logic.
	local tar = GetTarget(R.Range)
	if(tar and IsValid(tar)) then
		if _G.SDK.Cursor.Step == 0 then
			if(CantKill(tar, true, true, false, true) == false) then
				local offsetPredR = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.75, Range = 1000, Radius = 350, Speed = 2600}
				CastPredictedSpell({Hotkey = HK_R, Target = tar, SpellData = offsetPredR, GGPred = false, KillerPred = true})
			end
		end
	end

end

function Xayah:IsUnitFleeing(unit)
	if(unit and IsValid(unit) and unit.toScreen.onScreen) then
		local checkRunDir = GetUnitRunDirection(myHero, unit)
		if(checkRunDir == RUNNING_AWAY) then
			--Conditions where someone may be fleeing
			
			--Target is less than 30% HP
			local condition1 = (unit.health / unit.maxHealth) <= 0.3
			
			--You have 30% more HP than the target and they are less than 50% HP
			local condition2 = (myHero.health / myHero.maxHealth) - (unit.health / unit.maxHealth)>= 0.3 and (unit.health / unit.maxHealth) <= 0.5

			--You have 50% more HP than the target
			local condition3 = (myHero.health / myHero.maxHealth) - (unit.health / unit.maxHealth)>= 0.5

			if(condition1 or condition2 or condition3) then
				return true
			end
		end
	end
	
	return false
end

function Xayah:AutoE()
	if(self.Menu.MasterEToggle:Value() == false) then return end
	local function Killsteal()
		if(Ready(_E)) then
			local enemies = GetEnemyHeroes(1600)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy)) then
						if((CantKill(enemy, true, true, false)==false)) then
							local EDmg, Hits = self:CalculateEDamage(enemy)
							local AADmg = myHero.totalDamage
							EDmg = CalcPhysicalDamage(myHero, enemy, EDmg)
							AADmg = CalcPhysicalDamage(myHero, enemy, AADmg)

							local shouldUseE = true

							if(self.Menu.AutoE.KillStealOverkill:Value()) then
								if(#enemies > 1) then
									if(GetDistance(myHero, enemy) < _G.SDK.Data:GetAutoAttackRange(myHero, enemy)) then
										--Dont waste E if we can just AA
										if(enemy.health - AADmg < 0) then
											shouldUseE = false
										end

										--Dont waste on low feather hits
										if Hits <= 2 then
											shouldUseE = false
										end
									end

									if(#enemies >= 3) then
										-- Only KS distant targets if at least 3 feathers hit
										if(GetDistance(myHero, enemy) > _G.SDK.Data:GetAutoAttackRange(myHero, enemy) + 75) then
											if Hits < 3 then
												shouldUseE = false
											end	
										end
									end
								end
							end

							if(shouldUseE) then
								if(enemy.health - EDmg < 0) then
									Control.CastSpell(HK_E)
								else
									if(GetDistance(myHero, enemy) < _G.SDK.Data:GetAutoAttackRange(myHero, enemy)) then
										if(enemy.health - EDmg - AADmg < 0) then
											Control.CastSpell(HK_E)
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

	--AutoEOnXFeathers
	local function AutoEXFeathers()
		if(Ready(_E)) then
			local enemies = GetEnemyHeroes(1600)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy)) then
						if((CantKill(enemy, true, true, false)==false)) then
							local hits = self:GetTotalFeathersHit(enemy)
							if(hits >= self.Menu.AutoE.AutoEOnXFeathersCount:Value()) then
								Control.CastSpell(HK_E)
								return
							end
						end
					end
				end
			end
		end
	end

	--AutoE Root X Targets
	local function AutoERoot()
		if(Ready(_E)) then
			local enemies = GetEnemyHeroes(1600)
			if(#enemies > 0) then
				local totalRootCount = 0
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy)) then
						local hits = self:GetTotalFeathersHit(enemy)
						if(hits >= 3) then
							totalRootCount = totalRootCount + 1
						end
					end
				end

				if(totalRootCount >= self.Menu.AutoE.AutoERootCount:Value()) then
					Control.CastSpell(HK_E)
					return
				end
			end
		end
	end

	--AutoE Distant Enemies
	local function AutoEDistantEnemies()
		if(Ready(_E)) then
			local enemies = GetEnemyHeroes(1800)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy)) then
						if( GetDistance(myHero, enemy) >= Q.Range - 150 and (CantKill(enemy, true, true, false)==false)) then
							local EDmg = self:CalculateEDamage(enemy)
							EDmg = CalcPhysicalDamage(myHero, enemy, EDmg)
							if(EDmg/enemy.maxHealth >= self.Menu.AutoE.EDistantEnemiesHPAmnt:Value()/100) then
								Control.CastSpell(HK_E)
							end
						end
					end
				end
			end
		end
	end

	if(self.Menu.AutoE.KillSteal:Value()) then
		Killsteal()
	end

	if(self.Menu.AutoE.AutoEOnXFeathers:Value()) then
		AutoEXFeathers()
	end

	if(self.Menu.AutoE.AutoERoot:Value()) then
		AutoERoot()
	end

	if(self.Menu.AutoE.EDistantEnemies:Value()) then
		AutoEDistantEnemies()
	end
end

function Xayah:AutoR()

	local function AntiMelee()
		if not Ready(_R) then return end 
		
		local enemies = GetEnemyHeroes(R.Range - 25)
		if _G.SDK.Cursor.Step > 0 then
			return
		end

		if(myHero.health/myHero.maxHealth > self.Menu.AutoR.AntiMeleeRHPCheck:Value()/100) then
			return
		end

		local validEnemies = {}

		for _, enemy in ipairs(enemies) do
			if(IsValid(enemy)) then
				if(self.Menu.AutoR.AntiMeleeBlacklist[enemy.charName]) then
					if(self.Menu.AutoR.AntiMeleeBlacklist[enemy.charName]:Value() == false) then
						table.insert(validEnemies, enemy)
					end
				end
			end
		end

		if #validEnemies > 0 then
			table.sort(validEnemies, function(a, b)
				return a.health + (a.totalDamage * 2) + (a.attackSpeed * 100)
					> b.health + (b.totalDamage * 2) + (b.attackSpeed * 100)
			end)
			for _, enemy in ipairs(enemies) do
				if IsFacing(enemy) and GetDistance(myHero, enemy) < 250 and enemy.range <= 250 then
					Control.CastSpell(HK_R, enemy.pos)
					return
				end
			end
		end
	end

	local function AntiDash()
		if not Ready(_R) then return end 
		
		local enemies = GetEnemyHeroes(R.Range)
		if _G.SDK.Cursor.Step > 0 then
			return
		end

		if(myHero.health/myHero.maxHealth > self.Menu.AutoR.AntiDashRHPCheck:Value()/100) then
			return
		end

		for _, enemy in ipairs(enemies) do
			if(IsValid(enemy)) then
				local path = enemy.pathing
				if path and path.isDashing and enemy.posTo then
					if
						GetDistance(enemy, myHero) < 400
						and IsFacing(enemy)
					then
						Control.CastSpell(HK_E, enemy.pos)
						return
					end
				end
			end
		end
	end

	if self.Menu.AutoR.AntiMeleeR:Value() then
		AntiMelee()
	end

	if self.Menu.AutoR.AntiDashR:Value() then
		AntiDash()
	end
end

function Xayah:CanFeatherHitEnemy(feather, unit)

	local point, isOnSegment = ClosestPointOnLineSegment(unit.pos, myHero.pos, feather.pos)						
	if isOnSegment then
		local distCheck = GetDistance(unit.pos, point)
		if distCheck < 80 + unit.boundingRadius - 10 then
			return true
		end
	end

	return false
end

function Xayah:GetTotalFeathersHit(unit)
	local total = 0
	for _, feather in ipairs(self.FeatherData) do
		local point, isOnSegment = ClosestPointOnLineSegment(unit.pos, myHero.pos, feather.pos)						
		if isOnSegment then
			local distCheck = GetDistance(unit.pos, point)
			if distCheck < 80 + unit.boundingRadius - 10 then
				total = total + 1
			end
		end	
	end

	for _, feather in ipairs(self.PreFeatherData) do
		local point, isOnSegment = ClosestPointOnLineSegment(unit.pos, myHero.pos, feather.EndPos)						
		if isOnSegment then
			local distCheck = GetDistance(unit.pos, point)
			if distCheck < 80 + unit.boundingRadius - 10 then
				total = total + 1
			end
		end	
	end

	for _, feather in ipairs(self.DumbFeatherData) do
		local point, isOnSegment = ClosestPointOnLineSegment(unit.pos, myHero.pos, feather.EndPos)						
		if isOnSegment then
			local distCheck = GetDistance(unit.pos, point)
			if distCheck < 80 + unit.boundingRadius - 10 then
				total = total + 1
			end
		end	
	end

	return total
end
function Xayah:UpdateQDelay()
	Q.Delay = 0.25 - (0.07*(myHero.attackSpeed - 1)) + 0.125
end

function Xayah:HasNavori()
	return HasItem({Item.NavoriQuickblades})
end

function Xayah:HasLordDominiks()
	return HasItem({Item.LordDominiksRegards})
end

function Xayah:IsUlting()
	local buffs = _G.SDK.BuffManager:GetBuffs(myHero)
	for _, buff in ipairs(buffs) do
		if(buff.count > 0 and buff.name:lower():find("xayahr")) then
			return true
		end
	end

	return false
end

function Xayah:GetRawAbilityDamage(spell, tar)
	if(spell == "Q") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		return ({90, 120, 150, 180, 210})[myHero:GetSpellData(_Q).level] + (myHero.bonusDamage)
	end
	
	if(spell == "R") then
		if myHero:GetSpellData(_R).level == 0 then return 0 end
		return ({200, 300, 40})[myHero:GetSpellData(_R).level] + (myHero.bonusDamage)
	end

	return 0
end

function Xayah:CalculateEDamage(unit)
	local hits = self:GetTotalFeathersHit(unit)
	if(hits > 0) then
		local featherDmg = (40 + myHero:GetSpellData(_E).level * 10 + (0.6 * myHero.bonusDamage)) * (1 + myHero.critChance * 0.75)
		if self:HasNavori() then
			featherDmg = featherDmg * GetItemDamage(Item.NavoriQuickblades)
		end
		if self:HasLordDominiks() and unit.type == Obj_AI_Hero then
			featherDmg = featherDmg * GetItemDamage(Item.LordDominiksRegards, unit)
		end
		local rawDmg = 0
		for i = 1, hits do
			rawDmg = rawDmg + (featherDmg * (1 - (i - 1)*0.05))
		end
		return rawDmg, hits
	end

	return 0, 0
end

function Xayah:ManualKeys()
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


-- [[ DRAWINGS ]] --

local qcolA = Vector(239, 13, 255)
local qcolB = Vector(255, 13, 122)

function Xayah:Draw()
	if myHero.dead then return end

	if(self.Menu.Drawings.DrawQ:Value()) then
		if(Ready(_Q)) then

			local tick = math.abs((math.cos((GetTickCount() / 1000) * 2) + 1)/2)
			local res = qcolA:Lerp(qcolB, tick)
			res = {r = math.floor(res.x), g = math.floor(res.y), b = math.floor(res.z)}
			DrawCircle(myHero, Q.Range, 1, DrawColor(255, res.r, res.g, res.b)) --(Alpha, R, G, B)
		else
			DrawCircle(myHero, Q.Range, 1, DrawColor(55, 255, 255, 255)) --(Alpha, R, G, B)	
		end
	end

	if(self.Menu.Drawings.DrawERoot:Value()) then
		local fontSize = 19
		local pos = {x = myHero.pos:To2D().x - fontSize - 45, y = myHero.pos:To2D().y + 65}
		if(self.Menu.Combo.EKey:Value()) then
			DrawText("[E Rooting Enabled]", fontSize, Vector(pos), DrawColor(255, 80, 255, 80))
		else
			DrawText("[E Rooting Disabled]", fontSize, Vector(pos), DrawColor(155, 255, 80, 80))
		end
	end

	if(self.Menu.Drawings.DrawMasterEStatus:Value()) then
		local fontSize = 17
		local pos = {x = myHero.pos:To2D().x - fontSize - 20, y = myHero.pos:To2D().y + 95}
		if(self.Menu.MasterEToggle:Value()) then
			DrawText("[E Enabled]", fontSize, Vector(pos), DrawColor(255, 80, 235, 140))
		else
			DrawText("[E Disabled]", fontSize, Vector(pos), DrawColor(155, 255, 80, 80))
		end
	end

	--self:ConeSolver()
	self:FeatherDrawings()
end

local featherColors = {
	Purple = DrawColor(255, 255, 48, 234),
	Cyan = DrawColor(255, 0, 255, 255),
	FadedWhite = DrawColor(55, 255, 255, 255),
	RedPurple = DrawColor(255, 255, 13, 102),
}

function Xayah:FeatherDrawings()

	if(self.Menu.Drawings.Feathers.DrawFeathers:Value()) then
		for _, feather in ipairs(self.FeatherData) do
			DrawCircle(feather.pos, 25, 1, featherColors.Purple)
		end
	end

	if(self.Menu.Drawings.Feathers.DrawPreFeathers:Value()) then
		for i = #self.PreFeatherData, 1, -1 do
			local feather = self.PreFeatherData[i]
			DrawCircle(feather.EndPos, 25, 1, featherColors.Cyan)
		end
	end

	if(self.Menu.Drawings.Feathers.DrawPreFeathers:Value()) then
		for i = #self.DumbFeatherData, 1, -1 do
			local feather = self.DumbFeatherData[i]
			DrawCircle(feather.EndPos, 25, 1, featherColors.Cyan)
		end
	end

	if(self.Menu.Drawings.Feathers.DrawHitLines:Value()) then
		local enemies = GetEnemyHeroes(1800)
		for _, feather in ipairs(self.FeatherData) do
			if(#enemies > 0) then
				for _, enemy in ipairs(enemies) do
					if(IsValid(enemy)) then
						if(self:CanFeatherHitEnemy(feather, enemy)) then
							DrawLine(myHero.pos:To2D(), feather.pos:To2D(), 3, featherColors.RedPurple)
						else
							DrawLine(myHero.pos:To2D(), feather.pos:To2D(), 1, featherColors.FadedWhite)
						end
					else
						DrawLine(myHero.pos:To2D(), feather.pos:To2D(), 1, featherColors.FadedWhite)
					end
				end
			else
				DrawLine(myHero.pos:To2D(), feather.pos:To2D(), 1, featherColors.FadedWhite)
			end
		end
	end
end

function Xayah:ConeSolver()
	local ang = self.Menu.Angle:Value()
	local mainVec = (Game.mousePos() - myHero.pos):Normalized()
	local startPos = Game.mousePos():Extended(myHero.pos, GetDistance(Game.mousePos(), myHero.pos) + self.Menu.StartPos:Value())
	local v1 = mainVec:Rotated(0, math.rad(ang), 0)
	local v2 = mainVec:Rotated(0, math.rad(-ang), 0)
	DrawLine(myHero.pos:To2D(), Game.mousePos():To2D(), 1, DrawColor(55, 255, 255, 255))
	DrawLine(startPos:To2D(), (startPos + (v1*GetDistance(startPos, Game.mousePos()))):To2D(), 5, DrawColor(255, 255, 0, 0))
	DrawLine(startPos:To2D(), (startPos + (v2*GetDistance(startPos, Game.mousePos()))):To2D(), 5, DrawColor(255, 255, 0, 0))
	DrawLine((startPos + (v1*GetDistance(startPos, Game.mousePos()))):To2D(), (startPos + (v2*GetDistance(startPos, Game.mousePos()))):To2D(), 5, DrawColor(255, 255, 0, 0))
end


Xayah()
LoadUnits()
