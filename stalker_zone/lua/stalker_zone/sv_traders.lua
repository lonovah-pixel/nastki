-- Ассортимент торговцев группировок и восполнение складов.
-- Без восполнения склад NPC только убывает: скупленное уходит «в резервы» (Buyback=false).
local Z=STALKER_ZONE

local common={{"medkit",10},{"bandage",20},{"antirad",8},{"water",10},{"food",8},{"bread",10},
 {"ammo_pistol",30},{"ammo_smg",30},{"ammo_buckshot",20},{"crowbar",2},{"det_echo",2},{"gasmask",2}}
Z.TraderStock={
 sidor={{"pistol",2},{"revolver",1},{"rifle",1},{"shotgun",1},{"jacket",2},{"zarya",1},{"helmet",1},{"boots",2},
  {"vodka",10},{"sausage",8},{"ammo_357",10},{"grenade",4},{"det_bear",1},{"hazmat",1}},
 trader_duty={{"rifle",2},{"shotgun",2},{"duty_suit",1},{"exo",1},{"tactical_helmet",1},{"army_boots",2},{"medkit_army",6},{"ammo_357",10},{"grenade",6}},
 trader_freedom={{"rifle",2},{"revolver",1},{"freedom_suit",1},{"exo",1},{"sphere",1},{"energy",10},{"vodka",10},{"ar2",1},{"ammo_ar2",10}},
 trader_bandits={{"pistol",3},{"shotgun",2},{"bandit_jacket",3},{"vodka",15},{"sausage",10},{"ammo_357",6}},
 trader_mercs={{"ar2",1},{"ammo_ar2",15},{"merc_suit",1},{"sphere",1},{"crossbow",1},{"ammo_bolt",8},{"medkit_army",5}},
 trader_monolith={{"ar2",1},{"ammo_ar2",15},{"monolith_suit",1},{"tactical_helmet",1},{"medkit_army",5}},
 trader_military={{"rifle",3},{"berill",1},{"tactical_helmet",2},{"army_boots",2},{"grenade",8},{"medkit_army",8},{"ammo_357",10}},
 trader_clearsky={{"rifle",1},{"zarya",2},{"det_bear",1},{"medkit_sci",4},{"army_boots",1}},
 trader_scientists={{"seva",1},{"hazmat",2},{"medkit_sci",8},{"det_bear",2},{"det_veles",1},{"antirad",15}},
 trader_ecologists={{"hazmat",2},{"seva",1},{"gasmask",3},{"medkit_sci",6},{"det_veles",1}},
 trader_renegades={{"pistol",2},{"shotgun",1},{"bandit_jacket",2},{"vodka",10}},
}
-- Учёные и экологи платят за артефакты больше остальных.
Z.ArtifactBonus={trader_scientists=1.25,trader_ecologists=1.15}

local function assortment(id)
 local list={}
 for _,row in ipairs(common) do list[#list+1]={row[1],row[2]} end
 for _,row in ipairs(Z.TraderStock[id] or {}) do list[#list+1]={row[1],row[2]} end
 return list
end

function Z.ConfigureTraders()
 local N=STALKER_NPC;local S=STALKER_INV
 if not N or not N.Config or not N.Config.Traders or not S then return end
 for id,profile in pairs(N.Config.Traders) do
  profile.prices=profile.prices or {}
  for item,price in pairs(Z.ItemPrices) do
   if S.Items[item] and not profile.prices[item] then
    local sell=price.sell
    if Z.Artifacts[item] and Z.ArtifactBonus[id] then sell=math.floor(sell*Z.ArtifactBonus[id]) end
    profile.prices[item]={buy=price.buy,sell=sell}
   end
  end
  local stock={}
  for _,row in ipairs(assortment(id)) do if S.Items[row[1]] and profile.prices[row[1]] then stock[#stock+1]=row end end
  profile.stock=stock
 end
end
Z.ConfigureTraders()
-- Разделка добавляет цены частей мутантов на InitPostEntity; наши цены не перекрывают её.
hook.Add("InitPostEntity","STALKER_ZONE.Traders",function() Z.ConfigureTraders() end)

-- Пополнение: недостающее до нормы, не больше доли RestockShare за раз. Ревизия склада растёт,
-- поэтому открытые предложения игроков становятся устаревшими и пересчитываются.
function Z.RestockTrader(id)
 local N=STALKER_NPC;local S=STALKER_INV
 local profile=N.Config.Traders[id];if not profile or not N.DatabaseReady or N.Busy then return false end
 local stock=N.GetStock(id);if not stock then return false end
 local have={}
 for _,item in pairs(stock.grid) do have[item.id]=(have[item.id] or 0)+item.count end
 local nextStock=stock;local changed=false
 for _,row in ipairs(profile.stock or {}) do
  local want=row[2]-(have[row[1]] or 0)
  if want>0 then
   local add=math.max(1,math.ceil(want*Z.Config.RestockShare))
   local candidate=S.Insert(nextStock,row[1],add)
   if candidate then nextStock=candidate;changed=true end
  end
 end
 if not changed then return false end
 nextStock.revision=((stock.revision or 0)+1)%4294967296
 if N.Query("REPLACE INTO stnpc_stock VALUES("..sql.SQLStr(id)..","..sql.SQLStr(util.TableToJSON(nextStock))..")")==false then return false end
 N.Stocks[id]=nextStock
 return true
end

function Z.RestockAll()
 local N=STALKER_NPC;if not N or not N.Config then return 0 end
 local n=0
 for id in pairs(N.Config.Traders) do if Z.RestockTrader(id) then n=n+1 end end
 if n>0 and N.Log then N.Log("zone_restock",{traders=n}) end
 return n
end
timer.Create("STALKER_ZONE.Restock",60,0,function()
 Z.RestockCounter=(Z.RestockCounter or 0)+1
 if Z.RestockCounter>=Z.Config.RestockMinutes then Z.RestockCounter=0;Z.RestockAll() end
end)
-- Первый прогон после загрузки: склады, созданные до установки аддона, получают новый ассортимент.
hook.Add("InitPostEntity","STALKER_ZONE.Restock",function() timer.Simple(10,function() Z.RestockAll() end) end)
concommand.Add("stz_restock",function(p)
 if IsValid(p) and not p:IsSuperAdmin() then return end
 local n=Z.RestockAll();local msg="[STALKER Zone] Пополнено складов: "..n
 if IsValid(p) then p:ChatPrint(msg) else print(msg) end
end)
