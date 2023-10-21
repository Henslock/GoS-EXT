require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.08

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Evelynn will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Evelynn"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/evelynn.png"

local gameTick = GameTimer()

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Range = 800, Radius = 60, Speed = 2400}
local E = {Delay = 0.25, Range = 300}
local R = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.35, Range = 0, Radius = 500, Speed = math.huge}

local Q2Range = 550

local SmiteNames = {
	["SummonerSmite"]=1,
	["S5_SummonerSmitePlayerGanker"]=1,
	["SummonerSmiteAvatarOffensive"]=1,
	["SummonerSmiteAvatarUtility"]=1,
	["SummonerSmiteAvatarDefensive"]=1,
}

Evelynn.SmiteSlot = nil
Evelynn.SmiteCastSlot = nil

Evelynn.ComboDamageData = {}

--Main Menu
Evelynn.Menu = MenuElement({type = MENU, id = "KillerEvelynn", name = "Killer Evelynn", leftIcon=ChampIcon})
Evelynn.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})


function Evelynn:__init()
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

	--Assign our smite slot
	if(SmiteNames[myHero:GetSpellData(SUMMONER_1).name] == 1) then
		self.SmiteSlot = SUMMONER_1
		self.SmiteCastSlot = HK_SUMMONER_1
	end

	if(SmiteNames[myHero:GetSpellData(SUMMONER_2).name] == 1) then
		self.SmiteSlot = SUMMONER_2
		self.SmiteCastSlot = HK_SUMMONER_2
	end
	  

	self:UpdateGoSMenuAutoLevel()
end

function Evelynn:LoadMenu()                  	
	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseQStealth", name = "If Stealth: Use Q Near Stealth Radius", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "Use Melee W", value = true})
	self.Menu.Combo:MenuElement({id = "SemiManualW", name = "Semi-manual W", value = true})
	self.Menu.Combo:MenuElement({id = "UseWMelee", name = "Use W in Melee After Level", value = 9, min = 1, max = 18, step = 1})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "UseR", name = "Use R to Kill", value = true})
	self.Menu.Combo:MenuElement({id = "ROverkillProtection", name = "R Overkill Protection", value = true})
	self.Menu.Combo:MenuElement({id = "SmiteSettings", name = "Smite Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "HextechSettings", name = "Hextech Rocketbelt", type = MENU})

	-- Smite Settings
	self.Menu.Combo.SmiteSettings:MenuElement({id = "Enabled", name = "Use Smite Offensively", value = true})
	self.Menu.Combo.SmiteSettings:MenuElement({id = "KeepCharge", name = "Keep 1 Charge", value = true})
	self.Menu.Combo.SmiteSettings:MenuElement({id = "UseKill", name = "Use to Kill", value = true})
	self.Menu.Combo.SmiteSettings:MenuElement({id = "UseRKillRange", name = "Use to enter R Kill Range", value = true})

	-- Hextech Rocketbelt Settings
	self.Menu.Combo.HextechSettings:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.Combo.HextechSettings:MenuElement({id = "UseKill", name = "Use to Kill", value = true})
	self.Menu.Combo.HextechSettings:MenuElement({id = "UseGapclose", name = "Use to Gapclose", value = true})
	self.Menu.Combo.HextechSettings:MenuElement({id = "GapcloseHP", name = "Gapclose Safety Check", value = true, tooltip = "Low HP, Outnumbered, etc."})
	self.Menu.Combo.HextechSettings:MenuElement({id = "UseMelee", name = "Use in Melee", value = false})


	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})

	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseE", name = "Use E on Cannon", value = true})

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "Lane", name = "Lane", type = MENU})
	self.Menu.Clear:MenuElement({id = "Jungle", name = "Jungle", type = MENU})

	-- Lane Clear
	self.Menu.Clear.Lane:MenuElement({id = "UseE", name = "Use E on Cannon", value = true})
	self.Menu.Clear.Lane:MenuElement({name = "-- Q Settings --", type = SPACE})
	self.Menu.Clear.Lane:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "QMinMana", name = "Q Minimum Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear.Lane:MenuElement({id = "ChampCheck", name = "Use Q When No Enemies Around", value = true})
	self.Menu.Clear.Lane:MenuElement({name = "OR", type = SPACE})
	self.Menu.Clear.Lane:MenuElement({id = "LevelCheck", name = "Use Q After Level", value = 5, min = 1, max = 18, step = 1})

	-- Jungle Clear
	self.Menu.Clear.Jungle:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "WaitCharm", name = "Wait for Charm if Active", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "UseE", name = "Use E", value = true})

	-- Killsteal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.KillSteal:MenuElement({id = "ROverkillProtection", name = "R Overkill Protection", value = false})
	self.Menu.KillSteal:MenuElement({id = "RBlacklist", name = "R Killsteal Blacklist (Unless Solo)", type = MENU})

	-- Dragon & Baron Steal
	self.Menu:MenuElement({id = "DnBStealer", name = "Dragon & Baron Steal", type = MENU})
	self.Menu.DnBStealer:MenuElement({id = "StealDragon", name = "Dragon & Baron Steal Key", key = string.byte("Z")})
	self.Menu.DnBStealer:MenuElement({id = "DrawUI", name = "Draw Steal HP", value = true})
	self.Menu.DnBStealer:MenuElement({id = "DrawSmiteRange", name = "Draw Smite Range", value = true})
	self.Menu.DnBStealer:MenuElement({id = "UseFlash", name = "Use Flash", value = true})

	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawE", name = "Draw E Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawHextech", name = "Draw Hextech UI", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawKillableTargets", name = "Draw Killable Targets", value = true})
	self.Menu.Drawings:MenuElement({id = "DamageHPBar", name = "Damage HP Bar", type = MENU})

	self.Menu.Drawings.DamageHPBar:MenuElement({id = "DrawDamageHPBar", name = "Draw Full Combo Damage", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "YOffset", name = "Y Offset", value = 60, min = -100, max = 100, step = 5})

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

	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local hero = args.unit
		local charName = args.charName
		self.Menu.KillSteal.RBlacklist:MenuElement({id = charName, name = charName, value = false})
	end)
	
