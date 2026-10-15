--!strict
-- Usa APIs do Roblox: só roda no Studio (Tests/Run). O require fica dentro de run()
-- para o runner do Lune conseguir carregar o arquivo e pular o spec.
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "Remotes",
	robloxOnly = true,
	run = function(t)
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local RunService = game:GetService("RunService")
		local Config = require("@game/ReplicatedStorage/Shared/Config")
		local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")

		t.it("lists declared remotes in sorted order", function()
			local names = Remotes.names()
			t.expect(table.find(names, "Interact") ~= nil).toBe(true)
			local sorted = table.clone(names)
			table.sort(sorted)
			t.expect(names).toEqual(sorted)
		end)

		t.it("errors on unknown remote names", function()
			t.expect(function()
				Remotes.kindOf("DoesNotExist")
			end).toThrow('unknown remote "DoesNotExist"')
		end)

		t.it("server has every declared remote with the right class", function()
			if not (RunService:IsServer() and RunService:IsRunning()) then
				return -- só faz sentido no servidor durante o playtest
			end
			local folder = ReplicatedStorage:FindFirstChild(Config.Net.RemotesFolderName)
			t.expect(folder).toBeTruthy()
			for _, name in Remotes.names() do
				local remote = (folder :: Instance):FindFirstChild(name)
				t.expect(remote and remote.ClassName).toBe(Remotes.kindOf(name))
			end
		end)
	end,
}

return spec
