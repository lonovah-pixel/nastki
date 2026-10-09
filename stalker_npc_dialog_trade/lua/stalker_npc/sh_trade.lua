local N=STALKER_NPC
function N.Price(profile,item,side,ply)
    local p=profile.prices[item.id];if not p then return nil end
    local base
    if side=="buy" then base=p.buy else base=p.sell end
    if not base then return nil end
    local factor=1
    if SERVER and ply then factor=hook.Run("STNPC_PriceMultiplier",profile,item,side,ply) or 1 end
    if type(factor)~="number" or factor~=factor then return nil end
    local price=math.max(1,math.floor(base*(.25+.75*item.durability/100)*math.Clamp(factor,.5,2)))
    -- Скидка не должна превращать покупку и немедленную продажу в печать денег.
    if side=="sell" and p.buy then local buy=N.Price(profile,item,"buy",ply);if buy then price=math.min(price,math.max(1,math.floor(buy*.95))) end end
    return price
end
-- Переносит конкретный экземпляр. Состояние, магазин и остаток брони не восстанавливаются.
local function insertExact(inv,item)
    local S=STALKER_INV;local d=S.Items[item.id];local remaining=item.count
    if d.stackable then
        for i=1,40 do local v=inv.grid[i]
            if v and v.id==item.id and v.durability==item.durability and v.clip1==item.clip1 and v.clip2==item.clip2 and v.armor==item.armor then
                local n=math.min(remaining,d.max_stack-v.count);v.count=v.count+n;remaining=remaining-n
                if remaining==0 then return true end
            end
        end
    end
    for i=1,40 do if not inv.grid[i] then
        local v=table.Copy(item);v.count=math.min(remaining,d.max_stack);v.uid=S.UID();inv.grid[i]=v
        remaining=remaining-v.count;if remaining==0 then return true end
    end end
    return false
end
-- Чистая функция: никогда не изменяет входные таблицы. Обмен и бартер одной корзиной.
function N.BuildTrade(source,stock,profile,lines,balance,ply)
    local S=STALKER_INV
    if not S.IsInt(balance,0,N.Config.MaxBalance) then return nil,"economy" end
    if type(lines)~="table" or #lines<1 or #lines>N.Config.MaxLines then return nil,"invalid" end
    local inv=table.Copy(source);local store=table.Copy(stock);local seen={};local incoming,outgoing={},{};local total=0
    for _,l in ipairs(lines) do
        if not S.IsInt(l.index,1,40) or not S.IsInt(l.count,1,999) or (l.side~="buy" and l.side~="sell") then return nil,"invalid" end
        local key=l.side..l.index;if seen[key] then return nil,"invalid" end;seen[key]=true
        local grid=l.side=="buy" and store.grid or inv.grid;local item=grid[l.index]
        if not item or item.uid~=l.uid or item.count<l.count or not S.Items[item.id] then return nil,"stock" end
        local price=N.Price(profile,item,l.side,ply);if not price then return nil,"notrade" end
        local lot=table.Copy(item);lot.count=l.count
        if l.side=="buy" then incoming[#incoming+1]=lot;total=total+price*l.count
        else outgoing[#outgoing+1]=lot;total=total-price*l.count end
        item.count=item.count-l.count;if item.count==0 then grid[l.index]=nil end
    end
    if balance-total<0 then return nil,"funds" end
    if balance-total>N.Config.MaxBalance then return nil,"economy" end
    for _,lot in ipairs(incoming) do if not insertExact(inv,lot) then return nil,"full" end end
    if profile.Buyback~=false then for _,lot in ipairs(outgoing) do if not insertExact(store,lot) then return nil,"stockfull" end end end
    local weight=S.Weight(inv)
    if N.Config.EnforceWeight and weight>S.Config.MaxWeight and weight>S.Weight(source)+.0001 then return nil,"heavy" end
    S.CleanQuickbar(inv)
    return {inventory=inv,stock=store,total=total,balance=balance-total,weight=weight}
end
