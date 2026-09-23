# Manual de Recuperação de Falhas e Desastres — `vp_newspaper`

Este documento orienta os operadores e desenvolvedores sobre como o resource lida com quedas de servidor, crash de clientes e interrupções no OneSync, além de fornecer procedimentos manuais de reconciliação.

---

## 1. Recuperação Automática no Boot (`RecoverOnBoot`)

Sempre que o FXServer inicializa ou o resource é reiniciado (`ensure vp_newspaper`), o módulo `server/modules/operations.lua` executa uma rotina automática de varredura:

```sql
SELECT * FROM vp_newspaper_operations 
WHERE status IN ('PROCESSING', 'PENDING', 'COMPENSATING');
```

### Comportamento da Rotina Automática:
1. **Transações em `PENDING` com mais de 2 minutos**: São marcadas como `FAILED` automaticamente, pois foram interrompidas antes de tocar no saldo ou estoque.
2. **Transações em `PROCESSING`**: São movidas para `MANUAL_REVIEW` com log detalhado de auditoria no console, permitindo que a equipe verifique se houve débito real no jogador ou se a entrega foi cortada no meio.
3. **Transações em `COMPENSATING`**: Tentam reexecutar a rotina de compensação (devolução de saldo ou estoque ao stand).

---

## 2. Liberação de Locks de Redação Órfãos (Editor Sessions)

Se um repórter estava editando o jornal e sofreu um "Crash" no jogo ou desconexão forçada:

### 2.1. Desconexão Normal (`playerDropped`)
O listener `AddEventHandler('playerDropped', ...)` detecta a saída do jogador e imediatamente remove qualquer sessão associada ao seu `citizenid` na tabela `vp_newspaper_editor_sessions`.

### 2.2. Timeout Passivo (TTL de 90 Segundos)
Mesmo que o evento `playerDropped` não seja disparado a tempo (por exemplo, congelamento do processo FiveM do cliente), toda sessão possui uma coluna `expires_at = NOW() + INTERVAL 90 SECOND`.
Qualquer nova tentativa de lock por outro repórter executa:
```sql
DELETE FROM vp_newspaper_editor_sessions WHERE expires_at < NOW();
```
Portanto, uma estação de trabalho **nunca fica travada permanentemente**. O tempo máximo de espera após um crash sem heartbeat é de 90 segundos.

---

## 3. Consultas Úteis para Administradores de Banco de Dados

### 3.1. Verificar Operações que Exigem Atenção Manual
```sql
SELECT id, citizenid, operation_type, status, error_reason, created_at 
FROM vp_newspaper_operations 
WHERE status = 'MANUAL_REVIEW';
```

### 3.2. Auditar Movimentações do Cofre da Empresa
```sql
SELECT id, citizenid, operation_type, delta_amount, previous_balance, new_balance, created_at 
FROM vp_newspaper_ledger 
ORDER BY id DESC 
LIMIT 50;
```

### 3.3. Liberar Manualmente um Lock Travado de Editor (Emergencial)
```sql
-- Remove todas as sessões ativas de edição
DELETE FROM vp_newspaper_editor_sessions;
```

### 3.4. Reconciliar Estoque de Bancas Físicas
```sql
-- Retorna todas as bancas com estoque zerado para 10 unidades
UPDATE vp_newspaper_boxes SET stock = 10 WHERE stock = 0;
```
