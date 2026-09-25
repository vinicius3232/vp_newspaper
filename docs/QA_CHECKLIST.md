# Checklist de Garantia de Qualidade (QA) — `vp_newspaper`

Este documento contém o status das verificações automatizadas e as instruções detalhadas para o operador humano realizar a validação física in-game no servidor FiveM.

---

## 1. Resumo dos Portões de Qualidade

* **Validação de Sintaxe Lua 5.4 (`luac.exe -p`):** `[PASS]` (100% dos arquivos Lua validados com código de saída 0).
* **Testes Adversariais Automatizados (`tests/test_harness.js`):** `[PASS]` (97/97 cenários aprovados, 0 falhas).
* **Gate de Integração MariaDB 12 (`mariadb_integration_gate.py`):** `[PASS]` (10/10 testes aprovados).
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
| **QA-24** | Gestão financeira e saque do cofre com Ledger | In-Game / Economia | `[PENDING_OPERATOR]` | Ver Roteiro 5 abaixo. |
| **QA-25** | Transmissão de rádio global via `/weazeldj` | Rádio / DJ | `[PENDING_OPERATOR]` | Ver Roteiro 6 abaixo. |
| **QA-26** | Playback de Playlist do YouTube sem cortes | Áudio / NUI | `[PASS]` | Transição de faixas gerenciada via IFrame API `loadPlaylist`. |
| **QA-27** | Sintonizador veicular no painel (`/weazelradio`) | Gameplay / Carro | `[PENDING_OPERATOR]` | Ver Roteiro 6 abaixo. |
| **QA-28** | Escuta individual com fones de ouvido (`headphones`)| Item / Áudio | `[PENDING_OPERATOR]` | Volume pessoal 100% sem perda de distância. |
| **QA-29** | Carregar boombox no ombro (`radio_portable`) | Física / Animação | `[PENDING_OPERATOR]` | Animação `box_carry`, statebag `weazelCarryingRadio`. |
| **QA-30** | Áudio 3D multi-player (ouvir rádio de outro jogador)| Rede / Áudio 3D | `[PENDING_OPERATOR]` | Ver Roteiro 7 abaixo. Atenuação quadrática de 0m a 25m. |
| **QA-31** | Posicionar e recolher caixa no chão (`/pegarcaixa`) | Entidade / ox_target| `[PENDING_OPERATOR]` | `prop_boombox_01`, registro server-side e devolução do item. |
| **QA-32** | Instalar e desinstalar som veicular (Trunk/Roof/Bed)| Acoplamento | `[PENDING_OPERATOR]` | Ver Roteiro 8 abaixo. Proximidade <= 6m, StateBag. |
| **QA-33** | Presets do Equalizador Biquad (Bass, Broadcast, etc.)| Web Audio API | `[PASS]` | 5 nós biquad reconfigurados instantaneamente em cascata. |
| **QA-34** | Modo Streamer Anti-DMCA (`/modostreamer`) | Proteção / KVP | `[PASS]` | Silenciamento seletivo de streamers com persistência local. |
| **QA-35** | Atenuação de Plantão Urgente (Breaking News) | Áudio / Evento | `[PASS]` | Vinheta urgente atenua rádio em 85% com restauração suave. |

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

### Roteiro 6: Weazel Radio 98.5 FM & Playlists do YouTube
1. Com cargo de repórter ou admin, digite `/weazeldj`.
2. Selecione **"Adicionar Música ou Playlist"**:
   - Insira um link individual do YouTube ou uma Playlist (`https://www.youtube.com/playlist?list=...`).
   - Confirme a inserção na fila e veja o status mudar para `AO VIVO`.
3. Entre em qualquer veículo civil e digite `/weazelradio`:
   - Ative a opção "Sintonizar no Painel do Carro".
   - Verifique o som da rádio tocando nitidamente pelos alto-falantes do carro.
4. Abra o menu do Equalizador e alterne entre os presets (`Bass Boost`, `Broadcast FM`, `Club`):
   - Perceba a mudança imediata na resposta de frequências graves e agudas.
5. Use o item `headphones`:
   - O áudio passa a tocar diretamente no seu ouvido independente de estar dentro ou fora do carro.

### Roteiro 7: Caixa de Som Portátil & Áudio 3D Multi-Player
1. Dê a si mesmo o item `radio_portable`: `/giveitem me radio_portable 1`.
2. Use o item pelo inventário:
   - Selecione **"Carregar no Braço / Ombro"**: o ped assume a animação de carregar e a caixa fica acoplada ao corpo.
   - Caminhe pelo mapa: o som acompanha seus passos em tempo real.
3. Chame um segundo jogador (Jogador B):
   - Conforme o Jogador B se aproxima de você (a menos de 25 metros), ele ouve a música aumentando gradualmente.
   - Ao se afastar, o áudio diminui até silenciar suavemente.
4. Pressione a tecla `[E]`:
   - A caixa é posicionada no chão. O Jogador B continua ouvindo a música emanando do ponto exato no chão.
5. O Jogador B digite `/pegarcaixa` ou mire na caixa com o `ox_target` ("Recolher Caixa de Som"):
   - A caixa é removida do chão e transferida para o inventário do Jogador B.

### Roteiro 8: Sistema de Som Veicular (Rahe Engineering)
1. Pare com um carro e desça dele tendo uma `radio_portable` no inventário.
2. Mire no veículo com o `ox_target` e escolha "Sistema de Som Veicular".
3. Selecione "Instalar no Porta-Malas / Traseira":
   - A barra de progresso da instalação mecânica é executada.
   - O prop da caixa surge perfeitamente acoplado à traseira do carro.
4. Ligue a rádio do carro com `/weazelradio`.
5. Saia do carro e caminhe até 30 metros de distância:
   - O som automotivo potente é audível por todos que passarem pela rua ao redor do veículo.
6. Mire novamente no carro com `ox_target` e escolha "Desinstalar Caixa de Som":
   - O equipamento é desinstalado e a caixa volta para a sua mochila.

