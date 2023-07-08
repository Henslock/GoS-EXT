require "2DGeometry"
require "MapPositionGOS"

local scriptVersion = 1.16
----------------------------------------------------
--|                    AUTO UPDATE                       |--
----------------------------------------------------

do
    
	local Version = scriptVersion
	local gitHub = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/"
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "KillerAwareness.lua",
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "KillerAwareness.version",
        }
    }
    
    local function AutoUpdate()
        local function DownloadFile(path, fileName)
            DownloadFileAsync(gitHub .. fileName, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Path, Files.Version.Name)
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Path, Files.Lua.Name)
            print("*WARNING* New KillerAwareness Downloaded - Please RELOAD with [ F6 ]")
		else
			print("| KILLER | Awareness [ver. "..tostring(scriptVersion).."] loaded!")
        end
    end
   AutoUpdate()
end


----------------------------------------------------
--|                   		UTILITY					             |--
----------------------------------------------------
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team
local TEAM_JUNGLE = 300
local GameTimer = Game.Timer
local Allies, Enemies, Units, EnemyTurrets, FriendlyTurrets = {}, {}, {}, {}, {}
local MathHuge = math.huge
local TableInsert = table.insert
local TableRemove = table.remove
local DrawRect = Draw.Rect
local DrawLine = Draw.Line
local DrawCircle = Draw.Circle
local DrawCircleMinimap = Draw.CircleMinimap
local DrawColor = Draw.Color
local DrawText = Draw.Text
local ControlSetCursorPos = Control.SetCursorPos
local ControlKeyUp = Control.KeyUp
local ControlKeyDown = Control.KeyDown
local GameCanUseSpell = Game.CanUseSpell
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameTurretCount = Game.TurretCount
local GameTurret = Game.Turret
local GameIsChatOpen = Game.IsChatOpen
local GameResolution = Game.Resolution()
-- UTILITY FUNCTIONS --

local function LoadUnits()
	for i = 1, GameHeroCount() do
		local unit = GameHero(i); Units[i] = {unit = unit, spell = nil}
		if unit.team ~= myHero.team then TableInsert(Enemies, unit)
		elseif unit.team == myHero.team and unit ~= myHero then TableInsert(Allies, unit) end
	end
	
	for i = 1, Game.TurretCount() do
		local turret = Game.Turret(i)
		if turret and turret.isEnemy then TableInsert(EnemyTurrets, turret) end
		if turret and not turret.isEnemy then TableInsert(FriendlyTurrets, turret) end
	end
	
end

local function IsTurret(unit)
	if (not unit or unit.valid == false) then return false end
	if (unit.type == "AITurretClient") then return true end
	for i = 1, #EnemyTurrets do
		if(unit.networkID == Game.Turret(i).networkID) then return true end
	end

	for i = 1, #FriendlyTurrets do
		if(unit.networkID == Game.Turret(i).networkID) then return true end
	end
	return false
end

function GetEnemyHeroes()
	return Enemies
end

local function GetEnemyHeroes(range, bbox)
	local result = {}
	for _, unit in ipairs(Enemies) do
		local extrarange = bbox and unit.boundingRadius or 0
		if unit.distance < range + extrarange then
			table.insert(result, unit)
		end
	end
	return result
end

local function GetEnemyCount(range, pos)
    local pos = pos.pos
	local count = 0
	for i = 1, GameHeroCount() do 
	local hero = GameHero(i)
	local Range = range * range
		if hero.team ~= TEAM_ALLY and GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
		count = count + 1
		end
	end
	return count
end

function math.clamp(val, minval, maxval)
	if val < minval then
		return minval
	end
	if val >= minval and val <= maxval then
		return val
	end
	if val > maxval then
		return maxval
	end
end

local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

local function GetLineIntersection(pointA, pointB, pointC, pointD)
	local p1 = pointA
	local p2 = pointB
	local p3 = pointC
	local p4 = pointD

	local denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y)

	if (denominator ~= 0) then
		local u_a = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denominator
		local u_b = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / denominator

		if (u_a >= 0 and u_a <= 1 and u_b >= 0 and u_b <= 1) then
				local a1 = p2.y - p1.y;
				local b1 = p1.x - p2.x;
				local c1 = a1 * (p1.x) + b1 * (p1.y);

				local a2 = p4.y - p3.y;
				local b2 = p3.x - p4.x;
				local c2 = a2 * (p3.x) + b2 * (p3.y);
				
				local x = (b2 * c1 - b1 * c2) / denominator;
				local y = (a1 * c2 - a2 * c1) / denominator;
				return {x, y}
		end
	end

	return nil
end

local function GetChampScreenBoundsPos(unit)
	local halfVec = {x = GameResolution.x /2, y = GameResolution.y /2}
	local champPos = unit.pos:To2D()
	
	local line1 = GetLineIntersection(TOP_LEFT, TOP_RIGHT, myHero.pos:To2D(), champPos)
	local line2 = GetLineIntersection(TOP_RIGHT, BOTTOM_RIGHT, myHero.pos:To2D(), champPos)
	local line3 = GetLineIntersection(BOTTOM_RIGHT, BOTTOM_LEFT, myHero.pos:To2D(), champPos)
	local line4 = GetLineIntersection(BOTTOM_LEFT, TOP_LEFT, myHero.pos:To2D(), champPos)
	
	local points = {line1, line2, line3, line4}
	for _, point in pairs(points) do
		if point ~= nil then
			return point
		end
	end
	
	return nil
end

local function CheckPointInUI(point)
	--Check Minimap first
	if(point.x >= GameResolution.x * 0.8 and point.y >= GameResolution.y * 0.7) then
		return true
	end
	--Check hero UI
	if(point.x >= GameResolution.x * 0.25 and point.x <= GameResolution.x * 0.7) and point.y >= GameResolution.y * 0.85 then
		return true
	end
	return false
end

local function FileExists(path)
	local file = io.open(path, "r")
	if file ~= nil then 
		io.close(file) 
		return true 
	else 
		return false 
	end
end

-----------------------------------------------------

class "KillerAwareness"

local gameTick = GameTimer()
local scriptIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/killerawarenessicon.png"
local gitHub = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/"

TOP_LEFT, BOTTOM_LEFT, TOP_RIGHT, BOTTOM_RIGHT = {x = 0, y = 0}, {x = 0, y = GameResolution.y}, {x = GameResolution.x, y = 0}, {x = GameResolution.x , y = GameResolution.y}

local fallBackSprite = Sprite("KillerAwareness\\fallback.png")
local ChampionSprites = {}
local ChampionHaloData = {}
local TrackerData = {}

local MIATimer = 5
local haloCD = 10

KillerAwareness.Window = { x = Game.Resolution().x * 0.5 + 200, y = Game.Resolution().y * 0.5 }
KillerAwareness.AllowMove = nil
KillerAwareness.ChampionTrackerLoaded = false
KillerAwareness.Menu = {}

