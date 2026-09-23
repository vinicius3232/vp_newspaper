# 📰 vp_newspaper — Sistema de Jornalismo & Redação Weazel News (Hardened Production)

Recurso profissional, auditado e endurecido de mídia e jornalismo para FiveM, construído especificamente para **Heavy RP**, alta concorrência e integridade transacional absoluta.

## 🧱 1. Stack Oficial
* **Framework:** Qbox / QBCore (`exports['qbx_core']` e compatibilidade QBCore)
* **Inventário:** `ox_inventory` (manipulação atômica de slots, metadata de seriais únicos UUIDv4)
* **Interação:** `ox_target` (interações nos modelos de bancas, gráfica, redação e cofre)
* **Utilitários:** `ox_lib` (pontos, zonas, progress bars, callbacks, cache)
* **Banco de Dados:** `oxmysql` (MariaDB/MySQL com migrations idempotentes e constraints `CHECK`)
* **Execução:** Lua 5.4 nativo com isolamento rigoroso de escopo
* **OneSync:** OneSync Infinity (validação de distância vetorial euclidiana no servidor)
* **Frontend:** NUI (HTML5, Vanilla JS e jQuery UI nativo, sem ofuscação e com higienização XSS)

---

## 🏛️ 2. Arquitetura e Estrutura de Arquivos

```
vp_newspaper/
├── fxmanifest.lua           -- Manifest unificado com MLO, NUI e módulos de segurança
├── README.md                -- Documentação geral e guia rápido
├── shared/
│   └── config.lua           -- Coordenadas, bancas, preços limites e jobs
├── locales/
│   └── locales.lua          -- Localização completa em PT-BR (com fallback EN)
├── sql/
│   ├── schema.sql           -- Esquema legado unificado de referência
│   └── migrations/          -- Migrations versionadas idempotentes
│       ├── 001_initial_schema.sql
│       ├── 002_operations_and_ledger.sql
│       └── 003_editor_sessions.sql
├── server/
│   ├── database.lua         -- Executor idempotente de migrations no boot
│   ├── main.lua             -- Inicialização do recurso, logs e usables
│   ├── newspaper.lua        -- Editor com lock TTL, revisão otimista (OCC) e leitura
│   ├── company.lua          -- Cofre empresarial, atomic CAS withdrawal e ledgering
│   ├── boxes.lua            -- Stands com compra atômica CAS e reposição compensada
│   ├── printing.lua         -- Gráfica de impressão com rollback integral
│   └── modules/             -- Núcleo de segurança e transações
│       ├── security.lua     -- Rate limiter por camadas, distâncias físicas e validação
│       ├── operations.lua   -- Máquina de estados finita (FSM) durável e crash recovery
│       └── ledger.lua       -- Ledger financeiro contábil imutável
├── client/
│   ├── newspaper.lua        -- Leitor de jornal NUI, animações e virada de páginas
│   ├── editor.lua           -- Computador da redação, sessão de lock e heartbeats
│   ├── boxes.lua            -- Renderização de props das bancas e ox_target
│   └── main.lua             -- Zonas da redação, coleta de papel e garagem
├── web/                     -- Interface NUI
│   ├── index.html           -- Interface com carregamento limpo e seguro
│   ├── script.js            -- Vanilla JS nativo, higienização anti-XSS e drag-and-drop
│   ├── styles.css           -- Folhas de estilo da redação e leitor
│   ├── swap.ogg             -- Áudio de página de jornal
│   └── bg.png               -- Textura de papel vintage
├── tests/
│   └── test_harness.js      -- Suíte de testes automatizados com 20 cenários adversariais
├── docs/                    -- Documentação técnica de engenharia
│   ├── ARCHITECTURE.md      -- Diagramas de sequência e ciclo de vida
│   ├── SECURITY.md          -- Matriz de vetores de ataque e rate limits
│   ├── TRANSACTION_MODEL.md -- Modelo ACID, FSM e CAS
│   ├── QA_CHECKLIST.md      -- Checklist de homologação e roteiro in-game
│   └── RECOVERY.md          -- Manual de recuperação pós-crash e reconciliação
├── images/                  -- Ícones do inventário (newspaper, newspaperbox)
└── stream/                  -- MLO Weazel News completo
```

---

## 🛡️ 3. Principais Garantias de Engenharia

1. **Anti-Dupe & Integridade Financeira:**
   - Todo saque de cofre e venda em stand é executado via **Atomic Compare-And-Swap (CAS)** (`UPDATE ... WHERE balance >= amount`). Impossível gerar saldo negativo ou efetuar double spending.
   - Padrão **Fail-Closed**: insumos ou dinheiro são verificados/reservados antes da entrega de recompensas. Se `AddItem` falhar por inventário lotado, o sistema executa **Rollback Transacional Total**.
2. **Segurança Zero-Trust:**
   - **Tiered Rate Limiting**: Baldes deslizantes de requisições (`FAST`, `ECONOMIC`, `CRITICAL`).
   - **Validação de Distância Euclidiana 3D**: Todas as ações exigem proximidade estrita do ped do jogador com o ponto físico registrado (2.0m a 4.5m).
   - **Autoridade no Servidor**: Cargos e patentes (`job` e `jobBossGrade`) checados exclusivamente no servidor.
   - **Anti-XSS na NUI**: Sanitização estrita de strings via `escapeHtml()` e validação de URLs de imagens.
3. **Resiliência a Concorrência & Crashes:**
   - Concorrência de edição controlada por **Locks de Redação com TTL de 90s** e **Optimistic Concurrency Control (OCC)** por revisão de página.
   - **Crash Recovery no Boot (`RecoverOnBoot`)**: Reconciliação automática de operações que estavam em andamento se o servidor cair.

---

## 🧪 4. Suíte de Testes Automatizada

O resource inclui uma suíte de testes de estresse e adversariais em Node.js simulando concorrência real, ataques de injeção e falhas de inventário:

```bash
node tests/test_harness.js
```
*Resultado: **20/20 PASS** (Zero falhas).*

---

## 🚀 5. Instalação e Configuração

1. Adicione a pasta `vp_newspaper` em `resources/[standalone]/`.
2. Adicione ao seu `server.cfg`:
```cfg
ensure vp_newspaper
```
3. As tabelas do banco de dados são criadas e migradas automaticamente na inicialização via `sql/migrations/`.
4. Para consultar a documentação aprofundada de arquitetura e segurança, acesse a pasta [`docs/`](file:///docs/).
