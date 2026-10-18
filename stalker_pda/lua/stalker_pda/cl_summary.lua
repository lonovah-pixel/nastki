-- Вкладки «Сводка», «Новости» и «Статистика». Данные соседних аддонов читаются при отрисовке и только при их наличии.
local P=STALKER_PDA
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local W=P.UI
local cfg=P.Config
local function px(n) return T.Px(n) end

--[[ Данные сводки (без панелей — их проверяют тесты) ]]
-- Сытость и вода — из инвентаря (как в окне TAB: при голоде DarkRP сытость берётся из Energy).
function P.Needs()
 local S=STALKER_INV;local inv=S and S.Inventory
 if type(inv)~="table" then return end
 local lp=LocalPlayer()
 local energy=S.Config and S.Config.DarkRP and S.Config.DarkRP.UseHunger and IsValid(lp) and lp.getDarkRPVar and lp:getDarkRPVar("Energy")
 local hunger=type(energy)=="number" and energy or tonumber(inv.hunger) or 100
 return math.Clamp(hunger,0,100),math.Clamp(tonumber(inv.thirst) or 100,0,100)
end
-- Доза (0–100) и фон (доза/с) — сетевые переменные радиации; порог урона — из её конфигурации.
function P.Radiation()
 local lp=LocalPlayer();if not IsValid(lp) then return 0,0,30 end
 local R=STALKER_RAD
 local threshold=R and R.Config and tonumber(R.Config.DamageThreshold) or 30
 return lp:GetNW2Float("stalker_dose",0),lp:GetNW2Float("stalker_rad_rate",0),threshold
end
-- Состояние выброса: заголовок, токен цвета, пояснение.
function P.EmissionStatus()
 local E=ST_EMISSION
 if type(E)~="table" or type(E.State)~="table" then return "Нет данных о выбросах","muted","Модуль выбросов не установлен." end
 local st=E.State;local phase=tonumber(st.phase) or 0
 if phase>0 then
  local ph=E.Config and E.Config.Phases and E.Config.Phases[phase]
  local left=math.max(0,math.ceil((tonumber(st.ends) or 0)-CurTime()))
  return "ВЫБРОС: "..(ph and ph.name or "ИДЁТ"),"danger","Фаза сменится через "..P.Duration(left)..". Немедленно в укрытие под крышей!"
 end
 local nextAt=tonumber(st.next) or 0
 if cfg.EmissionForecast and nextAt>CurTime() then
  local mins=(nextAt-CurTime())/60;local lo=math.floor(mins/5)*5
  local when=lo<5 and "в ближайшие 5 минут" or ("через "..lo.."–"..(lo+5).." мин")
  return "Зона спокойна",lo<5 and "warn" or "ok","Прогноз учёных: выброс ожидается "..when.."."
 end
 return "Зона спокойна","ok","Выброс начинается с сирены — сразу ищите укрытие под крышей."
