--[[-----------------------------------------------------------------------
Русский язык DarkRP (STALKER RP)
---------------------------------------------------------------------------
Перевод всех фраз DarkRP. Язык выбирается переменной gmod_language:
на сервере пропишите `gmod_language ru` в server.cfg, у игроков русский
клиент Garry's Mod выставляет "ru" сам.

Если после обновления DarkRP появятся новые фразы, найдите их командой
клиента: darkrp_getphrases "ru" — и добавьте перевод в этот файл.
---------------------------------------------------------------------------]]

local my_language = {
    -- Admin things
    need_admin = "Нужны права администратора, чтобы %s",
    need_sadmin = "Нужны права суперадмина, чтобы %s",
    no_privilege = "У вас нет прав на это действие",
    no_jail_pos = "Нет точки заключения",
    invalid_x = "Неверное значение «%s»! %s",

    -- F1 menu
    f1ChatCommandTitle = "Чат-команды",
    f1Search = "Поиск...",

    -- Money things:
    price = "Цена: %s%d",
    priceTag = "Цена: %s",
    reset_money = "%s обнулил деньги всех игроков!",
    has_given = "%s передал вам %s",
    you_gave = "Вы передали игроку %s %s",
    npc_killpay = "%s за убитого мутанта!",
    profit = "прибыль",
    loss = "убыток",
    Donate = "Пожертвовать",
    you_donated = "Вы пожертвовали %s игроку %s!",
    has_donated = "%s пожертвовал %s!",

    -- backwards compatibility
    deducted_x = "Списано %s%d",
    need_x = "Нужно %s%d",

    deducted_money = "Списано %s",
    need_money = "Нужно %s",

    payday_message = "Выплата! Вы получили %s!",
    payday_unemployed = "Вы не получили жалование: у вас нет работы!",
    payday_missed = "Выплата пропущена (вы под арестом)!",

    property_tax = "Налог на имущество! %s",
    property_tax_cant_afford = "Вы не смогли заплатить налог! Ваше имущество изъято!",
    taxday = "День налогов! Удержано %s%% дохода!",

    found_cheque = "Вы нашли чек на %s%s, выписанный вам игроком %s.",
    cheque_details = "Чек выписан на имя %s.",
    cheque_torn = "Вы порвали чек.",
    cheque_pay = "Оплатить: %s",
    signed = "Подпись: %s",

    found_cash = "Вы подобрали %s%d!", -- backwards compatibility
    found_money = "Вы подобрали %s!",

    owner_poor = "Владелец (%s) слишком беден, чтобы оплатить эту продажу!",

    -- Police
    Wanted_text = "Розыск!",
    wanted = "Разыскивается!\nПричина: %s",
    youre_arrested = "Вы арестованы. Осталось: %d сек.!",
    youre_arrested_by = "Вас арестовал %s.",
    youre_unarrested_by = "Вас освободил %s.",
    hes_arrested = "%s арестован на %d сек.!",
    hes_unarrested = "%s освобождён из-под ареста!",
    warrant_ordered = "%s выдал ордер на обыск игрока %s. Причина: %s",
    warrant_request = "%s запрашивает ордер на обыск игрока %s\nПричина: %s",
    warrant_request2 = "Запрос на ордер отправлен: %s!",
    warrant_approved = "Ордер на обыск игрока %s одобрен!\nПричина: %s\nВыдал: %s",
    warrant_approved2 = "Теперь можно обыскать его жильё.",
    warrant_denied = "%s отклонил ваш запрос на ордер.",
    warrant_expired = "Ордер на обыск игрока %s истёк!",
    warrant_required = "Чтобы открыть эту дверь, нужен ордер.",
    warrant_required_unfreeze = "Чтобы разморозить этот предмет, нужен ордер.",
    warrant_required_unweld = "Чтобы отсоединить этот предмет, нужен ордер.",
    wanted_by_police = "%s объявлен в розыск!\nПричина: %s\nОбъявил: %s",
    wanted_by_police_print = "%s объявил в розыск игрока %s, причина: %s",
    wanted_expired = "%s больше не в розыске.",
    wanted_revoked = "%s больше не в розыске.\nСнял: %s",
    cant_arrest_other_cp = "Нельзя арестовать сотрудника охраны!",
    must_be_wanted_for_arrest = "Для ареста игрок должен быть в розыске.",
    cant_arrest_fadmin_jailed = "Нельзя арестовать игрока, которого посадил администратор.",
    cant_arrest_no_jail_pos = "Нельзя арестовывать: не задано ни одной точки заключения!",
    cant_arrest_spawning_players = "Нельзя арестовать только что возродившегося игрока.",

    suspect_doesnt_exist = "Подозреваемый не найден.",
    actor_doesnt_exist = "Исполнитель не найден.",
    get_a_warrant = "получить ордер",
    remove_a_warrant = "отменить ордер",
    make_someone_wanted = "объявить кого-то в розыск",
    remove_wanted_status = "снять розыск",
    already_a_warrant = "На этого подозреваемого уже есть ордер.",
    not_warranted = "На этого человека нет ордера.",
    already_wanted = "Подозреваемый уже в розыске.",
    not_wanted = "Подозреваемый не в розыске.",
    need_to_be_cp = "Нужно служить в охране.",
    suspect_must_be_alive_to_do_x = "Подозреваемый должен быть жив, чтобы %s.",
    suspect_already_arrested = "Подозреваемый уже под арестом.",

    -- Players
    health = "Здоровье: %s",
    job = "Профессия: %s",
    salary = "Жалование: %s%s",
    wallet = "Кошелёк: %s%s",
    weapon = "Оружие: %s",
    kills = "Убийства: %s",
    deaths = "Смерти: %s",
    rpname_changed = "%s сменил RP-имя на: %s",
    disconnected_player = "Отключившийся игрок",
    player = "игрок",

    -- Teams
    need_to_be_before = "Сначала нужно стать «%s», чтобы стать «%s»",
    need_to_make_vote = "Чтобы стать «%s», нужно голосование!",
    team_limit_reached = "Нельзя стать «%s»: достигнут лимит",
    wants_to_be = "%s\nхочет стать\n%s",
    has_not_been_made_team = "%s не стал «%s»!",
    job_has_become = "%s теперь «%s»!",

    -- Disasters
    meteor_approaching = "ВНИМАНИЕ: приближается метеоритный дождь!",
    meteor_passing = "Метеоритный дождь закончился.",
    meteor_enabled = "Метеоритные дожди включены.",
    meteor_disabled = "Метеоритные дожди отключены.",
    earthquake_report = "Зафиксировано землетрясение магнитудой %sMw",
    earthtremor_report = "Зафиксированы толчки магнитудой %sMw",

    -- Keys, vehicles and doors
    keys_allowed_to_coown = "Вы можете стать совладельцем\n(R с ключами или F2 — стать совладельцем)\n",
    keys_other_allowed = "Могут стать совладельцами:",
    keys_allow_ownership = "(R с ключами или F2 — разрешить владение)",
    keys_disallow_ownership = "(R с ключами или F2 — запретить владение)",
    keys_owned_by = "Владелец:",
    keys_unowned = "Свободно\n(R с ключами или F2 — купить)",
    keys_everyone = "(R с ключами или F2 — открыть для всех)",
    door_unown_arrested = "Под арестом нельзя покупать и продавать имущество!",
    door_unownable = "Эту дверь нельзя купить или продать!",
    door_sold = "Вы продали это за %s",
    door_already_owned = "У этой двери уже есть владелец!",
    door_cannot_afford = "Вам не хватает денег на эту дверь!",
    door_hobo_unable = "Бездомный не может покупать двери!",
    vehicle_cannot_afford = "Вам не хватает денег на этот транспорт!",
    door_bought = "Вы купили эту дверь за %s%s",
    vehicle_bought = "Вы купили этот транспорт за %s%s",
    door_need_to_own = "Нужно владеть этой дверью, чтобы %s",
    door_rem_owners_unownable = "Нельзя убрать владельцев у неприобретаемой двери!",
    door_add_owners_unownable = "Нельзя добавить владельцев неприобретаемой двери!",
    rp_addowner_already_owns_door = "%s уже владеет (или может владеть) этой дверью!",
    add_owner = "Добавить владельца",
    remove_owner = "Убрать владельца",
    coown_x = "Совладение: %s",
    allow_ownership = "Разрешить владение",
    disallow_ownership = "Запретить владение",
    edit_door_group = "Изменить группу двери",
    door_groups = "Группы дверей",
    door_group_doesnt_exist = "Такой группы дверей нет!",
    door_group_set = "Группа двери установлена.",
    sold_x_doors_for_y = "Вы продали дверей: %d за %s%d!", -- backwards compatibility
    sold_x_doors = "Вы продали дверей: %d за %s!",
    no_doors_owned = "У вас нет дверей!",

    -- Entities
    drugs = "наркотики",
    Drugs = "Наркотики",
    drug_lab = "Нарколаборатория",
    gun_lab = "Оружейная мастерская",
    any_lab = "любая лаборатория",
    gun = "оружие",
    microwave = "Микроволновка",
    food = "еда",
    Food = "Еда",
    money_printer = "Денежный принтер",
    tip_jar = "Банка для чаевых",

    sign_this_letter = "Подписать письмо",
    signed_yours = "С уважением,",

    money_printer_exploded = "Ваш денежный принтер взорвался!",
    money_printer_overheating = "Ваш денежный принтер перегревается!",

    contents = "Содержимое: ",
    amount = "Количество: ",

    picking_lock = "Взлом замка",

    cannot_pocket_x = "Это нельзя положить в карман!",
    cannot_pocket_gravgunned = "Нельзя положить в карман: предмет удерживается грави-пушкой.",
    object_too_heavy = "Предмет слишком тяжёлый.",
    pocket_full = "Карман полон!",
    pocket_no_items = "Карман пуст.",
    drop_item = "Выбросить предмет",

    bonus_destroying_entity = "уничтожение незаконного предмета.",

    switched_burst = "Режим огня: очередь с отсечкой.",
    switched_fully_auto = "Режим огня: автоматический.",
    switched_semi_auto = "Режим огня: одиночный.",

    keypad_checker_shoot_keypad = "Выстрелите в кодовую панель, чтобы увидеть, чем она управляет.",
    keypad_checker_shoot_entity = "Выстрелите в предмет, чтобы увидеть связанные с ним кодовые панели",
    keypad_checker_click_to_clear = "ПКМ — очистить.",
    keypad_checker_entering_right_pass = "Ввод верного кода",
    keypad_checker_entering_wrong_pass = "Ввод неверного кода",
    keypad_checker_after_right_pass = "после ввода верного кода",
    keypad_checker_after_wrong_pass = "после ввода неверного кода",
    keypad_checker_right_pass_entered = "Введён верный код",
    keypad_checker_wrong_pass_entered = "Введён неверный код",
    keypad_checker_controls_x_entities = "Эта панель управляет объектами: %d",
    keypad_checker_controlled_by_x_keypads = "Этим объектом управляют панели: %d",
    keypad_on = "ВКЛ",
    keypad_off = "ВЫКЛ",
    seconds = "сек.",

    persons_weapons = "Оружие игрока %s:",
    returned_persons_weapons = "Изъятое оружие игрока %s возвращено.",
    no_weapons_confiscated = "У игрока %s ничего не изъято!",
    no_illegal_weapons = "У игрока %s нет оружия.",
    confiscated_these_weapons = "Изъято оружие:",
    checking_weapons = "Изъятие оружия",

    shipment_antispam_wait = "Подождите, прежде чем создавать новую поставку.",
    createshipment = "Создать поставку",
    splitshipment = "Разделить поставку",
    shipment_cannot_split = "Эту поставку нельзя разделить.",

    -- Talking
    hear_noone = "Никто не слышит, как вы %s!",
    hear_everyone = "Вас слышат все!",
    hear_certain_persons = "Вас слышат (%s): ",

    whisper = "шепчете",
    yell = "кричите",
    broadcast = "[Трансляция!]",
    radio = "рация",
    request = "(ЗАПРОС!)",
    group = "(группа)",
    demote = "(УВОЛЬНЕНИЕ)",
    ooc = "OOC",
    radio_x = "Рация %d",

    talk = "говорите",
    speak = "говорите",

    speak_in_ooc = "писать в OOC",
    perform_your_action = "выполнить действие",
    talk_to_your_group = "писать своей группе",

    channel_set_to_x = "Канал установлен: %s!",
    channel = "канал",

    -- Notifies
    disabled = "%s отключено! %s",
    gm_spawnvehicle = "создавать транспорт",
    gm_spawnsent = "создавать скриптовые объекты (SENT)",
    gm_spawnnpc = "создавать NPC",
    see_settings = "См. настройки DarkRP.",
    limit = "Достигнут лимит: %s!",
    have_to_wait = "Подождите ещё %d сек., прежде чем использовать %s!",
    must_be_looking_at = "Нужно смотреть на: %s!",
    incorrect_job = "У вас неподходящая профессия, чтобы %s",
    unavailable = "%s недоступно",
    unable = "Невозможно %s. %s",
    cant_afford = "Вам не хватает денег: %s",
    created_x = "%s создал %s",
    cleaned_up = "Ваши объекты (%s) удалены.",
    you_bought_x = "Вы купили %s за %s%d.", -- backwards compatibility
    you_bought = "Вы купили %s за %s.",
    you_got_yourself = "Вы получили: %s.",
    you_received_x = "Вы получили %s за %s.",

    created_first_jailpos = "Создана первая точка заключения!",
    added_jailpos = "Добавлена ещё одна точка заключения!",
    reset_add_jailpos = "Все точки заключения удалены, добавлена новая здесь.",
    created_spawnpos = "Добавлена точка возрождения для профессии «%s».",
    updated_spawnpos = "Точки возрождения профессии «%s» сброшены, добавлена новая здесь.",
    remove_spawnpos = "Все точки возрождения профессии «%s» удалены.",
    do_not_own_ent = "Это не ваш объект!",
    cannot_drop_weapon = "Это оружие нельзя выбросить!",
    job_switch = "Профессии успешно обменяны!",
    job_switch_question = "Обменяться профессиями с %s?",
    job_switch_requested = "Запрос на обмен профессиями отправлен.",
    switch_jobs = "обменяться профессиями",

    cooks_only = "Только для поваров.",

    -- Misc
    unknown = "Неизвестно",
    arguments = "аргументы",
    no_one = "никто",
    door = "дверь",
    vehicle = "транспорт",
    door_or_vehicle = "дверь/транспорт",
    driver = "Водитель: %s",
    name = "Имя: %s",
    locked = "Заперто.",
    unlocked = "Открыто.",
    player_doesnt_exist = "Игрок не найден.",
    job_doesnt_exist = "Такой профессии нет!",
    must_be_alive_to_do_x = "Нужно быть живым, чтобы %s.",
    banned_or_demoted = "Запрещено / уволен",
    wait_with_that = "Не так быстро.",
    could_not_find = "Не удалось найти: %s",
    f3tovote = "F3 — голосовать",
    listen_up = "Внимание:", -- In rp_tell or rp_tellall
    nlr = "Правило новой жизни: не мстите за свою смерть.",
    reset_settings = "Все настройки сброшены!",
    must_be_x = "Нужно быть «%s», чтобы %s.",
    agenda = "повестка",
    agenda_updated = "Повестка обновлена",
    job_set = "%s сменил профессию на «%s»",
    demote_vote = "увольнение",
    demoted = "%s уволен",
    demoted_not = "%s не уволен",
    demote_vote_started = "%s начал голосование за увольнение игрока %s",
    demote_vote_text = "Кандидат на увольнение:\n%s", -- '%s' is the reason here
    cant_demote_self = "Нельзя уволить самого себя.",
    i_want_to_demote_you = "Я хочу тебя уволить. Причина: %s",
    tried_to_avoid_demotion = "Вы пытались избежать увольнения. Не вышло — вы уволены.", -- naughty boy!
    lockdown_started = "Объявлен комендантский час, возвращайтесь в укрытия!",
    lockdown_ended = "Комендантский час окончен",
    gunlicense_requested = "%s запросил у %s лицензию на оружие",
    gunlicense_granted = "%s выдал %s лицензию на оружие",
    gunlicense_denied = "%s отказал %s в лицензии на оружие",
    gunlicense_question_text = "Выдать %s лицензию на оружие?",
    gunlicense_remove_vote_text = "%s начал голосование за отзыв лицензии у %s",
    gunlicense_remove_vote_text2 = "Отозвать лицензию:\n%s", -- Where %s is the reason
    gunlicense_removed = "Лицензия игрока %s отозвана!",
    gunlicense_not_removed = "Лицензия игрока %s не отозвана!",
    vote_specify_reason = "Укажите причину!",
    vote_started = "Голосование создано",
    vote_alone = "Вы победили в голосовании: вы один на сервере.",
    you_cannot_vote = "Вы не можете голосовать!",
    x_cancelled_vote = "%s отменил последнее голосование.",
    cant_cancel_vote = "Нечего отменять: голосований не было!",
    jail_punishment = "Наказание за выход с сервера! Арест на %d сек.",
    admin_only = "Только для администраторов!", -- When doing /addjailpos
    chief_or = "Начальник или ",-- When doing /addjailpos
    frozen = "Заморожено.",
    recipient = "получатель",
    forbidden_name = "Запрещённое имя.",
    illegal_characters = "Недопустимые символы.",
    too_long = "Слишком длинно.",
    too_short = "Слишком коротко.",

    dead_in_jail = "Вы мертвы до окончания срока ареста!",
    died_in_jail = "%s погиб под арестом!",

    credits_for = "АВТОРЫ %s\n",
    credits_see_console = "Список авторов DarkRP выведен в консоль.",

    rp_getvehicles = "Доступный транспорт для своих машин:",

    data_not_loaded_one = "Ваши данные ещё не загружены. Подождите.",
    data_not_loaded_two = "Если это не проходит, перезайдите или обратитесь к администратору.",

    cant_spawn_weapons = "Вы не можете создавать оружие.",
    drive_disabled = "Управление объектами пока отключено.",
    property_disabled = "Свойства объектов пока отключены.",

    not_allowed_to_purchase = "Вам нельзя покупать этот предмет.",

    rp_teamban_hint = "rp_teamban [имя/ID игрока] [название/ID профессии]. Запретить игроку профессию.",
    rp_teamunban_hint = "rp_teamunban [имя/ID игрока] [название/ID профессии]. Снять запрет на профессию.",
    x_teambanned_y_for_z = "%s запретил игроку %s профессию «%s» на %s мин.",
    x_teamunbanned_y = "%s снял с игрока %s запрет на профессию «%s».",

    -- Backwards compatibility:
    you_set_x_salary_to_y = "Вы установили игроку %s жалование %s%d.",
    x_set_your_salary_to_y = "%s установил вам жалование %s%d.",
    you_set_x_money_to_y = "Вы установили игроку %s деньги: %s%d.",
    x_set_your_money_to_y = "%s установил вам деньги: %s%d.",

    you_set_x_salary = "Вы установили игроку %s жалование %s.",
    x_set_your_salary = "%s установил вам жалование %s.",
    you_set_x_money = "Вы установили игроку %s деньги: %s.",
    x_set_your_money = "%s установил вам деньги: %s.",
    you_set_x_name = "Вы сменили имя игрока %s на %s",
    x_set_your_name = "%s сменил ваше имя на %s",

    someone_stole_steam_name = "Ваше имя Steam уже занято как RP-имя, поэтому к нему добавлена «1».", -- Uh oh
    already_taken = "Уже занято.",

    job_doesnt_require_vote_currently = "Сейчас для этой профессии голосование не нужно!",

    x_made_you_a_y = "%s назначил вас: %s!",

    cmd_cant_be_run_server_console = "Эту команду нельзя выполнить из консоли сервера.",

    -- The lottery
    lottery_started = "Лотерея! Участвовать за %s%d?", -- backwards compatibility
    lottery_has_started = "Лотерея! Участвовать за %s?",
    lottery_entered = "Вы участвуете в лотерее за %s",
    lottery_not_entered = "%s не участвует в лотерее",
    lottery_noone_entered = "Никто не участвует в лотерее",
    lottery_won = "%s выиграл в лотерею! Выигрыш: %s",
    lottery = "лотерея",
    lottery_please_specify_an_entry_cost = "Укажите стоимость участия (%s–%s)",
    too_few_players_for_lottery = "Слишком мало игроков для лотереи. Нужно не меньше %d",
    lottery_ongoing = "Нельзя начать лотерею: она уже идёт",

    -- Animations
    custom_animation = "Анимация!",
    bow = "Поклон",
    sexy_dance = "Зажигательный танец",
    follow_me = "За мной!",
    laugh = "Смех",
    lion_pose = "Поза льва",
    nonverbal_no = "Жест «нет»",
    thumbs_up = "Большой палец",
    wave = "Помахать",
    dance = "Танец",

    -- Hungermod
    starving = "Голодаете!",

    -- AFK
    afk_mode = "Режим AFK",
    unable_afk_spam_prevention = "Подождите, прежде чем снова уходить в AFK.",
    salary_frozen = "Ваше жалование заморожено.",
    salary_restored = "С возвращением, жалование снова начисляется.",
    no_auto_demote = "Вас не уволят автоматически.",
    youre_afk_demoted = "Вы уволены за долгое бездействие. В следующий раз используйте /afk.",
    hes_afk_demoted = "%s уволен за долгое бездействие.",
    afk_cmd_to_exit = "Введите /afk, чтобы выйти из режима AFK.",
    player_now_afk = "%s отошёл (AFK).",
    player_no_longer_afk = "%s вернулся.",

    -- Hitmenu
    hit = "заказ",
    hitman = "Киллер",
    current_hit = "Заказ: %s",
    cannot_request_hit = "Нельзя сделать заказ! %s",
    hitmenu_request = "Заказать",
    player_not_hitman = "Этот игрок не киллер!",
    distance_too_big = "Слишком далеко.",
    hitman_no_suicide = "Киллер не станет убивать себя.",
    hitman_no_self_order = "Киллер не может заказать сам себя.",
    hitman_already_has_hit = "У киллера уже есть заказ.",
    price_too_low = "Слишком низкая цена!",
    hit_target_recently_killed_by_hit = "Цель недавно уже убили по заказу,",
    customer_recently_bought_hit = "Заказчик недавно уже делал заказ.",
    accept_hit_question = "Принять заказ от %s\nна %s за %s%d?", -- backwards compatibility
    accept_hit_request = "Принять заказ от %s\nна %s за %s?",
    hit_requested = "Заказ отправлен!",
    hit_aborted = "Заказ отменён! %s",
    hit_accepted = "Заказ принят!",
    hit_declined = "Киллер отклонил заказ!",
    hitman_left_server = "Киллер покинул сервер!",
    customer_left_server = "Заказчик покинул сервер!",
    target_left_server = "Цель покинула сервер!",
    hit_price_set_to_x = "Цена заказа: %s%d.", -- backwards compatibility
    hit_price_set = "Цена заказа: %s.",
    hit_complete = "Заказ выполнен: %s!",
    hitman_died = "Киллер погиб!",
    target_died = "Цель погибла!",
    hitman_arrested = "Киллера арестовали!",
    hitman_changed_team = "Киллер сменил профессию!",
    x_had_hit_ordered_by_y = "На %s был активный заказ от %s",
    place_a_hit = "сделать заказ!",
    hit_cancel = "отмена заказа!",
    hit_cancelled = "Заказ отменён!",
    no_active_hit = "У вас нет активного заказа!",

    -- Vote Restrictions
    hobos_no_rights = "У бездомных нет права голоса!",
    gangsters_cant_vote_for_government = "Бандиты не голосуют по делам власти!",
    government_cant_vote_for_gangsters = "Чиновники не голосуют по делам бандитов!",

    -- VGUI and some more doors/vehicles
    vote = "Голосование",
    time = "Время: %d",
    yes = "Да",
    no = "Нет",
    ok = "Хорошо",
    cancel = "Отмена",
    add = "Добавить",
    remove = "Убрать",
    none = "Нет",

    x_options = "Действия: %s",
    sell_x = "Продать: %s",
    set_x_title = "Подписать: %s",
    set_x_title_long = "Задать подпись объекту (%s), на который вы смотрите.",
    jobs = "Профессии",
    buy_x = "Купить: %s",

    -- F4menu
    ammo = "патроны",
    weapon_ = "оружие",
    no_extra_weapons = "Профессия не выдаёт оружия — снаряжение берётся из инвентаря (TAB).",
    become_job = "Выбрать профессию",
    create_vote_for_job = "Начать голосование",
    shipment = "поставка",
    Shipments = "Поставки",
    shipments = "поставки",
    F4guns = "Оружие",
    F4entities = "Разное",
    F4ammo = "Патроны",
    F4vehicles = "Транспорт",

    -- Tab 1
    give_money = "Передать деньги игроку перед вами",
    drop_money = "Выбросить деньги",
    change_name = "Сменить RP-имя",
    go_to_sleep = "Уснуть / проснуться",
    drop_weapon = "Выбросить текущее оружие",
    buy_health = "Купить здоровье (%s)",
    request_gunlicense = "Запросить лицензию на оружие",
    demote_player_menu = "Уволить игрока",

    searchwarrantbutton = "Объявить игрока в розыск",
    unwarrantbutton = "Снять розыск с игрока",
    noone_available = "Никого нет",
    request_warrant = "Запросить ордер на обыск",
    make_wanted = "Объявить в розыск",
    make_unwanted = "Снять розыск",
    set_jailpos = "Задать точку заключения",
    add_jailpos = "Добавить точку заключения",

    set_custom_job = "Своё название профессии (Enter — применить)",

    set_agenda = "Задать повестку (Enter — применить)",

    initiate_lockdown = "Объявить комендантский час",
    stop_lockdown = "Отменить комендантский час",
    start_lottery = "Начать лотерею",
    give_license_lookingat = "Выдать лицензию игроку перед вами",

    laws_of_the_land = "ЗАКОНЫ ЗОНЫ",
    law_added = "Закон добавлен.",
    law_removed = "Закон удалён.",
    law_reset = "Законы сброшены.",
    law_too_short = "Слишком короткий закон.",
    laws_full = "Список законов заполнен.",
    default_law_change_denied = "Базовые законы менять нельзя.",

    -- Second tab
    job_name = "Название: ",
    job_description = "Описание: ",
    job_weapons = "Оружие: ",

    -- Entities tab
    buy_a = "Купить %s: %s",

    -- Licenseweaponstab
    license_tab = [[Оружие без лицензии

    Отметьте оружие, которое можно получить БЕЗ лицензии!
    ]],
    license_tab_other_weapons = "Другое оружие:",
}

DarkRP.addLanguage("ru", my_language)
