# 📰 vp_newspaper — Sistema Completo de Jornalismo, Rádio 98.5 FM & Som 3D Weazel News

Recurso profissional, auditado e endurecido de mídia, jornalismo impresso e transmissão sonora para FiveM (Qbox / QBCore), construído para **Heavy RP**, alta concorrência, integridade transacional absoluta e áudio 3D imersivo.

---

## 🧱 1. Stack Oficial & Tecnologias

* **Framework:** Qbox / QBCore (`exports['qbx_core']` com retrocompatibilidade QBCore).
* **Inventário:** `ox_inventory` (manipulação atômica de slots, metadados, seriais UUIDv4 e hooks de uso).
* **Interação Física:** `ox_target` (bancas, impressora gráfica, cofre, mesa de som, veículos e caixas de som no chão).
* **Utilitários:** `ox_lib` (pontos, zonas, progress bars, callbacks, menus contextuais e input dialogs).
* **Persistência Relacional:** `oxmysql` (MariaDB/MySQL com migrations idempotentes versionadas, constraints `CHECK` e ledger append-only).
* **Áudio & Rádio:** Web Audio API (filtro paramétrico Biquad de 5 bandas) + YouTube IFrame API (com suporte nativo a Playlists).
* **Sincronização 3D Multi-Player:** StateBags replicadas (`weazelVehicleSpeaker`, `weazelCarryingRadio`) e registro server-side (`ActiveGroundSpeakers`).
* **Runtime:** Lua 5.4 nativo com isolamento rigoroso de escopo.
* **Frontend:** NUI (HTML5, Vanilla JS, CSS3 vintage e jQuery UI, com higienização estrita anti-XSS).

---

## 🏛️ 2. Arquitetura e Estrutura de Arquivos

```
vp_newspaper/
├── fxmanifest.lua           -- Manifest unificado com MLO, NUI, scripts e assets de áudio
├── README.md                -- Documentação geral e guia mestre
├── shared/
│   └── config.lua           -- Configuração de redação, bancas, rádio, equalizador e som
├── locales/
│   └── locales.lua          -- Localização completa em PT-BR (com fallback EN)
├── sql/
│   ├── schema.sql           -- Esquema legado unificado de referência
│   └── migrations/          -- Migrations versionadas idempotentes
│       ├── 001_initial_schema.sql
│       ├── 002_operations_and_ledger.sql
│       ├── 003_editor_sessions.sql
│       ├── 004_posters.sql
│       └── 005_speakers_system.sql
├── server/
│   ├── database.lua         -- Executor idempotente de migrations no boot
│   ├── main.lua             -- Inicialização do recurso, logs e usables
│   ├── newspaper.lua        -- Editor com lock TTL, revisão otimista (OCC) e leitura
│   ├── company.lua          -- Cofre empresarial, atomic CAS withdrawal e ledgering
│   ├── boxes.lua            -- Stands com compra atômica CAS e reposição compensada
│   ├── printing.lua         -- Gráfica de impressão com rollback integral
│   ├── posters.lua          -- Cartazes de parede, moderação e persistência SQL
│   ├── media.lua            -- Kit de reportagem e emissão de Plantão Urgente
│   ├── radio.lua            -- Rádio Weazel 98.5 FM, fila de DJ, som veicular e caixas no chão
│   ├── speakers_attach.lua  -- Acoplamento autoritativo de som veicular (estilo Rahe)
│   ├── broadcast_van.lua    -- Unidade móvel com mastro e cálculo de sinal RF
│   ├── admin.lua            -- Observabilidade e ferramentas de diagnóstico para staff
│   └── modules/             -- Núcleo de segurança e transações
│       ├── security.lua     -- Rate limiter por camadas, distâncias físicas e validação
│       ├── operations.lua   -- Máquina de estados finita (FSM) durável e crash recovery
│       ├── ledger.lua       -- Ledger financeiro contábil imutável
│       └── oxmysql_smoke.lua-- Validação de integridade do pool MySQL
├── client/
│   ├── newspaper.lua        -- Leitor de jornal NUI, animações e virada de páginas
│   ├── editor.lua           -- Computador da redação, sessão de lock e heartbeats
│   ├── boxes.lua            -- Renderização de props das bancas e ox_target
│   ├── posters.lua          -- Sistema de cartazes 3D na parede com DUI e raycasting
│   ├── media.lua            -- Câmera de vídeo com visor HUD, microfone de mão e boom
│   ├── radio.lua            -- Rádio, fones, som 3D espacial e boombox carry
│   ├── speakers_attach.lua  -- Sistema de fixação de alto-falantes em veículos
│   ├── broadcast_van.lua    -- Controle do mastro de transmissão da van Weazel
│   ├── newsroom_display.lua -- Monitor 3D digital interativo na redação central (DUI)
│   ├── admin.lua            -- Painel in-game para testes e diagnósticos staff
│   └── main.lua             -- Zonas da redação, coleta de papel e garagem
├── web/                     -- Interface NUI & Motor de Áudio (Estilo Lation UI)
│   ├── index.html           -- Interface visual: Leitor com barra flutuante, Editor e Diretoria Lation
│   ├── script.js            -- Vanilla JS nativo, higienização anti-XSS e drag-and-drop
│   ├── radio_audio.js       -- Web Audio API, Biquad Filter EQ, Streamer Mode e YouTube Player
│   ├── poster_dui.html      -- Página web de renderização limpa para texturas de cartazes
│   ├── newsroom_live.html   -- Página web do monitor 3D da redação
│   ├── radio_player.html    -- Player auxiliar e isolado de áudio
│   ├── styles.css           -- Folhas de estilo modernas com glassmorphism Lation UI
│   ├── swap.ogg             -- Efeito sonoro físico de folhear página de jornal
│   └── bg.png               -- Textura de papel de jornal
├── tests/
│   ├── test_harness.js      -- Suíte canônica com 97 testes automatizados adversariais
│   └── mariadb_integration_gate.py -- Gate de validação real contra MariaDB
├── docs/                    -- Documentação técnica aprofundada
│   ├── ARCHITECTURE.md      -- Diagramas de sequência, FSM e ciclo de vida
│   ├── RADIO_AND_SPEAKERS.md-- Manual completo de rádio, som veicular, 3D e playlists
│   ├── SECURITY.md          -- Matriz de vetores de ataque, rate limits e anti-exploit
│   ├── TRANSACTION_MODEL.md -- Modelo ACID, FSM e CAS
│   ├── QA_CHECKLIST.md      -- Checklist completo de homologação e testes in-game
│   └── RECOVERY.md          -- Manual de recuperação pós-crash e reconciliação
├── images/                  -- Ícones do inventário (newspaper, newspaperbox, radio_portable, etc.)
└── stream/                  -- MLO Weazel News completo para FiveM
```

