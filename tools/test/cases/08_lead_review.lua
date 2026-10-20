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
