-- Сеть редактора радиационных зон. Клиент шлёт stalker_rad.request {op,…}, сервер отвечает снимком stalker_rad.state.
-- Каждое действие проверяется здесь: частота, право radiation, допустимость полей. Клиенту не доверяем.
local R=STALKER_RAD
local C=STALKER_CORE
if not C or not C.Send or not C.Read then return end
util.AddNetworkString("stalker_rad.request")
util.AddNetworkString("stalker_rad.state")
-- Администраторы с открытой панелью получают снимок после любой правки (в том числе чужой).
R.Watchers=R.Watchers or {}

function R.Snapshot(result)
 return {zones=R.Zones,ready=R.Ready==true,error=R.LoadError,limit=R.Config.ZonesLimit,map=game.GetMap(),revision=R.Revision,migrated=R.Migrated,result=result}
end
function R.SendState(p,result) return C.Send("stalker_rad.state",p,R.Snapshot(result)) end

local function str(v,max) return type(v)=="string" and #v<=(max or 64) and v or nil end
-- Только поля формы: позицию через update не передать, для неё есть move.
local function formFields(a)
 local out={name=type(a.name)=="string" and a.name or nil,radius=tonumber(a.radius),rate=tonumber(a.rate)}
 if type(a.falloff)=="boolean" then out.falloff=a.falloff end
 if type(a.enabled)=="boolean" then out.enabled=a.enabled end
 return out
end
local placements={aim=true,feet=true}

local ops={}
ops.list=function(p) R.Watchers[p]=true;return true end
ops.close=function(p) R.Watchers[p]=nil;return true end
ops.create=function(p,a)
 if not placements[a.placement] then return false,"Неизвестный способ установки" end
 local pos,err=R.PlacementPos(p,a.placement);if not pos then return false,err end
 local data=formFields(a);data.pos=pos
 local id,e=R.AddZone(data);if not id then return false,e end
 return true,"Зона «"..R.ByID[id].name.."» создана",id
end
ops.update=function(p,a)
 local id=str(a.id,32);local z=R.GetZone(id);if not z then return false,"Зона не найдена" end
 local ok,err=R.UpdateZone(id,formFields(a));if not ok then return false,err end
 return true,"Зона «"..R.ByID[id].name.."» сохранена",id
end
ops.move=function(p,a)
 local id=str(a.id,32);local z=R.GetZone(id);if not z then return false,"Зона не найдена" end
 if not placements[a.placement] then return false,"Неизвестный способ установки" end
 local pos,err=R.PlacementPos(p,a.placement);if not pos then return false,err end
 local ok,e=R.UpdateZone(id,{pos=pos});if not ok then return false,e end
 return true,"Зона «"..z.name.."» перемещена",id
end
ops.remove=function(p,a)
 local id=str(a.id,32);local z=R.GetZone(id);if not z then return false,"Зона не найдена" end
 local ok,err=R.RemoveZone(id);if not ok then return false,err end
 return true,"Зона «"..z.name.."» удалена"
end
ops.teleport=function(p,a)
 local id=str(a.id,32);local z=R.GetZone(id);if not z then return false,"Зона не найдена" end
 local ok,err=R.TeleportTo(p,id);if not ok then return false,err end
 return true,"Вы у зоны «"..z.name.."»",id
end
-- Перечитать файл после ручного исправления (кнопка появляется, когда правка заблокирована).
ops.reload=function()
 local ok=R.Load()
 hook.Run("STALKER_RadZonesChanged","reload")
 return ok,ok and ("Файл зон перечитан: "..#R.Zones.." зон") or ("Файл зон всё ещё с ошибкой: "..tostring(R.LoadError))
end
-- Действия, которые меняют мир или игрока, пишутся в журнал «Коменданта».
local audited={create=true,update=true,move=true,remove=true,teleport=true,reload=true}

-- Выполнение запроса администратора: → ok, сообщение, id зоны.
function R.AdminAction(p,a)
 if not IsValid(p) or not C.CanAdmin(p,"radiation") then return false,"Нет права radiation" end
 if type(a)~="table" or type(a.op)~="string" or not ops[a.op] then return false,"Неизвестное действие" end
 R.Actor=p
 local ok,msg,id=ops[a.op](p,a)
 R.Actor=nil
 if audited[a.op] then R.Audit(p,a.op,id or str(a.id,32) or "",msg or "",ok) end
 return ok==true,msg,id
end

net.Receive("stalker_rad.request",function(len,p)
 if not IsValid(p) or not C.Rate(p,"rad.admin",4,10) then return end
 if not C.CanAdmin(p,"radiation") then
  R.Watchers[p]=nil
  C.Send("stalker_rad.state",p,{denied=true,result={ok=false,message="Нет права radiation"}})
  return
 end
 local a=C.Read(len,2000);if not a or type(a.op)~="string" then return end
 local ok,msg,id=R.AdminAction(p,a)
 if a.op=="close" then return end
 -- Список — без строки результата, чтобы не затирать сообщение о последнем действии.
 R.SendState(p,(a.op~="list" or not ok) and {op=a.op,ok=ok,message=msg,id=id} or nil)
end)

-- Правка из любого источника (панель, консоль, API) рассылается остальным открытым панелям.
hook.Add("STALKER_RadZonesChanged","STALKER.RadWatchers",function()
 for p in pairs(R.Watchers) do
  if not IsValid(p) or not C.CanAdmin(p,"radiation") then R.Watchers[p]=nil
  elseif p~=R.Actor then R.SendState(p) end
 end
end)
hook.Add("PlayerDisconnected","STALKER.RadWatchers",function(p) R.Watchers[p]=nil end)
