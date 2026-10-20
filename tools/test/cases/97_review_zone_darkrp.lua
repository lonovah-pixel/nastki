-- Ревью Зоны и DarkRP: наводка из сумки при неудачной выдаче, профессия группировки после переподключения,
-- запас патронов при смене профессии, голод в обход брони, сумка при лимите сущностей, «Воронка» с малым
-- радиусом затягивания, shared-настройки для памятки и энциклопедии, одна копия кадра для искажения аномалий.
-- Область мира: X 80 000 000…80 400 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local Z,S,ST=STALKER_ZONE,STALKER_INV,STALKER_SETTINGS
local X=80000000
local ROOT=os.getenv("GMOD_ROOT")

section("Ревью Зоны и DarkRP ("..M.Realm..")")
-- Значения, которые клиент показывает в памятке, справочнике «Зона» и энциклопедии КПК, должны приходить с сервера.
for _,id in ipairs({"zone.death_bag_lifetime","zone.survival_respawn","zone.artifact_refresh","zone.anomaly.springboard.force"}) do
 check(ST.Defs[id] and ST.Defs[id].realm=="shared","клиенту нужно — shared: "..id)
end

if SERVER then
 section("Ревью: shared-настройка рассылается клиентам")
 M.netSent={}
 check(ST.Set("zone.death_bag_lifetime",1200),"срок сумки меняется")
 local synced=false
 for _,s in ipairs(M.netSent) do
  if s.name=="stalker_settings.sync" then
   local d=util.JSONToTable(util.Decompress(s.data[2]) or "")
   if d and d.values and d.values["zone.death_bag_lifetime"]==1200 then synced=true end
  end
 end
 check(synced,"новый срок сумки ушёл клиентам (памятка «… лежит N мин.»)")
 ST.Set("zone.death_bag_lifetime",nil)

 section("Ревью: снимок редактора — только при праве zone")
 local boss=TEST.join({nick="Ревью комендант",pos=Vector(X+15000,0,0),superadmin=true})
 local exadmin=TEST.join({nick="Ревью бывший админ",pos=Vector(X+15100,0,0),superadmin=true})
 M.netReceive("stz.request",1,exadmin,{true})
 check(exadmin.StzEditing==true,"редактор открыт с правом zone")
 -- Право отозвали (ULX/«Комендант»), а окно редактора у игрока всё ещё открыто.
 exadmin._super=false
 M.netSent={}
 local raw=util.TableToJSON({op="artifacts",kind="field"})
 M.netReceive("stz.action",16+#raw*8,boss,{#raw,raw})
 local leaked,toBoss=false,false
 for _,s in ipairs(M.netSent) do if s.name=="stz.state" then if s.to==exadmin then leaked=true elseif s.to==boss then toBoss=true end end end
 check(toBoss,"действовавший администратор получил снимок")
 check(not leaked,"без права zone снимок Зоны (названия, координаты, ошибки) больше не приходит")
 M.removePlayer(boss);M.removePlayer(exadmin)

 section("Ревью: записи КПК остаются в сумке, если наводку не выдали")
 local giveOrig=S.GiveStashIntel
 local looter=TEST.join({nick="Ревью мародёр",pos=Vector(X,0,0)})
 local function intelBag(intel)
  local bag=ents.Create("stalker_deathbag");bag.Items={};bag.StashIntel=intel
  bag:SetPos(looter:GetPos());bag:Spawn();bag:SetHasIntel(true)
  return bag
 end
 local plant={owner="76561198000097001",ownerName="Ревью хозяин",stash="s97"}
 -- Бот, ошибка записи наводки: GiveStashIntel → false, причина (stalker_inv/sv_intel.lua).
 S.GiveStashIntel=function() return false,"Ошибка сохранения наводки" end
 local bag=intelBag(plant)
 Z.LootBag(looter,bag)
 check(IsValid(bag) and bag.StashIntel==plant and bag:GetHasIntel()==true,"неудачная выдача: наводка не пропала, сумка лежит")
 check(tostring(looter._chat[#looter._chat]):find("не прочитаны",1,true),"обыскавшему сказано, что записи не прочитаны: "..tostring(looter._chat[#looter._chat]))
 local got
 S.GiveStashIntel=function(p,intel) got={p=p,intel=intel};return true,"id97" end
 Z.LootBag(looter,bag)
 check(got and got.p==looter and got.intel==plant,"повторный обыск выдал ту же наводку")
 check(not IsValid(bag),"после выдачи пустая сумка убрана")
 -- Свой тайник: записи бесполезны, сумка не должна висеть с ними до конца срока.
 S.GiveStashIntel=function() return false,"Это координаты вашего собственного тайника" end
 bag=intelBag({owner=looter:SteamID64(),ownerName=looter:Nick(),stash="own"})
 Z.LootBag(looter,bag)
 check(not IsValid(bag),"свой тайник: записи израсходованы, сумка убрана")
 S.GiveStashIntel=giveOrig

 section("Ревью: сумка при исчерпании лимита сущностей")
 local victim=TEST.join({nick="Ревью без сумки",pos=Vector(X+3000,0,0)})
 check(S.GiveItem(victim,"medkit_army",2),"вещи выданы")
 local realCreate=ents.Create
 ents.Create=function(class) if class=="stalker_deathbag" then return NULL end;return realCreate(class) end
 M.kill(victim)
 ents.Create=realCreate
 check(TEST.gridCount(victim,"medkit_army")==2,"сумку не создать — вещи остались у игрока, а не пропали: "..TEST.gridCount(victim,"medkit_army"))
 M.spawn(victim)

 section("Ревью: голод отнимает здоровье, а не броню костюма")
 local hungry=TEST.join({nick="Ревью голодный",pos=Vector(X+6000,0,0)})
 hungry.StalkerInventory.hunger=0;hungry:SetArmor(50);hungry:SetHealth(100)
 local ticks=0
 hook.Add("EntityTakeDamage","zzz.test97.starve",function(ent,dmg) if ent==hungry and dmg:GetDamageType()==DMG_GENERIC and dmg:GetAttacker()==game.GetWorld() then ticks=ticks+1 end end)
 local cfg=Z.Config.Survival
 M.advance(cfg.Tick+1,.5)
 hook.Remove("EntityTakeDamage","zzz.test97.starve")
 check(ticks>=1,"голод нанёс урон: тактов "..ticks)
 check(hungry:Armor()==50,"очки брони не тратятся на голод: "..hungry:Armor())
 check(math.abs(hungry:Health()-(100-ticks*cfg.Damage))<1e-6,"голод снимает полный урон: здоровье "..hungry:Health())
 check(Z.AnomalyVictim==nil,"флаг урона в обход брони снят")
 hungry.StalkerInventory.hunger=100

 section("Ревью: «Воронка» с затягиванием меньше радиуса")
 local vcfg=Z.Anomalies.vortex;local savedR,savedPull=vcfg.radius,vcfg.pull
 -- Допустимо настройками: радиус до 600, затягивание от 40 (sh_settings.lua).
 vcfg.radius,vcfg.pull=300,100
 local vortex=ents.Create("stalker_anomaly");vortex:SetKind("vortex");vortex:SetPos(Vector(X+9000,0,0));vortex:Spawn()
 local walker=M.addPlayer({nick="Ревью у воронки",pos=Vector(X+9200,0,0)})
 vortex:Think()
 check(walker:Health()<100,"сталкер в радиусе срабатывания получает урон: здоровье "..walker:Health())
 vcfg.radius,vcfg.pull=savedR,savedPull
 vortex:Remove();M.removePlayer(walker)

 section("Ревью: смена профессии не обнуляет запас патронов")
 -- DarkRP changeTeam (gamemode/modules/jobs/sv_jobs.lua:149-157): при norespawn и keepPickedUp=false —
 -- StripWeapons() и RemoveAllAmmo(). stalker_jobs меняет профессию сам при вступлении и выходе из группировки.
 local env=setmetatable({GM={Config={}}},{__index=_G})
 local fn=assert(loadfile(ROOT.."/darkrpmodification/lua/darkrp_config/settings.lua"));setfenv(fn,env);fn()
 local rp=env.GM.Config
 check(rp.norespawn==true,"профессия меняется без возрождения (norespawn)")
 local jobsSrc=io.open(ROOT.."/darkrpmodification/lua/darkrp_customthings/jobs.lua"):read("*a")
 check(not jobsSrc:find('weapons%s*=%s*{%s*"'),"у профессий сборки нет оружия — снимать при смене нечего")
 local gunner=M.addPlayer({nick="Ревью стрелок",pos=Vector(X+12000,0,0)});gunner:GiveAmmo(90,"SMG1")
 if rp.norespawn and gunner:Alive() then
  if rp.keepPickedUp then for _,w in ipairs({}) do gunner:StripWeapon(w) end
  else gunner:StripWeapons();gunner:RemoveAllAmmo() end
 end
 check(gunner:GetAmmoCount("SMG1")==90,"после вступления в группировку патроны на месте: "..gunner:GetAmmoCount("SMG1"))
 M.removePlayer(gunner)

 section("Ревью: сон DarkRP (/sleep, /wake)")
 local envD=setmetatable({DarkRP={disabledDefaults={}}},{__index=_G})
 local fd=assert(loadfile(ROOT.."/darkrpmodification/lua/darkrp_config/disabled_defaults.lua"));setfenv(fd,envD);fd()
 local sleepOn=not (envD.DarkRP.disabledDefaults.modules and envD.DarkRP.disabledDefaults.modules.sleep)
 if sleepOn then
  -- Как в DarkRP (gamemode/modules/sleep/sv_sleep.lua): /sleep запоминает и снимает оружие (136-162), /wake —
  -- player:Spawn() живого игрока, возврат здоровья и брони, снова StripWeapons и Give запомненных классов (63-90).
  local sleeper=TEST.join({nick="Ревью соня",pos=Vector(X+18000,0,0)})
  local inv=table.Copy(sleeper.StalkerInventory);inv.equipment.pistol=S.NewItem("pistol",1);inv.equipment.armor=S.NewItem("zarya",1)
  S.Commit(sleeper,inv);M.advance(.5)
  sleeper.StalkerInventory.hunger=0
  local hp,armor=sleeper:Health(),sleeper:Armor()
  local classes={};for _,w in ipairs(sleeper:GetWeapons()) do classes[#classes+1]=w:GetClass() end
  sleeper:StripWeapons()
  M.spawn(sleeper);sleeper:SetHealth(hp);sleeper:SetArmor(armor);sleeper:StripWeapons()
  for _,c in ipairs(classes) do sleeper:Give(c) end
  M.advance(1)
  check(sleeper:Armor()==armor,"после /wake броня костюма не удвоена: "..armor.." → "..sleeper:Armor())
  local wep=sleeper:GetWeapon("weapon_pistol")
  check(IsValid(wep) and wep.StalkerManaged,"после /wake пистолет — оружие инвентаря (иначе /drop создаёт копию)")
  check(sleeper.StalkerInventory.hunger==0,"сон не утоляет голод: "..tostring(sleeper.StalkerInventory.hunger))
  M.removePlayer(sleeper)
 end
 check(not sleepOn,"модуль сна DarkRP отключён (disabled_defaults.lua)")

 section("Ревью: профессия группировки после переподключения")
 local saved={teams=RPExtraTeams,default=GAMEMODE.DefaultTeam,notify=DarkRP.notify}
 RPExtraTeams={[1]={name="Сталкер"},[2]={name="Боец «Долга»",stalkerFaction="duty",max=0}}
 GAMEMODE.DefaultTeam=1;DarkRP.notify=function() end
 -- Игроки других сценариев — мок без changeTeam: модуль их не трогает.
 local others={};for _,p in ipairs(player.GetAll()) do if not p.StalkerJobRestored then others[#others+1]=p;p.StalkerJobRestored=true end end
 M.loadFile(ROOT.."/darkrpmodification/lua/darkrp_modules/stalker_jobs/sv_jobs.lua","stalker_jobs/sv_jobs.lua")
 local function rpPlayer(nick,x)
  local p=M.addPlayer({nick=nick,pos=Vector(X+x,5000,0)})
  p.changeTeam=function(self,t,force)
   local allow=hook.Call("playerCanChangeTeam",nil,self,t,force)
   if allow==false then return false end
   self._team=t;return true
  end
  return p
 end
 local function member(p,f) p:SetNW2Bool("stfw_joined",f~=nil);p:SetNW2String("stfw_faction",f or "loner") end
 -- DarkRP ставит вошедшему профессию по умолчанию (sv_gamemode_functions.lua:679), профиль группировки уже есть.
 local back=rpPlayer("Ревью вернулся",100);member(back,"duty")
 local loner=rpPlayer("Ревью одиночка",200)
 M.advance(5.5,.5)
 check(back:Team()==2,"член «Долга» после входа снова в профессии группировки: "..back:Team())
 check(loner:Team()==1,"одиночка остаётся «Сталкером»")
 back._team=1;M.advance(5.5,.5)
 check(back:Team()==1,"понижение или решение администрации повторно не отменяется")
 local late=rpPlayer("Ревью поздний профиль",300)
 M.advance(5.5,.5);check(late:Team()==1,"профиль ещё не загружен — профессия по умолчанию")
 member(late,"duty");M.advance(5.5,.5)
 check(late:Team()==2,"профиль загрузился позже — профессия выдана")
 hook.Remove("playerCanChangeTeam","STALKER.Jobs.NoManual");hook.Remove("STFW_FactionChanged","STALKER.Jobs.AutoJoin")
 hook.Remove("STFW_FactionLeft","STALKER.Jobs.Left");timer.Remove("STALKER.Jobs.Membership")
 RPExtraTeams=saved.teams;GAMEMODE.DefaultTeam=saved.default;DarkRP.notify=saved.notify
 for _,p in ipairs(others) do p.StalkerJobRestored=nil end
 for _,p in ipairs({back,loner,late,looter,victim,hungry}) do M.removePlayer(p) end
end

if CLIENT then
 section("Ревью: памятка видит срок сумки с сервера")
 ST.Apply("zone.death_bag_lifetime",1200)
 local text=""
 for _,b in ipairs(Z.GuideBlocks()) do if type(b)=="string" then text=text..b.."\n" end end
 check(text:find("20 мин",1,true),"справочник «Зона»: сумка лежит 20 мин.")
 ST.Apply("zone.death_bag_lifetime",600)

 section("Ревью: искажение аномалий — одна копия кадра")
 local copies,sprites=0,0
 render.UpdateRefractTexture=function() copies=copies+1 end
 render.DrawSprite=function() sprites=sprites+1 end
 local list={}
 for i,kind in ipairs({"electro","burner","vortex","acid"}) do
  local a=ents.Create("stalker_anomaly");a:SetKind(kind);a:SetPos(Vector(X+i*300,0,0));a:Spawn();list[#list+1]=a
 end
 M.advance(.1)
 for _,a in ipairs(list) do M.protect("refract draw",a.DrawTranslucent,a) end
 check(copies==1,"четыре аномалии в кадре — одна копия кадра: "..copies)
 check(sprites>=#list,"искажение нарисовано у каждой аномалии: "..sprites)
 M.advance(.1)
 for _,a in ipairs(list) do M.protect("refract draw 2",a.DrawTranslucent,a) end
 check(copies==2,"следующий кадр — новая копия: "..copies)
 render.UpdateRefractTexture=nil;render.DrawSprite=nil
 for _,a in ipairs(list) do a:Remove() end
end