end
-- Активные задания аддона заданий: {{title, progress, goal}} (не больше 6).
function P.QuestSummary()
 local Q=STALKER_QUESTS
 if type(Q)~="table" or type(Q.ActiveSummary)~="function" then return nil end
 local ok,list=pcall(Q.ActiveSummary)
 local out={}
 for _,q in ipairs(ok and type(list)=="table" and list or {}) do
  if type(q)=="table" and #out<6 then
   out[#out+1]={title=tostring(q.title or "Задание"),progress=tonumber(q.progress) or 0,goal=math.max(1,tonumber(q.goal) or 1)}
  end
 end
 return out
end
-- Звание в группировке (stfw_frank) или «лидер».
function P.RankText(ply)
 if not IsValid(ply) or not C.Faction(ply) then return "не состоит в группировке" end
 if ply:GetNW2Bool("stfw_leader",false) then return "лидер группировки" end
 local frank=ply:GetNW2Int("stfw_frank",0)
 local ranks=STFW and STFW.FactionRanks
 return ranks and ranks[math.Clamp(frank,1,#ranks)] or "боец"
end
function P.Job(ply) local job=IsValid(ply) and ply.getDarkRPVar and ply:getDarkRPVar("job");return type(job)=="string" and job or nil end
function P.Wallet(ply) local m=IsValid(ply) and ply.getDarkRPVar and ply:getDarkRPVar("money");return tonumber(m) end

P.NewsKinds={info={"КПК","info"},ok={"КПК","ok"},warn={"Внимание","warn"},danger={"Опасность","danger"},emission={"Выброс","danger"},
 event={"Событие","accent"},war={"Война","danger"},capture={"Территория","accent"},quest={"Задание","accent2"},trade={"Торговля","ok"}}
function P.NewsKind(kind) local k=P.NewsKinds[kind or "info"] or P.NewsKinds.info;return k[1],k[2] end

local function column(x,y,w,title,rows)
 U.Text(title,"STALKER.Small",x,y,"muted")
 for i,r in ipairs(rows) do
  local ry=y+px(20)+(i-1)*px(36)
  U.Text(r[1],"STALKER.Small",x,ry,"text");U.Text(r[2],"STALKER.Mono",x+w,ry,r[4] or "text",TEXT_ALIGN_RIGHT)
  U.Bar(x,ry+px(18),w,px(7),r[3],T.C[r[4] or "accent"] or T.C.accent)
 end
end
local function needToken(v) return v<20 and "danger" or v<45 and "warn" or "ok" end

P.AddTab("summary",{title="Сводка",order=10,build=function(parent)
 local sc=W.Scroll(parent)
 -- Личность: имя, группировка, звание, профессия, деньги.
 W.Card(sc,96,function(_,w,h)
  local lp=LocalPlayer();if not IsValid(lp) then return end
  local fid=C.Faction(lp)
  surface.SetDrawColor(C.FactionColor(fid));surface.DrawRect(0,0,px(4),h)
  U.Text(U.Fit(lp:Nick(),"STALKER.Big",w*.55),"STALKER.Big",px(16),px(8),"accent")
  local faction=fid and C.FactionName(fid) or "Вольный сталкер"
  U.Text(faction.."  ·  "..P.RankText(lp),"STALKER.Body",px(16),px(48),"text")
  local job=P.Job(lp);if job then U.Text("Профессия: "..job,"STALKER.Small",px(16),px(70),"muted") end
  local money=P.Wallet(lp)
  U.Text("СЧЁТ","STALKER.Small",w-px(16),px(12),"muted",TEXT_ALIGN_RIGHT)
  U.Text(money and P.Money(money) or "—","STALKER.Head",w-px(16),px(30),"accent2",TEXT_ALIGN_RIGHT)
  U.Text("Сектор: "..game.GetMap(),"STALKER.Small",w-px(16),px(70),"muted",TEXT_ALIGN_RIGHT)
 end)
 -- Состояние: здоровье и броня, радиация, голод и жажда.
 W.Card(sc,126,function(_,w,h)
  local lp=LocalPlayer();if not IsValid(lp) then return end
  local cw=math.floor((w-px(64))/3);local y=px(10)
  local hp,maxhp=math.max(0,lp:Health()),math.max(1,lp:GetMaxHealth())
  local ratio=hp/maxhp
  column(px(16),y,cw,"ЗДОРОВЬЕ",{{"Здоровье",hp.." / "..maxhp,ratio,ratio<.3 and "danger" or ratio<.6 and "warn" or "ok"},
   {"Броня",tostring(lp:Armor()),math.Clamp(lp:Armor()/100,0,1),"info"}})
  local dose,rate,threshold=P.Radiation()
  local token=dose>=threshold and "danger" or dose>=1 and "warn" or "ok"
  column(px(32)+cw,y,cw,"РАДИАЦИЯ",{{"Доза",string.format("%.1f / 100",dose),dose/100,token},
   {rate>0 and "Фон: заражено" or "Фон в норме",rate>0 and string.format("+%.2f/с",rate) or "0",math.Clamp(rate/2,0,1),rate>0 and "danger" or "ok"}})
  local hunger,thirst=P.Needs()
  if hunger then
   column(px(48)+cw*2,y,cw,"ПОТРЕБНОСТИ",{{"Сытость",math.floor(hunger).."%",hunger/100,needToken(hunger)},{"Вода",math.floor(thirst).."%",thirst/100,needToken(thirst)}})
  else U.Text("ПОТРЕБНОСТИ","STALKER.Small",px(48)+cw*2,y,"muted");U.Text("нет данных инвентаря","STALKER.Small",px(48)+cw*2,y+px(20),"muted") end
 end)
 -- Выброс.
 local emission=W.Card(sc,62,function(self,w,h)
  local title,token,detail=P.EmissionStatus()
  surface.SetDrawColor(T.C[token] or T.C.ok);surface.DrawRect(0,0,px(4),h)
  U.Text("ВЫБРОС","STALKER.Small",px(16),px(8),"muted")
  U.Text(title,"STALKER.Head",px(16),px(26),token)
  U.Text(U.Fit(detail,"STALKER.Small",w*.6),"STALKER.Small",w-px(16),px(30),"text",TEXT_ALIGN_RIGHT)
 end)
 emission.Think=function(self) self.Active=(tonumber(ST_EMISSION and ST_EMISSION.State and ST_EMISSION.State.phase) or 0)>0 end
 -- Задания.
 W.Head(sc,"Активные задания")
 local quests=W.Card(sc,44,function(self,w,h)
  local list=self.List
  if not list then U.Text("Модуль заданий не установлен.","STALKER.Small",px(16),h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);return end
  if #list==0 then U.Text("Активных заданий нет. Задания выдают торговцы и персонажи Зоны.","STALKER.Small",px(16),h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);return end
  for i,q in ipairs(list) do
   local y=px(8)+(i-1)*px(40);local done=q.progress>=q.goal
   U.Text(U.Fit(q.title,"STALKER.Body",w*.7),"STALKER.Body",px(16),y,done and "ok" or "text")
   U.Text(math.floor(q.progress).." / "..math.floor(q.goal),"STALKER.Mono",w-px(16),y,done and "ok" or "muted",TEXT_ALIGN_RIGHT)
   U.Bar(px(16),y+px(22),w-px(32),px(7),q.progress/q.goal,done and T.C.ok or T.C.accent2)
  end
 end)
 quests.Think=function(self)
  if (self.Next or 0)>CurTime() then return end
  self.Next=CurTime()+1;self.List=P.QuestSummary()
  local tall=px(16)+math.max(1,self.List and #self.List or 1)*px(40)
  if self:GetTall()~=tall then self:SetTall(tall) end
 end
 -- Сообщения.
 local mail=W.Card(sc,52,function(self,w,h)
  local n=P.Unread or 0
  U.Text("СООБЩЕНИЯ","STALKER.Small",px(16),px(6),"muted")
  U.Text(n>0 and ("Непрочитанных: "..n) or "Новых сообщений нет","STALKER.Body",px(16),px(24),n>0 and "accent" or "text")
 end)
 mail.Think=function(self) self.Active=(P.Unread or 0)>0 end
 local open=U.Button(mail,"Открыть",function() P.Select("messages") end,"accent");open:Dock(RIGHT);open:SetWide(px(140));open:DockMargin(0,px(10),px(10),px(10))
 -- Последние новости.
 W.Head(sc,"Последние новости")
 W.Card(sc,128,function(_,w,h)
  local feed=C.NewsFeed or {}
  if #feed==0 then U.Text("Лента пуста: сеть КПК молчит.","STALKER.Small",px(16),h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);return end
  for i=1,math.min(5,#feed) do
   local e=feed[i];local y=px(8)+(i-1)*px(23)
   local title,token=P.NewsKind(e.kind)
   U.Text(P.Clock(e.t),"STALKER.Mono",px(16),y,"muted")
   U.Text(title,"STALKER.Small",px(70),y,token)
   U.Text(U.Fit(tostring(e.text or ""),"STALKER.Small",w-px(190)),"STALKER.Small",px(170),y,"text")
  end
 end)
 local all=W.Button(sc,"Вся лента новостей",function() P.Select("news") end)
 all:DockMargin(0,0,0,px(4))
end})

--[[ Новости: фильтр по виду и полная лента (60 последних записей ядра) ]]
P.NewsFilters={{"Все",nil},{"Выбросы",{emission=true}},{"События",{event=true}},{"Война",{war=true,capture=true}},{"Задания",{quest=true}},
 {"Торговля",{trade=true}},{"Прочее",{info=true,ok=true,warn=true,danger=true}}}
function P.FilterNews(filter)
 local out={}
 for _,e in ipairs(C.NewsFeed or {}) do if type(e)=="table" and (not filter or filter[e.kind or "info"]) then out[#out+1]=e end end
 return out
end
P.AddTab("news",{title="Новости",order=30,build=function(parent)
 local bar=W.Blank(parent,TOP);bar:SetTall(px(32));bar:DockMargin(0,0,0,px(8))
 local sc=W.Scroll(parent)
 local current=P.NewsFilter or 1
 local function fill()
  sc:Clear()
  local list=P.FilterNews(P.NewsFilters[current] and P.NewsFilters[current][2])
  if #list==0 then W.Text(sc,"Записей нет.","muted");return end
  for _,e in ipairs(list) do
   local title,token=P.NewsKind(e.kind)
   W.TextCard(sc,{head=title,headToken=token,right=P.Ago(e.t),text=tostring(e.text or ""),color=T.C[token]})
  end
 end
 for i,f in ipairs(P.NewsFilters) do
  local b=U.Button(bar,f[1],function(self) current=i;P.NewsFilter=i;fill() end);b:Dock(LEFT);b:SetWide(px(104));b:DockMargin(0,0,px(6),0)
  b.Think=function(self) self.Active=current==i end
 end
 fill()
 parent.PDARefresh={news=fill}
end})
hook.Add("STALKER_NewsUpdated","STALKER_PDA.News",function() P.Refresh("news") end)

--[[ Статистика: свои счётчики и топ-10 по выбранному ключу (запрос STALKER_CORE.RequestStats) ]]
P.StatOrder={"playtime","kills","deaths","mutants","artifacts","emissions","quests","events","captures","stashes","crafted","cooked","earned"}
function P.StatKeys(names)
 names=names or C.StatNames or {}
 local out,seen={},{}
 for _,k in ipairs(P.StatOrder) do if names[k] then out[#out+1]=k;seen[k]=true end end
 local rest={};for k in pairs(names) do if not seen[k] then rest[#rest+1]=k end end
 table.sort(rest);for _,k in ipairs(rest) do out[#out+1]=k end
 return out
end
function P.FormatStat(key,v)
 v=tonumber(v) or 0
 if key=="playtime" then return v<60 and (math.floor(v).." мин") or (math.floor(v/60).." ч "..math.floor(v%60).." мин") end
 if key=="earned" then return P.Money(v) end
 return string.Comma(math.floor(v))
end
function P.StatName(key) local n=C.StatNames and C.StatNames[key];return type(n)=="string" and n or key end
-- Имя в топе: в сети — как его видит игрок (знакомства), иначе имя от сервера или отметка «не в сети».
function P.TopName(row)
 local p=C.PlayerBySID(tostring(row.sid or ""))
 if IsValid(p) then return P.NameFor(LocalPlayer(),p) or p:Nick() end
 return type(row.name)=="string" and row.name or "Сталкер (не в сети)"
end
function P.RequestStats(key)
 P.StatsKey=key or P.StatsKey or "kills"
 if C.RequestStats then C.RequestStats(P.StatsKey,function(d) P.StatsData=d;P.Refresh("stats") end) end
end
hook.Add("STALKER_StatsUpdated","STALKER_PDA.Stats",function(d) if type(d)=="table" then P.StatsData=d;P.Refresh("stats") end end)

local function statRow(parent,label,value,token,highlight)
 local r=vgui.Create("DPanel",parent);r:Dock(TOP);r:SetTall(px(28));r:DockMargin(0,0,0,px(2))
 r.Paint=function(_,w,h)
  if highlight then surface.SetDrawColor(T.C.accent.r,T.C.accent.g,T.C.accent.b,30);surface.DrawRect(0,0,w,h) end
  U.Text(U.Fit(label,"STALKER.Body",w*.62),"STALKER.Body",px(8),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  U.Text(value,"STALKER.Mono",w-px(8),h/2,token or "accent2",TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
  surface.SetDrawColor(T.C.line.r,T.C.line.g,T.C.line.b,70);surface.DrawRect(0,h-1,w,1)
 end
 return r
end
P.AddTab("stats",{title="Статистика",order=40,build=function(parent)
 local bar=W.Blank(parent,TOP);bar:SetTall(px(32));bar:DockMargin(0,0,0,px(8))
 bar.Paint=function(_,w,h) U.Text("Рейтинг по показателю:","STALKER.Body",0,h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
 local combo=vgui.Create("DComboBox",bar);combo:Dock(LEFT);combo:SetWide(px(280));combo:DockMargin(px(200),0,0,0);U.Combo(combo,"stalker_pda")
 local refresh=U.Button(bar,"Обновить",function() P.RequestStats(P.StatsKey) end);refresh:Dock(LEFT);refresh:SetWide(px(130));refresh:DockMargin(px(8),0,0,0)
 local holder=W.Blank(parent,FILL)
 local left=vgui.Create("DPanel",holder);left:Dock(LEFT);left:DockPadding(px(10),px(32),px(10),px(10))
 left.Paint=function(_,w,h) U.Panel("",0,0,w,h,false);U.Text("МОИ ПОКАЗАТЕЛИ","STALKER.Small",px(12),px(10),"muted") end
 local right=vgui.Create("DPanel",holder);right:Dock(FILL);right:DockMargin(px(10),0,0,0);right:DockPadding(px(10),px(32),px(10),px(10))
 right.Paint=function(_,w,h) U.Panel("",0,0,w,h,false);U.Text("ТОП-10: "..P.StatName(P.StatsKey or "kills"),"STALKER.Small",px(12),px(10),"muted") end
 holder.PerformLayout=function(_,w) left:SetWide(math.floor(w/2-px(5))) end
 local mine,top=W.Scroll(left),W.Scroll(right)
 local function fill()
  mine:Clear();top:Clear()
  local d=P.StatsData
  if not d then W.Text(mine,"Запрос данных…","muted");return end
  local names=type(d.names)=="table" and d.names or C.StatNames or {}
  local stats=type(d.mine)=="table" and d.mine or {}
  for _,k in ipairs(P.StatKeys(names)) do statRow(mine,names[k] or k,P.FormatStat(k,stats[k]),(tonumber(stats[k]) or 0)>0 and "accent2" or "muted") end
  local t=type(d.top)=="table" and d.top
  if not t or type(t.list)~="table" or #t.list==0 then W.Text(top,"Пока никто не отличился.","muted");return end
  local me=IsValid(LocalPlayer()) and LocalPlayer():SteamID64()
  for i,row in ipairs(t.list) do
   if type(row)=="table" then statRow(top,i..". "..P.TopName(row),P.FormatStat(t.key,row.value),i<=3 and "accent" or "text",row.sid==me) end
  end
 end
 local keys=P.StatKeys()
 if #keys==0 then keys=P.StatOrder end
 for _,k in ipairs(keys) do combo:AddChoice(P.StatName(k),k,k==(P.StatsKey or "kills")) end
 combo.OnSelect=function(_,_,_,key) P.RequestStats(key) end
 parent.PDARefresh={stats=function()
  fill()
  -- Подписи счётчиков пришли с сервера — обновляем список выбора один раз.
  if not combo.Filled and C.StatNames then combo.Filled=true;combo:Clear()
   for _,k in ipairs(P.StatKeys()) do combo:AddChoice(P.StatName(k),k,k==P.StatsKey) end
  end
 end}
 fill();P.RequestStats(P.StatsKey or "kills")
end})
