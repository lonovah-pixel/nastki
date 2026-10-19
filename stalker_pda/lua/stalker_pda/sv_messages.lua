-- Личные сообщения КПК. Получатель в сети получает сообщение сразу, офлайн — при следующем входе (непрочитанные
-- хранятся в SQLite stalker_pda_messages). Каждая сторона может скрыть переписку у себя; строка удаляется,
-- когда её скрыли обе стороны или истёк срок хранения (pda.message_days).
local P=STALKER_PDA
local C=STALKER_CORE
local cfg=P.Config
util.AddNetworkString("stalker_pda.req")
util.AddNetworkString("stalker_pda.data")

local T="stalker_pda_messages"
local function q(s) return sql.SQLStr(s) end
P.DB=sql.Query("CREATE TABLE IF NOT EXISTS "..T.." (id INTEGER PRIMARY KEY AUTOINCREMENT, sender TEXT NOT NULL, recipient TEXT NOT NULL,"..
 " sender_name TEXT, recipient_name TEXT, body TEXT NOT NULL, sent INTEGER NOT NULL, seen INTEGER NOT NULL DEFAULT 0,"..
 " del_s INTEGER NOT NULL DEFAULT 0, del_r INTEGER NOT NULL DEFAULT 0)")~=false
if P.DB then
 sql.Query("CREATE INDEX IF NOT EXISTS stalker_pda_messages_rcpt ON "..T.." (recipient, seen)")
 sql.Query("CREATE INDEX IF NOT EXISTS stalker_pda_messages_sndr ON "..T.." (sender)")
else
 ErrorNoHalt("[STALKER PDA] Не удалось создать таблицу сообщений: "..tostring(sql.LastError()).."\n")
end
-- Кто был на сервере в этом сеансе: им можно написать и после выхода (имя — для списка собеседников).
P.Seen=P.Seen or {}
-- Под каким именем игрок видел собеседника в сети (модуль знакомств может скрывать ники) — после выхода собеседника
-- КПК показывает то же имя, а не настоящий ник. [sid смотрящего][sid собеседника]=имя; живёт до выхода смотрящего.
P.ShownNames=P.ShownNames or {}
function P.Remember(viewer,other,name)
 if type(viewer)~="string" or type(other)~="string" or type(name)~="string" or name=="" then return end
 local t=P.ShownNames[viewer];if not t then t={};P.ShownNames[viewer]=t end
 t[other]=name
end

function P.Push(ply,data) if IsValid(ply) then C.Send("stalker_pda.data",ply,data) end end

function P.UnreadCount(sid)
 if not P.DB or not sid then return 0 end
 return tonumber(sql.QueryValue("SELECT COUNT(*) FROM "..T.." WHERE recipient="..q(sid).." AND seen=0 AND del_r=0")) or 0
end

-- Имя офлайн-собеседника для sid: из последней переписки, из увиденного в этом сеансе, иначе позывной сети
-- (ник; при модуле знакомств — «Неизвестный сталкер», чтобы не раскрыть скрытое имя). nil — абонент неизвестен.
function P.KnownName(sid,other)
 if P.DB then
  local rows=sql.Query("SELECT sender,sender_name,recipient_name FROM "..T.." WHERE (sender="..q(sid).." AND recipient="..q(other)..") OR (sender="..q(other)..
   " AND recipient="..q(sid)..") ORDER BY id DESC LIMIT 1")
  local r=type(rows)=="table" and rows[1]
  if r then local name=r.sender==sid and r.recipient_name or r.sender_name;if name and name~="" then return name end end
 end
 local shown=P.ShownNames[sid] and P.ShownNames[sid][other]
 if shown then return shown end
 local nick=P.Seen[other]
 if nick and STALKER_SOCIAL and STALKER_SOCIAL.DisplayName then return "Неизвестный сталкер" end
 return nick
end

local function insert(from,to,fromName,toName,body)
 local ok=sql.Query(string.format("INSERT INTO %s (sender,recipient,sender_name,recipient_name,body,sent) VALUES(%s,%s,%s,%s,%s,%d)",
  T,q(from),q(to),q(fromName or ""),q(toName or ""),q(body),os.time()))
 if ok==false then return end
 return tonumber(sql.QueryValue("SELECT last_insert_rowid()"))
