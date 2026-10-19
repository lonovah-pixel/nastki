-- Работа над рецептом: серверный таймер с проверкой дистанции до станции. Игрок может держать окно открытым —
-- удерживать E не нужно, но отойти от верстака или костра (или уйти с места при крафте в поле) нельзя.
-- Ингредиенты списываются и результат выдаётся одной транзакцией STALKER_INV.Exchange в конце работы.
local CR=STALKER_CRAFT
local C=STALKER_CORE
local Cfg=CR.Config
CR.Jobs=CR.Jobs or {}

local function inv() return STALKER_INV end
local giveText=CR.GiveText

-- Можно ли сейчас работать руками (без учёта рецепта).
function CR.CanWork(ply)
 if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false,"Сейчас нельзя" end
 if C.Unconscious(ply) then return false,"Вы без сознания" end
 if ply:InVehicle() then return false,"Выйдите из транспорта" end
 if ply.StnpcTrading then return false,"Сначала закончите торговлю" end
 if C.Hold and C.Hold.IsHolding and C.Hold.IsHolding(ply) then return false,"Руки заняты" end
 local S=inv()
 if not S or not S.InventoryReady or not S.InventoryReady(ply) then return false,"Инвентарь недоступен" end
 return true
end

--[[ Проверка без изменения инвентаря: станция, ингредиенты и место под результат.
 Возвращает станцию (сущность или true — набор инструментов) и take, либо nil и причину. ]]
function CR.Check(ply,r)
 if not r or not CR.Available(r) then return nil,"Рецепт недоступен на сервере" end
 local ok,err=CR.CanWork(ply);if not ok then return nil,err end
 local S=inv()
 local counts=CR.Counts(ply.StalkerInventory)
 local station,why=CR.StationFor(ply,r,counts);if not station then return nil,why end
 local take,rows=CR.Resolve(r,counts)
 if not take then return nil,"Не хватает: "..CR.MissingText(rows) end
 -- Пробное списание и выдача на копии: заполненный рюкзак выясняется до начала работы, а не после.
 local copy=S.RemoveFrom(table.Copy(ply.StalkerInventory),take)
 if not copy then return nil,"Не хватает ингредиентов" end
 for _,g in ipairs(r.give) do
  local nextInv,reason=S.Insert(copy,g[1],g[2])
  if not nextInv then return nil,reason or "Рюкзак заполнен" end
  copy=nextInv
 end
 return station,take
end

local function setNW(ply,job)
 if not IsValid(ply) then return end
 ply:SetNW2Float("stcraft_start",job and job.start or 0);ply:SetNW2Float("stcraft_end",job and job.ends or 0)
 ply:SetNW2String("stcraft_label",job and job.label or "");ply:SetNW2String("stcraft_recipe",job and job.recipe.id or "")
 ply:SetNW2Int("stcraft_left",job and job.left or 0)
end
local function label(job)
 local r=job.recipe
 return (r.kind=="cook" and "Готовка: " or "Изготовление: ")..r.name..(job.total>1 and (" ("..(job.done+1).."/"..job.total..")") or "")
end
-- Сесть у огня (поза STALKER Social, если аддон установлен).
local function sit(ply,job)
 local So=STALKER_SOCIAL
 if job.recipe.kind~="cook" or not So or type(So.SetPose)~="function" then return end
 if type(So.GetPose)=="function" then local ok,pose=pcall(So.GetPose,ply);if ok and pose=="sit" then return end end
 local ok,res=pcall(So.SetPose,ply,"sit");job.posed=ok and res==true
end
local function stand(ply,job)
 local So=STALKER_SOCIAL
 if not job or not job.posed or not So or type(So.ClearPose)~="function" then return end
 if type(So.GetPose)=="function" then local ok,pose=pcall(So.GetPose,ply);if ok and pose~="sit" then return end end
 pcall(So.ClearPose,ply,"craft")
end