---

## 🌟 3. Principais Módulos do Sistema

### 3.1. Interface de Usuário Moderna (Padrão Lation UI)
* **Barra Flutuante de Leitura (Floating Reader Bar):** Ao ler jornais (`/lerjornal` ou usando o item), uma barra flutuante em formato de pílula translúcida com visual glassmorphism Lation permite navegação anterior/próxima, indicador de páginas `Página X de Y` e botão de fechar com feedback sonoro suave.
* **Painel da Diretoria & Gestão (Boss Dashboard):**
  * Sidebar com logo estilizado, badge de status `● 98.5 FM No Ar` e botões de navegação com marcador lateral animado.
  * Cards de métricas (KPIs) com ícones em destaque circular neon (Cofre Corporativo em Esmeralda, Tabela de Preços em Ciano).
  * Extrato de vendas do ledger contábil em formato de timeline moderna.
  * Painel de equipe com avatares e ações rápidas (promover, rebaixar, demitir).

### 3.2. Jornalismo & Redação Weazel News
* **Editor Gráfico NUI (WYSIWYG):** Diagramação de manchetes, matérias, colunas e imagens com drag-and-drop.
* **Concorrência Protegida:** Locks de estação de trabalho com TTL de 90 segundos e renovação automática via heartbeat, além de **Optimistic Concurrency Control (OCC)** por versão de página para evitar sobrescritas.
* **Ciclo Econômico Completo:**
  1. *Coleta:* Repórteres coletam folhas virgens (`empty_newspaper`).
  2. *Gráfica:* Impressão em lote converte 5 folhas em 1 caixa de jornais (`newspaperbox`).
  3. *Distribuição:* Abastecimento de stands/bancas espalhadas pelo mapa com pagamento de comissão.
  4. *Venda ao Público:* Cidadãos compram jornais individuais (`newspaper`) nas bancas via `ox_target`.
  5. *Cofre da Empresa:* Lucro das vendas creditado no cofre corporativo com histórico contábil.

