-- STALKER Core: настройки, метки, удержание E, новости, статистика, тема.
local M,check,section=TEST.M,TEST.check,TEST.section
local C,S,MK=STALKER_CORE,STALKER_SETTINGS,STALKER_MARKERS
section("Ядро ("..M.Realm..")")
check(C and C.Version,"STALKER_CORE загружен")
check(S.Defs["core.theme"],"настройка темы зарегистрирована")

-- Сжатие сети: пакет и обратное чтение.
local packed=C.Pack({a=1,b={"x"}})
check(type(packed)=="string" and util.JSONToTable(util.Decompress(packed)).a==1,"упаковка пакета")

if SERVER then
 section("Ядро: настройки")
 local cfg={Value=5,Flag=true,Mode="a"}
 S.Bind("test.value",cfg,"Value",{category="Тест",label="Число",type="number",min=1,max=10})
 S.Bind("test.flag",cfg,"Flag",{category="Тест",label="Флаг",type="bool"})
 S.Bind("test.mode",cfg,"Mode",{category="Тест",label="Режим",type="choice",choices={{"a","A"},{"b","B"}}})
 check(S.Get("test.value")==5 and S.Defs["test.value"].default==5,"значение и значение по умолчанию")
 check(S.Set("test.value",8),"установка значения");check(cfg.Value==8,"значение применено к конфигу")
 check(S.Set("test.value",50) and cfg.Value==10,"значение ограничено максимумом")
 check(not S.Set("test.mode","zzz"),"недопустимый вариант отклонён")
 check(not S.Set("test.flag","yes"),"строка вместо логического значения отклонена")
 local row=sql.Query("SELECT value FROM stalker_settings WHERE id='test.value'")
 check(row and util.JSONToTable(row[1].value).v==10,"значение сохранено в SQLite")
 check(S.Set("test.value",nil) and cfg.Value==5,"сброс к значению по умолчанию")
 check(sql.Query("SELECT value FROM stalker_settings WHERE id='test.value'")==nil,"сброс удаляет строку")
 -- Переопределение, сохранённое до регистрации, применяется при регистрации (как после рестарта).
 S.Stored["test.late"]=7;local late={V=1}
 S.Bind("test.late",late,"V",{category="Тест",label="Поздняя",type="number",min=0,max=9})
 check(late.V==7,"сохранённое значение применяется при регистрации")
 local list=S.List();local found=false
 for _,r in ipairs(list) do if r.id=="test.value" then found=r.category=="Тест" and r.label=="Число" end end
 check(found,"список настроек для админ-панели")
 local plain=M.addPlayer({nick="Без прав настроек"})
 check(not C.CanAdmin(plain,"settings"),"обычный игрок не меняет настройки")
 local boss=M.addPlayer({nick="Суперадмин настроек",superadmin=true})
 check(C.CanAdmin(boss,"settings"),"суперадмин меняет настройки")
 M.removePlayer(plain);M.removePlayer(boss)

 section("Ядро: метки")
 local a=M.addPlayer({nick="Метки А",pos=Vector(500000,0,0)});a:SetNW2Bool("stfw_joined",true);a:SetNW2String("stfw_faction","duty")
 local b=M.addPlayer({nick="Метки Б",pos=Vector(500000,0,0)})
 MK.Set("test.all",{pos=Vector(1,2,3),label="Всем",kind="poi"})
 MK.Set("test.duty",{pos=Vector(1,2,3),label="Долгу",kind="rally",visible={faction="duty"}})
 MK.Set("test.b",{pos=Vector(1,2,3),label="Только Б",kind="stash",visible={players={[b:SteamID64()]=true}}})
 MK.Set("test.old",{pos=Vector(1,2,3),label="Истекла",kind="event",expires=CurTime()-1})
 check(MK.VisibleTo(MK.Get("test.all"),a) and MK.VisibleTo(MK.Get("test.all"),b),"метка для всех")
 check(MK.VisibleTo(MK.Get("test.duty"),a) and not MK.VisibleTo(MK.Get("test.duty"),b),"метка видна только группировке")
 check(MK.VisibleTo(MK.Get("test.b"),b) and not MK.VisibleTo(MK.Get("test.b"),a),"метка видна только выбранному игроку")
 check(not MK.VisibleTo(MK.Get("test.old"),a),"истёкшая метка скрыта")
 M.netSent={};M.advance(1.1)
 local sentToA=0;for _,s in ipairs(M.netSent) do if s.name=="stalker_markers.sync" and s.to==a then sentToA=sentToA+1 end end
 check(sentToA==1,"метки отправлены игроку")
 check(MK.Get("test.old")==nil,"истёкшие метки удаляются")
 M.netSent={};M.advance(1.1)
 sentToA=0;for _,s in ipairs(M.netSent) do if s.name=="stalker_markers.sync" and s.to==a then sentToA=sentToA+1 end end
 check(sentToA==0,"без изменений метки не пересылаются")
 MK.Clear("test.")
 check(next(MK.List)==nil or not MK.Get("test.all"),"очистка меток по префиксу")

 section("Ядро: удержание E")
 local holder=M.addPlayer({nick="Держатель",pos=Vector(500000,1000,0)})
 local box=ents.Create("prop_physics");box:SetPos(Vector(500060,1000,0));box:Spawn()
 holder._aim=box:WorldSpaceCenter()
 holder.GetAimVector=function(self) return (box:WorldSpaceCenter()-self:GetShootPos()):GetNormalized() end
 local done=false
 holder:SetKey(IN_USE,true)
 check(C.Hold.Start(holder,box,1,"Тест",function() done=true end),"удержание начато")
 check(not C.Hold.Start(holder,box,1,"Тест",function() end),"второе удержание не начинается")
 M.advance(1.3,.1)
 check(done,"удержание завершилось действием")
 local cancelled=false
 C.Hold.Start(holder,box,2,"Тест",function() cancelled="done" end,{onCancel=function() cancelled=true end})
 holder:SetKey(IN_USE,false);M.advance(.3,.1)
 check(cancelled==true,"отпущенная E прерывает удержание")

 section("Ядро: новости и статистика")
 local entry=C.News("Тестовая новость","event")
 check(C.NewsFeed[1]==entry,"новость в ленте")
 local stat=M.addPlayer({nick="Статистика",pos=Vector(500000,2000,0)})
 C.AddStat(stat,"artifacts",2);C.AddStat(stat,"artifacts",1)
 check(C.GetStats(stat).artifacts==3,"счётчик статистики")
 hook.Run("PlayerDisconnected",stat)
 local saved=sql.Query("SELECT payload FROM stalker_stats WHERE sid="..sql.SQLStr(stat:SteamID64()))
 check(saved and util.JSONToTable(saved[1].payload).artifacts==3,"статистика сохраняется при выходе")
 for _,p in ipairs({a,b,holder,stat}) do M.removePlayer(p) end
