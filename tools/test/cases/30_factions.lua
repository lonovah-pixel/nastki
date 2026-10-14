-- STALKER Factions 2.0: вступление через NPC и приглашения, лимит состава, запрет лидера, звания,
-- захват по действию на флаге, казна и доход территорий, способности командования, меню и КПК.
-- Область мира: X 1 000 000…1 400 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local F,C,MK,S=STFW,STALKER_CORE,STALKER_MARKERS,STALKER_SETTINGS
section("Группировки 2.0: загрузка ("..M.Realm..")")
check(F and F.Config.CaptureActionSeconds==8 and F.Config.CaptureWindow==180 and F.Config.MaxMembers==15 and F.Config.LeaderBanCost==500000,"новые параметры конфигурации")
check(F.Config.PointIncome.base and F.Config.PointIncome.camp and F.Config.PointIncome.resource and F.Config.PointIncome.checkpoint and F.Config.IncomeInterval==60,"доход по типам точек")
check(type(F.Invite)=="function" or CLIENT,"STFW.Invite (сервер)")
check(type(F.IsMember)=="function" and type(F.Treasury)=="function","STFW.IsMember и STFW.Treasury")
check(#F.FactionRanks==5 and F.FactionRanks[4]=="Офицер","звания группировки")
for _,id in ipairs(F.AbilityOrder) do check(F.Abilities[id] and F.Abilities[id].cost and F.Abilities[id].cooldown,"способность "..id) end
for _,id in ipairs({"factions.join_fee","factions.max_members","factions.cap_duty","factions.capture_action","factions.capture_window","factions.capture_seconds",
 "factions.income_base","factions.income_camp","factions.income_resource","factions.income_checkpoint","factions.income_interval","factions.ban_cost",
 "factions.spawn_protection","factions.victory_score","factions.radar_range","factions.ability_rally_cooldown","factions.ability_mobilize_cost"}) do
 local def=S.Defs[id];check(def and def.category=="Группировки" and def.realm=="shared","настройка "..id)
end
check(scripted_ents.Get("stalker_flag"),"сущность флага зарегистрирована")
check(F.L("faction_full")=="Группировка заполнена","текст «Группировка заполнена»")

-- Последнее сообщение сети и его содержимое (STALKER_CORE.Send: размер + сжатый JSON).
local function lastSent(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end

if SERVER then
 local X=1000000
 local changed={}
 hook.Add("STFW_FactionChanged","TEST.Factions",function(p,id) changed[#changed+1]={p=p,id=id} end)
 local function joinedHook(p,id) for _,c in ipairs(changed) do if c.p==p and c.id==id then return true end end;return false end
 local players={}
 local function join(nick,x,y,extra)
  local o=extra or {};o.nick=nick;o.pos=Vector(X+x,y or 0,0)
  local p=TEST.join(o);p.StfwProtected=0;players[#players+1]=p;return p
 end
 local admin=join("Админ ГП",50000,0,{superadmin=true})
 local leader=join("Лидер Долга",200000,0)
 local recruit=join("Новобранец",200100,0)
 local guest=join("Гость",200200,0)
 local extra=join("Лишний",200300,0)
 check(F.Load(leader) and F.Load(leader).frank==1,"новый профиль: звание по умолчанию")

 section("Группировки 2.0: вступление")
 check(F.SetFaction(leader,"duty",true),"администратор включает в «Долг»")
 check(joinedHook(leader,"duty"),"хук STFW_FactionChanged при принудительном вступлении")
 check(F.Editor(admin,{op="leader",faction="duty",sid=leader:SteamID64()}),"лидер назначен")
 check(F.IsLeader(leader) and F.Role(leader)=="leader" and leader:GetNW2Bool("stfw_leader",false),"роль лидера и сетевая переменная")
 check(F.IsMember(leader,"duty") and not F.IsMember(recruit,"duty"),"STFW.IsMember")
 -- Вербовщик: окно с составом, взносом и репутацией, затем оплата взноса кнопкой.
 local npc=ents.Create("stalker_recruiter");npc:SetFactionID("duty");npc:SetPos(Vector(X+200150,0,0));npc:Spawn()
 recruit._money=10000;M.netSent={}
 F.SendRecruit(recruit,npc)
 local info=decode(lastSent("stfw.recruit",recruit))
 check(info and info.ok and info.fee==5000 and info.members==1 and info.cap==15 and info.leaderOnline==true,"окно вербовщика: состав, взнос, лидер в сети")
 local len,vals={17},{npc:EntIndex(),true}
 M.netReceive("stfw.recruit",17,recruit,vals)
 check(F.IsMember(recruit,"duty") and recruit._money==5000,"взнос оплачен и вступление выполнено")
 check(joinedHook(recruit,"duty"),"хук STFW_FactionChanged при вступлении у вербовщика")
 check(recruit:GetNW2Int("stfw_frank",0)==1,"новичок — «Рядовой»")
 -- Приглашение: окно у цели и вступление без взноса.
 M.netSent={};guest._money=100
 local ok,err=F.Invite(leader,guest)
 check(ok,"лидер приглашает игрока: "..tostring(err))
 local inv=decode(lastSent("stfw.invite",guest))
 check(inv and inv.faction=="duty" and inv.token and inv.seconds==F.Config.InviteSeconds,"приглашение отправлено цели")
 check(select(2,F.Invite(leader,guest))=="invite_pending","повторное приглашение ждёт ответа")
 local l,v=packet({token=inv.token,accept=true});M.netReceive("stfw.invite",l,guest,v)
 check(F.IsMember(guest,"duty") and guest._money==100,"приглашение принято без взноса")
 check(joinedHook(guest,"duty"),"хук STFW_FactionChanged при вступлении по приглашению")
 check(select(2,F.Invite(guest,extra))=="unauthorized","рядовой не может приглашать")
 -- Отказ от приглашения не меняет членство.
 F.Invite(leader,extra);local inv2=decode(lastSent("stfw.invite",extra))
 l,v=packet({token=inv2.token,accept=false});M.netReceive("stfw.invite",l,extra,v)
 check(not F.IsMember(extra,"duty") and F.Invites[extra:SteamID64()]==nil,"отказ от приглашения")

 section("Группировки 2.0: лимит состава")
 F.Config.JoinCaps.duty=3
 check(F.MemberCount("duty")==3 and F.IsFull("duty"),"состав 3 из 3")
 local can,why=F.CanJoin(extra,"duty");check(not can and why=="faction_full","полная группировка: faction_full")
 check(F.RecruitInfo(extra,"duty").reason=="faction_full","вербовщик показывает «Группировка заполнена»")
 check(select(2,F.Invite(leader,extra))=="faction_full","приглашение в полную группировку отклонено")
 extra._money=10000;M.netSent={};F.SendRecruit(extra,npc)
 M.netReceive("stfw.recruit",17,extra,{npc:EntIndex(),true})
 check(not F.IsMember(extra,"duty") and extra._money==10000,"взнос не списан, вступления нет")
 F.Config.JoinCaps.duty=0
 check(F.MemberCap("duty")==15,"общий лимит, если личный 0")

 section("Группировки 2.0: звания и исключение")
 for i=1,3 do F.Command(leader,{op="rank",sid=recruit:SteamID64(),delta=1}) end
 check(F.Load(recruit).frank==4 and F.Role(recruit)=="officer","повышение до офицера")
 check(select(2,F.SetRank(recruit,guest:SteamID64(),1))=="unauthorized","офицер не меняет звания")
 check(select(2,F.SetRank(leader,leader:SteamID64(),1))~=nil,"лидеру звание не меняется")
 check(F.Invite(recruit,extra),"офицер приглашает")
 F.Invites[extra:SteamID64()]=nil
 check(F.KickMember(recruit,guest:SteamID64()),"офицер исключает младшего")
 check(not F.IsMember(guest,"duty"),"рядовой исключён")
 check(select(2,F.KickMember(recruit,leader:SteamID64()))=="unauthorized","офицер не исключает лидера")
 -- Профиль не в сети: лидер меняет звание по SteamID64.
 local away=join("Боец не в сети",200400,0);F.SetFaction(away,"duty",true);local awaySID=away:SteamID64()
 hook.Run("PlayerDisconnected",away);M.removePlayer(away)
 check(F.SetRank(leader,awaySID,1),"повышение профиля не в сети")
 local row=sql.Query("SELECT payload FROM stfw_profiles WHERE sid="..sql.SQLStr(awaySID))
 check(row and util.JSONToTable(row[1].payload).frank==2,"звание сохранено в SQLite")
 check(F.MemberCount("duty")==3,"профиль не в сети считается в составе")

 section("Группировки 2.0: запрет вступления")
 F.SetFaction(guest,"duty",true)
 leader._money=600000
 ok,err=F.Command(leader,{op="ban",sid=guest:SteamID64()})
 check(ok and leader._money==100000,"запрет оплачен из кошелька лидера: "..tostring(err))
 check(not F.IsMember(guest,"duty"),"запрещённый член исключён")
 can,why=F.CanJoin(guest,"duty");check(not can and why=="leader_banned","CanJoin → leader_banned")
 check(select(2,F.Invite(leader,guest))=="leader_banned","приглашение запрещённого отклонено")
 leader._money=600000
 check(select(2,F.BanJoin(leader,extra:SteamID64()))=="ban_slot_taken","один запрет на лидера")
 check(select(2,F.BanJoin(recruit,extra:SteamID64()))=="unauthorized","офицер не запрещает вступление")
 F.Editor(admin,{op="leader",faction="duty",sid=recruit:SteamID64()})
 check(F.ActiveBan("duty")==nil and select(2,F.CanJoin(guest,"duty"))~="leader_banned","смена лидера снимает запрет")
 F.Editor(admin,{op="leader",faction="duty",sid=leader:SteamID64()})
 check(F.ActiveBan("duty")==nil,"запрет не возвращается с прежним лидером")
 check(F.BanJoin(leader,extra:SteamID64()) and F.LiftBan(leader) and F.ActiveBan("duty")==nil,"лидер снимает запрет (без возврата)")
 leader._money=0
 check(select(2,F.BanJoin(leader,extra:SteamID64()))=="ban_money","без денег запрет недоступен")

 section("Группировки 2.0: захват по действию")
 admin:SetPos(Vector(X+100000,0,0))
 local okp,errp,pointID=F.Editor(admin,{op="create",placement="feet",name="Тестовый блокпост",pointType="checkpoint",radius=400,height=200,radiation=0,anomaly=0,base=false,owner="duty"})
 check(okp and pointID,"точка создана: "..tostring(errp))
 admin:SetPos(Vector(X+50000,0,0))
 local function flagOf(id) for _,e in ipairs(ents.FindByClass("stalker_flag")) do if e:GetPointID()==id then return e end end end
 local flag=flagOf(pointID)
 check(flag and flag:GetOwnerID()=="duty" and flag:GetPointName()=="Тестовый блокпост","флаг поставлен на точке")
 local marker=MK.Get("stfw.flag."..pointID)
 check(marker and marker.kind=="flag" and marker.world==false,"метка флага для карты КПК (без флажка в мире)")
 check(F.Diplomacy(admin,{op="war",from="freedom",to="duty"}),"война объявлена")
 local attacker=join("Штурмовик",100060,0);F.SetFaction(attacker,"freedom",true);attacker.StfwProtected=0
 local function aimAt(p,e) p._aim=e:WorldSpaceCenter() end
 local point=function() return F.World.points[pointID] end
 M.advance(5)
 check((point().progress or 0)==0 and not point().armed,"без действия захват не идёт")
 aimAt(attacker,flag);attacker:SetKey(IN_USE,true);M.netSent={}
 flag:Use(attacker,attacker)
 check(C.Hold.IsHolding(attacker),"удержание E на флаге началось")
 M.advance(F.Config.CaptureActionSeconds+.5,.1);attacker:SetKey(IN_USE,false)
 check(point().armed=="freedom","точка вооружена для «Свободы»")
 local warned=false;for _,s in ipairs(M.netSent) do if s.name=="stalker_core.notify" and s.to==leader then warned=true end end
 check(warned,"владельцы получили оповещение")
 local news=false;for _,s in ipairs(M.netSent) do if s.name=="stalker_core.news" then local d=decode(s);if d and d.items and d.items[1].text:find("Начат захват точки",1,true) then news=true end end end
 check(news,"лента КПК: «Начат захват точки»")
 check(flagOf(pointID):GetArmedID()=="freedom","флаг показывает захват")
 M.advance(10)
 local p10=point().progress or 0
 check(p10>.1 and p10<.25,"прогресс захвата идёт только после действия: "..p10)
 -- Защитник удержанием E сбрасывает захват.
 local defender=join("Защитник",100040,30);F.SetFaction(defender,"duty",true);defender.StfwProtected=0
 aimAt(defender,flag);defender:SetKey(IN_USE,true)
 flag:Use(defender,defender)
 M.advance(F.Config.DefendActionSeconds+.5,.1);defender:SetKey(IN_USE,false)
 check(not point().armed and (point().progress or 0)==0,"защитник сбросил захват")
 defender:SetPos(Vector(X+300000,0,0))
 -- Мобилизация ускоряет захват на 50%.
 F.Editor(admin,{op="leader",faction="freedom",sid=attacker:SteamID64()})
 local w=table.Copy(F.World);F.Prog(w,"freedom").credits=500;F.Commit(w,{})
 ok,err=F.UseAbility(attacker,"mobilize")
 check(ok and F.BuffActive("freedom","mobilize") and math.abs(F.CaptureRate(F.World,"freedom")-1.5)<.001,"мобилизация: +50% к скорости захвата: "..tostring(err))
 attacker.StfwFlagUse=0;attacker:SetKey(IN_USE,true);flag:Use(attacker,attacker)
 M.advance(F.Config.CaptureActionSeconds+.5,.1);attacker:SetKey(IN_USE,false)
 check(point().armed=="freedom","повторное вооружение")
 local before=point().progress or 0
 M.advance(10)
 local gained=(point().progress or 0)-before
 check(gained>.2 and gained<.3,"скорость захвата с мобилизацией: "..gained)
 for _=1,80 do if point().owner=="freedom" then break end;M.advance(1) end
 check(point().owner=="freedom" and not point().armed,"точка захвачена «Свободой»")
 check((C.GetStats(attacker).captures or 0)>=1,"статистика захватов")
 check(C.NewsFeed[1] and C.NewsFeed[1].text:find("захватили",1,true),"новость о захвате")
 check(flagOf(pointID):GetOwnerID()=="freedom","флаг сменил владельца")
 -- Окно: атакующие ушли дольше окна — сброс.
 F.Editor(admin,{op="capture",id=pointID,faction="duty"})
 F.Config.CaptureWindow=5
 attacker.StfwFlagUse=0;attacker:SetKey(IN_USE,true);flag=flagOf(pointID);aimAt(attacker,flag);flag:Use(attacker,attacker)
 M.advance(F.Config.CaptureActionSeconds+.5,.1);attacker:SetKey(IN_USE,false)
 check(point().armed=="freedom","вооружение перед уходом")
 attacker:SetPos(Vector(X+150000,0,0));M.advance(7)
 check(not point().armed and (point().progress or 0)==0,"уход атакующих дольше окна сбрасывает захват")
 F.Config.CaptureWindow=180
 -- Условия действия.
 attacker:SetPos(Vector(X+100060,0,0))
 local eco=join("Эколог",100030,-20);F.SetFaction(eco,"ecologists",true);eco.StfwProtected=0
 check(F.ArmBlock(eco,point())=="territory_war","без войны захват чужой точки недоступен")
 eco:SetPos(Vector(X+300100,0,0))
 local free=join("Вольный",100050,20)
 check(F.ArmBlock(free,point())=="capture_need_member","вольный сталкер не захватывает")
 free:SetPos(Vector(X+300200,0,0))
 check(F.ArmBlock(attacker,point())==nil,"член воюющей группировки может начать захват")
 defender:SetPos(Vector(X+100040,30,0))
 check(F.ArmBlock(attacker,point())=="territory_contested","оспаривание блокирует действие")
 defender:SetPos(Vector(X+300000,0,0));attacker:SetPos(Vector(X+150000,0,0))
 -- Флаги восстанавливаются.
 flagOf(pointID):Remove();F.SyncFlags()
 check(flagOf(pointID),"флаг восстановлен после удаления")
 local hooks=hook.GetTable()
 check(hooks.PostCleanupMap and hooks.PostCleanupMap["STFW.Flags"] and hooks.InitPostEntity["STFW.Flags"],"флаги восстанавливаются при загрузке и очистке карты")

 section("Группировки 2.0: казна и доход")
 M.advance(3)
 local t0=F.Treasury("duty");local s0=F.ProgRead("duty").credits
 check(F.RunIncome(),"доход территорий начислен")
 check(F.Treasury("duty")==t0+F.Config.PointIncome.checkpoint,"деньги точки в казне: "..F.Treasury("duty"))
 check(F.ProgRead("duty").credits==s0+F.Config.SupplyPerTerritory,"очки снабжения")
 local ledger=F.ProgRead("duty").ledger
 check(ledger[#ledger] and ledger[#ledger].kind=="income","журнал казны: доход")
 -- Одиночки: доход точки делится между одиночками в сети.
 admin:SetPos(Vector(X+120000,0,0))
 local okl,_,lonerPoint=F.Editor(admin,{op="create",placement="feet",name="Лагерь одиночек",pointType="camp",radius=300,height=200,radiation=0,anomaly=0,base=false,owner="loner"})
 admin:SetPos(Vector(X+50000,0,0))
 local l1=join("Одиночка 1",250000,0);local l2=join("Одиночка 2",250100,0)
 F.SetFaction(l1,"loner",true);F.SetFaction(l2,"loner",true)
 local loners=0;for _,p in ipairs(player.GetHumans()) do local d=F.Load(p);if d and d.joined and d.faction=="loner" then loners=loners+1 end end
 local m1,m2=l1._money,l2._money
 F.RunIncome()
 local share=math.floor(F.Config.PointIncome.camp/loners)
 check(okl and l1._money==m1+share and l2._money==m2+share,"одиночки получили доход поровну: +"..share)
 check(F.Treasury("loner")==0,"казна одиночек не копится")
 -- Нет живого члена в сети — нет дохода.
 for _,p in ipairs(player.GetHumans()) do local d=F.Load(p);if d and d.joined and d.faction=="loner" then M.kill(p) end end
 m1=l1._money;F.RunIncome()
 check(l1._money==m1,"без живых членов в сети точка не приносит дохода")
 M.spawn(l1);M.spawn(l2)
 -- Лидер: снятие и выплаты.
 local money=leader._money;local tr=F.Treasury("duty")
 ok,err=F.Command(leader,{op="withdraw",amount=100})
 check(ok and leader._money==money+100 and F.Treasury("duty")==tr-100,"лидер снял деньги из казны: "..tostring(err))
 check(select(2,F.TreasuryWithdraw(leader,10000000))=="treasury_low","снять больше казны нельзя")
 check(select(2,F.TreasuryWithdraw(leader,-5))=="amount_invalid","отрицательная сумма отклонена")
 check(select(2,F.TreasuryWithdraw(recruit,10))=="unauthorized","офицер не снимает деньги")
 money=recruit._money
 check(F.TreasuryPayout(leader,recruit:SteamID64(),20) and recruit._money==money+20,"выплата бойцу")
 check(select(2,F.TreasuryPayout(leader,extra:SteamID64(),20))=="not_member","выплата чужому отклонена")
 ledger=F.ProgRead("duty").ledger
 check(ledger[#ledger].kind=="payout" and ledger[#ledger-1].kind=="withdraw","журнал: снятие и выплата")
 local rowW=sql.Query("SELECT payload FROM stfw_world WHERE map="..sql.SQLStr(game.GetMap()))
 local saved=rowW and util.JSONToTable(rowW[1].payload)
 check(saved and saved.progression.duty.treasury==F.Treasury("duty"),"казна сохранена в SQLite")

 section("Группировки 2.0: способности")
 w=table.Copy(F.World);F.Prog(w,"duty").credits=200;F.Commit(w,{})
 leader:SetPos(Vector(X+200000,0,0));recruit:SetPos(Vector(X+200100,0,0))
 ok,err=F.UseAbility(leader,"rally")
 check(ok and MK.Get("stfw.rally.duty") and MK.Get("stfw.rally.duty").kind=="rally","сбор: метка для группировки: "..tostring(err))
 check(F.ProgRead("duty").credits==200-F.Abilities.rally.cost,"стоимость списана")
 check(F.CooldownLeft("duty","rally")>0 and select(2,F.UseAbility(leader,"rally"))=="ability_cooldown","перезарядка")
 local saved2=util.JSONToTable(sql.Query("SELECT payload FROM stfw_world WHERE map="..sql.SQLStr(game.GetMap()))[1].payload)
 check(saved2.progression.duty.cooldowns.rally,"перезарядка хранится в мире")
 -- Боевой клич: −20% урона.
 local function hit(p,n) local before=p:Health();local d=DamageInfo();d:SetDamage(n);d:SetDamageType(DMG_GENERIC);d:SetAttacker(game.GetWorld());d:SetInflictor(game.GetWorld());p:TakeDamageInfo(d);return before-p:Health() end
 recruit:SetHealth(100);local plain=hit(recruit,50);recruit:SetHealth(100)
 check(F.UseAbility(recruit,"warcry"),"офицер применяет боевой клич")
 local reduced=hit(recruit,50)
 check(plain>0 and math.abs(reduced-plain*.8)<.01,"боевой клич снижает урон: "..plain.." → "..reduced)
 recruit:SetHealth(30)
 if recruit.StalkerInventory then recruit.StalkerInventory.dose=50 end
 check(F.UseAbility(leader,"hospital"),"полевой госпиталь")
 check(recruit:Health()==80,"госпиталь лечит: "..recruit:Health())
 if recruit.StalkerInventory then check(recruit.StalkerInventory.dose<=30.01,"госпиталь снижает дозу: "..tostring(recruit.StalkerInventory.dose)) end
 attacker:SetPos(Vector(X+201000,0,0))
 check(F.UseAbility(leader,"recon") and MK.Get("stfw.recon.duty."..attacker:SteamID64()),"разведка отмечает воюющих")
 check(MK.Get("stfw.recon.duty."..attacker:SteamID64()).kind=="enemy","метка противника")
 local bandages=STALKER_INV and STALKER_INV.CountItem(recruit,"bandage") or 0
 check(F.UseAbility(leader,"supply"),"снабжение")
 if STALKER_INV then check(STALKER_INV.CountItem(recruit,"bandage")==bandages+F.Abilities.supply.bandages,"бинты выданы") end
 check(select(2,F.UseAbility(recruit,"mobilize"))=="ability_rank","офицеру недоступна способность лидера")
 local private=join("Рядовой",200150,0);F.SetFaction(private,"duty",true)
 check(select(2,F.UseAbility(private,"warcry"))=="ability_rank","рядовому способности недоступны")
 w=table.Copy(F.World);F.Prog(w,"freedom").credits=0;F.Commit(w,{})
 check(select(2,F.UseAbility(attacker,"warcry"))=="supply_low","не хватает очков снабжения")
 M.command(leader,"stfw_ability","mobilize")
 check(F.BuffActive("duty","mobilize"),"консольная команда stfw_ability")
 check(hook.Run("PlayerSay",leader,"!ability rally")=="","чат-команда !ability")

 section("Группировки 2.0: данные меню")
 M.netSent={};F.SendState(leader)
 local st=decode(lastSent("stfw.state",leader))
 check(st and st.command and st.command.role=="leader" and type(st.command.treasury)=="number","меню лидера: казна")
 local inRoster=false;for _,m in ipairs(st.command.roster) do if m.sid==recruit:SteamID64() and m.frank==4 then inRoster=true end end
 check(inRoster and st.command.ledger and #st.command.ledger>0,"меню лидера: состав и журнал")
 check(st.progression.duty and st.progression.freedom==nil,"чужая казна не уходит клиенту")
 check(st.command.cooldowns.rally>0 and st.command.cap==15,"перезарядки и лимит в меню")
 M.netSent={};F.SendState(private)
 st=decode(lastSent("stfw.state",private))
 check(st and st.command==nil and st.progression.duty.treasury==nil and st.me.frank==1,"рядовой не видит казну и меню")
 M.netSent={};F.SendState(recruit)
 st=decode(lastSent("stfw.state",recruit))
 check(st and st.command and st.command.role=="officer" and st.command.ledger==nil,"офицер: меню без журнала казны")
 -- Команды по сети проверяются на сервере.
 l,v=packet({op="withdraw",amount=5});M.netReceive("stfw.cmd",l,private,v)
 check(F.Treasury("duty")>0 and private._money==3000,"рядовой не снимает деньги по сети")

 section("Группировки 2.0: совместимость данных")
 local oldSID="76561198099999001"
 sql.Query("INSERT OR REPLACE INTO stfw_profiles VALUES("..sql.SQLStr(oldSID)..","..sql.SQLStr('{"faction":"duty","joined":true,"xp":7,"rep":{}}')..")")
 local old=join("Старый профиль",200500,0,{sid=oldSID})
 local d=F.Load(old)
 check(d and d.faction=="duty" and d.frank==1 and d.kills==0 and d.captures==0,"старый профиль получает новые поля")
 check(F.ActiveBan("duty",{leaders={}})==nil,"мир без запретов")
 local prog=F.Prog({progression={duty={credits=5,levels={}}}},"duty")
 check(prog.treasury==0 and prog.credits==5 and type(prog.ledger)=="table" and type(prog.cooldowns)=="table","старое развитие группировки получает казну и журнал")

 section("Группировки 2.0: очистка")
 F.Editor(admin,{op="delete",id=pointID});F.Editor(admin,{op="delete",id=lonerPoint})
 check(not flagOf(pointID) and not MK.Get("stfw.flag."..pointID),"удаление точки убирает флаг и метку")
 F.Diplomacy(admin,{op="stop",from="freedom",to="duty"})
 MK.Clear("stfw.rally.");MK.Clear("stfw.recon.")
 npc:Remove();hook.Remove("STFW_FactionChanged","TEST.Factions")
 -- Мир общий для сценариев: снимаем лидеров и членство тестовых профилей.
 F.Editor(admin,{op="leader",faction="duty",sid=""});F.Editor(admin,{op="leader",faction="freedom",sid=""})
 for _,p in ipairs(players) do F.ExpelSID(p:SteamID64()) end;F.ExpelSID(awaySID)
 check(F.MemberCount("duty")==0 and F.MemberCount("freedom")==0,"тестовые профили исключены")
 for _,p in ipairs(players) do if p._valid then M.removePlayer(p) end end
else
 section("Группировки 2.0: клиент")
 local T=STALKER_THEME
 check(F.C.accent.r==T.C.accent.r and F.C.red.r==T.C.danger.r and F.C.green.g==T.C.ok.g,"цвета группировок из темы")
 T.Apply("pda");check(F.C.accent.r==T.Presets.pda.accent.r and F.C.accent.g==T.Presets.pda.accent.g,"смена темы перекрашивает интерфейс группировок")
 T.Apply("zone")
 check(type(F.BuildAdminPanel)=="function","STFW.BuildAdminPanel")
 check(C.PDATabs.factions and C.PDATabs.factions.order==40 and C.PDATabs.factions.title=="Группировка","вкладка КПК «Группировка»")
 local lp=LocalPlayer();local sid=lp:SteamID64()
 F.State={me={faction="duty",joined=true,xp=120,rep={duty=10},captures=1,kills=2,frank=5,role="leader"},role="leader",leader=true,admin=true,
  points={p1={id="p1",name="Склад",kind="checkpoint",owner="duty",pos={x=0,y=0,z=0},radius=300,height=200,radiation=0,anomaly=0,progress=.3,armed="freedom"},
   p2={id="p2",name="Хутор",kind="camp",owner="",pos={x=500,y=500,z=0},radius=300,height=200,radiation=0,anomaly=0,progress=0}},
  relations={["duty:freedom"]={points=-60,war=true,scores={duty=3,freedom=5}}},leaders={duty=sid},
  proposals={x={from="freedom",to="duty",points=10,peace=true,token="t"}},history={{winner="duty",loser="freedom",time=os.time()}},top={{name="Я",xp=120,captures=1}},
  members={{sid=sid,name="Я",faction="duty",joined=true}},traders={},progression={duty={credits=50,levels={},treasury=1000}},revision=0,serverTime=os.time(),count=2,cap=15,
  summary={members={duty=2},caps={duty=15}},
  command={role="leader",leader=sid,roster={{sid=sid,name="Я",frank=5,online=true,leader=true,xp=100},{sid="76561198000000099",name="Боец",frank=2,online=false,xp=5}},
   candidates={{sid="76561198000000098",name="Новичок"},{sid="76561198000000096",name="Изгой",banned=true}},count=2,cap=15,online=1,credits=50,
   income={money=150,supply=1,held=1,interval=60,last=150},cooldowns={rally=30,warcry=0},buffs={mobilize=20},treasury=1000,
   ledger={{t=os.time(),kind="income",amount=150,who="Территории",n=2},{t=os.time(),kind="withdraw",amount=-50,who="Я",note="Снято лидером"}},
   approvals={{sid="76561198000000097",name="Допущенный",expires=3600}},banCost=500000}}
 F.StateAt=CurTime()
 check(F.Treasury("duty")==1000,"STFW.Treasury на клиенте")
 lp:SetNW2Bool("stfw_joined",true);lp:SetNW2String("stfw_faction","duty")
 check(F.IsMember(lp,"duty") and not F.IsMember(lp,"freedom"),"STFW.IsMember на клиенте")
 -- Окна строятся без ошибок; затем отрисовываем все созданные панели.
 local created={};local orig=vgui.Create
 vgui.Create=function(name,parent) local p=orig(name,parent);created[#created+1]=p;return p end
 for _,id in ipairs({"overview","roster","treasury","abilities","diplomacy","admission"}) do M.protect("меню командования: "..id,F.CommandPages[id],M.stub("body"),F.State,F.State.command) end
 local officer=table.Copy(F.State.command);officer.role="officer";officer.treasury=nil;officer.ledger=nil
 for _,id in ipairs({"overview","roster","abilities","admission"}) do M.protect("меню офицера: "..id,F.CommandPages[id],M.stub("body"),F.State,officer) end
 F.State.command.ban={sid="76561198000000096",name="Изгой",t=os.time()}
 M.protect("вступление с запретом",F.CommandPages.admission,M.stub("body"),F.State,F.State.command)
 check(M.protect("открыть меню командования",F.OpenCommand),"меню командования открывается")
 M.command(nil,"stfw_leader")
 M.protect("F6",F.Open)
 for _,tab in ipairs({"status","map","rank"}) do M.protect("F6: "..tab,F.ShowPage,tab) end
 M.protect("админ-панель",F.Open,"admin","admin")
 for _,tab in ipairs({"admin","people","diplomacy_admin","traders"}) do M.protect("админ: "..tab,F.ShowPage,tab) end
 F.ShowRecruit({faction="duty",ent=1,ok=true,reason="",fee=5000,members=2,cap=15,rep=0,minRep=-100,leaderName="Лидер",leaderOnline=true,money=10000,current="loner"})
 check(F.RecruitFrame~=nil,"окно вербовщика")
 check(F.RecruitJoinLabel({ok=false,reason="faction_full"})=="Группировка заполнена","полная группировка: кнопка недоступна")
 check(F.RecruitJoinLabel({ok=true,reason="",fee=5000}):find("Оплатить взнос",1,true),"кнопка «Оплатить взнос и вступить»")
 local prev=F.RecruitFrame
 local l,v=packet({faction="freedom",ent=1,ok=false,reason="faction_full",fee=5000,members=15,cap=15,rep=0,minRep=-100})
 M.netReceive("stfw.recruit",l,nil,v)
 check(F.RecruitFrame~=prev,"окно вербовщика по сети")
 l,v=packet({faction="duty",from="Лидер",seconds=60,token="abc",members=2,cap=15})
 M.netReceive("stfw.invite",l,nil,v)
 check(F.InviteFrame~=nil,"окно приглашения")
 local pda=M.stub("pda");M.protect("вкладка КПК",F.BuildPDATab,pda)
 check(C.PDATabs.factions.badge()==1,"значок вкладки: входящее предложение")
 M.protect("админ-раздел",F.BuildAdminPanel,M.stub("admin"))
 vgui.Create=orig
 local painted=0
 for _,p in ipairs(created) do
  local paint=rawget(p,"Paint");if type(paint)=="function" then painted=painted+1;M.protect("отрисовка панели",paint,p,600,160) end
  local think=rawget(p,"Think");if type(think)=="function" then M.protect("Think панели",think,p) end
 end
 check(painted>20,"панели меню отрисованы: "..painted)
 -- Ожидание данных во вкладке КПК.
 local saved=F.State;F.State=nil
 local waiting=M.stub("pda2");M.protect("вкладка КПК без данных",F.BuildPDATab,waiting)
 F.State=saved;if type(rawget(waiting,"Think"))=="function" then M.protect("вкладка КПК дождалась данных",waiting.Think,waiting) end
 -- HUD: территория под захватом, полоса способностей.
 lp:SetNW2Float("stfw_warcry",CurTime()+10)
 for _,ev in ipairs({{"HUDPaint"},{"HUDShouldDraw","CHudHealth"},{"PostDrawTranslucentRenderables",false,false},{"Think"}}) do M.protect("HUD "..ev[1],hook.Run,unpack(ev)) end
 hook.Run("STFW_StateUpdated",F.State)
 -- Флаг: полотнище и табличка.
 local e=ents.Create("stalker_flag");e:SetOwnerID("duty");e:SetArmedID("freedom");e:SetPointName("Склад");e:SetProgress(.4);e:SetPos(Vector(30,0,0));e:Spawn()
 M.protect("флаг: полотнище",e.Draw,e);M.protect("флаг: табличка",e.DrawTranslucent,e)
 e:SetOwnerID("");e:SetArmedID("");M.protect("ничейный флаг",e.Draw,e);M.protect("ничейный флаг: табличка",e.DrawTranslucent,e)
 e:Remove()
 lp:SetNW2Float("stfw_warcry",0);lp:SetNW2Bool("stfw_joined",false);lp:SetNW2String("stfw_faction","")
 F.State=nil
end
