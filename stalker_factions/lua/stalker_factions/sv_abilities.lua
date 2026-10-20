--[[ Способности командования (как в ММО). Стоимость — очки снабжения группировки, перезарядка хранится в мире (os.time),
 временные эффекты — в памяти сервера (CurTime). Применяют лидер и, если разрешено, офицеры. ]]
local F=STFW
F.Buffs=F.Buffs or {}
function F.BuffActive(id,key) local b=F.Buffs[id or ""];return b~=nil and (b[key] or 0)>CurTime() end
function F.BuffLeft(id,key) local b=F.Buffs[id or ""];return b and math.max(0,math.ceil((b[key] or 0)-CurTime())) or 0 end
function F.CooldownLeft(id,ability,world)
 local d=((world or F.World).progression or {})[id or ""]
 local t=d and d.cooldowns and tonumber(d.cooldowns[ability]) or 0
 return math.max(0,t-os.time())
end
function F.CanUseAbility(p,ability)
 local a=F.Abilities[ability or ""];if not a then return false,"ability_unknown" end
 local role=F.Role(p)
 if role~="leader" and (role~="officer" or a.minRank=="leader") then return false,"ability_rank" end
 return true
end

-- Члены группировки рядом с точкой (живые, в сети).
local function membersNear(id,pos,radius)
 local list={}
 for _,q in ipairs(player.GetHumans()) do
  local d=F.Profiles[q:SteamID64()]
  if d and d.joined and d.faction==id and q:Alive() and q:GetPos():DistToSqr(pos)<=radius*radius then list[#list+1]=q end
 end
 return list
end
-- Снять дозу радиации: API системы радиации, если есть, иначе поле инвентаря и сетевая переменная.
local function reduceDose(q,amount)
 local R=STALKER_RAD
 if R and R.AddDose then return R.AddDose(q,-amount) end
 if R and R.SetDose and R.GetDose then return R.SetDose(q,math.max(0,R.GetDose(q)-amount)) end
 local inv=q.StalkerInventory
 if inv and tonumber(inv.dose) then inv.dose=math.max(0,inv.dose-amount);q:SetNW2Float("stalker_dose",inv.dose) end
end
-- Патроны к оружию в руках: предмет инвентаря с подходящим типом патронов, иначе патроны напрямую.
local function giveAmmo(q,packs)
 local wep=q:GetActiveWeapon();local S=STALKER_INV
 local ammoType=IsValid(wep) and wep:GetPrimaryAmmoType() or -1
 local name=ammoType and ammoType>=0 and game.GetAmmoName and game.GetAmmoName(ammoType)
 if S and S.Items and S.GiveItem then
  local item
  if name then for id,def in pairs(S.Items) do if def.ammo==name then item=id;break end end end
  item=item or (S.Items.ammo_pistol and "ammo_pistol")
  if item then return S.GiveItem(q,item,packs) end
 end
 if ammoType and ammoType>=0 then q:GiveAmmo(30*packs,ammoType) end
end

local effects={
 rally=function(p,id,a)
  local MK=STALKER_MARKERS
  if MK and MK.Set then MK.Set("stfw.rally."..id,{pos=p:GetPos(),label="Сбор: "..p:Nick(),kind="rally",visible={faction=id},expires=CurTime()+a.duration}) end
  return "Сбор у "..p:Nick().."! Метка на карте "..a.duration.." с."
 end,
 warcry=function(p,id,a)
  local list=membersNear(id,p:GetPos(),a.radius)
  for _,q in ipairs(list) do q.StfwWarcry=CurTime()+a.duration;q:SetNW2Float("stfw_warcry",CurTime()+a.duration) end
  return "Боевой клич: "..#list.." бойцов получают на "..math.floor(a.reduction*100).."% меньше урона "..a.duration.." с."
 end,
 hospital=function(p,id,a)
  local list=membersNear(id,p:GetPos(),a.radius)
  for _,q in ipairs(list) do q:SetHealth(math.min(math.max(q:GetMaxHealth(),q:Health()),q:Health()+a.heal));reduceDose(q,a.dose) end
  return "Полевой госпиталь: помощь получили "..#list.." бойцов."
 end,
 recon=function(p,id,a)
  local MK=STALKER_MARKERS;local n=0
  for _,q in ipairs(player.GetHumans()) do
   local d=F.Profiles[q:SteamID64()]
   if q~=p and q:Alive() and d and d.joined and q:GetPos():DistToSqr(p:GetPos())<=a.radius*a.radius then
    local relation=F.Relation(id,d.faction)
    if relation=="war" or relation=="enemy" then
     n=n+1
     if MK and MK.Set then MK.Set("stfw.recon."..id.."."..q:SteamID64(),{pos=q:GetPos(),label="Противник: "..F.Name(d.faction),kind="enemy",visible={faction=id},expires=CurTime()+a.duration}) end
    end
   end
  end
  return "Разведка: обнаружено противников — "..n.."."
 end,
 supply=function(p,id,a)
  local list=membersNear(id,p:GetPos(),a.radius);local S=STALKER_INV
  for _,q in ipairs(list) do
   if S and S.GiveItem and S.Items and S.Items.bandage then S.GiveItem(q,"bandage",a.bandages) else q:SetHealth(math.min(q:GetMaxHealth(),q:Health()+10*a.bandages)) end
   giveAmmo(q,a.ammo)
  end
  return "Снабжение: бинты и патроны получили "..#list.." бойцов."
 end,
 mobilize=function(p,id,a)
  F.Buffs[id]=F.Buffs[id] or {};F.Buffs[id].mobilize=CurTime()+a.duration
  return "Мобилизация: захват точек на "..math.floor(a.bonus*100).."% быстрее "..a.duration.." с."
 end,
}

-- Применение: проверки, списание очков и запуск перезарядки одной записью мира, затем эффект.
function F.UseAbility(p,ability)
 if not IsValid(p) then return false,"denied" end
 local a=F.Abilities[ability or ""];if not a or not effects[ability] then return false,"ability_unknown" end
 if not p:Alive() then return false,"dead" end
 -- Без сознания после выброса командовать нельзя (бинд stfw_ability и чат обходили бы блокировку управления).
 local C=STALKER_CORE;if C and C.Unconscious and C.Unconscious(p) then return false,"unconscious" end
 local ok,err=F.CanUseAbility(p,ability);if not ok then return false,err end
 local id=F.Load(p).faction
 if F.CooldownLeft(id,ability)>0 then return false,"ability_cooldown" end
 local w=table.Copy(F.World);local d=F.Prog(w,id);local cost=math.max(0,math.floor(a.cost or 0))
 if d.credits<cost then return false,"supply_low" end
 d.credits=d.credits-cost;d.cooldowns[ability]=os.time()+math.max(0,math.floor(a.cooldown or 0))
 if not F.Commit(w,{},"ability "..id.." "..ability.." "..p:SteamID64()) then return false,"storage" end
 local done,text=pcall(effects[ability],p,id,a)
 if not done then ErrorNoHalt("[STFW] ability "..ability..": "..tostring(text).."\n");text=a.name end
 F.AlertFaction(id,"«"..a.name.."» ("..p:Nick().."): "..tostring(text),"info",p)
 hook.Run("STFW_AbilityUsed",p,id,ability)
 return true,nil,tostring(text)
end
-- Боевой клич: −20% входящего урона.
hook.Add("EntityTakeDamage","STFW.Warcry",function(ent,dmg)
 if IsValid(ent) and ent:IsPlayer() and (ent.StfwWarcry or 0)>CurTime() then dmg:ScaleDamage(1-(F.Abilities.warcry.reduction or .2)) end
end)
hook.Add("PlayerDeath","STFW.Warcry",function(p) p.StfwWarcry=nil;p:SetNW2Float("stfw_warcry",0) end)
concommand.Add("stfw_ability",function(p,_,args)
 if not IsValid(p) or not F.RateOK(p,"stfw.ability",2,4) then return end
 local ok,err,text=F.UseAbility(p,args[1])
 F.Toast(p,ok and text or F.L(err or "denied"),ok and "ok" or "warn")
 if ok then F.SendState(p) end
end)
