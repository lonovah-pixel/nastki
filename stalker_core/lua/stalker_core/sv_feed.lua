-- Лента новостей КПК и личная статистика сталкеров.
local C=STALKER_CORE
for _,n in ipairs({"news","stats"}) do util.AddNetworkString("stalker_core."..n) end

--[[ Новости: kind — info, emission, event, war, capture, quest, trade, danger ]]
C.NewsFeed=C.NewsFeed or {}
function C.News(text,kind,targets)
 if type(text)~="string" or text=="" then return end
 local entry={t=os.time(),text=text,kind=kind or "info"}
 if not targets then
  table.insert(C.NewsFeed,1,entry)
  while #C.NewsFeed>60 do table.remove(C.NewsFeed) end
 end
 C.Send("stalker_core.news",targets,{items={entry}})
 hook.Run("STALKER_News",entry,targets)
 return entry
end
local function sendHistory(ply)
 if not IsValid(ply) then return end
 local items={};for i=1,math.min(25,#C.NewsFeed) do items[i]=C.NewsFeed[i] end
 C.Send("stalker_core.news",ply,{items=items,history=true})
end
hook.Add("PlayerInitialSpawn","STALKER_Core.News",function(ply) timer.Simple(3,function() sendHistory(ply) end) end)
-- Повтор для загрузившегося клиента (первый мог потеряться); клиент принимает историю один раз.
hook.Add("STALKER_PlayerReady","STALKER_Core.News",sendHistory)
-- Важные события сборки сразу попадают в ленту.
hook.Add("STEmissionStarted","STALKER_Core.News",function() C.News("Внимание! Приближается выброс. Немедленно ищите укрытие.","emission") end)
hook.Add("STEmissionFinished","STALKER_Core.News",function() C.News("Выброс закончился. Аномальные поля сместились.","emission") end)

--[[ Статистика: произвольные счётчики по ключу. Сохраняются в SQLite stalker_stats. ]]
C.StatNames={kills="Убито сталкеров",deaths="Смертей",mutants="Убито мутантов",artifacts="Найдено артефактов",quests="Выполнено заданий",
 crafted="Изготовлено предметов",cooked="Приготовлено блюд",events="Участие в событиях",earned="Заработано, ₽",playtime="Время в Зоне, мин",
 captures="Захвачено точек",stashes="Найдено чужих тайников",emissions="Пережито выбросов"}
C.StatsReady=sql.Query("CREATE TABLE IF NOT EXISTS stalker_stats (sid TEXT PRIMARY KEY, payload TEXT NOT NULL)")~=false
C.StatCache=C.StatCache or {}
local dirty={}
function C.LoadStats(sid)
 if not sid then return end
 if C.StatCache[sid] then return C.StatCache[sid] end
 local data={}
 if C.StatsReady then
  local rows=sql.Query("SELECT payload FROM stalker_stats WHERE sid="..sql.SQLStr(sid))
  local raw=rows and rows[1] and util.JSONToTable(rows[1].payload)
  if type(raw)=="table" then for k,v in pairs(raw) do if type(k)=="string" and type(v)=="number" then data[k]=v end end end
 end
 C.StatCache[sid]=data;return data
end
function C.AddStat(ply,key,amount)
 local sid=C.SID(ply);if not sid or type(key)~="string" then return end
 local s=C.LoadStats(sid);s[key]=(s[key] or 0)+(amount or 1);dirty[sid]=true
 return s[key]
end
function C.GetStats(ply) return C.LoadStats(C.SID(ply)) or {} end
function C.SaveStats(sid)
 if not C.StatsReady or not dirty[sid] or not C.StatCache[sid] then return end
 if sql.Query("REPLACE INTO stalker_stats VALUES("..sql.SQLStr(sid)..","..sql.SQLStr(util.TableToJSON(C.StatCache[sid]))..")")~=false then dirty[sid]=nil end
end
timer.Create("STALKER_Core.StatsSave",30,0,function() for sid in pairs(dirty) do C.SaveStats(sid) end end)
timer.Create("STALKER_Core.Playtime",60,0,function() for _,p in ipairs(player.GetHumans()) do C.AddStat(p,"playtime",1) end end)
hook.Add("PlayerDisconnected","STALKER_Core.Stats",function(ply) local sid=C.SID(ply);if sid then C.SaveStats(sid);C.StatCache[sid]=nil end end)
hook.Add("ShutDown","STALKER_Core.Stats",function() for sid in pairs(dirty) do C.SaveStats(sid) end end)
hook.Add("PlayerDeath","STALKER_Core.Stats",function(victim,_,attacker)
 C.AddStat(victim,"deaths",1)
 if IsValid(attacker) and attacker:IsPlayer() and attacker~=victim then C.AddStat(attacker,"kills",1) end
end)
hook.Add("OnNPCKilled","STALKER_Core.Stats",function(npc,attacker)
 if IsValid(attacker) and attacker:IsPlayer() and IsValid(npc) and (npc.StalkerMutant or npc:GetClass():match("^npc_")) then C.AddStat(attacker,"mutants",1) end
end)
hook.Add("STALKER_ZONE_ArtifactPicked","STALKER_Core.Stats",function(ply) C.AddStat(ply,"artifacts",1) end)
hook.Add("STEmissionFinished","STALKER_Core.Stats",function() for _,p in ipairs(player.GetHumans()) do if p:Alive() then C.AddStat(p,"emissions",1) end end end)

-- Запрос: собственная статистика и топ по выбранному счётчику (по сохранённым профилям).
-- Топ считается не чаще раза в StatTopTTL секунд на счётчик: разбор тысяч профилей на каждый запрос каждого игрока
-- (и сохранение всех изменённых) — лишняя нагрузка, которую легко раскачать.
C.StatTop=C.StatTop or {}
C.StatTopTTL=30
net.Receive("stalker_core.stats",function(len,ply)
 if not C.Rate(ply,"core.stats",.5,3) then return end
 local a=C.Read(len,300) or {}
 local out={mine=C.GetStats(ply),names=C.StatNames}
 local key=type(a.top)=="string" and C.StatNames[a.top] and a.top
 local cached=key and C.StatTop[key]
 if cached and cached.t>CurTime() then out.top=cached.top
 elseif key and C.StatsReady then
  for sid in pairs(dirty) do C.SaveStats(sid) end
  -- REPLACE переносит сохранённый профиль в конец таблицы: без ORDER BY первые 2000 строк — самые старые профили,
  -- и на сервере с большой базой активные игроки в топ не попадали.
  local rows=sql.Query("SELECT sid,payload FROM stalker_stats ORDER BY rowid DESC LIMIT 2000") or {}
  local list={}
  for _,row in ipairs(type(rows)=="table" and rows or {}) do
   local data=util.JSONToTable(row.payload or "")
   if type(data)=="table" and tonumber(data[key]) then
    local p=C.PlayerBySID(row.sid)
    list[#list+1]={sid=row.sid,name=IsValid(p) and p:Nick() or nil,value=tonumber(data[key])}
   end
  end
  table.sort(list,function(x,y) return x.value>y.value end)
  while #list>10 do table.remove(list) end
  out.top={key=key,list=list}
  C.StatTop[key]={t=CurTime()+C.StatTopTTL,top=out.top}
 end
 C.Send("stalker_core.stats",ply,out)
end)