end

function Evelynn:UpdateGoSMenuAutoLevel()
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

function Evelynn:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Evelynn:Tick()
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

	self:ManualKeys()
	self:KillSteal()
	self:UpdateComboDamage()

	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end

function Evelynn:OnWndMsg(msg, wParam)
	if wParam == HK_W then
		self:SemiManualW()
	end
end

function Evelynn:GenerateCastUltDirection(tar)
	return tar.pos
end
function Evelynn:Combo()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.Combo.UseR:Value()) then
		if(Ready(_R)) then
			local tar = GetTarget(R.Radius - 50)
			if(IsValid(tar) and GetDistance(tar, myHero) <= R.Radius and (CantKill(tar, true, false, false, true)==false)) then
				local dmg = self:GetRawAbilityDamage("R")
				if(tar.health/tar.maxHealth <= 0.3) then
					dmg = self:GetRawAbilityDamage("RExecute")
				end
				dmg = CalcMagicalDamage(myHero, tar, dmg)
				local castPos = self:GenerateCastUltDirection(tar)
				if(tar.health - dmg < 0) then

					local shouldCast = true
					if(self.Menu.Combo.ROverkillProtection:Value()) then
						if(self:IsROverkill(tar)) then
							shouldCast = false
						end
					end

					if(shouldCast) then
						Control.CastSpell(HK_R, castPos)
					end
				end
			end
		end
	end

	if(self.Menu.Combo.UseQ:Value()) then
		if(Ready(_Q)) then
			if(myHero:GetSpellData(_Q).name == "EvelynnQ") then
				local tar = GetTarget(Q.Range - 15)
				local rangeCheck = Q.Range
				if(self.Menu.Combo.UseQStealth:Value()) then
					if(self:IsInStealth()) then
						rangeCheck = 700
					end
				end
				if(IsValid(tar) and GetDistance(tar, myHero) <= rangeCheck) then

					local charmCheck = true
					local isCharmed, charmDuration = self:IsUnitCharmed(tar)
					local isCastingCharm = myHero.activeSpell.valid and myHero.activeSpell.name == "EvelynnWApplyMark"
					local predPos = GetPrediction(tar, Q.Speed, Q.Delay) or tar.pos
					if((isCharmed or isCastingCharm) and charmDuration < 2.5 - (GetDistance(myHero, predPos)/Q.Speed + Q.Delay - 0.1)) then
						charmCheck = false
					end

					if(charmCheck or GetDistance(myHero, tar)<= E.Range) then
						if(GetDistance(myHero, tar)<= E.Range) then
							--If we are on top of the target, dont worry about collision
							CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q})
						else
							--We need to make sure we dont hit minions
							CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, maxCollision = 1})

						end
					end
				end
			else
				local tar = GetTarget(Q2Range)
				if(IsValid(tar) and GetDistance(tar, myHero) <= Q2Range) then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end

	if(self.Menu.Combo.UseW:Value()) then
		if(myHero.levelData.lvl >= self.Menu.Combo.UseWMelee:Value() and Ready(_W)) then
			local tar = GetTarget(E.Range)
			if(IsValid(tar)) then
				Control.CastSpell(HK_W, tar)
			end
		end
	end

	if(self.Menu.Combo.UseE:Value()) then
		if(Ready(_E)) then
			local tar = GetTarget(E.Range + 250)
			if(IsValid(tar) and GetDistance(tar, myHero) <= E.Range + tar.boundingRadius) then
				Control.CastSpell(HK_E, tar)
			end
		end
	end

	if(self.Menu.Combo.HextechSettings.Enabled:Value()) then

		local hasHexbelt, hexbeltSlot = self:HasHextechRocketbelt()
		if(hasHexbelt) then
			local tar = GetTarget(1000)
			if(IsValid(tar)) then
				local predData = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Range = 1000, Radius = 60, Speed = 2400}

				--Use for killing
				if(self.Menu.Combo.HextechSettings.UseKill:Value()) then
					if not (MapPosition:intersectsWall(myHero.pos, tar.pos)) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, tar.pos, predData.Speed, predData.Delay, predData.Radius, {GGPrediction.COLLISION_ENEMYHERO, GGPrediction.COLLISION_MINION}, tar.networkID)
						if(collisionCount == 0) then
							local beltDmg = GetItemDamage(Item.HextechRocketbelt)
							beltDmg = CalcMagicalDamage(myHero, tar, beltDmg)

							if(tar.health - beltDmg <= 0) then
								Control.CastSpell(ItemHotKey[hexbeltSlot], tar.pos)
								return
							end
						end
					end
				end

				--Use for gap closing
				if(self.Menu.Combo.HextechSettings.UseGapclose:Value()) then
					if(GetDistance(myHero.pos, tar.pos) <= E.Range + tar.boundingRadius + 300 and GetDistance(myHero.pos, tar.pos) >= E.Range - 75) then
						if not (MapPosition:intersectsWall(myHero.pos, tar.pos)) then

							local safetyCheck = true
							if(myHero.health/myHero.maxHealth <= 0.3) then
								safetyCheck = false
							end

							--Dont hexteck towards tanks if low HP
							if(myHero.health/myHero.maxHealth <= 0.5 and (tar.health - myHero.health)>1000 and tar.maxHealth>=3300) then
								safetyCheck = false
							end

							local isCharmed, charmDuration = self:IsUnitCharmed(tar)
							local isCastingCharm = myHero.activeSpell.valid and myHero.activeSpell.name == "EvelynnWApplyMark"
							if((isCharmed or isCastingCharm) and charmDuration < 2.5) then
								safetyCheck = false
							end

							if(safetyCheck) then
								Control.CastSpell(ItemHotKey[hexbeltSlot], tar.pos)
								return
							end
						end			
					end
				end

				--Use in Melee
				if(self.Menu.Combo.HextechSettings.UseMelee:Value()) then
					if(GetDistance(myHero.pos, tar.pos) <= E.Range) then
						Control.CastSpell(ItemHotKey[hexbeltSlot], tar.pos)
						return		
					end
				end


			end
		end

	end

	if(self:HasSmite() and self:HasOffensiveSmite()) then
		if(self.Menu.Combo.SmiteSettings.Enabled:Value() and Ready(self.SmiteSlot)) then
			local chargeCheck = true
			if(self.Menu.Combo.SmiteSettings.KeepCharge:Value()) then
				if(myHero:GetSpellData(self.SmiteSlot).ammoCurrentCd <= 15 or myHero:GetSpellData(self.SmiteSlot).ammo == 2) then
					chargeCheck = true
				else
					chargeCheck = false
				end
			end

			if(chargeCheck) then

				--Use smite to kill
				if(self.Menu.Combo.SmiteSettings.UseKill:Value()) then
					local tar = GetTarget(500) -- Smite Range
					if(IsValid(tar)) then
						if(tar.health - self:GetSmiteDamage(tar) <= 0) then
							Control.CastSpell(self.SmiteCastSlot, tar)
						end
					end
				end

				--Use smite to bring into R kill range
				if(self.Menu.Combo.SmiteSettings.UseRKillRange:Value() and Ready(_R)) then
					local tar = GetTarget(500) -- Smite Range
					if(IsValid(tar)) then
						local referenceHealth = (tar.health - self:GetSmiteDamage(tar))
						if(tar.health/tar.maxHealth > 0.3 and referenceHealth/tar.maxHealth <= 0.3) then
							if(GetDistance(myHero, tar) <= 375) then --Make sure the target is closer for a guaranteed R hit.
								Control.CastSpell(self.SmiteCastSlot, tar)
							end
						end
					end
				end
			end
		end
	end
