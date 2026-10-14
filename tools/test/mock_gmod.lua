--[[ Минимальная эмуляция Garry's Mod для smoke-тестов аддонов сборки (LuaJIT + libsqlite3).

Не заменяет запуск в игре: физика, рендер и сеть упрощены. Цель — поймать ошибки загрузки,
опечатки в путях include/AddCSLuaFile, обращения к несуществующим функциям и сломанную логику
серверных сценариев (инвентарь, торговля, аномалии, мутанты, смерть, вайп).

Мир: плоская земля на высоте z=0, всё внутри карты, воды нет.
]]
local ffi=require("ffi")
local M={warnings={},globalsRead={},files={}}
local REALM=assert(os.getenv("GMOD_REALM"),"GMOD_REALM=server|client")
local ROOT=assert(os.getenv("GMOD_ROOT"),"GMOD_ROOT=путь к репозиторию")
local DATA=assert(os.getenv("GMOD_DATA"),"GMOD_DATA=временная папка data")
M.Realm=REALM
SERVER=REALM=="server";CLIENT=not SERVER

local function warn(msg) M.warnings[#M.warnings+1]=msg end
M.warn=warn

--[[ Файловая система ]]
local function exists(path) local f=io.open(path,"rb");if f then f:close();return true end;return false end
local function readAll(path) local f=io.open(path,"rb");if not f then return end;local s=f:read("*a");f:close();return s end
local function listDir(dir)
 local out={};local p=io.popen('ls -1 "'..dir..'" 2>/dev/null')
 if p then for line in p:lines() do out[#out+1]=line end;p:close() end
 table.sort(out);return out
end
local function isDir(path) local p=io.popen('test -d "'..path..'" && echo y');local r=p:read("*l");p:close();return r=="y" end
M.addons={}
for _,name in ipairs(listDir(ROOT)) do
 if name:match("^stalker_") and isDir(ROOT.."/"..name.."/lua") then M.addons[#M.addons+1]=ROOT.."/"..name end
end

--[[ Базовые библиотеки GMod ]]
function math.Clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
function math.Rand(a,b) return a+(b-a)*math.random() end
function math.Round(v,d) local m=10^(d or 0);return math.floor(v*m+.5)/m end
function math.NormalizeAngle(a) a=a%360;if a>180 then a=a-360 end;return a end
function math.Approach(c,t,i) if c<t then return math.min(c+i,t) end;return math.max(c-i,t) end
math.huge=math.huge
function string.Trim(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end
function string.Explode(sep,s) local out={};for part in (s..sep):gmatch("(.-)"..sep:gsub("%p","%%%0")) do out[#out+1]=part end;return out end
function string.Comma(n) local s=tostring(math.floor(n));local r=s:reverse():gsub("(%d%d%d)","%1 "):reverse();return (r:gsub("^ ","")) end
function string.StartWith(s,p) return s:sub(1,#p)==p end
function table.Copy(t,seen)
 if type(t)~="table" then return t end
 seen=seen or {};if seen[t] then return seen[t] end
 local out={};seen[t]=out
 for k,v in pairs(t) do out[table.Copy(k,seen)]=table.Copy(v,seen) end
 return setmetatable(out,getmetatable(t))
end
function table.Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
function table.GetKeys(t) local out={};for k in pairs(t) do out[#out+1]=k end;return out end
function table.HasValue(t,v) for _,x in pairs(t) do if x==v then return true end end;return false end
function table.IsEmpty(t) return next(t)==nil end
function SortedPairs(t,desc)
 local keys=table.GetKeys(t);table.sort(keys,function(a,b) if desc then return tostring(a)>tostring(b) end return tostring(a)<tostring(b) end)
 local i=0;return function() i=i+1;local k=keys[i];if k~=nil then return k,t[k] end end
end
function isstring(v) return type(v)=="string" end
function isnumber(v) return type(v)=="number" end
function istable(v) return type(v)=="table" end
function isfunction(v) return type(v)=="function" end
function isbool(v) return type(v)=="boolean" end
function Lerp(t,a,b) return a+(b-a)*t end
function ErrorNoHalt(...) local s=table.concat({...});warn("ErrorNoHalt: "..s) end
function ErrorNoHaltWithStack(...) ErrorNoHalt(...) end
function MsgN(...) end
function Msg(...) end
function ServerLog(s) M.serverLog=(M.serverLog or "")..s end
M.printed={}
local realPrint=print
function print(...) local t={};for i=1,select("#",...) do t[#t+1]=tostring(select(i,...)) end;M.printed[#M.printed+1]=table.concat(t," ") end
M.realPrint=realPrint

--[[ Время и таймеры ]]
M.now=100
function CurTime() return M.now end
function RealTime() return M.now end
function SysTime() return M.now end
function FrameTime() return .016 end
function FrameNumber() return math.floor(M.now*60) end
local timers,simple={},{}
timer={}
function timer.Create(name,delay,reps,fn) timers[name]={delay=delay,reps=reps,fn=fn,next=M.now+delay,left=reps} end
function timer.Simple(delay,fn) simple[#simple+1]={at=M.now+delay,fn=fn} end
function timer.Remove(name) timers[name]=nil end
function timer.Exists(name) return timers[name]~=nil end
function timer.Adjust(name,delay) if timers[name] then timers[name].delay=delay end end
function M.advance(seconds,step)
 step=step or .25;local target=M.now+seconds
 while M.now<target do
  M.now=math.min(target,M.now+step)
  local due={}
  for i=#simple,1,-1 do if simple[i].at<=M.now then due[#due+1]=simple[i];table.remove(simple,i) end end
  table.sort(due,function(a,b) return a.at<b.at end)
  for _,t in ipairs(due) do M.protect("timer.Simple",t.fn) end
  local names=table.GetKeys(timers);table.sort(names)
  for _,name in ipairs(names) do local t=timers[name]
   if t and t.next<=M.now then
    t.next=M.now+t.delay;M.protect("timer "..name,t.fn)
    if t.reps>0 then t.left=t.left-1;if t.left<=0 then timers[name]=nil end end
   end
  end
 end
end
M.errors={}
function M.protect(label,fn,...)
 local ok,err=xpcall(fn,debug.traceback,...)
 if not ok then M.errors[#M.errors+1]=label..": "..tostring(err) end
 return ok,err
end

--[[ Хуки ]]
local hooks={}
hook={}
function hook.Add(event,name,fn) hooks[event]=hooks[event] or {};hooks[event][name]=fn end
function hook.Remove(event,name) if hooks[event] then hooks[event][name]=nil end end
function hook.GetTable() return hooks end
function hook.Call(event,gm,...)
 local list=hooks[event]
 if list then
  local names=table.GetKeys(list);table.sort(names,function(a,b) return tostring(a)<tostring(b) end)
  for _,name in ipairs(names) do
   local fn=list[name]
   if fn then
    local r={xpcall(fn,debug.traceback,...)}
    if not r[1] then M.errors[#M.errors+1]="hook "..event.."/"..tostring(name)..": "..tostring(r[2])
    elseif r[2]~=nil then return unpack(r,2) end
   end
  end
 end
 if gm and gm[event] then return gm[event](gm,...) end
end
function hook.Run(event,...) return hook.Call(event,GAMEMODE,...) end
GAMEMODE={Config={}};GM=GAMEMODE

--[[ Векторы, углы, цвета ]]
local V={};V.__index=V
function Vector(x,y,z) if type(x)=="table" then return setmetatable({x=x.x,y=x.y,z=x.z},V) end return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
V.__add=function(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
V.__sub=function(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
V.__mul=function(a,b) if type(a)=="number" then a,b=b,a end;if type(b)=="number" then return Vector(a.x*b,a.y*b,a.z*b) end;return Vector(a.x*b.x,a.y*b.y,a.z*b.z) end
V.__div=function(a,b) return Vector(a.x/b,a.y/b,a.z/b) end
V.__unm=function(a) return Vector(-a.x,-a.y,-a.z) end
V.__eq=function(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end
V.__tostring=function(a) return string.format("%.2f %.2f %.2f",a.x,a.y,a.z) end
function V:Length() return math.sqrt(self.x^2+self.y^2+self.z^2) end
function V:LengthSqr() return self.x^2+self.y^2+self.z^2 end
function V:Distance(o) return (self-o):Length() end
function V:DistToSqr(o) return (self-o):LengthSqr() end
function V:Dot(o) return self.x*o.x+self.y*o.y+self.z*o.z end
function V:GetNormalized() local l=self:Length();if l==0 then return Vector(0,0,0) end;return self/l end
function V:Normalize() local n=self:GetNormalized();self.x,self.y,self.z=n.x,n.y,n.z end
function V:Angle() return Angle(0,math.deg(math.atan2(self.y,self.x)),0) end
function V:ToScreen() return {x=0,y=0,visible=false} end
function V:IsZero() return self.x==0 and self.y==0 and self.z==0 end
function VectorRand() return Vector(math.Rand(-1,1),math.Rand(-1,1),math.Rand(-1,1)) end
local A={};A.__index=A
function Angle(p,y,r) return setmetatable({p=p or 0,y=y or 0,r=r or 0,pitch=p or 0,yaw=y or 0,roll=r or 0},A) end
function A:Forward() local y=math.rad(self.y);return Vector(math.cos(y),math.sin(y),0) end
local C={};C.__index=C
function Color(r,g,b,a) return setmetatable({r=r,g=g,b=b,a=a or 255},C) end
color_white=Color(255,255,255);color_black=Color(0,0,0);color_transparent=Color(0,0,0,0)

--[[ JSON (поведение util.TableToJSON / JSONToTable GMod) ]]
local function isArray(t)
 local n=0;for k in pairs(t) do if type(k)~="number" or k<1 or k%1~=0 then return false end;n=n+1 end
 for i=1,n do if t[i]==nil then return false end end
 return n>0
end
local function encode(v,out,pretty)
 local t=type(v)
 if t=="nil" then out[#out+1]="null"
 elseif t=="boolean" then out[#out+1]=tostring(v)
 elseif t=="number" then if v~=v or v==math.huge or v==-math.huge then out[#out+1]="0" elseif v%1==0 and math.abs(v)<1e15 then out[#out+1]=string.format("%d",v) else out[#out+1]=string.format("%.14g",v) end
 elseif t=="string" then out[#out+1]='"'..v:gsub('[%c"\\]',function(c) local m={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'};return m[c] or string.format("\\u%04x",c:byte()) end)..'"'
 elseif t=="table" then
  if getmetatable(v)==V then return encode(string.format("[%g %g %g]",v.x,v.y,v.z),out) end
  if isArray(v) then out[#out+1]="[";for i,x in ipairs(v) do if i>1 then out[#out+1]="," end;encode(x,out) end;out[#out+1]="]"
  else
   out[#out+1]="{";local first=true
   local keys=table.GetKeys(v);table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
   for _,k in ipairs(keys) do
    local x=v[k]
    if type(x)~="function" then
     if not first then out[#out+1]="," end;first=false
     encode(tostring(k),out);out[#out+1]=":";encode(x,out)
    end
   end
   out[#out+1]="}"
  end
 else out[#out+1]="null" end
end
local function decode(s)
 local i=1
 local function ws() i=s:find("[^%s]",i) or #s+1 end
 local value
 local function str()
  local out={};i=i+1
  while true do
   local c=s:sub(i,i)
   if c=="" then error("bad json string") end
   if c=='"' then i=i+1;break end
   if c=="\\" then
    local n=s:sub(i+1,i+1)
    local map={n="\n",r="\r",t="\t",['"']='"',["\\"]="\\",["/"]="/",b="\b",f="\f"}
    if n=="u" then out[#out+1]=string.char(tonumber(s:sub(i+2,i+5),16)%256);i=i+6
    else out[#out+1]=map[n] or n;i=i+2 end
   else out[#out+1]=c;i=i+1 end
  end
  return table.concat(out)
 end
 function value()
  ws();local c=s:sub(i,i)
  if c=="{" then
   local t={};i=i+1;ws()
   if s:sub(i,i)=="}" then i=i+1;return t end
   while true do
    ws();local k=str();ws();assert(s:sub(i,i)==":","json :");i=i+1
    local v=value();t[tonumber(k) or k]=v;ws()
    local d=s:sub(i,i);i=i+1
    if d=="}" then break end;assert(d==",","json ,")
   end
   return t
  elseif c=="[" then
   local t={};i=i+1;ws()
   if s:sub(i,i)=="]" then i=i+1;return t end
   while true do t[#t+1]=value();ws();local d=s:sub(i,i);i=i+1;if d=="]" then break end;assert(d==",","json ,") end
   return t
  elseif c=='"' then return str()
  elseif s:sub(i,i+3)=="true" then i=i+4;return true
  elseif s:sub(i,i+4)=="false" then i=i+5;return false
  elseif s:sub(i,i+3)=="null" then i=i+4;return nil
  else local num=s:match("^-?%d+%.?%d*[eE]?[-+]?%d*",i);assert(num and #num>0,"json value at "..i);i=i+#num;return tonumber(num) end
 end
 return value()
end
util={}
function util.TableToJSON(t,pretty) local out={};encode(t,out,pretty);return table.concat(out) end
function util.JSONToTable(s) if type(s)~="string" or s=="" then return nil end;local ok,r=pcall(decode,s);if ok and type(r)=="table" then return r end end
function util.Compress(s) return "Z:"..s end
function util.Decompress(s) if type(s)=="string" and s:sub(1,2)=="Z:" then return s:sub(3) end end
function util.CRC(s) local h=0;for i=1,#s do h=(h*31+s:byte(i))%4294967296 end;return tostring(h) end
function util.AddNetworkString(name) M.netStrings=M.netStrings or {};M.netStrings[name]=true end
function util.IsValidModel(m) return type(m)=="string" and m:sub(-4)==".mdl" end
function util.IsInWorld() return true end
function util.PointContents() return 0 end
function util.Effect(name,data) M.effects=(M.effects or 0)+1 end
function EffectData()
 local d={};local m={__index=function(_,k) if k:sub(1,3)=="Set" then return function() end end;if k:sub(1,3)=="Get" then return function() return 0 end end end}
 return setmetatable(d,m)
end
function util.ScreenShake() end
-- Плоская земля на z=0.
function util.TraceLine(t)
 local s,e=t.start,t.endpos
 local res={Hit=false,StartSolid=false,HitSky=false,HitWorld=false,HitPos=e,HitNormal=Vector(0,0,0),Fraction=1,Entity=NULL}
 if s.z<0 then res.StartSolid=true;res.Hit=true;res.HitPos=s;return res end
 if e.z<=0 and s.z>=0 then
  local f=s.z/(s.z-e.z);res.Hit=true;res.HitWorld=true;res.Fraction=f
  res.HitPos=Vector(s.x+(e.x-s.x)*f,s.y+(e.y-s.y)*f,0);res.HitNormal=Vector(0,0,1);res.Entity=M.world
 end
 return res
end
function util.TraceHull(t) return {Hit=false,StartSolid=false,AllSolid=false,HitPos=t.endpos,Fraction=1,Entity=NULL} end
bit=require("bit")
-- utf8 (Lua 5.3 в GMod) — достаточно для подсчёта и обрезки строк интерфейса.
utf8=utf8 or {}
utf8.charpattern="[%z\1-\127\194-\244][\128-\191]*"
function utf8.len(s) local n=0;for _ in tostring(s):gmatch(utf8.charpattern) do n=n+1 end;return n end
function utf8.sub(s,i,j) local out={};local k=0;j=j or -1;local len=utf8.len(s);if j<0 then j=len+j+1 end
 for ch in tostring(s):gmatch(utf8.charpattern) do k=k+1;if k>=i and k<=j then out[#out+1]=ch end end;return table.concat(out) end
function utf8.codes(s) local i=0;local chars={};for ch in tostring(s):gmatch(utf8.charpattern) do chars[#chars+1]=ch end
 return function() i=i+1;if chars[i] then return i,chars[i]:byte() end end end

--[[ Консольные переменные и команды ]]
local convars={}
local CV={};CV.__index=CV
function CV:GetString() return tostring(self.value) end
function CV:GetInt() return math.floor(tonumber(self.value) or 0) end
function CV:GetFloat() return tonumber(self.value) or 0 end
function CV:GetBool() return (tonumber(self.value) or 0)~=0 end
function CV:SetString(v) self.value=v end
function CV:GetName() return self.name end
function CreateConVar(name,default) convars[name]=convars[name] or setmetatable({name=name,value=default},CV);return convars[name] end
CreateClientConVar=CreateConVar
function GetConVar(name) return convars[name] end
function GetConVarNumber(name) return convars[name] and convars[name]:GetFloat() or 0 end
function RunConsoleCommand(...) M.consoleCommands=M.consoleCommands or {};M.consoleCommands[#M.consoleCommands+1]={...} end
M.commands={}
concommand={Add=function(name,fn) M.commands[name]=fn end,Remove=function(name) M.commands[name]=nil end}
function M.command(ply,name,...) local fn=assert(M.commands[name],"нет команды "..name);return fn(ply,name,{...},table.concat({...}," ")) end
cvars={AddChangeCallback=function() end,GetConVarCallbacks=function() end}
FCVAR_ARCHIVE=128;FCVAR_REPLICATED=8192;FCVAR_NOTIFY=256

--[[ Сеть ]]
net={}
local netReceivers={}
local writes
function net.Start(name) assert(not SERVER or (M.netStrings and M.netStrings[name]),"net.Start без util.AddNetworkString: "..tostring(name));writes={name=name} end
for _,kind in ipairs({"UInt","Int","String","Bool","Float","Data","Entity","Table","Vector","Angle","Color","Double"}) do
 net["Write"..kind]=function(v) if writes then writes[#writes+1]=v end end
 net["Read"..kind]=function() return M.netRead and table.remove(M.netRead,1) end
end
function net.Send(target) M.netSent=M.netSent or {};M.netSent[#M.netSent+1]={name=writes and writes.name,to=target,data=writes};writes=nil end
net.Broadcast=net.Send;net.SendToServer=net.Send;net.SendOmit=net.Send;net.SendPVS=net.Send
function net.Receive(name,fn) netReceivers[name]=fn end
function M.netReceive(name,len,ply,values) M.netRead=values;return netReceivers[name](len,ply) end

--[[ Данные: data/ во временной папке ]]
file={}
local function dataPath(p) return DATA.."/"..p end
local function mkdir(p) os.execute('mkdir -p "'..p..'"') end
local function searchRoots(where)
 if where=="DATA" then return {DATA} end
 local roots={}
 for _,a in ipairs(M.addons) do roots[#roots+1]=where=="LUA" and (a.."/lua") or a end
 return roots
end
function file.Read(p,where) where=where or "DATA";for _,r in ipairs(searchRoots(where)) do local s=readAll(r.."/"..p);if s then return s end end end
function file.Exists(p,where) where=where or "DATA";for _,r in ipairs(searchRoots(where)) do if exists(r.."/"..p) or isDir(r.."/"..p) then return true end end;return false end
function file.Write(p,s) local dir=dataPath(p):match("^(.*)/");if dir then mkdir(dir) end;local f=assert(io.open(dataPath(p),"wb"));f:write(s);f:close() end
function file.Append(p,s) local dir=dataPath(p):match("^(.*)/");if dir then mkdir(dir) end;local f=assert(io.open(dataPath(p),"ab"));f:write(s);f:close() end
function file.Delete(p) os.remove(dataPath(p)) end
function file.CreateDir(p) mkdir(dataPath(p)) end
function file.Rename(a,b) return os.rename(dataPath(a),dataPath(b)) end
function file.IsDir(p,where) for _,r in ipairs(searchRoots(where or "DATA")) do if isDir(r.."/"..p) then return true end end;return false end
function file.Find(pattern,where)
 local dir,mask=pattern:match("^(.*)/([^/]*)$");if not dir then dir,mask="",pattern end
 local lua="^"..mask:gsub("%.","%%."):gsub("%*",".*").."$"
 local files,dirs,seenF,seenD={},{},{},{}
 for _,r in ipairs(searchRoots(where or "DATA")) do
  for _,name in ipairs(listDir(r.."/"..dir)) do
   if name:match(lua) then
    if isDir(r.."/"..dir.."/"..name) then if not seenD[name] then seenD[name]=true;dirs[#dirs+1]=name end
    elseif not seenF[name] then seenF[name]=true;files[#files+1]=name end
   end
  end
 end
 table.sort(files);table.sort(dirs);return files,dirs
end

--[[ SQLite через FFI ]]
ffi.cdef[[
typedef struct sqlite3 sqlite3; typedef struct sqlite3_stmt sqlite3_stmt;
int sqlite3_open(const char*, sqlite3**); const char* sqlite3_errmsg(sqlite3*);
int sqlite3_prepare_v2(sqlite3*, const char*, int, sqlite3_stmt**, const char**);
int sqlite3_step(sqlite3_stmt*); int sqlite3_column_count(sqlite3_stmt*);
const char* sqlite3_column_name(sqlite3_stmt*, int); const unsigned char* sqlite3_column_text(sqlite3_stmt*, int);
int sqlite3_column_type(sqlite3_stmt*, int); int sqlite3_finalize(sqlite3_stmt*);
]]
local okLib,lib=pcall(ffi.load,"sqlite3");if not okLib then lib=ffi.load("libsqlite3.so.0") end
local dbp=ffi.new("sqlite3*[1]");assert(lib.sqlite3_open(":memory:",dbp)==0);local db=dbp[0]
local lastError
sql={}
function sql.Query(q)
 local stmt=ffi.new("sqlite3_stmt*[1]");local tail=ffi.new("const char*[1]")
 local rows=nil;local rest=q
 while rest and rest:match("%S") do
  if lib.sqlite3_prepare_v2(db,rest,#rest,stmt,tail)~=0 then lastError=ffi.string(lib.sqlite3_errmsg(db));return false end
  if stmt[0]==nil then break end
  while true do
   local rc=lib.sqlite3_step(stmt[0])
   if rc==100 then
    rows=rows or {};local row={}
    for c=0,lib.sqlite3_column_count(stmt[0])-1 do
     local name=ffi.string(lib.sqlite3_column_name(stmt[0],c))
     if lib.sqlite3_column_type(stmt[0],c)~=5 then row[name]=ffi.string(lib.sqlite3_column_text(stmt[0],c)) end
    end
    rows[#rows+1]=row
   elseif rc==101 then break
   else lastError=ffi.string(lib.sqlite3_errmsg(db));lib.sqlite3_finalize(stmt[0]);return false end
  end
  lib.sqlite3_finalize(stmt[0])
  rest=tail[0]~=nil and ffi.string(tail[0]) or nil
 end
 return rows
end
function sql.QueryValue(q) local r=sql.Query(q);if r and r[1] then for _,v in pairs(r[1]) do return v end end;return nil end
function sql.SQLStr(s,noQuotes) s=tostring(s):gsub("'","''"):gsub("%z","");if noQuotes then return s end;return "'"..s.."'" end
function sql.LastError() return lastError end
function sql.TableExists(name) return sql.Query("SELECT name FROM sqlite_master WHERE type='table' AND name="..sql.SQLStr(name))~=nil end

--[[ Сущности ]]
M.entities={};local nextIndex=1
local E={}
local ENTMETA={__index=function(self,k)
 local v=rawget(self,"_class_tbl") and self._class_tbl[k];if v~=nil then return v end
 return E[k]
end}
NULL=setmetatable({_valid=false},{__index=function(_,k) if k=="IsValid" then return function() return false end end;return function() end end})
function IsValid(x) return type(x)=="table" and type(x.IsValid)=="function" and x:IsValid()==true end
local function newEntity(class,tbl)
 local e=setmetatable({_class=class,_valid=true,_pos=Vector(0,0,0),_ang=Angle(0,0,0),_nw={},_index=nextIndex,_class_tbl=tbl,_health=0,_maxhealth=100},ENTMETA)
 nextIndex=nextIndex+1;M.entities[#M.entities+1]=e
 if tbl and tbl.SetupDataTables then e:SetupDataTables() end
 return e
end
function E:IsValid() return self._valid end
function E:GetClass() return self._class end
function E:EntIndex() return self._index end
function E:SetPos(v) self._pos=Vector(v) end
function E:GetPos() return Vector(self._pos) end
function E:GetNetworkOrigin() return self:GetPos() end
function E:WorldSpaceCenter() return self._pos+Vector(0,0,self._center or 8) end
function E:NearestPoint() return self:WorldSpaceCenter() end
function E:SetAngles(a) self._ang=a end
function E:GetAngles() return self._ang end
function E:EyeAngles() return self._ang end
function E:Remove() if self._valid then self._valid=false;hook.Run("EntityRemoved",self);if self.OnRemove then self:OnRemove() end end end
function E:Spawn() if self.Initialize and not self._spawned then self._spawned=true;self:Initialize() end;self._spawned=true end
function E:Activate() end
function E:SetModel(m) self._model=m end
function E:GetModel() return self._model end
function E:Health() return self._health end
function E:SetHealth(h) self._health=h end
function E:GetMaxHealth() return self._maxhealth end
function E:SetMaxHealth(h) self._maxhealth=h end
function E:IsPlayer() return false end
function E:IsNPC() return self._class:sub(1,4)=="npc_" end
function E:IsNextBot() return false end
function E:IsRagdoll() return self._class=="prop_ragdoll" end
function E:IsWorld() return self._class=="worldspawn" end
function E:IsDormant() return false end
function E:GetPhysicsObject() return NULL end
function E:GetVelocity() return Vector(0,0,0) end
function E:SetVelocity(v) self._velocity=v end
function E:OBBMins() return Vector(-8,-8,0) end
function E:OBBMaxs() return Vector(8,8,16) end
function E:TakeDamageInfo(d)
 if self.OnTakeDamage then self:OnTakeDamage(d) end
 local blocked=hook.Run("EntityTakeDamage",self,d)
 if blocked==true then return end
 self._health=self._health-d:GetDamage();self._lastDamage=d
 if self._health<=0 and self:IsNPC() and self._valid then hook.Run("OnNPCKilled",self,d:GetAttacker(),d:GetInflictor());self:Remove() end
end
function E:EmitSound(s) M.sounds=(M.sounds or 0)+1 end
function E:StartLoopingSound() return 1 end
function E:StopLoopingSound() end
function E:SetNW2String(k,v) self._nw[k]=v end
E.SetNW2Int=E.SetNW2String;E.SetNW2Float=E.SetNW2String;E.SetNW2Bool=E.SetNW2String;E.SetNW2Entity=E.SetNW2String
E.SetNWString=E.SetNW2String;E.SetNWInt=E.SetNW2String;E.SetNWFloat=E.SetNW2String;E.SetNWBool=E.SetNW2String;E.SetNWEntity=E.SetNW2String
local function nwget(self,k,d) local v=self._nw[k];if v==nil then return d end;return v end
E.GetNW2String=nwget;E.GetNW2Int=nwget;E.GetNW2Float=nwget;E.GetNW2Bool=nwget;E.GetNW2Entity=function(s,k,d) return nwget(s,k,d or NULL) end
E.GetNWString=nwget;E.GetNWInt=nwget;E.GetNWFloat=nwget;E.GetNWBool=nwget;E.GetNWEntity=E.GetNW2Entity
function E:NetworkVar(kind,slot,name)
 local defaults={String="",Int=0,Float=0,Bool=false,Entity=NULL,Vector=Vector(0,0,0),Angle=Angle(0,0,0)}
 local key="_nv_"..name;self[key]=defaults[kind]
 self["Set"..name]=function(s,v) s[key]=v end
 self["Get"..name]=function(s) return s[key] end
end
for _,name in ipairs({"SetSolid","SetMoveType","SetCollisionGroup","SetCollisionBounds","SetUseType","DrawShadow","SetNoDraw","SetColor","SetMaterial","SetSkin",
 "SetBodygroup","PhysicsInit","SetRenderBounds","ResetSequence","SetKeyValue","SetShouldServerRagdoll","SetPreventTransmit","SetNotSolid","SetupBones",
 "NextThink","SetOwner","Fire","Input","SetParent","SetRenderMode","SetModelScale","SetTrigger","DeleteOnRemove","Ignite","Extinguish","SetRenderOrigin","SetRenderAngles","ManipulateBoneScale","DrawModel"}) do
 E[name]=E[name] or function() end
end
function E:LookupSequence() return 1 end
function E:LookupBone() return 1 end
function E:LookupAttachment() return 0 end
function E:GetSkin() return 0 end
function E:GetMaterial() return "" end
function E:GetColor() return Color(255,255,255) end
function E:GetBodyGroups() return {} end
function E:GetBodygroup() return 0 end
function E:GetMoveType() return self._movetype or 2 end
function E:GetPhysicsObjectCount() return 0 end
function E:GetOwner() return NULL end

M.world=newEntity("worldspawn");M.world.IsWorld=function() return true end
game={}
function game.GetWorld() return M.world end
function game.GetMap() return "gm_test" end
function game.CleanUpMap() for _,e in ipairs(M.entities) do if e._valid and not e:IsPlayer() and e~=M.world then e:Remove() end end;hook.Run("PostCleanupMap") end
function game.SinglePlayer() return false end
function game.MaxPlayers() return 32 end
engine={ActiveGamemode=function() return "darkrp" end}

scripted_ents={registered={}}
function scripted_ents.Register(tbl,class) scripted_ents.registered[class]=tbl end
function scripted_ents.Get(class) return scripted_ents.registered[class] end
ents={}
function ents.Create(class)
 local tbl=scripted_ents.registered[class]
 if not tbl and not class:match("^npc_") and not class:match("^prop_") and not class:match("^weapon_") and class~="env_fire" then M.warn("ents.Create неизвестного класса "..class) end
 local e=newEntity(class,tbl)
 if class:match("^npc_") then e._health=50;e._maxhealth=50;e._center=36 end
 return e
end
function ents.GetAll() local out={};for _,e in ipairs(M.entities) do if e._valid then out[#out+1]=e end end;return out end
function ents.FindByClass(class)
 local pat="^"..class:gsub("%*",".*").."$";local out={}
 for _,e in ipairs(M.entities) do if e._valid and e._class:match(pat) then out[#out+1]=e end end
 return out
end
function ents.FindInSphere(pos,r) local out={};for _,e in ipairs(M.entities) do if e._valid and e:GetPos():DistToSqr(pos)<=r*r then out[#out+1]=e end end;return out end
function Entity(i) for _,e in ipairs(M.entities) do if e._index==i and e._valid then return e end end;return NULL end

--[[ Урон ]]
local D={};D.__index=D
function DamageInfo() return setmetatable({_dmg=0,_type=0,_attacker=NULL,_inflictor=NULL},D) end
function D:SetDamage(v) self._dmg=v end
function D:GetDamage() return self._dmg end
function D:ScaleDamage(k) self._dmg=self._dmg*k end
function D:SetDamageType(t) self._type=t end
function D:GetDamageType() return self._type end
function D:IsDamageType(t) return bit.band(self._type,t)~=0 end
function D:SetAttacker(a) self._attacker=a end
function D:GetAttacker() return self._attacker end
function D:SetInflictor(a) self._inflictor=a end
function D:GetInflictor() return self._inflictor end
for _,n in ipairs({"SetDamagePosition","SetDamageForce","AddDamage"}) do D[n]=function() end end
function D:GetDamagePosition() return Vector(0,0,0) end
function D:GetDamageForce() return Vector(0,0,0) end
DMG_GENERIC=0;DMG_CRUSH=1;DMG_BULLET=2;DMG_SLASH=4;DMG_BURN=8;DMG_VEHICLE=16;DMG_FALL=32;DMG_BLAST=64;DMG_CLUB=128;DMG_SHOCK=256
DMG_SONIC=512;DMG_ENERGYBEAM=1024;DMG_DROWN=16384;DMG_PARALYZE=32768;DMG_NERVEGAS=65536;DMG_POISON=131072;DMG_RADIATION=262144
DMG_ACID=1048576;DMG_SLOWBURN=2097152;DMG_PLASMA=16777216;DMG_BUCKSHOT=536870912;DMG_DISSOLVE=67108864
HITGROUP_HEAD=1;HITGROUP_GENERIC=0
MOVETYPE_NONE=0;MOVETYPE_WALK=2;MOVETYPE_NOCLIP=8;MOVETYPE_VPHYSICS=6;OBS_MODE_NONE=0
SOLID_NONE=0;SOLID_BBOX=2;SOLID_VPHYSICS=6;SIMPLE_USE=3;COLLISION_GROUP_WEAPON=11;COLLISION_GROUP_IN_VEHICLE=10;COLLISION_GROUP_DEBRIS=1
MASK_SOLID=33570827;MASK_SOLID_BRUSHONLY=16395;MASK_PLAYERSOLID=33636363;MASK_NPCSOLID=33701899;MASK_VISIBLE=24705;MASK_SHOT=1174421507
CONTENTS_WATER=32;TRANSMIT_PVS=2;TRANSMIT_ALWAYS=0;IN_USE=32;CHAN_AUTO=0
RENDERGROUP_TRANSLUCENT=2;RENDERGROUP_OPAQUE=0;RENDERGROUP_BOTH=9
HUD_PRINTCONSOLE=2;HUD_PRINTTALK=3;NOTIFY_GENERIC=0;NOTIFY_ERROR=1
for i=0,9 do _G["KEY_"..i]=i+1 end
KEY_TAB=67;KEY_F6=97;KEY_F7=98;KEY_LALT=81;KEY_ESCAPE=70;KEY_SPACE=65;KEY_ENTER=64;MOUSE_LEFT=107;MOUSE_RIGHT=108
TEXT_ALIGN_LEFT=0;TEXT_ALIGN_CENTER=1;TEXT_ALIGN_RIGHT=2;TEXT_ALIGN_TOP=3;TEXT_ALIGN_BOTTOM=4
BOX_FRONT=0;TOP=4;LEFT=1;RIGHT=2;BOTTOM=5;FILL=3

--[[ Игроки ]]
M.players={}
local P={}
for k,v in pairs(E) do P[k]=v end
local PMETA={__index=function(self,k) local v=P[k];if v~=nil then return v end;return M.playerMeta[k] end}
M.playerMeta={}
function FindMetaTable(name)
 if name=="Player" then return M.playerMeta end
 if name=="Entity" then return E end
 if name=="Vector" then return V end
 return {}
end
local nextSID=0
function M.addPlayer(opts)
 opts=opts or {}
 nextSID=nextSID+1
 local p=setmetatable({_class="player",_valid=true,_pos=opts.pos or Vector(0,0,0),_ang=Angle(0,0,0),_nw={},_index=nextIndex,_health=100,_maxhealth=100,_armor=0,
  _alive=true,_sid=tostring(opts.sid or string.format("7656119800%07d",nextSID)),_nick=opts.nick or ("Сталкер"..#M.players),_admin=opts.admin,_super=opts.superadmin,_ammo={},_weapons={},_chat={},_money=opts.money or 3000,
  _team=1,_god=false,_aim=opts.aim or Vector(100,0,0)},PMETA)
 nextIndex=nextIndex+1;M.players[#M.players+1]=p;M.entities[#M.entities+1]=p
 return p
end
function M.removePlayer(p) for i,x in ipairs(M.players) do if x==p then table.remove(M.players,i) end end;p._valid=false end
function P:IsPlayer() return true end
function P:IsNPC() return false end
function P:IsBot() return false end
function P:SteamID64() return self._sid end
function P:SteamID() return "STEAM_0:0:"..self._sid:sub(-6) end
function P:UniqueID() return self._sid end
function P:Nick() return self._nick end
P.Name=P.Nick;P.GetName=P.Nick
function P:Alive() return self._alive end
function P:IsSuperAdmin() return self._super==true end
function P:IsAdmin() return self._super==true or self._admin==true end
function P:GetUserGroup() return self._super and "superadmin" or self._admin and "admin" or "user" end
function P:Armor() return self._armor end
function P:SetArmor(v) self._armor=v end
function P:ChatPrint(s) self._chat[#self._chat+1]=s end
P.PrintMessage=function(self,_,s) self._chat[#self._chat+1]=s end
function P:GetShootPos() return self._pos+Vector(0,0,64) end
function P:EyePos() return self._pos+Vector(0,0,64) end
function P:WorldSpaceCenter() return self._pos+Vector(0,0,36) end
function P:GetAimVector() return (self._aim-self:EyePos()):GetNormalized() end
function P:GetEyeTrace() local tr=util.TraceLine({start=self._aim+Vector(0,0,10),endpos=self._aim-Vector(0,0,10)});tr.Entity=self._aimEntity or tr.Entity;return tr end
function P:GiveAmmo(n,kind) self._ammo[kind]=(self._ammo[kind] or 0)+n;return n end
function P:GetAmmoCount(kind) return self._ammo[kind] or 0 end
function P:SetAmmo(n,kind) self._ammo[kind]=n end
function P:RemoveAllAmmo() self._ammo={} end
function P:Give(class,noAmmo)
 if self._weapons[class] and self._weapons[class]._valid then return NULL end
 local w=newEntity(class);w._clip1=0;w._owner=self
 w.Clip1=function(s) return s._clip1 end;w.Clip2=function() return 0 end;w.SetClip1=function(s,v) s._clip1=v end;w.SetClip2=function() end
 w.GetPrimaryAmmoType=function() return 1 end;w.GetSecondaryAmmoType=function() return -1 end
 self._weapons[class]=w;return w
end
function P:HasWeapon(class) return self._weapons[class]~=nil and self._weapons[class]._valid end
function P:GetWeapon(class) return self._weapons[class] or NULL end
function P:GetWeapons() local out={};for _,w in pairs(self._weapons) do if w._valid then out[#out+1]=w end end;return out end
function P:StripWeapons() for _,w in pairs(self._weapons) do w:Remove() end;self._weapons={} end
function P:SelectWeapon(c) self._active=c end
function P:GetActiveWeapon() return self._active and self._weapons[self._active] or NULL end
function P:Team() return self._team end
function P:KeyDown(key) return self._keys~=nil and self._keys[key]==true end
function P:SetKey(key,down) self._keys=self._keys or {};self._keys[key]=down or nil end
function P:GetMoveType() return self._movetype or MOVETYPE_WALK end
function P:SetMoveType(m) self._movetype=m end
function P:GetObserverMode() return OBS_MODE_NONE end
function P:InVehicle() return false end
function P:HasGodMode() return self._god end
function P:GodEnable() self._god=true end
function P:GodDisable() self._god=false end
function P:Freeze() end
function P:Ping() return 30 end
function P:ExitVehicle() end
function P:ConCommand(c) self._concommands=(self._concommands or "")..c..";" end
function P:ViewPunch() end
function P:SetLocalVelocity() end
function P:GetHull() return Vector(-16,-16,0),Vector(16,16,72) end
function P:Kick(reason) self._kicked=reason end
function P:GetInfo() return "ru" end
function P:DrawViewModel() end
function P:DrawWorldModel() end
function P:SetupHands() end
function P:Kill() self._health=0;M.kill(self) end
function P:getDarkRPVar(k) if k=="money" then return self._money end;if k=="job" then return "Сталкер" end end
function P:addMoney(n) self._money=self._money+n end
function P:setSelfDarkRPVar() end
function P:TakeDamageInfo(d)
 hook.Run("ScalePlayerDamage",self,self._hitgroup or HITGROUP_GENERIC,d)
 local blocked=hook.Run("EntityTakeDamage",self,d)
 if blocked==true then return end
 hook.Call("HandlePlayerArmorReduction",GAMEMODE,self,d)
 self._health=self._health-d:GetDamage();self._lastDamage=d
 if self._health<=0 and self._alive then M.kill(self,d:GetAttacker()) end
end
-- Как в базовом режиме GMod: броня поглощает 80% урона, кроме падения, утопления, яда и радиации.
function GAMEMODE:HandlePlayerArmorReduction(ply,dmginfo)
 if ply:Armor()<=0 or bit.band(dmginfo:GetDamageType(),DMG_FALL+DMG_DROWN+DMG_POISON+DMG_RADIATION)~=0 then return end
 local new=dmginfo:GetDamage()*.2;local armor=dmginfo:GetDamage()-new
 if armor>ply:Armor() then armor=ply:Armor();new=dmginfo:GetDamage()-armor;ply:SetArmor(0) else ply:SetArmor(ply:Armor()-armor) end
 dmginfo:SetDamage(new)
end
function M.kill(p,attacker)
 attacker=attacker or M.world
 hook.Run("DoPlayerDeath",p,attacker,DamageInfo())
 p._alive=false;p:StripWeapons()
 hook.Run("PlayerDeath",p,attacker,attacker)
end
function M.spawn(p)
 p._alive=true;p._health=100;p._armor=0;p:StripWeapons()
 hook.Run("PlayerSpawn",p)
end
player={}
function player.GetAll() local out={};for _,p in ipairs(M.players) do if p._valid then out[#out+1]=p end end;return out end
player.GetHumans=player.GetAll
function player.GetBySteamID64(id) for _,p in ipairs(M.players) do if p._sid==id then return p end end;return false end
function player.GetCount() return #M.players end
player_manager={SetPlayerClass=function() end,RunClass=function() end,AddValidModel=function() end,TranslatePlayerModel=function(m) return m end}
team={GetColor=function() return Color(255,255,255) end,GetName=function() return "Сталкер" end,NumPlayers=function() return 0 end}

resource={AddFile=function(p)
 local ok=false;for _,a in ipairs(M.addons) do if exists(a.."/"..p) then ok=true end end
 if not ok then M.warn("resource.AddFile: файл не найден в аддонах: "..p) end
end,AddWorkshop=function() end,AddSingleFile=function(p) end}

--[[ include / AddCSLuaFile ]]
local stack={}
local function resolve(path)
 local cur=stack[#stack]
 if cur then
  local dir=cur:match("^(.*)/")
  if dir and exists(dir.."/"..path) then return dir.."/"..path end
 end
 for _,a in ipairs(M.addons) do if exists(a.."/lua/"..path) then return a.."/lua/"..path end end
end
M.resolve=resolve
function include(path)
 local full=resolve(path)
 if not full then error("include: файл не найден: "..path,2) end
 M.files[full]=true
 local fn,err=loadfile(full);if not fn then error(err,2) end
 stack[#stack+1]=full
 local r={xpcall(fn,debug.traceback)}
 stack[#stack]=nil
 if not r[1] then error(r[2],0) end
 return unpack(r,2)
end
function AddCSLuaFile(path)
 if path==nil then return end
 if not resolve(path) then M.warn("AddCSLuaFile: файл не найден: "..path.." (из "..tostring(stack[#stack])..")") end
end
function M.loadFile(full,label)
 stack[#stack+1]=full;M.files[full]=true
 local fn,err=loadfile(full)
 local ok,e
 if not fn then ok,e=false,err else ok,e=xpcall(fn,debug.traceback) end
 stack[#stack]=nil
 if not ok then M.errors[#M.errors+1]=(label or full)..": "..tostring(e) end
 return ok
end

--[[ Загрузка autorun и сущностей как в GMod ]]
function M.loadAutorun()
 local list={}
 for _,a in ipairs(M.addons) do
  for _,name in ipairs(listDir(a.."/lua/autorun")) do if name:match("%.lua$") then list[#list+1]={name=name,path=a.."/lua/autorun/"..name} end end
  local sub=SERVER and "server" or "client"
  for _,name in ipairs(listDir(a.."/lua/autorun/"..sub)) do if name:match("%.lua$") then list[#list+1]={name=name,path=a.."/lua/autorun/"..sub.."/"..name} end end
 end
 table.sort(list,function(x,y) return x.name<y.name end)
 for _,f in ipairs(list) do M.loadFile(f.path,"autorun/"..f.name) end
end
function M.loadEntities()
 for _,a in ipairs(M.addons) do
  for _,class in ipairs(listDir(a.."/lua/entities")) do
   local dir=a.."/lua/entities/"..class
   ENT={ClassName=class,Folder="entities/"..class}
   local main=SERVER and dir.."/init.lua" or dir.."/cl_init.lua"
   if exists(main) then M.loadFile(main,"entities/"..class) elseif exists(dir.."/shared.lua") then M.loadFile(dir.."/shared.lua","entities/"..class) end
   scripted_ents.Register(ENT,class);ENT=nil
  end
 end
end

--[[ Клиентские библиотеки: разрешающая заглушка (любой вызов возвращает заглушку) ]]
local stubMeta={}
local function stub(name) return setmetatable({_stub=name},stubMeta) end
stubMeta.__index=function(self,k) local v=stub(self._stub.."."..tostring(k));rawset(self,k,v);return v end
stubMeta.__call=function(self,...) return stub(self._stub.."()") end
stubMeta.__add=function(a) return a end;stubMeta.__sub=stubMeta.__add;stubMeta.__mul=stubMeta.__add;stubMeta.__div=stubMeta.__add
stubMeta.__concat=function() return "" end;stubMeta.__lt=function() return false end;stubMeta.__le=function() return false end
M.stub=stub
function M.clientLibs()
 for _,name in ipairs({"surface","draw","render","cam","input","gui","cookie","notification","language","system","spawnmenu","list","killicon","matproxy","halo","effects","sound","chat","derma","menubar","properties","search","steamworks","physenv","video","mesh"}) do
  _G[name]=stub(name)
 end
 -- Зарегистрированные панели создаются по-настоящему: их методы выполняются, базовые методы Derma — заглушки.
 local function makePanel(name)
  local tbl=M.panels and M.panels[name]
  local base=stub("panel:"..tostring(name))
  if not tbl then return base end
  local obj=setmetatable({},{__index=function(_,k) local v=tbl[k];if v~=nil then return v end;return base[k] end})
  obj.GetWide=function() return 900 end;obj.GetTall=function() return 600 end;obj.IsValid=function() return true end
  if obj.Init then M.protect("panel "..name..":Init",obj.Init,obj) end
  return obj
 end
 vgui={Register=function(name,tbl,base) M.panels=M.panels or {};M.panels[name]=tbl;return tbl end,Create=makePanel,GetKeyboardFocus=function() return NULL end,CreateFromTable=function() return stub("panel") end}
 function Material(path) return stub("Material("..tostring(path)..")") end
 function ParticleEmitter() return stub("emitter") end
 function DynamicLight() return stub("light") end
 function ScrW() return 1920 end
 function ScrH() return 1080 end
 function Derma_Query() end
 function Derma_Message() end
 function Derma_Anim() return stub("anim") end
 function Derma_StringRequest() end
 function DermaMenu() return stub("menu") end
 function ClientsideModel() return stub("csmodel") end
 function CreateSound() return stub("sound") end
 function DrawColorModify() end
 function DrawMotionBlur() end
 function DrawToyTown() end
 function DrawBloom() end
 function DrawSharpen() end
 function EyePos() return Vector(0,0,64) end
 function EyeAngles() return Angle(0,0,0) end
 function AddOriginToPVS() end
 surface.GetTextSize=function() return 10,10 end
 cookie.GetNumber=function() return 0 end
 cookie.GetString=function() return "" end
 input.IsKeyDown=function() return false end
 input.IsMouseDown=function() return false end
 input.LookupBinding=function() return "e" end
 gui.IsGameUIVisible=function() return false end
 gui.IsConsoleVisible=function() return false end
 gui.MouseX=function() return 0 end
 gui.MouseY=function() return 0 end
 local lp=M.addPlayer({nick="Клиент"})
 function LocalPlayer() return lp end
 M.localPlayer=lp
end

--[[ Учёт обращений к неизвестным глобальным именам ]]
function M.trackGlobals()
 setmetatable(_G,{__index=function(_,k) M.globalsRead[k]=(M.globalsRead[k] or 0)+1 end})
end

return M
