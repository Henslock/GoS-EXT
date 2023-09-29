require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.02

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Nocturne will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()


----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Nocturne"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/nocturne.png"

local gameTick = GameTimer()

local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6,}

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 1100, Radius = 150, Speed = 1600}
local E = {Delay = 0, Range = 425}
local R = {Delay = 0, Range = 2500}

local ITEM_IRONSPIKEWHIP = 6029
local ITEM_STRIDEBREAKER = 6631
local ITEM_DREAMSHATTER = 7016

local SmiteNames = {
	["SummonerSmite"]=1,
	["S5_SummonerSmitePlayerGanker"]=1,
	["SummonerSmiteAvatarOffensive"]=1,
	["SummonerSmiteAvatarUtility"]=1,
	["SummonerSmiteAvatarDefensive"]=1,
}

Nocturne.SmiteSlot = nil
Nocturne.SmiteCastSlot = nil

Nocturne.ComboDamageData = {}

--Main Menu
Nocturne.Menu = MenuElement({type = MENU, id = "KillerNocturne", name = "Killer Nocturne", leftIcon=ChampIcon})
Nocturne.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})


function Nocturne:__init()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)

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

function Nocturne:LoadMenu()                  	
	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "UseStridebreaker", name = "Use Stridebreaker", value = true})
	self.Menu.Combo:MenuElement({id = "SmiteSettings", name = "Smite Settings", type = MENU})

	-- Smite Settings
	self.Menu.Combo.SmiteSettings:MenuElement({id = "Enabled", name = "Use Smite Offensively", value = true})
	self.Menu.Combo.SmiteSettings:MenuElement({id = "KeepCharge", name = "Keep 1 Charge", value = true})
	self.Menu.Combo.SmiteSettings:MenuElement({id = "UseKill", name = "Use to Kill", value = true})

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "Lane", name = "Lane", type = MENU})
	self.Menu.Clear:MenuElement({id = "Jungle", name = "Jungle", type = MENU})

	-- Flee
	self.Menu:MenuElement({id = "Flee", name = "Flee", type = MENU})
	self.Menu.Flee:MenuElement({id = "UseQ", name = "Use Q at Cursor", value = true})

	-- Lane Clear
	self.Menu.Clear.Lane:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "QMinMana", name = "Q Minimum Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear.Lane:MenuElement({id = "UseStridebreaker", name = "Use Stridebreaker", value = true})

	-- Jungle Clear
	self.Menu.Clear.Jungle:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "UseStridebreaker", name = "Use Stridebreaker", value = true})

	self.Menu:MenuElement({id = "AutoW", name = "Auto W", type = MENU})
	self.Menu.AutoW:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.AutoW:MenuElement({id = "Humanizer", name = "Humanizer", value = true})
	self.Menu.AutoW:MenuElement({id = "BlockTargetted", name = "Block Targetted", value = true})
	self.Menu.AutoW:MenuElement({id = "BlockNonTargetted", name = "Block Non-Targetted", value = true})
	self.Menu.AutoW:MenuElement({id = "Whitelist", name = "Whitelist", type = MENU})

	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		self.Menu.AutoW.Whitelist:MenuElement({id = args.charName, name = args.charName, type = MENU})

		self.Menu.AutoW.Whitelist[args.charName]:MenuElement({id = args.unit:GetSpellData(_Q).name, name = "Q", value = true})
		self.Menu.AutoW.Whitelist[args.charName]:MenuElement({id = args.unit:GetSpellData(_W).name, name = "W", value = true})
		self.Menu.AutoW.Whitelist[args.charName]:MenuElement({id = args.unit:GetSpellData(_E).name, name = "E", value = true})
		self.Menu.AutoW.Whitelist[args.charName]:MenuElement({id = args.unit:GetSpellData(_R).name, name = "R", value = true})

	end)

	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawE", name = "Draw E Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawR", name = "Draw R Range on Minimap", value = true})
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
	
end

function Nocturne:UpdateGoSMenuAutoLevel()
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

function Nocturne:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Nocturne:Tick()
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
		self:Flee()
	elseif(mode == "Harass") then
		self:Harass()
	elseif(mode == "LastHit") then
		self:LastHit()
	elseif(mode == "LaneClear") then
		self:Clear()
	end

	self:ManualKeys()
	self:UpdateComboDamage()

	if(self.Menu.AutoW.Enabled:Value()) then
		self:AutoW()
	end

	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end

