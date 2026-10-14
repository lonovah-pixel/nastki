-- API инвентаря для других аддонов: обмен, подсчёт, ремонт, передача между игроками.
local M,check,section=TEST.M,TEST.check,TEST.section
local S=STALKER_INV
check(S.ConditionFactor({durability=100})==1 and S.ConditionFactor({durability=0})==.5,"коэффициент состояния ("..M.Realm..")")
if not SERVER then return end
section("API инвентаря")
local a=TEST.join({nick="Обмен А",pos=Vector(700000,0,0)})
local b=TEST.join({nick="Обмен Б",pos=Vector(700000,200,0)})
a.StalkerInventory.grid={};b.StalkerInventory.grid={}
check(S.GiveItem(a,"scrap",10),"детали выданы")
check(S.CountItem(a,"scrap")==10,"подсчёт предметов")
local ok,err=S.Exchange(a,{scrap=4},{{"ammo_pistol",2}},"Изготовлено")
check(ok and S.CountItem(a,"scrap")==6 and S.CountItem(a,"ammo_pistol")==2,"обмен забирает и выдаёт: "..tostring(err))
local before=table.Copy(a.StalkerInventory.grid)
ok,err=S.Exchange(a,{scrap=50},{{"ammo_pistol",1}})
check(not ok and err and S.CountItem(a,"scrap")==6,"нехватка ингредиентов ничего не меняет: "..tostring(err))
ok=S.Exchange(a,{scrap=1},{{"no_such_item",1}})
check(not ok and S.CountItem(a,"scrap")==6,"ошибка выдачи откатывает обмен")
check(S.GiveItem(a,"zarya",1),"костюм выдан")
local suitUID;for _,it in pairs(a.StalkerInventory.grid) do if it.id=="zarya" then it.durability=30;suitUID=it.uid end end
check(S.RepairItem(a,suitUID,40),"ремонт выполнен")
for _,it in pairs(a.StalkerInventory.grid) do if it.uid==suitUID then check(it.durability==70,"состояние после ремонта: "..it.durability) end end
check(not S.RepairItem(a,"нет такого",10),"ремонт несуществующего предмета отклонён")
local scrapUID;for _,it in pairs(a.StalkerInventory.grid) do if it.id=="scrap" then scrapUID=it.uid end end
check(S.GiveFromTo(a,b,scrapUID,2),"передача части стака")
check(S.CountItem(a,"scrap")==4 and S.CountItem(b,"scrap")==2,"предметы перешли к получателю")
check(S.GiveFromTo(a,b,suitUID),"передача предмета целиком")
local got=false;for _,it in pairs(b.StalkerInventory.grid) do if it.uid==suitUID then got=it.durability==70 end end
check(got,"UID и износ сохраняются при передаче")
local rowA=sql.Query("SELECT payload FROM stalker_inventory WHERE steamid="..sql.SQLStr(a:SteamID64()))
check(rowA and not rowA[1].payload:find(suitUID,1,true),"передача сохранена в SQLite")
M.removePlayer(a);M.removePlayer(b)
