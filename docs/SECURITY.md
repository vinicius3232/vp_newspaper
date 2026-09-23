# Matriz de Segurança e Anti-Exploit — `vp_newspaper`

## 1. Visão Geral
O resource `vp_newspaper` implementa uma política de segurança militar ("Zero-Trust Client"), assumindo que qualquer evento vindo da camada client-side pode ser forjado, duplicado ou modificado por executores de script maliciosos (LUA injectors).

---

## 2. Matriz de Vetores de Ataque FiveM vs. Mitigação

| Vetor de Ataque / Exploit | Gravidade | Superfície Anterior (Vulnerável) | Mitigação Implementada (`vp_newspaper`) |
| :--- | :---: | :--- | :--- |
| **Server Event Trigger Spam** | CRÍTICA | Triggers podiam ser chamados em loop sem limitação de frequência. | **Tiered Rate Limiter** no servidor com janelas deslizantes (`FAST`, `ECONOMIC`, `CRITICAL`). Excesso gera rejeição imediata e log de alerta. |
| **Teleport / Remote Interaction Exploit** | ALTA | Jogador podia disparar compra, impressão ou coleta de qualquer lugar do mapa. | **Verificação de Distância Euclidiana 3D no Servidor** (`GetEntityCoords(GetPlayerPed(source))`). Distâncias estritas de 2.0m a 4.5m fail-closed. |
| **Double Spending / Vault Duplication** | CRÍTICA | Saque do cofre lia saldo e gravava posteriormente sem bloqueio, permitindo corrida (race condition). | **Atomic Compare-And-Swap (CAS)**: `UPDATE vp_newspaper_company SET balance = balance - ? WHERE id = 1 AND balance >= ?`. Se 0 rows, rejeita sem deduzir. |
| **Inventory Desync / Item Dupe** | CRÍTICA | Dinheiro era cobrado antes ou item entregue sem verificar se inventário suportava o peso. | **Ordem Transacional Estrita com Rollback**: Reserva de estoque -> Cobrança -> Entrega do item -> Se `AddItem` falhar, reembolso integral de dinheiro e estoque. |
| **XSS via Newspaper NUI (HTML Injection)** | ALTA | Repórter podia injetar `<script>`, `<iframe>` ou eventos `onload` no corpo do jornal, afetando todos os leitores. | **Sanitização de HTML na NUI**: Todas as strings passam por `escapeHtml()` com whitelist de entidades e bloqueio de schemas inseguros (`javascript:`, `data:`). |
| **Negative Number / NaN Money Glitch** | CRÍTICA | Envio de saques com valores negativos ou decimais malformados para inflar saldo da empresa ou do player. | **Validação e Normalização Numérica**: `math.floor`, checagem de tipo `type(val) == "number"` e rejeição de qualquer valor `<= 0` ou não finito. |
| **Job Spoofing / Impersonation** | ALTA | Client avisava ao servidor que tinha o job de repórter ou cargo de chefe. | **Autoridade Estrita no Servidor**: Verificação do cargo e grade diretamente via `Player.PlayerData.job.name` e `Player.PlayerData.job.grade.level` no momento exato do processamento. |
| **Serial Number Duplication / Spoofing** | MÉDIA | Jornais eram gerados sem identidade ou com números sequenciais previsíveis. | **Non-Authoritative Tracking Identifier (UUIDv4)**: Cada exemplar impresso possui serial único para rastreabilidade forense e anti-dupe (`vp_newspaper_copies`). O serial **não é segredo nem atua como autorização/credencial**; o servidor valida estritamente `source`, `citizenid` e estado. |

---

## 3. Especificação dos Rate Limits do Servidor

O módulo `server/modules/security.lua` gerencia baldes de tokens deslizantes por jogador (`source`):

| Categoria | Janela de Tempo | Limite Máximo | Ações Alvo |
| :--- | :---: | :---: | :--- |
| **FAST** | 10 segundos | 20 requisições | Navegação em páginas de jornal, leitura, heartbeats de editor. |
| **ECONOMIC** | 10 segundos | 5 requisições | Compra de jornais em bancas físicas, reabastecimento de stands. |
| **CRITICAL** | 10 segundos | 2 requisições | Saques de cofre empresarial, impressão em lote, salvamento de edições completas. |

---

## 4. Matriz de Distâncias Físicas Autorizadas

Qualquer tentativa de acionamento fora das coordenadas registradas no `Config` resulta em cancelamento silencioso com log de segurança:

| Ponto de Interação | Distância Máxima Permitida | Ponto de Referência |
| :--- | :---: | :--- |
| **Banca de Jornal (Stand)** | **2.5 metros** | Coordenadas da banca cadastrada no banco de dados (`vp_newspaper_boxes`). |
| **Mesa de Impressão (Printing)** | **2.5 metros** | `Config.Printing.location` |
| **Coleta de Papel (Paper Supply)** | **2.5 metros** | `Config.Paper.location` |
| **Estação de Redação (Editor)** | **2.0 metros** | `Config.Editor.location` |
| **Cofre e Gestão (Company Vault)** | **2.0 metros** | `Config.Company.location` |
| **Garagem de Veículos (Spawn/Store)** | **3.5m / 4.5m** | `Config.Garage.location` / `Config.Garage.spawnLocation` |

---

## 5. Integridade de Dados no Banco (MariaDB)

1. **Prepared Statements Obrigatórios**: 100% das queries utilizam parâmetros vinculados (`oxmysql:execute(query, params)`), tornando injeções de SQL impossíveis.
2. **Restrições de Check Positivo (`CHECK`)**:
   - `vp_newspaper_company`: `CHECK (balance >= 0)`
   - `vp_newspaper_boxes`: `CHECK (stock >= 0 AND stock <= max_stock)`
3. **Ledger Imutável**:
   - Toda transação financeira gera um registro na tabela `vp_newspaper_ledger`, contendo `timestamp`, `cid`, `operation_type`, `delta_balance`, `previous_balance` e `new_balance`.
