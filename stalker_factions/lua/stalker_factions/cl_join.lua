--[[ Вступление: окно вербовщика (оплата взноса и вступление кнопкой) и окно приглашения от лидера/офицера.
 Сервер присылает всё, что нужно показать; решение принимает только он. ]]
local F=STFW
local U=STALKER_STYLE
local W=F.UI
local function px(n) return W and W.Px and W.Px(n) or n end

local function header(parent,id,title,subtitle)
 local h=vgui.Create("DPanel",parent);h:Dock(TOP);h:SetTall(px(70));h:DockMargin(0,0,0,px(8))
 h.Paint=function(_,w,hh)
  U.Panel("",0,0,w,hh,true)
  if F.Emblem then F.Emblem(id,px(8),px(8),hh-px(16)) end
  U.Text(title,"STALKER.Title",hh+px(6),px(8),"accent")
  U.Text(subtitle,"STALKER.Small",hh+px(6),px(40),"muted")
 end
 return h
end

-- Подпись кнопки вступления по причине отказа сервера.
local function joinLabel(d)
 if d.reason=="faction_full" then return "Группировка заполнена" end
 if d.reason=="leader_banned" then return "Вступление запрещено лидером" end
 if d.reason=="already_joined" then return "Вы уже в этой группировке" end
 if not d.ok then return "Вступление недоступно" end
 if d.admitted or (d.fee or 0)==0 then return "Вступить"..(d.admitted and " (допуск лидера)" or "") end
 return "Оплатить взнос "..F.Money(d.fee).." и вступить"
end
F.RecruitJoinLabel=joinLabel

function F.ShowRecruit(d)
 local id=d.faction;local faction=F.Factions[id or ""];if not faction then return end
 if IsValid(F.RecruitFrame) then F.RecruitFrame:Remove() end
 local function send()
  net.Start("stfw.recruit");net.WriteUInt(tonumber(d.ent) or 0,16);net.WriteBool(true);net.SendToServer()
  if IsValid(F.RecruitFrame) then F.RecruitFrame:Remove() end
 end
 local label=joinLabel(d)
 local confirm=(d.admitted or (d.fee or 0)==0) and "Вступить в «"..F.Name(id).."»?" or ("Оплатить взнос "..F.Money(d.fee).." и вступить в «"..F.Name(id).."»?")
 if d.current and d.current~=id then confirm=confirm.." Членство в «"..F.Name(d.current).."» будет прекращено." end
 if not U or not U.Window then
  Derma_Query(F.Text(faction.description).."\n\n"..(d.ok and confirm or F.L(d.reason)),F.L("recruit"),d.ok and label or F.L("close"),function() if d.ok then send() end end,F.L("close"))
  return
 end
 local f=U.Window({title="ВЕРБОВЩИК — "..F.Name(id),w=680,h=620});F.RecruitFrame=f
 header(f,id,F.Name(id).."  ["..(faction.tag or "").."]","Вербовщик группировки")
 W.Text(f,"Зона не прощает одиночных ошибок. Нам нужны люди, готовые держать слово и защищать наши территории.","muted","STALKER.Small")
 W.Text(f,F.Text(faction.description),"text")
 W.Text(f,"Цель: "..F.Text(faction.ideology),"muted","STALKER.Small")
 local cap=tonumber(d.cap) or 0;local members=tonumber(d.members) or 0
 W.Card(f,112,function(_,w,h)
  local col=w/2
  U.Text("СОСТАВ","STALKER.Small",px(12),px(8),"muted")
  U.Text(members..(cap>0 and (" / "..cap) or " (без лимита)"),"STALKER.Head",px(12),px(26),cap>0 and members>=cap and "danger" or "text")
  U.Text("ВЗНОС","STALKER.Small",col,px(8),"muted")
  U.Text(d.admitted and "Бесплатно — допуск лидера" or ((d.fee or 0)>0 and F.Money(d.fee) or "Бесплатно"),"STALKER.Head",col,px(26),d.admitted and "ok" or "text")
  U.Text("ВАША РЕПУТАЦИЯ","STALKER.Small",px(12),px(58),"muted")
  U.Text(string.format("%+d",d.rep or 0).."  (нужно не ниже "..(d.minRep or -100)..")","STALKER.Head",px(12),px(76),(d.rep or 0)<(d.minRep or -100) and "danger" or "text")
  U.Text("ЛИДЕР","STALKER.Small",col,px(58),"muted")
  U.Text(d.leaderName and (d.leaderName..(d.leaderOnline and " · в сети" or " · не в сети")) or "не назначен","STALKER.Head",col,px(76),d.leaderOnline and "ok" or "muted")
 end)
 local status
 if d.ok then status=d.current and d.current~=id and ("Можно вступить. Членство в «"..F.Name(d.current).."» будет прекращено, должность лидера прежней группировки снимается.") or "Можно вступить."
 else status=F.L(d.reason)..((tonumber(d.seconds) or 0)>0 and (" — ещё "..W.Time(d.seconds)) or "") end
 if d.ok and not d.admitted and (d.fee or 0)>0 and d.money then status=status.." В кошельке: "..F.Money(d.money).."." end
 W.Text(f,status,d.ok and "ok" or "warn")
 local join=W.Button(f,label,function() Derma_Query(confirm,"Вступление",label,send,"Отмена") end,"accent");join:SetEnabled(d.ok==true)
 W.Text(f,"Без взноса можно вступить по приглашению лидера или офицера группировки — оно придёт окном.","muted","STALKER.Small")
 W.Button(f,F.L("close"),function() f:Remove() end)
 return f
