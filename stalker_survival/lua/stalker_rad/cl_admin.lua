-- Редактор радиационных зон (клиент): панель STALKER_RAD.BuildAdminPanel(parent) для «Коменданта»
-- и отдельное окно stalker_rad_menu. Пока панель открыта, зоны видны в мире (кольца, линии, подписи)
-- и метками на HUD/карте. Все изменения — запросами к серверу, он же проверяет права.
local R=STALKER_RAD
local C=STALKER_CORE
R.AdminZones=R.AdminZones or {}
R.Views=R.Views or {}
R.MarkerIDs=R.MarkerIDs or {}
R.FormVersion=R.FormVersion or 0

local function col(token,alpha)
 local c=R.ThemeColor(token)
 if alpha then return Color(c.r,c.g,c.b,alpha) end
 return c
end
local function px(n) local T=STALKER_THEME;return T and T.Px and T.Px(n) or math.Round(n) end
local function meters(units) return string.format("%.0f м",units*.01905) end

-- Поиск без учёта регистра, включая кириллицу (string.lower её не понижает).
function R.Lower(s)
 s=tostring(s or ""):lower()
 return (s:gsub("\208([\128-\175])",function(ch)
  local b=ch:byte()
  if b<=143 then return "\209"..string.char(b+16) end
  if b<=159 then return "\208"..string.char(b+32) end
  return "\209"..string.char(b-32)
 end))
end

function R.DefaultDraft() return {name="",radius=300,rate=2,falloff=true,enabled=true} end
R.Draft=R.Draft or R.DefaultDraft()

function R.Request(op,fields)
 if not C or not C.Send then return false end
 local t=fields or {};t.op=op
 return C.Send("stalker_rad.request",nil,t)
end
function R.ZoneByID(id) for _,z in ipairs(R.AdminZones) do if z.id==id then return z end end end

