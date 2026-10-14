local S = STALKER_INV
local function int(v, lo, hi) return type(v)=="number" and v==v and v%1==0 and v>=lo and v<=hi end
S.IsInt = int
function S.EmptyInventory()
    return {version=1, revision=0, grid={}, equipment={}, quickbar={}, hunger=100, thirst=100, radiation=0, dose=0, stashes={}}
end
function S.ValidLocation(zone, index)
    if zone=="grid" then return int(index,1,40) end
    if zone=="quickbar" then return int(index,1,9) end
    return zone=="equipment" and S.EquipmentByID[index]~=nil
end
function S.FindUID(inv, uid)
    for _,zone in ipairs({"grid","equipment"}) do
        for k,v in pairs(inv[zone]) do if v.uid==uid then return v,zone,k end end
    end
end
function S.GetAt(inv, zone, index)
    if not inv or not S.ValidLocation(zone,index) then return end
    if zone=="quickbar" then return S.FindUID(inv, inv.quickbar[index]) end
    return inv[zone][index]
end
function S.CanPlace(item, zone, index)
    if not item then return true end
    if zone=="grid" then return true end
    local d=S.Items[item.id]
    return zone=="equipment" and d and S.EquipmentByID[index].category==d.category and item.count==1
end
function S.Weight(inv)
    local n=0
    for _,zone in ipairs({"grid","equipment"}) do
        for _,item in pairs(inv[zone]) do local d=S.Items[item.id]; if d then n=n+d.weight*item.count end end
    end
    return n
end
function S.CleanQuickbar(inv)
    for k,uid in pairs(inv.quickbar) do if not S.FindUID(inv,uid) then inv.quickbar[k]=nil end end
end
function S.UID() return tostring(os.time()).."_"..tostring(math.random(100000,999999)).."_"..tostring(SysTime()):gsub("%.","") end
function S.NewItem(id,count,durability)
    local d=S.Items[id]
    return {id=id,uid=S.UID(),count=count or 1,durability=durability or d.durability,
        clip1=d.clip1 or 0,clip2=d.clip2 or 0,armor=d.stats.armor or 0}
end
-- Добавление в копию: при нехватке места исходный инвентарь не меняется.
function S.Insert(inv,id,count,durability)
    local d=S.Items[id]
    if not d or not int(count,1,999) then return false,"Неизвестный предмет или количество" end
    local copy=table.Copy(inv)
    durability=durability or d.durability
    if d.stackable then
        for i=1,40 do local v=copy.grid[i]
            if v and v.id==id and v.durability==durability then
                local take=math.min(count,d.max_stack-v.count);v.count=v.count+take;count=count-take
                if count==0 then return copy end
            end
        end
    end
    for i=1,40 do
        if not copy.grid[i] then
            local take=math.min(count,d.max_stack);copy.grid[i]=S.NewItem(id,take,durability);count=count-take
            if count==0 then return copy end
        end
    end
    return false,"Рюкзак заполнен"
end
-- Перестановка, объединение стаков и назначение ссылок хотбара.
function S.Move(inv, from, fi, to, ti)
    if not S.ValidLocation(from,fi) or not S.ValidLocation(to,ti) then return false,"Некорректная ячейка" end
    if from==to and fi==ti then return false,"Та же ячейка" end
    local a=S.GetAt(inv,from,fi)
    if not a then return false,"Ячейка пуста" end
    if to=="quickbar" then
        if from=="quickbar" then inv.quickbar[fi],inv.quickbar[ti]=inv.quickbar[ti],inv.quickbar[fi]
        else inv.quickbar[ti]=a.uid end
        return true
    end
    if from=="quickbar" then return false,"Хотбар хранит только ссылки" end
    local b=inv[to][ti]
    if not S.CanPlace(a,to,ti) or not S.CanPlace(b,from,fi) then return false,"Снаряжение не подходит к слоту" end
    if a and b and to=="grid" and a.id==b.id and a.durability==b.durability and S.Items[a.id].stackable then
        local n=math.min(a.count,S.Items[a.id].max_stack-b.count)
        if n<=0 then return false,"Стак заполнен" end
        b.count=b.count+n;a.count=a.count-n
        if a.count==0 then
            inv[from][fi]=nil
            for k,uid in pairs(inv.quickbar) do if uid==a.uid then inv.quickbar[k]=b.uid end end
        end
    else inv[from][fi],inv[to][ti]=b,a end
    S.CleanQuickbar(inv)
    return true