end
net.Receive("stfw.recruit",function(len)
 local d=F.ReadJSON(len);if type(d)=="table" then F.ShowRecruit(d) end
end)

-- Приглашение: окно с отсчётом; ответ уходит на сервер с токеном приглашения.
function F.ShowInvite(d)
 local id=d.faction;local faction=F.Factions[id or ""];if not faction or type(d.token)~="string" then return end
 local function answer(accept)
  F.SendJSON("stfw.invite",nil,{token=d.token,accept=accept})
  if IsValid(F.InviteFrame) then F.InviteFrame:Remove() end
 end
 local seconds=tonumber(d.seconds) or 60;local ends=CurTime()+seconds
 local text="«"..F.Name(id).."»: "..tostring(d.from).." приглашает вас вступить без взноса."
 if not U or not U.Window then Derma_Query(text,"Приглашение","Принять",function() answer(true) end,"Отказаться",function() answer(false) end);return end
 if IsValid(F.InviteFrame) then F.InviteFrame:Remove() end
 local f=U.Window({title="ПРИГЛАШЕНИЕ В ГРУППИРОВКУ",w=580,h=360});F.InviteFrame=f
 header(f,id,F.Name(id),"Приглашает: "..tostring(d.from))
 W.Text(f,F.Text(faction.description),"text","STALKER.Small")
 local current=LocalPlayer():GetNW2Bool("stfw_joined",false) and LocalPlayer():GetNW2String("stfw_faction","") or ""
 W.Text(f,"Вступление по приглашению — без взноса."..(current~="" and current~=id and (" Членство в «"..F.Name(current).."» будет прекращено.") or "")..(tonumber(d.cap) and d.cap>0 and (" Состав: "..(d.members or 0).." / "..d.cap..".") or ""),"muted","STALKER.Small")
 W.Card(f,40,function(_,w,h)
  local left=math.max(0,ends-CurTime())
  U.Text("Ответить в течение "..math.ceil(left).." с","STALKER.Small",px(12),px(4),"text")
  U.Bar(px(12),h-px(12),w-px(24),px(6),left/seconds)
 end)
 local row=W.Row(f,34)
 local yes=U.Button(row,"Принять",function() answer(true) end,"accent");yes:Dock(LEFT);yes:SetWide(px(260))
 local no=U.Button(row,"Отказаться",function() answer(false) end);no:Dock(RIGHT);no:SetWide(px(260))
 f.Think=function(self) if CurTime()>ends then self:Remove() end end
 surface.PlaySound("buttons/button17.wav")
 return f
end
net.Receive("stfw.invite",function(len)
 local d=F.ReadJSON(len);if type(d)=="table" then F.ShowInvite(d) end
end)
