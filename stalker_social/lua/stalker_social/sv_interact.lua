-- STALKER Social: действия меню взаимодействия (G) и вкладок КПК. Клиент присылает только намерение:
-- дистанцию, видимость, состояние обоих игроков, деньги и предметы проверяет сервер.
local S=STALKER_SOCIAL
local C=STALKER_CORE
local Cfg=S.Config

local function money(n) return S.Money(n) end
-- Цель действия: живой игрок рядом и в прямой видимости. range — дистанция (по умолчанию взаимодействия).
function S.ResolveTarget(ply,index,range,op)
 if not IsValid(ply) or not ply:Alive() then return nil,"Сейчас нельзя" end
 if C.Unconscious(ply) then return nil,"Вы без сознания" end
 local t=C.Int(index,1,65535) and Entity(index)
 if not IsValid(t) or not t:IsPlayer() or t==ply then return nil,"Сталкер не найден" end
 if not t:Alive() then return nil,"Сталкер мёртв" end
 local r=(range or Cfg.InteractDistance)+16
 if ply:GetPos():DistToSqr(t:GetPos())>r*r then return nil,"Подойдите ближе" end
 local tr=util.TraceLine({start=ply:EyePos(),endpos=t:EyePos(),filter={ply,t},mask=MASK_SOLID_BRUSHONLY})
 if tr.Hit then return nil,"Сталкер вне поля зрения" end
 if hook.Run("STALKER_SOCIAL_CanInteract",ply,t,op)==false then return nil,"Действие запрещено" end
 return t
end
-- Входящие предложения: ply.StsocOffers[от кого]={kind=expires}. Клиент цели показывает подсказку «G — ответить».
local function offer(from,to,kind)
 to.StsocOffers=to.StsocOffers or {}
 local o=to.StsocOffers[from] or {};o[kind]=CurTime()+Cfg.RequestSeconds;to.StsocOffers[from]=o
 C.Send("stalker_social.request",to,{kind=kind,ent=from:EntIndex(),name=S.Label(to,from),seconds=Cfg.RequestSeconds})
end
local function takeOffer(from,to,kind)
 local o=to.StsocOffers and to.StsocOffers[from]
 if not o or not o[kind] then return false end
 local alive=o[kind]>=CurTime();o[kind]=nil
 return alive
end
S.Offer=offer

local OPS={}
S.Ops=OPS
-- Представиться: цель узнаёт ваше имя и может представиться в ответ.
function OPS.intro(ply,a)
 local t,err=S.ResolveTarget(ply,a.t,nil,"intro");if not t then return false,err end
 if S.KnowsRaw(t,ply) then return false,"Этот сталкер уже знает ваше имя" end
 local ok,res=S.Learn(t,ply);if not ok then return false,res end
 takeOffer(t,ply,"intro")
 C.Notify(t,ply:Nick().." представился вам","info",6)
 if not S.KnowsRaw(ply,t) then offer(ply,t,"intro") end
 S.Gesture(ply,"wave")
 return true,"Вы представились: "..S.Label(ply,t).." теперь знает ваше имя"
end
-- Рукопожатие: первый протягивает руку, второй отвечает тем же действием (пока предложение живо).
function OPS.shake(ply,a)
 local t=C.Int(a.t,1,65535) and Entity(a.t)
 local answering=IsValid(t) and t:IsPlayer() and ply.StsocOffers and ply.StsocOffers[t] and (ply.StsocOffers[t].shake or 0)>=CurTime()
 local target,err=S.ResolveTarget(ply,a.t,answering and Cfg.ReplyDistance or nil,"shake");if not target then return false,err end
 t=target
 if answering then
  takeOffer(t,ply,"shake")
  local act=S.Act("ACT_GMOD_GESTURE_ITEM_GIVE")
  if act then S.Gesture(ply,act);S.Gesture(t,act) end
  C.Notify(t,"Рукопожатие: "..S.Label(t,ply),"ok",4)
  hook.Run("STALKER_SOCIAL_Handshake",t,ply)
  return true,"Рукопожатие: "..S.Label(ply,t)
 end
 local mine=t.StsocOffers and t.StsocOffers[ply]
 if mine and (mine.shake or 0)>=CurTime() then return false,"Вы уже протянули руку — ждите ответа" end
 offer(ply,t,"shake")
 return true,"Вы протянули руку. "..S.Label(ply,t).." может ответить (G)"
