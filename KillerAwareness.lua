require "2DGeometry"
require "MapPositionGOS"

local scriptVersion = 1.13
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
	
	for i = 1, Game.TurretCount() do
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
local scriptIcon = "https://www.proguides.com/public/media/rlocal/rune/reforged/thumbnail/8128.png"
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
	self.Menu:MenuElement({id = "WardPing", name = "Ward Auto-Ping", type = MENU})
	self.Menu.WardPing:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.WardPing:MenuElement({id = "BonusDelay", name = "Extra Humanizer Delay", value = 200, min = 50, max = 750, step = 25})

	--Champion Tracker
	--[[
	self.Menu:MenuElement({id = "ChampTracker", name = "Champion Tracker", type = MENU})
	self.Menu.ChampTracker:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.ChampTracker:MenuElement({id = "TrackAbilities", name = "Track Abilities", value = true})
	self.Menu.ChampTracker:MenuElement({id = "TrackSummoners", name = "Track Summoners", value = true})
	self.Menu.ChampTracker:MenuElement({id = "TrackExperience", name = "Track Experience", value = true})
	self.Menu.ChampTracker:MenuElement({id = "EnableTrackingWidget", name = "Enable Tracking Widget", value = false})
	--]]
	
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

	Scan = function(self)
		if not (myHero.valid or IsValid(myHero)) or GameIsChatOpen() then return end
		local wards = _G.SDK.ObjectManager:GetOtherEnemyMinions()
		local nearbyEnemies = _G.SDK.ObjectManager:GetEnemyHeroes(325) --Do not ping when enemies are around
		if(#wards > 0 and #nearbyEnemies == 0) then
			for _, ward in ipairs(wards) do
				if(ward.visible and ward.valid) then
					if(self:CheckExistingWard(ward) == false and self:IsNewWard(ward)) then
						local extraDelay = self.WardMenu.BonusDelay:Value() / 1000
						DelayAction(function()
							self.OldMousePos = Game.mousePos()
							self.WardTarget = ward
							self.IsActivePinging = true
							self.randomOffset = {x = math.random(-75, 75), y = 0, z = math.random(-75, 75)}
						end, 0.02 + extraDelay)
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
		Control.KeyDown(18)
		_G.SDK.Cursor:Add(MOUSEEVENTF_LEFTDOWN, finalClickPos)
		Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
		Control.mouse_event(MOUSEEVENTF_LEFTUP)
		DelayAction(function()
			Control.KeyUp(18)
			self.IsActivePinging = false
			if(myHero.pathing.hasMovePath) then
				_G.SDK.Cursor:Add(MOUSEEVENTF_RIGHTDOWN, self.OldMousePos)
			else
				_G.SDK.Cursor:Add(MOUSEEVENTF_LEFTDOWN, self.OldMousePos)
			end
		end, 0.008)

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

--Courtesy of the official champion tracker from GoS
local summonerSprites = {};

summonerSprites[1] = { Sprite("SpellTracker\\1.png"), "SummonerBarrier" }
summonerSprites[2] = { Sprite("SpellTracker\\2.png"), "SummonerBoost" }
summonerSprites[3] = { Sprite("SpellTracker\\3.png"), "SummonerDot" }
summonerSprites[4] = { Sprite("SpellTracker\\4.png"), "SummonerExhaust" }
summonerSprites[5] = { Sprite("SpellTracker\\5.png"), "SummonerFlash" }
summonerSprites[6] = { Sprite("SpellTracker\\6.png"), "SummonerHaste" }
summonerSprites[7] = { Sprite("SpellTracker\\7.png"), "SummonerHeal" }
summonerSprites[8] = { Sprite("SpellTracker\\8.png"), "SummonerSmite" }
summonerSprites[9] = { Sprite("SpellTracker\\9.png"), "SummonerTeleport" }
summonerSprites[10] = { Sprite("SpellTracker\\10.png"), "S5_SummonerSmiteDuel" }
summonerSprites[11] = { Sprite("SpellTracker\\11.png"), "S5_SummonerSmitePlayerGanker" }
summonerSprites[12] = { Sprite("SpellTracker\\12.png"), "SummonerPoroRecall" }
summonerSprites[13] = { Sprite("SpellTracker\\13.png"), "SummonerPoroThrow" }

ChampionTracker = {

	TrackerMenu = nil,

	OnTick = function (self)
		if not (KillerAwareness.Menu.Loaded) then
			return
		else
			self.TrackerMenu = KillerAwareness.Menu.ChampTracker
		end
	end,

	Draw = function (self)
	end
}

Callback.Add("Load", function()
	LoadUnits()
	KillerAwareness()
end)

Callback.Add("Tick", function()
	AutoWardPing:OnTick()
	--ChampionTracker:OnTick()
end)

Callback.Add("Draw", function()
	--ChampionTracker:Draw()
end)

if KillerAwareness.OnWndMsg then
	table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
		KillerAwareness:OnWndMsg(msg, wParam)
	end)
end