function KillerAwareness:__init()
	self:LoadMenu()
	self:CreateSprites()
	self:LoadHealthTrackerData()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function KillerAwareness:LoadHealthTrackerData()
	DelayAction(function()
	for k, v in pairs (Enemies) do
		TrackerData[v.name] = {champ = v.charName, timelastspotted = 0, mia = false}
	end
	end,  4)
end

function KillerAwareness:LoadMenu()

	self.Menu = MenuElement({type = MENU, id = "KillerAwareness", name = "Killer Awareness", leftIcon = scriptIcon})
	self.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})
	self.Menu.Loaded = true
	--Champion Tracker
	self.Menu:MenuElement({id = "ChampLineScan", name = "Champion Line Scan", type = MENU})
	self.Menu.ChampLineScan:MenuElement({id = "Enabled", name = "Enable", value = true})
	self.Menu.ChampLineScan:MenuElement({id = "LineThickness", name = "Line Thickness", value = 1, min = 1, max = 5, step = 1})
	
	--Awareness HUD
	self.Menu:MenuElement({id = "AwarenessHUD", name = "Awareness HUD", type = MENU})
	self.Menu.AwarenessHUD:MenuElement({id = "Enabled", name = "Enable", value = true})
	self.Menu.AwarenessHUD:MenuElement({id = "FadeOverUI", name = "Fade Icons over UI", value = true})
	self.Menu.AwarenessHUD:MenuElement({id = "WarningFlash", name = "Warning Flash", value = true})
	self.Menu.AwarenessHUD:MenuElement({id = "HudBuffer", name = "HUD Buffer", value = 75, min = 0, max = 200, step = 5})
	self.Menu.AwarenessHUD:MenuElement({id = "HudScale", name = "HUD Scale", value = 1, min = 0.5, max = 1.5, step = 0.1})
	
	--Turret Awareness
	self.Menu:MenuElement({id = "TurretAwareness", name = "Turret Awareness", type = MENU})
	self.Menu.TurretAwareness:MenuElement({id = "DrawAllies", name = "Draw Ally Turret Range", value = false})
	self.Menu.TurretAwareness:MenuElement({id = "DrawEnemies", name = "Draw Enemy Turret Range", value = true})
	self.Menu.TurretAwareness:MenuElement({id = "DrawHP", name = "Draw Turret HP on Minimap", value = true})
	self.Menu.TurretAwareness:MenuElement({id = "DrawRange", name = "Turret Draw Range", value = 500, min = 200, max = 1500, step = 100})

	--Ward Auto Ping
	--[[
	self.Menu:MenuElement({id = "WardPing", name = "Ward Auto-Ping", type = MENU})
	self.Menu.WardPing:MenuElement({name = "MANDATORY:", type = SPACE})
	self.Menu.WardPing:MenuElement({name = "Options > Hotkeys > Communication", type = SPACE})
	self.Menu.WardPing:MenuElement({name = "Match Quick Alert Ping with THIS Key!", type = SPACE})
	self.Menu.WardPing:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.WardPing:MenuElement({id = "Key", name = "Quick Alert Ping Key", key = string.byte("H")})
	--]]

	--Champion Tracker
	self.Menu:MenuElement({id = "ChampTracker", name = "Champion Tracker", type = MENU})

	
	--Health Tracker
	self.Menu:MenuElement({id = "DrawHealthTracker", name = "Draw Health Tracker", value = false})

	KillerAwareness.Menu = self.Menu
end

function KillerAwareness:Tick()
end

function KillerAwareness:CreateSprites()
	for _, enemy in pairs(Enemies) do
		if(FileExists(SPRITE_PATH .. "KillerAwareness/" .. enemy.charName:lower() .. ".png")) then
			ChampionSprites[enemy.charName] = Sprite("KillerAwareness\\" .. enemy.charName:lower() .. ".png")
		end
		
		ChampionHaloData[enemy.charName] = {haloCDTimer = os.clock(), haloFading = false, canTrigger = true, sprite = Sprite("KillerAwareness\\halo.png")}
	end
end

function KillerAwareness:FetchSprite(unit)
	if(ChampionSprites[unit.charName] ~= nil) then
		return ChampionSprites[unit.charName]
	else
		return fallBackSprite
	end
end

function KillerAwareness:IsInStatusBox(pt)
	return pt.x >= self.Window.x
		and pt.x <= self.Window.x + 186
		and pt.y >= self.Window.y
		and pt.y <= self.Window.y + 68
end

function KillerAwareness:OnWndMsg(msg, wParam)
	self.AllowMove = msg == 513
			and wParam == 0
			and self:IsInStatusBox(cursorPos)
			and { x = self.Window.x - cursorPos.x, y = self.Window.y - cursorPos.y }
		or nil
end

function KillerAwareness:Draw()

	if(self.Menu.AwarenessHUD.Enabled:Value()) then
		local buffer = self.Menu.AwarenessHUD.HudBuffer:Value()
		local scale = self.Menu.AwarenessHUD.HudScale:Value()
		for k, v in pairs(Enemies) do
			if(v and IsValid(v)) then

				if(v.toScreen.onScreen == false and myHero.toScreen.onScreen == true and myHero.pos:DistanceTo(v.pos) < 3500) then
					local posX = math.clamp(v.pos:To2D().x, 0 + buffer, GameResolution.x - buffer)
					local posY = math.clamp(v.pos:To2D().y, 0 + buffer, GameResolution.y - buffer)
					local sprite = self:FetchSprite(v)
					if(sprite ~= nil) then
						local screenVec = {x = posX, y = posY}
						
						sprite:SetColor(DrawColor(255, 255, 255, 255))
						
						if(self.Menu.AwarenessHUD.FadeOverUI:Value()) then
							if(CheckPointInUI(screenVec) == true) then
								sprite:SetColor(DrawColor(155, 255, 255, 255))
							end
						end

						sprite:SetScale(scale)
						sprite:Draw(posX -60 + (60*(1 - scale)), posY -60 + (60*(1 - scale)))
						
						if(os.clock() < ChampionHaloData[v.charName].haloCDTimer) then
							ChampionHaloData[v.charName].canTrigger = false
						end
						
						if(self.Menu.AwarenessHUD.WarningFlash:Value()) then
							self:DrawHalo(v, posX -100 + (100*(1 - scale)), posY -100 + (100*(1 - scale)), scale)
						end
					end
				else
					ChampionHaloData[v.charName].canTrigger = true
				end
			end
		end
	end

	if(self.Menu.ChampLineScan.Enabled:Value()) then
		-- Draw lines connecting to enemy champions
		for k, v in pairs(Enemies) do
			local distMax = 3000
			local distMin = 1000
			if(v and IsValid(v) and myHero.pos.DistanceTo(v.pos) <= distMax and myHero.pos.DistanceTo(v.pos) > distMin) then
				local lineThickness = self.Menu.ChampLineScan.LineThickness:Value()
				local lineAlphaVal = ((myHero.pos.DistanceTo(v.pos) - distMin) / (distMax - distMin)) * 0.9
				DrawLine(myHero.pos:To2D(), v.pos:To2D(), lineThickness, DrawColor(300 * lineAlphaVal, 255, 0, 0))
			end
		end
	end
	
	self:DrawTurretAwareness()
	
	if(self.Menu.DrawHealthTracker:Value()) then
		self:UpdateHealthData()
		self:DrawHealthTracker()
	end

