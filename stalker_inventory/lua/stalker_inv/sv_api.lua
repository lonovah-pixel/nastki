-- Серверный API инвентаря для других аддонов сборки (крафт, задания, передача предметов, ремонт).
-- Все операции атомарны: либо изменение целиком применяется и сохраняется, либо инвентарь не меняется.
local S=STALKER_INV

local function ready(ply)
 if not IsValid(ply) or not ply:IsPlayer() or ply.StalkerLoadError or ply.StnpcTrading then return false end
 S.LoadPlayer(ply)
 return ply.StalkerInventory~=nil
end
S.InventoryReady=ready

-- Сколько единиц предмета лежит в рюкзаке (экипировка не считается).
function S.CountItem(ply,id)
 local inv=IsValid(ply) and ply.StalkerInventory;if not inv then return 0 end
 local n=0;for _,item in pairs(inv.grid) do if item.id==id then n=n+item.count end end
 return n
end

-- Снять предметы из рюкзака в копии инвентаря. take={[id]=кол-во}. Возвращает nil и причину при нехватке.
function S.RemoveFrom(inv,take)
 for id,need in pairs(take or {}) do
  if not S.Items[id] or not S.IsInt(need,1,9999) then return nil,"Неизвестный предмет: "..tostring(id) end
  -- Сначала расходуем самые изношенные стаки: целые остаются игроку.
  local slots={}
  for i=1,40 do local item=inv.grid[i];if item and item.id==id then slots[#slots+1]=i end end
  table.sort(slots,function(a,b) return inv.grid[a].durability<inv.grid[b].durability end)
  for _,i in ipairs(slots) do
   local item=inv.grid[i];local n=math.min(need,item.count)
   item.count=item.count-n;need=need-n
   if item.count<=0 then inv.grid[i]=nil end
   if need==0 then break end
  end
  if need>0 then return nil,"Не хватает: "..S.Items[id].name end
 end
 S.CleanQuickbar(inv)
 return inv
end

--[[ Обмен: забрать take={[id]=n} и выдать give={{id,n,durability},…} одним сохранением.
 Возвращает true или false и причину (инвентарь при отказе не меняется). ]]
function S.Exchange(ply,take,give,message)
 if not ready(ply) then return false,"Инвентарь недоступен" end
 S.CaptureEquipment(ply)
 local inv,err=S.RemoveFrom(table.Copy(ply.StalkerInventory),take)
 if not inv then return false,err end
 for _,g in ipairs(give or {}) do
  local nextInv,reason=S.Insert(inv,g[1],g[2] or 1,g[3])
  if not nextInv then return false,reason end
  inv=nextInv
 end
 S.Commit(ply,inv,message)
 return true
end

-- Найти предмет по UID: возвращает предмет, зону (grid/equipment) и индекс в копии инвентаря.
local function locate(inv,uid)
 for _,zone in ipairs({"grid","equipment"}) do for k,v in pairs(inv[zone]) do if v.uid==uid then return v,zone,k end end end
end
-- Ремонт: amount — сколько процентов состояния добавить (до 100).
function S.RepairItem(ply,uid,amount,message)
 if not ready(ply) or type(uid)~="string" or not S.IsInt(amount,1,100) then return false,"Ремонт недоступен" end
 S.CaptureEquipment(ply)
 local inv=table.Copy(ply.StalkerInventory);local item=locate(inv,uid)
 if not item then return false,"Предмет не найден" end
 if item.durability>=100 then return false,"Предмет в полном порядке" end
 item.durability=math.min(100,item.durability+amount)
 S.Commit(ply,inv,message or ("Состояние: "..item.durability.."%"))
 return true
end

-- Сохранение двух инвентарей одной транзакцией SQLite (передача предметов между игроками).
local function saveBoth(a,invA,b,invB)
 local rows={}
 for _,pair in ipairs({{a,invA},{b,invB}}) do
  local sid=STALKER_CORE and STALKER_CORE.SID(pair[1]) or pair[1]:SteamID64()
  if sid then
   S.SaveStamp=math.max((S.SaveStamp or 0)+1,os.time()*1000)
   local copy=table.Copy(pair[2]);copy.savedAt=S.SaveStamp
   rows[#rows+1]="REPLACE INTO stalker_inventory (steamid,payload) VALUES ("..sql.SQLStr(sid)..","..sql.SQLStr(util.TableToJSON(copy))..")"
  end
 end
 if not S.DatabaseReady or S.CVBackend:GetString()=="json" then return true end
 if sql.Query("BEGIN")==false then return false end
 for _,q in ipairs(rows) do if sql.Query(q)==false then sql.Query("ROLLBACK");return false end end
 if sql.Query("COMMIT")==false then sql.Query("ROLLBACK");return false end
 return true
end
--[[ Передать count единиц предмета uid из рюкзака from в рюкзак to (сохраняются UID, износ, магазин).
 Часть стака получает новый UID. Возвращает true или false и причину. ]]
function S.GiveFromTo(from,to,uid,count)
 if from==to or not ready(from) or not ready(to) then return false,"Инвентарь недоступен" end
 S.CaptureEquipment(from);S.CaptureEquipment(to)
 local a,b=table.Copy(from.StalkerInventory),table.Copy(to.StalkerInventory)
 local item,zone,index=locate(a,uid)
 if not item or zone~="grid" then return false,"Передать можно только предмет из рюкзака" end
 count=count or item.count
 if not S.IsInt(count,1,item.count) then return false,"Неверное количество" end
 local moved=table.Copy(item);moved.count=count
 if count<item.count then item.count=item.count-count;moved.uid=S.UID() else a.grid[index]=nil end
 local slot;for i=1,40 do if not b.grid[i] then slot=i;break end end
 if not slot then return false,"У получателя нет свободной ячейки" end
 if S.FindUID(b,moved.uid) then moved.uid=S.UID() end
 b.grid[slot]=moved
 S.CleanQuickbar(a)
 a.revision=((from.StalkerInventory.revision or 0)+1)%4294967296
 b.revision=((to.StalkerInventory.revision or 0)+1)%4294967296
 if not saveBoth(from,a,to,b) then return false,"Ошибка сохранения: передача отменена" end
 from.StalkerInventory=a;to.StalkerInventory=b
 for _,p in ipairs({from,to}) do
  p:SetNW2Float("stalker_inv_weight",S.Weight(p.StalkerInventory))
  S.SaveInventory(p)
 end
 S.Sync(from,"Передано: "..S.Items[moved.id].name.." ×"..count)
 S.Sync(to,"Получено: "..S.Items[moved.id].name.." ×"..count)
 hook.Run("STALKER_INV_ItemTransferred",from,to,moved)
 return true
end
