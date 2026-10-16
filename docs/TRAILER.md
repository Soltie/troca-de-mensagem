# Trailer do jogo (30–45 s) — passagem para o Codex concluir

16/10/2026. Pedido do humano: vídeo de trailer/teaser estilo cinema, com logo no começo e no fim, títulos
grandes, cenas do Vigia, dos jogadores, do que dá para fazer e das áreas, impactos/explosões e suspense
entre as cenas. **O Claude parou por limite de uso; o Codex deve concluir.** Nada foi publicado.

## Como funciona (decisão)

O trailer é **montado e tocado dentro do Roblox** e **gravado com o OBS** (instalado, v32.2.2).
Sem ffmpeg/Python na máquina: toda a edição (cortes, títulos, sons, impactos) acontece no jogo, e o OBS só grava.

- `src/ReplicatedStorage/Client/Controllers/TrailerController.luau` — roteiro de ~40 s, só age no Studio
  (`RunService:IsStudio()`); registrado no fim de `Main.client`. Ponte de controle:
  `PlayerGui.TrailerUi.TrailerBridge:Invoke("play" | "seek", t | "stop")` (cliente).
- `src/ReplicatedStorage/Client/Trailer/TrailerActors.luau` — atores locais: 3 cópias do personagem com
  lanterna e poses (andar, correr, alcançar, ajoelhar, caído) e o Vigia (Rig + Poses do jogo, 12 qps).
- Roteiro (tempo do trailer): 0 preto + legenda "16 DE OUTUBRO · 03:12"; 3,6 LOGO (impacto); 5,2 estrada →
  portão; 8,4 equipe chegando à recepção; 12,0 "ELES ENTRARAM JUNTOS."; 13,2 corredor (Vigia ao fundo, a luz
  falha, ele está perto); 16,6 close do rosto + rugido → "O VIGIA"; 18,5 montagem (painel, disjuntores com
  faíscas/explosão, armário "ESCONDA-SE", perseguição, resgate "SALVE SUA EQUIPE", ala nova "UM MAPA NOVO",
  pichação "ELE SEGUE A LUZ" brilhando, "FUJA" no pátio); 28,8 bote do Vigia → corte seco com o maior impacto;
  30,0 silêncio + batimento; 31,6 LOGO final + "MODO HISTÓRIA · CO-OP DE 3 A 8 JOGADORES" + "EM BREVE NO ROBLOX".
- Sons: todos de `Shared/Game/Audio.luau` (licenciados, já usados no jogo), pré-carregados com sucesso (24/24).
- Enquadramentos conferidos por captura no Studio (seek): chegada, corredor (longe/perto), rosto, disjuntores,
  armário, perseguição, resgate, ala nova, pichação, fuga, bote e logo final — todos legíveis.

## Ambiente de gravação (estado em que o Claude parou)

- **Studio:** `build/Test.rbxlx` (place descartável, SEM Script Sync; studio_id do MCP
  `3b66b8d0-5c4d-40da-86f7-03e7c01bd175`). A janela (hwnd **3478006**, pode mudar se reabrir) está **visível e
  maximizada no 2º monitor** (DISPLAY2, x −1920..0). A área do jogo medida: tela (−1634,167) 1452×793.
  O Dev continua com o Codex; nada foi feito nele.
- **Código na place:** copiado de `src/` por um servidor local. Para atualizar: `node tools/trailer/serve_src.js
  C:/Users/xpg/Documents/roblox-teste` (porta 8765, em segundo plano) e, no Studio em **Edit**, rodar o trecho
  "Sincronizar" abaixo. Depois de sincronizar, trocar `Enabled = true` → `false` na `Config` **da place** (missão
  solo, só nela) — o trecho já faz isso.
- **Preparar a cena (Play):** esperar `GameState.Phase == "Playing"`, depois no **Server**:
  `DebugBridge:Invoke("freezeCreature", true)` e `DebugBridge:Invoke("placeCreature", Vector3.new(0,0,400))`
  (o Vigia do servidor sai de cena; o do trailer é local).
- **OBS:** perfil e coleção próprios **"S9Trailer"** (os do usuário, "Untitled", não foram alterados; o
  `user.ini` foi restaurado para Untitled). Gerados por `node tools/trailer/obs_setup.js 286 167 182 120`
  (recorte esquerda/cima/direita/baixo no monitor 2). Fonte de vídeo = **captura de tela do monitor 2**
  recortada na área do jogo; fonte de áudio = **áudio só do processo do Studio** (título do Test.rbxlx).
  Saída MP4 x264 1280×720 30 fps em `build/trailer/` (pasta ignorada pelo git). Atalhos globais:
  **Ctrl+Alt+Shift+NumPad7** grava, **NumPad8** para (F9 abre o console do Roblox — não usar).
