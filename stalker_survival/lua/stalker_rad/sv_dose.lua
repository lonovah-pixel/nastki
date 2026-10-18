-- Доза облучения: API для других аддонов, ежесекундный расчёт фона и урон.
-- Доза хранится в инвентаре (ply.StalkerInventory.dose, сохраняется с профилем) и дублируется в NW2 stalker_dose.
-- Без аддона инвентаря доза живёт в поле игрока до конца сессии.
local R=STALKER_RAD
local cfg=R.Config

-- Можно ли менять дозу: инвентарь загружен без ошибок (иначе запись затёрла бы профиль).
local function store(p)
 if not IsValid(p) or not p:IsPlayer() then return end
 if STALKER_INV then
  local inv=p.StalkerInventory
  if type(inv)=="table" and not p.StalkerLoadError then return inv end
  return
 end
 return p
end
function R.GetDose(p)
 local s=store(p);if not s then return IsValid(p) and p:GetNW2Float("stalker_dose",0) or 0 end
 if s==p then return tonumber(p.StalkerRadDose) or 0 end
 return tonumber(s.dose) or 0
end
-- SetDose/AddDose → новая доза (0..100) или false, если игрок не готов.
function R.SetDose(p,value)
 value=tonumber(value);if not R.Finite(value) then return false end
 local s=store(p);if not s then return false end
 value=math.Clamp(value,0,100)
 if s==p then p.StalkerRadDose=value else s.dose=value end
 p:SetNW2Float("stalker_dose",value)
 return value
end
function R.AddDose(p,delta)
 delta=tonumber(delta);if not R.Finite(delta) then return false end
 if not store(p) then return false end
 return R.SetDose(p,R.GetDose(p)+delta)
end

--[[ Фон и защита игрока: зоны карты (со спадом), территории группировок, экипированные предметы.
 Защита предмета умножается на STALKER_INV.ConditionFactor (износ), сломанный предмет (0 %) не защищает. ]]
function R.Exposure(p)
 local here=p:GetPos()
 local rate=R.RateAt(here,R.Zones)
 local F=STFW
 if F and type(F.World)=="table" and type(F.World.points)=="table" and (cfg.FactionFactor or 0)>0 then
  for _,point in pairs(F.World.points) do
   local pp=type(point)=="table" and point.pos;local level=type(point)=="table" and tonumber(point.radiation)
   if type(pp)=="table" and level and level>0 and tonumber(pp.x) and tonumber(pp.y) and tonumber(pp.z) then
    local radius=tonumber(point.radius) or 100
    if math.abs(here.z-pp.z)<=(tonumber(point.height) or 128) and ((here.x-pp.x)^2+(here.y-pp.y)^2)<=radius^2 then rate=rate+level*cfg.FactionFactor end
   end
  end
 end
 local protection=0
 local S=STALKER_INV;local inv=p.StalkerInventory
 if S and type(S.Items)=="table" and type(inv)=="table" and type(inv.equipment)=="table" then
  for _,item in pairs(inv.equipment) do
   local def=type(item)=="table" and S.Items[item.id];local stats=def and def.stats
   if type(stats)=="table" and (tonumber(item.durability) or 0)>0 then
    rate=rate+(tonumber(stats.radiation) or 0)
    local prot=tonumber(stats.radiationProtection) or 0
    if prot>0 then protection=protection+prot*(S.ConditionFactor and S.ConditionFactor(item) or 1) end
   end
  end
 end
 return rate,math.Clamp(protection,0,math.Clamp(tonumber(cfg.MaxProtection) or .95,0,1))
end

-- Урон от дозы выше порога: 1 + 1 за каждые 10 ед. сверх порога, не больше MaxDamage.
function R.DamageFor(dose)
 if dose<cfg.DamageThreshold or (cfg.MaxDamage or 0)<=0 then return 0 end
 return math.min(cfg.MaxDamage,1+(dose-cfg.DamageThreshold)/10)
end

function R.Tick()
 for _,p in ipairs(player.GetHumans()) do
  if p:Alive() and store(p) then
   local rate,protection=R.Exposure(p)
   local dose=R.SetDose(p,R.Step(R.GetDose(p),rate,protection)) or 0
   p:SetNW2Float("stalker_rad_rate",rate);p:SetNW2Float("stalker_rad_prot",protection)
   local amount=R.DamageFor(dose)
   if amount>0 then
    local dmg=DamageInfo();dmg:SetDamageType(DMG_RADIATION);dmg:SetDamage(amount)
    dmg:SetAttacker(game.GetWorld());dmg:SetInflictor(game.GetWorld());p:TakeDamageInfo(dmg)
   end
  end
 end
end
timer.Create("STALKER.Radiation",1,0,function() R.Tick() end)

hook.Add("PlayerDeath","STALKER.RadiationDeath",function(p)
 if R.SetDose(p,0) then
  p:SetNW2Float("stalker_rad_rate",0);p:SetNW2Float("stalker_rad_prot",0)
  if STALKER_INV and STALKER_INV.SaveInventory and p.StalkerInventory then STALKER_INV.SaveInventory(p) end
 end
end)
