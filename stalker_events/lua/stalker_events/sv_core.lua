-- Каркас событий: реестр, запуск и остановка, планировщик, участники, метки и рассылка состояния клиентам.
local E=STALKER_EVENTS
local C=STALKER_CORE
local Cfg=E.Config
util.AddNetworkString("stalker_events.state")
E.Defs=E.Defs or {}
E.Order=E.Order or {}
E.Active=E.Active or {}

local function value(v,def) if type(v)=="function" then return v(def) end;return v end
E.Value=value
function E.Log(text) print("[STALKER Events] "..text) end

--[[ Регистрация события:
 id         — латиница/цифры/_ (до 32 символов)
 name       — подпись; description — пояснение для КПК
 duration   — секунды (число или функция), weight — вес в случайном выборе, minPlayers — минимум игроков для автозапуска
 major      — крупное событие (по умолчанию да): одновременно идёт только одно крупное
 canStart(def) → true | false,"причина" — проверка перед запуском (и автоматическим, и ручным)
 start(ev) → true | false,"причина"; think(ev) — раз в секунду; stop(ev, reason) — reason: time, done, admin, cleanup, error
 В ev: id, name, def, started, ends, pos, where, data={}, npcs={}, participants={} ]]
function E.Register(def)
 assert(type(def)=="table" and type(def.id)=="string" and #def.id<=32 and def.id:match("^[%w_]+$"),"STALKER Events: некорректный id события")
 assert(type(def.start)=="function","STALKER Events: у события нет start")
 def.name=def.name or def.id;def.weight=def.weight or 10;def.minPlayers=def.minPlayers or 0
 if def.major==nil then def.major=true end
 if not E.Defs[def.id] then E.Order[#E.Order+1]=def.id end
 E.Defs[def.id]=def
 return def
end

function E.MajorActive()
 for _,ev in pairs(E.Active) do if ev.def.major then return ev end end
end
function E.Get(id) return E.Active[id] end

-- Для «Коменданта» и ULX: массив {id, name, active}.
function E.List()
 local out={}
 for _,id in ipairs(E.Order) do local def=E.Defs[id];out[#out+1]={id=id,name=def.name,active=E.Active[id]~=nil} end
 return out
end

local function cleanup(ev)
 for _,npc in ipairs(ev.npcs or {}) do if IsValid(npc) then npc:Remove() end end
 ev.npcs={}
 STALKER_MARKERS.Clear("stev.ev."..ev.id..".")
end

-- Запуск: opts.auto — из планировщика (тогда учитывается минимум игроков). Возвращает true или false, "причина".
function E.Start(id,opts)
 opts=opts or {}
 local def=type(id)=="string" and E.Defs[id]
 if not def then return false,"Неизвестное событие: "..tostring(id) end
 if E.Active[id] then return false,"Событие «"..def.name.."» уже идёт" end
 if def.major then local cur=E.MajorActive();if cur then return false,"Уже идёт событие «"..cur.name.."»" end end
 if opts.auto then
  local need=math.max(Cfg.MinPlayers,value(def.minPlayers,def) or 0)
  if #player.GetHumans()<need then return false,"Нужно игроков в сети: "..need end
 end
 if def.canStart then
  local ok,a,b=pcall(def.canStart,def)
  if not ok then ErrorNoHalt("[STALKER Events] "..id..".canStart: "..tostring(a).."\n");return false,"Ошибка события" end
  if a==false then return false,b or "Событие сейчас невозможно" end
 end
 local now=CurTime()
 local ev={id=id,name=def.name,def=def,started=now,data={},npcs={},participants={}}
 ev.duration=math.max(10,tonumber(value(def.duration,def)) or 600);ev.ends=now+ev.duration
 E.Active[id]=ev
 local ok,res,err=pcall(def.start,ev,opts)
 if not ok or res==false then
  if not ok then ErrorNoHalt("[STALKER Events] "..id..".start: "..tostring(res).."\n") end
  E.Active[id]=nil;cleanup(ev)
  if def.stop then pcall(def.stop,ev,"error") end
  return false,not ok and "Ошибка запуска события" or err or "Событие не запущено"
 end
 E.Log("событие «"..def.name.."» началось"..(ev.where and (" ("..ev.where..")") or ""))
 hook.Run("STALKER_EVENTS_Started",id,ev)
 E.MarkDirty()
 return true
end

-- Остановка: reason — admin (по умолчанию), time, done, cleanup. Возвращает true или false, "причина".
function E.Stop(id,reason)
 local ev=type(id)=="string" and E.Active[id]
 if not ev then return false,"Событие не идёт" end
 reason=reason or "admin"
 E.Active[id]=nil
 if ev.def.stop then local ok,err=pcall(ev.def.stop,ev,reason);if not ok then ErrorNoHalt("[STALKER Events] "..id..".stop: "..tostring(err).."\n") end end
 cleanup(ev)
 if reason=="admin" then C.News("Событие «"..ev.name.."» завершено.","event") end
 E.Log("событие «"..ev.name.."» завершено ("..reason..")")
 hook.Run("STALKER_EVENTS_Stopped",id,ev,reason)
 -- Следующее автоматическое событие — через случайный интервал после окончания крупного.
 if ev.def.major then E.ScheduleNext() end
 E.MarkDirty()
 return true
end
function E.StopAll(reason) for id in pairs(E.Active) do E.Stop(id,reason) end end

--[[ Планировщик ]]
function E.Interval()
 local lo,hi=Cfg.IntervalMin,Cfg.IntervalMax
 if hi<lo then lo,hi=hi,lo end
 return math.Rand(lo,hi)*60
end
function E.ScheduleNext(seconds) E.NextAt=CurTime()+(seconds or E.Interval()) end
-- После смены настроек: следующее событие не позже верхней границы интервала. Просроченное время (планировщик был
-- выключен) тоже пересчитывается, чтобы включение планировщика не запускало событие в ту же секунду.
function E.ClampSchedule()
 local now=CurTime();local hi=math.max(Cfg.IntervalMin,Cfg.IntervalMax)*60
 if not E.NextAt or E.NextAt<now or E.NextAt>now+hi then E.ScheduleNext() end
end
-- Случайное событие по весам среди доступных. Возвращает id или nil и причину.
function E.AutoStart()
 local pool,total={},0
 for _,id in ipairs(E.Order) do
  local def=E.Defs[id];local w=tonumber(value(def.weight,def)) or 0
  if w>0 and not E.Active[id] then pool[#pool+1]={id=id,w=w};total=total+w end
 end
 local reason="Нет событий с весом больше нуля"
 while #pool>0 do
  local roll=math.Rand(0,total);local pick=#pool
  for i,row in ipairs(pool) do roll=roll-row.w;if roll<=0 then pick=i;break end end
  local row=table.remove(pool,pick);total=total-row.w
  local ok,err=E.Start(row.id,{auto=true})
  if ok then return row.id end
  reason=err
 end
 return nil,reason
end

--[[ Участники: статистика «Участие в событиях» один раз за событие ]]
function E.Participate(ev,ply)
 if not ev or not IsValid(ply) or not ply:IsPlayer() then return end
 local sid=C.SID(ply);if not sid or ev.participants[sid] then return end
 ev.participants[sid]=true
 C.AddStat(ply,"events",1)
end

-- Метка события: id «stev.ev.<событие>.<суффикс>», убирается при остановке.
function E.Marker(ev,suffix,data)
 data.kind=data.kind or "event"
 if not data.expires then data.expires=ev.ends+5 end
 return STALKER_MARKERS.Set("stev.ev."..ev.id.."."..suffix,data)
end
function E.RemoveMarker(ev,suffix) STALKER_MARKERS.Remove("stev.ev."..ev.id.."."..suffix) end

-- Деньги игроку (DarkRP). Без DarkRP награда не выдаётся.
function E.Pay(ply,amount,why)
 amount=math.floor(tonumber(amount) or 0)
 if not IsValid(ply) or amount<=0 or not ply.addMoney then return false end
 ply:addMoney(amount)
 C.AddStat(ply,"earned",amount)
 C.Notify(ply,(why or "Награда")..": +"..E.Money(amount),"ok",6)
 return true
end

--[[ Состояние для клиентов: активные события, свои маячки, цель охоты ]]
function E.MarkDirty() E.Dirty=true end
function E.PublicActive()
 local list={};local now=CurTime()
 for _,id in ipairs(E.Order) do
  local ev=E.Active[id]
  if ev then list[#list+1]={id=id,name=ev.name,desc=ev.def.description,left=math.max(0,math.floor(ev.ends-now)),where=ev.where,info=ev.info} end
 end
 return list
end
function E.SendState(ply,active)
 if not IsValid(ply) then return end
 local out={active=active or E.PublicActive(),beacons=E.BeaconsOf and E.BeaconsOf(ply) or {},limit=Cfg.BeaconLimit}
 local bounty=E.Active.bounty
 if bounty and bounty.data.target==ply then out.target={left=math.max(0,math.floor(bounty.ends-CurTime())),reward=Cfg.BountySurvive} end
 C.Send("stalker_events.state",ply,out)
end
function E.Broadcast()
 E.Dirty=false
 local active=E.PublicActive()
 for _,p in ipairs(player.GetHumans()) do E.SendState(p,active) end
end
hook.Add("PlayerInitialSpawn","STALKER_EVENTS.State",function(ply) timer.Simple(4,function() if IsValid(ply) then E.SendState(ply) end end) end)

--[[ Раз в секунду: ход событий, истечение, планировщик ]]
function E.Tick()
 local now=CurTime()
 for id,ev in pairs(E.Active) do
  if E.Active[id]==ev and ev.def.think then
   local ok,err=pcall(ev.def.think,ev)
   if not ok then ErrorNoHalt("[STALKER Events] "..id..".think: "..tostring(err).."\n") end
  end
  if E.Active[id]==ev and now>=ev.ends then E.Stop(id,"time") end
 end
 if E.BeaconTick then E.BeaconTick() end
 if not E.NextAt then E.ScheduleNext() end
 if Cfg.Scheduler and not E.MajorActive() and now>=E.NextAt then
  local started,why=E.AutoStart()
  -- Не вышло (мало игроков, нет мест): повторная попытка через 5 минут.
  if not started then E.ScheduleNext(300);if why then E.LastAutoError=why end end
 end
 if E.Dirty then E.Broadcast() end
end
timer.Create("STALKER_EVENTS.Tick",1,0,function() E.Tick() end)
-- Очистка карты удаляет ящики, маячки и NPC: события завершаются без наград.
hook.Add("PostCleanupMap","STALKER_EVENTS.Cleanup",function() E.StopAll("cleanup") end)
