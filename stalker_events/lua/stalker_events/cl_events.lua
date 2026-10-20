-- Клиент: состояние событий, вкладка КПК «События», выбор видимости маячка, подсказки у ящика и маячка,
-- предупреждение цели «Охоты за головой». Оформление — только STALKER_STYLE и цвета темы.
local E=STALKER_EVENTS
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local function px(n) return T.Px(n) end
E.State=E.State or {active={},beacons={},limit=E.Config.BeaconLimit}
E.StateAt=E.StateAt or 0

--[[ Общие элементы окон событий ]]
local UI={}
E.UI=UI
function UI.Scroll(parent) local sc=vgui.Create("DScrollPanel",parent);sc:Dock(FILL);U.Scroll(sc);return sc end
function UI.Head(parent,text)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(30));p:DockMargin(0,px(8),0,px(4))
 p.Paint=function(_,w,h) U.Text(text,"STALKER.Head",0,h/2,"accent",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);surface.SetDrawColor(T.C.line);surface.DrawRect(0,h-1,w,1) end
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
function UI.Row(parent,h)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(h or 32));p:DockMargin(0,0,0,px(6))
 p.Paint=function() end
 return p
end
-- Кнопка у правого края строки или карточки.
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

-- Остаток времени с поправкой на момент получения снимка.
function E.Left(left,at) return math.max(0,(tonumber(left) or 0)-(CurTime()-(at or E.StateAt))) end

