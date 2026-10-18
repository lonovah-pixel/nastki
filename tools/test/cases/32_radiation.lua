-- Радиация 2.0: формат зон с id, миграция старого массива, атомарное сохранение и блокировка повреждённого файла,
-- серверный API и сеть редактора, доза с учётом износа защиты, настройки, панель администратора и HUD.
-- Область мира: X 2 000 000…2 400 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local R,C,S=STALKER_RAD,STALKER_CORE,STALKER_SETTINGS
section("Радиация 2.0: загрузка ("..M.Realm..")")
check(R and R.Config and R.Limits and type(R.ZoneRate)=="function" and type(R.CleanFields)=="function","общие функции радиации")
for _,row in ipairs({{"decay","server"},{"damage_threshold","shared"},{"max_damage","server"},{"max_protection","server"},{"faction_factor","server"},{"zones_limit","shared"}}) do
 local def=S.Defs["radiation."..row[1]]
 check(def and def.category=="Радиация" and def.realm==row[2],"настройка radiation."..row[1].." ("..row[2]..")")
end
-- Формула фона: без спада — постоянный, со спадом — линейно к границе; выключенная зона не облучает.
local z={pos={x=0,y=0,z=0},radius=400,rate=4,falloff=true,enabled=true}
check(math.abs(R.ZoneRate(z,Vector(200,0,0))-2)<1e-6 and R.ZoneRate(z,Vector(0,0,0))==4 and R.ZoneRate(z,Vector(401,0,0))==0,"спад к краю")
z.falloff=false;check(R.ZoneRate(z,Vector(399,0,0))==4,"без спада фон одинаков");z.enabled=false;check(R.ZoneRate(z,Vector(0,0,0))==0,"выключенная зона")
local f,err=R.CleanFields({name="  Свалка ",radius=300.4,rate=2.345},false)
check(f and f.name=="Свалка" and f.radius==300 and f.rate==2.35 and f.falloff==true and f.enabled==true,"проверка полей: обрезка, округление, значения по умолчанию")
check(not R.CleanFields({radius=10,rate=1},false) and not R.CleanFields({radius=300,rate=500},false) and not R.CleanFields({name="a\nb",radius=300,rate=1},false),"недопустимые поля отклонены")
check(not R.CleanFields({name=string.rep("я",40),radius=300,rate=1},false),"слишком длинное имя")
local part=R.CleanFields({falloff=false},true);check(part and part.falloff==false and part.radius==nil and part.name==nil,"частичная правка не трогает остальные поля")
check(R.CleanPos(Vector(1.26,2,3)).x==1.3 and not R.CleanPos({x=0/0,y=0,z=0}),"позиция: округление и отказ от NaN")

