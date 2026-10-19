-- Наводки на чужие тайники («координаты с убитого»).
-- При смерти игрока с шансом берётся случайный его непустой тайник на этой карте. Убийца-игрок получает наводку
-- сразу; иначе она остаётся в рюкзаке погибшего (bag.StashIntel), и аддон Зоны передаёт её подобравшему.
-- Держатель видит метку, у места удерживает E и может только забирать вещи. Владелец может быть не в сети:
-- его инвентарь читается из сохранения, а перенос пишется одной транзакцией для обоих.
local S=STALKER_INV
local C=STALKER_CORE
util.AddNetworkString("stalker_stash.intel")   -- сервер → клиент: список наводок держателя
util.AddNetworkString("stalker_stash.foreign") -- сервер → клиент: содержимое чужого тайника или закрытие окна
util.AddNetworkString("stalker_stash.loot")    -- клиент → сервер: забрать предмет из ячейки (0 — всё)
S.IntelReady=sql.Query("CREATE TABLE IF NOT EXISTS stalker_stash_intel (id TEXT PRIMARY KEY, holder TEXT NOT NULL, owner TEXT NOT NULL, stash TEXT NOT NULL, expires INTEGER NOT NULL, notified INTEGER NOT NULL DEFAULT 0, payload TEXT NOT NULL)")~=false
S.IntelHeld=S.IntelHeld or {} -- [SteamID64 держателя]={[id]=наводка}; только игроки в сети

local Q=sql.SQLStr
local function sidOf(p)
 if not IsValid(p) or not p:IsPlayer() then return end
 if C and C.SID then return C.SID(p) end
 return S.InventorySID(p)
end
local function playerBySID(id)
 if C and C.PlayerBySID then return C.PlayerBySID(id) end
 for _,p in ipairs(player.GetAll()) do if p:SteamID64()==id then return p end end
end
local function notify(p,text,kind,seconds)
 if not IsValid(p) or not text then return end
 if C and C.Notify then C.Notify(p,text,kind,seconds) else p:ChatPrint(text) end
