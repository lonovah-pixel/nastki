-- «Комендант»: окно администрирования в теме сборки (STALKER_STYLE.Window, токены STALKER_THEME.C).
-- Слева личный состав, в центре разделы: команды, реестры, настройки сборки и вкладки других аддонов.
local A=STALKER_ADMIN
A.Selected=A.Selected or {};A.State=nil;A.PageNumber=1;A.Category=A.Category or "Дисциплина"
local frame,roster,body,result,search,form
-- Значения от Derma могут быть не числами/строками (заглушки в тестах) — приводим явно.
local function num(v,d) return type(v)=="number" and v or d end
local function str(v) return type(v)=="string" and v or "" end
local function Px(n) return A.Px(n) end

function A.Send(data)
 local raw=util.TableToJSON(data);if not raw or #raw>8192 then return end
 net.Start("sta.request");net.WriteUInt(#raw,16);net.WriteData(raw,#raw);net.SendToServer()
end
-- Строчные буквы с кириллицей (string.lower в Lua не знает UTF-8): для поиска по именам и настройкам.
function A.Lower(s)
 s=tostring(s or ""):lower()
 s=s:gsub("\208([\144-\175])",function(c) local b=c:byte();if b<160 then return "\208"..string.char(b+32) end;return "\209"..string.char(b-32) end)
 return (s:gsub("\208\129","\209\145"))
end
local function selectedIDs()
 local out={};for id,v in pairs(A.Selected) do if v then out[#out+1]=id end end;table.sort(out);return out
end
function A.Output(text,token)
 if not IsValid(result) then return end
 local c=A.C[token or "text"]
 result:InsertColorChange(c.r,c.g,c.b,255)
 result:AppendText(os.date("%H:%M:%S").."  "..tostring(text).."\n");result:GotoTextEnd()
end
local function roleLabel(id) return (A.Config.Roles[id] or A.Config.Roles.user).label end
local function myRank() return A.State and (A.Config.Roles[A.State.role] or A.Config.Roles.user).rank or 0 end
local function integration(key) return A.State and A.State.integrations and A.State.integrations[key]==true end

--[[ Личный состав ]]
function A.PaintRosterRow(p,w,h,selected,hover)
 A.PaintBox(0,0,w,h,selected or hover,selected)
 surface.SetDrawColor(p.alive and A.C.ok or A.C.danger);surface.DrawRect(0,0,Px(3),h)
 local x=Px(12)
 draw.SimpleText((selected and "[x] " or "[  ] ")..A.Fit(p.name,A.F.body,w-x-Px(40)),A.F.body,x,Px(5),selected and A.C.accent or A.C.text)
 draw.SimpleText(p.sid,A.F.mono,x,Px(25),A.C.muted)
 local group=(p.group and p.group~="") and ("  ·  ULX: "..p.group) or ""
 draw.SimpleText(A.Fit(roleLabel(p.role)..group,A.F.small,w-x-Px(64)),A.F.small,x,Px(42),A.C.accent)
 draw.SimpleText(tostring(p.ping).." мс",A.F.small,w-Px(8),Px(42),A.C.muted,TEXT_ALIGN_RIGHT)
 local state=(p.frozen and "  · заморожен" or "")..(p.god and "  · бессмертие" or "")
 draw.SimpleText(A.Fit("HP "..tostring(p.health).."  AR "..tostring(p.armor).."  Доза "..math.Round(num(p.dose,0)).."  "..tostring(p.faction)..state,A.F.small,w-x-Px(8)),A.F.small,x,Px(58),A.C.muted)
end
function A.Toggle(sid)
 if A.Selected[sid] then A.Selected[sid]=nil;return end
 local limit=A.State and A.State.limits and A.State.limits.targets or A.Config.MaxTargets
 if #selectedIDs()>=limit then A.Output("Можно отметить не больше "..limit.." игроков","warn");return end
 A.Selected[sid]=true
end
function A.PlayerInfo(p)
 A.Message("ЛИЧНОЕ ДЕЛО",p.name.."\nSteamID64: "..p.sid.."\nУровень: "..roleLabel(p.role)..((p.group and p.group~="") and ("\nГруппа ULX: "..p.group) or "")..
  "\nПрофессия: "..tostring(p.team or "—").."\nГруппировка: "..tostring(p.faction).."\nЗдоровье / броня: "..tostring(p.health).." / "..tostring(p.armor)..
  "\nДоза: "..math.Round(num(p.dose,0),1).."\nЗаморожен: "..(p.frozen and "да" or "нет").."\nБессмертие «Коменданта»: "..(p.god and "да" or "нет"))
end
function A.RefreshRoster()
 if not IsValid(roster) or not A.State then return end
 roster:Clear()
 local query=A.Lower(IsValid(search) and str(search:GetValue()) or "")
 local online={}
 local rows=table.Copy(A.State.players or {});table.sort(rows,function(a,b) return A.Lower(a.name)<A.Lower(b.name) end)
 for _,p in ipairs(rows) do online[p.sid]=true
  if query=="" or A.Lower(p.name):find(query,1,true) or p.sid:find(query,1,true) or A.Lower(p.group or ""):find(query,1,true) then
   local row=vgui.Create("DButton",roster);row:Dock(TOP);row:DockMargin(0,0,Px(6),Px(4));row:SetTall(Px(78));row:SetText("")
   row.Paint=function(self,w,h) A.PaintRosterRow(p,w,h,A.Selected[p.sid]==true,self:IsHovered()==true) end
   row.DoClick=function() A.Toggle(p.sid) end
   row.DoRightClick=function()
    local menu=DermaMenu()
    menu:AddOption("Личное дело",function() A.PlayerInfo(p) end)
    menu:AddOption("Отметить только его",function() A.Selected={[p.sid]=true} end)
    menu:AddOption("Скопировать SteamID64",function() SetClipboardText(p.sid) end)
    menu:AddOption("Назначить уровень…",function() A.OfflineSID=p.sid;A.SelectSection("Допуски");A.ShowForm(A.Commands.role) end)
    menu:Open()
   end
  end
 end
 for id in pairs(A.Selected) do if not online[id] then A.Selected[id]=nil end end
end

--[[ Команды ]]
function A.Available(c)
 if not A.State or not A.State.permissions or not A.State.permissions[c.id] then return false end
 if c.id=="item" then return integration("inventory") end
 if c.id=="radiation" then return integration("radiation") and integration("inventory") end
 if c.id=="money" then return integration("darkrp") end
 if c.id=="faction" then return integration("factions") end
 if c.id:find("^emission_") then return integration("emissions") end
 if c.id=="zone_rebuild" then return integration("zone") end
 if c.id=="restock" then return integration("restock") end
 if c.id:find("^event_") then return integration("events") end
 return true
end
local function banHint()
 local limits=A.State and A.State.limits or {}
 local rank=myRank()
 local mine=rank>=90 and "без ограничений, включая бессрочный" or A.FormatMinutes(rank<60 and (limits.moderator or A.Config.ModeratorBanMinutes) or (limits.admin or A.Config.AdminBanMinutes))
 return "Лимиты: модератор — "..A.FormatMinutes(limits.moderator or A.Config.ModeratorBanMinutes)..", администратор — "..A.FormatMinutes(limits.admin or A.Config.AdminBanMinutes)..
  ", бессрочный бан — от уровня «Комендант». Ваш лимит: "..mine.."."
end
function A.FormatMinutes(m)
 m=num(m,0)
 if m==0 then return "бессрочно" end
 if m%1440==0 then return (m/1440).." дн." end
 if m%60==0 then return (m/60).." ч" end
 return m.." мин."
end
local scopeText={players="Цели: отмеченные игроки слева. Сервер повторно проверит допуск к каждой цели.",offline="Действие по SteamID64: выбор слева не используется.",
 self="Команда действует только на вас.",server="Команда действует на весь сервер."}
function A.ShowForm(c)
 if not IsValid(form) or not A.State then return end
 form:Clear();A.ActiveCommand=c.id
 A.Header(form,c.label,34)
 A.Label(form,scopeText[c.scope] or "",44,A.C.muted)
 local fields={};local f=c.field;local cat=A.State.catalog or {}
 if f=="reason" or f=="ban" or f=="offlineban" then fields.reason=A.Entry(form,"Причина","") end
 if f=="ban" or f=="offlineban" or f=="duration" then fields.minutes=A.Entry(form,"Срок в минутах / 0 = бессрочно","60") end
 if f=="message" then fields.reason=A.Entry(form,"Текст объявления","") end
 if f=="amount" or f=="dose" or f=="money" or f=="item" then
  fields.amount=A.Entry(form,f=="money" and "Изменение баланса / отрицательное = списать" or f=="item" and "Количество / 1–100" or f=="dose" and "Доза / 0–100" or "Значение / 0–255",
   f=="item" and "1" or f=="amount" and "100" or "0")
 end
 local catalogs={weapon="weapons",item="items",faction="factions",map="maps",role="roles",event="events"}
 if catalogs[f] then fields.value=A.Combo(form,f=="role" and "Уровень доступа" or f=="event" and "Событие" or "Параметр",cat[catalogs[f]]) end
 if c.scope=="offline" then fields.sid=A.Entry(form,"SteamID64",A.OfflineSID or "") end
 if c.id=="ban" or c.id=="ban_sid" then A.Label(form,banHint(),58,A.C.muted) end
 if (c.id=="ban" or c.id=="ban_sid" or c.id=="unban") and integration("ulibBans") then A.Label(form,"Баны хранятся в ULib: они видны и в XGUI → Bans.",26,A.C.info) end
 if c.id=="cleanup" then A.Label(form,"Будут удалены игровые сущности и постройки. Данные игроков не стираются.",48,A.C.danger) end
 if c.id=="zone_rebuild" then A.Label(form,"Аномалии всех полей и артефакты появятся заново, как после выброса.",48,A.C.warn) end
 if c.id=="role" then
  A.Label(form,integration("ulib") and "Уровень — это группа ULX: назначение сразу меняет группу игрока (и офлайн, по SteamID). Права групп настраиваются в XGUI (доступы stalker_*). Нельзя назначить равный себе или более высокий уровень."
   or "ULib не установлен: уровни хранятся в «Коменданте» (таблица sta_roles). Нельзя назначить равный себе или более высокий уровень.",76,A.C.muted)
 end
 local button=A.Button(form,c.danger and "ПРОВЕРИТЬ И ПОДТВЕРДИТЬ" or "ВЫПОЛНИТЬ КОМАНДУ",function()
  local a={kind="execute",command=c.id,targets=selectedIDs()}
  for key,field in pairs(fields) do if key=="value" then a.value=field.Value else a[key]=str(field:GetValue()) end end
  if a.amount then a.amount=tonumber(a.amount) end;if a.minutes then a.minutes=tonumber(a.minutes) end
  if c.scope=="players" and #a.targets==0 then A.Output("Выберите игрока слева","danger");return end
  if fields.value and a.value==nil then A.Output("Выберите значение в списке","danger");return end
  if (A.NextAction or 0)>RealTime() then return end;A.NextAction=RealTime()+0.6
  A.Send(a)
 end,c.danger and "danger" or "accent")
 button:SetTall(Px(38));button.Center=true;button:DockMargin(0,Px(6),0,Px(6))
 button:SetEnabled(A.Available(c))
 if not A.Available(c) then A.Label(form,"Недостаточно прав (stalker_"..c.permission..") или нужный аддон не установлен.",44,A.C.danger) end
 if c.id=="role" and integration("ulx") then local x=A.Button(form,"Открыть XGUI (группы и права ULX)",A.OpenXGUI);x.Center=true end
 A.Label(form,"Команда: "..c.id.."   ·   право: stalker_"..c.permission,30,A.C.muted)
end
local function intro(parent,cat)
 A.Header(parent,"ПУЛЬТ УПРАВЛЕНИЯ",34)
 if cat=="Допуски" then
  local lines={}
  for group,role in SortedPairs(A.Config.GroupRoles) do lines[#lines+1]="ULX «"..group.."» → "..roleLabel(role) end
  A.Label(parent,integration("ulib") and ("Уровни «Коменданта» — это группы ULX:\n"..table.concat(lines,"\n").."\nВладелец — из списка Owners (sh_config.lua), всегда в группе superadmin.")
   or "ULib не найден: уровни назначаются в этой панели и хранятся отдельно.",150,A.C.text)
  if integration("ulx") then local x=A.Button(parent,"Открыть XGUI",A.OpenXGUI);x.Center=true end
  return
 end
 A.Label(parent,"01 / Отметьте игроков слева\n02 / Выберите команду\n03 / Заполните параметры\n04 / Проверьте ответ сервера внизу",110,A.C.text)
 A.Label(parent,"ПКМ по игроку — личное дело. Опасные и групповые действия требуют подтверждения. Все команды проверяются сервером и пишутся в журнал (и в журнал ULX).",76,A.C.muted)
end
function A.BuildCommands(cat)
 local list=vgui.Create("DPanel",body);list:Dock(LEFT);list:SetWide(Px(250));list:DockMargin(0,0,Px(10),0);list.Paint=nil
 local scroll=A.Scroll(list)
 form=A.Scroll(body)
 local cmds={};for _,c in pairs(A.Commands) do if c.category==cat then cmds[#cmds+1]=c end end
 table.sort(cmds,function(a,b) return a.order<b.order end)
 for _,c in ipairs(cmds) do
  local b=A.Button(scroll,c.label,function() A.ShowForm(c) end);b:SetTall(Px(36))
  b.Dim=not A.Available(c)
  b.Think=function(self) self.Active=A.ActiveCommand==c.id end
 end
 intro(form,cat)
end

--[[ Реестры: журнал и баны (страницы с сервера) ]]
local statusText={attempt={"попытка","muted"},success={"выполнено","ok"},failed={"отклонено","danger"}}
local columns={logs={{"Время",.14},{"Кто",.22},{"Команда",.16},{"Цель",.30},{"Статус",.18}},bans={{"Игрок",.24},{"SteamID64",.22},{"Причина",.34},{"До",.20}}}
function A.PageRequest()
 local s=A.SectionByID[A.Category];if not s or s.kind~="page" then return end
 A.Send({kind=s.page,page=A.PageNumber})
end
local function nameOf(sid)
 for _,p in ipairs(A.State and A.State.players or {}) do if p.sid==sid then return p.name end end
 return sid=="CONSOLE" and "Консоль" or sid
end
function A.ShowStandalone(c)
 if not IsValid(body) then return end
 body:Clear()
 local b=A.Button(body,"← Назад",function() A.BuildBody() end);b:SetWide(Px(120));b.Center=true
 form=A.Scroll(body);A.ShowForm(c)
end
function A.BuildPage(s)
 local top=vgui.Create("DPanel",body);top:Dock(TOP);top:SetTall(Px(34));top:DockMargin(0,0,0,Px(8))
 top.Paint=function(_,w,h) draw.SimpleText("Страница "..A.PageNumber,A.F.small,w-Px(4),h/2,A.C.muted,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER) end
 local function tb(text,fn,w,kind) local b=A.Button(top,text,fn,kind);b:Dock(LEFT);b:SetWide(Px(w));b:DockMargin(0,0,Px(6),0);b.Center=true;return b end
 tb("←",function() A.PageNumber=math.max(1,A.PageNumber-1);A.PageRequest() end,44)
 tb("→",function() A.PageNumber=A.PageNumber+1;A.PageRequest() end,44)
 tb("Обновить",A.PageRequest,110)
 if s.page=="bans" then
  tb("Бан по SteamID64",function() A.ShowStandalone(A.Commands.ban_sid) end,170,"danger")
  tb("Снять бан",function() A.ShowStandalone(A.Commands.unban) end,120)
  if integration("ulibBans") then A.Label(body,"Баны ведёт ULib: те же записи видны в XGUI → Bans. Нажмите на строку, чтобы скопировать SteamID64.",26,A.C.info) end
 end
 local cols=columns[s.page]
 local head=vgui.Create("DPanel",body);head:Dock(TOP);head:SetTall(Px(24));head:DockMargin(0,0,Px(6),Px(2))
 head.Paint=function(_,w,h)
  local x=Px(8);for _,col in ipairs(cols) do draw.SimpleText(col[1],A.F.small,x,h/2,A.C.accent,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);x=x+w*col[2] end
  surface.SetDrawColor(A.C.line);surface.DrawRect(0,h-1,w,1)
 end
 A.Table=A.Scroll(body);A.Table.Section=s.page
 A.PageRequest()
end
function A.FillPage(data)
 if not IsValid(A.Table) or A.Table.Section~=data.section then return end
 A.Table:Clear()
 if not data.ok then A.Output("Ошибка чтения с сервера","danger");return end
 local cols=columns[data.section]
 for _,row in ipairs(data.rows or {}) do
  local cells,tokens
  if data.section=="logs" then
   local st=statusText[row.status] or {tostring(row.status),"muted"}
   cells={os.date("%d.%m %H:%M",tonumber(row.time) or 0),nameOf(row.actor),tostring(row.action),nameOf(row.target),st[1]}
   tokens={"muted","text","accent","text",st[2]}
  else
   local expires=tonumber(row.expires) or 0
   cells={tostring(row.name),tostring(row.sid),tostring(row.reason),expires==0 and "бессрочно" or os.date("%d.%m.%Y %H:%M",expires)}
   tokens={"text","muted","text",expires==0 and "danger" or "warn"}
  end
  local line=vgui.Create("DButton",A.Table);line:Dock(TOP);line:SetTall(Px(26));line:SetText("");line:DockMargin(0,0,Px(6),Px(2))
  line.Paint=function(self,w,h)
   A.PaintBox(0,0,w,h,self:IsHovered()==true or A.SelectedRow==row,false)
   local x=Px(8)
   for i,col in ipairs(cols) do local cw=w*col[2];draw.SimpleText(A.Fit(cells[i],A.F.small,cw-Px(10)),A.F.small,x,h/2,A.C[tokens[i]],TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);x=x+cw end
  end
  line.DoClick=function()
   A.SelectedRow=row
   if data.section=="bans" then A.OfflineSID=row.sid;SetClipboardText(tostring(row.sid));A.Output("SteamID64 скопирован: "..tostring(row.sid).." (форма «Снять бан» подставит его)","muted")
   else A.Output(nameOf(row.actor).." / "..tostring(row.action).." / "..nameOf(row.target).." / "..tostring(row.detail),"muted") end
  end
 end
 A.Output("Страница "..data.page..": записей "..#(data.rows or {}),"muted")
end

--[[ Настройки сборки: реестр STALKER_SETTINGS ]]
local function decimals(def) return num(def.decimals,0) end
function A.FormatSetting(def,v)
 if def.type=="bool" then return v==true and "вкл." or "выкл." end
 if def.type=="number" then
  v=num(v,0);local d=decimals(def)
  if d>0 then return string.format("%."..d.."f",v) end
  return string.format("%d",math.floor(v+.5))
 end
 if def.type=="choice" then for _,c in ipairs(def.choices or {}) do if c[1]==v then return tostring(c[2] or c[1]) end end end
 return tostring(v)
end
-- Значение ползунка: шаг, знаки после запятой и границы как у сервера (S.Validate).
function A.SnapSetting(def,v)
 local step=num(def.step,0);if step<=0 then step=10^-decimals(def) end
 v=math.floor(v/step+.5)*step
 if def.min then v=math.Clamp(v,def.min,def.max or v) end
 return math.Round(v,decimals(def))
end
function A.SettingRow(parent,def)
 local S=STALKER_SETTINGS
 local row=vgui.Create("DPanel",parent);row:Dock(TOP);row:SetTall(Px(58));row:DockMargin(0,0,Px(6),Px(4));row:DockPadding(Px(10),Px(12),Px(10),Px(12))
 row.Def=def
 local right=vgui.Create("DPanel",row);right:Dock(RIGHT);right:SetWide(Px(390));right.Paint=nil
 local function send(value) row.Pending=true;S.RequestSet(row.Def.id,value) end
 local reset=A.Button(right,"Сброс",function() if row.Def.changed then row.Pending=true;S.RequestReset(row.Def.id) end end)
 reset:Dock(RIGHT);reset:SetWide(Px(80));reset:DockMargin(Px(8),0,0,0);reset.Center=true
 reset:SetTooltip("По умолчанию: "..A.FormatSetting(def,def.default))
 reset:SetEnabled(def.changed==true)
 local holder=vgui.Create("DPanel",right);holder:Dock(FILL);holder.Paint=nil
 local function entryField(dock,wide)
  local e=vgui.Create("DTextEntry",holder);e:Dock(dock);if wide then e:SetWide(Px(wide)) end;A.StyleEntry(e)
  -- Сохранение по Enter; без Enter поле после потери фокуса возвращает текущее значение.
  e.OnLoseFocus=function(self)
   hook.Call("OnTextEntryLoseFocus",nil,self)
   timer.Simple(0,function() if IsValid(self) then if not self.Submitted and row.Refresh then row:Refresh() end;self.Submitted=nil end end)
  end
  return e
 end
 if def.type=="number" then
  local ranged=def.min and def.max and def.max>def.min
  local entry=entryField(ranged and RIGHT or FILL,96)
  entry.OnEnter=function(self)
   self.Submitted=true
   local v=tonumber(str(self:GetValue()))
   if not v then A.Output("«"..row.Def.label.."»: введите число","danger");row:Refresh();return end
   send(v)
  end
  if ranged then
   local slider=vgui.Create("DPanel",holder);slider:Dock(FILL);slider:DockMargin(0,0,Px(8),0);slider:SetCursor("hand")
   slider.Paint=function(self,w,h)
    local d=row.Def;local v=self.Dragging and self.Value or d.value
    local r=math.Clamp((num(v,d.min)-d.min)/(d.max-d.min),0,1);local y=h/2-Px(4)
    if STALKER_STYLE and STALKER_STYLE.Bar then STALKER_STYLE.Bar(0,y,w,Px(8),r,d.changed and A.C.accent or A.C.info)
    else surface.SetDrawColor(A.C.track);surface.DrawRect(0,y,w,Px(8));surface.SetDrawColor(A.C.accent);surface.DrawRect(0,y,w*r,Px(8)) end
    local rd=math.Clamp((num(d.default,d.min)-d.min)/(d.max-d.min),0,1)
    surface.SetDrawColor(A.C.muted);surface.DrawRect(math.floor(rd*(w-2)),y-Px(4),2,Px(16))
    surface.SetDrawColor(self.Dragging and A.C.accent2 or A.C.text);surface.DrawRect(math.floor(r*(w-Px(8))),h/2-Px(9),Px(8),Px(18))
   end
   slider.Track=function(self)
    local d=row.Def;local x=num((self:CursorPos()),0);local w=math.Clamp(num(self:GetWide(),1),1,100000)
    self.Value=A.SnapSetting(d,d.min+(d.max-d.min)*math.Clamp(x/w,0,1))
    entry:SetText(A.FormatSetting(d,self.Value))
   end
   slider.OnMousePressed=function(self,code) if code~=MOUSE_LEFT then return end;self.Dragging=true;self:MouseCapture(true);self:Track() end
   slider.OnMouseReleased=function(self)
    if not self.Dragging then return end
    self.Dragging=false;self:MouseCapture(false)
    if self.Value~=nil and self.Value~=row.Def.value then send(self.Value) end
   end
   slider.Think=function(self) if self.Dragging then self:Track() end end
  end
  row.Refresh=function() if entry:HasFocus()~=true then entry:SetText(A.FormatSetting(row.Def,row.Def.value)) end end
 elseif def.type=="bool" then
  local box=vgui.Create("DButton",holder);box:Dock(FILL);box:SetText("")
  box.Paint=function(self,w,h)
   local on=row.Def.value==true;local s=Px(20);local y=math.floor((h-s)/2)
   A.PaintBox(0,y,s,s,self:IsHovered()==true,false)
   if on then surface.SetDrawColor(A.C.accent);surface.DrawRect(Px(5),y+Px(5),s-Px(10),s-Px(10)) end
   draw.SimpleText(on and "Включено" or "Выключено",A.F.body,s+Px(10),h/2,on and A.C.ok or A.C.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  end
  box.DoClick=function() surface.PlaySound("buttons/lightswitch2.wav");send(row.Def.value~=true) end
  row.Refresh=function() end
 elseif def.type=="choice" then
  local combo=vgui.Create("DComboBox",holder);combo:Dock(FILL);A.StyleCombo(combo)
  local function fill()
   combo:Clear()
   for _,c in ipairs(row.Def.choices or {}) do combo:AddChoice(tostring(c[2] or c[1]),c[1]) end
   combo:SetValue(A.FormatSetting(row.Def,row.Def.value))
  end
  combo.OnSelect=function(_,_,_,data) if data~=nil and data~=row.Def.value then send(data) end end
  fill();row.Refresh=fill
 else
  local entry=entryField(FILL)
  entry.OnEnter=function(self) self.Submitted=true;send(str(self:GetValue())) end
  row.Refresh=function() if entry:HasFocus()~=true then entry:SetText(tostring(row.Def.value or "")) end end
 end
 row.Paint=function(self,w,h)
  local d=self.Def
  A.PaintBox(0,0,w,h,d.changed==true,false)
  if d.changed then surface.SetDrawColor(A.C.accent);surface.DrawRect(0,0,Px(3),h) end
  local tw=w-num(right:GetWide(),Px(390))-Px(34)
  draw.SimpleText(A.Fit(d.label,A.F.body,tw-Px(80)),A.F.body,Px(12),Px(7),d.changed and A.C.accent2 or A.C.text)
  draw.SimpleText(A.Fit(d.id..(d.description and ("  ·  "..d.description) or ""),A.F.small,tw),A.F.small,Px(12),Px(31),A.C.muted)
  local mark=self.Pending and {"сохранение…","muted"} or d.changed and {"изменено","accent"} or nil
  if mark then draw.SimpleText(mark[1],A.F.small,tw+Px(12),Px(9),A.C[mark[2]],TEXT_ALIGN_RIGHT) end
 end
 row:SetTooltip(def.description or def.label)
 row.SetDef=function(self,d) self.Def=d;self.Pending=nil;reset:SetEnabled(d.changed==true);reset:SetTooltip("По умолчанию: "..A.FormatSetting(d,d.default));self:Refresh() end
 row:Refresh()
 return row
end
function A.RenderSettings()
 local SV=A.SettingsView;if not SV or not IsValid(SV.scroll) then return end
 SV.scroll:Clear();SV.rows={};SV.ids={}
 local q=A.Lower(SV.filter);local current;local shown,changed=0,0
 for _,def in ipairs(A.LastSettings or {}) do
  SV.ids[#SV.ids+1]=def.id
  if def.changed then changed=changed+1 end
  local text=A.Lower(def.label.." "..def.id.." "..tostring(def.description or "").." "..def.category)
  if (SV.category=="" or def.category==SV.category) and (not SV.changedOnly or def.changed) and (q=="" or text:find(q,1,true)) then
   if def.category~=current then current=def.category;A.Header(SV.scroll,"▸ "..current,30) end
   SV.rows[def.id]=A.SettingRow(SV.scroll,def);shown=shown+1
  end
 end
 SV.total,SV.changed,SV.shown=#SV.ids,changed,shown
 if shown==0 then A.Label(SV.scroll,A.LastSettings and "Ничего не найдено. Измените поиск или раздел." or "Запрос списка настроек…",40,A.C.muted) end
end
local function sameIDs(SV,list)
 if not SV.ids or #SV.ids~=#list then return false end
 for i,def in ipairs(list) do if SV.ids[i]~=def.id then return false end end
 return true
end
local function fillCategories(SV)
 if not IsValid(SV.combo) then return end
 local cats,seen={},{}
 for _,def in ipairs(A.LastSettings or {}) do if not seen[def.category] then seen[def.category]=true;cats[#cats+1]=def.category end end
 local key=table.concat(cats,"|");if SV.catKey==key then return end;SV.catKey=key
 SV.combo:Clear();SV.combo:AddChoice("Все разделы","")
 for _,c in ipairs(cats) do SV.combo:AddChoice(c,c) end
 SV.combo:SetValue(SV.category=="" and "Все разделы" or SV.category)
end
-- Ответ сервера: полный список (и результат изменения). Строки обновляются на месте, чтобы не сбивать прокрутку.
function A.OnSettingsList(list,res)
 if type(list)~="table" or list==A.LastSettings then return end
 A.LastSettings=list
 if type(res)=="table" and res.id then
  local label=res.id;for _,d in ipairs(list) do if d.id==res.id then label=d.label.." = "..A.FormatSetting(d,d.value) end end
  if res.ok then A.Output("Настройка сохранена: "..label,"ok") else A.Output("Настройка не сохранена: "..label.." — "..tostring(res.error or "отказ сервера"),"danger") end
 end
 local SV=A.SettingsView;if not SV or not IsValid(SV.scroll) then return end
 fillCategories(SV)
 if sameIDs(SV,list) and not SV.changedOnly then
  local changed=0
  for _,def in ipairs(list) do if def.changed then changed=changed+1 end;local row=SV.rows[def.id];if IsValid(row) then row:SetDef(def) end end
  SV.changed=changed
  -- Ответ без изменений (отказ) снимает отметку «сохранение…».
  if type(res)=="table" and res.id and not res.ok and IsValid(SV.rows[res.id]) then SV.rows[res.id].Pending=nil end
 else A.RenderSettings() end
end
hook.Add("STALKER_SettingsList","STALKER.AdminSettings",function(list,res) A.OnSettingsList(list,res) end)
function A.RequestSettings()
 local S=STALKER_SETTINGS;if not S or not S.RequestList then return end
 S.RequestList(function(list,res) A.OnSettingsList(list,res) end)
end
function A.BuildSettings()
 local S=STALKER_SETTINGS
 if not S or not S.RequestList then A.Notice(body,"Реестр настроек недоступен","Нужен аддон stalker_core.","danger");return end
 local SV={rows={},filter="",category="",changedOnly=false};A.SettingsView=SV
 local top=vgui.Create("DPanel",body);top:Dock(TOP);top:SetTall(Px(34));top:DockMargin(0,0,0,Px(6));top.Paint=nil
 local refresh=A.Button(top,"Обновить",function() A.LastSettings=nil;A.RequestSettings() end);refresh:Dock(RIGHT);refresh:SetWide(Px(110));refresh:DockMargin(Px(6),0,0,0);refresh.Center=true
 local only=A.Button(top,"Только изменённые",function(self) SV.changedOnly=not SV.changedOnly;self.Active=SV.changedOnly;A.RenderSettings() end)
 only:Dock(RIGHT);only:SetWide(Px(170));only:DockMargin(Px(6),0,0,0);only.Center=true
 SV.combo=vgui.Create("DComboBox",top);SV.combo:Dock(RIGHT);SV.combo:SetWide(Px(220));SV.combo:DockMargin(Px(6),0,0,0);A.StyleCombo(SV.combo)
 SV.combo:SetValue("Все разделы")
 SV.combo.OnSelect=function(_,_,_,data) SV.category=type(data)=="string" and data or "";A.RenderSettings() end
 SV.search=vgui.Create("DTextEntry",top);SV.search:Dock(FILL);A.StyleEntry(SV.search)
 SV.search:SetPlaceholderText("Поиск: название, ID, описание…")
 SV.search.OnChange=function(self) SV.filter=str(self:GetValue());A.RenderSettings() end
 local info=vgui.Create("DPanel",body);info:Dock(TOP);info:SetTall(Px(22));info:DockMargin(0,0,0,Px(4))
 info.Paint=function(_,w,h)
  draw.SimpleText("Настроек: "..tostring(SV.total or 0).."  ·  изменено: "..tostring(SV.changed or 0).."  ·  число — ползунок или поле + Enter; изменения сразу применяются на сервере",A.F.small,0,h/2,A.C.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 SV.scroll=A.Scroll(body)
 if S.LastList then A.LastSettings=nil;A.OnSettingsList(S.LastList) else A.RenderSettings() end
 A.RequestSettings()
end

--[[ Вкладки других аддонов ]]
function A.Notice(parent,title,text,token)
 local box=A.Panel(parent,TOP);box:SetTall(Px(120))
 A.Label(box,title,30,A.C[token or "accent"]):SetFont(A.F.head)
 A.Label(box,text,60,A.C.muted)
 return box
end
local addonNames={STALKER_RAD="радиации (stalker_survival)",STALKER_ZONE="Зоны (stalker_zone)",STALKER_EVENTS="событий Зоны",STALKER_QUESTS="заданий",STALKER_CRAFT="крафта",STFW="группировок (stalker_factions)"}
function A.BuildAddon(s)
 local G=_G[s.global];local build=type(G)=="table" and G.BuildAdminPanel
 if type(build)~="function" then
  A.Notice(body,"Аддон не установлен","Вкладка «"..s.id.."» появится, когда будет установлен аддон "..(addonNames[s.global] or s.global).." с панелью администратора.","warn")
  return
 end
 local holder=vgui.Create("DPanel",body);holder:Dock(FILL);holder.Paint=nil
 local ok,err=pcall(build,holder)
 if not ok then
  ErrorNoHalt("[STALKER ADMIN] вкладка «"..s.id.."»: "..tostring(err).."\n")
  if IsValid(holder) then holder:Clear() end
  A.Notice(holder,"Ошибка вкладки","Аддон не смог построить панель: "..tostring(err),"danger")
 end
end

--[[ Разделы ]]
function A.SectionAllowed(s)
 if not s.permission then return true end
 local tabs=A.State and A.State.tabs or {}
 return tabs[s.permission]==true
end
function A.BuildBody()
 if not IsValid(body) or not A.State then return end
 body:Clear();A.ActiveCommand=nil;A.SettingsView=nil;A.Table=nil;form=nil
 local s=A.SectionByID[A.Category] or A.Sections[1]
 if not A.SectionAllowed(s) then
  A.Notice(body,"Недостаточный допуск","Для раздела «"..s.id.."» нужно право stalker_"..s.permission.." ("..(A.PermissionLabels[s.permission] or s.permission)..")."..
   (integration("ulx") and " Права групп выдаются в XGUI → Groups." or ""),"danger")
  return
 end
 if s.kind=="page" then A.BuildPage(s) elseif s.kind=="settings" then A.BuildSettings() elseif s.kind=="addon" then A.BuildAddon(s) else A.BuildCommands(s.id) end
end
function A.SelectSection(id)
 if not A.SectionByID[id] then return end
 A.Category=id;A.PageNumber=1;A.SelectedRow=nil;A.BuildBody()
end
function A.OpenXGUI()
 if IsValid(frame) then frame:Remove() end
 RunConsoleCommand("xgui","show")
end
function A.Help()
 A.Message("КОМЕНДАНТ / Справка","F7, !admin или sta_menu — панель.\nОтметьте цели слева, затем выберите раздел и команду. ПКМ по игроку — личное дело.\n"..
  "Все права проверяются на сервере. С ULX уровни — это группы ULX, права — доступы stalker_* (XGUI → Groups), баны — общий список ULib.\n"..
  "Команды STALKER есть и в меню ULX (категория STALKER).\n\nПервый владелец — из серверной консоли:\nsta_setrole STEAMID64 owner\n\nПодробнее — README_RU.md аддона.")
end
function A.BuildNav(parent)
 local scroll=A.Scroll(parent)
 local group
 for i,s in ipairs(A.Sections) do
  if s.group~=group then group=s.group;A.Header(scroll,group,24) end
  local b=A.Button(scroll,string.format("%02d  ",i)..s.id,function() A.SelectSection(s.id) end);b:SetTall(Px(28));b:DockMargin(0,0,Px(4),Px(3))
  b.Think=function(self) self.Active=A.Category==s.id;self.Dim=not A.SectionAllowed(s) end
 end
 A.Header(scroll,"СЕРВИС",24)
 local x=A.Button(scroll,"Открыть XGUI",A.OpenXGUI);x:SetTall(Px(28))
 x.Think=function(self) self:SetEnabled(integration("ulx")) end
 local h=A.Button(scroll,"Справка",A.Help);h:SetTall(Px(28))
end
function A.PaintHeader(w,h)
 local state=A.State
 draw.SimpleText(state and (state.map.."  ·  "..#state.players.."/"..state.max.."  ·  "..roleLabel(state.role)..((state.group and state.group~="") and ("  ·  ULX: "..state.group) or "")) or "СОЕДИНЕНИЕ…",
  A.F.small,w-Px(60),Px(10),A.C.muted,TEXT_ALIGN_RIGHT)
 draw.SimpleText("ВЫБРАНО: "..#selectedIDs().."   ·   СЕТЬ ЗОНЫ / "..A.Config.Version,A.F.small,w-Px(60),Px(27),A.C.accent,TEXT_ALIGN_RIGHT)
end
local function closed()
 A.Send({kind="cancel"});timer.Remove("STALKER.AdminPoll")
 if IsValid(A.ConfirmFrame) then A.ConfirmFrame.Answered=true;A.ConfirmFrame:Remove() end
 A.SettingsView=nil;A.Table=nil
end
function A.Open()
 if IsValid(frame) then frame:Remove();return end
 local style=STALKER_STYLE
 if style and style.Window then
  frame=style.Window({title="☢  "..A.Config.Title,w=1380,h=860,onClose=closed})
  local base=frame.Paint
  frame.Paint=function(self,w,h) base(self,w,h);A.PaintHeader(w,h) end
 else
  frame=vgui.Create("DFrame");frame:SetSize(math.min(1380,ScrW()-24),math.min(860,ScrH()-24));frame:Center();frame:SetTitle("");frame:MakePopup();frame:DockPadding(14,50,14,14)
  frame.Paint=function(_,w,h) A.PaintBox(0,0,w,h,false,false);draw.SimpleText(A.Config.Title,A.F.title,18,13,A.C.accent);A.PaintHeader(w,h) end
  frame.OnRemove=closed
 end
 A.Frame=frame;frame.Initialized=false
 local wide=num(frame:GetWide(),1380)
 local footer=A.Panel(frame,BOTTOM);footer:SetTall(Px(112));footer:DockMargin(0,Px(10),0,0)
 A.Header(footer,"ЖУРНАЛ СЕАНСА / ОТВЕТ СЕРВЕРА",22)
 result=vgui.Create("RichText",footer);result:Dock(FILL)
 result.PerformLayout=function(self) self:SetFontInternal(A.F.mono);self:SetFGColor(A.C.text) end
 local left=A.Panel(frame,LEFT);left:SetWide(math.Clamp(wide*.22,Px(220),Px(300)));left:DockMargin(0,0,Px(10),0)
 A.Header(left,"ЛИЧНЫЙ СОСТАВ",28)
 search=A.Entry(left,nil,"");search:SetPlaceholderText("Поиск: имя, SteamID64, группа")
 search.OnChange=function() A.RefreshRoster() end
 local bar=vgui.Create("DPanel",left);bar:Dock(TOP);bar:SetTall(Px(32));bar:DockMargin(0,0,0,Px(6));bar.Paint=nil
 local all=A.Button(bar,"Все",function()
  local limit=A.State and A.State.limits and A.State.limits.targets or A.Config.MaxTargets
  local count=0;for _,p in ipairs(A.State and A.State.players or {}) do if count<limit then A.Selected[p.sid]=true;count=count+1 end end
 end);all:Dock(LEFT);all:SetWide(Px(80));all.Center=true
 local none=A.Button(bar,"Сброс",function() A.Selected={} end);none:Dock(RIGHT);none:SetWide(Px(90));none.Center=true
 roster=A.Scroll(left)
 local nav=A.Panel(frame,LEFT);nav:SetWide(Px(205));nav:DockMargin(0,0,Px(10),0)
 A.BuildNav(nav)
 body=A.Panel(frame,FILL)
 A.Send({kind="state"})
 timer.Create("STALKER.AdminPoll",3,0,function() if IsValid(frame) then A.Send({kind="state"}) else timer.Remove("STALKER.AdminPoll") end end)
 A.Output("Запрос допуска…","accent")
 return frame
end
function A.ConfirmText(data)
 return data.label.."\n\n"..((data.targets and #data.targets>0) and table.concat(data.targets,"\n") or data.sid or "Весь сервер").."\n\n"..tostring(data.detail)..
  (data.minutes and ("\nСрок: "..A.FormatMinutes(data.minutes)) or "")..(data.amount and ("\nКоличество/значение: "..tostring(data.amount)) or "").."\n\nПодтверждение действует 25 секунд."
end
-- Ответ сервера (вынесен из net.Receive, чтобы его можно было проверить в тестах).
function A.HandleResponse(data)
 if data.kind=="denied" then
  notification.AddLegacy(tostring(data.message),NOTIFY_ERROR,5)
  if IsValid(frame) then frame:Remove() end
  return
 end
 if data.kind=="state" then
  A.State=data;A.RefreshRoster()
  if IsValid(frame) and not frame.Initialized then
   frame.Initialized=true;frame:InvalidateLayout(true);if IsValid(body) then body:InvalidateLayout(true) end
   A.BuildBody();A.Output("Допуск подтверждён: "..roleLabel(data.role)..((data.group and data.group~="") and (" (ULX: "..data.group..")") or "")..". Сеть Зоны доступна.","ok")
  end
 elseif data.kind=="confirm" then
  if not IsValid(frame) then return end
  if IsValid(A.ConfirmFrame) then A.ConfirmFrame.Answered=true;A.ConfirmFrame:Remove() end
  A.ConfirmFrame=A.Message("ПОДТВЕРЖДЕНИЕ КОМАНДЫ",A.ConfirmText(data),{
   {"Выполнить",function() A.Send({kind="confirm",token=data.token}) end,"danger"},
   {"Отмена",function() A.Send({kind="cancel"}) end}},
   function(win) if win.Answered~=true then A.Send({kind="cancel"}) end end)
 elseif data.kind=="result" then
  A.Output(data.message or "Ответ получен",data.ok and "ok" or "danger")
  for _,r in ipairs(data.results or {}) do A.Output(tostring(r.name).." → "..tostring(r.message),r.ok and "ok" or "danger") end
  if IsValid(frame) then A.Send({kind="state"});if IsValid(A.Table) then A.PageRequest() end end
 elseif data.kind=="page" then
  A.FillPage(data)
 end
end
net.Receive("sta.response",function()
 local size=net.ReadUInt(16);if type(size)~="number" or size>60000 then return end
 local raw=util.Decompress(net.ReadData(size),524288);local data=raw and util.JSONToTable(raw);if type(data)~="table" then return end
 A.HandleResponse(data)
end)
concommand.Add("sta_menu",function() A.Open() end)
local key=CreateClientConVar("sta_key",tostring(KEY_F7),true,false,"Клавиша админ-панели")
local held=false
hook.Add("Think","STALKER.AdminKey",function()
 local down=input.IsKeyDown(key:GetInt())
 if down and not held and not gui.IsGameUIVisible() and not gui.IsConsoleVisible() and not IsValid(vgui.GetKeyboardFocus()) then A.Open() end
 held=down
end)

-- Remote camera: no respawn, inventory reset, or player entity destruction.
hook.Add("CalcView","STALKER.AdminCamera",function(p,origin,angles,fov)
 local target=p:GetNW2Entity("sta_watch")
 if IsValid(target) then return {origin=target:EyePos(),angles=target:EyeAngles(),fov=fov,drawviewer=true} end
end)
hook.Add("HUDPaint","STALKER.AdminCamera",function()
 local p=LocalPlayer();if not IsValid(p) then return end
 local target=p:GetNW2Entity("sta_watch")
 if IsValid(target) then
  local text="КАМЕРА / "..target:Nick().." — F7 → Перемещение → Вернуться к себе"
  local w=Px(620);local x=ScrW()/2-w/2
  A.PaintBox(x,Px(18),w,Px(30),true,true)
  draw.SimpleText(text,A.F.body,ScrW()/2,Px(33),A.C.accent,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
end)
