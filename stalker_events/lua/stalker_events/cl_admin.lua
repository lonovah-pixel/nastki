-- Админ-панель событий: активные события, ручной запуск и остановка, планировщик, места событий, точки интереса.
-- Встраивается во вкладку «События» «Коменданта» (STALKER_EVENTS.BuildAdminPanel) и открывается окном stev_menu.
-- Каждое действие сервер проверяет сам (право events); панель только показывает снимок сервера.
local E=STALKER_EVENTS
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local UI=E.UI
local function px(n) return T.Px(n) end
E.AdminDraft=E.AdminDraft or {spot="",poi="",poiKind="note",flag=true,here=false}

function E.AdminRequest(op,data)
 data=data or {};data.op=op
 C.Send("stalker_events.admin",nil,data)
end
net.Receive("stalker_events.admin",function(len)
 local d=C.Read(len);if not d then return end
 if d.denied then E.Admin={denied=true} else E.Admin=d;E.AdminAt=CurTime() end
 if d.result and d.result.message then C.Toast(d.result.message,d.result.ok and "ok" or "warn",5) end
 if IsValid(E.AdminRoot) then E.FillAdmin(E.AdminRoot) end
end)

function E.BuildAdminPanel(parent)
 local root=vgui.Create("DPanel",parent);root:Dock(FILL);root.Paint=function() end
 E.AdminRoot=root
 E.FillAdmin(root)
 E.AdminRequest("state")
 return root
end

local function coords(p) return p and string.format("%d  %d  %d",p.x or 0,p.y or 0,p.z or 0) or "" end
local function distance(p)
 local lp=LocalPlayer();if not p or not IsValid(lp) then return "" end
 local d=lp:GetPos():Distance(Vector(p.x,p.y,p.z))*.01905
 return d<1000 and string.format("%.0f м",d) or string.format("%.1f км",d/1000)
end
-- Кнопка-переключатель: подпись и подсветка следуют за значением draft[key].
local function toggle(parent,draft,key,on,off,wide)
 local b=UI.Button(parent,draft[key] and on or off,function(self)
  draft[key]=not draft[key];self.Label=draft[key] and on or off;self.Active=draft[key]
 end,nil,wide)
 b.Active=draft[key]
 return b
end

local function activeSection(sc,a)
 UI.Head(sc,"Идёт сейчас")
 local any=false
 for _,ev in ipairs(a.events or {}) do
  if ev.active then
   any=true;local row=ev
   local card=UI.Card(sc,66,function(_,w,h)
    U.Text(row.name,"STALKER.Head",px(12),px(8),"accent")
    U.Text("Осталось "..E.FormatTime(E.Left(row.left,E.AdminAt)),"STALKER.Mono",px(12),px(36),"text")
    U.Text(U.Fit(row.info or (row.where and ("Место: "..row.where)) or "","STALKER.Small",math.max(10,w-px(300))),"STALKER.Small",px(140),px(37),"muted")
   end)
   UI.Button(card,"Остановить",function() E.AdminRequest("stop",{id=row.id}) end,"danger",140)
  end
 end
 if not any then UI.Note(sc,"Активных событий нет.") end
end

