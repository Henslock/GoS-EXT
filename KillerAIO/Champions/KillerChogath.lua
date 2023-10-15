require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.05

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Cho'Gath will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Chogath"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/chogath.png"

local gameTick = GameTimer()

local FeastTable = {
	SRU_Baron = "FeastBaron",
	SRU_RiftHerald = "FeastHerald",
	SRU_Dragon_Elder = "FeastDragon",
	SRU_Dragon_Water = "FeastDragon",
	SRU_Dragon_Fire = "FeastDragon",
	SRU_Dragon_Earth = "FeastDragon",
	SRU_Dragon_Air = "FeastDragon",
	SRU_Dragon_Ruined = "FeastDragon",
	SRU_Dragon_Chemtech = "FeastDragon",
	SRU_Dragon_Hextech = "FeastDragon",
	SRU_Blue = "FeastBlue",
	SRU_Red = "FeastRed",
	SRU_Gromp = "FeastGromp",
	SRU_Murkwolf = "FeastWolves",
	SRU_Razorbeak = "FeastRazorbeaks",
	SRU_Krug = "FeastKrugs",
	Sru_Crab = "FeastCrab"
}

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.2, Range = 925, Radius = 250, Speed = math.huge, Collision = false}
local W = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.5, Radius = 175, Range = 625, Speed = 28000, Collision = false}
local ESpikes = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 170, Range = 650, Speed = 1800, Collision = false}
local R = {Range = 175}

--Main Menu
Chogath.Menu = MenuElement({type = MENU, id = "KillerChogath", name = "Killer Cho'Gath", leftIcon = ChampIcon})
Chogath.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

Chogath.InterruptableSpells = {
	["CaitlynAceintheHole"] = {Name = "Caitlyn", displayname = "R | Ace in the Hole", spellname = "CaitlynAceintheHole"},
	["FiddleSticksR"] = {Name = "FiddleSticks", displayname = "R | Crowstorm", spellname = "Crowstorm"},
	["FiddleSticksW"] = {Name = "FiddleSticks", displayname = "W | Drain", spellname = "DrainChannel"},
	["GalioIdolOfDurand"] = {Name = "Galio", displayname = "R | Idol of Durand", spellname = "GalioIdolOfDurand"},
	["ReapTheWhirlwind"] = {Name = "Janna", displayname = "R | Monsoon", spellname = "ReapTheWhirlwind"},
	["KarthusFallenOne"] = {Name = "Karthus", displayname = "R | Requiem", spellname = "KarthusFallenOne"},
	["KatarinaR"] = {Name = "Katarina", displayname = "R | Death Lotus", spellname = "KatarinaR"},
	["LucianR"] = {Name = "Lucian", displayname = "R | The Culling", spellname = "LucianR"},
	["AlZaharNetherGrasp"] = {Name = "Malzahar", displayname = "R | Nether Grasp", spellname = "AlZaharNetherGrasp"},
	["Meditate"] = {Name = "MasterYi", displayname = "W | Meditate", spellname = "Meditate"},
	["MissFortuneBulletTime"] = {Name = "MissFortune", displayname = "R | Bullet Time", spellname = "MissFortuneBulletTime"},
	["AbsoluteZero"] = {Name = "Nunu", displayname = "R | Absoulte Zero", spellname = "AbsoluteZero"},
	["PantheonRJump"] = {Name = "Pantheon", displayname = "R | Jump", spellname = "PantheonRJump"},
	["PantheonRFall"] = {Name = "Pantheon", displayname = "R | Fall", spellname = "PantheonRFall"},
	["ShenStandUnited"] = {Name = "Shen", displayname = "R | Stand United", spellname = "ShenStandUnited"},
	["Destiny"] = {Name = "TwistedFate", displayname = "R | Destiny", spellname = "Destiny"},
	["VarusQ"] = {Name = "Varus", displayname = "Q | Piercing Arrow", spellname = "VarusQ"},
	["VelkozR"] = {Name = "Velkoz", displayname = "R | Lifeform Disintegration Ray", spellname = "VelkozR"},
	["InfiniteDuress"] = {Name = "Warwick", displayname = "R | Infinite Duress", spellname = "InfiniteDuress"},
	["XerathLocusOfPower2"] = {Name = "Xerath", displayname = "R | Rite of the Arcane", spellname = "XerathLocusOfPower2"},
	["JhinR"] = {displayname = "R | Curtain Call", spellname = "JhinR"},
}

function Chogath:__init()
	self:LoadMenu()

	table.insert(_G.SDK.OnTick, function()
		self:Tick()
	end)

	table.insert(_G.SDK.OnDraw, function()
		self:Draw()
	end)

	--Custom Callbacks
	_G.SDK.Orbwalker:OnPostAttack(function(...) Chogath:OnPostAttack(...) end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) Chogath:OnPreAttack(...) end)