function Nocturne:Combo()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.Combo.UseQ:Value() and Ready(_Q)) then
		local tar = GetTarget(Q.Range)
		if(IsValid(tar) and GetDistance(myHero, tar) < Q.Range - 100) then
			CastPredictedSpell(HK_Q, tar, Q, false, 0, 110, true)
		end
	end

	if(self.Menu.Combo.UseE:Value() and Ready(_E)) then
		local tar = GetTarget(E.Range)
		if(IsValid(tar) and GetDistance(myHero, tar) < E.Range) then
			Control.CastSpell(HK_E, tar)
		end
	end

	if(self.Menu.Combo.UseStridebreaker:Value()) then
		local tar = GetTarget(450)
		if(IsValid(tar)) then
			local hasWhip, whipSlot = self:HasIronspikewhip()
			local hasSB, SBSlot = self:HasStridebreaker()

			if(hasWhip or hasSB) then
				local slot = whipSlot or SBSlot
				if(GetDistance(myHero, tar) <= 425) and slot then -- 450 is the range of the whip, we'll go a bit tighter.
					Control.CastSpell(ItemHotKey[slot])
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
			end
		end
	end
end

function Nocturne:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
end

function Nocturne:Flee()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.Flee.UseQ:Value()) then
		if(Ready(_Q)) then
			Control.CastSpell(HK_Q)
		end
	end
end

function Nocturne:Clear()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(800)
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

