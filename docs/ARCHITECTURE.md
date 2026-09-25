# Arquitetura do Sistema — `vp_newspaper`

## 1. Visão Geral e Stack Tecnológica
O `vp_newspaper` é um resource FiveM de jornalismo impresso e distribuição física de notícias construído para Heavy RP, alta concorrência e integridade transacional absoluta.

### Stack de Dependências
* **FiveM FXServer:** Artifacts recomendados 10000+ (OneSync Infinity ativado).
* **Ambiente de Execução:** Lua 5.4 nativo com isolamento rigoroso de escopo (`local` obrigatório).
* **Framework:** Qbox / QBCore (`exports['qbx_core']` e compatibilidade `QBCore.Functions`).
* **Utilitários e UI:** `ox_lib` (points, callbacks, notifications, progressBar, cache, context menus, input dialogs).
* **Interação Física:** `ox_target` (interações nos modelos de stands de jornal, pontos de impressão, editor, cofre, veículos e caixas de som no chão).
* **Inventário:** `ox_inventory` (manipulação atômica de slots, metadata de seriais únicos e persistência de itens).
* **Persistência Relacional:** `oxmysql` (MariaDB/MySQL) com transações ACID, versionamento otimista e constraints rígidas.
* **Frontend & Áudio CEF:** NUI (HTML5, Vanilla JS, Web Audio API com 5-band Biquad Equalizer, YouTube IFrame API com suporte nativo a Playlists).
* **Sincronização 3D:** StateBags replicadas (`weazelVehicleSpeaker`, `weazelCarryingRadio`) e registro server-side de alto-falantes (`ActiveGroundSpeakers`).

---

## 2. Ciclo de Vida do Resource (Lifecycle)

```
[Server Boot / Resource Start]
       │
       ▼
1. Execução de Migrations SQL Idempotentes (001 -> 002 -> 003 -> 004 -> 005)
       │
       ▼
2. FSM Crash Recovery (RecoverOnBoot: reconcilia operações 'PROCESSING' / 'PENDING')
       │
       ▼
3. Limpeza de Locks Órfãos de Editor Sessions
       │
       ▼
4. Carga de Cache Inicial em Memória (Stands/Boxes a partir do Banco de Dados)
       │
       ▼
[Execução em Runtime (Event-Driven & State Machine)]
       │
       ├── Interações via ox_target (Client)
       ├── Validações de Distância Física, Cooldowns e Payload (Security Module)
       ├── Transações Atômicas CAS no Banco e Ledgering Financeiro
       │
[Player Dropped]
       │
       ▼
5. Liberação imediata de lock de editor para a CID desconectada
       │
[Resource Stop]
       │
       ▼
6. Cleanup de ox_lib points e desvinculação graciosa de sessões ativas
```

---

## 3. Diagramas de Sequência

### 3.1. Compra de Jornal no Stand (Atômica & Anti-Dupe)
```mermaid
sequenceDiagram
    autonumber
    actor Player as Jogador (Client)
    participant Lib as ox_lib / ox_target
    participant Net as Event Security Gate
    participant Srv as Server (boxes.lua)
    participant DB as MariaDB (CAS Update)
    participant FSM as Operations FSM
    participant Inv as ox_inventory

    Player->>Lib: Clica "Comprar Jornal ($5)" no Stand
    Lib->>Net: TriggerServerEvent('vp_newspaper:server:buyNewspaper', boxId)
    Net->>Net: Valida Cooldown, Distância (<2.5m) e Payload
    Net->>Srv: Processa Requisição
    Srv->>DB: UPDATE vp_newspaper_boxes SET stock = stock - 1 WHERE id = ? AND stock > 0
    alt Estoque Insuficiente (affectedRows == 0)
        DB-->>Srv: 0 rows
        Srv-->>Player: Notificação: "Stand sem estoque!" (FAIL-CLOSED)
    else Estoque Reservado com Sucesso
        Srv->>FSM: CreateOperation(cid, 'PURCHASE_STAND', metadata)
        Srv->>Player: Dedução de $5 (Player.Functions.RemoveMoney)
        alt Falha ao Deduzir Dinheiro
            Srv->>DB: UPDATE vp_newspaper_boxes SET stock = stock + 1 (Rollback Estoque)
            Srv->>FSM: MarkFailed(opId, 'insufficient_funds')
            Srv-->>Player: Notificação: "Dinheiro insuficiente"
        else Dinheiro Deduzido
            Srv->>Inv: AddItem(source, 'newspaper', 1, metadata={serial, edition})
            alt Inventário Cheio / Falha AddItem
                Srv->>Player: Reembolso $5
                Srv->>DB: UPDATE vp_newspaper_boxes SET stock = stock + 1
                Srv->>FSM: MarkCompensated(opId, 'inventory_full_refunded')
                Srv-->>Player: Notificação: "Inventário cheio! Reembolso efetuado."
            else Sucesso
                Srv->>DB: UPDATE vp_newspaper_company SET balance = balance + 5
                Srv->>FSM: MarkCommitted(opId)
                Srv-->>Player: Notificação: "Você comprou um jornal!"
            end
        end
    end
```

---

