-- Редактор Зоны: поля аномалий, логова мутантов, быстрые действия. Открытие: !zone или stz_editor.
-- Удерживайте ПКМ на фоне окна, чтобы повернуть камеру и прицелиться в точку размещения.
local Z=STALKER_ZONE
Z.EditorState=Z.EditorState or {fields={},zones={},stats={},ready=true}
local C={bg=Color(22,24,19),panel=Color(35,39,30),text=Color(217,207,176),muted=Color(138,143,115),accent=Color(200,169,81),green=Color(112,158,91),red=Color(179,68,48)}
surface.CreateFont("STZ.EdTitle",{font="Trebuchet MS",size=20,weight=700,extended=true})
surface.CreateFont("STZ.EdBody",{font="Tahoma",size=14,weight=500,extended=true})
surface.CreateFont("STZ.EdSmall",{font="Tahoma",size=12,weight=500,extended=true})

local function box(x,y,w,h,active)
 if STALKER_STYLE and STALKER_STYLE.Panel then return STALKER_STYLE.Panel("stalker_inv",x,y,w,h,active) end
 surface.SetDrawColor(C.panel);surface.DrawRect(x,y,w,h);surface.SetDrawColor(active and C.accent or Color(91,91,71));surface.DrawOutlinedRect(x,y,w,h,1)
end
local function button(parent,label,click,tall)
 local b=vgui.Create("DButton",parent);b:SetText("");b:SetTall(tall or 28);b.Label=label
 b.Paint=function(self,w,h) box(0,0,w,h,self:IsHovered() or self.Active);draw.SimpleText(self.Label,"STZ.EdBody",w/2,h/2,self:IsEnabled() and C.text or C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER) end
 b.DoClick=function() surface.PlaySound("buttons/lightswitch2.wav");click() end
 return b
end
local function label(parent,text)
 local l=vgui.Create("DLabel",parent);l:Dock(TOP);l:SetTall(20);l:SetFont("STZ.EdSmall");l:SetTextColor(C.muted);l:SetText(text);return l
end
local function slider(parent,title,min,max,value)
 local s=vgui.Create("DNumSlider",parent);s:Dock(TOP);s:SetTall(32);s:SetText(title);s:SetMin(min);s:SetMax(max);s:SetDecimals(0);s:SetValue(value)
 s.Label:SetTextColor(C.text);s.Label:SetFont("STZ.EdSmall");s.TextArea:SetTextColor(C.text);return s
end

