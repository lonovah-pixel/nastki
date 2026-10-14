-- Тема оформления сборки и общий стиль КПК (STALKER_STYLE). Все окна берут цвета из STALKER_THEME.C.
-- Тема игрока: stalker_theme (auto — тема сервера из настройки core.theme).
local C=STALKER_CORE
STALKER_THEME=STALKER_THEME or {}
local T=STALKER_THEME

local function rgb(r,g,b,a) return Color(r,g,b,a or 255) end
-- Токены: bg — фон окна, panel/panel2 — панели, line/lineHi — рамки, text/muted — текст,
-- accent — акцент, ok/warn/danger/info — состояния, track — фон полос, shadow — внутренняя тень.
T.Presets={
 zone={name="Зона — графит и янтарь",bg=rgb(15,17,17),panel=rgb(25,28,28),panel2=rgb(32,36,36),line=rgb(58,64,62),lineHi=rgb(232,142,46),
  text=rgb(226,226,214),muted=rgb(136,144,138),accent=rgb(236,148,48),accent2=rgb(250,196,92),ok=rgb(124,190,96),warn=rgb(232,196,72),
  danger=rgb(220,74,58),info=rgb(96,172,214),track=rgb(10,12,12,240),shadow=rgb(0,0,0,170),highlight=rgb(255,255,255,14)},
 classic={name="Классика — латунь КПК",bg=rgb(28,26,20),panel=rgb(35,39,30),panel2=rgb(42,38,32),line=rgb(91,91,71),lineHi=rgb(191,174,116),
  text=rgb(217,207,176),muted=rgb(138,143,115),accent=rgb(200,169,81),accent2=rgb(222,196,120),ok=rgb(112,158,91),warn=rgb(214,170,64),
  danger=rgb(179,68,48),info=rgb(100,138,145),track=rgb(9,12,8,240),shadow=rgb(8,10,8,220),highlight=rgb(144,139,107,75)},
 pda={name="КПК — зелёный монохром",bg=rgb(7,13,9),panel=rgb(12,22,15),panel2=rgb(16,30,20),line=rgb(40,82,52),lineHi=rgb(120,236,140),
  text=rgb(176,236,176),muted=rgb(92,146,104),accent=rgb(120,236,140),accent2=rgb(196,255,196),ok=rgb(120,236,140),warn=rgb(226,214,96),
  danger=rgb(236,96,80),info=rgb(110,210,200),track=rgb(4,8,5,240),shadow=rgb(0,0,0,180),highlight=rgb(160,255,170,12)},
 frost={name="Чистое Небо — сталь и бирюза",bg=rgb(13,17,22),panel=rgb(21,27,34),panel2=rgb(27,35,44),line=rgb(52,66,80),lineHi=rgb(96,206,214),
  text=rgb(220,230,236),muted=rgb(128,146,160),accent=rgb(96,206,214),accent2=rgb(170,236,240),ok=rgb(116,200,130),warn=rgb(232,200,96),
  danger=rgb(226,86,76),info=rgb(110,160,236),track=rgb(7,10,13,240),shadow=rgb(0,0,0,170),highlight=rgb(200,240,255,14)},
}
T.Order={"zone","classic","pda","frost"}
T.Default="zone"
T.C=T.C or table.Copy(T.Presets.zone)

local cvar=CreateClientConVar("stalker_theme","auto",true,false,"Тема интерфейса: auto, zone, classic, pda, frost")
function T.Resolve()
 local name=cvar:GetString()
 if name=="auto" or not T.Presets[name] then
  local server=C.Settings and C.Settings.Get("core.theme")
  name=T.Presets[server or ""] and server or T.Default
 end
 return name
end
function T.Apply(name)
 name=T.Presets[name] and name or T.Resolve()
 local p=T.Presets[name]
 for k,v in pairs(p) do if type(v)=="table" and v.r then T.C[k]=Color(v.r,v.g,v.b,v.a) end end
 T.Name=name
 hook.Run("STALKER_ThemeChanged",T,name)
end
function T.Color(token,alpha)
 local c=T.C[token] or T.C.text
 if alpha then return Color(c.r,c.g,c.b,alpha) end
 return c
end
cvars.AddChangeCallback("stalker_theme",function() T.Apply() end,"STALKER_Theme")
hook.Add("STALKER_SettingsSynced","STALKER_Theme",function() T.Apply() end)
T.Apply()

--[[ Шрифты интерфейса: масштаб по высоте экрана ]]
T.Scale=1
local function fonts()
 T.Scale=math.Clamp(ScrH()/900,.85,1.7)
 local s=T.Scale
 surface.CreateFont("STALKER.Title",{font="Trebuchet MS",size=math.Round(21*s),weight=700,extended=true})
 surface.CreateFont("STALKER.Head",{font="Tahoma",size=math.Round(16*s),weight=700,extended=true})
 surface.CreateFont("STALKER.Body",{font="Tahoma",size=math.Round(15*s),weight=500,extended=true})
 surface.CreateFont("STALKER.Small",{font="Tahoma",size=math.Round(13*s),weight=500,extended=true})
 surface.CreateFont("STALKER.Mono",{font="Consolas",size=math.Round(13*s),weight=500,extended=true})
 surface.CreateFont("STALKER.Big",{font="Trebuchet MS",size=math.Round(30*s),weight=700,extended=true})
