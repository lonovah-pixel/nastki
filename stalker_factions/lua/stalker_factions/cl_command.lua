--[[ Меню командования группировкой (лидер и офицеры): обзор, состав, казна, способности, дипломатия, вступление.
 Окно строится на STALKER_STYLE.Window; все действия уходят на сервер (stfw.cmd) и там же проверяются. ]]
local F=STFW
local U=STALKER_STYLE

--[[ Общие элементы новых окон группировок (используются и в окнах вступления и вкладке КПК). ]]
F.UI=F.UI or {}
local W=F.UI
local function px(n) local T=STALKER_THEME;return T and T.Px and T.Px(n) or n end
local function tc(token) local T=STALKER_THEME;return T and T.C and T.C[token] or F.C[token] or F.C.text end
W.Px=px;W.Color=tc
function W.Scroll(parent) local s=vgui.Create("DScrollPanel",parent);s:Dock(FILL);U.Scroll(s);return s end
function W.Columns(parent,leftWide)
 local l=vgui.Create("DScrollPanel",parent);l:Dock(LEFT);l:SetWide(px(leftWide or 400));l:DockMargin(0,0,px(14),0);U.Scroll(l)
 local r=vgui.Create("DScrollPanel",parent);r:Dock(FILL);U.Scroll(r);return l,r
end
function W.Head(parent,text) local l=U.Label(parent,text,"STALKER.Head","accent");l:Dock(TOP);l:DockMargin(0,px(6),0,px(6));return l end
function W.Text(parent,text,token,font) local l=U.Label(parent,text,font or "STALKER.Body",token or "text");l:Dock(TOP);l:DockMargin(0,0,0,px(6));return l end
function W.Card(parent,h,paint)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(h));p:DockMargin(0,0,0,px(6))
 p.Paint=function(self,w,hh) U.Panel("",0,0,w,hh,self.Active);if paint then paint(self,w,hh) end end
 return p
end
function W.Row(parent,h) local r=vgui.Create("DPanel",parent);r:Dock(TOP);r:SetTall(px(h or 32));r:DockMargin(0,0,0,px(6));r.Paint=nil;return r end
function W.Button(parent,label,fn,kind) local b=U.Button(parent,label,fn,kind);b:Dock(TOP);b:DockMargin(0,0,0,px(6));return b end
function W.Entry(parent,placeholder,numeric)
 local e=vgui.Create("DTextEntry",parent);e:SetTall(px(30));U.Entry(e,"")
 if placeholder then e:SetPlaceholderText(placeholder) end;if numeric then e:SetNumeric(true) end
 return e
end
function W.Combo(parent,placeholder,choices)
 local c=vgui.Create("DComboBox",parent);c:SetTall(px(30));U.Combo(c,"");c:SetValue(placeholder or "")
 for _,ch in ipairs(choices or {}) do c:AddChoice(ch[1],ch[2]) end
 c.OnSelect=function(_,_,_,v) c.Value=v end;return c
end
function W.Time(sec)
 sec=math.max(0,math.floor(sec or 0))
 if sec>=3600 then return string.format("%d ч %02d мин",math.floor(sec/3600),math.floor(sec%3600/60)) end
 return string.format("%d:%02d",math.floor(sec/60),sec%60)
end
-- Секунды, оставшиеся по снимку сервера (снимок приходит раз в 3 с).
function W.Left(sec) return math.max(0,(tonumber(sec) or 0)-(CurTime()-(F.StateAt or CurTime()))) end
function W.Toast(text,kind)
 local C=STALKER_CORE;if C and C.Toast then C.Toast(text,kind or "warn",4) else notification.AddLegacy(text,NOTIFY_ERROR,4) end
end
function F.Cmd(op,data) data=data or {};data.op=op;F.SendJSON("stfw.cmd",nil,data) end
local function amount(entry)
 local n=math.floor(tonumber(entry:GetValue()) or 0)
 if n<1 then W.Toast(F.L("amount_invalid"));return end
 return n
end

