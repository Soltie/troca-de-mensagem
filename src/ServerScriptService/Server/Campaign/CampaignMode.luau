--!strict
local RunService = game:GetService("RunService")
local Config = require("@game/ReplicatedStorage/Shared/Config")

local Mode = {}

function Mode.enabled(): boolean
	if Config.Campaign.Enabled then
		return true
	end
	if RunService:IsStudio() then
		local ok, args = pcall(function()
			return game:GetService("StudioTestService"):GetTestArgs()
		end)
		return ok and type(args) == "table" and args.campaignQA == true
	end
	return false
end

return Mode
