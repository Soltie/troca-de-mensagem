--!strict
local MockDataStore = require("@game/ServerScriptService/Server/Data/MockDataStore")
local PlayerDataSchema = require("@game/ServerScriptService/Server/Data/PlayerDataSchema")
local SessionLock = require("@game/ServerScriptService/Server/Data/SessionLock")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "SessionLock",
	run = function(t)
		t.it("free, own or expired locks can be taken; a fresh foreign lock cannot", function()
			t.expect(SessionLock.canTake(nil, "a", 100)).toBe(true)
			t.expect(SessionLock.canTake(SessionLock.make("a", 90), "a", 100)).toBe(true)
			t.expect(SessionLock.canTake(SessionLock.make("b", 90), "a", 100)).toBe(false)
			t.expect(SessionLock.canTake(SessionLock.make("b", 0), "a", SessionLock.TTL)).toBe(true)
			t.expect(SessionLock.canTake("garbage" :: any, "a", 1)).toBe(true)
		end)

		t.it("a blocked UpdateAsync transform leaves the stored data untouched", function()
			local store = MockDataStore.new()
			local data = PlayerDataSchema.template()
			data.wallet.creditos = 500
			data.sessionLock = SessionLock.make("new-server", 1000)
			store:UpdateAsync("k", function()
				return data
			end)
			-- Servidor antigo tenta salvar uma versão desatualizada: a trava de outro bloqueia.
			store:UpdateAsync("k", function(current: any)
				if not SessionLock.canTake(current.sessionLock, "old-server", 1010) then
					return nil
				end
				return PlayerDataSchema.template()
			end)
			t.expect(store:GetAsync("k").wallet.creditos).toBe(500)
		end)
	end,
}

return spec
