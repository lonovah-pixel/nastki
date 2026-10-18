-- Предмет «Маячок». Инвентарь и Зона грузятся позже событий, поэтому регистрация — по их хукам готовности
-- (и сразу, если они уже загружены, например после lua_refresh).
local E=STALKER_EVENTS
E.BeaconItem="beacon"
E.BeaconPrice={buy=600,sell=200}
-- У каких торговцев маячок есть в продаже (если ассортимент Зоны установлен).
E.BeaconTraders={sidor=3,trader_clearsky=2,trader_military=2}

function E.RegisterItems()
 local S=STALKER_INV;if not S or not S.RegisterItem then return false end
 S.RegisterItem(E.BeaconItem,{name="Маячок",model="models/props_lab/reciever01b.mdl",weight=.4,stackable=true,max_stack=5,category="misc",
  icon="stalker_events/items/beacon.png",
  description="Радиомаячок с проблесковым огнём. «Использовать» — поставить под прицелом и выбрать, кому виден сигнал: только вам или вашей группировке. "..
   "Батареи хватает на ограниченное время, срок — в КПК во вкладке «События». Забрать свой маячок — подойти и нажать E."})
 if SERVER then
  S.Items[E.BeaconItem].OnUse=function(ply) return E.BeaconPrompt(ply) end
 end
 return true
end

function E.RegisterPrices()
 local Z=STALKER_ZONE;if not Z or type(Z.ItemPrices)~="table" then return false end
 Z.ItemPrices[E.BeaconItem]=Z.ItemPrices[E.BeaconItem] or table.Copy(E.BeaconPrice)
 if type(Z.TraderStock)=="table" then
  for trader,count in pairs(E.BeaconTraders) do
   local list=Z.TraderStock[trader]
   if type(list)=="table" then
    local has=false;for _,row in ipairs(list) do if row[1]==E.BeaconItem then has=true end end
    if not has then list[#list+1]={E.BeaconItem,count} end
   end
  end
 end
 -- Торговцы уже настроены Зоной при её загрузке: обновляем цены и склады сразу.
 if SERVER and Z.ConfigureTraders then pcall(Z.ConfigureTraders) end
 return true
end

E.RegisterItems();E.RegisterPrices()
hook.Add("STALKER_INV_Ready","STALKER_EVENTS.Items",function() E.RegisterItems() end)
hook.Add("STALKER_ZONE_Ready","STALKER_EVENTS.Prices",function() E.RegisterPrices() end)
