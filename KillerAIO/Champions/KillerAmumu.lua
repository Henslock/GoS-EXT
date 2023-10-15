require "DamageLib"
require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "KillerAIO\\KillerLib"
require "KillerAIO\\KillerChampUpdater"

scriptVersion = 1.06

if not _G.SDK then
    print("GGOrbwalker is not enabled. Killer Amumu will exit.")
    return
end

-- [ AutoUpdate ]

UpdateMyHeroScript()

----------------------------------------------------
--|                Champion               		|--
----------------------------------------------------

class "Amumu"

local ChampIcon = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/ChampionIcons/amumu.png"

local gameTick = GameTimer()
Amumu.AutoLevelCheck = false

-- GG PRED
local Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 1100, Radius = 100, Speed = 2000, Collision = true, MaxCollision = 1, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
local W = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 350}
local E = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 350, Speed = math.huge}
local R = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 550, Speed = math.huge}

--Main Menu
Amumu.Menu = MenuElement({type = MENU, id = "KillerAmumu", name = "Killer Amumu", leftIcon = ChampIcon})
Amumu.Menu:MenuElement({name = " ", drop = {"Version: " .. scriptVersion}})

Amumu.InterruptableSpells = {
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

function Amumu:__init()
	self:LoadMenu()
	table.insert(_G.SDK.OnTick, function()
		self:Tick()
	end)

	table.insert(_G.SDK.OnDraw, function()
		self:Draw()
	end)

end

function Amumu:LoadMenu()                     	

	-- Combo
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "UseR", name = "Use R", value = true})
	self.Menu.Combo:MenuElement({id = "QSettings", name = "Q Settings", type = MENU})
	self.Menu.Combo:MenuElement({id = "RSettings", name = "R Settings", type = MENU})
	self.Menu.Combo:MenuElement({name = " ", drop = {"-----------------------------"}})	
	self.Menu.Combo:MenuElement({id = "WMana", name = "Disable W Below Mana", value = 10, min = 0, max = 100, step = 5, identifier = "%"})
	self.Menu.Combo:MenuElement({id = "SemiManualQ", name = "Semi-manual Q", key = string.byte("Z")})

	--Q Settings
	self.Menu.Combo.QSettings:MenuElement({id = "QRange", name = "Adjust Max Q Range", value = Q.Range, min = E.Radius + 100, max = Q.Range, step = 5})
	self.Menu.Combo.QSettings:MenuElement({id = "MeleeQ", name = "Don't Use Q in Melee Range", value = false})
	self.Menu.Combo.QSettings:MenuElement({id = "AntiChannelQ", name = "Use Q to Interrupt Channeled Spells", value = true})

	--R Settings
	self.Menu.Combo.RSettings:MenuElement({id = "AutoRCount", name = "Auto R on # Targets", value = 3, min = 1, max = 5, step = 1})

	-- Clear
	self.Menu:MenuElement({id = "Clear", name = "Clear", type = MENU})
	self.Menu.Clear:MenuElement({id = "UseW", name = "Use W", value = true})
	self.Menu.Clear:MenuElement({id = "UseE", name = "Use E", value = true})
	self.Menu.Clear:MenuElement({name = " ", drop = {"-----------------------------"}})	
	self.Menu.Clear:MenuElement({id = "WTargetCount", name = "Min # Targets to Use W", value = 3, min = 1, max = 6, step = 1})
	self.Menu.Clear:MenuElement({id = "WMana", name = "Disable W Below Mana", value = 30, min = 0, max = 100, step = 5, identifier = "%"})

	-- Kill Steal
	self.Menu:MenuElement({id = "KillSteal", name = "Kill Steal", type = MENU})
	self.Menu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true})
	
	-- Draws
	self.Menu:MenuElement({id = "Drawings", name = "Draws", type = MENU})
	self.Menu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
	self.Menu.Drawings:MenuElement({id = "DrawR", name = "Draw R Range", value = true})
		
	self.Menu:MenuElement({id = "AutoLevel", name = "Auto Level Skills (E - Q - W)", value = false})
	self.Menu:MenuElement({id = "DisableInFountain", name = "Disable Orbwalker while in Fountain", value = true})
	
end

