require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.01

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Veigar will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

--=============--

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
		if(myHero:GetSpellData(_Q).currentCd) > 0 and myHero:GetSpellData(_Q).cd ~= 0 then
			self.QDidCast = true
			local spell = myHero:GetSpellData(_Q)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.WDidCast == false) then
		if(myHero:GetSpellData(_W).currentCd) > 0 and myHero:GetSpellData(_W).cd ~= 0 then
			self.WDidCast = true
			local spell = myHero:GetSpellData(_W)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.EDidCast == false) then
		if(myHero:GetSpellData(_E).currentCd) > 0 and myHero:GetSpellData(_E).cd ~= 0 then
			self.EDidCast = true
			local spell = myHero:GetSpellData(_E)
			for i, Emit in pairs(self.OnSpellCastCallback) do
				Emit(spell)
			end
		end
	end
	
	if(self.RDidCast == false) then
		if(myHero:GetSpellData(_R).currentCd) > 0 and myHero:GetSpellData(_R).cd ~= 0 then
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
	if(Ready(_Q)) then self.QDidCast = false end
	if(Ready(_W)) then self.WDidCast = false end
	if(Ready(_E)) then self.EDidCast = false end
	if(Ready(_R)) then self.RDidCast = false end
end

local function OnSpellCast(fn)
    if not _SPELLCAST_START then
        _G.SpellCast = SpellCast()
    end
    table.insert(SpellCast.OnSpellCastCallback, fn)
end

--== Strafe Prediction==--

class("StrafePred")

StrafePred.WaypointData = {}
StrafePred.NewPosData = {}

function StrafePred:__init()
    _G._STAFEPRED_START = true
    self.OnStrafePredCallback = {}
    Callback.Add("Tick", function() self:OnTick() end)
	
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local enemyUnit = args.unit
		self.WaypointData[enemyUnit.handle] = {}
		self.NewPosData[enemyUnit.handle] = {x = 0, z = 0}
		
	end)
	
end
 
local waypointLimit = 4
local strafeMargin = 0.5 --The closer this value is to 1, the more strict the strafe check will be
local stutterDistMargin = 125

function StrafePred:OnTick()	
	for _, unit in pairs(Enemies) do
		if(unit.valid and IsValid(unit)) then
			if(unit.pathing.hasMovePath) and (self.NewPosData[unit.handle])  then
				local newPos = self.NewPosData[unit.handle]
				if(unit.pathing.endPos.x ~= newPos.x and unit.pathing.endPos.z ~= newPos.z ) then
					self.NewPosData[unit.handle] = unit.pathing.endPos
					local endPosVec = Vector(unit.pathing.endPos.x, unit.pos.y, unit.pathing.endPos.z)
					local startPosVec = Vector(unit.pathing.startPos.x, unit.pos.y, unit.pathing.startPos.z)
					local nVec = Vector(endPosVec - startPosVec):Normalized()

					if(self.WaypointData[unit.handle] ~= nil or self.WaypointData[unit.handle]) then
						self:AddWaypointData(unit, {nVec, GameTimer(), unit.pos})
					end
					
				end
			end
		end
	end
	
end

function StrafePred:AddWaypointData(unit, tbl)
	local uName = unit.handle
	for i = #self.WaypointData[uName], 1, -1 do
		self.WaypointData[uName][i + 1] = self.WaypointData[uName][i]
	end
	if(#self.WaypointData[uName] > waypointLimit) then
		table.remove(self.WaypointData[uName], waypointLimit + 1)
	end
	self.WaypointData[uName][1] = tbl
end

function StrafePred:IsStrafing(tar)
	local tName = tar.handle
	if(tar.pathing.hasMovePath == false) then return false end
	if(self.WaypointData[tName] ~= nil or self.WaypointData[tName]) then
		if(#self.WaypointData[tName] == waypointLimit) then
			--Dot product check
			local res1 = dotProduct(self.WaypointData[tName][1][1], self.WaypointData[tName][2][1])
			local res2 = dotProduct(self.WaypointData[tName][1][1], self.WaypointData[tName][3][1])
			local res3 = dotProduct(self.WaypointData[tName][1][1], self.WaypointData[tName][4][1])
			local timebetweenWaypoints = self.WaypointData[tName][1][2] - self.WaypointData[tName][2][2] -- Time between waypoint update
			local lastWaypointTime = GameTimer() - self.WaypointData[tName][1][2] --Time between last waypoint and game time
			
			local pos1 = self.WaypointData[tName][1][3]
			local pos2 = self.WaypointData[tName][2][3]
			local pos3 = self.WaypointData[tName][3][3]
			local pos4 = self.WaypointData[tName][4][3]
			local avgPos = (pos1+pos2+pos3+pos4)/4

			if(res1 <= -strafeMargin and res2 >= strafeMargin and res3 <= -strafeMargin and timebetweenWaypoints <= 0.70 and lastWaypointTime <= 0.7) then
				return true, avgPos
			else
				return false
			end
		end
	else
		return false
	end
	
	return false
end

function StrafePred:IsStutterDancing(tar)
	local tName = tar.handle
	if(tar.pathing.hasMovePath == false) then return false end
	if(self.WaypointData[tName] ~= nil or self.WaypointData[tName]) then
		if(#self.WaypointData[tName] == waypointLimit) then

			local pos1 = self.WaypointData[tName][1][3]
			local pos2 = self.WaypointData[tName][2][3]
			local pos3 = self.WaypointData[tName][3][3]
			local pos4 = self.WaypointData[tName][4][3]
			local avgPos = (pos1+pos2+pos3+pos4)/4
			

			local timebetweenWaypoints = self.WaypointData[tName][1][2] - self.WaypointData[tName][2][2] -- Time between waypoint update
			local lastWaypointTime = GameTimer() - self.WaypointData[tName][1][2] --Time between last waypoint and game time
			
			if(tar.pos:DistanceTo(avgPos) <= stutterDistMargin and tar.pos:DistanceTo(pos4) <= stutterDistMargin and timebetweenWaypoints <= 0.90 and lastWaypointTime <= 1 ) then
				return true, avgPos
			end
		end
	else
		return false
	end
	
	return false
end

local function OnChampStrafe(fn)
    if not _STAFEPRED_START then
        _G.StrafePred = StrafePred()
    end
    table.insert(StrafePred.OnStrafePredCallback, fn)
end

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Veigar"

local ChampIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/45.png"

local gameTick = GameTimer()
local WBufferTick = GameTimer()
Veigar.AutoLevelCheck = false

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 900, Radius = 140, Speed = 2200, Collision = true, MaxCollision = 2, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
local W = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.47, Radius = 240, Range = 900, Speed = math.huge, Collision = false}
local E = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.80, Radius = 390, Range = 725, Speed = math.huge, Collision = false}
local EEdge = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.80, Radius = 30, Range = 1100, Speed = math.huge, Collision = false}
local R = {Range = 650, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}

