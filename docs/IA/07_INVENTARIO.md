# Inventário das fontes para a IA

Projeto: **tung-tung-sahur**. Base que alterou src/: **d975d86f6ce5d6260d60eca745825a6e2973a6cd**.

225 arquivos Luau. src/ com alterações locais no momento da coleta: **False**.

Índice lexical gerado por [generate_inventory.py](../../tools/handoff/generate_inventory.py). Declarações, requires literais, listeners, callbacks e acessos a atributos têm linhas de origem. Não é análise AST: não resolve aliases dinâmicos, propagação de chamadas, funções anônimas sem nome, assinaturas multilinha completas nem qual ramo será executado. Uma ocorrência não prova execução. Leia o corpo da função e confirme no runtime. Hashes permitem detectar documentação desatualizada.

Não carregar tudo no contexto: buscar o símbolo/tarefa, ler só o bloco relevante e abrir a fonte. [CODE_MAP.json](CODE_MAP.json) oferece o mesmo índice estruturado para consultas por IA.

## src/ReplicatedStorage/Client/Controllers/ArtController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/ArtController.luau) · 315 linhas · SHA-256: 1e1175b0bf8b3dd7c34614696f8444370bfdb6035df7cb5233243b012fc7d6b6

### Funções nomeadas / callbacks atribuídos

~~~text
L26: local function makeImages()
L51: local function surface(part: Instance)
L94: local function removeSurface(part: Instance)
L104: local function screen(part: Instance)
L144: local function mote(part: Instance)
L168: local function setupSparks()
L200: local function step()
L244: function Controller.debugState(): { [string]: any }
L261: function Controller.Start()
~~~

### Dependências literais

- L6: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L7: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L8: @game/ReplicatedStorage/Shared/Game/SurfacePatterns → [fonte](../../src/ReplicatedStorage/Shared/Game/SurfacePatterns.luau)
- L9: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L10: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L11: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)

### Listeners / registros / callbacks