local function launchSection(sc,a,draft)
 UI.Head(sc,"Запуск событий")
 local row=UI.Row(sc,32)
 toggle(row,draft,"here","Место: под прицелом","Место: автоматически",220)
 local info=vgui.Create("DPanel",row);info:Dock(FILL)
 info.Paint=function(_,w,h) U.Text(U.Fit("Груз, гон и рейд можно высадить под прицелом; шторм и охота выбирают место сами.","STALKER.Small",w),"STALKER.Small",0,h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
 local busy=false
 for _,ev in ipairs(a.events or {}) do if ev.active then busy=true end end
 for _,ev in ipairs(a.events or {}) do
  local item=ev
  local card=UI.Card(sc,66,function(_,w,h)
   U.Text(item.name,"STALKER.Body",px(12),px(6),item.active and "accent" or "text")
   U.Text(U.Fit(item.desc or "","STALKER.Small",math.max(10,w-px(180))),"STALKER.Small",px(12),px(26),"muted")
   U.Text("Вес "..tostring(item.weight).." · автозапуск от "..tostring(item.minPlayers).." игроков","STALKER.Small",px(12),px(44),"muted")
  end)
  local b=UI.Button(card,item.active and "Идёт" or "Запустить",function() E.AdminRequest("start",{id=item.id,here=draft.here}) end,"accent",140)
  -- Одновременно идёт одно крупное событие: пока оно идёт, запуск других недоступен.
  if busy then b:SetEnabled(false) end
 end
end

local function schedulerSection(sc,a)
 UI.Head(sc,"Планировщик")
 UI.Card(sc,72,function(_,w,h)
  U.Text(a.scheduler and "Автоматические события включены" or "Автоматические события выключены","STALKER.Body",px(12),px(6),a.scheduler and "ok" or "warn")
  local nextText=a.next and E.FormatTime(E.Left(a.next,E.AdminAt)) or "—"
  local iv=a.interval or {}
  U.Text("Следующее через: "..nextText.."   ·   интервал "..tostring(iv[1] or "?").."–"..tostring(iv[2] or "?").." мин","STALKER.Small",px(12),px(30),"text")
  U.Text(U.Fit("Игроков: "..tostring(a.players or 0).."   ·   NPC событий: "..tostring(a.npc or 0).."   ·   маячков: "..tostring(a.beacons or 0)..
   (a.lastError and ("   ·   последний отказ: "..a.lastError) or ""),"STALKER.Small",math.max(10,w-px(24))),"STALKER.Small",px(12),px(48),"muted")
 end)
 local row=UI.Row(sc,32)
 UI.Button(row,a.scheduler and "Выключить" or "Включить",function() E.AdminRequest("scheduler",{on=not a.scheduler}) end,a.scheduler and "danger" or "accent",130)
 UI.Button(row,"Отложить на 30 мин",function() E.AdminRequest("schedule",{minutes=30}) end,nil,170)
 UI.Button(row,"Следующее через 1 мин",function() E.AdminRequest("schedule",{minutes=1}) end,nil,190)
 UI.Note(sc,"Интервал, минимум игроков, веса, длительности и награды — «Комендант» → «Настройки» → «События».")
end

local function spotsSection(sc,a,draft)
 UI.Head(sc,"Места событий: "..#(a.spots or {}).." из "..tostring(a.maxSpots or 64))
 local row=UI.Row(sc,32)
 UI.Button(row,"Показать (2 мин)",function() E.AdminRequest("spot_show") end,nil,150)
 UI.Button(row,"Добавить под прицелом",function() E.AdminRequest("spot_add",{name=draft.spot}) end,"accent",200)
 E.SpotEntry=UI.Entry(row,"Название места, например «Вертолётная площадка»",draft.spot,function(v) draft.spot=v end)
 for _,s in ipairs(a.spots or {}) do
  local spot=s
  local card=UI.Card(sc,48,function(_,w,h)
   U.Text(U.Fit(spot.name,"STALKER.Body",w*.4),"STALKER.Body",px(12),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   U.Text(coords(spot.pos).."   ·   "..distance(spot.pos),"STALKER.Mono",w*.42,h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  end)
  UI.Button(card,"Удалить",function() E.AdminRequest("spot_remove",{id=spot.id}) end,"danger",110)
 end
 UI.Note(sc,"Без размеченных мест события берут центры полей аномалий и логов Зоны или случайную землю рядом с игроками. В окне stev_menu ПКМ по фону — прицелиться.")
end

local function poiSection(sc,a,draft)
 UI.Head(sc,"Точки интереса: "..#(a.pois or {}).." из "..tostring(a.maxPOI or 128))
 local row=UI.Row(sc,32)
 UI.Button(row,"Поставить под прицелом",function() E.AdminRequest("poi_add",{name=draft.poi,kind=draft.poiKind,flag=draft.flag}) end,"accent",200)
 toggle(row,draft,"flag","Флажок в мире: да","Флажок в мире: нет",170)
 local combo=vgui.Create("DComboBox",row);combo:Dock(LEFT);combo:SetWide(px(150));combo:DockMargin(0,0,px(6),0);U.Combo(combo)
 for _,t in ipairs(E.POITypes) do combo:AddChoice(t[2],t[1],t[1]==draft.poiKind) end
 combo.OnSelect=function(_,_,_,data) if E.POITypeName[data or ""] then draft.poiKind=data end end
 E.POICombo=combo
 E.POIEntry=UI.Entry(row,"Название точки",draft.poi,function(v) draft.poi=v end)
 for _,p in ipairs(a.pois or {}) do
  local poi=p
  local card=UI.Card(sc,48,function(_,w,h)
   U.Text(U.Fit((E.POITypeName[poi.kind] or "Точка").." · "..poi.name,"STALKER.Body",w*.4),"STALKER.Body",px(12),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   U.Text(distance(poi.pos),"STALKER.Mono",w*.42,h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  end)
  UI.Button(card,"Удалить",function() E.AdminRequest("poi_remove",{id=poi.id}) end,"danger",110)
  UI.Button(card,poi.flag and "Флажок: да" or "Флажок: нет",function() E.AdminRequest("poi_edit",{id=poi.id,flag=not poi.flag}) end,nil,130)
 end
 UI.Note(sc,"Точки интереса видны всем игрокам на экране и на карте КПК, а с флажком — ещё и флагом в мире.")
end

function E.FillAdmin(root)
 root:Clear()
 local sc=UI.Scroll(root)
 local a=E.Admin
 if not a then UI.Note(sc,"Загрузка данных событий…");return sc end
 if a.denied then UI.Note(sc,"Нужно право stalker_events (управление событиями Зоны).","danger");return sc end
 local draft=E.AdminDraft
 if a.broken then UI.Note(sc,"Файл мест повреждён: правка мест и точек заблокирована до восстановления data/stalker_events/<карта>.json.","danger") end
 activeSection(sc,a)
 launchSection(sc,a,draft)
 schedulerSection(sc,a)
 spotsSection(sc,a,draft)
 poiSection(sc,a,draft)
 return sc
end

concommand.Add("stev_menu",function()
 if IsValid(E.AdminFrame) then E.AdminFrame:Remove() end
 local f=U.Window({title="События Зоны",w=860,h=700,look=true,onClose=function() E.AdminFrame=nil end})
 E.AdminFrame=f
 E.BuildAdminPanel(f)
end)
