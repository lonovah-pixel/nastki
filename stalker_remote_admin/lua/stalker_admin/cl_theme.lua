-- Оформление «Коменданта»: цвета — токены общей темы (STALKER_THEME.C), элементы — STALKER_STYLE.
-- Старые имена цветов панели (raised, edge, red, green) сопоставлены токенам темы, поэтому смена темы
-- игроком (stalker_theme) сразу перекрашивает окно.
local A=STALKER_ADMIN
local alias={raised="panel2",edge="line",red="danger",green="ok"}
-- Резерв на случай запуска без ядра сборки: панель должна открыться и без stalker_core.
local fallback={bg={15,17,17},panel={25,28,28},panel2={32,36,36},line={58,64,62},lineHi={232,142,46},text={226,226,214},muted={136,144,138},
 accent={236,148,48},accent2={250,196,92},ok={124,190,96},warn={232,196,72},danger={220,74,58},info={96,172,214},track={10,12,12,240},shadow={0,0,0,170},highlight={255,255,255,14}}
local cache={}
A.C=setmetatable({},{__index=function(_,key)
 key=alias[key] or key
 local T=STALKER_THEME;local c=T and T.C and T.C[key]
 if c then return c end
 local f=fallback[key] or fallback.text
 cache[key]=cache[key] or Color(f[1],f[2],f[3],f[4] or 255)
 return cache[key]
end})
function A.Color(token,alpha) local c=A.C[token];return Color(c.r,c.g,c.b,alpha or c.a) end

-- Шрифты ядра (масштабируются под экран); без ядра — свои с теми же ролями.
A.F={title="STALKER.Title",head="STALKER.Head",body="STALKER.Body",small="STALKER.Small",mono="STALKER.Mono",big="STALKER.Big"}
if not STALKER_THEME then
 surface.CreateFont("STA.Title",{font="Trebuchet MS",size=24,weight=800,extended=true})
 surface.CreateFont("STA.Head",{font="Tahoma",size=17,weight=700,extended=true})
 surface.CreateFont("STA.Body",{font="Tahoma",size=16,weight=500,extended=true})
 surface.CreateFont("STA.Small",{font="Tahoma",size=13,weight=500,extended=true})
 surface.CreateFont("STA.Mono",{font="Consolas",size=14,weight=500,extended=true})
 A.F={title="STA.Title",head="STA.Head",body="STA.Body",small="STA.Small",mono="STA.Mono",big="STA.Title"}
end
function A.Px(n) return STALKER_THEME and STALKER_THEME.Px and STALKER_THEME.Px(n) or n end
local function U() return STALKER_STYLE end

-- Фон панели: STALKER_STYLE.Panel или простой прямоугольник.
function A.PaintBox(x,y,w,h,active,metal)
 local style=U()
 if style and style.Panel then style.Panel("",x,y,w,h,active,metal);return end
 surface.SetDrawColor(metal and A.C.panel2 or A.C.panel);surface.DrawRect(x,y,w,h)
 surface.SetDrawColor(active and A.C.lineHi or A.C.line);surface.DrawOutlinedRect(x,y,w,h)
end
function A.Fit(text,font,width)
 local style=U();if style and style.Fit then return style.Fit(text,font,width) end
 return tostring(text)
end
function A.Panel(parent,dock)
 local p=vgui.Create("DPanel",parent);p:Dock(dock or FILL);p:DockPadding(A.Px(10),A.Px(10),A.Px(10),A.Px(10))
 p.Paint=function(_,w,h) A.PaintBox(0,0,w,h,false,false) end
 return p
end
function A.Label(parent,text,height,color)
 local p=vgui.Create("DLabel",parent);p:Dock(TOP);p:SetTall(A.Px(height or 26));p:SetFont(A.F.body)
 p:SetTextColor(color or A.C.text);p:SetText(text);p:SetWrap(true);return p
