-- Последствия голода/жажды, рюкзак погибшего и сохранение запаса патронов при выходе.
local Z=STALKER_ZONE

local function inventoryReady(p)
 return IsValid(p) and p.StalkerInventory and not p.StalkerLoadError and STALKER_INV
end

-- Изменение потребностей без пересчёта экипировки: ревизия растёт, клиент получает снимок.
local function commitNeeds(p)
 local S=STALKER_INV;local inv=p.StalkerInventory
 inv.revision=((inv.revision or 0)+1)%4294967296
 S.SaveInventory(p);S.Sync(p)
end

local function hunger(p,inv)
 local cfg=STALKER_INV.Config.DarkRP
 local energy=cfg and cfg.UseHunger and p.getDarkRPVar and p:getDarkRPVar("Energy")
 return type(energy)=="number" and energy or (inv.hunger or 100)
end

--[[ Голод и жажда ]]
timer.Create("STALKER_ZONE.Survival",Z.Config.Survival.Tick,0,function()
 local cfg=Z.Config.Survival;if not cfg.Enabled then return end
 for _,p in ipairs(player.GetHumans()) do
  local inv=inventoryReady(p) and p.StalkerInventory
  if inv and p:Alive() and not (ST_EMISSION and ST_EMISSION.IsUnconscious and ST_EMISSION.IsUnconscious(p)) then
   local starving,thirsty=hunger(p,inv)<=0,(inv.thirst or 100)<=0
   if starving or thirsty then
    local dmg=DamageInfo();dmg:SetDamage(cfg.Damage);dmg:SetDamageType(DMG_GENERIC)
    dmg:SetAttacker(game.GetWorld());dmg:SetInflictor(game.GetWorld())
    -- Голод — не попадание: очки брони HL2 (GM:HandlePlayerArmorReduction) иначе забирают 80% урона
    -- и навсегда списывают броню костюма. Обход брони — как у аномалий (sv_gear.lua).
    Z.AnomalyVictim=p;p:TakeDamageInfo(dmg);Z.AnomalyVictim=nil
    if (p.StzNeedsWarn or 0)<CurTime() then
     p.StzNeedsWarn=CurTime()+cfg.WarnEvery
     p:ChatPrint("[КПК] "..(thirsty and starving and "Голод и обезвоживание" or thirsty and "Обезвоживание" or "Голод").." отнимают здоровье. Поешьте и попейте.")
    end
   end
  end
 end
end)

-- После смерти персонаж не должен сразу умирать снова от голода.
hook.Add("PlayerSpawn","STALKER_ZONE.Needs",function(p)
 timer.Simple(.3,function()
  local cfg=Z.Config.Survival
  if not cfg.Enabled or not inventoryReady(p) or not p:Alive() then return end
  local inv=p.StalkerInventory;local low=cfg.RespawnMinimum
  if (inv.hunger or 100)>=low and (inv.thirst or 100)>=low then return end
  inv.hunger=math.max(inv.hunger or 100,low);inv.thirst=math.max(inv.thirst or 100,low)
  commitNeeds(p)
 end)
end)

--[[ Рюкзак погибшего: содержимое рюкзака (сетка) остаётся на месте смерти. Экипировка сохраняется.
 Наводка на тайник погибшего (STALKER_INV, DoPlayerDeath → victim.StalkerIntelPending) кладётся в сумку
 обработчиком STALKER_ZONE_BagDropped; поэтому сумка выпадает и с пустым рюкзаком, если наводка есть. ]]
