require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.09

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Naafiri will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

--[[SPELLCAST CLASS]]--

class("SpellCast")
 
function SpellCast:__init()
    _G._SPELLCAST_START = true
    self.OnSpellCastCallback = {}
    Callback.Add("Tick", function() self:OnTick() end)
end
 
SpellCast.QDidCast = false
SpellCast.WDidCast = false
SpellCast.EDidCast = false
SpellCast.RDidCast = false
 
function SpellCast:OnTick()

	if(self.QDidCast == false) then
		if(myHero:GetSpellData(_Q).currentCd) > 0 or myHero.activeSpell.name == myHero:GetSpellData(_Q).name and myHero:GetSpellData(_Q).cd ~= 0 then
			self.QDidCast = true
			local spell = myHero:GetSpellData(_Q)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.WDidCast == false) then
		if(myHero:GetSpellData(_W).currentCd) > 0 or myHero.activeSpell.name == myHero:GetSpellData(_W).name and myHero:GetSpellData(_W).cd ~= 0 then
			self.WDidCast = true
			local spell = myHero:GetSpellData(_W)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.EDidCast == false) then
		if(myHero:GetSpellData(_E).currentCd) > 0 or myHero.activeSpell.name == myHero:GetSpellData(_E).name and myHero:GetSpellData(_E).cd ~= 0 then
			self.EDidCast = true
			local spell = myHero:GetSpellData(_E)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.RDidCast == false) then
		if(myHero:GetSpellData(_R).currentCd) > 0 or myHero.activeSpell.name == myHero:GetSpellData(_R).name and myHero:GetSpellData(_R).cd ~= 0 then
			self.RDidCast = true
			local spell = myHero:GetSpellData(_R)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	self:UpdateSpellChecks()
end

function SpellCast:UpdateSpellChecks()
	if(Ready(_Q) and myHero.activeSpell.name ~= myHero:GetSpellData(_Q).name) then 
		self.QDidCast = false 
	end
	if(Ready(_W) and myHero.activeSpell.name ~= myHero:GetSpellData(_W).name) then 
		self.WDidCast = false 
	end
	if(Ready(_E) and myHero.activeSpell.name ~= myHero:GetSpellData(_E).name) then 
		self.EDidCast = false 
	end
	if(Ready(_R) and myHero.activeSpell.name ~= myHero:GetSpellData(_R).name) then 
		self.RDidCast = false 
	end
end

local function OnSpellCast(fn)
    if not _SPELLCAST_START then
        _G.SpellCast = SpellCast()
    end
    table.insert(SpellCast.OnSpellCastCallback, fn)
end


memoize = (function()
	local function is_callable(f)
	  local tf = type(f)
	  if tf == 'function' then return true end
	  if tf == 'table' then
		local mt = getmetatable(f)
		return type(mt) == 'table' and is_callable(mt.__call)
	  end
	  return false
	end
  
	local function cache_get(cache, params, refreshTime)
	  local node = cache
	  for i = 1, #params do
		node = node.children and node.children[params[i]]
		if not node then return nil end
	  end
	  
	  -- Check refresh time if provided
	  if refreshTime and node.cachedResultTime and (node.cachedResultTime + refreshTime) <= os.clock() then
		return nil
	  end
	  
	  return node.results
	end
  
	local function cache_put(cache, params, results)
	  local node = cache
	  local param
	  for i = 1, #params do
		param = params[i]
		node.children = node.children or {}
		node.children[param] = node.children[param] or {}
		node = node.children[param]
	  end
	  node.results = results
	  node.cachedResultTime = os.clock() -- Record the time when the result was cached
	end
  
	local function memoize(f, cache)
	  cache = cache or {}
  
	  if not is_callable(f) then
		error(string.format(
				"Only functions and callable tables are memoizable. Received %s (a %s)",
				tostring(f), type(f)))
	  end
  
	  return function (params, refreshTime)
		local results = cache_get(cache, params, refreshTime)
		if not results then
		  results = { f(table.unpack(params)) }
		  cache_put(cache, params, results)
		end
  
		return table.unpack(results)
	  end
	end
  
	return memoize
  end)()

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Naafiri"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/naafiri.png"

local gameTick = GameTimer()

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 900, Radius = 60, Speed = 1100}
local E = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Range = 350, Radius = 210, Speed = 1600}

--[[
NAAFIRI Item IDS
(Most commonly used items with Naafiri)

6693 = PROWLERS CLAW
6691 = DUSKBLADE

--]]

local ITEM_DUSKBLADE = 6691
local ITEM_PROWLERSCLAW = 6693
local ITEM_SANDSHRIKESCLAW = 7000

--Main Menu
Naafiri.Menu = MenuElement({type = MENU, id = "KillerNaafiri", name = "Killer Naafiri", leftIcon = ChampIcon})
Naafiri.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

Naafiri.PackmateData = {}
Naafiri.ComboDamageData = {}

local lastTick = GameTimer()

function Naafiri:__init()

	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)

	--Custom Callbacks
	OnSpellCast(function(spell) self:OnSpellCast(spell) end)
	_G.SDK.Orbwalker:OnPreMovement(function(...) Naafiri:OnPreMovement(...) end)

	self:UpdateGoSMenuAutoLevel()

end

