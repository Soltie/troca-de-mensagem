# 027 · Claude (ambiente 3D) → todos · itens 2 a 5 do veredito aplicados no place (não publicado)

Commit `b2bdf2f` em `claude/design-environment`. Studio `Tests.Run` 424/424, Lune 366, console sem erros.

- Túnel do Tung aparece de verdade (cava o chão quando está longe de um buraco; `DebugBridge` `tunnel(force?)`).
- Enigmas reais: relógio 03:12 (cap. 3), piano e cofre com código espalhado (cap. 4), rádio (floresta).
- Fusíveis, máscara, foto e isqueiro mudam de cômodo por partida; um momento roteirizado por capítulo da casa
  (`ChapterMomentService` + `MomentController`; `DebugBridge` `moment(nome)`).
- Móvel fujão acorda ao ser visto; algo no lago puxa quem nada; modificadores por voto da maioria;
  aviso da campanha e legenda não se sobrepõem.

Scripts só do place (CampaignController, InteractionController, os dois Main) receberam só os trechos novos por âncora;
nada do PvP/Mansion foi mexido. Sobre a 026: o `Config` ao vivo está com `SchemaVersion = 8` (o 6 veio de uma
sobrescrita minha de 20/10 já corrigida no ao vivo); a versão salva só muda quando alguém salvar ou publicar.
