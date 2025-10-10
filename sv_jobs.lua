local Config = lib.require('config')

local function GetJobCount(cid)
    local result = MySQL.query.await('SELECT COUNT(*) as jobCount FROM save_jobs WHERE cid = ?', {cid})
    local jobCount = result[1].jobCount
    return jobCount
end

local function CanSetJob(cid, jobName)
    local jobs = MySQL.query.await('SELECT job, grade FROM save_jobs WHERE cid = ? ', {cid})
    if not jobs then return false end
    for i = 1, #jobs do
        if jobs[i].job == jobName then
            return true, jobs[i].grade
        end
    end
    return false
end

lib.callback.register('randol_multijob:server:myJobs', function(source)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local storeJobs = {}
    local result = MySQL.query.await('SELECT * FROM save_jobs WHERE cid = ?', {xPlayer.identifier})
    for k, v in pairs(result) do
        local jobData = ESX.GetJobs()[v.job]

        if not jobData then 
            return error(('MISSING JOB FROM jobs.lua: "%s" | IDENTIFIER: %s'): format(v.job, xPlayer.identifier)) 
        end
        
        local grade = jobData.grades[tostring(v.grade)]

        if not grade then 
            return error(('MISSING JOB GRADE for "%s". GRADE MISSING: %s | IDENTIFIER: %s'): format(v.job, v.grade, xPlayer.identifier)) 
        end

        local salary = grade.salary or grade.grade_salary or 0

        storeJobs[#storeJobs + 1] = {
            job = v.job,
            salary = salary,
            jobLabel = jobData.label,
            gradeLabel = grade.label,
            grade = v.grade,
            onduty = v.onduty or false,
        }
    end
    return storeJobs
end)

RegisterNetEvent('randol_multijob:server:changeJob', function(job)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if xPlayer.job.name == job then 
        TriggerClientEvent('esx:showNotification', src, 'Your current job is already set to this.') 
        return 
    end

    local jobInfo = ESX.GetJobs()[job]
    if not jobInfo then 
        TriggerClientEvent('esx:showNotification', src, 'Invalid job.') 
        return 
    end

    local cid = xPlayer.identifier
    local canSet, grade = CanSetJob(cid, job)
    
    if not canSet then 
        return 
    end

    xPlayer.setJob(job, grade)
    
    local result = MySQL.query.await('SELECT onduty FROM save_jobs WHERE cid = ? AND job = ?', {cid, job})
    local onduty = result[1] and result[1].onduty == 1
    
    TriggerClientEvent('esx:showNotification', src, 'Your job is now: ' .. jobInfo.label)
    TriggerClientEvent('randol_multijob:client:setDutyStatus', src, onduty)
end)

RegisterNetEvent('randol_multijob:server:newJob', function(newJob)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local hasJob = false
    local cid = xPlayer.identifier
    if newJob.name == 'unemployed' then return end
    local result = MySQL.query.await('SELECT * FROM save_jobs WHERE cid = ? AND job = ?', {cid, newJob.name}) 
    if result[1] then
        MySQL.query.await('UPDATE save_jobs SET grade = ? WHERE job = ? and cid = ?', {newJob.grade, newJob.name, cid})
        hasJob = true
        return
    end
    if not hasJob and GetJobCount(cid) < Config.MaxJobs then 
        MySQL.insert.await('INSERT INTO save_jobs (cid, job, grade, onduty) VALUE (?, ?, ?, ?)', {cid, newJob.name, newJob.grade, 0})
    else
        return TriggerClientEvent('esx:showNotification', src, 'You have the max amount of jobs.')
    end
end)

RegisterNetEvent('randol_multijob:server:deleteJob', function(job)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    MySQL.query.await('DELETE FROM save_jobs WHERE cid = ? and job = ?', {xPlayer.identifier, job})
    local jobInfo = ESX.GetJobs()[job]
    TriggerClientEvent('esx:showNotification', src, 'You deleted '..jobInfo.label..' job from your menu.')
    if xPlayer.job.name == job then
        xPlayer.setJob('unemployed', 0)
    end
end)

RegisterNetEvent('randol_multijob:server:toggleDuty', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local currentJob = xPlayer.job.name
    
    if not Config.EnableDutySystem then
        TriggerClientEvent('esx:showNotification', src, 'Duty system is disabled.')
        return
    end
    
    local canGoOnDuty = false
    for _, job in ipairs(Config.DutyJobs) do
        if job == currentJob then
            canGoOnDuty = true
            break
        end
    end
    
    if not canGoOnDuty then
        TriggerClientEvent('esx:showNotification', src, 'This job cannot go on duty.')
        return
    end
    
    local result = MySQL.query.await('SELECT onduty FROM save_jobs WHERE cid = ? AND job = ?', {xPlayer.identifier, currentJob})
    
    if result[1] then
        local currentDutyStatus = result[1].onduty
        local newDutyStatus
        
        if currentDutyStatus == 1 or currentDutyStatus == true then
            newDutyStatus = 0
        else
            newDutyStatus = 1
        end
        
        MySQL.query.await('UPDATE save_jobs SET onduty = ? WHERE cid = ? AND job = ?', {newDutyStatus, xPlayer.identifier, currentJob})
        
        local dutyText = newDutyStatus == 1 and 'on duty' or 'off duty'
        TriggerClientEvent('esx:showNotification', src, 'You are now ' .. dutyText)
        TriggerClientEvent('randol_multijob:client:setDutyStatus', src, newDutyStatus == 1)
    else
        TriggerClientEvent('esx:showNotification', src, 'Job not found in your saved jobs.')
    end
end)

local function adminRemoveJob(src, id, job)
    local xPlayer = ESX.GetPlayerFromId(id)
    local cid = xPlayer.identifier
    local result = MySQL.query.await('SELECT * FROM save_jobs WHERE cid = ? AND job = ?', {cid, job})
    if result[1] then
        MySQL.query.await('DELETE FROM save_jobs WHERE cid = ? AND job = ?', {cid, job})
        TriggerClientEvent('esx:showNotification', src, ('Job: %s was removed from ID: %s'):format(job, id))
        if xPlayer.job.name == job then
            xPlayer.setJob('unemployed', 0)
        end
    else
        TriggerClientEvent('esx:showNotification', src, 'Player doesn\'t have this job?')
    end
end

ESX.RegisterCommand('removejob', 'admin', function(xPlayer, args, showError)
    local src = xPlayer.source
    if not args.playerId then 
        TriggerClientEvent('esx:showNotification', src, 'Must provide a player id.') 
        return 
    end
    if not args.job then 
        TriggerClientEvent('esx:showNotification', src, 'Must provide the name of the job to remove from the player.') 
        return 
    end
    local id = tonumber(args.playerId)
    local targetPlayer = ESX.GetPlayerFromId(id)
    if not targetPlayer then TriggerClientEvent('esx:showNotification', src, 'Player not online.') return end

    adminRemoveJob(src, id, args.job)
end, true, {help = "Remove a job from the player's multijob.", validate = true, arguments = {
    {name = 'playerId', help = 'ID of the player', type = 'player'},
    {name = 'job', help = 'Name of Job', type = 'string'}
}})

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    MySQL.query([=[
        CREATE TABLE IF NOT EXISTS `save_jobs` (
            `cid` VARCHAR(100) NOT NULL,
            `job` VARCHAR(100) NOT NULL,
            `grade` INT(11) NOT NULL,
            `onduty` TINYINT(1) DEFAULT 0
        );
    ]=])
end)
