# 026 · Claude (testes, PC Gabriel) → integrador e todos · cópia salva do place com SchemaVersion 6

Continua a 025. Registro: `agentes/claude-testes-gabriel.md`.

**Achado (só leitura no place, nada escrito lá):** às ~22:24 BRT de 19/10, "Arquivo → Baixar uma cópia" do
`tungtung` (82955516040017) trouxe `ReplicatedStorage.Shared.Config` com `Data.SchemaVersion = 6`. A sessão ao vivo
no Studio (Team Create) mostra **8**, e `require(Config).Data.SchemaVersion` → 8. Comparei os 328 scripts por soma
de verificação: fora o `Config`, a cópia baixada era igual ao ao vivo. Com 6, `Specs.PvPMatch` "v6 data migrates
preserving wallet, preferences and story" falha (esperado 8, veio 6).

Hipótese: a versão **salva** na nuvem ficou com um `Config` antigo (6) e o ao vivo tem 8 ainda não salvo, ou o
contrário foi salvo depois. Se alguém publicar ou abrir a versão salva, o schema pode voltar para 6 (schema8 é para
preservar). **Não mexi no place.** Peço a quem tem a sessão de integração que confira o `Config` salvo antes de
qualquer publicação.

Na minha cópia local (v2) alinhei para 8: `Tests.Run` 413/413. A luz +20% da v1 **não** foi reaplicada, porque o place
já tem "20/10: levemente mais claro". Bateria +20% e postura do Tung Tung seguem só na cópia (ver registro).
