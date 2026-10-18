-- «Путь новичка»: шесть шагов с наградами для игроков без выполненных заданий. Каждый шаг ведут метка
-- и направляющая линия (цель пересчитывается раз в 5 секунд: игрок перемещается, ближайший объект меняется).
local Q=STALKER_QUESTS
local C=STALKER_CORE
local Cfg=Q.Config
local Steps=Q.TutorialSteps

function Q.TutorialActive(d)
 return Cfg.Tutorial==true and type(d)=="table" and type(d.tut)=="table" and d.tut.state=="active" and Steps[d.tut.step]~=nil
end
function Q.TutorialStep(d) if Q.TutorialActive(d) then return Steps[d.tut.step] end end

-- Обучение начинается само у игрока без выполненных заданий, если оно ещё не начиналось.
function Q.TutorialCheck(ply,d)
 if not Cfg.Tutorial or type(d)~="table" or d.tut or (d.done or 0)>0 then return false end
 d.tut={state="active",step=1,started=os.time()}
 if not d.tracked then d.tracked="tutorial" end
 ply.StalkerQuestSnap=nil;ply.StalkerQuestTut=nil
 Q.Save(ply);Q.Changed(ply)
 C.Notify(ply,"«Путь новичка»: короткое обучение с наградами. Цель отмечена на экране, подробности — КПК (F4) → «Задания».","info",10)
 return true
end

--[[ Цели шагов ]]
local function nearestEnt(class,pos,filter)
 local best,bestD
 for _,e in ipairs(ents.FindByClass(class)) do
  if IsValid(e) and (not filter or filter(e)) then
   local dist=e:GetPos():DistToSqr(pos)
   if not bestD or dist<bestD then best,bestD=e,dist end
  end
 end
 return best,bestD
end
Q.NearestEnt=nearestEnt
function Q.TraderName(ent)
 local N=STALKER_NPC
 local p=IsValid(ent) and ent.GetTraderID and N and N.Config and N.Config.Traders and N.Config.Traders[ent:GetTraderID()]
 local name=p and type(p.name)=="table" and (p.name.ru or p.name.en)
 return name and ("Торговец «"..name.."»") or "Торговец"
end
Q.TutorialMissing={trader="На карте нет торговцев — этот шаг можно пропустить.",field="На карте нет полей аномалий — этот шаг можно пропустить.",
 barman="Нет ни Бармена, ни торговцев — этот шаг можно пропустить.",recruiter="На карте нет вербовщиков — этот шаг можно пропустить."}
function Q.TutorialTarget(ply,d)
 local step=Q.TutorialStep(d);if not step or not step.target then return end
 local cache=ply.StalkerQuestTut
 if cache and cache.step==d.tut.step and cache.at>CurTime() then return cache.pos,cache.label end
 local origin=ply:GetPos();local pos,label
 if step.target=="trader" then
  local e=nearestEnt("stalker_npc_trader",origin);if e then pos,label=e:GetPos(),Q.TraderName(e) end
 elseif step.target=="field" then
  local f=Q.Nearest(Q.ArtifactFields(),origin) or Q.Nearest(Q.Places("field"),origin)
  if f then pos,label=f.pos,"Поле аномалий «"..f.name.."»" end
 elseif step.target=="barman" then
  local e=nearestEnt("stalker_quest_npc",origin,function(x) return x:GetProfile()=="barman" end)
  if e then pos,label=e:GetPos(),Q.NPCName(e)
  else e=nearestEnt("stalker_npc_trader",origin);if e then pos,label=e:GetPos(),Q.TraderName(e) end end
 elseif step.target=="recruiter" then
  local e=nearestEnt("stalker_recruiter",origin)
  if e then
   local fid=e.GetFactionID and e:GetFactionID() or ""
   pos,label=e:GetPos(),"Вербовщик"..(fid~="" and (" «"..C.FactionName(fid).."»") or "")
  end
 end
 ply.StalkerQuestTut={step=d.tut.step,at=CurTime()+5,pos=pos,label=label and ("Обучение: "..label) or nil}
 return pos,ply.StalkerQuestTut.label
