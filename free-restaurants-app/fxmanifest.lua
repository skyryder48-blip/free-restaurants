fx_version 'cerulean'
game 'gta5'

name 'free-restaurants-app'
description 'Food Hub - Restaurant ordering app for LB Phone/Tablet'
author 'free-restaurants'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

-- NOTE: No ui_page directive - LB Phone/Tablet loads the UI in its own iframe
-- The files are served via cfx-nui-resourcename URL

files {
    'ui/dist/index.html',
    'ui/dist/**/*',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'free-restaurants',
}
