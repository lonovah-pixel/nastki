-- Задания: предложения квестодателей, взятие, прогресс, сдача и награды, сроки, метки и состояние для клиентов.
-- Клиенту не доверяем ничего: прогресс считают хуки сервера, предметы проверяются в рюкзаке при сдаче.
local Q=STALKER_QUESTS
local C=STALKER_CORE
local MK=STALKER_MARKERS
local Cfg=Q.Config
for _,n in ipairs({"state","dialog","action","admin"}) do util.AddNetworkString("stalker_quests."..n) end
Q.Dirty=Q.Dirty or {}

local function vec3(v) return {x=math.Round(v.x,1),y=math.Round(v.y,1),z=math.Round(v.z,1)} end
local function toVec(t) return Vector(t.x,t.y,t.z) end
Q.Vec3=vec3

-- Состояние игрока изменилось: метки и пакет КПК обновятся на ближайшем такте (не чаще раза в секунду).
function Q.Changed(ply) if IsValid(ply) then Q.Dirty[ply]=true end end
function Q.RefreshAll() for _,p in ipairs(player.GetHumans()) do if Q.Loaded and Q.Loaded(p) then Q.Changed(p) end end end

--[[ Инвентарь и деньги ]]
local function inv() local S=STALKER_INV;if S and S.CountItem and S.Exchange then return S end end
function Q.CountItems(ply,ids)
 local S=inv();if not S then return 0 end
 local n=0;for _,id in ipairs(ids or {}) do n=n+S.CountItem(ply,id) end
 return n
end
-- Что забрать при сдаче: предметы по порядку списка задания, пока не наберётся нужное количество.
function Q.TakePlan(ply,ids,need)
 local S=inv();if not S then return end
 local take,left={},need
 for _,id in ipairs(ids or {}) do
  if left<=0 then break end
  local have=S.CountItem(ply,id)
  if have>0 then local n=math.min(have,left);take[id]=(take[id] or 0)+n;left=left-n end
 end
 if left>0 then return end
 return take
end
function Q.Balance(ply) local m=ply.getDarkRPVar and ply:getDarkRPVar("money");return tonumber(m) end
function Q.Pay(ply,amount)
 amount=math.floor(tonumber(amount) or 0)
 if amount<=0 or not IsValid(ply) or not ply.addMoney then return 0 end
 ply:addMoney(amount);C.AddStat(ply,"earned",amount)
 return amount
end
function Q.EmissionActive() return type(ST_EMISSION)=="table" and type(ST_EMISSION.State)=="table" and (tonumber(ST_EMISSION.State.phase) or 0)>0 end

