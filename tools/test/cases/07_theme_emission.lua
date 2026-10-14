-- Общая тема в окнах торговца, разделки и выброса; настройки выброса в реестре админ-панели.
local M,check,section=TEST.M,TEST.check,TEST.section
local S,E=STALKER_SETTINGS,ST_EMISSION
section("Выброс и тема ("..M.Realm..")")
if SERVER then
 check(S.Defs["emission.auto"] and S.Defs["emission.interval_min"] and S.Defs["emission.phase_peak"],"настройки выброса зарегистрированы")
 local before=E.Config.IntervalMin
 check(S.Set("emission.interval_min",5) and E.Config.IntervalMin==300,"минимальный интервал из панели (минуты → секунды)")
 check(S.Set("emission.interval_max",2) and E.State.phase==0 and E.State.next>CurTime(),"минимум больше максимума не ломает планировщик")
 check(S.Set("emission.damage_scale",0) and E.Config.DamageScale==0,"множитель урона выброса")
 check(S.Set("emission.phase_peak",30) and E.Config.Phases[3].duration==30,"длительность фазы")
 for _,id in ipairs({"emission.interval_min","emission.interval_max","emission.damage_scale","emission.phase_peak"}) do S.Set(id,nil) end
 check(E.Config.IntervalMin==before and E.Config.DamageScale==1,"сброс настроек выброса")
 local plain=M.addPlayer({nick="Выброс без прав",pos=Vector(-900000,0,0)})
 local boss=M.addPlayer({nick="Выброс суперадмин",pos=Vector(-900000,100,0),superadmin=true})
 check(not E.IsAdmin(plain) and E.IsAdmin(boss),"управление выбросом — право events")
 M.removePlayer(plain);M.removePlayer(boss)
else
 local T=STALKER_THEME
 for _,name in ipairs({"zone","pda"}) do
  T.Apply(name)
  check(STALKER_NPC.Colors.accent==T.C.accent and STALKER_NPC.Colors.red==T.C.danger,"торговец берёт цвета темы «"..name.."»")
 end
 T.Apply("zone")
 local lp=LocalPlayer();local wasSuper=lp._super;lp._super=true
 M.protect("окно выброса",E.OpenMenu)
 lp._super=wasSuper
 -- В эмуляции окна Derma — заглушки: проверяем, что окно построено без ошибок.
 check(E.Menu~=nil and E.Menu.Auto~=nil,"окно управления выбросом в общей теме")
 E.Menu=nil
 E.State.phase=2;E.State.ends=CurTime()+10
 M.protect("HUD выброса",hook.Run,"HUDPaint")
 E.State.phase=0
end

-- Настройки разделки и торговцев в реестре админ-панели.
section("Разделка и торговля: настройки ("..M.Realm..")")
check(S.Defs["butcher.rounds"] and S.Defs["butcher.price_rare"] and S.Defs["trade.distance"],"настройки разделки и торговли зарегистрированы")
if SERVER then
 check(S.Set("butcher.rounds",7) and STALKER_BUTCHERING.Config.Rounds==3,"разрезов не больше трёх (ограничение сети)")
 local trader=STALKER_NPC.Config.Traders.sidor;local item=STALKER_BUTCHERING.ItemID("rare","perfect",false)
 check(S.Set("butcher.price_rare",1000) and trader.prices[item].sell==1000,"цена трофея применяется к торговцу")
 for _,id in ipairs({"butcher.rounds","butcher.price_rare"}) do S.Set(id,nil) end
 check(trader.prices[item].sell==650 and STALKER_BUTCHERING.Config.Rounds==3,"сброс цены и разрезов")
end