function Naafiri:LoadMenu()                     	
	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})

	if(myHero:GetSpellData(SUMMONER_1).name == "SummonerDot") or (myHero:GetSpellData(SUMMONER_2).name == "SummonerDot") then
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "Ignite Loaded", type = SPACE})
	else
		self.Menu.Combo:MenuElement({id = "IgniteCheck", name = "Ignite Not Loaded", type = SPACE})
	end

	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "UseIgnite", name = "Use Ignite", value = true})
	self.Menu.Combo:MenuElement({id = "EngageSettings", name = "Semi-manual Engage Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "WSettings", name = "W Settings", type = MENU})

	self.Menu.Combo.EngageSettings:MenuElement({id = "UseE", name = "Use E to Gapclose if Killable", value = true})
	self.Menu.Combo.EngageSettings:MenuElement({id = "SemiManualEngage", name = "Semi-manual Engage", key = string.byte("Z")})
	self.Menu.Combo.EngageSettings:MenuElement({id = "SemiManualFlashEngage", name = "Semi-manual Flash + E Engage", key = string.byte("C")})

	self.Menu.Combo.WSettings:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "WSpam", name = "Use W Regardless if Cooldown is < 7s", value = true})
	self.Menu.Combo.WSettings:MenuElement({name = "== SOLO LOGIC ==", type = SPACE})
	self.Menu.Combo.WSettings:MenuElement({id = "WSoloKill", name = "Engage with W on Solo Killable Targets", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "WSoloFinishOff", name = "Use At Any Range on lowHP Solo Targets", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "EWSolo", name = "E Gapclose -> W Solo Killable Targets", value = true})
	self.Menu.Combo.WSettings:MenuElement({name = "== TEAMFIGHT LOGIC ==", type = SPACE})
	self.Menu.Combo.WSettings:MenuElement({id = "WTeamGapclose", name = "Gapclose with W", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "WTeamFinishOff", name = "Use At Any Range on lowHP Enemies", value = true})


	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "QMana", name = "Q Min Mana", value = 15, min = 0, max = 100, step = 5, identifier = "%"})

	-- Flee
	self.Menu:MenuElement({id = "Flee", name = "Flee", type = MENU})
	self.Menu.Flee:MenuElement({id = "UseWallHop", name = "Use Wall Hop Assist", value = true})

	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseECanon", name = "Last Hit Canon with E", value = false})
	self.Menu.LastHit:MenuElement({id = "UseQ", name = "Last Hit Distant Minions with Q", value = true})

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "Lane", name = "Lane", type = MENU})
	self.Menu.Clear:MenuElement({id = "Jungle", name = "Jungle", type = MENU})

	-- Lane Clear
	self.Menu.Clear.Lane:MenuElement({id = "ChampCheck", name = "Only Use Skills When No Enemies Around", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "LevelCheck", name = "Only Use Skills After Level", value = 9, min = 1, max = 18, step = 1})
	self.Menu.Clear.Lane:MenuElement({id = "LogicCheck", name = "Logic: ", value = 1, drop = {"OR", "AND"}})
	self.Menu.Clear.Lane:MenuElement({id = "LineBreak", name = "=================", type = SPACE})
	self.Menu.Clear.Lane:MenuElement({id = "UseQ", name = "Use Q1 & Q2", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "QCount", name = "Use Q1 to hit X Minions", value = 3, min = 1, max = 5, step = 1, identifier = " Minions"})
	self.Menu.Clear.Lane:MenuElement({id = "UseEClusters", name = "Use E on Minion Clusters", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "UseECanon", name = "Use E to Kill Canon", value = true})
	self.Menu.Clear.Lane:MenuElement({id = "QMana", name = "Q Min Mana", value = 25, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Clear.Lane:MenuElement({id = "EMana", name = "E Min Mana", value = 15, min = 0, max = 100, step = 5, identifier = "%"})

	-- Jungle Clear
	self.Menu.Clear.Jungle:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "UseW", name = "Use W to Jump to Distant Mobs", value = true})
	self.Menu.Clear.Jungle:MenuElement({id = "UseE", name = "Use E", value = true})

	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "Msg", name = "[Note] W Kill Options are in Combo Mode", type = SPACE})
	self.Menu.KillSteal:MenuElement({id = "UseE", name = "Use E", value = true})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawW", name = "Draw W Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawE", name = "Draw E Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawPuppers", name = "Draw Puppers", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawEngageUI", name = "Draw Semi-manual Engage UI", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawKillableTargets", name = "Draw Killable Targets", value = true})
	self.Menu.Drawings:MenuElement({id = "DamageHPBar", name = "Damage HP Bar", type = MENU})

	self.Menu.Drawings.DamageHPBar:MenuElement({id = "DrawDamageHPBar", name = "Draw Full Combo Damage", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "ShowOverKillBar", name = "Draw Overkill Bar", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "YOffset", name = "Y Offset", value = 60, min = -100, max = 100, step = 5})

	self.Menu:MenuElement({id = "DisableInFountain", name = "Disable Orbwalker while in Fountain", value = true})
	
end

function Naafiri:UpdateGoSMenuAutoLevel()

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
			UpdateInfo()
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

function Naafiri:AutoLevel()
	
	local firstSkill = self.Menu.AutoLevel.FirstSkill:Value()
	local secondSkill = self.Menu.AutoLevel.SecondSkill:Value()
	skillPriority = GenerateSkillPriority(firstSkill, secondSkill)

	AutoLeveler(skillPriority)
end
function Naafiri:Tick()
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
	elseif(mode == "Flee") then
		self:Flee()
	elseif(mode == "LastHit") then
		self:LastHit()
	elseif(mode == "LaneClear") then
		self:Clear()
	end

	self:UpdatePackmateData()
	self:ManualKeys()
	self:UpdateComboDamage()
	self:KillSteal()
	self:ForcedW()

	if(self.Menu.Combo.EngageSettings.SemiManualEngage:Value()) then
		self:SemiManualEngage()
	end

	if(self.Menu.Combo.EngageSettings.SemiManualFlashEngage:Value()) then
		self:SemiManualFlashEngage()
	end

	if Game.IsOnTop() and self.Menu.AutoLevel.Enabled:Value() and myHero.levelData.lvl >= self.Menu.AutoLevel.StartingLevel:Value() then
		self:AutoLevel()
	end	
end

Naafiri.hopSPos, Naafiri.hopEPos = nil, nil
function Naafiri:OnPreMovement(args) --args.Target | args.Process

	if(GetMode() == "Flee") and Ready(_E) then
		if(self.Menu.Flee.UseWallHop:Value()) then
			local p1 = myHero.pos
			local p2 = Game.mousePos()
	
			if(MapPosition:intersectsWall(p1, p2)) then
				local wallCheckPos = MapPosition:getIntersectionPoint3D(p1, p2)
				if(wallCheckPos) then
					local thicknessCheck = wallCheckPos:Extended(p2, E.Range + E.Radius * 0.4)
					local inWallCheck = (MapPosition:inWall(thicknessCheck) == 1)
					if(not inWallCheck) then

						--Calculate wall thickness by using an inverse intersection check
						local isWallThickEnough = false
						local invWallCheckPos = nil
						if(MapPosition:intersectsWall(thicknessCheck, p1)) then
							invWallCheckPos = MapPosition:getIntersectionPoint3D(thicknessCheck, p1)
							if(invWallCheckPos) then
								local dist = GetDistance(invWallCheckPos, wallCheckPos)
								if(dist > 100) then isWallThickEnough = true end
							end
						end

						if(GetDistance(wallCheckPos, myHero) <= 850 and isWallThickEnough) then
							args.Target = wallCheckPos

							self.hopSPos = wallCheckPos
							if(GetDistance(invWallCheckPos, wallCheckPos) > E.Range) then
								self.hopEPos = thicknessCheck
							else
								self.hopEPos = wallCheckPos:Extended(p2, E.Range)
							end

							if(GetDistance(wallCheckPos, myHero) <= 100) then
								Control.CastSpell(HK_E, p2)
								self.hopSPos = nil
								self.hopEPos = nil
							end
						end
					end
				end
			end
		else
			self.hopSPos = nil
			self.hopEPos = nil
		end
	else
		self.hopSPos = nil
		self.hopEPos = nil
	end