Veigar.EData = {}
Veigar.ComboDamageData = {}

--Main Menu
Veigar.Menu = MenuElement({type = MENU, id = "KillerVeigar", name = "Killer Veigar", leftIcon = ChampIcon})
Veigar.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

Veigar.InterruptableSpells = {
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

function Veigar:__init()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	--Custom Callbacks
	OnSpellCast(function(spell) self:OnSpellCast(spell) end)
	StrafePred()
	_G.SDK.Orbwalker:OnPreAttack(function(...) Veigar:OnPreAttack(...) end)
end

function Veigar:LoadMenu()                     	

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "WSettings", name = "W Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.Combo:MenuElement({id = "SmartAABlock", name = "Smart AA Block", value = true})
	self.Menu.Combo:MenuElement({id = "SemiManualE", name = "Semi-manual E", key = string.byte("Z")})
	
	self.Menu.Combo.WSettings:MenuElement({id = "UseW", name = "Use W in Cage", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "UseWNormal", name = "Use W while E is on CD", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "WPeel", name = "Use W to Peel Off Melee", value = true})
	self.Menu.Combo.WSettings:MenuElement({id = "WStrafing", name = "Use W on Strafing Targets", value = false})
	self.Menu.Combo.WSettings:MenuElement({id = "WFleeing", name = "Use W on Fleeing Targets", value = true})
	
	-- Harass
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "KillCannon", name = "Prioritize Canon Minion", value = true})
	self.Menu.Harass:MenuElement({id = "QMana", name = "Q Min Mana", value = 10, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Harass:MenuElement({id = "UseW", name = "Use W on Enemies Going for Last Hit", value = true})
	self.Menu.Harass:MenuElement({id = "WMana", name = "W Min Mana", value = 30, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Last Hit
	self.Menu:MenuElement({id = "LastHit", name = "Last Hit", type = MENU})
	self.Menu.LastHit:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.LastHit:MenuElement({id = "TowerFarmAssist", name = "Tower Farming Assist", value = true})
	
	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Clear:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Clear:MenuElement({id = "WMana", name = "W Min Mana", value = 20, min = 0, max = 100, step = 5, identifier = "%"})
	
	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseR", name = "Use R", value = true})
	
	self.Menu:MenuElement({id = "AutoW", name = "Auto W on Immobile", value = true})
	self.Menu:MenuElement({id = "AutoE", name = "Auto E to Stop Dangerous Channels", value = true})
	self.Menu:MenuElement({id = "AutoECC", name = "Auto E on CC'd Targets", value = true})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQW", name = "Draw Q & W Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawE", name = "Draw E Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawKillableTargets", name = "Draw Killable Targets", value = true})
	self.Menu.Drawings:MenuElement({id = "DamageHPBar", name = "Damage HP Bar", type = MENU})
	self.Menu.Drawings:MenuElement({id = "Debug", name = "Debug Drawings", type = MENU})
	
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "DrawDamageHPBar", name = "Draw Full Combo Damage", value = true})
	self.Menu.Drawings.DamageHPBar:MenuElement({id = "YOffset", name = "Y Offset", value = 60, min = -100, max = 100, step = 5})
	-- debug.debug
	self.Menu.Drawings.Debug:MenuElement({id = "DrawParticles", name = "Draw Particles", value = false})
	
	-- Prediction
	self.Menu:MenuElement({id = "Prediction", name = "Prediction", type = MENU})
	self.Menu.Prediction:MenuElement({id = "QHitChance", name = "Q Hit Chance",  value = 2, drop = {"Normal", "High", "Immobile"}})
		
	self.Menu:MenuElement({id = "AutoLevel", name = "Auto Level Skills (Q - E - W)", value = false})
end


function Veigar:Tick()
	if(MyHeroNotReady()) then return end
	
	if(IsInFountain()) then
		_G.SDK.Orbwalker:SetMovement(false)
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
	
	self:UpdateEData()
	self:UpdateComboDamage()
	self:KillSteal()
	
	
	if(self.Menu.Combo.SmartAABlock:Value()) then
		self:SmartAABlock()
	end
	
	if(self.Menu.AutoW:Value()) then
		self:AutoWImmobile()
	end
	
	if(self.Menu.AutoE:Value()) then
		self:EInterrupter()
	end
	
	if(self.Menu.AutoECC:Value()) then
		self:EInterrupterCC()
	end
	
	if(self.Menu.Combo.SemiManualE:Value()) then
		self:SemiManualE()
	end
	
	if Game.IsOnTop() and self.Menu.AutoLevel:Value() then
		self:AutoLevel()
	end	
end

function Veigar:OnPreAttack(args)
    if GetMode()=="Combo" and (Ready(_Q)) then
        args.Process = false
    end
end

function Veigar:OnSpellCast(spell)
	if spell.name == "VeigarEventHorizon" then
		DelayAction(function()
            self:CheckE()
			WBufferTick = GameTimer() + 0 --Gives us a small window to react with our W after casting E, mostly used when they are in the cage
        end, E.Delay)
	end
end

function Veigar:CheckExistingE(obj)
	for _, e in pairs(self.EData) do
		if(e.networkID == obj.networkID) then
			return true
		end
	end
	return false
end

function Veigar:CheckE()
	local particleCount = Game.ParticleCount()
	for i = particleCount, 1, -1 do
		local obj = Game.Particle(i)
		local nameCheck = obj.name:lower():find("_e_cage_green")
		if obj and obj.type == "obj_GeneralParticleEmitter" and nameCheck and self:CheckExistingE(obj) == false then
			self.EData[#self.EData + 1] = obj
		end
	end
end

function Veigar:UpdateEData()
	for i = #self.EData, 1, -1 do
		local e = self.EData[i]
		if(e.type ~= "obj_GeneralParticleEmitter") then
			table.remove(self.EData, i)
		end
	end
end

function Veigar:AutoLevel()
	if self.AutoLevelCheck then return end
	
	local level = myHero.levelData.lvl
	local levelPoints = myHero.levelData.lvlPts

	if (levelPoints == 0) or (level == 1) then return end
	if (Game.mapID == HOWLING_ABYSS and level <= 3) then return end
	--Order = Q > E > W
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
					Control.KeyDown(HK_Q)
					Control.KeyUp(HK_Q)
					Control.KeyUp(HK_LUS)
				elseif level == 2 or level == 8 or level == 10 or level == 12 or level == 13 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_E)
					Control.KeyUp(HK_E)
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

function Veigar:Combo()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	--Q
	if(self.Menu.Combo.UseQ:Value()) then
		if(Ready(_Q)) then
			local target = GetTarget(Q.Range -10)
			if(target and IsValid(target) and target.toScreen.onScreen) then
				local isStrafing, avgPos = StrafePred:IsStrafing(target)
				local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
				
				if(isStrafing) then
					if(avgPos:DistanceTo(myHero.pos) < Q.Range) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, avgPos, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, target.networkID)
						if(collisionCount <= Q.MaxCollision) then
							Control.CastSpell(HK_Q, avgPos)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
				if(isStutterDancing) then
					if(avgPos2:DistanceTo(myHero.pos) < Q.Range) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, avgPos2, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, target.networkID)
						if(collisionCount <= Q.MaxCollision) then
							Control.CastSpell(HK_Q, avgPos2)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
				
				local QPrediction = GGPrediction:SpellPrediction(Q)
				QPrediction:GetPrediction(target, myHero)
				if QPrediction.CastPosition and QPrediction:CanHit(self.Menu.Prediction.QHitChance:Value() + 1) then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, QPrediction.CastPosition, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, target.networkID)
					if(collisionCount <= Q.MaxCollision) then
						Control.CastSpell(HK_Q, QPrediction.CastPosition)
						gameTick = GameTimer() + 0.2
						return
					end
				end
				
			end
		end
	end
	
	--W
	if(self.Menu.Combo.WSettings.UseW:Value()) then
		if(Ready(_W) and WBufferTick < GameTimer()) then
			local target = GetTarget(W.Range + W.Radius -10)
			if(target and IsValid(target) and target.toScreen.onScreen) then
				local isInside, eObj = self:IsUnitInsideE(target)
				if(isInside and eObj and IsImmobile(target) <= 0) then
				
					local isStrafing, avgPos = StrafePred:IsStrafing(target)
					local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
					if(isStrafing) then
						if(avgPos:DistanceTo(myHero.pos) < W.Range) then
							Control.CastSpell(HK_W, avgPos)
							gameTick = GameTimer() + 0.2
							return
						end
					end
					if(isStutterDancing) then
						if(avgPos2:DistanceTo(myHero.pos) < W.Range) then
							Control.CastSpell(HK_W, avgPos2)
							gameTick = GameTimer() + 0.2
							return
						end
					end
					local WPrediction, isExtended = GetExtendedSpellPrediction(target, W)
					if WPrediction:CanHit(HITCHANCE_NORMAL) then
						if(isExtended) then
							local castPos = myHero.pos:Extended(WPrediction.CastPosition, W.Range)
							Control.CastSpell(HK_W, castPos)
							gameTick = GameTimer() + 0.2
							return
						else
							--Smart placement of W
							local distCheck = (eObj.pos:DistanceTo(target.pos))
							if(distCheck <= 135) then
								Control.CastSpell(HK_W, target.pos)
								gameTick = GameTimer() + 0.2
								return
							else
								local placementPos = eObj.pos:Extended(target.pos, E.Radius/2 - 35)
								Control.CastSpell(HK_W, placementPos)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end
					
				end
				
			end
		end
	end
	
	--W Melee Peel
	if(self.Menu.Combo.WSettings.WPeel:Value()) then
		if(Ready(_W) and WBufferTick < GameTimer()) then
			local target = GetTarget(W.Radius + 100)
			if(target and IsValid(target) and target.range <= 200 and target.toScreen.onScreen) then
				local isInside, eObj = self:IsUnitInsideE(target)
				if(isInside) then return end
				local checkRunDir = GetUnitRunDirection(myHero, target)
				if(checkRunDir == RUNNING_TOWARDS) then
					Control.CastSpell(HK_W, myHero)
				else
					local WPrediction = GetExtendedSpellPrediction(target, W)
					if WPrediction:CanHit(HITCHANCE_HIGH) then
						--Control.CastSpell(HK_W, WPrediction.CastPosition)
						gameTick = GameTimer() + 0.2
						return
					end
				end
			end
		end
	end
	
	--W Strafing
	if(self.Menu.Combo.WSettings.WStrafing:Value()) then
		if(Ready(_W) and WBufferTick < GameTimer()) then
			local target = GetTarget(W.Range)
			if(target and IsValid(target) and target.toScreen.onScreen) then
				local WPrediction = GetExtendedSpellPrediction(target, W) --Merge pred chance
				if WPrediction:CanHit(HITCHANCE_HIGH) then
					local isStrafing, avgPos = StrafePred:IsStrafing(target)
					local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
					if(isStrafing) then
						if(avgPos:DistanceTo(myHero.pos) < W.Range) then
							Control.CastSpell(HK_W, avgPos)
							gameTick = GameTimer() + 0.2
							return
						end
					end
					if(isStutterDancing) then
						if(avgPos2:DistanceTo(myHero.pos) < W.Range) then
							Control.CastSpell(HK_W, avgPos2)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
			end
		end
	end
	
	--W Fleeing
	if(self.Menu.Combo.WSettings.WFleeing:Value()) then
		if(Ready(_W) and WBufferTick < GameTimer()) then
			local target = GetTarget(W.Range)
			if(target and IsValid(target) and target.toScreen.onScreen) then
				local checkRunDir = GetUnitRunDirection(myHero, target)
				local isInside, eObj = self:IsUnitInsideE(target)
				if(checkRunDir == RUNNING_AWAY and isInside == false) then
					--Conditions where someone may be fleeing
					
					--Target is less than 20% HP
					local condition1 = (target.health / target.maxHealth) <= 0.2 
					
					--You have 30% more HP than the target and they are less than 40% HP
					local condition2 = (myHero.health / myHero.maxHealth) - (target.health / target.maxHealth)>= 0.3 and (target.health / target.maxHealth) <= 0.4
					
					if(condition1 or condition2) then
						local WPrediction = GetExtendedSpellPrediction(target, W)
						if WPrediction:CanHit(HITCHANCE_HIGH) then
							Control.CastSpell(HK_W, WPrediction.CastPosition)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
			end
		end
	end
	
	--W Normal
	if(self.Menu.Combo.WSettings.UseWNormal:Value()) then
		if(Ready(_W) and Ready(_E) == false and WBufferTick < GameTimer()) then
			if (myHero:GetSpellData(_E).cd - myHero:GetSpellData(_E).currentCd) <= E.Delay then return end
			local target = GetTarget(W.Range)
			if(target and IsValid(target) and target.toScreen.onScreen) then
				local isInside = self:IsUnitInsideE(target)
				if(isInside == false) then
					local ECurrCD = myHero:GetSpellData(_E).currentCd
					local WTotalCD = myHero:GetSpellData(_W).cd
					if(ECurrCD > WTotalCD) then --Only use W if your E is on CD
						local WPrediction = GetExtendedSpellPrediction(target, W)
						if WPrediction:CanHit(HITCHANCE_HIGH) then
							Control.CastSpell(HK_W, WPrediction.CastPosition)
						end
					end
				end
			end
		end
	end
	
	--E
	if(self.Menu.Combo.UseE:Value()) then
		if(Ready(_E)) then
			local target = GetTarget(E.Range + E.Radius -15)

			if(target and IsValid(target) and target.toScreen.onScreen) then
				local isStrafing, avgPos = StrafePred:IsStrafing(target)
				local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
				if(isStrafing) then
					if(avgPos:DistanceTo(myHero.pos) < E.Range) then
						Control.CastSpell(HK_E, avgPos)
						gameTick = GameTimer() + 0.2
						return
					end
				end
				if(isStutterDancing) then
					if(avgPos2:DistanceTo(myHero.pos) < E.Range) then
						Control.CastSpell(HK_E, avgPos2)
						gameTick = GameTimer() + 0.2
						return
					end
				end
				
				local EPrediction, isExtended = GetExtendedSpellPrediction(target, E)
				if EPrediction:CanHit(HITCHANCE_HIGH) then
					if(isExtended == false) then
						Control.CastSpell(HK_E, EPrediction.CastPosition)
						gameTick = GameTimer() + 0.333
						return
					else
						if(target.pathing.hasMovePath) then
							local checkRunDir = GetUnitRunDirection(myHero, target)
							if(checkRunDir == RUNNING_AWAY) then
								--print("Running away")
								return
							else
								--print("Running Towards")
								if(target.distance <= (E.Range + E.Radius/2)) then
									local castPos = myHero.pos:Extended(EPrediction.CastPosition, E.Range -10) --The extra number is a buffer to reduce stutter dancing
									Control.CastSpell(HK_E, castPos)
									gameTick = GameTimer() + 0.333
									return
								end
							end
						else
							if(target.distance <= (E.Range + E.Radius/2)) then
								local castPos = myHero.pos:Extended(EPrediction.CastPosition, E.Range -10)
								Control.CastSpell(HK_E, castPos)
								gameTick = GameTimer() + 0.333
								return
							end
						end
					end
				end
			end
		end
	end

	--R
	if(self.Menu.Combo.UseR:Value()) then
		if(Ready(_R)) then
			local target = GetTarget(R.Range)
			if(target and IsValid(target) and target.toScreen.onScreen) then
				if(self:IsKillable(target) and (self:CantKill(target, true, true, false))==false) then
					Control.CastSpell(HK_R, target)
					gameTick = GameTimer() + 0.2
					return
				end
			end
		end
	end