end

function Evelynn:Harass()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.Harass.UseQ:Value()) then
		if(Ready(_Q)) then
			if(myHero:GetSpellData(_Q).name == "EvelynnQ") then
				local tar = GetTarget(Q.Range - 15)
				if(IsValid(tar) and GetDistance(tar, myHero) <= Q.Range) then

					local charmCheck = true
					local isCharmed, charmDuration = self:IsUnitCharmed(tar)
					local isCastingCharm = myHero.activeSpell.valid and myHero.activeSpell.name == "EvelynnWApplyMark"
					local predPos = GetPrediction(tar, Q.Speed, Q.Delay) or tar.pos
					if((isCharmed or isCastingCharm) and charmDuration < 2.5 - (GetDistance(myHero, predPos)/Q.Speed + Q.Delay - 0.1)) then
						charmCheck = false
					end

					if(charmCheck or GetDistance(myHero, tar)<= E.Range) then
						CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, maxCollision = 1})
					end
				end
			else
				local tar = GetTarget(Q2Range)
				if(IsValid(tar) and GetDistance(tar, myHero) <= Q2Range) then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function Evelynn:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.LastHit.UseE:Value() and Ready(_E)) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(E.Range) --Just do 1 check for optimization
		local canonMinion = GetCanonMinion(minions)
		
		--Prioritize the canon minion if its low
		if(canonMinion ~= nil) and IsValid(canonMinion) then
			local EDam = self:GetRawAbilityDamage("E", canonMinion)
			
			if ((canonMinion.health > 0) and (canonMinion.health + (canonMinion.health*0.05) - EDam <= 0)) and GetDistance(myHero, canonMinion) <= E.Range then
				Control.CastSpell(HK_E, canonMinion)
				return
			end
		end
	end
end

function Evelynn:Clear()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
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

local jungleBigMonsters = 
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
	["SRU_Dragon_Hextech"]= 1,
	["SRU_Blue"]= 1,
	["SRU_Red"]= 1,
	["SRU_Gromp"]= 1,
	["SRU_Murkwolf"]= 1,
	["SRU_Razorbeak"]= 1,
	["SRU_Krug"]= 1,
	["Sru_Crab"]= 1
}

