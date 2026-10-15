# Equipe de três pessoas — código, mundo e testes

Preparado em 15/10/2026. Fluxo recomendado para este repositório.

## Onde cada coisa fica

| Trabalho | Fonte oficial | Como compartilhar |
| --- | --- | --- |
| Scripts, UI por código, mapa procedural e configurações | Git, em `src/` | Repositório privado e pull requests |
| Modelos, texturas e arquivos de origem | `assets/`, quando adequados ao Git | Commits; assets da Roblox também precisam de permissão para a experiência |
| Objetos feitos manualmente em Edit | Place compartilhada da Roblox | Team Create e backups locais |
| Testar juntos, em computadores diferentes | Mesma sessão de Studio | Team Test |

Repositório: https://github.com/Soltie/roblox-teste (privado).

Cópia local de desenvolvimento: `C:\Users\xpg\Documents\roblox-teste`.
Cópia dedicada de integração, já clonada e com check verde:
`C:\Users\xpg\Documents\roblox-teste-integracao`.
Uma cópia separada evita que mudar a branch de desenvolvimento altere a place compartilhada.

Cada pessoa tem sua própria cópia local do repositório. Não coloquem a pasta de trabalho em
OneDrive/Google Drive/Dropbox para edição simultânea e não compartilhem uma única pasta `.git`.
Um commit é um ponto de recuperação; o push envia esse ponto para o remoto.

## Regra que impede sobrescritas pelo Script Sync

**Só um computador sincroniza os scripts na place compartilhada.** Chamaremos essa pessoa de
integrador. Os demais podem editar objetos e testar nessa place, mas mantêm o Script Sync
desconectado nela e não alteram os scripts pelo editor do Studio.

Os outros programadores sincronizam `src/` apenas em suas places LOCAIS. Enviam suas alterações
por branch e pull request. Após revisão, o integrador leva a versão aprovada à place compartilhada.
O integrador também desenvolve em cópia separada; sua pasta ligada à place compartilhada fica
dedicada à versão integrada. Nunca troque de branch com o sync compartilhado ativo.