function Z.DropDeathBag(p)
 local cfg=Z.Config.DeathDrop
 if not cfg.Enabled or not inventoryReady(p) then return end
 if hook.Run("STALKER_ZONE_CanDropBag",p)==false then return end
 local S=STALKER_INV;local inv=p.StalkerInventory
 local hasItems=next(inv.grid)~=nil
 if not hasItems and not p.StalkerIntelPending then return end
 -- Сумка создаётся до изъятия: при исчерпании лимита сущностей вещи остаются у игрока, а не пропадают.
 local bag=ents.Create("stalker_deathbag");if not IsValid(bag) then return end
 local items={}
 if hasItems then
  for i=1,40 do if inv.grid[i] then items[#items+1]=table.Copy(inv.grid[i]) end end
  -- Сначала изъятие из сохранения игрока, затем предметы в мире: рестарт не создаёт дубликатов.
  inv.grid={};S.CleanQuickbar(inv)
  inv.revision=((inv.revision or 0)+1)%4294967296
  p:SetNW2Float("stalker_inv_weight",S.Weight(inv))
  S.SaveInventory(p);S.Sync(p,"Рюкзак остался на месте гибели")
 end
 local pos=p:GetPos()+Vector(0,0,16)
 bag.Items=items;bag.OwnerSID=p:SteamID64()
 bag:SetPos(pos);bag:SetAngles(Angle(0,math.random(0,359),0));bag:Spawn()
 bag:SetOwnerName(p:Nick());bag:SetItemCount(#items)
 if bag.SetOwnerSID then bag:SetOwnerSID(tostring(p:SteamID64() or "")) end
 hook.Run("STALKER_ZONE_BagDropped",p,bag)
 if not IsValid(bag) then return end
 if bag.SetHasIntel then bag:SetHasIntel(bag.StashIntel~=nil) end
 -- Пустая сумка без наводки (обработчик не положил её) не нужна.
 if #items==0 and not bag.StashIntel then bag.Items=nil;bag:Remove();return end
 return bag
end
hook.Add("PlayerDeath","STALKER_ZONE.DeathBag",function(p) Z.DropDeathBag(p) end)

-- Записи КПК погибшего: наводку получает тот, кто первым успешно обыскал сумку. Если выдать не вышло
-- (бот, ошибка записи), записи остаются в сумке для следующего; свой тайник и негодная наводка — расходуются.
local spentIntel={["Это координаты вашего собственного тайника"]=true,["Наводка устарела"]=true,["Повреждённая наводка"]=true}
local function takeIntel(p,bag)
 if not bag.StashIntel or not STALKER_INV or not STALKER_INV.GiveStashIntel then return false end
 local intel=bag.StashIntel;bag.StashIntel=nil
 local ok,err=STALKER_INV.GiveStashIntel(p,intel)
 if not ok and not spentIntel[err] then
  bag.StashIntel=intel;p:ChatPrint("[КПК] Записи КПК не прочитаны: "..tostring(err or "попробуйте позже"));return false
 end
 if not ok then p:ChatPrint("[КПК] "..tostring(err)) end
 if bag.SetHasIntel then bag:SetHasIntel(false) end
 return true
end

-- Перенос предметов из рюкзака в инвентарь: столько, сколько влезает. UID сохраняются.
function Z.LootBag(p,bag)
 local S=STALKER_INV
 if not IsValid(bag) or not (bag.Items or bag.StashIntel) or bag.Busy or not p:Alive() or not inventoryReady(p) then return end
 if p:GetShootPos():DistToSqr(bag:WorldSpaceCenter())>Z.Config.DeathDrop.UseRange^2 then return end
 if S.IsUnconscious and S.IsUnconscious(p) then return end
 local list=bag.Items or {}
 if hook.Run("STALKER_INV_CanPickup",p,bag,list[1])==false then return end
 local left,taken={},0
 if #list>0 then
  S.CaptureEquipment(p)
  local inv=table.Copy(p.StalkerInventory)
  for _,item in ipairs(list) do
   local slot
   if not S.FindUID(inv,item.uid) and S.Items[item.id] then for i=1,40 do if not inv.grid[i] then slot=i;break end end end
   if slot then inv.grid[slot]=item;taken=taken+1 else left[#left+1]=item end
  end
  if taken==0 then
   p:ChatPrint("[КПК] Нет свободных ячеек в рюкзаке"..(bag.StashIntel and ": вещи остались в сумке" or ""))
   if not bag.StashIntel then return end
  end
  if taken>0 then
   bag.Busy=true
   S.Commit(p,inv,"Забрано предметов: "..taken..(#left>0 and (", осталось: "..#left) or ""))
   bag.Items=left;bag.Busy=nil
  end
 end
 local intel=takeIntel(p,bag)
 if taken==0 and not intel then return end
 local rest=#(bag.Items or {})
 if rest==0 and not bag.StashIntel then bag.Items=nil;bag:Remove() else bag:SetItemCount(rest) end
end

--[[ Запас патронов SWEP переживает выход с сервера (но не смерть). ]]
local ammoReady=sql.Query("CREATE TABLE IF NOT EXISTS stz_ammo (steamid TEXT PRIMARY KEY, payload TEXT NOT NULL)")~=false
local function sid(p) local id=not p:IsBot() and p:SteamID64();if id and id:match("^%d+$") and id~="0" then return id end end
function Z.SaveAmmo(p)
 if not Z.Config.AmmoPersistence or not ammoReady or not IsValid(p) then return end
 local id=sid(p);if not id then return end
 if not p:Alive() or p.StzAmmoPending then return end
 local data={}
 for _,ammo in ipairs(Z.Config.AmmoTypes) do local n=p:GetAmmoCount(ammo);if n>0 then data[ammo]=n end end
 if next(data) then sql.Query("REPLACE INTO stz_ammo VALUES("..sql.SQLStr(id)..","..sql.SQLStr(util.TableToJSON(data))..")")
 else sql.Query("DELETE FROM stz_ammo WHERE steamid="..sql.SQLStr(id)) end
end
function Z.RestoreAmmo(p)
 local id=sid(p);if not id then p.StzAmmoPending=nil;return end
 local rows=sql.Query("SELECT payload FROM stz_ammo WHERE steamid="..sql.SQLStr(id))
 p.StzAmmoPending=nil
 if not rows or not rows[1] then return end
 local data=util.JSONToTable(rows[1].payload)
 sql.Query("DELETE FROM stz_ammo WHERE steamid="..sql.SQLStr(id))
 if type(data)~="table" then return end
 for _,ammo in ipairs(Z.Config.AmmoTypes) do
  local n=tonumber(data[ammo])
  if n and n>0 then p:GiveAmmo(math.min(math.floor(n),9999),ammo,true) end
 end
 if (tonumber(data.Grenade) or 0)>0 and not p:HasWeapon("weapon_frag") then p:Give("weapon_frag",true) end
end
hook.Add("PlayerInitialSpawn","STALKER_ZONE.Ammo",function(p) p.StzAmmoPending=true end)
hook.Add("PlayerSpawn","STALKER_ZONE.Ammo",function(p)
 if not p.StzAmmoPending or not Z.Config.AmmoPersistence or not ammoReady then return end
 timer.Simple(1.5,function() if IsValid(p) and p:Alive() then Z.RestoreAmmo(p) end end)
end)
hook.Add("PlayerDisconnected","STALKER_ZONE.Ammo",Z.SaveAmmo)
hook.Add("ShutDown","STALKER_ZONE.Ammo",function() for _,p in ipairs(player.GetHumans()) do Z.SaveAmmo(p) end end)
-- Смерть сбрасывает запас: строка удаляется, чтобы не вернуть патроны после переподключения.
hook.Add("PlayerDeath","STALKER_ZONE.Ammo",function(p)
 local id=sid(p);if id and ammoReady then sql.Query("DELETE FROM stz_ammo WHERE steamid="..sql.SQLStr(id)) end
end)
