-- Параметры выброса в общей админ-панели (STALKER_SETTINGS, раздел «Выбросы»).
-- Значения из панели хранятся в SQLite ядра и важнее старого settings.json, который остаётся для совместимости.
local E=ST_EMISSION
local S=STALKER_SETTINGS;if not S then return end
local cat="Выбросы"
local function reschedule() if E.State.phase==0 then E.Schedule() end;E.Send() end
S.Register("emission.auto",{category=cat,label="Автоматические выбросы",type="bool",order=1,
 get=function() return E.Config.AutoStart end,set=function(v) E.Config.AutoStart=v end,onChange=reschedule})
S.Register("emission.interval_min",{category=cat,label="Минимальный интервал, мин",description="Отсчитывается от конца прошлого выброса",
 type="number",min=1,max=1440,order=2,get=function() return math.Round(E.Config.IntervalMin/60) end,set=function(v) E.Config.IntervalMin=v*60 end,onChange=reschedule})
S.Register("emission.interval_max",{category=cat,label="Максимальный интервал, мин",type="number",min=1,max=1440,order=3,
 get=function() return math.Round(E.Config.IntervalMax/60) end,set=function(v) E.Config.IntervalMax=v*60 end,onChange=reschedule})
S.Bind("emission.damage_scale",E.Config,"DamageScale",{category=cat,label="Множитель урона выброса",type="number",min=0,max=5,step=.1,decimals=1,order=4})
S.Bind("emission.knockout",E.Config,"KnockoutSeconds",{category=cat,label="Обморок на пике, сек (0 — без обморока)",type="number",min=0,max=60,order=5})
S.Bind("emission.damage_players",E.Config,"DamagePlayers",{category=cat,label="Выброс ранит игроков",type="bool",order=6})
S.Bind("emission.damage_npcs",E.Config,"DamageNPCs",{category=cat,label="Выброс ранит NPC",type="bool",order=7})
S.Bind("emission.auto_roof",E.Config,"AutoRoof",{category=cat,label="Укрытие под крышей определяется само",type="bool",order=8})
S.Bind("emission.roof_distance",E.Config,"RoofDistance",{category=cat,label="Высота поиска крыши, юниты",type="number",min=128,max=16384,order=9})
for i,phase in ipairs(E.Config.Phases) do
 S.Bind("emission.phase_"..phase.id,phase,"duration",{category=cat,label="Фаза «"..phase.name.."», сек",type="number",min=5,max=900,order=10+i})
end
