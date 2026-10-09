local B=STALKER_BUTCHERING
function B.InventoryReady(p)
 local S=STALKER_INV
 return S and S.DatabaseReady and S.CVBackend:GetString()~='json' and p:GetInventory() and not p.StalkerLoadError
end
-- Добыча и её удаление из очереди — одна SQLite-транзакция, как в NPC Trade.
-- Commit/GiveItem не сообщают надёжный результат записи и здесь не подходят.
function B.Claim(p)
 if not B.InventoryReady(p) or p.StnpcTrading or (STALKER_NPC and STALKER_NPC.Busy) or B.Outbox[p:SteamID64()] then return false,'Хранилище занято или недоступно' end
 local S=STALKER_INV;local id=p:SteamID64()
 local rows=B.Query('SELECT id,payload FROM stb_rewards WHERE steamid='..sql.SQLStr(id)..' LIMIT 32')
 if rows==false then return false,'Ошибка хранилища' end
 if not rows then return true,'Нет неполученной добычи' end
 S.CaptureEquipment(p);local original=p:GetInventory();local inv=table.Copy(original);local accepted={}
 for _,row in ipairs(rows) do
  local r=util.JSONToTable(row.payload)
  if type(r)~='table' or not S.IsInt(r.count,0,999) then return false,'Повреждена очередь добычи' end
  local nextInv=inv
  if r.count>0 then nextInv=S.Insert(inv,r.id,r.count,r.durability) end
  if nextInv and (r.count==0 or S.Weight(nextInv)<=B.Config.MaxWeight) then inv=nextInv;accepted[#accepted+1]=row.id end
 end
 if #accepted==0 then return false,'Освободите рюкзак или уменьшите вес. Добыча сохранена: stb_claim' end
 inv.revision=(original.revision+1)%4294967296
 S.SaveStamp=math.max((S.SaveStamp or 0)+1,os.time()*1000)
 local saved=table.Copy(inv);saved.savedAt=S.SaveStamp
 if B.Query('BEGIN IMMEDIATE')==false then return false,'Ошибка хранилища' end
 local ok=B.Query('REPLACE INTO stalker_inventory (steamid,payload) VALUES('..sql.SQLStr(id)..','..sql.SQLStr(util.TableToJSON(saved))..')')~=false
 for _,key in ipairs(accepted) do if B.Query('DELETE FROM stb_rewards WHERE id='..sql.SQLStr(key)..' AND steamid='..sql.SQLStr(id))==false then ok=false end end
 if not ok or B.Query('COMMIT')==false then B.Query('ROLLBACK');return false,'Ошибка сохранения; добыча остаётся в очереди' end
 p.StalkerInventory=inv;p:SetNW2Float('stalker_inv_weight',S.Weight(inv))
 S.SaveInventory(p);S.Sync(p,'Добыча получена')
 return true,'Получено результатов: '..#accepted
end
function B.Tool(p)
 local w=p:GetActiveWeapon();if not IsValid(w) then return end
 local cfg=B.Config.Tools[w:GetClass()];if cfg then return w,cfg end
end
function B.Wear(p,w,cfg)
 local S=STALKER_INV;if not S or not p:GetInventory() then return end
 -- Износ сохраняется только для SWEP, который принадлежит существующему инвентарю.
 for uid,owned in pairs(p.StalkerWeapons or {}) do if owned==w then
  S.CaptureEquipment(p);local inv=table.Copy(p:GetInventory());local item=S.FindUID(inv,uid)
  if item then item.durability=math.max(0,item.durability-cfg.wear);S.Commit(p,inv) end
  return
 end end
end
for _,event in ipairs({'STALKER_INV_CanAction','STALKER_INV_CanPickup','STNPC_CanTrade','CanPlayerEnterVehicle'}) do
 hook.Add(event,'STB.Busy',function(p) if B.Sessions and B.Sessions[p] then return false end end)
end
concommand.Add('stb_claim',function(p)
 if not IsValid(p) or not p:Alive() or B.Unconscious(p) or (B.Sessions and B.Sessions[p]) then return end
 if (p.StbClaimAfter or 0)>CurTime() then return end;p.StbClaimAfter=CurTime()+1
 local _,msg=B.Claim(p);p:ChatPrint('[Разделка] '..msg)
end)
