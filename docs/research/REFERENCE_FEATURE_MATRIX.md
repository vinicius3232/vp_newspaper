# 📊 Matriz Comparativa de Recursos (REFERENCE_FEATURE_MATRIX)

Este documento compara minuciosamente as capacidades de cada módulo do script alvo (`vp_newspaper`) com as implementações encontradas nos 5 resources de referência (`haze-newspaper`, `qbx_newsjob`, `lation_ui`, `rp_boombox`, `qbx_vehicleradio`).

Data da Análise: 25/09/2026  
Status: Análise Aprofundada Finalizada  

---

## 1. Tabela Comparativa de Recursos

| Sistema / Domínio | `vp_newspaper` (Atual) | `haze-newspaper` | `qbx_newsjob` | `lation_ui` / `rp_boombox` | Veredito & Ação |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Leitura de Jornal** | NUI Dark Glassmorphic, toolbar moderna, virar páginas, som | NUI Vintage rústica, flip anim | Não possui | Não possui | **Superior no vp_newspaper** (Manter e enriquecer). |
| **Editor de Matérias** | Multi-páginas, OCC (optimistic locking), anti-XSS, rascunhos | Editor simples com markdown básico | Não possui | Não possui | **Superior no vp_newspaper** (Integrar consumo de pautas de campo). |
| **Bancas de Jornal** | CAS (Compare-And-Swap), rollback compensatório, props dinâmicos | Zonas ox_target estáticas, estoque simples | Não possui | Não possui | **Superior no vp_newspaper** (Manter robustez financeira). |
| **Impressão & Tiragens** | Impressão em lote com custo de papel e tinta | Tiragem com controle de edição | Não possui | Não possui | **Compatível** (Adicionar metadados da edição impressa ao item). |
| **Trading Cards & Boosters** | ❌ Não possui | ✔ Pacotes, raridades, sorteio server-authoritative, serial único | Não possui | Não possui | **Lacuna crítica**. Incorporar módulo completo de Cartas & Boosters no `vp_newspaper`. |
| **PSA Grading de Cartas** | ❌ Não possui | ✔ Avaliação com subnotas (1-10), selo Gem Mint, serial único | Não possui | Não possui | **Lacuna crítica**. Incorporar PSA Grading com persistência em metadados. |
| **Revistas Colecionáveis (Comics)** | ❌ Não possui | ✔ Revistas temáticas com leitor próprio (PT/EN) | Não possui | Não possui | **Lacuna crítica**. Incorporar módulo de Revistas e Estante Colecionável. |
| **Jornalismo de Campo** | Equipamentos cosméticos (anims) | ✔ Entrevistas com NPCs, gravação de spots e geração de pautas (`leads`) | Equipamentos com job check | Não possui | **Lacuna de gameplay**. Incorporar geração de Pautas (`vp_leads`) para jornalistas. |
| **Entrega Paperboy (Arremesso)** | Rota de van tradicional | ✔ Rota de bike (Cruiser/BMX) com arremesso físico de jornal (`throw.lua`) | Não possui | Não possui | **Lacuna de gameplay**. Adicionar modalidade Paperboy com arremesso de bike. |
| **Câmera de Transmissão** | Overlay de visor simples | Não possui | ✔ Cinemática profissional, fov progressivo, letterbox, rotação suave | Não possui | **Oportunidade**. Incorporar cinemática e zoom do `qbx_newsjob` no `client/media.lua`. |
| **Rádio 98.5 FM & Caixas 3D** | Rádio Weazel 98.5 FM, van de transmissão, caixas de som 3D | Não possui | Não possui | ✔ Playlists personalizadas, favoritos, toggle veicular | **Superior no vp_newspaper** (Expandir com presets e favoritos). |
| **Design System & UI** | Tailwind/CSS customizado dark glass | Vintage paper | Standard ox_lib | ✔ Biblioteca rica Lation UI (drawers, alerts, timelines) | **Fusão**. Integrar compatibilidade com exports de notificações e drawers Lation UI. |

---

## 2. Síntese das Decisões de Engenharia

1. **Absorção Integral do Sistema de Colecionáveis do `haze-newspaper`:**
   - Implementar `server/cards.lua`, `client/cards.lua`, `server/collectibles.lua` e `client/collectibles.lua`.
   - Adicionar itens `card`, `booster_pack`, `psa_case` e `comic_book` com metadados resilientes para `ox_inventory`.
2. **Absorção do Sistema de Pautas e Jornalismo de Campo:**
   - Implementar `server/field.lua` e `client/field.lua`.
   - Spots de entrevista com NPCs e gravação de cenas policiais/culturais que geram `vp_leads` para alimentar matérias da redação.
3. **Absorção da Entrega Paperboy de Bicicleta:**
   - Implementar arremesso dinâmico de jornal da bike (`client/throw.lua` e `server/throw.lua`).
   - Verificação física de distância, colisão e cooldown server-side.
4. **Cinemática de Câmera de Alta Fidelidade:**
   - Enriquecer `client/media.lua` com o controle de rotação e zoom gradual de `qbx_newsjob`.
5. **Integração Amigável com Lation UI:**
   - Adicionar helper de UI em `client/main.lua` que utiliza `exports.lation_ui:showDrawer` e `notify` quando disponível, com fallback gracioso para `ox_lib`.