end
fonts();hook.Add("OnScreenSizeChanged","STALKER_Theme.Fonts",fonts)
function T.Px(n) return math.Round(n*T.Scale) end

--[[ Общий стиль КПК. Аргумент prefix оставлен для совместимости со старыми аддонами. ]]
STALKER_STYLE=STALKER_STYLE or {}
local U=STALKER_STYLE
U.Core=true
U.Materials=U.Materials or {}
local gradient=Material("vgui/gradient-d")
local gradientR=Material("vgui/gradient-r")
function U.Texture(path,x,y,w,h,alpha)
 local mat=U.Materials[path];if not mat then mat=Material(path,"smooth");U.Materials[path]=mat end
 if mat:IsError() then return end
 surface.SetMaterial(mat);surface.SetDrawColor(255,255,255,alpha or 255);surface.DrawTexturedRect(x,y,w,h)
end
function U.Panel(prefix,x,y,w,h,active,metal)
 local c=T.C
 surface.SetDrawColor(metal and c.panel2 or c.panel);surface.DrawRect(x,y,w,h)
 surface.SetMaterial(gradient);surface.SetDrawColor(0,0,0,70);surface.DrawTexturedRect(x,y+h*.4,w,h*.6)
 surface.SetDrawColor(c.highlight);surface.DrawRect(x+1,y+1,w-2,1)
 surface.SetDrawColor(active and c.lineHi or c.line);surface.DrawOutlinedRect(x,y,w,h,1)
 surface.SetDrawColor(c.shadow);surface.DrawOutlinedRect(x+1,y+1,w-2,h-2,1)
 if active then
  surface.SetDrawColor(c.accent)
  surface.DrawRect(x,y,math.min(10,w),2);surface.DrawRect(x,y,2,math.min(10,h))
  surface.DrawRect(x+w-math.min(10,w),y+h-2,math.min(10,w),2);surface.DrawRect(x+w-2,y+h-math.min(10,h),2,math.min(10,h))
 end
end
function U.Frame(prefix,w,h)
 local c=T.C
 surface.SetDrawColor(c.bg);surface.DrawRect(0,0,w,h)
 surface.SetMaterial(gradientR);surface.SetDrawColor(c.accent.r,c.accent.g,c.accent.b,10);surface.DrawTexturedRect(0,0,w,h)
 surface.SetDrawColor(c.line);surface.DrawOutlinedRect(0,0,w,h,1)
 surface.SetDrawColor(c.shadow);surface.DrawOutlinedRect(1,1,w-2,h-2,1)
 -- Уголки-скобы в цвете акцента.
 surface.SetDrawColor(c.accent)
 local L=16
 for _,pt in ipairs({{0,0,1,1},{w,0,-1,1},{0,h,1,-1},{w,h,-1,-1}}) do
  local x,y,dx,dy=pt[1],pt[2],pt[3],pt[4]
  surface.DrawRect(dx>0 and x or x-L,dy>0 and y or y-2,L,2)
  surface.DrawRect(dx>0 and x or x-2,dy>0 and y or y-L,2,L)
 end
 surface.SetDrawColor(c.line.r,c.line.g,c.line.b,90);surface.DrawRect(12,42,w-24,1)
end
function U.Bar(x,y,w,h,ratio,col)
 local c=T.C;ratio=math.Clamp(ratio or 0,0,1)
 surface.SetDrawColor(c.track);surface.DrawRect(x,y,w,h)
 surface.SetDrawColor(col or c.accent);surface.DrawRect(x+1,y+1,(w-2)*ratio,h-2)
 surface.SetDrawColor(255,255,255,30);surface.DrawRect(x+1,y+1,(w-2)*ratio,1)
end
function U.Entry(e,prefix)
 local c=T.C
 e:SetFont("STALKER.Body");e:SetTextColor(c.text);e:SetCursorColor(c.text);e:SetHighlightColor(c.accent)
 e.Paint=function(self,w,h) U.Panel(prefix,0,0,w,h,self:HasFocus());self:DrawTextEntryText(T.C.text,T.C.accent,T.C.text) end
