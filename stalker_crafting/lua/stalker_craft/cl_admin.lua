-- Админ-панель мастерских: верстаки и постоянные костры (ставятся под прицелом, сохраняются по карте),
-- походные костры игроков. Встраивается во вкладку «Крафт» «Коменданта» (STALKER_CRAFT.BuildAdminPanel)
-- и открывается окном stcraft_admin. Каждое действие сервер проверяет сам (право craft).
local CR=STALKER_CRAFT
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local UI=CR.UI
local px=UI.px

function CR.AdminRequest(op,data)
 data=data or {};data.op=op
 C.Send("stalker_craft.admin",nil,data)
end
net.Receive("stalker_craft.admin",function(len)
 local d=C.Read(len);if not d then return end
 if d.denied then CR.Admin={denied=true} else CR.Admin=d;CR.AdminAt=CurTime() end
 if d.result and d.result.message then C.Toast(d.result.message,d.result.ok and "ok" or "warn",5) end
 if CR.AdminRoot and IsValid(CR.AdminRoot) then CR.FillAdmin(CR.AdminRoot) end
end)

function CR.BuildAdminPanel(parent)
 local root=vgui.Create("DPanel",parent);root:Dock(FILL);root.Paint=function() end
 CR.AdminRoot=root
 CR.FillAdmin(root)
 CR.AdminRequest("state")
 return root
end

local function coords(p) return p and string.format("%d  %d  %d",p.x or 0,p.y or 0,p.z or 0) or "" end
local function distance(p)
 local lp=LocalPlayer();if not p or not IsValid(lp) then return "" end
 local d=lp:GetPos():Distance(Vector(p.x,p.y,p.z))*.01905
 return d<1000 and string.format("%.0f м",d) or string.format("%.1f км",d/1000)
end
-- Карточка места: подпись, координаты, расстояние и кнопки.
local function placeCard(sc,title,place,kind)
 local card=UI.Card(sc,48,function(_,w,h)
  U.Text(U.Fit(title,"STALKER.Body",w*.32),"STALKER.Body",px(12),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  U.Text(coords(place.pos).."   ·   "..distance(place.pos),"STALKER.Mono",w*.34,h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end)
 UI.Button(card,"Убрать",function() CR.AdminRequest("remove",{kind=kind,id=place.id}) end,"danger",110)
 UI.Button(card,"Перейти",function() CR.AdminRequest("go",{kind=kind,id=place.id}) end,nil,110)
 return card
end

function CR.FillAdmin(root)
 root:Clear()
 local sc=UI.Scroll(root)
 local a=CR.Admin
 if not a then UI.Note(sc,"Загрузка данных мастерских…");return sc end
 if a.denied then UI.Note(sc,"Нужно право stalker_craft (верстаки, костры и крафт).","danger");return sc end
 if a.broken then UI.Note(sc,"Файл мест повреждён: правка заблокирована до восстановления "..tostring(a.path)..".","danger") end
 local benches,fires,temp=a.benches or {},a.fires or {},a.temp or {}
 UI.Head(sc,"Обстановка")
 UI.Card(sc,54,function(_,w,h)
  U.Text("Верстаков: "..#benches.." из "..tostring(a.maxBenches or "?").."   ·   постоянных костров: "..#fires.." из "..tostring(a.maxFires or "?"),"STALKER.Body",px(12),px(6),"text")
  U.Text(U.Fit("Походных костров игроков: "..#temp.."   ·   работ в процессе: "..tostring(a.jobs or 0).."   ·   места хранятся в "..tostring(a.path or ""),"STALKER.Small",w-px(24)),"STALKER.Small",px(12),px(28),"muted")
 end)
 local row=UI.Row(sc,32)
 UI.Button(row,"Верстак под прицелом",function() CR.AdminRequest("bench_add") end,"accent",210,LEFT)
 UI.Button(row,"Костёр под прицелом",function() CR.AdminRequest("fire_add",{style="ring"}) end,"accent",200,LEFT)
 UI.Button(row,"Бочка с огнём под прицелом",function() CR.AdminRequest("fire_add",{style="barrel"}) end,nil,240,LEFT)
 local row2=UI.Row(sc,32)
 UI.Button(row2,"Показать места (2 мин)",function() CR.AdminRequest("show") end,nil,210,LEFT)
 UI.Button(row2,"Потушить походные костры",function() CR.AdminRequest("clear_temp") end,"danger",240,LEFT)
 UI.Button(row2,"Обновить",function() CR.AdminRequest("state") end,nil,120,LEFT)

 UI.Head(sc,"Верстаки: "..#benches)
 if #benches==0 then UI.Note(sc,"Верстаков нет. Без верстака доступны только простые рецепты (с набором инструментов в рюкзаке).") end
 for i,p in ipairs(benches) do placeCard(sc,"Верстак №"..i,p,"benches") end

 UI.Head(sc,"Постоянные костры: "..#fires)
 if #fires==0 then UI.Note(sc,"Постоянных костров нет. Игроки разжигают походные костры из предмета «Походный костёр».") end
 for i,p in ipairs(fires) do placeCard(sc,((p.style=="barrel") and "Бочка с огнём" or "Костёр").." №"..i,p,"fires") end

 UI.Head(sc,"Походные костры игроков: "..#temp)
 for _,t in ipairs(temp) do
  local row3=t
  UI.Card(sc,44,function(_,w,h)
   U.Text(U.Fit(row3.owner~="" and row3.owner or "Неизвестный","STALKER.Body",w*.32),"STALKER.Body",px(12),h/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   local left=math.max(0,(tonumber(row3.left) or 0)-(CurTime()-(CR.AdminAt or CurTime())))
   U.Text("догорит через "..CR.FormatTime(left).."   ·   "..distance(row3.pos),"STALKER.Mono",w*.34,h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  end)
 end
 UI.Note(sc,"Верстаки и костры встают на землю под прицелом и возвращаются после перезапуска карты. Время крафта, процент ремонта, срок "..
  "и лечение костра, множители блюд — «Комендант» → «Настройки» → «Крафт и готовка». В окне stcraft_admin ПКМ по фону — прицелиться.")
 return sc
end

concommand.Add("stcraft_admin",function()
 if IsValid(CR.AdminFrame) then CR.AdminFrame:Remove() end
 local f=U.Window({title="Мастерские и костры",w=920,h=700,look=true,onClose=function() CR.AdminFrame=nil end})
 CR.AdminFrame=f
 CR.BuildAdminPanel(f)
end)
