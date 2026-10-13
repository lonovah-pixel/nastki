-- Свойства экипировки: суммы статов надетых предметов. Скорость применяется в обоих realm,
-- чтобы предсказание движения клиента совпадало с сервером.
local Z=STALKER_ZONE

function Z.GearProfile(inv)
 local S=STALKER_INV;local out={}
 if not S or not inv or type(inv.equipment)~="table" then return out end
 for _,item in pairs(inv.equipment) do
  local d=S.Items[item.id]
  if d and item.durability>0 then
   for key,value in pairs(d.stats) do if type(value)=="number" then out[key]=(out[key] or 0)+value end end
  end
 end
 return out
end

hook.Add("SetupMove","STALKER_ZONE.GearSpeed",function(p,mv)
 local bonus=p:GetNW2Float("stz_speed",0)
 if bonus==0 then return end
 local k=math.Clamp(1+bonus/100,.6,1.3)
 mv:SetMaxClientSpeed(mv:GetMaxClientSpeed()*k);mv:SetMaxSpeed(mv:GetMaxSpeed()*k)
end)