### 3.2. Weazel Radio 98.5 FM & Transmissão Global
* **Mesa de Som / DJ (`/weazeldj`):** Painel para operadores da Weazel News adicionarem músicas, pularem faixas ou pausarem a programação.
* **Suporte Completo a Playlists do YouTube:**
  * Detecta links individuais de vídeos e **Playlists Completas** (`list=...`).
  * Avança automaticamente faixa a faixa pela playlist sem interrupções indesejadas.
  * Suporta fluxos de rádio web direta (Icecast/MP3/AAC).
* **Fones de Ouvido Privativos (`headphones`):** Escuta individual no ped, sem interferência de distância.
* **Sintonizador Veicular (`/weazelradio`):** Rádio integrada ao painel dos veículos.
* **Equalizador Paramétrico Biquad de 5 Bandas:**
  * Frequências: $80\text{Hz}$ (Lowshelf), $250\text{Hz}$ (Peaking), $1000\text{Hz}$ (Peaking), $4000\text{Hz}$ (Peaking) e $12000\text{Hz}$ (Highshelf).
  * Presets: `Broadcast FM`, `Bass Boost`, `Vocal & Notícias`, `Club & Balada`, `Outdoor / PA` e `Flat`.
* **Modo Streamer Anti-DMCA:** Comandos `/modostreamer` e `/safetypreference` com persistência local em KVP para silenciar músicas protegidas por direitos autorais em transmissões ao vivo.
* **Plantão Urgente (Breaking News):** Emite vinheta especial e atenua a rádio em 85% automaticamente, restaurando o volume após o término do alerta.

### 3.3. Sistema de Caixas de Som Físicas & Som Veicular (Rahe Speakers Engineering)
* **Item `radio_portable`:**
  * **No Chão:** Posiciona a caixa no chão com física estável (`prop_boombox_01`).
  * **No Braço / Ombro (Boombox Carry):** O ped carrega a caixa na mão/ombro com animação fluida (`anim@heists@box_carry@`). Teclas: `[E]` chão, `[G]` carro, `[X]` guardar.
  * **No Veículo:** Acopla o sistema de som diretamente no porta-malas (`trunk`), teto (`roof`) ou caçamba (`bed`) de veículos.
* **Áudio 3D Espacial Multi-Player:**
  * Todos os jogadores próximos ouvem as músicas com atenuação quadrática realista de distância.
  * Caixas no chão e jogadores carregando o som: alcance de até 25 metros.
  * Som instalado em veículos: alcance ampliado de até 30 metros para encontros de carros e eventos.
* **Recolhimento:** A caixa de som no chão pode ser recolhida via `ox_target` ("Recolher Caixa de Som") ou pelo comando `/pegarcaixa` (ou `/recolhersom`).

---

## 🎮 4. Comandos e Interações