end

function Chogath:LoadMenu()                     	

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	if(myHero:GetSpellData(SUMMONER_1).name == "SummonerDot") or (myHero:GetSpellData(SUMMONER_2).name == "SummonerDot") then
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "              Ignite Loaded", type = SPACE})
	else
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "              Ignite Not Loaded", type = SPACE})
	end
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.Combo:MenuElement({id = "UseIgnite", name = "Use Ignite", value = true})
	self.Menu.Combo:MenuElement({id = "UseEverfrost", name = "Use Everfrost", value = true})
	self.Menu.Combo:MenuElement({id = "RBlacklist", name = "R Blacklist", type = MENU})

	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseQ", name = "Use Q if Far Away OR Under Tower", value = true})
	self.Menu.LastHit:MenuElement({id = "QDistanceThreshold", name = "Q Distance Threshold", value = 600, min = 0, max = 950, step = 10, identifier = " Units"})

	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "AutoQFarmers", name = "Auto Q CSing Champs", value = true})
	self.Menu.Harass:MenuElement({id = "AutoE", name = "Auto E if it Can Hit", value = true})

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = false})
	self.Menu.Clear:MenuElement({id = "UseW", name = "Use W", value = false})
	self.Menu.Clear:MenuElement({id = "UseE", name = "Use E", value = false})
	self.Menu.Clear:MenuElement({name = " ", drop = {"=========="}})
	self.Menu.Clear:MenuElement({id = "QStartLevel", name = "Start Using Q at Level", value = 9, min = 1, max = 18, step = 1})
	self.Menu.Clear:MenuElement({id = "WStartLevel", name = "Start Using W at Level", value = 11, min = 1, max = 18, step = 1})
	self.Menu.Clear:MenuElement({id = "EStartLevel", name = "Start Using E at Level", value = 6, min = 1, max = 18, step = 1})
	self.Menu.Clear:MenuElement({id = "UseRBig", name = "Use R on Big Jungle Monsters", value = false})
	self.Menu.Clear:MenuElement({id = "QMinions", name = "Min Minions to Hit with Q", value = 3, min = 1, max = 6, step = 1})
	self.Menu.Clear:MenuElement({id = "QMana", name = "Q Minimum Mana", value = 35, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear:MenuElement({id = "WMinions", name = "Min Minions to Hit with W", value = 5, min = 1, max = 6, step = 1})
	self.Menu.Clear:MenuElement({id = "WMana", name = "W Minimum Mana", value = 65, min = 0, max = 100, step = 5, identifier = "%"})

	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseW", name = "Use W if R is on Cooldown", value = true})
	self.Menu.KillSteal:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.KillSteal:MenuElement({id = "RBlacklist", name = "R Blacklist", type = MENU})
	
	self.Menu:MenuElement({id = "AutoQImmobile", name = "Auto Q Immobile", value = true})
	self.Menu:MenuElement({id = "AutoQInterrupter", name = "Auto Q Channelled Spells", value = true})
	self.Menu:MenuElement({id = "AutoREpicMonsters", name = "Auto R Epic Monsters", value = true})

	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawReticle", name = "Draw Feast Reticle", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawConsumableUnits", name = "Draw Consumable Units", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DamageHPBar", name = "Damage HP Bar", type = MENU})

	self.Menu.Drawings.DamageHPBar:MenuElement({id = "DrawDamageHPBar", name = "Draw Full Combo Damage", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "YOffset", name = "Y Offset", value = 60, min = -100, max = 100, step = 5})

	--Consumable Units
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "FeastBaron", name = "Draw Baron", value = true, leftIcon = "http://puu.sh/rPuVv/933a78e350.png"})
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "FeastHerald", name = "Draw Herald", value = true, leftIcon = "http://puu.sh/rQs4A/47c27fa9ea.png"})
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "FeastDragon", name = "Draw Dragon", value = true, leftIcon = "http://puu.sh/rPvdF/a00d754b30.png"})
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "FeastBlue", name = "Draw Blue Buff", value = true, leftIcon = "http://puu.sh/rPvNd/f5c6cfb97c.png"})
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "FeastRed", name = "Draw Red Buff", value = true, leftIcon = "http://puu.sh/rPvQs/fbfc120d17.png"})
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "FeastGromp", name = "Draw Gromp", value = false, leftIcon = "http://puu.sh/rPvSY/2cf9ff7a8e.png"})
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "FeastWolves", name = "Draw Wolves", value = false, leftIcon = "http://puu.sh/rPvWu/d9ae64a105.png"})
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "FeastRazorbeaks", name = "Draw Razorbeaks", value = false, leftIcon = "http://puu.sh/rPvZ5/acf0e03cc7.png"})
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "FeastKrugs", name = "Draw Krugs", value = false, leftIcon = "http://puu.sh/rPw6a/3096646ec4.png"})
	self.Menu.Drawings.DrawConsumableUnits:MenuElement({id = "FeastCrab", name = "Draw Crab", value = true, leftIcon = "http://puu.sh/rPwaw/10f0766f4d.png"})

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

	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local hero = args.unit
		local charName = args.charName
		--Add R blacklist champs
		self.Menu.Combo.RBlacklist:MenuElement({id = charName, name = charName, value = false})
		self.Menu.KillSteal.RBlacklist:MenuElement({id = charName, name = charName, value = false})
	end)

