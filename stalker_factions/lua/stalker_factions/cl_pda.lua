--[[ Вкладка КПК «Группировка» и раздел группировок в общей админ-панели (STFW.BuildAdminPanel). ]]
local F=STFW
local U=STALKER_STYLE
local W=F.UI
local function px(n) return W and W.Px and W.Px(n) or n end

-- Вкладка ждёт первый снимок сервера и перестраивается, когда он придёт.
local function waitState(parent,build)
 F.Request()
 W.Text(parent,"Связь с сетью группировок…","muted")
 parent.Think=function(self) if F.State then self.Think=nil;self:Clear();build(self) end end
end

function F.BuildPDATab(parent)
 if not U or not U.Panel or not W then return end
 if not F.State then return waitState(parent,F.BuildPDATab) end
 local s=F.State;local me=s.me;local cmd=s.command
 local sc=W.Scroll(parent)
 local faction=F.Factions[me.faction] or {}
 local _,xpRank=F.Rank(me.xp or 0)
 W.Card(sc,84,function(_,w,h)
  if F.Emblem then F.Emblem(me.faction,px(10),px(10),h-px(20)) end
  U.Text(me.joined and F.Name(me.faction) or "Вольный сталкер","STALKER.Title",h+px(4),px(8),"accent")
  local rank=me.joined and (s.role=="leader" and "Лидер" or F.FRankName(me.frank)) or "не состоит в группировке"
  U.Text("Звание: "..rank.."   ·   "..(xpRank and xpRank[2] or "").." (XP "..(me.xp or 0)..")","STALKER.Small",h+px(4),px(40),"text")
  U.Text("Репутация: "..string.format("%+d",(me.rep or {})[me.faction] or 0).."   ·   захватов "..(me.captures or 0).."   ·   побед в бою "..(me.kills or 0),"STALKER.Small",h+px(4),px(58),"muted")
 end)
 if not me.joined then
  W.Text(sc,"Вступить в группировку можно у её вербовщика (подойдите к NPC и нажмите E) или по приглашению лидера — без взноса.","muted","STALKER.Small")
 else
  W.Text(sc,F.Text(faction.description),"muted","STALKER.Small")
  if s.count then W.Text(sc,"Состав: "..s.count..((s.cap or 0)>0 and (" / "..s.cap) or ""),"text","STALKER.Small") end
 end
 if cmd and cmd.treasury then
  W.Card(sc,58,function(_,w,h)
   U.Text("КАЗНА","STALKER.Small",px(12),px(6),"muted")
   U.Text(F.Money(cmd.treasury),"STALKER.Head",px(12),px(26),"accent")
   local inc=cmd.income or {}
   U.Text("+"..F.Money(inc.money or 0).." за "..W.Time(inc.interval or 60),"STALKER.Small",w-px(12),px(8),"ok",TEXT_ALIGN_RIGHT)
   U.Text("Снабжение: "..(cmd.credits or 0),"STALKER.Small",w-px(12),px(30),"text",TEXT_ALIGN_RIGHT)
  end)
 end
 W.Head(sc,"Территории")
 local owned,total=0,0
 for _,pt in SortedPairs(s.points or {}) do
  total=total+1
  if me.joined and pt.owner==me.faction then
   owned=owned+1;local point=pt
   W.Card(sc,40,function(_,w,h)
    U.Text(point.name,"STALKER.Body",px(12),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    local status,token="Под контролем","ok"
    if point.contested then status,token="Оспаривается","warn" elseif point.armed then status,token="Идёт захват: "..F.Name(point.armed),"danger" end
    U.Text(status,"STALKER.Small",w-px(12),h/2,token,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
   end)
  end
 end
 W.Text(sc,me.joined and ("Под контролем группировки: "..owned.." из "..total.." точек.") or ("Точек на карте: "..total.."."),"muted","STALKER.Small")
 W.Text(sc,"Захват начинается действием: удерживайте E на флаге точки (ничьей или врага во время войны), затем удерживайте зону.","muted","STALKER.Small")
 W.Button(sc,"Открыть сеть группировок (F6)",function() F.Open() end,"accent")
 if cmd then W.Button(sc,"Командование",function() F.OpenCommand() end) end
end
local C=STALKER_CORE
if C and C.RegisterPDATab then
 C.RegisterPDATab("factions",{title="Группировка",order=40,build=function(parent) F.BuildPDATab(parent) end,
  -- Значок: входящие дипломатические предложения лидеру.
  badge=function()
   local s=F.State;if not s or s.role~="leader" then return end
   local n=0;for _,p in pairs(s.proposals or {}) do if p.to==s.me.faction then n=n+1 end end
   return n>0 and n or nil
  end})
end

-- Раздел общей админ-панели: сводка и вход в редактор группировок.
function F.BuildAdminPanel(parent)
 if not U or not W then return end
 F.Request()
 local sc=W.Scroll(parent)
 W.Head(sc,"Группировки")
 W.Text(sc,"Точки и базы, флаги, вербовщики, лидеры, дипломатия и торговцы — в админ-панели группировок. Взносы, лимиты, доходы, время захвата и способности — в настройках, раздел «Группировки».","muted","STALKER.Small")
 W.Button(sc,"Открыть админ-панель группировок",function() F.Open("admin","admin") end,"accent")
 W.Button(sc,"Начислить доход территорий сейчас",function() RunConsoleCommand("stfw_income") end)
 W.Button(sc,"Обновить сводку",function() F.Request() end)
 local ids={};for id,f in pairs(F.Factions) do if f.playable then ids[#ids+1]=id end end;table.sort(ids)
 W.Card(sc,74,function(_,w,h)
  local s=F.State
  if not s or not s.admin then U.Text("Сводка доступна администратору группировок (право factions).","STALKER.Small",px(12),px(10),"muted");return end
  local points,owned,wars=0,0,0
  for _,pt in pairs(s.points or {}) do points=points+1;if pt.owner~="" then owned=owned+1 end end
  for _,r in pairs(s.relations or {}) do if r.war then wars=wars+1 end end
  U.Text("Точек: "..points.."   ·   с владельцем: "..owned.."   ·   войн: "..wars,"STALKER.Head",px(12),px(10),"text")
  U.Text("Флаги точек восстанавливаются автоматически при загрузке, правке и очистке карты.","STALKER.Small",px(12),px(42),"muted")
 end)
 W.Card(sc,30+#ids*20,function(_,w,h)
  local s=F.State;if not s or not s.summary then return end
  U.Text("ГРУППИРОВКА","STALKER.Small",px(12),px(8),"muted");U.Text("СОСТАВ","STALKER.Small",w*.45,px(8),"muted");U.Text("ЛИДЕР","STALKER.Small",w*.65,px(8),"muted")
  for i,id in ipairs(ids) do
   local y=px(8)+i*px(20)
   local n=s.summary.members[id] or 0;local cap=s.summary.caps[id] or 0
   U.Text(F.Name(id),"STALKER.Small",px(12),y,"text")
   U.Text(n..(cap>0 and (" / "..cap) or ""),"STALKER.Small",w*.45,y,cap>0 and n>=cap and "warn" or "text")
   local leader=s.leaders and s.leaders[id]
   local name;if leader then for _,m in ipairs(s.members or {}) do if m.sid==leader then name=m.name end end end
   U.Text(leader and (name or leader) or "—","STALKER.Small",w*.65,y,"muted")
  end
 end)
end
