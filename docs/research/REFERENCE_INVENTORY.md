# 📚 Inventário Completo de Recursos de Referência & Target

Este documento consolida o mapeamento exaustivo de todos os arquivos de código, configuração, banco de dados, documentação e assets binários presentes no projeto alvo (`vp_newspaper`) e nos 5 resources de referência analisados no ambiente do servidor QBox.

Data da Auditoria: 25/09/2026  
Status: Inventário Integral Verificado  

---

## 1. Resumo Quantitativo Geral

| Resource / Diretório | Categoria / Tipo | Total Arquivos | Arquivos Código/Doc | Linhas de Código/Doc | Assets / Binários |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`vp_newspaper`** | **SCRIPT ALVO (Principal)** | **81** | **54** | **18.108** | **27** |
| `haze-newspaper` | Referência: Jornal, Cards & Entregas | 108 | 46 | 7.944 | 62 |
| `qbx_newsjob` | Referência: QBox Newsjob Oficial | 19 | 17 | 1.287 | 2 |
| `lation_ui` | Referência: UI / Component Library | 135 | 42 | 6.507 | 93 |
| `rp_boombox` | Referência: Áudio Espacial & Playlists | 71 | 13 | 5.493 | 58 |
| `qbx_vehicleradio` | Referência: Rádio Veicular Nativo | 2 | 2 | 40 | 0 |
| **TOTAL GERAL** | — | **416** | **174** | **39.379** | **242** |

---

## 2. Detalhamento por Resource

### 2.1 SCRIPT ALVO: `vp_newspaper`
- **Caminho:** `E:\Users\Vinicius\Downloads\txData\Qbox_753251.base\resources\[standalone]\vp_newspaper`
- **Módulos Centrais:**
  - **Core & Admin:** `client/main.lua`, `client/admin.lua`, `server/main.lua`, `server/admin.lua`, `server/company.lua`
  - **Jornal & Editor:** `client/newspaper.lua`, `client/editor.lua`, `server/newspaper.lua`, `server/printing.lua`
  - **Bancas & Distribuição:** `client/boxes.lua`, `server/boxes.lua`
  - **Posters 3D (DUI):** `client/posters.lua`, `server/posters.lua`, `web/poster_dui.html`
  - **Newsroom Display:** `client/newsroom_display.lua`, `web/newsroom_live.html`
  - **Media Kit (Câmera/Mic/Breaking News):** `client/media.lua`, `server/media.lua`
  - **Rádio 98.5 FM & Caixas 3D:** `client/radio.lua`, `server/radio.lua`, `client/speakers_attach.lua`, `server/speakers_attach.lua`, `client/broadcast_van.lua`, `server/broadcast_van.lua`, `web/radio_audio.js`, `web/radio_player.html`
  - **Segurança, Ledger & Operações:** `server/modules/security.lua`, `server/modules/ledger.lua`, `server/modules/operations.lua`, `server/modules/oxmysql_smoke.lua`
  - **Database & Migrações:** `server/database.lua`, `sql/migrations/*.sql`
  - **Interface Web (NUI):** `web/index.html`, `web/styles.css`, `web/script.js`
  - **Testes Automatizados:** `tests/test_harness.js` (1.536 linhas, 97 asserções)

---

### 2.2 REFERÊNCIA 1: `haze-newspaper`
- **Caminho:** `E:\Users\Vinicius\Downloads\txData\Qbox_753251.base\resources\[standalone]\haze-newspaper`
- **Módulos Centrais:**
  - **Trading Cards & Boosters:** `client/cards.lua`, `server/cards.lua`, `web/cards/` (cartas colecionáveis, raridades, efeito sparkles/shine, serialização única, PSA grading com subscores de 1-10).
  - **Mercado Dinâmico de Cartas:** `client/market.lua`, `server/market.lua` (curva de oferta e demanda SD, precificação NPC buy/sell).
  - **Revistas Colecionáveis (Comics):** `client/collectibles.lua`, `server/collectibles.lua`, `web/collectibles/` (revistas temáticas em PT e EN com folheamento de páginas).
  - **Entregas & Paperboy (Bike Throw):** `client/delivery.lua`, `server/delivery.lua`, `client/throw.lua`, `server/throw.lua` (rota de entregas, arremesso de jornal da bicicleta com verificação física e limites diários).
  - **Jornalismo de Campo (Field Journalism):** `client/field.lua`, `server/field.lua` (pontos de entrevista, gravação de matéria, geração de pautas `haze_leads` para consumo na redação).
  - **Cadeia de Produção Gráfica:** `client/print.lua`, `server/print.lua` (tiragem física em lotes com custo debitado e atribuição de edição aos jornais gerados).
  - **Notícias Automáticas:** `server/autonews.lua` (gerador automático de wire de notícias e despacho periódico).
  - **Auto-Schema & Migrações:** `server/_schema.lua`, `sql/haze_newspaper.sql`.
  - **NUI Vintage:** `web/index.html`, `web/style.css`, `web/app.js`.