end

function Veigar:Harass()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) --Just do 1 check for optimization
	local canonMinion = GetCanonMinion(minions)
	
	--Q
	if(self.Menu.Harass.UseQ:Value()) then
		if(Ready(_Q) and (myHero.mana / myHero.maxMana) >= (self.Menu.Harass.QMana:Value() / 100)) then
		
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local QDam = self:GetRawAbilityDamage("Q")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (myHero.pos:DistanceTo(canonMinion.pos)/Q.Speed))
				
				if ((hp > 0) and (canonMinion.health + (canonMinion.health*0.05) - QDam <= 0)) then
					Control.CastSpell(HK_Q, canonMinion)
					gameTick = GameTimer() + 0.2
					return
				end
			end
			
			local target = GetTarget(Q.Range)
			if(target and IsValid(target)) then
				local isStrafing, avgPos = StrafePred:IsStrafing(target)
				local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
				
				if(isStrafing) then
					if(avgPos:DistanceTo(myHero.pos) < Q.Range) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, avgPos, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, target.networkID)
						if(collisionCount <= Q.MaxCollision) then
							Control.CastSpell(HK_Q, avgPos)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
				if(isStutterDancing) then
					if(avgPos2:DistanceTo(myHero.pos) < Q.Range) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, avgPos2, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, target.networkID)
						if(collisionCount <= Q.MaxCollision) then
							Control.CastSpell(HK_Q, avgPos2)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
				
				local QPrediction = GGPrediction:SpellPrediction(Q)
				QPrediction:GetPrediction(target, myHero)
				if QPrediction.CastPosition and QPrediction:CanHit(self.Menu.Prediction.QHitChance:Value() + 1) then
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
					gameTick = GameTimer() + 0.2
					return
				end
				
			end
		end
	end
	
	--W
	if(self.Menu.Harass.UseW:Value()) then
		if(Ready(_W)) then
			local tar = GetTarget(W.Range)
			if(tar and IsValid(tar)) then
				local fMinions = _G.SDK.ObjectManager:GetAllyMinions(W.Range + 400) --Just do 1 check for optimization
				for i = 1, #fMinions do
					local minion = fMinions[i]
					if(minion and IsValid(minion)) then
						local hp = _G.SDK.HealthPrediction:GetPrediction(minion, W.Delay)
						if(hp - tar.totalDamage <= 20) and (tar.pos:DistanceTo(minion.pos) <= tar.range) then
							local healthDiff = (minion.health ~= hp)
							if(healthDiff) and (tar.activeSpell.isAutoAttack == false) then
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

