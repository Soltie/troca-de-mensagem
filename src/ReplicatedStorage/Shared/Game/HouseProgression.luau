--!strict
-- Dependências públicas, sem códigos: História guiada; Desafio permite dividir tarefas entre colegas.
local Progress = {}
local groups: { { { number } } } = {
	{ {}, { 1 }, { 2 }, { 2 }, { 2 }, { 3, 4, 5 }, { 6 } },
	{ {}, {}, {}, { 1, 2, 3 }, { 4 }, { 5 }, { 6 } },
	{ {}, {}, {}, {}, { 1, 2, 3, 4 } },
	{ {}, { 1 }, {}, { 2, 3 }, { 4 }, { 5 } },
	{ {}, { 1 }, { 1 }, { 1 }, { 2, 3, 4 } },
}
function Progress.dependencies(mode: string?, chapter: number, index: number): { number }
	if mode == "Standard" and chapter <= 5 then
		return table.clone(groups[chapter][index])
	end
	return if index > 1 then { index - 1 } else {}
end
function Progress.ready(mode: string?, chapter: number, index: number, solved: (number) -> boolean): boolean
	for _, dependency in Progress.dependencies(mode, chapter, index) do
		if not solved(dependency) then
			return false
		end
	end
	return true
end
return table.freeze(Progress)
