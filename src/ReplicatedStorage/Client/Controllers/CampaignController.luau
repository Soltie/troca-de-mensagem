--!strict
-- HUD cooperativo: objetivo acionável, orientação progressiva, barras, inventário e guia sob demanda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local HouseCatalog = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Guide = require("@game/ReplicatedStorage/Shared/Game/PlayerGuide")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Hud = require("../UI/FieldHud")
local Juice = require("../UI/Juice")
local Noir = require("../UI/NoirHud")
local Theme = require("../UI/Theme")
local Character = require("./CharacterController")
local AudioController = require("./AudioController")
local GameUi = require("./GameUiController")
local Flashlight = require("./FlashlightController")

-- Mochila: nome e descrição de cada espaço (o detalhe embaixo da grade).
local BAG_TEXT: { [string]: { string } } = {
	flashlight = { "Lanterna", "Ilumina o caminho. Bateria: %d%%." },
	keys = { "Chaves", "Chaves da casa encontradas: %d de 3." },
	fuses = { "Fusíveis", "Fusíveis de porcelana: %d de 3." },
	artifact = { "Artefato", "O coração da casa. %d com o time." },
	battery = { "Pilha", "Recarrega a lanterna. Você tem %d." },
	oxygen = { "Ar extra", "Recupera o fôlego preso. Você tem %d." },
	decoy = { "Isca", "Faz barulho longe de você. Você tem %d." },
	gasoline = { "Lata de óleo da máquina", "Derrame nas pilhas de madeira dos cômodos." },
	lighter = { "Lamparina do Valdemar", "Leva o fogo da máquina até o rastro de óleo." },
	empty = { "", "" },
}

type FieldSlot = Hud.Slot

local player = Players.LocalPlayer
local Controller = { Name = "CampaignController" }
local guideToggle: (() -> ())? = nil
function Controller.toggleGuide()
	if guideToggle then
		guideToggle()
	end
end
local messages: { [string]: string } = {
	progress = "Etapa certa! Continue seguindo a pista.",
	solved = "Objetivo concluído!",
	need_partner = "Chame um amigo para apertar este mesmo botão!",
	wrong_sequence = "Errado! A sequência voltou ao começo e o barulho chamou o Tung Tung.",
	puzzle_alarm = "Errado! O barulho chamou o Tung Tung. O que já acertou continua valendo.",
	plank_knock = "Toc, toc... Escute o som. Aperte E de novo para levantar a tábua.",
	plank_wrong = "Craaac! Tábua errada. A casa ouviu.",
	stool_placed = "Banquinho nas marcas do chão. Falta mais um em cima.",
	stool_stack = "A pilha alcança a viga! Pegue a chave.",
	stool_ready = "Esse banquinho já está na pilha.",
	stool_fled = "O banquinho de boné fugiu da luz e a pilha caiu!",
	cida_light = "A cadeira recua da sua luz. Apague a lanterna (F) e chegue devagar.",
	fuse_need = "Traga um fusível. Cada um carrega só um por vez.",
	fuse_in = "Encaixou! A lâmpada acendeu sobre o desenho.",
	fuse_done = "Esse encaixe já tem fusível.",
	fuse_wrong = "Faísca! Encaixe errado: o fusível voltou para a sua mão e o barulho chamou o Tung.",
	hands_full = "Mãos ocupadas: leve o fusível ao quadro de luz primeiro.",
	portrait_down = "Esse retrato já caiu.",
	portrait_wrong = "O retrato despencou com estrondo! A casa ouviu.",
	crank_turn = "A corda corre pela parede... lá em cima, o relógio fez tic.",
	crank_heavy = "Toc! A manivela deu um estalo grave.",
	clock_overshoot = "Passou da hora! O relógio de cima badalou.",
	gear_turn = "Clac! A engrenagem girou.",
	gear_fit = "Um trecho do risco na parede brilhou.",
	gear_chime = "O relógio badalou! Alguém lá embaixo ouviu.",
	panel_note = "Uma nota baixinha... a mesma da tecla com esse desenho.",
	box_wound = "A caixinha tocou a música inteira, alto. Lá em cima, as batidas começaram!",
	box_playing = "A caixinha ainda está tocando.",
	niche_empty = "Nada aqui. Fique parado e escute o sussurro.",
	overload_fit = "Encaixou na pausa! A máquina engasgou.",
	overload_oiled = "O óleo escorreu nas engrenagens: a máquina disparou! Agora encaixe o coração na pausa.",
	overload_done = "A máquina já está sobrecarregada.",
	overload_warning = 'A máquina puxou você! Dona Cida grita: "Na pausa!"',
	overload_wrong = "Fora da pausa! A máquina rugiu e o Tung ouviu.",
	radio_ok = "Uma voz atrás do chiado... o canal pegou.",
	radio_static = "Chiado alto! As lanternas da margem apagaram e algo bateu no cais.",
	repair_order = "Aperte o botão aceso: desligar, trocar o fusível e ligar.",
	story_order = "Complete as pistas e os itens necessários. H abre o guia.",
	rescuing = "Ajudando... fique pertinho do seu amigo!",
	rescued = "Amigo de pé de novo!",
	rescue_cancelled = "Ajuda interrompida. Chegue perto e tente de novo.",
	too_far = "Chegue mais perto e mire no objeto.",
	vote_recorded = "Voto registrado! Esperando o time.",
	not_active = "Espere um amigo te ajudar ou o próximo capítulo.",
	party_full = "O time está cheio. Espere uma vaga.",
	restarting = "Nova aventura!",
	wait = "Só um instante...",
	occupied = "Já tem alguém escondido aí!",
	hide_enter = "Escondido! E para sair · Espaço para espiar · Z para prender o ar",
	hide_exit = "Você saiu do esconderijo.",
	not_available = "Isso não dá para fazer agora.",
	not_playing = "Espere o próximo capítulo.",
	door_opened = "Passagem aberta!",
	spawn_failed = "Você entra no próximo capítulo.",
	second_chance = "Segunda chance: você levantou!",
	crawl_start = "O Tung Tung te derrubou! Rasteje para longe dele.",
	crawl_up = "Você levantou. Na próxima pancada ele te pega.",
	continue_used = "O time volta para o começo deste capítulo.",
	checkpoint_restored = "Tentando de novo deste capítulo!",
	supply_full = "Já está cheio. Seu item continua na mochila.",
	need_flashlight = "Recolha a lanterna antes de usar uma pilha.",
	search_empty = "Vazio... procure nos outros móveis do cômodo.",
	locker_cursed = "Tinha alguma coisa lá dentro! Olhe a fresta antes de entrar num armário.",
	search_passed = "Ele não te ouviu... e foi embora. Por enquanto.",
	runaway = "O móvel criou perninhas e fugiu! Encurrale ele ou espere ele cansar.",
}