- Abrir o OBS: `Start-Process "C:\Program Files\obs-studio\bin\64bit\obs64.exe" -ArgumentList '--profile
  "S9Trailer" --collection "S9Trailer" --minimize-to-tray --disable-shutdown-check --disable-updater'
  -WorkingDirectory "C:\Program Files\obs-studio\bin\64bit"`. Se aparecer "OBS Studio Crash Detected" (ocorre
  depois de encerrar à força), clicar **Run in Normal Mode** (dá para clicar via UI Automation; ver histórico).
  Ao terminar, fechar o OBS e conferir que o `user.ini` continua com `Profile=Untitled`.
- Scripts: `tools/trailer/studio_window.ps1 -Action show|focus|measure|hide -Hwnd <hwnd>` (mostra/foca a janela,
  mede a área magenta para o recorte), `tools/trailer/obs_key.ps1 -Which start|stop` (atalhos do OBS).

## O que já foi provado

- Gravação por atalho funciona (OBS log: "Starting/Stopping recording due to hotkey"); foco mantido no Studio
  durante 41 s (Studio sem foco cai para 15 qps).
- Take 1 (`build/trailer/S9Trailer_2026-10-16_12-29-14.mp4`, 47,7 s, com áudio): todas as cenas 3D estão lá,
  **mas sem a interface** (sem faixas, títulos, logo e legendas) porque usava **captura de janela** — a camada
  de UI do Studio não entra nela. Por isso a fonte já foi trocada para **captura de tela** (falta gravar).
  Também sobrou ~2 s antes do início e jogo normal depois do fim.

## Falta fazer (Codex)

1. **No `TrailerController`:**
   - comando `"arm"(segundos)`: agenda o início para daqui a N s e devolve o horário em
     `DateTime.now().UnixTimestampMillis`; antes do início, tela preta;
   - ao passar de 40,5 s, **manter preto** em vez de chamar `stop()` (senão o jogo aparece no fim);
   - `lune run scripts/check` verde.
2. Sincronizar a place (trecho abaixo), Play, preparar a cena (Vigia congelado e longe), pré-carregar os sons
   (opcional: os IDs de `Audio`).
3. Abrir o OBS com o perfil S9Trailer. Confirmar no log: `Loaded scenes` com `Studio` (monitor_capture) e
   `StudioAudio`.
4. Gravar:
   - `studio_window.ps1 -Action focus`;
   - `"arm"(4)` pelo MCP (cliente) para obter o horário de início;
   - no PowerShell, esperar até o início − 0,3 s, mandar `obs_key.ps1 -Which start`, esperar 41 s e mandar
     `obs_key.ps1 -Which stop`;
   - não tirar o foco do Studio.
5. Revisar o MP4. Navegador interno: abrir o `file:///…mp4`, desenhar quadros num `<canvas>` (folha de
   contato) e conferir:
   - legendas, logo no começo/fim, títulos e faixas de cinema;
   - que o áudio decodifica (`webkitAudioDecodedByteCount` sobe).
6. Entregar ao humano o arquivo final em `build/trailer/` (renomear para `SUBESTACAO9_TRAILER.mp4`) e anotar o
   resultado aqui. Opcional: esconder de novo a janela do Test.rbxlx (`-Action hide`).

### Trecho "Sincronizar" (execute_luau, Edit, place Test.rbxlx)

```lua
local H = game:GetService("HttpService")
H.HttpEnabled = true
local ok, body = pcall(H.GetAsync, H, "http://127.0.0.1:8765/files.json")
H.HttpEnabled = false
assert(ok, body)
for _, f in H:JSONDecode(body) do
	local parent = game:GetService(f.parts[1])
	for i = 2, #f.parts - 1 do
		local c = parent:FindFirstChild(f.parts[i])
		if not c then c = Instance.new("Folder"); c.Name = f.parts[i]; c.Parent = parent end
		parent = c
	end
	local inst = parent:FindFirstChild(f.parts[#f.parts])
	if inst and inst.ClassName ~= f.kind then inst:Destroy(); inst = nil end
	if not inst then
		inst = Instance.new(f.kind); inst.Name = f.parts[#f.parts]
		if f.ctx ~= "" then inst.RunContext = Enum.RunContext[f.ctx] end
		inst.Parent = parent
	end
	if inst.Source ~= f.source then inst.Source = f.source end
end
local config = game.ReplicatedStorage.Shared.Config
config.Source = string.gsub(config.Source, "Enabled = true,", "Enabled = false,", 1) -- missão solo só na place
```

## Limites

- Os atores são cópias do avatar do humano (XISPEGE). Para divulgar, confirmar se ele quer o próprio avatar
  no vídeo. O rosto do Vigia é a foto real do Ademir (ver `docs/ASSETS.md`): o consentimento dele vale também
  para o trailer.
- Nada foi enviado para a Roblox nem para outro serviço. O vídeo fica local.
