# Arte das cartas (web/cards/)

Coloque aqui as imagens das cartas e preencha `image` em `Config.Collectibles.cards[<id>].image`
(ex.: `image = 'cards/mayor.png'`). Sem imagem, a carta usa o emoji `art` do catálogo.

## Especificação
- **Proporção:** 2.5 : 3.5 (proporção de carta de verdade), retrato.
- **Tamanho recomendado:** 600 × 840 px (ou 500 × 700). PNG (ou JPG).
- **Margem segura:** deixe ~8% de borda; a moldura/efeito de raridade é aplicada por CSS por cima.
- A arte aparece centralizada no topo da carta; o nome e a raridade entram embaixo (texto do jogo).

## Catálogo atual (7 cartas)
| id | raridade | tema | arquivo sugerido |
|---|---|---|---|
| card_reporter | comum     | repórter novato do jornal        | cards/reporter.png |
| card_editor   | comum     | editor-chefe na redação          | cards/editor.png |
| card_photog   | comum     | fotógrafo de imprensa            | cards/photog.png |
| card_star     | rara      | estrela/celebridade de Vinewood  | cards/star.png |
| card_heist    | rara      | o grande assalto (manchete)      | cards/heist.png |
| card_mayor    | lendária  | prefeito de Los Santos           | cards/mayor.png |
| card_edition0 | lendária  | edição histórica nº 0 do jornal  | cards/edition0.png |