local avoidQMinionHandle = 0

function Veigar:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range) --Just do 1 check for optimization
	local canonMinion = GetCanonMinion(minions)
	
	if(myHero.activeSpell.name:find("VeigarBasicAttack")) then
		avoidQMinionHandle = myHero.activeSpell.target
	end
	
	--Q
	if(self.Menu.LastHit.UseQ:Value()) then
		if(Ready(_Q)) then
		
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local QDam = self:GetRawAbilityDamage("Q")
				local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (myHero.pos:DistanceTo(canonMinion.pos)/Q.Speed))
				
				if ((hp > 0) and (canonMinion.health + (canonMinion.health*0.05) - QDam <= 0)) then
					Control.CastSpell(HK_Q, canonMinion)
					gameTick = GameTimer() + 0.2
					return
				end
			end
			
			for i = 1, #minions do
				local minion = minions[i]
				if(minion and IsValid(minion)) then
					--This is to prevent us Q'ing a target we are going to kill with an AA 
					local check = true
					if(avoidQMinionHandle == minion.handle and myHero.levelData.lvl >= 3) then
						if _G.SDK.HealthPrediction:GetLastHitTarget().handle == minion.handle then
							check = false
						end
					end
					if(myHero.pos:DistanceTo(minion.pos) <= Q.Range and check) then
						if(self.Menu.LastHit.TowerFarmAssist:Value()) then
							local isMinionUnderTurret, turretUnitMinion = IsUnderFriendlyTurret(minion)
							local isHeroUnderTurret, turretUnitHero = IsUnderFriendlyTurret(myHero)
							if (isMinionUnderTurret == false and isHeroUnderTurret == false) then
								self:StandardLastHit(minion)
							else
								--Check to see if the minion is under a friendly tower, or at least nearby it enough to justify using turret assist last hit
								local turretUnit = turretUnitMinion or turretUnitHero
								if(minion.pos:DistanceTo(turretUnit.pos) <= ((turretUnit.boundingRadius + 750 + minion.boundingRadius / 2) + 200)) then
									self:TowerLastHit(minion, turretUnit)
								end
							end
						else
							self:StandardLastHit(minion)
						end
					end
				end
			end
		end
	end
	
