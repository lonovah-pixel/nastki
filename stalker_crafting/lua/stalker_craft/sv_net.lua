-- Сеть: окно мастерской и костра, ремонт, админ-панель (право craft). Клиенту не доверяем ничего, кроме выбора:
-- станцию, ингредиенты, место в рюкзаке и дистанцию сервер проверяет сам.
local CR=STALKER_CRAFT
local C=STALKER_CORE
local Cfg=CR.Config

-- E по верстаку или костру: открыть окно на нужной вкладке.
function CR.UseStation(ply,ent,mode)
 if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not IsValid(ent) then return end
 if not C.Rate(ply,"craft.use",2,3) then return end
 if ply:GetShootPos():DistToSqr(ent:WorldSpaceCenter())>(Cfg.StationRange+60)^2 then return end
 if mode=="cook" and ent.IsLit and not ent:IsLit() then C.Notify(ply,"Костёр погас","warn",3);return end
 C.Send("stalker_craft.open",ply,{mode=mode})
end

net.Receive("stalker_craft.start",function(len,ply)
 if not C.Rate(ply,"craft.start",2,4) then return end
 local a=C.Read(len,300);if type(a)~="table" or not C.Str(a.id,32) then return end
 local ok,err=CR.Start(ply,a.id,C.Int(a.count,1,50) and a.count or 1)
 if not ok and err then C.Notify(ply,err,"warn",5) end
end)
net.Receive("stalker_craft.cancel",function(len,ply)
 if not C.Rate(ply,"craft.cancel",2,4) then return end
 CR.Cancel(ply,"Работа отменена")
end)
net.Receive("stalker_craft.repair",function(len,ply)
 if not C.Rate(ply,"craft.repair",1,3) then return end
 local a=C.Read(len,300);if type(a)~="table" or not C.Str(a.kit,32) or not C.Str(a.slot,32) then return end
 local ok,err=CR.Repair(ply,a.kit,a.slot)
 if not ok and err then C.Notify(ply,err,"warn",5) end
end)

--[[ Админ-панель: верстаки, постоянные костры, походные костры игроков ]]
local function vec3(v) return {x=math.Round(v.x),y=math.Round(v.y),z=math.Round(v.z)} end
function CR.AimPos(ply)
 local start=ply:EyePos()
 local tr=util.TraceLine({start=start,endpos=start+ply:GetAimVector()*4000,filter=ply,mask=MASK_SOLID})
 if not tr.Hit or tr.HitSky or tr.HitNormal.z<.6 then return end
 return tr.HitPos