---

### 2.3 REFERÊNCIA 2: `qbx_newsjob`
- **Caminho:** `E:\Users\Vinicius\Downloads\txData\Qbox_753251.base\resources\[qbx]\qbx_newsjob`
- **Módulos Centrais:**
  - **Sistema de Câmera de Reportagem:** `client/camera.lua` (renderização de viewfinder de broadcast, zoom progressivo, controle de eixos x/z do ped, ocultação seletiva de componentes da HUD do GTA, faixas letterbox de transmissão ao vivo).
  - **Equipamentos e Garagem:** `client/main.lua`, `server/main.lua` (adereços de microfone de mão e microfone boom, garagens terrestres e helipontos dedicados à imprensa).
  - **Localização:** 10 arquivos JSON (`locales/*.json`).

---

### 2.4 REFERÊNCIA 3: `lation_ui`
- **Caminho:** `E:\Users\Vinicius\Downloads\txData\Qbox_753251.base\resources\[standalone]\lation_ui`
- **Módulos Centrais:**
  - **Component Library (Exports):**
    - `client/components/drawer.lua` (gavetas laterais expansíveis com controles bloqueados)
    - `client/components/alert.lua` & `client/components/notify.lua` (modais de confirmação e alertas sonoros estilizados)
    - `client/components/menu.lua` & `client/components/listmenu.lua` (menus contextuais dinâmicos e scrollables)
    - `client/components/progressbar.lua` (barras de progresso imersivas com suporte a animação e props)
    - `client/components/radial.lua` (menu radial rápido com ícones FontAwesome)
    - `client/components/skillcheck.lua`, `patternlock.lua`, `signalbreach.lua` (minigames interativos)
    - `client/components/timeline.lua` (rastreador visual de etapas/missões)
  - **Sistema de Temas e Cores:** `client/utils/theme.lua`, `server/theme.lua` (sincronização de temas escuro/claro, acentuação e personalização persistente).

---

### 2.5 REFERÊNCIA 4: `rp_boombox`
- **Caminho:** `E:\Users\Vinicius\Downloads\txData\Qbox_753251.base\resources\[standalone]\rp_boombox`
- **Módulos Centrais:**
  - **Sessões de Áudio e Prop Físico:** `client.lua`, `server.lua` (instanciação e anexação do objeto boombox, cálculo de raio e atenuação espacial de áudio 3D).
  - **Gerenciador de Playlists:** `server.lua`, `html/main.js`, `install/rp_boombox.sql` (banco de dados para músicas salvas, favoritos por jogador e fila de reprodução).
  - **Interação ox_target:** Zonas dinâmicas anexadas ao prop de som com permissões de dono e controle de volume.

---

### 2.6 REFERÊNCIA 5: `qbx_vehicleradio`
- **Caminho:** `E:\Users\Vinicius\Downloads\txData\Qbox_753251.base\resources\[qbx]\qbx_smallresources\qbx_vehicleradio`
- **Módulos Centrais:**
  - **Controle de Rádio Veicular:** `client.lua`, `config.json` (monitoramento de entrada e saída de veículos via cache `lib.onCache('vehicle')`, chaveamento liga/desliga via comando nativo e desativação forçada de estações GTA para prevenir sobreposição de áudio).

---

## 3. Matriz de Integração e Compatibilidade

| Elemento | `vp_newspaper` Atual | Oportunidade Identificada nas Referências |
| :--- | :--- | :--- |
| **Colecionáveis** | Inexistente | Adicionar módulo de Revistas em Quadrinhos e Cartas Colecionáveis com Booster Packs e PSA Grading (do `haze-newspaper`). |
| **Entrega Paperboy** | Van terrestre tradicional | Adicionar rota estilo Paperboy de bicicleta com mecânica de arremesso (`client/throw.lua` do `haze-newspaper`). |
| **Jornalismo de Campo** | Equipamentos de pose (anim) | Adicionar spots de entrevistas e gravação que geram Pautas Reais (`haze_leads`) consumíveis no editor. |
| **Câmera ao Vivo** | Overlay simples de câmera | Integrar cinemática profissional de broadcast com rotação suave, zoom contínuo e ocultação total de HUD (`qbx_newsjob`). |
| **Interface NUI** | Dark slate / Glassmorphic | Expandir integração com componentes `lation_ui` (drawers, alertas nativos e timelines de entrega). |
| **Áudio Espacial** | Rádio 98.5 FM com xSound/WebAudio | Integrar recursos de playlist e favoritos de rádio inspirados no `rp_boombox`. |