-- Начать одно изделие очереди (первое или следующее).
local function begin(ply,job,station)
 local now=CurTime()
 job.ent=station~=true and station or nil
 job.pos=ply:GetPos();job.start=now;job.ends=now+CR.Duration(job.recipe)
 job.label=label(job)
 setNW(ply,job)
end

--[[ Поставить в работу count изделий рецепта id. Возвращает true или false и причину. ]]
function CR.Start(ply,id,count)
 local r=CR.ByID[id];if not r then return false,"Неизвестный рецепт" end
 local busy=CR.Jobs[ply];if busy then return false,"Вы уже заняты: "..busy.recipe.name end
 local station,err=CR.Check(ply,r);if not station then return false,err end
 count=math.Clamp(math.floor(tonumber(count) or 1),1,math.max(1,math.floor(Cfg.MaxRepeat)))
 local job={recipe=r,total=count,done=0,left=count-1}
 CR.Jobs[ply]=job
 begin(ply,job,station)
 sit(ply,job)
 ply:EmitSound(r.kind=="cook" and "ambient/fire/ignite.wav" or "buttons/lever7.wav",60,100)
 hook.Run("STALKER_CRAFT_Started",ply,r,count)
 return true
end

function CR.Cancel(ply,reason,silent)
 local job=CR.Jobs[ply];if not job then return false end
 CR.Jobs[ply]=nil;setNW(ply,nil);stand(ply,job)
 if not silent and IsValid(ply) and reason then C.Notify(ply,reason,"warn",4) end
 hook.Run("STALKER_CRAFT_Cancelled",ply,job.recipe,reason)
 return true
end

-- Станция всё ещё рядом и пригодна? Возвращает true или причину отмены.
local function stillValid(ply,job)
 local ok,err=CR.CanWork(ply);if not ok then return err end
 local r=job.recipe;local range=Cfg.StationRange+40
 if job.ent~=nil then
  if not IsValid(job.ent) or (job.ent.IsLit and not job.ent:IsLit()) then return r.station=="fire" and "Костёр погас" or "Верстак убран" end
  if job.ent:GetPos():DistToSqr(ply:GetPos())>range*range then return r.station=="fire" and "Вы отошли от костра" or "Вы отошли от верстака" end
 else
  if Cfg.NeedToolkit and STALKER_INV.CountItem(ply,"toolkit")<1 then return "Набор инструментов пропал из рюкзака" end
  if job.pos:DistToSqr(ply:GetPos())>Cfg.MoveTolerance^2 then return "Вы сошли с места: работа прервана" end
 end
 return true
end

