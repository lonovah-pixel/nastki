-- Предметы крафта и блюда. Инвентарь и Зона грузятся позже крафта, поэтому регистрация — по их хукам готовности
-- (и сразу, если они уже загружены, например после lua_refresh). Реестр общий: файл выполняется в обоих realm.
local CR=STALKER_CRAFT
local Cfg=CR.Config
local function icon(id) return "stalker_craft/items/"..id..".png" end

--[[ price — цена у торговцев (buy — продажа игроку, sell — скупка), не выше стоимости ингредиентов, чтобы
 крафт не превращался в печатный станок. food — эффекты блюда до множителя craft.food_mult. ]]
CR.ItemDefs={
 {"toolkit",{name="Набор инструментов",model="models/props_c17/BriefCase001a.mdl",weight=1.6,category="tool",
  description="Ключи, надфили и паяльник в потёртом кейсе. Пока набор в рюкзаке, простые рецепты доступны где угодно. Не расходуется. «Использовать» — открыть мастерскую."},
  {buy=1200,sell=200}},
 {"armor_kit",{name="Ремкомплект брони",model="models/props_lab/box01a.mdl",weight=.6,stackable=true,max_stack=5,category="tool",
  description="Заплаты, клей и пластины. «Использовать» — восстановить состояние самого изношенного из надетых костюма и шлема."},
  {buy=1100,sell=220}},
 {"weapon_kit",{name="Оружейный набор",model="models/items/item_item_crate.mdl",weight=.7,stackable=true,max_stack=5,category="tool",
  description="Пружины, бойки и оружейное масло. «Использовать» — восстановить состояние самого изношенного экипированного оружия."},
  {buy=1000,sell=160}},
 {"campfire_kit",{name="Походный костёр",model="models/props_junk/cardboard_box004a.mdl",weight=.8,stackable=true,max_stack=5,category="misc",
  description="Сухое горючее и складная решётка. «Использовать» — разжечь костёр под прицелом. У огня можно готовить, он медленно лечит."},
  {buy=250,sell=50}},
 {"meat_fried",{name="Жареное мясо",model="models/props_junk/garbage_metalcan001a.mdl",weight=.3,stackable=true,max_stack=10,category="food",
  description="Мясо мутанта, прожаренное на костре. Сытно и немного восстанавливает силы."},{buy=200,sell=70},{hunger=45,health=5}},
 {"meat_dubious",{name="Сомнительное мясо",model="models/props_junk/garbage_metalcan001a.mdl",weight=.3,stackable=true,max_stack=10,category="food",
  description="Токсичное мясо, жаренное дольше обычного. Голод утоляет, но фонит: после еды растёт доза радиации."},{buy=80,sell=15},{hunger=35,dose=true}},
 {"shashlik",{name="Шашлык",model="models/props_junk/garbage_metalcan002a.mdl",weight=.5,stackable=true,max_stack=10,category="food",
  description="Два куска мяса на шампуре. Лучшее блюдо у костра."},{buy=380,sell=120},{hunger=80,health=10}},
 {"stew",{name="Похлёбка",model="models/props_junk/garbage_metalcan002a.mdl",weight=.6,stackable=true,max_stack=10,category="food",
  description="Мясо, хлеб и вода в котелке. Утоляет и голод, и жажду."},{buy=420,sell=140},{hunger=60,thirst=30,health=5}},
 {"tea",{name="Чай",model="models/props_junk/garbage_plasticbottle003a.mdl",weight=.5,stackable=true,max_stack=10,category="food",
  description="Кипячёная вода с травами. Хорошо утоляет жажду и согревает."},{buy=160,sell=40},{thirst=45,health=3}},
}
CR.Food={}
CR.PriceList={}
for _,row in ipairs(CR.ItemDefs) do CR.PriceList[row[1]]=row[3];if row[4] then CR.Food[row[1]]=row[4] end end
-- Ремкомплекты: какой слот и какая настройка.
CR.Kits={armor_kit={slots={"armor","helmet"},config="RepairArmor",label="надетые костюм и шлем"},
 weapon_kit={slots={"primary","secondary","pistol"},config="RepairWeapon",label="экипированное оружие"}}