end
-- JSON рассматривается как недоверенное/устаревшее состояние. Ошибки не затирают файл.
function S.ValidateSaved(raw)
    if type(raw)~="table" or raw.version~=1 then return nil,"Неизвестная версия" end
    local out=S.EmptyInventory();local seen={}
    for _,zone in ipairs({"grid","equipment"}) do
        if type(raw[zone])~="table" then return nil,"Повреждённая секция "..zone end
        for key,v in pairs(raw[zone]) do
            local k=zone=="grid" and tonumber(key) or key
            if not S.ValidLocation(zone,k) or type(v)~="table" or not S.Items[v.id]
                or type(v.uid)~="string" or #v.uid>96 or #v.uid<1 or seen[v.uid]
                or not int(v.count,1,S.Items[v.id].max_stack) or not S.CanPlace(v,zone,k)
                or not int(v.durability,0,100) then return nil,"Недопустимый предмет: "..tostring(type(v)=="table" and v.id or key) end
            local d=S.Items[v.id]
            local n={id=v.id,uid=v.uid,count=v.count,durability=v.durability,
                clip1=math.Clamp(tonumber(v.clip1) or 0,-1,999),clip2=math.Clamp(tonumber(v.clip2) or 0,-1,999),
                armor=math.Clamp(tonumber(v.armor) or d.stats.armor or 0,0,d.stats.armor or 0)}
            out[zone][k]=n;seen[v.uid]=true
        end
    end
    if type(raw.quickbar)=="table" then for k,uid in pairs(raw.quickbar) do
        k=tonumber(k);if int(k,1,9) and seen[uid] then out.quickbar[k]=uid end
    end end
    for _,k in ipairs({"hunger","thirst"}) do out[k]=math.Clamp(tonumber(raw[k]) or 100,0,100) end
    out.dose=math.Clamp(tonumber(raw.dose) or 0,0,100)
    if raw.stashes~=nil then
        if type(raw.stashes)~="table" or table.Count(raw.stashes)>S.Config.MaxStashes then return nil,"Повреждены тайники" end
        for id,stash in pairs(raw.stashes) do
            if type(id)~="string" or #id>96 or type(stash)~="table" or type(stash.map)~="string" or type(stash.pos)~="table" or type(stash.items)~="table" then return nil,"Повреждён тайник" end
            for _,axis in ipairs({"x","y","z"}) do local v=stash.pos[axis];if type(v)~="number" or v~=v or math.abs(v)>1000000 then return nil,"Координаты тайника" end end
            local container=S.EmptyInventory();container.grid=stash.items
            local validated,err=S.ValidateSaved(container);if not validated then return nil,err end
            for slot,item in pairs(validated.grid) do if slot>S.Config.StashSlots or seen[item.uid] then return nil,"Дубликат/слот тайника" end;seen[item.uid]=true end
            out.stashes[id]={map=stash.map,pos=table.Copy(stash.pos),items=validated.grid}
        end
    end
    return out
end
-- Тайник владельца, на который смотрит игрок (сущность без коллизии, поэтому без трассировки).
function S.FindStashInView(ply)
    if not IsValid(ply) then return end
    local eye,aim=ply:EyePos(),ply:GetAimVector();local best,bestDot
    for _,ent in ipairs(ents.FindByClass("stalker_stash")) do
        if ent:GetStashOwner()==ply then
            local dir=ent:WorldSpaceCenter()-eye;local dist=dir:Length()
            if dist<=S.Config.StashUseRange then
                dir:Normalize();local dot=dir:Dot(aim)
                if dot>(dist<48 and .6 or .9) and (not bestDot or dot>bestDot) then best,bestDot=ent,dot end
            end
        end
    end
    return best
end
function S.IsUnconscious(ply)
    return ST_EMISSION and type(ST_EMISSION.IsUnconscious)=="function" and ST_EMISSION.IsUnconscious(ply)==true
end
local meta=FindMetaTable("Player")
function meta:GetInventory()
    if SERVER then return self.StalkerInventory end
    if self==LocalPlayer() then return S.Inventory end
end
-- Множитель защиты по состоянию: целый предмет — 1, полностью изношенный — 0.5 (общий для сервера и клиента).
function S.ConditionFactor(item)
    local d=type(item)=="table" and tonumber(item.durability) or 100
    return .5+.5*math.Clamp(d,0,100)/100
end
