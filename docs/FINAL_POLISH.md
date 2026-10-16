# Polish final — Tung Tung Sahur: The Cursed House

Branch `claude/final-polish`, criada de `codex/cursed-house` (`20bf296`). Worktree:
`C:\Users\xpg\Documents\roblox-teste\.cache\final-polish`. Nada foi publicado e nenhum push foi feito.

## O que mudou

| Área | Entrega | Onde |
| --- | --- | --- |
| Criatura | Tung Tung novo do zip (malha com esqueleto, textura PBR) e 5 animações Mixamo convertidas em dados | `Assets/TungTung.rbxm`, `Client/Creature/{TungTungRig,TungTungClips,ClipCodec}`, `tools/tungtung/` |
| Animação | Andar/correr pela velocidade, golpe na captura, na porta e no início da perseguição, passo lateral na busca, guarda com respiração parado | `CreatureVisualController` |
| Cinema | Tung Tung aparece na porta na abertura ("NÃO ACORDE O DONO") e anda na varanda no fundo do menu | `CinematicController` |
| Luz | Noite de lua legível (lilás/azulada), cores vivas, bloom para itens brilhantes, lanterna mais forte | `LightingProfile` |
| Terreno | Gramado, colinas no horizonte, pedras e trilha de terra gerados por código | `World/HouseScenery` |
| Cenário | Floresta com copas redondas, cogumelos neon, abóboras acesas, lampiões, vaga-lumes, cerca, lápides, casa repintada, janelas acesas, varanda, portão de ferro | `World/HouseScenery` |
| Props | Móveis por cômodo (sala, cozinha, jantar, banheiro, biblioteca, quartos, escritório, sótão, porão, ritual), sem colisão | `World/HouseFurniture` |
| HUD | Cartão de objetivo com barra de progresso, barras de fôlego/lanterna/ar, inventário em quadrados, moedas e nível, marcador amarelo | `UI/FieldHud`, `CampaignController` |
| Textos | Guia, papéis, títulos, loja e temporada em linguagem simples e no tema da casa | `PlayerGuide`, `CampaignCatalog`, `StoreCatalog`, `Text`, `SeasonCatalog` |
| Recompensas | Moedas e uma gema por capítulo (Fichas + XP na hora), brilho e "plim"; comemoração de capítulo/vitória com confete; nível novo | `CoinService`, `Game/CoinPlan`, `CoinController`, `UI/Juice` |
| Menu | Ícones, aba AJUSTES, vitrine 3D animada do Tung Tung, paleta roxa | `MainMenuController` |
| Ajustes | Painel novo; filtros retrô/VHS desligados por padrão (continuam opcionais) | `SettingsController`, `Config.Comfort` |
| Sons | "TUM TUM TUM" do bastão com legenda quando ele está perto | `CreatureVisualController` |

Servidores (lista e entrada) e amigos (entrar no servidor do amigo, convidar) já existiam no menu e foram mantidos.

## Monetização e público infantil

A loja, o passe e os itens continuam. Mudanças para não pressionar criança a gastar:

- A derrota repete o capítulo **de graça e sozinha** em poucos segundos (já era assim no servidor).
  A tela antiga mostrava só "CONTINUAR · R$ 49"; agora mostra a contagem grátis e não tem botão de compra.
  Quem já tem Continuação (de kits) pode voltar na hora.
- As Continuações pagas saíram da vitrine (o produto existe no catálogo, com descrição honesta).
- O cartão fixo "OFERTA ÚNICA" saiu da tela inicial; o kit segue à venda na aba MELHORIAS.
- Baús pagos já mostravam as chances antes de abrir e respeitam `PolicyService` (mantido).

Não foram criadas mecânicas para prender a criança por horas nem gatilhos de compra.
O engajamento vem de progresso visível (moedas, níveis, capítulos, colecionáveis, passe).

## Assets enviados (conta do dono, 16/10/2026)

Malha `rbxassetid://111005002149644`; texturas cor `71421127786076`, normal `88828750077938`,
rugosidade `124558417113945`, metal `123416759825160`. As animações **não** são assets do Roblox.
Detalhes e como regerar: [tools/tungtung/README.md](../tools/tungtung/README.md).

## Validação

- `lune run scripts/check`: ALL GREEN, 260 testes puros (novos: `TungTungClips`, `CoinPlan`).
- Studio (`Tests.Run`) na build final: 268 aprovados, 0 falhas, inclusive `HouseNavigation` e `TaskStations`.
- Console do Play: zero erros do projeto. Mundo: 2037 peças, 106 luzes.
- Conferido no Studio: Tung Tung andando/correndo/golpeando, captura com o rosto do modelo,
  moeda coletada (Fichas 100 → 102), derrota com volta grátis, comemoração de capítulo, menu e vitrine,
  aparição na abertura.
- Multijogador (`StudioTestService:ExecuteMultiplayerTestAsync`, harness `campaignQA`, receita em COOP_QA.md):
  História com 2 clientes: 64 verificações, 5 capítulos, Won. Desafio (padrão) com 2: 64, Won.
  História com 6 clientes (máximo): 68 verificações, 5 capítulos, Won. Nenhuma falha nem erro de projeto.
- Som novo da moeda (`rbxasset://sounds/electronicpingshort.wav`): `PreloadAsync` = Success.

Como testar: `lune run scripts/check`, depois `powershell -File tools/reopen_qa.ps1` (gera
`build/FinalPolish.rbxlx` e abre no Studio). O modelo só existe em builds Rojo
(`default.project.json`): o Script Sync não copia o `.rbxm`; sem ele o jogo volta ao boneco antigo.

## Limites conhecidos

- Diversão, ritmo e balanceamento precisam de partidas com pessoas reais (os testes automáticos
  teleportam e congelam a criatura).
- Desempenho em celular físico não foi medido (106 luzes pontuais, 2 mil peças).
- Os móveis não colidem (o jogador atravessa alguns) para não mexer em rotas e estações.
- O visual da abertura no lobby usa as câmeras originais do Codex.
- Publicar, criar produtos e ligar "Allow Mesh/Image APIs" (usado pelas texturas de superfície
  do ArtController) são passos humanos no Creator Hub.
