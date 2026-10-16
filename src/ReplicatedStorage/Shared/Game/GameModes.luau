--!strict
-- Votação pura do servidor: um voto por integrante, maioria absoluta e equipe mínima.
local Modes = {}
export type Id = "Standard" | "Story"
export type Votes = { [number]: Id }

function Modes.winner(votes: Votes, members: { [number]: any }, minimum: number): (Id?, number, number)
	local count, standard, story = 0, 0, 0
	for id in members do
		count += 1
		if votes[id] == "Standard" then
			standard += 1
		elseif votes[id] == "Story" then
			story += 1
		end
	end
	if count >= minimum then
		if story > count / 2 then
			return "Story", standard, story
		elseif standard > count / 2 then
			return "Standard", standard, story
		end
	end
	return nil, standard, story
end

return table.freeze(Modes)
