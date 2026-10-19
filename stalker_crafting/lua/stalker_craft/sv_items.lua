-- Действия предметов крафта из инвентаря. OnUse получает копию инвентаря (inv): все изменения делаются в ней —
-- после обработчика инвентарь сохраняет именно эту копию, и отдельный Commit (например, S.RepairItem) был бы затёрт.
-- Возврат true расходует одну единицу предмета.
local CR=STALKER_CRAFT
local C=STALKER_CORE
local Cfg=CR.Config

-- Сытость и вода как у еды инвентаря: сытость — DarkRP Energy, если включён голод DarkRP, иначе inv.hunger.
local function feed(ply,inv,stat,amount)
 if amount<=0 then return false end
 local S=STALKER_INV
 local rp=S.Config and S.Config.DarkRP
 if stat=="hunger" and rp and rp.UseHunger and ply.getDarkRPVar and ply.setSelfDarkRPVar then
  local energy=ply:getDarkRPVar("Energy")
  if type(energy)=="number" then
   if energy>=100 then return false end
   inv.hunger=math.min(100,energy+amount);ply:setSelfDarkRPVar("Energy",inv.hunger);return true
  end
 end
 local now=tonumber(inv[stat]) or 100
 if now>=100 then return false end
 inv[stat]=math.min(100,now+amount);return true
end
CR.Feed=feed

-- Блюдо: голод, жажда, здоровье; «сомнительное мясо» добавляет дозу (доза хранится в инвентаре, как у антирада).
function CR.EatDish(ply,item,inv)
 local id=item.id
 local hunger,thirst,health,dose=CR.FoodValue(id,"hunger"),CR.FoodValue(id,"thirst"),CR.FoodValue(id,"health"),CR.FoodValue(id,"dose")
 local any=false
 if feed(ply,inv,"hunger",hunger) then any=true end
 if feed(ply,inv,"thirst",thirst) then any=true end
 if health>0 and ply:Health()<ply:GetMaxHealth() then ply:SetHealth(math.min(ply:GetMaxHealth(),ply:Health()+health));any=true end
 if not any then return false,hunger>0 and "Вы сыты" or "Пить не хочется" end
 if dose>0 then
  inv.dose=math.Clamp((tonumber(inv.dose) or 0)+dose,0,100);ply:SetNW2Float("stalker_dose",inv.dose)
  C.Notify(ply,"Мясо фонит: доза радиации +"..dose,"warn",4)
 end
 hook.Run("STALKER_CRAFT_Eaten",ply,id)
 return true
end

-- Самый изношенный предмет в слотах набора; slotID — только этот слот.
function CR.KitTarget(inv,kitID,slotID)
 local kit=CR.Kits[kitID];if not kit or type(inv)~="table" or type(inv.equipment)~="table" then return end
 local best,bestSlot
 for _,slot in ipairs(kit.slots) do
  if not slotID or slot==slotID then
   local item=inv.equipment[slot]
   if item and (tonumber(item.durability) or 100)<100 and (not best or item.durability<best.durability) then best,bestSlot=item,slot end
  end
 end
 return best,bestSlot
end

function CR.UseKit(ply,item,inv)
 local kit=CR.Kits[item.id]
 local target,slot=CR.KitTarget(inv,item.id)
 if not target then return false,"Нечего чинить: надетое "..kit.label.." в полном порядке" end
 -- То же, что STALKER_INV.RepairItem, но в транзакции использования предмета (см. комментарий в начале файла).
 target.durability=math.min(100,target.durability+CR.KitAmount(item.id))
 C.Notify(ply,CR.ItemName(target.id)..": состояние "..target.durability.."%","ok",4)
 hook.Run("STALKER_CRAFT_Repaired",ply,slot,target)
 return true
end

function CR.RegisterUseHandlers()
 local S=STALKER_INV;if not S or not S.Items then return end
 local I=S.Items
 for id in pairs(CR.Food) do if I[id] then I[id].OnUse=function(ply,item,inv) return CR.EatDish(ply,item,inv) end end end
 for id in pairs(CR.Kits) do if I[id] then I[id].OnUse=function(ply,item,inv) return CR.UseKit(ply,item,inv) end end end
 if I.toolkit then
  -- Набор не расходуется: «Использовать» открывает мастерскую.
  I.toolkit.OnUse=function(ply)
   C.Send("stalker_craft.open",ply,{mode="craft"})
   return false,"Набор инструментов не расходуется: открыта мастерская"
  end
 end
 if I.campfire_kit then
  I.campfire_kit.OnUse=function(ply)
   if not CR.PlaceCampfire then return false,"Костры недоступны" end
   return CR.PlaceCampfire(ply)
  end
 end
end
CR.RegisterUseHandlers()