end

function Naafiri:OnSpellCast(spell)

	if spell.name == "NaafiriR" then
		DelayEvent(function ()
			self:ScanPackmates()
		end, 0.02)
	end

	if spell.name == "NaafiriE" then
		self.shouldSearchForDogs = true
	end

	if spell.name == "NaafiriW" then
		self.shouldSearchForDogs = true
	end
end

function Naafiri:Combo()
	if(gameTick > GameTimer()) then return end
	if not myHero.valid or myHero.dead or myHero.isChanneling then return end

	if(self.Menu.Combo.UseIgnite:Value()) then
		if(CanUseSummoner(myHero, "SummonerDot")) then
			local igniteRange = 600
			local target = GetTarget(igniteRange)
			if(IsValid(target)) then
				if(GetDistance(target, myHero) <= igniteRange) and (CantKill(target, true, false, false)==false) then

					local overkillCheck = self:CalculateOverkillAmount(target)
					local igniteDmg = 50 + (20 * myHero.levelData.lvl)
					local shouldUseIgnite = false

					if(overkillCheck ~= nil and overkillCheck < 0.25) then
						shouldUseIgnite = true
					end

					if(target.health - igniteDmg < 0 and target.health > 50) then
						if(Ready(_E) == false and Ready(_Q) == false and Ready(_W) == false) then
							shouldUseIgnite = true
						end
					end

					if(shouldUseIgnite) then
						UseIgnite(target)
						return
					end
				end
			end
		end
	end

	if(self.Menu.Combo.UseE:Value()) then
		if(Ready(_E)) then
			local target = GetTarget(E.Range)
			if(IsValid(target)) then
				if(GetDistance(target, myHero) >= 75) and (CantKill(target, true, false, false)==false) then
					if(IsTurretDiving(target.pos)) then
						if(self:IsKillable(target)) then
							Control.CastSpell(HK_E, target.pos)
						end
					else
						Control.CastSpell(HK_E, target.pos)
					end
				end
			end
		end
	end

	if(self.Menu.Combo.UseQ:Value()) then
		if(Ready(_Q)) then
			
			local target = GetTarget(Q.Range - 75)
			if(IsValid(target)) then
				CastPredictedSpell(HK_Q, target, Q, false)
			end
		end
	end

	if(self.Menu.Combo.WSettings.UseW:Value()) then
		if(Ready(_W)) then

			if(self.Menu.Combo.WSettings.WSpam:Value()) then
				if(myHero:GetSpellData(_W).cd <= 7) then
					local tar = GetTarget(self:GetWRange() - 15)
					if(IsValid(tar)) then
						Control.CastSpell(HK_W, tar)
						gameTick = GameTimer() + 0.2
						return
					end
				end
			end	

			local enemies = GetEnemyHeroes(1500)
			if(#enemies == 1) then
				local enemy = enemies[1]
				if(IsValid(enemy) and IsUnderTurret(enemy) == false) then

					--Solo logic:
					if(self.Menu.Combo.WSettings.WSoloKill:Value()) then
						if(self:IsKillable(enemy)) then
							if(GetDistance(myHero, enemy) <= self:GetWRange() and GetDistance(myHero, enemy) > E.Range + 100) then
								Control.CastSpell(HK_W, enemy)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end

					if(self.Menu.Combo.WSettings.WSoloFinishOff:Value()) then
						if(self:IsKillable(enemy) or (enemy.health / enemy.maxHealth <= 0.3)) then
							if(GetDistance(myHero, enemy) <= self:GetWRange()) then
								Control.CastSpell(HK_W, enemy)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end

					if(self.Menu.Combo.WSettings.EWSolo:Value()) then
						if(Ready(_E)) then
							local incDam = self.ComboDamageData[enemy.networkID] - CalcPhysicalDamage(myHero, enemy, self:GetRawAbilityDamage("E"))
							if(enemy.health - incDam <= 0) then
								if(GetDistance(myHero, enemy) <= (self:GetWRange() + E.Range) and GetDistance(myHero, enemy) > (self:GetWRange())) then
									Control.CastSpell(HK_E, enemy.pos)
									gameTick = GameTimer() + 0.2
									self:ForceWOnTarget(enemy)
									return
								end
							end
						end
					end	

				end
			end

			--Teamfight Logic
			if(#enemies > 1) then

				if(self.Menu.Combo.WSettings.WTeamGapclose:Value()) then
					local tar = GetTarget(self:GetWRange() - 15)
					if(IsValid(tar) and IsUnderTurret(tar) == false) then
						if(GetDistance(myHero, tar) > E.Range + 100) then
							Control.CastSpell(HK_W, tar)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end

				if(self.Menu.Combo.WSettings.WTeamFinishOff:Value()) then
					local tar = GetTarget(self:GetWRange() - 15)
					if(IsValid(tar) and IsUnderTurret(tar) == false) then
						if(self:IsKillable(tar) or (tar.health / tar.maxHealth <= 0.3)) then
							if(GetDistance(myHero, tar) <= self:GetWRange()) then
								Control.CastSpell(HK_W, tar)
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

function Naafiri:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not myHero.valid or myHero.dead or myHero.isChanneling then return end

	if(self.Menu.LastHit.UseECanon:Value() and Ready(_E)) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(E.Range)
		local canonMinion = GetCanonMinion(minions)
		
		--Prioritize the canon minion if its low
		if(canonMinion ~= nil) and IsValid(canonMinion) then
			local EDam = self:GetRawAbilityDamage("E")
			local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, (GetDistance(myHero, canonMinion)/E.Speed))
			
			if ((hp > 0) and (canonMinion.health + 30 - EDam <= 0)) and GetDistance(myHero, canonMinion) <= E.Range and GetDistance(myHero, canonMinion) > 75  then
				Control.CastSpell(HK_E, canonMinion.pos)
				gameTick = GameTimer() + 0.2
				return
			end
		end
	end

	if(self.Menu.LastHit.UseQ:Value() and Ready(_Q)) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
		
		for i = 1, #minions do
			local minion = minions[i]
			if(IsValid(minion)) then
				if(GetDistance(myHero, minion) <= (Q.Range - 50)) and (GetDistance(myHero, minion) > (E.Range + 100)) then
					local EDam = self:GetRawAbilityDamage("Q1")
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, (GetDistance(myHero, minion)/Q.Speed))

					if(hp > 0) and (hp - EDam <= 0) then
						Control.CastSpell(HK_Q, minion)
						gameTick = GameTimer() + 0.2
						return
					end
				end
			end
		end
	end