end

--[[ Отправка от игрока. Возвращает true, сообщение — или false, текст ошибки для отправителя. ]]
function P.SendMessage(ply,to,text)
 local sid=C.SID(ply)
 if not sid then return false,"Сообщения КПК доступны только игрокам Steam" end
 if not P.DB then return false,"Хранилище сообщений недоступно" end
 if not P.ValidSID(to) then return false,"Неверный адресат" end
 if to==sid then return false,"Нельзя написать самому себе" end
 -- Мут ULX (ulx mute) запрещает и личные сообщения КПК, иначе он обходится через КПК.
 if ply:GetNWBool("ulx_muted",false)==true then return false,"Вам запрещено писать: администрация отключила вам чат" end
 -- Без сознания КПК закрыт на клиенте, но запрос можно отправить и в обход окна — проверяем на сервере.
 if C.Unconscious(ply) then return false,"Вы без сознания: КПК недоступен" end
 local body,err=P.CleanText(text)
 if not body then return false,P.TextErrors[err] or "Недопустимое сообщение" end
 local wait=(ply.StalkerPDANext or 0)-CurTime()
 if wait>0 then return false,string.format("Подождите %d с перед следующим сообщением",math.ceil(wait)) end
 local target=C.PlayerBySID(to)
 local toName=IsValid(target) and P.NameFor(ply,target) or P.KnownName(sid,to)
 if not toName then return false,"Адресат не найден в сети КПК" end
 local unread=tonumber(sql.QueryValue("SELECT COUNT(*) FROM "..T.." WHERE sender="..q(sid).." AND recipient="..q(to).." AND seen=0 AND del_r=0")) or 0
 if unread>=cfg.UnreadLimit then return false,"Адресат ещё не прочитал ваши прошлые сообщения" end
 if hook.Run("STALKER_PDA_CanMessage",ply,to,body)==false then return false,"Сообщение не отправлено" end
 -- Имя отправителя глазами получателя; получатель офлайн — как он видел отправителя раньше, иначе позывной сети КПК.
 local fromName=IsValid(target) and P.NameFor(target,ply) or P.KnownName(to,sid) or ply:Nick()
 if IsValid(target) then P.Remember(sid,to,toName);P.Remember(to,sid,fromName) end
 local id=insert(sid,to,fromName,toName,body)
 if not id then return false,"Ошибка записи сообщения" end
 ply.StalkerPDANext=CurTime()+cfg.MessageInterval
 local msg={id=id,from=sid,to=to,text=body,t=os.time()}
 if IsValid(target) then P.Push(target,{kind="msg",msg=msg,name=fromName,unread=P.UnreadCount(to)}) end
 hook.Run("STALKER_PDA_Message",ply,to,body,target)
 return true,msg
end

--[[ Служебное сообщение от NPC/системы (задания, торговцы, события): P.SystemMessage(ply|sid, text, {key="sidor", name="Сидорович"}).
 Ответить на него нельзя. Офлайн-получатель прочитает его при входе. ]]
function P.SystemMessage(target,text,from)
 if not P.DB then return false end
 local to=type(target)=="string" and target or C.SID(target)
 if not P.ValidSID(to) then return false end
 from=type(from)=="table" and from or {}
 local key=tostring(from.key or "zone"):gsub("[^%w_]","_"):sub(1,32)
 key="sys."..(key~="" and key or "zone")
 local body=P.CleanText(text,1000);if not body then return false end
 local name=type(from.name)=="string" and from.name~="" and from.name:sub(1,64) or "Сеть КПК"
 local id=insert(key,to,name,"",body);if not id then return false end
 local ply=C.PlayerBySID(to)
 if IsValid(ply) then P.Push(ply,{kind="msg",msg={id=id,from=key,to=to,text=body,t=os.time(),system=true},name=name,unread=P.UnreadCount(to)}) end
 return true,id
end

