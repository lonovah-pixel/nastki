--[[---------------------------------------------------------------------------
STALKER RP: профессии группировок и членство STALKER Factions
---------------------------------------------------------------------------
- Вступление у вербовщика сразу переводит игрока в профессию группировки.
- Исключённый или сменивший группировку игрок возвращается в профессию
  по умолчанию (Сталкер), если его профессия принадлежит другой группировке.
---------------------------------------------------------------------------]]

local function isMember(ply, faction)
    return ply:GetNW2Bool("stfw_joined", false) and ply:GetNW2String("stfw_faction", "") == faction
end

local function factionTeam(faction)
    for teamID, job in pairs(RPExtraTeams or {}) do
        if job.stalkerFaction == faction then return teamID, job end
    end
end

hook.Add("STFW_FactionChanged", "STALKER.Jobs.AutoJoin", function(ply, faction)
    if not IsValid(ply) then return end
    local teamID, job = factionTeam(faction)
    if not teamID or ply:Team() == teamID then return end
    -- Профессия чужой группировки снимается в любом случае; новая выдаётся, если есть слот.
    if job.max and job.max > 0 and team.NumPlayers(teamID) >= job.max then
        ply:changeTeam(GAMEMODE.DefaultTeam, true)
        DarkRP.notify(ply, 1, 6, "Все места профессии «" .. job.name .. "» заняты. Выберите её позже в F4.")
        return
    end
    ply:changeTeam(teamID, true)
end)

timer.Create("STALKER.Jobs.Membership", 5, 0, function()
    if not GAMEMODE or not GAMEMODE.DefaultTeam then return end
    for _, ply in ipairs(player.GetHumans()) do
        local job = RPExtraTeams and RPExtraTeams[ply:Team()]
        if job and job.stalkerFaction and not isMember(ply, job.stalkerFaction) then
            ply:changeTeam(GAMEMODE.DefaultTeam, true)
            DarkRP.notify(ply, 1, 6, "Вы не состоите в группировке этой профессии — профессия сброшена на «Сталкер».")
        end
    end
end)
