fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vp_newspaper'
author 'Vini'
description 'Sistema Profissional de Jornal e Mídia (Weazel News) para FiveM — Clean Clone do NProbleM Newspaper'
version '2.0.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/script.js',
    'web/styles.css',
    'web/*.png',
    'web/swap.ogg',
    'images/*.png',
    'sql/migrations/*.sql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'locales/locales.lua',
}

client_scripts {
    'client/newspaper.lua',
    'client/editor.lua',
    'client/boxes.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/modules/security.lua',
    'server/modules/operations.lua',
    'server/modules/ledger.lua',
    'server/main.lua',
    'server/newspaper.lua',
    'server/company.lua',
    'server/boxes.lua',
    'server/printing.lua',
}

this_is_a_map 'yes'
data_file 'DLC_ITYP_REQUEST' 'stream/int_wnews.ytyp'

dependencies {
    'ox_lib',
    'oxmysql',
}
