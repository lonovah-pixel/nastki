local F=STFW
F.Profiles={};F.World={version=2,revision=0,points={},relations={},leaders={},proposals={},recruiters={},history={},npcRep={},progression={},bans={}}
local function query(q) local r=sql.Query(q);if r==false then ErrorNoHalt("[STFW] SQLite: "..sql.LastError().."\n");return false end return r end
function F.Log(s) print("[STFW] "..s);file.CreateDir("stalker_factions");file.Append("stalker_factions/audit.txt",os.date("!%Y-%m-%dT%H:%M:%SZ ")..s.."\n") end
function F.DebugLog(message) if F.Config.Debug then print("[STFW DEBUG] "..message) end end
-- Поля, появившиеся позже первого выпуска, получают значения по умолчанию (старые профили совместимы).
function F.ProfileDefaults(d)
 d.joinedAt=tonumber(d.joinedAt) or 0;d.xp=tonumber(d.xp) or 0;d.kills=tonumber(d.kills) or 0;d.captures=tonumber(d.captures) or 0
 d.frank=math.Clamp(math.floor(tonumber(d.frank) or 1),1,#F.FactionRanks)
 return d
end
-- Данные развития группировки в копии мира (создаются при первом обращении).
function F.Prog(w,id)
 w.progression=w.progression or {}
 local d=w.progression[id]
 if type(d)~="table" then d={};w.progression[id]=d end
 d.credits=tonumber(d.credits) or 0;d.treasury=tonumber(d.treasury) or 0
 if type(d.levels)~="table" then d.levels={} end
 if type(d.ledger)~="table" then d.ledger={} end
 if type(d.cooldowns)~="table" then d.cooldowns={} end
 return d
end
-- Только чтение: не изменяет опубликованный мир.
function F.ProgRead(id) return F.Prog({progression={[id]=table.Copy((F.World.progression or {})[id] or {})}},id) end
local function setup()
 if query("CREATE TABLE IF NOT EXISTS stfw_meta (id INTEGER PRIMARY KEY, version INTEGER NOT NULL)")==false then return end
 local v=tonumber(sql.QueryValue("SELECT version FROM stfw_meta WHERE id=1")) or 0
 if v>2 then F.Log("Unsupported future schema");return end
 if query("BEGIN")==false then return end
 local ok=query("CREATE TABLE IF NOT EXISTS stfw_world (map TEXT PRIMARY KEY, payload TEXT NOT NULL)")~=false
 ok=query("CREATE TABLE IF NOT EXISTS stfw_profiles (sid TEXT PRIMARY KEY, payload TEXT NOT NULL)")~=false and ok
 ok=query("INSERT OR REPLACE INTO stfw_meta VALUES(1,2)")~=false and ok
 if not ok then query("ROLLBACK");return end
 if query("COMMIT")==false then query("ROLLBACK");return end
 local rows=query("SELECT payload FROM stfw_world WHERE map="..sql.SQLStr(game.GetMap()))
 if rows==false then return end
 if rows and rows[1] then
  local w=util.JSONToTable(rows[1].payload)
  if type(w)~="table" or type(w.points)~="table" or type(w.relations)~="table" then F.Log("Corrupt world; refusing overwrite");return end
  for k,val in pairs(F.World) do if w[k]==nil then w[k]=val end end
  -- Миграция v1: добавлены переговоры, история и ревизии.
  w.version=2;F.World=w
 else
  for _,r in ipairs(F.InitialRelations) do F.World.relations[F.Pair(r[1],r[2])]={points=r[3],war=false,revision=0} end
 end
 local saved=query("SELECT sid,payload FROM stfw_profiles")
 if saved==false then return end
 for _,row in ipairs(saved or {}) do local d=util.JSONToTable(row.payload);if type(d)=="table" and F.Factions[d.faction] and type(d.rep)=="table" and type(d.xp)=="number" then F.ProfileDefaults(d);F.Profiles[row.sid]=d end end
 F.DatabaseReady=true
end
setup()
function F.Load(p)
 local sid=p:SteamID64();if F.Profiles[sid] then F.Profiles[sid].name=p:Nick();return F.Profiles[sid] end
 if not F.DatabaseReady or p:IsBot() then return end
 local rows=query("SELECT payload FROM stfw_profiles WHERE sid="..sql.SQLStr(sid));if rows==false then return end
 local d
 if rows then d=util.JSONToTable(rows[1].payload) else d=F.NewProfile() end
 if type(d)~="table" or not F.Factions[d.faction] or type(d.rep)~="table" then return end
 d.name=p:Nick();F.ProfileDefaults(d);F.Profiles[sid]=d;return d
end
-- Сначала транзакция SQLite, только затем публикация состояния и сетевые события.
function F.Commit(w,profiles,reason)
 if not F.DatabaseReady then return false end
 w.revision=F.World.revision+1
 -- Смена лидера навсегда снимает его запрет вступления (даже если тот же игрок позже снова станет лидером).
 for id,b in pairs(w.bans or {}) do if type(b)~="table" or w.leaders[id]~=b.leader then w.bans[id]=nil end end
 w.controlRevision=F.World.controlRevision or 0
 if reason and (reason:find("^editor ") or reason:find("^diplomacy ") or reason:find("^upgrade ")) then w.controlRevision=w.controlRevision+1 end
 if query("BEGIN")==false then return false end
 local ok=query("INSERT OR REPLACE INTO stfw_world VALUES("..sql.SQLStr(game.GetMap())..","..sql.SQLStr(util.TableToJSON(w))..")")~=false
 for sid,d in pairs(profiles or {}) do ok=query("INSERT OR REPLACE INTO stfw_profiles VALUES("..sql.SQLStr(sid)..","..sql.SQLStr(util.TableToJSON(d))..")")~=false and ok end
 if not ok then query("ROLLBACK");return false end
 if query("COMMIT")==false then query("ROLLBACK");return false end
 local victory=(w.victorySerial or 0)>(F.World.victorySerial or 0)
 F.World=w;for sid,d in pairs(profiles or {}) do F.Profiles[sid]=d end
 if reason then F.Log(reason) end
 for _,p in ipairs(player.GetAll()) do local d=F.Profiles[p:SteamID64()];if d then F.PublishProfile(p,d) end end
 if victory and F.Notify and w.history[#w.history] then F.Notify(nil,"victory",F.Name(w.history[#w.history].winner)) end
 return true
end
-- Сетевые переменные членства: группировка, звание и лидерство видны всем клиентам (F4, КПК, взаимодействие).
function F.PublishProfile(p,d)
 p:SetNW2String("stfw_faction",d.faction);p:SetNW2Bool("stfw_joined",d.joined==true)
 p:SetNW2Int("stfw_frank",d.joined and (d.frank or 1) or 0)
 p:SetNW2Bool("stfw_leader",d.joined==true and F.World.leaders[d.faction]==p:SteamID64())
end
function F.Save() return F.Commit(table.Copy(F.World),F.Profiles) end
-- Профиль одного игрока (вход и выход). F.Profiles хранит всех, кто когда-либо заходил: полная запись на каждом
-- входе и выходе — тысячи INSERT и заметный рывок сервера. Остальные профили меняются только через F.Commit.
function F.SaveProfile(sid) local d=F.Profiles[sid or ""];if not d then return false end;return F.Commit(table.Copy(F.World),{[sid]=d}) end
hook.Add("ShutDown","STFW.Save",function() if F.DatabaseReady then F.Save() end end)
hook.Add("PlayerDisconnected","STFW.SavePlayer",function(p) local sid=p:SteamID64();if F.Profiles[sid or ""] then F.SaveProfile(sid) end end)
