-- Ревью крафта и знакомств: состояние цели при передаче предмета и денег (без сознания), досылка данных загрузившемуся
-- клиенту (STALKER_PlayerReady), фразы шёпота и крика на языке сервера, /me знакомого с «вложенным» именем незнакомца,
-- имя владельца костра для незнакомца, место походного костра (сквозь стену, на голове сталкера).
-- Область мира X: 60 000 000…60 400 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local CR,S,C,SI=STALKER_CRAFT,STALKER_SOCIAL,STALKER_CORE,STALKER_INV
local X=60000000

local function lastTo(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end

if SERVER then
 local players={}
 local function join(nick,x,y)
  local p=TEST.join({nick=nick,pos=Vector(X+x,y or 0,0),aim=Vector(X+x+100,y or 0,0)});p.StfwProtected=0;players[#players+1]=p
  p.StalkerInventory.grid={};p.StalkerInventory.quickbar={}
  return p
 end
 local function act(p,tbl)
  if p.StalkerRate then p.StalkerRate["social.act"]=nil end
  local len,vals=packet(tbl);M.netReceive("stalker_social.act",len,p,vals)
 end
 local function notice(p) local d=decode(lastTo("stalker_core.notify",p));return d and d.text or "" end

 section("Ревью знакомств: передача сталкеру без сознания")
 local giver=join("Ревью: даритель",0);local sleeper=join("Ревью: в обмороке",60)
 SI.GiveItem(giver,"scrap",3)
 local uid;for _,it in pairs(giver.StalkerInventory.grid) do if it.id=="scrap" then uid=it.uid end end
 sleeper:SetNW2Float("stem_unconscious_until",CurTime()+60)
 check(C.Unconscious(sleeper),"цель без сознания (выброс)")
 M.netSent={}
 act(giver,{op="item",t=sleeper:EntIndex(),uid=uid,count=1})
 check(SI.CountItem(giver,"scrap")==3 and SI.CountItem(sleeper,"scrap")==0,"предмет не уходит сталкеру без сознания (GiveFromTo состояние не проверяет): "..notice(giver))
 giver._money=1000;local sm=sleeper._money
 act(giver,{op="money",t=sleeper:EntIndex(),amount=100})
 check(giver._money==1000 and sleeper._money==sm,"деньги не уходят сталкеру без сознания")
 sleeper:SetNW2Float("stem_unconscious_until",0)
 act(giver,{op="item",t=sleeper:EntIndex(),uid=uid,count=1})
 check(SI.CountItem(giver,"scrap")==2 and SI.CountItem(sleeper,"scrap")==1,"очнувшемуся предмет передаётся")

 section("Ревью: досылка загрузившемуся клиенту (STALKER_PlayerReady)")
 local slow=join("Ревью: медленный клиент",400)
 M.netSent={}
 hook.Run("STALKER_PlayerReady",slow)
 check(lastTo("stalker_craft.state",slow)~=nil,"счётчики крафта для КПК досылаются по STALKER_PlayerReady (таймер 5 с медленный клиент теряет)")
 local kn=decode(lastTo("stalker_social.known",slow))
 check(kn and type(kn.list)=="table","список знакомых досылается по STALKER_PlayerReady")

 section("Ревью знакомств: фразы шёпота и крика на языке сервера")
 -- DarkRP собирает префикс «(шепчете) Имя» на языке сервера (gmod_language ru в server.cfg), а клиент сверяет
 -- его со своей фразой (gmod_language клиента): сервер должен сообщить свои фразы.
 local oldPhrase=DarkRP.getPhrase
 DarkRP.getPhrase=function(k) return ({whisper="шепчете",yell="кричите"})[k] end
 M.netSent={};S.SendKnown(giver)
 kn=decode(lastTo("stalker_social.known",giver))
 check(kn and type(kn.phrases)=="table" and kn.phrases.whisper=="шепчете" and kn.phrases.yell=="кричите","клиенту отправлены фразы шёпота и крика сервера")
 DarkRP.getPhrase=oldPhrase

 section("Ревью крафта: место походного костра")
 local placer=join("Ревью: костровой",1000);local sid=placer:SteamID64()
 local trace=util.TraceLine
 local function clearFires() for _,e in ipairs(CR.TempFires(sid)) do e:Remove() end end
 -- Стена (плоскость x=X+1020) перед игроком: взгляд упирается в неё, запасная точка «на 48 units вперёд» — за ней.
 local wall=X+1020
 util.TraceLine=function(t)
  local s,e=t.start,t.endpos
  if s.z>0 and e.z>0 and (s.x-wall)*(e.x-wall)<0 then
   local f=(wall-s.x)/(e.x-s.x)
   return {Hit=true,HitWorld=true,HitSky=false,StartSolid=false,Fraction=f,HitPos=s+(e-s)*f,HitNormal=Vector(-1,0,0),Entity=game.GetWorld()}
  end
  return trace(t)
 end
 placer._aim=Vector(X+1100,0,64)
 local ok,err=CR.PlaceCampfire(placer)
 local fire=CR.TempFires(sid)[1]
 check(not ok and not IsValid(fire),"костёр не разжечь за стеной (запасная точка без прямой видимости): "..tostring(err))
 util.TraceLine=trace;clearFires()
 -- Взгляд на макушку соседа: MASK_SOLID ловит хитбокс игрока, нормаль вверх — костёр повис бы на голове.
 local victim=join("Ревью: сосед",1100)
 util.TraceLine=function(t)
  if t.mask==MASK_SOLID and t.start:DistToSqr(placer:EyePos())<1 then
   return {Hit=true,HitWorld=false,HitSky=false,StartSolid=false,Fraction=.5,HitPos=victim:GetPos()+Vector(0,0,72),HitNormal=Vector(0,0,1),Entity=victim}
  end
  return trace(t)
 end
 placer._aim=Vector(X+1100,0,72)
 ok,err=CR.PlaceCampfire(placer)
 util.TraceLine=trace
 fire=CR.TempFires(sid)[1]
 check(not (IsValid(fire) and fire:GetPos().z>1),"костёр не ставится на сталкера (только на землю): "..tostring(IsValid(fire) and fire:GetPos().z or err))
 clearFires()
 -- Обычный случай не сломан: земля под прицелом.
 placer._aim=Vector(X+1100,0,0)
 ok,err=CR.PlaceCampfire(placer);fire=CR.TempFires(sid)[1]
 check(ok and IsValid(fire) and math.abs(fire:GetPos().x-(X+1100))<1,"костёр на земле под прицелом: "..tostring(err))
 clearFires()

 for _,p in ipairs(players) do CR.Jobs[p]=nil;S.ClearPose(p,"cleanup");M.removePlayer(p) end
else
 local me=LocalPlayer();local oldPos=me:GetPos();me:SetPos(Vector(X,0,0))
 local savedKnown,hide=S.MyKnown,S.Config.HideNames
 S.Config.HideNames=true;S.MyKnown={}
 local said={};local oldAdd=chat.AddNonParsedText
 chat.AddNonParsedText=function(...) local o={};for _,x in ipairs({...}) do if type(x)=="string" then o[#o+1]=x end end;said[#said+1]=table.concat(o) end
 local col=Color(255,255,255)

 section("Ревью знакомств: шёпот и крик при другом языке клиента")
 local stranger=M.addPlayer({nick="Иван",pos=Vector(X+60,0,0)})
 local friend=M.addPlayer({nick="Иван Петров",pos=Vector(X+40,30,0)})
 local l,v=packet({list={{sid=friend:SteamID64(),name="Иван Петров",at=os.time()}},phrases={whisper="шепчете",yell="кричите"}})
 M.protect("список знакомых с фразами сервера",M.netReceive,"stalker_social.known",l,nil,v)
 check(S.Knows(me,friend) and not S.Knows(me,stranger),"клиент знает свой список")
 local oldPhrase=DarkRP.getPhrase
 DarkRP.getPhrase=function(k) return ({whisper="whisper",yell="yell"})[k] end
 local r=hook.Run("OnPlayerChat",stranger,"тсс",false,false,"(шепчете) Иван",col,col)
 check(r==true and said[#said]=="(шепчете) Незнакомец: тсс","шёпот незнакомца скрыт и у клиента с английским языком: "..tostring(said[#said]))
 r=hook.Run("OnPlayerChat",stranger,"стой",false,false,"(yell) Иван",col,col)
 check(r==true and said[#said]=="(yell) Незнакомец: стой","крик на языке клиента тоже скрыт")
 check(hook.Run("OnPlayerChat",stranger,"всем",false,false,"(OOC) Иван",col,col)==nil,"OOC по-прежнему не трогаем")
 DarkRP.getPhrase=oldPhrase

 section("Ревью знакомств: /me знакомого, чьё имя начинается с имени незнакомца")
 local n=#said
 r=hook.Run("ChatText","0","Иван Петров кивает","Иван Петров кивает","darkrp")
 check(r==nil and #said==n,"/me знакомого «Иван Петров» не приписан незнакомцу «Иван»: "..tostring(said[#said]))
 r=hook.Run("ChatText","0","Иван машет","Иван машет","darkrp")
 check(r==true and said[#said]=="Незнакомец машет","/me незнакомца скрыт")

 section("Ревью крафта: имя владельца костра для незнакомца")
 local sid="76561198000959595"
 local fire=ents.Create("stalker_campfire");fire:SetPos(Vector(X,100,0));fire:Spawn()
 fire:SetExpires(CurTime()+300);fire:SetOwnerName("Тайный Повар");fire:SetOwnerSID(sid)
 local text=CR.HintFor(fire) or ""
 check(text:find("готовить",1,true) and not text:find("Тайный Повар",1,true) and text:find("Незнакомец",1,true),"незнакомец не видит имя владельца костра: "..text)
 S.MyKnown[sid]={name="Тайный Повар",at=0}
 check((CR.HintFor(fire) or ""):find("Тайный Повар",1,true),"знакомый видит имя владельца")
 S.MyKnown[sid]=nil
 local owner=M.addPlayer({nick="Тайный Повар",sid=sid,pos=Vector(X,140,0)})
 text=CR.HintFor(fire) or ""
 check(not text:find("Тайный Повар",1,true) and text:find("Незнакомец",1,true),"владелец в сети — подпись STALKER Social: "..text)
 fire:SetOwnerSID(me:SteamID64());fire:SetOwnerName(me:Nick())
 check((CR.HintFor(fire) or ""):find(me:Nick(),1,true),"свой костёр — своё имя")
 fire:Remove()

 chat.AddNonParsedText=oldAdd
 S.MyKnown,S.Config.HideNames=savedKnown,hide
 for _,p in ipairs({stranger,friend,owner}) do M.removePlayer(p) end
 me:SetPos(oldPos)
end
