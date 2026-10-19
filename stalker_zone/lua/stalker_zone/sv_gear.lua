-- Защиты костюмов, шлемов, ботинок и артефактов; регенерация и вывод радиации.
local Z=STALKER_ZONE
Z.Gear=Z.Gear or setmetatable({},{__mode="k"})

function Z.RefreshGear(p)
 if not IsValid(p) then return end
 local gear=Z.GearProfile(p.StalkerInventory)
 Z.Gear[p]=gear
 local speed=math.Clamp(gear.speed or 0,-40,30)
 if p:GetNW2Float("stz_speed",0)~=speed then p:SetNW2Float("stz_speed",speed) end
end
hook.Add("STALKER_INV_EquipmentChanged","STALKER_ZONE.Gear",function(p) Z.RefreshGear(p) end)
hook.Add("PlayerSpawn","STALKER_ZONE.Gear",function(p) timer.Simple(.2,function() Z.RefreshGear(p) end) end)

hook.Add("EntityTakeDamage","STALKER_ZONE.Resists",function(ent,dmg)
 if not ent:IsPlayer() then return end
 local gear=Z.Gear[ent];if not gear then return end
 local resist=0
 for stat,types in pairs(Z.Resists) do
  local value=gear[stat]
  if value and value>0 then
   for _,flag in ipairs(types) do if dmg:IsDamageType(flag) then resist=math.max(resist,value);break end end
  end
 end
 if resist>0 then dmg:ScaleDamage(1-math.min(resist,Z.Config.ResistCap)/100) end
end)

-- Урон аномалии игнорирует очки брони HL2 (иначе куртка поглощает 80% и аномалии почти не ранят).
hook.Add("HandlePlayerArmorReduction","STALKER_ZONE.AnomalyArmor",function(p)
 if Z.AnomalyVictim==p then return true end
end)

hook.Add("ScalePlayerDamage","STALKER_ZONE.Helmet",function(p,hitgroup,dmg)
 if hitgroup~=HITGROUP_HEAD then return end
 local gear=Z.Gear[p];local head=gear and gear.headshot
 if head and head>0 then dmg:ScaleDamage(1-math.min(head,Z.Config.ResistCap)/100) end
end)

-- Раз в секунду: регенерация «Души»/«Компаса» и вывод радиации «Пузырём».
timer.Create("STALKER_ZONE.GearTick",1,0,function()
 for _,p in ipairs(player.GetHumans()) do
  local gear=Z.Gear[p];local inv=p.StalkerInventory
  if gear and p:Alive() and inv and not p.StalkerLoadError then
   local regen=gear.regen or 0
   if regen>0 and p:Health()<p:GetMaxHealth() then
    p.StzRegen=(p.StzRegen or 0)+regen
    local whole=math.floor(p.StzRegen)
    if whole>=1 then p.StzRegen=p.StzRegen-whole;p:SetHealth(math.min(p:GetMaxHealth(),p:Health()+whole)) end
   end
   -- Отрицательный суммарный фон (только артефакты, вне радиационных зон) ускоряет вывод дозы.
   local rate=p:GetNW2Float("stalker_rad_rate",0)
   if rate<0 then
    local R=STALKER_RAD
    if R and R.AddDose and R.GetDose then
     if (tonumber(R.GetDose(p)) or 0)>0 then R.AddDose(p,rate) end
    elseif (inv.dose or 0)>0 then
     inv.dose=math.max(0,inv.dose+rate);p:SetNW2Float("stalker_dose",inv.dose)
    end
   end
  end
 end
end)