end
-- Сжатый JSON (как STALKER_CORE.Send) — работает и без ядра.
local function send(name,p,tbl)
 if C and C.Send then return C.Send(name,p,tbl) end
 local raw=util.TableToJSON(tbl or {});local data=raw and util.Compress(raw)
 if not data or #data>63000 then return false end
 net.Start(name);net.WriteUInt(#data,16);net.WriteData(data,#data);net.Send(p);return true
end
local function rate(p,key,perSecond,burst)
 if C and C.Rate then return C.Rate(p,key,perSecond,burst) end
 p.StalkerIntelRate=p.StalkerIntelRate or {}
 if (p.StalkerIntelRate[key] or 0)>CurTime() then return false end
 p.StalkerIntelRate[key]=CurTime()+1/perSecond;return true
end
local function hoursText(seconds)
 seconds=math.max(0,math.floor(seconds));local h=math.floor(seconds/3600);local m=math.floor(seconds%3600/60)
 if h>0 then return h.." ч"..(m>0 and (" "..m.." мин") or "") end
 return math.max(1,m).." мин"
end
S.IntelTimeText=hoursText

local function finite(v) return type(v)=="number" and v==v and math.abs(v)<=S.MaxCoord end
--[[ Проверка и нормализация наводки (данные могли пройти через чужой аддон и рестарт).
 Формат: {owner=SteamID64, ownerName, stash=ID тайника, map, pos={x,y,z}, expires=os.time() окончания}. ]]
function S.ValidIntel(raw)
 if type(raw)~="table" then return end
 local pos=raw.pos
 if type(raw.owner)~="string" or not raw.owner:match("^%d+$") or #raw.owner>24 then return end
 if type(raw.stash)~="string" or #raw.stash<1 or #raw.stash>96 then return end
 if type(raw.map)~="string" or #raw.map<1 or #raw.map>128 then return end
 if (type(pos)~="table" and type(pos)~="Vector") or not finite(pos.x) or not finite(pos.y) or not finite(pos.z) then return end
 local expires=tonumber(raw.expires);if not expires or expires~=expires then return end
 local name=type(raw.ownerName)=="string" and raw.ownerName~="" and raw.ownerName:sub(1,64) or "неизвестный сталкер"
 return {owner=raw.owner,ownerName=name,stash=raw.stash,map=raw.map,pos={x=pos.x,y=pos.y,z=pos.z},expires=math.floor(expires)}
end
-- Наводка на случайный непустой тайник игрока на текущей карте (nil — нечего выдавать).
function S.MakeStashIntel(victim)
 local owner=sidOf(victim);local inv=owner and victim.StalkerInventory
 if not inv or victim.StalkerLoadError or type(inv.stashes)~="table" then return end
 local list={}
 for id,stash in pairs(inv.stashes) do if stash.map==game.GetMap() and next(stash.items) then list[#list+1]=id end end
 if #list==0 then return end
 table.sort(list)
 local id=list[math.random(#list)];local stash=inv.stashes[id]
 return {owner=owner,ownerName=victim:Nick(),stash=id,map=stash.map,pos=table.Copy(stash.pos),
  expires=os.time()+math.floor((tonumber(S.Config.StashIntelHours) or 6)*3600)}
end

--[[ Хранение: SQLite stalker_stash_intel, по строке на наводку. notified — владелец уже знает о рассекречивании. ]]
local function dbSave(holder,intel)
 if not S.IntelReady then return false end
 local payload=util.TableToJSON({map=intel.map,pos=intel.pos,ownerName=intel.ownerName,opened=intel.opened==true})
 return sql.Query("REPLACE INTO stalker_stash_intel (id,holder,owner,stash,expires,notified,payload) VALUES ("..Q(intel.id)..","..Q(holder)..","
  ..Q(intel.owner)..","..Q(intel.stash)..","..string.format("%d",intel.expires)..","..(intel.notified and 1 or 0)..","..Q(payload)..")")~=false
end
function S.LoadIntel(holder)
 local out={}
 if not S.IntelReady or type(holder)~="string" then return out end
 local rows=sql.Query("SELECT id,owner,stash,expires,notified,payload FROM stalker_stash_intel WHERE holder="..Q(holder).." AND expires>"..os.time())
 for _,r in ipairs(type(rows)=="table" and rows or {}) do
  local data=util.JSONToTable(r.payload or "")
  local intel=type(data)=="table" and S.ValidIntel({owner=r.owner,stash=r.stash,map=data.map,pos=data.pos,expires=r.expires,ownerName=data.ownerName})
  if intel then intel.id=r.id;intel.opened=data.opened==true;intel.notified=tonumber(r.notified)==1;out[r.id]=intel end
 end
 return out
end
-- Наводки игрока в сети (загружаются при первом обращении).
local function held(p)
 local id=sidOf(p);if not id then return {} end
 if not S.IntelHeld[id] then S.IntelHeld[id]=S.LoadIntel(id) end
 return S.IntelHeld[id],id
end
function S.IntelList(p) return table.Copy((held(p))) end

local function markerID(id) return "stash.intel."..id end
local function setMarker(holder,intel)
 local MK=STALKER_MARKERS;if not MK or not MK.Set then return end
 if intel.map~=game.GetMap() then MK.Remove(markerID(intel.id));return end
 MK.Set(markerID(intel.id),{pos=Vector(intel.pos.x,intel.pos.y,intel.pos.z),label="Тайник: "..intel.ownerName,kind="stash",
  visible={players={[holder]=true}},expires=CurTime()+math.max(1,intel.expires-os.time())})
end
local function removeMarker(id) local MK=STALKER_MARKERS;if MK and MK.Remove then MK.Remove(markerID(id)) end end

function S.SendIntel(p)
 if not IsValid(p) then return end
 local list={};local now=os.time()
 for id,intel in pairs((held(p))) do
  list[#list+1]={id=id,owner=intel.ownerName,map=intel.map,pos=intel.pos,left=math.max(0,intel.expires-now),opened=intel.opened or nil}
 end
 table.sort(list,function(a,b) if a.left~=b.left then return a.left<b.left end;return a.id<b.id end)
 send("stalker_stash.intel",p,{list=list})
end
local function closeForeign(p,message)
 if not IsValid(p) then return end
 p.StalkerLooting=nil;send("stalker_stash.foreign",p,{close=true,message=message})
end
-- Снять наводку (держатель может быть не в сети: тогда только база).
function S.RemoveIntelByID(holder,id,message)
 if S.IntelReady then sql.Query("DELETE FROM stalker_stash_intel WHERE id="..Q(id)) end
 removeMarker(id)
 local list=S.IntelHeld[holder];if list then list[id]=nil end
 local p=playerBySID(holder)
 if IsValid(p) then
  if p.StalkerLooting and p.StalkerLooting.id==id then closeForeign(p) end
  if message then notify(p,message,"info",6) end
  S.SendIntel(p)
 end
end
-- Тайник удалён или опустошён владельцем: все наводки на него теряют смысл.
function S.DropStashIntel(owner,stash,message)
 if not owner or not stash then return end
 local targets={}
 if S.IntelReady then
  local rows=sql.Query("SELECT id,holder FROM stalker_stash_intel WHERE owner="..Q(owner).." AND stash="..Q(stash))
  for _,r in ipairs(type(rows)=="table" and rows or {}) do targets[r.id]=r.holder end
 end
 for holder,list in pairs(S.IntelHeld) do for id,intel in pairs(list) do if intel.owner==owner and intel.stash==stash then targets[id]=holder end end end
 for id,holder in pairs(targets) do S.RemoveIntelByID(holder,id,message) end
end

--[[ Выдать наводку игроку. Возвращает true, id или false, причина.
 Повторная наводка на тот же тайник только продлевает срок. Владелец получает уведомление
 (если не в сети — при следующем входе). ]]
function S.GiveStashIntel(p,raw)
 local holder=sidOf(p);if not holder then return false,"Игрок не готов" end
 local intel=S.ValidIntel(raw);if not intel then return false,"Повреждённая наводка" end
 if intel.expires<=os.time() then return false,"Наводка устарела" end
 if intel.owner==holder then return false,"Это координаты вашего собственного тайника" end
 local list=held(p)
 for id,old in pairs(list) do
  if old.owner==intel.owner and old.stash==intel.stash then
   if intel.expires>old.expires then old.expires=intel.expires;dbSave(holder,old);setMarker(holder,old) end
   notify(p,"Наводка на тайник «"..old.ownerName.."» уже есть в КПК: срок обновлён","info",6);S.SendIntel(p)
   return true,id
  end
 end
 -- Лимит наводок: вытесняется та, что истекает раньше всех.
 local max=math.max(1,math.floor(tonumber(S.Config.StashIntelMax) or 8))
 while table.Count(list)>=max do
  local oldest;for id,x in pairs(list) do if not oldest or x.expires<list[oldest].expires then oldest=id end end
  S.RemoveIntelByID(holder,oldest)
 end
 intel.id=S.UID()
 local owner=playerBySID(intel.owner)
 intel.notified=IsValid(owner)
 if S.IntelReady and not dbSave(holder,intel) then return false,"Ошибка сохранения наводки" end
 list[intel.id]=intel
 setMarker(holder,intel)
 notify(p,"Наводка: координаты тайника сталкера «"..intel.ownerName.."». Метка на карте, срок "..hoursText(intel.expires-os.time())..".","ok",8)
 if IsValid(owner) then notify(owner,"Ваш тайник рассекречен: кто-то получил его координаты","danger",10) end
 S.SendIntel(p)
 hook.Run("STALKER_INV_StashIntelGiven",p,intel)
 return true,intel.id
end

-- Инвентарь владельца тайника: копия живого (если в сети) или загруженный из сохранения.
-- Возвращает inv, игрок-владелец или nil, причина.
local function ownerInventory(owner)
 local p=playerBySID(owner)
 if IsValid(p) then
  if p.StalkerLoadError or not p.StalkerInventory then return nil,nil,"Тайник сейчас недоступен" end
  if S.InventoryReady and not S.InventoryReady(p) then return nil,nil,"Тайник сейчас недоступен: попробуйте позже" end
  S.CaptureEquipment(p)
  return table.Copy(p.StalkerInventory),p
 end
 local inv=S.LoadInventoryBySID(owner)
 if not inv then return nil,nil,"Тайник сейчас недоступен" end
 return inv
end
function S.SendForeign(p,intel,stash,message)
 local items={}
 for slot,item in pairs(stash.items) do items[#items+1]={slot=slot,item=item} end
 table.sort(items,function(a,b) return a.slot<b.slot end)
 send("stalker_stash.foreign",p,{intel=intel.id,owner=intel.ownerName,slots=S.StashSlotsOf(stash),items=items,pos=intel.pos,message=message})
end
-- Проверка тайника по наводке; при пустом/удалённом тайнике наводка снимается.
local function resolve(p,id)
 local list,holder=held(p);local intel=list[id]
 if not intel then closeForeign(p);return nil,"Наводка недействительна" end
 if intel.expires<=os.time() then S.RemoveIntelByID(holder,id,"Наводка устарела");return nil end
 if intel.map~=game.GetMap() then return nil,"Тайник на другой карте: "..intel.map end
 local inv,owner,err=ownerInventory(intel.owner)
 if not inv then return nil,err end
 local stash=type(inv.stashes)=="table" and inv.stashes[intel.stash]
 if not stash or stash.map~=intel.map then S.RemoveIntelByID(holder,id,"Тайника больше нет — наводка снята");return nil end
 if not next(stash.items) then S.RemoveIntelByID(holder,id,"Тайник пуст — наводка снята");return nil end
 return intel,holder,inv,stash,owner
end
-- Открыть окно чужого тайника (после удержания E). Первое вскрытие идёт в статистику.
function S.OpenIntel(p,id)
 if not IsValid(p) or not p:Alive() or p.StalkerLoadError or S.IsUnconscious(p) then return false end
 local intel,holder,_,stash,owner=resolve(p,id)
 -- При отказе resolve вторым значением возвращает причину (или nil, если игрок уже уведомлён).
 if not intel then if holder then notify(p,holder,"warn",5) end;return false end
 if not S.StashReachable(p,stash) then notify(p,"Тайник вне досягаемости: подойдите ближе","warn",4);return false end
 if not intel.opened then
  intel.opened=true;dbSave(holder,intel)
  if C and C.AddStat then C.AddStat(p,"stashes",1) end
  if IsValid(owner) then notify(owner,"Кто-то вскрыл ваш тайник!","danger",10) end
  hook.Run("STALKER_INV_StashFound",p,intel)
  S.SendIntel(p)
 end
 p.StalkerLooting={id=id,pos=Vector(stash.pos.x,stash.pos.y,stash.pos.z)}
 S.Sync(p);S.SendForeign(p,intel,stash)
 return true
end
--[[ Забрать предмет из ячейки index (0 — всё, что влезет). Обе стороны сохраняются одной транзакцией;
 если владелец в сети, меняется и синхронизируется его живой инвентарь. ]]
function S.LootIntel(p,id,index)
 if not IsValid(p) or not p:Alive() or S.IsUnconscious(p) then return false,"Сейчас это невозможно" end
 if S.InventoryReady and not S.InventoryReady(p) then return false,"Инвентарь недоступен" end
 local looting=p.StalkerLooting
 if not looting or looting.id~=id then return false,"Сначала обыщите тайник: удерживайте E рядом с ним" end
 local intel,holder,inv,stash,owner=resolve(p,id)
 if not intel then return false,holder end
 if not S.StashReachable(p,stash) then closeForeign(p,"Вы отошли от тайника");return false end
 local limit=S.StashSlotsOf(stash)
 if index~=0 and (not S.IsInt(index,1,limit) or not stash.items[index]) then S.SendForeign(p,intel,stash);return false,"Ячейка пуста" end
 S.CaptureEquipment(p)
 local mine=table.Copy(p.StalkerInventory);local taken=0
 local function take(i)
  local item=stash.items[i];if not item then return end
  if S.FindUID(mine,item.uid) then item.uid=S.UID() end
  local before=item.count
  if S.StashTransfer(stash.items,i,mine.grid,0,40) then taken=taken+before-(stash.items[i]==item and item.count or 0) end
 end
 if index==0 then for i=1,limit do take(i) end else take(index) end
 if taken==0 then return false,"Рюкзак заполнен" end
 S.CleanQuickbar(mine)
 mine.revision=((p.StalkerInventory.revision or 0)+1)%4294967296
 inv.revision=((IsValid(owner) and owner.StalkerInventory.revision or inv.revision or 0)+1)%4294967296
 if not S.SaveInventoriesAtomic({{holder,mine},{intel.owner,inv}}) then return false,"Ошибка сохранения: ничего не изменилось" end
 p.StalkerInventory=mine;p:SetNW2Float("stalker_inv_weight",S.Weight(mine))
 if IsValid(owner) then
  owner.StalkerInventory=inv;owner:SetNW2Float("stalker_inv_weight",S.Weight(inv))
  S.RefreshStashEntities(owner);S.Sync(owner,"Кто-то забирает вещи из вашего тайника!")
 end
 local rest=next(stash.items)~=nil
 S.Sync(p,"Забрано из тайника: "..taken.." шт."..((index==0 and rest) and " Рюкзак заполнен: забрано не всё." or ""))
 hook.Run("STALKER_INV_StashLooted",p,intel.owner,intel.stash,taken)
 if rest then S.SendForeign(p,intel,stash) else S.RemoveIntelByID(holder,id,"Тайник опустошён — наводка снята") end
 return true
end

-- Точка тайника для удержания E: у чужого тайника нет сущности (её видит только владелец в сети).
local function point(pos)
 local base=Vector(pos.x,pos.y,pos.z);local center=base+Vector(0,0,8)
 return {IsValid=function() return true end,WorldSpaceCenter=function() return center end,GetPos=function() return base end}
end
-- Ближайшее место из наводок в радиусе, на которое игрок смотрит.
function S.NearestIntel(p,range)
 local best,bestD;local eye,aim=p:EyePos(),p:GetAimVector();local now=os.time()
 for _,intel in pairs((held(p))) do
  if intel.map==game.GetMap() and intel.expires>now then
   local pos=Vector(intel.pos.x,intel.pos.y,intel.pos.z);local d=p:GetPos():Distance(pos)
   if d<=range then
    local dir=pos+Vector(0,0,8)-eye;dir:Normalize()
    if dir:Dot(aim)>=.55 and (not bestD or d<bestD) then best,bestD=intel,d end
   end
  end
 end
 return best
end
-- E рядом с местом из наводки: обыск с удержанием (StashIntelHold секунд).
function S.TryIntelUse(p)
 if p.StalkerLoadError or S.IsUnconscious(p) then return false end
 local intel=S.NearestIntel(p,S.Config.StashUseRange);if not intel then return false end
 p.StashUseNext=CurTime()+.5
 local id=intel.id;local seconds=math.max(0,tonumber(S.Config.StashIntelHold) or 3)
 local H=C and C.Hold
 if H and H.Start and seconds>0 then
  return H.Start(p,point(intel.pos),seconds,"Обыск тайника",function(ply) S.OpenIntel(ply,id) end,{range=S.Config.StashUseRange,
   check=function(ply) local x=(held(ply))[id];if not x or x.expires<=os.time() then return "Наводка устарела" end end})
 end
 return S.OpenIntel(p,id)
end

net.Receive("stalker_stash.loot",function(len,p)
 if len<22 or len>1000 or not rate(p,"stash.loot",5,8) then return end
 local id=net.ReadString();local index=net.ReadUInt(6)
 if type(id)~="string" or #id<1 or #id>96 then return end
 local ok,err=S.LootIntel(p,id,index)
 if not ok and err then notify(p,err,"warn",4) end
end)

-- Смерть: решаем судьбу наводки до того, как Зона выбросит рюкзак (DoPlayerDeath идёт раньше PlayerDeath).
hook.Add("DoPlayerDeath","STALKER_INV.StashIntel",function(victim,attacker)
 victim.StalkerIntelPending=nil
 local chance=tonumber(S.Config.StashIntelChance) or 0
 if chance<=0 or math.random()*100>=chance then return end
 local intel=S.MakeStashIntel(victim);if not intel then return end
 if IsValid(attacker) and attacker:IsPlayer() and attacker~=victim and S.GiveStashIntel(attacker,intel) then return end
 victim.StalkerIntelPending=intel
end)
-- Рюкзак погибшего (stalker_zone): наводка лежит в нём, подобравший получит её через GiveStashIntel.
hook.Add("STALKER_ZONE_BagDropped","STALKER_INV.StashIntel",function(victim,bag)
 local intel=IsValid(victim) and victim.StalkerIntelPending
 if intel and IsValid(bag) then bag.StashIntel=intel;victim.StalkerIntelPending=nil end
end)
hook.Add("PlayerSpawn","STALKER_INV.StashIntel",function(p) p.StalkerIntelPending=nil;p.StalkerLooting=nil end)
-- Владельцу — сообщение о тайниках, рассекреченных в его отсутствие (один раз: notified=1).
local function announceOwner(p)
 local owner=sidOf(p);if not owner or not S.IntelReady then return end
 local n=tonumber(sql.QueryValue("SELECT COUNT(*) FROM stalker_stash_intel WHERE owner="..Q(owner).." AND notified=0 AND expires>"..os.time())) or 0
 if n<=0 then return end
 sql.Query("UPDATE stalker_stash_intel SET notified=1 WHERE owner="..Q(owner))
 local text=n==1 and "Ваш тайник рассекречен: пока вас не было, кто-то получил его координаты"
  or ("Ваши тайники рассекречены: пока вас не было, выдано наводок — "..n)
 notify(p,text,"danger",12)
 -- Клиент, ещё грузящий Lua, сообщение теряет, а notified уже 1: повторим его по STALKER_PlayerReady.
 if not p.StalkerIntelReady then p.StalkerIntelNotice=text end
end
-- Вход: метки своих наводок; владельцу — сообщение о тайниках, рассекреченных в его отсутствие.
hook.Add("PlayerInitialSpawn","STALKER_INV.StashIntel",function(p)
 timer.Simple(3,function()
  if not IsValid(p) then return end
  local list,holder=held(p)
  for _,intel in pairs(list) do setMarker(holder,intel) end
  S.SendIntel(p)
 end)
 timer.Simple(8,function() if IsValid(p) then announceOwner(p) end end)
end)
-- Клиент загрузил Lua: список наводок и уведомление из таймеров входа медленный клиент потерял — досылаем.
hook.Add("STALKER_PlayerReady","STALKER_INV.StashIntel",function(p)
 p.StalkerIntelReady=true
 S.SendIntel(p)
 if p.StalkerIntelNotice then notify(p,p.StalkerIntelNotice,"danger",12);p.StalkerIntelNotice=nil end
 announceOwner(p)
end)
hook.Add("PlayerDisconnected","STALKER_INV.StashIntel",function(p)
 local id=sidOf(p);local list=id and S.IntelHeld[id]
 if list then for intelID in pairs(list) do removeMarker(intelID) end;S.IntelHeld[id]=nil end
end)
-- Доступ к открытому чужому тайнику пропадает, если держатель ушёл: снова нужно удерживать E.
timer.Create("STALKER_INV.Looting",2,0,function()
 for _,p in ipairs(player.GetAll()) do
  local looting=p.StalkerLooting
  if looting and (not p:Alive() or not looting.pos or p:GetPos():DistToSqr(looting.pos)>(S.Config.StashRange+50)^2) then closeForeign(p) end
 end
end)
-- Истёкшие наводки снимаются у игроков в сети и вычищаются из базы.
timer.Create("STALKER_INV.IntelExpire",30,0,function()
 local now=os.time()
 for holder,list in pairs(S.IntelHeld) do
  for id,intel in pairs(list) do if intel.expires<=now then S.RemoveIntelByID(holder,id,"Наводка на тайник «"..intel.ownerName.."» устарела") end end
 end
 if S.IntelReady then sql.Query("DELETE FROM stalker_stash_intel WHERE expires<="..now) end
end)
STALKER_INV.GiveStashIntel=S.GiveStashIntel
