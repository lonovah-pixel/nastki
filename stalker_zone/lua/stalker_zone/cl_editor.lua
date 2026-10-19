-- Редактор Зоны: поля аномалий, логова мутантов, быстрые действия. Открытие: !zone или stz_editor.
-- Окно STALKER_STYLE.Window: удерживайте ПКМ на фоне окна, чтобы повернуть камеру и прицелиться в точку.
-- Здесь же общий для редактора и панели «Коменданта» канал stz.* и отладка радиусов аномалий (stz_anomaly_debug).
local Z=STALKER_ZONE
Z.EditorState=Z.EditorState or {fields={},zones={},stats={},ready=true}
Z.Views=Z.Views or {}

local function px(n) local T=STALKER_THEME;return T and T.Px and T.Px(n) or math.Round(n) end
local function col(token,alpha)
 local T=STALKER_THEME;if T and T.Color then return T.Color(token,alpha) end
 return Color(255,255,255,alpha or 255)
end
Z.Px,Z.Col=px,col

--[[ Сеть ]]
function Z.EditorSend(a)
 local raw=util.TableToJSON(a)
 if not raw or #raw>1000 then
  local C=STALKER_CORE;if C and C.Toast then C.Toast("Слишком длинный запрос","danger",4) end
  return false
 end
 net.Start("stz.action");net.WriteUInt(#raw,16);net.WriteData(raw,#raw);net.SendToServer()
 return true
end
function Z.EditorRequest(open) net.Start("stz.request");net.WriteBool(open==true);net.SendToServer() end

net.Receive("stz.state",function()
 local size=net.ReadUInt(16);if type(size)~="number" or size<1 then return end
 local raw=util.Decompress(net.ReadData(size) or "")
 local state=raw and util.JSONToTable(raw);if type(state)~="table" then return end
 state.fields=type(state.fields)=="table" and state.fields or {}
 state.zones=type(state.zones)=="table" and state.zones or {}
 state.stats=type(state.stats)=="table" and state.stats or {}
 Z.EditorState=state
 local reply=type(state.reply)=="table" and state.reply or nil
 if reply and reply.message then Z.LastReply={ok=reply.ok==true,text=tostring(reply.message),at=CurTime()} end
 if IsValid(Z.Editor) and Z.Editor.Rebuild then Z.Editor:Rebuild(reply and reply.ok and reply.id) end
 if Z.RefreshAdminViews then Z.RefreshAdminViews() end
end)

-- Открытые окна и панели Зоны: пока есть хоть одно, сервер присылает снимки после каждой правки.
function Z.TrackView(pnl) Z.Views[pnl]=true;Z.ViewsOpen=true;Z.EditorRequest(true) end
hook.Add("Think","STALKER_ZONE.Views",function()
 if not Z.ViewsOpen then return end
 for v in pairs(Z.Views) do if not IsValid(v) then Z.Views[v]=nil end end
 if next(Z.Views)==nil then Z.ViewsOpen=false;Z.EditorRequest(false) end
end)

--[[ Общие элементы ]]
function Z.EntrySummary(kind,row)
 if kind=="field" then
  return string.format("аномалий %d/%d · артефактов %d/%d · R %d",row.liveAnomalies or 0,row.count or 0,row.liveArtifacts or 0,row.artifacts or 0,row.radius or 0)
 end
 return string.format("мутантов %d/%d · раз в %d с · R %d",row.liveMutants or 0,row.max or 0,row.respawn or 0,row.radius or 0)
end
function Z.EntryDistance(row)
 local lp=LocalPlayer()
 if not IsValid(lp) or type(row.pos)~="table" then return "" end
 return string.format("%.0f м",lp:GetPos():Distance(Vector(row.pos.x or 0,row.pos.y or 0,row.pos.z or 0))*.01905)
end
function Z.PaintEntryRow(kind,row,w,h,active,right)
 local U=STALKER_STYLE
 U.Panel("",0,0,w,h,active,active)
 local reserve=right or 0
 U.Text(U.Fit(row.name or "?","STALKER.Body",w-px(90)-reserve),"STALKER.Body",px(10),px(5),"text")
 U.Text(Z.EntryDistance(row),"STALKER.Mono",w-px(10)-reserve,px(6),"muted",TEXT_ALIGN_RIGHT)
 U.Text(U.Fit(Z.EntrySummary(kind,row),"STALKER.Small",w-px(20)-reserve),"STALKER.Small",px(10),h-px(21),kind=="field" and "info" or "warn")
end
function Z.PaintReply(w,h)
 local r=Z.LastReply;if not r or r.text=="" then return end
 local U=STALKER_STYLE
 U.Text(U.Fit(r.text,"STALKER.Body",w),"STALKER.Body",0,h/2,r.ok and "ok" or "danger",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
end
-- Кнопка с подтверждением: первое нажатие спрашивает, второе в течение 3 с выполняет.
function Z.ConfirmButton(parent,label,fn,kind)
 local U=STALKER_STYLE
 local b=U.Button(parent,label,function(self)
  if (tonumber(self.ConfirmUntil) or 0)<CurTime() then self.ConfirmUntil=CurTime()+3;self.Label="Точно? Нажмите ещё раз";return end
  self.ConfirmUntil=nil;self.Label=label;fn()
 end,kind or "danger")
 b.Think=function(self) local t=tonumber(self.ConfirmUntil);if t and t<CurTime() then self.ConfirmUntil=nil;self.Label=label end end
 return b
end
-- Ряд кнопок равной ширины: specs={{подпись,функция,вид|nil,подтверждать}}.
function Z.ButtonRow(parent,specs,tall)
 local U=STALKER_STYLE
 local row=vgui.Create("DPanel",parent);row:Dock(TOP);row:SetTall(tall or px(32));row:DockMargin(0,0,0,px(6));row.Paint=nil
 local out={}
 for i,spec in ipairs(specs) do
  local b=spec[4] and Z.ConfirmButton(row,spec[1],spec[2],spec[3]) or U.Button(row,spec[1],spec[2],spec[3])
  b:Dock(LEFT);if i<#specs then b:DockMargin(0,0,px(6),0) end
  out[i]=b
 end
 row.PerformLayout=function(_,w) local bw=math.floor((w-px(6)*(#out-1))/math.max(1,#out));for _,b in ipairs(out) do if IsValid(b) then b:SetWide(bw) end end end
 row.Buttons=out
 return row,out
end
local function slider(parent,label,min,max,value)
 local U=STALKER_STYLE
 local s=vgui.Create("DNumSlider",parent);s:Dock(TOP);s:SetTall(px(34));s:DockMargin(0,0,0,px(4))
 s:SetText(label);s:SetMin(min);s:SetMax(max);s:SetDecimals(0);s:SetValue(value)
 if s.Label then s.Label:SetFont("STALKER.Body");s.Label:SetTextColor(col("text")) end
 if s.TextArea then U.Entry(s.TextArea);s.TextArea:SetWide(px(70)) end
 if s.Slider then
  s.Slider.Paint=function(_,w,h) U.Bar(0,h/2-px(2),w,px(4),((tonumber(s:GetValue()) or min)-min)/math.max(1,max-min),col("accent")) end
  if s.Slider.Knob then s.Slider.Knob.Paint=function(_,w,h) surface.SetDrawColor(col("accent2"));surface.DrawRect(w/2-px(3),0,px(6),h) end end
 end
 return s
end

--[[ Окно редактора ]]
local E={}
local function lookable(pnl,frame)
 local function press(_,code) if code==MOUSE_RIGHT and frame.OnMousePressed then frame:OnMousePressed(code) end end
 pnl.OnMousePressed=press
 local canvas=pnl.GetCanvas and pnl:GetCanvas()
 if canvas then canvas.OnMousePressed=press end
end

function Z.OpenEditor()
 local U=STALKER_STYLE
 if not U or not U.Window or not STALKER_THEME then print("[STALKER Zone] Редактор Зоны требует STALKER Core");return end
 if IsValid(Z.Editor) then Z.Editor:Remove() end
 local f
 f=U.Window({title="Редактор Зоны · "..game.GetMap(),w=1000,h=680,look=true,onClose=function() if Z.Editor==f then Z.Editor=nil end end})
 for k,v in pairs(E) do f[k]=v end
 f.Kind="field";f.Selected=nil
 local paint=f.Paint
 f.Paint=function(self,w,h) paint(self,w,h);self:PaintStats(w,h) end
 f.Footer=vgui.Create("DPanel",f);f.Footer:Dock(BOTTOM);f.Footer:SetTall(px(78));f.Footer:DockMargin(0,px(10),0,0);f.Footer.Paint=nil
 f.List=vgui.Create("DScrollPanel",f);f.List:Dock(LEFT);f.List:SetWide(px(330));f.List:DockMargin(0,0,px(12),0);U.Scroll(f.List)
 f.Form=vgui.Create("DScrollPanel",f);f.Form:Dock(FILL);U.Scroll(f.Form)
 lookable(f.List,f);lookable(f.Form,f);lookable(f.Footer,f)
 Z.Editor=f;Z.TrackView(f)
 f:BuildFooter();f:Rebuild()
 return f
end

function E:PaintStats(w,h)
 local U=STALKER_STYLE;local s=Z.EditorState.stats or {}
 local text=string.format("аномалий %d · артефактов %d/%d · мутантов %d/%d · ПКМ на фоне — обзор",s.anomalies or 0,s.artifacts or 0,s.maxArtifacts or 0,s.mutants or 0,s.maxMutants or 0)
 U.Text(U.Fit(text,"STALKER.Small",w*.55),"STALKER.Small",w-px(56),px(18),"muted",TEXT_ALIGN_RIGHT)
end

function E:BuildFooter()
 local U=STALKER_STYLE
 Z.ButtonRow(self.Footer,{
  {"Перестроить все поля",function() Z.EditorSend({op="regen",kind="field"}) end},
  {"Досыпать артефакты",function() Z.EditorSend({op="artifacts",kind="field"}) end},
  {"Перезапустить логова",function() Z.EditorSend({op="regen",kind="zone"}) end},
  {"Пополнить склады",function() Z.EditorSend({op="restock"}) end},
  {"Убрать мутантов",function() Z.EditorSend({op="mutants_clear"}) end,"danger",true},
 })
 local row=vgui.Create("DPanel",self.Footer);row:Dock(TOP);row:SetTall(px(32));row.Paint=nil
 -- Радиационные зоны редактирует аддон радиации: своё окно со списком, формой и предпросмотром.
 local rad=U.Button(row,"Радиационные зоны",function() RunConsoleCommand("stalker_rad_menu") end)
 rad:Dock(LEFT);rad:SetWide(px(220));rad:DockMargin(0,0,px(6),0)
 rad:SetEnabled(STALKER_RAD~=nil and STALKER_RAD.OpenMenu~=nil)
 local refresh=U.Button(row,"Обновить",function() Z.EditorRequest(true) end);refresh:Dock(LEFT);refresh:SetWide(px(140));refresh:DockMargin(0,0,px(10),0)
 local status=vgui.Create("DPanel",row);status:Dock(FILL);status.Paint=function(_,w,h) Z.PaintReply(w,h) end
 self.RadButton=rad
end

function E:Current()
 local list=self.Kind=="field" and Z.EditorState.fields or Z.EditorState.zones
 for _,row in ipairs(list or {}) do if row.id==self.Selected then return row end end
end

function E:AddRow(kind,row)
 local b=vgui.Create("DButton",self.List);b:SetText("");b:Dock(TOP);b:SetTall(px(46));b:DockMargin(0,0,px(4),px(4))
 b.Row=row;b.Kind=kind
 b.Paint=function(btn,w,h) Z.PaintEntryRow(btn.Kind,btn.Row,w,h,btn:IsHovered() or self.Selected==btn.Row.id) end
 b.DoClick=function() surface.PlaySound("buttons/lightswitch2.wav");self.Kind=kind;self.Selected=row.id;self:Rebuild() end
 b.DoDoubleClick=function() Z.EditorSend({op="goto",kind=kind,id=row.id}) end
 b.DoRightClick=function() if self.OnMousePressed then self:OnMousePressed(MOUSE_RIGHT) end end
 return b
end

function E:Rebuild(selectID)
 local U=STALKER_STYLE;local state=Z.EditorState
 if selectID then self.Selected=selectID end
 self.List:Clear()
 local function header(text) local l=U.Label(self.List,text,"STALKER.Head","accent");l:Dock(TOP);l:DockMargin(0,px(4),0,px(4)) end
 header("ПОЛЯ АНОМАЛИЙ ("..#(state.fields or {})..")")
 for _,row in ipairs(state.fields or {}) do self:AddRow("field",row) end
 header("ЛОГОВА МУТАНТОВ ("..#(state.zones or {})..")")
 for _,row in ipairs(state.zones or {}) do self:AddRow("zone",row) end
 local new=U.Button(self.List,"+ Новое поле аномалий",function() self.Kind="field";self.Selected=nil;self:Rebuild() end,"accent");new:Dock(TOP);new:DockMargin(0,px(10),px(4),px(4))
 local newZone=U.Button(self.List,"+ Новое логово мутантов",function() self.Kind="zone";self.Selected=nil;self:Rebuild() end,"accent");newZone:Dock(TOP);newZone:DockMargin(0,0,px(4),0)
 self:BuildForm()
end

function E:BuildForm()
 local U=STALKER_STYLE;local f=self.Form;f:Clear()
 local row=self:Current();local field=self.Kind=="field"
 if not row then self.Selected=nil end
 local title=U.Label(f,row and ((field and "Поле: " or "Логово: ")..row.name) or (field and "Новое поле аномалий" or "Новое логово мутантов"),"STALKER.Title","accent")
 title:Dock(TOP);title:DockMargin(0,0,0,px(6))
 if not Z.EditorState.ready then
  local warn=U.Label(f,"Файл Зоны повреждён — изменения заблокированы. Подробности: stz_status в консоли.","STALKER.Small","danger");warn:Dock(TOP);warn:DockMargin(0,0,0,px(6))
 end
 U.Label(f,"Название (видят только администраторы; на карте КПК — «"..(field and "Аномальное поле" or "Логово мутантов").."»)","STALKER.Small","muted"):Dock(TOP)
 local name=vgui.Create("DTextEntry",f);name:Dock(TOP);name:SetTall(px(30));name:DockMargin(0,px(2),0,px(8));U.Entry(name)
 name:SetValue(row and row.name or (field and "Аномальное поле" or "Логово"))
 local radius=slider(f,"Радиус, units",field and 150 or 100,field and 4000 or 3000,row and row.radius or (field and 700 or 600))
 local a,b
 if field then
  a=slider(f,"Количество аномалий",1,40,row and row.count or 8)
  b=slider(f,"Артефактов одновременно",0,15,row and row.artifacts or 3)
 else
  a=slider(f,"Мутантов одновременно",1,16,row and row.max or 4)
  b=slider(f,"Интервал появления, с",10,3600,row and row.respawn or 120)
 end
 U.Label(f,field and "Типы аномалий" or "Виды мутантов","STALKER.Small","muted"):Dock(TOP)
 local order=field and Z.AnomalyOrder or Z.MutantOrder;local catalog=field and Z.Anomalies or Z.Mutants
 local chosen={}
 local grid=vgui.Create("DIconLayout",f);grid:Dock(TOP);grid:SetSpaceX(px(6));grid:SetSpaceY(px(6));grid:DockMargin(0,px(4),0,px(8))
 for _,key in ipairs(order) do
  chosen[key]=row and type(row.types)=="table" and row.types[key]==true or (not row and key==order[1]) or false
  local t=U.Button(grid,catalog[key].name..(field and "" or (" · "..catalog[key].class)),function(btn) chosen[key]=not chosen[key];btn.Active=chosen[key] end)
  t:SetSize(px(field and 150 or 230),px(28));t.Active=chosen[key]
 end
 grid:SetTall(math.ceil(#order/(field and 3 or 2))*px(34))
 local function payload()
  local types={};for key,on in pairs(chosen) do if on then types[key]=true end end
  local p={kind=self.Kind,name=name:GetValue(),radius=math.Round(radius:GetValue()),types=types}
  if field then p.count=math.Round(a:GetValue());p.artifacts=math.Round(b:GetValue()) else p.max=math.Round(a:GetValue());p.respawn=math.Round(b:GetValue()) end
  return p
 end
 local actions=vgui.Create("DIconLayout",f);actions:Dock(TOP);actions:DockMargin(0,px(4),0,0);actions:SetSpaceX(px(8));actions:SetSpaceY(px(8))
 local function act(text,fn,kind,confirm)
  local bt=confirm and Z.ConfirmButton(actions,text,fn,kind) or U.Button(actions,text,fn,kind)
  bt:SetSize(px(250),px(30));return bt
 end
 if row then
  act("Сохранить параметры",function() local p=payload();p.op="update";p.id=row.id;Z.EditorSend(p) end,"accent")
  act("Переместить к прицелу",function() Z.EditorSend({op="move",kind=self.Kind,id=row.id,placement="aim"}) end)
  act("Переместить под себя",function() Z.EditorSend({op="move",kind=self.Kind,id=row.id,placement="feet"}) end)
  act(field and "Перестроить поле" or "Перезапустить логово",function() Z.EditorSend({op="regen",kind=self.Kind,id=row.id}) end)
  act("Телепорт к центру",function() Z.EditorSend({op="goto",kind=self.Kind,id=row.id}) end)
  act("Удалить",function() Z.EditorSend({op="delete",kind=self.Kind,id=row.id});self.Selected=nil end,"danger",true)
 else
  act("Создать под прицелом",function() local p=payload();p.op="create";p.placement="aim";Z.EditorSend(p) end,"accent")
  act("Создать под собой",function() local p=payload();p.op="create";p.placement="feet";Z.EditorSend(p) end,"accent")
 end
 actions:SetTall(px(row and 114 or 38))
 local hint=U.Label(f,field and "Аномалии и артефакты перестраиваются после каждого выброса. Двойной щелчок по записи — телепорт."
  or ("Мутанты не появляются ближе "..tostring(Z.Config.MutantSafeRadius).." units к игрокам. Двойной щелчок по записи — телепорт."),"STALKER.Small","muted")
 hint:Dock(TOP);hint:DockMargin(0,px(10),0,0)
end

concommand.Add("stz_editor",function()
 if IsValid(Z.Editor) then Z.Editor:Remove();Z.Editor=nil;return end
 Z.OpenEditor()
end)

--[[ Предпросмотр: границы полей (акцент) и логов (опасность) видны, пока открыт редактор. ]]
local function ring(pos,radius,color,segments)
 segments=segments or 48
 local step=math.pi*2/segments
 for i=0,segments-1 do
  local a,b=i*step,(i+1)*step
  render.DrawLine(pos+Vector(math.cos(a)*radius,math.sin(a)*radius,8),pos+Vector(math.cos(b)*radius,math.sin(b)*radius,8),color,true)
 end
end
function Z.DrawEditorPreview()
 local ed=Z.Editor
 for _,row in ipairs(Z.EditorState.fields or {}) do
  local pos=Vector(row.pos.x,row.pos.y,row.pos.z)
  local c=row.id==(ed and ed.Selected) and col("ok") or col("accent")
  ring(pos,row.radius,c);render.DrawLine(pos,pos+Vector(0,0,96),c,true)
 end
 for _,row in ipairs(Z.EditorState.zones or {}) do
  local pos=Vector(row.pos.x,row.pos.y,row.pos.z)
  local c=row.id==(ed and ed.Selected) and col("ok") or col("danger")
  ring(pos,row.radius,c);render.DrawLine(pos,pos+Vector(0,0,96),c,true)
 end
end
function Z.DrawEditorLabels()
 for _,list in ipairs({Z.EditorState.fields or {},Z.EditorState.zones or {}}) do
  for _,row in ipairs(list) do
   local s=Vector(row.pos.x,row.pos.y,row.pos.z+100):ToScreen()
   if s.visible then draw.SimpleTextOutlined(row.name,"STALKER.Body",s.x,s.y,col("text"),TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,1,col("shadow")) end
  end
 end
end
hook.Add("PostDrawTranslucentRenderables","STALKER_ZONE.EditorPreview",function(depth,sky)
 if sky or not IsValid(Z.Editor) then return end
 Z.DrawEditorPreview()
end)
hook.Add("HUDPaint","STALKER_ZONE.EditorLabels",function()
 if not IsValid(Z.Editor) then return end
 Z.DrawEditorLabels()
end)

--[[ Отладка аномалий для администраторов: stz_anomaly_debug 1 — кольца радиусов и параметры над аномалиями. ]]
local debugCvar=CreateClientConVar("stz_anomaly_debug","0",false,false,"Администраторам: показывать радиусы и параметры аномалий (1 — вкл.)")
function Z.AnomalyDebugAllowed()
 local lp=LocalPlayer()
 if not debugCvar:GetBool() or not IsValid(lp) then return false end
 if lp:IsAdmin() then return true end
 local C=STALKER_CORE
 return C and C.CanAdmin and C.CanAdmin(lp,"zone")==true or false
end
local function nearAnomalies(range)
 local out={};local eye=EyePos()
 for _,e in ipairs(ents.FindByClass("stalker_anomaly")) do
  local cfg=IsValid(e) and e.Config and e:Config()
  if cfg and e:GetPos():DistToSqr(eye)<range*range then out[#out+1]={ent=e,cfg=cfg} end
 end
 return out
end
function Z.DrawAnomalyDebug()
 if not Z.AnomalyDebugAllowed() then return end
 for _,a in ipairs(nearAnomalies(3000)) do
  local pos=a.ent:GetPos();local cfg=a.cfg
  local c=cfg.color or col("warn")
  ring(pos,cfg.radius or 0,Color(c.r,c.g,c.b,255),32)
  if cfg.pull and cfg.pull>(cfg.radius or 0) then ring(pos,cfg.pull,col("muted"),32) end
 end
end
function Z.AnomalyDebugText(cfg,ent)
 local scale=tonumber(Z.Config.AnomalyDamageScale) or 1
 local parts={cfg.name or "?","R "..tostring(cfg.radius),"урон "..tostring(math.Round((cfg.damage or 0)*scale,1))}
 if cfg.interval then parts[#parts+1]="такт "..cfg.interval.." с" else parts[#parts+1]="перезарядка "..tostring(cfg.cooldown or 0).." с" end
 if cfg.pull then parts[#parts+1]="затягивание "..cfg.pull end
 local since=ent and ent.GetTriggered and (CurTime()-(tonumber(ent:GetTriggered()) or 0))
 return table.concat(parts," · "),since and since<30 and string.format("сработала %.1f с назад",since) or "покой"
end
function Z.DrawAnomalyDebugLabels()
 if not Z.AnomalyDebugAllowed() then return end
 for _,a in ipairs(nearAnomalies(1500)) do
  local s=(a.ent:GetPos()+Vector(0,0,70)):ToScreen()
  if s.visible then
   local line,state=Z.AnomalyDebugText(a.cfg,a.ent)
   draw.SimpleTextOutlined(line,"STALKER.Small",s.x,s.y,col("warn"),TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,1,col("shadow"))
   draw.SimpleTextOutlined(state,"STALKER.Mono",s.x,s.y+px(2),col("muted"),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,col("shadow"))
  end
 end
end
hook.Add("PostDrawTranslucentRenderables","STALKER_ZONE.AnomalyDebug",function(depth,sky) if not sky then Z.DrawAnomalyDebug() end end)
hook.Add("HUDPaint","STALKER_ZONE.AnomalyDebug",function() Z.DrawAnomalyDebugLabels() end)
