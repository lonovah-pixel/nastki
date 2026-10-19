-- Казна группировок: доход территорий, журнал операций, снятие и выплаты лидером.
-- Деньги DarkRP начисляются только после успешной записи мира в SQLite.
local F=STFW

-- Запись журнала (последние LedgerSize). Доход подряд склеивается в одну строку, чтобы журнал не забивался.
function F.Ledger(d,kind,amount,who,note)
 local last=d.ledger[#d.ledger]
 if kind=="income" and last and last.kind=="income" and os.time()-(last.t or 0)<3600 then
  last.amount=last.amount+amount;last.n=(last.n or 1)+1;last.t=os.time();return
 end
 d.ledger[#d.ledger+1]={t=os.time(),kind=kind,amount=amount,who=who,note=note}
 while #d.ledger>math.max(1,F.Config.LedgerSize) do table.remove(d.ledger,1) end
end

-- Кошелёк DarkRP загружен. До загрузки данных игрока (DarkRPUnInitialized) money=nil, и addMoney падает
-- на сложении (DarkRP sv_money.lua): начисление после записи мира терялось бы вместе с остальными выплатами.
function F.WalletReady(p)
 return IsValid(p) and p.addMoney~=nil and p.getDarkRPVar~=nil and not p.DarkRPUnInitialized and type(p:getDarkRPVar("money"))=="number"
end
local function pays(pt,online)
 return pt.owner~="" and online[pt.owner] and not pt.contested and not pt.armed and (pt.progress or 0)==0
end
-- Ожидаемый доход группировки за интервал (для меню лидера).
function F.ExpectedIncome(id,world)
 world=world or F.World
 local money,supply,held=0,0,0
 for _,pt in pairs(world.points) do if pt.owner==id then
  held=held+1
  if not pt.contested and not pt.armed and (pt.progress or 0)==0 then
   money=money+math.max(0,math.floor(F.Config.PointIncome[pt.kind or "checkpoint"] or 0));supply=supply+F.Config.SupplyPerTerritory
  end
 end end
 return money,supply,held
end

--[[ Доход территорий за интервал (изменяет копию мира w).
 Деньги обычных группировок — в казну; доход точек одиночек делится поровну между одиночками в сети.
 Возвращает changed и список выплат {игрок, сумма} — их начисляют после сохранения мира. ]]
function F.AccrueIncome(w)
 local online,loners={},{}
 for _,p in ipairs(player.GetHumans()) do
  local d=F.Load(p)
  if d and d.joined and p:Alive() then online[d.faction]=true end
  if d and d.faction=="loner" and (d.joined or F.Config.LonerIncomeFreeStalkers) and F.WalletReady(p) then loners[#loners+1]=p end
 end
 local money,supply={},{}
 for _,pt in pairs(w.points) do
  if pays(pt,online) then
   supply[pt.owner]=(supply[pt.owner] or 0)+F.Config.SupplyPerTerritory
   money[pt.owner]=(money[pt.owner] or 0)+math.max(0,math.floor(F.Config.PointIncome[pt.kind or "checkpoint"] or 0))
  end
 end
 local changed,payouts=false,{}
 for id,amount in pairs(supply) do
  local d=F.Prog(w,id);local nextValue=math.min(F.Config.SupplyLimit,d.credits+amount)
  if nextValue~=d.credits then d.credits=nextValue;changed=true end
 end
 for id,amount in pairs(money) do
  if amount>0 then
   local d=F.Prog(w,id);d.lastIncome=amount;d.lastIncomeAt=os.time();changed=true
   if id=="loner" then
    local share=#loners>0 and math.floor(amount/#loners) or 0
    if share>0 then for _,p in ipairs(loners) do payouts[#payouts+1]={p,share} end;d.paidOut=(d.paidOut or 0)+share*#loners end
   else
    local before=d.treasury;d.treasury=math.min(F.Config.TreasuryLimit,d.treasury+amount)
    if d.treasury>before then F.Ledger(d,"income",d.treasury-before,"Территории") end
   end
  end
 end
 return changed,payouts
end
function F.PayIncome(payouts)
 for _,row in ipairs(payouts or {}) do
  local p,share=row[1],row[2]
  if F.WalletReady(p) then p:addMoney(share);F.Toast(p,"Доход точек одиночек: +"..F.Money(share),"ok",5) end
 end
end
-- Отдельный запуск дохода (админ-команда и проверки): сохраняет мир и выплачивает одиночкам.
function F.RunIncome()
 local w=table.Copy(F.World)
 local changed,payouts=F.AccrueIncome(w)
 if not changed then return false end
 if not F.Commit(w,{},"income") then return false end
 F.PayIncome(payouts);return true
end

local function amountOK(n) return type(n)=="number" and n==math.floor(n) and n>=1 and n<=1000000000 end
-- Лидер снимает деньги из казны себе в кошелёк.
function F.TreasuryWithdraw(p,amount)
 if not F.IsLeader(p) then return false,"unauthorized" end
 if not amountOK(amount) then return false,"amount_invalid" end
 if not F.WalletReady(p) then return false,"no_darkrp" end
 local id=F.Load(p).faction;local w=table.Copy(F.World);local d=F.Prog(w,id)
 if d.treasury<amount then return false,"treasury_low" end
 d.treasury=d.treasury-amount;F.Ledger(d,"withdraw",-amount,p:Nick(),"Снято лидером")
 if not F.Commit(w,{},"treasury withdraw "..id.." "..amount) then return false,"storage" end
 p:addMoney(amount)
 return true,nil,"Из казны получено "..F.Money(amount)
end
-- Выплата члену группировки в сети.
function F.TreasuryPayout(p,sid,amount)
 if not F.IsLeader(p) then return false,"unauthorized" end
 if not amountOK(amount) then return false,"amount_invalid" end
 local id=F.Load(p).faction
 local target=F.ValidSID(sid) and F.OnlineBySID(sid)
 if not target then return false,"member_offline" end
 local d=F.Load(target);if not d or not d.joined or d.faction~=id then return false,"not_member" end
 if not F.WalletReady(target) then return false,"no_darkrp" end
 local w=table.Copy(F.World);local prog=F.Prog(w,id)
 if prog.treasury<amount then return false,"treasury_low" end
 prog.treasury=prog.treasury-amount;F.Ledger(prog,"payout",-amount,p:Nick(),"Выплата: "..target:Nick())
 if not F.Commit(w,{},"treasury payout "..id.." "..sid.." "..amount) then return false,"storage" end
 target:addMoney(amount)
 if target~=p then F.Toast(target,"Выплата из казны «"..F.Name(id).."»: +"..F.Money(amount),"ok") end
 return true,nil,"Выплачено "..target:Nick()..": "..F.Money(amount)
end
-- Администратор: начислить доход вне очереди (проверка экономики на тестовом сервере).
concommand.Add("stfw_income",function(p)
 if IsValid(p) and not F.IsAdmin(p) then return end
 local ok=F.RunIncome();local text=ok and "Доход территорий начислен" or "Доход не начислен: нет удерживаемых точек с живыми членами в сети"
 if IsValid(p) then F.Toast(p,text,ok and "ok" or "warn") else print("[STFW] "..text) end
end)
