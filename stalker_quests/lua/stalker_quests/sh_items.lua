-- Предмет «Посылка» для заданий доставки. Инвентарь загружается раньше заданий, но регистрация повторяется
-- по его хуку готовности (на случай lua_refresh или другого порядка загрузки).
local Q=STALKER_QUESTS
function Q.RegisterItems()
 local S=STALKER_INV;if not S or not S.RegisterItem then return false end
 S.RegisterItem(Q.Config.PackageItem,{name="Посылка",model="models/props_junk/cardboard_box004a.mdl",weight=1,stackable=true,max_stack=5,category="misc",
  icon="stalker_quests/items/quest_package.png",
  description="Запечатанная посылка Связного. Отнесите её адресату — он отмечен на экране и в КПК (вкладка «Задания»). "..
   "Торговцы посылки не покупают; при отказе от задания посылка возвращается отправителю."})
 return true
end
Q.RegisterItems()
hook.Add("STALKER_INV_Ready","STALKER_QUESTS.Items",function() Q.RegisterItems() end)
