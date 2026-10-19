# REPASSE COMPLETO Claude → Codex (limite de uso do humano perto do fim)

O humano pediu que, perto do fim do limite, eu passasse tudo para o Codex continuar. Este é o estado inteiro.

## 1. Onde está cada coisa

- **Place tungtung (82955516040017), Team Create, NÃO publicado:** contém os lotes 1–7 + item 1 (luz). 266 scripts,
  Tests.Run 347/347, console sem erros. Aplicado por MCP (ScriptEditorService/instâncias), **sem Script Sync**.
- **Código-fonte:** branch `claude/ambiente3d-sobre-integrado` sobre `e23b635`, em
  `entregas/claude-ambiente3d/sobre-e23b635/` (patches 0001–0011 + `ambiente3d-sobre-e23b635.bundle`).
  - 0001–0010 = o que está no place. **0011 (escala dos móveis, item 4) NÃO está no place e NÃO foi testado em jogo**
    (só check ALL GREEN).
- Fora do Script Sync (precisa estar no place; já está): 13 MaterialVariant em `MaterialService`,
  `ReplicatedStorage.Assets.MansionProps` (53 modelos), `Workspace.Terrain` Decoration=true / GrassLength=0.55.
- **Antes de religar o Script Sync do integrador:** aplicar 0001–0010 na raiz `tungtung-integrado` e somar a linha
  `require("./Controllers/RainController")` no `Client/Main.client.luau` (depois do WorldFxController; manter a do
  DynamicHouseController). Senão o sync sobrescreve o place.

## 2. Lista do humano, na ordem de prioridade dele (trabalhar UM POR VEZ e parar para ele conferir)

| # | Problema | Estado |
| --- | --- | --- |
| 1 | Iluminação clara/chapada; quer casa ESCURA, com shaders, lanterna como fonte principal | **FEITO e APROVADO** (`HouseLights.luau`, `LightingProfile`) |
| 2 | Avisar integrador sobre Script Sync | feito (mensagens 009/010/esta) |
| 3 | Boneco pulando sozinho | **resolvido** sem mudança (humano: "já parou") |
| 4 | Móveis grandes demais (cadeira maior que o jogador) | **código pronto (patch 0011), falta testar e aplicar**: `FURNITURE` 1.25→0.85 em `HouseProps`; cama, mesa baixa, guarda-roupa do esconderijo e tapetes mantêm o tamanho (`KEEP`) porque cobrem colisões antigas; sofá/mesa de jantar/caixotes/caldeira sem exagero |
| 5 | Móveis sem colisão (atravessa sofá/mesa/estante) | pendente. Sugestão: caixa invisível CanCollide=true, CanQuery=false, do tamanho da base de cada móvel grande; rodar HouseNavigation/EstateGround depois |
| 6 | Restos primitivos nos cômodos (blocos cinza na estante da Sala, caixote liso no chão, bloco amarelo na parede = vela por cômodo do HouseBuilder, bloco vermelho na Cozinha, caixote no corredor antes da "PASSAGEM SELADA") | pendente |
| 7 | Itens de missão em bloco (fusível = bloco bege; chaves/moedas em caixotes) | pendente. Trocar só o visual (HouseActivities/CampaignActivities), manter peça, prompt, atributos, tags, colisão |
| 8 | Guarda-roupa do esconderijo horrível (modelo meu + folha `WardrobeLeaf` soldada à HideDoor) | pendente. Modelo bom com porta própria; HideDoor, prompt e câmera intactos |
| 9 | Portas dos cômodos horríveis (`MansionDoor` meu, `HouseFinish.dressDoor`) | pendente |
| 10 | Sofá feio e fora do estilo (Sofa_01 creme) | pendente. Trocar por sofá vitoriano escuro e gasto |
| 11 | Grama do Terrain feia (lâminas enormes amarelo-oliva) | pendente. Opções: GrassLength menor, cor mais escura/fria, ou Decoration=false |
| — | Testes que faltam | celular físico, partida humana completa (chuva x avisos da criatura), câmera dentro do guarda-roupa, floresta com lanterna, mouse físico |

Referência aprovada pelo humano: a **Cozinha** no cap. 1 (escura, ladrilho xadrez, luz quente pontual).

## 3. Como o humano quer que se trabalhe

- Um item por vez, seguindo a prioridade; **um teste sólido no final de cada item**, não dez; aplicar no tungtung e
  **parar para ele conferir** jogando no Studio (Play → História).
- Quando ele disser "anote", só registrar, sem mexer.
- Não publicar no Roblox sem ele mandar. Só UI/HUD/regras/economia/IDs são intocáveis (escopo visual).

## 4. Como aplicar no place sem Script Sync (o que eu usei)

1. Rojo build de um projeto só com os arquivos alterados → `.rbxm` em `<Studio>/content/`.
2. No Studio (Edit, MCP): `game:GetObjects("rbxasset://X.rbxm")`, e para cada script `ScriptEditorService:UpdateSourceAsync`
   (existente) ou `Clone().Parent` (novo), dentro de `ChangeHistoryService` recording.
3. Antes, conferir com soma de verificação que o Source do place é a versão esperada (não sobrescrever trabalho alheio).
4. Play local → `Tests.Run` → console.