end

--[[ Проверки шагов ]]
function Q.HasDetector(ply)
 local inv=ply.StalkerInventory;local S=STALKER_INV;local Z=STALKER_ZONE
 if type(inv)~="table" or type(inv.grid)~="table" then return false end
 for _,item in pairs(inv.grid) do
  if Z and type(Z.Detectors)=="table" and Z.Detectors[item.id] then return true end
  local def=S and S.Items and S.Items[item.id]
  if def and def.category=="detector" then return true end
 end
 return false
end
-- Артефакты в рюкзаке и на поясе (перекладывание в слот не считается продажей).
function Q.ArtifactCount(ply)
 local inv=ply.StalkerInventory;local S=STALKER_INV
 if type(inv)~="table" or not S or not S.Items then return 0 end
 local n=0
 for _,zone in ipairs({"grid","equipment"}) do
  for _,item in pairs(type(inv[zone])=="table" and inv[zone] or {}) do
   local def=S.Items[item.id];if def and def.category=="artifact" then n=n+(tonumber(item.count) or 1) end
  end
 end
 return n
end
function Q.ArtifactPrice(id)
 local Z=STALKER_ZONE;local p=Z and type(Z.ItemPrices)=="table" and Z.ItemPrices[id]
 return math.max(0,math.floor(tonumber(p and p.sell) or 1000))
end
-- Самый дешёвый артефакт в рюкзаке: его забирает Бармен на шаге «Хабар».
function Q.CheapestArtifact(ply)
 local inv=ply.StalkerInventory;local S=STALKER_INV
 if type(inv)~="table" or type(inv.grid)~="table" or not S then return end
 local best,bestPrice
 for _,item in pairs(inv.grid) do
  local def=S.Items[item.id]
  if def and def.category=="artifact" then
   local price=Q.ArtifactPrice(item.id)
   if not bestPrice or price<bestPrice then best,bestPrice=item.id,price end
  end
 end
 return best,bestPrice
end
function Q.NearTrader(ply)
 local N=STALKER_NPC
 if N and type(N.Sessions)=="table" and N.Sessions[ply] then return true end
 local range=((N and N.Config and tonumber(N.Config.Distance)) or 160)+80
 local _,dist=nearestEnt("stalker_npc_trader",ply:GetPos())
 return dist~=nil and dist<=range*range
end
--[[ Продажа торговцу надёжно видна по трём признакам за один такт: артефактов стало меньше, денег стало больше
 и игрок в этот момент торгует (открыт диалог торговца или он стоит рядом с торговцем). Выброс артефакта на землю
 не даёт денег, смерть — тоже; покупка без продажи не уменьшает артефакты. ]]
function Q.TutorialSold(ply)
 local arts,money=Q.ArtifactCount(ply),Q.Balance(ply) or 0
 local snap=ply.StalkerQuestSnap
 ply.StalkerQuestSnap={arts=arts,money=money}
 if not snap then return false end
 return arts<snap.arts and money>snap.money and Q.NearTrader(ply)
end