end

function Naafiri:Harass()
	if(gameTick > GameTimer()) then return end	
	if not myHero.valid or myHero.dead or myHero.isChanneling then return end

	if(self.Menu.Harass.UseQ:Value()) then
		if(Ready(_Q) and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then
			
			local target = GetTarget(Q.Range - 75)
			if(IsValid(target)) then
				CastPredictedSpell(HK_Q, target, Q, false)
			end

		end
	end
end

function Naafiri:Flee()
	if(gameTick > GameTimer()) then return end	
	if not myHero.valid or myHero.dead or myHero.isChanneling then return end
end

function Naafiri:Clear()
	if(gameTick > GameTimer()) then return end	
	if not myHero.valid or myHero.dead or myHero.isChanneling then return end

	local rangeCheck = math.max(Q.Range, self:GetWRange()) --Your W is further at max rank

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(rangeCheck)
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

	if(#jungleMinions > 0) then
		self:JungleClear(jungleMinions)
	end

	if(#laneMinions > 0) then
		self:LaneClear(laneMinions)
	end
end

function Naafiri:JungleClear(jungleMinions)
	if(self.Menu.Clear.Jungle.UseW:Value()) then
		if(Ready(_W)) then
			local nearbyMinions = _G.SDK.ObjectManager:GetEnemyMinions(550)
			if(#nearbyMinions == 0) then
				for _, minion in ipairs(jungleMinions) do
					if(GetDistance(minion.pos, myHero.pos) <= self:GetWRange()) then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end

	if(self.Menu.Clear.Jungle.UseQ:Value()) then
		if(Ready(_Q)) then
			for _, minion in ipairs(jungleMinions) do
				if(GetDistance(minion.pos, myHero.pos) <= Q.Range - 125) then
					Control.CastSpell(HK_Q, minion.pos)
				end
			end
		end
	end

	if(self.Menu.Clear.Jungle.UseE:Value()) then
		if(Ready(_E)) then
			for _, minion in ipairs(jungleMinions) do
				local clusterMinions = GetMinionsAroundMinion(E.Range, E.Radius, minion)

				if(#clusterMinions >= 1) then
					local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
					if(GetDistance(clusterMinionsAvgPos, myHero.pos) <= E.Range) then
						Control.CastSpell(HK_E, clusterMinionsAvgPos)
						return
					end
				else
					if(GetDistance(minion.pos, myHero.pos) <= E.Range) then
						Control.CastSpell(HK_E, minion.pos)
						return
					end
				end
			end
		end
	end
end

function Naafiri:LaneClear(laneMinions)
	local shouldUseClearSkills = true

	local champCheck, levelCheck = true, true
	if(self.Menu.Clear.Lane.ChampCheck:Value()) then
		local numEnemies = GetEnemyCount(1500, myHero)
		if(numEnemies ~= 0) then
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
		if(Ready(_E) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.Lane.EMana:Value() / 100)) then
			for _, minion in ipairs(laneMinions) do
				local clusterMinions = GetMinionsAroundMinion(E.Range, E.Radius, minion)

				if(#clusterMinions >= 2) then
					local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
					if(GetDistance(clusterMinionsAvgPos, myHero.pos) <= E.Range) then
						if(IsTurretDiving(clusterMinionsAvgPos) == false) then
							Control.CastSpell(HK_E, clusterMinionsAvgPos)
							return
						end
					end
				end
			end
		end
	end

	if(self.Menu.Clear.Lane.UseECanon:Value()) then
		if (Ready(_E) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.Lane.EMana:Value() / 100)) then
			local canonMinion = GetCanonMinion(laneMinions)
			
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local EDam = self:GetRawAbilityDamage("E")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, (GetDistance(myHero, canonMinion)/E.Speed))
				
				if ((hp > 0) and (canonMinion.health + 30 - EDam <= 0)) and GetDistance(myHero, canonMinion) <= E.Range and GetDistance(myHero, canonMinion) > 75  then
					if(IsTurretDiving(canonMinion.pos) == false) then
						Control.CastSpell(HK_E, canonMinion.pos)
						return
					end
				end
			end
		end
	end

	if(self.Menu.Clear.Lane.UseQ:Value()) then
		if(Ready(_Q) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.Lane.QMana:Value() / 100)) then

			--Check for bleeding minions first, we will prioritize those.
			local largetColl, collTarget = 0, nil
			for i = 1, #laneMinions do
				local minion = laneMinions[i]

				local bleedBuff = GetBuffData(minion, "NaafiriQBleed")
				if(GetDistance(myHero, minion) <= (Q.Range - 50) and bleedBuff and bleedBuff.duration >= 1) then
					--Find the best AoE line!
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius-5, {GGPrediction.COLLISION_MINION}, minion.networkID)
					if(collisionCount >= largetColl) then
						largetColl = collisionCount
						collTarget = minion
					end
				end
			end

			if(collTarget ~= nil) then
				Control.CastSpell(HK_Q, collTarget)
				gameTick = GameTimer() + 0.2
				return
			end

			for i = 1, #laneMinions do
				local minion = laneMinions[i]

				if(GetDistance(myHero, minion) <= (Q.Range - 50)) then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius-5, {GGPrediction.COLLISION_MINION},  minion.networkID)
					if(collisionCount >= self.Menu.Clear.Lane.QCount:Value()) then
						Control.CastSpell(HK_Q, minion)
						gameTick = GameTimer() + 0.2
						return
					end
				end
			end
		end
	end