| Comando / Ação | Descrição | Permissão |
| :--- | :--- | :--- |
| `/redacao` ou `/editorjornal` | **Abre o Editor Visual WYSIWYG** (NUI em tela cheia para criar e diagramar as páginas do jornal) | Repórteres / Dev (`Config.General.debugs`) |
| `/gestaojornal` ou `/weazelboss` | **Abre o Painel de Gestão da Empresa** (Saldo do cofre, histórico, contratações e preço) | Diretor (Grau 4) / Dev |
| `/lerjornal` | **Abre a NUI de leitura** da edição atual com prop físico na mão e som de folhear | Todos os jogadores (Sem Job) |
| `/imprimirjornal` | **Opera a prensa gráfica** e gera caixas de jornais impressos | Repórteres / Dev |
| `/pegapapel` | Coleta 10x folhas de papel virgem (`empty_newspaper`) para a prensa | Repórteres / Dev |
| `/weazeltest` | **Painel Interativo de Testes Staff** (Menu NProbleM, Kits, Teleportes, Rádio, Job Manager, Diagnóstico) | Staff / Dev (`Config.General.debugs`) |
| `/weazelkit` | **Gera instantaneamente** todos os itens no inventário (`radio_portable`, `headphones`, `newspaper`, etc.) | Staff / Dev (`Config.General.debugs`) |
| `/setweazel [grau]` | **Seta seu cargo imediatamente** para Weazel News (Padrão: Grau 4 / Diretor Geral) | Staff / Dev (`Config.General.debugs`) |
| `/tirarweazel` | Remove o emprego da Weazel News e retorna a desempregado | Staff / Dev (`Config.General.debugs`) |
| `/limparweazel` | Limpa todos os itens de teste da Weazel News do inventário | Staff / Dev (`Config.General.debugs`) |
| `/weazelradio` | Abre o menu sintonizador (rádio do carro, fones, equalizador e modo streamer) | Todos os jogadores (Sem Job) |
| `/weazeldj` | Abre a mesa de som / console de DJ para gerenciar a programação da rádio | Membros da Weazel News / Admin |
| `/pegarcaixa` ou `/recolhersom` | Recolhe a caixa de som portátil mais próxima do chão de volta ao inventário | Qualquer jogador próximo |
| `/cam`, `/mic`, `/bmic` | Empunha ou guarda câmera de filmagem, microfone de mão ou boom | Repórteres / Staff |
| `/plantao [texto]` | Dispara alerta de Plantão Urgente (Breaking News) no servidor com vinheta | Repórteres / Staff |
| `/modostreamer` | Alterna instantaneamente o Modo Streamer Anti-DMCA (silencia músicas comerciais) | Todos os jogadores |
| `/safetypreference` | Abre as preferências de segurança de áudio e proteção de direitos autorais | Todos os jogadores |
| `Item: radio_portable` | Abre o menu da caixa de som 3D (Colocar no Chão, Carregar no Ombro, Instalar no Carro) | Qualquer jogador com o item |
| `Item: headphones` | Coloca ou remove os fones de ouvido para sintonizar privativamente a 98.5 FM | Qualquer jogador com o item |
| `ox_target` no veículo | Opção "Sistema de Som Veicular" para instalar/gerenciar som no porta-malas, teto ou caçamba | Qualquer jogador próximo |
| `ox_target` na caixa de chão | Opção "Recolher Caixa de Som" para recolher o equipamento do chão | Qualquer jogador próximo |

### 📰 Fluxo Completo de Publicação & Economia Circular (Estilo NProbleM):
1. **Passo 1 (Redação / Diagramação):**
   * O jornalista usa o computador da redação ou digita `/redacao`.
   * Abre o **Editor WYSIWYG** (NUI estilo folha de jornal vintage com papel envelhecido).
   * Adiciona títulos, parágrafos, colunas, imagens por URL, formata tipografia e fontes clássicas.
   * Diagrama até 5 páginas e clica em **"Salvar" (`Save`)**.
2. **Passo 2 (Produção Gráfica / Impressão):**
   * Pega papel virgem (`empty_newspaper`) na estante ou via `/pegapapel`.
   * Vai até a Prensa Gráfica da redação ou usa `/imprimirjornal`.
   * A prensa executa a animação de prensagem industrial por 5s e gera a **Caixa de Jornais** (`newspaperbox`).
3. **Passo 3 (Distribuição / Abastecimento):**
   * O distribuidor retira uma Van na garagem da redação e coloca as caixas de jornais.
   * Vai até as bancas de jornal nas ruas (`newspaper_boxes`) e usa o `ox_target` para abastecer.
   * O estoque da banca sobe para a capacidade máxima (ex: 20 exemplares) e o entregador ganha comissão em dinheiro.
4. **Passo 4 (Consumo / Leitura Popular):**
   * Cidadãos vão a qualquer banca e compram o jornal com dinheiro ou banco.
   * O dinheiro vai para o cofre da Weazel News e o cidadão recebe o item `newspaper`.
   * Ao usar o item (ou `/lerjornal`), o personagem segura o jornal físico aberto nas mãos com animação e lê as matérias na NUI com som de folhear folhas (`swap.ogg`).
5. **Passo 5 (Gestão Corporativa / Diretoria):**
   * O Diretor Geral acessa o painel via `/gestaojornal` ou no balcão.
   * Consulta o saldo corporativo, realiza saques de lucros ou depósitos, altera o preço das bancas e gerencia a contratação/demissão de funcionários.

---