function Amumu:Tick()
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

	Q.Range = self.Menu.Combo.QSettings.QRange:Value()

	self:KillSteal()

	if(self.Menu.Combo.SemiManualQ:Value()) then
		self:SemiManualQ()
	end

	if Game.IsOnTop() and self.Menu.AutoLevel:Value() then
		self:AutoLevel()
	end	
end


function Amumu:AutoLevel()
	if self.AutoLevelCheck then return end
	
	local level = myHero.levelData.lvl
	local levelPoints = myHero.levelData.lvlPts

	if (levelPoints == 0) or (level == 1) then return end
	if (Game.mapID == HOWLING_ABYSS and level <= 3) then return end
	--Order = Q > E > W
	if(levelPoints >0) then
		self.AutoLevelCheck = true
		DelayAction(function()				
				
				--Levels 1 ~ 3
				if level == 1 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_Q)
					Control.KeyUp(HK_Q)
					Control.KeyUp(HK_LUS)
				elseif level == 2 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_W)
					Control.KeyUp(HK_W)
					Control.KeyUp(HK_LUS)
				elseif level == 3 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_E)
					Control.KeyUp(HK_E)
					Control.KeyUp(HK_LUS)
				end

				if level == 6 or level == 11 or level == 16 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_R)
					Control.KeyUp(HK_R)
					Control.KeyUp(HK_LUS)
				elseif level == 4 or level == 5 or level == 7 or level == 9 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_E)
					Control.KeyUp(HK_E)
					Control.KeyUp(HK_LUS)
				elseif level == 8 or level == 10 or level == 12 or level == 13 then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_Q)
					Control.KeyUp(HK_Q)
					Control.KeyUp(HK_LUS)
				elseif level == 14 or level == 15 or level == 17 or level == 18 then				
					Control.KeyDown(HK_LUS)
					Control.KeyDown(HK_W)
					Control.KeyUp(HK_W)
					Control.KeyUp(HK_LUS)
				end
		
			self.AutoLevelCheck = false
		end, 0.5)
	end
end


