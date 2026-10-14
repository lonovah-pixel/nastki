-- Smoke-тесты сборки. Запуск: tools/test/run.sh (нужны LuaJIT и libsqlite3).
-- Порядок: моки (tools/test/mocks/*.lua) → загрузка аддонов как в GMod → сценарии (tools/test/cases/*.lua).
-- Сценарии одного прогона делят мир: размещайте своих игроков и объекты в собственной области координат.
local dir=arg[0]:match("^(.*)/") or "."
package.path=dir.."/?.lua;"..package.path
local M=require("mock_gmod")
local T={pass=0,fail=0}
local function check(cond,msg)
 if cond then T.pass=T.pass+1 else T.fail=T.fail+1;M.realPrint("  ✗ "..tostring(msg)) end
 return cond
end
local function section(name) M.realPrint("• "..name) end
TEST={M=M,T=T,check=check,section=section}
function TEST.count(class) return #ents.FindByClass(class) end
function TEST.gridCount(p,id) local n=0;for _,it in pairs(p.StalkerInventory.grid) do if it.id==id then n=n+it.count end end;return n end
function TEST.gridIndex(p,id) for i=1,40 do local it=p.StalkerInventory.grid[i];if it and it.id==id then return i end end end
-- Игрок, прошедший вход и возрождение (инвентарь и профиль группировки загружены).
function TEST.join(opts) local p=M.addPlayer(opts);hook.Run("PlayerInitialSpawn",p);M.spawn(p);M.advance(4);return p end

local function listLua(sub)
 local out={};local p=io.popen('ls -1 "'..dir..'/'..sub..'" 2>/dev/null')
 if p then for name in p:lines() do if name:match("%.lua$") then out[#out+1]=dir.."/"..sub.."/"..name end end;p:close() end
 table.sort(out);return out
end

if CLIENT then M.clientLibs() end
-- Минимальный DarkRP для серверных аддонов: формат денег и уведомления.
DarkRP={formatMoney=function(n) return tostring(n).." ₽" end,notify=function() end}
for _,path in ipairs(listLua("mocks")) do local ok,err=pcall(dofile,path);if not ok then check(false,"мок "..path..": "..tostring(err)) end end
M.trackGlobals()
M.loadAutorun()
M.loadEntities()
hook.Run("Initialize")
hook.Run("InitPostEntity")
M.advance(12)

for _,path in ipairs(listLua("cases")) do
 local fn,err=loadfile(path)
 if not fn then check(false,"сценарий не компилируется: "..tostring(err))
 else
  local ok,e=xpcall(fn,debug.traceback)
  if not ok then check(false,"сценарий "..path:match("[^/]+$").." прерван: "..tostring(e)) end
 end
end

section("Итоги")
local optional={STALKER_WIPE=true,STFW=true,STALKER_RAD=true,ST_EMISSION=true,STALKER_NPC=true,STALKER_BUTCHERING=true,STALKER_ADMIN=true,STALKER_STYLE=true,
 STALKER_INV=true,STALKER_ZONE=true,STALKER_CORE=true,STALKER_SETTINGS=true,STALKER_MARKERS=true,STALKER_THEME=true,MySQLite=true,RPExtraTeams=true,ENT=true,
 LANGUAGE=true,ULib=true,ulx=true,CAMI=true,STALKER_PDA=true,STALKER_SOCIAL=true,STALKER_QUESTS=true,STALKER_CRAFT=true,STALKER_EVENTS=true}
local unknown={}
for k in pairs(M.globalsRead) do if not optional[k] and not tostring(k):match("^TEAM_") then unknown[#unknown+1]=k end end
table.sort(unknown)
if #unknown>0 then M.realPrint("  ! неизвестные глобальные имена: "..table.concat(unknown,", ")) end
for _,w in ipairs(M.warnings) do M.realPrint("  ! "..w) end
for _,e in ipairs(M.errors) do M.realPrint("  ✗ ОШИБКА "..e);T.fail=T.fail+1 end
M.realPrint(string.format("%s: проверок пройдено %d, провалено %d",M.Realm,T.pass,T.fail))
os.exit(T.fail==0 and 0 or 1)