-- Готово одно изделие: списание и выдача одной транзакцией, затем следующее в очереди.
function CR.Finish(ply,job)
 local r=job.recipe;local S=inv()
 local counts=CR.Counts(ply.StalkerInventory)
 local take,rows=CR.Resolve(r,counts)
 if not take then CR.Cancel(ply,"Не хватает: "..CR.MissingText(rows));return false end
 local give={};for _,g in ipairs(r.give) do give[#give+1]={g[1],g[2]} end
 local ok,err=S.Exchange(ply,take,give)
 if not ok then CR.Cancel(ply,err or "Не удалось изготовить");return false end
 job.done=job.done+1
 C.AddStat(ply,r.kind=="cook" and "cooked" or "crafted",1)
 hook.Run("STALKER_CRAFT_Crafted",ply,r,give)
 ply:EmitSound(r.kind=="cook" and "ambient/fire/ignite.wav" or "items/ammo_pickup.wav",60,110)
 if job.left<=0 then
  CR.Jobs[ply]=nil;setNW(ply,nil);stand(ply,job)
  C.Notify(ply,(r.kind=="cook" and "Приготовлено: " or "Изготовлено: ")..giveText(r)..(job.total>1 and (" — "..job.total.." раз") or ""),"ok",5)
  CR.SendState(ply)
  return true
 end
 -- Следующее изделие: станция и ингредиенты проверяются заново.
 local station,why=CR.Check(ply,r)
 if not station then
  CR.Jobs[ply]=nil;setNW(ply,nil);stand(ply,job)
  C.Notify(ply,"Готово "..job.done.." из "..job.total..". Дальше нельзя: "..tostring(why),"warn",6)
  CR.SendState(ply)
  return true
 end
 job.left=job.left-1
 begin(ply,job,station)
 return true
end

timer.Create("STALKER_CRAFT.Jobs",.2,0,function()
 local now=CurTime()
 local list={};for ply,job in pairs(CR.Jobs) do list[#list+1]={ply,job} end
 for _,row in ipairs(list) do
  local ply,job=row[1],row[2]
  if not IsValid(ply) then CR.Jobs[ply]=nil
  elseif CR.Jobs[ply]==job then
   local ok=stillValid(ply,job)
   if ok~=true then CR.Cancel(ply,ok)
   elseif now>=job.ends then
    local success,err=pcall(CR.Finish,ply,job)
    if not success then ErrorNoHalt("[STALKER Crafting] "..tostring(err).."\n");CR.Cancel(ply,"Ошибка крафта") end
   end
  end
 end
end)
hook.Add("PlayerDeath","STALKER_CRAFT.Jobs",function(ply) CR.Cancel(ply,"Гибель") end)
hook.Add("PlayerDisconnected","STALKER_CRAFT.Jobs",function(ply) CR.Jobs[ply]=nil end)
-- Нападение прерывает работу: под огнём не крафтят. Радиация, голод и падения — не нападение.
hook.Add("EntityTakeDamage","STALKER_CRAFT.Jobs",function(ent,dmg)
 if not CR.Jobs[ent] or dmg:GetDamage()<=0 then return end
 local a=dmg:GetAttacker()
 if IsValid(a) and a~=ent and (a:IsPlayer() or a:IsNPC()) then CR.Cancel(ent,"Вас атакуют — работа прервана") end
end)

--[[ Ремонт из окна мастерской: набор списывается, состояние восстанавливает STALKER_INV.RepairItem. ]]
function CR.Repair(ply,kitID,slotID)
 local kit=CR.Kits[kitID];if not kit then return false,"Неизвестный набор" end
 local valid=false;for _,s in ipairs(kit.slots) do if s==slotID then valid=true end end
 if not valid then return false,CR.ItemName(kitID).." не подходит к этому слоту" end
 if CR.Jobs[ply] then return false,"Вы заняты: "..CR.Jobs[ply].recipe.name end
 local ok,err=CR.CanWork(ply);if not ok then return false,err end
 local S=inv()
 if S.CountItem(ply,kitID)<1 then return false,"Нет предмета «"..CR.ItemName(kitID).."» в рюкзаке" end
 local item=ply.StalkerInventory.equipment[slotID]
 if not item then return false,"Слот пуст" end
 if (tonumber(item.durability) or 100)>=100 then return false,CR.ItemName(item.id).." в полном порядке" end
 local uid=item.uid;local amount=CR.KitAmount(kitID)
 ok,err=S.Exchange(ply,{[kitID]=1},{})
 if not ok then return false,err end
 local after=math.min(100,item.durability+amount)
 ok,err=S.RepairItem(ply,uid,amount,CR.ItemName(item.id)..": состояние "..after.."%")
 if not ok then
  -- Ремонт не прошёл — набор возвращается.
  S.Exchange(ply,{},{{kitID,1}})
  return false,err
 end
 hook.Run("STALKER_CRAFT_Repaired",ply,slotID,ply.StalkerInventory.equipment[slotID] or item)
 return true,CR.ItemName(item.id)..": состояние "..after.."%"
end

-- Счётчики игрока для КПК (изготовлено, приготовлено).
function CR.SendState(ply)
 if not IsValid(ply) then return end
 local st=C.GetStats and C.GetStats(ply) or {}
 C.Send("stalker_craft.state",ply,{crafted=tonumber(st.crafted) or 0,cooked=tonumber(st.cooked) or 0})
end
hook.Add("PlayerInitialSpawn","STALKER_CRAFT.State",function(ply) timer.Simple(5,function() if IsValid(ply) then CR.SendState(ply) end end) end)