end

function Naafiri:KillSteal()
	if(gameTick > GameTimer()) then return end
	
	if(self.Menu.KillSteal.UseE:Value()) then
		if(Ready(_E)) then
			local extendedRange = E.Range + (E.Radius * 0.75)
			local enemies = GetEnemyHeroes(extendedRange)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
						if((CantKill(enemy, true, false, false)==false)) then

							--Full E damage
							if(myHero.pos:DistanceTo(enemy.pos) <= E.Range) then
								local EDmg = self:GetRawAbilityDamage("E")
								local isKillable = false
								EDmg = CalcPhysicalDamage(myHero, enemy, EDmg)
								isKillable = (enemy.health - EDmg < 0)
								if(isKillable) then
									Control.CastSpell(HK_E, enemy.pos)
									return
								end
							end

							if(myHero.pos:DistanceTo(enemy.pos) > E.Range and myHero.pos:DistanceTo(enemy.pos) <= extendedRange) then
								local EFlurryDmg = self:GetRawAbilityDamage("EFlurry")
								local isKillable = false
								EFlurryDmg = CalcPhysicalDamage(myHero, enemy, EFlurryDmg)
								isKillable = (enemy.health - EFlurryDmg < 0)
								if(isKillable) then
									Control.CastSpell(HK_E, enemy.pos)
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

Naafiri.wTar = nil
function Naafiri:ForceWOnTarget(tar)
	self.wTar = tar
end

function Naafiri:ForcedW()
	if(self.wTar == nil) then return end

	if(myHero.activeSpell.name == "NaafiriW") then
		self.wTar = nil
		return 
	end

	if(self.wTar ~= nil) then
		if(IsValid(self.wTar)) then
			if(GetDistance(self.wTar, myHero) > (self:GetWRange() + E.Range)) then
				self.wTar = nil
				return
			end
		end
	end
	
	if(Ready(_W) and self.wTar ~= nil) then
		if(IsValid(self.wTar)) then
			Control.CastSpell(HK_W, self.wTar)
			return
		else
			self.wTar = nil
			return
		end
	else
		self.wTar = nil
		return 
	end
end

function Naafiri:SemiManualEngage()
	_G.SDK.Orbwalker:Orbwalk()
	
	if(gameTick > GameTimer()) then return end	

	if(Ready(_W)) then
		local target = GetTarget(self:GetWRange())
		if(target and IsValid(target)) then
			Control.CastSpell(HK_W, target)
			gameTick = GameTimer() + 0.2
			return
		end
	end

	if(self.Menu.Combo.EngageSettings.UseE:Value()) then
		if(Ready(_E) and Ready(_W)) then
			local EMaxDist = self:GetWRange() + E.Range
			local target = GetTarget(EMaxDist - 15)
			if(target and IsValid(target) and self:IsKillable(target)) then

				--WALL Check
				local isHittingWall = false
				if MapPosition:intersectsWall(myHero.pos, target.pos) then
					if(MapPosition:inWall(myHero.pos:Extended(target.pos, E.Range)) == 1) then
						isHittingWall = true
					end
				end

				if(GetDistance(myHero, target) > self:GetWRange() and GetDistance(myHero, target) <= EMaxDist) and not isHittingWall then
					Control.CastSpell(HK_E, target.pos)
					gameTick = GameTimer() + 0.2
					return
				end
			end
		end
	end

end

function Naafiri:SemiManualFlashEngage()
	_G.SDK.Orbwalker:Orbwalk()
	
	if(gameTick > GameTimer()) then return end	

	if(Ready(_W)) then
		local target = GetTarget(self:GetWRange())
		if(target and IsValid(target)) then
			Control.CastSpell(HK_W, target)
			gameTick = GameTimer() + 0.2
			return
		end
	end

	if(Ready(_E) and Ready(_W)) then
		local EMaxDist = self:GetWRange() + E.Range
		local target = GetTarget(EMaxDist - 15)
		if(target and IsValid(target)) then

			--WALL Check
			local isHittingWall = false
			if MapPosition:intersectsWall(myHero.pos, target.pos) then
				if(MapPosition:inWall(myHero.pos:Extended(target.pos, E.Range)) == 1) then
					isHittingWall = true
				end
			end
			if(GetDistance(myHero, target) > self:GetWRange() and GetDistance(myHero, target) <= EMaxDist) and not isHittingWall then
				Control.CastSpell(HK_E, target.pos)
				gameTick = GameTimer() + 0.2
				return
			end
		end
	end

	local flashRange = 400
	local canFlash = CanFlash()

	if(Ready(_E) and Ready(_W) and canFlash) then
		local FlashEMaxDist = self:GetWRange() + E.Range + flashRange
		local target = GetTarget(FlashEMaxDist - 15)
		if(target and IsValid(target) and target.toScreen.onScreen) then
			if (GetDistance(target.pos, Game.mousePos()) > 1600) then return end
			--WALL Check
			local isHittingWall = false
			if MapPosition:intersectsWall(myHero.pos, target.pos) then
				if(MapPosition:inWall(myHero.pos:Extended(target.pos, flashRange)) == 1) then
					isHittingWall = true
				end
			end
			if(GetDistance(myHero, target) > (self:GetWRange() + E.Range + 50) and GetDistance(myHero, target) <= FlashEMaxDist) and not isHittingWall then
				UseFlash()
				_G.Control.CastSpell(HK_E, target.pos)
				return
			end
		end
	end

end

function Naafiri:ManualKeys()
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

