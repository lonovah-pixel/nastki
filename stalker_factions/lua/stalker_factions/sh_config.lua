local F=STFW
F.Config={JoinFee=5000, JoinFees={loner=0}, ApprovalLifetime=86400,Language="ru",Debug=false,JoinCooldown=0,JoinMinRep=-100,RecruitDistance=180,
 CaptureSeconds=60,MaxContributors=3,SpawnProtection=10,ProposalTTL=600,TruceSeconds=300,
 VictoryScore=100,KillScore=1,CaptureScore=10,ControlScore=1,MaxPoints=48,
 RadarRange=2000,EnableBaseSpawn=true,DarkRP={Enabled=true,Mode="recruiter",Teams={}},
 MutantClasses={},TraderFactions={sidor="loner"}}
-- Teams: [имя TEAM-константы] = ID фракции. Профессии DarkRP не меняются автоматически.
F.Factions={}
local rows={
 {"loner","Одиночки","Loners","ОД",{181,159,94},true},
 {"duty","Долг","Duty","ДЛ",{180,65,48},true},
 {"freedom","Свобода","Freedom","СВ",{109,151,73},true},
 {"bandits","Бандиты","Bandits","БД",{140,120,101},true},
 {"mercs","Наёмники","Mercenaries","НМ",{84,126,167},true},
 {"monolith","Монолит","Monolith","МН",{180,190,187},true},
 {"military","Военные","Military","ВС",{126,142,79},true},
 {"clearsky","Чистое Небо","Clear Sky","ЧН",{108,184,189},true},
 {"scientists","Учёные","Scientists","УЧ",{204,161,72},true},
 {"ecologists","Экологи","Ecologists","ЭК",{179,176,89},true},
 {"renegades","Ренегаты","Renegades","РН",{154,115,74},true},
 {"zombies","Зомби","Zombies","ЗМ",{110,114,96},false},
 {"mutants","Мутанты","Mutants","МТ",{141,78,62},false}}
for _,r in ipairs(rows) do F.Factions[r[1]]={name={ru=r[2],en=r[3]},tag=r[4],color=r[5],playable=r[6],
 description={ru="Выживание, влияние и контроль территории Зоны.",en="Survival, influence and territory in the Zone."},
 ideology={ru="Определяется командованием группировки.",en="Defined by faction leadership."},emblem="",minRep=-100} end
F.Ranks={{0,"Новичок","Rookie"},{100,"Опытный","Experienced"},{300,"Ветеран","Veteran"},{700,"Мастер","Master"},{1500,"Легенда","Legend"}}
F.InitialRelations={{"duty","freedom",-60},{"military","bandits",-70},{"loner","bandits",-50},{"clearsky","scientists",60}}

local lore={
 loner={"Свободные сталкеры без единого командования.","Independent stalkers without a central command.","Выжить, найти хабар и вернуться.","Survive, find artifacts and return."},
 duty={"Дисциплинированная военизированная группировка.","A disciplined paramilitary faction.","Защитить мир от угроз Зоны.","Protect the world from the Zone."},
 freedom={"Сообщество сторонников свободной Зоны.","A community advocating an open Zone.","Свобода исследования и доступа.","Freedom to explore and enter."},
 bandits={"Вооружённые банды, живущие поборами и контрабандой.","Armed gangs relying on extortion and smuggling.","Прибыль и влияние.","Profit and influence."},
 mercs={"Профессиональные бойцы по контракту.","Professional contract fighters.","Выполнить контракт.","Complete the contract."},
 monolith={"Замкнутая группировка фанатичных защитников центра Зоны.","An insular faction of fanatical defenders of the Zone's center.","Служение Монолиту.","Service to the Monolith."},
 military={"Военные подразделения, контролирующие периметр.","Military units controlling the perimeter.","Приказ, порядок, контроль.","Orders, discipline, control."},
 clearsky={"Исследователи, ищущие понимание природы Зоны.","Researchers seeking to understand the Zone.","Понять и сохранить равновесие.","Understand and preserve balance."},
 scientists={"Научные экспедиции и полевые лаборатории.","Scientific expeditions and field laboratories.","Наблюдать, измерять, объяснять.","Observe, measure, explain."},
 ecologists={"Специалисты по последствиям аномальной среды.","Specialists studying the anomalous environment.","Исследовать и ограничить вред.","Study and limit environmental harm."},
 renegades={"Отколовшиеся и изгнанные сталкеры.","Splinter groups and outcast stalkers.","Выжить любой ценой.","Survive at any cost."}}
for id,v in pairs(lore) do F.Factions[id].description={ru=v[1],en=v[2]};F.Factions[id].ideology={ru=v[3],en=v[4]} end