### 3.3. Sistema Completo de Caixas de Som RAHE (Speakers System)
* **4 Tiers de Caixas de Som com Potências Distintas:**
  * `retro` (Boombox Retrô 1986): 30m de alcance, 85% de volume, transporte no ombro (\$250).
  * `vibe` (CyberBoombox RGB): 40m de alcance, 100% de volume, transporte no ombro (\$750).
  * `beat` (Torre SoundBeat Pro): 60m de alcance, 130% de volume, transporte com duas mãos (\$1.800).
  * `blast` (Estádio Blast PA System): 90m de alcance, 180% de volume, transporte com duas mãos (\$4.500).
* **Loja de Caixas de Som (`/lojasom`):** NPC vendedor na Praça Central com catálogo interativo e compra segura com fail-closed.
* **Pré-Visualização 3D (Gizmo de Posicionamento):** Modo fantasma ao colocar no chão com rotação `[Q]`/`[E]`, confirmação `[ENTER]` e cancelamento `[X]`.
* **Fila de Reprodução (Queue):** Gerenciador de faixas individuais ou em grupo com avanço automático ao fim do vídeo.
* **Histórico de Reprodução:** Registro no banco oxmysql e repetição de músicas em 1 clique.
* **Segurança e PIN Code:** Modos Público, Apenas Dono ou Senha de 4 dígitos.
* **Grupos de Caixas de Som (`/caixasomgrupo`):** Múltiplas caixas conectadas via `Connect Code` tocando a mesma música em sincronia absoluta no mapa.
* **Oclusão Acústica Veicular:** Atenuação automática de 65% e equalização abafada dentro de veículos fechados.
* **Painel de Administração Master (`/speakersadmin`):** Teleport até caixas ativas, exclusão remota e o comando de emergência `/killallspeakers`.

---

## 🎮 4. Guia Rápido de Uso & Comandos

### Comandos de Som & Caixas (RAHE):
* `/caixasom` — Abre o menu da caixa de som que você está segurando ou controlando.
* `/lojasom` — Abre a loja de compra de caixas de som e equipamentos.
* `/caixasomgrupo` — Abre o painel de criação e controle de Grupos de Som sincronizados.
* `/pegarcaixa` ou `/recolhersom` — Recolhe a caixa de som próxima para a mochila.
* `/streamermode` ou `/modostreamer` — Alterna a proteção contra DMCA para transmissões ao vivo.
* `/speakersadmin` — Painel de controle de administrador para listar e gerenciar caixas ativas.
* `/killallspeakers` — Comando emergencial de administrador para silenciar todos os sons da cidade.

### Comandos de Redação & Jornalismo:
* `/lerjornal` — Abre o leitor de jornal impresso nas mãos do jogador.
* `/redacao` — Acessa a redação e os computadores de diagramação.
* `/weazeldj` — Acesso à mesa de som da rádio Weazel News 98.5 FM.
* `/weazelradio` — Abre o rádio do veículo ou fones de ouvido.
* `/gestaojornal` — Painel administrativo e financeiro da diretoria da Weazel News.

---

## 🛡️ 5. Garantias de Segurança & Integridade Transacional

1. **Anti-Dupe & Integridade Financeira:**
   * Saques e compras executados via **Atomic Compare-And-Swap (CAS)** (`UPDATE ... WHERE balance >= amount`). Impossível gerar saldo negativo ou efetuar double spending.
   * Padrão **Fail-Closed**: insumos ou dinheiro são verificados/reservados antes da entrega de recompensas. Se `AddItem` falhar por inventário lotado, o sistema executa **Rollback Transacional Total**.
2. **Segurança Zero-Trust:**
   * **Tiered Rate Limiting**: Baldes deslizantes de requisições (`FAST`, `ECONOMIC`, `CRITICAL`).
   * **Validação de Distância Euclidiana 3D**: Todas as ações exigem proximidade estrita do ped com o ponto físico registrado (2.0m a 4.5m).
   * **Autoridade no Servidor**: Cargos, patentes e manipulações de entidades validadas exclusivamente no servidor.
   * **Anti-XSS na NUI**: Sanitização estrita de strings via `escapeHtml()` e validação de URLs.
3. **Resiliência a Concorrência & Crashes:**
   * Concorrência de edição controlada por **Locks de Redação com TTL de 90s** e **Optimistic Concurrency Control (OCC)** por revisão de página.
   * **Crash Recovery no Boot (`RecoverOnBoot`)**: Reconciliação automática de operações pendentes na inicialização do servidor.
4. **Adaptive Ticking (Performance Otimizada):**
   * Resmon ocioso de **`0.00 ms`** tanto no cliente quanto no servidor. O thread de áudio 3D só acelera quando fontes sonoras estão ativas na vizinhança imediata do jogador.