end

function KillerAwareness:DrawHalo(enemy, x, y, scale)
	local e = enemy.charName
	local haloData = ChampionHaloData[e]
	if(os.clock() > haloData.haloCDTimer and haloData.canTrigger) then
		haloData.haloCDTimer = os.clock() + haloCD
		haloData.haloFading = true
		haloData.canTrigger = false
	end
	
	if(haloData.haloFading) then
		local halo = haloData.sprite
		local duration = haloData.haloCDTimer - haloCD + 1
		local ratio = math.max(duration - os.clock(), 0) / 1
		if(ratio <= 0) then return end

		halo:SetColor(DrawColor(255 * math.min(ratio, 1), 255, 255, 0))
		halo:SetScale(scale)
		halo:Draw(x, y)
	end
end

function KillerAwareness:DrawTurretAwareness()
	local drawRange = self.Menu.TurretAwareness.DrawRange:Value()
	
	if(self.Menu.TurretAwareness.DrawAllies:Value()) then
		for _, turret in pairs(FriendlyTurrets) do
			if(turret.valid and myHero.alive) then
				if(IsTurret(turret)) then
					local turretRange = (turret.boundingRadius + 750 + myHero.boundingRadius / 2)
					local totalRange = drawRange + turretRange
					if(turret.distance <= totalRange and (turret.name ~= "Turret_OrderTurretShrine_A" and turret.name ~= "Turret_ChaosTurretShrine_A")) then
						local alphaLerp = 1 - math.max((turret.distance - (totalRange - 200)) / (totalRange - (totalRange - 200)), 0)
						DrawCircle(turret, turretRange, 2, DrawColor(255 *alphaLerp, 50, 90, 255))
					end
				end
			end
		end
	end
	
	if(self.Menu.TurretAwareness.DrawHP:Value()) then
		for _, turret in pairs(EnemyTurrets) do
			if(turret.valid and turret.isTargetableToTeam ) then
				if(IsTurret(turret)) then
					local hp = tostring(math.floor((turret.health / turret.maxHealth) * 100)).."%"
					DrawRect(turret.posMM.x - 14, turret.posMM.y + 12, 34, 16, DrawColor(125, 0, 0, 0));
					DrawText(hp, 16, turret.posMM.x - 12, turret.posMM.y + 12, DrawColor(255, 255, 255, 255));
				end
			end			
		end
	end
	
	if(self.Menu.TurretAwareness.DrawEnemies:Value()) then
		for _, turret in pairs(EnemyTurrets) do
			if(turret.valid and myHero.alive) then
				if(IsTurret(turret)) then
					local turretRange = (turret.boundingRadius + 750 + myHero.boundingRadius / 2)
					local totalRange = drawRange + turretRange
					if(turret.distance <= totalRange and (turret.name ~= "Turret_OrderTurretShrine_A" and turret.name ~= "Turret_ChaosTurretShrine_A")) then
						local alphaLerp = 1 - math.max((turret.distance - (totalRange - 200)) / (totalRange - (totalRange - 200)), 0)
						DrawCircle(turret, turretRange, 2, DrawColor(255 *alphaLerp, 255, 90, 55))
					end
				end
			end			
		end
	end
end

function KillerAwareness:DrawHealthTracker()
	if not (myHero.networkID)then return end
	if (Game.Timer() <= 1) then return end
	if KillerAwareness.AllowMove then
		KillerAwareness.Window = { x = cursorPos.x + KillerAwareness.AllowMove.x, y = cursorPos.y + KillerAwareness.AllowMove.y }
	end

	local rectHeight = #Enemies * 30	
	Draw.Rect(self.Window.x, self.Window.y, 300, rectHeight, Draw.Color(224, 23, 23, 23))
	Draw.Text("Health Tracker", 18, self.Window.x + 10, self.Window.y + 5, DrawColor(255, 255, 255, 255))
	local yOffset = 0
	
	local barWidth = 180
	local barOffset = 100
	local miaCheck = false
	for k, v in pairs(Enemies) do
		local hpRatio = v.health / math.floor(v.maxHealth)
		if(TrackerData[v.name] ~= nil) then
			miaCheck = ((GetTickCount() - TrackerData[v.name].timelastspotted) / 1000 >= MIATimer)
		end
		
		--HealthBarDraws
		if(not miaCheck and v.alive) then
			Draw.Rect(self.Window.x + barOffset, self.Window.y + 39 + yOffset, barWidth, 8, DrawColor(255, 0, 0, 0))
			Draw.Rect(self.Window.x + barOffset, self.Window.y + 39 + yOffset, barWidth * hpRatio -1, 8, IsValid(v) and DrawColor(255, 0, 255, 125) or DrawColor(55, 0, 255, 125))
		else
			Draw.Rect(self.Window.x + barOffset, self.Window.y + 39 + yOffset, barWidth, 8, DrawColor(55, 255, 255, 255))
		end
		
		-- Name

		if(not miaCheck and v.alive) then
			Draw.Text(v.charName, 17, self.Window.x + 10, self.Window.y + 35 + yOffset, DrawColor(255, 55, 255, 155))
		else
			Draw.Text(v.charName, 17, self.Window.x + 10, self.Window.y + 35 + yOffset, DrawColor(125, 255, 255, 255))
		end
		
		yOffset = yOffset + 20
	end

end

local pulseCheck = 0
function KillerAwareness:UpdateHealthData()
	for k,v in pairs(Enemies) do
		if(TrackerData[v.name] == nil) then return end
		if(IsValid(v)) then
			TrackerData[v.name].timelastspotted = GetTickCount()
			TrackerData[v.name].mia = false
		end
	end
	
	if(pulseCheck > GameTimer()) then return end
	pulseCheck = GameTimer() + 0.25
	
	for _, enemy in pairs(Enemies) do
		local miaCheck = ((GetTickCount() - TrackerData[enemy.name].timelastspotted) / 1000 >= MIATimer)	
		
		if(IsValid(enemy)) then
			TrackerData[enemy.name].timelastspotted = GetTickCount()
		end
		
		if(enemy.visible == false) then
			TrackerData[enemy.name].mia = true
		end
	end
end


local AutoWardPing, ChampionTracker

--Auto Ward Pinger

