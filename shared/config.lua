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

    -- Sistema de Colecionáveis: Trading Cards, Boosters & PSA Grading
    Collectibles = {
        enabled = true,
        items = {
            card = 'card',
            boosterPack = 'booster_pack',
            psaCase = 'psa_case',
            comicBook = 'comic_book',
        },
        rarities = {
            basic = { label = 'Comum', color = '#94a3b8', weight = 70, effect = 'none' },
            rare = { label = 'Rara', color = '#38bdf8', weight = 24, effect = 'sparkles' },
            legendary = { label = 'Lendária', color = '#fbbf24', weight = 6, effect = 'shine' },
        },
        cards = {
            ['card_mayor'] = { id = 'card_mayor', rarity = 'legendary', title = 'O Prefeito de Los Santos', description = 'Retrato oficial da posse na prefeitura.', image = 'cards/mayor.png' },
            ['card_tycoon'] = { id = 'card_tycoon', rarity = 'legendary', title = 'O Magnata de Los Santos', description = 'Investimentos bilionários na bolsa de valores.', image = 'cards/tycoon.png' },
            ['card_presstycoon'] = { id = 'card_presstycoon', rarity = 'legendary', title = 'O Barão da Imprensa', description = 'Fundador da maior rede de notícias do estado.', image = 'cards/presstycoon.png' },
            ['card_heist'] = { id = 'card_heist', rarity = 'legendary', title = 'O Golpe do Século', description = 'O assalto mais ousado aos cofres da Union Depository.', image = 'cards/heist.png' },
            ['card_prisonbreak'] = { id = 'card_prisonbreak', rarity = 'legendary', title = 'Fuga de Bolingbroke', description = 'A histórica quebra da penitenciária estadual.', image = 'cards/prisonbreak.png' },
            ['card_anchor'] = { id = 'card_anchor', rarity = 'rare', title = 'Âncora do Telejornal', description = 'A voz de confiança nas noites de San Andreas.', image = 'cards/anchor.png' },
            ['card_editor'] = { id = 'card_editor', rarity = 'rare', title = 'Editor-Chefe da Weazel', description = 'A caneta implacável que define as manchetes.', image = 'cards/editor.png' },
            ['card_actor'] = { id = 'card_actor', rarity = 'rare', title = 'Astro de Vinewood', description = 'O galã mais aclamado das telonas.', image = 'cards/actor.png' },
            ['card_athlete'] = { id = 'card_athlete', rarity = 'rare', title = 'Campeão do Maze Bank Arena', description = 'A lenda do basquete de Los Santos.', image = 'cards/athlete.png' },
            ['card_casino'] = { id = 'card_casino', rarity = 'rare', title = 'Diamond Casino & Resort', description = 'Noites de fortuna e apostas de alto risco.', image = 'cards/casino.png' },
            ['card_bank'] = { id = 'card_bank', rarity = 'rare', title = 'Cofre do Pacific Standard', description = 'O epicentro financeiro da metrópole.', image = 'cards/bank.png' },
            ['card_chef'] = { id = 'card_chef', rarity = 'rare', title = 'Chef Cinco Estrelas', description = 'Culinária refinada nos restaurantes de Rockford.', image = 'cards/chef.png' },
            ['card_dj'] = { id = 'card_dj', rarity = 'rare', title = 'DJ da Weazel Radio 98.5', description = 'Batidas lendárias nas madrugadas da rádio.', image = 'cards/dj.png' },
            ['card_influencer'] = { id = 'card_influencer', rarity = 'rare', title = 'Influencer de Del Perro', description = 'Milhões de seguidores e polêmicas virais.', image = 'cards/influencer.png' },
            ['card_scandal'] = { id = 'card_scandal', rarity = 'rare', title = 'O Escândalo Político', description = 'Vazamento de documentos que abalou a câmara.', image = 'cards/scandal.png' },
            ['card_storm'] = { id = 'card_storm', rarity = 'rare', title = 'A Grande Tempestade', description = 'O furacão histórico que atingiu o litoral.', image = 'cards/storm.png' },
            ['card_streetrace'] = { id = 'card_streetrace', rarity = 'rare', title = 'Racha no Canal de LS', description = 'Motores roncando na clandestinidade urbana.', image = 'cards/streetrace.png' },
            ['card_vinewood'] = { id = 'card_vinewood', rarity = 'rare', title = 'Letreiro de Vinewood', description = 'O símbolo máximo do glamour californiano.', image = 'cards/vinewood.png' },
            ['card_observatory'] = { id = 'card_observatory', rarity = 'basic', title = 'Observatório Galileu', description = 'A vista panorâmica mais clássica da cidade.', image = 'cards/observatory.png' },
            ['card_pier'] = { id = 'card_pier', rarity = 'basic', title = 'Píer Del Perro', description = 'Roda gigante e tardes ensolaradas à beira-mar.', image = 'cards/pier.png' },
            ['card_lighthouse'] = { id = 'card_lighthouse', rarity = 'basic', title = 'Farol de El Gordo', description = 'Guia solitário dos mares do norte.', image = 'cards/lighthouse.png' },
            ['card_market'] = { id = 'card_market', rarity = 'basic', title = 'Mercado de Pulgas', description = 'Achados e relíquias no centro antigo.', image = 'cards/market.png' },
            ['card_paperboy'] = { id = 'card_paperboy', rarity = 'basic', title = 'O Jovem Paperboy', description = 'Pedaladas velozes entregando as notícias matinais.', image = 'cards/paperboy.png' },
            ['card_photog'] = { id = 'card_photog', rarity = 'basic', title = 'Fotojornalista Weazel', description = 'O clique rápido que flagra a verdade.', image = 'cards/photog.png' },
            ['card_reporter'] = { id = 'card_reporter', rarity = 'basic', title = 'Repórter Investigativo', description = 'A apuração que não descansa até encontrar o furo.', image = 'cards/reporter.png' },
            ['card_columnist'] = { id = 'card_columnist', rarity = 'basic', title = 'Cronista da Cidade', description = 'Artigos mordazes sobre o cotidiano urbano.', image = 'cards/columnist.png' },
            ['card_pickpocket'] = { id = 'card_pickpocket', rarity = 'basic', title = 'Ladrão de Carteiras', description = 'O aviso clássico de segurança na Legion Square.', image = 'cards/pickpocket.png' },
            ['card_protest'] = { id = 'card_protest', rarity = 'basic', title = 'Manifestação Popular', description = 'Cidadãos erguendo cartazes por justiça.', image = 'cards/protest.png' },
        },
        comics = {
            ['comic_book_1'] = { id = 'comic_book_1', title = 'O Mistério de Mount Chiliad #1', totalPages = 4, folder = 'papers/comic_book_1' },
            ['comic_book_2'] = { id = 'comic_book_2', title = 'Crônicas de Los Santos #2', totalPages = 5, folder = 'papers/comic_book_2' },
        },
        boosters = {
            ['booster_common'] = { name = 'Pacote Weazel Básico', tier = 'common', count = 3, weights = { basic = 80, rare = 18, legendary = 2 } },
            ['booster_premium'] = { name = 'Pacote Weazel Ouro', tier = 'premium', count = 5, weights = { basic = 50, rare = 40, legendary = 10 } },
        },
        grading = {
            cost = 100,
            openingTimeMs = 4000,
        },
        customCards = {
            enabled = true,
            cost = 500,
            minGrade = 2, -- Editor ou Chefe da Weazel News
            defaultSet = 'Edição Comemorativa Weazel',
        },
    },

    -- Jornalismo de Campo: Spots de Reportagem, Entrevistas & Pautas Ativas (vp_leads)
    FieldJournalism = {
        enabled = true,
        acceptChance = 0.85,
        cooldownSeconds = 180,
        rewardRange = { 150, 300 },
        spots = {
            { id = 'spot_cityhall', name = 'Entrevista na Prefeitura', type = 'interview', coords = vector3(-545.0, -204.0, 38.2), heading = 210.0, npcModel = 'a_m_m_business_01', headlineSeed = 'Prefeitura anuncia novo plano de infraestrutura urbana' },
            { id = 'spot_lspd', name = 'Boletim da LSPD (Mission Row)', type = 'interview', coords = vector3(441.2, -982.0, 30.68), heading = 90.0, npcModel = 's_m_y_cop_01', headlineSeed = 'LSPD divulga balanço de apreensões e combate ao crime' },
            { id = 'spot_pillbox', name = 'Plantão Médico no Hospital Pillbox', type = 'footage', coords = vector3(308.5, -595.0, 43.28), heading = 18.0, npcModel = 's_m_m_doctor_01', headlineSeed = 'Hospital Central registra recorde de atendimentos de emergência' },
            { id = 'spot_legion', name = 'Voz do Cidadão na Praça Legion', type = 'interview', coords = vector3(193.5, -934.0, 30.68), heading = 140.0, npcModel = 'a_f_y_hipster_01', headlineSeed = 'População opina sobre segurança pública no centro' },
            { id = 'spot_dock', name = 'Movimentação Suspeita nas Docas', type = 'footage', coords = vector3(-153.0, -2385.0, 6.0), heading = 50.0, npcModel = 's_m_y_dockwork_01', headlineSeed = 'Investigação especial: logística portuária e fiscalização' },
        },
    },

    -- Entrega Paperboy: Rota Ágil de Bicicleta com Arremesso Físico
    Paperboy = {
        enabled = true,
        bikeModel = 'cruiser',
        spawnCoord = vector4(-552.0, -943.0, 23.85, 270.0),
        returnCoord = vector3(-553.5, -940.0, 23.85),
        throwCooldownMs = 2500,
        maxThrowDistance = 18.0,
        dailyLimit = 50,
        rewardPerThrow = { 45, 85 },
        throwTargets = {
            { id = 1, coords = vector3(-567.45, -922.34, 23.88), label = 'Banca Weazel Plaza' },
            { id = 2, coords = vector3(-605.0, -960.0, 22.0), label = 'Residência Alta St' },
            { id = 3, coords = vector3(-630.0, -890.0, 24.5), label = 'Apartamento Vespucci Blvd' },
            { id = 4, coords = vector3(-520.0, -870.0, 27.0), label = 'Comércio Boulevard Del Perro' },
            { id = 5, coords = vector3(-480.0, -920.0, 23.5), label = 'Edifício Comercial Rockford' },
            { id = 6, coords = vector3(-450.0, -980.0, 23.8), label = 'Entrada Sul San Andreas Ave' },
        },
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
