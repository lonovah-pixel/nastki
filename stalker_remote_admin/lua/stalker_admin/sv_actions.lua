local A=STALKER_ADMIN
A.Handlers={}
local H=A.Handlers
function A.Validate(c,a)
 local field=c.field
 if field=="reason" or field=="ban" or field=="offlineban" then
  a.reason=A.Text(a.reason);if not a.reason or #a.reason<3 then return false,"Укажите причину (3–"..A.Config.MaxReasonBytes.." байт)" end
 end
 if field=="ban" or field=="offlineban" or field=="duration" then if not A.Int(a.minutes,0,A.Config.MaxBanMinutes) then return false,"Неверный срок в минутах" end end
 if field=="amount" and not A.Int(a.amount,0,255) then return false,"Броня: 0–255" end
 if field=="dose" and not A.Int(a.amount,0,100) then return false,"Доза: 0–100" end
 if field=="money" and (not A.Int(a.amount,-1000000,1000000) or a.amount==0) then return false,"Изменение денег: −1000000…1000000, кроме 0" end
 if field=="message" then a.reason=A.Text(a.reason);if not a.reason or #a.reason<1 then return false,"Введите сообщение" end end
 if field=="weapon" and not A.Config.Weapons[a.value or ""] then return false,"Оружие не разрешено" end
 if field=="item" then
  if not STALKER_INV or not STALKER_INV.Items[a.value or ""] or not A.Int(a.amount,1,100) then return false,"Предмет недоступен / количество 1–100" end
 end
 if field=="faction" and (not STFW or not STFW.Factions or not STFW.Factions[a.value or ""] or not STFW.Factions[a.value].playable) then return false,"Группировка недоступна" end
 if field=="event" then
  local known=false;for _,e in ipairs(A.EventList()) do if e.id==a.value then known=true end end
  if not known then return false,"Событие не найдено (аддон событий не установлен?)" end
 end
 if field=="map" and (type(a.value)~="string" or not a.value:match("^[%w_%-]+$") or not file.Exists("maps/"..a.value..".bsp","GAME") or (next(A.Config.Maps) and not A.Config.Maps[a.value])) then return false,"Карта не разрешена или не установлена" end
 if c.scope=="offline" and not A.SID(a.sid) then return false,"Нужен SteamID64" end
 if field=="role" and not A.Config.Roles[a.value or ""] then return false,"Неизвестный допуск" end
 return true
end
function A.SafePosition(target,near)
 for _,offset in ipairs({Vector(80,0,0),Vector(-80,0,0),Vector(0,80,0),Vector(0,-80,0),Vector(120,120,0)}) do
  local pos=near+offset
  local tr=util.TraceHull({start=pos+Vector(0,0,64),endpos=pos-Vector(0,0,128),mins=Vector(-16,-16,0),maxs=Vector(16,16,72),filter=target,mask=MASK_PLAYERSOLID})
  if not tr.StartSolid and not tr.AllSolid and tr.Hit and tr.HitNormal.z>0.6 and util.IsInWorld(tr.HitPos) then return tr.HitPos+Vector(0,0,2) end
 end
end
local function teleport(target,near)
 if not target:Alive() then return false,"Цель мертва" end
 local pos=A.SafePosition(target,near);if not pos then return false,"Нет свободного места" end
 target.StaReturn={pos=target:GetPos(),map=game.GetMap()}
 if target:InVehicle() then target:ExitVehicle() end
 target:SetPos(pos);target:SetLocalVelocity(Vector(0,0,0));return true
end
local function inventory(target,fn)
 local S=STALKER_INV
 if not S or not target.StalkerInventory or target.StalkerLoadError then return false,"Инвентарь недоступен" end
 S.CaptureEquipment(target);local old=target.StalkerInventory;local copy,err=fn(table.Copy(old))
 if not copy then return false,err end
 copy.revision=((old.revision or 0)+1)%4294967296;target.StalkerInventory=copy
 if not S.SaveInventory(target) then target.StalkerInventory=old;return false,"Не удалось сохранить инвентарь" end
 target:SetNW2Float("stalker_inv_weight",S.Weight(copy));S.Sync(target);return true
end
H.warn=function(p,t,a) t:ChatPrint("[КОМЕНДАНТ] Предупреждение: "..a.reason);return true end
-- Кик через ULib (сообщение «Kicked by …», хук ULib для журналов), без ULib — штатный Kick.
function A.Kick(p,t,reason)
 if type(ULib)=="table" and type(ULib.kick)=="function" and pcall(ULib.kick,t,reason,IsValid(p) and p or nil) then return true end
 t:Kick(reason);return true
