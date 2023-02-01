require "2DGeometry"
require "MapPositionGOS"

local map = Game.mapID
if(map ~= SUMMONERS_RIFT) then
	print("Killer Awareness only works on Summoners Rift. Exiting!")
	return
end

----------------------------------------------------
--|                   		UTILITY					             |--
----------------------------------------------------
TEAM_ALLY = myHero.team
TEAM_ENEMY = 300 - myHero.team
TEAM_JUNGLE = 300
GameTimer = Game.Timer
Allies, Enemies, Units, EnemyTurrets, FriendlyTurrets = {}, {}, {}, {}, {}
MathHuge = math.huge
TableInsert = table.insert
TableRemove = table.remove
DrawRect = Draw.Rect
DrawLine = Draw.Line
DrawCircle = Draw.Circle
DrawCircleMinimap = Draw.CircleMinimap
DrawColor = Draw.Color
DrawText = Draw.Text
ControlSetCursorPos = Control.SetCursorPos
ControlKeyUp = Control.KeyUp
ControlKeyDown = Control.KeyDown
GameCanUseSpell = Game.CanUseSpell
GameHeroCount = Game.HeroCount
GameHero = Game.Hero
GameMinionCount = Game.MinionCount
GameMinion = Game.Minion
GameTurretCount = Game.TurretCount
GameTurret = Game.Turret
GameIsChatOpen = Game.IsChatOpen
GameResolution = Game.Resolution()
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
local scriptVersion = 1.05
local scriptIcon = "https://www.proguides.com/public/media/rlocal/rune/reforged/thumbnail/8128.png"
local updateIcon = "https://www.proguides.com/public/media/rlocal/summonerspell/thumbnail/12.png"
local gitHub = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/"

TOP_LEFT, BOTTOM_LEFT, TOP_RIGHT, BOTTOM_RIGHT = {x = 0, y = 0}, {x = 0, y = GameResolution.y}, {x = GameResolution.x, y = 0}, {x = GameResolution.x , y = GameResolution.y}

local fallBackSprite = Sprite("KillerAwareness\\fallback.png")
local ChampionSprites = {}
local ChampionHaloData = {}

local haloCD = 10

function KillerAwareness:__init()
	print("Killer Awareness [ver. "..tostring(scriptVersion).."] loaded!")
	self:LoadMenu()
	self:CreateSprites()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function KillerAwareness:LoadMenu()
	self.Menu = MenuElement({type = MENU, id = "KillerAwareness", name = "Killer Awareness", leftIcon = scriptIcon})
	self.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})
	
	--Champion Tracker
	self.Menu:MenuElement({id = "ChampTracker", name = "Champion Tracker", type = MENU})
	self.Menu.ChampTracker:MenuElement({id = "Enabled", name = "Enable", value = true})
	self.Menu.ChampTracker:MenuElement({id = "LineThickness", name = "Line Thickness", value = 1, min = 1, max = 5, step = 1})
	
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
	
	--Update button
	self.Menu:MenuElement({id = "UpdateBtn", name = "Check for Script Updates", type =  MENU, leftIcon = updateIcon, onclick = function() self:CheckUpdates() end})
end

function KillerAwareness:Tick()
end

function KillerAwareness:DownloadFile(path, fileName)
	DownloadFileAsync(gitHub .. fileName, path .. fileName, function() end)
	while not FileExist(path .. fileName) do end
end


function KillerAwareness:CheckUpdates()
	self.Menu.UpdateBtn:Hide(true)
	print("Fetching latest version of the script...")
	self:DownloadFile(SCRIPT_PATH, "KillerAwareness.lua")
	print("Script downloaded, please reload with F6")
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

	if(self.Menu.ChampTracker.Enabled:Value()) then
		-- Draw lines connecting to enemy champions
		for k, v in pairs(Enemies) do
			local distMax = 3000
			local distMin = 1000
			if(v and IsValid(v) and myHero.pos.DistanceTo(v.pos) <= distMax and myHero.pos.DistanceTo(v.pos) > distMin) then
				local lineThickness = self.Menu.ChampTracker.LineThickness:Value()
				local lineAlphaVal = ((myHero.pos.DistanceTo(v.pos) - distMin) / (distMax - distMin)) * 0.9
				DrawLine(myHero.pos:To2D(), v.pos:To2D(), lineThickness, DrawColor(300 * lineAlphaVal, 255, 0, 0))
			end
		end
	end
	
	self:DrawTurretAwareness()
	
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
				local turretRange = (turret.boundingRadius + 750 + myHero.boundingRadius / 2)
				local totalRange = drawRange + turretRange
				if(turret.distance <= totalRange and (turret.name ~= "Turret_OrderTurretShrine_A" and turret.name ~= "Turret_ChaosTurretShrine_A")) then
					local alphaLerp = 1 - math.max((turret.distance - (totalRange - 200)) / (totalRange - (totalRange - 200)), 0)
					DrawCircle(turret, turretRange, 2, DrawColor(255 *alphaLerp, 50, 90, 255))
				end
			end
		end
	end
	
	if(self.Menu.TurretAwareness.DrawHP:Value()) then
		for _, turret in pairs(EnemyTurrets) do
			if(turret.valid and turret.isTargetableToTeam ) then
				local hp = tostring(math.floor((turret.health / turret.maxHealth) * 100)).."%"
				DrawRect(turret.posMM.x - 14, turret.posMM.y + 12, 34, 16, DrawColor(125, 0, 0, 0));
				DrawText(hp, 16, turret.posMM.x - 12, turret.posMM.y + 12, DrawColor(255, 255, 255, 255));
			end			
		end
	end
	
	if(self.Menu.TurretAwareness.DrawEnemies:Value()) then
		for _, turret in pairs(EnemyTurrets) do
			if(turret.valid and myHero.alive) then
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

Callback.Add("Load", function()
	LoadUnits()
	KillerAwareness()
end)
