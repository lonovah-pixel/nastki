-- Личные сообщения КПК (клиент): список собеседников, переписка, отправка с лимитом длины и паузой, уведомления и значок.
local P=STALKER_PDA
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local W=P.UI
local cfg=P.Config
local function px(n) return T.Px(n) end

P.Inbox=P.Inbox or {}
P.Threads=P.Threads or {}
P.Unread=P.Unread or 0
P.Names=P.Names or {}

function P.Request(op,data) data=data or {};data.op=op;return C.Send("stalker_pda.req",nil,data) end
function P.Viewing(sid) return P.IsOpen() and P.Current=="messages" and P.Chat==sid end
function P.FindConversation(sid) for i,c in ipairs(P.Inbox) do if c.sid==sid then return c,i end end end
local function preview(text) text=tostring(text or "");return utf8.sub and utf8.sub(text,1,90) or text:sub(1,90) end
-- Переписка поднимается наверх списка с новым последним сообщением.
local function touch(sid,name,text,t,mine,unreadDelta,system)
 local c,i=P.FindConversation(sid)
 if not c then c={sid=sid,name=name or P.Names[sid] or "Неизвестный абонент",unread=0,system=system};table.insert(P.Inbox,1,c)
 elseif i>1 then table.remove(P.Inbox,i);table.insert(P.Inbox,1,c) end
 if name then c.name=name end
 c.last=preview(text);c.t=t or os.time();c.mine=mine
 c.unread=math.max(0,(c.unread or 0)+(unreadDelta or 0))
 return c
end
function P.DisplayName(sid)
 local p=not P.IsSystem(sid) and C.PlayerBySID(sid)
 if IsValid(p) then return P.NameFor(LocalPlayer(),p) or p:Nick() end
 local th=P.Threads[sid]
 return P.Names[sid] or (th and th.name) or "Неизвестный абонент"
end

