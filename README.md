# 📰 vp_newspaper — Sistema Profissional de Jornal & Redação (Weazel News)

Clone limpo, unificado e otimizado do **NProbleM Newspaper Remake**, adaptado para o ecossistema e stack oficial:
* **Framework:** QBCore / Qbox
* **Inventário:** ox_inventory (com suporte a metadata de edição e serial único)
* **Interação:** ox_target
* **Utilitários:** ox_lib (pontos, zonas, progress bars, cache)
* **Interface & Notificações:** lation_ui / ox_lib / QBCore
* **Banco de Dados:** oxmysql (com auto-schema automático no boot)
* **OneSync Infinity:** Compatibilidade total com checagem de distância física server-side.

---

## 🏛️ 1. Arquitetura e Estrutura de Arquivos

O recurso unificou as antigas duas pastas (`nproblem-newspaper` e `nproblem-newspaper-lib`) em um único pacote modular, idiomático e com **zero registradores decompilados**:

```
vp_newspaper/
├── fxmanifest.lua           -- Manifest unificado com MLO e NUI
├── README.md                -- Documentação técnica completa
├── shared/
│   └── config.lua           -- Configurações gerais, coordenadas, preços e bancas
├── locales/
│   └── locales.lua          -- Localização completa em PT-BR (com fallback EN)
├── sql/
│   └── schema.sql           -- Esquema SQL de referência
├── server/
│   ├── database.lua         -- Auto-schema no boot (criação automática de tabelas)
│   ├── main.lua             -- Bridge QBCore/Qbox, usables e logs Discord
│   ├── newspaper.lua        -- Trava do editor, persistência de páginas WYSIWYG
│   ├── company.lua          -- Gestão financeira, saldo, preço e funcionários
│   ├── boxes.lua            -- Bancas no mapa, compra e reabastecimento
│   └── printing.lua         -- Gráfica e estoque de bobinas de papel
├── client/
│   ├── newspaper.lua        -- Leitor de jornal NUI, virada de páginas e áudio
│   ├── editor.lua           -- Computador da redação e editor visual
│   ├── boxes.lua            -- Sincronização de props das bancas e ox_target
│   └── main.lua             -- Zonas de interação, garagem da van e gestão
├── web/                     -- Interface NUI (editor, leitor e painel de gestão)
│   ├── index.html           -- Interface com interceptor shim dinâmico de NUI
│   ├── script.js            -- Lógica frontend e jQuery UI draggables
│   ├── styles.css           -- Estilização
│   ├── swap.ogg             -- Efeito sonoro de virar a folha
│   └── bg.png               -- Textura de papel envelhecido
├── images/                  -- Ícones para o inventário
│   ├── newspaper.png
│   └── newspaperbox.png
└── stream/                  -- Interior MLO completo da Weazel News
    ├── int_wnews.ytyp
    ├── int_wnews_milo_.ymap
    └── ... (arquivos 3D e colisões)
```

---

## 🎮 2. Funcionalidades e Gameplay

1. **Leitura Imersiva do Jornal (`newspaper`):**
   * Usar o item no inventário abre a revista/jornal na tela com som vintage de folha virando (`swap.ogg`).
   * Animação do personagem segurando e lendo o jornal.

2. **Redação & Editor Visual WYSIWYG:**
   * Localizado no computador da redação da Weazel News.
   * Sistema de trava atômica: apenas um repórter edita por vez para evitar sobreposição.
   * Ferramentas de edição: tamanho de fonte, alinhamento, espaçamento, peso, cores, inserção de URLs de imagens, exclusão de elementos e limpeza de páginas.

3. **Cadeia de Produção Gráfica:**
   * **Depósito de Papel:** Pegar bobinas de papel em branco (`empty_newspaper`).
   * **Prensa Gráfica:** Transforma as bobinas em caixas de jornais impressos (`newspaperbox`).

4. **Distribuição & Bancas pela Cidade:**
   * Bancas (`prop_news_disp_02a`) com estoque independente.
   * Cidadãos podem comprar jornais pelo valor definido pela empresa.
   * Entregadores podem retirar a van oficial da Weazel News (`rumpo`) e reabastecer as bancas, recebendo comissão limpa em dinheiro.

5. **Painel de Gestão da Empresa (Boss Menu):**
   * Controle do saldo em cofre (depósitos e saques).
   * Ajuste do preço do jornal (com trava de teto máximo para balanceamento).
   * Histórico de transações financeiras.
   * Contratação, demissão e promoção de entregadores e editores.

---

## 🛡️ 3. Segurança e Anti-Exploit

* **Anti-Dupe Triplo:** Cada jornal gerado recebe um UUID v4 no metadata (`serial`) registrado na tabela `vp_newspaper_copies`.
* **Fail-Closed:** Remoção de dinheiro ou itens de estoque sempre precede a entrega de recompensas.
* **Checagem de Proximidade (OneSync Infinity):** Todas as transações com bancas de jornal validam a distância física vetorial no servidor (`<= 4.5m`).

---

## 🚀 4. Como Ativar

Adicione ao seu `server.cfg`:
```cfg
ensure vp_newspaper
```
*(Não é necessário importar SQL manualmente; o recurso cria e popula as tabelas automaticamente no boot).*
