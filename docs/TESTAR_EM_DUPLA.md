# Testar em dupla e publicar uma versão

Atualizado em 16/10/2026. História e Padrão aceitam **2–8 jogadores**.

> Arquivo final auditado: **build/PlaytestDupla_ATUALIZADO.rbxlx**. Use essa cópia para publicar.
> Ela corrige a migração do preset de iluminação ao abrir no Studio. Veja [BUILD_AUDIT.md](BUILD_AUDIT.md)
> e confira Allow Mesh / Image APIs para as texturas procedurais na experiência publicada.
Os dois precisam votar no mesmo modo; depois começa a contagem de cinco segundos.
Um jogador sozinho aguarda companhia. A dificuldade em dupla ainda precisa de teste humano.

## Jogar juntos pelo Roblox

1. O responsável gera a versão atual com `lune run scripts/check` e `lune run scripts/build`.
   Abrir `build/Test.rbxlx` no Studio. Essa build já contém os scripts; não conectar Script Sync nela.
   Não usar uma build antiga nem `places/Dev.rbxlx` sem os dois serviços sincronizados.
2. Para atualizar a experiência existente, usar **File → Publish to Roblox As…** (o nome pode
   aparecer como **Publish As**), selecionar a experiência e sua place inicial corretas e confirmar
   a atualização. Se o Studio já estiver na experiência correta, usar **File → Publish to Roblox**.
   Conferir o destino antes de sobrescrever. Publicar a versão e liberar acesso público são etapas distintas.
3. Para convidar antes de liberar o jogo, usar **File → Invite early testers**, selecionar o
   amigo/Trusted Friend correto e confirmar **Invite**. O Roblox pode exigir verificação de idade.
   Para uma experiência que já usa permissões de teste, conferir **Collaborate → Play/Playtest**
   e **Creator Hub → Publish settings → Manage Audience → Manage access → Playtest → Playtesters**.
   Manter o acesso restrito aos convidados. Os convites atuais e suas condições de idade estão
   descritos na documentação oficial de publicação ao final deste guia.
4. O responsável entra pelo aplicativo Roblox. O colega entra pela lista de amigos → perfil
   do responsável → **Join/Entrar**, respeitando as configurações de entrada/privacidade da conta.
   Se disponível, também pode escolher o mesmo servidor na aba **Servers/Servidores** da experiência.
   Clicar Play separadamente não garante que cairão no mesmo servidor.
5. Aguardar ambos aparecerem na equipe e escolher o mesmo modo. Testar tarefas, relé em dupla,
   captura/resgate e evacuação. Depois de atualizar a versão, sair do servidor antigo e entrar em
   uma sessão nova; um servidor que já estava rodando pode continuar com o código anterior.

O link registrado em `TEAM_WORKFLOW.md` é
https://www.roblox.com/games/108829116970531. Esse cadastro é anterior a esta alteração;
a versão publicada e os acessos atuais precisam ser conferidos pelo responsável.
Para apenas jogar, o colega não precisa clonar o GitHub nem instalar a toolchain.

## Jogar juntos no Studio: Team Test

1. Os dois abrem **a mesma experiência da nuvem**, não dois arquivos locais separados.
2. O responsável concede **Edit** em Collaborate; em experiência pessoal, o colega precisa
   ser amigo. O Studio também pode exigir verificação de idade/requisitos de colaboração.
   Play/Playtest permite jogar, mas não concede edição/Team Create.
3. O colega abre pelo Creator Hub → **Shared With Me → Edit in Studio**.
4. Uma pessoa escolhe **Team Test → Play**. A outra pressiona **Play** no próprio Studio
   para entrar na mesma sessão. Ao terminar, **End Session**.

**Só o integrador mantém Script Sync conectado à place compartilhada.** Os dois serviços,
`ServerScriptService` e `ReplicatedStorage`, precisam refletir a mesma versão aprovada.
A pasta dedicada registrada é `C:\Users\xpg\Documents\roblox-teste-integracao\src`;
ela não recebe automaticamente os commits desta pasta de desenvolvimento.
Os demais mantêm o sync desconectado nessa place. Nunca usar `rojo serve` junto do Script Sync.

## Simular dois jogadores no mesmo computador

No Studio, escolher **Server & Clients**, definir **2** clientes e pressionar **Play/F7**.
São dois clientes simulados locais. Para duas pessoas em computadores diferentes, usar
o aplicativo Roblox ou Team Test conforme os passos acima.

## Liberar ao público depois

Após publicar e validar a versão, ir ao Creator Hub → **Publish settings → Manage Audience →
Manage access → Public**. Para acesso geral, desativar a restrição **Friends** e salvar.
Atender aos requisitos de conta, verificação de idade e questionário de maturidade exibidos
para o público escolhido. A liberação para todas as idades tem exigências adicionais.
Isso não é necessário para começar o teste restrito em dupla e não foi executado pelo agente.

Fontes oficiais consultadas em 16/10/2026:

- [Testes no Studio e Team Test](https://create.roblox.com/docs/studio/testing-modes)
- [Colaboração e permissões](https://create.roblox.com/docs/projects/collaboration)
- [Publicação, convites de teste e público](https://create.roblox.com/docs/production/publishing/publish-games-and-places)

## Validação local desta alteração

- `lune run scripts/check`: ALL GREEN; 235 testes passando, 0 falhas, 4 specs exclusivos do Studio pulados.
- Runner no Studio: 258 testes passando, 0 falhas, 0 specs pulados. As specs cobrem os três estágios
  de História e Padrão com 2–8 integrantes e votação em dupla, incluindo empate e espera solo.
- Script Sync da `Dev.rbxlx`: ambas as raízes SyncedAsRoot; configuração e menu atualizados confirmados.
- A tentativa adicional de simulação multiplayer via StudioTestService retornou sem resultado;
  não comprova dois clientes conectados. A sessão com dois humanos ainda precisa ser executada.
- Console local: avisos de UIBlox, consulta de política da loja indisponível e falha ao carregar
  a animação `114302219876492`. Publicação/permissões desse asset precisam ser conferidas na experiência.
- Build atual gerada em `build/Test.rbxlx`. Nenhum push ou publicação executado pelo agente.