else
 section("Ядро: клиент")
 check(STALKER_THEME and STALKER_THEME.C.accent and STALKER_THEME.Name,"тема применена: "..tostring(STALKER_THEME.Name))
 check(STALKER_STYLE.Core and STALKER_STYLE.Panel and STALKER_STYLE.Window,"общий стиль из ядра")
 for _,name in ipairs(STALKER_THEME.Order) do STALKER_THEME.Apply(name);check(STALKER_THEME.Name==name,"тема «"..name.."» применяется") end
 STALKER_THEME.Apply("zone")
 C.RegisterPDATab("test",{title="Тест",order=5,build=function() end})
 check(C.PDATabList()[1] and C.PDATabList()[1].id=="test","вкладка КПК зарегистрирована")
 C.PDATabs.test=nil
 MK.SetLocal("test.local",{pos=Vector(10,0,0),label="Локальная",kind="quest"})
 check(#MK.All()>=1,"локальная метка в списке")
 C.Toast("Тест","info",1)
 for _,ev in ipairs({{"HUDPaint"},{"PostDrawTranslucentRenderables",false,false}}) do M.protect("core "..ev[1],hook.Run,unpack(ev)) end
 MK.RemoveLocal("test.local")
 local w=STALKER_STYLE.Window({title="Тест",look=true})
 check(w,"окно КПК создаётся")
end
