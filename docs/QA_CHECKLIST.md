# Checklist de Garantia de Qualidade (QA) — `vp_newspaper`

Este documento contém o status das verificações automatizadas e as instruções detalhadas para o operador humano realizar a validação física in-game no servidor FiveM.

---

## 1. Resumo dos Portões de Qualidade

* **Validação de Sintaxe Lua 5.4 (`luac.exe -p`):** `[PASS]` (16/16 arquivos validados com código de saída 0).
* **Testes Adversariais Automatizados (`tests/test_harness.js`):** `[PASS]` (20/20 cenários aprovados).
* **Varredura Anti-XSS e Higienização de NUI:** `[PASS]` (Zero ofuscação, `escapeHtml` e isolamento estrito).
* **Integridade Estrutural SQL (Migrations & Constraints):** `[PASS]` (Tabelas idempotentes com `CHECK` constraints).
* **Validação Física In-Game (FiveM Runtime):** `[PENDING_OPERATOR]` (Requer execução manual no cliente FiveM).

---

## 2. Matriz Detalhada de Testes

| ID | Cenário / Funcionalidade | Tipo de Teste | Status | Notas de Verificação |
| :---: | :--- | :---: | :---: | :--- |
| **QA-01** | Compra de jornal com estoque e saldo | Unitário / Harness | `[PASS]` | Deduz $5, decrementa estoque, entrega item com serial único. |
| **QA-02** | Bloqueio de compra com estoque zero | Unitário / Harness | `[PASS]` | Rejeita imediatamente, não cobra dinheiro. |
| **QA-03** | Rollback de estoque quando saldo insuficiente | Unitário / Harness | `[PASS]` | Estoque reservado é retornado se a cobrança falhar. |
| **QA-04** | Corrida de último estoque (Concorrência A vs B) | Adversarial | `[PASS]` | Apenas 1 comprador obtém o item; saldo do segundo intocado. |
| **QA-05** | Reembolso integral se inventário estiver cheio | Transacional | `[PASS]` | Dinheiro estornado e estoque devolvido com log compensatório. |
| **QA-06** | Reabastecimento por repórter autorizado | Regra de Negócio | `[PASS]` | Consome 1 caixa, adiciona 10 jornais, paga $50 de comissão. |
| **QA-07** | Reabastecimento negado para não-repórter | Segurança | `[PASS]` | Bloqueio fail-closed por verificação de cargo no servidor. |
| **QA-08** | Bloqueio de reabastecimento em stand já lotado | Regra de Negócio | `[PASS]` | Impede que a caixa seja consumida à toa. |
| **QA-09** | Impressão de jornais na gráfica (5 papéis -> 1 caixa) | Crafting | `[PASS]` | Dedução atômica de insumos e entrega da caixa. |
| **QA-10** | Falha de impressão por insumos insuficientes | Fail-Closed | `[PASS]` | Rejeição sem alteração de inventário. |
| **QA-11** | Devolução de papéis se inventário encher na impressão | Anti-Dupe | `[PASS]` | Insumos devolvidos caso `AddItem` retorne falso. |
| **QA-12** | Saque de cofre por Boss da empresa | Econômico | `[PASS]` | Permissão validada via `jobBossGrade`, saldo atualizado. |
| **QA-13** | Saque de cofre bloqueado para funcionários juniores | Autorização | `[PASS]` | Rejeição estrita baseada no grade do jogador. |
| **QA-14** | Saque duplo concorrente excedendo saldo | Concorrência | `[PASS]` | Atomic CAS impede saldo negativo mesmo com 2 saques simultâneos. |
| **QA-15** | Bloqueio de segundo repórter na estação de edição | Lock com TTL | `[PASS]` | Lock exclusivo de 90s concedido apenas ao primeiro repórter. |
| **QA-16** | Rejeição de salvamento com revisão desatualizada (OCC) | Concorrência | `[PASS]` | Versão conflitante é recusada para evitar sobrescrita de matérias. |
| **QA-17** | Bloqueio de ação remota (Distância > 2.5m) | Anti-Cheat | `[PASS]` | Rejeição estrita com validação euclidiana 3D no servidor. |
| **QA-18** | Rejeição de valores negativos ou NaN em saques | Sanitização | `[PASS]` | Tipagem e bounds checking antes de tocar no banco. |
| **QA-19** | Proteção contra spam de triggers (Rate Limit) | DoS / Anti-Spam | `[PASS]` | Janela deslizante bloqueia requisições excessivas. |
| **QA-20** | Renderização física do prop da banca e ox_target | In-Game / Visual | `[PENDING_OPERATOR]` | Ver Roteiro 1 abaixo. |
| **QA-21** | Animação e progresso na coleta de papel | In-Game / Física | `[PENDING_OPERATOR]` | Ver Roteiro 2 abaixo. |
| **QA-22** | Abertura do NUI do Editor e Leitor de Jornal | In-Game / UI | `[PENDING_OPERATOR]` | Ver Roteiro 3 abaixo. |
| **QA-23** | Spawning e armazenamento do veículo da empresa | In-Game / Garagem | `[PENDING_OPERATOR]` | Ver Roteiro 4 abaixo. |

