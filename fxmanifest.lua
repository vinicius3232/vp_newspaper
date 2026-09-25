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
    'web/poster_dui.html',
    'web/newsroom_live.html',
    'web/radio_player.html',
    'web/radio_audio.js',
    'web/*.js',
    'web/*.png',
    'web/cards/*.png',
    'web/papers/**/*.jpg',
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
    'client/posters.lua',
    'client/media.lua',
    'client/radio.lua',
    'client/speakers_attach.lua',
    'client/broadcast_van.lua',
    'client/newsroom_display.lua',
    'client/cards.lua',
    'client/field.lua',
    'client/throw.lua',
    'client/admin.lua',
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
    'server/posters.lua',
    'server/media.lua',
    'server/radio.lua',
    'server/speakers_attach.lua',
    'server/broadcast_van.lua',
    'server/cards.lua',
    'server/field.lua',
    'server/throw.lua',
    'server/admin.lua',
    'server/modules/oxmysql_smoke.lua',
}

this_is_a_map 'yes'
data_file 'DLC_ITYP_REQUEST' 'stream/int_wnews.ytyp'

dependencies {
    'ox_lib',
    'oxmysql',
}