local pages={}
pages.overview=function(body,s,cmd)
 local left,right=W.Columns(body,420)
 W.Head(left,"Казна и доход")
 W.Card(left,92,function(_,w,h)
  U.Text("КАЗНА","STALKER.Small",px(12),px(8),"muted")
  U.Text(cmd.treasury and F.Money(cmd.treasury) or "видна лидеру","STALKER.Big",px(12),px(26),"accent")
  U.Text("Очки снабжения: "..(cmd.credits or 0),"STALKER.Small",w-px(12),px(8),"text",TEXT_ALIGN_RIGHT)
 end)
 local inc=cmd.income or {}
 W.Card(left,86,function(_,w,h)
  U.Text("ДОХОД ЗА "..W.Time(inc.interval or 60),"STALKER.Small",px(12),px(8),"muted")
  U.Text("+"..F.Money(inc.money or 0).."   ·   +"..(inc.supply or 0).." снабжения","STALKER.Head",px(12),px(28),"ok")
  U.Text("Точек: "..(inc.held or 0)..(inc.last and ("   ·   последний доход "..F.Money(inc.last)) or ""),"STALKER.Small",px(12),h-px(24),"muted")
 end)
 W.Card(left,60,function(_,w,h)
  U.Text("СОСТАВ","STALKER.Small",px(12),px(8),"muted")
  U.Text((cmd.count or 0)..((cmd.cap or 0)>0 and (" / "..cmd.cap) or "").."   ·   в сети "..(cmd.online or 0),"STALKER.Head",px(12),px(28),"text")
 end)
 if s.me.faction=="loner" then W.Text(left,"Доход точек одиночек не копится в казне: он делится поровну между одиночками в сети.","muted","STALKER.Small") end
 local buffLeft=W.Left((cmd.buffs or {}).mobilize)
 if buffLeft>0 then W.Text(left,"Мобилизация активна: захват быстрее ещё "..W.Time(buffLeft),"warn","STALKER.Small") end
 W.Head(right,"Территории группировки")
 local owned=0
 for id,pt in SortedPairs(s.points or {}) do if pt.owner==s.me.faction then
  owned=owned+1;local point=pt
  W.Card(right,58,function(_,w,h)
   U.Text(point.name,"STALKER.Body",px(12),px(6),"text")
   U.Text(F.Text(F.PointTypes[point.kind or "checkpoint"] or "")..(point.base and " · база" or "").."   ·   +"..F.Money(F.Config.PointIncome[point.kind or "checkpoint"] or 0),"STALKER.Small",px(12),px(30),"muted")
   local status,token="Под контролем","ok"
   if point.contested then status,token="Оспаривается","warn" elseif point.armed then status,token="Захват: "..F.Name(point.armed).." "..math.floor((point.progress or 0)*100).."%","danger" end
   U.Text(status,"STALKER.Small",w-px(12),px(8),token,TEXT_ALIGN_RIGHT)
  end)
 end end
 if owned==0 then W.Text(right,"Группировка не удерживает точек. Начните захват: удерживайте E на флаге ничьей точки или точки врага во время войны.","muted","STALKER.Small") end
 W.Head(right,"Войны")
 local wars=0
 for key,r in pairs(s.relations or {}) do
  local a,b=key:match("^([^:]+):([^:]+)$")
  if r.war and (a==s.me.faction or b==s.me.faction) then
   wars=wars+1;local other=a==s.me.faction and b or a;local sc=r.scores or {}
   W.Text(right,"Война с «"..F.Name(other).."» — счёт "..(sc[s.me.faction] or 0).." : "..(sc[other] or 0).." (до "..F.Config.VictoryScore..")","danger","STALKER.Small")
  end
 end
 if wars==0 then W.Text(right,"Войн нет.","muted","STALKER.Small") end
end

