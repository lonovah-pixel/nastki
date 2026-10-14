-- №3: урон аномалий не поглощается очками брони HL2, защищают только характеристики снаряжения.
local M,check,section=TEST.M,TEST.check,TEST.section
if not SERVER then return end
section("Аномалии бьют в обход брони")
local Z=STALKER_ZONE
local a=ents.Create("stalker_anomaly");a:SetKind("electro");a:SetPos(Vector(600000,0,0));a:Spawn()
local p=M.addPlayer({nick="Броня",pos=Vector(600000,0,0)});p._center=24;p:SetArmor(40)
a:Think()
check(p:Health()==100-Z.Anomalies.electro.damage,"«Электра» снимает полный урон: здоровье "..p:Health())
check(p:Armor()==40,"очки брони не тратятся на аномалию")
local dmg=DamageInfo();dmg:SetDamage(50);dmg:SetDamageType(DMG_BULLET);dmg:SetAttacker(M.world)
p:SetHealth(100);p:TakeDamageInfo(dmg)
check(p:Health()==90 and p:Armor()==0,"пуля по-прежнему поглощается бронёй: "..p:Health().."/"..p:Armor())
check(Z.AnomalyVictim==nil,"флаг аномального урона снимается")
-- Ошибка внутри тика не ломает аномалию.
local broken=ents.Create("stalker_anomaly");broken:SetKind("burner");broken:SetPos(Vector(601000,0,0));broken:Spawn()
broken.Tick=function() error("тест") end
local before=#M.warnings
local ok=pcall(broken.Think,broken)
check(ok and #M.warnings==before+1,"ошибка в тике перехвачена и записана один раз")
table.remove(M.warnings)
M.removePlayer(p);a:Remove();broken:Remove()
