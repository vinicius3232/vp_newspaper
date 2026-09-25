Config = {}

-- Framework & Integrações
Config.Framework = 'qb' -- 'qb' ou 'qbox'
Config.UseOxLib = true
Config.UseOxInventory = true
Config.UseOxTarget = true

-- Notificações: 'lation' (lation_ui), 'ox' (ox_lib), ou 'qb'
Config.NotifySystem = 'ox'

Config.General = {
    debugs = true,
    allowTestCommands = true, -- Permite que qualquer jogador execute comandos de teste (/weazeltest, /weazelkit, /setweazel) sem restrição de permissão ACE em ambiente de desenvolvimento
    
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

    -- Módulo de Posters e Cartazes de Parede (DUI & Raycasting)
    Posters = {
        enabled = true,
        itemName = 'poster',                -- Item de inventário para colar cartazes
        removerItemName = 'poster_remover', -- Item para remover/rasgar cartazes (ou faca)
        streamDistance = 18.0,              -- Distância de streaming lib.points (ativação do DUI)
        drawDistance = 15.0,                -- Distância de desenho DrawSpritePoly
        defaultWidth = 0.7,                 -- Largura padrão em metros no mundo
        defaultHeight = 1.0,                -- Altura padrão em metros no mundo
        maxPlayerPosters = 10,              -- Limite de posters ativos por jogador comum
        reportersUnlimited = true,          -- Repórteres Weazel News sem limite
        allowPoliceRemove = true,           -- Policiais e repórteres podem remover qualquer cartaz
        duiResolution = { width = 512, height = 512 },
    },

    -- Kit de Reportagem Weazel News & Plantão Urgente (Breaking News)
    Media = {
        enabled = true,
        items = {
            camera = 'news_camera',
            mic = 'news_mic',
            boom = 'news_boom',
        },
        props = {
            camera = {
                model = 'prop_v_cam_01',
                bone = 28422, -- SKEL_R_Hand
                offset = vector3(0.0, 0.0, 0.0),
                rot = vector3(0.0, 0.0, 0.0),
                animDict = 'missfinale_c2mcs_1',
                animClip = 'fin_c2_mcs_1_camman',
            },
            mic = {
                model = 'p_ing_microphonel_01',
                bone = 60309, -- SKEL_L_Hand
                offset = vector3(0.055, 0.05, 0.0),
                rot = vector3(240.0, 0.0, 0.0),
                animDict = 'missfra1mcs_2_crew_react',
                animClip = 'reaction_c_idle',
            },
            boom = {
                model = 'prop_v_bmike_01',
                bone = 28422, -- SKEL_R_Hand
                offset = vector3(-0.08, 0.0, 0.0),
                rot = vector3(0.0, -85.0, 0.0),
                animDict = 'missfinale_c2mcs_1',
                animClip = 'fin_c2_mcs_1_camman',
            }
        },
        breakingNews = {
            cooldownSeconds = 60,       -- Cooldown entre plantões no servidor
            durationMs = 9000,          -- Tempo de exibição na tela do cidadão
            minGrade = 2,               -- Grau mínimo para emitir plantão
            sound = true,               -- Tocar vinheta de alerta ao vivo
        }
    },

    -- Weazel Radio 98.5 FM & Estúdio de Transmissão (Broadcasting Studio)
    Radio = {
        enabled = true,
        stationName = 'Weazel News Radio 98.5 FM',
        frequency = '98.5',
        djMinGrade = 1,                 -- Grau mínimo na Weazel News para controlar a mesa de som
        items = {
            headphones = 'headphones',          -- Fone de ouvido para escuta individual
            portableRadio = 'radio_portable',   -- Rádio portátil para colocar no chão
        },
        portableProp = joaat('prop_boombox_01'),
        portableAudioDistance = 20.0,   -- Distância máxima de audição em metros
        defaultVolume = 65,             -- Volume padrão (0-100)
        radioAcousticFilter = true,     -- Ativa simulação analógica FM (BiquadFilter)
        defaultTracks = {}
    },

    -- ==========================================================
    -- Tipos de Caixa de Som Portátil (RAHE Multi-Tier System)
    -- ==========================================================
    SpeakerTypes = {
        retro = {
            label        = 'Boombox Retrô',
            item         = 'speaker_retro',
            price        = 250,
            description  = 'Boombox clássico — ombro direito. Alcance até 35m.',
            model        = joaat('prop_boombox_01'),
            maxVolume    = 1.0,    -- Volume máximo permitido (0.1 - 2.0)
            maxRange     = 35.0,   -- Alcance máximo em metros
            carryType    = 'shoulder', -- 'shoulder' = ombro direito
            bone         = 57005,  -- SKEL_R_Hand
            attachOffset = vector3(0.27, 0.0, 0.0),
            attachRot    = vector3(0.0, 263.0, 58.0),
            eqPreset     = 'broadcast',
            icon         = '📻',
        },
        vibe = {
            label        = 'Speaker Vibe',
            item         = 'speaker_vibe',
            price        = 750,
            description  = 'Caixa de som compacta com graves reforçados. Alcance até 65m.',
            model        = joaat('prop_speaker_03'),
            maxVolume    = 1.5,
            maxRange     = 65.0,
            carryType    = 'box_carry', -- Duas mãos
            bone         = 28422,  -- SKEL_R_Hand
            attachOffset = vector3(0.0, 0.0, -0.1),
            attachRot    = vector3(0.0, 0.0, 0.0),
            eqPreset     = 'bass',
            icon         = '🔊',
        },
        beat = {
            label        = 'Beat Speaker Pro',
            item         = 'speaker_beat',
            price        = 1800,
            description  = 'Caixa de som profissional de clube com alta definição. Alcance até 100m.',
            model        = joaat('h4_prop_battle_club_speaker_med'),
            maxVolume    = 1.8,
            maxRange     = 100.0,
            carryType    = 'box_carry',
            bone         = 28422,
            attachOffset = vector3(0.0, 0.0, -0.1),
            attachRot    = vector3(0.0, 0.0, 0.0),
            eqPreset     = 'club',
            icon         = '🎵',
        },
        blast = {
            label        = 'Blast Tower Speaker',
            item         = 'speaker_blast',
            price        = 4500,
            description  = 'Torre de som para grandes eventos ao ar livre. Potência máxima e alcance até 150m.',
            model        = joaat('sf_prop_sf_speaker_stand_01a'),
            maxVolume    = 2.0,
            maxRange     = 150.0,
            carryType    = 'box_carry',
            bone         = 28422,
            attachOffset = vector3(0.0, 0.0, -0.1),
            attachRot    = vector3(0.0, 0.0, 0.0),
            eqPreset     = 'outdoor',
            icon         = '📢',
        },
    },

    -- Loja de Caixas de Som (Rahe Speaker Shop)
    SpeakerShop = {
        enabled = true,
        coords = vector4(-42.53, -1039.37, 27.41, 23.18),
        pedModel = joaat('s_m_y_shop_mask'),
        blip = {
            enabled = true,
            sprite = 52,
            color = 2,
            scale = 0.75,
            name = 'Loja de Caixas de Som',
        }
    },

    -- Sistema de Caixas de Som Veiculares (Inspirado no Rahe Speakers Audio System)
    VehicleSpeakers = {
        enabled = true,
        maxDistance = 5.0,
        audioDistance = 25.0,
        allowedPoints = { 'trunk', 'roof', 'bed' },
        defaultPoint = 'trunk',
    },

    -- Unidade Móvel de Transmissão (Van Rig / Broadcast Mast) - Inspirado em Senora Signalworks
    BroadcastVan = {
        enabled = true,
        allowedModels = {
            'rumpo',
            'rumpo3',
            'burrito',
            'burrito3',
            'speedo',
        },
        antennaProp = 'prop_air_mast_01',
        attachBone = 'bodyshell',
        attachOffset = vector3(0.0, -1.2, 1.45),
        attachRot = vector3(0.0, 0.0, 0.0),
        deployTimeMs = 4500,
        maxDeploySpeed = 0.8,
        maxInteractionDistance = 5.0,
        minGrade = 1,
        signalCalculation = {
            baseSignal = 50,
            maxAltitude = 160.0,
            altitudeWeight = 40.0,
            overheadObstructionCheck = true,
            obstructionDistance = 25.0,
            obstructionPenalty = 45,
            badWeatherPenalty = 15,
        }
    },

    -- Monitor 3D da Redação Central (DUI Wall Display na Weazel News)
    NewsroomDisplay = {
        enabled = true,
        coords = vector3(-578.5, -934.0, 25.5),
        heading = 270.0,
        width = 2.4,
        height = 1.35,
        streamDistance = 22.0,
        drawDistance = 18.0,
        duiResolution = { width = 1024, height = 576 },
        defaultHeadline = 'WEAZEL NEWS: A VERDADE EM TEMPO REAL',
        defaultSubtitle = 'Redação Central de Los Santos — Plantão 24 Horas',
        category = 'Noticiário Central',
    },

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