local function send(a)
 local raw=util.TableToJSON(a);if not raw or #raw>1000 then notification.AddLegacy("Слишком длинный запрос",NOTIFY_ERROR,4);return end
 net.Start("stz.action");net.WriteUInt(#raw,16);net.WriteData(raw,#raw);net.SendToServer()
end
local function request(open) net.Start("stz.request");net.WriteBool(open);net.SendToServer() end

net.Receive("stz.state",function()
 local size=net.ReadUInt(16);local raw=util.Decompress(net.ReadData(size) or "")
 local state=raw and util.JSONToTable(raw);if type(state)~="table" then return end
 Z.EditorState=state
 if IsValid(Z.Editor) then Z.Editor:Rebuild(state.reply and state.reply.ok and state.reply.id) end
end)

local PANEL={}
function PANEL:Init()
 self:SetSize(math.min(940,ScrW()-40),math.min(620,ScrH()-40));self:Center();self:MakePopup()
 self:DockPadding(14,46,14,14);self.Kind="field";self.Selected=nil
 local close=button(self,"×",function() self:Remove() end);close:SetSize(30,28);close:SetPos(self:GetWide()-44,10)
 self.List=vgui.Create("DScrollPanel",self);self.List:Dock(LEFT);self.List:SetWide(300);self.List:DockMargin(0,0,12,0)
 self.Form=vgui.Create("DScrollPanel",self);self.Form:Dock(FILL)
 self.Footer=vgui.Create("DPanel",self);self.Footer:Dock(BOTTOM);self.Footer:SetTall(72);self.Footer:DockMargin(0,10,0,0);self.Footer.Paint=nil
 self:BuildFooter();self:Rebuild();request(true)
end
function PANEL:Paint(w,h)
 if STALKER_STYLE and STALKER_STYLE.Frame then STALKER_STYLE.Frame("stalker_inv",w,h) else surface.SetDrawColor(C.bg);surface.DrawRect(0,0,w,h) end
 draw.SimpleText("РЕДАКТОР ЗОНЫ / "..game.GetMap(),"STZ.EdTitle",18,14,C.accent)
 local s=Z.EditorState.stats or {}
 draw.SimpleText(string.format("аномалий %d · артефактов %d / %d · ПКМ на фоне — обзор",s.anomalies or 0,s.artifacts or 0,s.maxArtifacts or 0),"STZ.EdSmall",w-60,20,C.muted,TEXT_ALIGN_RIGHT)
end
function PANEL:OnMousePressed(code)
 if code==MOUSE_RIGHT then self.Looking=true;self:SetMouseInputEnabled(false);gui.EnableScreenClicker(false) end
end
function PANEL:Think()
 if self.Looking and not input.IsMouseDown(MOUSE_RIGHT) then self.Looking=false;self:SetMouseInputEnabled(true);gui.EnableScreenClicker(true) end
end
function PANEL:OnRemove() gui.EnableScreenClicker(false);request(false) end

function PANEL:BuildFooter()
 local row=vgui.Create("DPanel",self.Footer);row:Dock(TOP);row:SetTall(30);row.Paint=nil
 local actions={
  {"Перестроить все поля",function() send({op="regen",kind="field"}) end},
  {"Досыпать артефакты",function() send({op="artifacts",kind="field"}) end},
  {"Перезапустить логова",function() send({op="regen",kind="zone"}) end},
  {"Пополнить склады",function() RunConsoleCommand("stz_restock") end},
 }
 for _,a in ipairs(actions) do local b=button(row,a[1],a[2]);b:Dock(LEFT);b:SetWide(196);b:DockMargin(0,0,8,0) end
 local rad=vgui.Create("DPanel",self.Footer);rad:Dock(TOP);rad:SetTall(30);rad:DockMargin(0,8,0,0);rad.Paint=nil
 local r=vgui.Create("DNumberWang",rad);r:Dock(LEFT);r:SetWide(70);r:SetMinMax(32,5000);r:SetValue(300)
 local i=vgui.Create("DNumberWang",rad);i:Dock(LEFT);i:SetWide(60);i:DockMargin(6,0,0,0);i:SetMinMax(1,100);i:SetDecimals(1);i:SetValue(2)
 local b=button(rad,"Радиационная зона под прицелом (радиус / доза в сек.)",function() RunConsoleCommand("stalker_rad_add",tostring(math.Round(r:GetValue())),tostring(i:GetValue())) end)
 b:Dock(LEFT);b:SetWide(420);b:DockMargin(8,0,0,0)
 local list=button(rad,"Список зон в консоль",function() RunConsoleCommand("stalker_rad_list") end);list:Dock(LEFT);list:SetWide(190);list:DockMargin(8,0,0,0)
end

function PANEL:Rebuild(selectID)
 local state=Z.EditorState
 if selectID then self.Selected=selectID end
 self.List:Clear()
 local function header(text) local l=vgui.Create("DLabel",self.List);l:Dock(TOP);l:SetTall(24);l:SetFont("STZ.EdBody");l:SetTextColor(C.accent);l:SetText(text) end
 local function add(kind,row)
  local caption=row.name..(kind=="field" and string.format("  [%d/%d · арт. %d]",row.liveAnomalies or 0,row.count,row.liveArtifacts or 0) or string.format("  [%d/%d]",row.liveMutants or 0,row.max))
  local b=button(self.List,caption,function() self.Kind=kind;self.Selected=row.id;self:Rebuild() end);b:Dock(TOP);b:DockMargin(0,0,0,4)
  b.Active=self.Selected==row.id
 end
 header("ПОЛЯ АНОМАЛИЙ ("..#(state.fields or {})..")")
 for _,row in ipairs(state.fields or {}) do add("field",row) end
 header("ЛОГОВА МУТАНТОВ ("..#(state.zones or {})..")")
 for _,row in ipairs(state.zones or {}) do add("zone",row) end
 local new=button(self.List,"+ Новое поле аномалий",function() self.Kind="field";self.Selected=nil;self:Rebuild() end);new:Dock(TOP);new:DockMargin(0,10,0,4)
 local newZone=button(self.List,"+ Новое логово мутантов",function() self.Kind="zone";self.Selected=nil;self:Rebuild() end);newZone:Dock(TOP)
 self:BuildForm()
end

function PANEL:Current()
 local list=self.Kind=="field" and Z.EditorState.fields or Z.EditorState.zones
 for _,row in ipairs(list or {}) do if row.id==self.Selected then return row end end
end

function PANEL:BuildForm()
 local f=self.Form;f:Clear()
 local row=self:Current();local field=self.Kind=="field"
 if not row then self.Selected=nil end
 local title=vgui.Create("DLabel",f);title:Dock(TOP);title:SetTall(28);title:SetFont("STZ.EdTitle");title:SetTextColor(C.text)
 title:SetText(row and ((field and "Поле: " or "Логово: ")..row.name) or (field and "Новое поле аномалий" or "Новое логово мутантов"))
 if not Z.EditorState.ready then label(f,"Файл Зоны повреждён — изменения заблокированы.") end
 label(f,"Название")
 local name=vgui.Create("DTextEntry",f);name:Dock(TOP);name:SetTall(28);name:SetValue(row and row.name or (field and "Аномальное поле" or "Логово"))
 if STALKER_STYLE and STALKER_STYLE.Entry then STALKER_STYLE.Entry(name,"stalker_inv") end
 local radius=slider(f,"Радиус, units",field and 150 or 100,field and 4000 or 3000,row and row.radius or (field and 700 or 600))
 local a,b
 if field then
  a=slider(f,"Количество аномалий",1,40,row and row.count or 8)
  b=slider(f,"Артефактов одновременно",0,15,row and row.artifacts or 3)
 else
  a=slider(f,"Мутантов одновременно",1,16,row and row.max or 4)
  b=slider(f,"Интервал появления, сек.",10,3600,row and row.respawn or 120)
 end
 label(f,field and "Типы аномалий" or "Виды мутантов")
 local checks={}
 local order=field and Z.AnomalyOrder or Z.MutantOrder;local catalog=field and Z.Anomalies or Z.Mutants
 local grid=vgui.Create("DIconLayout",f);grid:Dock(TOP);grid:SetSpaceX(8);grid:SetSpaceY(4)
 for _,key in ipairs(order) do
  local c=grid:Add("DCheckBoxLabel");c:SetSize(190,22);c:SetText(catalog[key].name..(field and "" or (" ("..catalog[key].class..")")));c:SetTextColor(C.text)
  c:SetValue(row and row.types[key] and 1 or (not row and key==order[1] and 1 or 0));checks[key]=c
 end
 grid:SetTall(math.ceil(#order/2)*26)
 local function payload()
  local types={};for key,c in pairs(checks) do if c:GetChecked() then types[key]=true end end
  local p={kind=self.Kind,name=name:GetValue(),radius=math.Round(radius:GetValue()),types=types}
  if field then p.count=math.Round(a:GetValue());p.artifacts=math.Round(b:GetValue()) else p.max=math.Round(a:GetValue());p.respawn=math.Round(b:GetValue()) end
  return p
 end
 local actions=vgui.Create("DIconLayout",f);actions:Dock(TOP);actions:DockMargin(0,10,0,0);actions:SetSpaceX(8);actions:SetSpaceY(8)
 local function act(text,fn) local bt=button(actions,text,fn);bt:SetSize(250,30);actions:Add(bt) end
 if row then
  act("Сохранить параметры",function() local p=payload();p.op="update";p.id=row.id;send(p) end)
  act("Переместить под прицел",function() send({op="move",kind=self.Kind,id=row.id,placement="aim"}) end)
  act("Переместить под себя",function() send({op="move",kind=self.Kind,id=row.id,placement="feet"}) end)
  act(field and "Перестроить поле" or "Перезапустить логово",function() send({op="regen",kind=self.Kind,id=row.id}) end)
  act("Телепорт к центру",function() send({op="goto",kind=self.Kind,id=row.id}) end)
  act("Удалить",function()
   Derma_Query("Удалить «"..row.name.."»?","Редактор Зоны","Удалить",function() send({op="delete",kind=self.Kind,id=row.id});self.Selected=nil end,"Отмена")
  end)
 else
  act("Создать под прицелом",function() local p=payload();p.op="create";p.placement="aim";send(p) end)
  act("Создать под собой",function() local p=payload();p.op="create";p.placement="feet";send(p) end)
 end
 actions:SetTall(110)
 local hint=label(f,field and "Аномалии и артефакты перестраиваются после каждого выброса." or "Мутанты не появляются ближе 700 units к игрокам.")
 hint:DockMargin(0,8,0,0)
end
vgui.Register("STALKERZoneEditor",PANEL,"EditablePanel")

concommand.Add("stz_editor",function()
 if IsValid(Z.Editor) then Z.Editor:Remove();return end
 Z.Editor=vgui.Create("STALKERZoneEditor")
end)

-- Предпросмотр: границы полей (бронза) и логов (красный) видны, пока открыт редактор.
hook.Add("PostDrawTranslucentRenderables","STALKER_ZONE.EditorPreview",function(depth,sky)
 if sky or not IsValid(Z.Editor) then return end
 local function ring(pos,radius,color)
  for i=0,47 do
   local a,b=i*math.pi/24,(i+1)*math.pi/24
   render.DrawLine(pos+Vector(math.cos(a)*radius,math.sin(a)*radius,8),pos+Vector(math.cos(b)*radius,math.sin(b)*radius,8),color,true)
  end
  render.DrawLine(pos,pos+Vector(0,0,96),color,true)
 end
 for _,row in ipairs(Z.EditorState.fields or {}) do ring(Vector(row.pos.x,row.pos.y,row.pos.z),row.radius,row.id==Z.Editor.Selected and C.green or C.accent) end
 for _,row in ipairs(Z.EditorState.zones or {}) do ring(Vector(row.pos.x,row.pos.y,row.pos.z),row.radius,row.id==Z.Editor.Selected and C.green or C.red) end
end)
hook.Add("HUDPaint","STALKER_ZONE.EditorLabels",function()
 if not IsValid(Z.Editor) then return end
 for _,list in ipairs({Z.EditorState.fields or {},Z.EditorState.zones or {}}) do
  for _,row in ipairs(list) do
   local s=Vector(row.pos.x,row.pos.y,row.pos.z+100):ToScreen()
   if s.visible then draw.SimpleText(row.name,"STZ.EdBody",s.x,s.y,C.text,TEXT_ALIGN_CENTER) end
  end
 end
end)
