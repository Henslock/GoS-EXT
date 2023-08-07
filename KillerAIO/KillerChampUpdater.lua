-- [ KillerAIO Universal Champ Updater ]

local KILLER_PATH = COMMON_PATH.."KillerAIO/"
local KILLER_CHAMPS = KILLER_PATH.."Champions/"
local champName = myHero.charName
local champFile = "Killer"..champName..".lua"
local champVersion = "Killer"..champName..".version"
local gitHub = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/KillerAIO/Champions/"

local function FileExists(path)
	local file = assert(io.open(path, "r"))
	if file ~= nil then 
		io.close(file) 
		return true 
	else 
		return false 
	end
end

local function DownloadFile(path, fileName)
	local startTime = os.clock()
	DownloadFileAsync(gitHub .. fileName, path .. fileName, function() end)
	repeat until os.clock() - startTime > 3 or FileExists(path .. fileName)
end

local function ReadFile(path, fileName)
	local file = io.open(path .. fileName, "r")
	local result = file:read()
	file:close()
	return result
end

function UpdateMyHeroScript()    
	DownloadFile(KILLER_CHAMPS, champVersion)
	local NewVersion = tonumber(ReadFile(KILLER_CHAMPS, champVersion))
	if NewVersion > scriptVersion then
		DownloadFile(KILLER_CHAMPS, champFile)
		print("New Killer "..champName.." Version - Please reload with F6")
	else
		print("| KILLER | "..champName.." Loaded! Enjoy :)")
	end
end
