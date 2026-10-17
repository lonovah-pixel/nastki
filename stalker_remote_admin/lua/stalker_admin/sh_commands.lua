local A=STALKER_ADMIN
A.Commands={}
local function add(id,label,category,permission,scope,field,danger,selfOK)
 A.Commands[id]={id=id,label=label,category=category,permission=permission,scope=scope or "players",field=field,danger=danger==true,selfOK=selfOK==true,order=table.Count(A.Commands)}
end
add("warn","Предупреждение","Дисциплина","warn",nil,"reason")
add("kick","Отключить","Дисциплина","kick",nil,"reason",true)
add("ban","Заблокировать","Дисциплина","ban",nil,"ban",true)
add("mute","Запретить чат","Дисциплина","mute",nil,"duration")
add("unmute","Разрешить чат","Дисциплина","mute")
add("gag","Запретить голос","Дисциплина","mute",nil,"duration")
add("ungag","Разрешить голос","Дисциплина","mute")
add("freeze","Заморозить","Дисциплина","freeze")
add("unfreeze","Разморозить","Дисциплина","freeze")
add("heal","Восстановить здоровье","Состояние","players",nil,nil,false,true)
add("armor","Установить броню","Состояние","players",nil,"amount",false,true)
add("respawn","Возродить","Состояние","players",nil,nil,true,true)
add("kill","Убить","Состояние","players",nil,nil,true)
add("god_on","Бессмертие: вкл.","Состояние","players",nil,nil,false,true)
add("god_off","Бессмертие: выкл.","Состояние","players",nil,nil,false,true)
add("watch","Наблюдать через камеру","Перемещение","observe")
add("watch_stop","Вернуться к себе","Перемещение","observe","self")
add("noclip_on","Полёт: вкл.","Перемещение","noclip",nil,nil,false,true)
add("noclip_off","Полёт: выкл.","Перемещение","noclip",nil,nil,false,true)
add("bring","Телепортировать к себе","Перемещение","teleport")
add("goto","Телепортироваться к игроку","Перемещение","teleport",nil,nil,false,true)
add("return","Вернуть на место","Перемещение","teleport",nil,nil,false,true)
add("weapon","Выдать оружие","Снаряжение","loadout",nil,"weapon",false,true)
add("item","Выдать предмет STALKER","Снаряжение","loadout",nil,"item",false,true)
add("money","Изменить деньги DarkRP","Снаряжение","economy",nil,"money",true,true)
add("faction","Назначить группировку","Обстановка","zone",nil,"faction",true,true)
add("radiation","Установить дозу","Обстановка","zone",nil,"dose",false,true)
add("emission_start","Запустить выброс","Обстановка","zone","server",nil,true)
add("emission_stop","Остановить выброс","Обстановка","zone","server",nil,true)
add("zone_rebuild","Перестроить Зону","Обстановка","zone","server",nil,true)
add("restock","Пополнить склады торговцев","Обстановка","zone","server")
add("event_start","Запустить событие","Обстановка","events","server","event",true)
add("event_stop","Остановить событие","Обстановка","events","server","event")
add("announce","Объявление по сети","Сервер","announce","server","message")
add("cleanup","Очистить карту","Сервер","server","server",nil,true)
add("map","Сменить карту","Сервер","server","server","map",true)
add("restart","Перезапустить карту","Сервер","server","server",nil,true)
add("ban_sid","Бан по SteamID64","Реестр банов","ban","offline","offlineban",true)
add("unban","Снять блокировку","Реестр банов","bans","offline","sid",true)
add("role","Назначить уровень доступа","Допуски","roles","offline","role",true)

-- Разделы панели. kind: commands — список команд; page — таблица с сервера; settings — реестр настроек;
-- addon — вкладка другого аддона (build — путь к функции BuildAdminPanel, permission — право «Коменданта»).
A.Sections={
 {group="КОМАНДЫ",id="Дисциплина",kind="commands"},
 {group="КОМАНДЫ",id="Состояние",kind="commands"},
 {group="КОМАНДЫ",id="Перемещение",kind="commands"},
 {group="КОМАНДЫ",id="Снаряжение",kind="commands"},
 {group="КОМАНДЫ",id="Обстановка",kind="commands"},
 {group="КОМАНДЫ",id="Сервер",kind="commands"},
 {group="РЕЕСТРЫ",id="Реестр банов",kind="page",page="bans",permission="bans"},
 {group="РЕЕСТРЫ",id="Допуски",kind="commands"},
 {group="РЕЕСТРЫ",id="Журнал",kind="page",page="logs",permission="logs"},
 {group="СИСТЕМЫ",id="Настройки",kind="settings",permission="settings"},
 {group="СИСТЕМЫ",id="Радиация",kind="addon",permission="radiation",global="STALKER_RAD"},
 {group="СИСТЕМЫ",id="Зона",kind="addon",permission="zone",global="STALKER_ZONE"},
 {group="СИСТЕМЫ",id="События",kind="addon",permission="events",global="STALKER_EVENTS"},
 {group="СИСТЕМЫ",id="Задания",kind="addon",permission="quests",global="STALKER_QUESTS"},
 {group="СИСТЕМЫ",id="Крафт",kind="addon",permission="craft",global="STALKER_CRAFT"},
 {group="СИСТЕМЫ",id="Группировки",kind="addon",permission="factions",global="STFW"},
}
A.SectionByID={};A.Categories={}
for _,s in ipairs(A.Sections) do A.SectionByID[s.id]=s;A.Categories[#A.Categories+1]=s.id end
-- Права, которые сервер сообщает клиенту для вкладок (кроме команд, они идут по каждой команде).
A.TabPermissions={"logs","bans","settings","radiation","zone","events","quests","craft","factions","roles"}