### 3.2. Impressão de Jornais na Gráfica
```mermaid
sequenceDiagram
    autonumber
    actor Reporter as Repórter (Client)
    participant Sec as Security Gate
    participant Srv as Server (printing.lua)
    participant Inv as ox_inventory

    Reporter->>Sec: TriggerServerEvent('vp_newspaper:server:printNewspaper')
    Sec->>Sec: Verifica Job ('reporter'), Cooldown e Distância física da impressora (<2.5m)
    Sec->>Srv: Autorizado
    Srv->>Inv: RemoveItem(source, 'empty_newspaper', 5)
    alt Material Insuficiente
        Srv-->>Reporter: Notificação: "Você precisa de 5 folhas de papel de jornal" (FAIL-CLOSED)
    else Papel Consumido
        Srv->>Inv: AddItem(source, 'newspaperbox', 1)
        alt Falha ao Entregar Caixa (Inventário Cheio/Peso Excedido)
            Srv->>Inv: AddItem(source, 'empty_newspaper', 5) (ROLLBACK TOTAL)
            Srv-->>Reporter: Notificação: "Espaço insuficiente! Papéis devolvidos."
        else Caixa Entregue
            Srv-->>Reporter: Notificação: "Caixa de jornais impressa com sucesso!"
        end
    end
```

---

### 3.3. Reposição de Stand (Restock)
```mermaid
sequenceDiagram
    autonumber
    actor Reporter as Repórter (Client)
    participant Srv as Server (boxes.lua)
    participant DB as MariaDB (CAS Update)
    participant Inv as ox_inventory

    Reporter->>Srv: TriggerServerEvent('vp_newspaper:server:restockBox', boxId)
    Srv->>Srv: Valida Job, Distância (<2.5m) e Cooldown
    Srv->>Inv: RemoveItem(source, 'newspaperbox', 1)
    alt Sem Caixa no Inventário
        Srv-->>Reporter: Notificação: "Você não tem uma caixa de jornais" (FAIL-CLOSED)
    else Caixa Consumida
        Srv->>DB: UPDATE vp_newspaper_boxes SET stock = stock + 10 WHERE id = ?
        alt Falha na Atualização do Banco
            Srv->>Inv: AddItem(source, 'newspaperbox', 1) (ROLLBACK)
            Srv-->>Reporter: Notificação: "Erro interno no stand. Caixa devolvida."
        else Estoque Atualizado
            Srv->>Reporter: Pagamento de comissão de entrega ($50)
            Srv-->>Reporter: Notificação: "Stand reabastecido (+10)!"
        end
    end
```

---

### 3.4. Edição Concorrente com Lock e OCC (Optimistic Concurrency Control)
```mermaid
sequenceDiagram
    autonumber
    actor Ed1 as Repórter 1
    actor Ed2 as Repórter 2
    participant Srv as Server (newspaper.lua)
    participant DB as MariaDB

    Ed1->>Srv: RequestLock(pageId)
    Srv->>DB: SELECT * FROM vp_newspaper_editor_sessions WHERE page_id = ?
    Srv->>DB: INSERT INTO vp_newspaper_editor_sessions (page_id, cid, expires_at)
    Srv-->>Ed1: Lock Concedido (TTL: 90s, Token emitido)

    Ed2->>Srv: RequestLock(pageId)
    Srv-->>Ed2: Lock Negado ("Estação ocupada por Repórter 1")

    loop A cada 30 segundos
        Ed1->>Srv: SendHeartbeat(pageId, token)
        Srv->>DB: UPDATE sessions SET expires_at = NOW() + 90s
    end

    Ed1->>Srv: SavePage(pageId, content, expectedRevision=2)
    Srv->>DB: UPDATE vp_newspaper_pages SET content = ?, revision = revision + 1 WHERE id = ? AND revision = 2
    alt Revisão Conflitante (affectedRows == 0)
        Srv-->>Ed1: Erro de Conflito de Versão (OCC FAIL)
    else Salvo com Sucesso
        Srv->>DB: DELETE FROM vp_newspaper_editor_sessions WHERE page_id = ?
        Srv-->>Ed1: Salvo com sucesso!
    end
```

---

### 3.5. Transmissão da Weazel Radio 98.5 FM, Som 3D & Playlists
```mermaid
sequenceDiagram
    autonumber
    actor DJ as DJ / Repórter
    actor Listener as Ouvinte / Ped Próximo
    participant Srv as Server (radio.lua)
    participant ClientDJ as Client DJ (radio.lua)
    participant ClientL as Client Ouvinte (radio.lua)
    participant NUI as NUI CEF (radio_audio.js)

    DJ->>ClientDJ: Executa /weazeldj -> Adicionar Música ou Playlist
    ClientDJ->>Srv: TriggerServerEvent('vp_newspaper:server:addRadioTrack', url, title)
    Srv->>Srv: Valida Permissão (Grade >= 1 ou Admin) e Sanitiza URL
    Srv->>Srv: Insere na StationState.queue (detecta se é Playlist ou Faixa)
    Srv->>ClientL: TriggerClientEvent('vp_newspaper:client:syncRadioState', broadcastData)

    loop Adaptive Ticking Loop (a cada 250ms a 1200ms)
        ClientL->>ClientL: UpdateRadioPlayback()
        Note over ClientL: Checa Fones -> Caixa Carregada -> Rádio do Carro -> Fontes 3D
        alt Fone de Ouvido Ligado ou Carregando Caixa
            ClientL->>NUI: SendNUIMessage({action='playRadio', volume=userVolume})
        else Próximo a Caixa no Chão ou Carro com Som
            ClientL->>ClientL: Calcula Distância Euclidiana 3D com Queda Quadrática
            ClientL->>NUI: SendNUIMessage({action='setVolume', volume=calculatedVolume})
        else Fora de Alcance (> 25m-30m)
            ClientL->>NUI: SendNUIMessage({action='stopRadio'})
        end
    end

    Note over NUI: Web Audio API aplica 5-Band Biquad EQ (Broadcast, Bass, etc.)
    alt Playlist do YouTube Finaliza Faixa
        NUI->>NUI: ytPlayer avança automaticamente para próxima música da lista
    else Fim da Programação
        NUI->>Srv: Callback 'radioTrackEnded'
        Srv->>Srv: Avança Fila ou Carrega Faixa Padrão
    end
```