function Amumu:Combo()
	if(gameTick > GameTimer()) then return end
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	-- R
	local RBuffer = -50
	if(Ready(_R) and self.Menu.Combo.UseR:Value()) then
		if(GetEnemyCount(R.Radius + RBuffer, myHero) >= self.Menu.Combo.RSettings.AutoRCount:Value()) then
			Control.CastSpell(HK_R)
			return
		end
	end

	--Q Interrupter
	if(self.Menu.Combo.UseQ:Value() and self.Menu.Combo.QSettings.AntiChannelQ:Value()) then
		if(Ready(_Q)) then
			local enemies = GetEnemyHeroes(Q.Range)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy.valid and IsValid(enemy) and self:CantKill(enemy, true, true, false) == false) then
						--Interrupt them if they are channeling an interruptible spell
						local spell = enemy.activeSpell
						if(spell and spell.valid and self.InterruptableSpells[spell.name]) then
							local QPrediction = GGPrediction:SpellPrediction(Q)
							QPrediction:GetPrediction(enemy, myHero)
							if QPrediction.CastPosition and QPrediction:CanHit(HITCHANCE_HIGH) then
								local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, QPrediction.CastPosition, Q.Speed, Q.Delay, Q.Radius + 5, Q.CollisionTypes, enemy.networkID)
								if(collisionCount < Q.MaxCollision) then
									Control.CastSpell(HK_Q, QPrediction.CastPosition)
									return
								end
							end
						end
						
					end
				end
			end
		end
	end

	--Q
	if(self.Menu.Combo.UseQ:Value()) then
		if(Ready(_Q)) then
			local tar = GetTarget(Q.Range)
			if(tar and IsValid(tar) and tar.toScreen.onScreen) then
				local shouldUseQ = true
				if(self.Menu.Combo.QSettings.MeleeQ:Value()) then
					if(GetDistance(tar, myHero) <= E.Radius) then
						shouldUseQ = false
					end
				end

				if(self:CantKill(tar, true, true, false) == true) then
					shouldUseQ = false
				end

				if(shouldUseQ) then
					CastPredictedSpell({Hotkey = HK_Q, Target = tar, SpellData = Q, maxCollision = 1})
					--[[
					local isStrafing, avgPos = StrafePred:IsStrafing(tar)
					local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(tar)
					if(isStrafing) then
						if(avgPos:DistanceTo(myHero.pos) < Q.Range) then
							local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, avgPos, Q.Speed, Q.Delay, Q.Radius + 5, Q.CollisionTypes, tar.networkID)
							if(collisionCount < Q.MaxCollision) then
								Control.CastSpell(HK_Q, avgPos)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end
					if(isStutterDancing) then
						if(avgPos2:DistanceTo(myHero.pos) < Q.Range) then
							local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, avgPos2, Q.Speed, Q.Delay, Q.Radius + 5, Q.CollisionTypes, tar.networkID)
							if(collisionCount < Q.MaxCollision) then
								Control.CastSpell(HK_Q, avgPos2)
								gameTick = GameTimer() + 0.2
								return
							end
						end
					end
					
					--We can use Q on targets that are casting spells and are stationary briefly
					if(tar.activeSpell.valid and tar.pathing.hasMovePath == false) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, tar.pos, Q.Speed, Q.Delay, Q.Radius + 5, Q.CollisionTypes, tar.networkID)
						if(collisionCount < Q.MaxCollision) then
							Control.CastSpell(HK_Q, tar.pos)
							gameTick = GameTimer() + 0.2
							return
						end
					end

					local QPrediction = GGPrediction:SpellPrediction(Q)
					QPrediction:GetPrediction(tar, myHero)
					if QPrediction.CastPosition and QPrediction:CanHit(HITCHANCE_HIGH) then
						local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, QPrediction.CastPosition, Q.Speed, Q.Delay, Q.Radius + 5, Q.CollisionTypes, tar.networkID)
						if(collisionCount < Q.MaxCollision) then
							Control.CastSpell(HK_Q, QPrediction.CastPosition)
							gameTick = GameTimer() + 0.2
							return
						end
					end
					--]]
				end
			end
		end
	end

	-- W
	local hasWActive = (myHero:GetSpellData(_W).toggleState == 2)
	if(Ready(_W) and self.Menu.Combo.UseW:Value()) then
		if((myHero.mana / myHero.maxMana) >= (self.Menu.Combo.WMana:Value() / 100) ) then
			if(GetEnemyCount(W.Radius, myHero) > 0) and not hasWActive then
				Control.CastSpell(HK_W)
				gameTick = GameTimer() + 0.05
				return
			end
		end
	end

	-- Disable your W if there are no enemies nearby or you are below the mana threshold
	local WDisableBuffer = 100
	if hasWActive and ((GetEnemyCount(W.Radius + WDisableBuffer, myHero) == 0) or (myHero.mana / myHero.maxMana) < (self.Menu.Combo.WMana:Value() / 100)) then
		Control.CastSpell(HK_W)
		gameTick = GameTimer() + 0.05
		return
	end


	-- E
	local EBuffer = -50
	if(Ready(_E) and self.Menu.Combo.UseE:Value()) then
		if(GetEnemyCount(E.Radius + EBuffer, myHero) > 0) then
			Control.CastSpell(HK_E)
			return
		end
	end

end

function Amumu:LastHit()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end
end

function Amumu:Clear()
	if(gameTick > GameTimer()) then return end	
	if not (myHero.valid or IsValid(myHero)) or myHero.isChanneling then return end

	-- E
	if(Ready(_E) and self.Menu.Clear.UseE:Value()) then
		if(GetMinionCount(E.Radius, E.Radius, myHero.pos) > 0) then
			Control.CastSpell(HK_E)
			return
		end
	end

	-- W
	local hasWActive = (myHero:GetSpellData(_W).toggleState == 2)
	if(Ready(_W) and self.Menu.Clear.UseW:Value()) then
		if((myHero.mana / myHero.maxMana) >= (self.Menu.Clear.WMana:Value() / 100) ) then
			if(GetMinionCount(W.Radius, W.Radius, myHero.pos) > self.Menu.Clear.WTargetCount:Value()) and not hasWActive then
				Control.CastSpell(HK_W)
				gameTick = GameTimer() + 0.05
				return
			end
		end
	end

	-- Disable your W if there are no minions nearby or you are below the mana threshold
	local WDisableBuffer = 100
	if hasWActive and ((GetMinionCount(W.Radius + WDisableBuffer, W.Radius + WDisableBuffer, myHero.pos) == 0) or (myHero.mana / myHero.maxMana) < (self.Menu.Combo.WMana:Value() / 100)) then
		Control.CastSpell(HK_W)
		gameTick = GameTimer() + 0.05
		return
	end
