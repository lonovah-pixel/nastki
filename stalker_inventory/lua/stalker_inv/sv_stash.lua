local S=STALKER_INV
util.AddNetworkString("stalker_stash.action")
-- Тайник и рюкзак сохраняются одним payload: нет отдельной базы для второй половины переноса.
function S.StashCommit(p,inv)
 local old=p.StalkerInventory
 inv.revision=(old.revision+1)%4294967296;S.CleanQuickbar(inv)
 p.StalkerInventory=inv
 if not S.SaveInventory(p) then p.StalkerInventory=old;return false end
 p:SetNW2Float("stalker_inv_weight",S.Weight(inv));S.Sync(p);return true
end
function S.StashAction(p,op,id,index,revision)
 local inv=p.StalkerInventory
 if not p:Alive() or p.StalkerLoadError or not inv or revision~=inv.revision then return false end
 S.CaptureEquipment(p);inv=table.Copy(inv);inv.stashes=inv.stashes or {}
 if op=="create" then
  if table.Count(inv.stashes)>=3 then return false end
  local tr=p:GetEyeTrace()
  if not tr.Hit or tr.HitSky or not tr.HitWorld or tr.HitNormal.z<0.5 or p:GetPos():DistToSqr(tr.HitPos)>150^2 then return false end
  local pos=tr.HitPos
  inv.stashes[S.UID()]={map=game.GetMap(),pos={x=pos.x,y=pos.y,z=pos.z},items={}}
 else
  local stash=inv.stashes[id]
  if not stash or stash.map~=game.GetMap() then return false end
  local pos=Vector(stash.pos.x,stash.pos.y,stash.pos.z)
  if p:GetPos():DistToSqr(pos)>150^2 then return false end
  local tr=util.TraceLine({start=p:EyePos(),endpos=pos+Vector(0,0,8),filter=p})
  if tr.Hit and tr.HitPos:DistToSqr(pos)>24^2 then return false end
  if op=="delete" then if next(stash.items) then return false end;inv.stashes[id]=nil
  else
   if not S.IsInt(index,1,op=="put" and 40 or 20) then return false end
   local source=op=="put" and inv.grid or stash.items
   local dest=op=="put" and stash.items or inv.grid
   local item=source[index];if not item then return false end
   local free;for slot=1,op=="put" and 20 or 40 do if not dest[slot] then free=slot;break end end
   if not free then return false end
   dest[free]=item;source[index]=nil
  end
 end
 return S.StashCommit(p,inv)
end
net.Receive("stalker_stash.action",function(len,p)
 if len<50 or len>1000 or (p.StashNext or 0)>CurTime() then return end
 p.StashNext=CurTime()+0.25
 local op=net.ReadUInt(2);local revision=net.ReadUInt(32);local id=net.ReadString();local index=net.ReadUInt(6)
 if #id>96 then return end
 local ok=S.StashAction(p,({"create","put","take","delete"})[op+1],id,index,revision)
 if not ok then S.Sync(p,"Тайник недоступен: подойдите ближе, проверьте место и свободные ячейки.") end
end)

hook.Add("PlayerSay","STALKER.StashChat",function(p,text)
 if string.lower(text)=="!stash" or string.lower(text)=="/stash" then p:ConCommand("stalker_stash");return "" end
end)