A documentação da Roblox confirma que Script Sync funciona com Team Create, mas alerta que
múltiplos usuários sincronizando os mesmos scripts podem sobrescrever mudanças. O sync é
bidirecional e não substitui revisão/merge do Git.
[Fonte: Script Sync](https://create.roblox.com/docs/scripting/sync).

## Configuração inicial

### 1. Identificar as pessoas

Preencher antes dos convites:

| Pessoa | Roblox | GitHub | Função inicial |
| --- | --- | --- | --- |
| Responsável | a preencher | Soltie | Integrador e código |
| Pessoa 2 | @roupadecama (informado; acesso ainda não verificado) | a preencher | Código ou mapa |
| Pessoa 3 | a preencher | a preencher | Arte, mapa ou QA |

As funções podem mudar. Todos podem programar em paralelo; só a entrada de código na place
compartilhada tem um responsável por vez. Não compartilhem senhas.

### 2. Entrar no GitHub

O responsável convida os dois usuários em **Settings → Collaborators / Manage access → Add people**.
Cada colega aceita e clona `https://github.com/Soltie/roblox-teste.git`, pelo GitHub Desktop ou Git.
Uma conta GitHub existente basta; quem não tiver precisa criar a própria conta.

Em cada máquina, instalar Roblox Studio, Git e Rokit (origem oficial:
https://github.com/rojo-rbx/rokit). Abrir um terminal na cópia do projeto:

```powershell
rokit install
lune run scripts/check
lune run scripts/build dev
```

O último comando cria `places/Dev.rbxlx` apenas se ela ainda não existir. Não usar `--force` sobre
uma place com trabalho manual. Abrir essa place LOCAL e configurar os dois serviços pelo
[passo a passo do Script Sync](MANUAL_STEPS.md). Na configuração atual do Studio, Script Sync já
foi lançado oficialmente; pode não aparecer mais em Beta Features.

### 3. Criar a experiência privada de desenvolvimento

O responsável abre a place correta no Studio, encerra o Play e usa **File → Publish to Roblox**
para criar uma experiência chamada provisoriamente `Roblox Teste - Desenvolvimento`.
Confirma que ela permanece privada e anota os IDs/link no final deste documento.
Salvar na Roblox para colaborar é diferente de disponibilizar o jogo ao público.

Para começar, a experiência pode ficar na conta pessoal do responsável. Um grupo pode ser
avaliado depois, se quiserem gestão por cargos; não é necessário criar/comprar um agora.

Em experiência pessoal: adicionar os dois como amigos Roblox; no Studio, **Collaborate**, buscar
cada usuário, dar **Edit** e salvar. Eles abrem a experiência compartilhada com **Edit in Studio**.
Team Create também exige os requisitos atuais de idade/verificação da Roblox. Em experiências
de grupo, edição é gerida por cargos. [Fonte: colaboração](https://create.roblox.com/docs/projects/collaboration).

Somente o integrador configura `ServerScriptService` e `ReplicatedStorage` dessa place para
sincronizar com uma cópia dedicada e limpa da `main`. Os outros não conectam o sync nela.

### 4. Validar o início

- Os três conseguem abrir a mesma experiência e veem os colaboradores.
- Somente o integrador tem sync dos scripts na place compartilhada.
- Cada programador consegue testar sua cópia local sem mudar a sessão dos outros.
- Uma alteração pequena, revisada e integrada aparece no Team Test dos três.
- Um integrante novo consegue clonar o repo e executar `scripts/check`.

## Rotina de código

Com sync da place compartilhada desconectado, ou na cópia local de desenvolvimento, iniciar
somente com `git status` limpo. Se houver alterações, salvar e fazer commit dos próprios arquivos
antes de atualizar; não descartar arquivos para limpar a pasta.

```powershell
git switch main
git pull --ff-only
git switch -c codex/minha-tarefa
```

Editar em `src/`. Combinar a divisão de arquivos (por exemplo servidor, cliente/UI e mundo).
Arquivos centrais como os dois `Main`, `Config` e `Remotes` precisam de coordenação explícita.

```powershell
lune run scripts/check
# Fazer playtest local e ler o console.
git add caminho/do/arquivo.luau
git commit -m "feat: descreve a mudança"
git push -u origin codex/minha-tarefa
```

Abrir pull request para `main`, usando o template, e pedir revisão a outro integrante.
Resolver conflitos na branch, revisar a combinação e repetir os checks antes do merge.
O agente deste projeto só faz push quando autorizado pelo humano.

Depois do merge, o integrador encerra Team Test, desconecta o sync mantendo os arquivos, verifica
que sua cópia de integração está limpa, atualiza `main` com `git pull --ff-only`, roda o check e
reconecta o sync. Revisa o diálogo antes de escolher Keep Disk; o disco deve corresponder ao
commit aprovado e não pode apagar trabalho válido da nuvem. Salva e inicia novo Team Test.

Sem proteção de branch disponível, revisão é um acordo da equipe, não bloqueio técnico.
No GitHub, proteção de branches em repos privados depende do plano; não pressupor que esteja
ativa. [Fonte: proteção de branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches).

## Jogar juntos

Com os três na experiência compartilhada, uma pessoa seleciona **Team Test** no menu de teste
e clica Play. Os outros entram pelo Play em seus Studios. Ao terminar, **End Session**.
Só pode existir uma sessão Team Test por vez. Para simular sozinho, usar **Server & Clients**
com três clientes; isso não reúne três computadores.
[Fonte: modos de teste](https://create.roblox.com/docs/studio/testing-modes).

Registrar o commit testado, os três participantes e o resultado. Verificar entrada simultânea,
interações do jogo, sair/voltar e console. O teste com três humanos só está validado após os
três realmente entrarem; um teste automatizado local não comprova isso.

## Cuidado específico com o mapa deste jogo

`WorldService.Init()` chama `MapBuilder.build(workspace)`. O mapa e a iluminação são criados
por código no começo da sessão; `MapBuilder` remove uma raiz anterior com o mesmo nome.

Assim, o trabalho principal de layout/aparência passa por `Server/World/Layout.luau`,
`MapBuilder.luau`, `Palette.luau` e `WorldService.luau`. Alterar o mapa durante Play não salva
a mudança. Não substituir esse mapa por edições manuais sem adaptar o construtor.

Se começarem a criar cenários manuais em Edit, dividir áreas/modelos entre as pessoas e
exportar checkpoints em `.rbxmx` versionados ou definir outro fluxo de assets antes de usá-los
no jogo. A adaptação do construtor para consumir esses assets ainda precisará ser implementada.
Script Sync não salva Parts, Terrain, Models, propriedades e tags como um backup completo.

## Recuperação e backup

- Código: commits pequenos e push da branch; recuperar uma mudança integrada com `git revert`
  e um novo PR. Não usar force push/reset destrutivo como rotina.
- Trabalho ainda sem commit: salvar cópia ou patch antes de tentar resolver um problema.
- Place manual: manter checkpoints locais com data, fora da pasta ignorada de builds; guardar
  cópia adicional em armazenamento de backup. Nuvem e Git cumprem funções diferentes.
- Recuperação da place: suspender colaboração com a equipe antes de restaurar histórico para
  que outra sessão não grave por cima. O histórico da Roblox não substitui cópia independente.
- `*.rbxl` e `*.rbxlx` estão ignorados pelo Git deste projeto; o push NÃO leva esses arquivos.

## Situação da implantação

Os IDs e convites abaixo só devem ser marcados como concluídos depois de verificados:

- [x] Repositório privado criado: https://github.com/Soltie/roblox-teste
- [x] Código anteriormente commitado enviado à `main`.
- [x] Cópia dedicada de integração clonada; check `ALL GREEN`, 73 testes puros passando,
  2 specs exclusivos do Studio pulados. Há aviso existente de API obsoleta `LoadCharacter`.
- [ ] Experiência privada criada e ID confirmado: a preencher.
- [ ] Contas dos dois colegas recebidas e convites aceitos nas duas plataformas.
- [ ] Integrador e pasta de integração definidos e sync único verificado.
- [ ] Check na máquina de cada integrante.
- [ ] Team Test com os três humanos concluído.

Preparação no Studio: foi aberta uma segunda instância com `build/Test.rbxlx`, gerada da cópia
de integração. O formulário `Publish Experience` está preenchido com o nome provisório e
Team Create ligado; isso ainda NÃO confirma criação. A opção `Data Sharing` apareceu ligada
por padrão; a escolha do responsável está pendente antes de enviar o formulário. Essa instância
de build ainda não tem Script Sync configurado. Depois de salvar na nuvem, abrir a experiência
compartilhada e conectar o sync da cópia dedicada, após conferir o diálogo de diferenças.

Alternativas: trabalhar somente no Studio com Live Scripting/Drafts é possível, mas exigiria
mudar a regra deste projeto de editar scripts pelo disco. Migrar tudo para Rojo seria outra
decisão de arquitetura; não iniciar `rojo serve` junto com o Script Sync atual.