AutoWardPing = {

	CachedClickedWards = {},
	WardMenu = nil,
	CachedWards = {},
	WardCountTicker = 0,
	TickUpdateTimer = 1,

	OnTick = function (self)
		if not (KillerAwareness.Menu.Loaded) then
			return
		else
			self.WardMenu = KillerAwareness.Menu.WardPing
		end

		if(self.WardMenu.Enabled:Value()) then
			self:Scan()
			if(self.IsActivePinging and self.WardTarget) then
				self:PingWard()
			end
			self:ClearGarbage()
		end
	end,

	UpdateCachedWards = function (self)
		if(self.WardCountTicker > GameTimer()) then return end
		self.CachedWards = _G.SDK.ObjectManager:GetOtherAllyMinions()
		self.WardCountTicker = GameTimer() + self.TickUpdateTimer
	end,

	Scan = function(self)
		if not (myHero.valid or IsValid(myHero)) or GameIsChatOpen() then return end
		self:UpdateCachedWards()
		local nearbyEnemies = _G.SDK.ObjectManager:GetEnemyHeroes(325) --Do not ping when enemies are around
		if(#self.CachedWards > 0 and #nearbyEnemies == 0) then
			for _, ward in ipairs(self.CachedWards) do
				if(ward.visible and ward.valid) then
					if(self:CheckExistingWard(ward) == false and self:IsNewWard(ward)) then

						self.OldMousePos = Game.mousePos()
						self.WardTarget = ward
						self.IsActivePinging = true
						self.randomOffset = {x = math.random(-75, 75), y = 0, z = math.random(-75, 75)}

						table.insert(self.CachedClickedWards, ward)
						return
					end
				end
			end
		end
	end,

	PingWard = function (self)
		if(self.WardTarget.toScreen.onScreen == false) then
			self.WardTarget = nil
			self.IsActivePinging = false
			return	
		end
		if not (myHero.valid or IsValid(myHero)) or GameIsChatOpen() then
			self.WardTarget = nil
			self.IsActivePinging = false
			return 
		end

		local finalClickPos = self.WardTarget.pos + self.randomOffset
		--_G.SDK.Cursor:Add(self.WardMenu.Key:Key(), finalClickPos)
		--Control.CastSpell(1, finalClickPos)
		--Control.CastSpell(self.WardMenu.Key:Key())
		--Control.CastSpell(1, finalClickPos)
		DelayAction( function ()
			--Control.CastSpell(2)
			self.IsActivePinging = false
		end, 0.1)
		--Control.CastSpell(1, finalClickPos)
	end,

	ClearGarbage = function(self)
		for i = #self.CachedClickedWards, 1, -1 do
			local ward = self.CachedClickedWards[i]
			if(ward == nil or ward.dead or not ward.valid) then
				table.remove(self.CachedClickedWards, i)
			end
		end
	end,

	CheckExistingWard = function (self, ward)
		for k, v in ipairs(self.CachedClickedWards) do
			if(v.networkID == ward.networkID) then
				return true
			end
		end
		return false
	end,

	IsNewWard = function(self, ward)
		if(ward.maxMana - ward.mana <= 5) then
			return true
		end
		return false
	end

}

local summonerSprites = {}
local summonerSpirteNames = {"Barrier", "Clarity", "Cleanse", "Exhaust", "Flash", "Ghost", "Heal", "Hexflash", "Ignite", "Mark", "Smite", "Teleport", "UnleashedTeleport"}

ChampionTracker = {

	TrackerMenu = nil,
	shouldDrawEnemies = true,
	shouldDrawAllies = true,
	shouldDrawMyHero = true,
	cachedSpriteScale = 1,
	fadedWhite = DrawColor(155, 255, 255, 255),
	ColorWhite = DrawColor(255, 255, 255, 255),
	ColorGrey = DrawColor(255, 120, 120, 120),
	SR_ExpGain = {0,280,660,1140,1720,2400,3180,4060,5040,6120,7300,8580,9960,11440,13020,14700,16480,18360},
	HA_ExpGain = {0,0,0,478,988,1738,2518,3398,4378,5458,6638,7918,9298,10778,12358,14038,15818,17698},
	CDFont = Draw.Font("NotoSans-Regular.ttf", "Ubuntu"),

	Init = function (self)
		self:InitSpirtes()
	end,

	InitSpirtes = function ()
		local check = true
		for i = 1, #summonerSpirteNames do
			local spriteName = summonerSpirteNames[i]
			if(FileExists(SPRITE_PATH .. "KillerAwareness/Summoners/" .. spriteName .. ".png") == false) then
				check = false
				break
			end
		end

		if(check == false) then
			print("Killer Awareness - Missing Sprites for Champion Tracker")

			DelayAction(function()
				if (KillerAwareness.Menu.Loaded) then
					KillerAwareness.Menu.ChampTracker:MenuElement({name = "[WARNING] Sprites Missing", drop = {""}})
					KillerAwareness.Menu.ChampTracker:MenuElement({name = " ", drop = {"Please download them on the forums."}})
					KillerAwareness.Menu.ChampTracker:MenuElement({name = " ", drop = {"Directory: Sprites/KillerAwareness/Summoners"}})
					KillerAwareness.ChampionTrackerLoaded = false
				end
			end,  1)
			return
		else
			--Init Sprites
			summonerSprites = {
				["SummonerBarrier"] = Sprite("KillerAwareness\\Summoners\\Barrier.png"),
				["SummonerBoost"] = Sprite("KillerAwareness\\Summoners\\Cleanse.png"),
				["SummonerMana"] = Sprite("KillerAwareness\\Summoners\\Clarity.png"),
				["SummonerDot"] = Sprite("KillerAwareness\\Summoners\\Ignite.png"),
				["SummonerExhaust"] = Sprite("KillerAwareness\\Summoners\\Exhaust.png"),
				["SummonerFlash"] = Sprite("KillerAwareness\\Summoners\\Flash.png"),
				["SummonerFlashPerksHextechFlashtraptionV2"] = Sprite("KillerAwareness\\Summoners\\Hexflash.png"),
				["SummonerHaste"] = Sprite("KillerAwareness\\Summoners\\Ghost.png"),
				["SummonerHeal"] = Sprite("KillerAwareness\\Summoners\\Heal.png"),
				["SummonerSmite"] = Sprite("KillerAwareness\\Summoners\\Smite.png"),
				["SummonerTeleport"] = Sprite("KillerAwareness\\Summoners\\Teleport.png"),
				["S12_SummonerTeleportUpgrade"] = Sprite("KillerAwareness\\Summoners\\UnleashedTeleport.png"),
				["SummonerSmiteAvatarOffensive"] = Sprite("KillerAwareness\\Summoners\\Smite.png"),
				["SummonerSmiteAvatarUtility"] = Sprite("KillerAwareness\\Summoners\\Smite.png"),
				["SummonerSmiteAvatarDefensive"] = Sprite("KillerAwareness\\Summoners\\Smite.png"),
				["S5_SummonerSmitePlayerGanker"] = Sprite("KillerAwareness\\Summoners\\Smite.png"),
				["SummonerSnowball"] = Sprite("KillerAwareness\\Summoners\\Mark.png"),
				["SummonerPoroRecall"] = Sprite("KillerAwareness\\Summoners\\Mark.png"),
				["SummonerPoroThrow"] = Sprite("KillerAwareness\\Summoners\\Mark.png")
				}

				DelayAction(function()
					if (KillerAwareness.Menu.Loaded) then
						KillerAwareness.Menu.ChampTracker:MenuElement({id = "Enabled", name = "Enabled", type = MENU})
						KillerAwareness.Menu.ChampTracker:MenuElement({id = "ClickedTarget", name = "Only Show on Clicked Target", type = MENU})
						KillerAwareness.Menu.ChampTracker:MenuElement({id = "TrackAbilities", name = "Track Abilities", value = true})
						KillerAwareness.Menu.ChampTracker:MenuElement({id = "TrackAbilityLevels", name = "Track Ability Levels", value = false})
						KillerAwareness.Menu.ChampTracker:MenuElement({id = "TrackSummoners", name = "Track Summoners", value = true})
						KillerAwareness.Menu.ChampTracker:MenuElement({id = "TrackExperience", name = "Track Experience", value = true})
						KillerAwareness.Menu.ChampTracker:MenuElement({id = "Customize", name = "Customize Elements", type = MENU})
						KillerAwareness.Menu.ChampTracker:MenuElement({id = "EnableTrackingWidget", name = "Enable Tracking Widget", value = false})
					
						--Champion Tracker Enabled
						KillerAwareness.Menu.ChampTracker.Enabled:MenuElement({id = "Enemies", name = "Enemies", value = true})
						KillerAwareness.Menu.ChampTracker.Enabled:MenuElement({id = "Allies", name = "Allies", value = false})
						KillerAwareness.Menu.ChampTracker.Enabled:MenuElement({id = "MyHero", name = "My Hero", value = false})
					
						--Hover Over Requirement
						KillerAwareness.Menu.ChampTracker.ClickedTarget:MenuElement({id = "AbilityLevels", name = "Ability Levels", value = false})
						KillerAwareness.Menu.ChampTracker.ClickedTarget:MenuElement({id = "Summoners", name = "Summoners", value = false})
						KillerAwareness.Menu.ChampTracker.ClickedTarget:MenuElement({id = "Experience", name = "Experience", value = false})
					
						--Champion Tracker Customization
						KillerAwareness.Menu.ChampTracker.Customize:MenuElement({id = "YOffset", name = "Y Offset", value = 50, min = -50, max = 150, step = 1})
						KillerAwareness.Menu.ChampTracker.Customize:MenuElement({id = "BarWidth", name = "Bar Width", value = 200, min = 120, max = 350, step = 2})
						KillerAwareness.Menu.ChampTracker.Customize:MenuElement({id = "BarHeight", name = "Bar Height", value = 14, min = 6, max = 30, step = 2})
						KillerAwareness.Menu.ChampTracker.Customize:MenuElement({id = "BarMargin", name = "Bar Margin", value = 4, min = 2, max = 12, step = 2})
						KillerAwareness.Menu.ChampTracker.Customize:MenuElement({id = "DisplayCDs", name = "Display Cooldowns", value = true})
						KillerAwareness.Menu.ChampTracker.Customize:MenuElement({id = "DisplayDecimals", name = "Display Decimals on CDs", value = false})
						KillerAwareness.Menu.ChampTracker.Customize:MenuElement({id = "DisplayBezel", name = "Display Bezel", value = true})
						KillerAwareness.Menu.ChampTracker.Customize:MenuElement({id = "XPBarPos", name = "Experience Bar Position",  value = 1, drop = {"Top", "Bottom"}})
						KillerAwareness.Menu.ChampTracker.Customize:MenuElement({id = "SummonerSize", name = "Summoner Icon Size", value = 50, min = 25, max = 100, step = 1, identifier = "%"})
		
						KillerAwareness.ChampionTrackerLoaded = true
					end
				end,  1)
		end
	end,

	OnTick = function (self)
		if not (KillerAwareness.ChampionTrackerLoaded) then return end
		if not (KillerAwareness.Menu.Loaded) then
			return
		else
			self.TrackerMenu = KillerAwareness.Menu.ChampTracker
		end

		if(self.TrackerMenu.Enabled.Enemies:Value()) then
			shouldDrawEnemies = true
		else
			shouldDrawEnemies = false
		end

		if(self.TrackerMenu.Enabled.Allies:Value()) then
			shouldDrawAllies = true
		else
			shouldDrawAllies = false
		end

		if(self.TrackerMenu.Enabled.MyHero:Value()) then
			shouldDrawMyHero = true
		else
			shouldDrawMyHero = false
		end
	end,

	UpdateSpriteScale = function (self)
		local spriteScale = self.TrackerMenu.Customize.SummonerSize:Value() / 100
		if(spriteScale ~= self.cachedSpriteScale) then
			self.cachedSpriteScale = spriteScale
			for _, sprite in pairs(summonerSprites) do
				sprite:SetScale(spriteScale)
			end
		end
	end,

	Draw = function (self)
		if not (KillerAwareness.ChampionTrackerLoaded) then return end

		if(shouldDrawEnemies) then
			for _, enemy in ipairs(Enemies) do
				if(IsValid(enemy) and enemy.charName ~= "PracticeTool_TargetDummy") then
					self:DrawChampionTracker(enemy)
				end
			end
		end

		if(shouldDrawAllies) then
			for _, ally in ipairs(Allies) do
				if(IsValid(ally)) then
					self:DrawChampionTracker(ally)
				end
			end
		end

		if(shouldDrawMyHero) then
			if(IsValid(myHero)) then
				self:DrawChampionTracker(myHero)
			end
		end
	end,

	DrawChampionTracker = function (self, unit)
		local barWidth = self.TrackerMenu.Customize.BarWidth:Value()
		local yOffset = self.TrackerMenu.Customize.YOffset:Value()
		local barHeight = self.TrackerMenu.Customize.BarHeight:Value()
		local barMargin = self.TrackerMenu.Customize.BarMargin:Value()
		local displayCDs = self.TrackerMenu.Customize.DisplayCDs:Value()
		local displayDecimals = self.TrackerMenu.Customize.DisplayDecimals:Value()
		local displayBezel = self.TrackerMenu.Customize.DisplayBezel:Value()
		local spriteSize = 64
		local spriteScale = self.cachedSpriteScale
		local fontSize = barHeight + 2
		local spellBarWidth = (barWidth - (barMargin*5)) / 4
		local heroPos = unit.pos2D

		if(heroPos.onScreen) then


			--Clicked Target DATA
			local shouldReveal, hoverExp, hoverSkillLevel, hoverSummoners = false, true, true, true
			local clickedTar = _G.SDK.TargetSelector.Selected
			if(clickedTar and IsValid(clickedTar)) then
				if(clickedTar.networkID == unit.networkID) then
					shouldReveal = true
				end
			end

			if(self.TrackerMenu.ClickedTarget.Experience:Value()) then
				if(shouldReveal) then
					hoverExp = true
				else
					hoverExp = false
				end
			end

			if(self.TrackerMenu.ClickedTarget.AbilityLevels:Value()) then
				if(shouldReveal) then
					hoverSkillLevel = true
				else
					hoverSkillLevel = false
				end
			end

			if(self.TrackerMenu.ClickedTarget.Summoners:Value()) then
				if(shouldReveal) then
					hoverSummoners = true
				else
					hoverSummoners = false
				end
			end

			--Experience Draws
			if(self.TrackerMenu.TrackExperience:Value() and (Game.mapID == SUMMONERS_RIFT or Game.mapID == HOWLING_ABYSS) and hoverExp) then
				local lvlData = unit.levelData;
				local xpBarPos = self.TrackerMenu.Customize.XPBarPos:Value()
				local barAnchorOffset = 0
				local widthAdjust = 0

				if(xpBarPos == 1) then
					barAnchorOffset = -10
				else
					barAnchorOffset = barHeight + (barMargin*2) + 4
				end

				if(displayBezel == false) then
					widthAdjust = barMargin
				end

				if (lvlData.lvl > 0) and (lvlData.lvl < 18) then
					DrawRect(heroPos.x - (barWidth/2) + widthAdjust, heroPos.y + yOffset + barAnchorOffset, barWidth - widthAdjust*2, 6, DrawColor(185, 0, 0, 0))

					if(Game.mapID == SUMMONERS_RIFT) then
						local totalExp = self.SR_ExpGain[lvlData.lvl+1] - self.SR_ExpGain[lvlData.lvl];
						local currExp = lvlData.exp - self.SR_ExpGain[lvlData.lvl];
						DrawRect(heroPos.x - (barWidth/2) + widthAdjust, heroPos.y + yOffset + barAnchorOffset, (currExp / totalExp) * (barWidth - widthAdjust*2), 4, DrawColor(255, 177, 68, 207))
					else
						local totalExp = self.HA_ExpGain[lvlData.lvl+1] - self.HA_ExpGain[lvlData.lvl];
						local currExp = lvlData.exp - self.HA_ExpGain[lvlData.lvl] - 661.5;
						DrawRect(heroPos.x - (barWidth/2) + widthAdjust, heroPos.y + yOffset + barAnchorOffset, (currExp / totalExp) * (barWidth - widthAdjust*2), 4, DrawColor(255, 177, 68, 207))
					end
				end
			end

			--Skill Draws
			if(self.TrackerMenu.TrackAbilities:Value()) then
				local formatToken = "%.0f"
				if(displayDecimals) then formatToken = "%.1f" end

				if(displayBezel) then
					DrawRect(heroPos.x - (barWidth/2), heroPos.y + yOffset, barWidth , barHeight + (barMargin*2), DrawColor(185, 0, 0, 0))
				end

				-- Q DATA
				local QData = unit:GetSpellData(_Q)
				if QData.level > 0 then
					local isOnCd, currCD, cdRatio, specialCase = self:GetSpellCooldownData(QData, unit)
					if(specialCase) then
						DrawRect(heroPos.x - (barWidth/2) + barMargin * 1 -1, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 0, 0, 0))
						DrawRect(heroPos.x - (barWidth/2) + barMargin * 1, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 201, 56, 197))
					else
						if isOnCd then
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 1 -1, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 125, 125, 125))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 1, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 0, 0, 0))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 1, heroPos.y + yOffset + barMargin, ((1 - (cdRatio)) * spellBarWidth), barHeight, DrawColor(255, 80, 80, 80))
							if(displayCDs) then
								DrawText(string.format(formatToken, currCD), fontSize, heroPos.x - (barWidth/2) + 3 + barMargin * 1, heroPos.y + yOffset + barMargin -2, DrawColor(255, 255, 255, 255), self.CDFont)
							end
						else
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 1 -1, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 0, 0, 0))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 1, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 40, 185, 70))
						end
					end
				else
					DrawRect(heroPos.x - (barWidth/2) + barMargin * 1 -1, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 80, 80, 80))
					DrawRect(heroPos.x - (barWidth/2) + barMargin * 1, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 0, 0, 0))
				end

				-- W DATA
				local WData = unit:GetSpellData(_W)
				if WData.level > 0 then
					local isOnCd, currCD, cdRatio, specialCase = self:GetSpellCooldownData(WData, unit)
					if(specialCase) then
						DrawRect(heroPos.x - (barWidth/2) + barMargin * 2 -1 + spellBarWidth, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 0, 0, 0))
						DrawRect(heroPos.x - (barWidth/2) + barMargin * 2 + spellBarWidth, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 201, 56, 197))
					else
						if isOnCd then
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 2 -1 + spellBarWidth, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 125, 125, 125))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 2 + spellBarWidth, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 0, 0, 0))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 2 + spellBarWidth, heroPos.y + yOffset + barMargin, ((1 - (cdRatio)) * spellBarWidth), barHeight, DrawColor(255, 80, 80, 80))
							if(displayCDs) then
								DrawText(string.format(formatToken, currCD), fontSize, heroPos.x - (barWidth/2) + 3 + barMargin*2 + spellBarWidth, heroPos.y + yOffset + barMargin -2, DrawColor(255, 255, 255, 255), self.CDFont)
							end
						else
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 2 -1 + spellBarWidth, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 0, 0, 0))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 2 + spellBarWidth, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 40, 185, 70))
						end
					end
				else
					DrawRect(heroPos.x - (barWidth/2) + barMargin * 2 -1 + spellBarWidth, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 80, 80, 80))
					DrawRect(heroPos.x - (barWidth/2) + barMargin * 2 + spellBarWidth, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 0, 0, 0))
				end

				--E DATA
				local EData = unit:GetSpellData(_E)
				if EData.level > 0 then
					local isOnCd, currCD, cdRatio, specialCase = self:GetSpellCooldownData(EData, unit)
					if(specialCase) then
						DrawRect(heroPos.x - (barWidth/2) + barMargin * 3 -1 + spellBarWidth*2, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 0, 0, 0))
						DrawRect(heroPos.x - (barWidth/2) + barMargin * 3 + spellBarWidth*2, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 201, 56, 197))
					else
						if isOnCd then
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 3 -1 + spellBarWidth*2, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 125, 125, 125))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 3 + spellBarWidth*2, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 0, 0, 0))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 3 + spellBarWidth*2, heroPos.y + yOffset + barMargin, ((1 - (cdRatio)) * spellBarWidth), barHeight, DrawColor(255, 80, 80, 80))
							if(displayCDs) then
								DrawText(string.format(formatToken, currCD), fontSize, heroPos.x - (barWidth/2) + 3 + barMargin*3 + spellBarWidth*2, heroPos.y + yOffset + barMargin -2, DrawColor(255, 255, 255, 255), self.CDFont)
							end
						else
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 3 -1 + spellBarWidth*2, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 0, 0, 0))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 3 + spellBarWidth*2, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 40, 185, 70))
						end
					end
				else
					DrawRect(heroPos.x - (barWidth/2) + barMargin * 3 -1 + spellBarWidth*2, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 80, 80, 80))
					DrawRect(heroPos.x - (barWidth/2) + barMargin * 3 + spellBarWidth*2, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 0, 0, 0))
				end

				--R DATA
				local RData = unit:GetSpellData(_R)
				if RData.level > 0 then
					local isOnCd, currCD, cdRatio, specialCase = self:GetSpellCooldownData(RData, unit)
					if(specialCase) then
						DrawRect(heroPos.x - (barWidth/2) + barMargin * 4 -1 + spellBarWidth*3, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 0, 0, 0))
						DrawRect(heroPos.x - (barWidth/2) + barMargin * 4 + spellBarWidth*3, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 201, 56, 197))
					else
						if isOnCd then
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 4 -1 + spellBarWidth*3, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 125, 125, 125))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 4 + spellBarWidth*3, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 0, 0, 0))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 4 + spellBarWidth*3, heroPos.y + yOffset + barMargin, ((1 - (cdRatio)) * spellBarWidth), barHeight, DrawColor(255, 80, 80, 80))
							if(displayCDs) then
								DrawText(string.format(formatToken, currCD), fontSize, heroPos.x - (barWidth/2) + 3 + barMargin*4 + spellBarWidth*3, heroPos.y + yOffset + barMargin -2, DrawColor(255, 255, 255, 255), self.CDFont)
							end
						else
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 4 -1 + spellBarWidth*3, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 0, 0, 0))
							DrawRect(heroPos.x - (barWidth/2) + barMargin * 4 + spellBarWidth*3, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 183, 222, 54))
						end
					end
				else
					DrawRect(heroPos.x - (barWidth/2) + barMargin * 4 -1 + spellBarWidth*3, heroPos.y + yOffset + barMargin -1, spellBarWidth +2, barHeight +2, DrawColor(255, 80, 80, 80))
					DrawRect(heroPos.x - (barWidth/2) + barMargin * 4 + spellBarWidth*3, heroPos.y + yOffset + barMargin, spellBarWidth, barHeight, DrawColor(255, 0, 0, 0))
				end

				--Ability Levels
				if(self.TrackerMenu.TrackAbilityLevels:Value() and barWidth >= 150 and hoverSkillLevel) then

					local xpBarPos = self.TrackerMenu.Customize.XPBarPos:Value()
					local barAnchorOffset = 0

					if(xpBarPos == 1) then
						barAnchorOffset = barHeight + barMargin - 5
					else
						barAnchorOffset = -20 + barMargin - 5
					end

					--Q
					DrawText(string.rep(".", QData.level), 20, heroPos.x - (barWidth/2) + barMargin*1, heroPos.y + yOffset + barAnchorOffset, DrawColor(255, 235, 171, 66), self.CDFont)

					--W
					DrawText(string.rep(".", WData.level), 20, heroPos.x - (barWidth/2) + barMargin * 2 + spellBarWidth, heroPos.y + yOffset + barAnchorOffset, DrawColor(255, 235, 171, 66), self.CDFont)
				
					--E
					DrawText(string.rep(".", EData.level), 20, heroPos.x - (barWidth/2) + barMargin * 3 + spellBarWidth *2, heroPos.y + yOffset + barAnchorOffset, DrawColor(255, 235, 171, 66), self.CDFont)

					--R
					DrawText(string.rep(".", RData.level), 20, heroPos.x - (barWidth/2) + barMargin * 4 + spellBarWidth *3, heroPos.y + yOffset + barAnchorOffset, DrawColor(255, 235, 171, 66), self.CDFont)
				end
			end

			--Summoner Draws
			if(self.TrackerMenu.TrackSummoners:Value() and hoverSummoners) then

				local formatToken = "%.0f"
				local centerBarOffset = -(spriteSize * spriteScale) + (barHeight/2) --This is to anchor the summoners in the center of the horizontal spell bar
				if(displayDecimals) then formatToken = "%.1f" end

				self:UpdateSpriteScale()

				DrawRect(heroPos.x - (barWidth/2) + barMargin + barWidth -2, heroPos.y + yOffset + barMargin + centerBarOffset -2, spriteSize * spriteScale + 4, spriteSize * spriteScale * 2 + 4, DrawColor(255, 0, 0, 0))

				--SUMMONER SLOT 1

				local SummonerSlot1 = unit:GetSpellData(SUMMONER_1)
				if SummonerSlot1.level > 0 then
					local spellCD = 0

					if SummonerSlot1.currentCd > 0 then
						spellCD = math.max(SummonerSlot1.currentCd / SummonerSlot1.cd, 0)
					end

					local SprIdx1 = summonerSprites[SummonerSlot1.name]
					local SprIdx1Fill = summonerSprites[SummonerSlot1.name]
					--Sprite fill animation
					if SprIdx1 ~= nil and SprIdx1Fill ~= nil then
						local sprCut = {x = 0, y = spriteSize * spriteScale, w = spriteSize * spriteScale, h = spriteSize * 2 * spriteScale}
						if(spellCD <= 0) then
							SprIdx1:SetColor(self.ColorWhite)
						else
							SprIdx1:SetColor(self.ColorGrey)
						end
						SprIdx1:Draw(sprCut, heroPos.x - (barWidth/2) + barMargin + barWidth, heroPos.y + yOffset + barMargin + centerBarOffset)

						if(spellCD > 0) then
							local sprCut = {x = 0, y = 0, w = spriteSize * spriteScale, h = spriteSize * spriteScale * spellCD}
							SprIdx1Fill:SetColor(self.ColorGrey)
							SprIdx1Fill:Draw(sprCut, heroPos.x - (barWidth/2) + barMargin + barWidth, heroPos.y + yOffset + barMargin + centerBarOffset)
						end
					end

					if(displayCDs and spellCD > 0) then
						local fontSize = (spriteSize * spriteScale) * 0.6
						DrawText(string.format(formatToken, SummonerSlot1.currentCd), 
							fontSize, heroPos.x - (barWidth/2) + barMargin + barWidth + (spriteSize * spriteScale) + 5, 
							heroPos.y + yOffset + barMargin + (spriteSize * spriteScale)/2 - fontSize/2 + centerBarOffset, 
							self.ColorWhite, self.CDFont)
					end

					if(spellCD > 0) then
					--Accent line for visual improvement
					DrawLine(heroPos.x - (barWidth/2) + barMargin + barWidth, heroPos.y + yOffset + barMargin + centerBarOffset + (spriteSize * spriteScale * spellCD),
							heroPos.x - (barWidth/2) + barMargin + barWidth + (spriteSize * spriteScale), heroPos.y + yOffset + barMargin + centerBarOffset + (spriteSize * spriteScale * spellCD),
							self.fadedWhite)
					end
				end

				--SUMMONER SLOT 2
				local SummonerSlot2 = unit:GetSpellData(SUMMONER_2)
				if SummonerSlot2.level > 0 then
					local spellCD = 0

					if SummonerSlot2.currentCd > 0 then
						spellCD = math.max(SummonerSlot2.currentCd / SummonerSlot2.cd, 0)
					end

					local SprIdx2 = summonerSprites[SummonerSlot2.name]
					local SprIdx2Fill = summonerSprites[SummonerSlot2.name]
					--Sprite fill animation
					if SprIdx2 ~= nil and SprIdx2Fill ~= nil then
						local sprCut = {x = 0, y = spriteSize * spriteScale, w = spriteSize * spriteScale, h = spriteSize * 2 * spriteScale}
						if(spellCD <= 0) then
							SprIdx2:SetColor(self.ColorWhite)
						else
							SprIdx2:SetColor(self.ColorGrey)
						end
						SprIdx2:Draw(sprCut, heroPos.x - (barWidth/2) + barMargin + barWidth, heroPos.y + yOffset + barMargin + (spriteSize * spriteScale) + centerBarOffset)

						if(spellCD > 0) then
							local sprCut = {x = 0, y = 0, w = spriteSize * spriteScale, h = spriteSize * spriteScale * spellCD}
							SprIdx2Fill:SetColor(self.ColorGrey)
							SprIdx2Fill:Draw(sprCut, heroPos.x - (barWidth/2) + barMargin + barWidth, heroPos.y + yOffset + barMargin + (spriteSize * spriteScale) + centerBarOffset)
						end
					end

					if(displayCDs and spellCD > 0) then
						local fontSize = (spriteSize * spriteScale) * 0.6
						DrawText(string.format(formatToken, SummonerSlot2.currentCd), 
							fontSize, heroPos.x - (barWidth/2) + barMargin + barWidth + (spriteSize * spriteScale) + 5, 
							heroPos.y + yOffset + barMargin + (spriteSize * spriteScale) + (spriteSize * spriteScale)/2 - fontSize/2 + centerBarOffset, 
							self.ColorWhite, self.CDFont)
					end

					if(spellCD > 0) then
					--Accent line for visual improvement
					DrawLine(heroPos.x - (barWidth/2) + barMargin + barWidth, heroPos.y + yOffset + barMargin + centerBarOffset + (spriteSize * spriteScale) + (spriteSize * spriteScale * spellCD),
							heroPos.x - (barWidth/2) + barMargin + barWidth + (spriteSize * spriteScale), heroPos.y + yOffset + barMargin + centerBarOffset + (spriteSize * spriteScale) + (spriteSize * spriteScale * spellCD), 
							self.fadedWhite)
					end
				end

			end

		end
	end,

	GetSpellCooldownData = function(self, spell, spellOwner)
		if(spell ~= nil and spellOwner ~= nil) then
			-- Returns IsOnCD, Current CD, CD Ratio, Special

			--Spell Exceptions always first
			local exceptionData = self:SpellExceptions(spell, spellOwner)
			if(exceptionData ~= nil) then
				return exceptionData[1], exceptionData[2], exceptionData[3], exceptionData[4]
			end

			if(spell.ammo == 0 and spell.ammoCurrentCd > 0) then
				return true, spell.ammoCurrentCd, spell.ammoCurrentCd / spell.ammoCd, false
			end

			if(spell.currentCd > 0) then
				return true, spell.currentCd, spell.currentCd / spell.cd, false
			end

			return false, 0, 0, false
		end
		return false, 0, 0, false
	end,

	--[[
		You can alter the way spells are tracked here.
		Return different information in the form of a table.

		{IsOnCD, Current CD, CD Ratio, SpecialCase}

		SpecialCase is for spells like Ahri's R which uses hudAmmo 
	]]
	SpellExceptions = function(self, spell, spellOwner)
		--Ahri Ultimate
		if(spellOwner.charName == "Ahri" and spell.name == "AhriR") then
			if(spellOwner.hudMaxAmmo > 0) then
				return {true, 0, 1, true}
			end
		end

		--Karthus Q
		if(spellOwner.charName == "Karthus" and (spell.name == "KarthusLayWasteA1" or spell.name == "KarthusLayWasteA2" or spell.name == "KarthusLayWasteA3")) then
			if(spell.ammoCurrentCd > 0) then
				return {true, spell.ammoCurrentCd, spell.ammoCurrentCd / spell.ammoCd, false}
			end
		end

		--Gwen W
		if(spellOwner.charName == "Gwen" and (spell.name == "GwenWRecast")) then
			return {true, 0, 1, true}
		end

		--Gwen R
		if(spellOwner.charName == "Gwen" and (spell.name == "GwenRRecast")) then
			return {true, 0, 1, true}
		end

		--Shyvana R
		if(spellOwner.charName == "Shyvana" and (spell.name == "ShyvanaTransformCast")) then
			if(spellOwner.mana ~= 100) then
				return {true, spellOwner.mana, 1-spellOwner.mana/spellOwner.maxMana, false}
			end
		end

		--Riven R
		if(spellOwner.charName == "Riven" and (spell.name == "RivenIzunaBlade")) and spellOwner then
            if spell.cd==0.5 then
                return {true, 0, 1, true}
            end
            if spell.cd==30 then
                return {true, 30, 1, false}
            end
        end

		--Kogmaw W
        if(spellOwner.charName == "KogMaw" and (spell.name == "KogMawBioArcaneBarrage")) and spell.cd-spell.currentCd<8 then
            return {true, 8-(spell.cd-spell.currentCd),(spell.cd-spell.currentCd)/8, false}
        end

		--Darius R
        if(spellOwner.charName == "Darius" and (spell.name == "DariusExecute")) and spell.castTime + 20 > Game.Timer() and spell.currentCd == 0 and spell.level < 3 then
            local buffduration=spell.castTime + 20 - Game.Timer()
            if buffduration > 0 then
                return {true, buffduration, (20-buffduration)/20, false}
            end
        end

		--General Recast Abilities
		if(spell.name:lower():find("recast")) then
			return {true, 0, 1, true}
		end

		return nil
	end
}

Callback.Add("Load", function()
	LoadUnits()
	ChampionTracker:Init()
	KillerAwareness()
end)

Callback.Add("Tick", function()
	--AutoWardPing:OnTick()
	ChampionTracker:OnTick()
end)

Callback.Add("Draw", function()
	ChampionTracker:Draw()
end)

if KillerAwareness.OnWndMsg then
	table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
		KillerAwareness:OnWndMsg(msg, wParam)
	end)
end
