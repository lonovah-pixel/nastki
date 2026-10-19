-- Рецепты крафта и готовки: общий реестр для сервера (проверка и выдача) и клиента (окно и книга рецептов).
-- Рецепт доступен, только если все его предметы зарегистрированы в инвентаре сервера: например, патроны и граната
-- появляются вместе со STALKER Zone, маячок — вместе со STALKER Events, трофеи — вместе с разделкой.
local CR=STALKER_CRAFT
local Cfg=CR.Config

-- Где выполняется рецепт: tool — простой (набор инструментов в рюкзаке или верстак), bench — у верстака, fire — у костра.
CR.Stations={tool="Набор инструментов или верстак",bench="Верстак",fire="Костёр"}
CR.Kinds={craft="Крафт",cook="Готовка"}
CR.Categories={
 craft={{"repair","Ремонт"},{"ammo","Боеприпасы"},{"medicine","Медицина"},{"gear","Снаряжение"}},
 cook={{"food","Блюда"},{"drink","Напитки"}},
}
CR.CategoryName={}
for _,list in pairs(CR.Categories) do for _,c in ipairs(list) do CR.CategoryName[c[1]]=c[2] end end

--[[ Группы ингредиентов: любой трофей разделки нужной части. part — часть туши (meat, hide, organ, rare),
 clean/toxic — только чистые или только токсичные образцы. ]]
