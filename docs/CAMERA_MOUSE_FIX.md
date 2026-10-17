# Câmera e mouse — 17/10/2026

Pedido: girar a câmera durante a partida sem segurar o botão direito do mouse.

`CameraController` agora restaura `MouseBehavior.LockCenter` depois da atualização dos menus,
inclusive quando algum fluxo deixou `Default` ativo. O cursor fica livre em cenas, captura,
espectador, lobby, derrota, menu do Roblox, caixas de texto e botões modais efetivamente visíveis.
Painéis ocultos não liberam o mouse. O controlador respeita perda de foco da janela e mantém
a câmera padrão do Roblox em primeira pessoa; não substitui o movimento nativo por uma câmera própria.

## Validação

- `lune run scripts/check`: ALL GREEN; 283 testes puros, zero falhas; 7 specs só de Studio puladas no Lune.
- Studio próprio: `TungTung_CAMERA_QA.rbxlx`, ID `45f51ad2-426f-4092-96d2-af3faaa9733c`.
- Fonte embutida conferida antes de Play. Build de QA idêntica à entrega por SHA-256.
- Suíte em uma execução isolada, iniciada em Play limpo: **295 passed, 0 failed, 0 skipped specs**.
  Uma primeira execução assíncrona se sobrepôs a outra suíte e falhou em `HouseNavigation/hide_Basement`;
  esse resultado foi descartado como execução contaminada. A execução final isolada passou.
- Voto no modo História pelo botão real do lobby: partida com `CameraType.Custom`,
  `LockCenter` e botão direito solto.
- Ajustes abertos com O: `Default`; botão FECHAR clicado: `LockCenter`.
- Guia aberto/fechado com H: `Default` → `LockCenter`.
- Cena Escape: `Default`; pular com Espaço: `Custom` + `LockCenter`.
- Soltura forçada de mouse durante a partida: recuperou `LockCenter` no quadro seguinte.
- Captura de tela confirmou o painel de ajustes aberto. Console sem erro do controlador;
  warnings de FoundationProvider/UIBlox são do CorePackages do Studio.
- Play encerrado; Studio devolvido a Edit. Nenhuma publicação ou push.

**Limite:** os comandos `moveTo` do MCP não produziram giro observável nem delta útil na câmera
travada. A recuperação do cursor e as transições foram verificadas; o giro com movimento físico
do mouse ainda requer conferência manual nesta build. Não foi declarado como teste aprovado.

## Entrega

`build/TungTungSahur.rbxlx` e `build/TungTung_HORROR_FINAL.rbxlx` atualizados.
SHA-256: `40659DD56F8080DFB580EDA4E988066FB22919D6DCED899A0194DE1B9CFE65E5`.
Auditoria: 225 fontes em disco e na build, zero diferenças ou scripts extras.
Relatórios da floresta continuam como evidência histórica de suas respectivas builds.
