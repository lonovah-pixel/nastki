-- Окно КПК: вертикальные вкладки слева (свои — первыми, затем вкладки других аддонов из STALKER_CORE.PDATabList),
-- F4 / !pda / !кпк / stalker_pda. Вкладка строится заново при каждом переключении в контейнере на всю ширину (Dock FILL).
local P=STALKER_PDA
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local cfg=P.Config
local function px(n) return T.Px(n) end

--[[ Набор элементов вкладок (общий для всех файлов аддона) ]]
local W=P.UI or {}
P.UI=W
function W.Scroll(parent) local s=vgui.Create("DScrollPanel",parent);s:Dock(FILL);U.Scroll(s);return s end
function W.Head(parent,text) local l=U.Label(parent,text,"STALKER.Head","accent");l:Dock(TOP);l:DockMargin(0,px(6),0,px(6));return l end
function W.Text(parent,text,token,font) local l=U.Label(parent,text,font or "STALKER.Body",token or "text");l:Dock(TOP);l:DockMargin(0,0,0,px(6));return l end
function W.Blank(parent,dock) local p=vgui.Create("DPanel",parent);p:Dock(dock or FILL);p.Paint=function() end;return p end
function W.Card(parent,h,paint)
 local c=vgui.Create("DPanel",parent);c:Dock(TOP);c:SetTall(px(h));c:DockMargin(0,0,0,px(8))
 c.Paint=function(self,w,hh) U.Panel("",0,0,w,hh,self.Active==true);if paint then paint(self,w,hh) end end
 return c
end
function W.Button(parent,label,fn,kind) local b=U.Button(parent,label,fn,kind);b:Dock(TOP);b:DockMargin(0,0,0,px(6));return b end
--[[ Карточка с переносом текста: высота подбирается по ширине (PerformLayout). opts: head, headToken, right, rightToken, text,
 font, color (полоса слева), token (цвет текста) ]]
function W.TextCard(parent,opts)
 local c=vgui.Create("DPanel",parent);c:Dock(TOP);c:DockMargin(0,0,0,px(6));c.Opts=opts;c.Lines={};c:SetTall(px(48))
 c.PerformLayout=function(self,w)
  local o=self.Opts;local font=o.font or "STALKER.Body"
  self.Lines=U.Wrap(o.text or "",font,w-px(28))
  surface.SetFont(font);local _,lh=surface.GetTextSize("Ag");self.LineH=lh+px(2)
  local tall=px(12)+(o.head and px(20) or 0)+#self.Lines*self.LineH
  if self:GetTall()~=tall then self:SetTall(tall) end
 end
 c.Paint=function(self,w,h)
  local o=self.Opts
  U.Panel("",0,0,w,h,false)
  if o.color then surface.SetDrawColor(o.color);surface.DrawRect(0,0,px(3),h) end
  local y=px(6)
  if o.head then
   U.Text(o.head,"STALKER.Small",px(14),y,o.headToken or "muted")
   if o.right then U.Text(o.right,"STALKER.Mono",w-px(10),y,o.rightToken or "muted",TEXT_ALIGN_RIGHT) end
   y=y+px(20)
  end
  for i,line in ipairs(self.Lines) do U.Text(line,o.font or "STALKER.Body",px(14),y+(i-1)*(self.LineH or px(16)),o.token or "text") end
 end
 return c
end

--[[ Форматирование ]]
function P.Money(n)
 n=math.floor(tonumber(n) or 0)
 if DarkRP and DarkRP.formatMoney then return DarkRP.formatMoney(n) end
 return string.Comma(n).." ₽"
end
function P.Clock(t) return os.date("%H:%M",tonumber(t) or os.time()) end
function P.Ago(t)
 t=tonumber(t) or 0;local d=os.time()-t
 if d<60 then return "только что" end
 if d<3600 then return math.floor(d/60).." мин назад" end
 if d<86400 and os.date("%d",t)==os.date("%d") then return "сегодня "..os.date("%H:%M",t) end
 return os.date("%d.%m %H:%M",t)
end
function P.Duration(sec)
 sec=math.max(0,math.floor(tonumber(sec) or 0))
 if sec<60 then return sec.." с" end
 if sec<3600 then return math.floor(sec/60).." мин "..(sec%60).." с" end
 return math.floor(sec/3600).." ч "..math.floor(sec%3600/60).." мин"