-- Состав вкладки КПК: перестраиваем её, только когда меняется число строк (иначе карточки читают свежий снимок сами).
local function layout(s)
 local ids={};for _,ev in ipairs(s.active or {}) do ids[#ids+1]=tostring(ev.id) end
 return table.concat(ids,",").."|"..#(s.beacons or {}).."|"..(s.target and "t" or "")
end
net.Receive("stalker_events.state",function(len)
 local d=C.Read(len);if not d then return end
 d.active=type(d.active)=="table" and d.active or {}
 d.beacons=type(d.beacons)=="table" and d.beacons or {}
 local rebuild=layout(d)~=layout(E.State or {})
 E.State=d;E.StateAt=CurTime()
 hook.Run("STALKER_EVENTS_StateUpdated",d)
 if rebuild and IsValid(E.PDAPanel) then E.BuildPDATab(E.PDAPanel) end
end)

--[[ Вкладка КПК «События» ]]
function E.BuildPDATab(parent)
 E.PDAPanel=parent
 parent:Clear()
 local s=E.State or {}
 local sc=UI.Scroll(parent)
 UI.Head(sc,"События Зоны")
 local active=s.active or {}
 if #active==0 then UI.Note(sc,"Сейчас в Зоне спокойно. О новом событии сообщит лента КПК, а место отметится на экране и на карте.") end
 for i in ipairs(active) do
  UI.Card(sc,76,function(_,w,h)
   local row=(E.State.active or {})[i];if not row then return end
   U.Text(U.Fit(row.name or "","STALKER.Head",w-px(120)),"STALKER.Head",px(12),px(8),"accent")
   U.Text(E.FormatTime(E.Left(row.left)),"STALKER.Mono",w-px(12),px(10),"text",TEXT_ALIGN_RIGHT)
   local sub=row.info or (row.where and ("Место: "..row.where)) or ""
   U.Text(U.Fit(sub,"STALKER.Small",w-px(24)),"STALKER.Small",px(12),px(32),"text")
   U.Text(U.Fit(row.desc or "","STALKER.Small",w-px(24)),"STALKER.Small",px(12),px(52),"muted")
  end)
 end
 if s.target then
  UI.Card(sc,56,function(_,w,h)
   local target=E.State.target;if not target then return end
   surface.SetDrawColor(T.Color("danger",40));surface.DrawRect(1,1,w-2,h-2)
   U.Text("За вашу голову назначена награда","STALKER.Head",px(12),px(8),"danger")
   U.Text("Продержитесь "..E.FormatTime(E.Left(target.left)).." — получите "..E.Money(target.reward or 0),"STALKER.Small",px(12),px(32),"text")
  end)
 end
 local beacons=s.beacons or {}
 UI.Head(sc,"Мои маячки: "..#beacons.." из "..(s.limit or E.Config.BeaconLimit))
 for i in ipairs(beacons) do
  UI.Card(sc,44,function(_,w,h)
   local row=(E.State.beacons or {})[i];if not row then return end
   U.Text(U.Fit(row.label or "Маячок","STALKER.Body",w*.5),"STALKER.Body",px(12),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   U.Text((row.faction or "")~="" and ("Группировка: "..C.FactionName(row.faction)) or "Виден только вам","STALKER.Small",w*.52,h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   local left=E.Left(row.left)
   U.Text(E.FormatTime(left),"STALKER.Mono",w-px(12),h/2,left<120 and "warn" or "text",TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
  end)
 end
 UI.Note(sc,"Маячок ставится из инвентаря: предмет «Маячок» → «Использовать», затем выберите, кому виден сигнал. "..
  "Свой маячок можно забрать, подойдя к нему и нажав E. Метки событий и маячков видны на экране и на карте КПК.")
end
if C.RegisterPDATab then
 C.RegisterPDATab("events",{title="События",order=50,build=function(parent) E.BuildPDATab(parent) end,
  badge=function() local n=#((E.State or {}).active or {});return n>0 and n or nil end})
end

--[[ Маячок: выбор видимости и подписи ]]
function E.OpenBeaconPrompt(d)
 if IsValid(E.BeaconFrame) then E.BeaconFrame:Remove() end
 local f=U.Window({title="Маячок",w=460,h=280,onClose=function() E.BeaconFrame=nil end})
 E.BeaconFrame=f
 UI.Note(f,"Маячок встанет на землю под прицелом (не дальше "..math.floor(C.Meters(E.Config.BeaconRange)).." м) и будет мигать "..
  tostring(d.minutes or E.Config.BeaconMinutes).." мин. Работает ваших маячков: "..tostring(d.have or 0).." из "..tostring(d.limit or E.Config.BeaconLimit)..".","text")
 local holder=UI.Row(f,34)
 local entry=UI.Entry(holder,"Подпись, например «Схрон у моста»",E.LastBeaconLabel or "")
 local function send(mode)
  local label=entry:GetValue()
  E.LastBeaconLabel=type(label)=="string" and label or nil
  C.Send("stalker_events.beacon",nil,{mode=mode,label=E.LastBeaconLabel})
  f:Remove()
 end
 E.BeaconSend=send
 local row=UI.Row(f,34)
 local fac=UI.Button(row,d.faction and ("Группировке «"..tostring(d.factionName or d.faction).."»") or "Группировке — вы не состоите",function() send("faction") end,nil,250)
 if not d.faction then fac:SetEnabled(false) end
 local mine=U.Button(row,"Только мне",function() send("self") end,"accent");mine:Dock(FILL)
 UI.Note(f,"Метку маячка видят на экране и на карте КПК только выбранные игроки. Забрать маячок — подойти и нажать E.")
end
net.Receive("stalker_events.beacon",function(len) local d=C.Read(len,2000);if d then E.OpenBeaconPrompt(d) end end)

--[[ Подсказки на экране ]]
local function hint(text,token)
 surface.SetFont("STALKER.Body")
 local w=math.max(px(220),surface.GetTextSize(text)+px(28))
 local h=px(32);local x,y=ScrW()/2-w/2,ScrH()/2+px(40)
 U.Panel("",x,y,w,h,true)
 U.Text(text,"STALKER.Body",ScrW()/2,y+h/2,token or "text",TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
end
E.Hint=hint
-- Имя владельца маячка глазами зрителя (знакомства STALKER Social): маячок, как и сумка погибшего, не выдаёт незнакомца.
function E.OwnerLabel(ent,lp)
 local name,sid=ent:GetOwnerName(),ent:GetOwnerSID();local SO=STALKER_SOCIAL
 if type(SO)~="table" or sid==lp:SteamID64() then return name end
 local owner=sid~="" and C.PlayerBySID and C.PlayerBySID(sid)
 if IsValid(owner) and SO.Label then return SO.Label(lp,owner) end
 local cfg=type(SO.Config)=="table" and SO.Config or {}
 if cfg.HideNames==false or (type(SO.MyKnown)=="table" and SO.MyKnown[sid]~=nil) or (cfg.AdminsSeeAll and lp:IsAdmin()) then return name end
 return (type(cfg.StrangerName)=="string" and cfg.StrangerName~="") and cfg.StrangerName or "Незнакомец"
end
function E.HintFor(ent,lp)
 if not IsValid(ent) then return end
 local class=ent:GetClass()
 if class=="stalker_cargo" then
  if ent:GetOpened() then return "E — забрать содержимое ("..ent:GetItemCount().." шт.)" end
  return "Удерживайте E — вскрыть сбитый груз"
 elseif class=="stalker_beacon" then
  local mine=ent:GetOwnerSID()==lp:SteamID64()
  return "Маячок «"..ent:GetLabel().."» · "..E.OwnerLabel(ent,lp)..(mine and "   ·   E — забрать" or "")
 end
end
hook.Add("HUDPaint","STALKER_EVENTS.HUD",function()
 local lp=LocalPlayer();if not IsValid(lp) then return end
 local tr=lp:GetEyeTrace()
 if tr and tr.HitPos and tr.HitPos:DistToSqr(lp:EyePos())<150*150 then
  local text=E.HintFor(tr.Entity,lp)
  if text then hint(text) end
 end
 -- Цель охоты видит, сколько осталось продержаться.
 local s=E.State
 if s and s.target and lp:Alive() then
  local w,h=px(380),px(46);local x,y=ScrW()/2-w/2,px(70)
  U.Panel("",x,y,w,h,true)
  surface.SetDrawColor(T.Color("danger",50));surface.DrawRect(x+1,y+1,w-2,h-2)
  U.Text("НА ВАС ОХОТЯТСЯ","STALKER.Head",ScrW()/2,y+px(6),"danger",TEXT_ALIGN_CENTER)
  U.Text("Продержитесь "..E.FormatTime(E.Left(s.target.left)),"STALKER.Small",ScrW()/2,y+px(26),"text",TEXT_ALIGN_CENTER)
 end
end)
