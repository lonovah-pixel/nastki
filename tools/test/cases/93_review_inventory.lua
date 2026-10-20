-- Ревью инвентаря: оружие инвентаря и DarkRP /drop (дубликат), действия в обмороке, досылка наводок и уведомления
-- владельцу загрузившемуся клиенту (STALKER_PlayerReady), износ костюма, снятого до применения износа, S.FitText без utf8.sub.
-- Область мира: X 40 000 000…40 400 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local S=STALKER_INV
local X=40000000

local function lastTo(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function notices(p,pattern)
 local n=0
 for _,s in ipairs(M.netSent or {}) do
  if s.name=="stalker_core.notify" and s.to==p then local d=decode(s);if d and tostring(d.text):find(pattern,1,true) then n=n+1 end end
 end
 return n
end
local function countSub(fn,...)
 local real,n=utf8.sub,0
 utf8.sub=function(...) n=n+1;return real(...) end
 local ok,a=pcall(fn,...)
 utf8.sub=real
 return n,ok,a
end

section("Ревью инвентаря ("..M.Realm..")")
if SERVER then
 local function slotOf(id) for i,e in ipairs(S.Config.Equipment) do if e.id==id then return i end end end
 -- Пакет действия как у S.SendAction: ревизия, ячейка (зона 2 бита + индекс 6 бит), UID, [ячейка назначения].
 local ZONE={grid=1,equipment=2,quickbar=3}
 local function act(p,action,zone,index,to,ti)
  local inv=p.StalkerInventory;local item=S.GetAt(inv,zone,index)
  local uid=item and item.uid or "x"
  local values={inv.revision,ZONE[zone],zone=="equipment" and slotOf(index) or index,uid}
  local len=32+2+6+(#uid+1)*8
  if to then values[#values+1]=ZONE[to];values[#values+1]=to=="equipment" and slotOf(ti) or ti;len=len+8 end
  return M.netReceive("stalker_inv."..action,len,p,values)
 end

 section("Ревью: оружие инвентаря и DarkRP /drop")
 local a=TEST.join({nick="Ревью оружейник",pos=Vector(X,0,0)})
 local inv=table.Copy(a.StalkerInventory);inv.grid={};inv.equipment={pistol=S.NewItem("pistol",1)};S.Commit(a,inv)
 local uid=a.StalkerInventory.equipment.pistol.uid
 local wep=a.StalkerWeapons and a.StalkerWeapons[uid]
 check(IsValid(wep) and wep.StalkerManaged,"пистолет из инвентаря выдан в руки")
 -- Как в DarkRP: /drop (entities/weapons/weapon_cs_base2/sv_commands.lua:57-77) и GM:DoPlayerDeath спрашивают canDropWeapon;
 -- GM:canDropWeapon (gamemode/modules/base/sv_gamemode_functions.lua:67) для weapon_pistol даёт true — его нет в DisallowDrop,
 -- restrictdrop=false. Затем dropDRPWeapon создаёт spawned_weapon, а предмет остаётся надетым и выдаётся снова — дубликат.
 local function darkrpCanDrop(p,w) local can=hook.Call("canDropWeapon",GAMEMODE,p,w);if can==nil then can=true end;return can end
 check(darkrpCanDrop(a,wep)==false,"/drop и смерть не создают spawned_weapon из оружия инвентаря")
 local crowbar=a:Give("weapon_crowbar")
 check(darkrpCanDrop(a,crowbar)==true and darkrpCanDrop(a,NULL)==true,"обычное оружие DarkRP выбрасывается как раньше")
 -- Вступление в группировку: stalker_jobs → ply:changeTeam(t,true); при norespawn=true DarkRP после OnPlayerChangedTeam
 -- делает StripWeapons и PlayerLoadout (gamemode/modules/jobs/sv_jobs.lua:145-163) — оружие инвентаря пропадало из рук.
 wep:SetClip1(5)
 hook.Call("OnPlayerChangedTeam",GAMEMODE,a,a:Team(),a:Team());a:StripWeapons();M.advance(.5)
 local again=a.StalkerWeapons and a.StalkerWeapons[uid]
 check(IsValid(again) and again~=wep and again:Clip1()==5,"после смены профессии оружие инвентаря снова в руках, магазин сохранён")

 section("Ревью: инвентарь в обмороке")
 local b=TEST.join({nick="Ревью без сознания",pos=Vector(X+300,0,0)})
 local binv=table.Copy(b.StalkerInventory);binv.grid={[1]=S.NewItem("medkit",3)};binv.equipment={};binv.quickbar={[1]=binv.grid[1].uid};S.Commit(b,binv)
 b:SetHealth(40)
 b:SetNW2Float("stem_unconscious_until",CurTime()+30)
 check(S.IsUnconscious(b),"игрок без сознания (выброс)")
 local drops=TEST.count("stalker_inv_drop")
 b.StalkerNet=nil;act(b,"use","quickbar",1)
 check(b:Health()==40 and TEST.gridCount(b,"medkit")==3,"ALT+1 в обмороке: аптечка не лечит и не тратится")
 b.StalkerNet=nil;act(b,"drop","grid",1)
 check(TEST.count("stalker_inv_drop")==drops and TEST.gridCount(b,"medkit")==3,"в обмороке предмет не выбрасывается")
 b:SetNW2Float("stem_unconscious_until",0)
 b.StalkerNet=nil;act(b,"use","quickbar",1)
 check(b:Health()==75 and TEST.gridCount(b,"medkit")==2,"очнувшийся игрок пользуется аптечкой")

 section("Ревью: износ костюма, снятого до применения")
 local w=TEST.join({nick="Ревью броня",pos=Vector(X+600,0,0)})
 local winv=table.Copy(w.StalkerInventory);winv.grid={};winv.equipment={armor=S.NewItem("jacket",1)};winv.quickbar={};S.Commit(w,winv)
 local suit=w.StalkerInventory.equipment.armor.uid
 check(S.WearEquipment(w,"armor",6.5),"износ костюма в очереди")
 -- Костюм сразу снят в рюкзак — раньше накопленный износ просто выбрасывался (снять/надеть — и износа нет).
 w.StalkerNet=nil;act(w,"move","equipment","armor","grid",1)
 M.advance(S.Config.ArmorWearInterval+.5)
 local moved=w.StalkerInventory.grid[1]
 check(moved and moved.uid==suit and moved.durability==94,"износ применён к снятому костюму: "..tostring(moved and moved.durability))
 local saved=S.LoadInventoryBySID(w:SteamID64())
 check(saved and saved.grid[1] and saved.grid[1].durability==94,"износ снятого костюма сохранён")

 section("Ревью: наводки — досылка загрузившемуся клиенту")
 local Q=sql.SQLStr
 local holderSID,ownerSID,owner2SID="76561198093000001","76561198093000002","76561198093000003"
 sql.Query("DELETE FROM stalker_stash_intel WHERE holder="..Q(holderSID))
 local h=TEST.join({nick="Ревью держатель",sid=holderSID,pos=Vector(X+900,0,0)})
 local function intel(owner,stash) return {owner=owner,ownerName="Ревью хозяин",stash=stash,map=game.GetMap(),pos={x=1,y=2,z=3},expires=os.time()+3600} end
 local ok1,id1=S.GiveStashIntel(h,intel(ownerSID,"rv_stash_1"))
 local ok2,id2=S.GiveStashIntel(h,intel(owner2SID,"rv_stash_2"))
 check(ok1 and ok2,"наводки выданы держателю (владельцы вне сети)")
 hook.Run("PlayerDisconnected",h);M.removePlayer(h)
 -- Медленный клиент: всё, что ушло по таймерам входа до загрузки Lua, потеряно.
 h=TEST.join({nick="Ревью держатель",sid=holderSID,pos=Vector(X+900,0,0)})
 M.netSent={}
 hook.Run("STALKER_PlayerReady",h)
 local list=decode(lastTo("stalker_stash.intel",h))
 check(list and type(list.list)=="table" and #list.list==2,"загрузившемуся клиенту дослан список наводок: "..tostring(list and list.list and #list.list))
 -- Владелец с медленным клиентом: уведомление по таймеру (8 с) ушло в пустоту, notified=1 — повторить при загрузке.
 local o=TEST.join({nick="Ревью хозяин",sid=ownerSID,pos=Vector(X+1200,0,0)});M.advance(6)
 check(sql.QueryValue("SELECT notified FROM stalker_stash_intel WHERE id="..Q(id1))=="1","владелец отмечен уведомлённым (таймер входа)")
 M.netSent={}
 hook.Run("STALKER_PlayerReady",o)
 check(notices(o,"рассекречен")==1,"уведомление о рассекреченном тайнике повторено загрузившемуся клиенту")
 M.netSent={};hook.Run("STALKER_PlayerReady",o)
 check(notices(o,"рассекречен")==0,"повторная загрузка не дублирует уведомление")
 -- Быстрый клиент: загрузился раньше таймера — уведомление сразу и только одно.
 local o2=M.addPlayer({nick="Ревью быстрый",sid=owner2SID,pos=Vector(X+1500,0,0)})
 hook.Run("PlayerInitialSpawn",o2);M.spawn(o2);M.advance(1)
 M.netSent={}
 hook.Run("STALKER_PlayerReady",o2)
 check(notices(o2,"рассекречен")==1,"быстрый клиент: уведомление сразу после загрузки")
 M.advance(9)
 check(notices(o2,"рассекречен")==1,"таймер входа не дублирует уведомление")
 check(sql.QueryValue("SELECT notified FROM stalker_stash_intel WHERE id="..Q(id2))=="1","отметка notified сохранена")
 sql.Query("DELETE FROM stalker_stash_intel WHERE holder="..Q(holderSID))
 for _,p in ipairs({a,b,w,h,o,o2}) do if IsValid(p) then hook.Run("PlayerDisconnected",p);M.removePlayer(p) end end
else
 section("Ревью: S.FitText без квадратичного utf8.sub")
 local realSize,calls=surface.GetTextSize,0
 surface.GetTextSize=function(s) calls=calls+1;return utf8.len(s)*7,10 end
 local function reference(text,width)
  if utf8.len(text)*7<=width then return text end
  local chars={};for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars+1]=ch end
  for i=#chars,1,-1 do local s=table.concat(chars,"",1,i).."…";if utf8.len(s)*7<=width then return s end end
  return "…"
 end
 -- Длинное имя в заголовке окна чужого тайника / сводке рисуется каждый кадр.
 local text="ТАЙНИК: "..string.rep("Сталкер ",25)
 local n,ok,res=countSub(S.FitText,text,"SI.Title",150)
 local fitCalls=calls
 check(ok and res==reference(text,150),"S.FitText обрезает как раньше: "..tostring(res))
 check(n==0,"S.FitText не зовёт utf8.sub (O(n²) в GMod, в Paint — каждый кадр): вызовов "..n)
 check(fitCalls<=12,"S.FitText измеряет текст O(log n) раз: "..fitCalls)
 check(S.FitText("Коротко","SI.Small",1000)=="Коротко" and S.FitText(text,"SI.Small",3)=="…" and S.FitText("abcdef","SI.Small",30)==reference("abcdef",30),
  "короткий текст без изменений, узкое поле — многоточие")
 surface.GetTextSize=realSize
end