-- Список переписок: последнее сообщение, непрочитанные, имя собеседника (в сети — как его видит игрок сейчас).
function P.Inbox(ply)
 local sid=C.SID(ply);if not sid or not P.DB then return {} end
 local rows=sql.Query("SELECT sender,recipient,sender_name,recipient_name,body,sent,seen FROM "..T.." WHERE (sender="..q(sid)..
  " AND del_s=0) OR (recipient="..q(sid).." AND del_r=0) ORDER BY id DESC LIMIT 1500")
 local list,index={},{}
 for _,r in ipairs(type(rows)=="table" and rows or {}) do
  local mine=r.sender==sid;local other=mine and r.recipient or r.sender
  local c=index[other]
  if not c and #list<80 then
   c={sid=other,name=(mine and r.recipient_name or r.sender_name) or "",last=P.Head(r.body,90),
    t=tonumber(r.sent) or 0,mine=mine,unread=0,system=P.IsSystem(other) or nil}
   index[other]=c;list[#list+1]=c
  end
  if c and not mine and r.seen=="0" then c.unread=c.unread+1 end
 end
 for _,c in ipairs(list) do
  local p=not c.system and C.PlayerBySID(c.sid)
  if IsValid(p) then c.online=true;c.name=P.NameFor(ply,p);P.Remember(sid,c.sid,c.name) end
  if c.name=="" then c.name=(not c.system and P.KnownName(sid,c.sid)) or "Неизвестный абонент" end
 end
 return list
end
function P.SendInbox(ply) P.Push(ply,{kind="inbox",list=P.Inbox(ply),unread=P.UnreadCount(C.SID(ply))}) end

-- Переписка с собеседником: последние сообщения (не больше ~40 КБ текста), входящие помечаются прочитанными.
function P.Thread(ply,other)
 local sid=C.SID(ply);if not sid or not P.DB then return {} end
 local rows=sql.Query("SELECT id,sender,body,sent,seen FROM "..T.." WHERE (sender="..q(sid).." AND recipient="..q(other).." AND del_s=0) OR (sender="..q(other)..
  " AND recipient="..q(sid).." AND del_r=0) ORDER BY id DESC LIMIT "..math.floor(cfg.HistoryLimit))
 local list,bytes={},0
 for _,r in ipairs(type(rows)=="table" and rows or {}) do
  bytes=bytes+#(r.body or "");if bytes>40000 then break end
  table.insert(list,1,{id=tonumber(r.id),mine=r.sender==sid,text=r.body,t=tonumber(r.sent) or 0,seen=r.seen=="1"})
 end
 return list
end
function P.MarkRead(ply,other)
 local sid=C.SID(ply);if not sid or not P.DB then return end
 local n=tonumber(sql.QueryValue("SELECT COUNT(*) FROM "..T.." WHERE sender="..q(other).." AND recipient="..q(sid).." AND seen=0")) or 0
 if n==0 then return end
 sql.Query("UPDATE "..T.." SET seen=1 WHERE sender="..q(other).." AND recipient="..q(sid).." AND seen=0")
 -- Отправитель в сети видит отметку «прочитано».
 local from=C.PlayerBySID(other);if IsValid(from) then P.Push(from,{kind="seen",sid=sid}) end
end
function P.SendThread(ply,other)
 P.MarkRead(ply,other)
 local sid=C.SID(ply)
 local p=not P.IsSystem(other) and C.PlayerBySID(other)
 local name=IsValid(p) and P.NameFor(ply,p) or P.KnownName(sid,other) or "Неизвестный абонент"
 if IsValid(p) then P.Remember(sid,other,name) end
 P.Push(ply,{kind="thread",sid=other,name=name,
  online=IsValid(p) or nil,system=P.IsSystem(other) or nil,messages=P.Thread(ply,other),unread=P.UnreadCount(C.SID(ply))})
end

-- Скрыть переписку у себя. Строки, скрытые обеими сторонами, удаляются сразу.
function P.DeleteThread(ply,other)
 local sid=C.SID(ply);if not sid or not P.DB then return end
 sql.Query("UPDATE "..T.." SET del_s=1 WHERE sender="..q(sid).." AND recipient="..q(other))
 sql.Query("UPDATE "..T.." SET del_r=1, seen=1 WHERE sender="..q(other).." AND recipient="..q(sid))
 sql.Query("DELETE FROM "..T.." WHERE (del_s=1 AND del_r=1) OR (sender LIKE 'sys.%' AND del_r=1)")
end

function P.Purge()
 if not P.DB then return end
 local before=os.time()-math.floor(cfg.MessageDays*86400)
 sql.Query("DELETE FROM "..T.." WHERE sent<"..before.." OR (del_s=1 AND del_r=1) OR (sender LIKE 'sys.%' AND del_r=1)")
end
timer.Create("STALKER_PDA.Purge",3600,0,P.Purge)
timer.Simple(5,P.Purge)
hook.Add("STALKER_SettingChanged","STALKER_PDA.Purge",function(id) if id=="pda.message_days" then P.Purge() end end)

-- Запросы клиента. Все поля проверяются; частота — общим ведром ядра и паузой между отправками.
local ops={}
function ops.inbox(ply) P.SendInbox(ply) end
function ops.thread(ply,a) if P.ValidSID(a.sid) or P.IsSystem(a.sid) then P.SendThread(ply,a.sid) end end
function ops.read(ply,a)
 if not (P.ValidSID(a.sid) or P.IsSystem(a.sid)) then return end
 P.MarkRead(ply,a.sid);P.Push(ply,{kind="unread",n=P.UnreadCount(C.SID(ply)),sid=a.sid})
end
function ops.send(ply,a)
 -- Ответ нужен и при отказе: клиент ждёт результата, чтобы вернуть текст в поле ввода.
 local ok,res
 if C.Rate(ply,"pda.send",1,3) then ok,res=P.SendMessage(ply,a.to,a.text) else ok,res=false,"Слишком часто: подождите немного" end
 P.Push(ply,{kind="result",ok=ok,to=type(a.to)=="string" and a.to:sub(1,20) or nil,msg=ok and res or nil,error=not ok and res or nil,
  next=ok and cfg.MessageInterval or nil})
end
function ops.delete(ply,a)
 if not (P.ValidSID(a.sid) or P.IsSystem(a.sid)) then return end
 P.DeleteThread(ply,a.sid);P.SendInbox(ply)
end
net.Receive("stalker_pda.req",function(len,ply)
 if not C.Rate(ply,"pda.req",4,10) then return end
 local a=C.Read(len,8000);if type(a)~="table" or type(a.op)~="string" then return end
 local fn=ops[a.op];if fn then fn(ply,a) end
end)

-- Вход: офлайн-сообщения ждут в КПК, игрок получает уведомление.
local function announce(ply)
 local sid=C.SID(ply);if not sid then return end
 local n=P.UnreadCount(sid)
 P.Push(ply,{kind="unread",n=n})
 if n>0 and C.Notify then C.Notify(ply,"Непрочитанных сообщений в КПК: "..n..". Откройте КПК (F4) → «Сообщения».","info",9) end
end
hook.Add("PlayerInitialSpawn","STALKER_PDA.Messages",function(ply)
 local sid=C.SID(ply);if not sid then return end
 P.Seen[sid]=ply:Nick()
 -- Клиент уже загрузился (STALKER_PlayerReady) — он получил или получит сообщение оттуда, второй раз не нужно.
 timer.Simple(6,function() if IsValid(ply) and not ply.StalkerPDAAnnounced then announce(ply) end end)
end)
-- Таймер выше — запасной путь: медленный клиент к 6-й секунде ещё грузит Lua и теряет значок и уведомление.
hook.Add("STALKER_PlayerReady","STALKER_PDA.Messages",function(ply)
 if ply.StalkerPDAAnnounced then return end
 ply.StalkerPDAAnnounced=true;announce(ply)
end)
hook.Add("PlayerDisconnected","STALKER_PDA.Messages",function(ply) local sid=C.SID(ply);if sid then P.Seen[sid]=ply:Nick();P.ShownNames[sid]=nil end end)

-- Чат: !pda, !кпк (в любом регистре), /pda.
local chat={["!pda"]=true,["/pda"]=true,["!кпк"]=true,["/кпк"]=true}
hook.Add("PlayerSay","STALKER_PDA.Chat",function(ply,text)
 local cmd=P.Lower(string.Trim(tostring(text or "")))
 if chat[cmd] then ply:ConCommand("stalker_pda");return "" end
end)
