-- ULX подхватывает этот файл сам (ulx/modules/sh/*.lua из всех аддонов, на сервере и у клиентов).
-- Команды категории «STALKER» в меню ULX/XGUI. Каждая идёт через STALKER_ADMIN.Execute: те же права
-- "stalker_<право>", допуски по рангу, проверки и журнал, что и в панели «Комендант».
if type(ulx)~="table" or type(ulx.command)~="function" or type(ULib)~="table" or type(ULib.cmds)~="table" then return end
local CATEGORY="STALKER"
local A=STALKER_ADMIN
if A and A.RegisterPrivileges then A.RegisterPrivileges() end

-- Подсказки автодополнения: таблицы заполняются заново, ссылки на них уже переданы ULib.
local items,factions,events={},{},{}
local function refill()
 for k in pairs(items) do items[k]=nil end;for k in pairs(factions) do factions[k]=nil end;for k in pairs(events) do events[k]=nil end
 if STALKER_INV and STALKER_INV.Items then for id in pairs(STALKER_INV.Items) do items[#items+1]=id end;table.sort(items) end
 if STFW and STFW.Factions then for id,f in pairs(STFW.Factions) do if f.playable then factions[#factions+1]=id end end;table.sort(factions) end
 local Adm=STALKER_ADMIN
 if SERVER and Adm and Adm.EventList then for _,e in ipairs(Adm.EventList()) do events[#events+1]=e.id end end
end
refill()
hook.Add("InitPostEntity","STALKER.AdminULXCompletes",refill)

local function say(ply,text,bad)
 if bad then ULib.tsayError(ply,text,true) else ULib.tsay(ply,text,true) end
end
-- Выполнение команды «Коменданта» от имени вызвавшего ULX. Возвращает успешные цели (для журнала ULX).
local function run(calling,command,targets,args)
 local Adm=STALKER_ADMIN
 if not Adm or not Adm.Execute then say(calling,"[Комендант] Панель не загружена",true);return end
 local a=args or {};a.kind="execute";a.command=command
 local bySID={}
 if targets then
  a.targets={}
  for _,t in ipairs(targets) do
   if IsValid(t) and not t:IsBot() and not bySID[t:SteamID64()] then bySID[t:SteamID64()]=t;a.targets[#a.targets+1]=t:SteamID64() end
  end
  if #a.targets==0 then say(calling,"[Комендант] Нет подходящих целей (боты не поддерживаются)",true);return end
 end
 local r=Adm.Execute(calling,a)
 if not r.results then say(calling,"[Комендант] "..tostring(r.message),true);return end
 local done={}
 for _,row in ipairs(r.results) do
  if row.ok then
   if row.sid and bySID[row.sid] then done[#done+1]=bySID[row.sid] end
   if row.message~="Выполнено" then say(calling,"[Комендант] "..row.message) end
  else say(calling,"[Комендант] "..tostring(row.name).." — "..tostring(row.message),true) end
 end
 return done,r.ok
end

function ulx.stalkeritem(calling,targets,item,amount)
 local done=run(calling,"item",targets,{value=item,amount=amount})
 if done and #done>0 then ulx.fancyLogAdmin(calling,"#A выдал #T предмет #s ×#i",done,item,amount) end
end
local cmd=ulx.command(CATEGORY,"ulx stalkeritem",ulx.stalkeritem,"!stalkeritem")
cmd:addParam{type=ULib.cmds.PlayersArg}
cmd:addParam{type=ULib.cmds.StringArg,hint="предмет",completes=items}
cmd:addParam{type=ULib.cmds.NumArg,min=1,max=100,default=1,hint="количество",ULib.cmds.optional,ULib.cmds.round}
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Выдать предмет STALKER в инвентарь (право stalker_loadout).")

function ulx.stalkerdose(calling,targets,dose)
 local done=run(calling,"radiation",targets,{amount=dose})
 if done and #done>0 then ulx.fancyLogAdmin(calling,"#A установил дозу радиации #i для #T",dose,done) end
end
cmd=ulx.command(CATEGORY,"ulx stalkerdose",ulx.stalkerdose,"!stalkerdose")
cmd:addParam{type=ULib.cmds.PlayersArg}
cmd:addParam{type=ULib.cmds.NumArg,min=0,max=100,default=0,hint="доза 0–100",ULib.cmds.optional,ULib.cmds.round}
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Установить накопленную дозу радиации (право stalker_zone).")

function ulx.stalkerfaction(calling,targets,faction)
 local done=run(calling,"faction",targets,{value=faction})
 if done and #done>0 then ulx.fancyLogAdmin(calling,"#A назначил #T в группировку #s",done,faction) end
end
cmd=ulx.command(CATEGORY,"ulx stalkerfaction",ulx.stalkerfaction,"!stalkerfaction")
cmd:addParam{type=ULib.cmds.PlayersArg}
cmd:addParam{type=ULib.cmds.StringArg,hint="группировка",completes=factions}
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Назначить группировку STALKER (право stalker_zone).")

-- Команды без целей: одно действие на весь сервер.
local function serverCommand(name,command,text,help,param)
 local fn=function(calling,value)
  local done,ok=run(calling,command,nil,{value=value})
  if ok then ulx.fancyLogAdmin(calling,text,value) end
 end
 ulx[name]=fn
 local c=ulx.command(CATEGORY,"ulx "..name,fn,"!"..name)
 if param then c:addParam(param) end
 c:defaultAccess(ULib.ACCESS_ADMIN)
 c:help(help)
 return c
end
serverCommand("emissionstart","emission_start","#A запустил выброс","Запустить выброс (право stalker_zone).")
serverCommand("emissionstop","emission_stop","#A остановил выброс","Остановить идущий выброс (право stalker_zone).")
serverCommand("zonerebuild","zone_rebuild","#A перестроил Зону","Перестроить аномалии и артефакты всех полей (право stalker_zone).")
serverCommand("stalkerrestock","restock","#A пополнил склады торговцев","Пополнить склады торговцев (право stalker_zone).")
serverCommand("stalkerevent","event_start","#A запустил событие #s","Запустить событие Зоны (право stalker_events).",{type=ULib.cmds.StringArg,hint="событие",completes=events})
serverCommand("stalkerstopevent","event_stop","#A остановил событие #s","Остановить событие Зоны (право stalker_events).",{type=ULib.cmds.StringArg,hint="событие",completes=events})
