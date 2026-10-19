-- Админ-панель заданий: квестодатели (поставить под прицелом, убрать под прицелом или из списка) и места заданий.
-- Встраивается во вкладку «Задания» «Коменданта» (STALKER_QUESTS.BuildAdminPanel) и открывается окном stq_menu.
-- Каждое действие сервер проверяет сам (право quests); панель только показывает снимок сервера.
local Q=STALKER_QUESTS
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local UI=Q.UI
local function px(n) return T.Px(n) end
Q.AdminDraft=Q.AdminDraft or {profile="barman",name="",point=""}

function Q.AdminRequest(op,data)
 data=data or {};data.op=op
 return C.Send("stalker_quests.admin",nil,data)
end
net.Receive("stalker_quests.admin",function(len)
 local d=C.Read(len);if not d then return end
 if d.denied then Q.Admin={denied=true} else Q.Admin=d end
 if d.result and d.result.message then C.Toast(d.result.message,d.result.ok and "ok" or "warn",5) end
 if IsValid(Q.AdminRoot) then Q.FillAdmin(Q.AdminRoot) end
end)

function Q.BuildAdminPanel(parent)
 local root=vgui.Create("DPanel",parent);root:Dock(FILL);root.Paint=function() end
 Q.AdminRoot=root
 Q.FillAdmin(root)
 Q.AdminRequest("state")
 return root
end

local function distance(p)
 local lp=LocalPlayer();if not p or not IsValid(lp) then return "" end
 return Q.Meters(lp:GetPos():Distance(Vector(p.x or 0,p.y or 0,p.z or 0)))
end
local function profileName(id) local p=Q.Profiles[id or ""];return p and p.name or tostring(id) end

local function npcSection(sc,a,draft)
 UI.Head(sc,"Квестодатели: "..#(a.npcs or {}).." из "..tostring(a.maxNPC or Q.Config.MaxNPC))
 local row=UI.Row(sc,32)
 UI.Button(row,"Убрать под прицелом",function() Q.AdminRequest("npc_remove",{aim=true}) end,"danger",190)
 UI.Button(row,"Поставить под прицелом",function() Q.AdminRequest("npc_add",{profile=draft.profile,name=draft.name}) end,"accent",210)
 local combo=vgui.Create("DComboBox",row);combo:Dock(LEFT);combo:SetWide(px(170));combo:DockMargin(0,0,px(6),0);U.Combo(combo)
 for _,p in ipairs(a.profiles or {}) do combo:AddChoice(p.name,p.id,p.id==draft.profile) end
 Q.AdminCombo=combo
 Q.AdminNameEntry=UI.Entry(row,"Своё имя (необязательно), например «Шустрый»",draft.name,function(v) draft.name=v end)
 local function aboutText() local p=Q.Profiles[draft.profile];return p and (p.name..": "..p.about) or "" end
 local note=UI.Note(sc,aboutText())
 combo.OnSelect=function(_,_,_,data)
  if not Q.Profiles[data or ""] then return end
  draft.profile=data
  if IsValid(note) then note:SetText(aboutText()) end
 end
 for _,r in ipairs(a.npcs or {}) do
  local rec=r
  local missing=type(rec.missing)=="table" and rec.missing or {}
  local card=UI.Card(sc,#missing>0 and 74 or 52,function(_,w,h)
   U.Text(U.Fit(profileName(rec.profile).." «"..tostring(rec.name).."»","STALKER.Body",w*.42),"STALKER.Body",px(12),px(8),rec.spawned and "text" or "warn")
   U.Text(rec.id.."   ·   "..distance(rec.pos)..(rec.spawned and "" or "   ·   не на карте"),"STALKER.Mono",w*.44,px(10),"muted")
   local avail=rec.available and ("Доступно шаблонов: "..rec.available) or ""
   U.Text(avail,"STALKER.Small",px(12),px(28),"muted")
   if #missing>0 then U.Text(U.Fit("Недоступно: "..table.concat(missing,"; "),"STALKER.Small",w-px(150)),"STALKER.Small",px(12),px(46),"warn") end
  end)
  UI.Button(card,"Убрать",function() Q.AdminRequest("npc_remove",{id=rec.id}) end,"danger",110)
 end
 UI.Note(sc,"Квестодатель встаёт на землю под прицелом лицом к вам. Расстановка сохраняется в data/stalker_quests/<карта>.json "..
  "и восстанавливается после рестарта и очистки карты. В окне stq_menu ПКМ по фону — прицелиться.")
end
local function pointSection(sc,a,draft)
 UI.Head(sc,"Места заданий «Разведка»: "..#(a.points or {}).." из "..tostring(a.maxPoints or Q.Config.MaxPoints))
 local row=UI.Row(sc,32)
 UI.Button(row,"Показать всё (2 мин)",function() Q.AdminRequest("show") end,nil,180)
 UI.Button(row,"Добавить под прицелом",function() Q.AdminRequest("point_add",{name=draft.point}) end,"accent",200)
 Q.AdminPointEntry=UI.Entry(row,"Название места, например «Старая водокачка»",draft.point,function(v) draft.point=v end)
 for _,p in ipairs(a.points or {}) do
  local point=p
  local card=UI.Card(sc,44,function(_,w,h)
   U.Text(U.Fit(tostring(point.name),"STALKER.Body",w*.45),"STALKER.Body",px(12),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   U.Text(point.id.."   ·   "..distance(point.pos),"STALKER.Mono",w*.47,h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  end)
  UI.Button(card,"Удалить",function() Q.AdminRequest("point_remove",{id=point.id}) end,"danger",110)
 end
 UI.Note(sc,"Без своих мест разведка ведёт к точкам интереса событий, полям аномалий и логовам Зоны. "..
  "Лимиты, награды, сроки и обучение — «Комендант» → «Настройки» → «Задания».")
end
function Q.FillAdmin(root)
 root:Clear()
 local sc=UI.Scroll(root)
 local a=Q.Admin
 if not a then UI.Note(sc,"Загрузка данных заданий…");return sc end
 if a.denied then UI.Note(sc,"Нужно право stalker_quests (управление заданиями и квестодателями).","danger");return sc end
 if a.broken then UI.Note(sc,"Файл квестодателей повреждён: правка заблокирована до восстановления data/stalker_quests/<карта>.json.","danger") end
 UI.Card(sc,44,function(_,w,h)
  U.Text("Игроков с заданиями в сети: "..tostring(a.players or 0).."   ·   активных заданий: "..tostring(a.active or 0).."   ·   шаблонов: "..tostring(a.templates or 0),
   "STALKER.Small",px(12),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end)
 npcSection(sc,a,Q.AdminDraft)
 pointSection(sc,a,Q.AdminDraft)
 return sc
end

concommand.Add("stq_menu",function()
 if IsValid(Q.AdminFrame) then Q.AdminFrame:Remove() end
 local f=U.Window({title="Задания и квестодатели",w=880,h=700,look=true,onClose=function() Q.AdminFrame=nil end})
 Q.AdminFrame=f
 Q.BuildAdminPanel(f)
end)
