-- Редактор Зоны: поля аномалий и логова мутантов. Доступ — право "zone" («Комендант» → ULX → суперадмин).
-- Тот же канал обслуживает панель «Комендант» → «Зона» (STALKER_ZONE.BuildAdminPanel): каждое действие
-- проверяется здесь, на сервере, независимо от того, какую вкладку открыл клиент.
local Z=STALKER_ZONE
for _,name in ipairs({"state","request","action"}) do util.AddNetworkString("stz."..name) end

function Z.CanEdit(p)
 if not IsValid(p) then return true end
 local C=STALKER_CORE
 if C and C.CanAdmin then return C.CanAdmin(p,Z.Config.EditorPermission or "zone")==true end
 if p:IsSuperAdmin() then return true end
 local A=STALKER_ADMIN
 return A and A.Has and A.Has(p,Z.Config.EditorPermission)==true or false
end

local function rate(p,key)
 local C=STALKER_CORE
 if C and C.Rate then return C.Rate(p,"zone."..key,2,6) end
 local now=CurTime();local b=p.StzBucket or {n=6,t=now};p.StzBucket=b
 b.n=math.min(6,b.n+(now-b.t)*2);b.t=now
 if b.n<1 then return false end;b.n=b.n-1;return true
end

local function entries(kind)
 local list={}
 for id,e in SortedPairs(kind=="field" and Z.World.fields or Z.World.zones) do
  local row=table.Copy(e);row.id=id;row.kind=kind
  if kind=="field" then
   local rt=Z.Runtime.fields[id];local a,b=0,0
   if rt then for _,x in ipairs(rt.anomalies) do if IsValid(x) then a=a+1 end end;for _,x in ipairs(rt.artifacts) do if IsValid(x) then b=b+1 end end end
   row.liveAnomalies,row.liveArtifacts=a,b
  else
   local rt=Z.Runtime.zones[id];local n=0
   if rt then for _,x in ipairs(rt.alive) do if IsValid(x) then n=n+1 end end end
   row.liveMutants=n
  end
  list[#list+1]=row
 end
 return list
end

-- Сводка для редактора, панели «Коменданта» и stz_status.
function Z.Summary()
 return {anomalies=#ents.FindByClass("stalker_anomaly"),artifacts=Z.CountArtifacts(),maxArtifacts=Z.Config.MaxArtifacts,
  mutants=Z.CountMutants and Z.CountMutants() or 0,maxMutants=Z.Config.MaxMutants,
  fields=table.Count(Z.World.fields),zones=table.Count(Z.World.zones),maxFields=Z.Config.MaxFields,maxZones=Z.Config.MaxMutantZones,
  traders=STALKER_NPC~=nil,restock=Z.Config.RestockMinutes,refresh=Z.Config.ArtifactRefreshMinutes,map=game.GetMap()}
end
local function recentErrors(n)
 local out={};local list=Z.Errors or {}
 for i=math.max(1,#list-n+1),#list do local e=list[i];out[#out+1]={t=e.t,source=e.source,text=e.text} end
 return out
end

function Z.SendEditorState(p,reply)
 local state={fields=entries("field"),zones=entries("zone"),ready=Z.WorldReady==true,reply=reply,stats=Z.Summary(),errors=recentErrors(5)}
 local raw=util.TableToJSON(state);local data=raw and util.Compress(raw)
 if not data or #data>60000 then return end
 net.Start("stz.state");net.WriteUInt(#data,16);net.WriteData(data,#data)
 if IsValid(p) then net.Send(p) else
  local list={};for _,v in ipairs(player.GetHumans()) do if v.StzEditing and Z.CanEdit(v) then list[#list+1]=v end end
  if #list>0 then net.Send(list) end
 end
end

local function placement(p,how)
 if how=="feet" then local pos=p:GetPos();if util.IsInWorld(pos) then return pos end;return end
 local tr=p:GetEyeTrace()
 if not tr.Hit or tr.HitSky or tr.HitNormal.z<.5 or p:GetPos():DistToSqr(tr.HitPos)>8192^2 then return end
 return tr.HitPos+tr.HitNormal*4
end
local function newID() return tostring(os.time()).."_"..math.random(10000,99999) end

function Z.EditorAction(p,a)
 if not Z.CanEdit(p) then return false,"Нужны права на редактирование Зоны" end
 local op=a.op
 -- Быстрые действия не меняют файл карты и доступны даже при повреждённом файле.
 if op=="restock" then
  if not STALKER_NPC or not Z.RestockAll then return false,"Торговля (stalker_npc_dialog_trade) не установлена" end
  return true,"Пополнено складов: "..Z.RestockAll()
 elseif op=="mutants_clear" then
  return true,"Убрано мутантов: "..(Z.RemoveMutants and Z.RemoveMutants() or 0)..". Логова заселятся заново по своему интервалу."
 elseif op=="artifacts" then
  return true,"Добавлено артефактов: "..Z.TopUpArtifacts()
 end
 if not Z.WorldReady then return false,"Файл Зоны повреждён: восстановите data/stalker_zone вручную" end
 local kind=a.kind=="zone" and "zone" or "field"
 -- Правка применяется к памяти, но откатывается, если файл не записался.
 local backup=table.Copy(Z.World)
 local store=kind=="field" and Z.World.fields or Z.World.zones
 local limit=kind=="field" and Z.Config.MaxFields or Z.Config.MaxMutantZones
 local id=type(a.id)=="string" and a.id or ""
 local target=store[id]
 if op=="create" then
  if table.Count(store)>=limit then return false,"Достигнут лимит записей" end
  local pos=placement(p,a.placement);if not pos then return false,"Наведите прицел на землю в пределах видимости" end
  a.pos={x=pos.x,y=pos.y,z=pos.z}
  local clean,err=Z.ValidateEntry(kind,a);if not clean then return false,err end
  id=newID();clean.id=id;store[id]=clean
 elseif op=="update" or op=="move" then
  if not target then return false,"Запись не найдена" end
  local merged=table.Copy(target)
  if op=="move" then
   local pos=placement(p,a.placement);if not pos then return false,"Наведите прицел на землю в пределах видимости" end
   merged.pos={x=pos.x,y=pos.y,z=pos.z}
  else for _,key in ipairs({"name","radius","count","artifacts","max","respawn","types"}) do if a[key]~=nil then merged[key]=a[key] end end end
  local clean,err=Z.ValidateEntry(kind,merged);if not clean then return false,err end
  clean.id=id;store[id]=clean
 elseif op=="delete" then
  if not target then return false,"Запись не найдена" end
  store[id]=nil
 elseif op=="regen" then
  if kind=="field" then if target then Z.BuildField(id) else Z.RegenerateAll(false) end
  else Z.ClearMutants(target and id or nil);if Z.InitMutants and not target then Z.InitMutants() elseif Z.Runtime.zones[id] then Z.Runtime.zones[id].next=0 end end
  return true
 elseif op=="goto" then
  if not target then return false,"Запись не найдена" end
  if not IsValid(p) then return false,"Телепорт доступен только игроку" end
  local pos=Z.GroundPoint(Vector(target.pos.x,target.pos.y,target.pos.z),64)
  if not pos then pos=Vector(target.pos.x,target.pos.y,target.pos.z) end
  p:SetPos(pos+Vector(0,0,8));return true,"Телепорт: «"..target.name.."»"
 else return false,"Неизвестное действие" end
 if not Z.SaveWorld() then
  Z.World=backup;Z.ReportError("Редактор Зоны","не удалось записать data/stalker_zone/"..game.GetMap()..".json")
  return false,"Не удалось сохранить data/stalker_zone"
 end
 Z.Log((IsValid(p) and p:SteamID64() or "console").." "..op.." "..kind.." "..id)
 -- Поле перестраивается сразу; логово догоняет численность на следующем такте.
 if kind=="field" then Z.BuildField(id)
 elseif op=="delete" or op=="move" then Z.ClearMutants(id)
 end
 if Z.UpdateMarkers then Z.UpdateMarkers() end
 return true,nil,id
end

net.Receive("stz.request",function(len,p)
 if len~=1 or not rate(p,"request") then return end
 local open=net.ReadBool()
 if not Z.CanEdit(p) then p.StzEditing=nil;return end
 p.StzEditing=open or nil
 if open then Z.SendEditorState(p) end
end)
net.Receive("stz.action",function(len,p)
 if len<16 or len>8192 or not rate(p,"action") or not Z.CanEdit(p) then return end
 local size=net.ReadUInt(16);if size<2 or size>1000 or len~=16+size*8 then return end
 local a=util.JSONToTable(net.ReadData(size));if type(a)~="table" or type(a.op)~="string" then return end
 local ok,err,id=Z.EditorAction(p,a)
 local text=ok and (err or "Готово") or err or "Действие недоступно"
 p:ChatPrint("[Редактор Зоны] "..text)
 Z.SendEditorState(p,{ok=ok==true,id=id,error=ok and nil or err,message=text,op=a.op})
 for _,v in ipairs(player.GetHumans()) do if v~=p and v.StzEditing then Z.SendEditorState(v) end end
end)

hook.Add("PlayerSay","STALKER_ZONE.Chat",function(p,text)
 local cmd=string.lower(string.Trim(text))
 if cmd=="!zone" or cmd=="/zone" then if Z.CanEdit(p) then p:ConCommand("stz_editor") end;return "" end
 if cmd=="!help" or cmd=="!помощь" or cmd=="/помощь" or cmd=="!guide" or cmd=="!памятка" then p:ConCommand("stz_help");return "" end
end)
concommand.Add("stz_regen",function(p)
 if not Z.CanEdit(p) then return end
 Z.RegenerateAll(false);local msg="[STALKER Zone] Аномалии и артефакты перестроены"
 if IsValid(p) then p:ChatPrint(msg) else print(msg) end
end)

--[[ stz_status: сводка Зоны и последние ошибки (консоль сервера или администратор с правом zone). ]]
function Z.StatusLines()
 local s=Z.Summary();local lines={}
 local function add(text) lines[#lines+1]=text end
 add("[STALKER Zone] Карта "..s.map..": файл "..(Z.WorldReady and "в порядке" or "ПОВРЕЖДЁН — редактор заблокирован")..".")
 add(string.format("Поля аномалий: %d / %d · аномалий %d · артефактов %d / %d · досыпка %s",s.fields,s.maxFields,s.anomalies,s.artifacts,s.maxArtifacts,
  s.refresh>0 and ("каждые "..s.refresh.." мин.") or "только после выброса"))
 add(string.format("Логова: %d / %d · мутантов %d / %d",s.zones,s.maxZones,s.mutants,s.maxMutants))
 add("Торговцы: "..(s.traders and (s.restock>0 and ("восполнение каждые "..s.restock.." мин.") or "автовосполнение выключено") or "аддон торговли не установлен")..
  " · урон аномалий ×"..tostring(Z.Config.AnomalyDamageScale))
 local errs=Z.Errors or {}
 if #errs==0 then add("Ошибок нет.") else
  add("Последние ошибки ("..#errs.."):")
  for i=math.max(1,#errs-9),#errs do local e=errs[i];add("  "..os.date("%d.%m %H:%M:%S",e.t).." · "..e.source..": "..e.text) end
 end
 return lines
end
concommand.Add("stz_status",function(p)
 if IsValid(p) and not Z.CanEdit(p) then p:ChatPrint("[STALKER Zone] Нужно право zone");return end
 for _,line in ipairs(Z.StatusLines()) do if IsValid(p) then p:PrintMessage(HUD_PRINTCONSOLE,line) else print(line) end end
 if IsValid(p) then p:ChatPrint("[STALKER Zone] Сводка Зоны выведена в консоль") end
end)
