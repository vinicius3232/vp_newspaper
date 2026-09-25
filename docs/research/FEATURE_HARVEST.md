# 🌾 Colheita de Inovações & Features Selecionadas (FEATURE_HARVEST)

Este documento elenca detalhadamente todos os conceitos, mecânicas, regras de negócio e subsistemas selecionados das referências para enriquecer o `vp_newspaper`.

Data da Colheita: 25/09/2026  
Status: Triagem & Especificação Concluídas  

---

## 1. Feature 1: Sistema de Cartas Colecionáveis & Booster Packs (Origem: `haze-newspaper`)
- **Conceito:** O Weazel News distribui e comercializa pacotes de figurinhas/cartas históricas de Los Santos (políticos, corporações, crimes lendários, heróis locais).
- **Mecânica Central:**
  - Jogador compra ou encontra itens `booster_pack` (comum ou premium).
  - Ao usar o item no inventário (`ox_inventory`), executa animação de abertura com barra de progresso.
  - O **servidor** (100% server-authoritative) realiza o sorteio ponderado das cartas de acordo com as raridades (`basic`, `rare`, `legendary`).
  - O jogador recebe itens `card` com metadados `{ id = 'card_xxx', rarity = 'legendary', title = '...' }`.
  - Visualização em tela cheia com NUI animada e efeitos visuais (brilho e sparkles).

## 2. Feature 2: PSA Grading System (Origem: `haze-newspaper`)
- **Conceito:** Avaliação oficial de estado de conservação de cartas colecionáveis por uma junta avaliadora do jornal.
- **Mecânica Central:**
  - Uso do item `psa_case` sobre uma carta normal do inventário.
  - O servidor calcula 4 subnotas (Centralização, Bordas, Cantos e Superfície) de 1 a 10 e atribui uma nota global `grade = math.floor(média)`.
  - Se `grade >= 9`, a carta recebe o selo "Gem Mint".
  - O item no inventário é atualizado com metadados `{ graded = true, serial = 'PSA-XXXXXXXX', grade = N, subscores = {...} }`.
  - Impede duplicação e garante rastreabilidade contra adulteração de metadados.

## 3. Feature 3: Revistas & Comics Colecionáveis (Origem: `haze-newspaper`)
- **Conceito:** Edições especiais ilustradas de histórias em quadrinhos e reportagens investigativas clássicas.
- **Mecânica Central:**
  - Item usável `comic_book` com metadado `{ issue = 'issue_1' }`.
  - Ao usar, abre leitor NUI customizado estilo revista com transição de páginas e suporte bilíngue.
  - Registro de descoberta no banco de dados para consulta na estante de coleções do leitor (`/colecao`).

## 4. Feature 4: Jornalismo de Campo & Pautas Investigativas (Origem: `haze-newspaper`)
- **Conceito:** Repórteres não apenas escrevem textos estáticos, mas investigam e cobrem eventos no mapa.
- **Mecânica Central:**
  - Locais de pauta no mapa (entrevistas com testemunhas e gravações de reportagem de campo).
  - Repórter utiliza câmera e microfone com verificação de posse de itens e proximidade física.
  - Ao concluir a entrevista ou filmagem, o servidor gera um registro de pauta ativa (`vp_leads`).
  - No editor de matérias da redação, o repórter pode selecionar uma de suas pautas para vincular à matéria, aumentando o prestígio e o pagamento da publicação.

## 5. Feature 5: Entrega Paperboy de Bicicleta com Arremesso Físico (Origem: `haze-newspaper`)
- **Conceito:** Rota ágil de entregas para jovens entregadores ou estagiários de bicicleta (Cruiser/BMX).
- **Mecânica Central:**
  - Início de rota no NPC da gráfica com veículo tipo bicicleta.
  - Marcação dinâmica de alvos de entrega (portas de residências ou bancas de rua).
  - Enquanto pedala, o entregador pressiona o botão de arremesso (`throw.lua`).
  - O script projeta um projétil físico de jornal enrolado em direção ao alvo usando vetores de velocidade e física do GTA.
  - Ao atingir a proximidade do destino, valida o sucesso no servidor, computa o pagamento e desconta do limite diário.

## 6. Feature 6: Cinemática de Câmera Broadcast de Alta Precisão (Origem: `qbx_newsjob`)
- **Conceito:** Operação de câmera de estúdio ou externa com controles refinados.
- **Mecânica Central:**
  - Suavização dos controles de rotação de câmera (`CheckInputRotation`).
  - Zoom gradual e contínuo via scroll do mouse (`HandleZoom`).
  - Ocultação inteligente de componentes nativos de radar e HUD para gravação limpa.
  - Overlay opcional com letterbox de transmissão jornalística ao vivo.

## 7. Feature 7: Compatibilidade Expandida com Lation UI (Origem: `lation_ui`)
- **Conceito:** Modernização da experiência visual do usuário final.
- **Mecânica Central:**
  - Detecção automática de `exports['lation_ui']`.
  - Uso de gavetas laterais (`showDrawer`) para o dashboard executivo da Weazel News.
  - Notificações de áudio e status através do sistema `lation_ui:notify`.
