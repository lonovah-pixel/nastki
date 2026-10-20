-- STALKER Social: хранение знакомств, контактов КПК и выбора нашивок (SQLite).
-- stalker_social_known:   кто (sid) знает кого (target), под каким именем, с какого времени, в контактах ли.
-- stalker_social_patches: выбор видимых нашивок и награды лидеров (JSON на игрока).
local S=STALKER_SOCIAL
local C=STALKER_CORE
for _,n in ipairs({"known","request","search","patches","act"}) do util.AddNetworkString("stalker_social."..n) end

S.DatabaseReady=sql.Query("CREATE TABLE IF NOT EXISTS stalker_social_known (sid TEXT NOT NULL, target TEXT NOT NULL, name TEXT NOT NULL, at INTEGER NOT NULL, contact INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (sid, target))")~=false
 and sql.Query("CREATE TABLE IF NOT EXISTS stalker_social_patches (sid TEXT PRIMARY KEY, payload TEXT NOT NULL)")~=false
if not S.DatabaseReady then ErrorNoHalt("[STALKER Social] SQLite недоступен: знакомства не сохраняются ("..tostring(sql.LastError())..")\n") end
S.KnownCache=S.KnownCache or {}
S.DataCache=S.DataCache or {}

local function cleanName(name) name=tostring(name or ""):gsub("[%c]","");return name:sub(1,64) end

--[[ Знакомые: {[sid цели]={name,at,contact}}. nil — профиль недоступен (бот, нет базы). ]]
function S.LoadKnown(ply)
 local sid=C.SID(ply);if not sid then return end
 local list=S.KnownCache[sid];if list then return list end
 if not S.DatabaseReady then return end
 local rows=sql.Query("SELECT target,name,at,contact FROM stalker_social_known WHERE sid="..sql.SQLStr(sid).." LIMIT "..S.MaxKnown)
 if rows==false then return end
 list={}
 for _,row in ipairs(rows or {}) do
  if row.target and row.target:match("^%d+$") then list[row.target]={name=row.name or "",at=tonumber(row.at) or 0,contact=row.contact=="1"} end
 end
 S.KnownCache[sid]=list
 return list
end
local function saveRow(sid,target,row)
 return sql.Query("REPLACE INTO stalker_social_known (sid,target,name,at,contact) VALUES ("..sql.SQLStr(sid)..","..sql.SQLStr(target)..","
  ..sql.SQLStr(row.name)..","..math.floor(row.at)..","..(row.contact and 1 or 0)..")")~=false
end

-- Префиксы «(шепчете) Имя» и «(кричите) Имя» DarkRP собирает на языке сервера (gmod_language сервера), а клиент сверяет
-- их со своими фразами: у игрока с английским клиентом шёпот незнакомца шёл бы с настоящим именем. Шлём фразы сервера.
function S.ChatPhrases()
 local out={}
 if DarkRP and DarkRP.getPhrase then
  for _,k in ipairs({"whisper","yell"}) do local ok,v=pcall(DarkRP.getPhrase,k);if ok and type(v)=="string" and v~="" then out[k]=v end end
 end
 return out
