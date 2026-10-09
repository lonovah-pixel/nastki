local B=STALKER_BUTCHERING
B.Profiles={};B.Outbox={}
function B.Log(text) print('[STB] '..text) end
function B.Query(q)
 local r=sql.Query(q);if r==false then B.Log('SQLite: '..sql.LastError()) end;return r
end
-- Версия 1: таблицы независимы от остальных аддонов, миграция идемпотентна.
B.Ready=B.Query('CREATE TABLE IF NOT EXISTS stb_profiles (steamid TEXT PRIMARY KEY, payload TEXT NOT NULL)')~=false
B.Ready=(B.Query('CREATE TABLE IF NOT EXISTS stb_rewards (id TEXT PRIMARY KEY, steamid TEXT NOT NULL, payload TEXT NOT NULL)')~=false) and B.Ready
B.Query('CREATE INDEX IF NOT EXISTS stb_rewards_owner ON stb_rewards(steamid)')
function B.Profile(p)
 local id=p:SteamID64();if p:IsBot() or not id or id=='0' then return nil end
 if B.Profiles[id] then return B.Profiles[id] end
 local rows=B.Query('SELECT payload FROM stb_profiles WHERE steamid='..sql.SQLStr(id));if rows==false then return end
 local data=rows and util.JSONToTable(rows[1].payload) or {version=1,xp=0,fatigue=0,at=os.time()}
 if type(data)~='table' or data.version~=1 or type(data.xp)~='number' or type(data.fatigue)~='number' or type(data.at)~='number' then return end
 B.Profiles[id]=data;return data
end
function B.Fatigue(d) return math.max(0,d.fatigue-math.max(0,os.time()-d.at)*.08) end
function B.StoreResult(job)
 if not B.Ready or B.Query('BEGIN IMMEDIATE')==false then return false end
 local exists=B.Query('SELECT id FROM stb_rewards WHERE id='..sql.SQLStr(job.id))
 if exists==false then B.Query('ROLLBACK');return false end
 if not exists then
  local a=B.Query('INSERT INTO stb_rewards VALUES('..sql.SQLStr(job.id)..','..sql.SQLStr(job.owner)..','..sql.SQLStr(util.TableToJSON(job.result))..')')
  local b=B.Query('REPLACE INTO stb_profiles VALUES('..sql.SQLStr(job.owner)..','..sql.SQLStr(util.TableToJSON(job.profile))..')')
  if a==false or b==false then B.Query('ROLLBACK');return false end
 end
 if B.Query('COMMIT')==false then B.Query('ROLLBACK');return false end
 B.Profiles[job.owner]=job.profile;return true
end
hook.Add('PlayerDisconnected','STB.ProfileCache',function(p) B.Profiles[p:SteamID64()]=nil end)
