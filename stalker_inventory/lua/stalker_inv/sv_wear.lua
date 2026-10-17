-- Износ экипированной брони от урона. Попадания копятся и применяются одним сохранением раз в
-- ArmorWearInterval секунд: при перестрелке инвентарь не пересохраняется на каждую пулю.
local S=STALKER_INV
S.WearQueue=S.WearQueue or setmetatable({},{__mode="k"}) -- [игрок]={[слот]={uid,amount}}

--[[ Поставить в очередь износ предмета в слоте экипировки (amount — проценты состояния, можно дробные).
 Возвращает true или false и причину. Применяется S.FlushWear (таймер, смерть, выход). ]]
function S.WearEquipment(ply,slotID,amount)
 if not IsValid(ply) or not ply:IsPlayer() or ply.StalkerLoadError then return false,"Игрок не готов" end
 if not S.EquipmentByID[slotID] then return false,"Неизвестный слот экипировки" end
 amount=tonumber(amount)
 if not amount or amount~=amount or amount<=0 then return false,"Некорректный износ" end
 local inv=ply.StalkerInventory;local item=inv and inv.equipment[slotID]
 if not item or item.durability<=0 then return false,"Слот пуст или предмет уже сломан" end
 local queue=S.WearQueue[ply];if not queue then queue={};S.WearQueue[ply]=queue end
 local entry=queue[slotID]
 -- Сменили предмет в слоте — износ прежнего на новый не переносится.
 if not entry or entry.uid~=item.uid then entry={uid=item.uid,amount=0};queue[slotID]=entry end
 entry.amount=math.min(100,entry.amount+math.min(amount,100))
 return true
end

--[[ Применить накопленный износ. Целые проценты списываются, дробный остаток копится дальше.
 silent=true — изменить живой инвентарь без Commit (перед сохранением при смерти и выходе). ]]
function S.FlushWear(ply,silent)
 local queue=S.WearQueue[ply];if not queue then return false end
 if not IsValid(ply) or not ply.StalkerInventory or ply.StalkerLoadError then S.WearQueue[ply]=nil;return false end
 -- Во время торговли инвентарь заморожен: износ подождёт.
 if not silent and S.InventoryReady and not S.InventoryReady(ply) then return false end
 if not silent then S.CaptureEquipment(ply) end
 local inv=silent and ply.StalkerInventory or table.Copy(ply.StalkerInventory)
 local changed,notes=false,{}
 for slotID,entry in pairs(queue) do
  local item=inv.equipment[slotID];local whole=math.floor(entry.amount)
  if not item or item.uid~=entry.uid or item.durability<=0 then queue[slotID]=nil
  elseif whole>=1 then
   local before=item.durability;item.durability=math.max(0,before-whole);entry.amount=entry.amount-whole;changed=true
   local name=S.Items[item.id] and S.Items[item.id].name or item.id
   if item.durability<=0 then notes[#notes+1]=name.." полностью изношен";queue[slotID]=nil
   elseif before>=25 and item.durability<25 then notes[#notes+1]=name..": состояние "..item.durability.."% — нужен ремонт" end
  end
 end
 if not next(queue) then S.WearQueue[ply]=nil end
 if not changed then return false end
 if silent then return true end
 local text=#notes>0 and table.concat(notes,". ") or nil
 local toast=text and STALKER_CORE and STALKER_CORE.Notify
 S.Commit(ply,inv,not toast and text or nil)
 if toast then STALKER_CORE.Notify(ply,text,"warn",6) end
 if text then hook.Run("STALKER_INV_EquipmentWorn",ply,inv.equipment) end
 return true
end

-- Типы урона, изнашивающие броню (битовая маска собирается при каждом вызове: список можно менять на лету).
local function wearing(dmg)
 for _,flag in ipairs(S.Config.ArmorWearTypes or {}) do if dmg:IsDamageType(flag) then return true end end
 return false
end
-- Попадание в голову изнашивает шлем, остальное — костюм. ScalePlayerDamage вызывается до EntityTakeDamage.
hook.Add("ScalePlayerDamage","STALKER_INV.WearHead",function(ply,hitgroup)
 if hitgroup==HITGROUP_HEAD then ply.StalkerHeadHitAt=CurTime() end
end)
hook.Add("EntityTakeDamage","STALKER_INV.Wear",function(ent,dmg)
 if not IsValid(ent) or not ent:IsPlayer() or not ent.StalkerInventory or ent.StalkerLoadError then return end
 local per=tonumber(S.Config.ArmorWearPerDamage) or 0
 local head=ent.StalkerHeadHitAt==CurTime();ent.StalkerHeadHitAt=nil
 if per<=0 or dmg:GetDamage()<=0 or not wearing(dmg) then return end
 local slotID=head and "helmet" or "armor"
 if not ent.StalkerInventory.equipment[slotID] then return end
 -- Износ засчитывается, только если урон действительно прошёл (его могли отменить другие обработчики).
 local hp,armor=ent:Health(),ent:Armor();local wear=math.min(dmg:GetDamage(),200)*per
 timer.Simple(0,function()
  if IsValid(ent) and (ent:Health()<hp or ent:Armor()<armor) then S.WearEquipment(ent,slotID,wear) end
 end)
end)
-- Периодическое применение; погибшие ждут возрождения (их износ уже сохранён при смерти).
function S.StartWearTimer()
 timer.Create("STALKER_INV.Wear",math.max(.5,tonumber(S.Config.ArmorWearInterval) or 2),0,function()
  for ply in pairs(S.WearQueue) do
   if not IsValid(ply) then S.WearQueue[ply]=nil elseif ply:Alive() then S.FlushWear(ply) end
  end
 end)
end
S.StartWearTimer()
STALKER_INV.WearEquipment=S.WearEquipment