end
H.kick=function(p,t,a) return A.Kick(p,t,a.reason) end
function A.FormatMinutes(m)
 if m==0 then return "бессрочно" end
 if m%1440==0 then return (m/1440).." дн." end
 if m%60==0 then return (m/60).." ч" end
 return m.." мин."
end
function A.Ban(p,sid,name,a)
 if IsValid(p) and (sid==p:SteamID64() or A.OfflineRank(sid)>=A.Rank(p)) then return false,"Недостаточный допуск для этой цели" end
 local limit=IsValid(p) and A.BanLimit(A.Rank(p))
 if limit and (a.minutes==0 or a.minutes>limit) then return false,"Лимит бана для вашего уровня: "..A.FormatMinutes(limit).." (бессрочно — от уровня «Комендант»)" end
 -- Повторный бан перезаписывает запись (ULib.addBan / REPLACE) вместе с рангом автора: без проверки младший уровень
 -- сократил бы бан старшего до минуты или «присвоил» его и снял (обход проверки разбана по рангу).
 local current=A.GetBan(sid);if current==false then return false,"Ошибка хранилища" end
 if current and IsValid(p) and (tonumber(current.rank) or 100)>A.Rank(p) then return false,"Бан выдан более высоким допуском" end
 local ok,err=A.StoreBan(p,sid,name,a.reason,a.minutes);if not ok then return false,err end
 -- ULib.addBan сам отключает онлайн-цель; без ULib — отключаем здесь.
 local target=player.GetBySteamID64(sid);if IsValid(target) and not A.UsesULibBans() then target:Kick("Блокировка: "..a.reason) end
 return true
end
H.ban=function(p,t,a) return A.Ban(p,t:SteamID64(),t:Nick(),a) end
H.ban_sid=function(p,_,a) return A.Ban(p,a.sid,a.sid,a) end
H.unban=function(p,_,a)
 local ban=A.GetBan(a.sid);if ban==false then return false,"Ошибка хранилища" end
 if not ban then return false,"Активного бана нет" end
 if IsValid(p) and (tonumber(ban.rank) or 100)>A.Rank(p) then return false,"Бан выдан более высоким допуском" end
 if not A.RemoveBan(p,a.sid) then return false,"Ошибка снятия бана" end;return true
end
for _,kind in ipairs({"mute","gag"}) do local k=kind
 H[k]=function(_,t,a)
  if not A.SetSanction(t,k,a.minutes) then return false,"Ошибка записи ограничения" end
  t:ChatPrint("[КОМЕНДАНТ] "..(k=="mute" and "Чат" or "Голос").." заблокирован: "..(a.minutes==0 and "бессрочно" or a.minutes.." мин."));return true
 end
 H["un"..k]=function(_,t)
  local ok=A.Query("DELETE FROM sta_sanctions WHERE sid="..sql.SQLStr(t:SteamID64()).." AND kind="..sql.SQLStr(k))~=false
  if ok then A.SanctionCache[t:SteamID64()]=nil end;return ok
 end
end
H.freeze=function(_,t) if t:InVehicle() then t:ExitVehicle() end;t.StaFrozen=true;t:Freeze(true);return true end
H.unfreeze=function(_,t) if not t.StaFrozen then return false,"Игрок не заморожен этой системой" end;t.StaFrozen=nil;t:Freeze(false);return true end
H.heal=function(_,t) if not t:Alive() then return false,"Цель мертва" end;t:SetHealth(t:GetMaxHealth());return true end
H.armor=function(_,t,a) if not t:Alive() then return false,"Цель мертва" end;t:SetArmor(a.amount);return true end
H.respawn=function(_,t) t:Spawn();return true end
H.kill=function(_,t) if not t:Alive() then return false,"Цель уже мертва" end;t:Kill();return true end
H.god_on=function(p,t)
 if p==t and not A.Config.AllowSelfGod then return false,"Бессмертие для себя отключено" end
 if not t.StaGod then t.StaGod={previous=t:HasGodMode(),actor=A.Actor(p)};t:GodEnable() end;return true
end
H.god_off=function(_,t)
 if t.StaGod then if not t.StaGod.previous then t:GodDisable() end;t.StaGod=nil end;return true
end
H.bring=function(p,t) if not IsValid(p) or not p:Alive() then return false,"Администратор должен быть жив" end;return teleport(t,p:GetPos()) end
H["goto"]=function(p,t) if not IsValid(p) or not t:Alive() then return false,"Цель должна быть жива" end;return teleport(p,t:GetPos()) end
H["return"]=function(_,t)
 local back=t.StaReturn;if not back or back.map~=game.GetMap() then return false,"Нет точки возврата" end
 local tr=util.TraceHull({start=back.pos,endpos=back.pos,mins=Vector(-16,-16,0),maxs=Vector(16,16,72),filter=t,mask=MASK_PLAYERSOLID})
 if tr.StartSolid or tr.AllSolid or tr.Hit or not util.IsInWorld(back.pos) then return false,"Точка возврата занята" end
 if t:InVehicle() then t:ExitVehicle() end;t:SetPos(back.pos);t:SetLocalVelocity(Vector(0,0,0));t.StaReturn=nil;return true
