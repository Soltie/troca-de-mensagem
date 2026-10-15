--!strict
--[[
	DataStore em memória com a mesma interface usada pelo PlayerDataService
	(GetAsync / UpdateAsync / RemoveAsync). Usado quando não há acesso às APIs
	(Studio sem permissão, place não publicada). Os dados somem quando o servidor fecha.
	Puro: testável no Lune.
]]

local TableUtil = require("@game/ReplicatedStorage/Shared/Util/TableUtil")

export type Store = {
	GetAsync: (self: Store, key: string) -> any,
	UpdateAsync: (self: Store, key: string, transform: (current: any) -> ...any) -> any,
	RemoveAsync: (self: Store, key: string) -> any,
}

local MockDataStore = {}

function MockDataStore.new(): Store
	local entries: { [string]: any } = {}
	local store = {}

	function store.GetAsync(_self: Store, key: string): any
		return TableUtil.deepCopy(entries[key])
	end

	function store.UpdateAsync(_self: Store, key: string, transform: (current: any) -> ...any): any
		-- Como no real, o transform pode retornar (valor, userIds, metadata); só o valor importa aqui.
		local nextValue = transform(TableUtil.deepCopy(entries[key]))
		-- Igual ao DataStore real: retornar nil cancela a escrita.
		if nextValue ~= nil then
			entries[key] = TableUtil.deepCopy(nextValue)
		end
		return TableUtil.deepCopy(entries[key])
	end

	function store.RemoveAsync(_self: Store, key: string): any
		local previous = entries[key]
		entries[key] = nil
		return previous
	end

	return store :: any
end

return MockDataStore