end
function CR.AdminSnapshot()
 local benches,fires,temp={},{},{}
 for id,p in SortedPairs(CR.World.benches) do benches[#benches+1]={id=id,pos=p.pos} end
 for id,p in SortedPairs(CR.World.fires) do fires[#fires+1]={id=id,pos=p.pos,style=p.style} end
 for _,e in ipairs(CR.TempFires()) do temp[#temp+1]={owner=e:GetOwnerName(),left=math.floor(e:TimeLeft() or 0),pos=vec3(e:GetPos())} end
 local jobs=0;for _ in pairs(CR.Jobs) do jobs=jobs+1 end
 return {benches=benches,fires=fires,temp=temp,jobs=jobs,broken=CR.WorldBroken==true,maxBenches=Cfg.MaxBenches,maxFires=Cfg.MaxFires,path="data/"..CR.WorldPath}
end
local function who(ply) return IsValid(ply) and (ply:Nick().." ("..tostring(ply:SteamID64())..")") or "консоль" end
local function nextID(prefix) CR.World.seq=(CR.World.seq or 0)+1;return prefix..CR.World.seq end
local function addPlace(ply,kind,style)
 local pos=CR.AimPos(ply);if not pos then return false,"Наведите прицел на ровную землю" end
 -- Повёрнут к администратору: стол стоит «лицом» к тому, кто его поставил.
 local dir=ply:GetPos()-pos;local yaw=math.Round(math.deg(math.atan2(dir.y,dir.x)))
 local place=CR.CleanPlace(kind,{pos=vec3(pos),yaw=yaw,style=style});if not place then return false,"Некорректное место" end
 local limit=kind=="benches" and Cfg.MaxBenches or Cfg.MaxFires
 return CR.EditWorld(function(w)
  if table.Count(w[kind])>=limit then return false,"Достигнут лимит: "..limit end
  for _,p in pairs(w[kind]) do
   if Vector(p.pos.x,p.pos.y,p.pos.z):DistToSqr(pos)<48*48 then return false,"Здесь уже стоит "..(kind=="benches" and "верстак" or "костёр") end
  end
  place.id=nextID(kind=="benches" and "b" or "f");w[kind][place.id]=place;return true
 end)
end
-- Операции панели: fn(ply, a) → ok, "сообщение".
CR.AdminOps={
 state=function() return true end,
 bench_add=function(ply)
  local ok,err=addPlace(ply,"benches")
  if ok then ServerLog("[STALKER Crafting] "..who(ply).." поставил верстак\n") end
  return ok,ok and "Верстак поставлен и сохранён" or err
 end,
 fire_add=function(ply,a)
  local style=CR.FireStyles[a.style or ""] and a.style or "ring"
  local ok,err=addPlace(ply,"fires",style)
  if ok then ServerLog("[STALKER Crafting] "..who(ply).." поставил постоянный костёр\n") end
  return ok,ok and (CR.FireStyles[style].." поставлен и сохранён") or err
 end,
 remove=function(ply,a)
  local kind=a.kind=="fires" and "fires" or a.kind=="benches" and "benches" or nil
  if not kind or type(a.id)~="string" or not CR.World[kind][a.id] then return false,"Место не найдено" end
  local ok,err=CR.EditWorld(function(w) w[kind][a.id]=nil;return true end)
  if ok then ServerLog("[STALKER Crafting] "..who(ply).." убрал "..kind.." "..a.id.."\n") end
  return ok,ok and (kind=="benches" and "Верстак убран" or "Костёр потушен и убран") or err
 end,
 -- Перейти к месту (администратор встаёт рядом).
 go=function(ply,a)
  local kind=a.kind=="fires" and "fires" or "benches"
  local p=type(a.id)=="string" and CR.World[kind][a.id];if not p then return false,"Место не найдено" end
  ply:SetPos(Vector(p.pos.x+60,p.pos.y,p.pos.z+4))
  return true,"Вы у места"
 end,
 -- Временные метки всех мест для этого администратора (2 минуты), даже если метки на карте выключены.
 show=function(ply)
  local sid=ply:SteamID64();local n=0
  STALKER_MARKERS.Clear("stcraft.show."..sid..".")
  for _,kind in ipairs({"benches","fires"}) do
   for id,p in pairs(CR.World[kind]) do
    n=n+1
    STALKER_MARKERS.Set("stcraft.show."..sid.."."..id,{pos=Vector(p.pos.x,p.pos.y,p.pos.z),kind="poi",label=kind=="benches" and "Верстак" or (CR.FireStyles[p.style] or "Костёр"),
     world=true,edge=true,visible={players={[sid]=true}},expires=CurTime()+120})
   end
  end
  return true,n>0 and ("Показано мест: "..n.." (2 минуты)") or "Верстаков и постоянных костров пока нет"
 end,
 -- Потушить все походные костры игроков.
 clear_temp=function(ply)
  local n=0;for _,e in ipairs(CR.TempFires()) do e:Remove();n=n+1 end
  return true,n>0 and ("Потушено походных костров: "..n) or "Походных костров нет"
 end,
}
net.Receive("stalker_craft.admin",function(len,ply)
 if not C.Rate(ply,"craft.admin",3,8) then return end
 local a=C.Read(len,2000);if type(a)~="table" or type(a.op)~="string" or not CR.AdminOps[a.op] then return end
 if not C.CanAdmin(ply,"craft") then C.Send("stalker_craft.admin",ply,{denied=true});return end
 local ok,res,msg=pcall(CR.AdminOps[a.op],ply,a)
 if not ok then ErrorNoHalt("[STALKER Crafting] admin "..a.op..": "..tostring(res).."\n");res,msg=false,"Ошибка операции" end
 local out=CR.AdminSnapshot()
 if a.op~="state" then out.result={op=a.op,ok=res~=false,message=msg} end
 C.Send("stalker_craft.admin",ply,out)
end)

-- Чат: !craft — мастерская, !craftadmin — управление верстаками и кострами (право craft).
hook.Add("PlayerSay","STALKER_CRAFT.Chat",function(ply,text)
 local t=string.Trim(tostring(text or "")):lower()
 if t=="!craft" or t=="/craft" then ply:ConCommand("stcraft_menu");return "" end
 if t=="!craftadmin" or t=="/craftadmin" then if C.CanAdmin(ply,"craft") then ply:ConCommand("stcraft_admin") end;return "" end
end)
-- Консоль сервера и RCON: список мест.
concommand.Add("stcraft_list",function(ply)
 if IsValid(ply) and not C.CanAdmin(ply,"craft") then return end
 local function out(s) if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE,s) else print(s) end end
 for _,kind in ipairs({"benches","fires"}) do
  for id,p in SortedPairs(CR.World[kind]) do out(kind.." "..id..": "..p.pos.x.." "..p.pos.y.." "..p.pos.z..(p.style and (" ("..p.style..")") or "")) end
 end
 out("Походных костров: "..#CR.TempFires().."; работ в процессе: "..table.Count(CR.Jobs))
end)
