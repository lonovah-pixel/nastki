--[[---------------------------------------------------------------------------
STALKER RP: профессии группировок и членство STALKER Factions
---------------------------------------------------------------------------
- Меню F4 DarkRP отключено (F4 — КПК), ручная смена профессии запрещена:
  /stalker, /duty и т. п. работают только для администрации. Профессии
  меняются принудительно (force) — этим модулем, голосованием о понижении
  и командами администратора.
- Вступление (у вербовщика или по приглашению лидера) сразу переводит игрока
  в профессию группировки; если все места заняты — выдаст, когда освободится.
- Вышедший или исключённый (STFW_FactionLeft) сразу возвращается в профессию
  по умолчанию (Сталкер). Таймер страхует случаи без хука (смена данных
  администратором, загрузка профиля).
---------------------------------------------------------------------------]]

local function isMember(ply, faction)
    return ply:GetNW2Bool("stfw_joined", false) and ply:GetNW2String("stfw_faction", "") == faction
end

local function factionTeam(faction)
    for teamID, job in pairs(RPExtraTeams or {}) do
        if job.stalkerFaction == faction then return teamID, job end
    end
end

local function notify(ply, kind, seconds, text)
    if DarkRP and DarkRP.notify then DarkRP.notify(ply, kind, seconds, text) end
end

-- Администрация (ULX/«Комендант», право factions) может сменить профессию вручную.
local function canManage(ply)
    if not IsValid(ply) then return true end
    if ply:IsAdmin() then return true end
    local C = STALKER_CORE
    return C and C.CanAdmin and C.CanAdmin(ply, "factions") == true or false
end

hook.Add("playerCanChangeTeam", "STALKER.Jobs.NoManual", function(ply, teamID, force)
    if force or canManage(ply) then return end
    return false, "Профессию выдаёт группировка: вступите у вербовщика или по приглашению лидера (F6)."
end)

-- Выдать профессию группировки; при нехватке мест — запомнить и выдать позже.
local function assignFactionJob(ply, faction)
    local teamID, job = factionTeam(faction)
    if not teamID then ply.StalkerJobPending = nil; return false end
    if ply:Team() == teamID then ply.StalkerJobPending = nil; return true end
    if job.max and job.max > 0 and team.NumPlayers(teamID) >= job.max then
        if ply:Team() ~= GAMEMODE.DefaultTeam then ply:changeTeam(GAMEMODE.DefaultTeam, true) end
        if ply.StalkerJobPending ~= teamID then
            notify(ply, 1, 6, "Все места профессии «" .. job.name .. "» заняты. Профессия выдастся сама, когда освободится место.")
        end
        ply.StalkerJobPending = teamID
        return false
    end
    ply.StalkerJobPending = nil
    ply:changeTeam(teamID, true)
    return true
end

hook.Add("STFW_FactionChanged", "STALKER.Jobs.AutoJoin", function(ply, faction)
    if not IsValid(ply) then return end
    assignFactionJob(ply, faction)
end)

-- Выход или исключение: профессия прежней группировки снимается сразу.
hook.Add("STFW_FactionLeft", "STALKER.Jobs.Left", function(ply, oldFaction)
    if not IsValid(ply) or not GAMEMODE or not GAMEMODE.DefaultTeam then return end
    ply.StalkerJobPending = nil
    local job = RPExtraTeams and RPExtraTeams[ply:Team()]
    if job and job.stalkerFaction and (job.stalkerFaction == oldFaction or not isMember(ply, job.stalkerFaction)) then
        ply:changeTeam(GAMEMODE.DefaultTeam, true)
        notify(ply, 0, 6, "Вы больше не состоите в группировке — профессия сброшена на «Сталкер».")
    end
end)

timer.Create("STALKER.Jobs.Membership", 5, 0, function()
    if not GAMEMODE or not GAMEMODE.DefaultTeam then return end
    for _, ply in ipairs(player.GetHumans()) do
        local job = RPExtraTeams and RPExtraTeams[ply:Team()]
        if job and job.stalkerFaction and not isMember(ply, job.stalkerFaction) then
            ply.StalkerJobPending = nil
            ply:changeTeam(GAMEMODE.DefaultTeam, true)
            notify(ply, 1, 6, "Вы не состоите в группировке этой профессии — профессия сброшена на «Сталкер».")
        elseif ply.StalkerJobPending then
            -- Ждёт свободного места в профессии своей группировки.
            local pending = RPExtraTeams and RPExtraTeams[ply.StalkerJobPending]
            if pending and pending.stalkerFaction and isMember(ply, pending.stalkerFaction) then
                assignFactionJob(ply, pending.stalkerFaction)
            else
                ply.StalkerJobPending = nil
            end
        end
    end
end)
