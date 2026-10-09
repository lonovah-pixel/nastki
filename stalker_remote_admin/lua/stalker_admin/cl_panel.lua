local A=STALKER_ADMIN
A.Selected={};A.State=nil;A.PageNumber=1
local frame,roster,body,nav,result,search,form,commandList
local category="Дисциплина"
function A.Send(data)
 local raw=util.TableToJSON(data);if not raw or #raw>8192 then return end
 net.Start("sta.request");net.WriteUInt(#raw,16);net.WriteData(raw,#raw);net.SendToServer()
end
local function selectedIDs()
 local result={};for id,v in pairs(A.Selected) do if v then result[#result+1]=id end end;table.sort(result);return result
end
local function output(text,color)
 if not IsValid(result) then return end
 result:InsertColorChange((color or A.C.text).r,(color or A.C.text).g,(color or A.C.text).b)
 result:AppendText(os.date("%H:%M:%S").."  "..text.."\n");result:GotoTextEnd()
end
local function refreshRoster()
 if not IsValid(roster) or not A.State then return end
 roster:Clear();local query=IsValid(search) and search:GetValue():lower() or ""
 local online={};local rows=table.Copy(A.State.players or {});table.sort(rows,function(a,b) return a.name:lower()<b.name:lower() end)
 for _,p in ipairs(rows) do online[p.sid]=true
  if query=="" or p.name:lower():find(query,1,true) or p.sid:find(query,1,true) then
   local row=vgui.Create("DButton",roster);row:Dock(TOP);row:DockMargin(0,0,0,5);row:SetTall(84);row:SetText("")
   row.Paint=function(_,w,h)
    surface.SetDrawColor(A.Selected[p.sid] and A.C.edge or A.C.raised);surface.DrawRect(0,0,w,h)
    surface.SetDrawColor(p.alive and A.C.green or A.C.red);surface.DrawRect(0,0,3,h)
    draw.SimpleText((A.Selected[p.sid] and "[X] " or "[ ] ")..string.sub(p.name,1,36),"STA.Body",10,7,A.C.text)
    draw.SimpleText(p.sid,"STA.Small",10,29,A.C.muted)
    draw.SimpleText((A.Config.Roles[p.role] or A.Config.Roles.user).label.." / "..p.ping.." ms","STA.Small",10,46,A.C.accent)
    draw.SimpleText("HP "..p.health.."  AR "..p.armor.."  "..p.faction,"STA.Small",10,63,A.C.muted)
   end
   row.DoClick=function() A.Selected[p.sid]=not A.Selected[p.sid] end
   row.DoRightClick=function()
    local menu=DermaMenu();menu:AddOption("Скопировать SteamID64",function() SetClipboardText(p.sid) end)
    menu:AddOption("Сведения",function() Derma_Message(p.name.."\n"..p.sid.."\nПрофессия: "..(p.team or "—").."\nГруппировка: "..p.faction.."\nДоза: "..math.Round(p.dose,1).."\nЗаморожен: "..tostring(p.frozen).."\nБессмертие STA: "..tostring(p.god),"Личное дело","Закрыть") end);menu:Open()
   end
  end
 end
 for id in pairs(A.Selected) do if not online[id] then A.Selected[id]=nil end end
end
local function available(c)
 if not A.State or not A.State.permissions[c.id] then return false end
 local i=A.State.integrations
 if c.id=="item" then return i.inventory end
 if c.id=="radiation" then return i.radiation and i.inventory end
 if c.id=="money" then return i.darkrp end
 if c.id=="faction" then return i.factions end
 if c.id:find("^emission_") then return i.emissions end
 return true
end
local function showForm(c)
 if not IsValid(form) then return end
 form:Clear();A.ActiveCommand=c.id
 A.Label(form,c.label:upper(),42,A.C.accent)
 A.Label(form,c.scope=="players" and "Цели: отмеченные игроки слева. Максимум 16. Перед выполнением сервер повторно проверит доступ." or c.scope=="offline" and "Действие по SteamID64. Онлайн-выбор слева не используется." or c.scope=="self" and "Команда действует только на вас." or "Команда действует на весь сервер.",68,A.C.muted)
 local fields={};local f=c.field;local cat=A.State.catalog
 if f=="reason" or f=="ban" or f=="offlineban" then fields.reason=A.Entry(form,"Причина","") end
 if f=="ban" or f=="offlineban" or f=="duration" then fields.minutes=A.Entry(form,"Срок в минутах / 0 = бессрочно","60") end
 if f=="message" then fields.reason=A.Entry(form,"Текст объявления","") end
 if f=="amount" or f=="dose" or f=="money" or f=="item" then
  fields.amount=A.Entry(form,f=="money" and "Изменение баланса / отрицательное = списать" or f=="item" and "Количество / 1–100" or "Значение",f=="item" and "1" or f=="amount" and "100" or "0")
 end
 local catalogs={weapon="weapons",item="items",faction="factions",map="maps",role="roles"}
 if catalogs[f] then fields.value=A.Combo(form,"Параметр",cat[catalogs[f]]) end
 if c.scope=="offline" then fields.sid=A.Entry(form,"SteamID64",A.OfflineSID or "") end
 if c.id=="ban" or c.id=="ban_sid" then A.Label(form,"Модератор: до 1 дня. Администратор: до 7 дней. Бессрочный бан — от уровня «Комендант».",64,A.C.muted) end
 if c.id=="cleanup" then A.Label(form,"Будут удалены игровые сущности и постройки. Данные игроков не стираются.",64,A.C.red) end
 if c.id=="role" then A.Label(form,"Допуски этой системы не изменяют группы ULX/FAdmin. Нельзя назначить равный себе или более высокий уровень.",70,A.C.muted) end
 local button=A.Button(form,c.danger and "ПРОВЕРИТЬ И ПОДТВЕРДИТЬ" or "ВЫПОЛНИТЬ КОМАНДУ",function()
  local a={kind="execute",command=c.id,targets=selectedIDs()}
  for key,field in pairs(fields) do a[key]=key=="value" and field.Value or field:GetValue() end
  if a.amount then a.amount=tonumber(a.amount) end;if a.minutes then a.minutes=tonumber(a.minutes) end
  if c.scope=="players" and #a.targets==0 then output("Выберите игрока слева",A.C.red);return end
  if (A.NextAction or 0)>RealTime() then return end;A.NextAction=RealTime()+0.6
  A.Send(a)
 end)
 button:SetEnabled(available(c))
 if not available(c) then A.Label(form,"Недостаточно прав или нужный модуль не установлен.",52,A.C.red) end
 A.Label(form,"COMMAND / "..c.id.."   ACCESS / "..c.permission,40,A.C.muted)
end
local function pageRequest()
 A.Send({kind=category=="Журнал" and "logs" or "bans",page=A.PageNumber})
end
local function buildCategory()
 if not IsValid(body) or not A.State then return end
 body:Clear();A.ActiveCommand=nil
 if category=="Журнал" or category=="Реестр банов" then
  local permission=category=="Журнал" and A.State.canLogs or A.State.canBans
  if not permission then A.Label(body,"Недостаточный допуск",40,A.C.red);return end
  local top=vgui.Create("DPanel",body);top:Dock(TOP);top:SetTall(42);top.Paint=nil
  local prev=A.Button(top,"←",function() A.PageNumber=math.max(1,A.PageNumber-1);pageRequest() end);prev:Dock(LEFT);prev:SetWide(50)
  local next=A.Button(top,"→",function() A.PageNumber=A.PageNumber+1;pageRequest() end);next:Dock(LEFT);next:SetWide(50)
  local refresh=A.Button(top,"Обновить",pageRequest);refresh:Dock(LEFT);refresh:SetWide(120)
  if category=="Реестр банов" then local unban=A.Button(top,"Снять бан по ID",function() body:Clear();form=vgui.Create("DScrollPanel",body);form:Dock(FILL);showForm(A.Commands.unban) end);unban:Dock(RIGHT);unban:SetWide(160) end
  if category=="Реестр банов" then A.Button(body,"Заблокировать игрока по SteamID64",function() body:Clear();form=vgui.Create("DScrollPanel",body);form:Dock(FILL);showForm(A.Commands.ban_sid) end) end
  A.Table=vgui.Create("DListView",body);A.Table:Dock(FILL);A.Table:SetMultiSelect(false)
  for _,label in ipairs(category=="Журнал" and {"Время","Кто","Команда","Цель","Статус"} or {"Игрок","SteamID64","Причина","До"}) do A.Table:AddColumn(label) end
  A.Table.OnRowSelected=function(_,_,row)
   if row.Data then
    if category=="Реестр банов" then A.OfflineSID=row.Data.sid;SetClipboardText(row.Data.sid)
    else output(row.Data.actor.." / "..row.Data.action.." / "..row.Data.target.." / "..row.Data.detail) end
   end
  end
  pageRequest();return
 end
 commandList=vgui.Create("DScrollPanel",body);commandList:Dock(LEFT);commandList:SetWide(math.Clamp(body:GetWide()*0.42,195,260));commandList:DockMargin(0,0,12,0)
 form=vgui.Create("DScrollPanel",body);form:Dock(FILL)
 local list={};for _,c in pairs(A.Commands) do if c.category==category then list[#list+1]=c end end
 table.sort(list,function(a,b) return a.id<b.id end)
 for _,c in ipairs(list) do
  local b=A.Button(commandList,c.label,function() showForm(c) end);b:SetTall(44);b:SetEnabled(available(c))
 end
 A.Label(form,"ПУЛЬТ УПРАВЛЕНИЯ",42,A.C.accent)
 A.Label(form,"01 / Отметьте игроков\n02 / Выберите команду\n03 / Заполните параметры\n04 / Проверьте результат",126,A.C.text)
 A.Label(form,"ПКМ по игроку — личное дело и SteamID64. Опасные и групповые действия требуют подтверждения. Все команды проверяются сервером и записываются в журнал.",100,A.C.muted)
end
function A.Open()
 if IsValid(frame) then frame:Close();return end
 frame=vgui.Create("DFrame");A.Frame=frame;frame:SetSize(math.min(1380,ScrW()-24),math.min(860,ScrH()-24));frame:Center();frame:SetTitle("");frame:ShowCloseButton(false);frame:MakePopup();frame:DockPadding(16,90,16,16)
 frame.Paint=function(_,w,h)
  surface.SetDrawColor(A.C.bg);surface.DrawRect(0,0,w,h)
  for y=0,h,5 do surface.SetDrawColor(255,255,230,2);surface.DrawRect(0,y,w,1) end
  surface.SetDrawColor(A.C.edge);surface.DrawOutlinedRect(0,0,w,h,2)
  draw.SimpleText("☢  "..A.Config.Title,"STA.Title",20,18,A.C.accent)
  draw.SimpleText("ZONE NETWORK  /  REMOTE ADMIN  /  "..A.Config.Version,"STA.Small",22,54,A.C.muted)
  local state=A.State
  draw.SimpleText(state and (state.map.."  •  "..#state.players.."/"..state.max.."  •  "..(A.Config.Roles[state.role] or A.Config.Roles.user).label) or "СОЕДИНЕНИЕ…","STA.Small",w-60,26,A.C.muted,TEXT_ALIGN_RIGHT)
  draw.SimpleText("ВЫБРАНО: "..#selectedIDs(),"STA.Small",w-60,52,A.C.accent,TEXT_ALIGN_RIGHT)
 end
 local close=A.Button(frame,"×",function() frame:Close() end);close:Dock(NODOCK);close:SetPos(frame:GetWide()-48,16);close:SetSize(30,32)
 local footer=A.Panel(frame,BOTTOM);footer:SetTall(122);footer:DockMargin(0,12,0,0)
 A.Label(footer,"ЖУРНАЛ СЕАНСА / ОТВЕТ СЕРВЕРА",20,A.C.accent)
 result=vgui.Create("RichText",footer);result:Dock(FILL);result.PerformLayout=function(self) self:SetFontInternal("STA.Small");self:SetFGColor(A.C.text) end
 local left=A.Panel(frame,LEFT);left:SetWide(math.Clamp(frame:GetWide()*.23,205,295));left:DockMargin(0,0,12,0)
 A.Label(left,"ЛИЧНЫЙ СОСТАВ",28,A.C.accent)
 search=A.Entry(left,"Поиск имени / SteamID64","");search.OnChange=refreshRoster
 local selectBar=vgui.Create("DPanel",left);selectBar:Dock(TOP);selectBar:SetTall(38);selectBar.Paint=nil
 local all=A.Button(selectBar,"Все",function()
  local count=0;for _,p in ipairs(A.State and A.State.players or {}) do if count<A.Config.MaxTargets then A.Selected[p.sid]=true;count=count+1 end end
 end);all:Dock(LEFT);all:SetWide(75)
 local none=A.Button(selectBar,"Сброс",function() A.Selected={} end);none:Dock(RIGHT);none:SetWide(90)
 roster=vgui.Create("DScrollPanel",left);roster:Dock(FILL)
 nav=A.Panel(frame,LEFT);nav:SetWide(165);nav:DockMargin(0,0,12,0);A.Label(nav,"РАЗДЕЛЫ",30,A.C.accent)
 for index,name in ipairs(A.Categories) do
  local b=A.Button(nav,string.format("%02d / ",index)..name,function() category=name;A.PageNumber=1;buildCategory() end);b:SetTall(38)
 end
 A.Button(nav,"Справка",function() Derma_Message("F7 / !admin / sta_menu — панель\nВыберите цели слева, затем раздел и команду.\nПКМ по игроку — сведения.\nВсе права проверяются на сервере.\n\nПервый владелец: серверная консоль\nsta_setrole STEAMID64 owner\n\nПодробная инструкция — README_RU.md.","КОМЕНДАНТ / Справка","Закрыть") end)
 body=A.Panel(frame,FILL)
 frame.OnClose=function() A.Send({kind="cancel"});timer.Remove("STALKER.AdminPoll");if IsValid(A.ConfirmFrame) then A.ConfirmFrame:Remove() end end
 A.Send({kind="state"})
 timer.Create("STALKER.AdminPoll",3,0,function() if IsValid(frame) then A.Send({kind="state"}) else timer.Remove("STALKER.AdminPoll") end end)
 output("Запрос допуска…",A.C.accent)
 frame.Initialized=false
end
net.Receive("sta.response",function()
 local size=net.ReadUInt(16);if size>60000 then return end
 local raw=util.Decompress(net.ReadData(size),524288);local data=raw and util.JSONToTable(raw);if type(data)~="table" then return end
 if data.kind=="denied" then notification.AddLegacy(data.message,NOTIFY_ERROR,5);if IsValid(frame) then frame:Close() end;return end
 if data.kind=="state" then
  A.State=data;refreshRoster()
  if IsValid(frame) and not frame.Initialized then frame.Initialized=true;frame:InvalidateLayout(true);body:InvalidateLayout(true);buildCategory();output("Допуск подтверждён. Сеть Зоны доступна.",A.C.green) end
 elseif data.kind=="confirm" then
  if not IsValid(frame) then return end
  if IsValid(A.ConfirmFrame) then A.ConfirmFrame:Remove() end
  A.ConfirmFrame=Derma_Query(data.label.."\n\n"..(#data.targets>0 and table.concat(data.targets,"\n") or data.sid or "Весь сервер").."\n\n"..tostring(data.detail)..(data.minutes and ("\nСрок: "..data.minutes.." мин.") or "")..(data.amount and ("\nКоличество/значение: "..data.amount) or "").."\n\nПодтверждение действует 25 секунд.","ПОДТВЕРЖДЕНИЕ КОМАНДЫ","Выполнить",function() A.Send({kind="confirm",token=data.token}) end,"Отмена",function() A.Send({kind="cancel"}) end)
 elseif data.kind=="result" then
  output(data.message or "Ответ получен",data.ok and A.C.green or A.C.red)
  for _,r in ipairs(data.results or {}) do output(r.name.." → "..r.message,r.ok and A.C.green or A.C.red) end
  if IsValid(frame) then A.Send({kind="state"}) end
 elseif data.kind=="page" then
  if not IsValid(A.Table) or (data.section=="logs" and category~="Журнал") or (data.section=="bans" and category~="Реестр банов") then return end
  A.Table:Clear()
  if not data.ok then output("Ошибка чтения журнала",A.C.red);return end
  for _,row in ipairs(data.rows) do local line
   if data.section=="logs" then line=A.Table:AddLine(os.date("%d.%m %H:%M",tonumber(row.time)),row.actor,row.action,row.target,row.status)
   else line=A.Table:AddLine(row.name,row.sid,row.reason,tonumber(row.expires)==0 and "Бессрочно" or os.date("%d.%m %H:%M",tonumber(row.expires))) end
   line.Data=row
  end
  output("Страница "..data.page.." / записей: "..#data.rows,A.C.muted)
 end
end)
concommand.Add("sta_menu",A.Open)
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
 if IsValid(target) then draw.SimpleText("КАМЕРА / "..target:Nick().." — F7 → Перемещение → Вернуться к себе","STA.Body",ScrW()/2,30,A.C.accent,TEXT_ALIGN_CENTER) end
end)