end
-- Значок на вкладке/в списке: число или короткая строка.
function P.DrawBadge(value,x,y,align)
 local text=tostring(value);if tonumber(value) and tonumber(value)>99 then text="99+" end
 surface.SetFont("STALKER.Small");local tw,th=surface.GetTextSize(text)
 local bw,bh=math.max(px(20),tw+px(10)),th+px(4)
 if align==TEXT_ALIGN_RIGHT then x=x-bw end
 draw.RoundedBox(math.floor(bh/2),x,y-bh/2,bw,bh,T.C.danger)
 draw.SimpleText(text,"STALKER.Small",x+bw/2,y,T.C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 return bw
end

--[[ Вкладки. Свои вкладки — P.AddTab(id, {title, order, build(parent), badge(), visible()}); чужие — STALKER_CORE.RegisterPDATab. ]]
P.Builtin=P.Builtin or {}
function P.AddTab(id,def)
 assert(type(id)=="string" and type(def)=="table" and type(def.build)=="function","P.AddTab: нужен id и build")
 def.id=id;def.order=def.order or 50;def.title=def.title or id;def.builtin=true
 P.Builtin[id]=def
 if P.IsOpen() then P.BuildNav() end
end
local function shown(def)
 if not def.visible then return true end
 local ok,v=pcall(def.visible);return not ok or v~=false
end
function P.TabList()
 local list={}
 for _,def in pairs(P.Builtin) do if shown(def) then list[#list+1]=def end end
 table.sort(list,function(a,b) if a.order~=b.order then return a.order<b.order end;return a.id<b.id end)
 if C.PDATabList then
  local ok,ext=pcall(C.PDATabList)
  for _,def in ipairs(ok and type(ext)=="table" and ext or {}) do
   if type(def)=="table" and type(def.id)=="string" and not P.Builtin[def.id] and type(def.build)=="function" then list[#list+1]=def end
  end
 end
 return list
end
function P.FindTab(id) for _,def in ipairs(P.TabList()) do if def.id==id then return def end end end
function P.Badge(def)
 if type(def)~="table" or type(def.badge)~="function" then return end
 local ok,v=pcall(def.badge)
 if ok and ((type(v)=="number" and v>0) or (type(v)=="string" and v~="")) then return v end
end

-- Клавиша F4 (бинд gm_showspare2) закрывает открытое окно: при открытом окне бинды не срабатывают.
function P.ToggleKey()
 local name=input.LookupBinding("gm_showspare2",true)
 local code=type(name)=="string" and isfunction(input.GetKeyCode) and input.GetKeyCode(name)
 if type(code)=="number" and code>0 then return code end
 return rawget(_G,"KEY_F4") or 95
end

function P.IsOpen() return P.Frame~=nil and IsValid(P.Frame) end
function P.Close() if P.IsOpen() then P.Frame:Remove() end;P.Frame=nil;P.Body=nil;P.Content=nil;P.NavList=nil end
function P.Toggle(tab) if P.IsOpen() then P.Close() else P.Open(tab) end end

local function navPaint(self,w,h)
 local active=P.Current==self.Def.id
 U.Panel("",0,0,w,h,active or self:IsHovered())
 if active then surface.SetDrawColor(T.C.accent);surface.DrawRect(0,px(4),px(3),h-px(8)) end
 local badge=P.Badge(self.Def)
 U.Text(U.Fit(self.Def.title,"STALKER.Body",w-px(badge and 56 or 24)),"STALKER.Body",px(14),h/2,active and "accent" or "text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 if badge then P.DrawBadge(badge,w-px(8),h/2,TEXT_ALIGN_RIGHT) end
end
function P.BuildNav()
 local nav=P.NavList;if not nav then return end
 nav:Clear()
 local external=false
 for _,def in ipairs(P.TabList()) do
  if not def.builtin and not external then
   external=true
   local l=U.Label(nav,"МОДУЛИ","STALKER.Small","muted");l:Dock(TOP);l:DockMargin(px(6),px(8),0,px(4))
  end
  local b=vgui.Create("DButton",nav);b:Dock(TOP);b:SetTall(px(38));b:DockMargin(0,0,0,px(4));b:SetText("");b.Def=def
  b.Paint=navPaint
  b.DoClick=function(self) surface.PlaySound("buttons/lightswitch2.wav");P.Select(self.Def.id) end
 end
end

-- Обновление открытой вкладки по событию (inbox, thread, news, stats…): вкладка кладёт обработчики в parent.PDARefresh.
function P.Refresh(kind,...)
 -- P.Content сбрасывается при закрытии окна и заменяется при переключении, поэтому здесь он всегда живой.
 local c=P.Content;if not c then return end
 local fn=type(c.PDARefresh)=="table" and c.PDARefresh[kind]
 if type(fn)=="function" then
  local ok,err=xpcall(fn,debug.traceback,...)
  if not ok then P.LastError={tab=P.Current,error=err};ErrorNoHalt("[STALKER PDA] обновление "..tostring(kind)..": "..tostring(err).."\n") end
 end
end

function P.Select(id)
 if not P.Body then return end
 local def=P.FindTab(id) or P.TabList()[1];if not def then return end
 if P.Content and IsValid(P.Content) then P.Content:Remove() end
 local content=W.Blank(P.Body,FILL)
 P.Content=content;P.Current=def.id;P.LastTab=def.id
 local ok,err=xpcall(def.build,debug.traceback,content)
 if not ok then
  P.LastError={tab=def.id,error=err}
  ErrorNoHalt("[STALKER PDA] вкладка «"..tostring(def.title).."»: "..tostring(err).."\n")
  W.Text(content,"Вкладка «"..tostring(def.title).."» не загрузилась. Подробности — в консоли.","danger")
 end
 hook.Run("STALKER_PDA_TabSelected",def.id,content)
 return content
end

function P.Open(tab)
 if not U or not U.Window then return end
 if P.IsOpen() then if tab then P.Select(tab) end;P.Frame:MoveToFront();return P.Frame end
 local f=U.Window({title="КПК",w=1120,h=720,onClose=function()
  P.Frame=nil;P.Body=nil;P.Content=nil;P.NavList=nil;hook.Run("STALKER_PDA_Closed")
 end})
 P.Frame=f
 local basePaint,baseKey=f.Paint,f.OnKeyCodePressed
 f.Paint=function(self,w,h)
  if basePaint then basePaint(self,w,h) end
  local lp=LocalPlayer()
  local info="СЕТЬ: "..#player.GetAll().." В СЕТИ   ·   "..os.date("%H:%M")
  if IsValid(lp) then info=U.Fit(lp:Nick(),"STALKER.Small",px(220)).."   ·   "..info end
  U.Text(info,"STALKER.Small",w-px(56),px(18),"muted",TEXT_ALIGN_RIGHT)
 end
 f.OnKeyCodePressed=function(self,key)
  if key==P.ToggleKey() and cfg.F4Key then self:Remove();return true end
  if baseKey then return baseKey(self,key) end
 end
 -- Без сознания (после выброса) КПК недоступен.
 f.Think=function(self) if C.Unconscious and C.Unconscious(LocalPlayer()) then self:Remove() end end
 local side=vgui.Create("DPanel",f);side:Dock(LEFT);side:SetWide(px(214));side:DockMargin(0,0,px(10),0)
 side:DockPadding(px(6),px(6),px(6),px(6))
 side.Paint=function(_,w,h) U.Panel("",0,0,w,h,false) end
 local foot=vgui.Create("DPanel",side);foot:Dock(BOTTOM);foot:SetTall(px(40))
 foot.Paint=function(_,w,h)
  surface.SetDrawColor(T.C.line);surface.DrawRect(0,0,w,1)
  U.Text("F4 — закрыть   ·   !кпк","STALKER.Small",w/2,h/2,"muted",TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
 local nav=W.Scroll(side);P.NavList=nav
 P.Body=W.Blank(f,FILL)
 P.BuildNav()
 P.Select(tab or P.LastTab or "summary")
 hook.Run("STALKER_PDA_Opened",f)
 return f
end
C.PDAOpen=function(tab) return P.Open(tab) end

hook.Add("STALKER_PDATabsChanged","STALKER_PDA.Nav",function() if P.IsOpen() then P.BuildNav() end end)
-- F4: меню DarkRP отключено, бинд gm_showspare2 открывает КПК. true — бинд дальше не идёт (в т.ч. в F4 DarkRP).
hook.Add("PlayerBindPress","STALKER_PDA.F4",function(_,bind,pressed)
 if not cfg.F4Key or type(bind)~="string" or not string.find(string.lower(bind),"gm_showspare2",1,true) then return end
 if pressed then P.Toggle() end
 return true
end)
-- stalker_pda — открыть/закрыть; stalker_pda <вкладка> — открыть на вкладке (summary, map, news, stats, encyclopedia, messages, guide…).
concommand.Add("stalker_pda",function(_,_,args)
 local tab=args and args[1]
 if tab and tab~="" then P.Open(tab) else P.Toggle() end
end)
function P.OpenTab(tab) return P.Open(tab) end
