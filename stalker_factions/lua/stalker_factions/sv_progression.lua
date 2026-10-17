local F=STFW
-- Очки снабжения начисляет доход территорий (sv_treasury.lua, F.AccrueIncome). Здесь — покупка улучшений.
function F.BuyUpgrade(p,a)
 if not F.IsLeader(p) then return false,"unauthorized" end
 local cfg=F.Upgrades[a.upgrade];if not cfg then return false,"denied" end
 local id=F.Load(p).faction;local level=F.UpgradeLevel(F.World,id,a.upgrade)
 if a.level~=level then return false,"stale" end
 local price=cfg.costs[level+1];if not price then return false,"upgrade_max" end
 local w=table.Copy(F.World);local d=F.Prog(w,id)
 if d.credits<price then return false,"supply_low" end
 d.credits=d.credits-price;d.levels[a.upgrade]=level+1
 if not F.Commit(w,{},"upgrade "..p:SteamID64().." "..id.." "..a.upgrade) then return false,"storage" end
 return true
end