function Controller.Start()
	if GameState.wait():GetAttribute("CampaignActive") ~= true then
		return
	end
	local state = ReplicatedStorage:WaitForChild("CampaignState", 15)
	assert(state, "[CampaignUI] missing campaign state")
	local ui = Hud.build(player:WaitForChild("PlayerGui"))
	local noir = Noir.build(player:WaitForChild("PlayerGui"), UserInputService.TouchEnabled)
	ui.feedback.FontFace = Noir.SansLight
	local helpOpen, teamHeld = false, false
	local noteOpen, bagOpen, selected = false, false, "flashlight"
	-- Evita abrir e fechar no mesmo toque (tecla repetida ou clique duplo).
	local toggledAt = 0
	local function debounced(): boolean
		local now = os.clock()
		if now - toggledAt < 0.2 then
			return true
		end
		toggledAt = now
		return false
	end
	local function openNote(value: boolean)
		if debounced() then
			return
		end
		noteOpen, bagOpen = value, false
		AudioController.play("Pickup", 0.35, 0.8, true)
	end
	local function openBag(value: boolean)
		if debounced() then
			return
		end
		bagOpen, noteOpen = value, false
		AudioController.play("Pickup", 0.35, 0.65, true)
	end
	noir.objectiveButton.Activated:Connect(function()
		openNote(not noteOpen)
	end)
	noir.bagButton.Activated:Connect(function()
		openBag(not bagOpen)
	end)
	for _, slot in noir.slots do
		slot.button.Activated:Connect(function()
			if slot.item ~= "empty" then
				selected = slot.item
			end
		end)
	end
	local function useSelected()
		if selected == "flashlight" then
			Flashlight.set(not Flashlight.isWanted())
		elseif selected == "battery" or selected == "oxygen" or selected == "decoy" then
			require("./InteractionController").useSupply(selected)
		else
			return
		end
		bagOpen = false
	end
	noir.useButton.Activated:Connect(useSelected)
	guideToggle = function()
		helpOpen = not helpOpen
	end
	local actions = game:GetService("ContextActionService")
	-- Mochila aberta: E equipa/usa e ← → trocam o item (prioridade alta: não abre porta nem pega item atrás).
	local bagKeysBound = false
	local function bindBagKeys(value: boolean)
		if value == bagKeysBound then
			return
		end
		bagKeysBound = value
		if not value then
			actions:UnbindAction("NoirBagKeys")
			return
		end
		actions:BindActionAtPriority(
			"NoirBagKeys",
			function(_, inputState, input)
				if inputState ~= Enum.UserInputState.Begin then
					return Enum.ContextActionResult.Sink
				end
				if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonA then
					useSelected()
					return Enum.ContextActionResult.Sink
				end
				local list = {}
				for _, slot in noir.slots do
					if slot.button.Visible then
						table.insert(list, slot.item)
					end
				end
				local at = table.find(list, selected) or 1
				local step = if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.DPadLeft
					then -1
					else 1
				if #list > 0 then
					selected = list[(at - 1 + step) % #list + 1]
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value + 10,
			Enum.KeyCode.E,
			Enum.KeyCode.ButtonA,
			Enum.KeyCode.Left,
			Enum.KeyCode.Right,
			Enum.KeyCode.DPadLeft,
			Enum.KeyCode.DPadRight
		)
	end
	actions:BindAction("HouseGuideTouch", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			helpOpen = not helpOpen
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonSelect)
	ui.close.Activated:Connect(function()
		helpOpen, teamHeld = false, false
	end)
	local tasks: { Guide.Activity } = {}
	local roster: { any } = {}
	local function decodeTasks()
		tasks = HttpService:JSONDecode((state:GetAttribute("Tasks") or "[]") :: string)
	end
	local function decodeRoster()
		roster = HttpService:JSONDecode((state:GetAttribute("Roster") or "[]") :: string)
	end
	state:GetAttributeChangedSignal("Tasks"):Connect(decodeTasks)
	state:GetAttributeChangedSignal("Roster"):Connect(decodeRoster)
	decodeTasks()
	decodeRoster()
	local feedbackUntil = 0
	local feedbackAt = 0
	player:GetAttributeChangedSignal("CampaignFeedbackSerial"):Connect(function()
		local key = tostring(player:GetAttribute("CampaignFeedback"))
		-- Entrar/sair do armário: a dica do rodapé (NoirHud) já explica; nada no meio da tela.
		-- Porta trocada: quem fala é a Dona Cida (DoorSwapController), sem aviso de "não dá" por cima.
		if key == "hide_enter" or key == "hide_exit" or key == "door_swapped" then
			return
		end
		ui.feedback.Text = messages[key] or "Isso não dá para fazer agora."
		feedbackUntil = os.clock() + 4
		feedbackAt = os.clock()
		-- Um texto por vez: o aviso novo tira a legenda velha do rodapé.
		GameUi.hideCaption()
		Juice.pop(ui.feedback, 0.25)
	end)

	-- Moedas e nível: animam quando sobem.
	local shownCoins = (tonumber(player:GetAttribute("Fichas")) or 0) :: number
	local function refreshCoins()
		local value = (tonumber(player:GetAttribute("Fichas")) or 0) :: number
		if value > shownCoins then
			local gain = value - shownCoins
			Juice.count(shownCoins, value, 0.6, function(current)
				ui.coins.Text = `{current}`
			end)
			local _ = gain
		else
			ui.coins.Text = `{value}`
		end
		shownCoins = value
	end
	local shownLevel = (tonumber(player:GetAttribute("Level")) or 1) :: number
	local function refreshLevel()
		local value = (tonumber(player:GetAttribute("Level")) or 1) :: number
		ui.level.Text = `NÍVEL {value}`
		-- Sem confete nem número subindo na tela: o nível aparece no fim do capítulo, na anotação.
		local _ = Theme
		shownLevel = value
	end
	-- Moedas pegas no capítulo atual (para o resumo da comemoração).
	local chapterCoins = 0
	player:GetAttributeChangedSignal("CoinPickupSerial"):Connect(function()
		chapterCoins += 1
	end)
	-- Fim de capítulo: a anotação abre e a página vira com o resumo (sem confete nem letreiro gigante).
	local pageOverride: { string }? = nil
	local function celebrate(big: boolean, title: string, detail: string)
		noteOpen, bagOpen = true, false
		Noir.flip(noir, function()
			pageOverride = { title, detail }
		end)
		task.delay(if big then 6 else 4, function()
			pageOverride = nil
		end)
		AudioController.play("StingerWin", if big then 0.7 else 0.45, 1, true)
	end
	-- Legenda das batidas do Tung Tung (vem do CreatureVisualController quando ele está perto).
	player:GetAttributeChangedSignal("TungKnockSerial"):Connect(function()
		if ui.gui.Enabled then
			-- Legenda discreta no rodapé (como os outros avisos), não um letreiro no meio da tela.
			GameUi.caption("Tum... tum... tum...", 1.6)
		end
	end)
	player:GetAttributeChangedSignal("Fichas"):Connect(refreshCoins)
	player:GetAttributeChangedSignal("Level"):Connect(refreshLevel)
	refreshCoins()
	refreshLevel()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not ui.gui.Enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.H then
			helpOpen = not helpOpen
		elseif input.KeyCode == Enum.KeyCode.J then
			openNote(not noteOpen)
		elseif input.KeyCode == Enum.KeyCode.Tab then
			-- TAB agora é a mochila; o time aparece na anotação do objetivo (J).
			openBag(not bagOpen)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		teamHeld = false
	end)
	local function setSlot(slot: FieldSlot, count: number, text: string)
		slot.count.Text = text
		slot.icon.TextTransparency = if count > 0 then 0 else 0.6
	end
	local elapsed, stageAt, lastStage, lastObjective, lastSolved = 0, 0, "", "", -1
	local noirObjective = ""
	local lastPhase = ""
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		local phase = tostring(state:GetAttribute("Phase"))
		local stage = (state:GetAttribute("Stage") or 0) :: number
		if phase ~= lastPhase then
			-- Só comemora o fim de um capítulo de verdade (não ao reiniciar depois de uma captura).
			local fromPlay = lastPhase == "Playing" or lastPhase == "Extracting"
			if phase == "Intermission" and fromPlay and stage >= 1 then
				celebrate(false, `CAPÍTULO {stage} CONCLUÍDO!`, `{chapterCoins} moedas neste capítulo`)
			elseif phase == "Won" then
				celebrate(true, "VOCÊS ESCAPARAM!", `{chapterCoins} moedas no último capítulo`)
			end
			lastPhase = phase
		end
		local story = state:GetAttribute("GameMode") == "Story"
		local status = player:GetAttribute("CampaignStatus") :: string?
		local cinema = player:GetAttribute("CinematicActive") == true
		ui.gui.Enabled = phase ~= "Lobby" and not cinema and state:GetAttribute("Building") ~= true
		local legacy = player.PlayerGui:FindFirstChild("GameUi")
		if legacy and legacy:IsA("ScreenGui") then
			legacy.Enabled = false
		end
		noir.gui.Enabled = ui.gui.Enabled
		if not ui.gui.Enabled then
			teamHeld = false
			noteOpen, bagOpen = false, false
			bindBagKeys(false)
			noir.modal.Visible, noir.modal.Modal = false, false
			player:SetAttribute("FieldGuideOpen", false)
			return
		end
		local key = `{state:GetAttribute("Seed")}:{stage}:{story}`
		if key ~= lastStage then
			lastStage, stageAt, helpOpen = key, os.clock(), false
			chapterCoins = 0
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local factor = ui.resize(camera.ViewportSize)
		local touch = UserInputService.TouchEnabled
		local activity, index = Guide.current(tasks)
		local now = workspace:GetServerTimeNow()
		local briefingRemaining =
			math.max(0, math.ceil(((state:GetAttribute("StorySceneEndsAt") or 0) :: number) - now))
		local title, detail = Guide.objective(if briefingRemaining > 0 then "Briefing" else phase, status, activity)
		local active = status == "Active" and phase == "Playing" and briefingRemaining == 0
		local activePlayers = 0
		local downed: any = nil
		for _, member in roster do
			if member.status == "Active" then
				activePlayers += 1
			end
			if member.status == "Downed" then
				downed = member
			end
		end
		local roleId = player:GetAttribute("CampaignRole")
		local roleTitle, roleDescription = "TIME", ""
		for _, role in Catalog.Roles do
			if role.id == roleId then
				roleTitle, roleDescription = role.title, role.description
			end
		end
		-- O papel completo fica no guia; o cabeçalho divide espaço com o destino da floresta.
		ui.chapter.Text = `{if story then "CAPÍTULO" else "NOITE"} {stage}/{#HouseCatalog.Chapters}`
		ui.title.Text = title
		if title ~= lastObjective then
			lastObjective = title
			Juice.pop(ui.order, 0.08)
		end
		ui.destination.Text = if active and activity then `{Guide.roomName(activity.room)}` else "CASA DO TUNG TUNG"
		ui.action.Text = if active and activity then Guide.instruction(activity, now, activePlayers) else detail
		if touch then
			ui.action.Text = ui.action.Text
				:gsub("aperte E", "toque AÇÃO")
				:gsub("Aperte E", "Toque AÇÃO")
				:gsub("H abre o guia", "GUIA mostra as pistas")
		end
		if phase == "Won" then
			local remaining = math.max(0, math.ceil((tonumber(state:GetAttribute("LobbyReturnAt")) or now) - now))
			ui.action.Text = `Voltando ao lobby com a equipe em {remaining}s`
		end
		local solved = (state:GetAttribute("Solved") or 0) :: number
		local total = math.max(1, (state:GetAttribute("Total") or 1) :: number)
		ui.progressFill.Size = UDim2.fromScale(math.clamp(solved / total, 0, 1), 1)
		ui.progress.Text = `{solved}/{total}`
		if solved > lastSolved and lastSolved >= 0 then
			Juice.pop(ui.progress, 0.6)
		end
		lastSolved = solved
		if phase == "Intermission" then
			local remaining = math.max(
				0,
				math.ceil(((state:GetAttribute("NextStageAt") or 0) :: number) - workspace:GetServerTimeNow())
			)
			ui.action.Text = `Próximo capítulo em {remaining}s`
		end
		if briefingRemaining > 0 then
			ui.action.Text = `Começa em {briefingRemaining}s...`
		end
		if status == "Downed" and phase ~= "Lost" then
			for _, member in roster do
				if member.id == player.UserId then
					ui.action.Text = `Espere um amigo te levantar: {math.max(0, math.ceil(member.downedUntil - now))}s`
				end
			end
		end
		ui.dossier.Visible = helpOpen or teamHeld
		player:SetAttribute("FieldGuideOpen", ui.dossier.Visible)
		ui.order.Visible = not ui.dossier.Visible
		ui.tipPanel.Visible = not touch and active and not ui.dossier.Visible and camera.ViewportSize.Y / factor >= 560
		local tipAge = os.clock() - stageAt
		ui.tip.Text = if tipAge < 16
			then Guide.StageTips[math.clamp(stage, 1, #Guide.StageTips)]
			else Guide.SurvivalTips[(math.floor((tipAge - 16) / 18) % #Guide.SurvivalTips) + 1]
		if downed and active then
			ui.tip.Text = `{downed.name} caiu! Chegue perto, mire e aperte E para ajudar.`
		end

		-- Barras de fôlego, lanterna e ar.
		local stamina, maximum = Character.getStamina()
		local battery = player:GetAttribute("Battery")
		local light = math.clamp(if type(battery) == "number" then battery else 0, 0, 1)
		local oxygen = math.clamp((tonumber(player:GetAttribute("Oxygen")) or 100) :: number, 0, 100)
		local breath = math.clamp(stamina / math.max(maximum, 1e-3), 0, 1)
		ui.setBar(ui.bars.stamina, breath, `FÔLEGO {math.floor(breath * 100)}%`, breath < 0.2)
		ui.setBar(ui.bars.battery, light, `LANTERNA {math.floor(light * 100)}%`, light < 0.15)
		ui.setBar(ui.bars.oxygen, oxygen / 100, `AR {math.floor(oxygen)}%`, oxygen < 25)
		ui.equipment.Text = if player:GetAttribute("Stance") == "Crouch" then "AGACHADO (silencioso)" else ""
		if phase == "Extracting" then
			ui.action.Text = `{if stage >= 6 then "CORRA PARA O RESGATE!" else "FUJA PARA O PORTÃO!"} {math.max(
				0,
				math.ceil(((state:GetAttribute("EscapeEndsAt") or 0) :: number) - now)
			)}s`
		end
		if oxygen < 15 then
			ui.action.Text = "O AR ESTÁ ACABANDO! Solte a respiração!"
		end

		-- Inventário do time e itens pessoais.
		local inventory = HttpService:JSONDecode((state:GetAttribute("Inventory") or "{}") :: string)
		local stock = HttpService:JSONDecode((player:GetAttribute("HouseSupplies") or "{}") :: string)
		local keys = (inventory.key_living or 0) + (inventory.key_kitchen or 0) + (inventory.key_dining or 0)
		local fuses = (inventory.fuse_1 or 0) + (inventory.fuse_2 or 0) + (inventory.fuse_3 or 0)
		setSlot(ui.slots.keys, keys, `{keys}/3`)
		setSlot(ui.slots.fuses, fuses, `{fuses}/3`)
		setSlot(ui.slots.artifact, inventory.artifact or 0, `{inventory.artifact or 0}`)
		setSlot(ui.slots.battery, stock.battery or 0, `{stock.battery or 0}`)
		setSlot(ui.slots.oxygen, stock.oxygen or 0, `{stock.oxygen or 0}`)
		setSlot(ui.slots.decoy, stock.decoy or 0, `{stock.decoy or 0}`)
		ui.inventory.Text =
			`CHAVES {keys}/3 · FUSÍVEIS {fuses}/3 · ARTEFATO {inventory.artifact or 0}\n1 PILHA {stock.battery or 0} · 2 AR {stock.oxygen or 0} · 3 ISCA {stock.decoy or 0}`
		ui.footer.Visible = status == "Active" and not ui.dossier.Visible
		ui.bars.battery.frame.Visible = player:GetAttribute("HasFlashlight") == true
		ui.tray.Visible = not touch and status == "Active" and not ui.dossier.Visible
		ui.controls.Visible = not touch and active and not ui.dossier.Visible and camera.ViewportSize.X / factor >= 900

		if ui.dossier.Visible then
			local lines = {
				`SEU PAPEL: {roleTitle}\n{roleDescription}`,
				if story
					then "MISSÃO\nFaçam os objetivos na ordem abaixo. O marcado é o próximo. São oito capítulos: fujam da casa, atravessem a floresta e alcancem o resgate!"
					else "DESAFIO\nDividam as tarefas disponíveis entre colegas. Coletem em qualquer ordem; mecanismos exigem as pistas e os itens. A seta é uma sugestão.",
				"OBJETIVOS",
			}
			for n, item in tasks do
				table.insert(
					lines,
					`{if item.solved
						then "[FEITO]"
						elseif item.available == false then "[TRANCADO]"
						elseif n == index then "[AGORA]"
						else "-"} {n}. {Guide.roomName(item.room)}\n{item.title or Catalog.KindNames[item.kind]}{if item.solved
						then ""
						elseif item.available == false then "\nComplete as pistas e os itens anteriores."
						else `\n{Guide.instruction(item, now, activePlayers)}`}`
				)
			end
			table.insert(lines, "TIME")
			local statusTitles: { [string]: string } = {
				Active = "na ativa",
				Downed = "precisa de ajuda",
				Waiting = "esperando",
				Escaped = "a salvo",
			}
			for _, member in roster do
				local remaining = if member.status == "Downed"
					then ` ({math.max(0, math.ceil(member.downedUntil - workspace:GetServerTimeNow()))}s)`
					else ""
				table.insert(lines, `{member.name}: {statusTitles[member.status] or member.status}{remaining}`)
			end
			if roleId == "scout" and active then
				local world = workspace:FindFirstChild("CursedHouse")
				local stations = world and world:FindFirstChild("CampaignActivities")
				local character = player.Character
				if stations and character then
					for _, model in stations:GetChildren() do
						local point = model:FindFirstChild("Station")
						if
							point
							and point:IsA("BasePart")
							and (point.Position - character:GetPivot().Position).Magnitude
								<= Config.Campaign.ScoutRange
						then
							table.insert(lines, `RADAR: {model:GetAttribute("RoomLabel") or "objetivo"} por perto!`)
						end
					end
				end
			end
			table.insert(lines, "COMO SOBREVIVER\n" .. table.concat(Guide.SurvivalTips, "\n\n"))
			table.insert(
				lines,
				"CONTROLES\nWASD andar · E usar · F lanterna\nShift correr · C agachar · Z/LB prender o ar\n1 pilha · 2 ar extra · 3 isca\nH guia · segure TAB para ver o time\nSetas: trocar de amigo quando estiver assistindo"
			)
			ui.pages.Text = table.concat(lines, "\n\n")
			if touch then
				ui.pages.Text = ui.pages.Text:gsub("aperte E", "toque AÇÃO"):gsub("Aperte E", "Toque AÇÃO")
				local controlsAt = ui.pages.Text:find("CONTROLES", 1, true)
				if controlsAt then
					ui.pages.Text = ui.pages.Text:sub(1, controlsAt - 1)
						.. "CONTROLES DE TOQUE\nArraste no lado livre da tela para olhar. Use o direcional para andar e o botão do Roblox para pular.\nAÇÃO usa o objeto na mira, ajuda colegas e sai do armário.\nCORRER liga/desliga a corrida; AGACHAR reduz o barulho.\nNo armário, segure O AR e solte para respirar.\nMOCHILA abre pilhas, ar extra e iscas. GUIA mostra objetivos e time; AJUSTES controla efeitos e áudio."
				end
			end
			local bounds = TextService:GetTextSize(
				ui.pages.Text,
				ui.pages.TextSize,
				Enum.Font.GothamMedium,
				Vector2.new(math.max(120, ui.pages.AbsoluteSize.X), 100000)
			)
			ui.pages.Size = UDim2.new(1, -16, 0, bounds.Y + 24)
		end
		-- Única orientação do jogo: o ponteiro em cima da lanterna (nada de seta na tela).
		local guideTarget: Vector3? = nil
		if active and (activity ~= nil or phase == "Extracting") then
			local world = workspace:FindFirstChild("CursedHouse")
			local stations = world and world:FindFirstChild("CampaignActivities")
			local model = stations and activity and stations:FindFirstChild(activity.id)
			local station = model and model:FindFirstChild("Station")
			guideTarget = if phase == "Extracting"
				then Vector3.new(0, 4, if stage >= 6 then 870 else 106)
				elseif station and station:IsA("BasePart") then station.Position + Vector3.new(0, 4, 0)
				else nil
		end
		Flashlight.setGuide(guideTarget)
		-- Luz guia (GuidingLightController) lê o mesmo alvo.
		if player:GetAttribute("GuideTarget") ~= guideTarget then
			player:SetAttribute("GuideTarget", guideTarget)
			player:SetAttribute("GuideTaskId", if activity then activity.id else nil)
		end
		-- HUD de terror (NoirHud): a antiga só guarda o guia (H) e os avisos curtos.
		ui.order.Visible = false
		ui.tray.Visible = false
		ui.waypoint.Visible = false
		ui.wallet.Visible = false
		ui.tipPanel.Visible = false
		ui.controls.Visible = false
		ui.footer.Visible = false
		ui.equipment.Visible = false
		local levelBadge = ui.level.Parent
		if levelBadge and levelBadge:IsA("GuiObject") then
			levelBadge.Visible = false
		end
		local panelOpen = (noteOpen or bagOpen) and not ui.dossier.Visible
		noir.note.Visible = noteOpen and not ui.dossier.Visible
		noir.bag.Visible = bagOpen and not ui.dossier.Visible
		bindBagKeys(noir.bag.Visible)
		noir.modal.Visible, noir.modal.Modal = panelOpen, panelOpen
		local quiet = ui.dossier.Visible or status ~= "Active"
		local cornerBox = noir.cornerTitle.Parent
		if cornerBox and cornerBox:IsA("GuiObject") then
			cornerBox.Visible = not quiet and not noteOpen
		end
		noir.cornerChapter.Text = Noir.spaced(ui.chapter.Text)
		noir.cornerTitle.Text = title
		-- Mochila aberta ocupa o rodapé: botões e barras somem (como na referência).
		local bagShown = noir.bag.Visible
		local buttonsBox = noir.objectiveButton.Parent
		if buttonsBox and buttonsBox:IsA("GuiObject") then
			buttonsBox.Visible = not bagShown
		end
		noir.stamina.Visible = status == "Active" and not ui.dossier.Visible and not bagShown
		local hiddenIn = player:GetAttribute("Hidden")
		local inHide = type(hiddenIn) == "string" and hiddenIn ~= ""
		noir.hint.Visible = inHide and not panelOpen
		-- Porta emperrada sendo forçada perto de mim: barra fina com o progresso (MansionProgress da folha).
		local forcing: number? = nil
		local doors = workspace:FindFirstChild(Tags.WorldFolder)
		doors = doors and doors:FindFirstChild("Doors")
		local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if doors and me and me:IsA("BasePart") then
			for _, panel in doors:GetChildren() do
				local progress = panel:GetAttribute("MansionProgress")
				if
					panel:IsA("BasePart")
					and type(progress) == "number"
					and progress > 0
					and progress < 1
					and (panel.Position - me.Position).Magnitude < 10
				then
					forcing = progress
					break
				end
			end
		end
		noir.work.Visible = forcing ~= nil and not panelOpen
		noir.workFill.Size = UDim2.fromScale(forcing or 0, 1)
		-- Revista do armário: o Espaço vira a batida do minijogo; a dica de espiar/sair sai de cena.
		noir.hint.Text = if player:GetAttribute("BreathTestAt") ~= nil
			then ""
			else (if UserInputService.TouchEnabled then Text.HiddenHintTouch else Text.HiddenHint)
				.. (if player:GetAttribute("HoldBreath") == true then "\n" .. Text.HoldingBreath else "")
		noir.staminaFill.Size = UDim2.fromScale(breath, 1)
		noir.air.Visible = status == "Active" and oxygen < 99.5 and not bagShown
		noir.airFill.Size = UDim2.fromScale(oxygen / 100, 1)
		noir.airFill.BackgroundColor3 = if oxygen < 25 then Noir.Blood else Noir.Paper
		if title ~= noirObjective then
			if noirObjective ~= "" then
				Noir.pulse(noir.objectiveButton)
				if noteOpen then
					Noir.flip(noir, function() end)
				end
			end
			noirObjective = title
		end
		if pageOverride then
			noir.noteChapter.Text = ui.chapter.Text
			noir.noteTitle.Text = pageOverride[1]
			noir.noteBody.Text = pageOverride[2]
			noir.noteList.Text = ""
			noir.noteProgress.Text = `NÍVEL {shownLevel}`
		else
			noir.noteChapter.Text = ui.chapter.Text .. "  ·  " .. ui.destination.Text
			noir.noteTitle.Text = title
			noir.noteBody.Text = ui.action.Text
			-- Um objetivo por vez: as próximas tarefas não aparecem (só o time, se houver).
			local list = {}
			if #roster > 1 then
				for _, member in roster do
					table.insert(
						list,
						`{member.name}: {if member.status == "Active"
							then "na ativa"
							elseif member.status == "Downed" then "precisa de ajuda"
							else string.lower(tostring(member.status))}`
					)
				end
			end
			noir.noteList.Text = table.concat(list, "\n")
			noir.noteProgress.Text = `{solved} / {total}`
		end
		if bagOpen then
			local counts: { [string]: number } = {
				flashlight = if player:GetAttribute("HasFlashlight") == true then math.floor(light * 100) else 0,
				keys = keys,
				fuses = fuses,
				artifact = inventory.artifact or 0,
				battery = stock.battery or 0,
				oxygen = stock.oxygen or 0,
				decoy = stock.decoy or 0,
				gasoline = if (inventory.gas_ignite or 0) > 0 then 0 else inventory.gasoline or 0,
				lighter = if (inventory.gas_ignite or 0) > 0 then 0 else inventory.lighter or 0,
				empty = 0,
			}
			-- Só aparece o que o jogador tem; o escolhido mostra nome, valor e (lanterna) a barra da bateria.
			local function owned(item: string): boolean
				return if item == "flashlight"
					then player:GetAttribute("HasFlashlight") == true
					else (counts[item] or 0) > 0
			end
			if not owned(selected) then
				for _, slot in noir.slots do
					if owned(slot.item) then
						selected = slot.item
						break
					end
				end
			end
			for _, slot in noir.slots do
				local count = counts[slot.item] or 0
				local chosen = slot.item == selected
				local value = if slot.item == "flashlight"
					then `{count}%`
					elseif slot.item == "keys" or slot.item == "fuses" then `{count}/3`
					else `{count}`
				slot.button.Visible = owned(slot.item)
				slot.count.Text = if chosen or slot.item == "flashlight" then "" else value
				slot.name.Visible = chosen
				slot.name.Text = `{Noir.spaced(
					string.upper((BAG_TEXT[slot.item] or BAG_TEXT.empty)[1]),
					"\u{2009}\u{2009}"
				)}\n{value}`
				slot.track.Visible = chosen and slot.item == "flashlight"
				slot.fill.Size = UDim2.fromScale(math.clamp(light, 0, 1), 1)
				local view = slot.icon:FindFirstChild("View")
				if view and view:IsA("ViewportFrame") then
					view.ImageTransparency = if chosen then 0 else 0.45
				end
			end
			local has = owned(selected)
			local info = if has then BAG_TEXT[selected] or BAG_TEXT.empty else BAG_TEXT.empty
			noir.detailName.Text = info[1]
			noir.detailText.Text = if has
				then string.format(info[2], counts[selected] or 0)
				else "A mochila está vazia. O que você pegar na casa aparece aqui."
			local usable = has
				and (selected == "flashlight" or selected == "battery" or selected == "oxygen" or selected == "decoy")
			noir.useButton.Visible = usable
			noir.useButton.Text = Noir.useLabel(
				if selected == "flashlight" then (if Flashlight.isWanted() then "DESLIGAR" else "EQUIPAR") else "USAR",
				UserInputService.TouchEnabled
			)
		end
		if os.clock() > feedbackUntil or GameUi.captionShownAt() > feedbackAt then
			ui.feedback.Text = ""
		end
		local storyUi = player.PlayerGui:FindFirstChild("StoryUi")
		local recording = storyUi and storyUi:FindFirstChild("RecoveredRecording")
		ui.feedback.Visible = not ui.dossier.Visible
			and not (
				storyUi
				and storyUi:IsA("ScreenGui")
				and storyUi.Enabled
				and recording
				and recording:IsA("GuiObject")
				and recording.Visible
			)
	end)
	if RunService:IsStudio() then
		local ok, args = pcall(function()
			return game:GetService("StudioTestService"):GetTestArgs()
		end)
		if ok and type(args) == "table" and args.campaignQA then
			local function qaRequest()
				local command = player:GetAttribute("CampaignQARequest")
				if type(command) ~= "string" then
					return
				end
				local request = HttpService:JSONDecode(command)
				task.spawn(function()
					local result: any
					if request.restart then
						result = Remotes.clientFunction("RequestRestart", 10):InvokeServer()
					elseif request.select then
						local chosen = require("./InteractionController").testInteract(request.id)
						result = {
							ok = true,
							data = {
								accepted = chosen and player:GetAttribute("CampaignAccepted") == true,
								message = if chosen
									then player:GetAttribute("CampaignFeedback")
									else "client_target_unavailable",
							},
						}
					elseif request.breath ~= nil then
						Remotes.clientEvent("SetHoldBreath", 10):FireServer(request.breath)
						result = { ok = true }
					else
						result = Remotes.clientFunction("Interact", 10):InvokeServer(request.id)
					end
					player:SetAttribute(
						"CampaignQAResponse",
						HttpService:JSONEncode({ serial = request.serial, result = result })
					)
				end)
			end
			player:GetAttributeChangedSignal("CampaignQARequest"):Connect(qaRequest)
			qaRequest()
		end
	end
end

return Controller