---

## 🧪 6. Suíte de Testes Automatizada & Quality Gates

O resource conta com uma suíte de testes de estresse em Node.js com SQLite relacional e um gate de integração real contra MariaDB 12:

```bash
# 1. Executar verificação sintática Lua 5.4 em todos os arquivos:
Get-ChildItem -Recurse -Filter *.lua | ForEach-Object { luac.exe -p $_.FullName }

# 2. Executar suíte canônica de testes automatizados (97 testes adversariais):
node tests/test_harness.js

# 3. Executar gate de integração real com MariaDB:
python tests/mariadb_integration_gate.py
```

*Resultado dos testes:*
- **100%** de conformidade sintática Lua 5.4 (`luac.exe -p` exit code 0).
- **97/97 testes PASS** no harness automatizado (zero falhas, zero regressões).
- **10/10 testes PASS** no gate MariaDB.

---

## 🚀 7. Instalação e Configuração

1. Coloque a pasta `vp_newspaper` em `resources/[standalone]/`.
2. Adicione ao seu `server.cfg`:
```cfg
ensure vp_newspaper
```
3. Registre os itens no seu `ox_inventory/data/items.lua`:
```lua
['newspaper'] = {
    label = 'Jornal Weazel News',
    weight = 100,
    stack = true,
    close = true,
    description = 'Edição impressa do jornal de Los Santos.'
},
['newspaperbox'] = {
    label = 'Caixa de Jornais',
    weight = 1000,
    stack = false,
    close = true,
    description = 'Lote de jornais impressos para reposição de bancas.'
},
['empty_newspaper'] = {
    label = 'Papel de Jornal',
    weight = 50,
    stack = true,
    close = true,
    description = 'Folhas de papel em branco para impressão gráfica.'
},
['radio_portable'] = {
    label = 'Caixa de Som Retrô',
    weight = 2500,
    stack = false,
    close = true,
    description = 'Caixa de som com áudio espacial 3D para chão, ombro ou veículo.'
},
['speaker_retro'] = {
    label = 'Boombox Retrô 1986',
    weight = 2500,
    stack = false,
    close = true,
    description = 'Boombox clássica dos anos 80 com áudio 3D (30m de alcance).'
},
['speaker_vibe'] = {
    label = 'CyberBoombox RGB',
    weight = 3000,
    stack = false,
    close = true,
    description = 'Caixa portátil com iluminação e alta definição (40m de alcance).'
},
['speaker_beat'] = {
    label = 'Torre SoundBeat Pro',
    weight = 6000,
    stack = false,
    close = true,
    description = 'Torre de som potente para festas e eventos médios (60m de alcance).'
},
['speaker_blast'] = {
    label = 'Estádio Blast PA System',
    weight = 12000,
    stack = false,
    close = true,
    description = 'Sistema de som de alta potência para multidões e arenas (90m de alcance).'
},
['headphones'] = {
    label = 'Fones de Ouvido Weazel',
    weight = 300,
    stack = false,
    close = true,
    description = 'Fones de alta fidelidade para ouvir a Weazel Radio 98.5 FM.'
}
```
4. As tabelas do banco de dados são migradas e estruturadas automaticamente na inicialização via `sql/migrations/` (incluindo `005_speakers_system.sql`).
5. Consulte a documentação complementar detalhada na pasta [`docs/`](file:///docs/), especialmente [`docs/RADIO_AND_SPEAKERS.md`](file:///docs/RADIO_AND_SPEAKERS.md).

---

## 📱 8. Integração com o Ecossistema (`vp_tablet`)

* **App Weazel News no Tablet:**
  * Registrado nativamente no Launcher e App Store do `vp_tablet` (`weazel_news`).
  * Cidadãos podem abrir o leitor de jornal digital diretamente pela tela do tablet com interface glassmorphism, virada de páginas e áudio imersivo de folheamento de papel.
  * Dispensa carregar o prop físico de jornal para consultas rápidas de notícias, classificados e comunicados governamentais.
* **Empresa Homologada no Tablet:**
  * Registrada em `Config.Services.Companies` do `vp_tablet` com o job `reporter`.
  * Repórteres e editores podem gerenciar canais de denúncia da população, notas de imprensa e chamados de pauta diretamente pelo tablet corporativo.


