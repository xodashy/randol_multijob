local Config = lib.require('config')

local currentDutyStatus = false

local function showMultijob()
    local PlayerData = ESX.GetPlayerData()
    local myJobs = lib.callback.await('randol_multijob:server:myJobs', false)
    
    currentDutyStatus = false
    if myJobs then
        for _, job in ipairs(myJobs) do
            if job.job == PlayerData.job.name then
                currentDutyStatus = job.onduty or false
                break
            end
        end
    end
    
    local jobMenu = {
        id = 'job_menu',
        title = 'My Jobs',
        options = {},
    }
    
    if Config.EnableDutySystem then
        local canGoOnDuty = false
        for _, job in ipairs(Config.DutyJobs) do
            if job == PlayerData.job.name then
                canGoOnDuty = true
                break
            end
        end
        
        if canGoOnDuty then
            local dutyStatus = currentDutyStatus and 'On Duty' or 'Off Duty'
            local dutyIcon = currentDutyStatus and 'fa-solid fa-toggle-on' or 'fa-solid fa-toggle-off'
            local colorIcon = currentDutyStatus and '#5ff5b4' or 'red'
            
            jobMenu.options[#jobMenu.options + 1] = {
                title = 'Toggle Duty',
                description = 'Current Status: ' .. dutyStatus,
                icon = dutyIcon,
                iconColor = colorIcon,
                onSelect = function()
                    TriggerServerEvent('randol_multijob:server:toggleDuty')
                    Wait(500)
                    showMultijob()
                end,
            }
        end
    end
    if myJobs then
        for _, job in ipairs(myJobs) do
            local isDisabled = PlayerData.job.name == job.job
            jobMenu.options[#jobMenu.options + 1] = {
                title = job.jobLabel,
                description = ('Grade: %s [%s]\nSalary: $%s'):format(job.gradeLabel, tonumber(job.grade), job.salary),
                icon = Config.JobIcons[job.job] or 'fa-solid fa-briefcase',
                arrow = true,
                disabled = isDisabled,
                event = 'randol_multijob:client:choiceMenu',
                args = {jobLabel = job.jobLabel, job = job.job, grade = job.grade},
            }
        end
        lib.registerContext(jobMenu)
        lib.showContext('job_menu')
    end
end

AddEventHandler('randol_multijob:client:choiceMenu', function(args)
    local displayChoices = {
        id = 'choice_menu',
        title = 'Job Actions',
        menu = 'job_menu',
        options = {
            {
                title = 'Switch Job',
                description = ('Switch your job to: %s'):format(args.jobLabel),
                icon = 'fa-solid fa-circle-check',
                onSelect = function()
                    TriggerServerEvent('randol_multijob:server:changeJob', args.job)
                    Wait(100)
                    showMultijob()
                end,
            },
            {
                title = 'Delete Job',
                description = ('Delete the selected job: %s'):format(args.jobLabel),
                icon = 'fa-solid fa-trash-can',
                onSelect = function()
                    TriggerServerEvent('randol_multijob:server:deleteJob', args.job)
                    Wait(100)
                    showMultijob()
                end,
            },
        }
    }
    lib.registerContext(displayChoices)
    lib.showContext('choice_menu')
end)

RegisterNetEvent('esx:setJob', function()
    TriggerServerEvent('randol_multijob:server:newJob')
end)

RegisterNetEvent('randol_multijob:client:setDutyStatus', function(onduty)
    currentDutyStatus = onduty
end)

lib.addKeybind({
    name = 'myjobs',
    description = 'Multi Job',
    defaultKey = 'F10',
    onPressed = function(self)
        showMultijob()
    end
})
