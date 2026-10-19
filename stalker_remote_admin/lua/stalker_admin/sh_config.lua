local A=STALKER_ADMIN
A.Config={
 Title="КОМЕНДАНТ",Version="2.0.0",MaxTargets=16,MaxBanMinutes=525600,MaxReasonBytes=240,
 LogDays=90,MaxPageRows=40,AllowSelfGod=true,
 -- Лимиты бана (минуты) для уровней ниже «Коменданта»; бессрочный бан — только от «Коменданта».
 ModeratorBanMinutes=1440,AdminBanMinutes=10080,
 -- Add your exact SteamID64 here, or use sta_setrole from the server console.
 Owners={}, -- ["76561198000000000"]=true
 -- Группа ULX → уровень «Коменданта». При ULib уровень игрока — это его группа ULX (с учётом наследования).
 GroupRoles={superadmin="superadmin",admin="admin",moderator="moderator",operator="helper"},
 -- От какой группы наследовать недостающие группы при назначении уровня (ULib создаёт их сам).
 GroupParents={operator="user",moderator="operator",admin="operator",superadmin="admin"},
 Roles={
  user={label="Сталкер",rank=0,permissions={}},
  helper={label="Наблюдатель",rank=10,permissions={view=true,observe=true,warn=true,teleport=true,logs=true}},
  moderator={label="Модератор",rank=30,permissions={view=true,observe=true,warn=true,kick=true,ban=true,mute=true,freeze=true,teleport=true,logs=true,bans=true}},
  admin={label="Администратор",rank=60,permissions={view=true,observe=true,warn=true,kick=true,ban=true,mute=true,freeze=true,teleport=true,logs=true,bans=true,players=true,noclip=true,loadout=true,announce=true,zone=true,radiation=true,events=true,quests=true}},
  superadmin={label="Комендант",rank=90,permissions={all=true}},
  owner={label="Владелец",rank=100,permissions={all=true}}
 },
 -- Native weapon classes that the panel is allowed to give. No arbitrary entity spawning.
 Weapons={weapon_crowbar=true,weapon_pistol=true,weapon_smg1=true,weapon_shotgun=true,weapon_ar2=true,weapon_physgun=true,gmod_tool=true},
 -- Empty = installed maps from maps/*.bsp. Otherwise only these names.
 Maps={},
}
-- Все права «Коменданта». В ULX/CAMI они видны как "stalker_<право>" и раздаются группам в XGUI.
A.Permissions={
 {"view","Открытие панели «Комендант»"},{"observe","Наблюдение через камеру игрока"},{"warn","Предупреждения"},
 {"kick","Отключение игроков"},{"ban","Блокировка игроков"},{"mute","Запрет чата и голоса"},{"freeze","Заморозка"},
 {"teleport","Телепорт"},{"logs","Журнал действий"},{"bans","Реестр банов и разбан"},{"players","Здоровье, броня, бессмертие"},
 {"noclip","Полёт"},{"loadout","Выдача оружия и предметов"},{"announce","Объявления по сети"},{"zone","Обстановка Зоны: доза, группировка, перестройка, склады"},
 {"economy","Деньги DarkRP"},{"server","Карта и очистка сервера"},{"roles","Назначение уровней (групп ULX)"},{"settings","Настройки сборки"},
 {"radiation","Радиационные зоны"},{"events","События Зоны и выбросы"},{"quests","Задания"},{"craft","Крафт"},{"factions","Группировки"},
}
A.PermissionLabels={};for _,row in ipairs(A.Permissions) do A.PermissionLabels[row[1]]=row[2] end

function A.Int(v,lo,hi) return type(v)=="number" and v==v and v%1==0 and v>=lo and v<=hi end
function A.SID(s) return type(s)=="string" and #s==17 and s:match("^7656119%d+$")~=nil end
function A.Text(s,limit)
 if type(s)~="string" or #s>(limit or A.Config.MaxReasonBytes) or s:find("[%z\1-\31\127]") then return nil end
 return s:match("^%s*(.-)%s*$")
end
-- Самый низкий уровень, у которого есть право (для значений по умолчанию в ULX/CAMI).
function A.MinRole(permission)
 local best
 for id,r in pairs(A.Config.Roles) do
  if r.rank>0 and (r.permissions.all==true or r.permissions[permission]==true) and (not best or r.rank<A.Config.Roles[best].rank) then best=id end
 end
 return best or "owner"
end
-- Лимит бана для ранга: nil — без ограничений (уровень «Комендант» и выше).
function A.BanLimit(rank)
 if rank>=90 then return nil end
 return rank<60 and A.Config.ModeratorBanMinutes or A.Config.AdminBanMinutes
end

-- Настройки «Коменданта» в общей админ-системе (вкладка «Настройки», категория «Комендант»).
local S=STALKER_SETTINGS
if S and S.Bind then
 local cat="Комендант"
 S.Bind("admin.ban_moderator",A.Config,"ModeratorBanMinutes",{category=cat,label="Лимит бана модератора, мин",type="number",min=10,max=525600,step=10,realm="shared",order=1,
  description="Самый долгий бан, который может выдать модератор. Бессрочный бан ему недоступен."})
 S.Bind("admin.ban_admin",A.Config,"AdminBanMinutes",{category=cat,label="Лимит бана администратора, мин",type="number",min=10,max=525600,step=10,realm="shared",order=2,
  description="Самый долгий бан, который может выдать администратор. Бессрочный бан — от уровня «Комендант»."})
 S.Bind("admin.ban_max",A.Config,"MaxBanMinutes",{category=cat,label="Максимальный срок бана, мин",type="number",min=60,max=5256000,step=60,order=3,
  description="Предел срочного бана для всех уровней (0 в форме — бессрочно)."})
 S.Bind("admin.log_days",A.Config,"LogDays",{category=cat,label="Срок хранения журнала, дней",type="number",min=1,max=3650,order=4,
  description="Записи журнала старше этого срока удаляются раз в час."})
 S.Bind("admin.self_god",A.Config,"AllowSelfGod",{category=cat,label="Бессмертие для себя",type="bool",order=5,
  description="Разрешить персоналу включать бессмертие самому себе."})
 S.Bind("admin.max_targets",A.Config,"MaxTargets",{category=cat,label="Игроков в одной команде",type="number",min=1,max=64,realm="shared",order=6,
  description="Сколько целей можно отметить для одной групповой команды."})
 S.Bind("admin.page_rows",A.Config,"MaxPageRows",{category=cat,label="Строк на странице журнала",type="number",min=10,max=100,order=7})
 S.Bind("admin.reason_bytes",A.Config,"MaxReasonBytes",{category=cat,label="Длина причины, байт",type="number",min=60,max=240,order=8,
  description="Предел длины причины и объявления (кириллица — 2 байта на букву)."})
end