function CR.KitAmount(kitID) local kit=CR.Kits[kitID];return kit and math.Clamp(math.floor(tonumber(Cfg[kit.config]) or 0),1,100) or 0 end

-- Числа в карточке предмета следуют за настройками (ремонт, множитель блюд, доза).
function CR.FoodValue(id,key)
 local f=CR.Food[id];if not f then return 0 end
 if key=="dose" then return f.dose and (tonumber(Cfg.ToxicDose) or 0) or 0 end
 local v=tonumber(f[key]) or 0
 if key=="hunger" or key=="thirst" then v=math.floor(v*(tonumber(Cfg.FoodMult) or 1)+.5) end
 return v
end
function CR.ApplyItemStats()
 local S=STALKER_INV;if not S or not S.Items then return end
 for id,kit in pairs(CR.Kits) do if S.Items[id] then S.Items[id].stats={repair=tonumber(Cfg[kit.config]) or 0} end end
 for id in pairs(CR.Food) do
  local d=S.Items[id]
  if d then
   local stats={}
   for _,key in ipairs({"hunger","thirst","health","dose"}) do local v=CR.FoodValue(id,key);if v>0 then stats[key=="dose" and "doseGain" or key]=v end end
   d.stats=stats
  end
 end
end

function CR.RegisterItems()
 local S=STALKER_INV;if not S or not S.RegisterItem then return false end
 S.CategoryNames=S.CategoryNames or {}
 S.CategoryNames.tool="Инструменты"
 for _,row in ipairs(CR.ItemDefs) do
  local data=table.Copy(row[2]);data.icon=icon(row[1])
  S.RegisterItem(row[1],data)
 end
 if S.RegisterStatFormat then
  S.RegisterStatFormat("repair",{label="Восстановление состояния",kind="percent",max=100,order=28})
  S.RegisterStatFormat("doseGain",{label="Доза радиации",kind="number",prefix="+",max=50,order=29,bad=true})
 end
 if S.StatNames then S.StatNames.repair="Ремонт";S.StatNames.doseGain="Доза радиации" end
 CR.ApplyItemStats()
 if SERVER and CR.RegisterUseHandlers then CR.RegisterUseHandlers() end
 CR.ItemsReady=true
 return true
end

-- Цены у торговцев Зоны и место в ассортименте (если Зона установлена).
CR.TraderStock={sidor={{"toolkit",2},{"armor_kit",2},{"campfire_kit",4}},trader_duty={{"armor_kit",3}},trader_military={{"armor_kit",3},{"weapon_kit",2}},
 trader_mercs={{"weapon_kit",2}},trader_bandits={{"campfire_kit",3}},trader_clearsky={{"toolkit",1},{"campfire_kit",3}}}
function CR.RegisterPrices()
 local Z=STALKER_ZONE;if not Z or type(Z.ItemPrices)~="table" then return false end
 for id,price in pairs(CR.PriceList) do Z.ItemPrices[id]=Z.ItemPrices[id] or table.Copy(price) end
 if type(Z.TraderStock)=="table" then
  for trader,rows in pairs(CR.TraderStock) do
   local list=Z.TraderStock[trader]
   if type(list)=="table" then
    for _,row in ipairs(rows) do
     local has=false;for _,r in ipairs(list) do if r[1]==row[1] then has=true end end
     if not has then list[#list+1]={row[1],row[2]} end
    end
   end
  end
 end
 -- Торговцы уже настроены Зоной при её загрузке: обновляем цены и склады сразу.
 if SERVER and Z.ConfigureTraders then pcall(Z.ConfigureTraders) end
 return true
end

CR.RegisterItems();CR.RegisterPrices()
hook.Add("STALKER_INV_Ready","STALKER_CRAFT.Items",function() CR.RegisterItems() end)
hook.Add("STALKER_ZONE_Ready","STALKER_CRAFT.Prices",function() CR.RegisterPrices() end)
