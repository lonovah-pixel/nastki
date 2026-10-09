local S=STALKER_INV
function S.CaptureEquipment(ply)
    local inv=ply.StalkerInventory;if not inv then return end
    for uid,wep in pairs(ply.StalkerWeapons or {}) do
        local item=S.FindUID(inv,uid)
        if item and IsValid(wep) then item.clip1=wep:Clip1();item.clip2=wep:Clip2() end
    end
    if ply.StalkerArmorUID then
        local item=S.FindUID(inv,ply.StalkerArmorUID)
        if item then item.armor=math.min(item.armor or 0,math.max(0,ply:Armor()-(ply.StalkerBaseArmor or 0))) end
    end
end
function S.ApplyEquipment(ply)
    local inv=ply.StalkerInventory;if not inv then return end
    ply.StalkerWeapons=ply.StalkerWeapons or {}
    local wanted={}
    for _,item in pairs(inv.equipment) do if S.Items[item.id].weapon and item.durability>0 then wanted[item.uid]=item end end
    for uid,wep in pairs(ply.StalkerWeapons) do
        if not wanted[uid] then if IsValid(wep) then wep:Remove() end;ply.StalkerWeapons[uid]=nil end
    end
    for uid,item in pairs(wanted) do
        local d=S.Items[item.id]
        if not IsValid(ply.StalkerWeapons[uid]) and not ply:HasWeapon(d.weapon) then
            local wep=ply:Give(d.weapon,true)
            if IsValid(wep) then
                wep.StalkerManaged=true;wep.StalkerOwner=ply
                wep:SetClip1(item.clip1 or 0);wep:SetClip2(item.clip2 or 0)
                ply.StalkerWeapons[uid]=wep
            end
        end
    end
    local armor=inv.equipment.armor;local uid=armor and armor.uid
    if uid~=ply.StalkerArmorUID then
        if ply.StalkerArmorUID then ply:SetArmor(math.min(ply:Armor(),ply.StalkerBaseArmor or 0)) end
        ply.StalkerArmorUID=uid;ply.StalkerBaseArmor=ply:Armor()
        if armor then ply:SetArmor(ply:Armor()+(armor.armor or 0)) end
    end
    inv.radiation=0
    for _,item in pairs(inv.equipment) do inv.radiation=inv.radiation+(S.Items[item.id].stats.radiation or 0) end
    hook.Run("STALKER_INV_EquipmentChanged",ply,inv.equipment)
end
function S.Commit(ply,inv,message)
    S.CleanQuickbar(inv);inv.revision=((ply.StalkerInventory and ply.StalkerInventory.revision or 0)+1)%4294967296
    ply.StalkerInventory=inv;ply:SetNW2Float("stalker_inv_weight",S.Weight(inv))
    S.ApplyEquipment(ply)
    if not S.SaveInventory(ply) then message="Ошибка сохранения: обратитесь к администратору" end
    S.Sync(ply,message)
end
function S.LoadPlayer(ply)
    if ply.StalkerInventory or ply.StalkerLoadError then return end
    local inv,fresh,err=S.LoadInventory(ply)
    if not inv then ply.StalkerLoadError=err;ply:ChatPrint(err);return end
    if fresh and S.CVStarter:GetBool() and not (DarkRP and S.Config.DarkRP.DisableStarter) then
        for _,v in ipairs(S.Config.Starter) do local nextInv=S.Insert(inv,v[1],v[2]);if nextInv then inv=nextInv end end
        for i=1,4 do if inv.grid[i] then inv.quickbar[i]=inv.grid[i].uid end end
    end
    ply.StalkerInventory=inv;S.Commit(ply,inv)
end
-- Серверный API: атомарное добавление всех единиц или отказ.
function S.GiveItem(ply,id,count)
    if not IsValid(ply) or not ply:IsPlayer() or ply.StalkerLoadError then return false,"Игрок не готов" end
    S.LoadPlayer(ply);if not ply.StalkerInventory then return false,"Нет инвентаря" end
    S.CaptureEquipment(ply)
    local inv,err=S.Insert(ply.StalkerInventory,id,count or 1)
    if not inv then return false,err end
    S.Commit(ply,inv);return true