end

function Chogath:UpdateGoSMenuAutoLevel()
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

function Chogath:Tick()
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

	R.Range =  _G.SDK.Data:GetAutoAttackRange(myHero)

	self:KillSteal()

	if(self.Menu.AutoQImmobile:Value()) then
		self:AutoQImmobile()
	end

	if(self.Menu.AutoQInterrupter:Value()) then
		self:QInterrupter()
	end

	if(myHero:GetSpellData(_R).level > 0) then
		if(myHero:GetSpellData(_R).currentCd == 0) then
			self:CacheFeastUnits()
		end
	end

	if(self.Menu.AutoREpicMonsters:Value()) then
		self:REpicMonsterSteal()
	end

	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end

function Chogath:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end

function Chogath:OnPreAttack(args)
    if GetMode()=="Combo" and (Ready(_R)) then
		if(Chogath:IsConsumable(args.Target)) then
			if(Chogath.Menu.Combo.RBlacklist[args.Target]) then
				if(Chogath.Menu.Combo.RBlacklist[args.Target]:Value() == false) then
        			args.Process = false
				end
			end
		end
    end
end

function Chogath:OnPostAttack(args)
	--AA Cancel Combo E
	if(GetMode() == "Combo") then
		if(Ready(_E) and self.Menu.Combo.UseE:Value()) then
			Control.CastSpell(HK_E)
		end
	end

	--Clear/Jungle Clear
	if(GetMode() == "LaneClear") then
		if(Ready(_E)) then
			if(self.Menu.Clear.UseE:Value() and myHero.levelData.lvl >= self.Menu.Clear.EStartLevel:Value()) then
				print("Called")
				Control.CastSpell(HK_E)
			end
		end
	end
end

function Chogath:IsUnitFleeing(unit)
	if(unit and IsValid(unit) and unit.toScreen.onScreen) then
		local checkRunDir = GetUnitRunDirection(myHero, unit)
		if(checkRunDir == RUNNING_AWAY) then
			--Conditions where someone may be fleeing
			
			--Target is less than 30% HP
			local condition1 = (unit.health / unit.maxHealth) <= 0.3
			
			--You have 30% more HP than the target and they are less than 50% HP
			local condition2 = (myHero.health / myHero.maxHealth) - (unit.health / unit.maxHealth)>= 0.3 and (unit.health / unit.maxHealth) <= 0.4

			--You have 50% more HP than the target
			local condition3 = (myHero.health / myHero.maxHealth) - (unit.health / unit.maxHealth)>= 0.5

			if(condition1 or condition2 or condition3) then
				return true
			end
		end
	end
	
	return false
end

function Chogath:IsTargetKnockedUp(target)
	if(target) then
		return HasBuff(target, "rupturelaunch")
	end
	return false
end

function Chogath:IsConsumable(target)
	if(target.health - self:GetRChampionDamage() <= 0) then
		return true
	end
	return false
end

function Chogath:GetBonusHealth()
	return myHero.maxHealth-(644 + 94*(myHero.levelData.lvl-1) * (0.7025+(0.0175*(myHero.levelData.lvl-1))))
end

function Chogath:GetFeastStacks()
	for i = 0, myHero.buffCount do
		local buff = myHero:GetBuff(i)	

		if buff.name:lower() == "feast" and buff.count > 0 then 
			return(buff.stacks/80)
		end
	end
end

function Chogath:GenerateQBias(pos, target)
	--A set of rules to bias the Q in directions that are more likely to LoadUnits
	if(GetDistance(myHero, target) >= R.Range + 150) then
		if (myHero.health / myHero.maxHealth >= 0.5) or ((myHero.health / myHero.maxHealth) - (target.health / target.maxHealth) >= 0.3) then 
			if(target.pathing.hasMovePath) then

				--We want to push the Q a little further away behind the target if the target isnt planning on approaching us
				local wayDist = GetDistance(myHero.pos, target.pathing.endPos)
				local meVec = (myHero.pos - target.pos):Normalized()
				local pathVec = (target.pathing.endPos - target.pos):Normalized()
				if(wayDist >= 500) then
					local bias = Vector(pos):Extended(myHero.pos, -75)
					local dist = GetDistance(myHero.pos, bias)
					local finalPos = myHero.pos:Extended(bias, math.min(dist, Q.Range))
					return bias
				end
			end
		end
	end
	return pos
