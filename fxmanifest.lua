fx_version 'cerulean'
game 'gta5'

author 'Randolio'

coauthor 'Theo'

description 'Randolio Multi Job for ESX'

shared_scripts { '@ox_lib/init.lua', 'config.lua'}

client_scripts { 'cl_jobs.lua' }

server_scripts { '@oxmysql/lib/MySQL.lua', 'sv_jobs.lua' }

lua54 'yes'
