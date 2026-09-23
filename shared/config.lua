Config = {}

-- Framework & Integrações
Config.Framework = 'qb' -- 'qb' ou 'qbox'
Config.UseOxLib = true
Config.UseOxInventory = true
Config.UseOxTarget = true

-- Notificações: 'lation' (lation_ui), 'ox' (ox_lib), ou 'qb'
Config.NotifySystem = 'ox'

Config.General = {
    debugs = false,
    
    -- Webhook do Discord para logs de edição, impressões e transações financeiras
    WebhookURL = '',

    -- Se verdadeiro, as bancas têm estoque limitado e os entregadores precisam reabastecê-las
    isBoxCheckAvailable = true,
    
    -- Nomes dos itens (ox_inventory)
    newspaperItemName = 'newspaper',        -- Jornal legível com NUI
    emptyNewpsaperItemName = 'empty_newspaper', -- Papel de imprensa em branco
    restockBoxesItemName = 'newspaperbox',     -- Caixa de jornais impressos para distribuição

    -- Capacidade máxima de jornais em cada banca
    allowedBoxSpace = 20,

    -- Quantidade máxima de páginas editáveis
    allowedMaxPage = 5,

    -- Preço máximo permitido por jornal (para evitar abuso de economia)
    maxNewspaperPrice = 50,

    -- Cargo e Empresa de Jornalismo
    jobName = 'reporter',
    jobBossGrade = 4,

    -- Recompensa para o entregador ao abastecer uma banca
    restockReward = true,
    restockPerReward = { 35, 70 }, -- Min e Max em dinheiro limpo
    
    -- Veículos de distribuição
    distributorVehicles = {
        'rumpo',
    },
    distributorVehicleLiveries = {
        rumpo = 4,
    },
    
    -- Coordenadas de spawn dos veículos de entrega (Weazel News)
    distributorCoords = {
        vector4(-555.79, -933.59, 23.87, 269.17),
        vector4(-555.68, -937.86, 23.86, 268.83),
        vector4(-556.54, -929.38, 23.88, 270.47),
    },
    -- Ponto para guardar o veículo de entrega
    distributorPutVehicleCoord = vector3(-557.0, -925.05, 23.87),

    -- Pontos de interação no MLO da Weazel News
    Coords = {
        managementCoord = vector3(-581.48, -937.2, 23.78),  -- Gestão / Painel Boss
        distributorCoord = vector3(-556.68, -937.65, 23.85), -- Garagem de entregadores
        printerCoord = vector3(-578.6, -938.18, 23.88),      -- Gráfica / Impressora
        editorCoord = vector3(-577.4, -928.08, 23.78),       -- Computador de Redação / Editor
        getPaperCoord = vector3(-593.42, -934.68, 24.03),     -- Estoque de folhas de jornal
    },

    -- Permissões para criar novas bancas de distribuição no mapa
    creatingBoxes = {
        command = 'criarBancaJornal', -- Comando administrativo
        allowedGroups = { 'admin', 'god', 'manager' },
    },

    -- Prop das bancas de distribuição espalhadas pela cidade
    boxPropModel = joaat('prop_news_disp_02a'),

    -- Bancas fixas iniciais pré-configuradas (caso não use apenas DB)
    defaultBoxes = {
        { id = 1, coords = vector4(-567.45, -922.34, 23.88, 178.5), stock = 15 },
        { id = 2, coords = vector4(229.89, -895.12, 30.69, 250.0), stock = 15 },
        { id = 3, coords = vector4(-262.15, -964.78, 31.22, 205.0), stock = 15 },
        { id = 4, coords = vector4(147.23, -1044.89, 29.37, 70.0), stock = 15 },
        { id = 5, coords = vector4(-1052.32, -232.18, 44.02, 115.0), stock = 15 },
    }
}

-- Blips no Mapa
Config.Blips = {
    weazelNews = {
        coords = vector3(-581.48, -937.2, 23.78),
        sprite = 184,
        display = 4,
        scale = 0.8,
        color = 1,
        title = 'Weazel News'
    }
}

-- Compatibilidade retroativa com NMConfig para o frontend NUI
NMConfig = Config
NMConfig.Framework = Config.Framework
NMConfig.General = Config.General
NMConfig.SQL = { ['oxmysql'] = true, ['ghmattimysql'] = false }
NMConfig.Target = { targetType = 'ox', contextMenu = 'ox' }