--[[ Ответы сервера (вынесены из net.Receive для тестов) ]]
function P.HandleData(d)
 local kind=d.kind
 if kind=="inbox" then
  P.Inbox={}
  for _,c in ipairs(type(d.list)=="table" and d.list or {}) do
   if type(c)=="table" and type(c.sid)=="string" then P.Inbox[#P.Inbox+1]=c;if type(c.name)=="string" then P.Names[c.sid]=c.name end end
  end
  P.Unread=tonumber(d.unread) or 0;P.InboxLoaded=true
  P.Refresh("inbox")
 elseif kind=="thread" then
  local sid=d.sid;if type(sid)~="string" then return end
  P.Threads[sid]={messages=type(d.messages)=="table" and d.messages or {},name=d.name,online=d.online,system=d.system}
  if type(d.name)=="string" then P.Names[sid]=d.name end
  local c=P.FindConversation(sid);if c then c.unread=0;if type(d.name)=="string" then c.name=d.name end end
  P.Unread=tonumber(d.unread) or P.Unread
  P.Refresh("thread",sid);P.Refresh("inbox")
 elseif kind=="msg" then
  local m=d.msg;if type(m)~="table" or type(m.from)~="string" or type(m.text)~="string" then return end
  local name=type(d.name)=="string" and d.name or P.Names[m.from]
  if name then P.Names[m.from]=name end
  local viewing=P.Viewing(m.from)
  local th=P.Threads[m.from];if th then table.insert(th.messages,{id=m.id,mine=false,text=m.text,t=m.t,seen=true}) end
  touch(m.from,name,m.text,m.t,false,viewing and 0 or 1,m.system)
  P.Unread=tonumber(d.unread) or (P.Unread+1)
  if viewing then P.Request("read",{sid=m.from})
  elseif cfg.MessageToast and C.Toast then C.Toast("Сообщение от "..(name or "абонента")..": "..preview(m.text),"info",7) end
  hook.Run("STALKER_PDA_NewMessage",m,name)
  P.Refresh("thread",m.from);P.Refresh("inbox")
 elseif kind=="result" then
  if d.ok and type(d.msg)=="table" then
   local m=d.msg
   local th=P.Threads[m.to];if th then table.insert(th.messages,{id=m.id,mine=true,text=m.text,t=m.t,seen=false}) end
   touch(m.to,nil,m.text,m.t,true,0)
   P.NextSend=CurTime()+(tonumber(d.next) or cfg.MessageInterval);P.SendError=nil;P.Pending=nil
   P.Refresh("thread",m.to);P.Refresh("inbox")
  else
   P.SendError=tostring(d.error or "Сообщение не отправлено");P.NextSend=0
   if C.Toast then C.Toast(P.SendError,"warn",5) end
   P.Refresh("error",d.to)
  end
 elseif kind=="unread" then
  P.Unread=tonumber(d.n) or 0
  if type(d.sid)=="string" then local c=P.FindConversation(d.sid);if c then c.unread=0 end end
  P.Refresh("inbox")
 elseif kind=="seen" then
  local th=type(d.sid)=="string" and P.Threads[d.sid]
  if th then for _,msg in ipairs(th.messages) do if msg.mine then msg.seen=true end end end
 end
end
net.Receive("stalker_pda.data",function(len) local d=C.Read(len);if type(d)=="table" then P.HandleData(d) end end)

-- Отправка: проверка как на сервере (сервер всё равно проверяет сам), пауза между сообщениями.
function P.Send(to,text)
 if not P.ValidSID(to) then return false,"Этому абоненту ответить нельзя" end
 local body,err=P.CleanText(text)
 if not body then P.SendError=P.TextErrors[err];return false,P.SendError end
 if (P.NextSend or 0)>CurTime() then return false,"Подождите "..math.ceil(P.NextSend-CurTime()).." с" end
 P.NextSend=CurTime()+math.max(.5,cfg.MessageInterval);P.Pending={to=to,text=body};P.SendError=nil
 P.Request("send",{to=to,text=body})
 return true
end
-- Открыть КПК на переписке с игроком (SteamID64) — для меню взаимодействия и других аддонов.
function P.OpenMessages(sid)
 if type(sid)=="string" and (P.ValidSID(sid) or P.IsSystem(sid)) then P.Chat=sid end
 return P.Open("messages")
end

--[[ Вкладка ]]
local function contactPaint(self,w,h)
 local c=self.Contact;local active=P.Chat==c.sid
 U.Panel("",0,0,w,h,active or self:IsHovered())
 local online=not c.system and IsValid(C.PlayerBySID(c.sid))
 local dot=c.system and T.C.accent2 or online and T.C.ok or T.C.muted
 draw.RoundedBox(px(4),px(8),px(10),px(8),px(8),dot)
 local unread=tonumber(c.unread) or 0
 local right=c.t and P.Ago(c.t) or (online and "в сети" or "")
 U.Text(right,"STALKER.Small",w-px(8),px(6),"muted",TEXT_ALIGN_RIGHT)
 surface.SetFont("STALKER.Small");local rw=surface.GetTextSize(right)
 local name=P.DisplayName(c.sid);if name=="Неизвестный абонент" and c.name then name=c.name end
 U.Text(U.Fit(name,"STALKER.Body",w-px(36)-rw),"STALKER.Body",px(24),px(4),unread>0 and "accent" or "text")
 if c.last then U.Text(U.Fit((c.mine and "Вы: " or "")..c.last,"STALKER.Small",w-px(unread>0 and 64 or 34)),"STALKER.Small",px(24),px(26),"muted") end
 if unread>0 then P.DrawBadge(unread,w-px(8),px(34),TEXT_ALIGN_RIGHT) end
end
local function bubble(parent,m,name)
 local b=vgui.Create("DPanel",parent);b:Dock(TOP);b:DockMargin(0,0,0,px(6));b.Msg=m;b.Name=name;b:SetTall(px(48))
 b.PerformLayout=function(self,w)
  local bw=math.floor(w*.74);self.BW=bw
  self.Lines=U.Wrap(self.Msg.text or "","STALKER.Body",bw-px(24))
  surface.SetFont("STALKER.Body");local _,lh=surface.GetTextSize("Ag");self.LH=lh+px(2)
  local tall=px(30)+#self.Lines*self.LH
  if self:GetTall()~=tall then self:SetTall(tall) end
 end
 b.Paint=function(self,w,h)
  local msg=self.Msg;local c=T.C;local bw=self.BW or math.floor(w*.74)
  local x=msg.mine and (w-bw) or 0
  surface.SetDrawColor(msg.mine and c.panel2 or c.panel);surface.DrawRect(x,0,bw,h)
  surface.SetDrawColor(msg.mine and c.lineHi or c.line);surface.DrawOutlinedRect(x,0,bw,h,1)
  surface.SetDrawColor(msg.mine and c.accent or c.info);surface.DrawRect(msg.mine and (x+bw-px(3)) or x,0,px(3),h)
  U.Text(msg.mine and "Вы" or U.Fit(self.Name or "","STALKER.Small",bw*.5),"STALKER.Small",x+px(12),px(5),msg.mine and "accent" or "info")
  local status=P.Ago(msg.t)..(msg.mine and (msg.seen and " · прочитано" or " · доставлено") or "")
  U.Text(status,"STALKER.Small",x+bw-px(12),px(5),"muted",TEXT_ALIGN_RIGHT)
  for i,line in ipairs(self.Lines or {}) do U.Text(line,"STALKER.Body",x+px(12),px(24)+(i-1)*(self.LH or px(17)),"text") end
 end
 return b
end

P.AddTab("messages",{title="Сообщения",order=60,badge=function() return (P.Unread or 0)>0 and P.Unread or nil end,build=function(parent)
 -- Слева: собеседники (переписки и игроки в сети).
 local left=vgui.Create("DPanel",parent);left:Dock(LEFT);left:SetWide(px(300));left:DockMargin(0,0,px(10),0);left:DockPadding(px(6),px(30),px(6),px(6))
 left.Paint=function(_,w,h) U.Panel("",0,0,w,h,false);U.Text("СОБЕСЕДНИКИ","STALKER.Small",px(10),px(9),"muted") end
 local search=vgui.Create("DTextEntry",left);search:Dock(TOP);search:SetTall(px(30));search:DockMargin(0,0,0,px(6));U.Entry(search)
 search:SetPlaceholderText("Поиск по имени")
 local list=W.Scroll(left)
 -- Справа: шапка собеседника, переписка, поле ввода.
 local right=vgui.Create("DPanel",parent);right:Dock(FILL);right:DockPadding(px(10),px(8),px(10),px(10))
 right.Paint=function(_,w,h) U.Panel("",0,0,w,h,false) end
 local head=vgui.Create("DPanel",right);head:Dock(TOP);head:SetTall(px(50));head:DockMargin(0,0,0,px(8))
 head.Paint=function(_,w,h)
  surface.SetDrawColor(T.C.line);surface.DrawRect(0,h-1,w,1)
  local sid=P.Chat
  if not sid then U.Text("Сеть КПК","STALKER.Head",0,px(4),"accent");U.Text("Личные сообщения сталкеров","STALKER.Small",0,px(26),"muted");return end
  U.Text(U.Fit(P.DisplayName(sid),"STALKER.Head",w-px(220)),"STALKER.Head",0,px(4),"accent")
  local status,token
  if P.IsSystem(sid) then status,token="Служебная рассылка — ответить нельзя","accent2"
  elseif IsValid(C.PlayerBySID(sid)) then status,token="В сети","ok"
  else status,token="Не в сети — сообщение дойдёт, когда абонент войдёт","muted" end
  U.Text(status,"STALKER.Small",0,px(26),token)
 end
 local del=U.Button(head,"Удалить переписку",nil,"danger");del:Dock(RIGHT);del:SetWide(px(200));del:DockMargin(0,px(8),0,px(10))
 local compose=vgui.Create("DPanel",right);compose:Dock(BOTTOM);compose:SetTall(px(64));compose:DockMargin(0,px(8),0,0)
 compose.Paint=function(_,w,h)
  local entryText=compose.Entry and compose.Entry:GetValue();entryText=type(entryText)=="string" and entryText or ""
  local n=utf8.len(entryText) or 0;local limit=math.floor(cfg.MessageLength)
  U.Text(n.." / "..limit,"STALKER.Mono",0,h-px(16),n>limit and "danger" or "muted")
  local wait=(P.NextSend or 0)-CurTime()
  if P.SendError then U.Text(U.Fit(P.SendError,"STALKER.Small",w-px(260)),"STALKER.Small",px(90),h-px(16),"danger")
  elseif wait>0 then U.Text("Следующее сообщение через "..math.ceil(wait).." с","STALKER.Small",px(90),h-px(16),"muted") end
 end
 local send=U.Button(compose,"Отправить",nil,"accent");send:Dock(RIGHT);send:SetWide(px(150));send:DockMargin(px(8),0,0,px(20))
 local entry=vgui.Create("DTextEntry",compose);entry:Dock(FILL);entry:DockMargin(0,0,0,px(20));U.Entry(entry);compose.Entry=entry
 entry:SetPlaceholderText("Сообщение… (Enter — отправить)")
 local thread=W.Scroll(right)
 thread.Think=function(self)
  -- После построения переписки прокручиваем вниз, пока раскладка не устоится.
  if (self.ScrollUntil or 0)>CurTime() then local bar=self:GetVBar();if bar and bar.SetScroll then bar:SetScroll(math.huge) end end
 end

 local function fillThread()
  thread:Clear();P.SendError=nil
  local sid=P.Chat
  if not sid then
   W.Text(thread,"Выберите собеседника слева. Сообщения доходят и до тех, кто не в сети — они прочитают их при входе.","muted")
   W.Text(thread,"Сообщения хранятся "..math.floor(cfg.MessageDays).." дн. Длина — до "..math.floor(cfg.MessageLength).." символов.","muted","STALKER.Small")
   return
  end
  local th=P.Threads[sid]
  if not th then W.Text(thread,"Загрузка переписки…","muted");return end
  if #th.messages==0 then W.Text(thread,"Сообщений пока нет. Напишите первым.","muted");return end
  local name=P.DisplayName(sid)
  for _,m in ipairs(th.messages) do if type(m)=="table" then bubble(thread,m,name) end end
  thread.ScrollUntil=CurTime()+.6
 end
 local function select(sid)
  P.Chat=sid;P.Request("thread",{sid=sid});fillThread()
  if entry.RequestFocus and not P.IsSystem(sid) then entry:RequestFocus() end
 end
 local function contact(c)
  local b=vgui.Create("DButton",list);b:Dock(TOP);b:SetTall(px(48));b:DockMargin(0,0,0,px(3));b:SetText("");b.Contact=c;b.Paint=contactPaint
  b.DoClick=function(self) surface.PlaySound("buttons/lightswitch2.wav");select(self.Contact.sid) end
  return b
 end
 local function fillContacts()
  list:Clear()
  local value=search:GetValue();local query=P.Lower(type(value)=="string" and string.Trim(value) or "")
  local function match(name) return query=="" or string.find(P.Lower(name),query,1,true)~=nil end
  local known={}
  local shown=0
  for _,c in ipairs(P.Inbox) do
   known[c.sid]=true
   if match(P.DisplayName(c.sid)) then contact(c);shown=shown+1 end
  end
  local me=LocalPlayer()
  local online={}
  for _,p in ipairs(player.GetAll()) do
   local sid=C.SID(p)
   if sid and p~=me and not known[sid] then online[#online+1]={sid=sid,name=P.NameFor(me,p) or p:Nick()} end
  end
  table.sort(online,function(a,b) return a.name<b.name end)
  local header=false
  for _,c in ipairs(online) do
   if match(c.name) then
    if not header then header=true;local l=U.Label(list,"В СЕТИ","STALKER.Small","muted");l:Dock(TOP);l:DockMargin(px(4),px(8),0,px(4)) end
    contact(c);shown=shown+1
   end
  end
  if shown==0 then W.Text(list,query=="" and "Пока не с кем переписываться: в сети никого, переписок нет." or "Никого не найдено.","muted","STALKER.Small") end
  left.Online=#player.GetAll()
 end
 left.Think=function(self)
  if (self.Next or 0)>CurTime() then return end
  self.Next=CurTime()+3
  if self.Online~=#player.GetAll() then fillContacts() end
 end
 search.OnChange=function() fillContacts() end

 local function doSend()
  local sid=P.Chat;if not sid then return end
  local value=entry:GetValue();if type(value)~="string" then return end
  if P.Send(sid,value) then entry:SetText("") end
  if entry.RequestFocus then entry:RequestFocus() end
 end
 send.DoClick=function(self) if self:IsEnabled() then surface.PlaySound("buttons/lightswitch2.wav");doSend() end end
 send.Think=function(self)
  local value=entry:GetValue()
  self:SetEnabled(P.Chat~=nil and not P.IsSystem(P.Chat) and type(value)=="string" and value:find("%S")~=nil and (P.NextSend or 0)<=CurTime())
 end
 entry.OnEnter=function() doSend() end
 -- Не даём набрать больше лимита (сервер всё равно режет).
 entry.AllowInput=function(self)
  local value=self:GetValue();local n=type(value)=="string" and utf8.len(value)
  if n and n>=cfg.MessageLength then return true end
 end
 entry.Think=function(self) self:SetEnabled(P.Chat==nil or not P.IsSystem(P.Chat)) end
 del.DoClick=function(self)
  local sid=P.Chat;if not sid then return end
  -- Подтверждение повторным нажатием в течение 3 секунд.
  if (self.ConfirmUntil or 0)<CurTime() then self.ConfirmUntil=CurTime()+3;self.Label="Точно удалить?";surface.PlaySound("buttons/button16.wav");return end
  self.ConfirmUntil=0;self.Label="Удалить переписку"
  P.Request("delete",{sid=sid});P.Threads[sid]=nil
  local _,i=P.FindConversation(sid);if i then table.remove(P.Inbox,i) end
  P.Chat=nil;fillThread();fillContacts()
 end
 del.Think=function(self)
  self:SetEnabled(P.Chat~=nil)
  if self.ConfirmUntil and self.ConfirmUntil~=0 and self.ConfirmUntil<CurTime() then self.ConfirmUntil=0;self.Label="Удалить переписку" end
 end

 parent.PDARefresh={
  inbox=fillContacts,
  thread=function(sid) if sid==P.Chat then fillThread() end end,
  error=function()
   local value=entry:GetValue()
   if P.Pending and (type(value)~="string" or value=="") then entry:SetText(P.Pending.text) end
  end,
 }
 fillContacts();fillThread()
 P.Request("inbox")
 if P.Chat then select(P.Chat) end
end})