function Nocturne:JungleClear(minions)

	local focusCreep = nil
	if(#minions > 1) then
		for _, minion in pairs(minions) do
			if(IsValid(minion)) then
				if(jungleBigMonsters[minion.charName]==1) then
					focusCreep = minion
					break
				end
			end
		end
	end

	if(self.Menu.Clear.Jungle.UseQ:Value() and Ready(_Q)) then
		if(focusCreep) and GetDistance(myHero, focusCreep) <= Q.Range then
			Control.CastSpell(HK_Q, focusCreep.pos)
			return
		else
			for _, minion in pairs(minions) do
				if(IsValid(minion)) then
					if(GetDistance(myHero, minion) < Q.Range) then
						Control.CastSpell(HK_Q, minion.pos)
						return
					end
				end
			end
		end
	end

	if(self.Menu.Clear.Jungle.UseE:Value() and Ready(_E)) then
		if(focusCreep) then
			if(GetDistance(myHero, focusCreep) <= E.Range) then
				Control.CastSpell(HK_E, focusCreep)
				return
			end
		else
			for _, minion in pairs(minions) do
				if(IsValid(minion)) then
					if(GetDistance(myHero, minion) < E.Range) then
						Control.CastSpell(HK_E, minion)
						return
					end
				end
			end
		end
	end

	if(self.Menu.Clear.Jungle.UseStridebreaker:Value()) then
		local hasWhip, whipSlot = self:HasIronspikewhip()
		local hasSB, SBSlot = self:HasStridebreaker()

		if(hasWhip or hasSB) then
			local slot = whipSlot or SBSlot
			if(focusCreep) then
				if(GetDistance(myHero, focusCreep) <= 350) and slot then -- 450 is the range of the whip, we'll go a bit tighter.
					Control.CastSpell(ItemHotKey[slot])
					return
				end
			else
				for _, minion in pairs(minions) do
					if(IsValid(minion)) then
						if(GetDistance(myHero, minion) < 350) and slot then
							Control.CastSpell(ItemHotKey[slot])
							return
						end
					end
				end
			end
		end
	end
end

function Nocturne:LaneClear(minions)

	if(self.Menu.Clear.Lane.UseQ:Value() and Ready(_Q)) then
		local shouldUseClearSkills = true

		if(myHero.mana/myHero.maxMana < (self.Menu.Clear.Lane.QMinMana:Value()/100)) then
			shouldUseClearSkills = false
		end

		if shouldUseClearSkills then
			for _, minion in pairs(minions) do
				if(IsValid(minion)) then

					local largetColl, collTarget = 0, nil
					for i = 1, #minions do
						local minion = minions[i]

						if(GetDistance(myHero, minion) <= (Q.Range - 50)) then
							--Find the best AoE line!
							local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
							if(collisionCount >= largetColl) then
								largetColl = collisionCount
								collTarget = minion
							end
						end
					end

					if(collTarget ~= nil) then
						Control.CastSpell(HK_Q, collTarget)
						return
					end
				end
			end
		end
	end

	if(self.Menu.Clear.Lane.UseStridebreaker:Value()) then
		local hasWhip, whipSlot = self:HasIronspikewhip()
		local hasSB, SBSlot = self:HasStridebreaker()

		if(hasWhip or hasSB) then
			local slot = whipSlot or SBSlot
			if(#minions >= 3) then
				local nearbyCount = 0
				for _, minion in pairs(minions) do
					if(IsValid(minion)) then
						if(GetDistance(myHero, minion) <= 450) then
							nearbyCount = nearbyCount + 1

							if(nearbyCount >= 3) then
								break
							end
						end
					end
				end

				if(nearbyCount >= 3) then
					Control.CastSpell(ItemHotKey[slot])
				end
			else
				for _, minion in pairs(minions) do
					if(IsValid(minion)) then
						if(GetDistance(myHero, minion) <= 450) then
							Control.CastSpell(ItemHotKey[slot])
						end
					end
				end
			end
		end
	end
end

function Nocturne:GetRRange()
	local range = ({2500, 3250, 4000})[myHero:GetSpellData(_R).level]
	return range
end

function Nocturne:AutoW()
	if not Ready(_W) then return end
	
	local targets = GetEnemyHeroes(2500)
	for _, unit in ipairs(targets) do
		local ePos = unit.pos
		local eSpell = unit.activeSpell
		if(eSpell and eSpell.valid and unit.isChanneling) then
			local delayAmnt = 0

			if(self.Menu.AutoW.Whitelist[unit.charName][eSpell.name]) then
				if(self.Menu.AutoW.Whitelist[unit.charName][eSpell.name]:Value() == false) then return end --If the enemy is casting a spell we have set to ignore, then don't shield
			end


			if(self.Menu.AutoW.Humanizer:Value()) then
				delayAmnt = assert(math.random(100, 300))
			end


			if(self.Menu.AutoW.BlockTargetted:Value()) then
				if(eSpell.target == myHero.handle) then
					DelayAction(function()
						if(Ready(_W)) then
							Control.CastSpell(HK_W)
						end			
					end, delayAmnt/1000)
					return
				end
			end
			
			if(self.Menu.AutoW.BlockNonTargetted:Value()) then
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
								if(Ready(_W)) then
									Control.CastSpell(HK_W)
								end			
							end, delayAmnt/1000)
							return
						end
					end
				end
			end

		end
	end
end

function Nocturne:HasSmite()
	if(self.SmiteSlot and self.SmiteCastSlot) then return true end

	return false
end

function Nocturne:HasOffensiveSmite()

	local smiteName = myHero:GetSpellData(self.SmiteSlot).name
	if(smiteName == "SummonerSmiteAvatarOffensive" or smiteName == "SummonerSmiteAvatarUtility" or smiteName == "SummonerSmiteAvatarDefensive") then
		return true
	end

	return false
end

function Nocturne:GetSmiteDamage(unit)
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

function Nocturne:HasStridebreaker()
    for i = ITEM_1, ITEM_7 do
		local id = myHero:GetItemData(i).itemID
        if id == ITEM_STRIDEBREAKER or id == ITEM_DREAMSHATTER then
			if(myHero:GetSpellData(i).currentCd == 0) then
				return true, i
			else
				return false
			end
        end
    end

	return false 
end

function Nocturne:HasIronspikewhip()
    for i = ITEM_1, ITEM_7 do
		local id = myHero:GetItemData(i).itemID
        if id == ITEM_IRONSPIKEWHIP then
			if(myHero:GetSpellData(i).currentCd == 0) then
				return true, i
			else
				return false
			end
        end
    end

	return false 
end

function Nocturne:GetRawAbilityDamage(spell, tar)
	if(spell == "Q") then
		return ({65, 110, 155, 200, 245})[myHero:GetSpellData(_Q).level] + (0.85 * myHero.bonusDamage)
	end

	if(spell == "E") then
		return ({80, 125, 170, 215, 260})[myHero:GetSpellData(_E).level] + (myHero.ap)
	end
	
	if(spell == "R") then
		return ({150, 275, 400})[myHero:GetSpellData(_R).level] + (1.20 * myHero.bonusDamage)
	end

	if(spell == "Passive") then
		return (1.20 * myHero.totalDamage)
	end

	return 0
end

function Nocturne:ManualKeys()
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
function Nocturne:UpdateComboDamage()
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

function Nocturne:GetTotalDamage(unit)
	local totalDmg = 0

	--Q
	if(Ready(_Q)) then
		local QDmg = self:GetRawAbilityDamage("Q")
		QDmg = CalcPhysicalDamage(myHero, unit, QDmg)
		totalDmg = totalDmg + QDmg
	end

	--E
	if(Ready(_E)) then
		local EDmg = self:GetRawAbilityDamage("E")
		EDmg = CalcMagicalDamage(myHero, unit, EDmg)
		totalDmg = totalDmg + EDmg
	end

	--R
	if(Ready(_R)) then
		local RDmg = self:GetRawAbilityDamage("R")
		RDmg = CalcPhysicalDamage(myHero, unit, RDmg)
		totalDmg = totalDmg + RDmg
	end

	--Passive
	if(myHero:GetSpellData(63).currentCd <= 8) then
		local PDmg = self:GetRawAbilityDamage("Passive")
		PDmg = CalcPhysicalDamage(myHero, unit, PDmg)
		totalDmg = totalDmg + PDmg
	end

	--Stridebreaker
	if(self:HasStridebreaker()) then
		local strideDmg = (1.75 * myHero.baseDamage)
		strideDmg = CalcPhysicalDamage(myHero, unit, strideDmg)
		totalDmg = totalDmg + strideDmg
	end

	--Ironspike Whip
	if(self:HasIronspikewhip()) then
		local whipDmg = myHero.baseDamage
		whipDmg = CalcPhysicalDamage(myHero, unit, whipDmg)
		totalDmg = totalDmg + whipDmg
	end
	
	totalDmg = totalDmg + (CalcPhysicalDamage(myHero, unit, myHero.totalDamage)*3)

	return totalDmg
end

function Nocturne:IsKillable(unit)
	local isKillable = false

	if(self.ComboDamageData[unit.networkID] ~= nil) then	
		local dmg = self.ComboDamageData[unit.networkID]
		if(unit.health - dmg <= 0) then
			isKillable = true
		end
		
	end
	return isKillable
end

-- [[ DRAWINGS ]] --

local alphaLerp = 0

function Nocturne:Draw()
	if myHero.dead then return end


	if(self.Menu.Drawings.DrawQ:Value()) then
		if(Ready(_Q)) then
			DrawCircle(myHero.pos, Q.Range, 1, DrawColor(255, 101, 5, 255))
		else
			DrawCircle(myHero.pos, Q.Range, 1, DrawColor(35, 101, 5, 255))
		end
	end

	if(self.Menu.Drawings.DrawE:Value()) then
		if(Ready(_E)) then
			DrawCircle(myHero.pos, E.Range, 1, DrawColor(255, 172, 5, 255))
		else
			DrawCircle(myHero.pos, E.Range, 1, DrawColor(35, 172, 5, 255))
		end
	end

	if(self.Menu.Drawings.DrawR:Value()) then
		if(Ready(_R)) then
			Draw.CircleMinimap(myHero.pos, self:GetRRange(), 1, DrawColor(185, 255, 255, 255))
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

function Nocturne:DrawDamageHPBars()
	for _, enemy in pairs(Enemies) do
		if(enemy.valid and IsValid(enemy)) then
			if(enemy.toScreen.onScreen) then
				if(Ready(_Q) or Ready(_E) or Ready(_R)) then
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

function Nocturne:DrawKillable()
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

function Nocturne:DrawKillReticle(unit)
	local reticleRadius = 75
	local speed = 135
	local newPos = Vector(unit.pos.x, unit.pos.y + 15, unit.pos.z)
	DrawCircle(unit, reticleRadius, 2, DrawColor(255, 255, 33, 92))
	local angle = ((GetTickCount() / 1000) % 360) * speed
	
	local vec1 = (Vector(math.cos(math.rad(angle)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle)) + unit.pos.z) - unit.pos):Normalized()
	local vec2 = (Vector(math.cos(math.rad(angle + 90)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 90)) + unit.pos.z) - unit.pos):Normalized()
	local vec3 = (Vector(math.cos(math.rad(angle + 180)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 180)) + unit.pos.z) - unit.pos):Normalized()
	local vec4 = (Vector(math.cos(math.rad(angle + 270)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 270)) + unit.pos.z) - unit.pos):Normalized()
	
	
	DrawLine((unit.pos + (vec1 * (reticleRadius - 20))):To2D(), (unit.pos + (vec1 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 33, 92))
	DrawLine((unit.pos + (vec2 * (reticleRadius - 20))):To2D(), (unit.pos + (vec2 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 33, 92))
	DrawLine((unit.pos + (vec3 * (reticleRadius - 20))):To2D(), (unit.pos + (vec3 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 33, 92))
	DrawLine((unit.pos + (vec4 * (reticleRadius - 20))):To2D(), (unit.pos + (vec4 * (reticleRadius + 20))):To2D(), 3, DrawColor(255, 255, 33, 92))
end

Nocturne()
LoadUnits()
