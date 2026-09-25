# 🗺️ Roteiro de Expansão & Implementação (EXPANSION_ROADMAP)

Este documento estabelece as fases sequenciais de implementação dos novos subsistemas no `vp_newspaper`.

Data: 25/09/2026  
Status: Aprovado para Execução Imediata  

---

## Fases de Execução

### Fase 1: Fundação de Banco de Dados & Configuração
- [x] Criar migração SQL `sql/migrations/006_collectibles_and_leads.sql`.
- [x] Atualizar `server/database.lua` com a nova migração.
- [x] Expandir `shared/config.lua` com configurações de `Collectibles`, `FieldJournalism` e `Paperboy`.

### Fase 2: Sistema de Trading Cards, Booster Packs & PSA Grading
- [ ] Implementar `server/cards.lua` (sorteio server-authoritative, abertura com lock, PSA grading com subnotas e serialização única).
- [ ] Implementar `client/cards.lua` (abertura com progress bar, visualização de cartas com efeitos visuais e estante `/colecao`).

### Fase 3: Sistema de Jornalismo de Campo (Pautas & Leads)
- [ ] Implementar `server/field.lua` (validação de proximidade, checagem de equipamento de imprensa, rate limits e persistência de pautas em `vp_leads`).
- [ ] Implementar `client/field.lua` (spots de entrevista com NPCs, gravação de matérias e integração com ox_target).

### Fase 4: Sistema de Entrega Paperboy com Arremesso Físico
- [ ] Implementar `server/throw.lua` (validação física de coordenadas, cota diária, dedução de jornais e recompensa financeira).
- [ ] Implementar `client/throw.lua` (spawn de bicicleta, mira, cálculo balístico de arremesso e projétil 3D).

### Fase 5: Aprimoramento da Câmera de Reportagem
- [ ] Refinar `client/media.lua` com cinemática contínua de zoom e rotação suave do `qbx_newsjob`.

### Fase 6: Atualização do Manifesto, Validação Mecânica & Testes
- [ ] Declarar novos arquivos em `fxmanifest.lua`.
- [ ] Compilar 100% dos scripts Lua com `luac.exe -p`.
- [ ] Expandir testes automatizados em `tests/test_harness.js`.
- [ ] Registrar histórico em `IMPLEMENTATION_LOG.md` e gerar `FINAL_VERIFICATION_REPORT.md`.
