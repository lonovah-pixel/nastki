-- Окно разговора с квестодателем: приветствие, сдача выполненных заданий, шаг обучения, предложения с наградами.
-- Окно только показывает снимок сервера; кнопки отправляют выбор, сервер проверяет всё сам и присылает новый снимок.
local Q=STALKER_QUESTS
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local UI=Q.UI
local function px(n) return T.Px(n) end

function Q.DialogAction(op,data)
 local d=Q.Dialog;if not d then return false end
 data=data or {};data.npc=d.npc
 return Q.Request(op,data)
end
net.Receive("stalker_quests.dialog",function(len)
 local d=C.Read(len);if not d then return end
 d.offers=type(d.offers)=="table" and d.offers or {}
 d.turnins=type(d.turnins)=="table" and d.turnins or {}
 Q.Dialog=d
 if d.result and d.result.message then C.Toast(d.result.message,d.result.ok and "ok" or "warn",5) end
 Q.OpenDialogWindow(d)
end)

local function turninSection(sc,d)
 if #d.turnins==0 then return end
 UI.Head(sc,"Сдать задание")
 for _,row in ipairs(d.turnins) do
  local t=row
  local card=UI.Card(sc,96,function(self,w,h)
   self.Active=t.ready
   U.Text(U.Fit(t.title or "","STALKER.Head",w-px(24)),"STALKER.Head",px(12),px(8),"accent")
   local goal=math.max(1,tonumber(t.goal) or 1)
   local line=t.ready and (t.deliver and "Посылка при вас" or "Задание выполнено") or (t.reason or t.objective or "")
   U.Text(U.Fit(line,"STALKER.Small",w-px(200)),"STALKER.Small",px(12),px(32),t.ready and "ok" or "warn")
   U.Text(U.Fit("Награда: "..Q.RewardText(t.reward),"STALKER.Small",w-px(200)),"STALKER.Small",px(12),px(50),"text")
   if not t.deliver then U.Bar(px(12),px(70),w-px(200),px(4),(tonumber(t.progress) or 0)/goal,t.ready and T.C.ok or T.C.accent) end
  end)
  local b=UI.Button(UI.Buttons(card),t.deliver and "Отдать посылку" or "Сдать",function() Q.DialogAction("turnin",{uid=t.uid}) end,"accent",170)
  if not t.ready then b:SetEnabled(false) end
 end
end
local function tutorialSection(sc,d)
 local tut=d.tutorial;if not tut then return end
 UI.Head(sc,"Путь новичка · шаг "..tostring(tut.step).." из "..tostring(tut.total))
 local card=UI.Card(sc,tut.handover and 110 or 76,function(_,w,h)
  U.Text(U.Fit(tostring(tut.title),"STALKER.Head",w-px(24)),"STALKER.Head",px(12),px(8),"accent2")
  UI.Lines(tut.text,"STALKER.Small",px(12),px(30),w-px(24),2,"text")
  local hv=tut.handover
  if hv then
   local text=hv.can and ("Бармен купит «"..tostring(hv.item).."» за "..Q.Money(hv.price or 0)) or "В рюкзаке нет артефактов — найдите артефакт в поле аномалий"
   U.Text(U.Fit(text,"STALKER.Small",w-px(220)),"STALKER.Small",px(12),px(70),hv.can and "ok" or "warn")
  end
 end)
 if tut.handover then
  local b=UI.Button(UI.Buttons(card),"Сдать артефакт",function() Q.DialogAction("handover") end,"accent",190)
  if not tut.handover.can then b:SetEnabled(false) end
 end
