-- STALKER Social: меню взаимодействия (G, взгляд на сталкера не дальше InteractDistance), входящие предложения
-- (подсказка на экране), результат обыска, приём списка знакомых и состояния нашивок. Всё решает сервер.
local S=STALKER_SOCIAL
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local Cfg=S.Config
local function px(n) return T.Px(n) end

function S.Request(op,data)
 data=data or {};data.op=op
 return C.Send("stalker_social.act",nil,data)
end

--[[ Данные с сервера ]]
net.Receive("stalker_social.known",function(len)
 local d=C.Read(len);if not d or type(d.list)~="table" then return end
 local map={}
 for _,row in ipairs(d.list) do
  if type(row)=="table" and type(row.sid)=="string" then map[row.sid]={name=tostring(row.name or ""),at=tonumber(row.at) or 0,contact=row.contact==true} end
 end
 S.MyKnown=map
 -- Фразы шёпота и крика на языке сервера (ими DarkRP собирает префикс локального чата).
 if type(d.phrases)=="table" then local p={};for _,k in ipairs({"whisper","yell"}) do if type(d.phrases[k])=="string" then p[k]=d.phrases[k] end end;S.ServerPhrases=p end
 hook.Run("STALKER_SOCIAL_KnownUpdated",map)
end)
net.Receive("stalker_social.patches",function(len)
 local d=C.Read(len);if not d or type(d.items)~="table" then return end
 d.visible=type(d.visible)=="table" and d.visible or {}
 S.PatchState=d
 hook.Run("STALKER_SOCIAL_PatchesUpdated",d)
end)
-- Входящие предложения: S.Offers[индекс игрока]={name, shake=до, intro=до}.
S.Offers=S.Offers or {}
net.Receive("stalker_social.request",function(len)
 local d=C.Read(len,2000);if not d or not C.Int(d.ent,1,65535) or (d.kind~="shake" and d.kind~="intro") then return end
 local o=S.Offers[d.ent] or {};o.name=tostring(d.name or Cfg.StrangerName);o[d.kind]=CurTime()+math.Clamp(tonumber(d.seconds) or 30,1,300)
 S.Offers[d.ent]=o
 surface.PlaySound("buttons/blip1.wav")
end)
function S.OfferFrom(ply,kind)
 local o=IsValid(ply) and S.Offers[ply:EntIndex()]
 return o and (o[kind] or 0)>CurTime() or false
