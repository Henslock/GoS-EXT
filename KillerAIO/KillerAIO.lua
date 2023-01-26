--[[ KILLER AIO --]]--

--[[

Created by Hightail

--]]

if _G.Killer then
	return
end

local scriptVersion = 1.01

local KILLER_PATH = COMMON_PATH.."KillerAIO/"
local KILLER_CHAMPS = KILLER_PATH.."Champions/"
local KILLER_LIB = "KillerLib.lua"
local KILLER_VERSION = "KillerLib.version"
local KILLER_UPDATER = "KillerChampUpdater.lua"
local gitHub = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/KillerAIO/"

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

local function DownloadFile(path, fileName)
	local startTime = os.clock()
	DownloadFileAsync(gitHub .. fileName, path .. fileName, function() end)
	repeat until os.clock() - startTime > 3 or FileExists(path .. fileName)
end

local function TryChampScriptDownload()
	local startTime = os.clock()
	DownloadFileAsync(gitHub .. "Champions/" .. champFile, KILLER_CHAMPS .. champFile, function() end)
	repeat until os.clock() - startTime > 3 or FileExists(KILLER_CHAMPS .. champFile)
	if(FileExists(KILLER_CHAMPS .. champFile)) then
		return true
	else
		return false
	end
end

local function CheckSupportedChamp()
	local result = FileExists(KILLER_CHAMPS .. champFile)
	if(result == true) then
		return result
	else
		local tryDownload = TryChampScriptDownload()
		if(tryDownload) == true then return true end
		return result
	end
end

--Download necessary core files/libraries
local function InitLibs()
	local libCheck = FileExists(KILLER_PATH .. KILLER_LIB)
	local updaterCheck = FileExists(KILLER_PATH .. KILLER_UPDATER)
	
	if(libCheck == false) then
		print("Installing Killer Libs...")
		DownloadFile(KILLER_PATH, KILLER_LIB)
		DownloadFile(KILLER_PATH, KILLER_VERSION)
		return
	end
	
	if(updaterCheck == false) then
		DownloadFile(KILLER_PATH, KILLER_UPDATER)
		return
	end
end

local function InitKillerAIO()
	InitLibs()
	local libCheck = FileExists(KILLER_PATH .. KILLER_LIB)
	if(libCheck == false) then
		print("Could not load KillerLib - Exiting!")
		return
	end
	
	local updaterCheck = FileExists(KILLER_PATH .. KILLER_UPDATER)
	if(updaterCheck == false) then
		print("Could not load Killer Champ Updater - Exiting!")
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
