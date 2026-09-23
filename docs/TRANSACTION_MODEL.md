# Modelo de Transações Duráveis e ACID — `vp_newspaper`

## 1. Visão Geral
Em economias de Heavy RP, operações que envolvem troca de bens físicos e moedas não podem falhar pela metade nem tolerar condições de corrida. O `vp_newspaper` adota o padrão de **Transações Duráveis com Máquina de Estados Finita (FSM)** e **Atualizações Atômicas Condicionais (CAS)**.

---

## 2. Máquina de Estados da Operação (`vp_newspaper_operations`)

Cada operação crítica (compra de jornal, saque de cofre, lote de impressão) é formalmente registrada com um identificador universal único (UUIDv4) antes da execução física.

```
       [ INÍCIO ]
           │
           ▼
     ┌───────────┐
     │  PENDING  │ ──( Falha Pré-Condição )──► ┌──────────┐
     └─────┬─────┘                             │  FAILED  │
           │                                   └──────────┘
           ▼
    ┌─────────────┐
    │ PROCESSING  │
    └──────┬──────┘
           │
     ┌─────┴─────────────────────────┐
     │ (Execução Atômica no Banco)   │
     │                               │
[Sucesso Total]             [Falha / Inventário Cheio]
     │                               │
     ▼                               ▼
┌───────────┐                ┌──────────────┐
│ COMMITTED │                │ COMPENSATING │
└───────────┘                └──────┬───────┘
                                    │
                       (Reembolso Concluído)
                                    │
                                    ▼
                             ┌─────────────┐
                             │ COMPENSATED │
                             └─────────────┘
                                    │
                         (Falha na Compensação)
                                    │
                                    ▼
                             ┌───────────────┐
                             │ MANUAL_REVIEW │
                             └───────────────┘
```

### Definição dos Estados:
* **`PENDING`**: Operação inicializada, parâmetros validados, aguardando início dos bloqueios atômicos.
* **`PROCESSING`**: Débito financeiro ou dedução de estoque em andamento.
* **`COMMITTED`**: Sucesso atômico confirmado. Bens transferidos, saldo gravado e ledger sincronizado.
* **`COMPENSATING`**: Falha detectada durante a entrega (ex: inventário sem capacidade). O sistema aciona rotina reversa.
* **`COMPENSATED`**: Todas as ações reversas (devolução de dinheiro, reposição de estoque) foram concluídas com sucesso.
* **`FAILED`**: A operação falhou na fase inicial de pré-requisitos antes de qualquer modificação de estado.
* **`MANUAL_REVIEW`**: Caso ocorra pane inesperada durante a compensação, o registro é congelado para auditoria do administrador, impedindo criação de dinheiro mágico ou duplicações.

---

## 3. Atomicidade e CAS (Compare-And-Swap)

Para evitar os tradicionais problemas de "Double Spending" em ambientes multithread como o OneSync Infinity e MariaDB, nós **NÃO** fazemos o anti-pattern:
```sql
-- ANTI-PATTERN VULNERÁVEL (NUNCA UTILIZADO):
SELECT balance FROM vp_newspaper_company WHERE id = 1; -- se dois jogadores lerem 5000 simultaneamente
-- Código LUA deduz na memória...
UPDATE vp_newspaper_company SET balance = novo_saldo WHERE id = 1; -- um sobrescreve o outro
```

Em vez disso, utilizamos **CAS Direto com Verificação de Linhas Afetadas (`affectedRows`)**:

### Exemplo 1: Saque Seguro no Cofre
```sql
UPDATE vp_newspaper_company
SET balance = balance - :amount,
    version = version + 1
WHERE id = 1 AND balance >= :amount;
```
* **Se `affectedRows == 1`**: O saldo foi decrementado com sucesso exclusivo. Nenhuma outra thread conseguiu o mesmo recurso. O dinheiro pode ser entregue ao jogador com segurança total.
* **Se `affectedRows == 0`**: O saldo era insuficiente no microssegundo da gravação. O saque é abortado imediatamente sem alterar um único centavo.

### Exemplo 2: Venda Concorrente do Último Exemplar no Stand
```sql
UPDATE vp_newspaper_boxes
SET stock = stock - 1,
    version = version + 1
WHERE id = :boxId AND stock > 0;
```
* Mesmo que 5 jogadores cliquem exatamente no mesmo milissegundo no stand com estoque = 1, o motor relacional do MariaDB garante que **apenas 1 thread** atualizará a linha (`affectedRows == 1`). As outras 4 receberão `affectedRows == 0` e serão notificadas instantaneamente de que o jornal esgotou.

---

## 4. Ledger Contábil Imutável (`vp_newspaper_ledger`)

Toda alteração de saldo gera uma entrada imutável no ledger:

```sql
INSERT INTO vp_newspaper_ledger (
    operation_id,
    citizenid,
    operation_type,
    delta_amount,
    previous_balance,
    new_balance,
    created_at
) VALUES (?, ?, ?, ?, ?, ?, NOW());
```

Isso garante rastreabilidade forense completa: o administrador da cidade pode a qualquer momento auditar o histórico de qualquer transação da empresa de jornalismo.
