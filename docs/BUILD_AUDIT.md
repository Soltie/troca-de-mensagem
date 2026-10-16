# Auditoria da versão para teste em dupla — 16/10/2026

**Arquivo final:** `build/PlaytestDupla_ATUALIZADO.rbxlx`.
É um snapshot do código local atual, incluindo as alterações locais de trailer já existentes.
Não foi feito push, publicação ou alteração de acesso/configuração no Creator Hub.

## Conteúdo conferido

- 168 arquivos Luau em `src/`, 168 scripts embutidos na place.
- Todos os Sources idênticos ao disco após normalizar CRLF/LF; classes Script/ModuleScript conferidas.
- Zero scripts faltando, extras ou com código diferente. Inclui mapa, props, materiais, padrões de
  textura, dados do rosto, áudio, menu, iluminação, pós-processamento, modos e limite 2–8.
- A place inclui o mundo base de `places/world` e o preset do projeto principal. O cenário
  completo e suas texturas são construídos pelo código no início do Play, não ficam visíveis em Edit.
- A cópia executada no Studio (`PlaytestDuplaLightingCheck.rbxlx`) e o arquivo final têm o mesmo SHA-256:

```text
373DBDDCB4559821E03825C8980D506765EEC16906904E620A2C8B1ECEB86A8F
```

## Correção encontrada durante a auditoria

A build anterior declarava LightingStyle=Realistic e PrioritizeLightingQuality=true, mas o Studio
abria com Soft/false. Sem Technology explícita, a migração de iluminação ao carregar alterava o
preset. Foi adicionado **Technology=Future** aos dois projetos Rojo, preservando os valores novos.
O arquivo gerado contém Technology=4, LightingStyle=0 e PrioritizeLightingQuality=true.

Uma instância nova do Studio confirmou **Realistic/true** e
`RBX_OriginalTechnologyOnFileLoad=4`. O resultado foi conferido em Edit e no cliente durante Play.
Problema de serialização/migração também documentado no
[rbx-dom #637](https://github.com/rojo-rbx/rbx-dom/issues/637).

## Execução verificada nesta build

- `lune run scripts/check`: ALL GREEN, 235 testes passando, zero falhas, quatro specs só do Studio pulados.
- Runner no Studio: 258 testes passando, zero falhas, zero specs pulados.
- Boot: 15 services e 30 controllers. Menu inicial presente; mínimo 2 registrado no arquivo.
- Log do atlas: 5/5 imagens. Contagem real no cliente: 320 faces texturizadas, sete CRTs,
  19 emissores ArtDust, 137 partes de ArtDetails e duas imagens AdemirPhoto na UI.
- Rosto local carregado em 128×128. Padrões de superfície gerados pelo módulo atual do repositório.
- Iluminação: GlobalShadows=true, Realistic, prioridade de qualidade ativa, bloom=0,19.
  Com energia ligada no probe: exposição=0,10, contraste=0,10, fog=164 e DOF=0.
- Capturas visuais conferidas com a energia desligada e ligada. Câmera e energia foram fixtures
  temporárias durante Play; a place em Edit não foi modificada por essas sondas.
- 49 IDs de áudio únicos carregados em Sound instances: IsLoaded=true e TimeLength>0 para todos.
  Preload de strings isoladas não foi usado como aprovação: produziu um falso resultado de Failure;
  o teste válido usa instâncias Sound com SoundId preenchido e as remove após verificar.
- Console do projeto: boot e runner aprovados. Avisos UIBlox/FoundationProvider do Studio presentes.
- Play encerrado e câmera de QA liberada ao terminar.

## Limites da confirmação

O arquivo está atualizado em relação a esta pasta de desenvolvimento. Esta auditoria não confirma
que a mesma versão já foi publicada, nem que um servidor antigo foi encerrado.

As superfícies procedurais e o rosto usam EditableImage. Na experiência publicada é necessário
habilitar **Experience Settings → Security → Allow Mesh / Image APIs**, ou **Creator Hub →
Configure → Settings → Enable Mesh / Image APIs**. Essa configuração externa não é habilitada
por gerar uma nova place. Sem ela, o código usa os materiais/rosto geométrico de fallback.
Fonte: [documentação oficial de EditableImage](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableImage.yaml).

O teste com dois humanos, o carregamento de assets na experiência publicada e o desempenho nos
computadores da equipe continuam pendentes. A build local usa dados mock por ter GameId=0.

## Reproduzir e publicar a cópia correta

```powershell
rojo build default.project.json --output build/PlaytestDupla_ATUALIZADO.rbxlx
./tools/audit_place.ps1
```

O auditor gera `build/PlaytestDupla_ATUALIZADO.audit.json`, com hashes de cada script,
projeto e arquivos do mundo, e falha se houver divergência ou preset de iluminação incompleto.
Não substitui o roundtrip no Studio para novas versões do engine.

Abrir **PlaytestDupla_ATUALIZADO.rbxlx** pelo File → Open from File. A aba PlaytestDupla já
aberta antes da correção conserva a iluminação carregada anteriormente; não publicar a partir dela.
Selecionar a experiência e sua place inicial no Publish As e conferir o destino antes de sobrescrever.
