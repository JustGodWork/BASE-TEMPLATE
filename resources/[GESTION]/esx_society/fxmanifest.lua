fx_version 'adamant'

game 'gta5'

description 'ESX Society'

version '1.6.0'

shared_script '@es_extended/imports.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@es_extended/locale.lua',
    'locales/br.lua',
    'locales/en.lua',
    'locales/es.lua',
    'locales/fi.lua',
    'locales/fr.lua',
    'locales/sv.lua',
    'locales/pl.lua',
    'locales/nl.lua',
    'locales/cs.lua',
    'locales/tr.lua',
    'config.lua',
    'server/main.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'locales/br.lua',
    'locales/en.lua',
    'locales/es.lua',
    'locales/fi.lua',
    'locales/fr.lua',
    'locales/sv.lua',
    'locales/pl.lua',
    'locales/nl.lua',
    'locales/cs.lua',
    'locales/tr.lua',
    'config.lua',
    "client/libs/RMenu.lua", -- NE PAS TOUCHER
    "client/libs/menu/RageUI.lua", -- NE PAS TOUCHER
    "client/libs/menu/Menu.lua", -- NE PAS TOUCHER
    "client/libs/menu/MenuController.lua", -- NE PAS TOUCHER
    "client/libs/components/*.lua", -- NE PAS TOUCHER
    "client/libs/menu/elements/*.lua", -- NE PAS TOUCHER
    "client/libs/menu/items/*.lua", -- NE PAS TOUCHER
    "client/libs/menu/panels/*.lua", -- NE PAS TOUCHER
    "client/libs/menu/panels/*.lua", -- NE PAS TOUCHER
    "client/libs/menu/windows/*.lua", -- NE PAS TOUCHER
    "client/libs/RageUtils.lua", -- NE PAS TOUCHER
}

client_scripts {
    'client/main.lua'
}

dependencies {
    'es_extended',
    'cron',
    'esx_addonaccount'
}