---

## 3. Roteiro Passo a Passo para o Operador Humano (In-Game FiveM)

### Roteiro 1: Validação dos Stands Físicos (Bancas de Jornal)
1. Conecte no servidor com um personagem comum (sem cargo de repórter).
2. Vá até a localização de um dos stands cadastrados (ex: Legion Square ou próximo ao Daily Globe).
3. Mire no modelo físico da banca com o `ox_target` (Alt / Botão direito).
4. Verifique as opções exibidas:
   - "Comprar Jornal ($5)" deve estar visível para todos os jogadores.
   - "Reabastecer Banca" deve estar **oculto** para quem não for repórter.
5. Clique em "Comprar Jornal":
   - Verifique se a animação do personagem ocorre.
   - Verifique a dedução de $5 da carteira.
   - Abra o inventário (`ox_inventory`) e confirme o item `newspaper` com número de série e edição legíveis no tooltip.
6. Use o jornal no inventário: a interface NUI deve abrir mostrando a capa e as páginas diagramadas. Pressione `ESC` ou clique em Fechar.

### Roteiro 2: Coleta de Papel e Impressão Gráfica
1. Set seu emprego para repórter: `/setjob [seu_id] reporter 1`.
2. Vá até as coordenadas de coleta de papel (`Config.Paper.location`):
   - Aproxime-se do ponto e utilize o `ox_target` para "Pegar Folhas de Papel".
   - Confirme a barra de progresso (ox_lib progressBar) e o recebimento de itens `empty_newspaper`.
3. Vá até a impressora gráfica (`Config.Printing.location`):
   - Interaja via `ox_target` em "Imprimir Jornais".
   - Verifique se 5 folhas são consumidas e 1 item `newspaperbox` é adicionado ao seu inventário.

### Roteiro 3: Edição de Notícias (Redação)
1. Vá até a estação de edição (`Config.Editor.location`).
2. Interaja no computador de redação:
   - A interface NUI do Editor deve carregar sem erros no console F8.
   - Digite um título e corpo de texto.
   - Clique em "Salvar Página".
   - Verifique se a notificação de confirmação aparece e o lock é liberado.
3. Chame outro jogador para tentar abrir o editor enquanto você estiver com ele aberto: ele deve receber a notificação de que o terminal está ocupado.

### Roteiro 4: Garagem e Veículo da Empresa
1. Vá até o ponto de garagem (`Config.Garage.location`).
2. Interaja para retirar o veículo de entrega (ex: Rumpo Daily Globe).
3. Verifique se o veículo aparece nas coordenadas configuradas com placa definida.
4. Guarde o veículo no ponto correspondente e certifique-se de que a entidade do veículo é deletada sem erros no console do servidor.

### Roteiro 5: Gestão Financeira (Cofre da Empresa)
1. Com o cargo de chefe (`grade: 4`), aproxime-se do cofre (`Config.Company.location`).
2. Abra o menu de gerenciamento e consulte o saldo da empresa.
3. Efetue um saque de teste (ex: $100).
4. Verifique se o dinheiro é creditado ao personagem e o saldo da empresa é deduzido.
5. Verifique no banco de dados se a tabela `vp_newspaper_ledger` registrou a transação com seu `citizenid` e valores exatos.
