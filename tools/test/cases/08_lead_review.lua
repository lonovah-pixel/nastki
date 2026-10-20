-- Правки ведущего по итогам ревью: предел распаковки пакетов игрока, мут «Коменданта» в КПК, type() как в GMod.
local M,check,section=TEST.M,TEST.check,TEST.section
local C=STALKER_CORE
section("Ревью: общие правки ("..M.Realm..")")
check(type(Vector(1,2,3))=="Vector" and type(Angle())=="Angle" and not istable(Vector()),"мок: type() у Vector и Angle как в GMod")
local back=util.JSONToTable(util.TableToJSON({p=Vector(1,2,3)}))
check(back and type(back.p)=="Vector" and back.p.y==2,"мок: JSON возвращает Vector, как util.JSONToTable GMod")
if SERVER then
 -- Пакет игрока в 600 байт распаковывается не больше чем в 64×600 байт.
 local realDec=util.Decompress;local asked
 util.Decompress=function(s,max) asked=max;return realDec(s) end
 local data=C.Pack({op="x"})
 M.netRead={#data,data};C.Read(16+#data*8,600)
 util.Decompress=realDec;M.netRead=nil
 check(asked==600*64,"предел распаковки пакета игрока зависит от его размера: "..tostring(asked))
 -- Мут «Коменданта» действует и на личные сообщения КПК.
 local A,P=STALKER_ADMIN,STALKER_PDA
 if A and A.SetSanction and P and P.SendMessage then
  local a=M.addPlayer({nick="Мут КПК",pos=Vector(-950000,0,0)});local b=M.addPlayer({nick="Адресат мута",pos=Vector(-950000,200,0)})
  M.spawn(a);M.spawn(b)
  A.SetSanction(a,"mute",10)
  local ok,err=P.SendMessage(a,b:SteamID64(),"привет")
  check(not ok and tostring(err):find("запрещено",1,true),"мут «Коменданта» запрещает сообщения КПК: "..tostring(err))
  A.SetSanction(a,"mute",-1)
  M.removePlayer(a);M.removePlayer(b)
 end
end

-- Смена профессии DarkRP без возрождения (вступление в группировку, выход, восстановление профессии при входе):
-- после OnPlayerChangedTeam DarkRP вызывает applyPlayerClassVars, а он всегда ставит броню StartArmor (sv_util.lua:202).
if SERVER and STALKER_INV then
 local S=STALKER_INV
 section("Ревью: броня костюма после смены профессии")
 local p=TEST.join({nick="Броня и профессия",pos=Vector(-960000,0,0)})
 local inv=table.Copy(p.StalkerInventory);inv.grid={};inv.equipment={armor=S.NewItem("jacket",1)};inv.quickbar={};S.Commit(p,inv)
 M.advance(.2)
 local full=p:Armor()
 check(full>0,"костюм даёт броню: "..full)
 hook.Call("OnPlayerChangedTeam",GAMEMODE,p,p:Team(),p:Team());p:SetArmor(0);M.advance(.5)
 check(p:Armor()==full,"после смены профессии броня костюма вернулась: "..p:Armor().." из "..full)
 S.CaptureEquipment(p)
 check((p.StalkerInventory.equipment.armor.armor or 0)>0,"очки брони костюма не обнулились в сохранении")
 M.removePlayer(p)
end
