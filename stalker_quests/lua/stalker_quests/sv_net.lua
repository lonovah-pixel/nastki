-- Сеть: разговор с квестодателем, действия игрока (взять, сдать, отказаться, отслеживать, обучение) и админ-панель.
-- Каждое действие проверяется на сервере: частота, расстояние до квестодателя, права, состояние задания.
local Q=STALKER_QUESTS
local C=STALKER_CORE
local MK=STALKER_MARKERS
local Cfg=Q.Config
function Q.Log(text) print("[STALKER Quests] "..text) end
local function who(ply) return IsValid(ply) and (ply:Nick().." ("..tostring(ply:SteamID64())..")") or "консоль" end

function Q.CanTalk(ply,ent)
 if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or C.Unconscious(ply) then return false end
 if not IsValid(ent) or ent:GetClass()~="stalker_quest_npc" or ent:GetNpcID()=="" then return false end
 return ply:GetPos():DistToSqr(ent:GetPos())<=Cfg.TalkDistance^2
end
function Q.Greeting(ply,d,prof)
 if Q.TutorialActive(d) then
  return "Новенький? Не робей. Загляни в КПК (F4), вкладка «Задания» — там «Путь новичка». А работа для тебя найдётся."
 end
 local list=prof and prof.greetings or {}
 return list[math.random(math.max(1,#list))] or "Есть работа, сталкер."
end
function Q.DialogView(ply,ent,result)
 local d=Q.Data(ply);if not d then return end
 Q.ResetDaily(d)
 local prof=Q.Profiles[ent:GetProfile()] or {}
 local full=#d.active>=Cfg.MaxActive
 local limit=Cfg.DailyLimit>0 and d.daily.n>=Cfg.DailyLimit
 local blocked=full and ("Не больше "..Cfg.MaxActive.." активных заданий") or (limit and "Лимит заданий на сегодня исчерпан") or nil
 local out={npc=ent:EntIndex(),id=ent:GetNpcID(),name=Q.NPCName(ent),title=prof.title,profile=ent:GetProfile(),about=prof.about,
  greeting=Q.Greeting(ply,d,prof),offers={},turnins={},active=#d.active,max=Cfg.MaxActive,daily=Cfg.DailyLimit,today=d.daily.n,result=result}
 for _,o in ipairs(Q.Offers(ply,ent)) do
  local q=o.q
  out.offers[#out.offers+1]={key=o.key,title=q.title,desc=q.desc,type=q.type,objective=Q.Objective(q),goal=q.goal,
   time=math.max(1,math.floor((q.time or 30)*Cfg.TimeMult)),reward=q.reward,blocked=blocked}
 end
 for _,q in ipairs(d.active) do
  if Q.TurnInHere(q,ent) then
   local ok,why=Q.Ready(ply,q)
   out.turnins[#out.turnins+1]={uid=q.uid,title=q.title,objective=Q.Objective(q),progress=q.progress,goal=q.goal,ready=ok==true,reason=why,reward=q.reward,deliver=q.type=="deliver"}
  end
 end
 out.tutorial=Q.TutorialDialog(ply,d,ent)
 return out
end
function Q.SendDialog(ply,ent,result)
 local v=Q.DialogView(ply,ent,result)
 if v then C.Send("stalker_quests.dialog",ply,v) end
end
-- Вызывается из ENT:Use квестодателя.
function Q.OpenDialog(ply,ent)
 if not Q.CanTalk(ply,ent) or not C.Rate(ply,"quests.talk",1,3) then return end
 if not Q.Data(ply) then C.Notify(ply,"Задания недоступны: профиль не загружен","warn",5);return end
 Q.SendDialog(ply,ent)
end

--[[ Действия игрока ]]
-- У квестодателя (нужен ent рядом с игроком): ответ — обновлённое окно разговора.
Q.NPCActions={
 talk=function() return true end,
 accept=function(ply,a,ent) if type(a.key)~="string" or #a.key>16 then return false,"Некорректный запрос" end;return Q.Accept(ply,ent,a.key) end,
 turnin=function(ply,a,ent) if type(a.uid)~="string" or #a.uid>16 then return false,"Некорректный запрос" end;return Q.TurnIn(ply,ent,a.uid) end,
 handover=function(ply,a,ent) return Q.TutorialHandover(ply,ent) end,
}
-- Из КПК: ответ — уведомление и новое состояние.
Q.SelfActions={
 state=function(ply) Q.Changed(ply);return true end,
 abandon=function(ply,a) if type(a.uid)~="string" or #a.uid>16 then return false,"Некорректный запрос" end;return Q.Abandon(ply,a.uid) end,
 track=function(ply,a) if a.uid~=nil and (type(a.uid)~="string" or #a.uid>16) then return false,"Некорректный запрос" end;return Q.Track(ply,a.uid) end,
 tutorial_skip=function(ply) return Q.TutorialSkipStep(ply) end,
 tutorial_stop=function(ply) return Q.TutorialStop(ply) end,
 tutorial_resume=function(ply) return Q.TutorialResume(ply) end,
 -- Клиент сообщает, что открыт КПК (F4 или вкладка «Задания»): засчитывается только на шаге обучения «КПК».
 pda=function(ply) Q.TutorialEvent(ply,"pda");return true end,
}
local silent={state=true,track=true,pda=true}
net.Receive("stalker_quests.action",function(len,ply)
 if not C.Rate(ply,"quests.action",3,6) then return end
 local a=C.Read(len,1000);if type(a)~="table" or type(a.op)~="string" then return end
 if not Q.Data(ply) then return end
 local fn=Q.NPCActions[a.op]
 if fn then
  local ent=C.Int(a.npc,1,65535) and Entity(a.npc)
  if not Q.CanTalk(ply,ent) then C.Notify(ply,"Подойдите ближе к квестодателю","warn",4);return end
  local ok,res,msg=pcall(fn,ply,a,ent)
  if not ok then ErrorNoHalt("[STALKER Quests] "..a.op..": "..tostring(res).."\n");res,msg=false,"Ошибка действия" end
  Q.SendDialog(ply,ent,a.op~="talk" and {op=a.op,ok=res~=false,message=msg} or nil)
  Q.Changed(ply)
  return
 end
 fn=Q.SelfActions[a.op];if not fn then return end
 local ok,res,msg=pcall(fn,ply,a)
 if not ok then ErrorNoHalt("[STALKER Quests] "..a.op..": "..tostring(res).."\n");res,msg=false,"Ошибка действия" end
 if msg and (res==false or not silent[a.op]) then C.Notify(ply,msg,res==false and "warn" or "ok",5) end
 if a.op=="state" then Q.Dirty[ply]=nil;Q.RefreshMarkers(ply,Q.Data(ply));Q.SendState(ply) end
end)

--[[ Админ-панель (право quests) ]]
local function vec3(v) return {x=math.Round(v.x),y=math.Round(v.y),z=math.Round(v.z)} end
-- Почему шаблоны квестодателя недоступны: администратор видит, чего не хватает на карте.
local function templatesFor(ent)
 local ok,off=0,{}
 for _,tid in ipairs(Q.TemplateOrder) do
  local tpl=Q.Templates[tid]
  if tpl.profile==ent:GetProfile() then
   local can,why=Q.Check(tpl,nil,ent)
   if can then ok=ok+1 else off[#off+1]=tpl.title..": "..tostring(why) end
  end
 end
 return ok,off
end
function Q.AdminSnapshot()
 local npcs,points={},{}
 for id,rec in SortedPairs(Q.World.npcs) do
  local ent=Q.FindNPC(id);local row={id=id,name=rec.name,profile=rec.profile,pos=rec.pos,spawned=IsValid(ent)}
  if IsValid(ent) then row.available,row.missing=templatesFor(ent) end
  npcs[#npcs+1]=row
 end
 for id,p in SortedPairs(Q.World.points) do points[#points+1]={id=id,name=p.name,pos=p.pos} end
 local profiles={}
 for _,pid in ipairs(Q.ProfileOrder) do local p=Q.Profiles[pid];profiles[#profiles+1]={id=pid,name=p.name,about=p.about} end
 local players,active=0,0
 for _,p in ipairs(player.GetHumans()) do local d=Q.Loaded(p);if d then players=players+1;active=active+#d.active end end
 return {npcs=npcs,points=points,profiles=profiles,broken=Q.WorldBroken==true,maxNPC=Cfg.MaxNPC,maxPoints=Cfg.MaxPoints,
  players=players,active=active,templates=#Q.TemplateOrder}
end
Q.AdminOps={
 state=function() return true end,
 npc_add=function(ply,a)
  local profile=type(a.profile)=="string" and Q.Profiles[a.profile] and a.profile
  if not profile then return false,"Выберите профиль квестодателя" end
  local name=nil
  if type(a.name)=="string" and a.name:match("%S") then name=Q.CleanName(a.name);if not name then return false,"Имя квестодателя: до 48 символов" end end
  local pos=Q.AimPos(ply);if not pos then return false,"Наведите прицел на землю" end
  local rec=Q.ValidNPC({profile=profile,name=name,pos=vec3(pos),yaw=(ply:GetPos()-pos):Angle().y})
  if not rec then return false,"Некорректное место" end
  local ok,err=Q.EditWorld(function(w)
   if table.Count(w.npcs)>=Cfg.MaxNPC then return false,"Достигнут лимит квестодателей: "..Cfg.MaxNPC end
   rec.id=Q.NextID("n");w.npcs[rec.id]=rec;return true
  end)
  if not ok then return false,err end
  Q.SpawnNPC(rec);Q.RefreshAll()
  Q.Log(who(ply).." поставил квестодателя "..rec.id.." ("..rec.profile..")")
  return true,"Квестодатель «"..rec.name.."» поставлен"
 end,
 -- Убрать по ID из списка или того, на кого смотрит администратор (aim=true).
 npc_remove=function(ply,a)
  local id=type(a.id)=="string" and Q.World.npcs[a.id] and a.id or nil
  if not id and a.aim then
   local tr=ply:GetEyeTrace();local e=tr and tr.Entity
   if IsValid(e) and e:GetClass()=="stalker_quest_npc" then id=e:GetNpcID();if not Q.World.npcs[id] then id=nil;e:Remove() end end
  end
  if not id then return false,a.aim and "Наведите прицел на квестодателя" or "Квестодатель не найден" end
  local name=Q.World.npcs[id].name
  local ok,err=Q.EditWorld(function(w) w.npcs[id]=nil;return true end)
  if not ok then return false,err end
  local e=Q.FindNPC(id);if IsValid(e) then e:Remove() end
  Q.NPCEnts[id]=nil;Q.RefreshAll()
  Q.Log(who(ply).." убрал квестодателя "..id)
  return true,"Квестодатель «"..name.."» убран"
 end,
 point_add=function(ply,a)
  local pos=Q.AimPos(ply);if not pos then return false,"Наведите прицел на землю" end
  local rec=Q.ValidPoint({name=a.name,pos=vec3(pos)});if not rec then return false,"Название места: от 1 до 48 символов" end
  local ok,err=Q.EditWorld(function(w)
   if table.Count(w.points)>=Cfg.MaxPoints then return false,"Достигнут лимит мест: "..Cfg.MaxPoints end
   rec.id=Q.NextID("p");w.points[rec.id]=rec;return true
  end)
  return ok,ok and ("Место «"..rec.name.."» добавлено") or err
 end,
 point_remove=function(ply,a)
  if type(a.id)~="string" or not Q.World.points[a.id] then return false,"Место не найдено" end
  local name=Q.World.points[a.id].name
  local ok,err=Q.EditWorld(function(w) w.points[a.id]=nil;return true end)
  return ok,ok and ("Место «"..name.."» удалено") or err
 end,
 -- Временные метки квестодателей и мест для этого администратора (2 минуты).
 show=function(ply)
  local sid=ply:SteamID64();local n=0
  MK.Clear("stq.admin."..sid..".")
  for id,rec in pairs(Q.World.npcs) do
   n=n+1
   MK.Set("stq.admin."..sid..".n"..id,{pos=Vector(rec.pos.x,rec.pos.y,rec.pos.z),kind="quest",label="Квестодатель · "..rec.name,world=true,edge=false,
    visible={players={[sid]=true}},expires=CurTime()+120})
  end
  for id,p in pairs(Q.World.points) do
   n=n+1
   MK.Set("stq.admin."..sid..".p"..id,{pos=Vector(p.pos.x,p.pos.y,p.pos.z),kind="poi",label="Место заданий · "..p.name,world=true,edge=false,
    visible={players={[sid]=true}},expires=CurTime()+120})
  end
  return true,n>0 and ("Показано: "..n.." (2 минуты)") or "Квестодателей и мест пока нет"
 end,
}
net.Receive("stalker_quests.admin",function(len,ply)
 if not C.Rate(ply,"quests.admin",3,8) then return end
 local a=C.Read(len,2000);if type(a)~="table" or type(a.op)~="string" or not Q.AdminOps[a.op] then return end
 if not C.CanAdmin(ply,"quests") then C.Send("stalker_quests.admin",ply,{denied=true});return end
 local ok,res,msg=pcall(Q.AdminOps[a.op],ply,a)
 if not ok then ErrorNoHalt("[STALKER Quests] admin "..a.op..": "..tostring(res).."\n");res,msg=false,"Ошибка операции" end
 local out=Q.AdminSnapshot()
 if a.op~="state" then out.result={op=a.op,ok=res~=false,message=msg} end
 C.Send("stalker_quests.admin",ply,out)
end)

-- Чат: !quests — журнал заданий, !questadmin — панель квестодателей (право quests).
hook.Add("PlayerSay","STALKER_QUESTS.Chat",function(ply,text)
 local t=string.Trim(tostring(text or "")):lower()
 if t=="!quests" or t=="/quests" or t=="!задания" then ply:ConCommand("stq_journal");return "" end
 if t=="!questadmin" or t=="/questadmin" then if C.CanAdmin(ply,"quests") then ply:ConCommand("stq_menu") end;return "" end
end)
-- Консоль сервера и RCON: stq_list — квестодатели и места заданий текущей карты.
concommand.Add("stq_list",function(ply)
 if IsValid(ply) and not C.CanAdmin(ply,"quests") then return end
 local function out(text) if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE,text) else print(text) end end
 for id,rec in SortedPairs(Q.World.npcs) do
  out(string.format("%s  %s «%s»  %.0f %.0f %.0f%s",id,(Q.Profiles[rec.profile] or {}).name or rec.profile,rec.name,rec.pos.x,rec.pos.y,rec.pos.z,IsValid(Q.FindNPC(id)) and "" or "  [не на карте]"))
 end
 for id,p in SortedPairs(Q.World.points) do out(string.format("%s  место «%s»  %.0f %.0f %.0f",id,p.name,p.pos.x,p.pos.y,p.pos.z)) end
 if not next(Q.World.npcs) and not next(Q.World.points) then out("Квестодателей и мест заданий на карте нет: stq_menu или «Комендант» → «Задания»") end
end)