end

function Chogath:HasEActive()
	for i = 0, myHero.buffCount do
		local buff = myHero:GetBuff(i)	

		if buff.name:lower() == "vorpalspikes" and buff.count > 0 then 
			return true
		end
	end
end

function Chogath:HasEverfrost()
	return HasItem({Item.EternalWinter, Item.Everfrost})
end

function Chogath:IsEpicJungleMonster(unit)
	if unit.charName == "SRU_Baron" 
		or unit.charName == "SRU_RiftHerald" 
		or unit.charName == "SRU_Dragon_Water" 
		or unit.charName == "SRU_Dragon_Fire" 
		or unit.charName == "SRU_Dragon_Earth" 
		or unit.charName == "SRU_Dragon_Air" 
		or unit.charName == "SRU_Dragon_Ruined" 
		or unit.charName == "SRU_Dragon_Chemtech" 
		or unit.charName == "SRU_Dragon_Hextech" 
		or unit.charName ==	"SRU_Dragon_Elder" then
		return true
	else
		return false
	end
end

function Chogath:IsBigJungleMonster(unit)
	if unit.charName == "SRU_Blue" 
		or unit.charName == "SRU_Red" 
		or unit.charName == "SRU_Gromp" 
		or unit.charName == "SRU_Murkwolf" 
		or unit.charName == "SRU_Razorbeak" 
		or unit.charName == "SRU_Krug" 
		or unit.charName == "Sru_Crab" then
		return true
	else
		return false
	end	
end

function Chogath:WallQCheck(pos, checkRadius)
	--This function will offset skill shots from the wall they are intersecting
	--4 Quadrant check
	local q1 = Vector(1, 0, 0) * (checkRadius)
	local q2 = Vector(0, 0, 1) * (checkRadius)
	local q3 = Vector(-1, 0, 0) * (checkRadius)
	local q4 = Vector(0, 0, -1) * (checkRadius)
	local pos1 = pos + q1
	local pos2 = pos + q2
	local pos3 = pos + q3
	local pos4 = pos + q4
	local point = { x = pos.x, z = pos.z }
	local point1 = { x = pos1.x, z = pos1.z }
	local point2 = { x = pos2.x, z = pos2.z }
	local point3 = { x = pos3.x, z = pos3.z }
	local point4 = { x = pos4.x, z = pos4.z }

	local result, x, y = MapPosition:inWall(point1)
	
	local intersect, newPos = false, pos
	if MapPosition:intersectsWall(point, point1) then
		intersect = true
		newPos = newPos + (-0.8 * q1)
	end

	if MapPosition:intersectsWall(point, point2) then
		intersect = true
		newPos = newPos + (-0.8 * q2)
	end

	if MapPosition:intersectsWall(point, point3) then
		intersect = true
		newPos = newPos + (-0.8 * q3)
	end

	if MapPosition:intersectsWall(point, point4) then
		intersect = true
		newPos = newPos + (-0.8 * q4)
	end

	if(intersect) then
		return true, newPos
	end

	return false, pos
end