end
-- Кнопка списка (текст слева, полоса-акцент у выбранной). kind: nil/"accent"/"danger".
function A.Button(parent,text,fn,kind)
 local p=vgui.Create("DButton",parent);p:Dock(TOP);p:DockMargin(0,0,0,A.Px(5));p:SetTall(A.Px(32));p:SetText("");p.Label=text;p.Kind=kind
 p.Paint=function(self,w,h)
  local hover=self:IsHovered() and self:IsEnabled()
  A.PaintBox(0,0,w,h,hover or self.Active,self.Active)
  if self.Kind then local c=A.C[self.Kind=="danger" and "danger" or "accent"];surface.SetDrawColor(c.r,c.g,c.b,hover and 60 or 26);surface.DrawRect(1,1,w-2,h-2) end
  if self.Active then surface.SetDrawColor(A.C.accent);surface.DrawRect(0,0,A.Px(3),h) end
  local col=(not self:IsEnabled() or self.Dim) and A.C.muted or self.Active and A.C.accent or A.C.text
  draw.SimpleText(A.Fit(self.Label,A.F.body,w-A.Px(18)),A.F.body,self.Center and w/2 or A.Px(10),h/2,col,self.Center and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 p.DoClick=function(self) if not self:IsEnabled() then return end;surface.PlaySound("buttons/lightswitch2.wav");fn(self) end;return p
end
function A.StyleEntry(e)
 local style=U()
 if style and style.Entry then style.Entry(e,"");e:SetFont(A.F.mono);return e end
 e:SetFont(A.F.mono);e:SetTextColor(A.C.text);e:SetCursorColor(A.C.accent)
 e.Paint=function(self,w,h) A.PaintBox(0,0,w,h,self:HasFocus());self:DrawTextEntryText(A.C.text,A.C.accent,A.C.text) end
 return e
end
function A.Entry(parent,label,default)
 if label then A.Label(parent,label,22,A.C.muted) end
 local e=vgui.Create("DTextEntry",parent);e:Dock(TOP);e:DockMargin(0,0,0,A.Px(8));e:SetTall(A.Px(32));e:SetText(default or "")
 return A.StyleEntry(e)
end
function A.StyleCombo(c)
 local style=U()
 if style and style.Combo then style.Combo(c,"",A.F.body) else c:SetFont(A.F.body) end
 return c
end
function A.Combo(parent,label,values)
 if label then A.Label(parent,label,22,A.C.muted) end
 local c=vgui.Create("DComboBox",parent);c:Dock(TOP);c:DockMargin(0,0,0,A.Px(8));c:SetTall(A.Px(32));c:SetValue("Выберите…")
 for _,v in ipairs(values or {}) do c:AddChoice(v.name==v.id and v.id or (v.name.." / "..v.id),v.id) end
 c.OnSelect=function(_,_,_,value) c.Value=value end
 return A.StyleCombo(c)
end
function A.Scroll(parent)
 local s=vgui.Create("DScrollPanel",parent);s:Dock(FILL)
 local style=U();if style and style.Scroll then style.Scroll(s) end
 return s
end
-- Заголовок раздела: акцентная подпись и линия.
function A.Header(parent,text,height)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(A.Px(height or 30));p:DockMargin(0,0,0,A.Px(4))
 p.Paint=function(_,w,h)
  draw.SimpleText(text,A.F.head,0,h/2,A.C.accent,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  surface.SetDrawColor(A.C.line);surface.DrawRect(0,h-1,w,1)
 end
 return p
end
-- Окно сообщения в теме сборки (вместо Derma_Message/Derma_Query). buttons: {{подпись, функция, kind}};
-- onClose(win) вызывается при любом закрытии; win.Answered=true, если нажата одна из кнопок.
function A.Message(title,text,buttons,onClose)
 local style=U()
 buttons=buttons or {{"Закрыть"}}
 if not style or not style.Window then
  if #buttons>=2 then Derma_Query(text,title,buttons[1][1],buttons[1][2] or function() end,buttons[2][1],buttons[2][2] or function() end)
  else Derma_Message(text,title,buttons[1][1]) end
  return
 end
 local w
 w=style.Window({title=title,w=560,h=380,onClose=function() if onClose then onClose(w) end end})
 local body=vgui.Create("DLabel",w);body:Dock(FILL);body:SetFont(A.F.body);body:SetTextColor(A.C.text);body:SetText(text);body:SetWrap(true);body:SetContentAlignment(7)
 local bar=vgui.Create("DPanel",w);bar:Dock(BOTTOM);bar:SetTall(A.Px(36));bar.Paint=nil
 for i,b in ipairs(buttons) do
  local btn=style.Button(bar,b[1],function() w.Answered=true;if b[2] then b[2]() end;if IsValid(w) then w:Remove() end end,b[3] or (i==1 and "accent" or nil))
  btn:Dock(RIGHT);btn:SetWide(A.Px(160));btn:DockMargin(A.Px(8),0,0,0)
 end
 return w
end