end

function Amumu:KillSteal()
	if(gameTick > GameTimer()) then return end
	
	--Q
	if(self.Menu.KillSteal.UseQ:Value()) then
		if(Ready(_Q)) and not myHero.isChanneling then
			local enemies = GetEnemyHeroes(Q.Range)
			if(#enemies > 0) then
				for _, enemy in pairs (enemies) do
					if(enemy.valid and IsValid(enemy) and enemy.toScreen.onScreen) then
						local isKillable = false
						local QDmg = self:GetRawAbilityDamage("Q")
						QDmg = CalcMagicalDamage(myHero, enemy, QDmg)
						isKillable = (enemy.health - QDmg + 15 < 0)
						if(isKillable and (self:CantKill(enemy, true, true, false))==false) then
							local QPrediction = GGPrediction:SpellPrediction(Q)
							QPrediction:GetPrediction(enemy, myHero)
							if QPrediction.CastPosition and QPrediction:CanHit(HITCHANCE_HIGH) then
								local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, QPrediction.CastPosition, Q.Speed, Q.Delay, Q.Radius + 25, Q.CollisionTypes, enemy.networkID)
								if(collisionCount < Q.MaxCollision) then
									Control.CastSpell(HK_Q, QPrediction.CastPosition)
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

function Amumu:GetRawAbilityDamage(spell, target)
	if(spell == "Q") then
		if myHero:GetSpellData(_Q).level == 0 then return 0 end
		return ({70, 95, 120, 145, 170})[myHero:GetSpellData(_Q).level] + (0.85 * myHero.ap)
   end
	
	return 0
end

function Amumu:SemiManualQ()
	_G.SDK.Orbwalker:Orbwalk()
	if(gameTick > GameTimer()) then return end	

	if(Ready(_Q)) then
		local target = GetTarget(Q.Range)
		if(target and IsValid(target)) then
			local isStrafing, avgPos = StrafePred:IsStrafing(target)
			local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
			if(isStrafing) then
				if(avgPos:DistanceTo(myHero.pos) < Q.Range) then
					Control.CastSpell(HK_Q, avgPos)
					gameTick = GameTimer() + 0.2
					return
				end
			end
			if(isStutterDancing) then
				if(avgPos2:DistanceTo(myHero.pos) < Q.Range) then
					Control.CastSpell(HK_Q, avgPos2)
					gameTick = GameTimer() + 0.2
					return
				end
			end
			
			--We can use Q on targets that are casting spells and are stationary briefly
			if(target.activeSpell.valid and target.pathing.hasMovePath == false) then
				local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, Q.Speed, Q.Delay, Q.Radius + 5, Q.CollisionTypes, target.networkID)
				if(collisionCount < Q.MaxCollision) then
					Control.CastSpell(HK_Q, target.pos)
					return
				end
			end

			local QPrediction = GGPrediction:SpellPrediction(Q)
			QPrediction:GetPrediction(target, myHero)
			if QPrediction.CastPosition and QPrediction:CanHit(HITCHANCE_HIGH) then
				local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, QPrediction.CastPosition, Q.Speed, Q.Delay, Q.Radius + 5, Q.CollisionTypes, target.networkID)
				if(collisionCount < Q.MaxCollision) then
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
					return
				end
			end
		end
	end

end

function Amumu:CantKill(unit, kill, ss, aa)
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

local alphaLerp = 0
function Amumu:Draw()
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


	if(self.Menu.Drawings.DrawR:Value()) then
		if(myHero:GetSpellData(_R).level > 0) then
			if(Ready(_R)) then
				if(GetEnemyCount(R.Radius, myHero) > 0) then
					DrawCircle(myHero, R.Radius, 2, DrawColor(255, 235, 192, 52))
				else
					DrawCircle(myHero, R.Radius, 1, DrawColor(100, 235, 192, 52))
				end
			else
				DrawCircle(myHero, R.Radius, 1, DrawColor(20, 235, 192, 52))
			end
		end
	end
end

Amumu()
LoadUnits()
