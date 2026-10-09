local S=STALKER_INV
util.AddNetworkString("stalker_stash.action")
util.AddNetworkString("stalker_stash.open")
local OPS={"create","put","take","delete","move","takeall"}
S.StashEnts=S.StashEnts or {}
local function stashPos(stash) return Vector(stash.pos.x,stash.pos.y,stash.pos.z) end
-- Тайник доступен только на своей карте, в радиусе и без стены между игроком и точкой.
function S.StashReachable(p,stash)
 if not stash or stash.map~=game.GetMap() then return false end
 local pos=stashPos(stash)
 if p:GetPos():DistToSqr(pos)>S.Config.StashRange^2 then return false end
 local tr=util.TraceLine({start=p:EyePos(),endpos=pos+Vector(0,0,8),filter=p,mask=MASK_SOLID_BRUSHONLY})
 return not (tr.Hit and tr.HitPos:DistToSqr(pos)>24^2)
end
-- Сущности тайников: передаются только владельцу, не имеют коллизии.
function S.StashTransmit(ent)
 local owner=ent:GetStashOwner()
 for _,other in ipairs(player.GetAll()) do ent:SetPreventTransmit(other,other~=owner) end
end
function S.RemoveStashEntities(p)
 for _,ent in pairs(S.StashEnts[p] or {}) do if IsValid(ent) then ent:Remove() end end
 S.StashEnts[p]=nil
end
function S.RefreshStashEntities(p)
 if not IsValid(p) then return end
 local list=S.StashEnts[p] or {};S.StashEnts[p]=list
 local stashes=p.StalkerInventory and not p.StalkerLoadError and p.StalkerInventory.stashes or {}
 for id,ent in pairs(list) do
  local stash=stashes[id]
  if not IsValid(ent) or not stash or stash.map~=game.GetMap() then
   if IsValid(ent) then ent:Remove() end;list[id]=nil
  else ent:SetItemCount(table.Count(stash.items)) end
 end
 for id,stash in pairs(stashes) do
  if stash.map==game.GetMap() and not IsValid(list[id]) then
   local ent=ents.Create("stalker_stash")
   if IsValid(ent) then
    ent:SetPos(stashPos(stash));ent:SetStashOwner(p);ent:SetStashID(id);ent:Spawn()
    ent:SetItemCount(table.Count(stash.items));S.StashTransmit(ent);list[id]=ent
   end
  end
 end
end
-- Тайник и рюкзак сохраняются одним payload: нет отдельной базы для второй половины переноса.
function S.StashCommit(p,inv,message)
 local old=p.StalkerInventory
 inv.revision=(old.revision+1)%4294967296;S.CleanQuickbar(inv)
 p.StalkerInventory=inv
 if not S.SaveInventory(p) then p.StalkerInventory=old;return false,"Ошибка сохранения: обратитесь к администратору" end
 p:SetNW2Float("stalker_inv_weight",S.Weight(inv));S.RefreshStashEntities(p);S.Sync(p,message);return true
end
-- Перенос source[index] -> dest[target]. target=0: дозаполнить стаки, затем первая свободная ячейка.
-- Занятая ячейка с другим предметом — обмен местами.
local function transfer(source,index,dest,target,limit)
 local item=source[index];if not item then return false,"Ячейка пуста" end
 local d=S.Items[item.id];if not d then return false end
 if target==0 then
  local changed=false
  if d.stackable then
   for slot=1,limit do local v=dest[slot]
    if v and v~=item and v.id==item.id and v.durability==item.durability and v.count<d.max_stack then
     local n=math.min(item.count,d.max_stack-v.count);v.count=v.count+n;item.count=item.count-n;changed=true
     if item.count==0 then source[index]=nil;return true end
    end
   end
  end
  for slot=1,limit do if not dest[slot] then dest[slot]=item;source[index]=nil;return true end end
  return changed,"Нет свободных ячеек"
 end
 local other=dest[target]
 if other==item then return false end
 if not other then dest[target]=item;source[index]=nil;return true end
 if d.stackable and other.id==item.id and other.durability==item.durability then
  local n=math.min(item.count,d.max_stack-other.count);if n<=0 then return false,"Стак заполнен" end
  other.count=other.count+n;item.count=item.count-n;if item.count==0 then source[index]=nil end;return true
 end
 dest[target],source[index]=item,other;return true