function Chogath:Combo()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	--R
	if(Ready(_R) and self.Menu.Combo.UseR:Value()) then
		local target = GetTarget(R.Range - 5)
		if(IsValid(target) and CantKill(target, true, true, false) == false) then

			if(self.Menu.Combo.RBlacklist[target.charName]) then
				if(self.Menu.Combo.RBlacklist[target.charName]:Value() == false) then
					if(self:IsConsumable(target)) then
						Control.CastSpell(HK_R, target)
						return
					end
				end
			end
		end
	end

	-- Q
	if(Ready(_Q) and self.Menu.Combo.UseQ:Value()) then
		local target = GetTarget(Q.Range + Q.Radius)
		if(target ~= nil and IsValid(target)) then
		
			if(myHero.pos:DistanceTo(target.pos) < Q.Range) then

				local pos = CastPredictedSpell({Hotkey = HK_Q, Target = target, SpellData = Q, ReturnPos = true, collisionRadiusOverride = Q.Radius - 50})
				if(pos) then
					local isQinWall, correctedPosition = self:WallQCheck(pos, Q.Radius*0.5)
					Control.CastSpell(HK_Q, pos)
				end
			end
		end
	end

	-- Everfrost
	if(self.Menu.Combo.UseEverfrost:Value()) then
		local hasEverfrost, itemSlot = self:HasEverfrost()
		if(hasEverfrost) then
			local target = GetTarget(850 - 25) -- Everfrost Range
			if(IsValid(target)) then
				if(IsImmobile(target) >= 0.5 or self:IsTargetKnockedUp(target)) then
					local tarPos = {x = target.pos.x,y = myHero.pos.y,z = target.pos.z}
					Control.CastSpell(ItemHotKey[itemSlot], tarPos)
					return
				end

				if(GetDistance(myHero.pos, target.pos) >= R.Range + 100) and Ready(_Q)==false and Ready(_W)==false and self:IsUnitFleeing(target) then
					local tarPos = {x = target.pos.x,y = myHero.pos.y,z = target.pos.z}
					Control.CastSpell(ItemHotKey[itemSlot], tarPos)
					return			
				end
			end
		end
	end

	--W if Close to you
	if(Ready(_W) and self.Menu.Combo.UseW:Value()) then
		local target = GetTarget(W.Range - 200)

		if(IsValid(target)) then

			if(Ready(_R)and self.Menu.Combo.UseR:Value() and self:IsConsumable(target)) then
				return
			end

			CastPredictedSpell({Hotkey = HK_W, Target = target, SpellData = W})
		end
	end

	--W if knocked up or slowed
	if(Ready(_W) and self.Menu.Combo.UseW:Value()) then
		local target = GetTarget(W.Range - 15)

		if(IsValid(target)) then

			if(Ready(_R)and self.Menu.Combo.UseR:Value() and self:IsConsumable(target)) then
				return
			end

			if(IsImmobile(target) >= 0.5) or self:IsTargetKnockedUp(target) then
				CastPredictedSpell({Hotkey = HK_W, Target = target, SpellData = W})
			end
		end
	end

	--Ignite Logic
	if(self.Menu.Combo.UseIgnite:Value()) then
		if(HasIgnite()) then
			local enemies = GetEnemyHeroes(600) --Ignite range
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy)) then
						if(CantKill(enemy, true, true, false)==false) then
							local igniteDmg = GetIgniteDamage()

							--Condition 1: Ignite will kill when all of our abilities are down, and we are out of melee range
							if(enemy.health - igniteDmg <= 0) and (enemy.health > 100) and GetDistance(myHero.pos, enemy.pos) >= R.Range + 100 and Ready(_R) == false and Ready(_Q) == false and Ready(_W) == false then
								UseIgnite(enemy)
								return
							end

							--Condition 2: Our R is up, we are in melee range, and ignite will bring us into R's kill threshold
							if GetDistance(myHero.pos, enemy.pos) <= R.Range and Ready(_R) == true and Ready(_Q) == false and Ready(_W) == false then
								if(self:IsConsumable(enemy) == false) then
									local EDmg = self:CalculateEChampDamage(enemy)*2
									local RDmg = self:GetRChampionDamage()
									if(enemy.health - RDmg - EDmg - igniteDmg <= 0) and (enemy.health - RDmg > 0) then
										UseIgnite(enemy)
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

function Chogath:Harass()
	if(gameTick > GameTimer()) then return end	

	if(self.Menu.Harass.AutoQFarmers:Value()) then
		self:AutoQAntiFarm()
	end

	if(self.Menu.Harass.AutoE:Value()) then
		if(Ready(_E) or self:HasEActive()) then
			local target = GetTarget(ESpikes.Range)
			if(IsValid(target)) then
				local EPrediction = GGPrediction:SpellPrediction(ESpikes)
				EPrediction:GetPrediction(target, myHero)
				if EPrediction:CanHit(HITCHANCE_HIGH) then

					--Check to see if the direction vector of us hitting the minion intersects with the enemy champion
					local minions = _G.SDK.ObjectManager:GetEnemyMinions(R.Range + 25)
					if(#minions > 0) then
						for i = 1, #minions do
							local minion = minions[i]
							if(minion and IsValid(minion)) then
								local diffVec = myHero.pos + (minion.pos - myHero.pos):Normalized() * ESpikes.Range
								local point, isOnSegment = ClosestPointOnLineSegment(target.pos, myHero.pos, diffVec)						
								if isOnSegment then
									local distCheck = GetDistance(target.pos, point)
									if distCheck < ESpikes.Radius then
										--Good to use it!

										if(Ready(_E)) then
											Control.CastSpell(HK_E)
											_G.SDK.Orbwalker:Attack(minion)
											return
										else
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
	end
end

function Chogath:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	if(self.Menu.LastHit.UseQ:Value() and Ready(_Q)) then
		local QDistanceThreshold = self.Menu.LastHit.QDistanceThreshold:Value()
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) --Just do 1 check for optimization
		local canonMinion = GetCanonMinion(minions)
		
		--Prioritize the canon minion
		if(canonMinion ~= nil) and IsValid(canonMinion) then
			if((IsUnderTurret(canonMinion) and GetDistance(myHero.pos, canonMinion.pos) >= R.Range + 100) or GetDistance(myHero.pos, canonMinion.pos) >= QDistanceThreshold) then
				local QDam = self:GetRawAbilityDamage("Q")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, 1.1)
				
				if ((hp > 0) and (canonMinion.health + (canonMinion.health*0.05) - QDam <= 0)) then
					Control.CastSpell(HK_Q, canonMinion)
					gameTick = GameTimer() + 0.2
					return
				end
			end
		end
		

		for i = 1, #minions do
			local minion = minions[i]
			if(minion and IsValid(minion)) then
				if(IsUnderTurret(minion) or GetDistance(myHero.pos, minion.pos) >= QDistanceThreshold) then
					local QDam = self:GetRawAbilityDamage("Q")
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, 1.1)
					
					if ((hp > 0) and (minion.health + (minion.health*0.05) - QDam <= 0) and (minion.health/minion.maxHealth <= 0.70)) then
						Control.CastSpell(HK_Q, minion)
						gameTick = GameTimer() + 0.2
						return
					end
				end
			end
		end
	end