local function myRank(s) return s.me.role=="leader" and 100 or (s.me.frank or 1) end
local function inviteBlock(parent,cmd)
 local choices={};for _,c in ipairs(cmd.candidates or {}) do if not c.banned then choices[#choices+1]={c.name..(c.faction and (" · "..F.Name(c.faction)) or ""),c.sid} end end
 local row=W.Row(parent,32)
 local combo=W.Combo(row,#choices>0 and "Игрок в сети" or "Нет игроков для приглашения",choices);combo:Dock(FILL);combo:DockMargin(0,0,px(6),0)
 local b=U.Button(row,"Пригласить",function() if not combo.Value then W.Toast("Выберите игрока");return end;F.Cmd("invite",{sid=combo.Value}) end,"accent")
 b:Dock(RIGHT);b:SetWide(px(130))
 W.Text(parent,"Приглашённый получит окно на "..F.Config.InviteSeconds.." с и вступит без взноса, если в группировке есть место.","muted","STALKER.Small")
end
pages.roster=function(body,s,cmd)
 local left,right=W.Columns(body,620)
 W.Head(left,"Состав: "..(cmd.count or 0)..((cmd.cap or 0)>0 and (" / "..cmd.cap) or ""))
 local mine=myRank(s);local leader=cmd.role=="leader"
 for _,m in ipairs(cmd.roster or {}) do
  local member=m
  local card=W.Card(left,50,function(_,w,h)
   surface.SetDrawColor(member.online and tc("ok") or tc("muted"));surface.DrawRect(px(10),h/2-px(4),px(8),px(8))
   U.Text(member.name,"STALKER.Body",px(26),px(5),"text")
   U.Text((member.leader and "Лидер" or F.FRankName(member.frank)).."   ·   XP "..(member.xp or 0)..(member.online and "   ·   в сети" or ""),"STALKER.Small",px(26),px(27),member.leader and "accent" or "muted")
  end)
  local theirs=member.leader and 100 or (member.frank or 1)
  if member.sid~=LocalPlayer():SteamID64() and theirs<mine then
   local kick=U.Button(card,"Исключить",function()
    Derma_Query("Исключить "..member.name.." из группировки?","Состав","Исключить",function() F.Cmd("kick",{sid=member.sid}) end,"Отмена")
   end,"danger")
   kick:Dock(RIGHT);kick:SetWide(px(110));kick:DockMargin(px(4),px(9),px(8),px(9))
  end
  if leader and not member.leader then
   local down=U.Button(card,"▼",function() F.Cmd("rank",{sid=member.sid,delta=-1}) end);down:Dock(RIGHT);down:SetWide(px(36));down:DockMargin(px(4),px(9),0,px(9));down:SetEnabled((member.frank or 1)>1)
   local up=U.Button(card,"▲",function() F.Cmd("rank",{sid=member.sid,delta=1}) end);up:Dock(RIGHT);up:SetWide(px(36));up:DockMargin(px(4),px(9),0,px(9));up:SetEnabled((member.frank or 1)<#F.FactionRanks)
  end
 end
 W.Head(right,"Пригласить")
 inviteBlock(right,cmd)
 W.Head(right,"Звания")
 for i,name in ipairs(F.FactionRanks) do W.Text(right,i..". "..name..(i>=F.OfficerRank and " — приглашает и исключает младших, применяет способности офицеров" or ""),i>=F.OfficerRank and "text" or "muted","STALKER.Small") end
 W.Text(right,leader and "Звания меняет лидер (кнопки ▲ ▼), в том числе у бойцов не в сети." or "Звания меняет лидер группировки.","muted","STALKER.Small")
end

pages.treasury=function(body,s,cmd)
 local left,right=W.Columns(body,440)
 W.Head(left,"Казна")
 W.Card(left,70,function(_,w,h) U.Text(F.Money(cmd.treasury or 0),"STALKER.Big",px(12),px(16),"accent") end)
 W.Text(left,"Снять себе в кошелёк","text","STALKER.Small")
 local row=W.Row(left,32)
 local sum=W.Entry(row,"Сумма, ₽",true);sum:Dock(FILL);sum:DockMargin(0,0,px(6),0)
 local b=U.Button(row,"Снять",function() local n=amount(sum);if n then F.Cmd("withdraw",{amount=n}) end end,"accent");b:Dock(RIGHT);b:SetWide(px(120))
 W.Text(left,"Выплатить бойцу в сети","text","STALKER.Small")
 local choices={};for _,m in ipairs(cmd.roster or {}) do if m.online then choices[#choices+1]={m.name.." · "..(m.leader and "Лидер" or F.FRankName(m.frank)),m.sid} end end
 local who=W.Combo(left,"Боец в сети",choices);who:Dock(TOP);who:DockMargin(0,0,0,px(6))
 local row2=W.Row(left,32)
 local pay=W.Entry(row2,"Сумма, ₽",true);pay:Dock(FILL);pay:DockMargin(0,0,px(6),0)
 local b2=U.Button(row2,"Выплатить",function()
  if not who.Value then W.Toast("Выберите бойца");return end
  local n=amount(pay);if n then F.Cmd("payout",{sid=who.Value,amount=n}) end
 end,"accent");b2:Dock(RIGHT);b2:SetWide(px(120))
 W.Text(left,"Казну пополняют удерживаемые точки раз в "..W.Time(F.Config.IncomeInterval)..", пока в группировке есть живой боец в сети.","muted","STALKER.Small")
 W.Head(right,"Журнал операций")
 local ledger=cmd.ledger or {}
 if #ledger==0 then W.Text(right,"Операций пока не было.","muted","STALKER.Small") end
 local names={income="Доход территорий",withdraw="Снятие",payout="Выплата"}
 for i=#ledger,1,-1 do
  local e=ledger[i]
  W.Card(right,46,function(_,w,h)
   U.Text((names[e.kind] or e.kind or "")..(e.n and e.n>1 and (" ×"..e.n) or "")..(e.note and e.kind~="income" and (" · "..e.note) or ""),"STALKER.Body",px(12),px(4),"text")
   U.Text(os.date("%d.%m %H:%M",e.t or 0)..(e.who and ("   ·   "..e.who) or ""),"STALKER.Small",px(12),px(25),"muted")
   U.Text(((e.amount or 0)>=0 and "+" or "")..F.Money(e.amount or 0),"STALKER.Head",w-px(12),px(12),(e.amount or 0)>=0 and "ok" or "danger",TEXT_ALIGN_RIGHT)
  end)
 end
end

pages.abilities=function(body,s,cmd)
 local left,right=W.Columns(body,cmd.role=="leader" and 600 or 900)
 W.Head(left,"Способности командования")
 W.Text(left,"Очки снабжения: "..(cmd.credits or 0)..". Способность можно повесить на клавишу: bind <клавиша> \"stfw_ability <id>\" или написать в чат !ability <id>.","muted","STALKER.Small")
 -- Перезарядки — из последнего снимка: их нет в отпечатке окна, вкладка не перестраивается, а F.StateAt
 -- обновляется каждые 3 с — с перезарядкой из снимка постройки кнопка оставалась бы неактивной навсегда.
 local function live() local c=F.State and F.State.command;return c or cmd end
 for _,id in ipairs(F.AbilityOrder) do
  local a=F.Abilities[id];local ability=id
  local allowed=cmd.role=="leader" or a.minRank~="leader"
  local card=W.Card(left,84,function(_,w,h)
   U.Text(a.name.."  ("..ability..")","STALKER.Head",px(12),px(6),allowed and "accent" or "muted")
   local lines=U.Wrap(a.description,"STALKER.Small",w-px(170))
   for i=1,math.min(2,#lines) do U.Text(lines[i],"STALKER.Small",px(12),px(26)+(i-1)*px(15),"text") end
   local cd=W.Left((live().cooldowns or {})[ability])
   U.Text("Стоимость "..a.cost.."  ·  перезарядка "..W.Time(a.cooldown)..(a.minRank=="leader" and "  ·  только лидер" or ""),"STALKER.Small",px(12),h-px(20),"muted")
   if cd>0 then U.Text("Готово через "..W.Time(cd),"STALKER.Small",w-px(12),px(8),"warn",TEXT_ALIGN_RIGHT) end
  end)
  local b=U.Button(card,"Применить",function() F.Cmd("ability",{id=ability}) end,"accent")
  b:Dock(RIGHT);b:SetWide(px(130));b:DockMargin(px(6),px(24),px(10),px(24))
  b.Think=function(self) local c=live();self:SetEnabled(allowed and W.Left((c.cooldowns or {})[ability])<=0 and (c.credits or 0)>=a.cost) end
 end
 if cmd.role~="leader" then return end
 W.Head(right,"Развитие группировки")
 W.Text(right,F.L("supply_help"),"muted","STALKER.Small")
 for key,cfg in SortedPairs(F.Upgrades) do
  local id=key;local level=F.UpgradeLevel(s,s.me.faction,id);local price=cfg.costs[level+1]
  W.Card(right,58,function(_,w,h)
   U.Text(F.Text(cfg.name).."  ·  "..level.." / "..#cfg.costs,"STALKER.Body",px(12),px(6),"text")
   U.Text(F.Text(cfg.description),"STALKER.Small",px(12),px(30),"muted")
  end)
  local b=W.Button(right,price and (F.L("upgrade_buy").." — "..price.." снабжения") or F.L("upgrade_max"),function()
   Derma_Query(F.Text(cfg.name).." — "..tostring(price).." очков снабжения",F.L("upgrade_buy"),F.L("accept"),function() F.Action({kind="upgrade",upgrade=id,level=level}) end,F.L("close"))
  end)
  b:SetEnabled(price~=nil and (cmd.credits or 0)>=price)
 end
end

-- Дипломатия: прежняя логика переговоров лидера (предложения, война, ответы).
pages.diplomacy=function(body,s,cmd)
 local me=s.me;local left,right=W.Columns(body,380)
 local function act(a) F.Action(a) end
 local function button(parent,text,fn) return W.Button(parent,text,fn) end
 W.Head(left,F.L("target"));local target=F.Combo(left,me.faction=="duty" and "freedom" or "duty");local points=F.DiplomacySlider(left,0)
 F.RelationCard(right,me.faction,function() return target.StfwValue end)
 local peace=vgui.Create("DCheckBoxLabel",left);peace:Dock(TOP);peace:SetTall(px(32));peace:SetText(F.L("peace"));peace:SetTextColor(tc("text"));peace:SetValue(true)
 button(left,F.L("send"),function() act({kind="diplomacy",op="propose",from=me.faction,to=target.StfwValue,points=math.Round(points:GetValue()),peace=peace:GetChecked()}) end)
 button(left,F.L("start"),function() Derma_Query(F.L("start").." / "..F.Name(target.StfwValue),F.L("diplomacy"),F.L("accept"),function() act({kind="diplomacy",op="war",from=me.faction,to=target.StfwValue}) end,F.L("close")) end)
 W.Head(right,F.L("pending"))
 local any=false
 for _,proposal in pairs(s.proposals or {}) do local p=proposal
  if p.from==me.faction or p.to==me.faction then
   any=true
   W.Text(right,F.Name(p.from).." → "..F.Name(p.to).."  ·  "..p.points.."  ·  "..(p.peace and F.L("peace") or "без мира"),"text","STALKER.Small")
   if p.to==me.faction then
    button(right,F.L("accept"),function() act({kind="diplomacy",op="accept",from=p.to,to=p.from,token=p.token}) end)
    button(right,F.L("reject"),function() act({kind="diplomacy",op="reject",from=p.to,to=p.from,token=p.token}) end)
    button(right,F.L("counter"),function() target.StfwValue=p.from;target:SetValue(F.Name(p.from));points:SetValue(p.points);peace:SetValue(p.peace) end)
   end
  end
 end
 if not any then W.Text(right,"Предложений нет.","muted","STALKER.Small") end
end

pages.admission=function(body,s,cmd)
 local leader=cmd.role=="leader"
 local left,right=W.Columns(body,leader and 480 or 900)
 W.Head(left,"Состав и вступление")
 local full=(cmd.cap or 0)>0 and (cmd.count or 0)>=(cmd.cap or 0)
 W.Text(left,"Состав: "..(cmd.count or 0)..((cmd.cap or 0)>0 and (" / "..cmd.cap) or " (без лимита)")..(full and " — группировка заполнена, вступить нельзя." or "."),full and "warn" or "text","STALKER.Small")
 W.Text(left,"Вступить можно у вербовщика (взнос "..F.Money(F.JoinFee(s.me.faction))..") или по приглашению.","muted","STALKER.Small")
 W.Head(left,"Приглашение")
 inviteBlock(left,cmd)
 if not leader then return end
 W.Head(left,"Допуски на бесплатное вступление")
 W.Text(left,"Допуск действует "..W.Time(F.Config.ApprovalLifetime).." у вербовщика вашей группировки.","muted","STALKER.Small")
 for _,a in ipairs(cmd.approvals or {}) do
  local grant=a
  local card=W.Card(left,40,function(_,w,h) U.Text(grant.name.."  ·  ещё "..W.Time(grant.expires),"STALKER.Small",px(12),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end)
  local b=U.Button(card,"Отозвать",function() F.Cmd("revoke",{sid=grant.sid}) end);b:Dock(RIGHT);b:SetWide(px(110));b:DockMargin(0,px(5),px(6),px(5))
 end
 local choices={};for _,c in ipairs(cmd.candidates or {}) do if not c.banned then choices[#choices+1]={c.name,c.sid} end end
 local row=W.Row(left,32)
 local combo=W.Combo(row,"Игрок в сети",choices);combo:Dock(FILL);combo:DockMargin(0,0,px(6),0)
 local grant=U.Button(row,"Выдать допуск",function() if combo.Value then F.Cmd("approve",{sid=combo.Value}) end end);grant:Dock(RIGHT);grant:SetWide(px(150))

 W.Head(right,"Запрет вступления")
 W.Text(right,"Один запрет на лидера: игрок не сможет вступить в группировку, пока вы остаётесь лидером. Цена — "..F.Money(cmd.banCost or F.Config.LeaderBanCost).." из вашего кошелька, без возврата. Запрещённый член группировки исключается сразу.","muted","STALKER.Small")
 if cmd.ban then
  local ban=cmd.ban
  W.Card(right,58,function(_,w,h)
   U.Text("Запрещено: "..tostring(ban.name),"STALKER.Head",px(12),px(6),"danger")
   U.Text(tostring(ban.sid).."   ·   с "..os.date("%d.%m.%Y",ban.t or 0),"STALKER.Small",px(12),px(32),"muted")
  end)
  W.Button(right,"Снять запрет (деньги не возвращаются)",function()
   Derma_Query("Снять запрет с "..tostring(ban.name).."? Слот освободится, деньги не вернутся.","Запрет вступления","Снять",function() F.Cmd("unban") end,"Отмена")
  end,"danger")
  return
 end
 local options={}
 for _,m in ipairs(cmd.roster or {}) do if not m.leader then options[#options+1]={m.name.." · член группировки",m.sid} end end
 for _,c in ipairs(cmd.candidates or {}) do options[#options+1]={c.name,c.sid} end
 local pick=W.Combo(right,"Кого запретить",options);pick:Dock(TOP);pick:DockMargin(0,0,0,px(6))
 local sid=W.Entry(right,"или SteamID64 игрока не в сети");sid:Dock(TOP);sid:DockMargin(0,0,0,px(6))
 W.Button(right,"Запретить вступление за "..F.Money(cmd.banCost or F.Config.LeaderBanCost),function()
  local target=F.ValidSID(sid:GetValue()) and sid:GetValue() or pick.Value
  if not target then W.Toast("Выберите игрока или введите SteamID64");return end
  Derma_Query("Запретить вступление игроку "..target.." за "..F.Money(cmd.banCost or F.Config.LeaderBanCost).."?","Запрет вступления","Запретить",function() F.Cmd("ban",{sid=target}) end,"Отмена")
 end,"danger")
end
F.CommandPages=pages

F.CommandTabs={{id="overview",title="Обзор"},{id="roster",title="Состав"},{id="treasury",title="Казна",leader=true},{id="abilities",title="Способности"},
 {id="diplomacy",title="Дипломатия",leader=true},{id="admission",title="Вступление"}}
-- Отпечаток данных меню: окно перестраивается только при реальных изменениях (не каждые 3 секунды).
-- Точки нужны только «Обзору»: прогресс захвата меняется каждую секунду, и на других вкладках окно
-- перестраивалось бы с каждым снимком, сбрасывая выбранного бойца или игрока в списках.
local function hash(state)
 local c=state and state.command;if not c then return "" end
 return util.TableToJSON({c.roster,c.candidates,c.treasury,c.ledger,c.ban,c.approvals,c.credits,c.count,c.cap,c.role,state.proposals,F.CommandCurrent=="overview" and state.points or nil}) or ""
end
function F.CommandTab(id)
 local f=F.CommandFrame;if not IsValid(f) then return end
 local s=F.State;local cmd=s and s.command;if not cmd then f:Remove();return end
 if not f.Tabs[id] then id="overview" end
 F.CommandCurrent=id;f.Hash=hash(s)
 for key,b in pairs(f.Tabs) do b.Active=key==id end
 f.Body:Clear()
 local ok,err=pcall(pages[id],f.Body,s,cmd)
 if not ok then ErrorNoHalt("[STFW] command page "..id..": "..tostring(err).."\n") end
end
function F.OpenCommand(tab)
 if not U or not U.Window then return F.Open() end
 local cmd=F.State and F.State.command
 if not cmd then F.Request();W.Toast("Меню командования доступно лидеру и офицерам группировки");return end
 if IsValid(F.CommandFrame) then F.CommandFrame:Remove() end
 if IsValid(F.Frame) then F.Frame:Remove() end
 local f=U.Window({title="КОМАНДОВАНИЕ — "..F.Name(F.State.me.faction)..(cmd.role=="leader" and "  ·  ЛИДЕР" or "  ·  ОФИЦЕР"),w=1100,h=700})
 F.CommandFrame=f
 local bar=vgui.Create("DPanel",f);bar:Dock(TOP);bar:SetTall(px(32));bar:DockMargin(0,0,0,px(10));bar.Paint=nil
 f.Tabs={}
 for _,t in ipairs(F.CommandTabs) do
  if not t.leader or cmd.role=="leader" then
   local id=t.id;local b=U.Button(bar,t.title,function() F.CommandTab(id) end)
   b:Dock(LEFT);b:SetWide(px(140));b:DockMargin(0,0,px(6),0);f.Tabs[id]=b
  end
 end
 local back=U.Button(bar,"Сеть группировок",function() F.Open() end);back:Dock(RIGHT);back:SetWide(px(170))
 f.Body=vgui.Create("DPanel",f);f.Body:Dock(FILL);f.Body.Paint=nil
 F.CommandTab(tab or F.CommandCurrent or "overview")
 return f
end
hook.Add("STFW_StateUpdated","STFW.Command",function(state)
 local f=F.CommandFrame;if not IsValid(f) then return end
 if not state.command then f:Remove();return end
 local h=hash(state);local reply=state.reply and state.reply.cmd
 if h==f.Hash and not reply then return end
 f.Hash=h
 -- Не сбиваем ввод: пока фокус в поле окна, перестраиваем только по ответу на действие.
 local focus=vgui.GetKeyboardFocus()
 if reply or not (IsValid(focus) and focus.HasParent and focus:HasParent(f)) then F.CommandTab(F.CommandCurrent or "overview") end
end)
hook.Add("STFW_ThemeChanged","STFW.Command",function() if IsValid(F.CommandFrame) then F.CommandTab(F.CommandCurrent or "overview") end end)