end
local function offersSection(sc,d)
 UI.Head(sc,"Задания")
 if #d.offers==0 then UI.Note(sc,"Сейчас работы нет. Загляните позже — предложения обновляются, а сданные задания снова появятся после отката.") end
 for _,row in ipairs(d.offers) do
  local o=row
  local card=UI.Card(sc,150,function(_,w,h)
   local typ=Q.Types[o.type or ""]
   U.Text(U.Fit(o.title or "","STALKER.Head",w-px(200)),"STALKER.Head",px(12),px(8),"accent")
   U.Text((typ and typ.label or "Задание").." · срок "..tostring(o.time or "?").." мин","STALKER.Mono",w-px(12),px(10),"muted",TEXT_ALIGN_RIGHT)
   UI.Lines(o.desc,"STALKER.Small",px(12),px(32),w-px(24),3,"text")
   U.Text(U.Fit("Цель: "..tostring(o.objective or "").."  ("..tostring(o.goal or 1)..")","STALKER.Small",w-px(24)),"STALKER.Small",px(12),px(84),"muted")
   U.Text(U.Fit("Награда: "..Q.RewardText(o.reward),"STALKER.Small",w-px(200)),"STALKER.Small",px(12),px(104),"ok")
   if o.blocked then U.Text(U.Fit(o.blocked,"STALKER.Small",w-px(200)),"STALKER.Small",px(12),px(122),"warn") end
  end)
  local b=UI.Button(UI.Buttons(card),"Взять задание",function() Q.DialogAction("accept",{key=o.key}) end,"accent",170)
  if o.blocked then b:SetEnabled(false) end
 end
end
function Q.FillDialog(body,d)
 body:Clear()
 local head=vgui.Create("DPanel",body);head:Dock(TOP);head:SetTall(px(78));head:DockMargin(0,0,0,px(4))
 head.Paint=function(_,w,h)
  U.Panel("",0,0,w,h,false)
  U.Text(U.Fit(tostring(d.title or "").."  ·  "..tostring(d.about or ""),"STALKER.Small",w-px(20)),"STALKER.Small",px(10),px(6),"muted")
  UI.Lines("«"..tostring(d.greeting or "").."»","STALKER.Body",px(10),px(26),w-px(20),2,"text",px(19))
 end
 local foot=vgui.Create("DPanel",body);foot:Dock(BOTTOM);foot:SetTall(px(26));foot:DockMargin(0,px(4),0,0)
 foot.Paint=function(_,w,h)
  local daily=(tonumber(d.daily) or 0)>0 and ("   ·   взято сегодня: "..tostring(d.today or 0).." из "..tostring(d.daily)) or ""
  U.Text("Активных заданий: "..tostring(d.active or 0).." из "..tostring(d.max or "?")..daily,"STALKER.Small",0,h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  U.Text("Журнал — КПК (F4) → «Задания»","STALKER.Small",w,h/2,"muted",TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
 end
 local sc=UI.Scroll(body)
 turninSection(sc,d)
 tutorialSection(sc,d)
 offersSection(sc,d)
 return sc
end
function Q.OpenDialogWindow(d)
 local f=Q.DialogFrame
 if not IsValid(f) or f.NpcIndex~=d.npc then
  if IsValid(f) then f:Remove() end
  f=U.Window({title=tostring(d.name or "Квестодатель"),w=780,h=660,onClose=function() Q.DialogFrame=nil;Q.Dialog=nil end})
  f.NpcIndex=d.npc
  f.Body=vgui.Create("DPanel",f);f.Body:Dock(FILL);f.Body.Paint=function() end
  Q.DialogFrame=f
 end
 f.Title=tostring(d.name or "Квестодатель")
 Q.FillDialog(f.Body,d)
 return f
end
-- Окно закрывается, если игрок отошёл от квестодателя.
hook.Add("Think","STALKER_QUESTS.Dialog",function()
 local f=Q.DialogFrame;if not IsValid(f) or not Q.Dialog then return end
 local lp=LocalPlayer();local ent=Entity(Q.Dialog.npc or 0)
 if not IsValid(lp) or not IsValid(ent) or lp:GetPos():DistToSqr(ent:GetPos())>(Q.Config.TalkDistance+60)^2 then f:Remove() end
end)