local function lastSent(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end

if SERVER then
 local X=2000000
 local path=R.Path
 check(path=="stalker_radiation/gm_test.json","путь файла зон карты")

 section("Радиация 2.0: миграция старого формата")
 local legacy=util.TableToJSON({
  {pos={x=X+1000,y=0,z=0},radius=300,rate=2},
  {pos={x=X+5000,y=0,z=0},radius=10,rate=150},
  {pos={x=X+9000,y=0,z=0},radius=200,rate=0},
  {radius=100,rate=1},
  {pos={x=X+12000,y=0,z=0},radius=250,rate=1.5}})
 file.Write(path,legacy)
 check(R.Load() and R.Ready,"старый файл загружен и перенесён")
 check(#R.Zones==4 and R.Migrated and R.Migrated.count==4 and R.Migrated.skipped==1,"перенесено 4 зоны, пропущена запись без координат")
 local z1,z2,z3,z4=R.Zones[1],R.Zones[2],R.Zones[3],R.Zones[4]
 check(z1.id=="rad_1" and z1.name=="Зона 1" and z1.radius==300 and z1.rate==2 and z1.falloff==false and z1.enabled==true,"поля перенесённой зоны: id, имя, без спада")
 check(z2.radius==32 and z2.rate==100,"значения вне границ приведены к границам")
 check(z3.enabled==false and z3.rate==0.01,"бездействовавшая зона перенесена выключенной")
 check(z4.id=="rad_4" and z4.name=="Зона 5","имя хранит исходный номер")
 check(R.Migrated.backup and file.Read(R.Migrated.backup,"DATA")==legacy,"копия старого файла сохранена без изменений")
 local saved=util.JSONToTable(file.Read(path,"DATA") or "")
 check(saved and saved.version==2 and saved.next==5 and #saved.zones==4 and saved.zones[1].id=="rad_1","файл в новом формате")
 check(not file.Exists(R.PendingPath,"DATA"),"временная копия удалена после записи")

 section("Радиация 2.0: API зон")
 local id=R.AddZone({name="Ржавый тягач",pos=Vector(X+20000,0,0),radius=400,rate=4})
 check(id=="rad_5" and R.ByID[id] and R.ByID[id].falloff==true,"AddZone → стабильный id, спад по умолчанию")
 local bad,why=R.AddZone({name="x",pos=Vector(X,0,0),radius=5,rate=1});check(bad==nil and why and why:find("Радиус",1,true),"AddZone отклоняет малый радиус: "..tostring(why))
 bad,why=R.AddZone({name="x",radius=300,rate=1});check(bad==nil and why,"AddZone без позиции отклонён")
 check(R.UpdateZone(id,{name="Тягач",rate=6,falloff=false}) and R.ByID[id].name=="Тягач" and R.ByID[id].rate==6 and R.ByID[id].falloff==false and R.ByID[id].radius==400,"UpdateZone меняет только переданные поля")
 check(R.UpdateZone(id,{name=""}) and R.ByID[id].name=="Тягач","пустое имя при правке оставляет прежнее")
 check(not R.UpdateZone(id,{radius=99999}) and R.ByID[id].radius==400,"UpdateZone отклоняет недопустимое значение")
 check(not R.UpdateZone("rad_404",{rate=1}),"правка несуществующей зоны")
 check(R.RemoveZone("rad_2") and not R.ByID.rad_2 and #R.Zones==4,"RemoveZone по id")
 local id6=R.AddZone({pos=Vector(X+30000,0,0),radius=300,rate=1})
 check(id6=="rad_6" and R.ByID[id6].name=="Зона 6","id удалённой зоны не переиспользуется, имя по умолчанию")
 -- Лимит зон из настроек.
 check(S.Set("radiation.zones_limit",#R.Zones) and R.Config.ZonesLimit==#R.Zones,"лимит зон через настройки")
 bad,why=R.AddZone({pos=Vector(X+31000,0,0),radius=300,rate=1});check(bad==nil and why and why:find("лимит",1,true),"лимит зон соблюдается")
 S.Set("radiation.zones_limit",nil);check(R.Config.ZonesLimit==128,"сброс лимита")
 -- Перечитывание: ids, имена и параметры совпадают.
 local before=util.TableToJSON(R.Zones)
 check(R.Load() and util.TableToJSON(R.Zones)==before and R.NextID==7,"после перезагрузки зоны и счётчик id совпадают")

 section("Радиация 2.0: повреждённый файл")
 local good=file.Read(path,"DATA")
 -- Сообщения об ошибке файла перехватываем: они ожидаемы и проверяются ниже.
 local logged={};local errorNoHalt=ErrorNoHalt;ErrorNoHalt=function(s) logged[#logged+1]=s end
 file.Write(path,"{broken json")
 check(not R.Load() and not R.Ready and R.LoadError and #R.Zones==0,"повреждённый JSON блокирует редактирование")
 bad,why=R.AddZone({pos=Vector(X,0,0),radius=300,rate=1})
 check(bad==nil and why and why:find("заблокировано",1,true),"AddZone при блокировке отклонён")
 check(file.Read(path,"DATA")=="{broken json","повреждённый файл не перезаписан")
 -- Одна неверная запись: исправные зоны действуют, но файл не трогаем.
 local partial=util.TableToJSON({version=2,next=3,zones={{id="rad_1",name="A",pos={x=X+1000,y=0,z=0},radius=300,rate=2,falloff=true,enabled=true},{id="rad_1",name="B",pos={x=X,y=0,z=0},radius=300,rate=2}}})
 file.Write(path,partial)
 check(not R.Load() and #R.Zones==1 and R.LoadError:find("повторяющийся",1,true),"повтор id: исправная зона работает, правка заблокирована")
 check(not R.RemoveZone("rad_1") and file.Read(path,"DATA")==partial,"удаление при блокировке не меняет файл")
 file.Write(path,util.TableToJSON({version=7,zones={}}));check(not R.Load() and R.LoadError:find("формат",1,true),"неизвестная версия формата")
 ErrorNoHalt=errorNoHalt
 check(#logged==3 and logged[1]:find("заблокировано",1,true),"ошибки файла зон пишутся в журнал сервера")
 file.Write(path,good)
 local admin=M.addPlayer({nick="Радиолог",superadmin=true,pos=Vector(X+100000,0,0),aim=Vector(X+100500,0,0)})
 M.command(admin,"stalker_rad_reload")
 check(R.Ready and #R.Zones==5,"stalker_rad_reload перечитывает исправленный файл")

 section("Радиация 2.0: консоль")
 check(C.CanAdmin(admin,"radiation"),"у суперадмина есть право radiation")
 M.command(admin,"stalker_rad_add","350","3","0","Старый","карьер")
 local added=R.Zones[#R.Zones]
 check(added and added.name=="Старый карьер" and added.radius==350 and added.rate==3 and added.falloff==false and added.pos.x==X+100500,"stalker_rad_add по прицелу с именем и спадом")
 local user=M.addPlayer({nick="Простой сталкер",pos=Vector(X+100000,500,0),aim=Vector(X+100600,0,0)})
 local count=#R.Zones
 M.command(user,"stalker_rad_add","300","2");M.command(user,"stalker_rad_remove",added.id)
 check(#R.Zones==count,"игрок без права не меняет зоны")
 admin._chat={};M.command(admin,"stalker_rad_list")
 check(#admin._chat==count+1 and admin._chat[1]:find("Радиационные зоны",1,true) and admin._chat[#admin._chat]:find(added.id,1,true),"stalker_rad_list выводит зоны")
 M.command(admin,"stalker_rad_remove",tostring(count))
 check(#R.Zones==count-1 and not R.ByID[added.id],"stalker_rad_remove по номеру")
 M.command(admin,"stalker_rad_remove","rad_6")
 check(not R.ByID.rad_6,"stalker_rad_remove по id")

 section("Радиация 2.0: сеть редактора")
 M.netSent={}
 local l,v=packet({op="list"});M.netReceive("stalker_rad.request",l,admin,v)
 local st=decode(lastSent("stalker_rad.state",admin))
 check(st and st.ready==true and #st.zones==#R.Zones and st.limit==128 and st.map=="gm_test" and R.Watchers[admin],"список зон для администратора, подписка на изменения")
 local second=M.addPlayer({nick="Второй радиолог",superadmin=true,pos=Vector(X+110000,0,0)})
 l,v=packet({op="list"});M.netReceive("stalker_rad.request",l,second,v)
 M.netSent={}
 l,v=packet({op="create",placement="aim",name="Котлован",radius=500,rate=3,falloff=true,enabled=true})
 M.netReceive("stalker_rad.request",l,admin,v)
 st=decode(lastSent("stalker_rad.state",admin))
 local nid=st and st.result and st.result.id
 check(st and st.result.ok and nid and R.ByID[nid] and R.ByID[nid].pos.x==X+100500 and R.ByID[nid].name=="Котлован","создание по прицелу через сеть")
 local other=decode(lastSent("stalker_rad.state",second))
 check(other and #other.zones==#R.Zones and other.result==nil,"второй администратор получил обновление")
 l,v=packet({op="update",id=nid,name="Котлован-2",radius=450,rate=1.5,falloff=false,enabled=false,pos={x=0,y=0,z=0}})
 M.netReceive("stalker_rad.request",l,admin,v)
 local nz=R.ByID[nid]
 check(nz.name=="Котлован-2" and nz.radius==450 and nz.rate==1.5 and nz.falloff==false and nz.enabled==false and nz.pos.x==X+100500,"правка через сеть (позиция правкой не меняется)")
 l,v=packet({op="move",id=nid,placement="feet"});M.netReceive("stalker_rad.request",l,admin,v)
 check(R.ByID[nid].pos.x==X+100000,"перемещение под администратора")
 admin:SetPos(Vector(X+150000,0,0))
 l,v=packet({op="teleport",id=nid});M.netReceive("stalker_rad.request",l,admin,v)
 check(admin:GetPos():Distance(Vector(X+100000,0,0))<200 and admin.StaReturn,"телепорт к зоне с точкой возврата")
 l,v=packet({op="create",placement="aim",radius=1,rate=3});M.netReceive("stalker_rad.request",l,admin,v)
 st=decode(lastSent("stalker_rad.state",admin));check(st and st.result.ok==false and st.result.message:find("Радиус",1,true),"недопустимая зона: понятная ошибка")
 l,v=packet({op="explode"});M.netReceive("stalker_rad.request",l,admin,v)
 st=decode(lastSent("stalker_rad.state",admin));check(st and st.result.ok==false,"неизвестное действие отклонено")
 count=#R.Zones;M.netSent={}
 l,v=packet({op="remove",id=nid});M.netReceive("stalker_rad.request",l,user,v)
 st=decode(lastSent("stalker_rad.state",user))
 check(#R.Zones==count and R.ByID[nid] and st and st.denied,"игрок без права получает отказ")
 l,v=packet({op="remove",id=nid});M.netReceive("stalker_rad.request",l,admin,v)
 check(not R.ByID[nid],"удаление через сеть")
 if sql.TableExists("sta_audit") then
  check(tonumber(sql.QueryValue("SELECT COUNT(*) FROM sta_audit WHERE action LIKE 'radiation_%'") or 0)>=4,"действия записаны в журнал «Коменданта»")
 end
 l,v=packet({op="reload"});M.netReceive("stalker_rad.request",l,admin,v)
 st=decode(lastSent("stalker_rad.state",admin));check(st and st.result.ok and st.ready and #st.zones==#R.Zones,"перечитывание файла из панели")
 l,v=packet({op="close"});M.netReceive("stalker_rad.request",l,second,v)
 check(not R.Watchers[second],"закрытие панели снимает подписку")

 section("Радиация 2.0: доза, защита и износ")
 local zid=R.AddZone({name="Тестовая",pos=Vector(X+200000,0,0),radius=400,rate=4,falloff=true})
 local p=TEST.join({nick="Облучаемый",pos=Vector(X+260000,0,0)})
 check(R.GetDose(p)==0 and R.SetDose(p,12.5)==12.5 and p:GetNW2Float("stalker_dose",0)==12.5 and p.StalkerInventory.dose==12.5,"SetDose: инвентарь и NW2")
 check(R.AddDose(p,200)==100 and R.AddDose(p,-500)==0,"AddDose ограничивает 0..100")
 local ghost=M.addPlayer({nick="Без инвентаря"});check(R.AddDose(ghost,5)==false,"доза не меняется без загруженного инвентаря")
 p:SetPos(Vector(X+200200,0,0))
 local rate,prot=R.Exposure(p);check(math.abs(rate-2)<1e-6 and prot==0,"фон со спадом на половине радиуса: "..rate)
 M.advance(1,1)
 check(math.abs(p:GetNW2Float("stalker_rad_rate",0)-2)<1e-6 and math.abs(R.GetDose(p)-2)<0.01,"доза растёт на фон: "..R.GetDose(p))
 local inv=p.StalkerInventory;local IS=STALKER_INV
 inv.equipment.armor=IS.NewItem("hazmat",1,100)
 rate,prot=R.Exposure(p);check(math.abs(prot-.7)<1e-6,"защита целого костюма")
 inv.equipment.armor.durability=50
 rate,prot=R.Exposure(p);check(math.abs(prot-.7*IS.ConditionFactor(inv.equipment.armor))<1e-6 and prot<.7,"износ снижает защиту: "..prot)
 inv.equipment.armor.durability=0
 rate,prot=R.Exposure(p);check(prot==0,"сломанный костюм не защищает")
 inv.equipment.armor.durability=100
 S.Set("radiation.max_protection",0.5);rate,prot=R.Exposure(p);check(prot==0.5,"предел защиты из настроек")
 S.Set("radiation.max_protection",nil)
 local d0=R.GetDose(p);M.advance(1,1)
 check(math.abs(R.GetDose(p)-(d0+2*(1-.7)))<0.01 and math.abs(p:GetNW2Float("stalker_rad_prot",0)-.7)<1e-6,"доза с учётом защиты, NW2 защиты")
 inv.equipment.armor=nil
 -- Территория группировки: уровень точки × коэффициент.
 if STFW and STFW.World and STFW.World.points then
  STFW.World.points.test_rad={id="test_rad",pos={x=X+300000,y=0,z=0},radius=300,height=200,radiation=50}
  p:SetPos(Vector(X+300100,0,0))
  rate=R.Exposure(p);check(math.abs(rate-5)<1e-6,"радиация территории ×0.1: "..rate)
  S.Set("radiation.faction_factor",0.2);rate=R.Exposure(p);check(math.abs(rate-10)<1e-6,"коэффициент территорий из настроек")
  S.Set("radiation.faction_factor",nil);STFW.World.points.test_rad=nil
 end
 -- Порог и урон.
 p:SetPos(Vector(X+260000,0,0))
 R.SetDose(p,50);local hp=p:Health();M.advance(1,1)
 check(p:Health()<hp and p._lastDamage and p._lastDamage:GetDamageType()==DMG_RADIATION,"урон выше порога")
 S.Set("radiation.max_damage",0);R.SetDose(p,50);hp=p:Health();M.advance(1,1)
 check(p:Health()==hp,"MaxDamage 0 — облучение не ранит");S.Set("radiation.max_damage",nil)
 S.Set("radiation.decay",1);R.SetDose(p,10);M.advance(1,1);check(math.abs(R.GetDose(p)-9)<0.01,"вывод дозы из настроек");S.Set("radiation.decay",nil)
 R.SetDose(p,40);M.kill(p);check(R.GetDose(p)==0 and p:GetNW2Float("stalker_dose",1)==0,"смерть сбрасывает дозу")
 M.spawn(p)
 -- Без аддона инвентаря и группировок доза хранится в поле игрока до конца сессии.
 local inventory,factions=STALKER_INV,STFW;STALKER_INV=nil;STFW=nil
 local solo=M.addPlayer({nick="Одиночка без инвентаря",pos=Vector(X+200000,0,0)})
 local ok=M.protect("rad tick no inventory",R.Tick)
 check(ok and math.abs(R.GetDose(solo)-4)<0.01 and solo:GetNW2Float("stalker_dose",0)==R.GetDose(solo),"без инвентаря доза идёт в поле игрока: "..R.GetDose(solo))
 STALKER_INV,STFW=inventory,factions;M.removePlayer(solo)
 -- Уборка: зоны теста не должны облучать другие сценарии.
 R.RemoveZone(zid)
 for _,q in ipairs({admin,user,second,ghost,p}) do M.removePlayer(q) end
else
 section("Радиация 2.0: клиент")
 check(type(R.BuildAdminPanel)=="function" and type(R.OpenMenu)=="function" and M.commands.stalker_rad_menu,"панель, окно и команда stalker_rad_menu")
 check(R.Lower("ПРИВЕТ Ёжик Zone")=="привет ёжик zone","поиск без учёта регистра кириллицы")
 local T=STALKER_THEME
 check(R.Color(50)==T.C.danger and R.Color(5)==T.C.warn and R.Color(0)==T.C.ok,"цвета дозы из темы")
 T.Apply("pda");check(R.Color(50)==T.C.danger and R.Colors.muted==T.C.muted,"смена темы меняет цвета дозиметра");T.Apply("zone")
 local line=R.HUDLine(2,.5);check(line:find("ФОН +2.00",1,true) and line:find("ЗАЩИТА 50%",1,true),"строка фона и защиты")
 check(R.HUDLine(0,0)=="ФОН В НОРМЕ","фон в норме")
 local lp=LocalPlayer();lp:SetNW2Float("stalker_dose",50);lp:SetNW2Float("stalker_rad_rate",2);lp:SetNW2Float("stalker_rad_prot",.3)
 M.protect("rad hud",R.DrawHUD);M.protect("rad hud hook",hook.Run,"HUDPaint");M.protect("rad fx",hook.Run,"RenderScreenspaceEffects")
 lp:SetNW2Float("stalker_dose",0);lp:SetNW2Float("stalker_rad_rate",0)
 -- Панель: заглушки Derma делаем валидными, как в тесте «Коменданта».
 local create=vgui.Create
 vgui.Create=function(...) local p=create(...);if type(p)=="table" and rawget(p,"_stub") then rawset(p,"IsValid",function() return true end) end;return p end
 M.netSent={}
 local parent=vgui.Create("DPanel")
 local root
 M.protect("rad panel build",function() root=R.BuildAdminPanel(parent) end)
 local view;for v in pairs(R.Views) do if v.root==root then view=v end end
 check(root and view and R.PanelOpen and R.PreviewActive(),"панель построена, предпросмотр включён")
 local req=lastSent("stalker_rad.request");local body=req and util.JSONToTable(util.Decompress(req.data[2]))
 check(body and body.op=="list","панель запрашивает список зон")
 M.protect("rad header paint (загрузка)",R.PaintHeader,900,60)
 local zones={{id="rad_1",name="Свалка",pos={x=100,y=0,z=0},radius=300,rate=2,falloff=true,enabled=true},
  {id="rad_2",name="Ржавый тягач",pos={x=4000,y=0,z=0},radius=500,rate=5,falloff=false,enabled=false},{id="bad"}}
 local data=C.Pack({zones=zones,ready=true,limit=128,map="gm_test",revision=3,migrated={count=2,skipped=0}})
 M.netReceive("stalker_rad.state",16+#data*8,nil,{#data,data})
 check(#R.AdminZones==2 and R.AdminState.ready,"снимок принят, неверная запись отброшена")
 local MK=STALKER_MARKERS
 check(MK.Local["rad.rad_1"] and MK.Local["rad.rad_2"] and MK.Local["rad.rad_1"].label:find("Свалка",1,true),"метки зон на время работы панели")
 R.Select("rad_2")
 check(R.Selected=="rad_2" and R.Draft.name=="Ржавый тягач" and R.Draft.radius==500 and R.Draft.falloff==false and R.Draft.enabled==false and MK.Local["rad.rad_2"].edge,"выбор зоны заполняет форму")
 for _,args in ipairs({{900,60},{300,60}}) do M.protect("rad header paint",R.PaintHeader,args[1],args[2]) end
 M.protect("rad row paint",R.PaintRow,R.AdminZones[1],400,50,true);M.protect("rad row paint off",R.PaintRow,R.AdminZones[2],400,50,false)
 M.protect("rad info paint",R.PaintInfo,500,48);M.protect("rad status paint",R.PaintStatus,500,28)
 local a,b=R.DraftInfo({rate=3,falloff=true,enabled=true});check(a:find("1.50",1,true) and b:find("10 с",1,true),"подсказка: половина радиуса и время до порога")
 M.protect("rad layout wide",R.LayoutView,view,1200,800);check(view.wide==true,"широкая вкладка: список слева")
 M.protect("rad layout narrow",R.LayoutView,view,600,800);check(view.wide==false,"узкое окно: список сверху")
 R.Filter="тяг";check(#R.VisibleZones()==1 and R.VisibleZones()[1].id=="rad_2","фильтр по имени");R.Filter="rad_1";check(#R.VisibleZones()==1,"фильтр по id");R.Filter=""
 R.SortByDistance=true;lp:SetPos(Vector(3900,0,0));check(R.VisibleZones()[1].id=="rad_2","сортировка по расстоянию");R.SortByDistance=false;lp:SetPos(Vector(0,0,0))
 M.protect("rad refresh",R.RefreshPanel)
 -- Действия формы отправляют запросы; недопустимая форма — нет.
 local function lastOp() local s=lastSent("stalker_rad.request");return s and util.JSONToTable(util.Decompress(s.data[2])) end
 M.netSent={};R.Draft.radius=5;R.Create("aim")
 check(lastSent("stalker_rad.request")==nil and R.LastResult and R.LastResult.ok==false,"неверный радиус не отправляется")
 R.Draft.radius=450;R.Draft.name="Новая";R.SaveSelected();local op=lastOp()
 check(op and op.op=="update" and op.id=="rad_2" and op.radius==450 and op.name=="Новая","сохранение выбранной зоны")
 R.Create("feet");op=lastOp();check(op and op.op=="create" and op.placement=="feet","создание под собой")
 R.MoveSelected("aim");op=lastOp();check(op and op.op=="move" and op.placement=="aim","перемещение к прицелу")
 R.TeleportSelected();op=lastOp();check(op and op.op=="teleport" and op.id=="rad_2","телепорт")
 R.RemoveSelected();op=lastOp();check(op and op.op=="remove","удаление")
 -- Ответ сервера с ошибкой и созданием.
 M.protect("rad result",R.OnAdminState,{result={op="update",ok=false,message="Радиус: от 32 до 5000"}})
 check(R.LastResult.ok==false and R.LastResult.message:find("Радиус",1,true) and #R.AdminZones==2,"ошибка сервера показывается, список сохраняется")
 table.insert(zones,{id="rad_3",name="Котлован",pos={x=0,y=300,z=0},radius=200,rate=1,falloff=true,enabled=true})
 M.protect("rad created",R.OnAdminState,{zones=zones,ready=true,limit=128,result={op="create",ok=true,message="Создана",id="rad_3"}})
 check(R.Selected=="rad_3" and R.Draft.name=="Котлован","новая зона выбирается автоматически")
 M.protect("rad blocked",R.OnAdminState,{zones=zones,ready=false,error="файл не читается как JSON",limit=128})
 M.protect("rad header blocked",R.PaintHeader,900,60)
 M.protect("rad denied",R.OnAdminState,{denied=true,result={ok=false,message="Нет права radiation"}})
 M.protect("rad header denied",R.PaintHeader,900,60)
 R.OnAdminState({zones=zones,ready=true,limit=128})
 -- Предпросмотр в мире и подписи.
 check(R.DrawZone3D(R.AdminZones[1],Vector(0,0,64))==true and R.DrawZone3D(R.AdminZones[1],Vector(90000,0,64))==false,"кольца рисуются только вблизи")
 M.protect("rad preview 3d",hook.Run,"PostDrawTranslucentRenderables",false,false)
 M.protect("rad preview labels",hook.Run,"HUDPaint")
 M.protect("rad markers hud",hook.Run,"HUDPaint")
 -- Отдельное окно.
 local frame
 M.protect("rad menu",function() frame=R.OpenMenu() end)
 check(frame and R.Menu==frame,"окно stalker_rad_menu открывается")
 -- Закрытие всех панелей: подписка снимается, метки убираются.
 for v in pairs(R.Views) do rawset(v.root,"IsValid",function() return false end) end
 M.netSent={};M.protect("rad close",hook.Run,"Think")
 op=lastOp()
 check(not R.PanelOpen and op and op.op=="close" and not MK.Local["rad.rad_1"],"закрытие панели: отписка и удаление меток")
 vgui.Create=create
 -- Без ядра панель сообщает, что нужен STALKER Core.
 local style=STALKER_STYLE;STALKER_STYLE=nil
 local ok=M.protect("rad no core",R.BuildAdminPanel,parent);check(ok,"без ядра панель не падает")
 STALKER_STYLE=style
 check(S.Defs["radiation.damage_threshold"] and S.Defs["radiation.damage_threshold"].realm=="shared","настройки радиации доступны клиенту")
end