~~~text
L188: box:GetAttributeChangedSignal("Spark"):Connect(function()
L280: CollectionService:GetInstanceAddedSignal("ArtSurface"):Connect(surface)
L281: CollectionService:GetInstanceAddedSignal("ArtScreen"):Connect(screen)
L282: CollectionService:GetInstanceAddedSignal("ArtDust"):Connect(mote)
L283: CollectionService:GetInstanceRemovedSignal("ArtSurface"):Connect(removeSurface)
L284: CollectionService:GetInstanceRemovedSignal("ArtScreen"):Connect(function(part: Instance)
L292: CollectionService:GetInstanceRemovedSignal("ArtDust"):Connect(function(part: Instance)
L302: RunService.RenderStepped:Connect(function(dt)
~~~

### Estado observado / publicado

~~~text
L55: local kind = part:GetAttribute("SurfaceStyle")
L188: box:GetAttributeChangedSignal("Spark"):Connect(function()
L189: if box:GetAttribute("Spark") and Settings.get("flashes") and snapshot and snapshot.phase == "Playing" then
L211: local kind = part:GetAttribute("Indicator")
L213: local pivot = part:GetAttribute("Pivot")
L262: GameState.observe(function(state)
~~~

## src/ReplicatedStorage/Client/Controllers/AudioController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau) · 529 linhas · SHA-256: 7e410c1d58cd7d6d4da5f7b396cca94c78ae0fc8dc375ebf83a39bc85857e787

### Funções nomeadas / callbacks atribuídos

~~~text
L69: local function getGroup(): SoundGroup
L74: local function applyClip(sound: Sound, clipName: string)
L86: local function make(name: string, clipName: string, parent: Instance, looped: boolean, ui: boolean?): Sound
L96: local function creatureRoot(): BasePart?
L102: local function checkInside(position: Vector3): boolean
L114: local function zoneAt(position: Vector3): (string, string)
L140: local function setReverb(name: string)
L154: function AudioController.play(clipName: string, volumeScale: number?, speed: number?, ui: boolean?): Sound
L173: function AudioController.playAt(clipName: string, parent: Instance, volumeScale: number?, speed: number?): Sound
L195: function AudioController.playAtPosition(
L225: function AudioController.loopAt(clipName: string, parent: Instance): Sound
L234: function AudioController.configure(sound: Sound, clipName: string)
L239: function AudioController.isInside(): boolean
L244: function AudioController.zone(): string
L248: function AudioController.setMusicState(state: MusicState)
L252: function AudioController.musicState(): MusicState
L256: function AudioController.setFear(value: number)
L261: function AudioController.silence(duration: number)
L266: function AudioController.muffle(duration: number)
L270: function AudioController.debugState(): { [string]: any }
L287: function AudioController.Init()
L328: local function update()
L334: local function master()
L349: function AudioController.Start()
L350: local function spatial(instance: Instance)
L365: local function adopt(instance: Instance)
~~~

### Dependências literais

- L22: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L23: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L24: @game/ReplicatedStorage/Shared/Game/Audio → [fonte](../../src/ReplicatedStorage/Shared/Game/Audio.luau)
- L25: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L26: @game/ReplicatedStorage/Shared/Game/ThreatPresentation → [fonte](../../src/ReplicatedStorage/Shared/Game/ThreatPresentation.luau)
- L27: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L54: @game/ReplicatedStorage/Shared/Game/HousePreferences → [fonte](../../src/ReplicatedStorage/Shared/Game/HousePreferences.luau)

### Listeners / registros / callbacks

~~~text
L161: sound.Ended:Once(function()
L183: sound.Ended:Once(function()
L212: sound.Destroying:Once(function()
L331: player:GetAttributeChangedSignal("Mix_" .. category):Connect(update)
L338: player:GetAttributeChangedSignal("Mix_master"):Connect(master)
L358: workspace.DescendantAdded:Connect(spatial)
L376: world.DescendantAdded:Connect(adopt)
L416: RunService.RenderStepped:Connect(function(dt: number)
~~~

### Estado observado / publicado

~~~text
L133: return (part:GetAttribute("Room") :: string?) or part.Name,
L134: (part:GetAttribute("Reverb") :: string?) or "Room"
L329: channel.Volume = tonumber(player:GetAttribute("Mix_" .. category)) or 1
L331: player:GetAttributeChangedSignal("Mix_" .. category):Connect(update)
L335: g.Volume = tonumber(player:GetAttribute("Mix_master")) or 1
L338: player:GetAttributeChangedSignal("Mix_master"):Connect(master)
L392: GameState.observe(function(next: GameState.Snapshot)
L425: local forest = world ~= nil and world:GetAttribute("ForestActive") == true
L426: local forestDark = forest and world ~= nil and world:GetAttribute("ForestBlackout") == true
L445: local hidden = player:GetAttribute("Hidden")
L454: local inPlay = Presentation.playing(s.phase, player:GetAttribute("CampaignStatus") :: string?)
~~~

## src/ReplicatedStorage/Client/Controllers/BodyAudioController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/BodyAudioController.luau) · 249 linhas · SHA-256: 77ce281af245a24f299b0c193a196da9fee53557c72e1f24f4f2af0067aeb015

### Funções nomeadas / callbacks atribuídos

~~~text
L56: local function isHidden(): boolean
L61: local function inPuddle(position: Vector3): boolean
L77: local function surfaceAt(motion: CharacterController.Motion, root: BasePart): Surface
L95: local function step(motion: CharacterController.Motion, root: BasePart)
L117: local function breathe(motion: CharacterController.Motion, now: number)
L144: local function muteDefaults(character: Model)
L149: local function mute(child: Instance)
L169: function BodyAudioController.setFear(value: number)
L173: function BodyAudioController.lastSurface(): Surface
L177: function BodyAudioController.Start()
~~~

### Dependências literais

- L18: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L19: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L20: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L21: ./CharacterController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterController.luau)

### Listeners / registros / callbacks

~~~text
L152: child:GetPropertyChangedSignal("Volume"):Connect(function()
L162: root.ChildAdded:Connect(mute)
L184: player.CharacterAdded:Connect(muteDefaults)
L205: player:GetAttributeChangedSignal("HoldBreath"):Connect(function()
L216: player:GetAttributeChangedSignal("Gasps"):Connect(function()
L225: RunService.RenderStepped:Connect(function(dt: number)
~~~

### Estado observado / publicado

~~~text
L57: local hidden = player:GetAttribute("Hidden")
L83: local tagged = part:GetAttribute("Surface")
L128: tonumber(player:GetAttribute("BreathIntensity")) or 0,
L152: child:GetPropertyChangedSignal("Volume"):Connect(function()
L178: GameState.observe(function(snapshot)
L205: player:GetAttributeChangedSignal("HoldBreath"):Connect(function()
L206: local now = player:GetAttribute("HoldBreath") == true
L216: player:GetAttributeChangedSignal("Gasps"):Connect(function()
L217: local count = (player:GetAttribute("Gasps") :: number?) or 0
~~~

## src/ReplicatedStorage/Client/Controllers/CameraController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/CameraController.luau) · 510 linhas · SHA-256: 37ccbafae598e69afd3fc41ca5ad78967d4e38dec511a63b6860fd3a35fe23b6

### Funções nomeadas / callbacks atribuídos

~~~text
L76: local function humanoid(): Humanoid?
L81: local function rootPart(): BasePart?
L89: local function updatePointer()
L128: local function approach(current: number, target: number, rate: number, dt: number): number
L133: local function undo()
L141: local function positionOffset(dt: number, motion: CharacterController.Motion, root: BasePart): Vector3
L186: local function rotationOffset(dt: number, motion: CharacterController.Motion, now: number): CFrame
L217: local function fieldOfView(dt: number, motion: CharacterController.Motion): number
L231: local function updateHidden(camera: Camera)
L243: local function updateCapture(camera: Camera, now: number, dt: number)
L270: local function apply(dt: number)
L334: function CameraController.setCinema(frame: CFrame, fov: number, focus: Vector3?): boolean
L349: function CameraController.endCinema()
L355: function CameraController.setSpectator(target: Player?)
L369: function CameraController.addTrauma(amount: number)
L374: function CameraController.shake(amount: number, _duration: number?)
L379: function CameraController.punch(amount: number?)
L384: function CameraController.setFear(value: number)
L389: function CameraController.land(intensity: number)
L395: function CameraController.setHidden(eye: CFrame?)
L413: function CameraController.capture(target: () -> Vector3?)
L424: function CameraController.isCapturing(): boolean
L429: function CameraController.reset()
L467: function CameraController.debugState(): { [string]: any }
L480: function CameraController.Start()
L482: local function track(instance: Instance)
~~~

### Dependências literais

- L27: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L28: ./CharacterController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterController.luau)
- L29: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)

### Listeners / registros / callbacks

~~~text
L490: playerGui.DescendantAdded:Connect(track)
L491: playerGui.DescendantRemoving:Connect(function(instance: Instance)
L496: UserInputService.WindowFocused:Connect(function()
L499: UserInputService.WindowFocusReleased:Connect(function()
L505: RunService:BindToRenderStep("S9CameraUndo", Enum.RenderPriority.Camera.Value - 1, undo)
L506: RunService:BindToRenderStep("S9CameraApply", Enum.RenderPriority.Camera.Value + 1, apply)
L507: RunService:BindToRenderStep("S9CameraPointer", Enum.RenderPriority.Last.Value + 1, updatePointer)
~~~

### Estado observado / publicado

~~~text
L97: or player:GetAttribute("ModeMenuOpen") == true
L98: or (campaign ~= nil and campaign:GetAttribute("Phase") == "Lost")
~~~

## src/ReplicatedStorage/Client/Controllers/CampaignController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/CampaignController.luau) · 511 linhas · SHA-256: 9876dad20a9a48ec4963f43847443afd73c9425e057a9bf18d15beab07a44128

### Funções nomeadas / callbacks atribuídos

~~~text
L26: function Controller.toggleGuide()
L61: function Controller.Start()
L69: guideToggle = function()
L84: local function decodeTasks()
L87: local function decodeRoster()
L104: local function refreshCoins()
L119: local function refreshLevel()
L134: local function celebrate(big: boolean, title: string, detail: string)
L175: local function setSlot(slot: FieldSlot, count: number, text: string)
L472: local function qaRequest()
~~~

### Dependências literais

- L9: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L10: @game/ReplicatedStorage/Shared/Game/CampaignCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/CampaignCatalog.luau)
- L11: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L12: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L13: @game/ReplicatedStorage/Shared/Game/PlayerGuide → [fonte](../../src/ReplicatedStorage/Shared/Game/PlayerGuide.luau)
- L14: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L15: ../UI/FieldHud → [fonte](../../src/ReplicatedStorage/Client/UI/FieldHud.luau)
- L16: ../UI/Juice → [fonte](../../src/ReplicatedStorage/Client/UI/Juice.luau)
- L17: ../UI/Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)
- L18: ./CharacterController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterController.luau)
- L19: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L483: ./InteractionController → [fonte](../../src/ReplicatedStorage/Client/Controllers/InteractionController.luau)

### Listeners / registros / callbacks

~~~text
L79: ui.close.Activated:Connect(function()
L90: state:GetAttributeChangedSignal("Tasks"):Connect(decodeTasks)
L91: state:GetAttributeChangedSignal("Roster"):Connect(decodeRoster)
L95: player:GetAttributeChangedSignal("CampaignFeedbackSerial"):Connect(function()
L131: player:GetAttributeChangedSignal("CoinPickupSerial"):Connect(function()
L147: player:GetAttributeChangedSignal("TungKnockSerial"):Connect(function()
L152: player:GetAttributeChangedSignal("Fichas"):Connect(refreshCoins)
L153: player:GetAttributeChangedSignal("Level"):Connect(refreshLevel)
L157: UserInputService.InputBegan:Connect(function(input, processed)
L167: UserInputService.InputEnded:Connect(function(input)
L172: UserInputService.WindowFocusReleased:Connect(function()
L181: RunService.RenderStepped:Connect(function(dt)
L505: player:GetAttributeChangedSignal("CampaignQARequest"):Connect(qaRequest)
~~~

### Rede

~~~text
L481: result = Remotes.clientFunction("RequestRestart", 10):InvokeServer()
L494: Remotes.clientEvent("SetHoldBreath", 10):FireServer(request.breath)
L497: result = Remotes.clientFunction("Interact", 10):InvokeServer(request.id)
~~~

### Estado observado / publicado

~~~text
L62: if GameState.wait():GetAttribute("CampaignActive") ~= true then
L85: tasks = HttpService:JSONDecode((state:GetAttribute("Tasks") or "[]") :: string)
L88: roster = HttpService:JSONDecode((state:GetAttribute("Roster") or "[]") :: string)
L90: state:GetAttributeChangedSignal("Tasks"):Connect(decodeTasks)
L91: state:GetAttributeChangedSignal("Roster"):Connect(decodeRoster)
L95: player:GetAttributeChangedSignal("CampaignFeedbackSerial"):Connect(function()
L96: ui.feedback.Text = messages[tostring(player:GetAttribute("CampaignFeedback"))]
L103: local shownCoins = (tonumber(player:GetAttribute("Fichas")) or 0) :: number
L105: local value = (tonumber(player:GetAttribute("Fichas")) or 0) :: number
L118: local shownLevel = (tonumber(player:GetAttribute("Level")) or 1) :: number
L120: local value = (tonumber(player:GetAttribute("Level")) or 1) :: number
L131: player:GetAttributeChangedSignal("CoinPickupSerial"):Connect(function()
L147: player:GetAttributeChangedSignal("TungKnockSerial"):Connect(function()
L152: player:GetAttributeChangedSignal("Fichas"):Connect(refreshCoins)
L153: player:GetAttributeChangedSignal("Level"):Connect(refreshLevel)
L187: local phase = tostring(state:GetAttribute("Phase"))
L188: local stage = (state:GetAttribute("Stage") or 0) :: number
L197: local story = state:GetAttribute("GameMode") == "Story"
L198: local status = player:GetAttribute("CampaignStatus") :: string?
L199: local cinema = player:GetAttribute("CinematicActive") == true
L200: ui.gui.Enabled = phase ~= "Lobby" and not cinema and state:GetAttribute("Building") ~= true
L207: player:SetAttribute("FieldGuideOpen", false)
L210: local key = `{state:GetAttribute("Seed")}:{stage}:{story}`
L224: math.max(0, math.ceil(((state:GetAttribute("StorySceneEndsAt") or 0) :: number) - now))
L237: local roleId = player:GetAttribute("CampaignRole")
L262: local remaining = math.max(0, math.ceil((tonumber(state:GetAttribute("LobbyReturnAt")) or now) - now))
L265: local solved = (state:GetAttribute("Solved") or 0) :: number
L266: local total = math.max(1, (state:GetAttribute("Total") or 1) :: number)
L276: math.ceil(((state:GetAttribute("NextStageAt") or 0) :: number) - workspace:GetServerTimeNow())
L291: player:SetAttribute("FieldGuideOpen", ui.dossier.Visible)
L304: local battery = player:GetAttribute("Battery")
L306: local oxygen = math.clamp((tonumber(player:GetAttribute("Oxygen")) or 100) :: number, 0, 100)
L311: ui.equipment.Text = if player:GetAttribute("Stance") == "Crouch" then "🤫 AGACHADO (silencioso)" else ""
L315: math.ceil(((state:GetAttribute("EscapeEndsAt") or 0) :: number) - now)
L323: local inventory = HttpService:JSONDecode((state:GetAttribute("Inventory") or "{}") :: string)
L324: local stock = HttpService:JSONDecode((player:GetAttribute("HouseSupplies") or "{}") :: string)
L336: ui.bars.battery.frame.Visible = player:GetAttribute("HasFlashlight") == true
L389: `🦅 RADAR: {model:GetAttribute("RoomLabel") or "objetivo"} por perto!`
L473: local command = player:GetAttribute("CampaignQARequest")
L487: accepted = selected and player:GetAttribute("CampaignAccepted") == true,
L489: then player:GetAttribute("CampaignFeedback")
L499: player:SetAttribute(
L505: player:GetAttributeChangedSignal("CampaignQARequest"):Connect(qaRequest)
~~~

## src/ReplicatedStorage/Client/Controllers/CharacterAnimatorController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterAnimatorController.luau) · 353 linhas · SHA-256: 4c99941af3c0b624956bf9e8457c0cebc827949df2ce8f81ec0feb5546102d2d

### Funções nomeadas / callbacks atribuídos

~~~text
L43: local function writeBase(joint: Joint, frame: CFrame)
L51: local function readBase(joint: Joint): CFrame
L59: local function jointPoint(joint: Joint?, side: number): Vector3?
L71: local function lowestY(part: BasePart): number
L85: local function segment(upper: Joint?, lower: Joint?, fallback: number): number
L96: local function remove(other: Player)
L112: local function getRig(other: Player): Rig?
L176: local function joint(rig: Rig, name: string, frame: CFrame)
L183: local function animate(other: Player, dt: number)
L273: local function placeLamp(other: Player, rig: Rig)
L299: function Controller.debugState(): { [string]: any }
L318: function Controller.Start()
~~~

### Dependências literais

- L11: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L12: @game/ReplicatedStorage/Shared/Game/CharacterPose → [fonte](../../src/ReplicatedStorage/Shared/Game/CharacterPose.luau)
- L13: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L14: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L15: ./CameraController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CameraController.luau)

### Listeners / registros / callbacks

~~~text
L319: Players.PlayerRemoving:Connect(remove)
L320: player.CharacterAdded:Connect(function()
L324: RunService.PreSimulation:Connect(function(dt)
L345: RunService.RenderStepped:Connect(function()
~~~

### Rede

~~~text
L332: Remotes.clientEvent("SetLook", 5):FireServer(pitch)
~~~

### Estado observado / publicado

~~~text
L136: hipHeight = math.max(tonumber(model:GetAttribute("StandHipHeight")) or h.HipHeight, 1.2),
L139: feedbackSerial = other:GetAttribute("CampaignFeedbackSerial"),
L193: local crouch = other:GetAttribute("Stance") == "Crouch"
L195: rig.pitch = Pose.approach(rig.pitch, (other:GetAttribute("LookPitch") :: number?) or 0, 12, dt)
L196: local down = other:GetAttribute("CampaignStatus") == "Downed"
L198: local serial = other:GetAttribute("CampaignFeedbackSerial")
L204: and other:GetAttribute("CampaignFeedback") == "rescuing"
L206: local on = other:GetAttribute(Tags.Attr.Flashlight) == true
L207: and (other:GetAttribute("Hidden") == nil or other:GetAttribute("Hidden") == "")
L279: local down = other:GetAttribute("CampaignStatus") == "Downed"
L280: local on = other:GetAttribute(Tags.Attr.Flashlight) == true
L281: and (other:GetAttribute("Hidden") == nil or other:GetAttribute("Hidden") == "")
~~~

## src/ReplicatedStorage/Client/Controllers/CharacterController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterController.luau) · 402 linhas · SHA-256: 6c2f54c2fbe1109fd8c4f18df3a19fc0165ccf31ccf095e87ad245451961faf8

### Funções nomeadas / callbacks atribuídos

~~~text
L76: local function humanoid(): Humanoid?
L81: local function rootPart(): BasePart?
L87: local function disableCoreUi()
L103: local function serverStance(): Stance
L110: local function isHidden(): boolean
L115: local function active(): boolean
L121: local function canStand(): boolean
L139: local function sendStance(stance: Stance)
L150: local function desiredStance(): Stance
L158: local function syncStance(now: number)
L187: local function currentStance(): Stance
L195: local function probeFloor(root: BasePart, character: Model)
L210: local function update(dt: number)
L305: function CharacterController.Init()
L314: function CharacterController.Start()
L375: function CharacterController.getStamina(): (number, number)
L379: function CharacterController.isSprinting(): boolean
L383: function CharacterController.getMotion(): Motion
L387: function CharacterController.onLanded(callback: (intensity: number) -> ())
L392: function CharacterController.onStandBlocked(callback: () -> ())
L397: function CharacterController.requestStance(stance: Stance)
~~~

### Dependências literais

- L17: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L18: @game/ReplicatedStorage/Shared/Game/Perks → [fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau)
- L19: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L20: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)

### Listeners / registros / callbacks

~~~text
L326: UserInputService.WindowFocusReleased:Connect(function()
L342: player.CharacterAdded:Connect(function(character: Model)
L353: UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
L366: UserInputService.InputEnded:Connect(function(input: InputObject)
L372: RunService.RenderStepped:Connect(update)
~~~

### Rede

~~~text
L143: local ok, remote = pcall(Remotes.clientEvent, "SetStance", 5)
L145: remote:FireServer(stance)
~~~

### Estado observado / publicado

~~~text
L104: if player:GetAttribute("Stance") == "Crouch" then
L111: local hidden = player:GetAttribute("Hidden")
L116: local status = player:GetAttribute("CampaignStatus")
L226: local wantsSprint = player:GetAttribute("TouchSprint") == true
L243: local lungs = Perks.factor("folego", tonumber(player:GetAttribute("PerkFolego")) or 0)
L317: player:SetAttribute("TouchSprint", state == Enum.UserInputState.Begin)
L327: player:SetAttribute("TouchSprint", false)
L330: GameState.observe(function(snapshot)
L346: standHipHeight = (character:GetAttribute("StandHipHeight") :: number?) or h.HipHeight
L376: return stamina, P.StaminaMax * Perks.factor("folego", tonumber(player:GetAttribute("PerkFolego")) or 0)
~~~

## src/ReplicatedStorage/Client/Controllers/CinematicController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/CinematicController.luau) · 687 linhas · SHA-256: 58628d2311c8c2d41a6a1db0da493b109fd83b72667b5d883441ad14d3a61017

### Funções nomeadas / callbacks atribuídos

~~~text
L82: local function dropCameo()
L98: local function ensureCameo(): TungTungRig.TungRig?
L110: local function updateCameo(current: Shots.Sequence, index: number, dt: number)
L179: local function vec(v: Shots.Vec): Vector3
L183: local function sink(): Enum.ContextActionResult
L187: local function campaignState(): Instance?
L191: local function hideSelf()
L200: local function showSelf()
L215: local function setCctv(on: boolean)
L221: function Controller.stop()
L245: function Controller.play(value: Shots.Sequence, playOptions: PlayOptions?)
L290: function Controller.debugState(): { [string]: any }
L303: local function phaseKey(): (string, string)
L313: local function roleTitle(): string
L324: function Controller.wake(delay: number?)
L340: function Controller.stageCard()
L390: local function onKeyChanged(phase: string, previous: string)
L426: local function updateSequence(current: Shots.Sequence, dt: number)
L492: function Controller.Init()
L523: local function cardLine(
L573: bridge.OnInvoke = function(command: string, value: any): any
L614: function Controller.Start()
~~~

### Dependências literais

- L25: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L26: @game/ReplicatedStorage/Shared/Game/CampaignCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/CampaignCatalog.luau)
- L27: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L28: @game/ReplicatedStorage/Shared/Game/CinematicShots → [fonte](../../src/ReplicatedStorage/Shared/Game/CinematicShots.luau)
- L29: @game/ReplicatedStorage/Shared/Game/Presentation → [fonte](../../src/ReplicatedStorage/Shared/Game/Presentation.luau)
- L30: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L31: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L32: ./CameraController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CameraController.luau)
- L33: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)
- L34: ./TransitionController → [fonte](../../src/ReplicatedStorage/Client/Controllers/TransitionController.luau)
- L35: ./StoreController → [fonte](../../src/ReplicatedStorage/Client/Controllers/StoreController.luau)
- L36: ./CharacterAnimatorController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterAnimatorController.luau)
- L37: ../Creature/TungTungRig → [fonte](../../src/ReplicatedStorage/Client/Creature/TungTungRig.luau)
- L38: ../Creature/ArmadilhoRig → [fonte](../../src/ReplicatedStorage/Client/Creature/ArmadilhoRig.luau)
- L39: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L40: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L41: ../UI/Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)
- L411: @game/ReplicatedStorage/Shared/Game/ForestCinema → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestCinema.luau)
- L607: ./UiFeedbackController → [fonte](../../src/ReplicatedStorage/Client/Controllers/UiFeedbackController.luau)

### Listeners / registros / callbacks

~~~text
L558: button.Activated:Connect(Controller.stop)
L573: bridge.OnInvoke = function(command: string, value: any): any
L615: UserInputService.InputBegan:Connect(function(input, _processed)
L626: player.CharacterRemoving:Connect(Controller.stop)
L629: player:GetAttributeChangedSignal("CampaignStatus"):Connect(function()
L636: RunService:BindToRenderStep("S9Cinematic", Enum.RenderPriority.Camera.Value - 2, function(dt)
L681: RunService:BindToRenderStep("S9CinematicSelf", Enum.RenderPriority.Camera.Value + 3, function()
~~~

### Estado observado / publicado

~~~text
L228: player:SetAttribute("CinematicActive", false)
L229: player:SetAttribute("CinematicHold", false)
L230: player:SetAttribute("OpeningActive", false)
L257: player:SetAttribute("CinematicActive", true)
L259: player:SetAttribute("CinematicHold", not options.loop)
L306: local phase = tostring(campaign:GetAttribute("Phase"))
L307: return phase, `{phase}:{campaign:GetAttribute("CampaignId")}:{campaign:GetAttribute("Stage")}`
L314: local id = player:GetAttribute("CampaignRole")
L347: local stage = tonumber(campaign:GetAttribute("Stage")) or 1
L348: local title = tostring(campaign:GetAttribute("Title") or "")
L349: local threat = tostring(campaign:GetAttribute("Threat") or "")
L401: player:SetAttribute("OpeningActive", true)
L406: player:SetAttribute("OpeningActive", true)
L410: if campaign and campaign:GetAttribute("ForestActive") == true
L415: if campaign and campaign:GetAttribute("GameMode") ~= "Story" then
L628: local lastStatus = player:GetAttribute("CampaignStatus")
L629: player:GetAttributeChangedSignal("CampaignStatus"):Connect(function()
L630: local status = player:GetAttribute("CampaignStatus")
L647: and state:GetAttribute("ForestActive") == true
L652: player:SetAttribute("ForestEpilogueVisible", showTeaser)
L657: (tonumber(state:GetAttribute("LobbyReturnAt")) or workspace:GetServerTimeNow())
L665: if phase == "Lobby" and player:GetAttribute("ModeMenuOpen") == true and not Store.isOpen() then
L670: if Store.isOpen() or player:GetAttribute("CampaignStatus") == "Downed" then
~~~

## src/ReplicatedStorage/Client/Controllers/CoinController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/CoinController.luau) · 85 linhas · SHA-256: 6de7e74814f424e1709d10591994019c9cdb5351b00f151c999847366f7e8b4f

### Funções nomeadas / callbacks atribuídos

~~~text
L22: local function track(part: Instance)
L33: local function burst(position: Vector3, gem: boolean)
L59: function CoinController.Start()
~~~

### Dependências literais

- L12: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)

### Listeners / registros / callbacks

~~~text
L25: part.AncestryChanged:Connect(function(_, parent)
L63: CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
L64: player:GetAttributeChangedSignal("CoinPickupSerial"):Connect(function()
L75: RunService.RenderStepped:Connect(function(dt)
~~~

### Estado observado / publicado

~~~text
L64: player:GetAttributeChangedSignal("CoinPickupSerial"):Connect(function()
L65: local at = player:GetAttribute("CoinPickupAt")
L66: local gem = player:GetAttribute("CoinPickupGem") == true
~~~

## src/ReplicatedStorage/Client/Controllers/ContinueController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/ContinueController.luau) · 203 linhas · SHA-256: e126059e6929f434e0a4cea02656c2a3ca28fc1b8772576b0f3f7eee56ea31e0

### Funções nomeadas / callbacks atribuídos

~~~text
L39: local function stock(): number
L50: local function say(key: string?)
L56: local function useContinue()
L78: local function build()
L161: function Controller.debugState(): { [string]: any }
L165: function Controller.Start()
~~~

### Dependências literais

- L17: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L18: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L19: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L20: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L21: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L22: ../UI/Juice → [fonte](../../src/ReplicatedStorage/Client/UI/Juice.luau)
- L23: ../UI/Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)
- L24: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)

### Listeners / registros / callbacks

~~~text
L140: b.Activated:Connect(function()
L171: RunService.RenderStepped:Connect(function()
~~~

### Rede

~~~text
L62: return Remotes.clientFunction("Store", 5):InvokeServer("use_continue")
~~~

### Estado observado / publicado

~~~text
L40: local raw = player:GetAttribute("Consumables")
L166: if GameState.wait():GetAttribute("CampaignActive") ~= true then
L176: local visible = state:GetAttribute("Phase") == "Lost" and player:GetAttribute("CinematicActive") ~= true
~~~

## src/ReplicatedStorage/Client/Controllers/CosmeticController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/CosmeticController.luau) · 115 linhas · SHA-256: 8f3cfefb052a4d002198a7d6810ab96deffd193209001cac35cbfb845a28f138

### Funções nomeadas / callbacks atribuídos

~~~text
L25: local function rgb(c: StoreCatalog.RGB?, fallback: Color3): Color3
L32: local function material(name: string?): Enum.Material
L39: local function equippedItem(attribute: string, kind: StoreCatalog.ItemKind): StoreCatalog.Item
L48: local function applyFlashlight()
L58: local function applyUniform()
L63: local function applyFilter()
L68: local function titlesVisible(): boolean
L73: local function updateTitles()
L90: function CosmeticController.Start()
~~~

### Dependências literais

- L15: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L16: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L17: ./FlashlightController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FlashlightController.luau)
- L18: ./LightingController → [fonte](../../src/ReplicatedStorage/Client/Controllers/LightingController.luau)

### Listeners / registros / callbacks

~~~text
L98: player:GetAttributeChangedSignal(attribute):Connect(apply)
L106: RunService.Heartbeat:Connect(function(dt: number)
~~~

### Estado observado / publicado

~~~text
L40: local id = player:GetAttribute(attribute)
L69: local status = player:GetAttribute("CampaignStatus")
L98: player:GetAttributeChangedSignal(attribute):Connect(apply)
L101: GameState.observe(function(snapshot)
~~~

## src/ReplicatedStorage/Client/Controllers/CreatureVisualController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/CreatureVisualController.luau) · 351 linhas · SHA-256: 94064e9d9cd8dfd895e153f3449a5c01d88ff6d3574c1ae8a167077d60b80f1b

### Funções nomeadas / callbacks atribuídos

~~~text
L51: local function serverRoot(): BasePart?
L57: local function visualModel(): Model
L65: local function emitter(): Attachment
L73: local function animationFor(currentMode: string): (string, number)
L89: local function setShown(value: boolean)
L100: local function onModeChanged(previous: string, current: string)
L133: local function footstep(root: BasePart, camera: Camera?)
L148: local function lookYawAt(base: CFrame, camera: Camera?): number
L157: local function updateTung(t: TungTungRig.TungRig, root: BasePart, dt: number, camera: Camera?)
L198: local function updateLegacy(r: Rig.Rig, root: BasePart, dt: number, camera: Camera?)
L242: local function update(dt: number)
L295: function CreatureVisualController.react(name: string)
L306: function CreatureVisualController.Init()
L315: function CreatureVisualController.Start()
L316: local function watchDoor(inst: Instance)
L339: function CreatureVisualController.status(): (boolean, string, number)
L347: function CreatureVisualController.clip(): string?
~~~

### Dependências literais

- L14: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L15: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L16: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L17: ../Creature/Poses → [fonte](../../src/ReplicatedStorage/Client/Creature/Poses.luau)
- L18: ../Creature/Rig → [fonte](../../src/ReplicatedStorage/Client/Creature/Rig.luau)
- L19: ../Creature/TungTungRig → [fonte](../../src/ReplicatedStorage/Client/Creature/TungTungRig.luau)
- L20: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L21: ./CameraController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CameraController.luau)

### Listeners / registros / callbacks

~~~text
L320: inst:GetAttributeChangedSignal("BangSerial"):Connect(function()
L331: world.DescendantAdded:Connect(watchDoor)
L335: RunService.RenderStepped:Connect(update)
~~~

### Estado observado / publicado

~~~text
L138: if root:GetAttribute("FalseExit") then 0.25 else 1,
L244: local active = root ~= nil and root:GetAttribute(Tags.Attr.CreatureActive) == true and root.Position.Y > -100
L252: local currentMode = (root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Patrol"
L265: local forest = world ~= nil and world:GetAttribute("ForestActive") == true
L280: Players.LocalPlayer:SetAttribute(
L282: ((Players.LocalPlayer:GetAttribute("TungKnockSerial") :: number?) or 0) + 1
L320: inst:GetAttributeChangedSignal("BangSerial"):Connect(function()
L332: GameState.observe(function(snapshot)
~~~

## src/ReplicatedStorage/Client/Controllers/FearController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/FearController.luau) · 213 linhas · SHA-256: 4680a317d10c9b6752062decbe479f30fcc962b1d0403fff780180985e9f06a7

### Funções nomeadas / callbacks atribuídos

~~~text
L42: local function creatureRoot(): BasePart?
L48: local function isHidden(): boolean
L54: local function nearLight(position: Vector3): boolean
L70: local function checkVisible(camera: Camera, root: BasePart): boolean
L98: function FearController.get(): number
L102: function FearController.level(): number
L106: function FearController.darkness(): number
L110: function FearController.spike(amount: number)
L114: function FearController.onLevelChanged(callback: (level: number) -> ())
L118: function FearController.debugState(): { [string]: any }
L129: function FearController.Start()
~~~

### Dependências literais

- L18: @game/ReplicatedStorage/Shared/Game/FearModel → [fonte](../../src/ReplicatedStorage/Shared/Game/FearModel.luau)
- L19: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L20: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L21: @game/ReplicatedStorage/Shared/Game/ThreatPresentation → [fonte](../../src/ReplicatedStorage/Shared/Game/ThreatPresentation.luau)
- L22: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L23: ./BodyAudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/BodyAudioController.luau)
- L24: ./CameraController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CameraController.luau)
- L25: ./FlashlightController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FlashlightController.luau)

### Listeners / registros / callbacks

~~~text
L141: RunService.RenderStepped:Connect(function(dt: number)
~~~

### Estado observado / publicado

~~~text
L49: local hidden = player:GetAttribute("Hidden")
L130: GameState.observe(function(next: GameState.Snapshot)
L158: local status = player:GetAttribute("CampaignStatus") :: string?
L161: then (root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Dormant"
L165: if root then root:GetAttribute(Tags.Attr.ThreatTargetUserId) :: number? else nil,
L182: local alert = if root then (root:GetAttribute("Alert") :: number?) or 0 else 0
~~~

## src/ReplicatedStorage/Client/Controllers/FlashlightController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/FlashlightController.luau) · 582 linhas · SHA-256: 68e5f52976610142e63cc539ecf4b3e394a9a33cbf0de66b5dd2702230759552

### Funções nomeadas / callbacks atribuídos

~~~text
L59: local function charge(): number
L64: local function serverOn(): boolean
L68: local function isHidden(): boolean
L73: local function hint(key: string)
L79: local function creatureDistance(position: Vector3): number
L88: local function send(value: boolean)
L97: local function localPart(
L121: local function buildViewmodel(): Viewmodel
L125: local function add(name: string, size: Vector3, color: Color3, material: Enum.Material?): BasePart
L161: local function placeViewmodel(base: CFrame)
L171: local function updateLeds(now: number)
L194: local function applyVisible()
L217: local function partNamed(name: string): BasePart?
L234: function FlashlightController.isOn(): boolean
L239: function FlashlightController.isWanted(): boolean
L244: function FlashlightController.applySkin(body: Color3, head: Color3, beam: Color3, material: Enum.Material)
L266: function FlashlightController.applySleeve(color: Color3)
L274: function FlashlightController.set(value: boolean, silent: boolean?)
L288: function FlashlightController.flicker(duration: number)
L295: function FlashlightController.onHint(callback: (key: string) -> ())
L300: function FlashlightController.showPickup(kind: string, from: Vector3)
L334: function FlashlightController.playKeyUnlock()
L371: function FlashlightController.Init()
L439: function FlashlightController.Start()
~~~

### Dependências literais

- L17: @game/ReplicatedStorage/Shared/Game/BatteryModel → [fonte](../../src/ReplicatedStorage/Shared/Game/BatteryModel.luau)
- L18: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L19: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L20: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L21: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L22: @game/ReplicatedStorage/Shared/Game/LightingProfile → [fonte](../../src/ReplicatedStorage/Shared/Game/LightingProfile.luau)
- L23: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L24: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)
- L25: ./CharacterController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterController.luau)

### Listeners / registros / callbacks

~~~text
L440: player:GetAttributeChangedSignal("CinematicActive"):Connect(function()
L446: player:GetAttributeChangedSignal("CampaignStatus"):Connect(applyVisible)
L447: UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
L467: player:GetAttributeChangedSignal(Tags.Attr.Flashlight):Connect(function()
L474: player:GetAttributeChangedSignal("Hidden"):Connect(function()
L487: player.CharacterAdded:Connect(function()
L499: RunService:BindToRenderStep("S9Flashlight", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
~~~

### Rede

~~~text
L90: local ok, remote = pcall(Remotes.clientEvent, "SetFlashlight", 10)
L92: remote:FireServer(value)
~~~

### Estado observado / publicado

~~~text
L60: local value = player:GetAttribute("Battery")
L65: return player:GetAttribute(Tags.Attr.Flashlight) == true
L69: local hidden = player:GetAttribute("Hidden")
L82: if root and root:IsA("BasePart") and root:GetAttribute(Tags.Attr.CreatureActive) then
L195: local status = player:GetAttribute("CampaignStatus")
L199: and player:GetAttribute("CinematicActive") ~= true
L235: local status = player:GetAttribute("CampaignStatus")
L440: player:GetAttributeChangedSignal("CinematicActive"):Connect(function()
L441: if player:GetAttribute("CinematicActive") ~= true then
L446: player:GetAttributeChangedSignal("CampaignStatus"):Connect(applyVisible)
L451: if player:GetAttribute("CinematicActive") == true then
L460: local status = player:GetAttribute("CampaignStatus")
L467: player:GetAttributeChangedSignal(Tags.Attr.Flashlight):Connect(function()
L474: player:GetAttributeChangedSignal("Hidden"):Connect(function()
L494: GameState.observe(function(snapshot)
L539: local visible = player:GetAttribute("HasFlashlight") == true
L541: and player:GetAttribute("CinematicActive") ~= true
L542: and (player:GetAttribute("CampaignStatus") == nil or player:GetAttribute("CampaignStatus") == "Active")
~~~

## src/ReplicatedStorage/Client/Controllers/GameUiController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/GameUiController.luau) · 1009 linhas · SHA-256: ff6e289447f4155ef1170a5adae4a78f36e2005f04d388f80abcf861f8abab78

### Funções nomeadas / callbacks atribuídos

~~~text
L64: local function r(): Refs
L69: local function label(props: { [string]: any }): TextLabel
L85: local function frame(props: { [string]: any }, children: { any }?): Frame
L93: local function stroke(color: Color3, thickness: number): Instance
L103: local function buildFace(parent: Instance, variant: number): Frame
L141: local function build(): Refs
L494: local function rescale()
L533: local function onOff(value: boolean): string
L537: local function refreshHelp()
L550: local function refreshObjective(s: GameState.Snapshot)
L587: local function typeInto(target: TextLabel, value: string, token: number, current: () -> number)
L602: local function playIntro(fromCheckpoint: boolean?)
L635: local function endIntro()
L654: local function showFinale(s: GameState.Snapshot)
L700: local function playScareThenFinale(s: GameState.Snapshot)
L728: local function requestRestart(mode: "full" | "checkpoint")
L740: local function showCaption(text: string, duration: number?)
L765: local function onState(s: GameState.Snapshot, changed: string?)
L819: function GameUiController.Init()
L865: local function visibility()
L879: function GameUiController.Start()
L888: local function cinematicChanged()
L962: function GameUiController.setPrompt(text: string?)
L978: function GameUiController.caption(text: string, duration: number?)
L982: function GameUiController.showNote(id: string)
L998: function GameUiController.isNoteOpen(): boolean
L1002: function GameUiController.closeNote()
~~~

### Dependências literais

- L15: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L16: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L17: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L18: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L19: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L20: ../UI/Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)
- L21: ../Creature/AdemirPortrait → [fonte](../../src/ReplicatedStorage/Client/Creature/AdemirPortrait.luau)
- L22: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)

### Listeners / registros / callbacks

~~~text
L353: noteClose.Activated:Connect(function()
L502: camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
L838: RunService.RenderStepped:Connect(function()
L871: player:GetAttributeChangedSignal("CinematicActive"):Connect(visibility)
L873: player:GetAttributeChangedSignal(key):Connect(visibility)
L883: ui.note:GetPropertyChangedSignal("Visible"):Connect(function()
L901: player:GetAttributeChangedSignal("CinematicActive"):Connect(cinematicChanged)
L904: ui.restart.Activated:Connect(function()
L907: ui.continueButton.Activated:Connect(function()
L910: UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
L933: RunService.RenderStepped:Connect(function(dt: number)
~~~

### Rede

~~~text
L731: Remotes.clientFunction("RequestRestart", 5):InvokeServer(mode)
~~~

### Estado observado / publicado

~~~text
L355: player:SetAttribute("NoteOpen", false)
L502: camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
L866: (shared :: ScreenGui).Enabled = player:GetAttribute("CinematicActive") ~= true
L867: and player:GetAttribute("ComfortMenuOpen") ~= true
L868: and player:GetAttribute("FieldGuideOpen") ~= true
L869: and player:GetAttribute("TouchBackpackOpen") ~= true
L871: player:GetAttributeChangedSignal("CinematicActive"):Connect(visibility)
L873: player:GetAttributeChangedSignal(key):Connect(visibility)
L881: GameState.observe(onState)
L883: ui.note:GetPropertyChangedSignal("Visible"):Connect(function()
L889: local active = player:GetAttribute("CinematicActive") == true
L901: player:GetAttributeChangedSignal("CinematicActive"):Connect(cinematicChanged)
L950: local battery = player:GetAttribute("Battery")
L965: if (player:GetAttribute("Hidden") or "") ~= "" then
L967: .. (if player:GetAttribute("HoldBreath") == true then "\nPRENDENDO O AR..." else "")
L995: player:SetAttribute("NoteOpen", true)
L1006: player:SetAttribute("NoteOpen", false)
~~~

## src/ReplicatedStorage/Client/Controllers/HapticsController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/HapticsController.luau) · 196 linhas · SHA-256: 7ad899babcf406061eedd645b2d52d8b1d0a655f99edf87995f9a51b4727015b

### Funções nomeadas / callbacks atribuídos

~~~text
L42: local function enabled(): boolean
L46: local function supported(motor: Enum.VibrationMotor): boolean
L59: local function setMotor(motor: Enum.VibrationMotor, value: number)
L71: local function creature(): (BasePart?, string)
L92: function HapticsController.pulse(strength: number, duration: number, motor: Enum.VibrationMotor?)
L103: function HapticsController.stopAll()
L109: function HapticsController.debugState(): { [string]: any }
L113: function HapticsController.Start()
~~~

### Dependências literais

- L17: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L18: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L19: @game/ReplicatedStorage/Shared/Game/ThreatPresentation → [fonte](../../src/ReplicatedStorage/Shared/Game/ThreatPresentation.luau)
- L20: ./CharacterController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterController.luau)
- L21: ./FearController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FearController.luau)
- L22: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)

### Listeners / registros / callbacks

~~~text
L122: UserInputService.GamepadDisconnected:Connect(function()
L129: RunService.RenderStepped:Connect(function(dt: number)
~~~

### Estado observado / publicado

~~~text
L74: if not root or not root:IsA("BasePart") or root:GetAttribute(Tags.Attr.CreatureActive) ~= true then
L77: local status = player:GetAttribute("CampaignStatus") :: string?
L79: (root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Dormant",
L80: root:GetAttribute(Tags.Attr.ThreatTargetUserId) :: number?,
L114: GameState.observe(function(next)
L143: local status = player:GetAttribute("CampaignStatus") :: string?
~~~

## src/ReplicatedStorage/Client/Controllers/HudController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/HudController.luau) · 138 linhas · SHA-256: 0dd6baa933da8d0dd6de717969630d659c41acafcb721c19369cfb4eea8b59ba

### Funções nomeadas / callbacks atribuídos

~~~text
L28: local function averageFps(): number
L44: function HudController.Init()
L77: function HudController.Start()
L128: function HudController.metrics(): { [string]: number }
~~~

### Dependências literais

- L12: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L13: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L14: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L15: ./CreatureVisualController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CreatureVisualController.luau)
- L16: ./FearController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FearController.luau)
- L17: ./TensionController → [fonte](../../src/ReplicatedStorage/Client/Controllers/TensionController.luau)

### Listeners / registros / callbacks

~~~text
L78: UserInputService.InputBegan:Connect(function(input: InputObject)
L84: RunService.RenderStepped:Connect(function(dt: number)
~~~

## src/ReplicatedStorage/Client/Controllers/InteractionController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/InteractionController.luau) · 438 linhas · SHA-256: 8b272ce0a89f28b5fc347472bef85de08f6fc615590134e684ebb508f3aa18d7

### Funções nomeadas / callbacks atribuídos

~~~text
L46: local function hiddenId(): string?
L51: local function allowed(): boolean
L58: local function clearTarget()
L68: local function holdBreath(value: boolean)
L81: local function visible(camera: Camera, part: BasePart): boolean
L97: local function findTarget(camera: Camera): BasePart?
L120: local function messageFor(key: string): string
L124: local function interact(id: string, part: BasePart?, action: string?)
L183: function InteractionController.activate(action: string?)
L212: function InteractionController.requestBreath(value: boolean)
L217: function InteractionController.useSupply(item: string)
L224: function InteractionController.Start()
L248: local function syncHidden()
L292: local function breathAction(_: string, state: Enum.UserInputState, input: InputObject)
L325: local function cancelBreath()
L395: function InteractionController.currentTarget(): string?
L405: function InteractionController.testInteract(expectedId: string): boolean
~~~

### Dependências literais

- L15: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L16: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L17: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L18: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L19: @game/ReplicatedStorage/Shared/Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)
- L20: @game/ReplicatedStorage/Shared/Game/InteractionPresentation → [fonte](../../src/ReplicatedStorage/Shared/Game/InteractionPresentation.luau)
- L21: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L22: ./CameraController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CameraController.luau)
- L23: ./CharacterController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterController.luau)
- L24: ./FearController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FearController.luau)
- L25: ./FlashlightController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FlashlightController.luau)
- L26: ./ScreenFxController → [fonte](../../src/ReplicatedStorage/Client/Controllers/ScreenFxController.luau)
- L27: ./GameUiController → [fonte](../../src/ReplicatedStorage/Client/Controllers/GameUiController.luau)
- L31: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

### Listeners / registros / callbacks

~~~text
L244: player:GetAttributeChangedSignal("CampaignStatus"):Connect(function()
L256: player:GetAttributeChangedSignal("Hidden"):Connect(syncHidden)
L257: player:GetAttributeChangedSignal("HideEye"):Connect(syncHidden)
L258: player.CharacterAdded:Connect(function()
L274: UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
L283: UserInputService.InputEnded:Connect(function(input)
L288: UserInputService.WindowFocusReleased:Connect(function()
L328: GuiService.MenuOpened:Connect(cancelBreath)
L330: player:GetAttributeChangedSignal(attr):Connect(cancelBreath)
L332: player.CharacterAdded:Connect(cancelBreath)
L353: RunService.RenderStepped:Connect(function(dt: number)
~~~

### Rede

~~~text
L74: local ok, remote = pcall(Remotes.clientEvent, "SetHoldBreath", 5)
L76: remote:FireServer(value)
L133: return Remotes.clientFunction("Interact", 5):InvokeServer(id, action)
L220: Remotes.clientFunction("UseHouseItem", 5):InvokeServer(item)
~~~

### Estado observado / publicado

~~~text
L47: local id = player:GetAttribute("Hidden")
L52: return player:GetAttribute("FieldGuideOpen") ~= true
L53: and player:GetAttribute("ComfortMenuOpen") ~= true
L54: and player:GetAttribute("CinematicActive") ~= true
L55: and Rules.allowed(phase, player:GetAttribute("CampaignStatus") :: string?)
L103: if instance:IsA("BasePart") and instance:GetAttribute(Tags.Attr.InteractEnabled) == true then
L106: local maxDistance = (instance:GetAttribute(Tags.Attr.InteractDistance) :: number?) or 8
L203: local id = part:GetAttribute(Tags.Attr.InteractId)
L205: type(id) == "string" and (not alt or (not campaign and type(part:GetAttribute("InteractAlt")) == "string"))
L225: campaign = GameState.wait():GetAttribute("CampaignActive") == true
L235: GameState.observe(function(snapshot)
L244: player:GetAttributeChangedSignal("CampaignStatus"):Connect(function()
L249: local eye = player:GetAttribute("HideEye")
L256: player:GetAttributeChangedSignal("Hidden"):Connect(syncHidden)
L257: player:GetAttributeChangedSignal("HideEye"):Connect(syncHidden)
L330: player:GetAttributeChangedSignal(attr):Connect(cancelBreath)
L367: Text.HiddenHint .. (if player:GetAttribute("HoldBreath") then "\n" .. Text.HoldingBreath else "")
L373: local prompt = current:GetAttribute(Tags.Attr.InteractPrompt)
L377: current:GetAttribute("InteractAlt") :: string?,
L378: current:GetAttribute("Locked") == true,
L398: local id = part:GetAttribute(Tags.Attr.InteractId)
L419: if candidate:IsA("BasePart") and candidate:GetAttribute(Tags.Attr.InteractId) == expectedId then
~~~

## src/ReplicatedStorage/Client/Controllers/LightingController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/LightingController.luau) · 248 linhas · SHA-256: 5e8a465e6c38b9764b6dc727ac4f7d886748614c44de067dc3858936268b5a64

### Funções nomeadas / callbacks atribuídos

~~~text
L28: local function rgb(values: { number }): Color3
L32: function controller.setDanger(value: number)
L36: function controller.setFilter(item: StoreCatalog.Item)
L48: local function underRoof(position: Vector3): boolean
L61: function controller.debugState(): { [string]: any }
L80: function controller.Init()
L108: function controller.Start()
L109: local function syncBase()
L186: bridge.OnInvoke = function(command: string, position: Vector3?, target: Vector3?): any
~~~

### Dependências literais

- L6: @game/ReplicatedStorage/Shared/Game/LightingProfile → [fonte](../../src/ReplicatedStorage/Shared/Game/LightingProfile.luau)
- L7: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L8: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L9: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)
- L222: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L223: ./WorldFxController → [fonte](../../src/ReplicatedStorage/Client/Controllers/WorldFxController.luau)

### Listeners / registros / callbacks

~~~text
L118: Lighting:GetAttributeChangedSignal("BaseFogEnd"):Connect(syncBase)
L119: RunService.RenderStepped:Connect(function(dt)
L186: bridge.OnInvoke = function(command: string, position: Vector3?, target: Vector3?): any
L227: RunService:BindToRenderStep("S9LightingQA", Enum.RenderPriority.Last.Value + 5, function()
~~~

### Estado observado / publicado

~~~text
L110: local value = Lighting:GetAttribute("BaseFogEnd")
L117: power = if Lighting:GetAttribute("S9PowerOn") == true then 1 else 0
L118: Lighting:GetAttributeChangedSignal("BaseFogEnd"):Connect(syncBase)
L136: power = Profile.approach(power, if Lighting:GetAttribute("S9PowerOn") == true then 1 else 0, delta)
L138: forest = Profile.approach(forest, if world and world:GetAttribute("ForestActive") == true then 1 else 0, delta)
L167: local cinema = budget.depth and player:GetAttribute("CinematicActive") == true and Settings.motionEnabled()
L199: player:SetAttribute("ModeMenuOpen", false)
L232: player:SetAttribute("ModeMenuOpen", false)
~~~

## src/ReplicatedStorage/Client/Controllers/MainMenuController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/MainMenuController.luau) · 1841 linhas · SHA-256: f38f6a54524086ce6c483defdae527687d6d9c5a6b5677f65ec2f710ed3e2830

### Funções nomeadas / callbacks atribuídos

~~~text
L96: local function px(value: string): string
L100: local function campaign(): Instance?
L104: local function json(name: string, fallback: any): any
L115: local function number(value: number): string
L121: local function clock(seconds: number): string
L131: local function label(props: { [string]: any }): TextLabel
L150: local function note(props: { [string]: any }): TextLabel
L166: local function frame(props: { [string]: any }, children: { any }?): Frame
L174: local function stroke(color: Color3, thickness: number?, transparency: number?): Instance
L183: local function button(props: { [string]: any }, onClick: () -> ()): TextButton
L215: local function say(key: string?)
L233: local function invoke(name: string, ...: any): (any, string?)
L252: local function store(action: string, arg: string?): any
L265: local function buyProduct(key: string)
L276: local function clearBody(): Frame?
L288: local function sectionTitle(parent: Instance, text: string, order: number): TextLabel
L298: local function pips(parent: Instance, filled: number, total: number, position: UDim2)
L315: local function storyCleared(): ({ [number]: boolean }, { [number]: boolean })
L328: local function storyPreview(): (number, string)
L352: local function modeCard(
L438: local function buildPlay(parent: Frame)
L816: local function effectText(id: string, level: number): string
L829: local function buildPerks(b: Frame)
L1075: local function fetchServers()
L1090: local function buildServers(b: Frame)
L1183: local function fetchFriends()
L1199: local function invite()
L1214: local function buildFriends(b: Frame)
L1332: local function renderTab()
L1368: local function selectTab(id: TabId)
L1382: local function build(): ScreenGui
L1752: function Controller.debugState(): { [string]: any }
L1762: function Controller.select(id: string)
L1766: function Controller.Start()
L1795: local function qaVote()
~~~

### Dependências literais

- L27: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L28: @game/ReplicatedStorage/Shared/Game/Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L29: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L30: @game/ReplicatedStorage/Shared/Game/Perks → [fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau)
- L31: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L32: @game/ReplicatedStorage/Shared/Game/StoryRewards → [fonte](../../src/ReplicatedStorage/Shared/Game/StoryRewards.luau)
- L33: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L34: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L35: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L36: ../UI/Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)
- L37: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L38: ./CinematicController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CinematicController.luau)
- L39: ./StoreController → [fonte](../../src/ReplicatedStorage/Client/Controllers/StoreController.luau)
- L40: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)
- L41: ../Creature/TungTungRig → [fonte](../../src/ReplicatedStorage/Client/Creature/TungTungRig.luau)

### Listeners / registros / callbacks

~~~text
L202: b.MouseEnter:Connect(function()
L205: b.MouseLeave:Connect(function()
L208: b.Activated:Connect(function()
L792: connection = RunService.RenderStepped:Connect(function(dt)
L1508: navButton.MouseEnter:Connect(function()
L1513: navButton.MouseLeave:Connect(function()
L1516: navButton.Activated:Connect(function()
L1643: RunService.RenderStepped:Connect(function(dt)
L1785: player:GetAttributeChangedSignal(name):Connect(function()
L1804: player:GetAttributeChangedSignal("ModeQARequest"):Connect(qaVote)
L1808: RunService:BindToRenderStep("S9MainMenu", Enum.RenderPriority.Last.Value, function()
~~~

### Rede

~~~text
L240: return Remotes.clientFunction(name, 5):InvokeServer(table.unpack(args, 1, args.n))
L1800: Remotes.clientFunction("SelectGameMode"):InvokeServer(mode)
~~~

### Estado observado / publicado

~~~text
L105: local raw = player:GetAttribute(name)
L340: local multiplier = if player:GetAttribute("StoryPass") == true then StoryRewards.PassMultiplier else 1
L428: local count = if state then state:GetAttribute(if id == "Story" then "StoryVotes" else "StandardVotes") else 0
L430: local mine = player:GetAttribute("GameModeVote") == id
L504: if player:GetAttribute("StoryPass") == true then
L563: local fichas = (tonumber(player:GetAttribute("BoostFichasUntil")) or 0) - now
L564: local xp = (tonumber(player:GetAttribute("BoostXpUntil")) or 0) - now
L572: if player:GetAttribute("Vip") == true then
L651: then math.ceil((tonumber(state:GetAttribute("NextStageAt")) or 0) - workspace:GetServerTimeNow())
L668: local vote = other:GetAttribute("GameModeVote")
L1719: local xp = tonumber(player:GetAttribute("Xp")) or 0
L1723: local titleId = player:GetAttribute("Title")
L1726: (if titleItem then titleItem.name else "") .. (if player:GetAttribute("Vip") == true then " · VIP" else "")
L1730: `💰 {number(tonumber(player:GetAttribute("Fichas")) or 0)} FICHAS   💎 {number(
L1731: tonumber(player:GetAttribute("Creditos")) or 0
L1736: badge.Visible = player:GetAttribute("DailyClaimable") == true
L1737: or (tonumber(player:GetAttribute("SpinsLeft")) or 0) > 0
L1767: if GameState.wait():GetAttribute("CampaignActive") ~= true then
L1785: player:GetAttributeChangedSignal(name):Connect(function()
L1796: local command = player:GetAttribute("ModeQARequest")
L1804: player:GetAttributeChangedSignal("ModeQARequest"):Connect(qaVote)
L1813: local open = state:GetAttribute("Phase") == "Lobby" and player:GetAttribute("OpeningActive") ~= true
L1814: player:SetAttribute("ModeMenuOpen", open)
~~~

## src/ReplicatedStorage/Client/Controllers/RetroFxController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/RetroFxController.luau) · 164 linhas · SHA-256: 66d93f547df15bd03ec4c8635c77a407432f2a9c9cc432892b960a55d8725f90

### Funções nomeadas / callbacks atribuídos

~~~text
L26: local function buildScanlines(container: Frame, height: number)
L40: local function edge(parent: Instance, anchor: Vector2, position: UDim2, size: UDim2, rotation: number)
L58: local function buildOverlay(): ScreenGui
L105: function RetroFxController.Init()
L109: function RetroFxController.Start()
~~~

### Dependências literais

- L12: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L13: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)
- L14: ./FearController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FearController.luau)

### Listeners / registros / callbacks

~~~text
L118: RunService.RenderStepped:Connect(function(dt: number)
~~~

## src/ReplicatedStorage/Client/Controllers/ScreenFxController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/ScreenFxController.luau) · 240 linhas · SHA-256: 1ac0b96e572c4bb75f2ed8a4541f60f7ddd9933fb5cb117ff1ac26a4b41e79d0

### Funções nomeadas / callbacks atribuídos

~~~text
L34: function ScreenFxController.capture()
L38: function ScreenFxController.pulse(color: Color3)
L45: function ScreenFxController.reset()
L57: function ScreenFxController.debugState(): { [string]: any }
L70: function ScreenFxController.Init()
L171: function ScreenFxController.Start()
~~~

### Dependências literais

- L7: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L8: @game/ReplicatedStorage/Shared/Game/PixelText → [fonte](../../src/ReplicatedStorage/Shared/Game/PixelText.luau)
- L9: @game/ReplicatedStorage/Shared/Game/ThreatPresentation → [fonte](../../src/ReplicatedStorage/Shared/Game/ThreatPresentation.luau)
- L10: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L11: ./FearController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FearController.luau)
- L12: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)
- L13: ./LightingController → [fonte](../../src/ReplicatedStorage/Client/Controllers/LightingController.luau)

### Listeners / registros / callbacks

~~~text
L179: Lighting:GetAttributeChangedSignal("BaseFogEnd"):Connect(function()
L186: RunService.RenderStepped:Connect(function(dt)
~~~

### Estado observado / publicado

~~~text
L71: local initialFog = Lighting:GetAttribute("BaseFogEnd")
L172: GameState.observe(function(next)
L179: Lighting:GetAttributeChangedSignal("BaseFogEnd"):Connect(function()
L180: local value = Lighting:GetAttribute("BaseFogEnd")
L197: local playing = Presentation.playing(s.phase, player:GetAttribute("CampaignStatus") :: string?)
~~~

## src/ReplicatedStorage/Client/Controllers/SettingsController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau) · 478 linhas · SHA-256: 673022ab7533e5ebf0fa66744a49712bdd482a6b55846d3484bea472de2643e1

### Funções nomeadas / callbacks atribuídos

~~~text
L57: local function refreshMenu()
L104: function SettingsController.visualBudget(): Quality.Budget
L107: function SettingsController.shadersEnabled(): boolean
L110: function SettingsController.setVisual(key: string, value: number)
L132: function SettingsController.toggleMenu()
L138: function SettingsController.get(key: Key): boolean
L142: function SettingsController.set(key: Key, value: boolean)
L157: function SettingsController.toggle(key: Key): boolean
L163: function SettingsController.toggleMotion(): boolean
L171: function SettingsController.motionEnabled(): boolean
L175: function SettingsController.onChanged(listener: (key: Key, value: boolean) -> ())
L179: function SettingsController.Init()
L243: local function option(key: string, index: number, column: number, callback: () -> ())
L321: function SettingsController.Start()
L327: local function load()
L370: bridge.OnInvoke = function(key: string, value: number?): any
L382: local function qaVisualRequest()
~~~

### Dependências literais

- L21: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L22: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L23: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L24: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L25: ../UI/Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)
- L26: @game/ReplicatedStorage/Shared/Game/VisualQuality → [fonte](../../src/ReplicatedStorage/Shared/Game/VisualQuality.luau)
- L27: @game/ReplicatedStorage/Shared/Game/HousePreferences → [fonte](../../src/ReplicatedStorage/Shared/Game/HousePreferences.luau)
- L28: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)

### Listeners / registros / callbacks

~~~text
L260: button.Activated:Connect(callback)
L304: RunService.RenderStepped:Connect(function()
L363: Players.LocalPlayer:GetAttributeChangedSignal("HousePreferences"):Connect(load)
L364: Players.LocalPlayer:GetAttributeChangedSignal("HousePreferencesSaved"):Connect(refreshMenu)
L365: Players.LocalPlayer:GetAttributeChangedSignal("HousePreferencesSaveMode"):Connect(refreshMenu)
L370: bridge.OnInvoke = function(key: string, value: number?): any
L417: Players.LocalPlayer:GetAttributeChangedSignal("VisualQARequest"):Connect(qaVisualRequest)
L451: UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
~~~

### Rede

~~~text
L122: Remotes.clientEvent("SetHousePreference"):FireServer(key, value)
L149: Remotes.clientEvent("SetHousePreference"):FireServer(key, if value then 1 else 0)
L292: Remotes.clientEvent("SetHousePreference"):FireServer(key, mixes[key])
L426: Remotes.clientEvent("SetHousePreference"):FireServer(key, value)
~~~

### Estado observado / publicado

~~~text
L86: local saved = Players.LocalPlayer:GetAttribute("HousePreferencesSaved")
L87: local current = Players.LocalPlayer:GetAttribute("HousePreferences")
L90: elseif saved ~= nil and saved == current then (if Players.LocalPlayer:GetAttribute(
L127: Players.LocalPlayer:SetAttribute("VisualQualityApplied", SettingsController.visualBudget().name)
L128: Players.LocalPlayer:SetAttribute("ShadersApplied", shaders)
L135: Players.LocalPlayer:SetAttribute("ComfortMenuOpen", menu.Visible)
L290: Players.LocalPlayer:SetAttribute("Mix_" .. key, mixes[key])
L298: Players.LocalPlayer:SetAttribute("ComfortMenuOpen", false)
L328: local raw = Players.LocalPlayer:GetAttribute("HousePreferences")
L358: Players.LocalPlayer:SetAttribute("Mix_" .. key, mixes[key])
L363: Players.LocalPlayer:GetAttributeChangedSignal("HousePreferences"):Connect(load)
L364: Players.LocalPlayer:GetAttributeChangedSignal("HousePreferencesSaved"):Connect(refreshMenu)
L365: Players.LocalPlayer:GetAttributeChangedSignal("HousePreferencesSaveMode"):Connect(refreshMenu)
L383: local raw = Players.LocalPlayer:GetAttribute("VisualQARequest")
L417: Players.LocalPlayer:GetAttributeChangedSignal("VisualQARequest"):Connect(qaVisualRequest)
L435: Players.LocalPlayer:SetAttribute("ComfortMenuOpen", menu.Visible)
L447: Players.LocalPlayer:SetAttribute("ComfortMenuOpen", menu.Visible)
~~~

## src/ReplicatedStorage/Client/Controllers/SpectatorController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/SpectatorController.luau) · 102 linhas · SHA-256: 9c6ada048d7eaee6c9d761b0ae7ccb010c351c37693011149e66d729752fc1bf

### Funções nomeadas / callbacks atribuídos

~~~text
L17: function Controller.debugState(): { [string]: any }
L21: function Controller.cycle(step: number)
L25: function Controller.Start()
~~~

### Dependências literais

- L7: @game/ReplicatedStorage/Shared/Game/SpectatorRules → [fonte](../../src/ReplicatedStorage/Shared/Game/SpectatorRules.luau)
- L8: @game/ReplicatedStorage/Shared/Game/PixelText → [fonte](../../src/ReplicatedStorage/Shared/Game/PixelText.luau)
- L9: ./CameraController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CameraController.luau)
- L10: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)

### Listeners / registros / callbacks

~~~text
L45: UserInputService.InputBegan:Connect(function(input, processed)
L55: RunService.RenderStepped:Connect(function(dt)
~~~

### Estado observado / publicado

~~~text
L62: local phase = if state then state:GetAttribute("Phase") else ""
L63: local allowed = Rules.allowed(tostring(phase), player:GetAttribute("CampaignStatus") :: string?)
L76: if other ~= player and other:GetAttribute("CampaignStatus") == "Active" and h and h.Health > 0 and head then
L94: if player:GetAttribute("CampaignStatus") == "Downed"
~~~

## src/ReplicatedStorage/Client/Controllers/StoreController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/StoreController.luau) · 1450 linhas · SHA-256: 80ffefe6e1f25ae44f1a00c60883374236de8e8f0ee1460146614db0705ff6be

### Funções nomeadas / callbacks atribuídos

~~~text
L57: local function rgb(c: StoreCatalog.RGB): Color3
L62: local function px(value: string): string
L66: local function attr(name: string, fallback: any): any
L74: local function jsonSet(name: string): { [string]: boolean }
L87: local function isOwned(item: StoreCatalog.Item, owned: { [string]: boolean }): boolean
L97: local function equippedId(kind: StoreCatalog.ItemKind): string
L103: local function allowed(): boolean
L108: local function label(props: { [string]: any }): TextLabel
L122: local function button(props: { [string]: any }, onClick: () -> ()): TextButton
L149: local function setMessage(key: string?)
L158: local function request(action: string, arg: string?): Types.Result<any>?
L174: local function track(event: string, offer: string?)
L180: local function showToast(lines: { string }, color: Color3?, duration: number?)
L219: local function toast(lines: { string }, color: Color3?, duration: number?)
L223: local function itemName(id: string): string
L228: local function onNotice(payload: { [string]: any })
L306: local function clearContent(): ScrollingFrame?
L319: local function setLayout(c: ScrollingFrame, grid: boolean)
L341: local function card(parent: Instance, order: number, accent: Color3): Frame
L360: local function renderShop(c: ScrollingFrame)
L475: local function showOdds(title: string, lines: { string })
L532: local function percent(value: number): string
L539: local function oddsLines(chest: StoreCatalog.Chest): { string }
L555: local function playReel(
L626: local function renderChests(c: ScrollingFrame)
L703: local function renderDaily(c: ScrollingFrame)
L849: local function renderCollection(c: ScrollingFrame)
L907: local function rewardText(reward: StoreCatalog.Reward?): string
L924: local function renderSeason(c: ScrollingFrame)
L1042: local function renderRobux(c: ScrollingFrame)
L1087: render = function()
L1128: local function setOpen(value: boolean)
L1157: local function build()
L1358: function StoreController.isOpen(): boolean
L1362: function StoreController.setOpen(value: boolean)
L1367: function StoreController.openTab(key: string)
L1380: function StoreController.Init()
L1384: function StoreController.Start()
~~~

### Dependências literais

- L19: @game/ReplicatedStorage/Shared/Game/Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L20: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L21: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L22: @game/ReplicatedStorage/Shared/Game/Perks → [fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau)
- L23: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L24: @game/ReplicatedStorage/Shared/Game/Season → [fonte](../../src/ReplicatedStorage/Shared/Game/Season.luau)
- L25: @game/ReplicatedStorage/Shared/Game/SeasonCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/SeasonCatalog.luau)
- L26: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L27: @game/ReplicatedStorage/Shared/Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)
- L28: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L29: ../UI/Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)
- L30: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)

### Listeners / registros / callbacks

~~~text
L142: b.Activated:Connect(function()
L1332: RunService.RenderStepped:Connect(function()
L1394: player:GetAttributeChangedSignal("CampaignStatus"):Connect(function()
L1424: player:GetAttributeChangedSignal(name):Connect(function()
L1433: remote.OnClientEvent:Connect(function(payload: any)
L1440: UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
~~~

### Rede

~~~text
L164: return Remotes.clientFunction("Store", 5):InvokeServer(action, arg)
L175: Remotes.clientEvent("StoreTrack", 5):FireServer(event, offer)
L1431: local ok, remote = pcall(Remotes.clientEvent, "StoreNotice", 30)
~~~

### Estado observado / publicado

~~~text
L67: local value = player:GetAttribute(name)
L104: local status = player:GetAttribute("CampaignStatus")
L186: if player:GetAttribute("CinematicHold") == true then
L1342: toastHolder.Visible = player:GetAttribute("ModeMenuOpen") ~= true
L1343: and player:GetAttribute("FieldGuideOpen") ~= true
L1344: and player:GetAttribute("ComfortMenuOpen") ~= true
L1345: and player:GetAttribute("TouchBackpackOpen") ~= true
L1385: GameState.observe(function(snapshot)
L1394: player:GetAttributeChangedSignal("CampaignStatus"):Connect(function()
L1424: player:GetAttributeChangedSignal(name):Connect(function()
~~~

## src/ReplicatedStorage/Client/Controllers/StoryController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/StoryController.luau) · 107 linhas · SHA-256: 97d93dce4e1f4ce7a5b87f9a7f9d94206ec4bd617e4ae2345d0e486039414d81

### Funções nomeadas / callbacks atribuídos

~~~text
L14: function Controller.Start()
L27: local function text(name: string, y: number, height: number): TextLabel
~~~

### Dependências literais

- L6: @game/ReplicatedStorage/Shared/Game/StoryCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoryCatalog.luau)
- L7: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L8: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L9: ./CinematicController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CinematicController.luau)
- L10: ./TransitionController → [fonte](../../src/ReplicatedStorage/Client/Controllers/TransitionController.luau)

### Listeners / registros / callbacks

~~~text
L58: RunService:BindToRenderStep("S9Story", Enum.RenderPriority.Camera.Value - 1, function()
~~~

### Estado observado / publicado

~~~text
L15: if GameState.wait():GetAttribute("CampaignActive") ~= true then
L59: local active = state:GetAttribute("GameMode") == "Story" and state:GetAttribute("Phase") ~= "Lobby"
L60: gui.Enabled = active and player:GetAttribute("CinematicActive") ~= true
L67: local stage = (state:GetAttribute("Stage") or 0) :: number
L73: local endsAt = (state:GetAttribute("StorySceneEndsAt") or 0) :: number
L74: local key = `{state:GetAttribute("StorySceneSerial")}:{stage}`
L81: local phase = tostring(state:GetAttribute("Phase"))
L82: local solved = (state:GetAttribute("Solved") or 0) :: number
L94: local remaining = math.max(0, math.ceil((tonumber(state:GetAttribute("LobbyReturnAt")) or now) - now))
L101: and player:GetAttribute("FieldGuideOpen") ~= true
~~~

## src/ReplicatedStorage/Client/Controllers/TelevisionController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/TelevisionController.luau) · 63 linhas · SHA-256: 5d1d869e2415cbbfbc8227aa4678b441a3399ba3e270c75c4b6ce07b04ffb8a8

### Funções nomeadas / callbacks atribuídos

~~~text
L10: function Controller.Start()
L13: local function track(inst: Instance)
~~~

### Dependências literais

- L7: @game/ReplicatedStorage/Shared/Game/HouseBroadcast → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseBroadcast.luau)
- L8: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)

### Listeners / registros / callbacks

~~~text
L21: CollectionService:GetInstanceAddedSignal("HouseTelevision"):Connect(track)
L22: CollectionService:GetInstanceRemovedSignal("HouseTelevision"):Connect(function(inst)
L27: RunService.Heartbeat:Connect(function(dt)
~~~

### Estado observado / publicado

~~~text
L38: local stage = math.clamp(tonumber(state and state:GetAttribute("Stage")) or 1, 1, #Broadcast)
L47: local phase = state and state:GetAttribute("Phase")
L61: Players.LocalPlayer:SetAttribute("TelevisionReady", true)
~~~

## src/ReplicatedStorage/Client/Controllers/TensionController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/TensionController.luau) · 406 linhas · SHA-256: e6063e7c58ecd68090ae84fec07432c5a1071390ebaedce34bcfc710b078a1a7

### Funções nomeadas / callbacks atribuídos

~~~text
L34: local function cleanup()
L54: local function rootPart(): BasePart?
L60: local function context(): Director.Context
L92: local function soundAt(name: string, position: Vector3, volume: number?, speed: number?)
L96: local function parameters(): RaycastParams
L115: local function apparition(name: string, token: number)
L177: local function moveVisual(name: string, token: number)
L237: local function perform(name: string, token: number)
L296: local function schedule(name: string, silence: boolean)
L334: function Controller.preview(name: string): boolean
L350: function Controller.debugState(): { [string]: any }
L362: function Controller.Start()
~~~

### Dependências literais

- L8: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L9: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L10: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L11: @game/ReplicatedStorage/Shared/Game/TensionDirector → [fonte](../../src/ReplicatedStorage/Shared/Game/TensionDirector.luau)
- L12: @game/ReplicatedStorage/Shared/Game/ThreatPresentation → [fonte](../../src/ReplicatedStorage/Shared/Game/ThreatPresentation.luau)
- L13: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L14: ./FearController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FearController.luau)
- L15: ./FlashlightController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FlashlightController.luau)
- L16: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)
- L17: ./WorldFxController → [fonte](../../src/ReplicatedStorage/Client/Controllers/WorldFxController.luau)

### Listeners / registros / callbacks

~~~text
L374: RunService.RenderStepped:Connect(function(dt)
~~~

### Estado observado / publicado

~~~text
L64: local status = player:GetAttribute("CampaignStatus") :: string?
L66: if root then (root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Dormant" else "Dormant",
L67: if root then root:GetAttribute(Tags.Attr.ThreatTargetUserId) :: number? else nil,
L74: local stage = (campaign:GetAttribute("Stage") :: number?) or 0
L75: local solved = (campaign:GetAttribute("Solved") :: number?) or 0
L81: creatureActive = root ~= nil and root:GetAttribute(Tags.Attr.CreatureActive) == true,
L88: hidden = type(player:GetAttribute("Hidden")) == "string" and player:GetAttribute("Hidden") ~= "",
L193: and item:GetAttribute("DoorState") == "closed"
L363: GameState.observe(function(next)
~~~

## src/ReplicatedStorage/Client/Controllers/ThreatFeedbackController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/ThreatFeedbackController.luau) · 96 linhas · SHA-256: 14c2e4557ec15852ff57b538467b1f53a06a8d16ce3b792ed703e737aa7066ab

### Funções nomeadas / callbacks atribuídos

~~~text
L22: local function target(): Vector3?
L35: function Controller.debugState(): { [string]: any }
L39: function Controller.Start()
~~~

### Dependências literais

- L5: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L6: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L7: @game/ReplicatedStorage/Shared/Game/ThreatPresentation → [fonte](../../src/ReplicatedStorage/Shared/Game/ThreatPresentation.luau)
- L8: ./AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L9: ./CameraController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CameraController.luau)
- L10: ./FearController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FearController.luau)
- L11: ./ScreenFxController → [fonte](../../src/ReplicatedStorage/Client/Controllers/ScreenFxController.luau)

### Listeners / registros / callbacks

~~~text
L45: RunService.RenderStepped:Connect(function()
~~~

### Estado observado / publicado

~~~text
L42: GameState.observe(function(next)
L50: local status = player:GetAttribute("CampaignStatus") :: string?
L78: (root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Dormant",
L79: root:GetAttribute(Tags.Attr.ThreatTargetUserId) :: number?,
~~~

## src/ReplicatedStorage/Client/Controllers/TouchControlsController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/TouchControlsController.luau) · 320 linhas · SHA-256: 72e1e7264cf2f20825a4168665ea9ca92b59ba35ef30be4fe5e486b73c21c977

### Funções nomeadas / callbacks atribuídos

~~~text
L22: function Controller.Start()
L49: local function button(parent: Instance, name: string, title: string): TextButton
L104: local function closePack()
L111: local function releaseBreath()
L119: local function cancel()
L217: local function stock()
~~~

### Dependências literais

- L9: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L10: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L11: ../UI/Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)
- L12: ./InteractionController → [fonte](../../src/ReplicatedStorage/Client/Controllers/InteractionController.luau)
- L13: ./GameUiController → [fonte](../../src/ReplicatedStorage/Client/Controllers/GameUiController.luau)
- L14: ./CharacterController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterController.luau)
- L15: ./FlashlightController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FlashlightController.luau)
- L16: ./CampaignController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CampaignController.luau)
- L17: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)
- L18: ./SpectatorController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SpectatorController.luau)

### Listeners / registros / callbacks

~~~text
L108: close.Activated:Connect(closePack)
L123: breath.InputBegan:Connect(function(input)
L133: breathConnection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
L142: Input.InputEnded:Connect(function(input)
L147: Input.WindowFocusReleased:Connect(cancel)
L148: GuiService.MenuOpened:Connect(cancel)
L160: player:GetAttributeChangedSignal(name):Connect(cancel)
L162: player.CharacterAdded:Connect(function()
L166: action.Activated:Connect(function()
L177: sprint.Activated:Connect(function()
L180: light.Activated:Connect(function()
L183: crouch.Activated:Connect(function()
L186: pack.Activated:Connect(function()
L190: guide.Activated:Connect(function()
L194: options.Activated:Connect(function()
L210: b.Activated:Connect(function()
L227: player:GetAttributeChangedSignal("HouseSupplies"):Connect(stock)
L240: previous.Activated:Connect(function()
L243: nextPlayer.Activated:Connect(function()
L248: RunService.RenderStepped:Connect(function(dt)
~~~

### Estado observado / publicado

~~~text
L106: player:SetAttribute("TouchBackpackOpen", false)
L121: player:SetAttribute("TouchSprint", false)
L133: breathConnection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
L160: player:GetAttributeChangedSignal(name):Connect(cancel)
L169: and (player:GetAttribute("Hidden") or "") == ""
L178: player:SetAttribute("TouchSprint", player:GetAttribute("TouchSprint") ~= true)
L188: player:SetAttribute("TouchBackpackOpen", open)
L218: local raw = player:GetAttribute("HouseSupplies")
L227: player:GetAttributeChangedSignal("HouseSupplies"):Connect(stock)
L271: local phase = if state then state:GetAttribute("Phase") else GameState.get("Phase")
L272: local status = player:GetAttribute("CampaignStatus")
L273: local cinema = player:GetAttribute("CinematicActive") == true
L275: local menu = player:GetAttribute("ComfortMenuOpen") == true or player:GetAttribute("FieldGuideOpen") == true
L276: local hidden = type(player:GetAttribute("Hidden")) == "string" and player:GetAttribute("Hidden") ~= ""
L290: light.Visible = not hidden and not note and player:GetAttribute("HasFlashlight") == true
L302: sprint.Text = if player:GetAttribute("TouchSprint") == true then "CORRER\nLIGADO" else "CORRER"
L303: sprint.BackgroundColor3 = if player:GetAttribute("TouchSprint") == true then Theme.Accent else Theme.Panel
L310: if not controls.Visible and (heldBreath or player:GetAttribute("TouchSprint") == true) then
L314: local items = HttpService:JSONDecode((state:GetAttribute("Inventory") or "{}") :: string)
~~~

## src/ReplicatedStorage/Client/Controllers/TrailerController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/TrailerController.luau) · 1184 linhas · SHA-256: 348c88eeaab7bca655909c275f5298e2a0ef13da337497683816a34c6007cb6b

### Funções nomeadas / callbacks atribuídos

~~~text
L80: local function v(x: number, y: number, z: number): Vector3
L84: local function ease(t: number): number
L89: local function lerp(a: Vector3, b: Vector3, t: number): Vector3
L94: local function dolly(a: Vector3, b: Vector3, la: Vector3, lb: Vector3, fov: number, smooth: boolean?)
L103: local function light(name: string, position: Vector3, color: Color3, range: number, brightness: number): PointLight
L124: local function spot(name: string, from: Vector3, at: Vector3, brightness: number, angle: number): SpotLight
L149: local function buildProps()
L213: local function glowGraffiti(on: boolean)
L235: local function allLightsOff()
L247: local function buildActors()
L258: local function hideAll()
L268: local function walk(i: number, a: Vector3, b: Vector3, alpha: number, kind: Actors.PoseName, pitch: number?)
L280: local function stand(i: number, at: Vector3, look: Vector3, kind: Actors.PoseName, pitch: number?, time: number?)
L289: local function creature(at: Vector3, look: Vector3, animation: string, dt: number, rate: number, yaw: number?)
L368: local function sectorCenter(): Vector3
L384: act = function()
L397: act = function(alpha)
L412: act = function(alpha, time, dt)
L434: act = function(_alpha, time, dt)
L452: act = function(_alpha, time)
L463: act = function(_alpha, time)
L482: act = function(alpha, _time, dt)
L496: act = function(alpha, _time, dt)
L508: camera = function(alpha: number): (CFrame, number)
L513: act = function(_alpha, time)
L525: camera = function(alpha: number): (CFrame, number)
L530: act = function()
L542: act = function(_alpha, time)
L553: act = function(alpha)
L568: act = function(alpha, _time, dt)
L581: local function px(value: string): string
L585: local function buildUi()
L594: local function black(name: string, fields: { [string]: any }): Frame
L789: local function slam(holder: GuiObject, scale: UIScale, local_t: number, d: number)
L798: local function renderUi(time: number)
L895: local function playCue(index: number, cue: SoundCue)
L916: local function updateSounds(time: number)
L931: local function stopSounds(keepFired: boolean?)
L944: local function shotAt(time: number): Shot?
L953: local function frame(time: number, dt: number)
L1000: local function setActive(on: boolean)
L1078: function Controller.prepare()
L1087: function Controller.play()
L1097: function Controller.arm(delay: number): number
L1106: function Controller.seek(time: number)
L1114: function Controller.stop()
L1122: function Controller.Start()
L1129: bridge.OnInvoke = function(command: string, value: any): any
~~~

### Dependências literais

- L30: @game/ReplicatedStorage/Shared/Game/Audio → [fonte](../../src/ReplicatedStorage/Shared/Game/Audio.luau)
- L31: @game/ReplicatedStorage/Shared/Game/PixelText → [fonte](../../src/ReplicatedStorage/Shared/Game/PixelText.luau)
- L32: ../Trailer/TrailerActors → [fonte](../../src/ReplicatedStorage/Client/Trailer/TrailerActors.luau)
- L33: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L34: ../UI/Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)
- L35: ./CameraController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CameraController.luau)

### Listeners / registros / callbacks

~~~text
L1129: bridge.OnInvoke = function(command: string, value: any): any
L1149: RunService:BindToRenderStep("S9Trailer", Enum.RenderPriority.Camera.Value + 4, function(dt)
~~~

### Estado observado / publicado

~~~text
L1011: player:SetAttribute("CinematicActive", on)
L1045: other:SetAttribute("TrailerWasEnabled", other.Enabled)
L1047: elseif other:GetAttribute("TrailerWasEnabled") ~= nil then
L1048: other.Enabled = other:GetAttribute("TrailerWasEnabled") == true
L1049: other:SetAttribute("TrailerWasEnabled", nil)
~~~

## src/ReplicatedStorage/Client/Controllers/TransitionController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/TransitionController.luau) · 671 linhas · SHA-256: 7656597f64ca22b04409cf254211da0fed34bb8c9f400447e75adc25f42745eb

### Funções nomeadas / callbacks atribuídos

~~~text
L70: local function r(): Refs
L75: local function bump(layer: string): number
L80: local function alive(layer: string, token: number): boolean
L85: local function stepped(layer: string, duration: number, apply: (number) -> (), existingToken: number?): boolean
L102: local function text(props: { [string]: any }): TextLabel
L118: local function black(props: { [string]: any }, children: { any }?): Frame
L130: local function lidGradient(rotation: number): Instance
L141: local function build(): Refs
L346: local function applyLetterbox(alpha: number)
L354: local function applyEyes(alpha: number)
L362: local function applyFade(alpha: number)
L367: local function updateStatic(now: number)
L403: function TransitionController.Init()
L410: function TransitionController.Start()
L456: function TransitionController.setLetterbox(on: boolean, duration: number?)
L464: function TransitionController.closeEyes(duration: number?)
L472: function TransitionController.openEyes(duration: number?, flutter: boolean?)
L475: local function hold(alpha: number, time: number): boolean
L504: function TransitionController.blink(hold: number?)
L517: function TransitionController.setFade(alpha: number, duration: number?)
L526: function TransitionController.static(duration: number, strength: number?)
L533: function TransitionController.stamp(label: string?, mode: StampMode?, clock: number?)
L548: function TransitionController.sceneShade(alpha: number)
L554: function TransitionController.reveal(duration: number?)
L561: function TransitionController.title(title: string?, subtitle: string?)
L608: function TransitionController.caption(value: string?)
L641: function TransitionController.reset()
L658: function TransitionController.debugState(): { [string]: any }
~~~

### Dependências literais

- L22: @game/ReplicatedStorage/Shared/Game/CinematicShots → [fonte](../../src/ReplicatedStorage/Shared/Game/CinematicShots.luau)
- L23: @game/ReplicatedStorage/Shared/Game/Presentation → [fonte](../../src/ReplicatedStorage/Shared/Game/Presentation.luau)
- L24: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)
- L25: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L26: ../UI/Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)

### Listeners / registros / callbacks

~~~text
L412: RunService.RenderStepped:Connect(function(dt: number)
~~~

## src/ReplicatedStorage/Client/Controllers/UiFeedbackController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/UiFeedbackController.luau) · 182 linhas · SHA-256: 5b14edda3e2cc076ddd3cbadf5efa71ca154c23d866c6720918129ca3a1d3f14

### Funções nomeadas / callbacks atribuídos

~~~text
L22: local function update(state: Feedback)
L47: local function attach(instance: Instance)
L96: local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
L144: function Controller.debugState(): { [string]: any }
L155: function Controller.Start()
~~~

### Dependências literais

- L6: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)

### Listeners / registros / callbacks

~~~text
L97: table.insert(state.connections, signal:Connect(callback))
L128: connect(instance:GetPropertyChangedSignal(property), function()
L157: gui.DescendantAdded:Connect(attach)
L161: UserInputService.InputEnded:Connect(function(input)
~~~

### Estado observado / publicado

~~~text
L48: if not instance:IsA("GuiButton") or tracked[instance] or instance:GetAttribute("PresentationFeedback") == false then
L128: connect(instance:GetPropertyChangedSignal(property), function()
~~~

## src/ReplicatedStorage/Client/Controllers/WorldFxController.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Controllers/WorldFxController.luau) · 243 linhas · SHA-256: 0e86707ca9fbccbe6054553f6fcbcd856611b45bc65f42aafcda182af7f43e66

### Funções nomeadas / callbacks atribuídos

~~~text
L31: local function selectShadows()
L82: local function step()
L130: function WorldFxController.debugState(): { [string]: any }
L152: function WorldFxController.surge(duration: number, origin: Vector3?, radius: number?)
L158: function WorldFxController.Start()
L159: local function add(instance: Instance)
~~~

### Dependências literais

- L12: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L13: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L14: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L15: @game/ReplicatedStorage/Shared/Game/LightingProfile → [fonte](../../src/ReplicatedStorage/Shared/Game/LightingProfile.luau)
- L16: ./SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)

### Listeners / registros / callbacks

~~~text
L202: workspace.DescendantAdded:Connect(add)
L203: workspace.DescendantRemoving:Connect(function(instance)
L229: RunService.RenderStepped:Connect(function(dt: number)
~~~

### Estado observado / publicado

~~~text
L91: local raw = (instance:GetAttribute("BaseBrightness") :: number?) or entry.brightness
L95: local kind = instance:GetAttribute(Tags.Attr.LightKind)
L101: then Profile.flicker(now, entry.seed, instance:GetAttribute(Tags.Attr.Flicker) == true, flashes)
L164: if instance:IsA("ParticleEmitter") and instance:GetAttribute("VisualOptional") == true then
L169: and instance:GetAttribute("VisualDetail") == true
L215: GameState.observe(function(next: GameState.Snapshot)
~~~

## src/ReplicatedStorage/Client/Creature/AdemirFaceData.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Creature/AdemirFaceData.luau) · 921 linhas · SHA-256: 33bfa737c285a0746b185a5d4726342ea87c00483c719319d3778c5aff55b1e4

## src/ReplicatedStorage/Client/Creature/AdemirPortrait.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Creature/AdemirPortrait.luau) · 100 linhas · SHA-256: 00e8d58abac50bcbb7f873d81ceda773609304db84a4d298d6114bd11976baa2

### Funções nomeadas / callbacks atribuídos

~~~text
L16: local function getPortrait(): EditableImage?
L45: function AdemirPortrait.createImage(props: { [string]: any }): ImageLabel?
L65: function AdemirPortrait.applyToRig(parts: { [string]: BasePart }, light: PointLight)
~~~

### Dependências literais

- L8: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L9: ../UI/Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L10: ./AdemirFaceData → [fonte](../../src/ReplicatedStorage/Client/Creature/AdemirFaceData.luau)

### Estado observado / publicado

~~~text
L86: head:SetAttribute("Appearance", "AdemirPhoto")
~~~

## src/ReplicatedStorage/Client/Creature/ArmadilhoRig.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Creature/ArmadilhoRig.luau) · 61 linhas · SHA-256: 924642afcf6c276d5ab21c03185b3daee623c7ec463d0041ef7682a9191752b2

### Funções nomeadas / callbacks atribuídos

~~~text
L5: function Rig.build(parent: Instance): Model
L8: local function part(name: string, p: Vector3, size: Vector3, color: Color3): BasePart
~~~

## src/ReplicatedStorage/Client/Creature/ClipCodec.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Creature/ClipCodec.luau) · 132 linhas · SHA-256: 5656d08915642f4ec884f7f6e00166ca437cffff632982022fde7ba4b52ee36f

### Funções nomeadas / callbacks atribuídos

~~~text
L33: function ClipCodec.base64Decode(text: string): buffer
L64: function ClipCodec.decode(clip: RawClip, bones: { string }, posRange: number): Decoded
L106: function ClipCodec.locate(decoded: Decoded, time: number): (number, number, number)
L116: function ClipCodec.rotation(decoded: Decoded, frame: number, bone: number): (number, number, number, number)
L123: function ClipCodec.position(decoded: Decoded, frame: number, bone: number): (number, number, number)
~~~

## src/ReplicatedStorage/Client/Creature/Poses.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Creature/Poses.luau) · 193 linhas · SHA-256: cee5b9ee7e9b7a84a26a7c2dd6a488f0e1a2c95a5dbc00b191ca13bdd13a37d7

### Funções nomeadas / callbacks atribuídos

~~~text
L33: local function pose(values: { [string]: any }): Pose
~~~

## src/ReplicatedStorage/Client/Creature/Rig.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Creature/Rig.luau) · 172 linhas · SHA-256: d10b74eadeecc2b01d2ac4da960e62e06f38019e5753a9288a97c102ba8f352c

### Funções nomeadas / callbacks atribuídos

~~~text
L62: function Rig.build(parent: Instance): Rig
L118: function Rig.solve(rig: Rig, base: CFrame, pose: Poses.Pose, extraNeckYaw: number): { CFrame }
~~~

### Dependências literais

- L10: ./Poses → [fonte](../../src/ReplicatedStorage/Client/Creature/Poses.luau)
- L12: ./UniformDetails → [fonte](../../src/ReplicatedStorage/Client/Creature/UniformDetails.luau)

## src/ReplicatedStorage/Client/Creature/TungTungClips.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Creature/TungTungClips.luau) · 833 linhas · SHA-256: 20ed1edde28bbb7c2fce17b370e9ffa000ca66e79453be52077141e966574af7

## src/ReplicatedStorage/Client/Creature/TungTungRig.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Creature/TungTungRig.luau) · 243 linhas · SHA-256: c85b50c61aadd44343f1337b9ecdeb068c5fae0122a0bd67462731450bbf146b

### Funções nomeadas / callbacks atribuídos

~~~text
L46: local function clipData(name: string): ({ { CFrame } }, ClipCodec.Decoded)
L78: function TungTungRig.available(): boolean
L84: function TungTungRig.build(parent: Instance?): TungRig?
L144: function TungTungRig.playing(rig: TungRig): ClipName?
L149: function TungTungRig.play(rig: TungRig, name: ClipName, fadeTime: number?, speed: number?)
L169: function TungTungRig.setSpeed(rig: TungRig, speed: number)
L176: function TungTungRig.cycle(rig: TungRig): number
L185: function TungTungRig.finished(rig: TungRig): boolean
L190: local function sample(track: Track, bone: number): CFrame
L202: function TungTungRig.step(rig: TungRig, dt: number, lookYaw: number?)
L239: function TungTungRig.place(rig: TungRig, base: CFrame)
~~~

### Dependências literais

- L12: ./ClipCodec → [fonte](../../src/ReplicatedStorage/Client/Creature/ClipCodec.luau)
- L13: ./TungTungClips → [fonte](../../src/ReplicatedStorage/Client/Creature/TungTungClips.luau)

## src/ReplicatedStorage/Client/Creature/UniformDetails.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Creature/UniformDetails.luau) · 105 linhas · SHA-256: c40c9cc4142ee3687dadaf552e37be6e2ed1d91ca8fa51fbbb1076ded18d4124

## src/ReplicatedStorage/Client/Main.client.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Main.client.luau) · 57 linhas · SHA-256: c93e6bbbcb8693a799d7db609a8c4e0b59df9dd8cd4e0f00cbbbd8fa4aa137b3

### Dependências literais

- L12: @game/ReplicatedStorage/Shared/Loader → [fonte](../../src/ReplicatedStorage/Shared/Loader.luau)
- L13: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L20: ./Controllers/SettingsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SettingsController.luau)
- L21: ./Controllers/TransitionController → [fonte](../../src/ReplicatedStorage/Client/Controllers/TransitionController.luau)
- L22: ./Controllers/AudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/AudioController.luau)
- L23: ./Controllers/CharacterController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterController.luau)
- L24: ./Controllers/CameraController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CameraController.luau)
- L25: ./Controllers/CharacterAnimatorController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CharacterAnimatorController.luau)
- L26: ./Controllers/BodyAudioController → [fonte](../../src/ReplicatedStorage/Client/Controllers/BodyAudioController.luau)
- L27: ./Controllers/FlashlightController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FlashlightController.luau)
- L28: ./Controllers/FearController → [fonte](../../src/ReplicatedStorage/Client/Controllers/FearController.luau)
- L29: ./Controllers/LightingController → [fonte](../../src/ReplicatedStorage/Client/Controllers/LightingController.luau)
- L30: ./Controllers/RetroFxController → [fonte](../../src/ReplicatedStorage/Client/Controllers/RetroFxController.luau)
- L31: ./Controllers/WorldFxController → [fonte](../../src/ReplicatedStorage/Client/Controllers/WorldFxController.luau)
- L32: ./Controllers/ArtController → [fonte](../../src/ReplicatedStorage/Client/Controllers/ArtController.luau)
- L33: ./Controllers/TensionController → [fonte](../../src/ReplicatedStorage/Client/Controllers/TensionController.luau)
- L34: ./Controllers/ScreenFxController → [fonte](../../src/ReplicatedStorage/Client/Controllers/ScreenFxController.luau)
- L35: ./Controllers/ThreatFeedbackController → [fonte](../../src/ReplicatedStorage/Client/Controllers/ThreatFeedbackController.luau)
- L36: ./Controllers/CreatureVisualController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CreatureVisualController.luau)
- L37: ./Controllers/GameUiController → [fonte](../../src/ReplicatedStorage/Client/Controllers/GameUiController.luau)
- L38: ./Controllers/InteractionController → [fonte](../../src/ReplicatedStorage/Client/Controllers/InteractionController.luau)
- L39: ./Controllers/HudController → [fonte](../../src/ReplicatedStorage/Client/Controllers/HudController.luau)
- L40: ./Controllers/HapticsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/HapticsController.luau)
- L41: ./Controllers/CosmeticController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CosmeticController.luau)
- L42: ./Controllers/StoreController → [fonte](../../src/ReplicatedStorage/Client/Controllers/StoreController.luau)
- L43: ./Controllers/CampaignController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CampaignController.luau)
- L44: ./Controllers/CoinController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CoinController.luau)
- L45: ./Controllers/TouchControlsController → [fonte](../../src/ReplicatedStorage/Client/Controllers/TouchControlsController.luau)
- L46: ./Controllers/SpectatorController → [fonte](../../src/ReplicatedStorage/Client/Controllers/SpectatorController.luau)
- L47: ./Controllers/CinematicController → [fonte](../../src/ReplicatedStorage/Client/Controllers/CinematicController.luau)
- L48: ./Controllers/MainMenuController → [fonte](../../src/ReplicatedStorage/Client/Controllers/MainMenuController.luau)
- L49: ./Controllers/ContinueController → [fonte](../../src/ReplicatedStorage/Client/Controllers/ContinueController.luau)
- L50: ./Controllers/StoryController → [fonte](../../src/ReplicatedStorage/Client/Controllers/StoryController.luau)
- L51: ./Controllers/TelevisionController → [fonte](../../src/ReplicatedStorage/Client/Controllers/TelevisionController.luau)
- L52: ./Controllers/TrailerController → [fonte](../../src/ReplicatedStorage/Client/Controllers/TrailerController.luau)
- L53: ./Controllers/UiFeedbackController → [fonte](../../src/ReplicatedStorage/Client/Controllers/UiFeedbackController.luau)

## src/ReplicatedStorage/Client/Trailer/TrailerActors.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/Trailer/TrailerActors.luau) · 270 linhas · SHA-256: 0aeaf8d67251e48a886d02d68ec1f686685c097627468239e1aaabb5abcd55ed

### Funções nomeadas / callbacks atribuídos

~~~text
L41: local function readBase(joint: Joint): CFrame
L48: local function writeBase(joint: Joint, frame: CFrame)
L56: local function setJoint(member: Member, name: string, rotation: CFrame)
L64: function TrailerActors.member(parent: Instance, shirt: Color3?): Member?
L149: function TrailerActors.pose(
L214: function TrailerActors.placeLamp(member: Member, pitch: number?, on: boolean?)
L225: function TrailerActors.hide(member: Member)
L231: function TrailerActors.creature(parent: Instance): Creature
L239: function TrailerActors.creaturePose(
L264: function TrailerActors.hideCreature(creature: Creature)
~~~

### Dependências literais

- L14: ../Creature/Poses → [fonte](../../src/ReplicatedStorage/Client/Creature/Poses.luau)
- L15: ../Creature/Rig → [fonte](../../src/ReplicatedStorage/Client/Creature/Rig.luau)

## src/ReplicatedStorage/Client/UI/Create.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/UI/Create.luau) · 40 linhas · SHA-256: 32d799a315abb6ddf5140f8213c8fa97c023bc80dd7b0d8f664df6d875effb8d

### Funções nomeadas / callbacks atribuídos

~~~text
L17: local function Create(className: string, props: { [string]: any }?, children: { any }?): Instance
~~~

## src/ReplicatedStorage/Client/UI/FieldHud.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/UI/FieldHud.luau) · 518 linhas · SHA-256: 660c56e109da7403cf044f4f7120d3823b5b70065679d5431ca487a5bd5535cc

### Funções nomeadas / callbacks atribuídos

~~~text
L16: local function corner(radius: UDim?): Instance
L20: local function stroke(color: Color3?, thickness: number?, transparency: number?): Instance
L29: local function card(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2?): Frame
L49: local function label(
L75: local function bar(parent: Instance, name: string, _icon: string, color: Color3, y: number): Bar
L112: local function slot(parent: Instance, name: string, icon: string, order: number, key: string?): Slot
L143: function Hud.build(parent: Instance)
L416: local function resize(viewport: Vector2)
L475: local function setBar(which: Bar, value: number, text: string, warn: boolean?)
L512: viewport = function()
~~~

### Dependências literais

- L7: ./Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L8: ./Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)
- L9: ./Icons → [fonte](../../src/ReplicatedStorage/Client/UI/Icons.luau)

## src/ReplicatedStorage/Client/UI/Icons.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/UI/Icons.luau) · 35 linhas · SHA-256: 6b15a21f4eb75f443f9b9313b1a462071e542c07462ed0022baa9a3ee46d1076

### Funções nomeadas / callbacks atribuídos

~~~text
L5: function Icons.draw(parent: Instance, kind: string, color: Color3)
L6: local function box(x: number, y: number, w: number, h: number, rotation: number?): Frame
~~~

### Dependências literais

- L3: ./Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)

## src/ReplicatedStorage/Client/UI/Juice.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/UI/Juice.luau) · 145 linhas · SHA-256: a09df1e396d97f4f7f3f7bba96db640d5ceeddbb3e9a9ab3fdc5540349265e38

### Funções nomeadas / callbacks atribuídos

~~~text
L14: local function scaleOf(object: GuiObject): UIScale
L23: function Juice.pop(object: GuiObject, amount: number?)
L32: function Juice.appear(object: GuiObject, delay: number?)
L43: function Juice.floatText(parent: Instance, text: string, position: UDim2, color: Color3?, size: number?, hold: number?)
L84: function Juice.confetti(parent: Instance, origin: Vector2, count: number?)
L117: function Juice.glow(stroke: UIStroke, low: number, high: number): Tween
L129: function Juice.count(from: number, to: number, duration: number, apply: (number) -> ())
~~~

### Dependências literais

- L9: ./Create → [fonte](../../src/ReplicatedStorage/Client/UI/Create.luau)
- L10: ./Theme → [fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau)

### Listeners / registros / callbacks

~~~text
L70: rise.Completed:Once(function()
L110: tween.Completed:Once(function()
L132: value.Changed:Connect(function(current)
L139: tween.Completed:Once(function()
~~~

## src/ReplicatedStorage/Client/UI/Theme.luau

[Abrir fonte](../../src/ReplicatedStorage/Client/UI/Theme.luau) · 39 linhas · SHA-256: f2e82132dfea13b7d59af57b3700cb501642c35be8001519c0663b0546ab2ebb

## src/ReplicatedStorage/Shared/Config.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Config.luau) · 331 linhas · SHA-256: 05d0f195b2f471db4aa45b5bb7e06f73e6c930e45793ccd98158be0808e2c4f5

### Dependências literais

- L7: ./Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)
- L8: ./Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)

## src/ReplicatedStorage/Shared/Game/Audio.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/Audio.luau) · 90 linhas · SHA-256: 42f21d6c61a8799fa0aebb52e9e7f9efb19dcce541ee195acc936e9b735fd731

## src/ReplicatedStorage/Shared/Game/BatteryModel.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/BatteryModel.luau) · 94 linhas · SHA-256: 14031574d9126f213bc16b03c2e171a31bcc61dc151d499c143b5bb14b1cc77e

### Funções nomeadas / callbacks atribuídos

~~~text
L25: function BatteryModel.new(charge: number?): State
L29: function BatteryModel.canTurnOn(state: State): boolean
L34: function BatteryModel.setOn(state: State, want: boolean): boolean
L45: function BatteryModel.step(state: State, dt: number, drainFactor: number?): boolean
L62: function BatteryModel.addPickup(state: State, amount: number?)
L67: function BatteryModel.leds(charge: number): number
L74: function BatteryModel.isLow(charge: number): boolean
L79: function BatteryModel.brightness(charge: number): number
L87: function BatteryModel.secondsToRecover(charge: number): number
~~~

### Dependências literais

- L12: ../Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

## src/ReplicatedStorage/Shared/Game/CampaignCatalog.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/CampaignCatalog.luau) · 98 linhas · SHA-256: 9f4f728b6ef52d2d672f965a525b84ee957a08b7ba81ed3c66ddf0c10f6c8b02

### Dependências literais

- L3: ../Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)
- L93: ./HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)

## src/ReplicatedStorage/Shared/Game/CharacterPose.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/CharacterPose.luau) · 78 linhas · SHA-256: b8b5e1ceeef10a152e1c9694ff832af9390e2dea0571267cb6e9a0aac716bdde

### Funções nomeadas / callbacks atribuídos

~~~text
L21: function CharacterPose.quantizePitch(degrees: number): number
L32: function CharacterPose.shouldSend(last: number?, current: number, since: number): boolean
L47: function CharacterPose.crouch(legLength: number, drop: number, maxAngle: number?): (number, number)
L59: function CharacterPose.lean(speed: number, walkSpeed: number, sprintSpeed: number, max: number?): number
L68: function CharacterPose.split(pitch: number): (number, number)
L73: function CharacterPose.approach(current: number, target: number, rate: number, dt: number): number
~~~

## src/ReplicatedStorage/Shared/Game/CinematicShots.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/CinematicShots.luau) · 352 linhas · SHA-256: 1d66941a430688a9c28a0b283f804134ba49535e68d9c16d42f8eaf010449960

### Funções nomeadas / callbacks atribuídos

~~~text
L40: local function v(x: number, y: number, z: number): Vec
L44: local function shot(values: Shot): Shot
L209: function CinematicShots.isCctv(s: Shot): boolean
L213: function CinematicShots.lens(s: Shot, alpha: number): number
L218: function CinematicShots.quantize(alpha: number, duration: number, fps: number): number
L224: function CinematicShots.wrap(sequence: Sequence, elapsed: number): number
L236: function CinematicShots.caption(lines: { string }?, elapsed: number, total: number): string?
L245: function CinematicShots.ease(kind: Ease, t: number): number
L257: function CinematicShots.lerp(a: Vec, b: Vec, t: number): Vec
L261: function CinematicShots.duration(sequence: Sequence): number
L270: function CinematicShots.locate(sequence: Sequence, elapsed: number): (number, number, boolean)
L283: function CinematicShots.sample(s: Shot, alpha: number): (Vec, Vec)
L289: function CinematicShots.clock(seconds: number): string
~~~

## src/ReplicatedStorage/Shared/Game/Economy.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau) · 497 linhas · SHA-256: 424b00801cd41cb1167cce77492ef2fe4d0ae93b36d880ff1f01515722ab5d67

### Funções nomeadas / callbacks atribuídos

~~~text
L52: local function emptyGranted(): Granted
L58: function Economy.xpToNext(level: number): number
L63: function Economy.levelInfo(xp: number): (number, number, number)
L73: function Economy.isOwned(data: Data, itemId: string, vip: boolean?): boolean
L87: function Economy.price(entry: Item, currency: StoreCatalog.Currency): number?
L95: function Economy.chestPool(chest: Chest): { [string]: { string } }
L108: function Economy.chestOdds(chest: Chest): { OddsLine }
L127: function Economy.dayIndex(serverTime: number): number
L132: function Economy.dailyState(data: Data, day: number): (boolean, number, Reward)
L146: function Economy.spinsLeft(data: Data, day: number, vip: boolean?): number
L154: function Economy.multiplier(vip: boolean?): number
L159: function Economy.runReward(summary: RunSummary, vip: boolean?): Reward
L180: local function grantItem(data: Data, itemId: string, granted: Granted)
L199: local function addXp(data: Data, amount: number, granted: Granted)
L231: function Economy.applyReward(data: Data, reward: Reward, into: Granted?): Granted
L260: function Economy.buyItem(data: Data, itemId: string, currency: StoreCatalog.Currency, vip: boolean?): (boolean, string?)
L281: function Economy.pickWeighted(weights: { number }, random: () -> number): number
L303: function Economy.openChest(
L334: function Economy.claimDaily(data: Data, day: number): (boolean, string?, number?, Granted?)
L344: function Economy.spin(
L368: function Economy.recordRun(data: Data, summary: RunSummary, vip: boolean?, now: number?): Granted
L390: function Economy.addTape(data: Data, tapeId: string, now: number, vip: boolean?): (boolean, Granted?)
L412: function Economy.tapeCount(data: Data): number
L420: function Economy.equip(data: Data, itemId: string, vip: boolean?): (boolean, string?)
L433: function Economy.equipped(data: Data, kind: StoreCatalog.ItemKind, vip: boolean?): string
L448: function Economy.grantProduct(
L481: function Economy.trimPurchases(data: Data, max: number)
~~~

### Dependências literais

- L10: ./Perks → [fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau)
- L11: ./StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L12: ../Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)

## src/ReplicatedStorage/Shared/Game/FearModel.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/FearModel.luau) · 107 linhas · SHA-256: 35cfcae1784944b47b8d8d71a81e92316649a6236d9bfefe0e00f2325ee0d593

### Funções nomeadas / callbacks atribuídos

~~~text
L42: function FearModel.new(): State
L46: function FearModel.target(inputs: Inputs): number
L69: function FearModel.spike(state: State, amount: number)
L75: function FearModel.levelFor(value: number, current: number): number
L87: function FearModel.step(state: State, inputs: Inputs, dt: number): boolean
L100: function FearModel.reset(state: State)
~~~

### Dependências literais

- L14: ../Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

## src/ReplicatedStorage/Shared/Game/ForestCatalog.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/ForestCatalog.luau) · 221 linhas · SHA-256: 0d74096c8d9a6629eac600a54fba7df9c3cfdea9c3390f38dc4fe3567aca510d

### Dependências literais

- L3: ../Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)

## src/ReplicatedStorage/Shared/Game/ForestCinema.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/ForestCinema.luau) · 64 linhas · SHA-256: edcdb2f93c82c4e980fefd87bb40e55bfb9a0acebbe7c82a9061b100a57dcc65

### Dependências literais

- L2: ./CinematicShots → [fonte](../../src/ReplicatedStorage/Shared/Game/CinematicShots.luau)

## src/ReplicatedStorage/Shared/Game/ForestThreat.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/ForestThreat.luau) · 17 linhas · SHA-256: 47f3a9ff27b4ff7131e1341a97bc1017f564f6a21a5ae1bf9d6916630783cbd7

### Funções nomeadas / callbacks atribuídos

~~~text
L4: function Threat.speed(chapter: number, mode: string, base: number): number
L11: function Threat.interval(chapter: number): number
L14: function Threat.dark(now: number, chapter: number): boolean
~~~

## src/ReplicatedStorage/Shared/Game/GameModes.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/GameModes.luau) · 27 linhas · SHA-256: 411ff3211cacebef1ffb7958fb5f61d3539b122d799a96f12340357d18456470

### Funções nomeadas / callbacks atribuídos

~~~text
L7: function Modes.winner(votes: Votes, members: { [number]: any }, minimum: number): (Id?, number, number)
~~~

## src/ReplicatedStorage/Shared/Game/GameState.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau) · 149 linhas · SHA-256: fc926694c116dce7c30e1166cc433f621b871e730b2725150d894ec93057b562

### Funções nomeadas / callbacks atribuídos

~~~text
L67: function GameState.serverCreate(): Configuration
L82: local function instance(): Configuration
L88: function GameState.set(name: string, value: any)
L93: function GameState.get(name: string): any
L98: function GameState.wait(timeout: number?): Configuration
L104: function GameState.snapshotOf(config: Instance): Snapshot
L105: local function attr(name: string): any
L133: function GameState.snapshot(): Snapshot
L138: function GameState.observe(callback: (snapshot: Snapshot, changed: string?) -> ()): () -> ()
~~~

### Listeners / registros / callbacks

~~~text
L141: local connection = config.AttributeChanged:Connect(function(name: string)
~~~

### Estado observado / publicado

~~~text
L76: config:SetAttribute(name, value)
L88: function GameState.set(name: string, value: any)
L90: instance():SetAttribute(name, value)
L93: function GameState.get(name: string): any
L94: return instance():GetAttribute(name)
L106: local value = config:GetAttribute(name)
L138: function GameState.observe(callback: (snapshot: Snapshot, changed: string?) -> ()): () -> ()
~~~

## src/ReplicatedStorage/Shared/Game/HouseBroadcast.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/HouseBroadcast.luau) · 46 linhas · SHA-256: 2455ab2fa162668b545c077394468e9ec108c709e7c3c698fce214be4621b4b0

### Dependências literais

- L3: ../Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)

## src/ReplicatedStorage/Shared/Game/HouseCatalog.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau) · 207 linhas · SHA-256: 19e04d590e8d5427e52a07871078ea2cde07e1804542f6f49a95797a90d4e373

### Funções nomeadas / callbacks atribuídos

~~~text
L7: local function objective(
~~~

### Dependências literais

- L3: ../Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)
- L203: ./ForestCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestCatalog.luau)

## src/ReplicatedStorage/Shared/Game/HouseEnvelope.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/HouseEnvelope.luau) · 21 linhas · SHA-256: 9f5f249a97745dbf9dd4cca98aaa20e7464081beaf839c5c0f8798619405d657

### Funções nomeadas / callbacks atribuídos

~~~text
L13: function Envelope.isGarden(x: number, z: number): boolean
~~~

## src/ReplicatedStorage/Shared/Game/HouseLayout.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/HouseLayout.luau) · 32 linhas · SHA-256: 0646204fe060b1906fac9b8c01e9c66d18a5fd597b84b2a1e105d83bf878e451

### Funções nomeadas / callbacks atribuídos

~~~text
L12: function Layout.opening(y: number): Rect?
L20: function Layout.decks(y: number): { Rect }
~~~

## src/ReplicatedStorage/Shared/Game/HousePreferences.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/HousePreferences.luau) · 57 linhas · SHA-256: 8a7cd74c867bf3de4233504a21d42007e0ba52d6ef6c353b1357addabbac4d7a

### Funções nomeadas / callbacks atribuídos

~~~text
L21: function Preferences.valid(key: string, value: any): boolean
L32: function Preferences.sanitize(raw: any): { [string]: number }
L45: function Preferences.category(clip: string): string
~~~

## src/ReplicatedStorage/Shared/Game/HouseProgression.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/HouseProgression.luau) · 25 linhas · SHA-256: 3c76986e31502db028f8fd961a9e7bc4341ff043c2d804372f2fdab4be819732

### Funções nomeadas / callbacks atribuídos

~~~text
L11: function Progress.dependencies(mode: string?, chapter: number, index: number): { number }
L17: function Progress.ready(mode: string?, chapter: number, index: number, solved: (number) -> boolean): boolean
~~~

## src/ReplicatedStorage/Shared/Game/InteractionPresentation.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/InteractionPresentation.luau) · 19 linhas · SHA-256: 538c6dd90b7b2b13a03590c5695b7a6ae9dbf978c6126b527f5b2a0cc37650e2

### Funções nomeadas / callbacks atribuídos

~~~text
L4: function Rules.allowed(phase: string, status: string?): boolean
L8: function Rules.prompt(prompt: string, alt: string?, locked: boolean, hasKey: boolean, campaign: boolean): string
L15: function Rules.pickup(kind: string?): boolean
~~~

## src/ReplicatedStorage/Shared/Game/LightingProfile.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/LightingProfile.luau) · 112 linhas · SHA-256: 6dd095cb39618a9a7261fb8ce9c138bef73334109761c82f08264a31523c20b0

### Funções nomeadas / callbacks atribuídos

~~~text
L38: function Profile.grade(indoor: number, power: number): Grade
L50: function Profile.exposure(indoor: number, power: number): number
L56: function Profile.fixture(name: string, brightness: number, range: number): (number, number)
L67: function Profile.fogEnd(base: number, danger: number): number
L71: function Profile.approach(current: number, target: number, dt: number): number
L76: function Profile.flicker(now: number, seed: number, marked: boolean, flashes: boolean): number
L87: function Profile.shadowBudget(quality: number): number
L93: function Profile.selectShadows(candidates: { Candidate }, budget: number): { [string]: boolean }
~~~

### Dependências literais

- L3: ../Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

## src/ReplicatedStorage/Shared/Game/Perks.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau) · 287 linhas · SHA-256: d1a24f14e3fdf524b33d393088de74ed9d0a4e65ced5d287f1d9d9fae7fb9850

### Funções nomeadas / callbacks atribuídos

~~~text
L150: function Perks.level(data: Data, id: string): number
L159: function Perks.factor(id: string, level: number): number
L169: function Perks.nextCost(id: string, level: number, currency: Currency): number?
L178: function Perks.count(data: Data, id: string): number
L186: function Perks.inLoadout(data: Data, id: string): boolean
L190: function Perks.boostActive(data: Data, kind: BoostKind, now: number): boolean
L196: function Perks.runMultipliers(data: Data, now: number): (number, number)
L203: function Perks.upgrade(data: Data, id: string, currency: Currency): (boolean, string?, number?)
L222: function Perks.add(data: Data, id: string, amount: number): number
L232: function Perks.buyConsumable(data: Data, id: string, currency: Currency): (boolean, string?)
L253: function Perks.consume(data: Data, id: string): boolean
L263: function Perks.setLoadout(data: Data, id: string, on: boolean): (boolean, string?)
L277: function Perks.addBoost(data: Data, kind: BoostKind, minutes: number, now: number)
~~~

### Dependências literais

- L22: ../Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)

## src/ReplicatedStorage/Shared/Game/PixelText.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/PixelText.luau) · 30 linhas · SHA-256: c7d8e3a1580bd0495701e3265495bbd3f5d8d627861a8ca3692dc76c5c037486

### Funções nomeadas / callbacks atribuídos

~~~text
L24: function PixelText.normalize(text: string): string
~~~

## src/ReplicatedStorage/Shared/Game/PlayerGuide.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/PlayerGuide.luau) · 120 linhas · SHA-256: 5dd924c4ec0731787b4de2861e7334eafcbdb5c3a25647c0012050c4af3fe701

### Funções nomeadas / callbacks atribuídos

~~~text
L21: function Guide.roomName(id: string): string
L35: function Guide.current(tasks: { Activity }): (Activity?, number)
L44: function Guide.instruction(activity: Activity, now: number, activePlayers: number?): string
L77: function Guide.objective(phase: string, status: string?, activity: Activity?): (string, string)
~~~

### Dependências literais

- L4: ./CampaignCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/CampaignCatalog.luau)
- L5: ./HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L27: ./ForestCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestCatalog.luau)

## src/ReplicatedStorage/Shared/Game/Presentation.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/Presentation.luau) · 27 linhas · SHA-256: b3367389736540a1c9c2eef52abbe0c8f8ef14d55c62c43ad74e0e7282bb3a5a

### Funções nomeadas / callbacks atribuídos

~~~text
L5: function Presentation.ease(alpha: number): number
L10: function Presentation.shade(elapsed: number, duration: number): number
L18: function Presentation.cut(alpha: number, duration: number, incoming: boolean, outgoing: boolean): number
~~~

## src/ReplicatedStorage/Shared/Game/Season.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/Season.luau) · 169 linhas · SHA-256: e05ad000221f777e21a1ea14b4b84503cb0c48c901e11ec5007ee1744c5976c3

### Funções nomeadas / callbacks atribuídos

~~~text
L34: local function emptyGranted(): Economy.Granted
L38: local function emptyResult(): SeasonGranted
L45: function Season.current(now: number): SeasonDef?
L55: function Season.daysLeft(season: SeasonDef, now: number): number
L59: function Season.maxTier(season: SeasonDef): number
L65: function Season.tierInfo(season: SeasonDef, xp: number): (number, number, number)
L74: function Season.reward(season: SeasonDef, tier: number, track: Track): StoreCatalog.Reward?
L83: function Season.runXp(summary: Economy.RunSummary): number
L96: function Season.xpOf(data: Data, season: SeasonDef): number
L100: function Season.isGranted(data: Data, season: SeasonDef, tier: number, track: Track): boolean
L111: function Season.sync(data: Data, season: SeasonDef): boolean
L120: function Season.grantReached(data: Data, season: SeasonDef, premium: boolean, into: SeasonGranted?): SeasonGranted
L144: function Season.addXp(data: Data, season: SeasonDef, amount: number, premium: boolean): SeasonGranted
L160: function Season.hasRewards(result: SeasonGranted): boolean
~~~

### Dependências literais

- L11: ./Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L12: ./SeasonCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/SeasonCatalog.luau)
- L13: ./StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L14: ../Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)

## src/ReplicatedStorage/Shared/Game/SeasonCatalog.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/SeasonCatalog.luau) · 111 linhas · SHA-256: 97137804bcdf056087bed98e586392ba95e134324cc2bb3d57cbb69fbf08199f

### Dependências literais

- L17: ./StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)

## src/ReplicatedStorage/Shared/Game/ServerList.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/ServerList.luau) · 117 linhas · SHA-256: b40124ba7475fb2ed440294add97473867a6c5a9993c77b86d99aedeebf821bd

### Funções nomeadas / callbacks atribuídos

~~~text
L30: function ServerList.validJob(job: unknown): boolean
L37: function ServerList.decode(raw: unknown, job: string): Entry?
L62: function ServerList.alive(entry: Entry, now: number): boolean
L67: function ServerList.joinable(entry: Entry, selfJob: string, now: number): (boolean, string?)
L80: local function rank(entry: Entry): number
L90: function ServerList.sorted(entries: { Entry }, selfJob: string, now: number): { Entry }
~~~

## src/ReplicatedStorage/Shared/Game/SpectatorRules.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/SpectatorRules.luau) · 23 linhas · SHA-256: caf0120c62ca93c9933683971872b71c6e6ef209ff4a221d346c258ade8fa635

### Funções nomeadas / callbacks atribuídos

~~~text
L5: function Rules.allowed(phase: string, status: string?): boolean
L10: function Rules.choose(ids: { number }, current: number?, direction: number): number?
~~~

## src/ReplicatedStorage/Shared/Game/StoreCatalog.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau) · 932 linhas · SHA-256: 9c987ba468f812f9ede55f4db31cde42f5fb96e667870b819f4fc0f69afe7165

### Funções nomeadas / callbacks atribuídos

~~~text
L124: function StoreCatalog.defaultFor(kind: ItemKind): string
L128: local function item(def: Item): Item
~~~

## src/ReplicatedStorage/Shared/Game/StoryCatalog.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/StoryCatalog.luau) · 75 linhas · SHA-256: 9cc726a23a5d8bfa0d936c6f4fb9f342e27940f16d5b35d4fa313d7ae4c1bc79

### Funções nomeadas / callbacks atribuídos

~~~text
L7: local function point(x: number, y: number, z: number): Shots.Vec
L10: local function beat(label: string, a: Shots.Vec, b: Shots.Vec, look: Shots.Vec): Shots.Shot
~~~

### Dependências literais

- L2: ./HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L3: ../Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)
- L4: ./CinematicShots → [fonte](../../src/ReplicatedStorage/Shared/Game/CinematicShots.luau)
- L6: ./HouseBroadcast → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseBroadcast.luau)

## src/ReplicatedStorage/Shared/Game/StoryRewards.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/StoryRewards.luau) · 128 linhas · SHA-256: a75a4601d4a9a75a5b8f26c9f248467b885e9e0b582d5863e19ceb6aec856086

### Funções nomeadas / callbacks atribuídos

~~~text
L51: local function scaled(reward: Reward, multiplier: number): Reward
L65: function StoryRewards.cleared(data: Data, chapter: number): boolean
L70: function StoryRewards.clearedCount(data: Data): number
L81: function StoryRewards.preview(data: Data, chapter: number, hasPass: boolean?): (string, Reward?)
L97: function StoryRewards.award(
~~~

### Dependências literais

- L13: ./Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L14: ./StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L15: ../Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)

## src/ReplicatedStorage/Shared/Game/SurfacePatterns.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/SurfacePatterns.luau) · 55 linhas · SHA-256: e43cb6aacc6fd2d7984d89ea263976438934a2e13d2b6602b4f0e2dee76fefdc

### Funções nomeadas / callbacks atribuídos

~~~text
L7: local function noise(x: number, y: number, seed: number): number
L11: function Patterns.pixels(kind: string, seed: number): buffer
~~~

## src/ReplicatedStorage/Shared/Game/Tags.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau) · 37 linhas · SHA-256: 98481348585972e135151e1a14a4041f1068ba46a8738d6197d35eab3d6d9824

## src/ReplicatedStorage/Shared/Game/TaskRewards.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/TaskRewards.luau) · 27 linhas · SHA-256: e2b2824b7825e92f9794b5e80b45a7b3f0659340fa93df8c643662040b3d5f7e

### Funções nomeadas / callbacks atribuídos

~~~text
L7: function TaskRewards.reward(contributed: boolean): Reward
L13: function TaskRewards.claim(ledger: Ledger, key: string, id: number, grant: () -> boolean): boolean
~~~

## src/ReplicatedStorage/Shared/Game/TensionDirector.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/TensionDirector.luau) · 334 linhas · SHA-256: e6fdfdd9329f1069ae9ab4fd6e1d085acff73cfee8a4e36f09730ae8f9d00913

### Funções nomeadas / callbacks atribuídos

~~~text
L169: function TensionDirector.new(random: (() -> number)?, now: number?): Director
L183: local function record(d: Director, now: number, text: string)
L190: local function desiredState(d: Director, ctx: Context): DirectorState
L217: function TensionDirector.eligible(d: Director, name: EventName, ctx: Context): boolean
L247: function TensionDirector.gap(d: Director, progress: number): number
L252: function TensionDirector.step(d: Director, ctx: Context, dt: number): Decision
L318: function TensionDirector.notify(d: Director, now: number, text: string, hold: number?)
L325: function TensionDirector.reset(d: Director, now: number)
~~~

### Dependências literais

- L17: ../Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

## src/ReplicatedStorage/Shared/Game/Text.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau) · 330 linhas · SHA-256: 7316f04b9c385223633042b52873447cf8a7c3fe0b2b3883236fd815956746dc

### Funções nomeadas / callbacks atribuídos

~~~text
L313: local function normalize(value: any): any
~~~

### Dependências literais

- L8: ./PixelText → [fonte](../../src/ReplicatedStorage/Shared/Game/PixelText.luau)

## src/ReplicatedStorage/Shared/Game/ThreatPresentation.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/ThreatPresentation.luau) · 45 linhas · SHA-256: b4177c239531e78a2ca83a58df908db9a5459392268ad714775781541bd5949b

### Funções nomeadas / callbacks atribuídos

~~~text
L7: function Presentation.playing(phase: string, status: string?): boolean
L11: function Presentation.mode(mode: string, targetId: number?, userId: number, status: string?): string
L25: function Presentation.captured(previousStatus: string?, status: string?, previousPhase: string?, phase: string): boolean
L32: function Presentation.effects(fear: number, playing: boolean, flashes: boolean, retro: boolean)
~~~

### Dependências literais

- L3: ../Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

## src/ReplicatedStorage/Shared/Game/VisualQuality.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Game/VisualQuality.luau) · 46 linhas · SHA-256: 1fd26d5e0d248178c270cdde22e134583d8da35f7f3e2b73814abbe985030f74

### Funções nomeadas / callbacks atribuídos

~~~text
L18: function Quality.resolve(preference: number, touch: boolean, savedQuality: number): number
L34: function Quality.budget(level: number, shaders: boolean): Budget
~~~

## src/ReplicatedStorage/Shared/Loader.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Loader.luau) · 74 linhas · SHA-256: 543432cf9f56cbc79b57fa3f126387b22e09de36bba10232fcbe4f58e6c11b0c

### Funções nomeadas / callbacks atribuídos

~~~text
L30: function Loader.validate(label: string, modules: { any }): { Module }
L54: local function runPhase(label: string, phase: Phase, modules: { Module })
L67: function Loader.boot(modules: { any }, options: Options): number
~~~

## src/ReplicatedStorage/Shared/Logger.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Logger.luau) · 91 linhas · SHA-256: f40e00a48ecd0d2665baad902de2a75dec18f795dd896f6f7a138ee32b57faf7

### Funções nomeadas / callbacks atribuídos

~~~text
L34: local function defaultSink(level: LogLevel, line: string)
L47: function Logger.setLevel(level: LogLevel)
L51: function Logger.getLevel(): LogLevel
L56: function Logger.setSink(newSink: Sink?)
L60: function Logger.format(scope: string, level: LogLevel, message: string, ...: any): string
L66: function Logger.new(scope: string): Logger
L67: local function emit(level: LogLevel, message: string, ...: any)
L76: debug = function(message: string, ...: any)
L79: info = function(message: string, ...: any)
L82: warn = function(message: string, ...: any)
L85: error = function(message: string, ...: any)
~~~

### Dependências literais

- L12: ./Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L13: ./Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)

## src/ReplicatedStorage/Shared/Net/Guard.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Net/Guard.luau) · 189 linhas · SHA-256: 6778403485aff7ee5a004b9ff4bc372766ebb138434d7857d42066c0f2d30489

### Funções nomeadas / callbacks atribuídos

~~~text
L33: local function fail(expected: string, value: unknown): (boolean, string?)
L37: function Guard.number(options: NumberOptions?): Validator
L63: function Guard.integer(options: NumberOptions?): Validator
L68: function Guard.string(options: StringOptions?): Validator
L93: function Guard.boolean(): Validator
L103: function Guard.literal(...: string | number | boolean): Validator
L115: function Guard.optional(validator: Validator): Validator
L125: function Guard.array(itemValidator: Validator, maxLength: number?): Validator
L159: function Guard.instanceOf(className: string): Validator
L173: function Guard.args(validators: { Validator }): (args: { n: number, [number]: unknown }) -> (boolean, string?)
~~~

## src/ReplicatedStorage/Shared/Net/RateLimiter.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Net/RateLimiter.luau) · 78 linhas · SHA-256: d3c5f059140f07fe77a45638fa97586eef70c6ca0aa3734d395297f81f6fadd7

### Funções nomeadas / callbacks atribuídos

~~~text
L33: function RateLimiter.new(options: Options): RateLimiter
L41: local function allow(key: any): boolean
L60: local function reset(key: any)
L67: local function size(): number
~~~

## src/ReplicatedStorage/Shared/Net/Remotes.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau) · 142 linhas · SHA-256: f6b07a758572ecdbc655f9779b3bf50192402ecc14c946dd0bc7b59dc1db2c26

### Funções nomeadas / callbacks atribuídos

~~~text
L51: function Remotes.names(): { string }
L60: function Remotes.kindOf(name: string): RemoteKind
L69: function Remotes.setupServer(): Folder
L93: local function serverRemote(name: string, kind: RemoteKind): Instance
L105: local function clientRemote(name: string, kind: RemoteKind, timeout: number?): Instance
L118: function Remotes.serverEvent(name: string): RemoteEvent
L122: function Remotes.serverFunction(name: string): RemoteFunction
L126: function Remotes.serverUnreliableEvent(name: string): UnreliableRemoteEvent
L130: function Remotes.clientEvent(name: string, timeout: number?): RemoteEvent
L134: function Remotes.clientFunction(name: string, timeout: number?): RemoteFunction
L138: function Remotes.clientUnreliableEvent(name: string, timeout: number?): UnreliableRemoteEvent
~~~

### Dependências literais

- L16: ../Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

### Rede

~~~text
L118: function Remotes.serverEvent(name: string): RemoteEvent
L122: function Remotes.serverFunction(name: string): RemoteFunction
L126: function Remotes.serverUnreliableEvent(name: string): UnreliableRemoteEvent
L130: function Remotes.clientEvent(name: string, timeout: number?): RemoteEvent
L134: function Remotes.clientFunction(name: string, timeout: number?): RemoteFunction
L138: function Remotes.clientUnreliableEvent(name: string, timeout: number?): UnreliableRemoteEvent
~~~

## src/ReplicatedStorage/Shared/Types.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Types.luau) · 72 linhas · SHA-256: 2e50db628e8ea7383004dbd7fbfb38eb2159578e9d1945d46e3b0b6acf7caeec

## src/ReplicatedStorage/Shared/Util/Retry.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Util/Retry.luau) · 53 linhas · SHA-256: 47bf6fc6c3d2a8c644c4e474d7e2773ce1ac957d69e1506b303952f1f6ea99f4

### Funções nomeadas / callbacks atribuídos

~~~text
L24: function Retry.delayFor(attempt: number, baseDelay: number, maxDelay: number?): number
L30: function Retry.run<T>(fn: () -> T, options: Options): (boolean, T?, string?)
~~~

## src/ReplicatedStorage/Shared/Util/TableUtil.luau

[Abrir fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau) · 70 linhas · SHA-256: 6c058404a2f7fd80cd037748cdbcb91fc8d7d5bbbdf8f8116a3abbbb78f5f57d

### Funções nomeadas / callbacks atribuídos

~~~text
L9: function TableUtil.deepCopy<T>(value: T): T
L22: function TableUtil.reconcile<T>(target: any, template: T): T
L39: function TableUtil.deepFreeze<T>(value: T): T
L50: function TableUtil.deepEqual(a: any, b: any): boolean
~~~

## src/ServerScriptService/Server/Campaign/ActivityBuilder.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/ActivityBuilder.luau) · 229 linhas · SHA-256: 2c1933a793396c2832b170dd061c5a5d8d2423b542d29ed78b88bc045011dbf9

### Funções nomeadas / callbacks atribuídos

~~~text
L25: function Builder.build(parent: Instance, plan: Generator.Plan, distance: number): Built
L149: function Builder.refresh(built: Built, tasks: { [string]: Session.TaskState }, now: number?, activePlayers: number?)
~~~

### Dependências literais

- L4: @game/ReplicatedStorage/Shared/Game/CampaignCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/CampaignCatalog.luau)
- L5: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L6: @game/ReplicatedStorage/Shared/Game/PixelText → [fonte](../../src/ReplicatedStorage/Shared/Game/PixelText.luau)
- L7: ../World/Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L8: ../World/Palette → [fonte](../../src/ServerScriptService/Server/World/Palette.luau)
- L9: ./CampaignGenerator → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignGenerator.luau)
- L10: ./CoopSession → [fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau)
- L21: ./HouseActivities → [fonte](../../src/ServerScriptService/Server/Campaign/HouseActivities.luau)

### Estado observado / publicado

~~~text
L39: model:SetAttribute("RoomLabel", Catalog.RoomNames[activity.room])
L118: focus:SetAttribute(Tags.Attr.InteractId, id)
L119: focus:SetAttribute(
L123: focus:SetAttribute(Tags.Attr.InteractDistance, distance)
L124: focus:SetAttribute(Tags.Attr.InteractEnabled, true)
L142: shutter:SetAttribute("OptionalLink", id)
L194: target.focus:SetAttribute(Tags.Attr.InteractEnabled, state ~= nil and not state.solved and not locked)
L206: target.focus:SetAttribute(Tags.Attr.InteractPrompt, prompt)
L223: lamp:SetAttribute("Progress", state.progress)
L224: lamp:SetAttribute("Solved", state.solved)
~~~

## src/ServerScriptService/Server/Campaign/CampaignGenerator.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/CampaignGenerator.luau) · 174 linhas · SHA-256: d14b8b9a1c7488888526336d5d12fb340d1f6269b072ac0ee26e0032911b3ea0

### Funções nomeadas / callbacks atribuídos

~~~text
L37: function Generator.create(seed: number, stage: number, players: number): Plan
L90: function Generator.validate(plan: Plan): (boolean, string?)
~~~

### Dependências literais

- L3: @game/ReplicatedStorage/Shared/Game/CampaignCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/CampaignCatalog.luau)
- L4: ../World/Layout → [fonte](../../src/ServerScriptService/Server/World/Layout.luau)
- L5: ../World/ProceduralLayout → [fonte](../../src/ServerScriptService/Server/World/ProceduralLayout.luau)
- L6: ./SeededRandom → [fonte](../../src/ServerScriptService/Server/Campaign/SeededRandom.luau)

## src/ServerScriptService/Server/Campaign/CampaignMode.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/CampaignMode.luau) · 20 linhas · SHA-256: c3ac759bed30c87a77a77703b4e68331bd04cd540ded9099704fa7b9aadc5b21

### Funções nomeadas / callbacks atribuídos

~~~text
L7: function Mode.enabled(): boolean
~~~

### Dependências literais

- L3: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

## src/ServerScriptService/Server/Campaign/CampaignRuntime.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/CampaignRuntime.luau) · 1302 linhas · SHA-256: 2c5efb08bd55a9cf4089a6f61ce452fe0d1edc6b112737e0f036df7f3bb37cfc

### Funções nomeadas / callbacks atribuídos

~~~text
L80: local function slotFor(id: number): number
L97: local function parts(player: Player): (Model?, BasePart?, Humanoid?)
L105: local function feedback(player: Player, message: string)
L111: local function freeze(player: Player, value: boolean)
L118: local function publish()
L204: local function clearRescues()
L211: local function spawnMember(player: Player)
L297: local function stage()
L357: local function everyoneReady(): boolean
L405: local function hasSight(player: Player, focus: BasePart, range: number): boolean
L429: local function selfRevive(player: Player, expectedVersion: number)
L453: local function capture(player: Player)
L506: local function payCompletedTasks()
L528: local function afterActivity(previous: Session.Phase)
L551: local function interact(player: Player, id: string, _action: string?): { accepted: boolean, message: string }
L558: local function response(ok: boolean, message: string)
L706: local function retryStage(player: Player): (boolean, string?)
L728: local function restartCampaign()
L780: local function tick()
L1006: function Runtime.Init()
L1025: function Runtime.Start()
L1157: local function join(player: Player)
L1173: local function assign(instance: Instance)
L1248: function Runtime.restart()
L1253: function Runtime.debugForest(chapter: number): boolean
L1271: function Runtime.setPlayerAdapter(adapter: any)
L1274: function Runtime.lose(player: Player)
L1277: function Runtime.win(player: Player)
L1282: function Runtime.getPhase(): "Loading" | "Intro" | "Playing" | "Won" | "Lost"
L1285: function Runtime.snapshot(): { [string]: any }
~~~

### Dependências literais

- L10: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L11: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L12: @game/ReplicatedStorage/Shared/Game/CampaignCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/CampaignCatalog.luau)
- L13: @game/ReplicatedStorage/Shared/Game/GameModes → [fonte](../../src/ReplicatedStorage/Shared/Game/GameModes.luau)
- L14: @game/ReplicatedStorage/Shared/Game/Perks → [fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau)
- L15: @game/ReplicatedStorage/Shared/Game/StoryCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoryCatalog.luau)
- L16: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L17: @game/ReplicatedStorage/Shared/Game/TaskRewards → [fonte](../../src/ReplicatedStorage/Shared/Game/TaskRewards.luau)
- L18: @game/ReplicatedStorage/Shared/Game/HousePreferences → [fonte](../../src/ReplicatedStorage/Shared/Game/HousePreferences.luau)
- L19: @game/ReplicatedStorage/Shared/Net/Guard → [fonte](../../src/ReplicatedStorage/Shared/Net/Guard.luau)
- L20: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L21: ../Net/ServerNet → [fonte](../../src/ServerScriptService/Server/Net/ServerNet.luau)
- L22: ../Services/WorldService → [fonte](../../src/ServerScriptService/Server/Services/WorldService.luau)
- L23: ../Services/CreatureService → [fonte](../../src/ServerScriptService/Server/Services/CreatureService.luau)
- L24: ../Services/CollectibleService → [fonte](../../src/ServerScriptService/Server/Services/CollectibleService.luau)
- L26: ../Services/PerkService → [fonte](../../src/ServerScriptService/Server/Services/PerkService.luau)
- L27: ../Services/StoreService → [fonte](../../src/ServerScriptService/Server/Services/StoreService.luau)
- L28: ./ActivityBuilder → [fonte](../../src/ServerScriptService/Server/Campaign/ActivityBuilder.luau)
- L29: ../World/Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L30: ./CoopSession → [fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau)
- L32: ./Endings → [fonte](../../src/ServerScriptService/Server/Campaign/Endings.luau)
- L33: ../Services/PlayerDataService → [fonte](../../src/ServerScriptService/Server/Services/PlayerDataService.luau)
- L1242: ../../Tests/CampaignHarness → [fonte](../../src/ServerScriptService/Tests/CampaignHarness.luau)

### Listeners / registros / callbacks

~~~text
L261: humanoid.Died:Connect(function()
L1021: CreatureService.onCapture(capture)
L1026: ServerNet.onEvent("SetHousePreference", {
L1063: playerAdapter.setNoiseHandler(CreatureService.makeNoise)
L1065: ServerNet.onInvoke(
L1110: StoreService.setContinueHandler(retryStage)
L1111: ServerNet.onInvoke("SelectGameMode", {
L1127: ServerNet.onInvoke("Interact", {
L1134: ServerNet.onInvoke("RequestRestart", {
L1148: ServerNet.onEvent(
L1172: player.CharacterAdded:Connect(function(character)
L1181: character.DescendantAdded:Connect(assign)
L1186: Players.PlayerAdded:Connect(join)
L1187: Players.PlayerRemoving:Connect(function(player)
~~~

### Rede

~~~text
L1026: ServerNet.onEvent("SetHousePreference", {
L1065: ServerNet.onInvoke(
L1111: ServerNet.onInvoke("SelectGameMode", {
L1127: ServerNet.onInvoke("Interact", {
L1134: ServerNet.onInvoke("RequestRestart", {
L1147: if not ServerNet.isRegistered("SetFlashlight") then
L1148: ServerNet.onEvent(
~~~

### Estado observado / publicado

~~~text
L106: player:SetAttribute("CampaignFeedback", message)
L107: local serial = player:GetAttribute("CampaignFeedbackSerial")
L108: player:SetAttribute("CampaignFeedbackSerial", (if type(serial) == "number" then serial else 0) + 1)
L125: replicated:SetAttribute("LobbyReturnAt", lobbyReturnAt)
L130: player:SetAttribute("CampaignStatus", member.status)
L131: player:SetAttribute("CampaignRole", member.role)
L139: deathCause = player:GetAttribute("DeathCause"),
L164: replicated:SetAttribute("Roster", HttpService:JSONEncode(roster))
L165: replicated:SetAttribute("Tasks", HttpService:JSONEncode(tasks))
L166: replicated:SetAttribute("Inventory", HttpService:JSONEncode(session.inventory))
L167: replicated:SetAttribute("EscapeEndsAt", escapeEndsAt)
L168: replicated:SetAttribute("Stage", session.stage)
L169: replicated:SetAttribute("ForestActive", session.stage >= 6)
L170: replicated:SetAttribute("Seed", session.seed)
L171: replicated:SetAttribute("Title", if plan then plan.title else "REUNINDO A EQUIPE")
L172: replicated:SetAttribute("Threat", if plan then Catalog.Threats[plan.threat].title else "")
L173: replicated:SetAttribute("Solved", Session.solvedCount(session))
L174: replicated:SetAttribute("Total", if plan then #plan.activities else 0)
L175: replicated:SetAttribute("NextStageAt", nextStageAt)
L176: replicated:SetAttribute("Phase", session.phase)
L178: replicated:SetAttribute("GameMode", selectedMode or "")
L179: replicated:SetAttribute("StandardVotes", standardVotes)
L180: replicated:SetAttribute("StoryVotes", storyVotes)
L181: replicated:SetAttribute("Players", Session.count(session))
L182: replicated:SetAttribute("Building", building)
L183: replicated:SetAttribute("StorySceneSerial", sceneSerial)
L184: replicated:SetAttribute("StorySceneStartedAt", sceneStartedAt)
L185: replicated:SetAttribute("StorySceneEndsAt", sceneEndsAt)
L192: GameState.set("RoundStartedAt", startedAt)
L194: GameState.set("RoundEndedAt", workspace:GetServerTimeNow())
L196: GameState.set("Phase", phase)
L197: GameState.set("PowerOn", WorldService.isPowered())
L198: GameState.set("CreatureActive", CreatureService.isActive())
L279: player:SetAttribute("HasFlashlight", session.inventory.flashlight == 1)
L280: player:SetAttribute("DeathCause", "")
L281: player:SetAttribute(Tags.Attr.Flashlight, session.inventory.flashlight == 1)
L285: player:SetAttribute("CampaignGraceUntil", workspace:GetServerTimeNow() + C.SpawnGrace)
L333: focus:SetAttribute(Tags.Attr.InteractEnabled, false)
L437: player:SetAttribute("CampaignGraceUntil", now + C.ReviveGrace)
L486: beacon:SetAttribute(Tags.Attr.InteractId, `rescue_{player.UserId}`)
L487: beacon:SetAttribute(Tags.Attr.InteractPrompt, `RESGATAR {player.DisplayName}`)
L488: beacon:SetAttribute(Tags.Attr.InteractDistance, Config.Game.InteractDistance)
L489: beacon:SetAttribute(Tags.Attr.InteractEnabled, true)
L512: elseif player:GetAttribute("StoreReady") == true then
L559: player:SetAttribute("CampaignAccepted", ok)
L593: * Perks.factor("socorro", tonumber(player:GetAttribute("PerkSocorro")) or 0),
L625: replicated:SetAttribute("LastClue", text.Text)
L718: GameState.set("RoundEndedAt", 0)
L750: player:SetAttribute("GameModeVote", "")
L753: player:SetAttribute("HasFlashlight", false)
L754: player:SetAttribute(Tags.Attr.Flashlight, false)
L771: GameState.set("RoundId", version)
L772: GameState.set("RoundEndedAt", 0)
L774: replicated:SetAttribute("Ending", "")
L775: replicated:SetAttribute("LastClue", "")
L811: target:SetAttribute("CampaignGraceUntil", now + C.ReviveGrace)
L889: if inHide and player:GetAttribute("HoldBreath") == true then
L970: replicated:SetAttribute("Ending", if session.stage >= 6 then "forest_rescue" else "house_fire")
L1012: gameState:SetAttribute("CampaignActive", true)
L1057: player:SetAttribute("HousePreferences", HttpService:JSONEncode(data.house.preferences))
L1086: if item == "battery" and player:GetAttribute("HasFlashlight") ~= true then
L1092: or (item == "oxygen" and (tonumber(player:GetAttribute("Oxygen")) or 100) >= 99.9)
L1105: player:SetAttribute("HouseSupplies", HttpService:JSONEncode(stock))
L1122: player:SetAttribute("GameModeVote", mode)
L1152: player:SetAttribute(Tags.Attr.Flashlight, on)
L1162: player:SetAttribute("CampaignStatus", "Waiting")
L1170: player:SetAttribute("HouseSupplies", HttpService:JSONEncode(supplies[player.UserId]))
L1171: player:SetAttribute("GameModeVote", "")
L1283: return GameState.get("Phase")
~~~

## src/ServerScriptService/Server/Campaign/CoopSession.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau) · 419 linhas · SHA-256: da1d92ab169b81a13cd6b9f657f44c81d162b33316f99cef7d929f1cb78cc685

### Funções nomeadas / callbacks atribuídos

~~~text
L46: local function finite(n: number): boolean
L50: function Session.new(seed: number, policy: Policy, mode: string?, house: boolean?): State
L74: function Session.count(state: State, status: Status?): number
L84: function Session.join(state: State, id: number): (boolean, string?)
L100: local function evaluate(state: State)
L125: function Session.leave(state: State, id: number)
L138: function Session.beginStage(state: State): (boolean, string?)
L176: function Session.solvedCount(state: State): number
L186: function Session.taskReady(state: State, taskId: string): boolean
L203: function Session.act(state: State, id: number, taskId: string, button: number, now: number): (boolean, string)
L294: function Session.capture(state: State, id: number, now: number, rising: number?): boolean
L313: function Session.eliminate(state: State, id: number): boolean
L323: function Session.revive(state: State, helperId: number, targetId: number, now: number): (boolean, string?)
L340: function Session.selfRevive(state: State, id: number, now: number): (boolean, string?)
L353: function Session.retryStage(state: State): (boolean, string?)
L367: function Session.tick(state: State, now: number)
L389: function Session.escape(state: State, id: number): boolean
L402: function Session.voteRestart(state: State, id: number): (boolean, string?)
~~~

### Dependências literais

- L3: @game/ReplicatedStorage/Shared/Game/CampaignCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/CampaignCatalog.luau)
- L4: ./CampaignGenerator → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignGenerator.luau)
- L5: ./HousePlan → [fonte](../../src/ServerScriptService/Server/Campaign/HousePlan.luau)
- L6: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L7: @game/ReplicatedStorage/Shared/Game/HouseProgression → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseProgression.luau)

## src/ServerScriptService/Server/Campaign/Endings.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/Endings.luau) · 12 linhas · SHA-256: a07dcbe8458cd2b350755813ab05bdc5d06d422f961827d890ea050caaa709a9

### Funções nomeadas / callbacks atribuídos

~~~text
L6: function Endings.resolve(escaped: number, now: number, deadline: number, chapter: number?): string?
~~~

## src/ServerScriptService/Server/Campaign/ForestPlan.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/ForestPlan.luau) · 93 linhas · SHA-256: a4fb6babb74da2a728f7f9799f15991f5ceee0de02474512fbcbce1468b69615

### Funções nomeadas / callbacks atribuídos

~~~text
L7: function Plan.create(seed: number, chapter: number, players: number, mode: string): Generator.Plan
L55: function Plan.validate(plan: Generator.Plan): (boolean, string?)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/ForestCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestCatalog.luau)
- L3: ./CampaignGenerator → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignGenerator.luau)
- L4: ../World/ProceduralLayout → [fonte](../../src/ServerScriptService/Server/World/ProceduralLayout.luau)
- L5: ./SeededRandom → [fonte](../../src/ServerScriptService/Server/Campaign/SeededRandom.luau)

## src/ServerScriptService/Server/Campaign/HouseActivities.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/HouseActivities.luau) · 185 linhas · SHA-256: 1fa3f19697b8419c1ee4aade772c266bc9a61ad9a703c190e5852a0e67dfd462

### Funções nomeadas / callbacks atribuídos

~~~text
L14: function Activities.build(parent: Instance, plan: Generator.Plan, distance: number): any
L137: function Activities.refresh(built: any, tasks: any)
~~~

### Dependências literais

- L4: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L5: ../World/Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L6: ./HousePlan → [fonte](../../src/ServerScriptService/Server/Campaign/HousePlan.luau)
- L7: ./CampaignGenerator → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignGenerator.luau)
- L8: ../World/HouseTaskProps → [fonte](../../src/ServerScriptService/Server/World/HouseTaskProps.luau)
- L9: @game/ReplicatedStorage/Shared/Game/HouseProgression → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseProgression.luau)

### Estado observado / publicado

~~~text
L24: model:SetAttribute("RoomLabel", spec.room)
L98: focus:SetAttribute(Tags.Attr.InteractId, id)
L99: focus:SetAttribute(
L106: focus:SetAttribute(Tags.Attr.InteractDistance, distance)
L107: focus:SetAttribute(Tags.Attr.InteractEnabled, index == 1 and spec.kind ~= "hide" and spec.kind ~= "breath")
L165: target.focus:SetAttribute(Tags.Attr.InteractEnabled, enabled)
~~~

## src/ServerScriptService/Server/Campaign/HouseLevelPlan.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/HouseLevelPlan.luau) · 61 linhas · SHA-256: cd5d9944322859afe91693fcae83a5c5ed9c679f19d397f6c2a87723a560f54c

### Funções nomeadas / callbacks atribuídos

~~~text
L16: function Levels.create(seed: number, chapter: number, mode: string): Level
L57: function Levels.relocate(level: Level, index: number): Spot?
~~~

### Dependências literais

- L3: ./SeededRandom → [fonte](../../src/ServerScriptService/Server/Campaign/SeededRandom.luau)

## src/ServerScriptService/Server/Campaign/HousePlan.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/HousePlan.luau) · 115 linhas · SHA-256: 755a32322918ae76a39f9c24f329464482ab7af87e73db598ca44f4aaa8aeeac

### Funções nomeadas / callbacks atribuídos

~~~text
L9: function Plan.create(seed: number, chapter: number, players: number, mode: string): Generator.Plan
L73: function Plan.validate(plan: Generator.Plan): (boolean, string?)
~~~

### Dependências literais

- L3: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L4: ./CampaignGenerator → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignGenerator.luau)
- L5: ../World/ProceduralLayout → [fonte](../../src/ServerScriptService/Server/World/ProceduralLayout.luau)
- L6: ./SeededRandom → [fonte](../../src/ServerScriptService/Server/Campaign/SeededRandom.luau)
- L7: ./HouseLevelPlan → [fonte](../../src/ServerScriptService/Server/Campaign/HouseLevelPlan.luau)
- L11: ./ForestPlan → [fonte](../../src/ServerScriptService/Server/Campaign/ForestPlan.luau)
- L75: ./ForestPlan → [fonte](../../src/ServerScriptService/Server/Campaign/ForestPlan.luau)

## src/ServerScriptService/Server/Campaign/SeededRandom.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/SeededRandom.luau) · 25 linhas · SHA-256: 1eae09d0497be49bde156ed923aacb9d3735bcf23d5a46cd3869438fd07c0ae5

### Funções nomeadas / callbacks atribuídos

~~~text
L6: function SeededRandom.new(seed: number): Generator
L9: local function integer(a: number, b: number): number
L14: local function shuffle<T>(items: { T }): { T }
~~~

## src/ServerScriptService/Server/Campaign/StoryPlan.luau

[Abrir fonte](../../src/ServerScriptService/Server/Campaign/StoryPlan.luau) · 9 linhas · SHA-256: 1916b0f7aade30a5e7677bfbeb93ce3284358d2f9bab02c91fb23e1fed0db8f9

### Funções nomeadas / callbacks atribuídos

~~~text
L6: function StoryPlan.create(stage: number, players: number): Generator.Plan
~~~

### Dependências literais

- L2: ./HousePlan → [fonte](../../src/ServerScriptService/Server/Campaign/HousePlan.luau)
- L3: @game/ReplicatedStorage/Shared/Game/StoryCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoryCatalog.luau)
- L4: ./CampaignGenerator → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignGenerator.luau)

## src/ServerScriptService/Server/Data/MockDataStore.luau

[Abrir fonte](../../src/ServerScriptService/Server/Data/MockDataStore.luau) · 46 linhas · SHA-256: 60475dcee4bf8561c4c2f108a85c3e17a1205aae77db9b69847e45eabaec550c

### Funções nomeadas / callbacks atribuídos

~~~text
L19: function MockDataStore.new(): Store
L23: function store.GetAsync(_self: Store, key: string): any
L27: function store.UpdateAsync(_self: Store, key: string, transform: (current: any) -> ...any): any
L37: function store.RemoveAsync(_self: Store, key: string): any
~~~

### Dependências literais

- L9: @game/ReplicatedStorage/Shared/Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)

## src/ServerScriptService/Server/Data/PlayerDataSchema.luau

[Abrir fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau) · 149 linhas · SHA-256: ded80245ba0eda954b8ec0ed3596fa6d3f4af84d7112d102f71b1cb8514907d1

### Funções nomeadas / callbacks atribuídos

~~~text
L57: local function numberMap(value: unknown, max: number): { [string]: number }
L70: local function finiteOr(value: any, fallback: number): number
L76: function PlayerDataSchema.template(): Types.PlayerData
L81: function PlayerDataSchema.migrate(raw: unknown): Types.PlayerData
~~~

### Dependências literais

- L21: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L22: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L23: @game/ReplicatedStorage/Shared/Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)
- L24: @game/ReplicatedStorage/Shared/Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)
- L26: @game/ReplicatedStorage/Shared/Game/HousePreferences → [fonte](../../src/ReplicatedStorage/Shared/Game/HousePreferences.luau)

## src/ServerScriptService/Server/Data/SessionLock.luau

[Abrir fonte](../../src/ServerScriptService/Server/Data/SessionLock.luau) · 38 linhas · SHA-256: 62683e59465a6602a7387ec684ad29ed5d61182da39b23ded63c4b6aae98a039

### Funções nomeadas / callbacks atribuídos

~~~text
L23: function SessionLock.canTake(current: Lock?, job: string, now: number, ttl: number?): boolean
L34: function SessionLock.make(job: string, now: number): Lock
~~~

## src/ServerScriptService/Server/Game/BreakerPuzzle.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/BreakerPuzzle.luau) · 79 linhas · SHA-256: 4373a3157a771508448124e7140cff2c0554a76699ac308c5fc233b11a9c9ca0

### Funções nomeadas / callbacks atribuídos

~~~text
L19: function BreakerPuzzle.new(order: { number }): State
L30: function BreakerPuzzle.shuffle(count: number, nextInteger: (number, number) -> number): { number }
L42: function BreakerPuzzle.isUp(state: State, index: number): boolean
L54: function BreakerPuzzle.press(state: State, index: number): Result
L71: function BreakerPuzzle.describe(order: { number }): string
~~~

## src/ServerScriptService/Server/Game/Checkpoint.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/Checkpoint.luau) · 44 linhas · SHA-256: 6faecc7edb9a3fff2d7e01ed6ac1c4fcd0d8ba2adf73c55bffff1955538ed9b7

### Funções nomeadas / callbacks atribuídos

~~~text
L28: function Checkpoint.capture(input: Snapshot): Snapshot
L35: function Checkpoint.restore(snapshot: Snapshot): Snapshot
L40: function Checkpoint.isUsable(snapshot: Snapshot?): boolean
~~~

### Dependências literais

- L11: @game/ReplicatedStorage/Shared/Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)
- L12: ./Objectives → [fonte](../../src/ServerScriptService/Server/Game/Objectives.luau)

## src/ServerScriptService/Server/Game/CoinPlan.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/CoinPlan.luau) · 82 linhas · SHA-256: 4335aacf9b1e4783a0ca1ec353c7cad0d441c704230c8f816bb5bf9fac86325f

### Funções nomeadas / callbacks atribuídos

~~~text
L31: local function roomPoint(room: House.Room, spot: { number }): (number, number)
L37: function CoinPlan.create(seed: number, perRoom: number, yard: number): { Coin }
~~~

### Dependências literais

- L11: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L12: ../Campaign/SeededRandom → [fonte](../../src/ServerScriptService/Server/Campaign/SeededRandom.luau)

## src/ServerScriptService/Server/Game/CreatureBrain.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/CreatureBrain.luau) · 158 linhas · SHA-256: db4e4de77ac21176dbf25e24e6ba60b73ede857aabcf935b2ad132050db354af

### Funções nomeadas / callbacks atribuídos

~~~text
L57: function CreatureBrain.new(): Brain
L68: function CreatureBrain.activate(brain: Brain)
L74: function CreatureBrain.speedFor(mode: Mode, fuses: number, hunt: boolean): number
L88: local function command(brain: Brain, target: any?, hunt: boolean, event: string?): Command
L97: function CreatureBrain.step(brain: Brain, p: Perception): Command
~~~

### Dependências literais

- L17: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

## src/ServerScriptService/Server/Game/EconomyEvents.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/EconomyEvents.luau) · 195 linhas · SHA-256: 71f66686bd762a96ee5964263fbdd8bedfd30caf685d2ff20cea6cc5b7e8e3f5

### Funções nomeadas / callbacks atribuídos

~~~text
L52: local function levelPart(granted: Economy.Granted): (number, number)
L65: local function refundPart(granted: Economy.Granted): number
L74: local function withBalances(entries: { Entry }, wallet: { fichas: number, creditos: number }): { Event }
L111: local function addChange(entries: { Entry }, change: Change)
L164: function EconomyEvents.build(wallet: { fichas: number, creditos: number }, changes: { Change }): { Event }
L173: function EconomyEvents.sources(
L182: function EconomyEvents.sink(
~~~

### Dependências literais

- L16: @game/ReplicatedStorage/Shared/Game/Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L17: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)

## src/ServerScriptService/Server/Game/HideRules.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/HideRules.luau) · 82 linhas · SHA-256: f445ee13eb52b299ec9deb9f71ca856db6fba811e6a2caa745d7bff01ea1d2f8

### Funções nomeadas / callbacks atribuídos

~~~text
L37: function HideRules.canEnter(ctx: EnterContext): (boolean, string?)
L57: function HideRules.sawEntry(sinceSeen: number, chasing: boolean): boolean
L62: function HideRules.exposure(previous: number, distance: number, holdingBreath: boolean, dt: number): number
L72: function HideRules.found(ctx: FoundContext): boolean
~~~

### Dependências literais

- L11: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

## src/ServerScriptService/Server/Game/Objectives.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/Objectives.luau) · 168 linhas · SHA-256: 76a2d003d52203933d941a42eb37c6c0c431f65b6aad25ca16d1e02effc3ef17

### Funções nomeadas / callbacks atribuídos

~~~text
L29: function Objectives.new(total: number): State
L46: function Objectives.collectedCount(state: State): number
L55: function Objectives.collect(state: State, fuseId: string): (boolean, string?)
L68: function Objectives.insert(state: State): (number, string?)
L81: function Objectives.isPanelComplete(state: State): boolean
L86: function Objectives.canUseBreakers(state: State): (boolean, string?)
L96: function Objectives.solveBreakers(state: State): boolean
L104: function Objectives.powerOn(state: State): boolean
L112: function Objectives.openGate(state: State): (boolean, string?)
L123: function Objectives.canWin(state: State): boolean
L127: function Objectives.takeKey(state: State): (boolean, string?)
L137: function Objectives.useKey(state: State, doorId: string): (boolean, string?)
L149: function Objectives.objectiveKey(state: State): ObjectiveKey
~~~

## src/ServerScriptService/Server/Game/Oxygen.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/Oxygen.luau) · 38 linhas · SHA-256: e413f836da42d34fc4930305e7b5dc47e0ef758d89e90847b25d4d8035ec56c5

### Funções nomeadas / callbacks atribuídos

~~~text
L5: function Oxygen.new(): State
L8: function Oxygen.request(state: State, hold: boolean, now: number): boolean
L22: function Oxygen.step(state: State, dt: number, now: number): boolean
~~~

## src/ServerScriptService/Server/Game/PlayerRules.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/PlayerRules.luau) · 103 linhas · SHA-256: 26d8c0308966262eadf06ceaabe6f3d2f98b539e79261b90d0f93ee40576ff69

### Funções nomeadas / callbacks atribuídos

~~~text
L30: function PlayerRules.maxSpeed(stance: Stance): number
L38: function PlayerRules.walkSpeed(stance: Stance): number
L45: function PlayerRules.newSpeedCheck(): SpeedCheck
L54: function PlayerRules.checkSpeed(check: SpeedCheck, speed: number, allowed: number, now: number): SpeedVerdict
L71: function PlayerRules.newBreath(): Breath
L76: function PlayerRules.holdBreath(breath: Breath, now: number): boolean
L86: function PlayerRules.releaseBreath(breath: Breath, now: number)
L94: function PlayerRules.stepBreath(breath: Breath, now: number): "gasp"?
~~~

### Dependências literais

- L9: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

## src/ServerScriptService/Server/Game/RoundRules.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/RoundRules.luau) · 69 linhas · SHA-256: 6cf9a9d980b308db484735b31de7b26d57dce7745b041fc69377fa09f57bdf79

### Funções nomeadas / callbacks atribuídos

~~~text
L31: function RoundRules.canTransition(from: Phase, to: Phase): boolean
L36: function RoundRules.canRestart(phase: Phase): boolean
L41: function RoundRules.validateInteraction(ctx: InteractionContext): (boolean, string?)
L64: function RoundRules.formatTime(seconds: number): string
~~~

## src/ServerScriptService/Server/Game/StoreFunnel.luau

[Abrir fonte](../../src/ServerScriptService/Server/Game/StoreFunnel.luau) · 72 linhas · SHA-256: cec7c87eea292b6d6171f3a670b39099218195b9cb648ddb73d2f158fa3b3d56

### Funções nomeadas / callbacks atribuídos

~~~text
L41: function StoreFunnel.new(): State
L45: local function advance(state: State, step: number, fields: { string }): { Step }
L54: function StoreFunnel.open(state: State, sessionId: string): { Step }
L60: function StoreFunnel.view(state: State, offer: string): { Step }
L68: function StoreFunnel.purchase(state: State, kind: string, currency: string): { Step }
~~~

## src/ServerScriptService/Server/Main.server.luau

[Abrir fonte](../../src/ServerScriptService/Server/Main.server.luau) · 48 linhas · SHA-256: f8890063adf44d424a5ab40f473efdeb4278b9c88aabcbf3ebee2ef8e6758ff1

### Dependências literais

- L7: @game/ReplicatedStorage/Shared/Loader → [fonte](../../src/ReplicatedStorage/Shared/Loader.luau)
- L8: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L9: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L19: ./Services/PlayerDataService → [fonte](../../src/ServerScriptService/Server/Services/PlayerDataService.luau)
- L20: ./Services/TelemetryService → [fonte](../../src/ServerScriptService/Server/Services/TelemetryService.luau)
- L21: ./Services/StoreService → [fonte](../../src/ServerScriptService/Server/Services/StoreService.luau)
- L22: ./Services/WorldService → [fonte](../../src/ServerScriptService/Server/Services/WorldService.luau)
- L23: ./Services/PlayerStateService → [fonte](../../src/ServerScriptService/Server/Services/PlayerStateService.luau)
- L24: ./Services/PresenceService → [fonte](../../src/ServerScriptService/Server/Services/PresenceService.luau)
- L25: ./Services/LobbyService → [fonte](../../src/ServerScriptService/Server/Services/LobbyService.luau)
- L26: ./Services/CreatureService → [fonte](../../src/ServerScriptService/Server/Services/CreatureService.luau)
- L27: ./Services/PropService → [fonte](../../src/ServerScriptService/Server/Services/PropService.luau)
- L28: ./Services/CosmeticService → [fonte](../../src/ServerScriptService/Server/Services/CosmeticService.luau)
- L29: ./Services/CollectibleService → [fonte](../../src/ServerScriptService/Server/Services/CollectibleService.luau)
- L30: ./Services/RoundService → [fonte](../../src/ServerScriptService/Server/Services/RoundService.luau)
- L31: ./Services/RewardService → [fonte](../../src/ServerScriptService/Server/Services/RewardService.luau)
- L32: ./Services/PerkService → [fonte](../../src/ServerScriptService/Server/Services/PerkService.luau)
- L33: ./Services/CoinService → [fonte](../../src/ServerScriptService/Server/Services/CoinService.luau)
- L34: ./Services/DebugService → [fonte](../../src/ServerScriptService/Server/Services/DebugService.luau)
- L38: ./Services/RoundService → [fonte](../../src/ServerScriptService/Server/Services/RoundService.luau)

## src/ServerScriptService/Server/Net/ServerNet.luau

[Abrir fonte](../../src/ServerScriptService/Server/Net/ServerNet.luau) · 104 linhas · SHA-256: c1bf63af85efe73d456e433cbd5a654435c8f5273925455d1581d5d1d8a658a2

### Funções nomeadas / callbacks atribuídos

~~~text
L40: local function prepare(name: string, options: HandlerOptions)
L54: function ServerNet.isRegistered(name: string): boolean
L59: function ServerNet.onInvoke<T>(name: string, options: HandlerOptions, handler: (player: Player, ...any) -> T)
L63: remote.OnServerInvoke = function(player: Player, ...: any): Types.Result<T>
L83: function ServerNet.onEvent(name: string, options: HandlerOptions, handler: (player: Player, ...any) -> ())
~~~

### Dependências literais

- L16: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L17: @game/ReplicatedStorage/Shared/Net/Guard → [fonte](../../src/ReplicatedStorage/Shared/Net/Guard.luau)
- L18: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L19: @game/ReplicatedStorage/Shared/Net/RateLimiter → [fonte](../../src/ReplicatedStorage/Shared/Net/RateLimiter.luau)
- L20: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L21: @game/ReplicatedStorage/Shared/Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)

### Listeners / registros / callbacks

~~~text
L34: Players.PlayerRemoving:Connect(function(player: Player)
L63: remote.OnServerInvoke = function(player: Player, ...: any): Types.Result<T>
L83: function ServerNet.onEvent(name: string, options: HandlerOptions, handler: (player: Player, ...any) -> ())
L87: remote.OnServerEvent:Connect(function(player: Player, ...: any)
~~~

### Rede

~~~text
L54: function ServerNet.isRegistered(name: string): boolean
L59: function ServerNet.onInvoke<T>(name: string, options: HandlerOptions, handler: (player: Player, ...any) -> T)
L60: local remote = Remotes.serverFunction(name)
L83: function ServerNet.onEvent(name: string, options: HandlerOptions, handler: (player: Player, ...any) -> ())
L84: local remote = Remotes.serverEvent(name)
~~~

## src/ServerScriptService/Server/Services/CoinService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/CoinService.luau) · 182 linhas · SHA-256: 33c7c01df0026707cd4f297e43f88e2b97bdc5a2e2ee799fae1e75a62af3dc7b

### Funções nomeadas / callbacks atribuídos

~~~text
L33: local function clear()
L40: local function makeCoin(parent: Instance, spec: CoinPlan.Coin): BasePart
L73: local function spawnCoins(seed: number, stage: number)
L86: local function collect(player: Player, coin: BasePart)
L104: local function tick()
L129: function CoinService.Start()
L143: local function refresh()
L174: function CoinService.status(): (number, number)
~~~

### Dependências literais

- L15: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L16: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L17: ../Game/CoinPlan → [fonte](../../src/ServerScriptService/Server/Game/CoinPlan.luau)
- L18: ./StoreService → [fonte](../../src/ServerScriptService/Server/Services/StoreService.luau)

### Listeners / registros / callbacks

~~~text
L159: state:GetAttributeChangedSignal(name):Connect(refresh)
L164: RunService.Heartbeat:Connect(function(dt)
~~~

### Estado observado / publicado

~~~text
L65: part:SetAttribute("Value", if spec.gem then C.GemValue else C.Value)
L66: part:SetAttribute("Xp", if spec.gem then C.GemXp else C.Xp)
L67: part:SetAttribute("Gem", spec.gem)
L91: local value = (coin:GetAttribute("Value") :: number?) or C.Value
L92: local xp = (coin:GetAttribute("Xp") :: number?) or C.Xp
L94: local gem = coin:GetAttribute("Gem") == true
L97: player:SetAttribute("CoinPickupValue", value)
L98: player:SetAttribute("CoinPickupAt", position)
L99: player:SetAttribute("CoinPickupGem", gem)
L100: player:SetAttribute("CoinPickupSerial", ((player:GetAttribute("CoinPickupSerial") :: number?) or 0) + 1)
L110: if player:GetAttribute("CampaignStatus") ~= "Active" then
L144: local phase = state:GetAttribute("Phase")
L145: local seed = (state:GetAttribute("Seed") :: number?) or 0
L146: local stage = (state:GetAttribute("Stage") :: number?) or 0
L159: state:GetAttributeChangedSignal(name):Connect(refresh)
~~~

## src/ServerScriptService/Server/Services/CollectibleService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/CollectibleService.luau) · 268 linhas · SHA-256: 30c28e7de81bebb0c926d096463a5073e8b731eb6f568c49340265f88c685dfc

### Funções nomeadas / callbacks atribuídos

~~~text
L55: local function clear()
L64: local function exclusions(): { Instance }
L80: local function farFromPlayers(position: Vector3): boolean
L91: local function findSpot(): CFrame?
L116: local function chooseTape(): string?
L139: local function build(at: CFrame, tapeId: string): BasePart
L181: local function spawnTape()
L197: local function canReach(character: Model, part: BasePart): boolean
L217: function CollectibleService.Start()
L237: function CollectibleService.collect(player: Player): Types.InteractResponse
L261: function CollectibleService.debugState(): { [string]: any }
~~~

### Dependências literais

- L18: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L19: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L20: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L21: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L22: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L23: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L24: @game/ReplicatedStorage/Shared/Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)
- L25: ./StoreService → [fonte](../../src/ServerScriptService/Server/Services/StoreService.luau)

### Estado observado / publicado

~~~text
L170: case:SetAttribute(Tags.Attr.InteractId, TAPE_ID)
L171: case:SetAttribute(Tags.Attr.InteractPrompt, Text.Prompts.Tape)
L172: case:SetAttribute(Tags.Attr.InteractDistance, REACH)
L173: case:SetAttribute(Tags.Attr.InteractEnabled, true)
L174: case:SetAttribute("Tape", tapeId)
L218: GameState.observe(function(snapshot, changed)
L222: local stage = if state then (state:GetAttribute("Stage") :: number?) or 0 else 0
L242: local status = player:GetAttribute("CampaignStatus")
L243: if GameState.get("Phase") ~= "Playing" or (status ~= nil and status ~= "Active") then
~~~

## src/ServerScriptService/Server/Services/CosmeticService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/CosmeticService.luau) · 231 linhas · SHA-256: 98fddd0e8f06a04e4d5da29bf5493eb77ebd620e9ad5554c78623592648dbe5c

### Funções nomeadas / callbacks atribuídos

~~~text
L37: local function rgb(c: StoreCatalog.RGB?): Color3?
L44: local function attach(folder: Instance, base: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3)
L66: local function bodyPart(character: Model, names: { string }): BasePart?
L76: local function applyUniform(character: Model, folder: Instance, item: StoreCatalog.Item)
L143: local function applyTitle(character: Model, folder: Instance, item: StoreCatalog.Item)
L168: local function apply(player: Player, force: boolean?)
L203: local function watch(player: Player)
L216: function CosmeticService.Start()
L227: function CosmeticService.apply(player: Player)
~~~

### Dependências literais

- L16: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L17: @game/ReplicatedStorage/Shared/Game/PixelText → [fonte](../../src/ReplicatedStorage/Shared/Game/PixelText.luau)
- L18: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L19: ./StoreService → [fonte](../../src/ServerScriptService/Server/Services/StoreService.luau)

### Listeners / registros / callbacks

~~~text
L178: character.Destroying:Once(function()
L204: player.CharacterAppearanceLoaded:Connect(function()
L217: Players.PlayerAdded:Connect(watch)
~~~

## src/ServerScriptService/Server/Services/CreatureService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/CreatureService.luau) · 683 linhas · SHA-256: 1ee09d58711c5d4610f0f58df8ad72ccdeaa896d06079a88fa6ad1a6ca80dc63

### Funções nomeadas / callbacks atribuídos

~~~text
L76: local function getRoot(): BasePart
L81: local function feet(): Vector3
L85: local function setAttributes(mode: string)
L94: local function placeAt(position: Vector3, look: Vector3?)
L104: local function vec(p: Layout.Point): Vector3
L108: local function findTarget(): Target?
L141: local function lineOfSight(target: Target): boolean
L155: local function perceiveHidden(target: Target, now: number): CreatureBrain.Perception
L214: local function perceive(target: Target?, now: number): CreatureBrain.Perception
L269: local function computePath(target: Vector3)
L311: local function stopMoving()
L317: local function nextPatrolNode(): Vector3
L335: local function goTo(target: Vector3, speed: number, urgent: boolean)
L350: local function fireCapture(player: Player)
L356: local function brainTick()
L435: local function move(dt: number)
L495: function CreatureService.Init()
L516: function CreatureService.Start()
L530: function CreatureService.reset()
L554: function CreatureService.activate(at: Vector3?)
L582: function CreatureService.setFuses(count: number)
L586: function CreatureService.setHunt(on: boolean)
L591: function CreatureService.makeNoise(position: Vector3, radius: number)
L612: function CreatureService.silhouette()
L617: function CreatureService.endingPose()
L622: function CreatureService.freeze()
L628: function CreatureService.setFrozen(value: boolean)
L636: function CreatureService.holdOff(seconds: number)
L641: function CreatureService.sawEntry(player: Player): boolean
L644: function CreatureService.secondsSinceSeen(): number
L648: function CreatureService.isChasing(): boolean
L652: function CreatureService.onCapture(callback: (Player) -> ())
L656: function CreatureService.isActive(): boolean
L660: function CreatureService.state(): { [string]: any }
L677: function CreatureService.debugPlace(position: Vector3)
~~~

### Dependências literais

- L15: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L16: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L18: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L19: ../Game/CreatureBrain → [fonte](../../src/ServerScriptService/Server/Game/CreatureBrain.luau)
- L20: @game/ReplicatedStorage/Shared/Game/ForestThreat → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestThreat.luau)
- L21: ../Game/HideRules → [fonte](../../src/ServerScriptService/Server/Game/HideRules.luau)
- L22: ../World/Layout → [fonte](../../src/ServerScriptService/Server/World/Layout.luau)
- L23: ./WorldService → [fonte](../../src/ServerScriptService/Server/Services/WorldService.luau)

### Listeners / registros / callbacks

~~~text
L526: RunService.Heartbeat:Connect(move)
L652: function CreatureService.onCapture(callback: (Player) -> ())
~~~

### Estado observado / publicado

~~~text
L87: r:SetAttribute(Tags.Attr.CreatureMode, mode)
L88: r:SetAttribute(Tags.Attr.CreatureActive, active)
L90: r:SetAttribute(Tags.Attr.ThreatTargetUserId, 0)
L116: local campaignStatus = player:GetAttribute("CampaignStatus")
L118: local grace = player:GetAttribute("CampaignGraceUntil")
L158: local at = player:GetAttribute("HiddenAt")
L163: local quiet = player:GetAttribute("HoldBreath") == true and player:GetAttribute(Tags.Attr.Flashlight) ~= true
L169: local seen = player:GetAttribute("HiddenSeen") == true
L182: player:SetAttribute("HiddenSeen", true)
L183: getRoot():SetAttribute("Alert", now)
L218: local hiddenId = target.player:GetAttribute("Hidden")
L228: local flashlight = target.player:GetAttribute(Tags.Attr.Flashlight) == true
L230: local crouch = if target.player:GetAttribute("Stance") == "Crouch" then Config.Player.CrouchSightFactor else 1
L231: local forest = WorldService.get().root:GetAttribute("ForestActive") == true
L380: tonumber(WorldService.get().root:GetAttribute("HouseChapter")) or 0,
L389: getRoot():SetAttribute("FalseExit", feintUntil > now)
L391: getRoot():SetAttribute(Tags.Attr.ThreatTargetUserId, if target then target.player.UserId else 0)
~~~

## src/ServerScriptService/Server/Services/DebugService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/DebugService.luau) · 169 linhas · SHA-256: 83eb7925a908875635dbb887ec7992db065aa91f89796c47588a68b1ad654732

### Funções nomeadas / callbacks atribuídos

~~~text
L36: local function encode(value: any): any
L50: forestChapter = function(chapter: number)
L53: lightingPower = function(on: boolean)
L57: state = function()
L68: awaken = function()
L72: freezeCreature = function(value: boolean)
L76: placeCreature = function(position: Vector3)
L80: teleport = function(position: Vector3)
L90: checkpoint = function()
L95: grant = function(what: string)
L99: setBattery = function(value: number)
L105: fall = function(id: string)
L108: storeGrant = function(fichas: number, creditos: number)
L114: endRound = function(result: string)
L125: seasonXp = function(amount: number)
L132: analytics = function()
L135: tape = function()
L138: holdOff = function(seconds: number)
L142: restart = function()
L152: function DebugService.Init()
L158: bridge.OnInvoke = function(command: string, ...: any): any
~~~

### Dependências literais

- L24: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L25: ./CollectibleService → [fonte](../../src/ServerScriptService/Server/Services/CollectibleService.luau)
- L26: ./CreatureService → [fonte](../../src/ServerScriptService/Server/Services/CreatureService.luau)
- L27: ./PlayerStateService → [fonte](../../src/ServerScriptService/Server/Services/PlayerStateService.luau)
- L28: ./PropService → [fonte](../../src/ServerScriptService/Server/Services/PropService.luau)
- L29: ./RoundService → [fonte](../../src/ServerScriptService/Server/Services/RoundService.luau)
- L30: ./StoreService → [fonte](../../src/ServerScriptService/Server/Services/StoreService.luau)
- L31: ./TelemetryService → [fonte](../../src/ServerScriptService/Server/Services/TelemetryService.luau)
- L32: ./WorldService → [fonte](../../src/ServerScriptService/Server/Services/WorldService.luau)

### Listeners / registros / callbacks

~~~text
L158: bridge.OnInvoke = function(command: string, ...: any): any
~~~

## src/ServerScriptService/Server/Services/LobbyService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/LobbyService.luau) · 202 linhas · SHA-256: b446e203508eda1298419e30ab53629e031f6c036b3a6580d36268ac1b9ea74c

### Funções nomeadas / callbacks atribuídos

~~~text
L38: local function now(): number
L43: local function selfEntry(): ServerList.Entry
L57: local function publishSelf()
L78: local function readAll(): { ServerList.Entry }
L100: local function teleport(player: Player, jobId: string): (boolean, string)
L113: local function handle(player: Player, action: string, arg: string?): { [string]: any }
L163: function LobbyService.Start()
~~~

### Dependências literais

- L22: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L23: @game/ReplicatedStorage/Shared/Net/Guard → [fonte](../../src/ReplicatedStorage/Shared/Net/Guard.luau)
- L24: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L25: @game/ReplicatedStorage/Shared/Game/ServerList → [fonte](../../src/ReplicatedStorage/Shared/Game/ServerList.luau)
- L26: ../Net/ServerNet → [fonte](../../src/ServerScriptService/Server/Net/ServerNet.luau)

### Listeners / registros / callbacks

~~~text
L176: ServerNet.onInvoke("Lobby", {
L190: game:BindToClose(function()
~~~

### Rede

~~~text
L176: ServerNet.onInvoke("Lobby", {
~~~

### Estado observado / publicado

~~~text
L45: local mode = if campaign then campaign:GetAttribute("GameMode") else nil
L51: phase = if campaign then tostring(campaign:GetAttribute("Phase") or "Lobby") else "Lobby",
L52: stage = if campaign then tonumber(campaign:GetAttribute("Stage")) or 0 else 0,
~~~

## src/ServerScriptService/Server/Services/PerkService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/PerkService.luau) · 107 linhas · SHA-256: f137ca4d70ec19e70c47232f90e7b1921015c1332f8efe84210aa8764a18faa5

### Funções nomeadas / callbacks atribuídos

~~~text
L35: local function stageKey(): string
L43: local function markUsed(player: Player, id: string, key: string): boolean
L53: local function giveExtraBattery(key: string)
L74: function PerkService.secondChance(player: Player, revive: () -> ()): boolean
L90: function PerkService.Start()
~~~

### Dependências literais

- L19: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L20: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L21: @game/ReplicatedStorage/Shared/Game/Perks → [fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau)
- L22: ./StoreService → [fonte](../../src/ServerScriptService/Server/Services/StoreService.luau)

### Listeners / registros / callbacks

~~~text
L102: Players.PlayerRemoving:Connect(function(player)
~~~

### Estado observado / publicado

~~~text
L37: if campaign and GameState.get("CampaignActive") then
L38: return `c{GameState.get("RoundId")}:{campaign:GetAttribute("Stage")}`
L40: return `s{GameState.get("RoundId")}`
L55: local status = player:GetAttribute("CampaignStatus")
L59: player:GetAttribute("SpareBattery") ~= true
L63: player:SetAttribute("SpareBattery", true)
L84: player:SetAttribute("SecondChanceAt", workspace:GetServerTimeNow() + Perks.SECOND_CHANCE_DELAY)
L91: GameState.observe(function(snapshot, changed)
L96: if GameState.get("Phase") == "Playing" and stageKey() == key then
~~~

## src/ServerScriptService/Server/Services/PlayerDataService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/PlayerDataService.luau) · 297 linhas · SHA-256: f25309f8aeaef063644ee9fc2467b447748a291367ce72da21be6e03699032a3

### Funções nomeadas / callbacks atribuídos

~~~text
L55: local function storeName(): string
L62: local function chooseMode(): (Types.DataMode, string)
L88: local function getStore(): Store
L93: local function retryOptions(label: string): Retry.Options
L98: onRetry = function(attempt: number, err: string, delay: number)
L104: local function jobId(): string
L109: local function saveProfile(player: Player, profile: Profile, release: boolean?): boolean
L146: local function acquire(key: string): (boolean, any, string?)
L179: local function loadProfile(player: Player)
L205: local function onPlayerRemoving(player: Player)
L214: local function onShutdown()
L229: local function autosaveLoop()
L242: function PlayerDataService.Init()
L252: function PlayerDataService.Start()
L262: function PlayerDataService.get(player: Player): Types.PlayerData?
L267: function PlayerDataService.waitFor(player: Player, timeout: number?): Types.PlayerData?
L276: function PlayerDataService.update(player: Player, mutator: (data: Types.PlayerData) -> ()): boolean
L285: function PlayerDataService.save(player: Player): boolean
L293: function PlayerDataService.getMode(): (Types.DataMode, string)
~~~

### Dependências literais

- L30: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L31: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L32: @game/ReplicatedStorage/Shared/Util/Retry → [fonte](../../src/ReplicatedStorage/Shared/Util/Retry.luau)
- L33: @game/ReplicatedStorage/Shared/Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)
- L34: @game/ReplicatedStorage/Shared/Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)
- L35: ../Data/MockDataStore → [fonte](../../src/ServerScriptService/Server/Data/MockDataStore.luau)
- L36: ../Data/PlayerDataSchema → [fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau)
- L37: ../Data/SessionLock → [fonte](../../src/ServerScriptService/Server/Data/SessionLock.luau)

### Listeners / registros / callbacks

~~~text
L253: Players.PlayerAdded:Connect(loadProfile)
L254: Players.PlayerRemoving:Connect(onPlayerRemoving)
L258: game:BindToClose(onShutdown)
~~~

### Estado observado / publicado

~~~text
L136: player:SetAttribute("HousePreferencesSaveMode", mode)
L137: player:SetAttribute("HousePreferencesSaved", HttpService:JSONEncode(snapshot.house.preferences))
~~~

## src/ServerScriptService/Server/Services/PlayerStateService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/PlayerStateService.luau) · 484 linhas · SHA-256: 2038f91965d397fda20bd75a0defe8ed581185b2d016061f5966c5fc1e7b8a11

### Funções nomeadas / callbacks atribuídos

~~~text
L60: local function newState(): PlayerState
L80: local function stateOf(player: Player): PlayerState
L89: local function parts(player: Player): (Model?, BasePart?, Humanoid?)
L99: local function isPlaying(): boolean
L103: local function standHipHeight(character: Model, humanoid: Humanoid): number
L112: local function publishLight(player: Player, state: PlayerState)
L116: local function publishBattery(player: Player, state: PlayerState, force: boolean?)
L125: local function canStand(character: Model, root: BasePart): boolean
L136: local function applyStance(player: Player, state: PlayerState, stance: Stance)
L149: local function setStance(player: Player, stance: Stance)
L167: local function setFlashlight(player: Player, on: boolean)
L177: local function setHoldBreath(player: Player, hold: boolean)
L195: local function validateSpeed(player: Player, state: PlayerState, now: number)
L220: local function tick()
L299: function PlayerStateService.Start()
L334: function PlayerStateService.setNoiseHandler(handler: (position: Vector3, radius: number) -> ())
L339: function PlayerStateService.resetForSpawn(player: Player, battery: number?)
L363: function PlayerStateService.markTeleported(player: Player)
L371: function PlayerStateService.stance(player: Player): Stance
L375: function PlayerStateService.isHidden(player: Player): boolean
L379: function PlayerStateService.hiddenId(player: Player): string?
L383: function PlayerStateService.sinceExit(player: Player): number
L391: function PlayerStateService.enterHide(
L422: function PlayerStateService.exitHide(player: Player): boolean
L446: function PlayerStateService.battery(player: Player): number
L450: function PlayerStateService.addBattery(player: Player, amount: number?)
L461: function PlayerStateService.addOxygen(player: Player, amount: number): boolean
L469: function PlayerStateService.grantFlashlight(player: Player)
L473: function PlayerStateService.snapshot(player: Player): { [string]: any }
~~~

### Dependências literais

- L21: @game/ReplicatedStorage/Shared/Game/BatteryModel → [fonte](../../src/ReplicatedStorage/Shared/Game/BatteryModel.luau)
- L22: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L23: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L24: @game/ReplicatedStorage/Shared/Game/Perks → [fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau)
- L25: @game/ReplicatedStorage/Shared/Net/Guard → [fonte](../../src/ReplicatedStorage/Shared/Net/Guard.luau)
- L26: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L27: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L28: ../Game/Oxygen → [fonte](../../src/ServerScriptService/Server/Game/Oxygen.luau)
- L30: ../Game/PlayerRules → [fonte](../../src/ServerScriptService/Server/Game/PlayerRules.luau)
- L31: ../Net/ServerNet → [fonte](../../src/ServerScriptService/Server/Net/ServerNet.luau)
- L300: ./CreatureService → [fonte](../../src/ServerScriptService/Server/Services/CreatureService.luau)

### Listeners / registros / callbacks

~~~text
L301: ServerNet.onEvent("SetFlashlight", {
L306: ServerNet.onEvent("SetStance", {
L313: ServerNet.onEvent("SetHoldBreath", {
L318: Players.PlayerRemoving:Connect(function(player: Player)
L334: function PlayerStateService.setNoiseHandler(handler: (position: Vector3, radius: number) -> ())
~~~

### Rede

~~~text
L301: ServerNet.onEvent("SetFlashlight", {
L306: ServerNet.onEvent("SetStance", {
L313: ServerNet.onEvent("SetHoldBreath", {
~~~

### Estado observado / publicado

~~~text
L100: return GameState.get("Phase") == "Playing"
L104: local stored = character:GetAttribute("StandHipHeight")
L108: character:SetAttribute("StandHipHeight", humanoid.HipHeight)
L113: player:SetAttribute(Tags.Attr.Flashlight, state.battery.on)
L120: player:SetAttribute("Battery", charge)
L146: player:SetAttribute("Stance", stance)
L157: player:SetAttribute("Stance", state.stance)
L161: player:SetAttribute("Stance", state.stance)
L169: if Config.House.Enabled and player:GetAttribute("HasFlashlight") ~= true then
L184: or player:GetAttribute("CampaignStatus") ~= "Active"
L192: player:SetAttribute("HoldBreath", state.oxygen.holding)
L227: local level = tonumber(player:GetAttribute("PerkBateria")) or 0
L230: if player:GetAttribute("SpareBattery") == true then
L231: player:SetAttribute("SpareBattery", false)
L236: not Config.House.Enabled or player:GetAttribute("HasFlashlight") == true
L250: and player:GetAttribute("CampaignStatus") == "Active"
L257: player:SetAttribute("DeathCause", "oxygen")
L262: player:SetAttribute("Oxygen", math.floor(state.oxygen.value))
L263: player:SetAttribute("HoldBreath", state.oxygen.holding)
L271: player:SetAttribute("BreathIntensity", if state.oxygen.holding then 0 else intensity)
L285: math.max(0.5, Perks.factor("silencio", tonumber(player:GetAttribute("PerkSilencio")) or 0))
L352: BatteryModel.setOn(state.battery, not Config.House.Enabled or player:GetAttribute("HasFlashlight") == true)
L355: player:SetAttribute("Hidden", "")
L356: player:SetAttribute("HiddenSeen", false)
L357: player:SetAttribute("HoldBreath", false)
L358: player:SetAttribute("Gasps", state.gasps)
L413: player:SetAttribute("HiddenAt", front)
L414: player:SetAttribute("HiddenSeen", sawEntry)
L415: player:SetAttribute("HideEye", eye)
L416: player:SetAttribute("HoldBreath", false)
L417: player:SetAttribute("Hidden", id)
L439: player:SetAttribute("Hidden", "")
L440: player:SetAttribute("HiddenSeen", false)
L441: player:SetAttribute("HoldBreath", false)
L455: BatteryModel.setOn(state.battery, not Config.House.Enabled or player:GetAttribute("HasFlashlight") == true)
L470: player:SetAttribute("HasFlashlight", true)
~~~

## src/ServerScriptService/Server/Services/PresenceService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/PresenceService.luau) · 40 linhas · SHA-256: fa0bf1cc5ff7b7e419e9260574f5d6b517fbb11e3042c35640e8a9fadc97df04

### Funções nomeadas / callbacks atribuídos

~~~text
L24: function PresenceService.Start()
~~~

### Dependências literais

- L13: @game/ReplicatedStorage/Shared/Game/CharacterPose → [fonte](../../src/ReplicatedStorage/Shared/Game/CharacterPose.luau)
- L14: @game/ReplicatedStorage/Shared/Net/Guard → [fonte](../../src/ReplicatedStorage/Shared/Net/Guard.luau)
- L15: ../Net/ServerNet → [fonte](../../src/ServerScriptService/Server/Net/ServerNet.luau)

### Listeners / registros / callbacks

~~~text
L25: ServerNet.onEvent("SetLook", {
L32: Players.PlayerAdded:Connect(function(player)
~~~

### Rede

~~~text
L25: ServerNet.onEvent("SetLook", {
~~~

### Estado observado / publicado

~~~text
L30: player:SetAttribute(ATTRIBUTE, CharacterPose.quantizePitch(pitch))
L33: player:SetAttribute(ATTRIBUTE, 0)
L36: player:SetAttribute(ATTRIBUTE, 0)
~~~

## src/ServerScriptService/Server/Services/PropService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/PropService.luau) · 143 linhas · SHA-256: 59cc6e3fb84d748586f1627d31b920dfca939230231900c0b8e9219b4532dbcb

### Funções nomeadas / callbacks atribuídos

~~~text
L28: local function fall(item: FeatureBuilder.FallableHandle, from: Vector3)
L67: local function tick()
L98: function PropService.Start()
L116: function PropService.reset()
L133: function PropService.debugFall(id: string): boolean
~~~

### Dependências literais

- L13: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L14: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L15: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L16: ../World/FeatureBuilder → [fonte](../../src/ServerScriptService/Server/World/FeatureBuilder.luau)
- L17: ./CreatureService → [fonte](../../src/ServerScriptService/Server/Services/CreatureService.luau)
- L18: ./WorldService → [fonte](../../src/ServerScriptService/Server/Services/WorldService.luau)

### Estado observado / publicado

~~~text
L32: item.model:SetAttribute("Fallen", true)
L68: if GameState.get("Phase") ~= "Playing" then
L109: GameState.observe(function(snapshot, changed)
L128: item.model:SetAttribute("Fallen", false)
~~~

## src/ServerScriptService/Server/Services/RewardService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/RewardService.luau) · 178 linhas · SHA-256: 3859b04d73840d5c428fc59b4d48c91d277573741f6099c537f092b65248c394

### Funções nomeadas / callbacks atribuídos

~~~text
L34: local function soloSummary(won: boolean): Economy.RunSummary
L45: local function campaignAwards(won: boolean)
L73: local function onEnd(phase: string)
L91: local function decodeRoster(state: Instance): { any }?
L98: local function payChapter(state: Instance)
L131: local function watchStory(state: Instance)
L163: function RewardService.Start()
~~~

### Dependências literais

- L22: @game/ReplicatedStorage/Shared/Game/Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L23: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L24: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L25: ../Campaign/CampaignMode → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignMode.luau)
- L26: ./StoreService → [fonte](../../src/ServerScriptService/Server/Services/StoreService.luau)

### Listeners / registros / callbacks

~~~text
L133: state:GetAttributeChangedSignal("Roster"):Connect(function()
L143: state:GetAttributeChangedSignal("Phase"):Connect(function()
~~~

### Estado observado / publicado

~~~text
L39: fuses = GameState.get("FusesCollected") or 0,
L40: breakers = GameState.get("BreakersOn") == true,
L51: return HttpService:JSONDecode((state:GetAttribute("Roster") :: string?) or "[]")
L56: local stage = (state:GetAttribute("Stage") :: number?) or 1
L74: local round = GameState.get("RoundId") or 0
L93: return HttpService:JSONDecode((state:GetAttribute("Roster") :: string?) or "[]")
L99: local chapter = tonumber(state:GetAttribute("Stage")) or 0
L100: local key = `{GameState.get("RoundId") or 0}:{chapter}`
L132: local lastPhase = state:GetAttribute("Phase")
L133: state:GetAttributeChangedSignal("Roster"):Connect(function()
L135: if roster and state:GetAttribute("Phase") == "Playing" then
L143: state:GetAttributeChangedSignal("Phase"):Connect(function()
L144: local phase = state:GetAttribute("Phase")
L148: local story = state:GetAttribute("GameMode") == "Story"
L170: GameState.observe(function(snapshot, changed)
~~~

## src/ServerScriptService/Server/Services/RoundService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/RoundService.luau) · 671 linhas · SHA-256: 675b4c4c76b1be7e9efaec07fb7f8ca4cbe99d33b30378748c70ee5a86102f8e

### Funções nomeadas / callbacks atribuídos

~~~text
L52: local function publish()
L66: local function setPhase(nextPhase: RoundRules.Phase): boolean
L77: local function characterParts(player: Player): (Model?, BasePart?, Humanoid?)
L87: local function setFrozen(player: Player, frozen: boolean)
L95: local function endRound(player: Player, result: "Won" | "Lost")
L107: local function spawnPlayer(player: Player, at: CFrame, battery: number?)
L133: local function awaken()
L142: local function noise(position: Vector3, radius: number)
L147: local function canReach(character: Model, item: WorldService.Interactable): boolean
L167: local function saveCheckpoint(player: Player?)
L183: local function powerOn(myRound: number, player: Player?)
L201: local function breakerMask(): { boolean }
L209: local function pressBreaker(player: Player, id: string, position: Vector3): Response
L252: local function useDoor(player: Player, id: string, action: string, position: Vector3): Response
L279: local function hide(player: Player, id: string, position: Vector3, alive: boolean): Response
L311: local function interact(player: Player, id: string, action: string?): Response
L403: local function tick()
L430: local function beginPlaying(myRound: number, delay: number)
L445: local function enterIntro()
L454: local function restart()
L484: local function continueFromCheckpoint()
L543: function RoundService.Init()
L555: function RoundService.Start()
L579: local function onPlayer(player: Player)
L606: function RoundService.restart()
L610: function RoundService.continueFromCheckpoint()
L614: function RoundService.lose(player: Player)
L618: function RoundService.win(player: Player)
L622: function RoundService.getPhase(): RoundRules.Phase
L627: function RoundService.debugGrant(what: string, player: Player?)
L651: function RoundService.snapshot(): { [string]: any }
~~~

### Dependências literais

- L17: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L19: ../Campaign/CampaignMode → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignMode.luau)
- L20: ../Campaign/CampaignRuntime → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignRuntime.luau)
- L22: @game/ReplicatedStorage/Shared/Game/GameState → [fonte](../../src/ReplicatedStorage/Shared/Game/GameState.luau)
- L23: @game/ReplicatedStorage/Shared/Net/Guard → [fonte](../../src/ReplicatedStorage/Shared/Net/Guard.luau)
- L24: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L25: @game/ReplicatedStorage/Shared/Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)
- L26: ../Game/BreakerPuzzle → [fonte](../../src/ServerScriptService/Server/Game/BreakerPuzzle.luau)
- L27: ../Game/Checkpoint → [fonte](../../src/ServerScriptService/Server/Game/Checkpoint.luau)
- L28: ../Game/HideRules → [fonte](../../src/ServerScriptService/Server/Game/HideRules.luau)
- L29: ../Game/Objectives → [fonte](../../src/ServerScriptService/Server/Game/Objectives.luau)
- L30: ../Game/RoundRules → [fonte](../../src/ServerScriptService/Server/Game/RoundRules.luau)
- L31: ../Net/ServerNet → [fonte](../../src/ServerScriptService/Server/Net/ServerNet.luau)
- L32: ./CollectibleService → [fonte](../../src/ServerScriptService/Server/Services/CollectibleService.luau)
- L33: ./CreatureService → [fonte](../../src/ServerScriptService/Server/Services/CreatureService.luau)
- L34: ./PlayerStateService → [fonte](../../src/ServerScriptService/Server/Services/PlayerStateService.luau)
- L35: ./WorldService → [fonte](../../src/ServerScriptService/Server/Services/WorldService.luau)

### Listeners / registros / callbacks

~~~text
L122: humanoid.Died:Connect(function()
L549: CreatureService.onCapture(function(player: Player)
L552: PlayerStateService.setNoiseHandler(noise)
L556: ServerNet.onInvoke("Interact", {
L564: ServerNet.onInvoke("RequestRestart", {
L590: Players.PlayerAdded:Connect(onPlayer)
~~~

### Rede

~~~text
L556: ServerNet.onInvoke("Interact", {
L564: ServerNet.onInvoke("RequestRestart", {
~~~

### Estado observado / publicado

~~~text
L53: GameState.set("FusesTotal", objectives.total)
L54: GameState.set("FusesCollected", Objectives.collectedCount(objectives))
L55: GameState.set("FusesHeld", objectives.held)
L56: GameState.set("FusesInserted", objectives.inserted)
L57: GameState.set("PowerOn", objectives.powerOn)
L58: GameState.set("GateOpen", objectives.gateOpen)
L59: GameState.set("HasKey", objectives.hasKey)
L60: GameState.set("BreakersOn", objectives.breakersOn)
L61: GameState.set("Objective", Objectives.objectiveKey(objectives))
L62: GameState.set("CreatureActive", CreatureService.isActive())
L63: GameState.set("CheckpointReady", Checkpoint.isUsable(checkpoint))
L73: GameState.set("Phase", nextPhase)
L100: GameState.set("RoundEndedAt", workspace:GetServerTimeNow())
L437: GameState.set("RoundStartedAt", workspace:GetServerTimeNow())
L469: GameState.set("BreakerOrder", order)
L472: GameState.set("FromCheckpoint", false)
L473: GameState.set("RoundId", roundId)
L474: GameState.set("RoundStartedAt", 0)
L475: GameState.set("RoundEndedAt", 0)
L517: GameState.set("FromCheckpoint", true)
L518: GameState.set("RoundId", roundId)
L519: GameState.set("RoundStartedAt", 0)
L520: GameState.set("RoundEndedAt", 0)
~~~

## src/ServerScriptService/Server/Services/StoreService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/StoreService.luau) · 886 linhas · SHA-256: 8d17419f28040e4962c1146b2c5e845282a8e1f8ed044428dda9cf34d203f90e

### Funções nomeadas / callbacks atribuídos

~~~text
L82: local function random(): number
L86: local function today(): number
L90: local function ownsPass(player: Player, key: string): boolean
L95: local function setPass(player: Player, key: string)
L101: local function isVip(player: Player): boolean
L105: local function activeSeason(): SeasonCatalog.SeasonDef?
L109: local function hasSeasonPass(player: Player, season: SeasonCatalog.SeasonDef): boolean
L114: local function seasonOfPass(key: string): SeasonCatalog.SeasonDef?
L123: local function productById(id: number, kind: "product" | "pass"): StoreCatalog.Product?
L135: local function publish(player: Player)
L212: local function notify(player: Player, kind: string, granted: Economy.Granted?, extra: { [string]: any }?)
L234: local function seasonChanges(result: Season.SeasonGranted?): { EconomyEvents.Change }
L245: local function addSeasonXp(player: Player, data: Types.PlayerData, amount: number): Season.SeasonGranted?
L254: local function notifySeason(player: Player, result: Season.SeasonGranted?, extra: { [string]: any }?)
L279: local function deliver(player: Player, product: StoreCatalog.Product, purchaseId: string): boolean
L314: local function grantStoryPassItems(player: Player)
L324: local function grantPass(player: Player, product: StoreCatalog.Product)
L346: local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
L365: local function refreshPasses(player: Player)
L378: local function refreshPolicy(player: Player)
L393: local function syncSeason(player: Player)
L408: local function onPlayer(player: Player)
L420: local function mutate(player: Player, mutator: (data: Types.PlayerData) -> StoreResponse): StoreResponse
L434: local function requestProduct(player: Player, key: string): StoreResponse
L473: local function handle(player: Player, action: string, arg: string?): StoreResponse
L629: function StoreService.Start()
L673: function StoreService.isVip(player: Player): boolean
L678: function StoreService.equipped(player: Player, kind: StoreCatalog.ItemKind): string
L691: function StoreService.awardTask(player: Player, contributed: boolean): Economy.Granted?
L713: function StoreService.awardCoin(player: Player, fichas: number, xp: number): Economy.Granted?
L732: function StoreService.awardRun(player: Player, summary: Economy.RunSummary, sku: string?): Economy.Granted?
L762: function StoreService.awardTape(player: Player, tapeId: string, finder: string?): boolean
L789: function StoreService.ownedTapes(player: Player): { [string]: boolean }
L801: function StoreService.onChanged(callback: (Player) -> ())
L807: function StoreService.perkLevel(player: Player, id: string): number
L813: function StoreService.inLoadout(player: Player, id: string): boolean
L819: function StoreService.consume(player: Player, id: string): boolean
L831: function StoreService.setContinueHandler(handler: (Player) -> (boolean, string?))
L835: function StoreService.hasStoryPass(player: Player): boolean
L840: function StoreService.awardStory(player: Player, chapter: number, flawless: boolean): StoryRewards.Outcome?
L869: function StoreService.debugGrant(player: Player, fichas: number, creditos: number)
L877: function StoreService.debugSeasonXp(player: Player, amount: number)
~~~

### Dependências literais

- L38: @game/ReplicatedStorage/Shared/Game/Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L39: @game/ReplicatedStorage/Shared/Game/Perks → [fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau)
- L40: @game/ReplicatedStorage/Shared/Game/StoryRewards → [fonte](../../src/ReplicatedStorage/Shared/Game/StoryRewards.luau)
- L41: @game/ReplicatedStorage/Shared/Game/TaskRewards → [fonte](../../src/ReplicatedStorage/Shared/Game/TaskRewards.luau)
- L42: @game/ReplicatedStorage/Shared/Net/Guard → [fonte](../../src/ReplicatedStorage/Shared/Net/Guard.luau)
- L43: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L44: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)
- L45: @game/ReplicatedStorage/Shared/Game/Season → [fonte](../../src/ReplicatedStorage/Shared/Game/Season.luau)
- L46: @game/ReplicatedStorage/Shared/Game/SeasonCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/SeasonCatalog.luau)
- L47: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L48: @game/ReplicatedStorage/Shared/Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)
- L49: ../Game/EconomyEvents → [fonte](../../src/ServerScriptService/Server/Game/EconomyEvents.luau)
- L50: ../Net/ServerNet → [fonte](../../src/ServerScriptService/Server/Net/ServerNet.luau)
- L51: ./PlayerDataService → [fonte](../../src/ServerScriptService/Server/Services/PlayerDataService.luau)
- L52: ./TelemetryService → [fonte](../../src/ServerScriptService/Server/Services/TelemetryService.luau)

### Listeners / registros / callbacks

~~~text
L630: ServerNet.onInvoke("Store", {
L654: MarketplaceService.PromptGamePassPurchaseFinished:Connect(
L663: Players.PlayerAdded:Connect(onPlayer)
L664: Players.PlayerRemoving:Connect(function(player: Player)
L831: function StoreService.setContinueHandler(handler: (Player) -> (boolean, string?))
~~~

### Rede

~~~text
L227: local ok, remote = pcall(Remotes.serverEvent, "StoreNotice")
L229: remote:FireClient(player, payload)
L630: ServerNet.onInvoke("Store", {
~~~

### Estado observado / publicado

~~~text
L155: player:SetAttribute("Fichas", data.wallet.fichas)
L156: player:SetAttribute("Creditos", data.wallet.creditos)
L157: player:SetAttribute("Xp", data.xp)
L158: player:SetAttribute("Level", level)
L159: player:SetAttribute("Vip", vip)
L160: player:SetAttribute("PaidRandomRestricted", restrictedCache[player] ~= false)
L161: player:SetAttribute("Owned", HttpService:JSONEncode(owned))
L162: player:SetAttribute("Tapes", HttpService:JSONEncode(tapes))
L163: player:SetAttribute("DailyStreak", streakDay)
L164: player:SetAttribute("DailyClaimable", claimable)
L165: player:SetAttribute("SpinsLeft", Economy.spinsLeft(data, day, vip))
L166: player:SetAttribute("StarterBought", data.oncePurchases.pacote_inicial ~= nil)
L167: player:SetAttribute("KitBought", data.oncePurchases.kit_sobrevivente ~= nil)
L168: player:SetAttribute("EquipFlashlight", Economy.equipped(data, "flashlight", vip))
L169: player:SetAttribute("EquipUniform", Economy.equipped(data, "uniform", vip))
L170: player:SetAttribute("EquipFilter", Economy.equipped(data, "filter", vip))
L171: player:SetAttribute("Title", Economy.equipped(data, "title", vip))
L172: player:SetAttribute("SeasonId", if season then season.id else "")
L173: player:SetAttribute("SeasonXp", if season then Season.xpOf(data, season) else 0)
L174: player:SetAttribute("SeasonPremium", season ~= nil and hasSeasonPass(player, season))
L180: player:SetAttribute(PERK_ATTRIBUTES[perk.id], perkLevel)
L190: player:SetAttribute("Perks", HttpService:JSONEncode(levels))
L191: player:SetAttribute("Consumables", HttpService:JSONEncode(stock))
L192: player:SetAttribute("Loadout", HttpService:JSONEncode(kit))
L193: player:SetAttribute("BoostFichasUntil", data.boosts.fichasUntil)
L194: player:SetAttribute("BoostXpUntil", data.boosts.xpUntil)
L203: player:SetAttribute("HousePreferences", HttpService:JSONEncode(data.house.preferences))
L204: player:SetAttribute("StoryProgress", HttpService:JSONEncode({ cleared = cleared, flawless = flawless }))
L205: player:SetAttribute("StoryPass", ownsPass(player, StoreCatalog.StoryPassKey))
L206: player:SetAttribute("StoreReady", true)
~~~

## src/ServerScriptService/Server/Services/TelemetryService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/TelemetryService.luau) · 170 linhas · SHA-256: 8a0c7ddc8ddbba87986f30ab7f402d5561c367f40b77b2cd5784139f026225c8

### Funções nomeadas / callbacks atribuídos

~~~text
L34: local function remember(entry: { [string]: any })
L42: local function customFields(values: { string }): { [string]: string }?
L56: local function funnelOf(player: Player): StoreFunnel.State
L65: local function sendSteps(player: Player, state: StoreFunnel.State, steps: { StoreFunnel.Step })
L99: function TelemetryService.economy(player: Player, events: { EconomyEvents.Event })
L130: function TelemetryService.storeOpened(player: Player)
L135: function TelemetryService.offerViewed(player: Player, offer: string)
L141: function TelemetryService.purchased(player: Player, kind: string, currency: string)
L147: function TelemetryService.history(): { { [string]: any } }
L151: function TelemetryService.Start()
~~~

### Dependências literais

- L20: @game/ReplicatedStorage/Shared/Net/Guard → [fonte](../../src/ReplicatedStorage/Shared/Net/Guard.luau)
- L21: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L22: ../Game/EconomyEvents → [fonte](../../src/ServerScriptService/Server/Game/EconomyEvents.luau)
- L23: ../Game/StoreFunnel → [fonte](../../src/ServerScriptService/Server/Game/StoreFunnel.luau)
- L24: ../Net/ServerNet → [fonte](../../src/ServerScriptService/Server/Net/ServerNet.luau)

### Listeners / registros / callbacks

~~~text
L152: ServerNet.onEvent("StoreTrack", {
L165: Players.PlayerRemoving:Connect(function(player: Player)
~~~

### Rede

~~~text
L152: ServerNet.onEvent("StoreTrack", {
~~~

## src/ServerScriptService/Server/Services/WorldService.luau

[Abrir fonte](../../src/ServerScriptService/Server/Services/WorldService.luau) · 1026 linhas · SHA-256: 6618fea9be6b6ec59da6f575d555c9766a35299aca1d90d1032a5609f1a45218

### Funções nomeadas / callbacks atribuídos

~~~text
L63: local function getWorld(): MapBuilder.World
L68: local function getFeatures(): FeatureBuilder.Built
L73: local function vec(p: Layout.Point): Vector3
L78: local function removeTemplateWorld()
L87: local function applyLighting(power: boolean)
L108: local function rgb(v: { number }): Color3
L121: local function lights(): { BasePart }
L132: local function setLightPart(part: BasePart, on: boolean)
L149: local function doorPose(door: MapBuilder.DoorHandle, angle: number): CFrame
L153: local function angleFor(door: MapBuilder.DoorHandle, state: DoorState): number
L162: local function currentAngle(door: MapBuilder.DoorHandle): number
L178: local function refreshDoorPrompt(door: MapBuilder.DoorHandle)
L202: local function animateDoor(door: MapBuilder.DoorHandle, state: DoorState, instant: boolean?)
L248: local function setLocked(door: MapBuilder.DoorHandle, value: boolean)
L260: local function twitch(door: MapBuilder.DoorHandle, strength: number)
L279: local function setModelShown(model: Model, shown: boolean, home: Instance)
L283: local function setFeatureEnabled(id: string, enabled: boolean)
L291: local function pickupsFolder(): Instance
L301: function WorldService.Init()
L348: function WorldService.get(): MapBuilder.World
L352: function WorldService.features(): FeatureBuilder.Built
L356: function WorldService.rebuildSector(plan: ProceduralLayout.Plan)
L364: function WorldService.patrolNodes(): { Layout.Point }
L394: function WorldService.creatureSpawns(): { Layout.Point }
L407: function WorldService.spawnCFrame(): CFrame
L411: function WorldService.checkpointCFrame(): CFrame
L419: function WorldService.interactable(id: string): Interactable?
L427: function WorldService.setInteractEnabled(id: string, enabled: boolean)
L438: function WorldService.resetRound(rng: Random, plan: ProceduralLayout.Plan?)
L507: function WorldService.setFuseCollected(id: string)
L515: function WorldService.setPanelFuses(count: number)
L526: function WorldService.setPower(on: boolean)
L552: function WorldService.isPowered(): boolean
L559: function WorldService.setBreakers(up: { boolean })
L571: function WorldService.setProcedure(order: string)
L578: function WorldService.breakerFeedback(kind: "ok" | "wrong" | "solved" | "denied")
L605: function WorldService.setTaken(id: string)
L615: function WorldService.takenSnapshot(): { [string]: boolean }
L620: function WorldService.applyTaken(snapshot: { [string]: boolean })
L628: function WorldService.locker(id: string): FeatureBuilder.LockerHandle?
L633: function WorldService.swingLocker(id: string)
L652: function WorldService.door(id: string): MapBuilder.DoorHandle?
L656: function WorldService.doorState(id: string): DoorState
L660: function WorldService.isLocked(id: string): boolean
L665: function WorldService.useDoor(id: string): (boolean, DoorState)
L676: function WorldService.altDoor(id: string): (boolean, DoorState)
L687: function WorldService.toggleDoor(id: string): (boolean, boolean)
L692: function WorldService.rattleDoor(id: string)
L705: function WorldService.unlockDoor(id: string, player: Player): boolean
L730: function WorldService.closedDoorNear(position: Vector3, range: number): MapBuilder.DoorHandle?
L743: function WorldService.lockedDoorNear(position: Vector3, range: number): MapBuilder.DoorHandle?
L755: function WorldService.bangDoor(door: MapBuilder.DoorHandle)
L764: function WorldService.forceOpenDoor(door: MapBuilder.DoorHandle)
L771: function WorldService.doorSnapshot(): ({ [string]: DoorState }, { [string]: boolean })
L775: function WorldService.applyDoors(states: { [string]: DoorState }, lockedStates: { [string]: boolean })
L784: function WorldService.openGate(): boolean
L804: function WorldService.isInsideBuilding(position: Vector3): boolean
L816: function WorldService.isInExitZone(position: Vector3): boolean
L833: function WorldService.setHouseStage(chapter: number, seed: number?, mode: string?)
L891: function WorldService.upperNoise()
L904: function WorldService.forestPressure(now: number, playing: boolean)
L909: function WorldService.houseEvent(event: string?)
L950: function WorldService.houseRuins()
L995: function WorldService.setHouseDestruction(on: boolean)
~~~

### Dependências literais

- L13: @game/ReplicatedStorage/Shared/Game/LightingProfile → [fonte](../../src/ReplicatedStorage/Shared/Game/LightingProfile.luau)
- L16: @game/ReplicatedStorage/Shared/Game/Audio → [fonte](../../src/ReplicatedStorage/Shared/Game/Audio.luau)
- L17: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L18: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L19: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L20: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L21: ../World/Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L22: ../World/ArtBuilder → [fonte](../../src/ServerScriptService/Server/World/ArtBuilder.luau)
- L23: ../World/FeatureBuilder → [fonte](../../src/ServerScriptService/Server/World/FeatureBuilder.luau)
- L24: ../World/Features → [fonte](../../src/ServerScriptService/Server/World/Features.luau)
- L25: ../World/Layout → [fonte](../../src/ServerScriptService/Server/World/Layout.luau)
- L26: ../World/MapBuilder → [fonte](../../src/ServerScriptService/Server/World/MapBuilder.luau)
- L27: ../World/Palette → [fonte](../../src/ServerScriptService/Server/World/Palette.luau)
- L28: ../World/ProceduralLayout → [fonte](../../src/ServerScriptService/Server/World/ProceduralLayout.luau)
- L29: ../World/SectorBuilder → [fonte](../../src/ServerScriptService/Server/World/SectorBuilder.luau)
- L38: ../World/HouseBuilder → [fonte](../../src/ServerScriptService/Server/World/HouseBuilder.luau)
- L39: ../World/HouseScenery → [fonte](../../src/ServerScriptService/Server/World/HouseScenery.luau)
- L40: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L41: ../Campaign/HouseLevelPlan → [fonte](../../src/ServerScriptService/Server/Campaign/HouseLevelPlan.luau)
- L42: ../World/HouseLevelBuilder → [fonte](../../src/ServerScriptService/Server/World/HouseLevelBuilder.luau)
- L43: ../World/HouseAccess → [fonte](../../src/ServerScriptService/Server/World/HouseAccess.luau)
- L44: @game/ReplicatedStorage/Shared/Game/ForestCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestCatalog.luau)
- L45: ../World/ForestBuilder → [fonte](../../src/ServerScriptService/Server/World/ForestBuilder.luau)

### Estado observado / publicado

~~~text
L116: Lighting:SetAttribute("S9PowerOn", power)
L118: Lighting:SetAttribute("BaseFogEnd", Lighting.FogEnd)
L137: local kind = part:GetAttribute(Tags.Attr.LightKind)
L181: panel:SetAttribute("DoorState", state)
L182: panel:SetAttribute("Locked", locked[door.id] == true)
L184: panel:SetAttribute(Tags.Attr.InteractPrompt, Text.Prompts.DoorLocked)
L185: panel:SetAttribute("InteractAlt", nil)
L187: panel:SetAttribute(Tags.Attr.InteractPrompt, Text.Prompts.DoorClose)
L188: panel:SetAttribute("InteractAlt", Text.Prompts.DoorCrack)
L190: panel:SetAttribute(Tags.Attr.InteractPrompt, Text.Prompts.DoorOpen)
L191: panel:SetAttribute("InteractAlt", Text.Prompts.DoorShut)
L193: panel:SetAttribute(Tags.Attr.InteractPrompt, Text.Prompts.DoorOpen)
L194: panel:SetAttribute("InteractAlt", Text.Prompts.DoorCrack)
L255: door.panel:SetAttribute("LockState", if value then "locked" else "unlocked")
L287: item.focus:SetAttribute(Tags.Attr.InteractEnabled, enabled)
L431: item.focus:SetAttribute(Tags.Attr.InteractEnabled, enabled)
L523: panel.focus:SetAttribute("Fuses", count)
L530: local kind = part:GetAttribute(Tags.Attr.LightKind)
L574: b.box:SetAttribute("Order", order)
L592: b.box:SetAttribute("Spark", sparkCount)
L599: b.box:SetAttribute("Solved", os.clock())
L710: door.panel:SetAttribute("LockState", "unlocking")
L711: door.panel:SetAttribute("UnlockBy", player.UserId)
L756: door.panel:SetAttribute("BangSerial", ((door.panel:GetAttribute("BangSerial") :: number?) or 0) + 1)
L835: getWorld().root:SetAttribute("HouseChapter", chapter)
L836: getWorld().root:SetAttribute("ForestBlackout", false)
L838: getWorld().root:SetAttribute("ForestActive", chapter >= 6)
L916: forest:SetAttribute("LastEvent", event)
L918: forest:SetAttribute("ForcedBlackoutUntil", workspace:GetServerTimeNow() + 7)
~~~

## src/ServerScriptService/Server/World/ArtBuilder.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/ArtBuilder.luau) · 189 linhas · SHA-256: c1d395b0e70bb3d6d622b2a341c240e05dc1c6bd674308f1ec1560e029d87b15

### Funções nomeadas / callbacks atribuídos

~~~text
L14: local function detail(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
L20: local function cabinet(parent: Instance, position: Vector3, yaw: number, label: string)
L57: local function dressRooms(root: Instance)
L115: local function surfaceKind(part: BasePart): string?
L137: function Art.build(world: Instance)
L163: local function rank(part: BasePart): number
~~~

### Dependências literais

- L4: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L5: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L6: ./Layout → [fonte](../../src/ServerScriptService/Server/World/Layout.luau)
- L7: ./Palette → [fonte](../../src/ServerScriptService/Server/World/Palette.luau)
- L8: ./ProceduralLayout → [fonte](../../src/ServerScriptService/Server/World/ProceduralLayout.luau)

### Estado observado / publicado

~~~text
L24: body:SetAttribute("SurfaceStyle", "paint")
L116: local explicit = part:GetAttribute("SurfaceStyle")
L147: object:SetAttribute("SurfaceStyle", kind)
L186: root:SetAttribute("SurfaceCandidates", #surfaces)
~~~

## src/ServerScriptService/Server/World/Build.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/Build.luau) · 215 linhas · SHA-256: 2025f634c85b8287090279da0b2a25f31042bb13a1135592bea20d61150c50af

### Funções nomeadas / callbacks atribuídos

~~~text
L35: function Build.folder(parent: Instance, name: string): Folder
L42: function Build.model(parent: Instance, name: string): Model
L49: function Build.part(
L81: function Build.box(
L94: function Build.block(
L108: function Build.cylinder(
L129: function Build.light(
L153: function Build.sign(
L201: function Build.sound(part: Instance, name: string, id: string, volume: number, speed: number?, looped: boolean?): Sound
~~~

### Dependências literais

- L9: @game/ReplicatedStorage/Shared/Game/PixelText → [fonte](../../src/ReplicatedStorage/Shared/Game/PixelText.luau)
- L10: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)

### Estado observado / publicado

~~~text
L145: part:SetAttribute(Tags.Attr.LightKind, kind)
L146: part:SetAttribute(Tags.Attr.Flicker, flicker == true)
L147: part:SetAttribute("BaseBrightness", brightness)
~~~

## src/ServerScriptService/Server/World/Expansion.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/Expansion.luau) · 236 linhas · SHA-256: 866001d336215b568ae502b5a775c9e63f415c937d6d4157f867c7b79ce309dc

### Funções nomeadas / callbacks atribuídos

~~~text
L11: local function sign(parent: Instance, name: string, p: Vector3, facing: Vector3, text: string)
L18: local function fence(parent: Instance, a: Vector3, b: Vector3)
L35: local function roofs(parent: Instance)
L49: local function workshop(parent: Instance)
L66: local function gallery(parent: Instance)
L79: local function control(parent: Instance)
L116: local function archive(parent: Instance)
L142: local function transformer(parent: Instance, x: number, z: number, index: number)
L184: local function switchyard(parent: Instance)
L213: function Expansion.build(parent: Instance)
~~~

### Dependências literais

- L3: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L4: ./Layout → [fonte](../../src/ServerScriptService/Server/World/Layout.luau)
- L5: ./Palette → [fonte](../../src/ServerScriptService/Server/World/Palette.luau)
- L6: ./Props → [fonte](../../src/ServerScriptService/Server/World/Props.luau)

## src/ServerScriptService/Server/World/FeatureBuilder.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/FeatureBuilder.luau) · 658 linhas · SHA-256: 46e9c30dc3111447ceed647c73fdbd6dc4b3ba0a107cbca2f8199449edcb4347

### Funções nomeadas / callbacks atribuídos

~~~text
L81: local function vec(p: Features.Point): Vector3
L85: local function register(
L110: local function clip(part: Instance, name: string, clipName: string, speed: number?, looped: boolean?): Sound
L122: local function buildLocker(built: Built, parent: Instance, spec: Features.Locker)
L128: local function local3(x: number, y: number, z: number): CFrame
L207: local function buildKey(built: Built, parent: Instance, spot: Features.Spot)
L239: local function buildBattery(built: Built, parent: Instance, spot: Features.Spot)
L260: local function buildBreakers(built: Built, parent: Instance)
L368: local function buildFallable(built: Built, parent: Instance, spec: Features.Fallable)
L372: local function add(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): BasePart
L446: local function buildSurfaces(parent: Instance)
L496: local function buildCrawl(parent: Instance)
L541: local function buildRadio(parent: Instance): BasePart
L558: local function buildIndicators(parent: Instance)
L560: local function gauge(center: Vector3, facing: Vector3, kind: string)
L605: local function buildZones(parent: Instance)
L622: function FeatureBuilder.build(parent: Instance): Built
~~~

### Dependências literais

- L12: @game/ReplicatedStorage/Shared/Game/Audio → [fonte](../../src/ReplicatedStorage/Shared/Game/Audio.luau)
- L13: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L14: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L15: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L16: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L17: ./Features → [fonte](../../src/ServerScriptService/Server/World/Features.luau)
- L18: ./Layout → [fonte](../../src/ServerScriptService/Server/World/Layout.luau)
- L19: ./Palette → [fonte](../../src/ServerScriptService/Server/World/Palette.luau)

### Estado observado / publicado

~~~text
L95: focus:SetAttribute(Tags.Attr.InteractId, id)
L96: focus:SetAttribute(Tags.Attr.InteractPrompt, prompt)
L97: focus:SetAttribute(Tags.Attr.InteractDistance, maxDistance)
L98: focus:SetAttribute(Tags.Attr.InteractEnabled, true)
L433: model:SetAttribute("Fallen", false)
L462: plank:SetAttribute("Surface", "wood")
L552: led:SetAttribute("Indicator", "Blink")
L581: needle:SetAttribute("Indicator", kind)
L582: needle:SetAttribute("Pivot", frame * CFrame.new(0, 0, -0.05))
L598: led:SetAttribute("Indicator", "PanelLed")
L599: led:SetAttribute("Index", i)
L617: zone:SetAttribute("Room", room.id)
L618: zone:SetAttribute("Reverb", Features.Reverb[room.id] or "Room")
~~~

## src/ServerScriptService/Server/World/Features.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/Features.luau) · 186 linhas · SHA-256: 444c4ea55506450fbfc3933641aac92e2622ed037d184e35fdc223caefbc82ed

### Funções nomeadas / callbacks atribuídos

~~~text
L175: function Features.pick<T>(list: { T }, count: number, nextInteger: (number, number) -> number): { T }
~~~

## src/ServerScriptService/Server/World/ForestBuilder.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/ForestBuilder.luau) · 402 linhas · SHA-256: 9e93fc55975a05b0f6cc0a5e7ae069fe7b4d5ee1a120e339b4303b4e326d028a

### Funções nomeadas / callbacks atribuídos

~~~text
L14: local function block(
L31: function Builder.clear(parent: Instance, features: FeatureBuilder.Built)
L42: function Builder.build(parent: Instance, chapter: number, seed: number, features: FeatureBuilder.Built): Folder
L85: local function tree(container: Instance, x: number, z: number, distant: boolean)
L381: function Builder.pressure(parent: Instance, now: number, chapter: number, playing: boolean)
~~~

### Dependências literais

- L4: @game/ReplicatedStorage/Shared/Game/ForestCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestCatalog.luau)
- L5: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L6: @game/ReplicatedStorage/Shared/Game/Audio → [fonte](../../src/ReplicatedStorage/Shared/Game/Audio.luau)
- L7: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L8: ./FeatureBuilder → [fonte](../../src/ServerScriptService/Server/World/FeatureBuilder.luau)
- L9: ./ForestLayout → [fonte](../../src/ServerScriptService/Server/World/ForestLayout.luau)
- L10: @game/ReplicatedStorage/Shared/Game/ForestThreat → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestThreat.luau)

### Estado observado / publicado

~~~text
L45: root:SetAttribute("Chapter", chapter)
L46: root:SetAttribute("HorrorForest", true)
L95: trunk:SetAttribute("ForestTree", true)
L96: trunk:SetAttribute("NearTrail", not distant)
L167: cap:SetAttribute("VisualDetail", true)
L265: door:SetAttribute(Tags.Attr.InteractId, id)
L266: door:SetAttribute(Tags.Attr.InteractPrompt, "ESCONDER NO ABRIGO")
L267: door:SetAttribute(Tags.Attr.InteractEnabled, true)
L268: door:SetAttribute(Tags.Attr.InteractDistance, 8)
L386: local forced = tonumber(forest:GetAttribute("ForcedBlackoutUntil")) or 0
L388: if forest:GetAttribute("Blackout") == dark then
L391: forest:SetAttribute("Blackout", dark)
L392: parent:SetAttribute("ForestBlackout", dark)
L394: if part:GetAttribute(Tags.Attr.LightKind) == "ForestGuide" then
~~~

## src/ServerScriptService/Server/World/ForestLayout.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/ForestLayout.luau) · 48 linhas · SHA-256: c21801ae5e6cf250548f6453f4530f86c06ccb203c5b97173982ed3bb4d02c99

### Funções nomeadas / callbacks atribuídos

~~~text
L7: function Layout.clearings(seed: number): { Rect }
L40: function Layout.reserved(x: number, z: number, clearings: { Rect }): boolean
~~~

### Dependências literais

- L3: @game/ReplicatedStorage/Shared/Game/ForestCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestCatalog.luau)
- L4: ../Campaign/ForestPlan → [fonte](../../src/ServerScriptService/Server/Campaign/ForestPlan.luau)

## src/ServerScriptService/Server/World/HouseAccess.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/HouseAccess.luau) · 86 linhas · SHA-256: c4123c33c7d361965333dc4bcf2b827fa180e5413133be38699b984325461ec3

### Funções nomeadas / callbacks atribuídos

~~~text
L8: function Access.build(root: Instance)
L26: local function barrier(name: string, base: Vector3, size: Vector3)
L70: function Access.refresh(root: Instance)
~~~

### Dependências literais

- L3: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L4: @game/ReplicatedStorage/Shared/Game/HouseEnvelope → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseEnvelope.luau)

### Estado observado / publicado

~~~text
L28: part:SetAttribute("MissionBarrier", name)
~~~

## src/ServerScriptService/Server/World/HouseArchitecture.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/HouseArchitecture.luau) · 161 linhas · SHA-256: 5c70cecd2cc01da9daed3263aac3a3d0e9369553ed710c5598809e9a6503e123

### Funções nomeadas / callbacks atribuídos

~~~text
L12: local function piece(parent: Instance, name: string, base: Vector3, size: Vector3, color: Color3, solid: boolean?)
L30: local function plaque(parent: Instance, position: Vector3, facing: Vector3, text: string)
L37: function Architecture.build(structure: Instance, dressing: Instance)
~~~

### Dependências literais

- L3: @game/ReplicatedStorage/Shared/Game/HouseLayout → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseLayout.luau)
- L4: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)

### Estado observado / publicado

~~~text
L26: glass:SetAttribute("VisualDetail", true)
L48: slab:SetAttribute("FloorLevel", y)
L89: panel:SetAttribute("VisualDetail", true)
~~~

## src/ServerScriptService/Server/World/HouseBuilder.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/HouseBuilder.luau) · 362 linhas · SHA-256: d2f6703a00032cdebcb9c81a0f5ae951e028632ec279248be5df6b5b2837b771

### Funções nomeadas / callbacks atribuídos

~~~text
L19: local function block(
L47: local function sound(parent: Instance, name: string): Sound
L50: local function sign(parent: Instance, text: string, position: Vector3, facing: Vector3?)
L61: local function tag(part: BasePart, id: string, prompt: string)
L68: local function ramp(parent: Instance, name: string, x: number, fromZ: number, toZ: number, fromY: number, toY: number)
L100: function Builder.build(parent: Instance): (MapBuilder.World, FeatureBuilder.Built)
L166: local function gate(name: string, x: number, y: number, z: number, sx: number, sz: number)
~~~

### Dependências literais

- L4: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L5: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L6: @game/ReplicatedStorage/Shared/Game/Audio → [fonte](../../src/ReplicatedStorage/Shared/Game/Audio.luau)
- L7: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L8: ./MapBuilder → [fonte](../../src/ServerScriptService/Server/World/MapBuilder.luau)
- L9: ./FeatureBuilder → [fonte](../../src/ServerScriptService/Server/World/FeatureBuilder.luau)
- L10: ./HouseArchitecture → [fonte](../../src/ServerScriptService/Server/World/HouseArchitecture.luau)
- L11: @game/ReplicatedStorage/Shared/Game/HouseLayout → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseLayout.luau)
- L12: ./HouseTelevision → [fonte](../../src/ServerScriptService/Server/World/HouseTelevision.luau)
- L13: ./HouseAccess → [fonte](../../src/ServerScriptService/Server/World/HouseAccess.luau)

### Estado observado / publicado

~~~text
L62: part:SetAttribute(Tags.Attr.InteractId, id)
L63: part:SetAttribute(Tags.Attr.InteractPrompt, prompt)
L64: part:SetAttribute(Tags.Attr.InteractDistance, 8)
L65: part:SetAttribute(Tags.Attr.InteractEnabled, true)
L79: part:SetAttribute("StairRoute", name)
~~~

## src/ServerScriptService/Server/World/HouseFurniture.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/HouseFurniture.luau) · 266 linhas · SHA-256: 726e9f3ffa829cb9869eaad99f798cee8f54839c3b4b95b3c7d32b6e500c33d5

### Funções nomeadas / callbacks atribuídos

~~~text
L22: local function placer(parent: Instance, room: House.Room): Place
L41: local function lampStand(put: Place, x: number, z: number, color: Color3)
L57: local function sofa(put: Place, x: number, z: number, color: Color3)
L71: local function shelf(put: Place, x: number, z: number, length: number)
L91: local function crate(put: Place, x: number, z: number, size: number, y: number?)
L95: local function candle(put: Place, x: number, z: number, y: number?)
L107: local function plant(put: Place, x: number, z: number)
L118: Living = function(put, color)
L131: Kitchen = function(put)
L145: Dining = function(put, color)
L154: Bath = function(put)
L161: Library = function(put)
L167: Machine = function(put)
L186: Bedroom = function(put, color)
L191: Child = function(put, color)
L207: Office = function(put)
L214: Locked = function(put)
L220: Attic = function(put)
L226: Basement = function(put)
L241: Ritual = function(put)
L256: function Furniture.build(parent: Instance)
~~~

### Dependências literais

- L10: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L11: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)

## src/ServerScriptService/Server/World/HouseLevelBuilder.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/HouseLevelBuilder.luau) · 280 linhas · SHA-256: ca636661cf6b56efabbea0e5defc06562454321e482a24ac0f79bc8ba6acb1f3

### Funções nomeadas / callbacks atribuídos

~~~text
L11: local function piece(parent: Instance, name: string, base: Vector3, size: Vector3, color: Color3, solid: boolean?)
L23: local function sign(parent: Instance, p: Vector3, text: string)
L34: local function pavilion(parent: Instance, x: number, z: number, title: string, glass: boolean)
L58: local function stairs(parent: Instance, side: number)
L77: local function suppress(part: BasePart)
L85: local function serviceStairs(parent: Instance, side: number)
L108: function Builder.build(root: Instance, level: Levels.Level)
L258: function Builder.ruins(root: Instance)
~~~

### Dependências literais

- L3: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L4: ../Campaign/HouseLevelPlan → [fonte](../../src/ServerScriptService/Server/Campaign/HouseLevelPlan.luau)

### Estado observado / publicado

~~~text
L78: if part:GetAttribute("LevelOriginalTransparency") == nil then
L79: part:SetAttribute("LevelOriginalTransparency", part.Transparency)
L80: part:SetAttribute("LevelOriginalCollide", part.CanCollide)
L81: part:SetAttribute("LevelOriginalQuery", part.CanQuery)
L114: root:SetAttribute("LevelEnvironment", if level.outdoor then "Exterior" else "Interior")
L115: root:SetAttribute("LevelTheme", level.theme)
L204: if wall:GetAttribute("LevelOriginalTransparency") ~= nil then
L205: wall.Transparency = wall:GetAttribute("LevelOriginalTransparency") :: number
L206: wall.CanCollide = wall:GetAttribute("LevelOriginalCollide") :: boolean
L207: wall.CanQuery = wall:GetAttribute("LevelOriginalQuery") :: boolean
~~~

## src/ServerScriptService/Server/World/HouseScenery.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/HouseScenery.luau) · 660 linhas · SHA-256: 07e627d4038082976417a46a03e98d9a55a9fed86cb9b83d88b9d38c3a3b272a

### Funções nomeadas / callbacks atribuídos

~~~text
L60: local function inside(x: number, z: number, margin: number): boolean
L67: local function onPath(x: number, z: number): boolean
L71: local function decor(
L88: local function ball(
L102: local function glow(part: BasePart, color: Color3, range: number, brightness: number)
L113: local function restyle(root: Instance)
L156: local function terrain()
L204: local function tree(parent: Instance, position: Vector3, height: number, rng: Random)
L233: local function forest(parent: Instance)
L284: local function pumpkin(parent: Instance, position: Vector3, size: number)
L333: local function lampPost(parent: Instance, position: Vector3)
L368: local function fireflies(parent: Instance, center: Vector3, spread: Vector3)
L397: local function grave(parent: Instance, position: Vector3, yaw: number)
L431: local function fence(parent: Instance, from: Vector3, to: Vector3)
L451: local function exterior(parent: Instance)
L499: local function window(parent: Instance, center: Vector3, normal: Vector3, width: number, height: number)
L522: local function facade(parent: Instance)
L550: local function forestGate(root: Instance)
L597: local function interior(parent: Instance)
L644: function Scenery.build(root: Instance)
~~~

### Dependências literais

- L15: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L16: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L17: ./HouseFurniture → [fonte](../../src/ServerScriptService/Server/World/HouseFurniture.luau)

### Estado observado / publicado

~~~text
L372: emitter:SetAttribute("VisualOptional", true)
~~~

## src/ServerScriptService/Server/World/HouseTaskProps.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/HouseTaskProps.luau) · 118 linhas · SHA-256: 96ec0767c1cb0b7cf22d55bbf76a921880775da3329b975cfc79027a1d8f5a80

### Funções nomeadas / callbacks atribuídos

~~~text
L9: local function part(parent: Instance, name: string, p: Vector3, size: Vector3, color: Color3)
L24: function Props.build(parent: Instance, p: Vector3, item: string?, kind: string)
~~~

### Dependências literais

- L3: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)

## src/ServerScriptService/Server/World/HouseTelevision.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/HouseTelevision.luau) · 52 linhas · SHA-256: 9789eaf0dc6e6b23e130ca6ac2b4492c9ea1b5e4d0451cfb9286d9e95b277495

### Funções nomeadas / callbacks atribuídos

~~~text
L5: function Television.build(parent: Instance)
L8: local function box(name: string, center: Vector3, size: Vector3, color: Color3)
~~~

### Dependências literais

- L3: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)

## src/ServerScriptService/Server/World/Layout.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/Layout.luau) · 342 linhas · SHA-256: 20c9066cacd5d6ec73305d2626f0bc4381f8885b6682a59b8bc5c366782d433a

### Funções nomeadas / callbacks atribuídos

~~~text
L55: local function door(center: number): Opening
L59: local function window(center: number): Opening
L315: function Layout.roomAt(x: number, z: number): Room?
L324: function Layout.inRect(rect: Rect, x: number, z: number): boolean
L328: function Layout.isIndoor(x: number, z: number): boolean
L333: function Layout.wallById(id: string): Wall?
~~~

## src/ServerScriptService/Server/World/MapBuilder.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/MapBuilder.luau) · 778 linhas · SHA-256: 2f553194455ee9b80711981d9c78982921669ba4946b9710b98cc1c678af57e2

### Funções nomeadas / callbacks atribuídos

~~~text
L86: local function vec(p: Layout.Point): Vector3
L90: local function register(world: World, id: string, kind: Kind, focus: BasePart, model: Instance, prompt: string)
L108: local function wallColors(x: number, z: number, exteriorSide: boolean): (Color3, Color3)
L119: local function buildWall(parent: Instance, wall: Layout.Wall)
L181: local function tiles(parent: Instance, rect: Layout.Rect, size: number, a: Color3, b: Color3)
L200: local function inner(rect: Layout.Rect): Layout.Rect
L204: local function buildFloors(parent: Instance)
L273: local function buildDoor(world: World, parent: Instance, spec: Layout.Door)
L340: local function buildRooms(parent: Instance)
L461: local function buildLights(world: World, parent: Instance)
L482: local function buildSigns(parent: Instance)
L533: local function buildPanel(world: World, parent: Instance)
L581: local function buildCourtyard(world: World, parent: Instance)
L617: local function fenceRun(a: Vector3, b: Vector3)
L725: local function buildPickups(world: World, parent: Instance)
L739: function MapBuilder.build(parent: Instance): World
~~~

### Dependências literais

- L11: @game/ReplicatedStorage/Shared/Game/Audio → [fonte](../../src/ReplicatedStorage/Shared/Game/Audio.luau)
- L12: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L13: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)
- L14: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)
- L15: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L16: ./Expansion → [fonte](../../src/ServerScriptService/Server/World/Expansion.luau)
- L17: ./Layout → [fonte](../../src/ServerScriptService/Server/World/Layout.luau)
- L18: ./Palette → [fonte](../../src/ServerScriptService/Server/World/Palette.luau)
- L19: ./Props → [fonte](../../src/ServerScriptService/Server/World/Props.luau)
- L20: ./ProceduralLayout → [fonte](../../src/ServerScriptService/Server/World/ProceduralLayout.luau)
- L21: ./WallMath → [fonte](../../src/ServerScriptService/Server/World/WallMath.luau)

### Estado observado / publicado

~~~text
L92: focus:SetAttribute(Tags.Attr.InteractId, id)
L93: focus:SetAttribute(Tags.Attr.InteractPrompt, prompt)
L94: focus:SetAttribute(Tags.Attr.InteractDistance, distance)
L95: focus:SetAttribute(Tags.Attr.InteractEnabled, true)
~~~

## src/ServerScriptService/Server/World/Palette.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/Palette.luau) · 82 linhas · SHA-256: 25807001f5d8daef614d67ff7c1adf4ae94bad7225ef520254c965505ceb77ab

## src/ServerScriptService/Server/World/ProceduralLayout.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/ProceduralLayout.luau) · 246 linhas · SHA-256: 9f382e58cffbeab2bf54eb6e7b7dd0df4fe16cd5ef92daca3e1e0353cc8ea4fc

### Funções nomeadas / callbacks atribuídos

~~~text
L36: function Layout.center(cell: number): (number, number)
L43: function Layout.entranceX(cell: number): number
L48: function Layout.isOutdoorRoom(room: Room): boolean
L52: function Layout.passages(plan: Plan): { Passage }
L72: function Layout.isIndoor(plan: Plan, x: number, z: number): boolean
L87: function Layout.patrolPoints(plan: Plan): { { x: number, y: number, z: number } }
L105: function Layout.edges(): { Link }
L118: function Layout.create(seed: number, stage: number): Plan
L131: local function root(cell: number): number
L158: function Layout.connected(plan: Plan, a: number, b: number): boolean
L167: function Layout.validate(plan: Plan): (boolean, string?)
L215: function Layout.slots(plan: Plan): { { id: string, room: string, x: number, z: number } }
L225: function Layout.returnRoutes(plan: Plan): { [number]: number }
~~~

### Dependências literais

- L3: ../Campaign/SeededRandom → [fonte](../../src/ServerScriptService/Server/Campaign/SeededRandom.luau)

## src/ServerScriptService/Server/World/Props.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/Props.luau) · 389 linhas · SHA-256: 823d0bc596a22482c72d9c12a96c31b092fa1485b538e2398808681f5dfa6e14

### Funções nomeadas / callbacks atribuídos

~~~text
L16: local function at(base: Vector3, yaw: number, offset: Vector3): Vector3
L21: local function rotated(base: Vector3, yaw: number, offset: Vector3): CFrame
L25: local function piece(
L39: function Props.desk(parent: Instance, base: Vector3, yaw: number)
L79: function Props.chair(parent: Instance, base: Vector3, yaw: number, fallen: boolean?)
L83: local function p(name: string, offset: Vector3, size: Vector3, color: Color3)
L94: function Props.cabinet(parent: Instance, base: Vector3, yaw: number)
L115: function Props.crate(parent: Instance, base: Vector3, yaw: number, s: number)
L145: function Props.shelf(parent: Instance, base: Vector3, yaw: number, width: number)
L165: function Props.locker(parent: Instance, base: Vector3, yaw: number, count: number)
L177: function Props.counter(parent: Instance, base: Vector3, yaw: number, length: number)
L185: function Props.bench(parent: Instance, base: Vector3, yaw: number)
L195: function Props.workbench(parent: Instance, base: Vector3, yaw: number)
L209: function Props.pumpTank(parent: Instance, base: Vector3, height: number, diameter: number)
L230: function Props.pipe(parent: Instance, a: Vector3, b: Vector3, diameter: number, color: Color3?, solid: boolean?)
L238: function Props.generator(parent: Instance, base: Vector3, yaw: number)
L258: function Props.lampFixture(parent: Instance, position: Vector3): BasePart
L267: function Props.emergencyLight(parent: Instance, position: Vector3): BasePart
L276: function Props.fuse(parent: Instance, name: string, position: Vector3): (Model, BasePart)
L296: function Props.note(parent: Instance, name: string, position: Vector3, yaw: number): BasePart
L320: function Props.tree(parent: Instance, base: Vector3, height: number, rng: Random)
L340: function Props.van(parent: Instance, base: Vector3, yaw: number)
L357: function Props.booth(parent: Instance, base: Vector3, yaw: number)
L370: function Props.streetLamp(parent: Instance, base: Vector3): BasePart
L381: function Props.floodLight(parent: Instance, base: Vector3, target: Vector3): BasePart
~~~

### Dependências literais

- L7: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L8: ./Palette → [fonte](../../src/ServerScriptService/Server/World/Palette.luau)

## src/ServerScriptService/Server/World/SectorBuilder.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/SectorBuilder.luau) · 347 linhas · SHA-256: adde32f4bd8da7412e64b3976c41cae5ca66db20fd150c6a4a62b23f97b88bc6

### Funções nomeadas / callbacks atribuídos

~~~text
L17: local function surface(part: BasePart, style: string)
L22: local function sign(parent: Instance, p: Vector3, facing: Vector3, text: string, size: Vector2?)
L32: local function wall(parent: Instance, a: Vector3, b: Vector3, opening: boolean, outdoor: boolean?)
L35: local function segment(offset: number, width: number, bottom: number, top: number)
L78: local function equipment(parent: Instance, kind: string, frame: CFrame)
L80: local function block(name: string, p: Vector3, size: Vector3, color: Color3): BasePart
L149: local function dressing(parent: Instance, room: Layout.Room)
L193: local function passage(parent: Instance, spec: Layout.Passage)
L242: function Builder.build(parent: Instance, plan: Layout.Plan): Folder
~~~

### Dependências literais

- L4: @game/ReplicatedStorage/Shared/Game/CampaignCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/CampaignCatalog.luau)
- L5: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L6: ./ProceduralLayout → [fonte](../../src/ServerScriptService/Server/World/ProceduralLayout.luau)
- L7: ./Palette → [fonte](../../src/ServerScriptService/Server/World/Palette.luau)
- L8: ./Props → [fonte](../../src/ServerScriptService/Server/World/Props.luau)
- L9: ./SectorExterior → [fonte](../../src/ServerScriptService/Server/World/SectorExterior.luau)

### Estado observado / publicado

~~~text
L18: part:SetAttribute("SurfaceStyle", style)
L46: part:SetAttribute("SectorWall", true)
L195: model:SetAttribute("Covered", spec.covered)
L247: root:SetAttribute("Seed", plan.seed)
L248: root:SetAttribute("Stage", plan.stage)
L252: model:SetAttribute("RoomKind", room.kind)
L253: model:SetAttribute("Cell", room.cell)
L266: model:SetAttribute("Outdoor", outdoor)
~~~

## src/ServerScriptService/Server/World/SectorExterior.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/SectorExterior.luau) · 98 linhas · SHA-256: dbafed88ef969ef05a963f510a35e3dd2de57aa958d08f57de9546908ff0bd8e

### Funções nomeadas / callbacks atribuídos

~~~text
L12: local function fence(parent: Instance, a: Vector3, b: Vector3)
L27: local function sign(parent: Instance, position: Vector3, facing: Vector3, text: string)
L36: function Exterior.build(parent: Instance)
~~~

### Dependências literais

- L3: ./Build → [fonte](../../src/ServerScriptService/Server/World/Build.luau)
- L4: ./ProceduralLayout → [fonte](../../src/ServerScriptService/Server/World/ProceduralLayout.luau)
- L5: ./Palette → [fonte](../../src/ServerScriptService/Server/World/Palette.luau)
- L6: ./Props → [fonte](../../src/ServerScriptService/Server/World/Props.luau)

### Estado observado / publicado

~~~text
L42: floor:SetAttribute("OutdoorArea", zone.id)
~~~

## src/ServerScriptService/Server/World/WallMath.luau

[Abrir fonte](../../src/ServerScriptService/Server/World/WallMath.luau) · 69 linhas · SHA-256: 5e69fe60f2b09576e51b46711e77f626de091462a6cc15a540d1201e997f0367

### Funções nomeadas / callbacks atribuídos

~~~text
L17: function WallMath.solidSegments(from: number, to: number, y0: number, y1: number, openings: { Opening }): { Segment }
L24: local function add(a: number, b: number, low: number, high: number)
L44: function WallMath.splitBands(segments: { Segment }, split: number): ({ Segment }, { Segment })
L61: function WallMath.area(segments: { Segment }): number
~~~

## src/ServerScriptService/Tests/CampaignHarness.luau

[Abrir fonte](../../src/ServerScriptService/Tests/CampaignHarness.luau) · 329 linhas · SHA-256: 480acf527673bf3c0ad4dd0cea0c37d124f3b1c0f3db7d30b7d33e26d978b88e

### Funções nomeadas / callbacks atribuídos

~~~text
L13: function Harness.run(runtime: any, args: any)
L18: local function check(value: boolean, name: string)
L23: local function waitFor(predicate: () -> boolean, name: string, timeout: number?)
L33: local function move(player: Player, position: Vector3)
L41: local function request(player: Player, command: any): any
L83: local function visualCheck()
L109: local function voteMode(serialNumber: number)
~~~

### Dependências literais

- L7: ../Server/Services/CreatureService → [fonte](../../src/ServerScriptService/Server/Services/CreatureService.luau)
- L8: ../Server/Services/PlayerStateService → [fonte](../../src/ServerScriptService/Server/Services/PlayerStateService.luau)
- L9: ../Server/Services/WorldService → [fonte](../../src/ServerScriptService/Server/Services/WorldService.luau)
- L10: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)

### Estado observado / publicado

~~~text
L44: local before = tonumber(player:GetAttribute("CampaignFeedbackSerial")) or 0
L45: player:SetAttribute("CampaignQARequest", HttpService:JSONEncode(command))
L48: return player:GetAttribute("HoldBreath") == command.breath
L50: return (tonumber(player:GetAttribute("CampaignFeedbackSerial")) or 0) > before
L56: accepted = player:GetAttribute("CampaignAccepted") == true,
L57: message = tostring(player:GetAttribute("CampaignFeedback")),
L91: teammate:SetAttribute(
L96: local raw = teammate:GetAttribute("HousePreferences")
L112: teammate:SetAttribute(
L145: actor:GetAttribute("HasFlashlight") == false and actor:GetAttribute("Flashlight") == false,
L166: check(players[2]:GetAttribute("CampaignStatus") == "Active", "rescue returns teammate")
L178: local hasScene = (tonumber(state:GetAttribute("StorySceneEndsAt")) or 0) > 0
L187: check(locker.door:GetAttribute("InteractEnabled") == true, "library cabinet discoverable by client")
L214: check((tonumber(actor:GetAttribute("Oxygen")) or 100) < 100, "tutorial consumes real oxygen")
L216: check(actor:GetAttribute("Hidden") == "", "exit restores hide state")
L224: check(teammate:GetAttribute("HasFlashlight") == true, "shared flashlight")
L254: local deadline = tonumber(state:GetAttribute("LobbyReturnAt")) or 0
L266: state:GetAttribute("LobbyReturnAt") == 0 and state:GetAttribute("GameMode") == "",
L271: teammate:GetAttribute("CampaignStatus") == "Waiting"
L272: and teammate:GetAttribute("GameModeVote") == "",
L281: teammate:GetAttribute("HasFlashlight") == false
L282: and teammate:GetAttribute("Hidden") == ""
L283: and teammate:GetAttribute("HoldBreath") == false,
L299: runtime.snapshot().solved == 0 and actor:GetAttribute("HasFlashlight") == false,
~~~

## src/ServerScriptService/Tests/Run.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Run.luau) · 54 linhas · SHA-256: 3c58c70dbed373cc4dd733f604807660747244ae4d340cda8f611443a658e147

### Funções nomeadas / callbacks atribuídos

~~~text
L14: local function loadSpecs(folder: Instance): { TestKit.Spec }
L34: run = function()
~~~

### Dependências literais

- L12: ./TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/BatteryModel.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/BatteryModel.luau) · 80 linhas · SHA-256: 2d2aa05dcf61af244e94d9a027ab2fd4224f2312ab1ec5b87c9d25e262b76e58

### Funções nomeadas / callbacks atribuídos

~~~text
L8: local function run(state: BatteryModel.State, seconds: number): boolean
L19: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/BatteryModel → [fonte](../../src/ReplicatedStorage/Shared/Game/BatteryModel.luau)
- L3: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/BreakerPuzzle.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/BreakerPuzzle.luau) · 50 linhas · SHA-256: 2b3a590ce1d9012f6ebb35aca1a4ae6acfccda934efa2bee4b765300d2f8a90c

### Funções nomeadas / callbacks atribuídos

~~~text
L7: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Game/BreakerPuzzle → [fonte](../../src/ServerScriptService/Server/Game/BreakerPuzzle.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/CampaignGenerator.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/CampaignGenerator.luau) · 81 linhas · SHA-256: 2d457333c6c0ab47efec3816bfdd3bde64d22049e3c2fa2c89aee727b0284b13

### Funções nomeadas / callbacks atribuídos

~~~text
L8: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Campaign/CampaignGenerator → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignGenerator.luau)
- L3: @game/ServerScriptService/Server/Campaign/SeededRandom → [fonte](../../src/ServerScriptService/Server/Campaign/SeededRandom.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/CampaignPerks.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/CampaignPerks.luau) · 85 linhas · SHA-256: 76cc8f19569d296d6ba7fd9eb411aa1e6a3de471e59eb1f7d5d2b92584dbeca7

### Funções nomeadas / callbacks atribuídos

~~~text
L7: local function party(count: number, stage: number?): Session.State
L19: run = function(t)
~~~

### Dependências literais

- L3: @game/ReplicatedStorage/Shared/Game/BatteryModel → [fonte](../../src/ReplicatedStorage/Shared/Game/BatteryModel.luau)
- L4: @game/ServerScriptService/Server/Campaign/CoopSession → [fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau)
- L5: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/CharacterPose.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/CharacterPose.luau) · 57 linhas · SHA-256: c4198c3d34f614c0cc6abae1d1ea10f9c941b8e40ecd26e1f47e0e1e2d52f30b

### Funções nomeadas / callbacks atribuídos

~~~text
L7: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/CharacterPose → [fonte](../../src/ReplicatedStorage/Shared/Game/CharacterPose.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/Checkpoint.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Checkpoint.luau) · 85 linhas · SHA-256: f4124b12c2e26b91b74a874f567aef75f99504263d361fd17c93a1a1250aeca3

### Funções nomeadas / callbacks atribuídos

~~~text
L6: local function powered(): Objectives.State
L18: local function input(objectives: Objectives.State, overrides: { [string]: any }?): Checkpoint.Snapshot
L37: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Game/Checkpoint → [fonte](../../src/ServerScriptService/Server/Game/Checkpoint.luau)
- L3: @game/ServerScriptService/Server/Game/Objectives → [fonte](../../src/ServerScriptService/Server/Game/Objectives.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/CinematicShots.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/CinematicShots.luau) · 120 linhas · SHA-256: 569d0c509ec445791539731754654e5ff05e148a152d26ebcb769428b91277ba

### Funções nomeadas / callbacks atribuídos

~~~text
L9: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/CinematicShots → [fonte](../../src/ReplicatedStorage/Shared/Game/CinematicShots.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/CoinPlan.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/CoinPlan.luau) · 73 linhas · SHA-256: 0d60b520f1041b990331067e8e1c82e674a14bca252ae45412c2793f4ccda5bc

### Funções nomeadas / callbacks atribuídos

~~~text
L6: local function roomCount(): number
L18: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Game/CoinPlan → [fonte](../../src/ServerScriptService/Server/Game/CoinPlan.luau)
- L3: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/CoopSession.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/CoopSession.luau) · 235 linhas · SHA-256: 02ee6b649e50793c56290e700140fff2a7b52b65f20be009fefa4c8e1cbec118

### Funções nomeadas / callbacks atribuídos

~~~text
L8: local function party(count: number, stage: number?): Session.State
L18: local function complete(state: Session.State)
L39: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Campaign/CoopSession → [fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau)
- L3: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/CreatureBrain.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/CreatureBrain.luau) · 120 linhas · SHA-256: 02cd1228e3a0285224b7a522de8bcca4663de00d57da1604159582ab812a5e31

### Funções nomeadas / callbacks atribuídos

~~~text
L10: local function perception(overrides: { [string]: any }): CreatureBrain.Perception
L27: local function awake(): CreatureBrain.Brain
L35: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L3: @game/ServerScriptService/Server/Game/CreatureBrain → [fonte](../../src/ServerScriptService/Server/Game/CreatureBrain.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/Economy.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Economy.luau) · 217 linhas · SHA-256: 9500c3d8bbb87d19edc5b9fc5245d196af90fe1a71af01e927dcb3f51fecee37

### Funções nomeadas / callbacks atribuídos

~~~text
L7: local function fixed(...: number): () -> number
L16: local function summary(overrides: { [string]: any }?): Economy.RunSummary
L29: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L3: @game/ServerScriptService/Server/Data/PlayerDataSchema → [fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau)
- L4: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L5: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/EconomyEvents.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/EconomyEvents.luau) · 43 linhas · SHA-256: ac8fc2b211e5faf86944da13d18c1518d67bc2d9fc7911d1b020f3bc9f14c185

### Funções nomeadas / callbacks atribuídos

~~~text
L8: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Game/EconomyEvents → [fonte](../../src/ServerScriptService/Server/Game/EconomyEvents.luau)
- L3: @game/ReplicatedStorage/Shared/Game/Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L4: @game/ServerScriptService/Server/Data/PlayerDataSchema → [fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau)
- L5: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/EstateGround.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/EstateGround.luau) · 62 linhas · SHA-256: ac107532c529eecf788d9bc122e896fad82f8282716e8848625319eaca87bf32

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t: TestKit.Context)
~~~

### Dependências literais

- L2: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L8: @game/ServerScriptService/Server/World/HouseBuilder → [fonte](../../src/ServerScriptService/Server/World/HouseBuilder.luau)
- L9: @game/ServerScriptService/Server/World/HouseLevelBuilder → [fonte](../../src/ServerScriptService/Server/World/HouseLevelBuilder.luau)
- L10: @game/ServerScriptService/Server/Campaign/HouseLevelPlan → [fonte](../../src/ServerScriptService/Server/Campaign/HouseLevelPlan.luau)

## src/ServerScriptService/Tests/Specs/FearModel.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/FearModel.luau) · 110 linhas · SHA-256: fb94332b029bc191a65b8dd7645d26e7d80c1e3d6fe02f366bb249092ed57d8e

### Funções nomeadas / callbacks atribuídos

~~~text
L8: local function inputs(overrides: { [string]: any }): FearModel.Inputs
L23: local function run(state: FearModel.State, i: FearModel.Inputs, seconds: number)
L32: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L3: @game/ReplicatedStorage/Shared/Game/FearModel → [fonte](../../src/ReplicatedStorage/Shared/Game/FearModel.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/ForestCampaign.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/ForestCampaign.luau) · 68 linhas · SHA-256: 7c109fbacaa6d480d5b79d9daf96d0e7c2b6a05aab4e5e9cb23634fd1e9fe308

### Funções nomeadas / callbacks atribuídos

~~~text
L8: run = function(t: TestKit.Context)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Campaign/ForestPlan → [fonte](../../src/ServerScriptService/Server/Campaign/ForestPlan.luau)
- L3: @game/ServerScriptService/Server/Campaign/CoopSession → [fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau)
- L4: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L5: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/ForestHorror.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/ForestHorror.luau) · 99 linhas · SHA-256: aa87225ef566a8945f6d9a9d4ac3ce67b9358673b0b58daed4957f5ab4fb150b

### Funções nomeadas / callbacks atribuídos

~~~text
L13: run = function(t: TestKit.Context)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/ForestThreat → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestThreat.luau)
- L3: @game/ReplicatedStorage/Shared/Game/ForestCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestCatalog.luau)
- L4: @game/ServerScriptService/Server/World/ForestLayout → [fonte](../../src/ServerScriptService/Server/World/ForestLayout.luau)
- L5: @game/ServerScriptService/Server/Campaign/ForestPlan → [fonte](../../src/ServerScriptService/Server/Campaign/ForestPlan.luau)
- L6: @game/ServerScriptService/Server/Campaign/CoopSession → [fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau)
- L7: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L8: @game/ReplicatedStorage/Shared/Game/ForestCinema → [fonte](../../src/ReplicatedStorage/Shared/Game/ForestCinema.luau)
- L9: @game/ReplicatedStorage/Shared/Game/CinematicShots → [fonte](../../src/ReplicatedStorage/Shared/Game/CinematicShots.luau)
- L10: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/ForestNavigation.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/ForestNavigation.luau) · 84 linhas · SHA-256: d95566cbf3e585f525a929c88909821fea750e2fe5bcecece356e86d13b64d47

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t: TestKit.Context)
L52: local function route(a: Vector3, b: Vector3)
~~~

### Dependências literais

- L2: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L8: @game/ServerScriptService/Server/World/ForestBuilder → [fonte](../../src/ServerScriptService/Server/World/ForestBuilder.luau)
- L9: @game/ServerScriptService/Server/World/HouseBuilder → [fonte](../../src/ServerScriptService/Server/World/HouseBuilder.luau)
- L10: @game/ServerScriptService/Server/Campaign/ForestPlan → [fonte](../../src/ServerScriptService/Server/Campaign/ForestPlan.luau)

### Estado observado / publicado

~~~text
L18: if tree:IsA("BasePart") and tree:GetAttribute("NearTrail") == true then
L28: t.expect(world.root:GetAttribute("ForestBlackout")).toBe(true)
L36: t.expect(world.root:GetAttribute("ForestBlackout")).toBe(false)
~~~

## src/ServerScriptService/Tests/Specs/Guard.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Guard.luau) · 113 linhas · SHA-256: 9865ffd4a5e814e8d172bc7a24ea0d185113dbb665e8b2ec08cb1b76675c85e2

### Funções nomeadas / callbacks atribuídos

~~~text
L5: local function accepts(validator: Guard.Validator, value: any): boolean
L12: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Net/Guard → [fonte](../../src/ReplicatedStorage/Shared/Net/Guard.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/HideRules.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/HideRules.luau) · 78 linhas · SHA-256: 9af1d04548603afa18e9de5d88e3c27ea5a2cb79e1b69097c25f936fe4daaf2c

### Funções nomeadas / callbacks atribuídos

~~~text
L8: local function enter(overrides: { [string]: any }): HideRules.EnterContext
L22: local function found(overrides: { [string]: any }): HideRules.FoundContext
L39: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L3: @game/ServerScriptService/Server/Game/HideRules → [fonte](../../src/ServerScriptService/Server/Game/HideRules.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/HouseAccess.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/HouseAccess.luau) · 82 linhas · SHA-256: ad1934992b9b3c8da8af62f1902d23ace8dd81b515094637606f90f763b3975a

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t: TestKit.Context)
L25: local function route(a: Vector3, b: Vector3): boolean
~~~

### Dependências literais

- L2: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L12: @game/ServerScriptService/Server/World/HouseBuilder → [fonte](../../src/ServerScriptService/Server/World/HouseBuilder.luau)
- L13: @game/ServerScriptService/Server/World/HouseAccess → [fonte](../../src/ServerScriptService/Server/World/HouseAccess.luau)
- L14: @game/ServerScriptService/Server/World/HouseLevelBuilder → [fonte](../../src/ServerScriptService/Server/World/HouseLevelBuilder.luau)
- L15: @game/ServerScriptService/Server/Campaign/HouseLevelPlan → [fonte](../../src/ServerScriptService/Server/Campaign/HouseLevelPlan.luau)

## src/ServerScriptService/Tests/Specs/HouseLayout.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/HouseLayout.luau) · 35 linhas · SHA-256: 21bc62cbd2ec315bd4e38db1a856640fc0b880f38e442d764246904ae9d838ee

### Funções nomeadas / callbacks atribuídos

~~~text
L9: run = function(t: TestKit.Context)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/HouseLayout → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseLayout.luau)
- L3: @game/ReplicatedStorage/Shared/Game/StoryCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoryCatalog.luau)
- L4: @game/ReplicatedStorage/Shared/Game/HouseBroadcast → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseBroadcast.luau)
- L5: @game/ReplicatedStorage/Shared/Game/CinematicShots → [fonte](../../src/ReplicatedStorage/Shared/Game/CinematicShots.luau)
- L6: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/HouseLevelNavigation.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/HouseLevelNavigation.luau) · 100 linhas · SHA-256: e0959990fd8a7d7a72ee9fd040a072e13dd67f91ea5b1076c5939ed736e78d45

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t: TestKit.Context)
~~~

### Dependências literais

- L2: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L7: @game/ServerScriptService/Server/Campaign/HouseLevelPlan → [fonte](../../src/ServerScriptService/Server/Campaign/HouseLevelPlan.luau)
- L8: @game/ServerScriptService/Server/World/HouseBuilder → [fonte](../../src/ServerScriptService/Server/World/HouseBuilder.luau)
- L9: @game/ServerScriptService/Server/World/HouseLevelBuilder → [fonte](../../src/ServerScriptService/Server/World/HouseLevelBuilder.luau)
- L10: @game/ServerScriptService/Server/Campaign/HousePlan → [fonte](../../src/ServerScriptService/Server/Campaign/HousePlan.luau)
- L11: @game/ServerScriptService/Server/Campaign/HouseActivities → [fonte](../../src/ServerScriptService/Server/Campaign/HouseActivities.luau)
- L12: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)

### Estado observado / publicado

~~~text
L88: and (wall.Name == "RoomPartition" or wall:GetAttribute("LevelOriginalTransparency") ~= nil)
L93: t.expect(world.root:GetAttribute("LevelEnvironment")).toBe("Interior")
~~~

## src/ServerScriptService/Tests/Specs/HouseLevels.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/HouseLevels.luau) · 66 linhas · SHA-256: df9681dc05688b33828a17683ac77a05af04609a582986e5f4455cc6577e8748

### Funções nomeadas / callbacks atribuídos

~~~text
L9: run = function(t: TestKit.Context)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Campaign/HouseLevelPlan → [fonte](../../src/ServerScriptService/Server/Campaign/HouseLevelPlan.luau)
- L3: @game/ServerScriptService/Server/Campaign/HousePlan → [fonte](../../src/ServerScriptService/Server/Campaign/HousePlan.luau)
- L4: @game/ServerScriptService/Server/Campaign/CoopSession → [fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau)
- L5: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L6: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/HouseNavigation.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/HouseNavigation.luau) · 134 linhas · SHA-256: 4dbc09754d450cac61eb04ac2291864fef8c3e79d428c3bd40b3243369a1b2ce

### Funções nomeadas / callbacks atribuídos

~~~text
L7: run = function(t: TestKit.Context)
~~~

### Dependências literais

- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L9: @game/ServerScriptService/Server/World/HouseBuilder → [fonte](../../src/ServerScriptService/Server/World/HouseBuilder.luau)
- L10: @game/ReplicatedStorage/Shared/Game/HouseCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/HouseCatalog.luau)
- L11: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L13: @game/ServerScriptService/Server/Services/WorldService → [fonte](../../src/ServerScriptService/Server/Services/WorldService.luau)
- L40: @game/ServerScriptService/Server/World/HouseAccess → [fonte](../../src/ServerScriptService/Server/World/HouseAccess.luau)
- L70: @game/ServerScriptService/Server/Campaign/HousePlan → [fonte](../../src/ServerScriptService/Server/Campaign/HousePlan.luau)
- L78: @game/ServerScriptService/Server/Campaign/HouseLevelPlan → [fonte](../../src/ServerScriptService/Server/Campaign/HouseLevelPlan.luau)

## src/ServerScriptService/Tests/Specs/HouseProgression.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/HouseProgression.luau) · 44 linhas · SHA-256: 1dce9e5f8151749615d4e71ed92976f2faa9ca5ebd4a4e717f6e69af8a962956

### Funções nomeadas / callbacks atribuídos

~~~text
L7: run = function(t: TestKit.Context)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Campaign/CoopSession → [fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau)
- L3: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/InteractionPresentation.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/InteractionPresentation.luau) · 29 linhas · SHA-256: 3f526c3187f95873bd3b95d13fd8accd73208f715f894cb1832b9be283a017d9

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/InteractionPresentation → [fonte](../../src/ReplicatedStorage/Shared/Game/InteractionPresentation.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/Layout.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Layout.luau) · 177 linhas · SHA-256: 0448ed3328b9e82d97e2dd94e7112065659e868302d7b24983cda9dc79b27db5

### Funções nomeadas / callbacks atribuídos

~~~text
L8: local function inside(p: Layout.Point): boolean
L14: run = function(t)
~~~

### Dependências literais

- L3: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L4: @game/ServerScriptService/Server/World/Layout → [fonte](../../src/ServerScriptService/Server/World/Layout.luau)
- L5: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L6: @game/ServerScriptService/Server/World/WallMath → [fonte](../../src/ServerScriptService/Server/World/WallMath.luau)

## src/ServerScriptService/Tests/Specs/LightingProfile.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/LightingProfile.luau) · 70 linhas · SHA-256: 90cf03dd46a1c0b25db698a660034326439fe7fcaf4348fd4b302f1776279626

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/LightingProfile → [fonte](../../src/ReplicatedStorage/Shared/Game/LightingProfile.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/Loader.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Loader.luau) · 73 linhas · SHA-256: 804fd1459b925d8b9398d5b2d817e7dc359fa5720ab502839cb86c7f60a387fd

### Funções nomeadas / callbacks atribuídos

~~~text
L7: run = function(t)
L10: local function module(name: string)
L13: Init = function()
L16: Start = function()
L31: Init = function()
L44: Start = function()
L50: Init = function()
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Loader → [fonte](../../src/ReplicatedStorage/Shared/Loader.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/Logger.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Logger.luau) · 59 linhas · SHA-256: b48d2bec81664ca54abe41ee47a190ac95e379ab4759ec61c6d35386734f953a

### Funções nomeadas / callbacks atribuídos

~~~text
L10: local function capture(level: Types.LogLevel, body: () -> ()): { Entry }
L28: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Logger → [fonte](../../src/ReplicatedStorage/Shared/Logger.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L4: @game/ReplicatedStorage/Shared/Types → [fonte](../../src/ReplicatedStorage/Shared/Types.luau)

## src/ServerScriptService/Tests/Specs/Objectives.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Objectives.luau) · 122 linhas · SHA-256: d16575d81aaac0b3e7c36258a59b148f968701ed80d265cfe79cee681ad17348

### Funções nomeadas / callbacks atribuídos

~~~text
L7: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Game/Objectives → [fonte](../../src/ServerScriptService/Server/Game/Objectives.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/Perks.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Perks.luau) · 137 linhas · SHA-256: 07080fa5215f77566bc762f44f228e86e35092515e0ef58c19a6ca679e2db131

### Funções nomeadas / callbacks atribuídos

~~~text
L10: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L3: @game/ReplicatedStorage/Shared/Game/Perks → [fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau)
- L4: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L5: @game/ServerScriptService/Server/Data/PlayerDataSchema → [fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau)
- L6: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/PixelText.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/PixelText.luau) · 22 linhas · SHA-256: a8ce1047336d8d31b194643cbed7a81578c214b885b37a90ebf8027a2f1fdbac

### Funções nomeadas / callbacks atribuídos

~~~text
L8: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/PixelText → [fonte](../../src/ReplicatedStorage/Shared/Game/PixelText.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L4: @game/ReplicatedStorage/Shared/Game/Text → [fonte](../../src/ReplicatedStorage/Shared/Game/Text.luau)

## src/ServerScriptService/Tests/Specs/PlayerData.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/PlayerData.luau) · 82 linhas · SHA-256: f98402ecb28c65e20922670b2cc21493fbf81e0287d20c27c7d7856f6effdec4

### Funções nomeadas / callbacks atribuídos

~~~text
L9: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L3: @game/ServerScriptService/Server/Data/MockDataStore → [fonte](../../src/ServerScriptService/Server/Data/MockDataStore.luau)
- L4: @game/ServerScriptService/Server/Data/PlayerDataSchema → [fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau)
- L5: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/PlayerGuide.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/PlayerGuide.luau) · 48 linhas · SHA-256: a3eba0d9346408812c7291d4e489df9de0acdb4c23ff809522432ab65870ff8d

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t)
L7: local function activity(kind: string, progress: number): Guide.Activity
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/PlayerGuide → [fonte](../../src/ReplicatedStorage/Shared/Game/PlayerGuide.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/PlayerRules.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/PlayerRules.luau) · 53 linhas · SHA-256: d3f76c6474812c488afc49a2e52a2c06e893bda4438bb6858e10677bf9237346

### Funções nomeadas / callbacks atribuídos

~~~text
L10: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L3: @game/ServerScriptService/Server/Game/PlayerRules → [fonte](../../src/ServerScriptService/Server/Game/PlayerRules.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/Presentation.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Presentation.luau) · 31 linhas · SHA-256: e8b771886ef5dee0adef0c792362ac7d2bcc58961d7fa0345fc85e7489468e85

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/Presentation → [fonte](../../src/ReplicatedStorage/Shared/Game/Presentation.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/ProceduralLayout.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/ProceduralLayout.luau) · 170 linhas · SHA-256: 1508b61e512553aadf59c962ddfc32343bd0bab20e12bf24aa389bfff249d85f

### Funções nomeadas / callbacks atribuídos

~~~text
L7: local function signature(plan: Layout.Plan, geometryOnly: boolean?): string
L22: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/World/ProceduralLayout → [fonte](../../src/ServerScriptService/Server/World/ProceduralLayout.luau)
- L3: @game/ServerScriptService/Server/World/Layout → [fonte](../../src/ServerScriptService/Server/World/Layout.luau)
- L4: @game/ServerScriptService/Server/Campaign/CampaignGenerator → [fonte](../../src/ServerScriptService/Server/Campaign/CampaignGenerator.luau)
- L5: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/RateLimiter.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/RateLimiter.luau) · 51 linhas · SHA-256: 10dd216f0b5782793d3b86ed06ba2051536ed75d5101fc0541ad9f90464719c6

### Funções nomeadas / callbacks atribuídos

~~~text
L7: run = function(t)
L9: local function clock(): number
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Net/RateLimiter → [fonte](../../src/ReplicatedStorage/Shared/Net/RateLimiter.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/Remotes.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Remotes.luau) · 43 linhas · SHA-256: 1affbafe904ec5d0cc42536ed0ae1a3f3d28f0c75933e8a917728c0158e8c1f5

### Funções nomeadas / callbacks atribuídos

~~~text
L9: run = function(t)
~~~

### Dependências literais

- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L12: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L13: @game/ReplicatedStorage/Shared/Net/Remotes → [fonte](../../src/ReplicatedStorage/Shared/Net/Remotes.luau)

## src/ServerScriptService/Tests/Specs/Retry.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Retry.luau) · 67 linhas · SHA-256: 92b5143e6e312a9971db0e81bed1dd788decd358648d18c92e9472f21823b377

### Funções nomeadas / callbacks atribuídos

~~~text
L7: run = function(t)
L15: wait = function()
L37: wait = function(seconds: number)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Util/Retry → [fonte](../../src/ReplicatedStorage/Shared/Util/Retry.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/RoundRules.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/RoundRules.luau) · 83 linhas · SHA-256: e11e03a4779b82a3af82e0d2ac5eda3f8e883610bb274b102a27b15c61c3d61a

### Funções nomeadas / callbacks atribuídos

~~~text
L5: local function context(overrides: { [string]: any }): RoundRules.InteractionContext
L24: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Game/RoundRules → [fonte](../../src/ServerScriptService/Server/Game/RoundRules.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/Season.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/Season.luau) · 80 linhas · SHA-256: 8ac8b4f179484d3b3b89c242aca3c7c13965130e7afddf6b17dc67461b5827ed

### Funções nomeadas / callbacks atribuídos

~~~text
L10: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/Season → [fonte](../../src/ReplicatedStorage/Shared/Game/Season.luau)
- L3: @game/ReplicatedStorage/Shared/Game/SeasonCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/SeasonCatalog.luau)
- L4: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L5: @game/ServerScriptService/Server/Data/PlayerDataSchema → [fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau)
- L6: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/ServerList.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/ServerList.luau) · 62 linhas · SHA-256: 26812e9219a3f94a6e025acef7141d59236d08ac8db7e97ed438e981623643bb

### Funções nomeadas / callbacks atribuídos

~~~text
L10: local function entry(job: string, players: number, phase: string, updated: number): ServerList.Entry
L16: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/ServerList → [fonte](../../src/ReplicatedStorage/Shared/Game/ServerList.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/SessionLock.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/SessionLock.luau) · 38 linhas · SHA-256: cd36d540b0ed19eab6cb8d5dcc29ff5e41d5a01e5c7b39816ff26986d9bd1267

### Funções nomeadas / callbacks atribuídos

~~~text
L9: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Data/MockDataStore → [fonte](../../src/ServerScriptService/Server/Data/MockDataStore.luau)
- L3: @game/ServerScriptService/Server/Data/PlayerDataSchema → [fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau)
- L4: @game/ServerScriptService/Server/Data/SessionLock → [fonte](../../src/ServerScriptService/Server/Data/SessionLock.luau)
- L5: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/SpectatorRules.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/SpectatorRules.luau) · 34 linhas · SHA-256: e35a8e27b054a2a4e3a83f207c6ca134ec21395d642310e9682e9f91d0353c7d

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/SpectatorRules → [fonte](../../src/ReplicatedStorage/Shared/Game/SpectatorRules.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/StoreCatalog.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/StoreCatalog.luau) · 91 linhas · SHA-256: ec1fbc0afd2d72803590723d8d33916c24c3c51aaaacfd7272978e518b28ebde

### Funções nomeadas / callbacks atribuídos

~~~text
L8: run = function(t)
L55: local function check(reward: StoreCatalog.Reward)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/Economy → [fonte](../../src/ReplicatedStorage/Shared/Game/Economy.luau)
- L3: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/StoreFunnel.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/StoreFunnel.luau) · 22 linhas · SHA-256: b07f230e176f3344e03d139daea2d1b046233367cd1a86709c8f3c5582f009bb

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Game/StoreFunnel → [fonte](../../src/ServerScriptService/Server/Game/StoreFunnel.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/StoryMode.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/StoryMode.luau) · 172 linhas · SHA-256: 3396cb4fdc5047c5f63d5f916d74f13a766f51f4d0b2435a8dd230db850474d4

### Funções nomeadas / callbacks atribuídos

~~~text
L13: run = function(t: TestKit.Context)
~~~

### Dependências literais

- L2: @game/ServerScriptService/Server/Campaign/CoopSession → [fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau)
- L3: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L4: @game/ServerScriptService/Server/Campaign/HousePlan → [fonte](../../src/ServerScriptService/Server/Campaign/HousePlan.luau)
- L5: @game/ReplicatedStorage/Shared/Game/StoryCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoryCatalog.luau)
- L6: @game/ReplicatedStorage/Shared/Game/GameModes → [fonte](../../src/ReplicatedStorage/Shared/Game/GameModes.luau)
- L7: @game/ReplicatedStorage/Shared/Game/CinematicShots → [fonte](../../src/ReplicatedStorage/Shared/Game/CinematicShots.luau)
- L8: @game/ServerScriptService/Server/Data/PlayerDataSchema → [fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau)
- L9: @game/ServerScriptService/Server/Game/Oxygen → [fonte](../../src/ServerScriptService/Server/Game/Oxygen.luau)
- L10: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L142: @game/ReplicatedStorage/Shared/Game/HousePreferences → [fonte](../../src/ReplicatedStorage/Shared/Game/HousePreferences.luau)

## src/ServerScriptService/Tests/Specs/StoryRewards.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/StoryRewards.luau) · 88 linhas · SHA-256: c78f049265bded196a9c8d966317eb99d6ae4892cee5f17f26e01aa6ac63ccb5

### Funções nomeadas / callbacks atribuídos

~~~text
L10: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/Perks → [fonte](../../src/ReplicatedStorage/Shared/Game/Perks.luau)
- L3: @game/ReplicatedStorage/Shared/Game/StoreCatalog → [fonte](../../src/ReplicatedStorage/Shared/Game/StoreCatalog.luau)
- L4: @game/ReplicatedStorage/Shared/Game/StoryRewards → [fonte](../../src/ReplicatedStorage/Shared/Game/StoryRewards.luau)
- L5: @game/ServerScriptService/Server/Data/PlayerDataSchema → [fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau)
- L6: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/SurfacePatterns.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/SurfacePatterns.luau) · 30 linhas · SHA-256: 2ee9792c015fa41ebc2d64ef51716d4aec33e338e663f32e254c3ff86e6e88d2

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/SurfacePatterns → [fonte](../../src/ReplicatedStorage/Shared/Game/SurfacePatterns.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/TableUtil.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/TableUtil.luau) · 62 linhas · SHA-256: a1ede7b9c94e2693a224f79f8935659fe774be7fcb26f07ba42191918c535cec

### Funções nomeadas / callbacks atribuídos

~~~text
L7: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/TaskRewards.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/TaskRewards.luau) · 35 linhas · SHA-256: 0ef1718771aec904c4879ca1c106d4243e1f96a89ddfe1d667736518da5b812d

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t)
L14: local function grant(): boolean
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/TaskRewards → [fonte](../../src/ReplicatedStorage/Shared/Game/TaskRewards.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/TaskStations.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/TaskStations.luau) · 71 linhas · SHA-256: 469f9b09e2093f5b43c4ee6f11e5fb1c36554c5507c6f2a0dd54485daf5ec2e8

### Funções nomeadas / callbacks atribuídos

~~~text
L6: run = function(t)
L11: local function fixture(mode: string, stage: number, run: (any, any) -> ())
~~~

### Dependências literais

- L2: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)
- L7: @game/ServerScriptService/Server/Campaign/ActivityBuilder → [fonte](../../src/ServerScriptService/Server/Campaign/ActivityBuilder.luau)
- L8: @game/ServerScriptService/Server/Campaign/CoopSession → [fonte](../../src/ServerScriptService/Server/Campaign/CoopSession.luau)
- L9: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L10: @game/ReplicatedStorage/Shared/Game/Tags → [fonte](../../src/ReplicatedStorage/Shared/Game/Tags.luau)

### Estado observado / publicado

~~~text
L36: t.expect(built.targets[`{id}_3`].focus:GetAttribute(Tags.Attr.InteractPrompt)).toBe("TESTAR ENERGIA")
L39: t.expect(built.targets[`{id}_3`].focus:GetAttribute(Tags.Attr.InteractEnabled)).toBe(false)
L51: t.expect(built.targets[`{id}_1`].focus:GetAttribute(Tags.Attr.InteractPrompt))
L58: t.expect(built.targets.task_2_1.focus:GetAttribute(Tags.Attr.InteractEnabled)).toBe(false)
L62: t.expect(built.targets.task_2_1.focus:GetAttribute(Tags.Attr.InteractEnabled)).toBe(true)
~~~

## src/ServerScriptService/Tests/Specs/TensionDirector.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/TensionDirector.luau) · 144 linhas · SHA-256: 663f5280e1c80dbffd808c833e20ef325454744858a1b2dc2c773fd74db0d55a

### Funções nomeadas / callbacks atribuídos

~~~text
L8: local function ctx(overrides: { [string]: any }): TensionDirector.Context
L28: local function always(): number
L33: local function simulate(
L55: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Config → [fonte](../../src/ReplicatedStorage/Shared/Config.luau)
- L3: @game/ReplicatedStorage/Shared/Game/TensionDirector → [fonte](../../src/ReplicatedStorage/Shared/Game/TensionDirector.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/ThreatPresentation.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/ThreatPresentation.luau) · 50 linhas · SHA-256: c7ce5a82c3bbd371c4212dad5d85f77502e0337d80b438857de7bc0add60720b

### Funções nomeadas / callbacks atribuídos

~~~text
L7: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/ThreatPresentation → [fonte](../../src/ReplicatedStorage/Shared/Game/ThreatPresentation.luau)
- L3: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/TungTungClips.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/TungTungClips.luau) · 63 linhas · SHA-256: 193b019983bad40b3dffe049048d8ab7e9d83cfe4efa3dc606f1f8d1d5ad87c2

### Funções nomeadas / callbacks atribuídos

~~~text
L10: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Client/Creature/ClipCodec → [fonte](../../src/ReplicatedStorage/Client/Creature/ClipCodec.luau)
- L3: @game/ReplicatedStorage/Client/Creature/TungTungClips → [fonte](../../src/ReplicatedStorage/Client/Creature/TungTungClips.luau)
- L4: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/Specs/VisualQuality.luau

[Abrir fonte](../../src/ServerScriptService/Tests/Specs/VisualQuality.luau) · 50 linhas · SHA-256: 200e4f345fea7fe650c93c33c9cdba5ddb8b527ccfe1a1cc1801dd89c3e56200

### Funções nomeadas / callbacks atribuídos

~~~text
L8: run = function(t)
~~~

### Dependências literais

- L2: @game/ReplicatedStorage/Shared/Game/VisualQuality → [fonte](../../src/ReplicatedStorage/Shared/Game/VisualQuality.luau)
- L3: @game/ReplicatedStorage/Shared/Game/HousePreferences → [fonte](../../src/ReplicatedStorage/Shared/Game/HousePreferences.luau)
- L4: @game/ServerScriptService/Server/Data/PlayerDataSchema → [fonte](../../src/ServerScriptService/Server/Data/PlayerDataSchema.luau)
- L5: ../TestKit → [fonte](../../src/ServerScriptService/Tests/TestKit.luau)

## src/ServerScriptService/Tests/TestKit.luau

[Abrir fonte](../../src/ServerScriptService/Tests/TestKit.luau) · 167 linhas · SHA-256: b013f951e34ca1e9caaaeb65de6870dbc5b29920f8866a8b7634b7f03580a144

### Funções nomeadas / callbacks atribuídos

~~~text
L62: local function show(value: any): string
L69: local function expect(value: any): Expectation
L71: toBe = function(expected: any)
L76: toEqual = function(expected: any)
L81: toBeNil = function()
L86: toBeTruthy = function()
L91: toBeFalsy = function()
L96: toBeCloseTo = function(expected: number, epsilon: number?)
L101: toThrow = function(substring: string?)
L118: function TestKit.run(specs: { Spec }, options: RunOptions): Report
L129: describe = function(name: string, body: () -> ())
L134: it = function(name: string, body: () -> ())
L157: function TestKit.format(report: Report): string
~~~

### Dependências literais

- L21: @game/ReplicatedStorage/Shared/Util/TableUtil → [fonte](../../src/ReplicatedStorage/Shared/Util/TableUtil.luau)
