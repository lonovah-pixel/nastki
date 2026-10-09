local S=STALKER_INV
for _,id in ipairs({"medkit","bandage"}) do
    S.Items[id].OnUse=function(ply,item,inv,def)
        if ply:Health()>=ply:GetMaxHealth() then return false,"Здоровье уже полное" end
        ply:SetHealth(math.min(ply:GetMaxHealth(),ply:Health()+def.stats.health));return true
    end
end
for _,id in ipairs({"food","water"}) do
    S.Items[id].OnUse=function(ply,item,inv,def)
        local stat=def.stats.hunger and "hunger" or "thirst"
        if stat=="hunger" and S.Config.DarkRP.UseHunger and ply.getDarkRPVar and ply.setSelfDarkRPVar then
            local energy=ply:getDarkRPVar("Energy")
            if type(energy)=="number" then
                if energy>=100 then return false,"Сытость уже полная" end
                inv.hunger=math.min(100,energy+def.stats.hunger);ply:setSelfDarkRPVar("Energy",inv.hunger);return true
            end
        end
        if inv[stat]>=100 then return false,"Показатель уже полный" end
        inv[stat]=math.min(100,inv[stat]+def.stats[stat]);return true
    end
end
S.Items.ammo_pistol.OnUse=function(ply,item,inv,def)
    if ply:GiveAmmo(def.ammoCount,def.ammo,true)<=0 then return false,"Боезапас заполнен" end
    return true
end

S.Items.antirad.OnUse=function(p,item,inv)
 if (inv.dose or 0)<=0 then return false,"Облучения нет" end
 inv.dose=math.max(0,inv.dose-40);p:SetNW2Float("stalker_dose",inv.dose);return true
end
