fx_version 'cerulean'
game 'gta5'

name 'free-restaurants'
author 'Your Name'
description 'Comprehensive restaurant framework for QBox - Multi-location, player jobs, and business management'
version '1.0.0'
repository 'https://github.com/yourusername/free-restaurants'

lua54 'yes'

-- Dependencies
dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql',
}

-- Shared files (loaded on both client and server)
shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/utils.lua',
    'config/settings.lua',
    'config/jobs.lua',
    'config/recipes.lua',
    'config/locations.lua',
}

-- Client scripts
client_scripts {
    'client/main.lua',
    'client/duty.lua',
    'client/stations.lua',
    'client/cooking.lua',
    'client/orders.lua',
    'client/customers.lua',
    'client/management.lua',
    'client/delivery.lua',
    'client/progression.lua',
    'client/tablet.lua',
    'client/npc-customers.lua',
    'client/cleaning.lua',
}

-- Server scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/stations.lua',
    'server/main.lua',
    'server/banking.lua',
    'server/duty.lua',
    'server/stations.lua',
    'server/crafting.lua',
    'server/customers.lua',
    'server/management.lua',
    'server/progression.lua',
    'server/decay.lua',
    'server/delivery.lua',
    'server/inspection.lua',
    'server/npc-customers.lua',
}

-- NUI files
ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/**/*.html',
    'ui/**/*.js',
    'ui/**/*.css',
    'lb-tablet-app/ui/**/*.html',
    'lb-tablet-app/ui/**/*.js',
    'lb-tablet-app/ui/**/*.css',
    'lb-tablet-app/ui/**/*.png',
    'locales/*.json',
}

-- Ox lib configuration
ox_libs {
    'locale',
    'table',
    'math',
}

-- Provide exports for external integration
provides {
    'free-restaurants',
}