end

function Veigar:StandardLastHit(minion)
	local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, minion.networkID)
	if(collisionCount <= Q.MaxCollision) then
		local QDam = self:GetRawAbilityDamage("Q")
		local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay + (myHero.pos:DistanceTo(minion.pos)/Q.Speed))
		if ((hp > 0) and (minion.health + 10 - QDam <= 0)) then
			Control.CastSpell(HK_Q, minion)
			gameTick = GameTimer() + 0.2
			return
		end
	end
end

function Veigar:TowerLastHit(minion, turret)
	local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, minion.networkID)
	local turrDmg = GetTurretDamage()
	local predHP = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay)
	local QDam = self:GetRawAbilityDamage("Q")
	if(turret.targetID == minion.networkID) then
		if(collisionCount <= Q.MaxCollision) then
			if(predHP > 0 and minion.health - QDam <= 0) then
				Control.CastSpell(HK_Q, minion)
			end
		end
	else -- Prime minions
		if(predHP - turrDmg > 0 and predHP - turrDmg < myHero.totalDamage*2) then
			_G.SDK.Orbwalker:Attack(minion)
		end
		
		if(turret.targetID == 0 or turret.targetID == nil) then
			if(predHP > 0 and minion.health - QDam <= 0) then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
end

function Veigar:Clear()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
	
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
	local canonMinion = GetCanonMinion(minions)
	
	if(myHero.activeSpell.name:find("VeigarBasicAttack")) then
		avoidQMinionHandle = myHero.activeSpell.target
	end
			
	--Q
	if(self.Menu.Clear.UseQ:Value()) then
		if(Ready(_Q)) then
			--Prioritize the canon minion if its low
			if(canonMinion ~= nil) and IsValid(canonMinion) then
				local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, canonMinion.pos, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, canonMinion.networkID)
				if(collisionCount <= Q.MaxCollision) then
					local QDam = self:GetRawAbilityDamage("Q")
					local hp = _G.SDK.HealthPrediction:GetPrediction(canonMinion, Q.Delay + (myHero.pos:DistanceTo(canonMinion.pos)/Q.Speed))
					
					--This is to prevent us Q'ing a target we are going to kill with an AA 
					local check = true
					if(avoidQMinionHandle == canonMinion.handle) then
						if canonMinion.health - myHero.totalDamage <= 0 then
							check = false
						end
					end
					
					if ((hp > 0) and (canonMinion.health + (canonMinion.health*0.08) - QDam <= 0) and check) then
						Control.CastSpell(HK_Q, canonMinion)
						gameTick = GameTimer() + 0.2
						return
					end
				end
			end
					
			for i = 1, #minions do
				local minion = minions[i]
				if(minion and IsValid(minion)) then
					
					--This is to prevent us Q'ing a target we are going to kill with an AA 
					local check = true
					if(avoidQMinionHandle == minion.handle) then
						if _G.SDK.HealthPrediction:GetLastHitTarget().handle == minion.handle then
							check = false
						end
					end
					
					if(myHero.pos:DistanceTo(minion.pos) <= Q.Range and check) then
						
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, Q.CollisionTypes, minion.networkID)
						if(collisionCount <= Q.MaxCollision) then
							local QDam = self:GetRawAbilityDamage("Q")
							local hp = _G.SDK.HealthPrediction:GetPrediction(minion, Q.Delay + (myHero.pos:DistanceTo(minion.pos)/Q.Speed))
							if ((hp > 0) and (hp + (minion.health*0.05) - QDam <= 0)) then
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
	
	--W
	if(self.Menu.Clear.UseW:Value()) then
		if(Ready(_W) and (myHero.mana / myHero.maxMana) >= (self.Menu.Clear.WMana:Value() / 100)) then
			for i = 1, #minions do		
				local minion = minions[i]
				if IsValid(minion) then
					if(myHero.pos:DistanceTo(minion.pos) < W.Range) then
						local clusterMinions = GetMinionsAroundMinion(W.Range, W.Radius, minion)
						if(#clusterMinions >= 2) then
							local clusterMinionsAvgPos = AverageClusterPosition(clusterMinions)
							Control.CastSpell(HK_W, clusterMinionsAvgPos)
							gameTick = GameTimer() + 0.2
							return
						end
					end
				end
			end
		end
	end
	
end

function Veigar:KillSteal()
	if(gameTick > GameTimer()) then return end
	
	--R
	if(self.Menu.KillSteal.UseR:Value()) then
		if(Ready(_R)) then
			for _, enemy in pairs(Enemies) do
				if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
					if(enemy.pos:DistanceTo(myHero.pos) <= R.Range) then
						if(self:IsKillable(enemy) and (self:CantKill(enemy, true, true, false)==false)) then
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

function Veigar:AutoWImmobile()
	if(Ready(_W)) then
		local target = GetTarget(W.Range + W.Radius)
		if(target ~= nil and IsValid(target)) then
			local WPrediction, isExtended = GetExtendedSpellPrediction(target, W)
			if WPrediction:CanHit(HITCHANCE_IMMOBILE) then
				if(isExtended) then
					local castPos = myHero.pos:Extended(WPrediction.CastPosition, W.Range)
					Control.CastSpell(HK_W, castPos)
					return
				else
					Control.CastSpell(HK_W, WPrediction.CastPosition)
					return
				end
			end
			
			if(IsImmobile(target) >= 1.0) then
				local WPrediction, isExtended = GetExtendedSpellPrediction(target, W)
				if WPrediction:CanHit(HITCHANCE_HIGH) then
					if(isExtended) then
						local castPos = myHero.pos:Extended(WPrediction.CastPosition, W.Range)
						Control.CastSpell(HK_W, castPos)
						return
					else
						Control.CastSpell(HK_W, WPrediction.CastPosition)
						return
					end
				end
			end
		end
	end
end

function Veigar:SemiManualE()
	_G.SDK.Orbwalker:SetAttack(false)
	_G.SDK.Orbwalker:Orbwalk()
	
	if(gameTick > GameTimer()) then return end	

	if(Ready(_E)) then
		local target = GetTarget(E.Range + E.Radius)
		if(target and IsValid(target)) then
			local isStrafing, avgPos = StrafePred:IsStrafing(target)
			local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
			if(isStrafing) then
				if(avgPos:DistanceTo(myHero.pos) < E.Range) then
					Control.CastSpell(HK_E, avgPos)
					gameTick = GameTimer() + 0.2
					return
				end
			end
			if(isStutterDancing) then
				if(avgPos2:DistanceTo(myHero.pos) < E.Range) then
					Control.CastSpell(HK_E, avgPos2)
					gameTick = GameTimer() + 0.2
					return
				end
			end
			
			local EPrediction, isExtended = GetExtendedSpellPrediction(target, E)
			if EPrediction:CanHit(HITCHANCE_HIGH) then
				if(isExtended == false) then
					Control.CastSpell(HK_E, EPrediction.CastPosition)
					gameTick = GameTimer() + 0.333
					return
				else
					if(target.pathing.hasMovePath) then
						local checkRunDir = GetUnitRunDirection(myHero, target)
						if(checkRunDir == RUNNING_AWAY) then
							--"Running away"
							return
						else
							--"Running Towards"
							if(target.distance <= (E.Range + E.Radius -50)) then
								local castPos = myHero.pos:Extended(EPrediction.CastPosition, E.Range -10)
								Control.CastSpell(HK_E, castPos)
								gameTick = GameTimer() + 0.333
								return
							end
						end
					else
						if(target.distance <= (E.Range + E.Radius -50)) then
							local castPos = myHero.pos:Extended(EPrediction.CastPosition, E.Range -10)
							Control.CastSpell(HK_E, castPos)
							gameTick = GameTimer() + 0.333
							return
						end
					end
				end
			end
		end
	end

end

function Veigar:EInterrupter()
	if(Ready(_E)) then
		local enemies = GetEnemyHeroes(E.Range + E.Radius)
		if(#enemies > 0) then
			for _, enemy in pairs (enemies) do
				if(enemy.valid and IsValid(enemy)) then

					--Interrupt them if they are channeling an interruptible spell
					local spell = enemy.activeSpell
					if(spell and spell.valid and self.InterruptableSpells[spell.name]) then
						local EPrediction, isExtended = GetExtendedSpellPrediction(enemy, EEdge)
						if EPrediction:CanHit(HITCHANCE_NORMAL) then
							if(isExtended) then
								local castVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
								local offsetVec = castVec:Extended(myHero.pos, E.Radius-65)
								Control.CastSpell(HK_E, offsetVec)
								return
							else
								local castVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
								local offsetVec = castVec:Extended(myHero.pos, E.Radius-65)
								Control.CastSpell(HK_E, offsetVec)
								return
							end
						end
					end
					
				end
			end
		end
	end
end

function Veigar:EInterrupterCC()
	if(Ready(_E)) then
		local enemy = GetTarget(E.Range + E.Radius -10)
		if(enemy and IsValid(enemy) and enemy.toScreen.onScreen) then
			--Interrupt them if they are channeling an interruptible spell
			if(IsImmobile(enemy) >= E.Delay) then
				local EPrediction, isExtended = GetExtendedSpellPrediction(enemy, EEdge)
				if EPrediction:CanHit(HITCHANCE_NORMAL) then
					if(isExtended) then
						local castVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
						local offsetVec = castVec:Extended(myHero.pos, E.Radius-65)
						Control.CastSpell(HK_E, offsetVec)
						return
					else
						local castVec = Vector(EPrediction.CastPosition.x, myHero.pos.y, EPrediction.CastPosition.z)
						local offsetVec = castVec:Extended(myHero.pos, E.Radius-65)
						Control.CastSpell(HK_E, offsetVec)
						return
					end
				end
			end
		end
	end
end

function Veigar:SmartAABlock()
	local mode = GetMode()
	
	if(mode == "LaneClear") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Flee") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Harass") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "LastHit") then
	_G.SDK.Orbwalker:SetAttack(true)
	elseif (mode == "Combo") then
		if (myHero.mana / myHero.maxMana) >= 0.08 and self.Menu.Combo.SmartAABlock:Value() and (Ready(_Q)) then
			_G.SDK.Orbwalker:SetAttack(false)
		else
			_G.SDK.Orbwalker:SetAttack(true)
		end
	end
