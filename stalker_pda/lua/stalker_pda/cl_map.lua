-- Карта КПК: подложка карты (STALKER_INV.Config.MapMaterials + MapBounds) или схема с сеткой по меткам и игроку;
-- метки ядра (map~=false) с фильтром по типам, масштаб колесом, перетаскивание, подсказки, своя метка (ЛКМ) с HUD-стрелкой.
local P=STALKER_PDA
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local W=P.UI
local MK=STALKER_MARKERS
local cfg=P.Config
local function px(n) return T.Px(n) end
P.MapHidden=P.MapHidden or {}
P.MapMats=P.MapMats or {}
P.WaypointID="pda.waypoint"

--[[ Границы карты. Форматы: {mins=Vector,maxs=Vector}, {min=…,max=…}, {Vector,Vector}, {x1=,y1=,x2=,y2=}, {minx,miny,maxx,maxy}. ]]
local function xy(v)
 if v==nil then return end
 local ok,x,y=pcall(function() return v.x or v[1],v.y or v[2] end)
 if ok and tonumber(x) and tonumber(y) then return tonumber(x),tonumber(y) end
end
function P.ParseBounds(b)
 if type(b)~="table" then return end
 local x1,y1,x2,y2
 if tonumber(b.x1) then x1,y1,x2,y2=tonumber(b.x1),tonumber(b.y1),tonumber(b.x2),tonumber(b.y2)
 elseif tonumber(b[1]) and tonumber(b[4]) then x1,y1,x2,y2=tonumber(b[1]),tonumber(b[2]),tonumber(b[3]),tonumber(b[4])
 else x1,y1=xy(b.mins or b.min or b[1]);x2,y2=xy(b.maxs or b.max or b[2]) end
 if not (x1 and y1 and x2 and y2) then return end
 local out={minx=math.min(x1,x2),maxx=math.max(x1,x2),miny=math.min(y1,y2),maxy=math.max(y1,y2)}
 if out.maxx-out.minx<1 or out.maxy-out.miny<1 then return end
 return out
end
-- Подложка карты: материал и границы для текущей карты (картинка — вид сверху, север (+Y) вверху).
function P.MapImage()
 local S=STALKER_INV;local conf=S and S.Config
 if type(conf)~="table" or type(conf.MapMaterials)~="table" or type(conf.MapBounds)~="table" then return end
 local map=game.GetMap()
 local path=conf.MapMaterials[map];local bounds=P.ParseBounds(conf.MapBounds[map])
 if type(path)~="string" or not bounds then return end
 local mat=P.MapMats[path]
 if mat==nil then mat=Material(path,"smooth");if mat:IsError() then mat=false end;P.MapMats[path]=mat end
 if not mat then return end
 return mat,bounds
