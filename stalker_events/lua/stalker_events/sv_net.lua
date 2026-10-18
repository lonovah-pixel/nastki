-- Сеть: админ-панель событий (право events) и установка маячка игроком. Клиенту не доверяем ничего, кроме выбора.
local E=STALKER_EVENTS
local C=STALKER_CORE
local Cfg=E.Config
util.AddNetworkString("stalker_events.admin")

local function vec3(v) return {x=math.Round(v.x),y=math.Round(v.y),z=math.Round(v.z)} end
function E.AdminSnapshot()
 local events={};local now=CurTime()
 for _,id in ipairs(E.Order) do
  local def=E.Defs[id];local ev=E.Active[id]
  events[#events+1]={id=id,name=def.name,desc=def.description,active=ev~=nil,left=ev and math.max(0,math.floor(ev.ends-now)) or nil,
   where=ev and ev.where or nil,info=ev and ev.info or nil,weight=tonumber(E.Value(def.weight,def)) or 0,minPlayers=math.max(Cfg.MinPlayers,tonumber(E.Value(def.minPlayers,def)) or 0)}
 end
 local spots,pois={},{}
 for id,s in SortedPairs(E.World.spots) do spots[#spots+1]={id=id,name=s.name,pos=s.pos} end
 for id,p in SortedPairs(E.World.pois) do pois[#pois+1]={id=id,name=p.name,kind=p.kind,flag=p.flag,pos=p.pos} end
 return {events=events,scheduler=Cfg.Scheduler==true,next=E.NextAt and math.max(0,math.floor(E.NextAt-now)) or nil,
  interval={Cfg.IntervalMin,Cfg.IntervalMax},players=#player.GetHumans(),npc=E.CountNPC(),beacons=#E.AllBeacons(),
  spots=spots,pois=pois,broken=E.WorldBroken==true,lastError=E.LastAutoError,maxSpots=Cfg.MaxSpots,maxPOI=Cfg.MaxPOI}
end

local function who(ply) return IsValid(ply) and (ply:Nick().." ("..tostring(ply:SteamID64())..")") or "консоль" end
-- Операции панели: fn(ply, a) → ok, "сообщение".
E.AdminOps={
 state=function() return true end,
 start=function(ply,a)
  local opts={};if a.here then opts.pos=E.AimPos(ply);if not opts.pos then return false,"Наведите прицел на землю" end end
  local ok,err=E.Start(a.id,opts)
  if ok then E.Log(who(ply).." запустил событие "..tostring(a.id)) end
  return ok,ok and ("Событие «"..E.Defs[a.id].name.."» запущено") or err
 end,
 stop=function(ply,a)
  local ok,err=E.Stop(a.id,"admin")
  if ok then E.Log(who(ply).." остановил событие "..tostring(a.id)) end
  return ok,ok and "Событие остановлено" or err
 end,
 -- Перенести следующее автоматическое событие: через minutes минут (0 — сейчас же, если ничего не идёт).
 schedule=function(ply,a)
  if not C.Num(a.minutes,0,600) then return false,"Укажите от 0 до 600 минут" end
  E.ScheduleNext(a.minutes*60)
  local text=a.minutes==0 and "Следующее событие начнётся сейчас" or ("Следующее событие через "..a.minutes.." мин")
  return true,text..(Cfg.Scheduler and "" or " — когда планировщик будет включён")
 end,
 scheduler=function(ply,a)
  if type(a.on)~="boolean" then return false,"Некорректное значение" end
  local ok,err=STALKER_SETTINGS.Set("events.scheduler",a.on,ply)
  return ok,ok and (a.on and "Планировщик включён" or "Планировщик выключен") or err
 end,
 spot_add=function(ply,a)
  local pos=E.AimPos(ply);if not pos then return false,"Наведите прицел на землю" end
  local spot=E.ValidSpot({name=a.name,pos=vec3(pos)});if not spot then return false,"Название места: от 1 до 48 символов" end
  local ok,err=E.EditWorld(function(w)
   if table.Count(w.spots)>=Cfg.MaxSpots then return false,"Достигнут лимит мест: "..Cfg.MaxSpots end
   spot.id=E.NextID("s");w.spots[spot.id]=spot;return true
  end)
  return ok,ok and ("Место «"..spot.name.."» добавлено") or err
 end,
 spot_remove=function(ply,a)
  if type(a.id)~="string" or not E.World.spots[a.id] then return false,"Место не найдено" end
  local name=E.World.spots[a.id].name
  local ok,err=E.EditWorld(function(w) w.spots[a.id]=nil;return true end)
  return ok,ok and ("Место «"..name.."» удалено") or err
 end,
 -- Временные метки мест событий для этого администратора (2 минуты).
 spot_show=function(ply)
  local sid=ply:SteamID64();local n=0
  STALKER_MARKERS.Clear("stev.spot."..sid..".")
  for id,s in pairs(E.World.spots) do
   n=n+1
   STALKER_MARKERS.Set("stev.spot."..sid.."."..id,{pos=Vector(s.pos.x,s.pos.y,s.pos.z),kind="event",label="Место событий · "..s.name,
    world=true,edge=false,visible={players={[sid]=true}},expires=CurTime()+120})
  end
  return true,n>0 and ("Показано мест: "..n.." (2 минуты)") or "Мест событий пока нет"
 end,
 poi_add=function(ply,a)
  local pos=E.AimPos(ply);if not pos then return false,"Наведите прицел на землю" end
  local poi=E.ValidPOI({name=a.name,kind=a.kind,flag=a.flag==true,pos=vec3(pos)})
  if not poi then return false,"Укажите тип и название точки (до 48 символов)" end
  local ok,err=E.EditWorld(function(w)
   if table.Count(w.pois)>=Cfg.MaxPOI then return false,"Достигнут лимит точек: "..Cfg.MaxPOI end
   poi.id=E.NextID("p");w.pois[poi.id]=poi;return true
  end)
  return ok,ok and ("Точка «"..poi.name.."» поставлена") or err
 end,
 poi_edit=function(ply,a)
  local old=type(a.id)=="string" and E.World.pois[a.id];if not old then return false,"Точка не найдена" end
  local poi=E.ValidPOI({name=a.name==nil and old.name or a.name,kind=a.kind==nil and old.kind or a.kind,flag=a.flag==nil and old.flag or a.flag==true,pos=old.pos})
  if not poi then return false,"Укажите тип и название точки (до 48 символов)" end
  local ok,err=E.EditWorld(function(w) poi.id=a.id;w.pois[a.id]=poi;return true end)
  return ok,ok and "Точка обновлена" or err
 end,
 poi_remove=function(ply,a)
  if type(a.id)~="string" or not E.World.pois[a.id] then return false,"Точка не найдена" end
  local name=E.World.pois[a.id].name
  local ok,err=E.EditWorld(function(w) w.pois[a.id]=nil;return true end)
  return ok,ok and ("Точка «"..name.."» удалена") or err
 end,
}

net.Receive("stalker_events.admin",function(len,ply)
 if not C.Rate(ply,"events.admin",3,8) then return end
 local a=C.Read(len,4000);if type(a)~="table" or type(a.op)~="string" or not E.AdminOps[a.op] then return end
 if not C.CanAdmin(ply,"events") then C.Send("stalker_events.admin",ply,{denied=true});return end
 local ok,res,msg=pcall(E.AdminOps[a.op],ply,a)
 if not ok then ErrorNoHalt("[STALKER Events] admin "..a.op..": "..tostring(res).."\n");res,msg=false,"Ошибка операции" end
 local out=E.AdminSnapshot()
 if a.op~="state" then out.result={op=a.op,ok=res~=false,message=msg} end
 C.Send("stalker_events.admin",ply,out)
end)

net.Receive("stalker_events.beacon",function(len,ply)
 if not C.Rate(ply,"events.beacon",1,3) then return end
 local a=C.Read(len,600);if type(a)~="table" then return end
 local ok,err=E.PlaceBeacon(ply,a.mode,a.label)
 if not ok and err then C.Notify(ply,err,"warn",5) end
end)

-- Чат: !events — окно управления событиями (для администраторов с правом events).
hook.Add("PlayerSay","STALKER_EVENTS.Chat",function(ply,text)
 local t=string.Trim(tostring(text or "")):lower()
 if t~="!events" and t~="/events" then return end
 if C.CanAdmin(ply,"events") then ply:ConCommand("stev_menu") end
 return ""
end)

-- Консоль сервера и RCON: stev_start <id>, stev_stop <id>, stev_list.
local function consoleOut(ply,text) if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE,text) else print(text) end end
concommand.Add("stev_start",function(ply,_,args)
 if IsValid(ply) and not C.CanAdmin(ply,"events") then return end
 local ok,err=E.Start(args[1]);consoleOut(ply,ok and ("Событие запущено: "..tostring(args[1])) or ("Ошибка: "..tostring(err)))
end)
concommand.Add("stev_stop",function(ply,_,args)
 if IsValid(ply) and not C.CanAdmin(ply,"events") then return end
 local ok,err=E.Stop(args[1],"admin");consoleOut(ply,ok and "Событие остановлено" or ("Ошибка: "..tostring(err)))
end)
concommand.Add("stev_list",function(ply)
 if IsValid(ply) and not C.CanAdmin(ply,"events") then return end
 for _,row in ipairs(E.List()) do consoleOut(ply,row.id.." — "..row.name..(row.active and " [идёт]" or "")) end
 consoleOut(ply,E.NextAt and ("Следующее автоматическое событие через "..E.FormatTime(E.NextAt-CurTime())..(Cfg.Scheduler and "" or " (планировщик выключен)")) or "Планировщик ещё не запущен")
end)
