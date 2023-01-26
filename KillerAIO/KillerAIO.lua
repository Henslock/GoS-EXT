--[[ KILLER AIO --]]--

--[[

Supported Champions:
- Karthus
- Annie
- Syndra

Created by Hightail.

--]]

if _G.Killer then
	return
end

local scriptVersion = 1.01

local KILLER_PATH = COMMON_PATH.."KillerAIO/"
local KILLER_CHAMPS = KILLER_PATH.."Champions/"
local KILLER_LIB = "KillerLib.lua"
local gitHub = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/Champions/"

local champName = myHero.charName
local champFile = "Killer"..champName..".lua"

local function FileExists(path)
	local file = io.open(path, "r")
	if file ~= nil then 
		io.close(file) 
		return true 
	else 
		return false 
	end
end

local function ReadFile(path, fileName)
	local file = io.open(path .. fileName, "r")
	local result = file:read()
	file:close()
	return result
end

local function CheckSupportedChamp()
	local result = FileExists(KILLER_CHAMPS .. champFile)
	return result
end


local function InitKillerAIO()
	local libCheck = FileExists(KILLER_PATH .. KILLER_LIB)
	if(libCheck == false) then
		print("Could not load KillerLib - Exiting!")
		return
	end
	
	if(CheckSupportedChamp()) then
		require("KillerAIO\\Champions\\Killer"..champName)
	else
		print("KILLERAIO - " .. champName .. " is not supported!")
	end
end
	
Callback.Add("Load", function() 
	InitKillerAIO()
	_G.Killer = true
end)