end
H.weapon=function(_,t,a) if not t:Alive() then return false,"Цель мертва" end;return IsValid(t:Give(a.value)) end
H.item=function(_,t,a) return inventory(t,function(inv) return STALKER_INV.Insert(inv,a.value,a.amount) end) end
H.radiation=function(_,t,a)
 local R=STALKER_RAD;if not R then return false,"Система радиации не установлена" end
 -- Без загруженного инвентаря доза хранится в самой радиации; с инвентарём — сохраняется сразу одним коммитом.
 if not t.StalkerInventory and R.SetDose then
  if R.SetDose(t,a.amount)==false then return false,"Доза недоступна" end;return true
 end
 local ok,err=inventory(t,function(inv) inv.dose=a.amount;return inv end)
 if ok then if R.SetDose then R.SetDose(t,a.amount) else t:SetNW2Float("stalker_dose",a.amount) end end;return ok,err
end
H.money=function(_,t,a)
 if not t.addMoney or not t.getDarkRPVar then return false,"DarkRP недоступен" end
 local balance=t:getDarkRPVar("money")
 if type(balance)~="number" or balance+a.amount<0 or balance+a.amount>2147483647 then return false,"Баланс выходит за пределы" end
 t:addMoney(a.amount);return true
end
H.faction=function(_,t,a) if not STFW or not STFW.SetFaction then return false,"Группировки не установлены" end;return STFW.SetFaction(t,a.value,true) end
H.emission_start=function()
 if not ST_EMISSION or not ST_EMISSION.Start then return false,"Выбросы не установлены" end
 if ST_EMISSION.Start()~=true then return false,"Выброс уже идёт" end;return true
end
H.emission_stop=function()
 if not ST_EMISSION or not ST_EMISSION.Stop then return false,"Выбросы не установлены" end
 if ST_EMISSION.Stop(true)~=true then return false,"Выброс сейчас не идёт" end;return true
end
-- Перестройка Зоны: аномалии и артефакты всех полей заново (как после выброса).
H.zone_rebuild=function()
 local Z=STALKER_ZONE;if not Z or not Z.RegenerateAll then return false,"Аддон Зоны не установлен" end
 Z.RegenerateAll(true);return true
end
H.restock=function()
 local Z=STALKER_ZONE;if not Z or not Z.RestockAll then return false,"Аддон Зоны не установлен" end
 local n=Z.RestockAll();return true,nil,"Пополнено складов: "..tostring(n or 0)
end
-- Список событий от аддона событий в едином виде {id,name,active}. Формат List() допускается разный.
function A.EventList()
 local E=STALKER_EVENTS;if type(E)~="table" or type(E.List)~="function" then return {} end
 local ok,list=pcall(E.List);if not ok or type(list)~="table" then return {} end
 local out,seen={},{}
 for k,v in pairs(list) do
  local id,name,active
  if type(v)=="table" then id=v.id or (type(k)=="string" and k or nil);name=v.name or v.title or v.label;active=v.active==true or v.running==true
  elseif type(v)=="string" then id=type(k)=="string" and k or v;name=v end
  if type(id)=="string" and id~="" and #id<=64 and not seen[id] then seen[id]=true;out[#out+1]={id=id,name=tostring(name or id),active=active==true} end
 end
 table.sort(out,function(a,b) return a.id<b.id end)
 return out
end
local function eventCall(fn,id,fail)
 local E=STALKER_EVENTS;if type(E)~="table" or type(E[fn])~="function" then return false,"Аддон событий не установлен" end
 local called,ok,err=pcall(E[fn],id)
 if not called then ErrorNoHalt("[STA] STALKER_EVENTS."..fn..": "..tostring(ok).."\n");return false,"Ошибка аддона событий" end
 if ok==false or (ok==nil and err~=nil) then return false,type(err)=="string" and err or fail end
 return true
