# Compartilhar e trabalhar em dois computadores

## Situação verificada na preparação

Em 17/10/2026 existem dois repositórios Git INDEPENDENTES e sem remote configurado:

- subestacao-9, branch codex/subestacao-9.
- tung-tung-sahur, branch codex/tung-tung-sahur.

O antigo https://github.com/Soltie/roblox-teste.git pertence ao histórico original. Baixar apenas esse remoto não garante receber as duas versões separadas, este guia nem commits locais posteriores. Os links/Place IDs antigos de TEAM_WORKFLOW/SETUP_REPORT são históricos e não comprovam qual experiência recebe cada jogo agora.

Este trabalho fez commits locais e um pacote portátil; não fez push, não criou remotos/repositórios GitHub nem concedeu acesso ao colega.

## Caminho pronto agora: pacote com fonte + histórico

O ZIP de entrega reúne:

~~~text
LEIA_PRIMEIRO.md
MANIFEST.json
subestacao-9/          fonte versionada + docs + build/Subestacao9.rbxlx
tung-tung-sahur/       fonte versionada + docs + build/TungTungSahur.rbxlx
historico/
  subestacao-9.bundle
  tung-tung-sahur.bundle
~~~

As pastas de fonte não contêm .git: são exportações auditáveis dos commits. Para desenvolver mantendo o histórico, clonar os bundles em pastas NOVAS fora da pasta extraída. Exemplo com o ZIP extraído em C:/Projetos/pacote e diretório de trabalho C:/Projetos:

~~~powershell
Set-Location C:/Projetos
git clone -b codex/subestacao-9 ./pacote/historico/subestacao-9.bundle ./subestacao-9
git clone -b codex/tung-tung-sahur ./pacote/historico/tung-tung-sahur.bundle ./tung-tung-sahur
~~~

Não clonar por cima de uma pasta já existente. O clone do bundle configura origin como caminho do bundle: isso NÃO é um servidor de colaboração. Remover esse origin local antes de adicionar o GitHub definitivo ou usar o bundle apenas para troca offline. Não executar git pull supondo que ele buscará trabalho do outro PC.

Dentro de cada clone:

~~~powershell
git log -1 --oneline
git status --short
rokit install
lune run scripts/check
lune run scripts/build
~~~

Abrir build/Test.rbxlx e ler LEIA_IA_COLEGA.md. Builds são ignoradas pelo Git, então um clone novo as regenera; o ZIP inclui duas builds prontas apenas por conveniência.

Bundle leva objetos e histórico Git alcançáveis pelo branch exportado, incluindo versões antigas. Tratar o pacote como privado. .cache, sessões de IA, credenciais/configurações privadas e alterações não commitadas não são incluídas pelo exportador da entrega.

Git bundle é transporte de repositório sem serviço remoto; [referência oficial](https://git-scm.com/docs/git-bundle).

## Caminho contínuo: dois repositórios privados no GitHub

O responsável cria dois repositórios PRIVADOS vazios na própria conta/organização, um por jogo, sem README inicial independente. Após conferir nomes, permissões e os commits que irão sair, executar no projeto correspondente (substituir URL_REAL; não executar o placeholder):

~~~powershell
git remote -v
git remote add origin URL_REAL
git push -u origin HEAD
~~~

Se já existir origin apontando para o bundle ou outro endereço, conferir e usar git remote set-url origin URL_REAL em vez de adicionar duplicado. Preservar o branch atual; a branch padrão do GitHub precisa apontar para a versão enviada. Se optarem por main, criar/integrar conscientemente, sem resetar o branch existente. Não enviar o segundo jogo ao primeiro remote por engano.

O responsável convida a conta GitHub do colega e ele aceita. Depois, no PC dele, clonar cada URL correta com Git/GitHub Desktop. Download ZIP do GitHub também baixa arquivos, mas não traz .git/histórico nem prepara branches/PRs; para contribuir, preferir clone.

GitHub privado só dá acesso ao código. Para abrir/editar o place compartilhado, a conta Roblox dele precisa receber a permissão adequada separadamente. Playtest não equivale a Edit. Sem permissão Roblox ele ainda pode editar e testar os arquivos locais; permissões de assets privados precisam ser conferidas na experiência de destino.

## Regra principal

**Na mesma place compartilhada, só o integrador mantém o Script Sync conectado.** Cada programador conecta o src/ do seu clone apenas à sua place LOCAL. Na place compartilhada os demais deixam sync desligado e não editam scripts pelo Studio. Isso evita que arquivos antigos de outro PC sobrescrevam o código integrado.

Em cada jogo: branch por tarefa → src/ → checks → QA local → commit → push autorizado → PR → revisão → integração. Quem integra atualiza uma cópia dedicada, conecta o src/ aprovado e testa em equipe. Não trocar de branch com o sync compartilhado ativo.

Exemplo após clone limpo e remoto já conferido:

~~~powershell
git status --short
git fetch origin
git switch -c codex/nome-da-tarefa
~~~

Escolher base correta antes de criar a branch; fetch sozinho não atualiza o código local. Se houver mudanças locais, preservá-las e combinar a integração; não usar reset --hard, clean, checkout -- ou stash automático para abrir caminho.

Ao concluir:

~~~powershell
git add CAMINHOS_DA_SUA_TAREFA
git diff --cached
git commit -m "feat: descricao da tarefa"
~~~

Push/PR/merge somente dentro da autorização recebida para aquele trabalho. Não usar git add . em pasta compartilhada com outras sessões.

## Sem GitHub, ainda dá para devolver alterações

Com a base do pacote e a tarefa commitada, criar um bundle incremental com o branch e excluir a base conhecida:

~~~powershell
git bundle create minha-tarefa.bundle HEAD ^COMMIT_BASE
~~~

COMMIT_BASE é o hash exato fornecido em MANIFEST.json, não a palavra literal. O integrador precisa ter essa base; inspeciona com git bundle list-heads, busca HEAD do bundle para uma branch de revisão e só integra após revisar diff/checks/QA. Alternativa: git format-patch COMMIT_BASE..HEAD e envio dos patches.

Não enviar apenas uma .rbxlx modificada como substituto dos commits: ela não mostra a fonte revisável de forma conveniente. Não sincronizar a mesma pasta .git por OneDrive/Drive/Dropbox.

## Para jogar juntos

Server & Clients é teste de vários clientes no MESMO PC. Team Test usa a experiência compartilhada e permissões Roblox. O responsável abre a sessão e os demais entram; encerrar a sessão ao terminar. Não é necessário dar acesso GitHub a alguém que só vai jogar, nem publicar o jogo ao público para desenvolver localmente.

As ferramentas de colaboração e suas exigências podem mudar: [documentação oficial Roblox](https://create.roblox.com/docs/projects/collaboration). Não presumir acesso de nomes/convites listados em documentos antigos.