CR.Groups={
 hide={label="Шкура мутанта",part="hide"},
 hide_clean={label="Шкура мутанта (чистая)",part="hide",clean=true},
 meat_clean={label="Мясо мутанта (чистое)",part="meat",clean=true},
 meat_toxic={label="Мясо мутанта (токсичное)",part="meat",toxic=true},
 organ={label="Орган мутанта",part="organ"},
}
-- Существующие ID группы: худшие образцы первыми, чтобы хорошие трофеи оставались игроку.
function CR.GroupIDs(key)
 local g=CR.Groups[key];local S=STALKER_INV
 if not g or not S or not S.Items then return {} end
 local B=STALKER_BUTCHERING
 local grades=(B and type(B.Order)=="table") and B.Order or {"perfect","success","partial","fail"}
 local out={}
 for i=#grades,1,-1 do
  local grade=grades[i]
  if grade~="fail" then
   for _,toxic in ipairs({false,true}) do
    if (not g.clean or not toxic) and (not g.toxic or toxic) then
     local id=(B and B.ItemID) and B.ItemID(g.part,grade,toxic) or ("stb_"..g.part.."_"..grade..(toxic and "_toxic" or "_clean"))
     if S.Items[id] then out[#out+1]=id end
    end
   end
  end
 end
 return out
end

--[[ Рецепт:
 id, name — ключ и подпись; kind — craft | cook; cat — категория из CR.Categories; station — tool | bench | fire;
 time — базовое время, с (умножается на craft.time_mult или craft.cook_mult);
 need — ингредиенты: {"id", n} или {group="ключ CR.Groups", n=1}; give — результат: {{"id", n}, …};
 requires — предметы, без которых рецепт скрыт (кроме need/give); note — пояснение в окне. ]]
CR.Recipes=CR.Recipes or {}
CR.ByID=CR.ByID or {}
function CR.RegisterRecipe(r)
 assert(type(r)=="table" and type(r.id)=="string" and r.id:match("^[%w_]+$") and #r.id<=32,"RegisterRecipe: некорректный id")
 assert(type(r.need)=="table" and type(r.give)=="table" and #r.give>0,"RegisterRecipe: нужны need и give")
 r.kind=r.kind=="cook" and "cook" or "craft"
 r.station=CR.Stations[r.station or ""] and r.station or (r.kind=="cook" and "fire" or "tool")
 r.cat=r.cat or (r.kind=="cook" and "food" or "gear")
 r.time=math.Clamp(tonumber(r.time) or 3,.5,60)
 r.name=r.name or r.id
 if not CR.ByID[r.id] then CR.Recipes[#CR.Recipes+1]=r else for i,old in ipairs(CR.Recipes) do if old.id==r.id then CR.Recipes[i]=r end end end
 CR.ByID[r.id]=r
 return r
end
local add=CR.RegisterRecipe
-- Ремонт.
add({id="armor_kit",name="Ремкомплект брони",cat="repair",station="tool",time=4,need={{"scrap",4},{group="hide",n=1}},give={{"armor_kit",1}},
 note="Заплаты из шкуры и металлические пластины. Применяется к надетому костюму или шлему."})
add({id="weapon_kit",name="Оружейный набор",cat="repair",station="bench",time=5,need={{"scrap",7}},give={{"weapon_kit",1}},
 note="Пружины, бойки и смазка. Применяется к экипированному оружию."})
-- Боеприпасы: самодельные патроны из деталей.
add({id="ammo_pistol",name="Пистолетные патроны",cat="ammo",station="tool",time=3,need={{"scrap",2}},give={{"ammo_pistol",1}},
 note="Переснаряжённые гильзы. Делаются и в поле."})
add({id="ammo_buckshot",name="Дробь 12×70",cat="ammo",station="bench",time=4,need={{"scrap",3}},give={{"ammo_buckshot",1}}})
add({id="ammo_smg",name="Автоматные патроны",cat="ammo",station="bench",time=5,need={{"scrap",4}},give={{"ammo_smg",1}}})
-- Медицина.
add({id="bandage",name="Бинты из шкуры",cat="medicine",station="tool",time=3,need={{group="hide_clean",n=1}},give={{"bandage",3}},
 note="Выделанная чистая шкура режется на повязки. Токсичная шкура не годится."})
-- Снаряжение.
add({id="grenade",name="Граната",cat="gear",station="bench",time=6,need={{"scrap",5},{"ammo_buckshot",2}},give={{"grenade",1}},
 note="Корпус из деталей, порох из разобранных патронов."})
add({id="toolkit",name="Набор инструментов",cat="gear",station="bench",time=6,need={{"scrap",10}},give={{"toolkit",1}},
 note="С набором в рюкзаке простые рецепты доступны где угодно. Набор не расходуется."})
add({id="campfire_kit",name="Походный костёр",cat="gear",station="tool",time=3,need={{"scrap",3}},give={{"campfire_kit",1}},
 note="Сухое горючее и решётка. «Использовать» в инвентаре — разжечь костёр под прицелом."})
add({id="beacon",name="Маячок",cat="gear",station="bench",time=6,need={{"scrap",8},{group="organ",n=1}},give={{"beacon",1}},requires={"beacon"},
 note="Радиомаячок собирается, если на сервере установлены события Зоны. Орган мутанта — на изоляцию и клей."})
-- Готовка у костра.
add({id="meat_fried",name="Жареное мясо",kind="cook",cat="food",time=4,need={{group="meat_clean",n=1}},give={{"meat_fried",1}}})
add({id="meat_dubious",name="Сомнительное мясо",kind="cook",cat="food",time=7,need={{group="meat_toxic",n=1}},give={{"meat_dubious",1}},
 note="Токсичное мясо жарится дольше и всё равно фонит."})
add({id="shashlik",name="Шашлык",kind="cook",cat="food",time=6,need={{group="meat_clean",n=2}},give={{"shashlik",1}}})
add({id="stew",name="Похлёбка",kind="cook",cat="food",time=6,need={{group="meat_clean",n=1},{"water",1},{"bread",1}},give={{"stew",1}}})
add({id="tea",name="Чай",kind="cook",cat="drink",time=3,need={{"water",1}},give={{"tea",1}}})

--[[ Проверки (оба realm) ]]
local function itemName(id) local d=STALKER_INV and STALKER_INV.Items and STALKER_INV.Items[id];return d and d.name or id end
CR.ItemName=itemName

-- Рецепт можно показать и выполнить: все предметы зарегистрированы на этом сервере.
function CR.Available(r)
 local S=STALKER_INV
 if type(r)~="table" or r.disabled or not S or not S.Items then return false end
 for _,g in ipairs(r.give) do if not S.Items[g[1]] then return false end end
 for _,ing in ipairs(r.need) do
  if ing.group then if #CR.GroupIDs(ing.group)==0 then return false end
  elseif not S.Items[ing[1]] then return false end
 end
 for _,id in ipairs(r.requires or {}) do if not S.Items[id] then return false end end
 return true
end
function CR.List(kind)
 local out={}
 for _,r in ipairs(CR.Recipes) do if (not kind or r.kind==kind) and CR.Available(r) then out[#out+1]=r end end
 return out
end

function CR.Duration(r)
 local mult=r.kind=="cook" and Cfg.CookMult or Cfg.TimeMult
 return math.Clamp(r.time*(tonumber(mult) or 1),.5,120)
end

-- Сколько чего лежит в рюкзаке (экипировка не расходуется на крафт).
function CR.Counts(inv)
 local out={}
 if type(inv)~="table" or type(inv.grid)~="table" then return out end
 for _,item in pairs(inv.grid) do if type(item)=="table" and item.id then out[item.id]=(out[item.id] or 0)+(tonumber(item.count) or 0) end end
 return out
end

--[[ Что списать: take={[id]=n} или nil, если не хватает. rows — строки для окна: {label,id,have,need,ok}.
 times — сколько изделий сразу (для подсчёта «на сколько хватит»). ]]
function CR.Resolve(r,counts,times)
 times=times or 1
 local left={};for id,n in pairs(counts or {}) do left[id]=n end
 local take,rows,ok={},{},true
 for _,ing in ipairs(r.need) do
  local need=(ing.group and (ing.n or 1) or (ing[2] or 1))*times
  local ids=ing.group and CR.GroupIDs(ing.group) or {ing[1]}
  local have=0;for _,id in ipairs(ids) do have=have+(left[id] or 0) end
  local rest=need
  for _,id in ipairs(ids) do
   if rest<=0 then break end
   local n=math.min(rest,left[id] or 0)
   if n>0 then take[id]=(take[id] or 0)+n;left[id]=left[id]-n;rest=rest-n end
  end
  rows[#rows+1]={label=ing.group and CR.Groups[ing.group].label or itemName(ing[1]),id=ids[1],group=ing.group,have=have,need=need,ok=rest<=0}
  if rest>0 then ok=false end
 end
 return ok and take or nil,rows
end
-- На сколько изделий хватает ингредиентов (до предела очереди).
function CR.Possible(r,counts,limit)
 limit=limit or Cfg.MaxRepeat
 local n=0
 while n<limit and CR.Resolve(r,counts,n+1) do n=n+1 end
 return n
end
function CR.MissingText(rows)
 local parts={}
 for _,row in ipairs(rows or {}) do if not row.ok then parts[#parts+1]=row.label.." ("..row.have.."/"..row.need..")" end end
 return table.concat(parts,", ")
end

-- Ближайшая станция класса в радиусе (костёр — только горящий).
function CR.FindStation(ply,class)
 if not IsValid(ply) then return end
 local pos=ply:GetPos();local range=Cfg.StationRange;local best,bestD
 for _,e in ipairs(ents.FindByClass(class)) do
  if IsValid(e) and (not e.IsLit or e:IsLit()) then
   local d=e:GetPos():DistToSqr(pos)
   if d<=range*range and (not bestD or d<bestD) then best,bestD=e,d end
  end
 end
 return best
end
--[[ Где выполнить рецепт: сущность станции, true (набор инструментов в рюкзаке) или nil и причина. ]]
function CR.StationFor(ply,r,counts)
 if r.station=="fire" then
  local fire=CR.FindStation(ply,"stalker_campfire");if fire then return fire end
  return nil,"Нужен горящий костёр рядом"
 end
 local bench=CR.FindStation(ply,"stalker_workbench")
 if bench then return bench end
 if r.station=="bench" then return nil,"Нужен верстак" end
 if not Cfg.NeedToolkit or ((counts or {}).toolkit or 0)>0 then return true end
 return nil,"Нужен набор инструментов в рюкзаке или верстак рядом"
end