function Evelynn:JungleClear(minions)
	if(self.Menu.Clear.Jungle.WaitCharm:Value()) then
		local minionCharmed = false
		for _, minion in pairs(minions) do
			if(IsValid(minion)) then
				local charmedStatus, charmedDuration = self:IsUnitCharmed(minion)
				local isCastingCharm = myHero.activeSpell.valid and myHero.activeSpell.name == "EvelynnWApplyMark"
				if((charmedStatus or isCastingCharm) and charmedDuration < 2.5 - (GetDistance(minion, myHero)/Q.Speed + Q.Delay - 0.1)) then
					minionCharmed = true
					break
				end
			end
		end

		if(minionCharmed == true) then
			return
		end
	end
	
	if(self.Menu.Clear.Jungle.UseQ:Value() and Ready(_Q)) then
		local focusCreep = nil
		if(#minions > 1) then
			for _, minion in pairs(minions) do
				if(IsValid(minion)) then
					if(jungleBigMonsters[minion.charName]==1 and GetDistance(myHero, minion) <= Q.Range) then
						focusCreep = minion
						break
					end
				end
			end
		end

		if(focusCreep) and myHero:GetSpellData(_Q).name == "EvelynnQ" and GetDistance(myHero, focusCreep) <= Q.Range then
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, focusCreep.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION}, focusCreep.networkID)
			if(collisionCount == 0) then
				Control.CastSpell(HK_Q, focusCreep.pos)
			else
				if(focusCreep.health/focusCreep.maxHealth<= 0.8 or focusCreep.attackData.target == myHero.handle) then
					for _, minion in pairs(minions) do
						if(IsValid(minion) and Ready(_Q)) then
							if(GetDistance(myHero, minion) < Q2Range) then
								Control.CastSpell(HK_Q, minion.pos)
								break
							end
						end
					end		
				end
			end
		else
			for _, minion in pairs(minions) do
				if(IsValid(minion) and Ready(_Q)) then
					if(myHero:GetSpellData(_Q).name == "EvelynnQ") then
						if(GetDistance(myHero, minion) < Q.Range-15) then
							Control.CastSpell(HK_Q, minion.pos)
							break
						end
					else
						if(GetDistance(myHero, minion) < Q2Range) then
							Control.CastSpell(HK_Q, minion.pos)
							break
						end
					end
				end
			end
		end
	end

	if(self.Menu.Clear.Jungle.UseE:Value() and Ready(_E)) then
		local focusCreep = nil
		if(#minions > 1) then
			for _, minion in pairs(minions) do
				if(IsValid(minion)) then
					if(jungleBigMonsters[minion.charName]==1 and GetDistance(myHero, minion) <= E.Range) then
						focusCreep = minion
						break
					end
				end
			end
		end

		if(focusCreep and IsValid(focusCreep) and Ready(_E)) then
			Control.CastSpell(HK_E, focusCreep)
			return
		end

		for _, minion in pairs(minions) do
			if(IsValid(minion)) and Ready(_E) then
				if(GetDistance(myHero, minion) <= E.Range - 10) then
					Control.CastSpell(HK_E, minion)
					break
				end
			end
		end
	end
end

function Evelynn:LaneClear(minions)

	if(self.Menu.Clear.Lane.UseE:Value() and Ready(_E)) then
		local canonMinion = GetCanonMinion(minions)
		--Prioritize the canon minion if its low
		if(canonMinion ~= nil) and IsValid(canonMinion) then
			local EDam = self:GetRawAbilityDamage("E", canonMinion)
			
			if ((canonMinion.health > 0) and (canonMinion.health + (canonMinion.health*0.05) - EDam <= 0)) and GetDistance(myHero, canonMinion) <= E.Range then
				Control.CastSpell(HK_E, canonMinion)
				return
			end
		end
	end

	if(self.Menu.Clear.Lane.UseQ:Value() and Ready(_Q)) then
		local shouldUseClearSkills = true

		local champCheck, levelCheck, manaCheck = true, true, true
		if(self.Menu.Clear.Lane.ChampCheck:Value()) then
			local numEnemies = GetEnemyCount(1500, myHero)
			if(numEnemies ~= 0) then
				champCheck = false
			end
		end

		if(myHero.levelData.lvl < self.Menu.Clear.Lane.LevelCheck:Value()) then
			levelCheck = false
		end

		if(myHero.mana/myHero.maxMana < (self.Menu.Clear.Lane.QMinMana:Value()/100)) then
			manaCheck = false
		end

		shouldUseClearSkills = (levelCheck or champCheck) and manaCheck

		if shouldUseClearSkills then
			for _, minion in pairs(minions) do
				if(IsValid(minion)) then
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, (GetDistance(myHero, minion)/Q.Speed))
					local qDmg = self:GetRawAbilityDamage("Q")
					if(hp>0 and (hp-qDmg > myHero.totalDamage or hp-qDmg <= 0) and GetDistance(minion, myHero) <= Q2Range) then
						Control.CastSpell(HK_Q, minion.pos)
					end
				end
			end
		end
	end
end