end
function U.Combo(cb,prefix,font)
 cb:SetTextColor(Color(0,0,0,0));cb:SetFont(font or "STALKER.Body")
 cb.Paint=function(self,w,h) U.Panel(prefix,0,0,w,h,self:IsHovered());draw.SimpleText(self:GetValue(),font or "STALKER.Body",8,h/2,T.C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
 if IsValid(cb.DropButton) then cb.DropButton.Paint=function(_,w,h) draw.SimpleText("▾",font or "STALKER.Body",w/2,h/2,T.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER) end end
end
function U.Scroll(scroll)
 local bar=scroll:GetVBar();bar:SetWide(8);bar:SetHideButtons(true)
 bar.Paint=function(_,w,h) surface.SetDrawColor(T.C.track);surface.DrawRect(0,0,w,h) end
 bar.btnGrip.Paint=function(_,w,h) surface.SetDrawColor(T.C.line);surface.DrawRect(1,0,w-2,h);surface.SetDrawColor(T.C.accent);surface.DrawRect(1,0,w-2,2) end
end

--[[ Готовые элементы для новых окон ]]
function U.Text(text,font,x,y,token,ax,ay)
 local col=type(token)=="table" and token or T.C[token or "text"] or T.C.text
 draw.SimpleText(text,font or "STALKER.Body",x,y,col,ax or TEXT_ALIGN_LEFT,ay or TEXT_ALIGN_TOP)
end
function U.Fit(text,font,width)
 surface.SetFont(font);text=tostring(text)
 if surface.GetTextSize(text)<=width then return text end
 local n=utf8.len(text) or #text
 for i=n,1,-1 do local s=utf8.sub(text,1,i).."…";if surface.GetTextSize(s)<=width then return s end end
 return "…"
end
function U.Wrap(text,font,width)
 surface.SetFont(font);local lines={};local line=""
 for word in tostring(text):gmatch("%S+") do
  local nextLine=line=="" and word or line.." "..word
  if surface.GetTextSize(nextLine)>width and line~="" then lines[#lines+1]=line;line=word else line=nextLine end
 end
 if line~="" then lines[#lines+1]=line end
 return lines
end
-- Кнопка: kind — nil/"accent"/"danger". Клик со звуком; disabled рисуется приглушённо.
function U.Button(parent,label,onClick,kind)
 local b=vgui.Create("DButton",parent);b:SetText("");b:SetTall(T.Px(30));b.Label=label;b.Kind=kind
 b.Paint=function(self,w,h)
  local hover=self:IsHovered() and self:IsEnabled()
  U.Panel("",0,0,w,h,hover or self.Active)
  if self.Kind=="accent" or self.Kind=="danger" then
   local col=T.C[self.Kind=="danger" and "danger" or "accent"]
   surface.SetDrawColor(col.r,col.g,col.b,hover and 60 or 28);surface.DrawRect(1,1,w-2,h-2)
  end
  draw.SimpleText(U.Fit(self.Label,"STALKER.Body",w-12),"STALKER.Body",w/2,h/2,self:IsEnabled() and T.C.text or T.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
 b.DoClick=function(self) if not self:IsEnabled() then return end;surface.PlaySound("buttons/lightswitch2.wav");if onClick then onClick(self) end end
 return b
end
function U.Label(parent,text,font,token)
 local l=vgui.Create("DLabel",parent);l:SetFont(font or "STALKER.Body");l:SetTextColor(T.C[token or "text"] or T.C.text)
 l:SetText(text or "");l:SetWrap(true);l:SetAutoStretchVertical(true);return l
end
--[[ Окно КПК: заголовок, кнопка закрытия, ПКМ по фону — обзор камерой (opts.look).
 opts: title, w, h, look, onClose. Возвращает окно; содержимое добавляйте в него (DockPadding уже задан). ]]
function U.Window(opts)
 opts=opts or {}
 local f=vgui.Create("EditablePanel")
 f:SetSize(math.min(T.Px(opts.w or 900),ScrW()-20),math.min(T.Px(opts.h or 600),ScrH()-20));f:Center();f:MakePopup()
 f:DockPadding(T.Px(14),T.Px(50),T.Px(14),T.Px(14))
 f.Title=opts.title or ""
 f.Paint=function(self,w,h) U.Frame("",w,h);draw.SimpleText(self.Title,"STALKER.Title",T.Px(18),T.Px(13),T.C.accent) end
 local close=U.Button(f,"×",function() f:Remove() end);close:SetSize(T.Px(32),T.Px(28))
 f.PerformLayout=function(self,w) if IsValid(close) then close:SetPos(w-T.Px(44),T.Px(10)) end end
 f.CloseButton=close
 if opts.look then
  f.OnMousePressed=function(self,code) if code==MOUSE_RIGHT then self.Looking=true;self:SetMouseInputEnabled(false);gui.EnableScreenClicker(false) end end
  f.Think=function(self) if self.Looking and not input.IsMouseDown(MOUSE_RIGHT) then self.Looking=false;self:SetMouseInputEnabled(true);gui.EnableScreenClicker(true) end end
 end
 f.OnRemove=function() gui.EnableScreenClicker(false);if opts.onClose then opts.onClose() end end
 f.OnKeyCodePressed=function(self,key) if key==KEY_ESCAPE then self:Remove() end end
 return f
end