end
-- Передать деньги DarkRP.
function OPS.money(ply,a)
 if Cfg.MaxTransfer<=0 then return false,"Денежные переводы отключены" end
 if not ply.addMoney then return false,"Деньги недоступны на этом сервере" end
 local n=a.amount
 if not C.Int(n,1,Cfg.MaxTransfer) then return false,"Сумма от 1 до "..money(Cfg.MaxTransfer) end
 local t,err=S.ResolveTarget(ply,a.t,nil,"money");if not t then return false,err end
 local afford
 if ply.canAfford then afford=ply:canAfford(n) else afford=(tonumber(ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0)>=n end
 if not afford then return false,"Недостаточно денег" end
 ply:addMoney(-n);t:addMoney(n)
 S.Gesture(ply,S.Act("ACT_GMOD_GESTURE_ITEM_GIVE") or "agree")
 C.Notify(t,"Получено от "..S.Label(t,ply)..": "..money(n),"ok",6)
 hook.Run("STALKER_SOCIAL_MoneyGiven",ply,t,n)
 return true,"Передано "..S.Label(ply,t)..": "..money(n)
end
-- Передать предмет из рюкзака (STALKER Inventory).
function OPS.item(ply,a)
 local I=STALKER_INV
 if not (I and I.GiveFromTo) then return false,"Инвентарь недоступен" end
 if not C.Str(a.uid,96) or (a.count~=nil and not C.Int(a.count,1,999)) then return false,"Предмет не найден" end
 local t,err=S.ResolveTarget(ply,a.t,nil,"item");if not t then return false,err end
 local ok,res=I.GiveFromTo(ply,t,a.uid,a.count)
 if not ok then return false,res or "Передача не удалась" end
 S.Gesture(ply,S.Act("ACT_GMOD_GESTURE_ITEM_GIVE") or "agree")
 return true
end
-- Добавить в контакты КПК (только знакомого).
function OPS.contact(ply,a)
 local t,err=S.ResolveTarget(ply,a.t,nil,"contact");if not t then return false,err end
 if not S.KnowsRaw(ply,t) then return false,"Сначала познакомьтесь: попросите сталкера представиться" end
 local ok,res=S.SetContact(ply,C.SID(t),true);if not ok then return false,res end
 return true,t:Nick().." добавлен в контакты КПК"
end
-- Пригласить в группировку (STALKER Factions решает, может ли пригласивший и подходит ли цель).
function OPS.invite(ply,a)
 if not (STFW and STFW.Invite) then return false,"Группировки недоступны" end
 local t,err=S.ResolveTarget(ply,a.t,nil,"invite");if not t then return false,err end
 local ok,why=STFW.Invite(ply,t)
 if not ok then return false,STFW.L and STFW.L(why or "denied") or tostring(why) end
 return true,"Приглашение отправлено: "..S.Label(ply,t)
end
-- Обыскать: только сталкера с поднятыми руками, только просмотр рюкзака.
function OPS.search(ply,a)
 local t,err=S.ResolveTarget(ply,a.t,nil,"search");if not t then return false,err end
 if S.GetPose(t)~="surrender" then return false,"Обыскать можно только сталкера с поднятыми руками" end
 local I=STALKER_INV
 local inv=I and I.InventoryReady and I.InventoryReady(t) and t.StalkerInventory
 if not inv then return false,"Рюкзак недоступен" end
 local items={}
 for slot=1,40 do
  local it=inv.grid[slot]
  if it and I.Items[it.id] then items[#items+1]={id=it.id,count=it.count,durability=it.durability} end
 end
 C.Send("stalker_social.search",ply,{ent=t:EntIndex(),name=S.Label(ply,t),items=items,weight=I.Weight and math.Round(I.Weight(inv),1) or nil})
 C.Notify(t,"Вас обыскивает "..S.Label(t,ply),"warn",6)
 S.Gesture(ply,S.Act("ACT_GMOD_GESTURE_ITEM_PLACE") or "agree")
 hook.Run("STALKER_SOCIAL_Searched",ply,t)
 return true
end
-- Награда лидера (выдать или снять).
function OPS.award(ply,a)
 local t,err=S.ResolveTarget(ply,a.t,nil,"award");if not t then return false,err end
 local ok,given=S.ToggleAward(ply,t,a.award);if not ok then return false,given end
 local name=S.AwardByID[a.award].name
 C.Notify(t,(given and "Командир наградил вас нашивкой «" or "Командир снял нашивку «")..name.."»",given and "ok" or "warn",6)
 return true,(given and "Награда выдана: «" or "Награда снята: «")..name.."»"
end
--[[ Без цели рядом: КПК ]]
local function validSID(sid) return type(sid)=="string" and #sid<=20 and sid:match("^%d+$")~=nil end
function OPS.uncontact(ply,a)
 if not validSID(a.sid) then return false end
 local ok,err=S.SetContact(ply,a.sid,false);if not ok then return false,err end
 return true,"Контакт удалён"
end
function OPS.forget(ply,a)
 if not validSID(a.sid) then return false end
 local ok,err=S.Forget(ply,a.sid);if not ok then return false,err end
 return true,"Знакомство забыто"
end
function OPS.known(ply) S.SendKnown(ply);return true end
function OPS.patches(ply) S.SendPatchState(ply);return true end
function OPS.visible(ply,a)
 local ok,err=S.SetVisible(ply,a.ids);S.SendPatchState(ply)
 if not ok then return false,err end
 return true
end

-- Один вход для всех действий: {op, t (индекс цели), amount, uid, count, award, sid, ids}.
net.Receive("stalker_social.act",function(len,ply)
 if not C.Rate(ply,"social.act",3,8) then return end
 local a=C.Read(len,2000);if not a or not C.Str(a.op,16) then return end
 local fn=OPS[a.op];if not fn then return end
 local ok,msg=fn(ply,a)
 if msg then C.Notify(ply,msg,ok and "ok" or "warn",5) end
end)
-- Консоль: stsoc_intro — представиться тому, на кого смотрите (удобно для бинда).
concommand.Add("stsoc_intro",function(ply)
 if not IsValid(ply) or not C.Rate(ply,"social.act",3,8) then return end
 local tr=ply:GetEyeTrace();local t=tr and tr.Entity
 if not IsValid(t) or not t:IsPlayer() then C.Notify(ply,"Посмотрите на сталкера","warn",4);return end
 local ok,msg=OPS.intro(ply,{t=t:EntIndex()});if msg then C.Notify(ply,msg,ok and "ok" or "warn",5) end
end)
hook.Add("PlayerDisconnected","STALKER_SOCIAL.Offers",function(gone)
 for _,p in ipairs(player.GetAll()) do if p.StsocOffers then p.StsocOffers[gone]=nil end end
end)
