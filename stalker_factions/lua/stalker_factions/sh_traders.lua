local F=STFW
-- Профили создаются в обоих realms до загрузки складов. Склад отдельный на профиль.
function F.RegisterTraders()
 local N=STALKER_NPC;if not N or not N.Config then return end
 local base=N.Config.Traders.sidor;if not base then return end
 local rows={
 loner={'sidor','Сидорович','male_07','Заходи, сталкер. Аптечки, патроны, провизия — всё по делу. За хороший хабар плачу честно.'},
 duty={'trader_duty','Прапор','male_04','Снабжение Долга. Оружие держи на предохранителе. Если нужны боеприпасы или аптечки — выкладывай список.'},
 freedom={'trader_freedom','Складовщик Свободы','male_02','Здорово. На складе есть чем поживиться. Посмотри ассортимент — договоримся без лишних церемоний.'},
 bandits={'trader_bandits','Скупщик','male_09','Товар показывай. За целое заплачу, за хлам много не проси. Цены увидишь до сделки.'},
 mercs={'trader_mercs','Интендант','male_08','Снабжение по контракту. Цена зависит от состояния снаряжения и наших отношений. Выбирайте.'},
 monolith={'trader_monolith','Хранитель','male_01','Запасы подготовлены. Возьми необходимое для пути. Пригодные образцы могут пополнить наши резервы.'},
 military={'trader_military','Каптенармус','male_03','У пункта снабжения не задерживаться. Заявку на снаряжение оформляй здесь. Расчёт по ведомости.'},
 clearsky={'trader_clearsky','Техник снабжения','male_06','С болот без припасов лучше не выходить. Есть медикаменты и боеприпасы. Образцы тоже принимаем.'},
 scientists={'trader_scientists','Лаборант','male_05','Добро пожаловать. Нас интересуют образцы тканей и артефакты. Чистые, неповреждённые материалы ценятся выше.'},
 ecologists={'trader_ecologists','Полевой закупщик','male_07','Собираем материалы для анализа среды. Токсичные образцы принимаем отдельно, с поправкой к цене.'},
 renegades={'trader_renegades','Меняла','male_09','Запасов немного, но без дела не уйдёшь. Покажи добычу и выбери, что нужно.'}}
 for faction,row in pairs(rows) do
  local id,name,model,greeting=row[1],row[2],row[3],row[4]
  local profile=N.Config.Traders[id] or table.Copy(base)
  profile.Faction=faction;profile.AcceptButchering=true;profile.Buyback=false
  profile.name={ru=name,en=name};profile.role={ru='Снабжение / '..F.Name(faction),en='Faction supplies / '..F.Name(faction)}
  profile.model='models/Humans/Group01/'..model..'.mdl';profile.root='greeting'
  profile.info={ru='Покупка и продажа через кошелёк DarkRP. Итог подтверждается перед оплатой. Цена учитывает состояние, репутацию и отношения группировок. Скупленные образцы уходят в резервы и не занимают витрину.',en='DarkRP wallet. Confirm the quote before payment. Condition and faction relations affect prices. Sold samples go to reserves.'}
  profile.prices.artifact=profile.prices.artifact or {buy=5500,sell=2200}
  profile.nodes={
   greeting={text={ru=greeting,en='Welcome. Supplies and field samples are available for trade.'},choices={
    {id='trade',text={ru='Покажи ассортимент. Хочу купить или продать.',en='Show your stock. Buy or sell.'},action='trade'},
    {id='terms',text={ru='От чего зависят твои цены?',en='How do you set prices?'},next='terms'},
    {id='samples',text={ru='Принимаешь части мутантов и артефакты?',en='Do you accept samples and artifacts?'},next='samples'},
    {id='faction',text={ru='Расскажи о вашей группировке.',en='Tell me about your faction.'},next='faction'},
    {id='bye',text={ru='Бывай.',en='Goodbye.'},action='close'}}},
   terms={text={ru='Сначала собираешь предложение. Потом я проверяю наличие товара, вес и деньги. Повреждённое снаряжение дешевле. Союзникам условия лучше, во время войны торговля закрыта.',en='Build your offer, then review the quote. Condition and relations affect prices. Trade is blocked during war.'},choices={
    {id='trade',text={ru='Понятно. Перейдём к торговле.',en='Let us trade.'},action='trade'},
    {id='back',text={ru='Назад к разговору.',en='Back.'},next='greeting'}}},
   samples={text={ru='Да. Мясо, шкуры, органы и редкие компоненты. За чистый образец в хорошем состоянии получишь больше. Токсичность и повреждения учитываются в цене.',en='Meat, hides, organs and rare components. Clean, intact samples are worth more.'},choices={
    {id='trade',text={ru='Посмотри, что у меня есть.',en='See what I have.'},action='trade'},
    {id='back',text={ru='Вернёмся к разговору.',en='Back.'},next='greeting'}}},
   faction={text=F.Factions[faction].description,choices={{id='back',text={ru='Ясно. Что ещё?',en='Understood. What else?'},next='greeting'}}}}
  N.Config.Traders[id]=profile;F.Config.TraderFactions[id]=faction
 end
end
F.RegisterTraders()