end
H.event_start=function(_,_,a) return eventCall("Start",a.value,"Событие не запущено") end
H.event_stop=function(_,_,a) return eventCall("Stop",a.value,"Событие не остановлено") end
H.announce=function(_,_,a) for _,p in ipairs(player.GetHumans()) do p:ChatPrint("[СЕТЬ ЗОНЫ] "..a.reason) end;return true end
H.cleanup=function() game.CleanUpMap();return true end
H.map=function(_,_,a) timer.Simple(1,function() RunConsoleCommand("changelevel",a.value) end);return true end
H.restart=function() timer.Simple(1,function() RunConsoleCommand("changelevel",game.GetMap()) end);return true end
H.role=function(p,_,a) return A.SetRole(p,a.sid,a.value) end
hook.Add("PlayerCanHearPlayersVoice","STALKER.AdminGag",function(_,talker) if A.GetSanction(talker,"gag") then return false,false end end)
hook.Add("PlayerSay","STALKER.AdminChat",function(p,text)
 if A.GetSanction(p,"mute") then return "" end
 if text:lower()=="!admin" or text:lower()=="/admin" then if A.Has(p,"view") then p:ConCommand("sta_menu") end;return "" end
end)
hook.Add("PlayerSpawn","STALKER.AdminEffects",function(p) timer.Simple(0,function()
 if IsValid(p) then if p.StaFrozen then p:Freeze(true) end;if p.StaGod then p:GodEnable() end end
end) end)
hook.Add("PlayerDisconnected","STALKER.AdminDisconnect",function(p) A.SanctionCache[p:SteamID64()]=nil end)
-- Prevent revoked staff from keeping self-granted immortality.
timer.Create("STALKER.AdminRevokeEffects",2,0,function()
 for _,p in ipairs(player.GetHumans()) do
  if p.StaGod and p.StaGod.actor==p:SteamID64() and not A.Has(p,"players") then H.god_off(nil,p) end
 end
end)

function A.StopWatch(p)
 if not IsValid(p) then return end
 p.StaWatch=nil;p:SetNW2Entity("sta_watch",NULL)
end
H.watch=function(p,t)
 if not IsValid(p) or p==t or not p:Alive() or not t:Alive() or p:InVehicle() then return false,"Нужны две живые цели; выйдите из транспорта" end
 p.StaWatch=t;p:SetNW2Entity("sta_watch",t);return true
end
H.watch_stop=function(p) A.StopWatch(p);return true end
hook.Add("SetupPlayerVisibility","STALKER.AdminCamera",function(p)
 if IsValid(p.StaWatch) and A.Has(p,"observe") then AddOriginToPVS(p.StaWatch:EyePos()) end
end)
hook.Add("StartCommand","STALKER.AdminCamera",function(p,cmd)
 if IsValid(p.StaWatch) then cmd:ClearButtons();cmd:ClearMovement() end
end)
hook.Add("PlayerDeath","STALKER.AdminCamera",A.StopWatch)
hook.Add("PlayerUse","STALKER.AdminCamera",function(p) if IsValid(p.StaWatch) then return false end end)
H.noclip_on=function(p,t)
 if not t:Alive() or t:InVehicle() or t.StaFrozen then return false,"Нельзя включить полёт в этом состоянии" end
 if not t.StaFlight then t.StaFlight={move=t:GetMoveType(),actor=A.Actor(p),origin=t:GetPos()};t:SetMoveType(MOVETYPE_NOCLIP) end;return true
end
H.noclip_off=function(_,t)
 if not t.StaFlight then return false,"Полёт не включён этой системой" end
 local tr=util.TraceHull({start=t:GetPos(),endpos=t:GetPos(),mins=Vector(-16,-16,0),maxs=Vector(16,16,72),filter=t,mask=MASK_PLAYERSOLID})
 if tr.StartSolid or tr.AllSolid then
  local pos=A.SafePosition(t,t.StaFlight.origin)
  if not pos then return false,"Выйдите из стены перед отключением полёта" end;t:SetPos(pos)
 end
 t:SetMoveType(t.StaFlight.move);t.StaFlight=nil;return true
end
hook.Add("PlayerNoClip","STALKER.AdminFlight",function(p,desired)
 if p.StaFlight then if not desired then H.noclip_off(nil,p) end;return false end
end)
hook.Add("PlayerSpawn","STALKER.AdminFlight",function(p) p.StaFlight=nil;A.StopWatch(p) end)
timer.Create("STALKER.AdminCameraPermissions",1,0,function()
 for _,p in ipairs(player.GetHumans()) do
  if p.StaWatch and (not IsValid(p.StaWatch) or not p.StaWatch:Alive() or not A.Has(p,"observe") or not A.CanTarget(p,p.StaWatch,A.Commands.watch)) then A.StopWatch(p) end
  if p.StaFlight and p.StaFlight.actor==p:SteamID64() and not A.Has(p,"noclip") then local ok=H.noclip_off(nil,p);if not ok then p:SetMoveType(MOVETYPE_WALK);p.StaFlight=nil end end
 end
end)
