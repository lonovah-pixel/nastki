-- Клиент: состояние заданий, вкладка КПК «Задания», сводка для КПК, трекер в правом верхнем углу,
-- направляющая линия к цели (GUIDE LINE), подписи над квестодателями. Оформление — STALKER_STYLE и цвета темы.
local Q=STALKER_QUESTS
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local Cfg=Q.Config
local function px(n) return T.Px(n) end
local trackerCvar=CreateClientConVar("stq_tracker","1",true,false,"Трекер задания в правом верхнем углу: 1 — показывать, 0 — скрыть")
local guideCvar=CreateClientConVar("stq_guideline","1",true,false,"Направляющая линия на земле к цели задания: 1 — показывать, 0 — скрыть")
Q.State=Q.State or {active={},history={},npcs={},max=Cfg.MaxActive,daily=Cfg.DailyLimit,today=0,done=0}
Q.StateAt=Q.StateAt or 0
Q.StatusNames={done="выполнено",abandoned="отказ",expired="срок истёк",failed="провалено"}
Q.StatusTokens={done="ok",abandoned="muted",expired="warn",failed="danger"}

--[[ Общие элементы окон заданий ]]
local UI={}
Q.UI=UI
function UI.Scroll(parent) local sc=vgui.Create("DScrollPanel",parent);sc:Dock(FILL);U.Scroll(sc);return sc end
function UI.Head(parent,text)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(30));p:DockMargin(0,px(8),0,px(4));p.Text=text
 p.Paint=function(self,w,h) U.Text(U.Fit(self.Text,"STALKER.Head",w),"STALKER.Head",0,h/2,"accent",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);surface.SetDrawColor(T.C.line);surface.DrawRect(0,h-1,w,1) end
 return p
end
function UI.Note(parent,text,token)
 local l=U.Label(parent,text,"STALKER.Small",token or "muted");l:Dock(TOP);l:DockMargin(0,0,0,px(6))
 return l
end
function UI.Card(parent,h,paint)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(h));p:DockMargin(0,0,0,px(6))
 p:DockPadding(px(8),px(8),px(8),px(8))
 p.Paint=function(self,w,hh) U.Panel("",0,0,w,hh,self.Active);if paint then paint(self,w,hh) end end
 return p
end
-- Ряд кнопок внизу карточки (кнопки добавляются справа налево).
function UI.Buttons(card)
 local row=vgui.Create("DPanel",card);row:Dock(BOTTOM);row:SetTall(px(28));row.Paint=function() end
 return row
end
function UI.Row(parent,h)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(h or 32));p:DockMargin(0,0,0,px(6));p.Paint=function() end
 return p
end
function UI.Button(parent,label,fn,kind,wide)
 local b=U.Button(parent,label,fn,kind);b:Dock(RIGHT);b:SetWide(px(wide or 130));b:DockMargin(px(6),0,0,0)
 return b
end
function UI.Entry(parent,placeholder,value,onChange)
 local e=vgui.Create("DTextEntry",parent);U.Entry(e);e:Dock(FILL)
 e:SetPlaceholderText(placeholder or "");e:SetValue(value or "")
 e.OnChange=function(self) if onChange then onChange(self:GetValue()) end end
 return e