--[[ Выполнимость шаблонов и генерация ]]
local function mutantClasses(keys)
 local cat=Q.Mutants();local out={}
 if keys then for _,k in ipairs(keys) do local m=cat[k];if m and m.class then out[#out+1]=m.class end end
 else for _,m in pairs(cat) do if type(m)=="table" and m.class then out[#out+1]=m.class end end end
 table.sort(out)
 return out
end
-- Логова Зоны, где водятся нужные мутанты (nil — любые).
function Q.LairsFor(keys)
 local out={}
 for _,row in ipairs(Q.Places("lair")) do
  local ok=keys==nil
  if keys and type(row.types)=="table" then for _,k in ipairs(keys) do if row.types[k] then ok=true end end end
  if ok then out[#out+1]=row end
 end
 return out
end
function Q.ArtifactFields()
 local out={}
 for _,row in ipairs(Q.Places("field")) do if (tonumber(row.artifacts) or 0)>0 then out[#out+1]=row end end
 return out
end
-- Место для разведки: из источников шаблона, не ближе MinVisitDistance к квестодателю.
function Q.PickPlace(tpl,ent)
 local cands={}
 local origin=IsValid(ent) and ent:GetPos()
 for _,src in ipairs(tpl.sources or {"point"}) do
  for _,row in ipairs(Q.Places(src)) do
   if not origin or row.pos:DistToSqr(origin)>=Cfg.MinVisitDistance^2 then cands[#cands+1]=row end
  end
 end
 if #cands==0 then return end
 return cands[math.random(#cands)]
end
function Q.DeliveryTargets(ent)
 local out={}
 for _,e in ipairs(Q.NPCList()) do if e~=ent and e:GetNpcID()~=(IsValid(ent) and ent:GetNpcID() or "") then out[#out+1]=e end end
 return out
end
-- Можно ли сейчас выдать задание по шаблону (иначе — причина).
function Q.Check(tpl,ply,ent)
 local t=tpl.type
 if t=="fetch" then
  if not inv() then return false,"Нет инвентаря" end
  if #Q.ResolveItems(tpl.items)==0 then return false,"Нет подходящих предметов на сервере" end
 elseif t=="kill" then
  if #Q.LairsFor(tpl.mutants)==0 then return false,"Нет логов с такими мутантами" end
 elseif t=="artifact" then
  if #Q.ArtifactFields()==0 then return false,"Нет полей аномалий с артефактами" end
 elseif t=="visit" then
  if not Q.PickPlace(tpl,ent) then return false,"Нет мест для разведки" end
 elseif t=="deliver" then
  if not inv() or not STALKER_INV.Items[Cfg.PackageItem] then return false,"Нет инвентаря" end
  if #Q.DeliveryTargets(ent)==0 then return false,"Нет других квестодателей" end
 elseif t=="emission" then
  if type(ST_EMISSION)~="table" then return false,"Выбросы не установлены" end
  -- Без расписания выброс может не случиться до конца срока.
  if not Q.EmissionActive() and type(ST_EMISSION.Config)=="table" and ST_EMISSION.Config.AutoStart==false then return false,"Выбросы по расписанию выключены" end
 end
 return true
end
-- Конкретное задание из шаблона: количество, место, получатель и награда фиксируются при генерации.
function Q.Instantiate(tpl,ply,ent)
 if type(tpl)=="string" then tpl=Q.Templates[tpl] end
 if type(tpl)~="table" or not IsValid(ent) or not Q.Check(tpl,ply,ent) then return end
 local n=math.random(tpl.goal[1],math.max(tpl.goal[1],tpl.goal[2]))
 if tpl.type=="visit" or tpl.type=="deliver" or tpl.type=="emission" then n=1 end
 local prof=Q.Profiles[ent:GetProfile()] or {}
 local r=tpl.reward or {}
 local money=((r.money or 0)+(r.per or 0)*n)*math.Rand(.9,1.1)*Cfg.RewardMult
 money=math.max(0,math.floor(money/10+.5)*10)
 local items={}
 for _,it in ipairs(r.items or {}) do if STALKER_INV and STALKER_INV.Items and STALKER_INV.Items[it[1]] then items[#items+1]={it[1],it[2] or 1} end end
 -- Репутация — у группировки квестодателя, если группировки установлены.
 local faction=prof.faction
 if not (STFW and STFW.Factions and STFW.Factions[faction or ""]) then faction=nil end
 local q={tpl=tpl.id,type=tpl.type,title=tpl.title,profile=ent:GetProfile(),giver=ent:GetNpcID(),giverName=Q.NPCName(ent),goal=n,progress=0,
  time=tpl.time,news=tpl.news==true,what=tpl.what,reward={money=money,rep=faction and (r.rep or 0) or 0,faction=faction,items=items}}
 local vars={n=n,what=tpl.what}
 if tpl.type=="fetch" then
  q.items=Q.ResolveItems(tpl.items)
 elseif tpl.type=="kill" then
  q.mutants=tpl.mutants and table.Copy(tpl.mutants) or nil;q.classes=mutantClasses(tpl.mutants)
  local lair=Q.Nearest(Q.LairsFor(tpl.mutants),ent:GetPos())
  if lair then q.hint={name="Логово «"..lair.name.."»",pos=vec3(lair.pos)} end
 elseif tpl.type=="artifact" then
  local field=Q.Nearest(Q.ArtifactFields(),ent:GetPos())
  if field then q.hint={name="Поле «"..field.name.."»",pos=vec3(field.pos)} end
 elseif tpl.type=="visit" then
  local place=Q.PickPlace(tpl,ent);if not place then return end
  q.place={name=place.name,pos=vec3(place.pos),radius=Cfg.VisitRadius};vars.place=place.name
 elseif tpl.type=="deliver" then
  local list=Q.DeliveryTargets(ent);if #list==0 then return end
  local target=list[math.random(#list)]
  q.to=target:GetNpcID();q.toName=Q.NPCName(target);vars.to=q.toName
 end
 q.desc=Q.Fill(tpl.desc,vars)
 return q
end

-- Предложения квестодателя кэшируются на OfferMinutes: повторный разговор не перебирает награды.
-- Кэш — по SteamID, а не на сущности игрока: иначе перезаход выдавал бы новые предложения и награды.
Q.OfferCache=Q.OfferCache or {}
function Q.Offers(ply,ent,force)
 local d=Q.Data(ply);if not d or not IsValid(ent) then return {} end
 local id,sid=ent:GetNpcID(),C.SID(ply)
 Q.OfferCache[sid]=Q.OfferCache[sid] or {}
 local cache=Q.OfferCache[sid][id]
 if force or not cache or cache.expires<CurTime() or cache.profile~=ent:GetProfile() then
  cache={expires=CurTime()+Cfg.OfferMinutes*60,profile=ent:GetProfile(),list={}}
  Q.OfferCache[sid][id]=cache
  local pool,total={},0
  for _,tid in ipairs(Q.TemplateOrder) do
   local tpl=Q.Templates[tid]
   if tpl.profile==ent:GetProfile() and not Q.HasTemplate(d,tid) and not Q.OnCooldown(d,tid) and Q.Check(tpl,ply,ent) then
    pool[#pool+1]=tpl;total=total+tpl.weight
   end
  end
  while #pool>0 and #cache.list<Cfg.Offers do
   local roll,pick=math.Rand(0,total),#pool
   for i,tpl in ipairs(pool) do roll=roll-tpl.weight;if roll<=0 then pick=i;break end end
   local tpl=table.remove(pool,pick);total=total-tpl.weight
   local q=Q.Instantiate(tpl,ply,ent)
   if q then Q.OfferSeq=(Q.OfferSeq or 0)+1;cache.list[#cache.list+1]={key="o"..Q.OfferSeq,q=q} end
  end
 end
 -- Взятые шаблоны и шаблоны на откате из предложения пропадают.
 for i=#cache.list,1,-1 do
  local tid=cache.list[i].q.tpl
  if Q.HasTemplate(d,tid) or Q.OnCooldown(d,tid) then table.remove(cache.list,i) end
 end
 return cache.list
end
-- Добавить в предложение конкретный шаблон (для сценариев и отладки). Возвращает ключ предложения.
function Q.AddOffer(ply,ent,tid)
 local list=Q.Offers(ply,ent);local q=Q.Instantiate(tid,ply,ent);if not q then return end
 Q.OfferSeq=(Q.OfferSeq or 0)+1;local key="o"..Q.OfferSeq
 list[#list+1]={key=key,q=q}
 return key,q
end

--[[ Взятие, прогресс, сдача ]]
function Q.Accept(ply,ent,key)
 local d=Q.Data(ply);if not d then return false,"Профиль заданий недоступен" end
 Q.ResetDaily(d)
 if #d.active>=Cfg.MaxActive then return false,"Не больше "..Cfg.MaxActive.." активных заданий одновременно" end
 if Cfg.DailyLimit>0 and d.daily.n>=Cfg.DailyLimit then return false,"На сегодня хватит: не больше "..Cfg.DailyLimit.." заданий в сутки" end
 local list=Q.Offers(ply,ent);local offer,index
 for i,o in ipairs(list) do if o.key==key then offer,index=o,i end end
 if not offer then return false,"Предложение устарело — поговорите ещё раз" end
 local q=table.Copy(offer.q)
 if q.type=="deliver" then
  local target=Q.FindNPC(q.to)
  if not IsValid(target) then table.remove(list,index);return false,"Получатель посылки больше не принимает" end
  local S=inv();if not S then return false,"Инвентарь недоступен" end
  local ok,err=S.Exchange(ply,{},{{Cfg.PackageItem,1}},"Получена посылка: "..q.toName)
  if not ok then return false,err or "Нет места для посылки" end
 end
 table.remove(list,index)
 d.seq=d.seq+1;q.uid="q"..d.seq
 q.accepted=os.time();q.expires=q.accepted+math.max(60,math.floor((q.time or 30)*60*Cfg.TimeMult));q.time=nil
 if q.type=="emission" and Q.EmissionActive() and ply:Alive() then q.armed=true end
 d.active[#d.active+1]=q;d.daily.n=d.daily.n+1
 if not d.tracked or d.tracked=="" or (d.tracked=="tutorial" and not Q.TutorialActive(d)) then d.tracked=q.uid end
 Q.Save(ply);Q.Changed(ply)
 C.Notify(ply,"Новое задание: «"..q.title.."». "..Q.Objective(q),"info",6)
 hook.Run("STALKER_QUESTS_Accepted",ply,q)
 return true,"Задание «"..q.title.."» взято"
end

function Q.ReturnText(q)
 if q.type=="deliver" then return "отнесите посылку: "..tostring(q.toName) end
 return "вернитесь: "..tostring(q.giverName)
end
-- Событийный прогресс (убийства, находки, место, выброс).
function Q.Progress(ply,q,amount)
 if q.done then return end
 q.progress=math.min(q.goal,q.progress+(amount or 1))
 if q.progress>=q.goal then
  q.done=true
  C.Notify(ply,"Задание «"..q.title.."» выполнено — "..Q.ReturnText(q),"ok",7)
  Q.Save(ply)
 else
  C.Notify(ply,"«"..q.title.."»: "..q.progress.." из "..q.goal,"info",3)
  Q.SaveSoon(ply)
 end
 Q.Changed(ply)
end
-- Готово к сдаче (предметы проверяются по рюкзаку прямо сейчас).
function Q.Ready(ply,q)
 if q.type=="fetch" then
  local have=Q.CountItems(ply,q.items)
  if have>=q.goal then return true end
  return false,"Не хватает: "..have.." из "..q.goal
 end
 if q.type=="deliver" then
  if Q.CountItems(ply,{Cfg.PackageItem})>=1 then return true end
  return false,"Посылки нет в рюкзаке"
 end
 if q.done then return true end
 return false,"Ещё не выполнено: "..q.progress.." из "..q.goal
end
-- Быстрая проверка для меток и значков (fetch — по последнему пересчёту прогресса, доставка — посылка при себе).
function Q.ReadyNow(ply,q)
 if q.type=="fetch" then return q.progress>=q.goal end
 if q.type=="deliver" then return Q.CountItems(ply,{Cfg.PackageItem})>=1 end
 return q.done==true
end
function Q.GiverEnt(q)
 local e=Q.FindNPC(q.giver);if IsValid(e) then return e end
 return Q.AnyNPCOfProfile(q.profile) or Q.NPCList()[1]
end
-- Кому сдавать: выдавшему; если его убрали — квестодателю того же профиля; если таких нет — любому.
-- Посылка — адресату; если адресата убрали — любому квестодателю, кроме отправителя.
function Q.TurnInHere(q,ent)
 if not IsValid(ent) then return false end
 local id=ent:GetNpcID()
 if q.type=="deliver" then
  if q.to==id then return true end
  return not IsValid(Q.FindNPC(q.to)) and id~=q.giver
 end
 if q.giver==id then return true end
 if IsValid(Q.FindNPC(q.giver)) then return false end
 if ent:GetProfile()==q.profile then return true end
 return not IsValid(Q.AnyNPCOfProfile(q.profile))
end
function Q.GiveReward(ply,q,take)
 local r=q.reward or {}
 local give={}
 for _,it in ipairs(r.items or {}) do if STALKER_INV and STALKER_INV.Items and STALKER_INV.Items[it[1]] then give[#give+1]={it[1],it[2] or 1} end end
 if next(take or {}) or #give>0 then
  local S=inv();if not S then return false,"Инвентарь недоступен" end
  local ok,err=S.Exchange(ply,take or {},give,"Задание «"..q.title.."» сдано")
  if not ok then return false,err or "Обмен не удался" end
 end
 Q.Pay(ply,r.money)
 if (r.rep or 0)~=0 and r.faction and STFW and STFW.AddReputation then
  local ok,err=pcall(STFW.AddReputation,ply,r.faction,r.rep,"quest")
  if not ok then ErrorNoHalt("[STALKER Quests] репутация: "..tostring(err).."\n") end
 end
 C.AddStat(ply,"quests",1)
 return true
end
function Q.TurnIn(ply,ent,uid)
 local d=Q.Data(ply);if not d then return false,"Профиль заданий недоступен" end
 local q,i=Q.FindActive(d,uid);if not q then return false,"Задание не найдено" end
 if not Q.TurnInHere(q,ent) then
  return false,q.type=="deliver" and ("Посылку ждёт другой адресат: "..tostring(q.toName)) or ("Сдавать нужно: "..tostring(q.giverName))
 end
 local ok,why=Q.Ready(ply,q);if not ok then return false,why end
 local take={}
 if q.type=="fetch" then take=Q.TakePlan(ply,q.items,q.goal);if not take then return false,"Не хватает предметов" end
 elseif q.type=="deliver" then take={[Cfg.PackageItem]=1} end
 local paid,err=Q.GiveReward(ply,q,take);if not paid then return false,err end
 table.remove(d.active,i)
 q.progress=q.goal
 Q.Finish(ply,d,q,"done")
 if q.news and Cfg.News then C.News(Q.NPCName(ent)..": задание «"..q.title.."» выполнено.","quest") end
 C.Notify(ply,"Задание «"..q.title.."» выполнено. Награда: "..Q.RewardText(q.reward),"ok",7)
 return true,"Задание «"..q.title.."» сдано"
end
-- Посылка возвращается отправителю при отказе или провале доставки (если она ещё в рюкзаке).
function Q.ReturnPackage(ply)
 local S=inv()
 if S and S.CountItem(ply,Cfg.PackageItem)>=1 then S.Exchange(ply,{[Cfg.PackageItem]=1},{},"Посылка возвращена отправителю") end
end
-- Итог задания: история, откат шаблона, счётчик выполненных. status: done, abandoned, expired.
function Q.Finish(ply,d,q,status)
 table.insert(d.history,1,{title=q.title,status=status,t=os.time(),money=status=="done" and (q.reward and q.reward.money or 0) or 0,giver=q.giverName})
 while #d.history>Cfg.History do table.remove(d.history) end
 if Cfg.Cooldown>0 and q.tpl and q.tpl~="" then d.cooldowns[q.tpl]=os.time()+Cfg.Cooldown*60 end
 if status=="done" then d.done=d.done+1 end
 if q.type=="deliver" and status~="done" then Q.ReturnPackage(ply) end
 if d.tracked==q.uid then
  d.tracked=(d.active[1] and d.active[1].uid) or (Q.TutorialActive(d) and "tutorial") or nil
 end
 if status=="expired" then C.Notify(ply,"Срок задания «"..q.title.."» истёк","warn",6) end
 Q.Save(ply);Q.Changed(ply)
 hook.Run("STALKER_QUESTS_Finished",ply,q,status)
end
function Q.Abandon(ply,uid)
 local d=Q.Data(ply);if not d then return false,"Профиль заданий недоступен" end
 local q,i=Q.FindActive(d,uid);if not q then return false,"Задание не найдено" end
 table.remove(d.active,i)
 Q.Finish(ply,d,q,"abandoned")
 return true,"Вы отказались от задания «"..q.title.."»"
end
function Q.Track(ply,uid)
 local d=Q.Data(ply);if not d then return false,"Профиль заданий недоступен" end
 if uid==nil or uid=="" then d.tracked=nil
 elseif uid=="tutorial" then if not Q.TutorialActive(d) then return false,"Обучение не идёт" end;d.tracked=uid
 else if not Q.FindActive(d,uid) then return false,"Задание не найдено" end;d.tracked=uid end
 Q.SaveSoon(ply);Q.Changed(ply)
 return true
end

--[[ Хуки прогресса ]]
function Q.KillMatches(q,key,class)
 if q.mutants then
  if key then for _,k in ipairs(q.mutants) do if k==key then return true end end;return false end
 elseif key then return true end
 for _,c in ipairs(q.classes or {}) do if c==class then return true end end
 return false
end
-- Без возврата значения: иначе хук остановил бы выплату DarkRP за NPC.
hook.Add("OnNPCKilled","STALKER_QUESTS.Kill",function(npc,attacker)
 if not IsValid(npc) or not IsValid(attacker) or not attacker:IsPlayer() then return end
 local d=Q.Loaded(attacker);if not d then return end
 local key,class=npc.StalkerMutant,npc:GetClass()
 for _,q in ipairs(d.active) do
  if q.type=="kill" and not q.done and Q.KillMatches(q,key,class) then Q.Progress(attacker,q,1) end
 end
end)
hook.Add("STALKER_ZONE_ArtifactPicked","STALKER_QUESTS.Artifact",function(ply,id)
 if not IsValid(ply) then return end
 local d=Q.Loaded(ply);if not d then return end
 for _,q in ipairs(d.active) do if q.type=="artifact" and not q.done then Q.Progress(ply,q,1) end end
 if Q.TutorialEvent then Q.TutorialEvent(ply,"artifact",id) end
end)
-- Выброс засчитывается тому, кто был жив при его начале (или взял задание во время выброса) и дожил до конца.
hook.Add("STEmissionStarted","STALKER_QUESTS.Emission",function()
 for _,p in ipairs(player.GetHumans()) do
  local d=Q.Loaded(p)
  if d and p:Alive() then for _,q in ipairs(d.active) do if q.type=="emission" and not q.done then q.armed=true end end end
 end
end)
hook.Add("PlayerDeath","STALKER_QUESTS.Emission",function(p)
 local d=Q.Loaded(p);if not d then return end
 for _,q in ipairs(d.active) do
  if q.type=="emission" and q.armed then q.armed=false;C.Notify(p,"«"..q.title.."»: вы погибли — переживите следующий выброс","warn",6);Q.Changed(p) end
 end
end)
hook.Add("STEmissionFinished","STALKER_QUESTS.Emission",function()
 for _,p in ipairs(player.GetHumans()) do
  local d=Q.Loaded(p)
  if d then for _,q in ipairs(d.active) do
   if q.type=="emission" and q.armed and not q.done then q.armed=false;if p:Alive() then Q.Progress(p,q,1) end end
  end end
 end
end)
hook.Add("STEmissionAborted","STALKER_QUESTS.Emission",function()
 for _,p in ipairs(player.GetHumans()) do local d=Q.Loaded(p);if d then for _,q in ipairs(d.active) do if q.type=="emission" then q.armed=false end end end end
end)

--[[ Цели, метки, состояние ]]
-- Куда вести игрока: адресат посылки, выдавший квестодатель (если готово), место разведки или подсказка (логово, поле).
function Q.Target(ply,q)
 if q.type=="deliver" then
  local e=Q.FindNPC(q.to)
  -- Адресата убрали: посылку примет любой квестодатель, кроме отправителя.
  if not IsValid(e) then for _,x in ipairs(Q.NPCList()) do if x:GetNpcID()~=q.giver then e=x;break end end end
  if IsValid(e) then return e:GetPos(),"Доставка: "..Q.NPCName(e) end
  return
 end
 if Q.ReadyNow(ply,q) then
  local e=Q.GiverEnt(q);if IsValid(e) then return e:GetPos(),"Сдать: "..Q.NPCName(e) end
  return
 end
 if q.type=="visit" and q.place then return toVec(q.place.pos),"Разведка: "..q.place.name end
 if q.hint then return toVec(q.hint.pos),q.hint.name end
end
function Q.RefreshMarkers(ply,d)
 local sid=C.SID(ply);if not sid or not d then return end
 local prefix="stq."..sid.."."
 local keep={}
 local function set(key,pos,label,tracked)
  local id=prefix..key;keep[id]=true
  MK.Set(id,{pos=pos,label=label,kind="quest",edge=tracked==true,world=false,visible={players={[sid]=true}}})
 end
 for _,q in ipairs(d.active) do
  local pos,label=Q.Target(ply,q)
  if pos then set(q.uid,pos,label,d.tracked==q.uid) end
 end
 if Q.TutorialActive(d) and Q.TutorialTarget then
  local pos,label=Q.TutorialTarget(ply,d)
  if pos then set("tut",pos,label,d.tracked=="tutorial") end
 end
 for id in pairs(MK.List) do if id:sub(1,#prefix)==prefix and not keep[id] then MK.Remove(id) end end
end
function Q.QuestView(ply,q)
 local pos,label=Q.Target(ply,q)
 -- Доставка «готова», пока посылка при себе, но в КПК и трекере остаётся целью «Доставьте посылку».
 return {uid=q.uid,title=q.title,desc=q.desc,type=q.type,objective=Q.Objective(q),progress=q.progress,goal=q.goal,ready=q.type~="deliver" and Q.ReadyNow(ply,q),
  left=math.max(0,q.expires-os.time()),giverName=q.giverName,toName=q.toName,reward=q.reward,pos=pos and vec3(pos) or nil,label=label}
end
function Q.BuildState(ply)
 local d=Q.Data(ply);if not d then return end
 Q.ResetDaily(d)
 local out={active={},history={},tracked=d.tracked,max=Cfg.MaxActive,daily=Cfg.DailyLimit,today=d.daily.n,done=d.done,npcs={}}
 for _,q in ipairs(d.active) do
  out.active[#out.active+1]=Q.QuestView(ply,q)
  if Q.ReadyNow(ply,q) then out.npcs[q.type=="deliver" and q.to or q.giver]=true end
 end
 for i=1,math.min(#d.history,Cfg.History) do out.history[i]=d.history[i] end
 if Q.TutorialView then out.tutorial=Q.TutorialView(ply,d) end
 return out
end
function Q.SendState(ply)
 local s=Q.BuildState(ply);if not s then return false end
 return C.Send("stalker_quests.state",ply,s)
end

--[[ Раз в секунду: сроки, разведка, сбор предметов, обучение, рассылка изменений ]]
function Q.TickPlayer(ply,d)
 local now=os.time()
 for i=#d.active,1,-1 do
  local q=d.active[i]
  if q.expires<=now then
   table.remove(d.active,i);Q.Finish(ply,d,q,"expired")
  elseif not q.done then
   if q.type=="visit" and q.place and ply:Alive() then
    local p,t=ply:GetPos(),q.place.pos
    local dx,dy=p.x-t.x,p.y-t.y
    if dx*dx+dy*dy<=q.place.radius^2 and math.abs(p.z-t.z)<=400 then Q.Progress(ply,q,1) end
   elseif q.type=="fetch" then
    local have=math.min(q.goal,Q.CountItems(ply,q.items))
    if have~=q.progress then
     local was=q.progress>=q.goal;q.progress=have;Q.Changed(ply)
     if have>=q.goal and not was then C.Notify(ply,"«"..q.title.."»: всё собрано — "..Q.ReturnText(q),"ok",6) end
    end
   end
  end
 end
 if Q.TutorialTick then Q.TutorialTick(ply,d) end
end
function Q.Tick()
 for _,ply in ipairs(player.GetHumans()) do
  local d=Q.Loaded(ply)
  if d then
   local ok,err=pcall(Q.TickPlayer,ply,d)
   if not ok then ErrorNoHalt("[STALKER Quests] такт: "..tostring(err).."\n") end
   if Q.Dirty[ply] then Q.Dirty[ply]=nil;Q.RefreshMarkers(ply,d);Q.SendState(ply) end
  end
 end
 for p in pairs(Q.Dirty) do if not IsValid(p) then Q.Dirty[p]=nil end end
end
timer.Create("STALKER_QUESTS.Tick",1,0,function() Q.Tick() end)

-- Профиль, обучение и пакет КПК после входа. Пакет из таймера PlayerInitialSpawn медленный клиент теряет,
-- поэтому то же повторяется по STALKER_PlayerReady (ядро: Lua клиента уже работает).
function Q.PlayerReady(ply)
 if not IsValid(ply) then return end
 local d=Q.Data(ply);if not d then return end
 if Q.TutorialCheck then Q.TutorialCheck(ply,d) end
 Q.Changed(ply)
end
hook.Add("PlayerInitialSpawn","STALKER_QUESTS.Data",function(ply) timer.Simple(2,function() Q.PlayerReady(ply) end) end)
hook.Add("STALKER_PlayerReady","STALKER_QUESTS.Data",function(ply) Q.PlayerReady(ply) end)
hook.Add("PlayerDisconnected","STALKER_QUESTS.Data",function(ply)
 local sid=C.SID(ply);if not sid then return end
 if Q.Players[sid] then Q.Save(ply) end
 Q.Players[sid]=nil;Q.Dirty[ply]=nil
 MK.Clear("stq."..sid..".")
 -- Кэш предложений вышедшего живёт до истечения (перезаход не перебирает награды); истёкшие убираем.
 local now=CurTime()
 for s,list in pairs(Q.OfferCache) do
  for id,c in pairs(list) do if c.expires<now then list[id]=nil end end
  if not next(list) then Q.OfferCache[s]=nil end
 end
end)