end
-- Метки для карты: всё, что видно игроку (сервер уже отфильтровал), кроме map=false и скрытых типов. Своя метка — отдельно.
function P.MapMarkers(all)
 local out={}
 if not MK or not MK.All then return out end
 for _,m in ipairs(MK.All()) do
  if type(m)=="table" and m.map~=false and m.id~=P.WaypointID and m.pos and (all or not P.MapHidden[m.kind or "poi"]) then out[#out+1]=m end
 end
 return out
end
-- Схема без картинки: квадрат по меткам, игроку и своей метке с запасом.
function P.SchemeBounds(markers)
 local minx,miny,maxx,maxy
 local function add(p) if p then minx=math.min(minx or p.x,p.x);maxx=math.max(maxx or p.x,p.x);miny=math.min(miny or p.y,p.y);maxy=math.max(maxy or p.y,p.y) end end
 local lp=LocalPlayer();if IsValid(lp) then add(lp:GetPos()) end
 for _,m in ipairs(markers or {}) do add(m.pos) end
 add(P.Waypoint)
 if not minx then return {minx=-2000,miny=-2000,maxx=2000,maxy=2000} end
 local cx,cy=(minx+maxx)/2,(miny+maxy)/2
 local half=math.max(maxx-minx,maxy-miny,3000)/2*1.15
 return {minx=cx-half,miny=cy-half,maxx=cx+half,maxy=cy+half}
end
-- Шаг сетки в метрах: ~6–12 линий на видимой ширине.
function P.GridStep(units)
 local meters=C.Meters(units)/8
 for _,s in ipairs({5,10,25,50,100,250,500,1000,2500,5000}) do if s>=meters then return s end end
 return 10000
end

--[[ Своя метка: локальная метка ядра со стрелкой у края экрана; запоминается для карты (cookie). ]]
local function cookieKey() return "stalker_pda_wp_"..game.GetMap() end
function P.SetWaypoint(pos,silent)
 if not pos or not MK or not MK.SetLocal then return end
 P.Waypoint=Vector(pos.x,pos.y,pos.z)
 MK.SetLocal(P.WaypointID,{pos=P.Waypoint,label="Моя метка",kind="beacon",color=T.C.accent2,edge=true,world=false,range=1000000})
 pcall(cookie.Set,cookieKey(),string.format("%.0f %.0f %.0f",pos.x,pos.y,pos.z))
 if not silent then surface.PlaySound("buttons/blip1.wav") end
 hook.Run("STALKER_PDA_Waypoint",P.Waypoint)
end
function P.ClearWaypoint()
 P.Waypoint=nil
 if MK and MK.RemoveLocal then MK.RemoveLocal(P.WaypointID) end
 pcall(cookie.Delete,cookieKey())
 hook.Run("STALKER_PDA_Waypoint",nil)
end
hook.Add("InitPostEntity","STALKER_PDA.Waypoint",function()
 local ok,raw=pcall(cookie.GetString,cookieKey(),"")
 local x,y,z=tostring(ok and raw or ""):match("^(%-?%d+) (%-?%d+) (%-?%d+)$")
 if x then P.SetWaypoint(Vector(tonumber(x),tonumber(y),tonumber(z)),true) end
end)
-- Дошли до своей метки — снимаем её.
timer.Create("STALKER_PDA.Waypoint",.5,0,function()
 local lp=LocalPlayer()
 if not P.Waypoint or not IsValid(lp) or (cfg.WaypointReach or 0)<=0 then return end
 local d=lp:GetPos()-P.Waypoint;d.z=0
 if d:Length()<=cfg.WaypointReach then P.ClearWaypoint();if C.Toast then C.Toast("Вы на месте: своя метка снята.","ok",4) end end
end)

local function diamond(x,y,size,col)
 draw.NoTexture();surface.SetDrawColor(col)
 surface.DrawPoly({{x=x,y=y-size},{x=x+size,y=y},{x=x,y=y+size},{x=x-size,y=y}})
end
local function arrow(x,y,angle,size,col)
 local function rot(dx,dy) return {x=x+dx*math.cos(angle)-dy*math.sin(angle),y=y+dx*math.sin(angle)+dy*math.cos(angle)} end
 draw.NoTexture();surface.SetDrawColor(col)
 surface.DrawPoly({rot(size,0),rot(-size*.7,size*.65),rot(-size*.35,0),rot(-size*.7,-size*.65)})
end
local function meters(units) local m=C.Meters(units);return m<1000 and string.format("%.0f м",m) or string.format("%.1f км",m/1000) end
P.MapMeters=meters

--[[ Панель карты ]]
local PANEL={}
function PANEL:Init() self.Scale=nil;self.CX=0;self.CY=0;self:SetCursor("crosshair") end
function PANEL:CursorLocal()
 local x,y=self:LocalCursorPos()
 if type(x)=="number" and type(y)=="number" then return x,y end
end
function PANEL:ToScreen(x,y,w,h) return w/2+(x-self.CX)*self.Scale,h/2-(y-self.CY)*self.Scale end
function PANEL:ToWorld(sx,sy,w,h) return self.CX+(sx-w/2)/self.Scale,self.CY-(sy-h/2)/self.Scale end
function PANEL:Fit(b,w,h)
 self.CX=(b.minx+b.maxx)/2;self.CY=(b.miny+b.maxy)/2
 self.Scale=math.max(1e-4,math.min(w/(b.maxx-b.minx),h/(b.maxy-b.miny))*.95)
 self.MinScale=self.Scale*.3;self.MaxScale=math.max(self.Scale*30,.5)
 self.Bounds=b
end
function PANEL:CenterOn(pos) if pos and self.Scale then self.CX,self.CY=pos.x,pos.y end end
function PANEL:Reset() self.Scale=nil end
function PANEL:Zoom(delta,mx,my)
 if not self.Scale then return end
 local w,h=self:GetWide(),self:GetTall()
 mx,my=mx or w/2,my or h/2
 local wx,wy=self:ToWorld(mx,my,w,h)
 self.Scale=math.Clamp(self.Scale*(delta>0 and 1.25 or 1/1.25),self.MinScale,self.MaxScale)
 -- Точка под курсором остаётся на месте.
 self.CX=wx-(mx-w/2)/self.Scale;self.CY=wy+(my-h/2)/self.Scale
end
function PANEL:OnMouseWheeled(delta) local mx,my=self:CursorLocal();self:Zoom(delta,mx,my);return true end
function PANEL:OnMousePressed(code)
 local mx,my=self:CursorLocal();if not mx then return end
 if code==MOUSE_LEFT then self.Drag={x=mx,y=my,cx=self.CX,cy=self.CY,moved=false};self:MouseCapture(true)
 elseif code==MOUSE_RIGHT and P.Waypoint then P.ClearWaypoint();surface.PlaySound("buttons/button16.wav") end
end
function PANEL:OnCursorMoved(x,y)
 local d=self.Drag;if not d or not self.Scale or type(x)~="number" then return end
 if not d.moved and math.abs(x-d.x)+math.abs(y-d.y)>4 then d.moved=true;self:SetCursor("sizeall") end
 if d.moved then self.CX=d.cx-(x-d.x)/self.Scale;self.CY=d.cy+(y-d.y)/self.Scale end
end
function PANEL:OnMouseReleased(code)
 if code~=MOUSE_LEFT or not self.Drag then return end
 local d=self.Drag;self.Drag=nil;self:MouseCapture(false);self:SetCursor("crosshair")
 if not d.moved and self.Scale then
  local wx,wy=self:ToWorld(d.x,d.y,self:GetWide(),self:GetTall())
  local lp=LocalPlayer()
  P.SetWaypoint(Vector(wx,wy,IsValid(lp) and lp:GetPos().z or 0))
 end
end
function PANEL:PaintGrid(w,h)
 local c=T.C
 local x0,y1=self:ToWorld(0,0,w,h);local x1,y0=self:ToWorld(w,h,w,h)
 local stepM=P.GridStep(x1-x0);local step=stepM/.01905
 surface.SetDrawColor(c.line.r,c.line.g,c.line.b,70)
 local gx,n=math.floor(x0/step)*step,0
 while gx<=x1 and n<200 do local sx=self:ToScreen(gx,0,w,h);surface.DrawRect(math.floor(sx),0,1,h);gx=gx+step;n=n+1 end
 local gy=math.floor(y0/step)*step;n=0
 while gy<=y1 and n<200 do local _,sy=self:ToScreen(0,gy,w,h);surface.DrawRect(0,math.floor(sy),w,1);gy=gy+step;n=n+1 end
 return stepM
end
function PANEL:Paint(w,h)
 local c=T.C
 surface.SetDrawColor(c.track);surface.DrawRect(0,0,w,h)
 local markers=P.MapMarkers()
 local mat,b=P.MapImage()
 if not self.Scale then self:Fit(b or P.SchemeBounds(P.MapMarkers(true)),w,h) end
 if mat then
  local x1,y1=self:ToScreen(b.minx,b.maxy,w,h);local x2,y2=self:ToScreen(b.maxx,b.miny,w,h)
  surface.SetMaterial(mat);surface.SetDrawColor(255,255,255,240);surface.DrawTexturedRect(x1,y1,x2-x1,y2-y1)
 else self:PaintGrid(w,h) end
 local mx,my=self:CursorLocal()
 local hover,best=nil,px(12)^2
 local labels=#markers<=40
 for _,m in ipairs(markers) do
  local x,y=self:ToScreen(m.pos.x,m.pos.y,w,h)
  if x>-px(40) and x<w+px(40) and y>-px(40) and y<h+px(40) then
   local col=m.color or c.accent
   if tonumber(m.radius) and m.radius>0 then surface.DrawCircle(x,y,m.radius*self.Scale,col.r,col.g,col.b,110) end
   diamond(x,y,px(7),c.shadow);diamond(x,y,px(5),col)
   if labels and m.label then U.Text(U.Fit(m.label,"STALKER.Small",px(160)),"STALKER.Small",x+px(9),y-px(8),col) end
   if mx then local d=(mx-x)^2+(my-y)^2;if d<best then hover,best=m,d end end
  end
 end
 -- Своя метка.
 if P.Waypoint then
  local x,y=self:ToScreen(P.Waypoint.x,P.Waypoint.y,w,h)
  surface.SetDrawColor(c.accent2);surface.DrawRect(x-px(9),y-1,px(18),2);surface.DrawRect(x-1,y-px(9),2,px(18))
  diamond(x,y,px(4),c.accent2);U.Text("Моя метка","STALKER.Small",x+px(10),y+px(2),"accent2")
 end
 -- Игрок: стрелка по направлению взгляда (yaw 0 — восток, +Y — север, экранная ось Y вниз).
 local lp=LocalPlayer()
 if IsValid(lp) then
  local pos=lp:GetPos();local x,y=self:ToScreen(pos.x,pos.y,w,h)
  arrow(x,y,-math.rad(lp:EyeAngles().y),px(10),c.shadow);arrow(x,y,-math.rad(lp:EyeAngles().y),px(8),c.ok)
  if P.Waypoint then
   local wx,wy=self:ToScreen(P.Waypoint.x,P.Waypoint.y,w,h)
   surface.SetDrawColor(c.accent2.r,c.accent2.g,c.accent2.b,90);surface.DrawLine(x,y,wx,wy)
  end
 end
 -- Подсказка при наведении.
 if hover then
  local kind=MK and MK.Kinds and MK.Kinds[hover.kind or "poi"]
  local lines={hover.label or (kind and kind.label) or "Метка",(kind and kind.label or "Метка")..(IsValid(lp) and ("  ·  "..meters(lp:GetPos():Distance(hover.pos))) or "")}
  if hover.expiresAt then lines[#lines+1]="Исчезнет через "..P.Duration(hover.expiresAt-CurTime()) end
  local tw=px(60);surface.SetFont("STALKER.Body")
  for _,l in ipairs(lines) do tw=math.max(tw,(surface.GetTextSize(l))+px(20)) end
  local th=px(10)+#lines*px(18);local tx,ty=math.min(mx+px(14),w-tw-px(4)),math.min(my+px(14),h-th-px(4))
  U.Panel("",tx,ty,tw,th,true)
  for i,l in ipairs(lines) do U.Text(l,i==1 and "STALKER.Body" or "STALKER.Small",tx+px(10),ty+px(5)+(i-1)*px(18),i==1 and "text" or "muted") end
 elseif mx and IsValid(lp) and not self.Drag then
  local wx,wy=self:ToWorld(mx,my,w,h);local p=lp:GetPos()
  U.Text("До курсора: "..meters(math.sqrt((wx-p.x)^2+(wy-p.y)^2)),"STALKER.Small",w-px(10),h-px(22),"muted",TEXT_ALIGN_RIGHT)
 end
 -- Масштабная линейка и север.
 local unitsPer=px(100)/self.Scale
 U.Text(meters(unitsPer),"STALKER.Small",px(12),h-px(34),"text")
 surface.SetDrawColor(c.text);surface.DrawRect(px(12),h-px(14),px(100),2);surface.DrawRect(px(12),h-px(20),2,px(8));surface.DrawRect(px(110),h-px(20),2,px(8))
 U.Text("С ▲","STALKER.Small",w-px(12),px(8),"muted",TEXT_ALIGN_RIGHT)
 if not mat then U.Text("Схема: подложка карты не задана","STALKER.Small",px(12),px(8),"muted") end
 surface.SetDrawColor(c.line);surface.DrawOutlinedRect(0,0,w,h,1)
end
vgui.Register("STALKER_PDAMap",PANEL,"DPanel")

--[[ Легенда: типы меток с переключателями (фильтр), количество на карте ]]
local function legendRow(parent,kind,def)
 local b=vgui.Create("DButton",parent);b:Dock(TOP);b:SetTall(px(28));b:DockMargin(0,0,0,px(2));b:SetText("");b.Kind=kind;b.Def=def
 b.Paint=function(self,w,h)
  local hidden=P.MapHidden[self.Kind]==true
  if self:IsHovered() then surface.SetDrawColor(T.C.highlight);surface.DrawRect(0,0,w,h) end
  diamond(px(12),h/2,px(5),hidden and T.C.muted or (self.Def.color or T.C.accent))
  U.Text(U.Fit(self.Def.label or self.Kind,"STALKER.Small",w-px(64)),"STALKER.Small",px(26),h/2,hidden and "muted" or "text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  U.Text(hidden and "скрыто" or tostring(self.Count or 0),"STALKER.Mono",w-px(6),h/2,"muted",TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
 end
 b.Think=function(self)
  if (self.Next or 0)>CurTime() then return end
  self.Next=CurTime()+.5;local n=0
  for _,m in ipairs(P.MapMarkers(true)) do if (m.kind or "poi")==self.Kind then n=n+1 end end
  self.Count=n
 end
 b.DoClick=function(self) P.MapHidden[self.Kind]=not P.MapHidden[self.Kind] or nil;surface.PlaySound("buttons/lightswitch2.wav") end
 return b
end
P.AddTab("map",{title="Карта",order=20,build=function(parent)
 local side=vgui.Create("DPanel",parent);side:Dock(RIGHT);side:SetWide(px(230));side:DockMargin(px(10),0,0,0);side:DockPadding(px(8),px(30),px(8),px(8))
 side.Paint=function(_,w,h) U.Panel("",0,0,w,h,false);U.Text("ЛЕГЕНДА И ФИЛЬТР","STALKER.Small",px(10),px(9),"muted") end
 local map=vgui.Create("STALKER_PDAMap",parent);map:Dock(FILL)
 parent.Map=map
 local kinds={}
 for kind,def in pairs(MK and MK.Kinds or {}) do kinds[#kinds+1]={kind,def} end
 table.sort(kinds,function(a,b) return tostring(a[2].label or a[1])<tostring(b[2].label or b[1]) end)
 for _,k in ipairs(kinds) do legendRow(side,k[1],k[2]) end
 local tools=W.Blank(side,BOTTOM);tools:SetTall(px(200))
 local help=U.Label(tools,"ЛКМ — поставить свою метку, ПКМ — убрать её. Колесо — масштаб, перетаскивание — сдвиг.","STALKER.Small","muted")
 help:Dock(BOTTOM);help:DockMargin(0,px(6),0,0)
 local function button(label,fn,kind) local b=U.Button(tools,label,fn,kind);b:Dock(TOP);b:DockMargin(0,0,0,px(4));return b end
 button("Центр на мне",function() local lp=LocalPlayer();if IsValid(lp) then map:CenterOn(lp:GetPos()) end end,"accent")
 button("Показать всю карту",function() map:Reset() end)
 button("Показать все метки",function() P.MapHidden={} end)
 local clear=button("Убрать свою метку",function() P.ClearWaypoint() end,"danger")
 clear.Think=function(self) self:SetEnabled(P.Waypoint~=nil) end
end})
