local B=STALKER_BUTCHERING
function B.RegisterItems()
 local S=STALKER_INV;if not S or not S.RegisterItem then return end
 for _,part in ipairs(B.Config.Parts) do for _,grade in ipairs(B.Order) do if grade~='fail' then
  for _,toxic in ipairs({false,true}) do
   local id=B.ItemID(part.id,grade,toxic)
   S.RegisterItem(id,{name=part.name..' / '..B.Config.Grades[grade].name..(toxic and ' / токсично' or ''),
    description='Трофей разделки. '..(toxic and 'Токсичный образец; требует обработки специалистом.' or 'Образец без выявленного токсичного загрязнения.'),
    weight=part.weight,model=part.model,category='material',stackable=true,max_stack=20,durability=B.Config.Grades[grade].condition,
    stats={toxicity=toxic and 100 or 0}})
  end
 end end end
 S.StatNames.toxicity='Токсичность'
end
B.RegisterItems()
hook.Add('STALKER_INV_Ready','STB.Items',B.RegisterItems)
-- Не заменяем PriceMultiplier: дипломатия и цены войны продолжают работать.
-- force — пересчитать цены после изменения в админ-панели (иначе цены, заданные торговцу вручную, не трогаем).
function B.RegisterTrade(force)
 local N=STALKER_NPC;if not N or not N.Config then return end
 for id,t in pairs(N.Config.Traders) do if B.Config.TraderIDs[id] or t.AcceptButchering then
  for _,part in ipairs(B.Config.Parts) do for _,grade in ipairs(B.Order) do if grade~='fail' then for _,toxic in ipairs({false,true}) do
   local item=B.ItemID(part.id,grade,toxic)
   t.prices[item]=(not force and t.prices[item]) or {buy=math.floor(part.price*2*(toxic and .4 or 1)),sell=math.floor(part.price*(toxic and .4 or 1))}
  end end end end
 end end
end
B.RegisterTrade();hook.Add('InitPostEntity','STB.Trade',B.RegisterTrade)
