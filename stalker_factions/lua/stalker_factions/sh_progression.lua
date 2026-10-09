local F=STFW
-- Очки снабжения не являются деньгами DarkRP. Состояние хранится вместе с картой.
F.Config.SupplyPerTerritory=1
F.Config.SupplyLimit=100000
F.Upgrades={
 logistics={name={ru="Тактика захвата",en="Capture tactics"},description={ru="+10% к скорости захвата за уровень",en="+10% capture speed per level"},costs={10,20,30}},
 infirmary={name={ru="Оснащение базы",en="Base equipment"},description={ru="Минимум 5 / 10 / 15 брони при возрождении на базе",en="At least 5 / 10 / 15 armor on base respawn"},costs={10,20,30}},
 supply={name={ru="Договоры снабжения",en="Supply contracts"},description={ru="−2% к ценовому коэффициенту своих торговцев за уровень, в пределах общего лимита скидки",en="−2% own trader price factor per level, within discount cap"},costs={10,20,30}}
}
function F.UpgradeLevel(world,id,key)
 local d=((world or {}).progression or {})[id]
 local n=d and d.levels and d.levels[key] or 0
 return math.Clamp(tonumber(n) or 0,0,#F.Upgrades[key].costs)
end
function F.TerritoryStatus(point,faction,joined,world)
 if point.contested then return "territory_contested" end
 if not joined then return "territory_join" end
 if point.owner==faction then return point.base and "territory_base" or "territory_owned" end
 if point.owner~="" and F.Relation(faction,point.owner,world)~="war" then return "territory_war" end
 if point.attacker and (point.progress or 0)>0 then return "territory_capturing" end
 return "territory_enter"
end