end
-- Список знакомых владельцу (клиент хранит его, чтобы сам решать, чьи имена показывать).
function S.SendKnown(ply)
 local list=S.LoadKnown(ply);if not list then return end
 local out={}
 for sid,row in pairs(list) do out[#out+1]={sid=sid,name=row.name,at=row.at,contact=row.contact or nil} end
 table.sort(out,function(a,b) return a.at>b.at end)
 C.Send("stalker_social.known",ply,{list=out,phrases=S.ChatPhrases()})
end

-- viewer узнаёт имя target. Возвращает true, впервые ли (или false и причину).
function S.Learn(viewer,target)
 local vs,ts=C.SID(viewer),C.SID(target)
 if not vs or not ts or vs==ts then return false,"Знакомство недоступно" end
 local list=S.LoadKnown(viewer);if not list then return false,"Хранилище знакомств недоступно" end
 local old=list[ts]
 if not old and table.Count(list)>=S.MaxKnown then return false,"Список знакомых переполнен" end
 local row={name=cleanName(target:Nick()),at=old and old.at or os.time(),contact=old and old.contact or false}
 if not saveRow(vs,ts,row) then return false,"Ошибка записи" end
 list[ts]=row
 S.SendKnown(viewer)
 if not old then hook.Run("STALKER_SOCIAL_Introduced",target,viewer) end
 return true,old==nil
end
-- Добавить в контакты КПК / убрать (знакомство остаётся).
function S.SetContact(ply,sid,on)
 local list=S.LoadKnown(ply);local row=list and list[sid]
 if not row then return false,"Сначала познакомьтесь" end
 if row.contact==(on==true) then return true end
 local copy={name=row.name,at=row.at,contact=on==true}
 if not saveRow(C.SID(ply),sid,copy) then return false,"Ошибка записи" end
 list[sid]=copy;S.SendKnown(ply)
 return true
end
-- Забыть знакомство (и контакт).
function S.Forget(ply,sid)
 local mine=C.SID(ply);local list=S.LoadKnown(ply)
 if not mine or not list or not list[sid] then return false,"Такого знакомства нет" end
 if sql.Query("DELETE FROM stalker_social_known WHERE sid="..sql.SQLStr(mine).." AND target="..sql.SQLStr(sid))==false then return false,"Ошибка записи" end
 list[sid]=nil;S.SendKnown(ply)
 return true
end

--[[ Нашивки игрока: {visible={жетоны}, chosen=bool, awards={[id]={faction,by,bySid,at}}} ]]
local function defaults() return {visible={},chosen=false,awards={}} end
function S.LoadData(ply)
 local sid=C.SID(ply);if not sid then return end
 local d=S.DataCache[sid];if d then return d end
 d=defaults()
 if S.DatabaseReady then
  local rows=sql.Query("SELECT payload FROM stalker_social_patches WHERE sid="..sql.SQLStr(sid))
  if rows==false then return end
  local raw=rows and rows[1] and util.JSONToTable(rows[1].payload or "")
  if type(raw)=="table" then
   for _,t in ipairs(type(raw.visible)=="table" and raw.visible or {}) do if S.ValidToken(t) and #d.visible<5 then d.visible[#d.visible+1]=t end end
   d.chosen=raw.chosen==true
   for id,a in pairs(type(raw.awards)=="table" and raw.awards or {}) do
    if S.AwardByID[id] and type(a)=="table" and type(a.faction)=="string" then
     d.awards[id]={faction=a.faction,by=cleanName(a.by),bySid=tostring(a.bySid or ""),at=tonumber(a.at) or 0}
    end
   end
  end
 end
 S.DataCache[sid]=d
 return d
end
function S.SaveData(ply,d)
 local sid=C.SID(ply);if not sid or not S.DatabaseReady then return false end
 return sql.Query("REPLACE INTO stalker_social_patches (sid,payload) VALUES ("..sql.SQLStr(sid)..","..sql.SQLStr(util.TableToJSON(d))..")")~=false
end

-- Вход: свежее имя в чужих списках (контакты показывают имя и вне сети), нашивки (NW2 доходят и позже).
hook.Add("PlayerInitialSpawn","STALKER_SOCIAL.Store",function(ply)
 local sid=C.SID(ply)
 if sid and S.DatabaseReady then
  local name=cleanName(ply:Nick())
  sql.Query("UPDATE stalker_social_known SET name="..sql.SQLStr(name).." WHERE target="..sql.SQLStr(sid))
  for _,list in pairs(S.KnownCache) do if list[sid] then list[sid].name=name end end
 end
 timer.Simple(2,function() if IsValid(ply) and S.RefreshPatches then S.RefreshPatches(ply) end end)
end)
-- Список знакомых — когда Lua клиента уже работает: сообщение из PlayerInitialSpawn (даже через 2 с) медленный клиент теряет.
hook.Add("STALKER_PlayerReady","STALKER_SOCIAL.Store",function(ply) if IsValid(ply) then S.SendKnown(ply) end end)
hook.Add("PlayerDisconnected","STALKER_SOCIAL.Store",function(ply)
 local sid=C.SID(ply);if sid then S.KnownCache[sid]=nil;S.DataCache[sid]=nil end
end)
