-- Прогресс заданий игроков: SQLite stalker_quests (sid → JSON). Активные задания, история, счётчик выполненных,
-- откаты шаблонов, суточный лимит, обучение и отслеживаемое задание.
local Q=STALKER_QUESTS
local C=STALKER_CORE
local Cfg=Q.Config
Q.DBReady=sql.Query("CREATE TABLE IF NOT EXISTS stalker_quests (sid TEXT PRIMARY KEY, payload TEXT NOT NULL)")~=false
Q.Players=Q.Players or {}
Q.SaveQueue=Q.SaveQueue or {}

function Q.NewData() return {version=1,seq=0,active={},history={},done=0,cooldowns={},daily={day="",n=0}} end
function Q.Today() return os.date("%Y-%m-%d") end

local function num(v,lo,hi,def) if C.Num(v,lo,hi) then return v end;return def end
local function str(v,max) if type(v)=="string" and #v<=(max or 256) and not v:find("[%c]") then return v end end
local function vec(t) if type(t)=="table" and C.Num(t.x,-1e7,1e7) and C.Num(t.y,-1e7,1e7) and C.Num(t.z,-1e7,1e7) then return {x=t.x,y=t.y,z=t.z} end end
local function reward(r)
 r=type(r)=="table" and r or {}
 local items={}
 for _,it in ipairs(type(r.items)=="table" and r.items or {}) do
  if type(it)=="table" and str(it[1],48) and C.Int(it[2],1,999) then items[#items+1]={it[1],it[2]} end
 end
 return {money=math.floor(num(r.money,0,1e9,0)),rep=math.floor(num(r.rep,-1000,1000,0)),faction=str(r.faction,32),items=items}
end
local function strList(t,max)
 local out={};for _,v in ipairs(type(t)=="table" and t or {}) do if str(v,64) and #out<(max or 64) then out[#out+1]=v end end;return out
end

-- Задание из сохранения: всё приводится к ожидаемым типам, мусор отбрасывается.
function Q.ValidQuest(a)
 if type(a)~="table" or not Q.Types[a.type or ""] or not str(a.uid,16) or not str(a.title,200) then return end
 local q={uid=a.uid,tpl=str(a.tpl,48) or "",type=a.type,title=a.title,desc=str(a.desc,1000) or "",profile=str(a.profile,32) or "",
  giver=str(a.giver,32) or "",giverName=str(a.giverName,256) or "квестодатель",goal=math.floor(num(a.goal,1,1000,1)),
  accepted=math.floor(num(a.accepted,0,4e9,os.time())),expires=math.floor(num(a.expires,0,4e9,os.time()+3600)),
  reward=reward(a.reward),news=a.news==true,done=a.done==true,what=str(a.what,200)}
 -- armed («жив при начале выброса») не восстанавливаем: профиль читается заново только после выхода или рестарта,
 -- а перезаход посреди выброса — возрождение у точки появления, как после гибели (гибель armed сбрасывает).
 q.progress=math.floor(math.Clamp(num(a.progress,0,1000,0),0,q.goal))
 if q.type=="fetch" then q.items=strList(a.items);if #q.items==0 then return end end
 if q.type=="kill" then q.mutants=a.mutants and strList(a.mutants) or nil;q.classes=strList(a.classes) end
 if q.type=="visit" then
  local p=type(a.place)=="table" and a.place
  if not p or not vec(p.pos) then return end
  q.place={name=str(p.name,256) or "место",pos=vec(p.pos),radius=math.floor(num(p.radius,50,5000,Cfg.VisitRadius))}
 end
 if q.type=="deliver" then q.to=str(a.to,32);q.toName=str(a.toName,256) or "получатель";if not q.to then return end end
 if type(a.hint)=="table" and vec(a.hint.pos) then q.hint={name=str(a.hint.name,256) or "",pos=vec(a.hint.pos)} end
 return q
end
function Q.ValidData(raw)
 local d=Q.NewData()
 if type(raw)~="table" then return d end
 d.seq=math.floor(num(raw.seq,0,1e9,0));d.done=math.floor(num(raw.done,0,1e9,0))
 for _,a in ipairs(type(raw.active)=="table" and raw.active or {}) do
  local q=Q.ValidQuest(a);if q and #d.active<10 then d.active[#d.active+1]=q end
 end
 for _,h in ipairs(type(raw.history)=="table" and raw.history or {}) do
  if type(h)=="table" and str(h.title,200) and #d.history<100 then
   d.history[#d.history+1]={title=h.title,status=str(h.status,16) or "done",t=math.floor(num(h.t,0,4e9,0)),money=math.floor(num(h.money,0,1e9,0)),giver=str(h.giver,256)}
  end
 end
 for id,t in pairs(type(raw.cooldowns)=="table" and raw.cooldowns or {}) do
  if str(id,48) and C.Num(t,0,4e9) and t>os.time() then d.cooldowns[id]=math.floor(t) end
 end
 if type(raw.daily)=="table" and str(raw.daily.day,16) then d.daily={day=raw.daily.day,n=math.floor(num(raw.daily.n,0,1e6,0))} end
 d.tracked=str(raw.tracked,16)
 if type(raw.tut)=="table" then
  local state=raw.tut.state
  if state=="active" or state=="done" or state=="skipped" then
   d.tut={state=state,step=math.floor(math.Clamp(num(raw.tut.step,1,100,1),1,#Q.TutorialSteps+1)),started=math.floor(num(raw.tut.started,0,4e9,os.time()))}
  end
 end
 return d
end

-- Профиль игрока (nil — бот или игрок без SteamID: задания не сохраняются).
function Q.Data(ply)
 local sid=C.SID(ply);if not sid then return end
 local d=Q.Players[sid];if d then return d end
 if not Q.DBReady then return end
 local rows=sql.Query("SELECT payload FROM stalker_quests WHERE sid="..sql.SQLStr(sid))
 if rows==false then return end
 if rows and rows[1] then
  local raw=util.JSONToTable(rows[1].payload or "")
  if type(raw)~="table" then
   -- Повреждённую запись не теряем: копия под отдельным ключом, игрок начинает с чистого листа.
   sql.Query("REPLACE INTO stalker_quests VALUES("..sql.SQLStr("broken:"..sid..":"..os.time())..","..sql.SQLStr(rows[1].payload or "")..")")
   ErrorNoHalt("[STALKER Quests] Повреждён профиль заданий "..sid.."; сохранена копия broken:"..sid.."\n")
  end
  d=Q.ValidData(raw)
 else d=Q.NewData() end
 Q.Players[sid]=d
 return d
end
function Q.Loaded(ply) local sid=C.SID(ply);return sid and Q.Players[sid] end

function Q.Save(ply)
 local sid=C.SID(ply);local d=sid and Q.Players[sid]
 if not d or not Q.DBReady then return false end
 Q.SaveQueue[sid]=nil
 local payload=util.TableToJSON(d);if not payload then return false end
 return sql.Query("REPLACE INTO stalker_quests VALUES("..sql.SQLStr(sid)..","..sql.SQLStr(payload)..")")~=false
end
-- Прогресс убийств и находок пишется пачкой раз в 15 секунд; взятие и сдача — сразу.
function Q.SaveSoon(ply) local sid=C.SID(ply);if sid then Q.SaveQueue[sid]=true end end
function Q.FlushSaves()
 for sid in pairs(Q.SaveQueue) do
  local p=C.PlayerBySID(sid)
  if IsValid(p) then Q.Save(p) else Q.SaveQueue[sid]=nil end
 end
end
timer.Create("STALKER_QUESTS.Save",15,0,Q.FlushSaves)
hook.Add("ShutDown","STALKER_QUESTS.Save",function() for _,p in ipairs(player.GetHumans()) do Q.Save(p) end end)

-- Суточный лимит обнуляется с началом новых суток (время сервера).
function Q.ResetDaily(d)
 local today=Q.Today()
 if d.daily.day~=today then d.daily={day=today,n=0} end
end
-- Откат шаблона: true, если шаблон ещё недоступен (и сколько секунд осталось).
function Q.OnCooldown(d,tpl)
 local t=d.cooldowns[tpl];if not t then return false end
 if t<=os.time() then d.cooldowns[tpl]=nil;return false end
 return true,t-os.time()
end
function Q.FindActive(d,uid)
 for i,q in ipairs(d.active) do if q.uid==uid then return q,i end end
end
function Q.HasTemplate(d,tpl)
 for _,q in ipairs(d.active) do if q.tpl==tpl then return true end end
 return false
end