end

function Chogath:Clear()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	--Q
	if(self.Menu.Clear.UseQ:Value() and myHero.levelData.lvl >= self.Menu.Clear.QStartLevel:Value()) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range - 15)
		if(Ready(_Q) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.QMana:Value() / 100)) then
			for i = 1, #minions do		
				local minion = minions[i]
				if IsValid(minion) then
					if(myHero.pos:DistanceTo(minion.pos) < Q.Range - 15) then
						local clusterMinions = GetMinionsAroundMinion(Q.Range, Q.Radius, minion)
						if(#clusterMinions >= self.Menu.Clear.QMinions:Value()-1) then
							local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
							Control.CastSpell(HK_Q, clusterMinionsAvgPos)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
			end
		end
	end

	--W
	if(self.Menu.Clear.UseW:Value() and myHero.levelData.lvl >= self.Menu.Clear.WStartLevel:Value()) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(W.Range)
		if(Ready(_W) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.WMana:Value() / 100)) then
			for i = 1, #minions do		
				local minion = minions[i]
				if IsValid(minion) then
					if(myHero.pos:DistanceTo(minion.pos) < W.Range - 15) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, math.huge, W.Delay, W.Radius, {GGPrediction.COLLISION_MINION})
						if(collisionCount >= self.Menu.Clear.WMinions:Value()) then
							Control.CastSpell(HK_W, minion.pos)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
			end
		end
	end

	--R
	if(self.Menu.Clear.UseRBig:Value()) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(R.Range)
		if(Ready(_R)) then
			for i = 1, #minions do		
				local minion = minions[i]
				if(IsValid(minion)) then
					local checkUnit = self:IsBigJungleMonster(minion)
					if(checkUnit == true) then
						if(minion.health - self:GetRMinionDamage() <= 0 and GetDistance(myHero.pos, minion.pos) <= R.Range) then
							Control.CastSpell(HK_R, minion)
							return
						end
					end
				end
			end
		end
	end	

end

function Chogath:KillSteal()
	if(gameTick > GameTimer()) then return end

	--R
	if(self.Menu.KillSteal.UseR:Value()) then
		if(Ready(_R)) then
			local enemies = GetEnemyHeroes(1500)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then

						if(self.Menu.KillSteal.RBlacklist[enemy.charName]) then
							if(self.Menu.KillSteal.RBlacklist[enemy.charName]:Value() == false) then
								if(self:IsConsumable(enemy) and (CantKill(enemy, true, true, false)==false)) then
									if(myHero.pos:DistanceTo(enemy.pos) < R.Range) then
										Control.CastSpell(HK_R, enemy)
										gameTick = GameTimer() + 0.2
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

	--W
	if(self.Menu.KillSteal.UseW:Value()) then
		if(Ready(_W) and Ready(_R)==false) then
			local enemies = GetEnemyHeroes(1500)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
						if(CantKill(enemy, true, true, false)==false) then
							if(myHero.pos:DistanceTo(enemy.pos) < W.Range - 75) then

								local wDmg = self:GetRawAbilityDamage("W")
								wDmg = CalcMagicalDamage(myHero, enemy, wDmg)
								if(enemy.health - wDmg + 35 <= 0) then
									Control.CastSpell(HK_W, enemy)
									gameTick = GameTimer() + 0.2
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

function Chogath:AutoQAntiFarm()
	if(Ready(_Q)) then
		local enemy = GetTarget(Q.Range - 25)
		if(IsValid(enemy)) then
			local AA = enemy.activeSpell
			if(AA.valid and AA.isAutoAttack) then
				local isHittingAlly = false
				if(AA.target == myHero.handle) then isHittingAlly = true end

				if(AA.endTime - GameTimer() >= 1) then
					for _, ally in ipairs(Allies) do
						if(AA.target == ally.handle) then
							isHittingAlly = true
							break
						end
					end

					if(isHittingAlly == false) then
						Control.CastSpell(HK_Q, enemy.pos)					
						return
					end
				end
			end
		end
	end
