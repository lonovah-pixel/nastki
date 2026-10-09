local F=STFW
F.Locale={ru={history="Последние победы",expel="Исключить из группировки",title="СЕТЬ ГРУППИРОВОК",status="Группировка",map="Территории",diplomacy="Дипломатия",rank="Ранг / задачи",admin="Редактор",join="Вступить",close="Закрыть",send="Предложить",accept="Принять",reject="Отклонить",counter="Встречное предложение",allied="Союз",enemy="Вражда",neutral="Нейтралитет",war="Война",saved="Сохранено",denied="Действие недоступно",stale="Данные изменились — повторите действие",storage="Ошибка сохранения: действие отменено",joined="Вы вступили в группировку",cooldown="Смена группировки пока недоступна",recruit="ВЕРБОВЩИК",proposal="Получено дипломатическое предложение",captured="Захвачена точка",victory="Победа в войне",unauthorized="Нужны полномочия лидера или администратора",updated="Отношения изменены",points="Очки отношений",peace="Мир / перемирие",leader="Лидер",create="Создать под прицелом",move="Переместить под прицел",delete="Удалить",edit="Сохранить параметры",recruiter="Поставить вербовщика",nojoin="Вступление — через вербовщика. Нажмите E рядом с NPC.",radiation="Радиация",anomaly="Аномалии",offline="Нет назначенного лидера",stop="Остановить войну",start="Начать войну",target="Целевая фракция",pending="Предложения",task="Захватывайте вражеские точки во время войны: +25 опыта и +10 репутации.",health="ЗДОРОВЬЕ",armor="БРОНЯ"},
 en={history="Recent victories",expel="Expel from faction",title="FACTION NETWORK",status="Faction",map="Territories",diplomacy="Diplomacy",rank="Rank / objectives",admin="Editor",join="Join",close="Close",send="Propose",accept="Accept",reject="Reject",counter="Counteroffer",allied="Alliance",enemy="Hostile",neutral="Neutral",war="War",saved="Saved",denied="Action unavailable",stale="State changed — retry",storage="Save failed: action cancelled",joined="Faction joined",cooldown="Faction change on cooldown",recruit="RECRUITER",proposal="Diplomatic proposal received",captured="Point captured",victory="War victory",unauthorized="Leader or administrator authority required",updated="Relations updated",points="Relationship points",peace="Peace / truce",leader="Leader",create="Create at crosshair",move="Move to crosshair",delete="Delete",edit="Save properties",recruiter="Place recruiter",nojoin="Join through a recruiter. Press E near the NPC.",radiation="Radiation",anomaly="Anomalies",offline="No leader assigned",stop="End war",start="Declare war",target="Target faction",pending="Proposals",task="Capture hostile points during war: +25 XP and +10 reputation.",health="HEALTH",armor="ARMOR"}}
function F.L(k) return (F.Locale[F.Config.Language] or F.Locale.en)[k] or k end

local pointLocale={ru={point_settings="ПАРАМЕТРЫ ТЕРРИТОРИИ",new_point="+ Новая точка",point_name="Название точки",point_name_example="Например: Склад на Кордоне",point_values="Проверьте тип и числовые параметры",point_owner="Владелец точки",point_position="Нужна поверхность земли в пределах 4096 units",point_radius="Радиус, units",point_height="Полувысота, units",base_spawn="Использовать как базу возрождения",placement="РАЗМЕЩЕНИЕ",placement_help="Заполните имя и параметры. Создайте под собой или укажите место следующим кликом в мире.",create_feet="Создать здесь, под игроком",placement_click="ЛКМ — подтвердить место под прицелом",placement_cancel="ПКМ / Escape — отменить",request_timeout="Сервер не ответил. Повторите действие."},en={point_settings="TERRITORY SETTINGS",new_point="+ New point",point_name="Point name",point_name_example="For example: Cordon depot",point_values="Check point type and numeric values",point_owner="Point owner",point_position="Aim at ground within 4096 units",point_radius="Radius, units",point_height="Half-height, units",base_spawn="Use as respawn base",placement="PLACEMENT",placement_help="Fill in name and settings. Create at your feet or confirm a position with the next world click.",create_feet="Create here, at player position",placement_click="LMB — confirm position at crosshair",placement_cancel="RMB / Escape — cancel",request_timeout="Server did not respond. Try again."}}
for lang,values in pairs(pointLocale) do for k,v in pairs(values) do STFW.Locale[lang][k]=v end end

F.Locale.ru.leader_member="Сначала включите игрока в выбранную группировку"
F.Locale.en.leader_member="The player must first join the selected faction"
F.Locale.ru.job_mismatch="Для вступления нужна соответствующая профессия DarkRP"
F.Locale.en.job_mismatch="A matching DarkRP job is required"

local fixes={
 profile_unavailable={"Профиль не загружен: проверьте SQLite сервера","Profile unavailable: check server SQLite"},
 invalid_faction={"У вербовщика недопустимая группировка","Invalid recruiter faction"},
 already_joined={"Вы уже состоите в этой группировке","You already belong to this faction"},
 low_reputation={"Недостаточно репутации для вступления","Reputation is too low to join"},
 recruit_ready={"Можно вступить. Текущее членство будет заменено; должность лидера прежней группировки снимается.","You can join. Your current membership and previous leadership will be replaced."},
 base_blocked={"База занята или под атакой: использовано обычное место возрождения","Base blocked or under attack: used normal spawn"},
 territory_contested={"Захват остановлен: присутствуют разные группировки","Contested: multiple factions present"},
 territory_join={"Для захвата нужно вступить в группировку","Join a faction to capture"},
 territory_base={"Своя база / возрождение при свободном месте","Own base / respawn if space is clear"},
 territory_owned={"Территория под вашим контролем","Territory under your control"},
 territory_war={"Для захвата чужой точки объявите войну","Declare war to capture an owned point"},
 territory_capturing={"Идёт захват территории","Capture in progress"},
 territory_enter={"Займите зону без noclip и защиты возрождения","Enter without noclip or spawn protection"},
 select_territory={"Выберите территорию слева","Select a territory on the left"},
 supply_balance={"Очки снабжения","Supply points"},
 supply_help={"+1 очко в минуту за каждую удерживаемую точку, если в группировке есть живой игрок онлайн. Оспариваемые точки не приносят очков. Покупать улучшения может только назначенный лидер.","+1 per minute per held point while a faction member is alive online. Contested points yield nothing. Only the appointed leader can buy upgrades."},
 supply_low={"Недостаточно очков снабжения","Not enough supply points"},
 upgrade_buy={"Повысить уровень","Upgrade"},
 upgrade_max={"Максимальный уровень","Maximum level"}
}
for key,row in pairs(fixes) do F.Locale.ru[key]=row[1];F.Locale.en[key]=row[2] end

F.Locale.ru.admission_required="Нужны деньги на взнос или действующий допуск лидера"
F.Locale.en.admission_required="Entry fee or valid leader approval required"
