-- Инвентарь 2.0: компактные тайники с вместимостью в самом тайнике, наводки на чужие тайники с убитых,
-- обыск по удержанию E и перенос у владельца вне сети, характеристики брони и износ от урона,
-- сводка КПК вместо вкладок «Карта»/«PDA», тема оформления, настройки «Инвентарь».
-- Область мира: X 2 500 000…2 900 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local S,C,MK,SET=STALKER_INV,STALKER_CORE,STALKER_MARKERS,STALKER_SETTINGS
local function lastSent(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end
local function notified(p,pattern)
 for _,s in ipairs(M.netSent or {}) do
  if s.name=="stalker_core.notify" and s.to==p then local d=decode(s);if d and d.text and d.text:find(pattern,1,true) then return true end end
 end
 return false
end

section("Инвентарь 2.0: загрузка ("..M.Realm..")")
check(S.Config.StashSlots==12 and S.Config.LegacyStashSlots==20,"новые тайники — 12 ячеек, старые — 20")
check(S.Config.StashModel=="models/props_junk/garbage_bag001a.mdl" and S.Config.StashModelFallback,"компактная модель тайника и запасная")
check(S.Config.StashIntelChance==35 and S.Config.StashIntelHours==6,"шанс и срок наводки")
for id,realm in pairs({["inv.max_weight"]="shared",["inv.overweight_speed"]="shared",["inv.max_stashes"]="shared",["inv.stash_slots"]="shared",
 ["inv.stash_intel_chance"]="server",["inv.stash_intel_hours"]="server",["inv.armor_wear"]="server",["inv.autosave"]="server"}) do
 local def=SET.Defs[id];check(def and def.category=="Инвентарь" and def.realm==realm,"настройка "..id)
end
-- Реестр характеристик: проценты, доли, скорость, износ.
check(S.StatFormat.bulletResist and S.StatFormat.radiationProtection.kind=="fraction" and S.StatFormat.speed.kind=="speed","реестр S.StatFormat")
local text,label,ratio,token=S.FormatStat("radiationProtection",.25)
check(text=="25%" and label=="Защита от радиации" and math.abs(ratio-.25)<1e-6,"доля → проценты: "..tostring(text))
text,_,_,token=S.FormatStat("speed",-20);check(text=="−20%" and token=="danger","скорость со знаком: "..tostring(text))
check((S.FormatStat("bulletResist",7.5))=="7.5%" and (S.FormatStat("weight",6))=="6 кг","проценты и вес")
local suit=S.NewItem("hazmat",1);suit.durability=0
local rows=S.ItemStats(suit);local byKey={};for _,r in ipairs(rows) do byKey[r.key]=r end
check(byKey.radiationProtection and byKey.radiationProtection.text=="35%" and byKey.radiationProtection.nominal=="70%","защита с учётом износа (×0.5) и номинал")
check(byKey.armor and byKey.armor.text=="25" and byKey.weight and byKey.weight.text=="6 кг","очки брони и вес в характеристиках")
check(rows[1].key=="armor","порядок строк: очки брони первыми")
local worn=table.Copy(suit);worn.durability=50
local gear=S.GearSummary({equipment={armor=worn}})
check(math.abs((gear.radiationProtection or 0)-.525)<1e-6,"сводная защита комплекта учитывает износ")
check(next(S.GearSummary({equipment={armor=suit}}))==nil,"сломанный костюм не защищает")
-- Старые тайники без поля slots: 20 ячеек, данные не теряются; лимит количества не блокирует загрузку.
local raw=S.EmptyInventory()
raw.stashes={old={map="gm_test",pos={x=1,y=2,z=3},items={["18"]={id="scrap",uid="legacy_1",count=5,durability=100}}},
 old2={map="gm_test",pos={x=5,y=2,z=3},items={}}}
local maxStashes=S.Config.MaxStashes;S.Config.MaxStashes=1
local inv=S.ValidateSaved(raw)
check(inv and inv.stashes.old.slots==20 and inv.stashes.old.items[18] and inv.stashes.old.items[18].count==5,"старый тайник: 20 ячеек, предмет в 18-й сохранён")
check(inv and inv.stashes.old2,"снижение лимита тайников не блокирует инвентарь")
S.Config.MaxStashes=maxStashes
raw.stashes={new={map="gm_test",pos={x=1,y=2,z=3},slots=12,items={["13"]={id="scrap",uid="legacy_2",count=1,durability=100}}}}
check(S.ValidateSaved(raw)==nil,"предмет вне вместимости нового тайника отклоняется")
check(S.StashSlotsOf({})==20 and S.StashSlotsOf({slots=12})==12,"вместимость тайника")

if SERVER then
 local X=2600000
 local MKget=function(id) return MK.List[id] end
 section("Инвентарь 2.0: компактный тайник")
 local owner=TEST.join({nick="Хозяин тайника",pos=Vector(X,0,0),aim=Vector(X+60,0,0)})
 owner.StalkerInventory.grid={};owner.StalkerInventory.stashes={}
 check(S.GiveItem(owner,"medkit",3) and S.GiveItem(owner,"scrap",5),"предметы для тайника выданы")
 local ok,err=S.StashAction(owner,"create",nil,0,0,owner.StalkerInventory.revision)
 check(ok,"тайник создан: "..tostring(err))
 local stashID,stash=next(owner.StalkerInventory.stashes)
 check(stash and stash.slots==12,"вместимость записана в тайник: "..tostring(stash and stash.slots))
 local ent;for _,e in ipairs(ents.FindByClass("stalker_stash")) do if e:GetStashID()==stashID then ent=e end end
 check(ent and ent:GetModel()==S.Config.StashModel and ent:GetSlots()==12,"сущность: компактная модель и число ячеек")
 local function put(id)
  local i=TEST.gridIndex(owner,id);return S.StashAction(owner,"put",stashID,i,0,owner.StalkerInventory.revision)
 end
 check(put("medkit") and put("scrap"),"предметы положены в тайник")
 local i=S.Insert(owner.StalkerInventory,"water",1);owner.StalkerInventory=i;local wi=TEST.gridIndex(owner,"water")
 check(not S.StashAction(owner,"put",stashID,wi,13,owner.StalkerInventory.revision),"ячейка 13 вне вместимости отклонена")
 SET.Set("inv.stash_slots",8)
 check(S.Config.StashSlots==8 and owner.StalkerInventory.stashes[stashID].slots==12,"смена настройки не меняет существующий тайник")
 SET.Set("inv.stash_slots",nil);check(S.Config.StashSlots==12,"сброс настройки")
 SET.Set("inv.autosave",45);check(timer.Exists("STALKER_INV.Autosave") and S.Config.Autosave==45,"автосохранение из настроек");SET.Set("inv.autosave",nil)

 section("Инвентарь 2.0: наводка с убитого")
 S.Config.StashIntelChance=100
 local killer=TEST.join({nick="Убийца",pos=Vector(X+60,80,0),aim=Vector(X+60,0,0)})
 local killerSID=killer:SteamID64();M.netSent={}
 M.kill(owner,killer)
 local list=S.IntelHeld[killerSID] or {};local intelID,intel=next(list)
 check(intel and intel.owner==owner:SteamID64() and intel.stash==stashID and intel.map=="gm_test","убийца получил наводку на тайник")
 check(intel and intel.expires>os.time()+5*3600,"срок наводки — 6 часов")
 local marker=intelID and MKget("stash.intel."..intelID)
 check(marker and marker.kind=="stash" and marker.visible.players[killerSID] and not marker.visible.players[owner:SteamID64()],"метка видна только держателю")
 check(notified(killer,"Наводка") and notified(owner,"рассекречен"),"уведомления держателю и владельцу")
 local row=sql.Query("SELECT holder,owner FROM stalker_stash_intel WHERE id="..sql.SQLStr(intelID or ""))
 check(row and row[1] and row[1].holder==killerSID,"наводка сохранена в SQLite")
 check(decode(lastSent("stalker_stash.intel",killer)).list[1].id==intelID,"список наводок отправлен держателю")
 M.spawn(owner);M.advance(1)

 section("Инвентарь 2.0: обыск чужого тайника")
 local stranger=TEST.join({nick="Прохожий",pos=Vector(X+60,90,0),aim=Vector(X+60,0,0)})
 local l0=(#intelID+1)*8+6
 M.netReceive("stalker_stash.loot",l0,stranger,{intelID,1})
 check(TEST.gridCount(stranger,"medkit")==0,"без наводки и обыска забрать нельзя")
 M.netReceive("stalker_stash.loot",l0,killer,{intelID,1})
 check(TEST.gridCount(killer,"medkit")==0,"без удержания E забрать нельзя")
 killer:SetKey(IN_USE,true);hook.Run("KeyPress",killer,IN_USE)
 check(C.Hold.IsHolding(killer),"у места тайника началось удержание E")
 M.netSent={};M.advance(S.Config.StashIntelHold+.5,.1);killer:SetKey(IN_USE,false)
 check(killer.StalkerLooting and killer.StalkerLooting.id==intelID,"тайник открыт после удержания")
 local opened=decode(lastSent("stalker_stash.foreign",killer))
 check(opened and opened.intel==intelID and opened.slots==12 and #opened.items==2,"окно чужого тайника: содержимое и вместимость")
 check((C.GetStats(killer).stashes or 0)==1,"статистика «Найдено чужих тайников»")
 check(notified(owner,"вскрыл"),"владелец узнал о вскрытии")
 local medSlot;for slot,item in pairs(owner.StalkerInventory.stashes[stashID].items) do if item.id=="medkit" then medSlot=slot end end
 local revBefore=owner.StalkerInventory.revision
 M.netReceive("stalker_stash.loot",l0,killer,{intelID,medSlot})
 check(TEST.gridCount(killer,"medkit")==3,"предмет перешёл в рюкзак держателя")
 local live=owner.StalkerInventory.stashes[stashID]
 check(live and not live.items[medSlot] and owner.StalkerInventory.revision~=revBefore,"живой инвентарь владельца в сети изменён")
 local fromDB=S.LoadInventoryBySID(owner:SteamID64())
 check(fromDB and table.Count(fromDB.stashes[stashID].items)==1,"изменение владельца записано в базу")
 check(S.IntelHeld[killerSID][intelID]~=nil,"тайник не пуст — наводка остаётся")
 -- Владелец вышел: перенос по SteamID64 из сохранения.
 hook.Run("PlayerDisconnected",owner);M.removePlayer(owner)
 M.netSent={}
 M.netReceive("stalker_stash.loot",l0,killer,{intelID,0})
 check(TEST.gridCount(killer,"scrap")==5,"«Забрать всё» у владельца вне сети")
 fromDB=S.LoadInventoryBySID(owner:SteamID64())
 check(fromDB and fromDB.stashes[stashID] and next(fromDB.stashes[stashID].items)==nil,"тайник владельца вне сети опустошён в базе")
 local holderDB=S.LoadInventoryBySID(killerSID);local n=0
 for _,it in pairs(holderDB and holderDB.grid or {}) do if it.id=="scrap" then n=n+it.count end end
 check(n==5,"инвентарь держателя сохранён той же транзакцией")
 check(S.IntelHeld[killerSID][intelID]==nil and MKget("stash.intel."..intelID)==nil,"пустой тайник — наводка и метка сняты")
 check(not sql.Query("SELECT id FROM stalker_stash_intel WHERE id="..sql.SQLStr(intelID)),"наводка удалена из базы")
 local closed=decode(lastSent("stalker_stash.foreign",killer));check(closed and closed.close,"окно чужого тайника закрыто")

 section("Инвентарь 2.0: наводка в рюкзаке погибшего")
 local victim=TEST.join({nick="Погибший",pos=Vector(X+2000,0,0),aim=Vector(X+2060,0,0)})
 victim.StalkerInventory.stashes={};S.GiveItem(victim,"bandage",4);S.GiveItem(victim,"water",1)
 check(S.StashAction(victim,"create",nil,0,0,victim.StalkerInventory.revision),"тайник погибшего создан")
 local vStash=next(victim.StalkerInventory.stashes)
 check(S.StashAction(victim,"put",vStash,TEST.gridIndex(victim,"bandage"),0,victim.StalkerInventory.revision),"бинты в тайнике")
 M.kill(victim)
 local bagIntel
 for _,b in ipairs(ents.FindByClass("stalker_deathbag")) do if b.StashIntel and b.StashIntel.owner==victim:SteamID64() then bagIntel=b.StashIntel end end
 if not bagIntel and victim.StalkerIntelPending then
  -- Без аддона Зоны рюкзака нет: эмулируем его хук.
  local bag={IsValid=function() return true end};hook.Run("STALKER_ZONE_BagDropped",victim,bag);bagIntel=bag.StashIntel
 end
 check(bagIntel and bagIntel.stash==vStash and victim.StalkerIntelPending==nil,"смерть не от игрока: наводка лежит в рюкзаке")
 local picker=TEST.join({nick="Мародёр",pos=Vector(X+2060,80,0),aim=Vector(X+2060,0,0)})
 M.netSent={}
 local given,gid=S.GiveStashIntel(picker,bagIntel)
 check(given and S.IntelHeld[picker:SteamID64()][gid],"подобравший получил наводку")
 check(notified(victim,"рассекречен"),"владелец в сети предупреждён")
 local again,gid2=S.GiveStashIntel(picker,bagIntel);check(again and gid2==gid and table.Count(S.IntelHeld[picker:SteamID64()])==1,"повторная наводка лишь продлевает срок")
 check(not S.GiveStashIntel(victim,bagIntel),"свой тайник наводкой не выдаётся")
 local stale=table.Copy(bagIntel);stale.expires=os.time()-1;check(not S.GiveStashIntel(picker,stale),"устаревшая наводка отклоняется")
 check(not S.GiveStashIntel(picker,{owner="x"}),"повреждённая наводка отклоняется")
 -- Держатель перезашёл: наводки и метки восстанавливаются из базы.
 local pickerSID=picker:SteamID64()
 hook.Run("PlayerDisconnected",picker);M.removePlayer(picker)
 check(S.IntelHeld[pickerSID]==nil and MKget("stash.intel."..gid)==nil,"выход держателя убирает метки")
 picker=TEST.join({nick="Мародёр",sid=pickerSID,pos=Vector(X+2060,80,0),aim=Vector(X+2060,0,0)})
 check(S.IntelHeld[pickerSID] and S.IntelHeld[pickerSID][gid] and MKget("stash.intel."..gid),"наводка восстановлена после перезахода")
 -- Владелец опустошил и удалил тайник — наводка снимается.
 M.spawn(victim);M.advance(1)
 check(S.StashAction(victim,"takeall",vStash,0,0,victim.StalkerInventory.revision),"владелец забрал всё")
 check(S.StashAction(victim,"delete",vStash,0,0,victim.StalkerInventory.revision),"владелец удалил тайник")
 check(S.IntelHeld[pickerSID][gid]==nil and MKget("stash.intel."..gid)==nil,"удалённый тайник — наводка снята")

 section("Инвентарь 2.0: владелец вне сети узнаёт о наводке")
 local away=TEST.join({nick="Отсутствующий",pos=Vector(X+4000,0,0),aim=Vector(X+4060,0,0)})
 away.StalkerInventory.stashes={};S.GiveItem(away,"food",2)
 S.StashAction(away,"create",nil,0,0,away.StalkerInventory.revision)
 local aStash=next(away.StalkerInventory.stashes)
 S.StashAction(away,"put",aStash,TEST.gridIndex(away,"food"),0,away.StalkerInventory.revision)
 local awayIntel=S.MakeStashIntel(away);local awaySID=away:SteamID64()
 check(awayIntel and awayIntel.stash==aStash and awayIntel.ownerName=="Отсутствующий","наводка формируется из тайника на этой карте")
 hook.Run("PlayerDisconnected",away);M.removePlayer(away)
 local okAway,aid=S.GiveStashIntel(picker,awayIntel)
 check(okAway and sql.QueryValue("SELECT notified FROM stalker_stash_intel WHERE id="..sql.SQLStr(aid))=="0","владелец вне сети: уведомление отложено")
 M.netSent={}
 away=TEST.join({nick="Отсутствующий",sid=awaySID,pos=Vector(X+4000,0,0)});M.advance(6)
 check(notified(away,"рассекречен"),"при входе владелец узнал о рассекреченном тайнике")
 check(sql.QueryValue("SELECT notified FROM stalker_stash_intel WHERE id="..sql.SQLStr(aid))=="1","отметка об уведомлении сохранена")
 -- Доступ к открытому тайнику пропадает, когда держатель уходит.
 picker._pos=Vector(X+4060,80,0);picker._aim=Vector(X+4060,0,0);picker:SetKey(IN_USE,true);hook.Run("KeyPress",picker,IN_USE)
 M.advance(S.Config.StashIntelHold+.5,.1);picker:SetKey(IN_USE,false)
 check(picker.StalkerLooting and picker.StalkerLooting.id==aid,"тайник отсутствующего открыт по наводке")
 picker._pos=Vector(X+5000,0,0);M.advance(2.5)
 check(picker.StalkerLooting==nil,"держатель ушёл — доступ к чужому тайнику закрыт")
 -- Истечение срока: наводка снимается таймером.
 S.IntelHeld[pickerSID][aid].expires=os.time()-1;M.advance(31)
 check(S.IntelHeld[pickerSID][aid]==nil and MKget("stash.intel."..aid)==nil,"истёкшая наводка снята")
 -- Шанс 0 — наводок нет.
 S.Config.StashIntelChance=0
 local before=table.Count(S.IntelHeld[killerSID] or {})
 local v2=TEST.join({nick="Без шанса",pos=Vector(X+6000,0,0),aim=Vector(X+6060,0,0)})
 v2.StalkerInventory.stashes={};S.GiveItem(v2,"scrap",1);S.StashAction(v2,"create",nil,0,0,v2.StalkerInventory.revision)
 S.StashAction(v2,"put",next(v2.StalkerInventory.stashes),TEST.gridIndex(v2,"scrap"),0,v2.StalkerInventory.revision)
 M.kill(v2,killer)
 check(table.Count(S.IntelHeld[killerSID] or {})==before,"шанс 0% — наводка не выдаётся")
 S.Config.StashIntelChance=35

 section("Инвентарь 2.0: износ брони")
 local w=TEST.join({nick="Броненосец",pos=Vector(X+8000,0,0)})
 local winv=table.Copy(w.StalkerInventory);winv.equipment.armor=S.NewItem("jacket",1);winv.equipment.helmet=S.NewItem("helmet",1);S.Commit(w,winv)
 check(not S.WearEquipment(w,"нет",5) and not S.WearEquipment(w,"armor",-1) and not S.WearEquipment(w,"boots",5),"износ: неверный слот, количество или пустой слот")
 local per=S.Config.ArmorWearPerDamage;S.Config.ArmorWearPerDamage=.1
 local function hit(amount,kind,head)
  w._hitgroup=head and HITGROUP_HEAD or nil;w:SetHealth(100)
  local d=DamageInfo();d:SetDamage(amount);d:SetDamageType(kind);d:SetAttacker(M.world);d:SetInflictor(M.world);w:TakeDamageInfo(d)
  w._hitgroup=nil
 end
 local rev=w.StalkerInventory.revision
 hit(50,DMG_BULLET);M.advance(.3)
 check(w.StalkerInventory.equipment.armor.durability==100,"износ копится, а не применяется сразу")
 M.advance(S.Config.ArmorWearInterval+.5)
 local dur=w.StalkerInventory.equipment.armor.durability
 check(dur<100 and dur>=94 and w.StalkerInventory.revision~=rev,"пуля изнашивает костюм одним сохранением: "..dur.."%")
 check(w.StalkerInventory.equipment.helmet.durability==100,"шлем цел при попадании в тело")
 hit(40,DMG_BULLET,true);M.advance(S.Config.ArmorWearInterval+.5)
 check(w.StalkerInventory.equipment.helmet.durability<100 and w.StalkerInventory.equipment.armor.durability==dur,"попадание в голову изнашивает шлем")
 hit(30,DMG_FALL);M.advance(S.Config.ArmorWearInterval+.5)
 check(w.StalkerInventory.equipment.armor.durability==dur,"падение броню не изнашивает")
 hit(40,DMG_BURN);hit(40,DMG_SHOCK);M.advance(S.Config.ArmorWearInterval+.5)
 check(w.StalkerInventory.equipment.armor.durability<dur,"огонь и электричество изнашивают костюм")
 M.netSent={}
 check(S.WearEquipment(w,"helmet",100),"API износа: очередь");S.FlushWear(w)
 check(w.StalkerInventory.equipment.helmet.durability==0 and notified(w,"изношен"),"шлем полностью изношен — предупреждение")
 check(not S.WearEquipment(w,"helmet",5),"сломанный предмет больше не изнашивается")
 S.WearEquipment(w,"armor",.4);S.WearEquipment(w,"armor",.4);dur=w.StalkerInventory.equipment.armor.durability;S.FlushWear(w)
 check(w.StalkerInventory.equipment.armor.durability==dur,"дробный износ копится до целого процента")
 S.WearEquipment(w,"armor",7.3);M.kill(w)
 local wDB=S.LoadInventoryBySID(w:SteamID64())
 check(wDB and wDB.equipment.armor.durability==dur-8,"износ (0.8 остатка + 7.3) сохранён при смерти: "..tostring(wDB and wDB.equipment.armor.durability))
 S.Config.ArmorWearPerDamage=per
 for _,p in ipairs({killer,stranger,victim,picker,away,v2,w}) do if IsValid(p) then hook.Run("PlayerDisconnected",p);M.removePlayer(p) end end
end

if CLIENT then
 section("Инвентарь 2.0: клиент")
 local T=STALKER_THEME;local lp=LocalPlayer()
 check(S.C.accent.r==T.C.accent.r and S.C.background.g==T.C.bg.g,"цвета инвентаря — токены темы")
 T.Apply("pda");check(S.C.accent.g==T.Presets.pda.accent.g,"смена темы обновляет инвентарь");T.Apply()
 -- Окно инвентаря: сводка вместо «Карта»/«PDA», карточка брони, подсказка.
 S.Inventory=S.EmptyInventory();S.Inventory.equipment.armor=S.NewItem("hazmat",1);S.Inventory.equipment.armor.durability=40
 S.Inventory.grid[1]=S.NewItem("medkit",2);S.SelectedUID=S.Inventory.equipment.armor.uid
 S.Close();check(M.protect("открыть инвентарь",S.Open) and S.Frame,"инвентарь открывается")
 local labels={};for _,tab in ipairs(S.Frame.Tabs) do labels[#labels+1]=tab.Label end
 check(table.concat(labels,",")=="Рюкзак,Артефакты,Сводка","вкладки: Рюкзак, Артефакты, Сводка")
 M.protect("рамка инвентаря",S.Frame.Paint,S.Frame,960,600)
 M.protect("карточка брони",S.Frame.PaintDetail,S.Frame,212,388)
 M.protect("экипировка",S.Frame.Equipment.Paint,S.Frame.Equipment,180,388)
 M.protect("ячейка",S.Frame.GridSlots[1].Paint,S.Frame.GridSlots[1],62,62)
 local tip=vgui.Create("STALKERTooltip");M.protect("подсказка: предмет",tip.SetItem,tip,S.Inventory.equipment.armor);M.protect("подсказка: отрисовка",tip.Paint,tip,274,260)
 check(tip.Stats and #tip.Stats>=3,"подсказка показывает характеристики брони")
 M.protect("вкладка Сводка",S.Frame.SetTab,S.Frame,"Сводка")
 local pdaOpened;local prev=C.PDAOpen;C.PDAOpen=function(tab) pdaOpened=true end
 S.Intel={{id="i1",owner="Сосед",map=game.GetMap(),pos={x=40,y=0,z=0},expiresAt=CurTime()+600}}
 M.protect("сводка: отрисовка",S.Frame.PDA.Paint,S.Frame.PDA,512,388)
 local rowsSummary=S.SummaryRows(lp);local hasIntel=false;for _,r in ipairs(rowsSummary) do if r[1]=="Наводки" and r[2]:find("Сосед",1,true) then hasIntel=true end end
 check(hasIntel,"сводка: наводки с расстоянием")
 M.protect("кнопка «Открыть КПК (F4)»",S.Frame.PDA.OpenButton.DoClick,S.Frame.PDA.OpenButton)
 check(pdaOpened and S.Frame==nil,"кнопка закрывает инвентарь и открывает КПК")
 C.PDAOpen=prev
 -- Окно своего тайника: вместимость из тайника (старый — 20, новый — 12).
 S.Inventory.stashes={old={map=game.GetMap(),pos={x=20,y=0,z=0},items={}},new={map=game.GetMap(),pos={x=30,y=0,z=0},items={},slots=12}}
 S.Open("old");check(S.StashFrame and S.StashFrame.SlotCount==20,"старый тайник: 20 ячеек")
 S.Close();S.Open("new");check(S.StashFrame and S.StashFrame.SlotCount==12,"новый тайник: 12 ячеек")
 M.protect("окно тайника",S.StashFrame.Paint,S.StashFrame,300,600);M.protect("тайник: тело",S.StashFrame.Body.Paint,S.StashFrame.Body,256,388)
 M.protect("менеджер тайников",S.OpenStashManager);if S.Manager then M.protect("менеджер: отрисовка",S.Manager.Paint,S.Manager,560,440) end
 S.Close()
 -- Чужой тайник по наводке: окно, забрать предмет, закрытие.
 local item=S.NewItem("scrap",3)
 local l,v=packet({intel="intel1",owner="Сосед",slots=12,items={{slot=2,item=item}},pos={x=40,y=0,z=0}})
 M.netReceive("stalker_stash.foreign",l,nil,v)
 check(S.Foreign and S.Foreign.items[2] and S.StashFrame and S.StashFrame.Foreign and S.StashFrame.SlotCount==12,"окно чужого тайника открыто")
 M.protect("чужой тайник: рамка",S.StashFrame.Paint,S.StashFrame,300,600)
 M.protect("чужой тайник: ячейка",S.StashFrame.Slots[2].Paint,S.StashFrame.Slots[2],62,62)
 M.protect("чужой тайник: Think",S.StashFrame.Think,S.StashFrame)
 check(S.StashFrame.Slots[2]:GetItem()==S.Foreign.items[2],"ячейка показывает предмет чужого тайника")
 M.netSent={};S.LootPending=0;M.protect("забрать предмет",S.HandleDrop,S.StashFrame.Slots[2],S.Frame.GridSlots[1])
 check(lastSent("stalker_stash.loot"),"перетаскивание в рюкзак отправляет запрос")
 M.netSent={};M.protect("положить в чужой",S.HandleDrop,S.Frame.GridSlots[1],S.StashFrame.Slots[1])
 check(not lastSent("stalker_stash.loot"),"в чужой тайник положить нельзя")
 l,v=packet({close=true});M.netReceive("stalker_stash.foreign",l,nil,v)
 check(S.Foreign==nil,"сервер закрыл окно чужого тайника")
 S.Close()
 -- Список наводок, подсказка у места, вкладка КПК.
 l,v=packet({list={{id="i2",owner="Сосед",map=game.GetMap(),pos={x=50,y=0,z=0},left=3600}}})
 M.netReceive("stalker_stash.intel",l,nil,v)
 check(#S.Intel==1 and S.Intel[1].owner=="Сосед","список наводок получен")
 check(S.NearestIntelLocal(200)==S.Intel[1],"ближайшее место из наводок")
 M.protect("подсказка у тайника",hook.Run,"HUDPaint")
 check(C.PDATabs.stashes and C.PDATabs.stashes.badge()==1,"вкладка КПК «Тайники» со значком")
 local created={};local orig=vgui.Create
 vgui.Create=function(name,parent) local p=orig(name,parent);created[#created+1]=p;return p end
 M.protect("вкладка КПК: построение",C.PDATabs.stashes.build,M.stub("pda"))
 vgui.Create=orig
 for _,p in ipairs(created) do
  local paint=rawget(p,"Paint");if type(paint)=="function" then M.protect("вкладка КПК: отрисовка",paint,p,600,400) end
  local think=rawget(p,"Think");if type(think)=="function" then M.protect("вкладка КПК: Think",think,p) end
 end
 S.Intel={};S.Inventory=S.EmptyInventory();S.SelectedUID=nil
end