end
function S.ActiveOffers()
 local out={};local now=CurTime()
 for index,o in pairs(S.Offers) do
  local ply=Entity(index)
  if IsValid(ply) and ply:IsPlayer() then
   for _,kind in ipairs({"shake","intro"}) do if (o[kind] or 0)>now then out[#out+1]={ply=ply,kind=kind,left=o[kind]-now,name=S.Label(LocalPlayer(),ply)} end end
  else S.Offers[index]=nil end
 end
 table.sort(out,function(a,b) return a.left>b.left end)
 return out
end
local function clearOffer(ply,kind) local o=IsValid(ply) and S.Offers[ply:EntIndex()];if o then o[kind]=nil end end

--[[ Подсказка о предложениях сверху экрана ]]
hook.Add("HUDPaint","STALKER_SOCIAL.Offers",function()
 local list=S.ActiveOffers();if #list==0 then return end
 local w=px(460);local h=px(30);local x=ScrW()/2-w/2;local y=px(90)
 for i=1,math.min(3,#list) do
  local o=list[i]
  U.Panel("",x,y,w,h,true)
  local text=o.kind=="shake" and (o.name.." протягивает руку · G — пожать") or (o.name.." представился · G — представиться в ответ")
  U.Text(U.Fit(text,"STALKER.Body",w-px(70)),"STALKER.Body",x+px(10),y+h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  U.Text(math.ceil(o.left).." с","STALKER.Small",x+w-px(10),y+h/2,"muted",TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
  y=y+h+px(4)
 end
end)

--[[ Цель взгляда ]]
function S.InRange(ply,range)
 local me=LocalPlayer()
 return IsValid(me) and IsValid(ply) and ply:IsPlayer() and ply~=me and ply:Alive() and me:GetPos():DistToSqr(ply:GetPos())<=(range or Cfg.InteractDistance)^2
end
function S.AimedPlayer()
 local me=LocalPlayer();if not IsValid(me) then return end
 local tr=me:GetEyeTrace();local ent=tr and tr.Entity
 if S.InRange(ent) then return ent end
end

--[[ Меню взаимодействия ]]
local function head(parent,text)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(28));p:DockMargin(0,0,0,px(6))
 p.Paint=function(_,w,h) U.Text(text,"STALKER.Head",0,h/2,"accent",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);surface.SetDrawColor(T.C.line);surface.DrawRect(0,h-1,w,1) end
 return p
end
local function note(parent,text,token)
 local l=U.Label(parent,text,"STALKER.Small",token or "muted");l:Dock(TOP);l:DockMargin(0,0,0,px(6));return l
end
local function card(parent,h,paint)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(h));p:DockMargin(0,0,0,px(6));p:DockPadding(px(8),px(8),px(8),px(8))
 p.Paint=function(self,w,hh) U.Panel("",0,0,w,hh,self.Active);if paint then paint(self,w,hh) end end
 return p
end
local function scroll(parent) local sc=vgui.Create("DScrollPanel",parent);sc:Dock(FILL);U.Scroll(sc);return sc end
S.MenuUI={head=head,note=note,card=card,scroll=scroll}

-- Строка нашивок цели (значок, название, описание).
local function patchRows(parent,list)
 if #list==0 then note(parent,"Нашивок не видно.");return end
 for _,id in ipairs(list) do
  local info=S.PatchInfo(id)
  if info then
   card(parent,56,function(_,w,h)
    S.DrawPatch(id,px(4),h/2-px(20),px(40))
    U.Text(U.Fit(info.name,"STALKER.Body",w-px(64)),"STALKER.Body",px(54),px(10),"text")
    U.Text(U.Fit(info.desc,"STALKER.Small",w-px(64)),"STALKER.Small",px(54),px(30),"muted")
   end)
  end
 end
end
S.PatchRows=patchRows

local PAGES={}
S.MenuPages=PAGES
function PAGES.card(body,t)
 local me=LocalPlayer()
 card(body,64,function(_,w,h)
  if not IsValid(t) then return end
  local name,faction=S.DisplayName(me,t)
  U.Text(U.Fit(name,"STALKER.Title",w-px(16)),"STALKER.Title",px(6),px(6),"text")
  local sub=faction and C.FactionName(faction) or (S.Knows(me,t) and "Знакомый сталкер" or "Нашивки группировки не видно")
  U.Text(U.Fit(sub,"STALKER.Small",w-px(16)),"STALKER.Small",px(6),px(36),faction and C.FactionColor(faction) or "muted")
 end)
 local status=card(body,40,function(_,w,h)
  if not IsValid(t) then return end
  local pose=S.PoseByID[S.GetPose(t)]
  local text=pose and ("Поза: "..pose.name..(pose.id=="surrender" and " — можно обыскать" or "")) or "Стоит спокойно"
  if S.OfferFrom(t,"shake") then text="Протягивает вам руку — нажмите «Пожать руку»" elseif S.OfferFrom(t,"intro") then text="Представился вам — можно представиться в ответ" end
  U.Text(U.Fit(text,"STALKER.Body",w-px(16)),"STALKER.Body",px(6),h/2,(S.OfferFrom(t,"shake") or S.OfferFrom(t,"intro")) and "accent" or "muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end)
 status.Think=function(self) self.Active=S.OfferFrom(t,"shake") or S.OfferFrom(t,"intro") end
 head(body,"Нашивки")
 patchRows(body,S.VisiblePatches(t))
end
function PAGES.patches(body,t)
 head(body,"Нашивки сталкера")
 local sc=scroll(body)
 patchRows(sc,S.VisiblePatches(t))
end
function PAGES.money(body,t)
 head(body,"Передать деньги")
 local me=LocalPlayer()
 local have=me.getDarkRPVar and tonumber(me:getDarkRPVar("money"))
 note(body,(have and ("У вас: "..S.Money(have)..". ") or "").."Не больше "..S.Money(Cfg.MaxTransfer).." за раз.")
 local row=vgui.Create("DPanel",body);row:Dock(TOP);row:SetTall(px(32));row:DockMargin(0,0,0,px(6));row.Paint=function() end
 local entry=vgui.Create("DTextEntry",row);U.Entry(entry);entry:Dock(FILL);entry:SetNumeric(true);entry:SetPlaceholderText("Сумма, ₽")
 local send=U.Button(row,"Передать",function()
  local n=math.floor(tonumber(entry:GetValue()) or 0)
  if n<1 then return end
  S.Request("money",{t=t:EntIndex(),amount=n})
 end,"accent")
 send:Dock(RIGHT);send:SetWide(px(130));send:DockMargin(px(6),0,0,0)
 body.Entry=entry;body.Send=send
 local quick=vgui.Create("DPanel",body);quick:Dock(TOP);quick:SetTall(px(32));quick.Paint=function() end
 for _,n in ipairs({100,500,1000,5000}) do
  local b=U.Button(quick,S.Money(n),function() entry:SetValue(tostring(n)) end)
  b:Dock(LEFT);b:SetWide(px(96));b:DockMargin(0,0,px(6),0)
 end
end
function PAGES.item(body,t)
 head(body,"Передать предмет из рюкзака")
 local I=STALKER_INV
 if not (I and I.Inventory and I.Items) then note(body,"Инвентарь недоступен.");return end
 local sc=scroll(body);local any=false
 for slot=1,40 do
  local it=I.Inventory.grid[slot];local d=it and I.Items[it.id]
  if d then
   any=true
   local c=card(sc,48,function(_,w,h)
    if I.DrawItemIcon then I.DrawItemIcon(it,px(2),px(4),px(54),h-px(8)) end
    U.Text(U.Fit(d.name..(it.count>1 and (" ×"..it.count) or ""),"STALKER.Body",w-px(300)),"STALKER.Body",px(64),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   end)
   local all=U.Button(c,it.count>1 and ("Все ("..it.count..")") or "Передать",function() S.Request("item",{t=t:EntIndex(),uid=it.uid,count=it.count});if IsValid(S.Menu) then S.Menu:Remove() end end,"accent")
   all:Dock(RIGHT);all:SetWide(px(110));all:DockMargin(px(6),0,0,0)
   if it.count>1 then
    local one=U.Button(c,"1 шт.",function() S.Request("item",{t=t:EntIndex(),uid=it.uid,count=1}) end)
    one:Dock(RIGHT);one:SetWide(px(70));one:DockMargin(px(6),0,0,0)
   end
  end
 end
 if not any then note(sc,"Рюкзак пуст.") end
end
function PAGES.award(body,t)
 head(body,"Награды командира")
 note(body,"Награда видна на рукаве, пока сталкер состоит в вашей группировке. Повторное нажатие снимает награду.")
 for _,a in ipairs(S.Awards) do
  local id="award_"..a.id
  local c=card(body,52,function(_,w,h)
   S.DrawPatch(id,px(2),h/2-px(18),px(36))
   U.Text(a.name,"STALKER.Body",px(48),px(8),"text")
   U.Text(U.Fit(a.desc,"STALKER.Small",w-px(200)),"STALKER.Small",px(48),px(28),"muted")
  end)
  local b=U.Button(c,"Выдать / снять",function() S.Request("award",{t=t:EntIndex(),award=a.id}) end)
  b:Dock(RIGHT);b:SetWide(px(130))
 end
end
-- Обыск: только просмотр.
function PAGES.search(body,data)
 head(body,"Обыск: "..tostring(data.name or Cfg.StrangerName))
 local I=STALKER_INV
 note(body,"Только просмотр: забрать вещи можно, если хозяин отдаст их сам."..(data.weight and ("  Вес: "..data.weight.." кг") or ""))
 local sc=scroll(body)
 if #data.items==0 then note(sc,"Рюкзак пуст.");return end
 for _,it in ipairs(data.items) do
  local d=I and I.Items and I.Items[it.id]
  card(sc,44,function(_,w,h)
   if d and I.DrawItemIcon then I.DrawItemIcon(it,px(2),px(4),px(50),h-px(8)) end
   U.Text(U.Fit((d and d.name or tostring(it.id))..((tonumber(it.count) or 1)>1 and (" ×"..it.count) or ""),"STALKER.Body",w-px(150)),"STALKER.Body",px(60),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   U.Text((tonumber(it.durability) or 100).."%","STALKER.Small",w-px(8),h/2,(tonumber(it.durability) or 100)<50 and "warn" or "muted",TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
  end)
 end
end

function S.ShowPage(f,page,arg)
 if not f or not f.Body or not PAGES[page] then return end
 f.Body:Clear();f.Page=page
 PAGES[page](f.Body,arg or f.Target)
 for _,b in ipairs(f.Buttons or {}) do b.Active=b.Page==page end
end
-- Кнопки меню: подпись может зависеть от предложений цели, видимость — от группировок и инвентаря.
function S.MenuActions(t)
 local me=LocalPlayer()
 local mine=C.Faction(me);local theirs=C.Faction(t)
 local officer=STFW~=nil and mine~=nil and (me:GetNW2Bool("stfw_leader",false) or me:GetNW2Int("stfw_frank",0)>=(STFW.OfficerRank or 4))
 local leader=STFW~=nil and mine~=nil and me:GetNW2Bool("stfw_leader",false)
 return {
  {id="intro",label=function() return S.OfferFrom(t,"intro") and "Представиться в ответ" or "Представиться" end,
   run=function() clearOffer(t,"intro");S.Request("intro",{t=t:EntIndex()}) end},
  {id="shake",label=function() return S.OfferFrom(t,"shake") and "Ответить на рукопожатие" or "Пожать руку" end,
   run=function() clearOffer(t,"shake");S.Request("shake",{t=t:EntIndex()}) end},
  {id="money",label="Передать деньги",page="money",show=Cfg.MaxTransfer>0},
  {id="item",label="Передать предмет",page="item",show=STALKER_INV~=nil},
  {id="patches",label="Нашивки",page="patches"},
  {id="contact",label="В контакты КПК",run=function() S.Request("contact",{t=t:EntIndex()}) end},
  {id="invite",label="Пригласить в группировку",show=officer and theirs~=mine,run=function() S.Request("invite",{t=t:EntIndex()}) end},
  {id="award",label="Наградить нашивкой",page="award",show=leader and theirs==mine},
  {id="search",label="Обыскать",show=STALKER_INV~=nil,enabled=function() return S.GetPose(t)=="surrender" end,
   run=function() S.Request("search",{t=t:EntIndex()}) end},
 }
end
function S.OpenInteract(t)
 if not S.InRange(t,Cfg.InteractDistance*1.2) then return end
 if IsValid(S.Menu) then S.Menu:Remove() end
 local f=U.Window({title=S.Label(LocalPlayer(),t),w=700,h=480,onClose=function() S.Menu=nil end})
 S.Menu=f;f.Target=t;f.Buttons={}
 local left=vgui.Create("DPanel",f);left:Dock(LEFT);left:SetWide(px(220));left:DockMargin(0,0,px(10),0);left.Paint=function() end
 local body=vgui.Create("DPanel",f);body:Dock(FILL);body:DockPadding(px(10),px(10),px(10),px(10))
 body.Paint=function(_,w,h) U.Panel("",0,0,w,h) end
 f.Body=body
 local cardBtn=U.Button(left,"Сталкер",function() S.ShowPage(f,"card") end);cardBtn:Dock(TOP);cardBtn:DockMargin(0,0,0,px(10));cardBtn.Page="card"
 f.Buttons[#f.Buttons+1]=cardBtn
 for _,a in ipairs(S.MenuActions(t)) do
  if a.show~=false then
   local b=U.Button(left,type(a.label)=="function" and a.label() or a.label,function()
    if a.page then S.ShowPage(f,a.page) elseif a.run then a.run() end
   end)
   b:Dock(TOP);b:DockMargin(0,0,0,px(6));b.Page=a.page;b.ActionID=a.id
   b.Think=function(self)
    if type(a.label)=="function" then self.Label=a.label() end
    -- Ответ на предложение цели подсвечен акцентом.
    if a.id=="shake" or a.id=="intro" then self.Kind=S.OfferFrom(t,a.id) and "accent" or nil end
    if a.enabled then self:SetEnabled(a.enabled()==true) end
   end
   f.Buttons[#f.Buttons+1]=b
  end
 end
 -- Цель ушла, погибла или пропала — меню закрывается.
 f.Think=function(self)
  if not S.InRange(t,Cfg.InteractDistance*1.6) then
   if IsValid(t) and t:IsPlayer() and t:Alive() and C.Toast then C.Toast("Сталкер слишком далеко","warn",3) end
   self:Remove();return
  end
  self.Title=S.Label(LocalPlayer(),t)
 end
 S.ShowPage(f,"card")
 return f
end
net.Receive("stalker_social.search",function(len)
 local d=C.Read(len);if not d or type(d.items)~="table" then return end
 local ent=C.Int(d.ent,1,65535) and Entity(d.ent)
 if IsValid(S.Menu) and S.Menu.Target==ent then S.ShowPage(S.Menu,"search",d);return end
 local f=U.Window({title="Обыск",w=560,h=460})
 local body=vgui.Create("DPanel",f);body:Dock(FILL);body.Paint=function() end
 PAGES.search(body,d)
 S.SearchWindow=f
end)

-- Список знакомых приходит при входе; если клиент ещё грузился, просим его сами.
hook.Add("InitPostEntity","STALKER_SOCIAL.Known",function() timer.Simple(3,function() S.Request("known") end) end)

--[[ Клавиша G и консоль ]]
local keyCV=CreateClientConVar("stsoc_key",tostring(KEY_G or 17),true,false,"Клавиша меню взаимодействия с игроком (код KEY_*)")
hook.Add("StartChat","STALKER_SOCIAL.Chat",function() S.Chatting=true end)
hook.Add("FinishChat","STALKER_SOCIAL.Chat",function() S.Chatting=false end)
-- Общая проверка «клавиша нажата в игре», а не в чате, консоли или поле ввода. menu — открытое окно, которое клавиша закрывает.
function S.KeyAllowed(menu)
 if S.Chatting or gui.IsGameUIVisible() or gui.IsConsoleVisible() then return false end
 local focus=vgui.GetKeyboardFocus()
 if IsValid(focus) and focus.IsEditing and focus:IsEditing() then return false end
 return IsValid(menu) or not IsValid(focus)
end
function S.InteractKey()
 if not S.KeyAllowed(S.Menu) then return end
 if IsValid(S.Menu) then S.Menu:Remove();return end
 local t=S.AimedPlayer()
 if not t then if C.Toast then C.Toast("Посмотрите на сталкера рядом с вами","info",3) end;return end
 S.OpenInteract(t)
end
local held=false
hook.Add("Think","STALKER_SOCIAL.InteractKey",function()
 local down=input.IsKeyDown(keyCV:GetInt())
 if down and not held and IsValid(LocalPlayer()) then S.InteractKey() end
 held=down
end)
concommand.Add("stsoc_interact",function() local t=S.AimedPlayer();if t then S.OpenInteract(t) end end)