end

function Veigar:CantKill(unit, kill, ss, aa)
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

function Veigar:HasElectrocute(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count>0 and buff.name:lower():find("electrocute.lua") then
			return true
        end
    end
    return false
end

function Veigar:IsUnitInsideE(unit)
	for _, e in pairs(self.EData) do
		if(unit.pos:DistanceTo(e.pos) <= E.Radius) then
			return true, e
		end
	end
	return false
end

function Veigar:GetRawAbilityDamage(spell)
	if(spell == "Q") then
		 return ({80, 120, 160, 200, 240})[myHero:GetSpellData(_Q).level] + (0.6 * myHero.ap)
	end
	
	if(spell == "W") then
		return ({100, 150, 200, 250, 300})[myHero:GetSpellData(_Q).level] + myHero.ap
	end
	
	return 0
end

function Veigar:GetRDamage(unit)
	local baseAmnt = ({175, 250, 325})[myHero:GetSpellData(_R).level] + (0.75 * myHero.ap)
	local ratioMult = (math.min(1 -(unit.health / unit.maxHealth), 0.667) / 0.667)
	return CalcMagicalDamage(myHero, unit, baseAmnt + (baseAmnt * ratioMult))
end

local dataTick = GameTimer()
function Veigar:UpdateComboDamage()
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

function Veigar:IsKillable(unit)
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

function Veigar:GetTotalDamage(unit)
	local totalDmg = 0
	
	if(Ready(_R)) then
		totalDmg = totalDmg + self:GetRDamage(unit)
		totalDmg = totalDmg - 15 --Slight buffer
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
	
	return totalDmg
end

function Veigar:GetTotalComboDamage(unit)
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
	
	--6655 = Ludens
	local ludensCheck, ludensIsUp = CheckDmgItems(6655)
	if(ludensCheck and ludensIsUp) then
		local ludensDmg = 100 + (myHero.ap * 0.1)
		local ludensCalcDmg = CalcMagicalDamage(myHero, unit, ludensDmg)
		
		totalDmg = totalDmg + ludensCalcDmg
	end
	
	if(Ready(_R)) then
		local baseAmnt = ({175, 250, 325})[myHero:GetSpellData(_R).level] + (0.75 * myHero.ap)
		local ratioMult = (math.min(1 -((unit.health - totalDmg) / unit.maxHealth), 0.667) / 0.667)
		local RDmg = CalcMagicalDamage(myHero, unit, baseAmnt + (baseAmnt * ratioMult))
		totalDmg = totalDmg + RDmg
	end
	
	return totalDmg
end

local alphaLerp = 0
function Veigar:Draw()
	if myHero.dead then return end
	
	if(self.Menu.Drawings.DrawQW:Value()) then
		DrawCircle(myHero, Q.Range, 1, DrawColor(50, 80, 215, 255)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Drawings.DrawE:Value()) then
		DrawCircle(myHero, E.Range, 1, DrawColor(50, 170, 55, 225)) --(Alpha, R, G, B)
	end
	
	if(self.Menu.Drawings.DrawKillableTargets:Value()) then
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
	
	if(self.Menu.Drawings.Debug.DrawParticles:Value()) then
		local particleCount = Game.ParticleCount()
		for i = particleCount, 1, -1 do
			local obj = Game.Particle(i)
			if obj and obj.type == "obj_GeneralParticleEmitter" and obj.name:find("Veigar") then
				DrawText(obj.name, 18, obj.pos:To2D())
			end
		end
	end
end

function Veigar:DrawKillable()
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

function Veigar:DrawDamageHPBars()

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

function Veigar:DrawKillReticle(unit)
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

Veigar()
LoadUnits()