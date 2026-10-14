-- STALKER Core: общие контракты сборки. Сеть, права, частота запросов, мелкие помощники.
STALKER_CORE=STALKER_CORE or {}
local C=STALKER_CORE
C.Version="2.0.0"
C.MaxPacket=63000

function C.Int(v,lo,hi) return type(v)=="number" and v==v and v%1==0 and v>=lo and v<=hi end
function C.Num(v,lo,hi) return type(v)=="number" and v==v and v>-math.huge and v<math.huge and v>=lo and v<=hi end
function C.Str(v,maxBytes) return type(v)=="string" and #v>0 and #v<=(maxBytes or 128) and not v:find("[%c]") end

-- SteamID64 живого игрока или nil (боты и локальный сервер без Steam не сохраняются).
function C.SID(ply)
 if not IsValid(ply) or not ply:IsPlayer() or ply:IsBot() then return end
 local id=ply:SteamID64();if id and id:match("^%d+$") and id~="0" then return id end
end
function C.PlayerBySID(sid)
 for _,p in ipairs(player.GetHumans()) do if p:SteamID64()==sid then return p end end
end

-- Группировка игрока из сетевых переменных STALKER Factions (nil — не состоит).
function C.Faction(ply)
 if not IsValid(ply) or not ply:GetNW2Bool("stfw_joined",false) then return end
 local id=ply:GetNW2String("stfw_faction","");if id~="" then return id end
end
function C.FactionName(id)
 if STFW and STFW.Name and id then return STFW.Name(id) end
 return id and tostring(id) or "Одиночки"
end
function C.FactionColor(id)
 local f=STFW and STFW.Factions and STFW.Factions[id or ""]
 if f and f.color then return Color(f.color[1],f.color[2],f.color[3]) end
 return Color(181,159,94)
end

-- Сжатый JSON по сети: единый формат для новых аддонов.
function C.Pack(tbl)
 local raw=util.TableToJSON(tbl or {});if not raw then return end
 local data=util.Compress(raw);if data and #data<=C.MaxPacket then return data end
end
-- SERVER: target — игрок, список или nil (всем). CLIENT: отправка серверу.
function C.Send(name,target,tbl)
 local data=C.Pack(tbl);if not data then return false end
 net.Start(name);net.WriteUInt(#data,16);net.WriteData(data,#data)
 if SERVER then if target then net.Send(target) else net.Broadcast() end else net.SendToServer() end
 return true
end
-- Читает пакет C.Send. len — длина сообщения в битах (проверяется, если передана).
function C.Read(len,maxBytes)
 local size=net.ReadUInt(16)
 if size<1 or size>(maxBytes or C.MaxPacket) or (len and len~=16+size*8) then return end
 local raw=util.Decompress(net.ReadData(size) or "")
 if not raw or #raw>1000000 then return end
 local t=util.JSONToTable(raw);if type(t)=="table" then return t end
end

-- Ведро токенов: perSecond восполнение, burst — запас. Ключ разделяет разные действия.
function C.Rate(ply,key,perSecond,burst)
 if not IsValid(ply) then return true end
 ply.StalkerRate=ply.StalkerRate or {}
 local now=CurTime();local b=ply.StalkerRate[key]
 if not b then b={n=burst or 5,t=now};ply.StalkerRate[key]=b end
 b.n=math.min(burst or 5,b.n+(now-b.t)*(perSecond or 2));b.t=now
 if b.n<1 then return false end
 b.n=b.n-1;return true
end

-- Права администрирования: «Комендант» → ULX/CAMI (доступ "stalker_<право>") → суперадмин.
function C.CanAdmin(ply,permission)
 if not IsValid(ply) then return true end
 local A=STALKER_ADMIN
 if A and A.Has and A.Ready then return A.Has(ply,permission)==true end
 if ULib and ULib.ucl and ULib.ucl.query then
  local ok=ULib.ucl.query(ply,"stalker_"..tostring(permission))
  if ok~=nil then return ok==true end
 end
 return ply:IsSuperAdmin()
end

-- Расстояние в метрах (1 unit ≈ 1.905 см).
function C.Meters(units) return units*.01905 end

-- Без сознания после выброса: многие действия должны блокироваться.
function C.Unconscious(ply)
 return type(ST_EMISSION)=="table" and type(ST_EMISSION.IsUnconscious)=="function" and ST_EMISSION.IsUnconscious(ply)==true
end

-- Короткие уведомления на экране (сервер → клиент). kind: info, ok, warn, danger.
if SERVER then
 util.AddNetworkString("stalker_core.notify")
 function C.Notify(target,text,kind,seconds)
  if type(text)~="string" or text=="" then return end
  return C.Send("stalker_core.notify",target,{text=text,kind=kind or "info",seconds=seconds or 6})
 end
end
