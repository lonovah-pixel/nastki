-- Параметры разделки в общей админ-панели (STALKER_SETTINGS, раздел «Разделка туш»).
local B=STALKER_BUTCHERING
local S=STALKER_SETTINGS;if not S then return end
local cat="Разделка туш"
S.Bind("butcher.distance",B.Config,"Distance",{category=cat,label="Дистанция разделки, юниты",type="number",min=60,max=300,realm="shared",order=1})
S.Bind("butcher.corpse_lifetime",B.Config,"CorpseLifetime",{category=cat,label="Туша доступна, сек",type="number",min=30,max=3600,order=2})
S.Bind("butcher.max_corpses",B.Config,"MaxCorpses",{category=cat,label="Лимит туш на карте",type="number",min=8,max=256,order=3})
S.Bind("butcher.cooldown",B.Config,"Cooldown",{category=cat,label="Пауза между разделками, сек",type="number",min=0,max=60,step=.5,decimals=1,order=4})
-- Номер разреза передаётся двумя битами: больше трёх раундов клиент не отправит.
S.Bind("butcher.rounds",B.Config,"Rounds",{category=cat,label="Разрезов за разделку",type="number",min=1,max=3,order=5})
S.Bind("butcher.round_seconds",B.Config,"RoundSeconds",{category=cat,label="Время на разрез, сек",type="number",min=1,max=6,step=.1,decimals=1,order=6})
S.Bind("butcher.cancel_on_damage",B.Config,"CancelOnDamage",{category=cat,label="Урон прерывает разделку",type="bool",order=7})
S.Bind("butcher.max_weight",B.Config,"MaxWeight",{category=cat,label="Трофеи кладутся, пока вес рюкзака не больше, кг",type="number",min=1,max=500,order=8})
for i,part in ipairs(B.Config.Parts) do
 S.Bind("butcher.price_"..part.id,part,"price",{category=cat,label="Цена трофея «"..part.name.."» у торговца, ₽",type="number",min=0,max=100000,order=20+i,
  onChange=function() if SERVER and B.RegisterTrade then B.RegisterTrade(true) end end})
 S.Bind("butcher.yield_"..part.id,part,"base",{category=cat,label="Выход «"..part.name.."» за удачную разделку, шт.",type="number",min=0,max=20,order=30+i})
end
