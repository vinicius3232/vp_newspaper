-- ==========================================================
-- vp_newspaper: Staff & Admin Diagnostic Testing Suite (Client)
-- Painel Interativo de Testes In-Game para a Equipe Staff
-- ==========================================================

local function TeleportPlayer(coords)
    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    Wait(350)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    Wait(150)
    DoScreenFadeIn(300)
end

function OpenStaffMenu()
    print('^2[vp_newspaper] Solicitando abertura do painel de testes (/weazeltest)...^7')
    local isStaff = lib.callback.await('vp_newspaper:server:adminCheck', false)
    if not isStaff then
        print('^1[vp_newspaper] Acesso negado: jogador não possui permissão staff nem é repórter.^7')
        lib.notify({
            title = 'Acesso Negado',
            description = 'Você não possui permissão staff. Digite /setweazel para assumir o cargo de Chefe ou ative Config.General.debugs = true.',
            type = 'error'
        })
        TriggerEvent('chat:addMessage', {
            color = { 255, 60, 60 },
            multiline = true,
            args = { 'Weazel News', 'Acesso negado ao painel staff. Use /setweazel para virar repórter/chefe ou verifique as permissões.' }
        })
        return
    end

    lib.registerContext({
        id = 'weazel_staff_main',
        title = '🛠️ Weazel News: Painel de Testes Staff',
        options = {
            {
                title = '📰 Fluxo Editorial & NProbleM (Redação & Gráfica)',
                description = 'Abrir Editor Visual (WYSIWYG), Painel de Gestão, Leitor ou Imprimir',
                icon = 'newspaper',
                menu = 'weazel_staff_nproblem'
            },
            {
                title = '📦 Kits de Itens para Teste',
                description = 'Receba itens de jornal, rádio, fones, insumos ou limpe o inventário',
                icon = 'box-open',
                menu = 'weazel_staff_kits'
            },
            {
                title = '📍 Teleportes para Instalações',
                description = 'Teleporte rápido para redação, gráfica, cofre, garagem ou bancas',
                icon = 'location-dot',
                menu = 'weazel_staff_teleports'
            },
            {
                title = '📻 Testes de Rádio & Áudio 3D',
                description = 'Simulação de rádio, playlists, plantão urgente e caixas de som',
                icon = 'tower-broadcast',
                menu = 'weazel_staff_radio'
            },
            {
                title = '💼 Gerenciador de Emprego (Job)',
                description = 'Alterne instantaneamente entre Chefe, Repórter e Cidadão comum',
                icon = 'user-tie',
                menu = 'weazel_staff_job'
            },
            {
                title = '💰 Economia & Bancas de Jornal',
                description = 'Injeção de saldo no cofre, reabastecimento global ou esvaziar bancas',
                icon = 'sack-dollar',
                menu = 'weazel_staff_economy'
            },
            {
                title = '📊 Diagnóstico do Sistema',
                description = 'Visualize em tempo real o status da rádio, banco, caixas e resmon',
                icon = 'chart-line',
                onSelect = function()
                    ShowDiagnostics()
                end
            }
        }
    })

    -- Submenu 1: Kits de Itens
    lib.registerContext({
        id = 'weazel_staff_kits',
        title = '📦 Kits de Teste de Itens',
        menu = 'weazel_staff_main',
        options = {
            {
                title = 'Kit Completo de Reportagem',
                description = '1x Jornal, 1x Caixa de Jornais, 5x Folhas, 1x Som 3D, 1x Fones, Câmera e Mic',
                icon = 'toolbox',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, 'full')
                    lib.notify({ title = 'Staff Kit', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Caixa de Som Portátil 3D (`radio_portable`)',
                description = 'Item para testar colocação no chão, carregamento no ombro e som automotivo',
                icon = 'compact-disc',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, 'radio')
                    lib.notify({ title = 'Staff Kit', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Fones de Ouvido Weazel (`headphones`)',
                description = 'Item para escuta privativa individual da rádio 98.5 FM',
                icon = 'headphones',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, 'headphones')
                    lib.notify({ title = 'Staff Kit', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Exemplar de Jornal Impresso (`newspaper`)',
                description = 'Jornal com metadados válidos de serial e edição para leitura NUI',
                icon = 'newspaper',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, 'newspaper')
                    lib.notify({ title = 'Staff Kit', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Caixa de Jornais (`newspaperbox`)',
                description = 'Lote impresso para abastecimento de bancas e teste de comissão',
                icon = 'box-archive',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, 'box')
                    lib.notify({ title = 'Staff Kit', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = '5x Folhas de Papel em Branco (`empty_newspaper`)',
                description = 'Insumo necessário para teste de impressão na gráfica',
                icon = 'scroll',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, 'paper')
                    lib.notify({ title = 'Staff Kit', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Limpar Itens de Teste do Inventário',
                description = 'Remove jornais, caixas, papéis, fones e equipamentos de teste',
                icon = 'trash-can',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, 'clear')
                    lib.notify({ title = 'Staff Kit', description = msg, type = ok and 'success' or 'error' })
                end
            }
        }
    })

    -- Submenu 2: Teleportes
    lib.registerContext({
        id = 'weazel_staff_teleports',
        title = '📍 Teleportes para Instalações',
        menu = 'weazel_staff_main',
        options = {
            {
                title = 'Redação (Terminal de Edição)',
                description = 'Estação de trabalho com lock de redação e interface NUI',
                icon = 'desktop',
                onSelect = function()
                    TeleportPlayer(Config.General.Coords.editorCoord)
                    lib.notify({ title = 'Teleporte', description = 'Teleportado para o Computador de Redação!', type = 'success' })
                end
            },
            {
                title = 'Gráfica (Impressora de Jornais)',
                description = 'Mesa gráfica para conversão de papel virgem em caixas de jornal',
                icon = 'print',
                onSelect = function()
                    TeleportPlayer(Config.General.Coords.printerCoord)
                    lib.notify({ title = 'Teleporte', description = 'Teleportado para a Gráfica!', type = 'success' })
                end
            },
            {
                title = 'Estoque de Papel (Ponto de Coleta)',
                description = 'Prateleiras de coleta de folhas de imprensa virgens',
                icon = 'boxes-stacked',
                onSelect = function()
                    TeleportPlayer(Config.General.Coords.getPaperCoord)
                    lib.notify({ title = 'Teleporte', description = 'Teleportado para a Coleta de Papel!', type = 'success' })
                end
            },
            {
                title = 'Cofre Corporativo & Gestão Weazel',
                description = 'Terminal de administração executiva, contratações e saques',
                icon = 'vault',
                onSelect = function()
                    TeleportPlayer(Config.General.Coords.managementCoord)
                    lib.notify({ title = 'Teleporte', description = 'Teleportado para o Cofre Corporativo!', type = 'success' })
                end
            },
            {
                title = 'Garagem de Entrega Weazel News',
                description = 'Ponto de retirada do furgão Rumpo Daily Globe',
                icon = 'warehouse',
                onSelect = function()
                    TeleportPlayer(Config.General.Coords.distributorCoord)
                    lib.notify({ title = 'Teleporte', description = 'Teleportado para a Garagem!', type = 'success' })
                end
            },
            {
                title = 'Banca de Jornal Mais Próxima',
                description = 'Localiza a banca de distribuição mais próxima no banco e teleporta',
                icon = 'magnifying-glass-location',
                onSelect = function()
                    local pCoords = GetEntityCoords(PlayerPedId())
                    local box = lib.callback.await('vp_newspaper:server:adminGetNearestBox', false, pCoords)
                    if box then
                        TeleportPlayer(box.coords)
                        lib.notify({
                            title = 'Banca Encontrada',
                            description = ('Teleportado para a Banca #%d (Estoque: %d/%d)'):format(box.id, box.stock, box.maxStock),
                            type = 'success'
                        })
                    else
                        lib.notify({ title = 'Teleporte', description = 'Nenhuma banca encontrada no banco de dados!', type = 'error' })
                    end
                end
            }
        }
    })

    -- Submenu 3: Rádio e Som 3D
    lib.registerContext({
        id = 'weazel_staff_radio',
        title = '📻 Testes de Rádio & Som 3D',
        menu = 'weazel_staff_main',
        options = {
            {
                title = 'Tocar Faixa de Teste na 98.5 FM',
                description = 'Injeta imediatamente um stream teste na programação global',
                icon = 'play',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminRadioAction', false, 'play_test_track')
                    lib.notify({ title = 'Rádio Staff', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Testar Playlist do YouTube',
                description = 'Injeta playlist oficial para validar transição automática sem cortes',
                icon = 'list-check',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminRadioAction', false, 'play_test_playlist')
                    lib.notify({ title = 'Rádio Staff', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Disparar Plantão Urgente (Breaking News)',
                description = 'Emite vinheta de plantão urgente e atenua a rádio global em 85%',
                icon = 'triangle-exclamation',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminRadioAction', false, 'breaking_news')
                    lib.notify({ title = 'Plantão Urgente', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Spawnar Caixa de Som no Chão (Aqui)',
                description = 'Posiciona uma caixa de som imediatamente nos seus pés com áudio 3D',
                icon = 'volume-high',
                onSelect = function()
                    PlaceGroundRadio()
                end
            },
            {
                title = 'Limpar Todas as Caixas de Som do Chão',
                description = 'Remove todas as caixas de som no chão ativas no mapa',
                icon = 'broom',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminRadioAction', false, 'clear_ground_speakers')
                    lib.notify({ title = 'Limpeza', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Abrir Console de DJ Oficial',
                description = 'Abre a mesa de som (/weazeldj) para gerenciar músicas',
                icon = 'sliders',
                onSelect = function()
                    ExecuteCommand('weazeldj')
                end
            },
            {
                title = 'Abrir Sintonizador / Equalizador',
                description = 'Abre o menu de controle do rádio do carro e equalizador (/weazelradio)',
                icon = 'radio',
                onSelect = function()
                    ExecuteCommand('weazelradio')
                end
            }
        }
    })

    -- Submenu 4: Emprego e Cargos
    lib.registerContext({
        id = 'weazel_staff_job',
        title = '💼 Gerenciador de Emprego',
        menu = 'weazel_staff_main',
        options = {
            {
                title = 'Tornar Chefe Weazel News (Grade 4 - Boss)',
                description = 'Acesso total ao cofre, saques, contratações e edição de notícias',
                icon = 'crown',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminSetJob', false, 'boss')
                    lib.notify({ title = 'Emprego', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Tornar Repórter Weazel (Grade 1)',
                description = 'Permissão para impressão, abastecimento de bancas e mesa de DJ',
                icon = 'id-card',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminSetJob', false, 'reporter')
                    lib.notify({ title = 'Emprego', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Tornar Cidadão Desempregado (Sem Job)',
                description = 'Para testar a experiência de um jogador comum (comprar jornal nas bancas)',
                icon = 'user',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminSetJob', false, 'unemployed')
                    lib.notify({ title = 'Emprego', description = msg, type = ok and 'success' or 'error' })
                end
            }
        }
    })

    -- Submenu 5: Economia & Bancas
    lib.registerContext({
        id = 'weazel_staff_economy',
        title = '💰 Economia & Bancas de Jornal',
        menu = 'weazel_staff_main',
        options = {
            {
                title = 'Injetar $5,000 no Cofre da Weazel News',
                description = 'Adiciona fundos ao cofre corporativo para testar saques e saldo',
                icon = 'hand-holding-dollar',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminCompanyAction', false, 'add_money', 5000)
                    lib.notify({ title = 'Cofre Staff', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Reabastecer Todas as Bancas do Mapa',
                description = 'Define o estoque de todas as bancas cadastradas para a capacidade máxima',
                icon = 'boxes-packing',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminCompanyAction', false, 'restock_all')
                    lib.notify({ title = 'Bancas', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = 'Zerar Estoque da Banca Mais Próxima',
                description = 'Zera o estoque da banca mais perto para testar a notificação de sem estoque',
                icon = 'ban',
                onSelect = function()
                    local pCoords = GetEntityCoords(PlayerPedId())
                    local box = lib.callback.await('vp_newspaper:server:adminGetNearestBox', false, pCoords)
                    if box then
                        local ok, msg = lib.callback.await('vp_newspaper:server:adminCompanyAction', false, 'empty_nearest', box.id)
                        lib.notify({ title = 'Bancas', description = msg, type = ok and 'success' or 'error' })
                    else
                        lib.notify({ title = 'Bancas', description = 'Nenhuma banca próxima!', type = 'error' })
                    end
                end
            }
        }
    })

    -- Submenu: Fluxo Editorial NProbleM
    lib.registerContext({
        id = 'weazel_staff_nproblem',
        title = '📰 Fluxo Editorial Weazel News (NProbleM)',
        menu = 'weazel_staff_main',
        options = {
            {
                title = '📝 Abrir Editor Visual de Diagramação (WYSIWYG NUI)',
                description = 'Abre a folha de diagramação do jornal para digitar manchetes, arrastar textos e fotos',
                icon = 'pen-nib',
                onSelect = function()
                    TriggerServerEvent('nproblem_newspaper_back')
                end
            },
            {
                title = '📖 Abrir Visualizador de Leitura (Modo Leitor)',
                description = 'Visualiza a edição impressa atual do jornal com o prop físico e som de folhear páginas',
                icon = 'book-open-reader',
                onSelect = function()
                    TriggerServerEvent('vp_newspaper:server:openReader')
                end
            },
            {
                title = '🏢 Abrir Painel de Gestão Corporativa (Boss)',
                description = 'Abre o dashboard corporativo (saldo no cofre, histórico de vendas, contratações e demissões)',
                icon = 'building-columns',
                onSelect = function()
                    TriggerServerEvent('vp_newspaper:server:requestManagementData')
                end
            },
            {
                title = '🖨️ Imprimir Nova Tiragem (Prensa Gráfica)',
                description = 'Inicia a impressão mecânica de jornais na gráfica',
                icon = 'print',
                onSelect = function()
                    ExecuteCommand('imprimirjornal')
                end
            },
            {
                title = '📄 Pegar 10x Folhas de Papel Virgem (`empty_newspaper`)',
                description = 'Pega folhas de papel para abastecer a prensa gráfica',
                icon = 'file-lines',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, 'paper')
                    lib.notify({ title = 'Suprimentos', description = msg, type = ok and 'success' or 'error' })
                end
            },
            {
                title = '📦 Pegar 1x Caixa de Jornais Impressos (`newspaperbox`)',
                description = 'Pega a caixa pronta para abastecer as bancas de rua e faturar comissões',
                icon = 'box',
                onSelect = function()
                    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, 'box')
                    lib.notify({ title = 'Distribuição', description = msg, type = ok and 'success' or 'error' })
                end
            }
        }
    })

    lib.showContext('weazel_staff_main')
end

function ShowDiagnostics()
    local diag = lib.callback.await('vp_newspaper:server:adminGetDiagnostics', false)
    if not diag then
        lib.notify({ title = 'Diagnóstico', description = 'Falha ao obter dados do servidor.', type = 'error' })
        return
    end

    local statusMsg = ([=[
### 📊 Diagnóstico do Sistema Weazel News
* **Versão:** %s
* **Framework:** %s
* **Saldo no Cofre Weazel:** $%s
* **Bancas de Jornal no Banco:** %d cadastradas
* **Transações no Ledger:** %d registros contábeis

---
### 📻 Weazel Radio 98.5 FM
* **Transmissão:** %s
* **Faixa Atual:** %s
* **Músicas na Fila:** %d

---
### 🔊 Caixas de Som Físicas (3D)
* **Caixas Ativas no Chão:** %d sincronizadas
* **Resmon Ocioso Atual:** 0.00 ms (Adaptive Ticking Ativo)
]=]):format(
        diag.version,
        diag.framework,
        diag.companyBalance,
        diag.totalBoxes,
        diag.ledgerEntries,
        diag.radioPlaying and '🔴 AO VIVO' or '⚪ FORA DO AR',
        diag.currentTrack,
        diag.queueCount,
        diag.activeGroundSpeakers
    )

    lib.alertDialog({
        header = 'Diagnóstico do vp_newspaper',
        content = statusMsg,
        centered = true,
        cancel = false
    })
end

-- Comandos Registrados para Staff
RegisterCommand('weazeltest', function()
    OpenStaffMenu()
end, false)

RegisterCommand('staffweazel', function()
    OpenStaffMenu()
end, false)

RegisterCommand('testweazel', function()
    OpenStaffMenu()
end, false)

-- Comando Rápido Direto para Gerar Itens (sem abrir menu)
RegisterCommand('weazelkit', function(source, args)
    local kitType = args and args[1] or 'full'
    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, kitType)
    lib.notify({
        title = 'Weazel Kit',
        description = msg,
        type = ok and 'success' or 'error'
    })
    TriggerEvent('chat:addMessage', {
        color = ok and { 60, 220, 60 } or { 255, 60, 60 },
        multiline = true,
        args = { 'Weazel Kit', msg or 'Comando executado.' }
    })
end, false)

RegisterCommand('daritensweazel', function(source, args)
    ExecuteCommand('weazelkit ' .. (args[1] or 'full'))
end, false)

RegisterCommand('limparweazel', function()
    local ok, msg = lib.callback.await('vp_newspaper:server:adminGiveKit', false, 'clear')
    lib.notify({
        title = 'Weazel Kit',
        description = msg,
        type = ok and 'success' or 'error'
    })
end, false)

-- Comandos Rápidos de Emprego (Client-Side)
RegisterCommand('setweazel', function(source, args)
    local grade = tonumber(args and args[1]) or 4
    local ok, msg = lib.callback.await('vp_newspaper:server:adminSetJob', false, 'boss', grade)
    lib.notify({
        title = 'Weazel News',
        description = msg or 'Cargo atualizado com sucesso!',
        type = ok and 'success' or 'error'
    })
    TriggerEvent('chat:addMessage', {
        color = ok and { 60, 220, 60 } or { 255, 60, 60 },
        multiline = true,
        args = { 'Weazel News', msg or 'Cargo atualizado com sucesso!' }
    })
end, false)

RegisterCommand('seteweazel', function(source, args)
    ExecuteCommand('setweazel ' .. (args and args[1] or '4'))
end, false)

RegisterCommand('setreporter', function(source, args)
    ExecuteCommand('setweazel ' .. (args and args[1] or '4'))
end, false)

RegisterCommand('tirarweazel', function()
    local ok, msg = lib.callback.await('vp_newspaper:server:adminSetJob', false, 'unemployed', 0)
    lib.notify({
        title = 'Weazel News',
        description = msg or 'Emprego removido.',
        type = ok and 'success' or 'error'
    })
    TriggerEvent('chat:addMessage', {
        color = { 255, 180, 0 },
        multiline = true,
        args = { 'Weazel News', msg or 'Emprego removido. Você agora é desempregado.' }
    })
end, false)

RegisterNetEvent('vp_newspaper:client:openStaffMenu', function()
    OpenStaffMenu()
end)