function Naafiri:IsInTeamfight()
	--Team fights for this would be considered at least 2 enemies and 1 nearby ally
	local enemies = GetEnemyHeroes(Q.Range)
	if(#enemies >= 2) then
		--Ally check
		local allies = GetAllyHeroes(self:GetWRange())
		if(#allies >= 1) then
			return true
		end
	end
	
	return false
end

local dataTick = GameTimer()
function Naafiri:UpdateComboDamage()
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

function Naafiri:IsKillable(unit)
	local isKillable = false
	local igniteOverkill = false
	local igniteDmg = 50 + (20 * myHero.levelData.lvl)

	if(self.ComboDamageData[unit.networkID] ~= nil) then	
		local dmg = self.ComboDamageData[unit.networkID]
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

function Naafiri:GetTotalDamage(unit)
	local totalDmg = 0

	--Q
	if(Ready(_Q) or myHero.activeSpell.name == "NaafiriQ") then
		local QDmg = 0
		if(HasBuff(myHero, "NaafiriQRecast") == false) then
			QDmg = self:GetRawAbilityDamage("Q1")
			QDmg = QDmg + self:GetQ2MaxPossibleDamage(unit)
		else
			local bleedBuff = GetBuffData(unit, "NaafiriQBleed")
			if(bleedBuff.count > 0) then
				QDmg = QDmg + self:GetQ2MaxPossibleDamage(unit)
			else
				QDmg = self:GetRawAbilityDamage("Q1")
			end
		end
		QDmg = CalcPhysicalDamage(myHero, unit, QDmg)
		totalDmg = totalDmg + QDmg
	end

	--W
	if(Ready(_W) or myHero.activeSpell.name == "NaafiriW") then
		local WDmg = self:GetRawAbilityDamage("W")
		WDmg = CalcPhysicalDamage(myHero, unit, WDmg)
		totalDmg = totalDmg + WDmg

		--We can make the assumption that we will AA once after landing W
		local AADmg = CalcPhysicalDamage(myHero, unit, myHero.totalDamage)
		totalDmg = totalDmg + AADmg
	end

	--E
	if(Ready(_E)) then
		local EDmg = self:GetRawAbilityDamage("E")
		EDmg = CalcPhysicalDamage(myHero, unit, EDmg)
		totalDmg = totalDmg + EDmg
	end

	if(self.Menu.Combo.UseIgnite:Value()) then
		if(CanUseSummoner(myHero, "SummonerDot")) then
			local igniteDmg = 50 + (20 * myHero.levelData.lvl)
			totalDmg = totalDmg + igniteDmg
		end
	end

	if HasElectrocute() then
		local baseDmg = 30+(150/(17*(myHero.levelData.lvl)))
		local bonusDmg = (myHero.ap * 0.25)+(myHero.bonusDamage*0.4)
		local value = baseDmg + bonusDmg 
		local ElecDmg=_G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL , value )
		totalDmg= totalDmg + ElecDmg
	end

	if(self:HasItem(ITEM_PROWLERSCLAW)) then
		local prowlersDmg = 85 + (0.55 * myHero.bonusDamage)
		prowlersDmg = CalcPhysicalDamage(myHero, unit, prowlersDmg)
		totalDmg= totalDmg + prowlersDmg
	end

	--Bonus AA Calc
	local AADmg = CalcPhysicalDamage(myHero, unit, myHero.totalDamage)
	totalDmg = totalDmg + AADmg

	--This is not an accurate calculation of Duskblade since your damage would be dynamically updating with their health, but it's better than no calculation at all
	if(self:HasDuskblade()) then
		local duskMult = math.min(((1 - (unit.health / unit.maxHealth)) / 7) * 1.8, 0.18)
		totalDmg= totalDmg * (1 + duskMult)
	end

	return totalDmg
end

function Naafiri:CalculateOverkillAmount(unit)
	-- Returns between 0 and 1
	-- 0 means a 0% overkill, your combo matched their healthpool.
	-- 1 means a 100% overkill, you did double of their health with your combo.
	local totalDmg = 0
	if(self.ComboDamageData[unit.networkID] ~= nil) then	
		local dmg = self.ComboDamageData[unit.networkID]
		if(unit.health - dmg <= 0) then
			local overkillRatio = math.min(((dmg - unit.health) / unit.maxHealth), 1)

			return overkillRatio
		end
	end

	return nil
end

function Naafiri:GetWRange()
	local bonusRange = ({0, 80, 160, 240})[myHero:GetSpellData(_R).level + 1]
	return 700 + bonusRange
end

--Note: Q does 70% damage to minions
function Naafiri:GetRawAbilityDamage(spell)
	if(spell == "Q1") then
		return ({35, 45, 55, 65, 75})[myHero:GetSpellData(_Q).level] + (0.2 * myHero.bonusDamage)
	end

	if(spell == "W") then
		local initDam = ({30, 70, 110, 150, 190})[myHero:GetSpellData(_W).level] + (0.8 * myHero.bonusDamage)
		local packmateDam = (({3, 7, 11, 15, 19})[myHero:GetSpellData(_W).level] + (0.08 * myHero.bonusDamage)) * (#self.PackmateData)

		--Empowered Auto
		local packmateAADmg = 6 + ((myHero.levelData.lvl - 1)*1.4) + (0.045 * myHero.bonusDamage)
		local empPackmateAA = (packmateAADmg * 1.3) * (#self.PackmateData)
		local dam = initDam + packmateDam + empPackmateAA
		return dam
	end

	if(spell == "E") then
		return ({100, 150, 200, 250, 300})[myHero:GetSpellData(_E).level] + (1.3 * myHero.bonusDamage)
	end

	if(spell == "EFlurry") then
		return ({65, 100, 135, 170, 205})[myHero:GetSpellData(_E).level] + (0.8 * myHero.bonusDamage)
	end

	return 0
end

function Naafiri:GetQ2Damage(unit)
	if(unit.valid) then
		local bleedBuff = GetBuffData(unit, "NaafiriQBleed")
		local popDamage = 0
		local dmg = 0
		if(bleedBuff) then
			local tickAmount = math.ceil(bleedBuff.duration/0.5)
			popDamage = ({3, 6, 9, 12, 15})[myHero:GetSpellData(_Q).level] + (0.08 * myHero.bonusDamage)
			popDamage = popDamage * tickAmount
		end
		local missingHPRatio = (1 - (unit.health / unit.maxHealth))
		dmg = ({30, 45, 60, 75, 90})[myHero:GetSpellData(_Q).level] + (0.4 * myHero.bonusDamage)
		dmg = dmg * (1 + missingHPRatio)
		return dmg + popDamage
	end
end

function Naafiri:GetQ2MaxPossibleDamage(unit)
	if(unit.valid) then
		local popDamage = 0
		local dmg = 0

		local tickAmount = math.ceil(4.25/0.5)
		popDamage = ({3, 6, 9, 12, 15})[myHero:GetSpellData(_Q).level] + (0.08 * myHero.bonusDamage)
		popDamage = popDamage * tickAmount

		local missingHPRatio = (1 - (unit.health / unit.maxHealth))
		dmg = ({30, 45, 60, 75, 90})[myHero:GetSpellData(_Q).level] + (0.4 * myHero.bonusDamage)
		dmg = dmg * (1 + missingHPRatio)
		return dmg + popDamage
	end
end

function Naafiri:GetPassiveCooldown()
	return myHero:GetSpellData(63).currentCd
end

function Naafiri:HasItem(itemId)
    for i = ITEM_1, ITEM_7 do
		local id = myHero:GetItemData(i).itemID
        if id == itemId then
			if(myHero:GetSpellData(i).currentCd == 0) then
				return true, i
			else
				return false
			end
        end
    end
	return false
end

function Naafiri:HasDuskblade()
    for i = ITEM_1, ITEM_7 do
		local id = myHero:GetItemData(i).itemID
        if id == ITEM_DUSKBLADE then
			return true
        end
    end

	return false 
end

function Naafiri:HasRActive()
	local rBuff = GetBuffData(myHero, "NaafiriR")
	return rBuff.count > 0
end

function Naafiri:GetMaxPossiblePackmateCount()
	if(myHero.levelData.lvl >= 9) then
		return 3
	end
	return 2
end

function Naafiri:GetNumberPackmates()
	return #self.PackmateData
end

function Naafiri:CheckExistingPackmate(unit)
	for _, packmate in pairs(self.PackmateData) do
		if(packmate.networkID == unit.networkID) then
			return true
		end
	end
	return false
end

function Naafiri:CleanupPackmateData()
	for i = #self.PackmateData, 1, -1 do
		local packmate = self.PackmateData[i]
		if(packmate.dead) then
			table.remove(self.PackmateData, i)
		end
	end
end

local NaafiriPassiveStaticCD = {
	[1] = 25,
	[6] = 20,
	[11] = 15,
	[16] = 10
}

function Naafiri:UpdatePackmateData()
	self:CleanupPackmateData()

	--Code to calculate our passive CD
	local staticCD = 25
	for k, v in pairs(NaafiriPassiveStaticCD) do
		if(myHero.levelData.lvl >= k) then
			staticCD = v
		end
	end

	--If we just started counting down our passive cooldown, double check our dogs
	if(self:GetPassiveCooldown() >= (staticCD - 1.5)) then
		self:ScanPackmates()
	end

	self:AbilityUpdatePackmates()

	if(#self.PackmateData < self:GetMaxPossiblePackmateCount()) then
		local passiveCd = self:GetPassiveCooldown()
		if(passiveCd<=1) then
			self:ScanPackmates()
		end

		self:CheckForPackmateChanges()
	end
end

function Naafiri:ScanPackmates()
	self:CleanupPackmateData()
	local packmates = {}
	local packmatesParse = _G.SDK.ObjectManager:GetAllyMinions(1500)

	--Check for nearby packmates
	for _, packmate in ipairs(packmatesParse) do
		if(packmate.charName == "NaafiriPackmate") then
			if(packmate and not packmate.dead) then
				table.insert(packmates, packmate)
			end
		end
	end
	self.PackmateData = packmates
end

Naafiri.shouldSearchForDogs = false
function Naafiri:AbilityUpdatePackmates()
	--When you use E or W, your packmate count goes to 0, this will force scan until this value is no longer 0
	if(myHero.activeSpell.valid) then
		if(myHero.activeSpell.name == "NaafiriE" or myHero.activeSpell.name == "NaafiriW") then
			self.shouldSearchForDogs = true
		end
	end

	if(self.shouldSearchForDogs and #self.PackmateData == 0) then
		self:ScanPackmates()
		return
	end

	if(self.shouldSearchForDogs and #self.PackmateData ~= 0) then
		self.shouldSearchForDogs = false
		return
	end
end

local searchTimer = GameTimer()
function Naafiri:CheckForPackmateChanges()
	if(GameTimer() <= searchTimer) then return end
	self:CleanupPackmateData()
	local packmates = {}
	local packmatesParse = _G.SDK.ObjectManager:GetAllyMinions(1500)

	for _, packmate in ipairs(packmatesParse) do
		if(packmate.charName == "NaafiriPackmate") then
			if(packmate and not packmate.dead) then
				table.insert(packmates, packmate)
			end
		end
	end

	if(#packmates == #self.PackmateData) then
		self.PackmateData = packmates
		searchTimer = GameTimer() + self:GetPassiveCooldown()
	else
		self.PackmateData = packmates
	end
end

local alphaLerp = 0
local lerpS, lerpE = nil, nil
function Naafiri:Draw()
	if myHero.dead then return end
	--local missileCount = memoizeMissileCount({}, 2)
	if(self.Menu.Drawings.DrawQ:Value()) then
		if(myHero:GetSpellData(_Q).level > 0) then
			if(myHero:GetSpellData(_Q).currentCd == 0) then
				DrawCircle(myHero, Q.Range, 1, DrawColor(130, 235, 64, 52))
			else
				DrawCircle(myHero, Q.Range, 1, DrawColor(30, 235, 64, 52))
			end
		end
	end

	if(self.Menu.Flee.UseWallHop:Value()) then
		if(GetMode() == "Flee") then
			if(self.hopEPos ~= nil and self.hopSPos ~= nil) then
				if(lerpS == nil) then
					lerpS = self.hopSPos
				end

				if(lerpE == nil) then
					lerpE = self.hopEPos
				end
				local col = DrawColor(255, 215, 215, 0)

				lerpS = Lerp(lerpS, self.hopSPos, 0.2)
				lerpE = Lerp(lerpE, self.hopEPos, 0.2)
				DrawCircle(lerpS, 5, 25, col)
				DrawCircle(lerpS, 20, 5, col)
				DrawCircle(lerpE, 50, 1, col)
				DrawLine(lerpE:To2D(), lerpS:To2D(), 2, col)
			else
				lerpS, lerpE = nil, nil
			end
		else
			lerpS, lerpE = nil, nil
		end
	end

	if(self.Menu.Drawings.DrawW:Value()) then
		if(myHero:GetSpellData(_W).level > 0) then
			if(self:HasRActive()) then
				DrawCircle(myHero, self:GetWRange(), 5, DrawColor(225, 255, 90, 20))
			else
				DrawCircle(myHero, self:GetWRange(), 1, DrawColor(130, 255, 215, 56))
			end
		end
	end

	if(self.Menu.Drawings.DrawE:Value()) then
		if(myHero:GetSpellData(_E).level > 0) then
			DrawCircle(myHero, E.Range, 2, DrawColor(130, 215, 115, 185))
		end
	end

	if(self.Menu.Drawings.DrawPuppers:Value()) then
		if(#self.PackmateData > 0) then
			for _, pupper in ipairs(self.PackmateData) do
				if(pupper.valid) then
					DrawCircle(pupper, 125, 1, DrawColor(85, 255, 32, 32))
				end
			end
		end
	end

	if(self.Menu.Drawings.DrawEngageUI:Value()) then
		if(self.Menu.Combo.EngageSettings.SemiManualEngage:Value()) then
			if(Ready(_W) == false) then 
				if(myHero:GetSpellData(_W).currentCd <= 10 and (myHero:GetSpellData(_W).level > 0)) then
					local fontSize = 55
					local eCD = string.format("%.1f", myHero:GetSpellData(_W).currentCd)
					local pos = {x = myHero.pos:To2D().x - fontSize + 24, y = myHero.pos:To2D().y + 50}
					DrawText(eCD, fontSize, Vector(pos), DrawColor(255, 255, 80, 120))
				end
			else
				self:DrawEngageUI()
			end
		end

		if(self.Menu.Combo.EngageSettings.SemiManualFlashEngage:Value()) then
			if(Ready(_W) == false) then 
				if(myHero:GetSpellData(_W).currentCd <= 10 and (myHero:GetSpellData(_W).level > 0)) then
					local fontSize = 55
					local eCD = string.format("%.1f", myHero:GetSpellData(_W).currentCd)
					local pos = {x = myHero.pos:To2D().x - fontSize + 24, y = myHero.pos:To2D().y + 50}
					DrawText(eCD, fontSize, Vector(pos), DrawColor(255, 255, 80, 120))
				end
			else

				local flashRange = 400
				local canFlash = CanFlash()

				if(canFlash) then
					DrawCircle(myHero.pos, self:GetWRange() + E.Range + flashRange, 1, DrawColor(35, 125, 125, 125))
				else
					DrawCircle(myHero.pos, self:GetWRange() + E.Range, 1, DrawColor(35, 125, 125, 125))
				end
				self:DrawFlashEngageUI()
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

	if(self.Menu.Drawings.DrawKillableTargets:Value()) then
		self:DrawKillable()
	end
end

function Naafiri:DrawDotLines(pos1, pos2, visibleRange, color, lineCount)
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

function Naafiri:DrawEngageUI()
	local closetTarget = nil
	local targets = GetEnemyHeroes(1900)
	for _, target in ipairs(targets) do
		if(closetTarget == nil) then
			closetTarget = target
		end
		if(GetDistance(myHero, target) <= GetDistance(myHero, closetTarget)) then
			closetTarget = target
		end
	end

	if(IsValid(closetTarget)) then
		if(GetDistance(closetTarget, myHero) >= self:GetWRange()) then
			local pos1 = myHero.pos:Extended(closetTarget.pos, self:GetWRange())
			local UIColor = {a = 255, r = 255, g = 80, b = 110}
			self:DrawDotLines(pos1, closetTarget.pos, 1000, UIColor, 10)
			DrawCircle(pos1, 2, 25, DrawColor(UIColor.a, UIColor.r, UIColor.g, UIColor.b))
			DrawCircle(closetTarget, 10, 10, DrawColor(UIColor.a, UIColor.r, UIColor.g, UIColor.b))
		end
	end
end

function Naafiri:DrawFlashEngageUI()
	local closetTarget = nil
	local targets = GetEnemyHeroes(2200)
	for _, target in ipairs(targets) do
		if(closetTarget == nil) then
			closetTarget = target
		end
		if(GetDistance(myHero, target) <= GetDistance(myHero, closetTarget)) then
			closetTarget = target
		end
	end

	local flashRange = 400
	local canFlash = CanFlash()

	local dist = self:GetWRange() + E.Range

	if(canFlash) then
		dist = self:GetWRange() + E.Range + flashRange
	end

	if(IsValid(closetTarget)) then
		if(GetDistance(closetTarget, myHero) >= dist) then
			local pos1 = myHero.pos:Extended(closetTarget.pos, dist)
			local UIColor = {a = 255, r = 255, g = 225, b = 40}
			self:DrawDotLines(pos1, closetTarget.pos, 1000, UIColor, 10)
			DrawCircle(pos1, 2, 25, DrawColor(UIColor.a, UIColor.r, UIColor.g, UIColor.b))
			DrawCircle(closetTarget, 10, 10, DrawColor(UIColor.a, UIColor.r, UIColor.g, UIColor.b))
		end
	end
end

function Naafiri:DrawKillable()
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

function Naafiri:DrawDamageHPBars()

	for _, enemy in pairs(Enemies) do
		if(IsValid(enemy)) then
			if(enemy.toScreen.onScreen) then
				if(Ready(_Q) or Ready(_W) or Ready(_E)) then
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

					--Overkill bar
					if(self.Menu.Drawings.DamageHPBar.ShowOverKillBar:Value()) then
						if(enemy.health - dmg <= 0) then
							Draw.Rect(bar.x - (barLength/2) -3, bar.y + barOffset + 6, barLength +6, barHeight + 3, DrawColor(225 * alphaLerp, 0, 0, 0))

							local overkillRatio = math.min(((dmg - enemy.health) / enemy.maxHealth), 1)
							Draw.Rect(bar.x - (barLength/2), bar.y + barOffset + barHeight + 3, barLength * (overkillRatio), barHeight, DrawColor(255 * alphaLerp, 161, 11, 131))
						end
					end
				end
			end
		end
	end
end

function Naafiri:DrawKillReticle(unit)
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

Naafiri()
LoadUnits()
