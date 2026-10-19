-- Эффекты использования новых предметов. Возврат true расходует одну единицу.
local Z=STALKER_ZONE

-- Доза — через API радиации (STALKER_RAD.AddDose), если он есть. Обработчик получает копию инвентаря,
-- которую инвентарь затем сохраняет: новая доза записывается и в неё, иначе сохранение вернуло бы старую.
local function reduceDose(p,inv,amount)
 local R=STALKER_RAD
 local dose=R and R.GetDose and tonumber(R.GetDose(p)) or tonumber(inv.dose) or 0
 if dose<=0 then return false end
 if R and R.AddDose then
  local v=R.AddDose(p,-amount)
  if v==false then return false end
  inv.dose=v;return true
 end
 inv.dose=math.max(0,dose-amount);p:SetNW2Float("stalker_dose",inv.dose);return true
end

function Z.RegisterUseHandlers()
 local S=STALKER_INV;if not S or not S.Items then return end
 local I=S.Items
 -- Готовые обработчики базового инвентаря читают параметры из описания предмета.
 if I.medkit and I.medkit.OnUse then I.medkit_army.OnUse=I.medkit.OnUse end
 if I.food and I.food.OnUse then I.bread.OnUse=I.food.OnUse;I.sausage.OnUse=I.food.OnUse end
 if I.water and I.water.OnUse then I.energy.OnUse=I.water.OnUse end
 if I.ammo_pistol and I.ammo_pistol.OnUse then
  for _,id in ipairs({"ammo_smg","ammo_buckshot","ammo_357","ammo_ar2","ammo_bolt"}) do I[id].OnUse=I.ammo_pistol.OnUse end
 end
 I.medkit_sci.OnUse=function(p,item,inv,def)
  local healed=false
  if p:Health()<p:GetMaxHealth() then p:SetHealth(math.min(p:GetMaxHealth(),p:Health()+def.stats.health));healed=true end
  local cleaned=reduceDose(p,inv,def.stats.dose)
  if not healed and not cleaned then return false,"Лечение не требуется" end
  return true
 end
 I.vodka.OnUse=function(p,item,inv,def)
  if not reduceDose(p,inv,def.stats.dose) then return false,"Облучения нет — водка подождёт" end
  p:ViewPunch(Angle(math.Rand(-4,4),math.Rand(-6,6),0));return true
 end
 I.grenade.OnUse=function(p)
  if p:GetAmmoCount("Grenade")>=5 then return false,"Больше гранат не унести" end
  p:GiveAmmo(1,"Grenade",true)
  if not p:HasWeapon("weapon_frag") then p:Give("weapon_frag",true) end
  p:SelectWeapon("weapon_frag");return true
 end
 for id,cfg in pairs(Z.Detectors) do
  I[id].OnUse=function(p,item,inv)
   local best=Z.BestDetector(inv)
   if best and best.tier>cfg.tier then return false,"Работает более совершенный детектор из рюкзака" end
   return false,"Детектор включён, пока лежит в рюкзаке. Ищите артефакты у аномалий."
  end
 end
end
Z.RegisterUseHandlers()