--[[ Переход по шагам и награды ]]
function Q.TutorialRewardView(step)
 local r=step.reward or {}
 local items={};for _,it in ipairs(r.items or {}) do if STALKER_INV and STALKER_INV.Items and STALKER_INV.Items[it[1]] then items[#items+1]={it[1],it[2] or 1} end end
 return {money=math.floor((r.money or 0)*Cfg.RewardMult/10+.5)*10,items=items}
end
function Q.TutorialReward(ply,step)
 local r=Q.TutorialRewardView(step)
 if #r.items>0 and STALKER_INV and STALKER_INV.Exchange then
  local ok,err=STALKER_INV.Exchange(ply,{},r.items,"Награда обучения")
  if not ok then C.Notify(ply,"Награда предметами не поместилась: "..tostring(err),"warn",6) end
 end
 return Q.Pay(ply,r.money)
end
function Q.TutorialAdvance(ply,d,id,skip)
 local step=Q.TutorialStep(d);if not step or step.id~=id then return false end
 if not skip then Q.TutorialReward(ply,step) end
 d.tut.step=d.tut.step+1
 ply.StalkerQuestSnap=nil;ply.StalkerQuestTut=nil
 if d.tut.step>#Steps then
  d.tut.state="done";d.done=(d.done or 0)+1
  C.AddStat(ply,"quests",1)
  table.insert(d.history,1,{title="Путь новичка",status="done",t=os.time(),money=0,giver="Обучение"})
  while #d.history>Cfg.History do table.remove(d.history) end
  if d.tracked=="tutorial" then d.tracked=d.active[1] and d.active[1].uid or nil end
  C.Notify(ply,"«Путь новичка» пройден! Дальше — задания квестодателей: Бармен, Профессор, Охотник и Связной.","ok",10)
  hook.Run("STALKER_QUESTS_TutorialDone",ply)
 else
  local nxt=Steps[d.tut.step]
  C.Notify(ply,(skip and "Шаг пропущен. " or "Шаг выполнен! ").."Дальше: «"..nxt.title.."». "..nxt.text,"info",9)
 end
 Q.Save(ply);Q.Changed(ply)
 return true
end
function Q.TutorialEvent(ply,kind,arg)
 local d=Q.Loaded(ply);local step=d and Q.TutorialStep(d)
 if not step then return end
 if kind=="artifact" and step.id=="artifact" then Q.TutorialAdvance(ply,d,"artifact")
 elseif kind=="use" and step.id=="trader" and arg=="stalker_npc_trader" then Q.TutorialAdvance(ply,d,"trader")
 elseif kind=="use" and step.id=="recruiter" and arg=="stalker_recruiter" then Q.TutorialAdvance(ply,d,"recruiter")
 elseif kind=="pda" and step.id=="pda" then Q.TutorialAdvance(ply,d,"pda") end
end
function Q.TutorialTick(ply,d)
 if not d.tut then Q.TutorialCheck(ply,d);return end
 local step=Q.TutorialStep(d);if not step then return end
 local id=step.id
 if id=="trader" then
  local N=STALKER_NPC
  if N and type(N.Sessions)=="table" and N.Sessions[ply] then Q.TutorialAdvance(ply,d,id);return end
 elseif id=="detector" then
  if Q.HasDetector(ply) then Q.TutorialAdvance(ply,d,id);return end
 elseif id=="sell" then
  if Q.TutorialSold(ply) then Q.TutorialAdvance(ply,d,id);return end
 elseif id=="recruiter" then
  local _,dist=nearestEnt("stalker_recruiter",ply:GetPos())
  if dist and ply:Alive() and dist<=(Cfg.TalkDistance+50)^2 then Q.TutorialAdvance(ply,d,id);return end
 end
 -- Ближайшая цель могла смениться: обновляем метку и линию.
 local old=ply.StalkerQuestTut
 if not old or old.step~=d.tut.step or old.at<=CurTime() then
  local oldPos=old and old.step==d.tut.step and old.pos or nil
  local pos=Q.TutorialTarget(ply,d)
  if (pos==nil)~=(oldPos==nil) or (pos and oldPos and pos:DistToSqr(oldPos)>1) then Q.Changed(ply) end
 end
end

-- Сдать артефакт Бармену на шаге «Хабар»: он забирает самый дешёвый артефакт рюкзака и платит цену торговца.
function Q.TutorialHandover(ply,ent)
 local d=Q.Data(ply);local step=d and Q.TutorialStep(d)
 if not step or step.id~="sell" then return false,"Сейчас это не нужно" end
 if not IsValid(ent) or ent:GetProfile()~="barman" then return false,"Артефакты для обучения принимает Бармен" end
 local S=STALKER_INV;if not S or not S.Exchange then return false,"Инвентарь недоступен" end
 local id,price=Q.CheapestArtifact(ply)
 if not id then return false,"В рюкзаке нет артефактов" end
 local ok,err=S.Exchange(ply,{[id]=1},{},"Бармен забрал: "..Q.ItemName(id))
 if not ok then return false,err or "Обмен не удался" end
 Q.Pay(ply,price)
 Q.TutorialAdvance(ply,d,"sell")
 return true,"Бармен купил «"..Q.ItemName(id).."» за "..Q.Money(price)
end
function Q.TutorialSkipStep(ply)
 local d=Q.Data(ply);local step=d and Q.TutorialStep(d)
 if not step then return false,"Обучение не идёт" end
 Q.TutorialAdvance(ply,d,step.id,true)
 return true,"Шаг «"..step.title.."» пропущен"
end
function Q.TutorialStop(ply)
 local d=Q.Data(ply);if not Q.TutorialActive(d) then return false,"Обучение не идёт" end
 d.tut.state="skipped"
 if d.tracked=="tutorial" then d.tracked=d.active[1] and d.active[1].uid or nil end
 Q.Save(ply);Q.Changed(ply)
 return true,"Обучение отложено: продолжить можно в КПК, вкладка «Задания»"
end
function Q.TutorialResume(ply)
 local d=Q.Data(ply)
 if not d or type(d.tut)~="table" or d.tut.state~="skipped" then return false,"Обучение не было отложено" end
 if not Cfg.Tutorial then return false,"Обучение выключено администратором" end
 d.tut.state="active";d.tracked=d.tracked or "tutorial"
 ply.StalkerQuestSnap=nil;ply.StalkerQuestTut=nil
 Q.Save(ply);Q.Changed(ply)
 return true,"Обучение продолжается: «"..Steps[d.tut.step].title.."»"
end

-- Пакеты для КПК и окна квестодателя.
function Q.TutorialView(ply,d)
 if not Cfg.Tutorial or type(d.tut)~="table" or d.tut.state=="done" then return nil end
 if d.tut.state=="skipped" then return {state="skipped",step=d.tut.step,total=#Steps} end
 local step=Steps[d.tut.step];if not step then return nil end
 local pos,label=Q.TutorialTarget(ply,d)
 return {state="active",step=d.tut.step,total=#Steps,id=step.id,title=step.title,text=step.text,reward=Q.TutorialRewardView(step),
  pos=pos and Q.Vec3(pos) or nil,label=label,note=step.target and not pos and Q.TutorialMissing[step.target] or nil}
end
function Q.TutorialDialog(ply,d,ent)
 local step=Q.TutorialStep(d);if not step then return nil end
 local out={step=d.tut.step,total=#Steps,title=step.title,text=step.text}
 if step.id=="sell" and IsValid(ent) and ent:GetProfile()=="barman" then
  local id,price=Q.CheapestArtifact(ply)
  out.handover={item=id and Q.ItemName(id) or nil,price=price,can=id~=nil}
 end
 return out
end

-- Разговор с торговцем и вербовщиком засчитывается сразу по нажатию E (а не только по открытому окну).
hook.Add("PlayerUse","STALKER_QUESTS.Tutorial",function(ply,ent)
 if not IsValid(ply) or not IsValid(ent) then return end
 local class=ent:GetClass()
 if class=="stalker_npc_trader" or class=="stalker_recruiter" then Q.TutorialEvent(ply,"use",class) end
end)
-- F4 (gm_showspare2) — КПК. Клиент дополнительно сообщает об открытии вкладки «Задания».
hook.Add("ShowSpare2","STALKER_QUESTS.Tutorial",function(ply) if IsValid(ply) then Q.TutorialEvent(ply,"pda") end end)