end
local function slot(n,limit,auto) return (auto and n==0) or S.IsInt(n,1,limit) end
function S.StashAction(p,op,id,index,target,revision)
 local inv=p.StalkerInventory
 if not p:Alive() or p.StalkerLoadError or not inv then return false end
 if revision~=inv.revision then return false,"Состояние обновилось. Повторите действие." end
 if S.IsUnconscious(p) then return false,"Вы без сознания" end
 if hook.Run("STALKER_INV_CanStash",p,op,id)==false then return false,"Действие запрещено" end
 S.CaptureEquipment(p);inv=table.Copy(inv);inv.stashes=inv.stashes or {}
 local grid,limit=40,S.Config.StashSlots
 local message
 if op=="create" then
  if table.Count(inv.stashes)>=S.Config.MaxStashes then return false,"Можно иметь не больше "..S.Config.MaxStashes.." тайников" end
  local tr=p:GetEyeTrace()
  if not tr.Hit or tr.HitSky or not tr.HitWorld or tr.HitNormal.z<0.5 or p:GetPos():DistToSqr(tr.HitPos)>S.Config.StashRange^2 then
   return false,"Наведите прицел на ровную поверхность рядом с собой"
  end
  for _,other in pairs(inv.stashes) do
   if other.map==game.GetMap() and stashPos(other):DistToSqr(tr.HitPos)<48^2 then return false,"Слишком близко к другому тайнику" end
  end
  local pos=tr.HitPos
  inv.stashes[S.UID()]={map=game.GetMap(),pos={x=pos.x,y=pos.y,z=pos.z},items={}}
  message="Тайник создан"
 else
  local stash=inv.stashes[id]
  if not stash then return false,"Тайник не найден" end
  if not S.StashReachable(p,stash) then return false,"Тайник вне досягаемости: подойдите ближе" end
  local ok,err=true
  if op=="delete" then
   if next(stash.items) then return false,"Сначала освободите тайник" end
   inv.stashes[id]=nil;message="Тайник удалён"
  elseif op=="put" then
   if not slot(index,grid) or not slot(target,limit,true) then return false end
   ok,err=transfer(inv.grid,index,stash.items,target,limit)
  elseif op=="take" then
   if not slot(index,limit) or not slot(target,grid,true) then return false end
   ok,err=transfer(stash.items,index,inv.grid,target,grid)
  elseif op=="move" then
   if not slot(index,limit) or not slot(target,limit) or index==target then return false end
   ok,err=transfer(stash.items,index,stash.items,target,limit)
  elseif op=="takeall" then
   ok=false
   for i=1,limit do if stash.items[i] and transfer(stash.items,i,inv.grid,0,grid) then ok=true end end
   if next(stash.items) then message="Рюкзак заполнен: забрано не всё" end
   if not ok then err="Рюкзак заполнен" end
  else return false end
  if not ok then return false,err end
 end
 return S.StashCommit(p,inv,message)
end
net.Receive("stalker_stash.action",function(len,p)
 if len<55 or len>1000 or (p.StashNext or 0)>CurTime() then return end
 p.StashNext=CurTime()+0.1
 local op=OPS[net.ReadUInt(3)+1];local revision=net.ReadUInt(32);local id=net.ReadString()
 local index=net.ReadUInt(6);local target=net.ReadUInt(6)
 if not op or #id>96 then return end
 local ok,err=S.StashAction(p,op,id,index,target,revision)
 if not ok then S.Sync(p,err or "Тайник недоступен") end
end)
-- E по своему тайнику открывает окно тайника рядом с рюкзаком.
hook.Add("KeyPress","STALKER_INV.StashUse",function(p,key)
 if key~=IN_USE or not p:Alive() or (p.StashUseNext or 0)>CurTime() then return end
 local ent=S.FindStashInView(p);if not IsValid(ent) then return end
 p.StashUseNext=CurTime()+.5
 local inv=p.StalkerInventory;local stash=inv and inv.stashes and inv.stashes[ent:GetStashID()]
 if not stash or p.StalkerLoadError or S.IsUnconscious(p) then return end
 if not S.StashReachable(p,stash) then p:ChatPrint("Тайник вне досягаемости");return end
 S.Sync(p);net.Start("stalker_stash.open");net.WriteString(ent:GetStashID());net.Send(p)
end)
hook.Add("PlayerInitialSpawn","STALKER_INV.StashTransmit",function(p)
 for _,ent in ipairs(ents.FindByClass("stalker_stash")) do if ent:GetStashOwner()~=p then ent:SetPreventTransmit(p,true) end end
end)
hook.Add("PlayerSpawn","STALKER_INV.StashEnts",function(p)
 timer.Simple(.1,function() if IsValid(p) then S.RefreshStashEntities(p) end end)
end)
hook.Add("PlayerDisconnected","STALKER_INV.StashEnts",S.RemoveStashEntities)
hook.Add("PostCleanupMap","STALKER_INV.StashEnts",function()
 S.StashEnts={}
 for _,p in ipairs(player.GetAll()) do S.RefreshStashEntities(p) end
end)
local function locked(ent) if IsValid(ent) and ent:GetClass()=="stalker_stash" then return false end end
hook.Add("PhysgunPickup","STALKER_INV.StashLock",function(_,ent) return locked(ent) end)
hook.Add("GravGunPickupAllowed","STALKER_INV.StashLock",function(_,ent) return locked(ent) end)
hook.Add("CanProperty","STALKER_INV.StashLock",function(_,_,ent) return locked(ent) end)
hook.Add("CanTool","STALKER_INV.StashLock",function(_,tr) if IsValid(tr.Entity) and tr.Entity:GetClass()=="stalker_stash" then return false end end)

hook.Add("PlayerSay","STALKER.StashChat",function(p,text)
 if string.lower(text)=="!stash" or string.lower(text)=="/stash" then p:ConCommand("stalker_stash");return "" end
end)