-- Снимок сервера: зоны проверяются по типам перед отрисовкой.
local function cleanZones(list)
 local out={}
 for _,z in ipairs(type(list)=="table" and list or {}) do
  if type(z)=="table" and type(z.id)=="string" and type(z.pos)=="table" and tonumber(z.pos.x) and tonumber(z.pos.y) and tonumber(z.pos.z)
   and tonumber(z.radius) and tonumber(z.rate) then
   z.name=tostring(z.name or z.id);out[#out+1]=z
  end
 end
 return out
end
function R.SetStatus(ok,message) R.LastResult={ok=ok,message=tostring(message or ""),at=CurTime()} end

function R.OnAdminState(data)
 if type(data)~="table" then return end
 R.AdminState=data
 if data.zones~=nil then R.AdminZones=cleanZones(data.zones) elseif data.denied then R.AdminZones={} end
 local res=data.result
 if type(res)=="table" then
  R.SetStatus(res.ok==true,res.message or (res.ok and "Готово" or "Отклонено"))
  if res.ok and res.op=="create" and type(res.id)=="string" then R.Select(res.id,true) end
 end
 if R.Selected and not R.ZoneByID(R.Selected) then R.Selected=nil end
 R.SyncMarkers()
 R.RefreshPanel()
end
if C and C.Read then net.Receive("stalker_rad.state",function(len) local data=C.Read(len);if data then R.OnAdminState(data) end end) end

-- Выбор зоны переносит её поля в форму.
function R.Select(id,quiet)
 local z=id and R.ZoneByID(id)
 R.Selected=z and z.id or nil
 R.Draft=z and {name=z.name,radius=z.radius,rate=z.rate,falloff=z.falloff~=false,enabled=z.enabled~=false} or R.DefaultDraft()
 R.FormVersion=R.FormVersion+1
 R.SyncMarkers()
 if not quiet then R.RefreshPanel() end
end

function R.PreviewActive()
 for v in pairs(R.Views) do if IsValid(v.root) then return true end end
 return false
end

-- Локальные метки зон (видит только этот администратор), выбранная — со стрелкой у края экрана.
function R.SyncMarkers()
 local MK=STALKER_MARKERS;if not MK or not MK.SetLocal then return end
 local keep={}
 if R.PreviewActive() then
  for _,z in ipairs(R.AdminZones) do
   local id="rad."..z.id;keep[id]=true
   MK.SetLocal(id,{pos=Vector(z.pos.x,z.pos.y,z.pos.z),label="☢ "..z.name,kind="poi",color=z.enabled~=false and col("warn") or col("muted"),
    world=false,edge=z.id==R.Selected,range=30000})
  end
 end
 for id in pairs(R.MarkerIDs) do if not keep[id] then MK.RemoveLocal(id) end end
 R.MarkerIDs=keep
end

function R.ZoneSummary(z)
 return string.format("%.2f ед./с · R %d%s%s",z.rate,z.radius,z.falloff~=false and " · спад" or "",z.enabled==false and " · выкл." or "")
end
local function zoneColor(z)
 if z.id==R.Selected then return col("accent") end
 if z.enabled==false then return col("muted") end
 return col("warn")
end

-- Список с фильтром и сортировкой по расстоянию.
function R.VisibleZones()
 local q=R.Lower(string.Trim(R.Filter or ""))
 local out={}
 for _,z in ipairs(R.AdminZones) do
  if q=="" or R.Lower(z.name):find(q,1,true) or z.id:find(q,1,true) then out[#out+1]=z end
 end
 local p=LocalPlayer()
 if R.SortByDistance and IsValid(p) then
  local here=p:GetPos();local d={}
  for _,z in ipairs(out) do d[z]=here:DistToSqr(Vector(z.pos.x,z.pos.y,z.pos.z)) end
  table.sort(out,function(a,b) return d[a]<d[b] end)
 end
 return out
end

--[[ Отрисовка частей панели (вынесены в функции: их же вызывают тесты). ]]
function R.PaintHeader(w,h)
 local U=STALKER_STYLE;local st=R.AdminState
 U.Panel("",0,0,w,h,false)
 U.Text("☢ Радиационные зоны"..(st and st.map and (" · "..st.map) or ""),"STALKER.Head",px(12),px(8),"accent")
 local line,token
 if not st then line,token="Загрузка списка зон…","muted"
 elseif st.denied then line,token="Нет права radiation: обратитесь к старшему администратору","danger"
 elseif not st.ready then line,token="Файл зон повреждён — правка заблокирована: "..tostring(st.error or "?").." Исправьте файл и нажмите «Перечитать файл».","danger"
 else
  local on=0;for _,z in ipairs(R.AdminZones) do if z.enabled~=false then on=on+1 end end
  line=string.format("Зон: %d / %d · включено %d",#R.AdminZones,tonumber(st.limit) or R.Config.ZonesLimit,on);token="muted"
  if st.migrated then line=line..string.format(" · перенесено из старого формата: %d",tonumber(st.migrated.count) or 0) end
 end
 U.Text(U.Fit(line,"STALKER.Small",w-px(st and st.ready==false and not st.denied and 440 or 280)),"STALKER.Small",px(12),h-px(24),token)
end
function R.PaintRow(z,w,h,hover)
 local U=STALKER_STYLE
 U.Panel("",0,0,w,h,hover or z.id==R.Selected,z.id==R.Selected)
 local p=LocalPlayer()
 local dist=IsValid(p) and meters(p:GetPos():Distance(Vector(z.pos.x,z.pos.y,z.pos.z))) or ""
 U.Text(U.Fit(z.name,"STALKER.Body",w-px(100)),"STALKER.Body",px(10),px(6),z.enabled~=false and "text" or "muted")
 U.Text(dist,"STALKER.Mono",w-px(10),px(7),"muted",TEXT_ALIGN_RIGHT)
 U.Text(U.Fit(z.id.." · "..R.ZoneSummary(z),"STALKER.Small",w-px(20)),"STALKER.Small",px(10),h-px(21),z.enabled~=false and "warn" or "muted")
end
-- Подсказка формы: фон в центре и на половине радиуса, время до порога лучевой болезни без защиты.
function R.DraftInfo(d)
 d=d or R.Draft
 local rate=tonumber(d.rate) or 0;local half=d.falloff and rate/2 or rate
 local threshold=math.floor(tonumber(R.Config.DamageThreshold) or 30)
 local first=string.format("В центре %.2f ед./с, на половине радиуса %.2f ед./с%s",rate,half,d.falloff and ", у границы 0" or "")
 local second=rate>0 and string.format("Порог %d ед. без защиты — примерно через %d с в центре",threshold,math.ceil(threshold/rate)) or "Зона не облучает"
 return first,second
end
function R.PaintInfo(w,h)
 local U=STALKER_STYLE
 U.Panel("",0,0,w,h,false)
 local a,b=R.DraftInfo()
 U.Text(U.Fit(a,"STALKER.Small",w-px(20)),"STALKER.Small",px(10),px(6),"text")
 U.Text(U.Fit(b,"STALKER.Small",w-px(20)),"STALKER.Small",px(10),px(26),R.Draft.enabled and "warn" or "muted")
end
function R.PaintStatus(w,h)
 local res=R.LastResult;if not res or res.message=="" then return end
 local token=res.ok==true and "ok" or (res.ok==false and "danger" or "muted")
 STALKER_STYLE.Text(STALKER_STYLE.Fit(res.message,"STALKER.Body",w),"STALKER.Body",0,h/2,token,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
end

--[[ Построение панели ]]
-- В окне stalker_rad_menu ПКМ по любому фону панели включает обзор камерой (режим look окна STALKER_STYLE.Window).
function R.StartLook()
 if IsValid(R.Menu) and R.Menu.OnMousePressed then R.Menu:OnMousePressed(MOUSE_RIGHT) end
end
local function lookable(pnl)
 if not pnl then return pnl end
 pnl.OnMousePressed=function(_,code) if code==MOUSE_RIGHT then R.StartLook() end end
 return pnl
end
-- Поле ввода в теме с подсказкой, пока поле пустое (свой Paint темы не рисует placeholder скина).
local function entry(parent,placeholder)
 local U=STALKER_STYLE
 local e=vgui.Create("DTextEntry",parent);U.Entry(e)
 local paint=e.Paint
 e.Paint=function(self,w,h)
  paint(self,w,h)
  if self:GetValue()=="" and not self:HasFocus() then U.Text(U.Fit(placeholder,"STALKER.Body",w-px(12)),"STALKER.Body",px(6),h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
 end
 return e
end
local function slider(parent,label,min,max,decimals,key)
 local U=STALKER_STYLE
 local s=vgui.Create("DNumSlider",parent);s:Dock(TOP);s:SetTall(px(36));s:DockMargin(0,0,0,px(6))
 s:SetText(label);s:SetMin(min);s:SetMax(max);s:SetDecimals(decimals);s:SetValue(R.Draft[key])
 if s.Label then s.Label:SetFont("STALKER.Body");s.Label:SetTextColor(col("text")) end
 if s.TextArea then U.Entry(s.TextArea);s.TextArea:SetWide(px(76)) end
 if s.Slider then
  s.Slider.Paint=function(_,w,h) U.Bar(0,h/2-px(2),w,px(4),(s:GetValue()-min)/(max-min),col("accent")) end
  if s.Slider.Knob then s.Slider.Knob.Paint=function(_,w,h) surface.SetDrawColor(col("accent2"));surface.DrawRect(w/2-px(3),0,px(6),h) end end
 end
 s.OnValueChanged=function(_,val) val=tonumber(val);if val then R.Draft[key]=math.Clamp(val,min,max) end end
 return s
end
local function toggle(parent,key,onText,offText)
 local b=STALKER_STYLE.Button(parent,onText,function() R.Draft[key]=not R.Draft[key] end)
 b:Dock(TOP);b:DockMargin(0,0,0,px(6))
 b.Think=function(self) local on=R.Draft[key]==true;self.Active=on;self.Label=on and onText or offText end
 return b
end
-- Ряд кнопок равной ширины.
local function buttonRow(parent,specs)
 local row=lookable(vgui.Create("DPanel",parent));row:Dock(TOP);row:SetTall(px(32));row:DockMargin(0,0,0,px(6));row.Paint=nil
 local out={}
 for i,spec in ipairs(specs) do
  local b=STALKER_STYLE.Button(row,spec[1],spec[2],spec[3]);b:Dock(LEFT);if i<#specs then b:DockMargin(0,0,px(6),0) end
  out[i]=b
 end
 row.PerformLayout=function(_,w) local bw=math.floor((w-px(6)*(#out-1))/#out);for _,b in ipairs(out) do if IsValid(b) then b:SetWide(bw) end end end
 return unpack(out)
end

-- Полезная нагрузка формы с проверкой на клиенте (окончательно проверяет сервер).
local function draftPayload()
 local d=R.Draft
 local f,err=R.CleanFields({name=d.name,radius=d.radius,rate=d.rate,falloff=d.falloff==true,enabled=d.enabled==true},false)
 if not f then R.SetStatus(false,err);R.RefreshPanel();return end
 return f
end
function R.Create(placement)
 local f=draftPayload();if not f then return end
 f.placement=placement;R.Request("create",f);R.SetStatus(nil,"Создание зоны…");R.RefreshPanel()
end
function R.SaveSelected()
 if not R.Selected then return end
 local f=draftPayload();if not f then return end
 f.id=R.Selected;R.Request("update",f);R.SetStatus(nil,"Сохранение…");R.RefreshPanel()
end
function R.MoveSelected(placement) if R.Selected then R.Request("move",{id=R.Selected,placement=placement}) end end
function R.TeleportSelected() if R.Selected then R.Request("teleport",{id=R.Selected}) end end
function R.RemoveSelected() if R.Selected then R.Request("remove",{id=R.Selected}) end end

function R.BuildAdminPanel(parent)
 local U=STALKER_STYLE
 if not U or not U.Button or not U.Window or not STALKER_THEME then
  local l=vgui.Create("DLabel",parent);l:Dock(TOP);l:SetText("Редактор радиационных зон требует STALKER Core");return l
 end
 local v={}
 local root=lookable(vgui.Create("DPanel",parent));root:Dock(FILL);root.Paint=nil;v.root=root

 local head=lookable(vgui.Create("DPanel",root));head:Dock(TOP);head:SetTall(px(60));head:DockMargin(0,0,0,px(8))
 head.Paint=function(_,w,h) R.PaintHeader(w,h) end
 local refresh=U.Button(head,"Обновить",function() R.Request("list") end);refresh:Dock(RIGHT);refresh:SetWide(px(110));refresh:DockMargin(px(6),px(14),px(10),px(14))
 local fresh=U.Button(head,"Новая зона",function() R.Select(nil) end,"accent");fresh:Dock(RIGHT);fresh:SetWide(px(130));fresh:DockMargin(0,px(14),0,px(14))
 v.fresh=fresh
 local reload=U.Button(head,"Перечитать файл",function() R.Request("reload") end,"danger");reload:Dock(RIGHT);reload:SetWide(px(150));reload:DockMargin(0,px(14),px(6),px(14))
 v.reload=reload

 -- Список зон: слева на широкой вкладке, сверху в узком окне (см. R.LayoutView).
 local side=lookable(vgui.Create("DPanel",root));side:Dock(LEFT);side:SetWide(px(360));side.Paint=nil;v.side=side
 local filter=entry(side,"Поиск по имени или id");filter:Dock(TOP);filter:SetTall(px(30));filter:SetValue(R.Filter or "")
 filter.OnChange=function(self) R.Filter=self:GetValue();R.RefreshList(v) end
 local sort=U.Button(side,"",function() R.SortByDistance=not R.SortByDistance;R.RefreshList(v) end);sort:Dock(TOP);sort:DockMargin(0,px(6),0,px(6))
 sort.Think=function(self) self.Label=R.SortByDistance and "Сортировка: ближние сверху" or "Сортировка: по порядку создания" end
 local list=vgui.Create("DScrollPanel",side);list:Dock(FILL);U.Scroll(list);lookable(list);v.list=list

 -- Форма зоны.
 local form=vgui.Create("DScrollPanel",root);form:Dock(FILL);U.Scroll(form);lookable(form);v.form=form
 local title=lookable(vgui.Create("DPanel",form));title:Dock(TOP);title:SetTall(px(26));title:DockMargin(0,0,0,px(4))
 title.Paint=function(_,w,h)
  local z=R.Selected and R.ZoneByID(R.Selected)
  local text=z and string.format("Зона %s · %.0f %.0f %.0f",z.id,z.pos.x,z.pos.y,z.pos.z) or "Новая зона — по прицелу или под вами"
  U.Text(U.Fit(text,"STALKER.Head",w),"STALKER.Head",0,h/2,"accent",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 U.Label(form,"Имя (видят только администраторы)","STALKER.Small","muted"):Dock(TOP)
 local name=entry(form,"Например: Ржавый тягач");name:Dock(TOP);name:SetTall(px(30));name:DockMargin(0,px(2),0,px(8))
 name.OnChange=function(self) R.Draft.name=self:GetValue() end
 v.name=name
 v.radius=slider(form,"Радиус, units",R.Limits.radiusMin,R.Limits.radiusMax,0,"radius")
 v.rate=slider(form,"Доза в центре, ед./с",R.Limits.rateMin,R.Limits.rateMax,2,"rate")
 toggle(form,"falloff","Спад к краю: фон слабеет к границе","Без спада: фон одинаков по всей зоне")
 toggle(form,"enabled","Зона включена","Зона выключена (не облучает)")
 local info=lookable(vgui.Create("DPanel",form));info:Dock(TOP);info:SetTall(px(48));info:DockMargin(0,0,0,px(8))
 info.Paint=function(_,w,h) R.PaintInfo(w,h) end

 v.createAim,v.createFeet=buttonRow(form,{{"Создать по прицелу",function() R.Create("aim") end,"accent"},{"Создать под собой",function() R.Create("feet") end,"accent"}})
 v.save,v.teleport=buttonRow(form,{{"Сохранить изменения",function() R.SaveSelected() end,"accent"},{"Телепорт к зоне",function() R.TeleportSelected() end}})
 v.moveAim,v.moveFeet=buttonRow(form,{{"Переместить к прицелу",function() R.MoveSelected("aim") end},{"Переместить под себя",function() R.MoveSelected("feet") end}})
 -- Удаление — повторным нажатием в течение 3 секунд.
 v.remove=buttonRow(form,{{"Удалить зону",function(b)
  if (b.ConfirmUntil or 0)<CurTime() then b.ConfirmUntil=CurTime()+3;b.Label="Точно удалить? Нажмите ещё раз";return end
  b.ConfirmUntil=nil;b.Label="Удалить зону";R.RemoveSelected()
 end,"danger"}})
 v.remove.Think=function(self) if self.ConfirmUntil and self.ConfirmUntil<CurTime() then self.ConfirmUntil=nil;self.Label="Удалить зону" end end
 local status=lookable(vgui.Create("DPanel",form));status:Dock(TOP);status:SetTall(px(28));status.Paint=function(_,w,h) R.PaintStatus(w,h) end
 local hint=U.Label(form,"Пока панель открыта, зоны видны в мире кольцами и метками. В окне stalker_rad_menu зажмите ПКМ на фоне окна, чтобы навести прицел.","STALKER.Small","muted")
 hint:Dock(TOP);hint:DockMargin(0,px(6),0,0)

 root.PerformLayout=function(_,w,h) R.LayoutView(v,w,h) end
 root.OnRemove=function() R.Views[v]=nil end
 R.Views[v]=true;R.PanelOpen=true
 R.Request("list")
 R.RefreshView(v)
 return root
end

-- Широкая вкладка: список слева; узкое окно: список сверху.
function R.LayoutView(v,w,h)
 if not IsValid(v.side) then return end
 local wide=w>=px(760)
 if v.wide~=wide then
  v.wide=wide
  if wide then v.side:Dock(LEFT);v.side:DockMargin(0,0,px(10),0) else v.side:Dock(TOP);v.side:DockMargin(0,0,0,px(10)) end
 end
 if wide then local sw=math.floor(w*.4);if v.side:GetWide()~=sw then v.side:SetWide(sw) end
 else local sh=math.floor(h*.34);if v.side:GetTall()~=sh then v.side:SetTall(sh) end end
end

function R.RefreshList(v)
 if not IsValid(v.list) then return end
 v.list:Clear()
 local zones=R.VisibleZones()
 for _,z in ipairs(zones) do
  local row=vgui.Create("DButton",v.list);row:SetText("");row:Dock(TOP);row:SetTall(px(50));row:DockMargin(0,0,px(4),px(4))
  row.Zone=z
  row.Paint=function(self,w,h) R.PaintRow(self.Zone,w,h,self:IsHovered()) end
  row.DoClick=function() surface.PlaySound("buttons/lightswitch2.wav");R.Select(z.id) end
  row.DoDoubleClick=function() R.Select(z.id);R.TeleportSelected() end
  row.DoRightClick=function() R.StartLook() end
 end
 if #zones==0 then
  local empty=STALKER_STYLE.Label(v.list,#R.AdminZones==0 and "Зон на карте нет. Задайте параметры и нажмите «Создать по прицелу»." or "Ничего не найдено","STALKER.Small","muted")
  empty:Dock(TOP);empty:DockMargin(px(4),px(8),px(4),0)
 end
end
function R.UpdateButtons(v)
 local st=R.AdminState
 local ready=st~=nil and st.ready==true and not st.denied
 local selected=R.Selected~=nil and R.ZoneByID(R.Selected)~=nil
 local full=#R.AdminZones>=((st and tonumber(st.limit)) or R.Config.ZonesLimit)
 local function set(b,on) if IsValid(b) then b:SetEnabled(on==true) end end
 set(v.createAim,ready and not full);set(v.createFeet,ready and not full)
 set(v.save,ready and selected);set(v.moveAim,ready and selected);set(v.moveFeet,ready and selected);set(v.remove,ready and selected)
 set(v.teleport,selected and not (st and st.denied))
 if IsValid(v.reload) then v.reload:SetVisible(st~=nil and st.ready==false and not st.denied) end
end
function R.FillForm(v)
 v.formVersion=R.FormVersion
 if IsValid(v.name) then v.name:SetValue(R.Draft.name or "") end
 if IsValid(v.radius) then v.radius:SetValue(R.Draft.radius) end
 if IsValid(v.rate) then v.rate:SetValue(R.Draft.rate) end
end
function R.RefreshView(v)
 R.RefreshList(v)
 if v.formVersion~=R.FormVersion then R.FillForm(v) end
 R.UpdateButtons(v)
end
function R.RefreshPanel()
 for v in pairs(R.Views) do if IsValid(v.root) then R.RefreshView(v) end end
end

-- Закрытие последней панели: сервер перестаёт слать снимки, метки убираются.
hook.Add("Think","STALKER.RadPanelWatch",function()
 if not R.PanelOpen then return end
 for v in pairs(R.Views) do if not IsValid(v.root) then R.Views[v]=nil end end
 if next(R.Views)==nil then R.PanelOpen=false;R.Request("close");R.SyncMarkers() end
end)

-- Отдельное окно у правого края экрана: центр (прицел) остаётся виден, ПКМ по фону — обзор камерой.
function R.OpenMenu()
 if IsValid(R.Menu) then R.Menu:Remove() end
 local U=STALKER_STYLE
 if not U or not U.Window then print("[Radiation] Редактор зон требует STALKER Core");return end
 local f=U.Window({title="☢ Радиационные зоны",w=600,h=820,look=true,onClose=function() R.Menu=nil end})
 f:SetPos(ScrW()-f:GetWide()-px(16),math.max(px(10),(ScrH()-f:GetTall())/2))
 R.BuildAdminPanel(f)
 R.Menu=f
 return f
end
concommand.Add("stalker_rad_menu",function() R.OpenMenu() end)

--[[ Предпросмотр в мире ]]
local RINGS={0,.3,.6,.85}
function R.AimTrace()
 local p=LocalPlayer();if not IsValid(p) then return end
 local tr=p:GetEyeTrace()
 if tr and tr.Hit and not tr.HitSky then return tr end
end
-- Шар зоны: сечения на нескольких высотах, меридианы через точки колец и ось с вершиной.
function R.DrawZone3D(z,eye)
 local center=Vector(z.pos.x,z.pos.y,z.pos.z);local r=z.radius
 local dist=eye:Distance(center)
 if dist>r+8000 then return false end
 local base=zoneColor(z)
 local color=Color(base.r,base.g,base.b,math.Clamp(255-math.max(0,dist-r)/8000*190,60,255))
 local seg=dist<r+1500 and 48 or 24
 local rings={}
 for k,f in ipairs(RINGS) do
  local rr=r*math.sqrt(1-f*f);local pts={}
  for i=0,seg do local a=i/seg*math.pi*2;pts[i]=center+Vector(math.cos(a)*rr,math.sin(a)*rr,r*f) end
  for i=1,seg do render.DrawLine(pts[i-1],pts[i],color,false) end
  rings[k]=pts
 end
 local top=center+Vector(0,0,r)
 for m=0,7 do
  local i=m*seg/8;local prev=rings[1][i]
  for k=2,#rings do render.DrawLine(prev,rings[k][i],color,false);prev=rings[k][i] end
  render.DrawLine(prev,top,color,false)
 end
 render.DrawLine(center,top,color,false)
 return true
end
-- Будущая зона в точке прицела: контур нового радиуса.
function R.DrawAim3D(tr)
 local r=tonumber(R.Draft.radius) or 300;local c=col("accent2");local seg=48
 for _,f in ipairs({0,.5}) do
  local rr=r*math.sqrt(1-f*f);local prev
  for i=0,seg do
   local a=i/seg*math.pi*2;local pt=tr.HitPos+Vector(math.cos(a)*rr,math.sin(a)*rr,r*f)
   if prev then render.DrawLine(prev,pt,c,false) end;prev=pt
  end
 end
 render.DrawLine(tr.HitPos,tr.HitPos+Vector(0,0,r),c,false)
end
hook.Add("PostDrawTranslucentRenderables","STALKER.RadPreview",function(depth,sky)
 if depth or sky or not R.PreviewActive() then return end
 local eye=EyePos();local drawn=0
 for _,z in ipairs(R.AdminZones) do
  if drawn>=48 then break end
  if R.DrawZone3D(z,eye) then drawn=drawn+1 end
 end
 local tr=R.AimTrace();if tr then R.DrawAim3D(tr) end
end)
function R.DrawLabels()
 if not R.PreviewActive() then return end
 local p=LocalPlayer();if not IsValid(p) then return end
 local eye=EyePos();local shadow=col("shadow")
 for _,z in ipairs(R.AdminZones) do
  local center=Vector(z.pos.x,z.pos.y,z.pos.z)
  if eye:DistToSqr(center)<(z.radius+4000)^2 then
   local s=(center+Vector(0,0,math.min(z.radius,200))):ToScreen()
   if s.visible then
    draw.SimpleTextOutlined("☢ "..z.name,"STALKER.Head",s.x,s.y,zoneColor(z),TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,1,shadow)
    draw.SimpleTextOutlined(R.ZoneSummary(z),"STALKER.Mono",s.x,s.y+px(2),col("text"),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,shadow)
   end
  end
 end
 local tr=R.AimTrace()
 if tr then
  local rate=R.RateAt(tr.HitPos,R.AdminZones)
  draw.SimpleTextOutlined(string.format("Фон в точке прицела: %.2f ед./с",rate),"STALKER.Mono",ScrW()/2,ScrH()/2+px(24),rate>0 and col("warn") or col("muted"),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,shadow)
 end
end
hook.Add("HUDPaint","STALKER.RadPreviewLabels",function() R.DrawLabels() end)