end

function Chogath:AutoQImmobile()
	if(Ready(_Q)) then
		local target = GetTarget(Q.Range + Q.Radius -10)
		if(IsValid(target)) then
			local QPrediction, isExtended = GetExtendedSpellPrediction(target, Q)
			if QPrediction:CanHit(HITCHANCE_IMMOBILE) then
				if(isExtended) then
					local castPos = myHero.pos:Extended(QPrediction.CastPosition, Q.Range -10)
					Control.CastSpell(HK_Q, castPos)
					return
				else
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
					return
				end
			end
			
			if(IsImmobile(target) >= 1.0) then
				local QPrediction, isExtended = GetExtendedSpellPrediction(target, Q)
				if QPrediction:CanHit(HITCHANCE_HIGH) then
					if(isExtended) then
						local castPos = myHero.pos:Extended(QPrediction.CastPosition, Q.Range -10)
						Control.CastSpell(HK_Q, castPos)
						return
					else
						Control.CastSpell(HK_Q, QPrediction.CastPosition)
						return
					end
				end
			end
		end
	end
end

function Chogath:QInterrupter()
	if(Ready(_Q)) then
		local enemies = GetEnemyHeroes(Q.Range + Q.Radius - 10)
		if(#enemies > 0) then
			for _, enemy in pairs (enemies) do
				if(IsValid(enemy)) then
					--Interrupt them if they are channeling an interruptible spell
					local spell = enemy.activeSpell
					if(spell and spell.valid and self.InterruptableSpells[spell.name]) then
						local QPrediction, isExtended = GetExtendedSpellPrediction(enemy, Q)
						if QPrediction:CanHit(HITCHANCE_NORMAL) then
							if(isExtended) then
								local castPos = myHero.pos:Extended(QPrediction.CastPosition, Q.Range)
								Control.CastSpell(HK_Q, castPos)
								return
							else
								Control.CastSpell(HK_E, QPrediction.CastPosition)
								return
							end
						end
					end
					
				end
			end
		end
	end
end

function Chogath:GetRMinionDamage()
	local bonusHealthDmg = self:GetBonusHealth() * 0.1
	return ({1200, 1200, 1200})[myHero:GetSpellData(_R).level] + (0.5 * myHero.ap) + bonusHealthDmg
end

function Chogath:GetRChampionDamage()
	local bonusHealthDmg = self:GetBonusHealth() * 0.1
	return ({300, 475, 650})[myHero:GetSpellData(_R).level] + (0.5 * myHero.ap) + bonusHealthDmg
end

function Chogath:GetRawAbilityDamage(spell)

	if(spell == "Q") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		return ({80, 140, 200, 260, 320})[myHero:GetSpellData(_Q).level] + (myHero.ap)
	end

	if(spell == "W") then
		if myHero:GetSpellData(_W).level == 0 then return 0 end
		return ({80, 135, 190, 245, 300})[myHero:GetSpellData(_W).level] + (0.7 * myHero.ap)
	end
	
	return 0
end

function Chogath:CalculateEChampDamage(unit)
	local feastStacks = self:GetFeastStacks()
	local hpDmg = unit.maxHealth * (3 + (feastStacks*0.5)/100)
	return ({22, 34, 46, 58, 70})[myHero:GetSpellData(_E).level] + (0.3 * myHero.ap) + hpDmg
end

local cachedUnits = {}
local cacheTick = 0
local cacheTickrate = 1.5
function Chogath:CacheFeastUnits()
	if(cacheTick > GameTimer()) then return end
	cachedUnits = {}
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(1000)
	for i = 1, #minions do
		local minion = minions[i]
		if(IsValid(minion)) then
			if(FeastTable[minion.charName] ~= nil) then
				local tableResult = FeastTable[minion.charName]
				local checkUnit = self.Menu.Drawings.DrawConsumableUnits[tableResult]:Value()
				if(checkUnit == true) then
					table.insert(cachedUnits, minion)
				end
			end
		end
	end
	cacheTick = GameTimer() + cacheTickrate
	return
end

function Chogath:REpicMonsterSteal()
	if(Ready(_R)) then
		if(cachedUnits) then
			for _, minion in ipairs(cachedUnits) do
				if(IsValid(minion)) then
					local checkUnit = self:IsEpicJungleMonster(minion)
					if(checkUnit == true) then
						if(minion.health - self:GetRMinionDamage() <= 0 and GetDistance(myHero.pos, minion.pos) <= R.Range) then
							Control.CastSpell(HK_R, minion)
							return
						end
					end
				end
			end
		end
	end
end

function Chogath:GetTotalComboDamage(unit)
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
	
	if(self:HasEverfrost()) then
		local everfrostDmg = GetItemDamage(Item.Everfrost)
		everfrostDmg = CalcMagicalDamage(myHero, unit, everfrostDmg)
		
		totalDmg = totalDmg + everfrostDmg
	end

	if(HasIgnite()) then
		local igniteDmg = GetIgniteDamage()
		totalDmg = totalDmg + igniteDmg
	end
	
	if(Ready(_R)) then
		local RDmg = self:GetRChampionDamage()
		totalDmg = totalDmg + RDmg
	end

	if(HasArcaneComet()) then
		local cDmg = GetArcaneCometDamage()
		cDmg = CalcMagicalDamage(myHero, unit, cDmg)
		totalDmg = totalDmg + cDmg
	end

	return totalDmg
end

local alphaLerp = 0
function Chogath:Draw()
	if myHero.dead then return end

	if(self.Menu.Drawings.DrawQ:Value()) then
		if(myHero:GetSpellData(_Q).level > 0) then
			if(myHero:GetSpellData(_Q).currentCd == 0) then
				DrawCircle(myHero, Q.Range, 1, DrawColor(130, 120, 255, 215))
			else
				DrawCircle(myHero, Q.Range, 1, DrawColor(30, 120, 255, 215))
			end
		end
	end

	if(self.Menu.LastHit.UseQ:Value()) then
		if(Ready(_Q) and GetMode() == "LastHit") then
			local radius = self.Menu.LastHit.QDistanceThreshold:Value()
			DrawCircle(myHero, radius, 1, DrawColor(65, 125, 125, 125))
		end
	end
	

	if(self.Menu.Drawings.DrawReticle:Value()) then
		if(myHero:GetSpellData(_R).level > 0) then
			if(myHero:GetSpellData(_R).currentCd == 0) then
				self:DrawKillable()
			end
		end
	end

	if(self.Menu.Drawings.DrawConsumableUnits.Enabled:Value()) then
		if(myHero:GetSpellData(_R).level > 0) then
			if(myHero:GetSpellData(_R).currentCd == 0) then
				self:DrawFeastableUnits()
			end
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

function Chogath:DrawKillable()
	local enemies = GetEnemyHeroes(3000)
	if(#enemies > 0) then
		for _, enemy in pairs(enemies) do
			if(IsValid(enemy)) then
				if(self:IsConsumable(enemy)) then
					self:DrawKillReticle(enemy)
				end
			end
		end
	end
end

function Chogath:DrawDamageHPBars()
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

local feastColor = DrawColor(255, 255, 80, 185)
function Chogath:DrawFeastableUnits()
	if(cachedUnits) then
		for _, minion in ipairs(cachedUnits) do
			if(IsValid(minion)) then
				local tableResult = FeastTable[minion.charName]
				local checkUnit = self.Menu.Drawings.DrawConsumableUnits[tableResult]:Value()
				if(checkUnit == true) then
					if(minion.health - self:GetRMinionDamage() <= 0) then
						DrawCircle(minion, minion.boundingRadius, 8, feastColor)
					end
				end
			end
		end
	end
end

local reticleColor = DrawColor(255, 255, 74, 234)
function Chogath:DrawKillReticle(unit)
	local reticleRadius = 75
	local speed = 135
	local newPos = Vector(unit.pos.x, unit.pos.y + 15, unit.pos.z)
	DrawCircle(unit, reticleRadius, 2, reticleColor)
	local angle = ((GetTickCount() / 1000) % 360) * speed
	
	local vec1 = (Vector(math.cos(math.rad(angle)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle)) + unit.pos.z) - unit.pos):Normalized()
	local vec2 = (Vector(math.cos(math.rad(angle + 90)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 90)) + unit.pos.z) - unit.pos):Normalized()
	local vec3 = (Vector(math.cos(math.rad(angle + 180)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 180)) + unit.pos.z) - unit.pos):Normalized()
	local vec4 = (Vector(math.cos(math.rad(angle + 270)) + unit.pos.x, unit.pos.y, math.sin(math.rad(angle + 270)) + unit.pos.z) - unit.pos):Normalized()
	
	
	DrawLine((unit.pos + (vec1 * (reticleRadius - 20))):To2D(), (unit.pos + (vec1 * (reticleRadius + 20))):To2D(), 3, reticleColor)
	DrawLine((unit.pos + (vec2 * (reticleRadius - 20))):To2D(), (unit.pos + (vec2 * (reticleRadius + 20))):To2D(), 3, reticleColor)
	DrawLine((unit.pos + (vec3 * (reticleRadius - 20))):To2D(), (unit.pos + (vec3 * (reticleRadius + 20))):To2D(), 3, reticleColor)
	DrawLine((unit.pos + (vec4 * (reticleRadius - 20))):To2D(), (unit.pos + (vec4 * (reticleRadius + 20))):To2D(), 3, reticleColor)
end

Chogath()
LoadUnits()