end
-- Текст в несколько строк в пределах ширины (рисуется в Paint карточки).
function UI.Lines(text,font,x,y,w,maxLines,token,lineH)
 local lines=U.Wrap(text or "",font,math.max(20,w))
 for i=1,math.min(maxLines,#lines) do
  local line=lines[i];if i==maxLines and #lines>maxLines then line=U.Fit(line.." …",font,w) end
  U.Text(line,font,x,y+(i-1)*(lineH or px(16)),token or "text")
 end
 return math.min(maxLines,#lines)
end
local function meters(units) local m=units*.01905;return m<1000 and string.format("%.0f м",m) or string.format("%.1f км",m/1000) end
Q.Meters=meters

--[[ Состояние ]]
function Q.Left(left) return math.max(0,(tonumber(left) or 0)-(CurTime()-Q.StateAt)) end
-- Вкладку КПК перестраиваем только при изменении состава (карточки читают свежий снимок сами).
local function layout(s)
 local parts={tostring(s.tracked),#(s.history or {})}
 for _,q in ipairs(s.active or {}) do parts[#parts+1]=tostring(q.uid) end
 local t=s.tutorial;parts[#parts+1]=t and (tostring(t.state)..tostring(t.step)) or "-"
 return table.concat(parts,"|")
end
net.Receive("stalker_quests.state",function(len)
 local d=C.Read(len);if not d then return end
 d.active=type(d.active)=="table" and d.active or {}
 d.history=type(d.history)=="table" and d.history or {}
 d.npcs=type(d.npcs)=="table" and d.npcs or {}
 local rebuild=layout(d)~=layout(Q.State or {})
 Q.State=d;Q.StateAt=CurTime()
 hook.Run("STALKER_QUESTS_StateUpdated",d)
 if rebuild and IsValid(Q.PDAPanel) then Q.BuildPDATab(Q.PDAPanel) end
end)
function Q.Request(op,data)
 data=data or {};data.op=op
 return C.Send("stalker_quests.action",nil,data)
end

-- Отслеживаемая цель: задание или текущий шаг обучения (единый вид для трекера и линии).
function Q.Tracked()
 local s=Q.State or {}
 local tut=s.tutorial
 if s.tracked=="tutorial" and tut and tut.state=="active" then
  return {tutorial=true,title=tostring(tut.title),objective=tut.note or tut.text or "Подробности — КПК, вкладка «Задания»",progress=(tut.step or 1)-1,
   goal=tut.total or #Q.TutorialSteps,pos=tut.pos,label=tut.label}
 end
 for _,q in ipairs(s.active or {}) do if q.uid==s.tracked then return q end end
end
function Q.TrackedPos()
 local t=Q.Tracked()
 if t and type(t.pos)=="table" and tonumber(t.pos.x) then return Vector(t.pos.x,t.pos.y,t.pos.z),t end
end

-- Для сводки КПК (контракт): {{title, progress, goal}}, отслеживаемое — первым.
function Q.ActiveSummary()
 local s=Q.State or {};local first,rest={},{}
 local tut=s.tutorial
 if tut and tut.state=="active" then
  local row={title="Путь новичка: "..tostring(tut.title),progress=(tut.step or 1)-1,goal=tut.total or #Q.TutorialSteps}
  if s.tracked=="tutorial" then first[#first+1]=row else rest[#rest+1]=row end
 end
 for _,q in ipairs(s.active or {}) do
  local row={title=tostring(q.title),progress=tonumber(q.progress) or 0,goal=tonumber(q.goal) or 1,ready=q.ready==true}
  if s.tracked==q.uid then first[#first+1]=row else rest[#rest+1]=row end
 end
 for _,row in ipairs(rest) do first[#first+1]=row end
 return first
end

--[[ КПК открыт: засчитывается шаг обучения «КПК» (F4, вкладка «Задания» или хук окна КПК) ]]
local lastPDA=0
function Q.NotifyPDA()
 local tut=(Q.State or {}).tutorial
 if not tut or tut.state~="active" or tut.id~="pda" or CurTime()-lastPDA<2 then return false end
 lastPDA=CurTime()
 return Q.Request("pda")
end
hook.Add("PlayerBindPress","STALKER_QUESTS.PDA",function(_,bind,pressed)
 if pressed and type(bind)=="string" and bind:lower():find("gm_showspare2",1,true) then Q.NotifyPDA() end
end)
hook.Add("ShowSpare2","STALKER_QUESTS.PDA",function() Q.NotifyPDA() end)
hook.Add("STALKER_PDAOpened","STALKER_QUESTS.PDA",function() Q.NotifyPDA() end)

--[[ Вкладка КПК «Задания» ]]
local function rewardLine(r) return "Награда: "..Q.RewardText(r) end
local function questCard(sc,i)
 local q0=Q.State.active[i]
 local card=UI.Card(sc,160,function(self,w,h)
  local q=(Q.State.active or {})[i];if not q then return end
  local tracked=Q.State.tracked==q.uid;self.Active=tracked
  local left=Q.Left(q.left)
  U.Text(U.Fit(q.title or "","STALKER.Head",w-px(140)),"STALKER.Head",px(12),px(8),"accent")
  U.Text(Q.FormatTime(left),"STALKER.Mono",w-px(12),px(10),left<300 and "warn" or "text",TEXT_ALIGN_RIGHT)
  local typ=Q.Types[q.type or ""]
  U.Text(U.Fit((typ and typ.label or "Задание").." · выдал: "..tostring(q.giverName or "?")..(tracked and " · отслеживается" or ""),"STALKER.Small",w-px(24)),"STALKER.Small",px(12),px(30),"muted")
  U.Text(U.Fit(q.desc or "","STALKER.Small",w-px(24)),"STALKER.Small",px(12),px(48),"muted")
  local goal=math.max(1,tonumber(q.goal) or 1);local prog=tonumber(q.progress) or 0
  U.Text(U.Fit(q.ready and ("Готово — "..tostring(q.label or "вернитесь к квестодателю")) or (q.objective or ""),"STALKER.Small",w-px(90)),"STALKER.Small",px(12),px(68),q.ready and "ok" or "text")
  U.Text(prog.."/"..goal,"STALKER.Mono",w-px(12),px(68),q.ready and "ok" or "accent",TEXT_ALIGN_RIGHT)
  U.Bar(px(12),px(88),w-px(24),px(5),prog/goal,q.ready and T.C.ok or T.C.accent)
  U.Text(U.Fit(rewardLine(q.reward),"STALKER.Small",w-px(24)),"STALKER.Small",px(12),px(98),"text")
 end)
 card:SetTooltip(q0 and q0.desc or "")
 local row=UI.Buttons(card)
 local uid=q0 and q0.uid
 local abandon=UI.Button(row,"Отказаться",nil,"danger",150)
 abandon.Confirm=false
 abandon.DoClick=function(self)
  -- Отказ в два нажатия: первое спрашивает подтверждение.
  if not self.Confirm then self.Confirm=true;self.Label="Точно отказаться?";surface.PlaySound("buttons/button16.wav");return end
  surface.PlaySound("buttons/lightswitch2.wav");Q.Request("abandon",{uid=uid})
 end
 local tracked=Q.State.tracked==uid
 UI.Button(row,tracked and "Не отслеживать" or "Отслеживать",function() Q.Request("track",{uid=tracked and "" or uid}) end,tracked and nil or "accent",150)
 return card
end
local function tutorialSection(sc,s)
 local tut=s.tutorial
 if not tut then return end
 if tut.state=="skipped" then
  UI.Head(sc,"Путь новичка — отложено")
  local card=UI.Card(sc,74,function(_,w,h)
   U.Text("Обучение остановлено на шаге "..tostring(tut.step).." из "..tostring(tut.total),"STALKER.Body",px(12),px(8),"text")
  end)
  UI.Button(UI.Buttons(card),"Продолжить обучение",function() Q.Request("tutorial_resume") end,"accent",200)
  return
 end
 UI.Head(sc,"Путь новичка · шаг "..tostring(tut.step).." из "..tostring(tut.total))
 local card=UI.Card(sc,168,function(self,w,h)
  local t=(Q.State or {}).tutorial;if not t or t.state~="active" then return end
  self.Active=Q.State.tracked=="tutorial"
  U.Text(U.Fit(tostring(t.title),"STALKER.Head",w-px(24)),"STALKER.Head",px(12),px(8),"accent2")
  UI.Lines(t.text,"STALKER.Small",px(12),px(32),w-px(24),3,"text")
  U.Bar(px(12),px(86),w-px(24),px(5),((t.step or 1)-1)/math.max(1,t.total or 6),T.C.accent2)
  local info=t.note or (t.label and (t.label.." · "..(t.pos and LocalPlayer and IsValid(LocalPlayer()) and meters(LocalPlayer():GetPos():Distance(Vector(t.pos.x,t.pos.y,t.pos.z))) or "")) or "")
  U.Text(U.Fit(info,"STALKER.Small",w-px(24)),"STALKER.Small",px(12),px(96),t.note and "warn" or "muted")
  U.Text(U.Fit(rewardLine(t.reward),"STALKER.Small",w-px(24)),"STALKER.Small",px(12),px(114),"text")
 end)
 local row=UI.Buttons(card)
 UI.Button(row,"Отложить обучение",function() Q.Request("tutorial_stop") end,"danger",180)
 UI.Button(row,"Пропустить шаг",function() Q.Request("tutorial_skip") end,nil,160)
 if s.tracked~="tutorial" then UI.Button(row,"Отслеживать",function() Q.Request("track",{uid="tutorial"}) end,"accent",150) end
end
function Q.BuildPDATab(parent)
 Q.PDAPanel=parent
 parent:Clear()
 Q.NotifyPDA()
 local s=Q.State or {}
 local sc=UI.Scroll(parent)
 tutorialSection(sc,s)
 local daily=(tonumber(s.daily) or 0)>0 and (" · сегодня взято "..tostring(s.today or 0).." из "..tostring(s.daily)) or ""
 UI.Head(sc,"Активные задания: "..#(s.active or {}).." из "..tostring(s.max or Cfg.MaxActive)..daily)
 if #(s.active or {})==0 then
  UI.Note(sc,"Активных заданий нет. Задания выдают квестодатели — Бармен, Профессор, Охотник и Связной: подойдите и нажмите E.")
 end
 for i in ipairs(s.active or {}) do questCard(sc,i) end
 UI.Head(sc,"История · выполнено заданий: "..tostring(s.done or 0))
 if #(s.history or {})==0 then UI.Note(sc,"История пуста.") end
 for i in ipairs(s.history or {}) do
  UI.Card(sc,40,function(_,w,h)
   local e=(Q.State.history or {})[i];if not e then return end
   U.Text(U.Fit(tostring(e.title),"STALKER.Body",w*.45),"STALKER.Body",px(12),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   U.Text(U.Fit(tostring(e.giver or ""),"STALKER.Small",w*.22),"STALKER.Small",w*.47,h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   local status=Q.StatusNames[e.status] or tostring(e.status)
   if e.status=="done" and (tonumber(e.money) or 0)>0 then status=status.." · "..Q.Money(e.money) end
   U.Text(status,"STALKER.Small",w*.70,h/2,Q.StatusTokens[e.status] or "muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   U.Text(e.t and os.date("%d.%m %H:%M",e.t) or "","STALKER.Mono",w-px(12),h/2,"muted",TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
  end)
 end
 UI.Note(sc,"Отслеживаемое задание показано в правом верхнем углу и ведёт направляющая линия на земле. "..
  "Скрыть: stq_guideline 0 (линия), stq_tracker 0 (трекер). Метки целей — на экране и на карте КПК.")
 return sc
end
if C.RegisterPDATab then
 C.RegisterPDATab("quests",{title="Задания",order=45,build=function(parent) Q.BuildPDATab(parent) end,
  badge=function()
   local n=0;for _,q in ipairs((Q.State or {}).active or {}) do if q.ready then n=n+1 end end
   return n>0 and n or nil
  end})
end
-- Журнал заданий: вкладка КПК, а без аддона КПК — отдельное окно с тем же содержимым.
concommand.Add("stq_journal",function()
 if C.PDAOpen then C.OpenPDA("quests");return end
 if IsValid(Q.JournalFrame) then Q.JournalFrame:Remove() end
 local f=U.Window({title="Журнал заданий",w=820,h=660,onClose=function() Q.JournalFrame=nil;Q.PDAPanel=nil end})
 Q.JournalFrame=f
 local holder=vgui.Create("DPanel",f);holder:Dock(FILL);holder.Paint=function() end
 Q.BuildPDATab(holder)
 Q.Request("state")
end)

--[[ Трекер (правый верхний угол) ]]
function Q.PaintTracker()
 if not trackerCvar:GetBool() then return end
 local lp=LocalPlayer();if not IsValid(lp) then return end
 local t=Q.Tracked();if not t then return false end
 local w=px(320);local x,y=ScrW()-w-px(24),px(24)
 local pos=t.pos and Vector(t.pos.x,t.pos.y,t.pos.z)
 -- Компактно (до 76 px): ниже начинаются уведомления группировок.
 local h=px(pos and 76 or 60)
 U.Panel("",x,y,w,h,true)
 local timeW=0
 if t.left then
  local left=Q.Left(t.left);local text=Q.FormatTime(left)
  surface.SetFont("STALKER.Mono");timeW=surface.GetTextSize(text)+px(8)
  U.Text(text,"STALKER.Mono",x+w-px(10),y+px(8),left<300 and "warn" or "muted",TEXT_ALIGN_RIGHT)
 end
 local title=(t.tutorial and "Обучение: " or "")..tostring(t.title or "")
 U.Text(U.Fit(title,"STALKER.Head",w-px(20)-timeW),"STALKER.Head",x+px(10),y+px(6),t.tutorial and "accent2" or "accent")
 local goal=math.max(1,tonumber(t.goal) or 1);local prog=tonumber(t.progress) or 0
 local line=t.ready and ("Готово — "..tostring(t.label or "к квестодателю")) or tostring(t.objective or "")
 U.Text(U.Fit(line,"STALKER.Small",w-px(70)),"STALKER.Small",x+px(10),y+px(28),t.ready and "ok" or "text")
 U.Text(prog.."/"..goal,"STALKER.Mono",x+w-px(10),y+px(28),t.ready and "ok" or "accent",TEXT_ALIGN_RIGHT)
 U.Bar(x+px(10),y+px(47),w-px(20),px(5),prog/goal,t.ready and T.C.ok or (t.tutorial and T.C.accent2 or T.C.accent))
 if pos then
  local text="До цели: "..meters(lp:GetPos():Distance(pos))..(t.label and (" · "..t.label) or "")
  U.Text(U.Fit(text,"STALKER.Small",w-px(20)),"STALKER.Small",x+px(10),y+px(56),"muted")
 end
 return true
end

--[[ GUIDE LINE: шевроны на земле от игрока к цели по прямой (до GuideLength units), бегут к цели и тают вдали.
 Высоту земли берём трассировками вдоль линии раз в 32 units; профиль пересчитывается, когда игрок отошёл,
 цель сменилась или прошло полсекунды. Шевроны привязаны к цели, поэтому не дёргаются при движении игрока. ]]
Q.GuideStep=32
function Q.BuildGuide(origin,target)
 local dir=Vector(target.x-origin.x,target.y-origin.y,0);local dist=dir:Length()
 if dist<1 then return end
 dir=dir*(1/dist)
 local len=math.min(Cfg.GuideLength,dist)
 local step=Q.GuideStep;local n=math.floor(len/step)+1
 local samples={};local z=origin.z;local lp=LocalPlayer()
 for i=0,n do
  local start=Vector(origin.x+dir.x*i*step,origin.y+dir.y*i*step,z+72)
  local tr=util.TraceLine({start=start,endpos=start-Vector(0,0,512),mask=MASK_SOLID_BRUSHONLY,filter=lp})
  if tr and tr.Hit and not tr.StartSolid then z=tr.HitPos.z end
  samples[i]=z
 end
 return {origin=origin,target=target,dir=dir,len=len,dist=dist,step=step,samples=samples,n=n,built=CurTime()}
end
local function groundZ(g,along)
 local f=math.Clamp(along/g.step,0,g.n);local i=math.floor(f)
 local a=g.samples[i] or g.origin.z;local b=g.samples[i+1] or a
 return a+(b-a)*(f-i)
end
Q.GuideSpacing=72;Q.GuideSpeed=90
-- Список шевронов {pos, dir, alpha} для текущего кадра (отдельно от отрисовки — проверяется сценарием).
function Q.GuideChevrons()
 if not guideCvar:GetBool() then Q.Guide=nil;return end
 local lp=LocalPlayer();if not IsValid(lp) or not lp:Alive() then return end
 local target=Q.TrackedPos();if not target then Q.Guide=nil;return end
 local origin=lp:GetPos()
 local g=Q.Guide
 if not g or g.target:DistToSqr(target)>1 or g.origin:DistToSqr(origin)>48*48 or CurTime()-g.built>.5 then g=Q.BuildGuide(origin,target);Q.Guide=g end
 if not g then return end
 local dir=Vector(target.x-origin.x,target.y-origin.y,0);local dist=dir:Length()
 if dist<96 then return {} end
 dir=dir*(1/dist)
 local len=math.min(Cfg.GuideLength,dist)
 local spacing=Q.GuideSpacing
 -- Расстояние от цели до шеврона кратно шагу и уменьшается со временем: шевроны «бегут» к цели.
 local phase=(-CurTime()*Q.GuideSpeed)%spacing
 local k=math.max(0,math.ceil((dist-phase-len)/spacing))
 -- Предел — 200 шевронов от первого, а не номер шага от цели: у цели дальше ~15 000 units k с самого начала больше 200.
 local k0=k
 local out={}
 while true do
  local d=dist-phase-k*spacing
  if d<40 then break end
  if d<=len then
   local fadeIn=math.Clamp((d-40)/120,0,1);local fadeOut=math.Clamp(1-d/len,0,1)^.7
   local alpha=math.floor(235*fadeIn*fadeOut)
   if alpha>4 then
    local wx,wy=origin.x+dir.x*d,origin.y+dir.y*d
    local along=(wx-g.origin.x)*g.dir.x+(wy-g.origin.y)*g.dir.y
    out[#out+1]={pos=Vector(wx,wy,groundZ(g,along)+3),alpha=alpha}
   end
  end
  k=k+1
  if k-k0>200 then break end
 end
 return out,dir
end
function Q.DrawGuide()
 local list,dir=Q.GuideChevrons()
 if not list or #list==0 or not dir then return 0 end
 local c=T.C.accent2;local right=Vector(-dir.y,dir.x,0)
 render.SetColorMaterial()
 for _,ch in ipairs(list) do
  local col=Color(c.r,c.g,c.b,ch.alpha)
  local tip=ch.pos+dir*10;local back=ch.pos-dir*8
  render.DrawBeam(back+right*14,tip,4,0,1,col)
  render.DrawBeam(back-right*14,tip,4,0,1,col)
 end
 return #list
end
hook.Add("PostDrawTranslucentRenderables","STALKER_QUESTS.Guide",function(depth,sky)
 if depth or sky then return end
 Q.DrawGuide()
end)

--[[ Квестодатели: подпись над головой, «?» — можно сдать задание, «!» — шаг обучения; подсказка «E — поговорить» ]]
function Q.NPCLabel(ent)
 local prof=Q.Profiles[ent:GetProfile()];local base=prof and prof.name or "Квестодатель";local name=ent:GetQuestName()
 if name=="" or name==base then return base end
 return base.." «"..name.."»"
end
function Q.NPCMark(ent)
 local s=Q.State or {}
 if s.npcs and s.npcs[ent:GetNpcID()] then return "?","ok" end
 local tut=s.tutorial
 if tut and tut.state=="active" and tut.id=="sell" and ent:GetProfile()=="barman" then return "!","accent2" end
end
function Q.DrawNPC(ent)
 local eye=EyePos();local pos=ent:GetPos()+Vector(0,0,84)
 local dist=eye:Distance(pos);if dist>800 then return end
 local alpha=math.Clamp((800-dist)/200,0,1)
 local prof=Q.Profiles[ent:GetProfile()]
 local shadow=T.Color("shadow",math.floor(220*alpha))
 cam.Start3D2D(pos,Angle(0,EyeAngles().y-90,90),.16)
  draw.SimpleTextOutlined(Q.NPCLabel(ent),"STALKER.Big",0,0,T.Color("accent",math.floor(255*alpha)),TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,2,shadow)
  if prof then draw.SimpleTextOutlined(prof.title,"STALKER.Head",0,px(2),T.Color("text",math.floor(230*alpha)),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,shadow) end
  local mark,token=Q.NPCMark(ent)
  if mark then draw.SimpleTextOutlined(mark,"STALKER.Big",0,-px(40),T.Color(token,math.floor(255*alpha)),TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,2,shadow) end
 cam.End3D2D()
end
function Q.HintFor(ent,lp)
 if not IsValid(ent) or ent:GetClass()~="stalker_quest_npc" then return end
 if lp:GetPos():DistToSqr(ent:GetPos())>Cfg.TalkDistance^2 then return end
 return "E — поговорить: "..Q.NPCLabel(ent)
end
hook.Add("HUDPaint","STALKER_QUESTS.HUD",function()
 local lp=LocalPlayer();if not IsValid(lp) then return end
 Q.PaintTracker()
 local tr=lp:GetEyeTrace()
 local text=tr and Q.HintFor(tr.Entity,lp)
 if text then
  surface.SetFont("STALKER.Body")
  local tw=surface.GetTextSize(text)
  local w=math.max(px(220),tw+px(28));local h=px(32);local x,y=ScrW()/2-w/2,ScrH()/2+px(40)
  U.Panel("",x,y,w,h,true)
  U.Text(text,"STALKER.Body",ScrW()/2,y+h/2,"text",TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
end)
