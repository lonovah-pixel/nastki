-- Свойства экипировки: суммы статов надетых предметов. Скорость применяется в обоих realm,
-- чтобы предсказание движения клиента совпадало с сервером.
local Z=STALKER_ZONE

-- Не зависят от износа: скорость, регенерация и фон радиации (это свойства, а не защита).
local noWear={speed=true,regen=true,radiation=true}
-- Защита падает с износом: реестр характеристик инвентаря (cond=true), без него — защиты Зоны.
local function wears(S,key)
 if noWear[key] then return false end
 local f=type(S.StatFormat)=="table" and S.StatFormat[key]
 if f then return f.cond==true end
 return Z.Resists[key]~=nil or key=="headshot"
end

-- Реальная защита совпадает с карточкой предмета: костюм, шлем и обувь (S.WearCategories)
-- защищают на S.ConditionFactor(item) от номинала, сломанный предмет (0 %) не действует.
function Z.GearProfile(inv)
 local S=STALKER_INV;local out={}
 if not S or not inv or type(inv.equipment)~="table" then return out end
 local cats=type(S.WearCategories)=="table" and S.WearCategories or {}
 for _,item in pairs(inv.equipment) do
  local d=type(item)=="table" and S.Items[item.id]
  if d and (tonumber(item.durability) or 0)>0 then
   local factor=cats[d.category] and S.ConditionFactor and S.ConditionFactor(item) or 1
   for key,value in pairs(d.stats or {}) do
    if type(value)=="number" then
     if factor~=1 and wears(S,key) then value=value*factor end
     out[key]=(out[key] or 0)+value
    end
   end
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