end
function S.HandleAction(ply,action,zone,index,to,ti)
    S.CaptureEquipment(ply)
    local inv=table.Copy(ply.StalkerInventory)
    local item,realZone,realIndex
    if zone=="quickbar" then item,realZone,realIndex=S.GetAt(inv,zone,index)
    else item=inv[zone][index];realZone=zone;realIndex=index end
    local d=S.Items[item.id]
    local ok,err=false,"Действие недоступно"
    if action=="move" then
        -- Не выдаём второй экземпляр SWEP одного класса и не заменяем оружие другого аддона.
        if to=="equipment" and d.weapon then
            for _,other in pairs(inv.equipment) do
                if other.uid~=item.uid and S.Items[other.id].weapon==d.weapon then S.Sync(ply,"Это оружие уже экипировано");return end
            end
            local wep=ply:GetWeapon(d.weapon)
            if IsValid(wep) and not wep.StalkerManaged then S.Sync(ply,"Такое оружие уже выдано игровым режимом");return end
        end
        ok,err=S.Move(inv,zone,index,to,ti)
    elseif action=="unbind" and zone=="quickbar" then inv.quickbar[index]=nil;ok=true
    elseif action=="use" then
        if d.weapon and realZone=="equipment" then
            local w=ply.StalkerWeapons and ply.StalkerWeapons[item.uid]
            if IsValid(w) then ply:SelectWeapon(d.weapon);ok=true else err="Оружие недоступно или занято игровым режимом" end
        elseif d.OnUse then
            local success,result,reason=pcall(d.OnUse,ply,item,inv,d)
            if not success then ErrorNoHalt("[STALKER Inventory] OnUse: "..tostring(result).."\n");err="Ошибка обработчика предмета"
            elseif result then item.count=item.count-1;if item.count<=0 then inv[realZone][realIndex]=nil end;ok=true
            else err=reason or err end
        else
            for _,e in ipairs(S.Config.Equipment) do
                if e.category==d.category and not inv.equipment[e.id] then
                    if d.weapon and ply:HasWeapon(d.weapon) then err="Такое оружие уже есть у игрока";break end
                    ok,err=S.Move(inv,realZone,realIndex,"equipment",e.id);break
                end
            end
        end
    elseif action=="drop" then
        local start=ply:GetShootPos()
        local tr=util.TraceHull({start=start,endpos=start+ply:GetAimVector()*70,
            mins=Vector(-10,-10,-10),maxs=Vector(10,10,10),filter=ply,mask=MASK_SOLID})
        if tr.StartSolid then err="Недостаточно места для выброса"
        else
            local ent=ents.Create("stalker_inv_drop")
            if IsValid(ent) then
                ent.Item=table.Copy(item);ent:SetPos(tr.HitPos);ent:Spawn();ent:SetItemTitle(d.name)
                ent.PickupAfter=CurTime()+.6;ent:Activate()
                inv[realZone][realIndex]=nil;ok=true
            end
        end
    elseif action=="disassemble" and S.Config.AllowDisassemble and d.salvage then
        inv[realZone][realIndex]=nil;ok=true
        for id,n in pairs(d.salvage) do
            local nextInv,reason=S.Insert(inv,id,n*item.count)
            if not nextInv then ok=false;err=reason;break end
            inv=nextInv
        end
    end
    if ok then S.Commit(ply,inv) else S.Sync(ply,err) end
end
function S.Pickup(ply,ent)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not ent.Item or ent.Busy or
        ply:GetShootPos():DistToSqr(ent:GetPos())>150*150 or (ent.PickupAfter or 0)>CurTime() then return end
    S.LoadPlayer(ply);if not ply.StalkerInventory or ply.StalkerLoadError then return end
    if hook.Run("STALKER_INV_CanPickup",ply,ent,ent.Item)==false then return end
    S.CaptureEquipment(ply)
    local inv=table.Copy(ply.StalkerInventory);local empty
    -- Выброшенный стак сохраняет UID, износ, магазин и броню без пересоздания.
    for i=1,40 do if not inv.grid[i] then empty=i;break end end
    if not empty then ply:ChatPrint("Нужна свободная ячейка для подбора");return end
    if S.FindUID(inv,ent.Item.uid) then return end
    ent.Busy=true;inv.grid[empty]=table.Copy(ent.Item);ent.Item=nil;ent:Remove();S.Commit(ply,inv)
end
hook.Add("PlayerInitialSpawn","STALKER_INV.Load",function(ply) S.LoadPlayer(ply) end)
hook.Add("PlayerSpawn","STALKER_INV.Equip",function(ply)
    timer.Simple(0,function()
        if not IsValid(ply) then return end
        S.LoadPlayer(ply);ply.StalkerArmorUID=nil;ply.StalkerBaseArmor=nil
        S.ApplyEquipment(ply);S.Sync(ply)
    end)
end)
hook.Add("DoPlayerDeath","STALKER_INV.CaptureDeath",function(ply)
    S.CaptureEquipment(ply)
    -- Нативный дроп SWEP не должен создавать копию предмета.
    for _,w in pairs(ply.StalkerWeapons or {}) do if IsValid(w) then w:Remove() end end
    ply.StalkerWeapons={};S.SaveInventory(ply)
end)
hook.Add("PlayerDroppedWeapon","STALKER_INV.NoDuplicate",function(ply,wep)
    if IsValid(wep) and wep.StalkerManaged then S.CaptureEquipment(ply);wep:Remove() end
end)
hook.Add("PlayerCanPickupWeapon","STALKER_INV.ManagedWeapon",function(ply,wep)
    if wep.StalkerManaged then return false end
end)
hook.Add("PlayerDisconnected","STALKER_INV.Save",function(ply) S.SaveInventory(ply) end)
hook.Add("ShutDown","STALKER_INV.SaveAll",function() for _,ply in ipairs(player.GetAll()) do S.SaveInventory(ply) end end)
timer.Create("STALKER_INV.Autosave",S.Config.Autosave,0,function()
    for _,ply in ipairs(player.GetAll()) do if ply.StalkerInventory then S.SaveInventory(ply) end end
end)
-- Небольшая автономная модель потребностей. DarkRP hunger не изменяется.
timer.Create("STALKER_INV.Needs",60,0,function()
    for _,ply in ipairs(player.GetAll()) do if ply:Alive() and ply.StalkerInventory and not ply.StalkerLoadError then
        S.CaptureEquipment(ply);local inv=table.Copy(ply.StalkerInventory)
        local energy=S.Config.DarkRP.UseHunger and ply.getDarkRPVar and ply:getDarkRPVar("Energy")
        inv.hunger=type(energy)=="number" and math.Clamp(energy,0,100) or math.max(0,inv.hunger-.5);inv.thirst=math.max(0,inv.thirst-.8);S.Commit(ply,inv)
    end end
end)
concommand.Add("stalker_inv_give",function(ply,_,args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local target=IsValid(ply) and ply or nil
    if args[3] then for _,p in ipairs(player.GetAll()) do if p:SteamID64()==args[3] then target=p;break end end end
    if not IsValid(target) then print("stalker_inv_give <id> <count> <steamid64>");return end
    local ok,err=S.GiveItem(target,args[1] or "",tonumber(args[2]) or 1)
    if not ok then if IsValid(ply) then ply:ChatPrint(err) else print(err) end end
end)