function Evelynn:KillSteal()
	--R
	if(self.Menu.KillSteal.UseR:Value()) then
		if(Ready(_R)) then
			local enemies = GetEnemyHeroes(R.Radius - 100)
			if(#enemies > 0) then
				for _, enemy in pairs(enemies) do
					if(enemy and IsValid(enemy)) then
						if((CantKill(enemy, true, false, false, true)==false)) then
							local dmg = self:GetRawAbilityDamage("R")
							if(enemy.health/enemy.maxHealth <= 0.3) then
								dmg = self:GetRawAbilityDamage("RExecute")
							end
							dmg = CalcMagicalDamage(myHero, enemy, dmg)
							local castPos = self:GenerateCastUltDirection(enemy)

							if(#enemies == 1) then --We can KS on solo targets
								if(enemy.health - dmg < 0) then
									local shouldCast = true
									if(self.Menu.KillSteal.ROverkillProtection:Value()) then
										if(self:IsROverkill(enemy)) then
											shouldCast = false
										end
									end

									if(shouldCast) then
										Control.CastSpell(HK_R, castPos)
										return
									end
								end
							else
								if(self.Menu.KillSteal.RBlacklist[enemy.charName]) then
									if(self.Menu.KillSteal.RBlacklist[enemy.charName]:Value() == false) then
										if(enemy.health - dmg < 0) then

											local shouldCast = true
											if(self.Menu.KillSteal.ROverkillProtection:Value()) then
												if(self:IsROverkill(enemy)) then
													shouldCast = false
												end
											end

											if(shouldCast) then
												Control.CastSpell(HK_R, castPos)
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
end

function Evelynn:CalculateDragonMitigation()
	--Hacky fix.
	--[[
		First dragon spawns at 5 mins, assuming they are perfectly killed the next one would be at 10 mins and provide the 7% mitigation.
		This assumes all dragons will be killed by 25mins, if they aren't then the mitigation will act as a buffer.
	]]
	local bonus = math.min(math.floor(math.max(0, GameTimer() - 300) / 300) * 7, 28)
	return bonus/100
end

function Evelynn:SemiManualW()
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	if(Ready(_W)) then
		if(GetMode() == "Combo") then
			local enemies = GetEnemyHeroes(self:GetWRange())
			local tar = GetTarget(self:GetWRange())
			local closestTar = nil
			if(#enemies > 0) then
				closestTar = GetClosestUnitToCursor(enemies)
			end

			if(closestTar and IsValid(closestTar)) then
				Control.CastSpell(HK_W, closestTar)
			else
				if(IsValid(tar)) then
					Control.CastSpell(HK_W, tar)
				end
			end
		end
	end
end

function Evelynn:DnBKillsteal()
	_G.SDK.Orbwalker:Orbwalk()

	local flashRange = 400
	local smiteRange = 500
	local smiteNames = {
		["SRU_Dragon_Elder"]=1, 
		["SRU_Dragon_Water"]=1, 
		["SRU_Dragon_Fire"]=1, 
		["SRU_Dragon_Earth"]=1, 
		["SRU_Dragon_Air"]=1, 
		["SRU_Dragon_Ruined"]=1, 
		["SRU_Dragon_Chemtech"]=1, 
		["SRU_Dragon_Hextech"]=1,
		["SRU_RiftHerald"]=1,
		["SRU_Baron"]=1,
	}
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(flashRange + smiteRange + 200)

	local monster = nil
	if(#minions > 0) then
		for _, minion in pairs(minions) do
			if(IsValid(minion)) then
				if(smiteNames[minion.charName] == 1) then
					monster = minion
					break;
				end
			end
		end
	end

	if(monster) then
		local isDragon = false
		if(monster.charName == "SRU_Baron" or monster.charName == "SRU_RiftHerald") then
			isDragon = true
		end
		local monsterExecuteHP = monster.maxHealth*0.3
		local isCharmed, charmDuration = self:IsUnitCharmed(monster)
		--Calculate our combo's damage
		local totalDmgExecute = 0

		local WDmg = 0
		if(Ready(_W) or isCharmed) then
			WDmg = self:GetRawAbilityDamage("WMinion")
			WDmg = CalcMagicalDamage(myHero, monster, WDmg)
			WDmg = WDmg * (1 - self:CalculateDragonMitigation())
		end

		local RDmgExecute = self:GetRawAbilityDamage("RExecute")
		RDmgExecute = CalcMagicalDamage(myHero, monster, RDmgExecute)
		RDmgExecute = RDmgExecute * (1 - self:CalculateDragonMitigation())
		totalDmgExecute = totalDmgExecute + RDmgExecute


		local smiteDmg = self:GetSmiteDamage(monster)
		totalDmgExecute = totalDmgExecute + smiteDmg

		totalDmgExecute = totalDmgExecute - 100 --Buffer

		if(Ready(_W) and not isCharmed) then
			if(monster.health < totalDmgExecute + WDmg and monster.health < monsterExecuteHP) then
				Control.CastSpell(HK_W, monster)
				isCharmed = true
			end
		end

		--
		if(monster.health < monsterExecuteHP) then
			local shouldWaitCharm = false
			local charmCheck = isCharmed or (myHero.activeSpell.valid and myHero.activeSpell.name == "EvelynnWApplyMark")
			if(charmCheck) then
				shouldWaitCharm = true

				--Go in for the steal if waiting for the charm is pointless
				if(monster.health - totalDmgExecute < 0) then
					shouldWaitCharm = false
				end

				if(charmDuration >= 2.5) then
					shouldWaitCharm = false
					totalDmgExecute = totalDmgExecute + WDmg
				end
			end

			if(monster.health - totalDmgExecute < 0 and shouldWaitCharm == false) then

				--Flash
				if(self.Menu.DnBStealer.UseFlash:Value()) then
					if(CanFlash()) then
						if(GetDistance(myHero, monster) >= 500 and GetDistance(myHero, monster) < 900) then
							UseFlash(monster.pos)
						end
					end
				end

				if(GetDistance(myHero, monster) <= smiteRange) then
					if(Ready(_R) and myHero.isChanneling == false) then
						Control.CastSpell(HK_R, monster.pos)

						DelayEvent(function ()
							if(Ready(self.SmiteSlot)) then
								Control.CastSpell(self.SmiteCastSlot, monster)
							end
						end, R.Delay)
					end
				end
			end
		end

		--Drawing portion
		if(self.Menu.DnBStealer.DrawUI:Value()) then
			self:DrawEpicMonsterHealth(monster, totalDmgExecute + WDmg)
		end

		--Smite Range
		if(self.Menu.DnBStealer.DrawSmiteRange:Value()) then
			DrawCircle(myHero.pos, 500, 3, DrawColor(255, 234, 237, 21))
		end
	end

end

function Evelynn:DrawEpicMonsterHealth(monster, totalDamage)

	if(monster.toScreen.onScreen) then
		local bar = monster.pos:To2D()
		local barLength = 200
		local barHeight = 8
		local barOffset = 100
		local hpRatio = (monster.health / monster.maxHealth)
		local executeRatio = ((monster.maxHealth*0.3) / monster.maxHealth)
		local dmg = totalDamage
		local dmgRatio = math.min(dmg / monster.maxHealth, executeRatio)
		if(monster.health - dmg <= 0) then
			dmgRatio = hpRatio
		end
		--Bar BG
		Draw.Rect(bar.x - (barLength/2) -3, bar.y + barOffset - 3, barLength +6, barHeight + 6, DrawColor(225, 0, 0, 0))
		
		--Health bar
		Draw.Rect(bar.x - (barLength/2), bar.y + barOffset, barLength * (hpRatio - 0.02), barHeight, DrawColor(255, 21, 232, 130))
	
		--Damage bar
		Draw.Rect(bar.x - (barLength/2), bar.y + barOffset, barLength * dmgRatio, barHeight, DrawColor(255, 255, 45, 115))

		if(Ready(_R)) then
			Draw.Rect(bar.x - (barLength/2) + (barLength * executeRatio), bar.y + barOffset, 4, barHeight, DrawColor(255, 0, 0, 0))
		end
	end

end

function Evelynn:HasSmite()
	if(self.SmiteSlot and self.SmiteCastSlot) then return true end

	return false
end

function Evelynn:HasOffensiveSmite()

	local smiteName = myHero:GetSpellData(self.SmiteSlot).name
	if(smiteName == "SummonerSmiteAvatarOffensive" or smiteName == "SummonerSmiteAvatarUtility" or smiteName == "SummonerSmiteAvatarDefensive" or smiteName == "S5_SummonerSmitePlayerGanker") then
		return true
	end

	return false
end

function Evelynn:GetSmiteDamage(unit)
	local SmiteDamage = 600
	local SmiteUnleashedDamage = 900
	local SmitePrimalDamage = 1200
	local SmiteAdvDamageHero = 80 + 80 / 17 * (myHero.levelData.lvl - 1)
	if unit.type ~= Obj_AI_Hero then
		if myHero:GetSpellData(self.SmiteSlot).name == "SummonerSmite" then
			return SmiteDamage
		elseif myHero:GetSpellData(self.SmiteSlot).name == "S5_SummonerSmiteDuel" or
			myHero:GetSpellData(self.SmiteSlot).name == "S5_SummonerSmitePlayerGanker" then
			return SmiteUnleashedDamage
		elseif myHero:GetSpellData(self.SmiteSlot).name == 'SummonerSmiteAvatarOffensive' or
			myHero:GetSpellData(self.SmiteSlot).name == 'SummonerSmiteAvatarUtility' or
			myHero:GetSpellData(self.SmiteSlot).name == 'SummonerSmiteAvatarDefensive' then
			return SmitePrimalDamage
		end
	elseif unit.type == Obj_AI_Hero then
		if myHero:GetSpellData(self.SmiteSlot).name == "S5_SummonerSmiteDuel" or
			myHero:GetSpellData(self.SmiteSlot).name == "S5_SummonerSmitePlayerGanker" then
			return SmiteAdvDamageHero
		elseif myHero:GetSpellData(self.SmiteSlot).name == 'SummonerSmiteAvatarOffensive' or
			myHero:GetSpellData(self.SmiteSlot).name == 'SummonerSmiteAvatarUtility' or
			myHero:GetSpellData(self.SmiteSlot).name == 'SummonerSmiteAvatarDefensive' then
			return SmiteAdvDamageHero
		end
	else return 0 end
end

function Evelynn:IsEmpowered()
	return (myHero:GetSpellData(_E).name == "EvelynnE2")
end

function Evelynn:IsInStealth()
	if(not myHero.dead) then
		for i = 0, myHero.buffCount do
			local buff = myHero:GetBuff(i)	

			if buff.name:lower():find("evelynnstealthring") and buff.count > 0 then 
				return true
			end
		end
	end

	return false
end

function Evelynn:IsUnitCharmed(unit)
	if(IsValid(unit)) then
		for i = 0, unit.buffCount do
			local buff = unit:GetBuff(i)	
	
			if buff.name:lower()=="evelynnw" and buff.count > 0 then 
				return true, (GameTimer() - buff.startTime)
			end
		end
	end

	return false, 0
end

function Evelynn:IsUnitQMarked(unit)
	if(IsValid(unit)) then
		for i = 0, unit.buffCount do
			local buff = unit:GetBuff(i)
			if buff.name == "evelynnqdebuff" and buff.count > 0 then
				return true
			end
		end
	end

	return false
end

function Evelynn:IsROverkill(unit)
	--[[
		Conditions for an overkill, using R when:
		- The target is less than 100 HP and theres an ally within range of the target.
			- Check if the ally is ranged or melee
		- When you are within range of your E and it will kill. Your E has to either be up, or up within 0.5 seconds.
		- When the target has less than 100 health and your Q2 will kill them while in Q2 range.
	]]
	--Condition 1:
	if(unit.health <= 100) then
		for _, ally in ipairs(Allies) do
			if(IsValid(ally)) then
				if(GetDistance(ally, unit) <= ally.range) then
					return true
				end
			end
		end
	end

	--Condition 2:
	if(GetDistance(myHero, unit) <= E.Range) then
		if(Ready(_E) or myHero:GetSpellData(_E).currentCd <= 0.5) then
			local eDmg = self:GetRawAbilityDamage("E", unit)
			eDmg = CalcMagicalDamage(myHero, unit, eDmg)
			if(unit.health - eDmg <= 0) then
				return true
			end
		end
	end

	--Condition 3:
	if(unit.health <= 100) then
		if(myHero:GetSpellData(_Q).name ~= "EvelynnQ") and GetDistance(myHero, unit) <= Q2Range then
			local q2Dmg = self:GetRawAbilityDamage("Q")
			q2Dmg = CalcMagicalDamage(myHero, unit, q2Dmg)

			local qBonusDmg = self:GetRawAbilityDamage("QBonus")
			qBonusDmg = CalcMagicalDamage(myHero, unit, qBonusDmg)

			if(self:IsUnitQMarked(unit)) then
				q2Dmg = q2Dmg + qBonusDmg
			end

			if(unit.health - q2Dmg <= 0) then
				return true
			end
		end
	end

	return false
end

function Evelynn:GetWRange()
	local range = ({1200, 1300, 1400, 1500, 1600})[myHero:GetSpellData(_W).level]
	return range
end

function Evelynn:HasHextechRocketbelt()
    return HasItem({Item.HextechRocketbelt, Item.UpgradedAeropack})
end

function Evelynn:GetRawAbilityDamage(spell, tar)
	if(spell == "Q") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		return ({25, 30, 35, 40, 45})[myHero:GetSpellData(_Q).level] + (0.30 * myHero.ap)
	end

	if(spell == "QBonus") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		return ({15, 25, 35, 45, 55})[myHero:GetSpellData(_Q).level] + (0.25 * myHero.ap)
	end

	if(spell == "WMinion") then
		if myHero:GetSpellData(_W).level == 0 then return 0 end
		return ({250, 300, 350, 400, 450})[myHero:GetSpellData(_W).level] + (0.6 * myHero.ap)
	end

	if(spell == "E") then
		if myHero:GetSpellData(_E).level == 0 then return 0 end
		if(tar and IsValid(tar)) then
			if(self:IsEmpowered()) then
				local healthRatio = tar.maxHealth * (((myHero.ap/100)*2.5) + 4)/100
				return ({75, 100, 125, 150, 175})[myHero:GetSpellData(_E).level] + math.floor(healthRatio + 0.5)	
			else
				local healthRatio = tar.maxHealth * (((myHero.ap/100)*1.5) + 3)/100
				return ({55, 75, 85, 100, 115})[myHero:GetSpellData(_E).level] + math.floor(healthRatio + 0.5)
			end
		end
	end
	
	if(spell == "R") then
		if myHero:GetSpellData(_R).level == 0 then return 0 end
		return ({125, 250, 375})[myHero:GetSpellData(_R).level] + (0.75 * myHero.ap)
	end

	if(spell == "RExecute") then
		if myHero:GetSpellData(_R).level == 0 then return 0 end
		return ({300, 600, 900})[myHero:GetSpellData(_R).level] + (1.8 * myHero.ap)
	end

	return 0
end

function Evelynn:ManualKeys()
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
function Evelynn:UpdateComboDamage()
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

function Evelynn:GetTotalDamage(unit)
	local totalDmg = 0

	--Q
	local QDmg = self:GetRawAbilityDamage("Q")*4 + self:GetRawAbilityDamage("QBonus")*3
	QDmg = CalcMagicalDamage(myHero, unit, QDmg)
	totalDmg = totalDmg + QDmg

	--E
	if(Ready(_E)) then
		local EDmg = self:GetRawAbilityDamage("E", unit)
		EDmg = CalcMagicalDamage(myHero, unit, EDmg)
		totalDmg = totalDmg + EDmg
	end

	--R
	if(Ready(_R)) then
		local RDmg = self:GetRawAbilityDamage("R")
		if(unit.health/unit.maxHealth <= 0.3) then
			RDmg = self:GetRawAbilityDamage("RExecute")
		end
		RDmg = CalcMagicalDamage(myHero, unit, RDmg)

		totalDmg = totalDmg + RDmg
	end

	--Belt
	if(self:HasHextechRocketbelt()) then
		local beltDmg = GetItemDamage(Item.HextechRocketbelt)
		beltDmg = CalcMagicalDamage(myHero, unit, beltDmg)
		totalDmg = totalDmg + beltDmg
	end

	--Electrocute
	if HasElectrocute() then
		local elecDmg = GetElectrocuteDamage()
		elecDmg = CalcMagicalDamage(myHero, unit, elecDmg)
		totalDmg= totalDmg + elecDmg
	end
	
	totalDmg = totalDmg + CalcPhysicalDamage(myHero, unit, myHero.totalDamage)

	return totalDmg
end

function Evelynn:IsExecutable(unit)
	local isKillable = false

	if(self.ComboDamageData[unit.networkID] ~= nil) then	
		local dmg = self.ComboDamageData[unit.networkID]

		if(Ready(_R)) then

			local RDmg = self:GetRawAbilityDamage("R")
			if(unit.health/unit.maxHealth <= 0.3) then
				RDmg = self:GetRawAbilityDamage("RExecute")
			end
			RDmg = CalcMagicalDamage(myHero, unit, RDmg)

			if(unit.health - RDmg <= 0) then
				isKillable = true
			end
		end
	end
	return isKillable
end

-- [[ DRAWINGS ]] --

local alphaLerp = 0
local qDrawSize = Q.Range
function Evelynn:Draw()
	if myHero.dead then return end

	--Placing this in Draw for better accuracy
	if self.Menu.DnBStealer.StealDragon:Value() then
		self:DnBKillsteal()
	end

	if(self.Menu.Drawings.DrawQ:Value()) then

		local rangeCheck = Q.Range
		if(self.Menu.Combo.UseQStealth:Value()) then
			if(self:IsInStealth()) then
				rangeCheck = 700
			end
		end

		if(myHero:GetSpellData(_Q).name == "EvelynnQ") then
			qDrawSize = Lerp(qDrawSize, rangeCheck, 0.1)
		else
			qDrawSize = Lerp(qDrawSize, Q2Range, 0.1)
		end
		if(myHero:GetSpellData(_Q).name == "EvelynnQ") then
			DrawCircle(myHero.pos, qDrawSize, 1, DrawColor(125, 204, 28, 252))
		else
			DrawCircle(myHero.pos, qDrawSize, 1, DrawColor(255, 242, 40, 252))
		end
	end

	if(self.Menu.Drawings.DrawE:Value()) then
		if(Ready(_E)) then
			DrawCircle(myHero.pos, E.Range, 1, DrawColor(255, 209, 36, 85))
		else
			DrawCircle(myHero.pos, E.Range, 1, DrawColor(35, 209, 36, 85))
		end
	end

	if(self.Menu.Drawings.DrawHextech:Value()) then
		if(GetMode() == "Combo") then
			self:DrawHextechLeap()
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

	if(self.Menu.Drawings.DrawKillableTargets:Value()) then
		self:DrawKillable()
	end

end

local function remap(val, low1, high1, low2, high2)
	return math.max(low2, low2 + (val - low1) * (high2 - low2) / (high1 - low1))
end

function Evelynn:DrawHextechLeap()
	local searchRange = 1200
	if(self:HasHextechRocketbelt()) then

		local closetTarget = nil
		local targets = GetEnemyHeroes(searchRange)
		for _, target in ipairs(targets) do
			if(closetTarget == nil) then
				closetTarget = target
			end
			if(GetDistance(myHero, target) <= GetDistance(myHero, closetTarget)) then
				closetTarget = target
			end
		end

		if(closetTarget and IsValid(closetTarget)) then
			local fade = 1 - remap(GetDistance(myHero, closetTarget), searchRange-100, searchRange, 0, 1)
			local lineStart = closetTarget.pos:Extended(myHero.pos, E.Range + 300)
			if(GetDistance(myHero, closetTarget) >= E.Range + 300) then
				local UIColor = {a = 255 * fade, r = 255, g = 25, b = 215}
				self:DrawDotLines(myHero.pos, lineStart, 1000, UIColor, 6)
				DrawLine(lineStart:To2D(), closetTarget.pos:To2D(), DrawColor(35 * fade, 255, 255, 255))
				DrawCircle(lineStart, 5, 15, DrawColor(UIColor.a, UIColor.r, UIColor.g, UIColor.b))
				DrawCircle(myHero.pos, 10, 10, DrawColor(UIColor.a, UIColor.r, UIColor.g, UIColor.b))
			end
		end
	end
end

function Evelynn:DrawDotLines(pos1, pos2, visibleRange, color, lineCount)
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

function Evelynn:DrawDamageHPBars()
	for _, enemy in pairs(Enemies) do
		if(enemy.valid and IsValid(enemy)) then
			if(enemy.toScreen.onScreen) then
				if(Ready(_Q) or Ready(_E)) then
					local bar = enemy.pos:To2D()
					local barLength = 150
					local barHeight = 4
					local barOffset = self.Menu.Drawings.DamageHPBar.YOffset:Value()
					local hpRatio = (enemy.health / enemy.maxHealth)
					local executeRatio = ((enemy.maxHealth*0.3) / enemy.maxHealth)
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

					if(Ready(_R)) then
						-- Execute Tick
						Draw.Rect(bar.x - (barLength/2) + (barLength * executeRatio), bar.y + barOffset, 4, barHeight, DrawColor(255 * alphaLerp, 0, 0, 0))
					end
				end
			end
		end
	end
end

function Evelynn:DrawKillable()
	local enemies = GetEnemyHeroes(3000)
	if(#enemies > 0) then
		for _, enemy in pairs(enemies) do
			if(enemy.valid and IsValid(enemy)) then
				if(self:IsExecutable(enemy)) then
					self:DrawKillReticle(enemy)
				end
			end
		end
	end
end

function Evelynn:DrawKillReticle(unit)
	local reticleRadius = 75
	local speed = 135
	local newPos = Vector(unit.pos.x, unit.pos.y + 15, unit.pos.z)
	DrawCircle(unit, reticleRadius, 2, DrawColor(255, 255, 33, 240))
	local angle = ((GetTickCount() / 1000) % 360) * speed
	
	local vec1 = (Vector(math.cos(math.rad(angle)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle)) + unit.pos.z) - unit.pos):Normalized()
	local vec2 = (Vector(math.cos(math.rad(angle + 90)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 90)) + unit.pos.z) - unit.pos):Normalized()
	local vec3 = (Vector(math.cos(math.rad(angle + 180)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 180)) + unit.pos.z) - unit.pos):Normalized()
	local vec4 = (Vector(math.cos(math.rad(angle + 270)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 270)) + unit.pos.z) - unit.pos):Normalized()
	
	
	DrawLine((unit.pos + (vec1 * (reticleRadius - 20))):To2D(), (unit.pos + (vec1 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 33, 240))
	DrawLine((unit.pos + (vec2 * (reticleRadius - 20))):To2D(), (unit.pos + (vec2 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 33, 240))
	DrawLine((unit.pos + (vec3 * (reticleRadius - 20))):To2D(), (unit.pos + (vec3 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 33, 240))
	DrawLine((unit.pos + (vec4 * (reticleRadius - 20))):To2D(), (unit.pos + (vec4 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 33, 240))
end

Evelynn()
LoadUnits()
