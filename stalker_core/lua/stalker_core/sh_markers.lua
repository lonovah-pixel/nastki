-- Метки мира: точки интереса, флаги территорий, маячки, сбитые грузы, цели заданий, координаты тайников.
-- Сервер решает, кому видна метка, и раз в секунду рассылает изменения. Клиент рисует HUD, флаги и карту КПК.
local C=STALKER_CORE
STALKER_MARKERS=STALKER_MARKERS or {}
local M=STALKER_MARKERS
C.Markers=M

-- Типы меток: цвет и поведение по умолчанию (поля конкретной метки важнее).
M.Kinds={
 poi={color=Color(220,200,140),world=false,edge=false,range=4000,label="Точка интереса"},
 flag={color=Color(200,169,81),world=true,edge=false,range=6000,label="Территория"},
 beacon={color=Color(110,200,255),world=true,edge=true,range=12000,label="Маячок"},
 cargo={color=Color(255,140,60),world=true,edge=true,range=30000,label="Сбитый груз"},
 event={color=Color(240,90,70),world=true,edge=true,range=30000,label="Событие"},
 quest={color=Color(250,220,90),world=false,edge=true,range=60000,label="Задание"},
 stash={color=Color(170,140,255),world=true,edge=true,range=20000,label="Тайник"},
 rally={color=Color(120,230,120),world=true,edge=true,range=30000,label="Сбор группировки"},
 enemy={color=Color(230,70,60),world=false,edge=false,range=6000,label="Противник"},
 trader={color=Color(200,169,81),world=false,edge=false,range=3000,label="Торговец"},
}

if SERVER then
 util.AddNetworkString("stalker_markers.sync")
 M.List=M.List or {}
 M.Sent=M.Sent or setmetatable({},{__mode="k"})

 --[[ data:
  pos      — Vector (обязательно)
  label    — подпись; kind — тип из M.Kinds; color — Color; icon — путь материала
  world    — рисовать флажок в мире; edge — показывать стрелку у края экрана; map — на карте КПК (по умолчанию да)
  range    — дальность показа на HUD, units
  visible  — "all" (по умолчанию) или таблица: {players={[sid]=true}, faction="duty", admins=true, check=function(ply) end}
  expires  — CurTime() истечения (nil — бессрочно)
  owner    — SteamID64 владельца (для маячков) ]]
 function M.Set(id,data)
  if type(id)~="string" or type(data)~="table" or not data.pos then return false end
  local m=table.Copy(data);m.id=id
  local p=data.pos;m.pos={x=math.Round(p.x,1),y=math.Round(p.y,1),z=math.Round(p.z,1)}
  local kind=M.Kinds[m.kind or "poi"] or M.Kinds.poi
  m.kind=m.kind or "poi"
  if m.color then m.color={m.color.r,m.color.g,m.color.b} end
  if m.world==nil then m.world=kind.world end
  if m.edge==nil then m.edge=kind.edge end
  if m.map==nil then m.map=true end
  m.range=m.range or kind.range
  m.check=data.visible and data.visible.check or nil
  M.List[id]=m;M.Dirty=true
  return true
 end
 function M.Remove(id) if M.List[id] then M.List[id]=nil;M.Dirty=true end end
 function M.Get(id) return M.List[id] end
 function M.Clear(prefix)
  for id in pairs(M.List) do if not prefix or id:sub(1,#prefix)==prefix then M.List[id]=nil;M.Dirty=true end end
 end

 function M.VisibleTo(m,ply)
  if m.expires and m.expires<CurTime() then return false end
  local v=m.visible
  if v==nil or v=="all" then return true end
  if type(v)~="table" then return false end
  local sid=ply:SteamID64()
  if v.players and v.players[sid] then return true end
  if m.owner==sid then return true end
  if v.faction and C.Faction(ply)==v.faction then return true end
  if v.factions and v.factions[C.Faction(ply) or ""] then return true end
  if v.admins and ply:IsAdmin() then return true end
  if m.check then local ok,res=pcall(m.check,ply);if ok and res then return true end end
  return false
 end

 local function packFor(ply)
  local out={}
  for id,m in pairs(M.List) do
   if M.VisibleTo(m,ply) then
    out[#out+1]={id=id,pos=m.pos,label=m.label,kind=m.kind,color=m.color,icon=m.icon,world=m.world,edge=m.edge,map=m.map,range=m.range,
     expires=m.expires and math.max(0,math.floor(m.expires-CurTime())) or nil,radius=m.radius}
   end
  end
  table.sort(out,function(a,b) return a.id<b.id end)
  return out
 end
 function M.SyncPlayer(ply,force)
  local list=packFor(ply);local raw=util.TableToJSON(list) or ""
  if not force and M.Sent[ply]==raw then return end
  M.Sent[ply]=raw;C.Send("stalker_markers.sync",ply,{list=list})
 end
 timer.Create("STALKER_Markers.Sync",1,0,function()
  local now=CurTime()
  for id,m in pairs(M.List) do if m.expires and m.expires<now then M.List[id]=nil;M.Dirty=true end end
  -- Видимость зависит и от группировки игрока, поэтому сверяем снимок для каждого.
  for _,ply in ipairs(player.GetHumans()) do M.SyncPlayer(ply) end
  M.Dirty=false
 end)
 hook.Add("PlayerInitialSpawn","STALKER_Markers.Sync",function(ply) timer.Simple(2,function() if IsValid(ply) then M.SyncPlayer(ply,true) end end) end)
 hook.Add("PlayerDisconnected","STALKER_Markers.Sync",function(ply) M.Sent[ply]=nil end)
else
 M.Server=M.Server or {}
 M.Local=M.Local or {}
 net.Receive("stalker_markers.sync",function(len)
  local data=C.Read(len);if not data then return end
  local list={}
  for _,m in ipairs(data.list or {}) do
   m.pos=Vector(m.pos.x,m.pos.y,m.pos.z)
   m.color=m.color and Color(m.color[1],m.color[2],m.color[3]) or (M.Kinds[m.kind] or M.Kinds.poi).color
   if m.expires then m.expiresAt=CurTime()+m.expires end
   list[#list+1]=m
  end
  M.Server=list
  hook.Run("STALKER_MarkersUpdated",list)
 end)
 -- Клиентские метки (например, локальные подсказки) с тем же форматом.
 function M.SetLocal(id,data)
  local m=table.Copy(data);m.id=id;m.kind=m.kind or "poi"
  local kind=M.Kinds[m.kind] or M.Kinds.poi
  m.color=m.color or kind.color;if m.world==nil then m.world=kind.world end;if m.edge==nil then m.edge=kind.edge end
  if m.map==nil then m.map=true end;m.range=m.range or kind.range
  M.Local[id]=m
 end
 function M.RemoveLocal(id) M.Local[id]=nil end
 function M.All()
  local out={}
  for _,m in ipairs(M.Server) do if not m.expiresAt or m.expiresAt>CurTime() then out[#out+1]=m end end
  for _,m in pairs(M.Local) do out[#out+1]=m end
  return out
 end
end
