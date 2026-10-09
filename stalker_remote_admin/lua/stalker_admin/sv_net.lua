local A=STALKER_ADMIN
for _,name in ipairs({"request","response"}) do util.AddNetworkString("sta."..name) end
local sequence=0
function A.Reply(p,data)
 if not IsValid(p) then print("[STA] "..(util.TableToJSON(data) or "response"));return end
 local raw=util.TableToJSON(data);if not raw then return end
 local packed=util.Compress(raw);if not packed or #packed>60000 then return end
 net.Start("sta.response");net.WriteUInt(#packed,16);net.WriteData(packed,#packed);net.Send(p)
end
function A.Preflight(p,a)
 if type(a)~="table" or type(a.command)~="string" then return false,"Неверный запрос" end
 local c=A.Commands[a.command]
 if not c or not A.Has(p,c.permission) then return false,"Недостаточный допуск" end
 local valid,err=A.Validate(c,a);if not valid then return false,err end
 local targets={}
 if c.scope=="players" then
  if type(a.targets)~="table" then return false,"Выберите игроков" end
  local count=table.Count(a.targets)
  if count<1 or count>A.Config.MaxTargets or count~=#a.targets then return false,"Выберите от 1 до "..A.Config.MaxTargets.." игроков" end
  if (a.command=="goto" or a.command=="watch") and count~=1 then return false,"Для перехода выберите одного игрока" end
  local seen={}
  for _,sid in ipairs(a.targets) do
   if not A.SID(sid) or seen[sid] then return false,"Некорректная цель" end;seen[sid]=true
   local target=player.GetBySteamID64(sid);local allowed,why=A.CanTarget(p,target,c)
   if not allowed then return false,why end;targets[#targets+1]=target
  end
 end
 if a.command=="role" and IsValid(p) and (a.sid==p:SteamID64() or A.OfflineRank(a.sid)>=A.Rank(p) or A.Config.Roles[a.value].rank>=A.Rank(p)) then return false,"Нельзя выдать или изменить этот допуск" end
 return true,c,targets
end
function A.Execute(p,a)
 local ok,c,targets=A.Preflight(p,a);if not ok then return {kind="result",ok=false,message=c} end
 local results={}
 local function run(target)
  local sid=IsValid(target) and target:SteamID64() or a.sid or (c.scope=="self" and A.Actor(p) or "SERVER")
  local name=IsValid(target) and target:Nick() or sid
  if not A.Audit(p,a.command,sid,util.TableToJSON(a),"attempt") then results[#results+1]={name=name,ok=false,message="Журнал недоступен; действие отменено"};return end
  local called,success,err=pcall(A.Handlers[a.command],p,target,a)
  if not called then ErrorNoHalt("[STA] "..tostring(success).."\n");success=false;err="Ошибка обработчика; проверьте журнал сервера" end
  A.Audit(p,a.command,sid,err or "",success==true and "success" or "failed")
  results[#results+1]={name=name,ok=success==true,message=success==true and "Выполнено" or (err or "Действие отклонено")}
 end
 if c.scope=="players" then for _,target in ipairs(targets) do run(target) end else run(nil) end
 local success=true;for _,r in ipairs(results) do if not r.ok then success=false end end
 return {kind="result",ok=success,results=results,message=success and "Команда выполнена" or "Есть ошибки; см. результаты"}
end
function A.Plan(p,a)
 local ok,c,targets=A.Preflight(p,a);if not ok then A.Reply(p,{kind="result",ok=false,message=c});return end
 if c.danger or #targets>1 then
  sequence=sequence+1
  local token=tostring(sequence)..":"..tostring(math.random(100000,999999))
  p.StaPending={token=token,expires=CurTime()+25,action=table.Copy(a)}
  local names={};for _,t in ipairs(targets) do names[#names+1]=t:Nick().." ["..t:SteamID64().."]" end
  A.Reply(p,{kind="confirm",token=token,label=c.label,targets=names,detail=a.reason or a.value or a.amount or "",minutes=a.minutes,amount=a.amount,sid=a.sid})
 else A.Reply(p,A.Execute(p,a)) end
end
function A.Confirm(p,token)
 local pending=p.StaPending;p.StaPending=nil
 if not pending or type(token)~="string" or token~=pending.token or CurTime()>pending.expires then return {kind="result",ok=false,message="Подтверждение истекло или уже использовано"} end
 return A.Execute(p,pending.action)
end
function A.Snapshot(p)
 local rows={};for _,t in ipairs(player.GetHumans()) do
  A.RememberRank(t)
  local faction=STFW and STFW.Load and STFW.Load(t)
  rows[#rows+1]={sid=t:SteamID64(),name=t:Nick(),role=A.Role(t),rank=A.Rank(t),health=t:Health(),armor=t:Armor(),alive=t:Alive(),ping=t:Ping(),team=team.GetName(t:Team()),faction=faction and faction.faction or "—",frozen=t.StaFrozen==true,god=t.StaGod~=nil,dose=t:GetNW2Float("stalker_dose",0)}
 end
 local permissions={};for id,c in pairs(A.Commands) do permissions[id]=A.Has(p,c.permission) end
 local weapons={};for id in pairs(A.Config.Weapons) do weapons[#weapons+1]={id=id,name=id} end;table.sort(weapons,function(a,b) return a.id<b.id end)
 local items={};if STALKER_INV then for id,item in pairs(STALKER_INV.Items) do items[#items+1]={id=id,name=item.name} end end
 local factions={};if STFW then for id,f in pairs(STFW.Factions) do if f.playable then factions[#factions+1]={id=id,name=STFW.Name(id)} end end end
 local maps={};for _,path in ipairs(file.Find("maps/*.bsp","GAME") or {}) do local id=path:sub(1,-5);if not next(A.Config.Maps) or A.Config.Maps[id] then maps[#maps+1]={id=id,name=id} end end
 local roles={};for id,r in pairs(A.Config.Roles) do if r.rank<A.Rank(p) then roles[#roles+1]={id=id,name=r.label} end end
 A.Reply(p,{kind="state",players=rows,permissions=permissions,role=A.Role(p),map=game.GetMap(),max=game.MaxPlayers(),catalog={weapons=weapons,items=items,factions=factions,maps=maps,roles=roles},integrations={inventory=STALKER_INV~=nil,factions=STFW~=nil,radiation=STALKER_RAD~=nil,emissions=ST_EMISSION~=nil,darkrp=DarkRP~=nil},canLogs=A.Has(p,"logs"),canBans=A.Has(p,"bans")})
end
local function allowed(p)
 local now=CurTime();p.StaBucket=p.StaBucket or {t=now,n=8};local b=p.StaBucket
 b.n=math.min(8,b.n+(now-b.t)*2);b.t=now
 if b.n<1 then return false end;b.n=b.n-1;return true
end
net.Receive("sta.request",function(len,p)
 if len<32 or len>65552 or not allowed(p) then return end
 if not A.Has(p,"view") then A.Reply(p,{kind="denied",message="Нет доступа к админ-панели"});return end
 local size=net.ReadUInt(16);if size<2 or size>8192 or len~=size*8+16 then return end
 local a=util.JSONToTable(net.ReadData(size));if type(a)~="table" then return end
 if a.kind=="state" then A.Snapshot(p)
 elseif a.kind=="execute" then A.Plan(p,a)
 elseif a.kind=="confirm" then A.Reply(p,A.Confirm(p,a.token))
 elseif a.kind=="cancel" then p.StaPending=nil
 elseif a.kind=="logs" or a.kind=="bans" then
  if not A.Has(p,a.kind) or not A.Int(a.page,1,100000) then return end
  local rows=A.Page(a.kind,a.page)
  A.Reply(p,{kind="page",section=a.kind,page=a.page,rows=rows or {},ok=rows~=false})
 end
end)
-- Explicit JSON commands in server console; no arbitrary Lua/OS command execution.
concommand.Add("sta_exec",function(p,_,_,raw)
 if IsValid(p) then return end
 if type(raw)~="string" or #raw>8192 then return end
 local a=util.JSONToTable(raw);A.Reply(p,A.Execute(p,a))
end)
