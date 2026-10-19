-- Маячки игроков: предмет «Маячок» ставит мигающую сущность под прицелом, метка kind="beacon" видна владельцу
-- или его группировке. Срок работы ограничен, одновременно — не больше BeaconLimit, владелец забирает маячок клавишей E.
local E=STALKER_EVENTS
local C=STALKER_CORE
local Cfg=E.Config
util.AddNetworkString("stalker_events.beacon")
E.Beacons=E.Beacons or {}

function E.AllBeacons()
 local out={}
 for _,ent in ipairs(E.Beacons) do if IsValid(ent) then out[#out+1]=ent end end
 E.Beacons=out
 return out
end
function E.CountBeacons(sid)
 local n=0;for _,ent in ipairs(E.AllBeacons()) do if ent.OwnerSID==sid then n=n+1 end end
 return n
end
-- Для КПК владельца: подписи, видимость и остаток срока.
function E.BeaconsOf(ply)
 local sid=C.SID(ply);local out={};if not sid then return out end
 for _,ent in ipairs(E.AllBeacons()) do
  if ent.OwnerSID==sid then out[#out+1]={label=ent:GetLabel(),faction=ent:GetFactionID(),left=math.max(0,math.floor(ent:GetExpires()-CurTime()))} end
 end
 return out
end

-- «Использовать» на предмете: предмет не расходуется сразу, клиент выбирает видимость и подпись.
function E.BeaconPrompt(ply)
 local sid=C.SID(ply)
 if not sid then return false,"Маячок недоступен" end
 if E.CountBeacons(sid)>=Cfg.BeaconLimit then return false,"Работает максимум маячков: "..Cfg.BeaconLimit..". Заберите один из них (E)" end
 local fid=C.Faction(ply)
 C.Send("stalker_events.beacon",ply,{faction=fid,factionName=fid and C.FactionName(fid) or nil,limit=Cfg.BeaconLimit,have=E.CountBeacons(sid),minutes=Cfg.BeaconMinutes})
 return false,"Выберите, кому будет виден маячок"
end

local function markerID(ent) return "stev.beacon."..ent:EntIndex() end
function E.BeaconMarker(ent)
 local fid=ent:GetFactionID()
 local visible={players={[ent.OwnerSID]=true}}
 if fid~="" then visible.faction=fid end
 STALKER_MARKERS.Set(markerID(ent),{pos=ent:GetPos()+Vector(0,0,8),kind="beacon",label=ent:GetLabel()..(fid~="" and (" · "..ent:GetOwnerName()) or ""),
  visible=visible,owner=ent.OwnerSID,expires=ent:GetExpires(),color=fid~="" and C.FactionColor(fid) or nil})
end

--[[ Установка: mode — "self" (только владелец) или "faction"; label — подпись (до 32 символов). ]]
function E.PlaceBeacon(ply,mode,label)
 local S=STALKER_INV
 if not IsValid(ply) or not ply:Alive() or C.Unconscious(ply) then return false,"Сейчас нельзя поставить маячок" end
 local sid=C.SID(ply);if not sid then return false,"Маячок недоступен" end
 if not S or not S.CountItem or not S.Items[E.BeaconItem] then return false,"Инвентарь недоступен" end
 if S.CountItem(ply,E.BeaconItem)<1 then return false,"В рюкзаке нет маячка" end
 if E.CountBeacons(sid)>=Cfg.BeaconLimit then return false,"Работает максимум маячков: "..Cfg.BeaconLimit end
 if mode~="self" and mode~="faction" then return false,"Неизвестный режим маячка" end
 local fid=C.Faction(ply)
 if mode=="faction" and not fid then return false,"Вы не состоите в группировке" end
 label=E.CleanName(label)
 if label and (utf8.len(label) or #label)>32 then label=nil end
 label=label or "Маячок"
 local start=ply:EyePos()
 local tr=util.TraceLine({start=start,endpos=start+ply:GetAimVector()*Cfg.BeaconRange,filter=ply,mask=MASK_SOLID})
 if not tr.Hit or tr.HitSky or tr.StartSolid or tr.HitNormal.z<.5 then return false,"Наведите прицел на землю рядом с собой" end
 if IsValid(tr.Entity) and not tr.Entity:IsWorld() then return false,"Маячок ставится на землю или пол" end
 local pos=tr.HitPos
 local ok,err=S.Exchange(ply,{[E.BeaconItem]=1},{},"Маячок установлен: «"..label.."»")
 if not ok then return false,err end
 local ent=ents.Create("stalker_beacon")
 if not IsValid(ent) then S.GiveItem(ply,E.BeaconItem,1);return false,"Сущность маячка недоступна" end
 ent.OwnerSID=sid
 ent:SetPos(pos);ent:SetAngles(Angle(0,ply:EyeAngles().y,0))
 ent:SetOwnerName(ply:Nick());ent:SetLabel(label);ent:SetFactionID(mode=="faction" and fid or "")
 ent:SetOwnerSID(sid);ent:SetExpires(CurTime()+Cfg.BeaconMinutes*60)
 ent:Spawn()
 E.Beacons[#E.Beacons+1]=ent
 E.BeaconMarker(ent)
 ent:EmitSound("buttons/blip1.wav",65,110)
 E.MarkDirty()
 return true,ent
end

-- E на маячке: владелец забирает его обратно в рюкзак.
function E.UseBeacon(ply,ent)
 if not IsValid(ply) or not ply:IsPlayer() or not IsValid(ent) or ent.Collected then return end
 if ply:GetShootPos():DistToSqr(ent:WorldSpaceCenter())>150*150 then return end
 -- Имя владельца не называем: незнакомцу (STALKER Social) его знать неоткуда.
 if C.SID(ply)~=ent.OwnerSID then C.Notify(ply,"Маячок «"..ent:GetLabel().."» чужой — забрать его может только владелец","info",3);return end
 local S=STALKER_INV
 if not S or not S.GiveItem then return end
 local ok,err=S.GiveItem(ply,E.BeaconItem,1)
 if not ok then C.Notify(ply,"Не удалось забрать маячок: "..tostring(err),"warn",4);return end
 ent.Collected=true;ent:Remove()
 C.Notify(ply,"Маячок «"..ent:GetLabel().."» снят","ok",3)
 return true
end
function E.BeaconRemoved(ent)
 STALKER_MARKERS.Remove(markerID(ent))
 E.MarkDirty()
end

-- Разряженные маячки гаснут и исчезают (раз в секунду из E.Tick).
function E.BeaconTick()
 local now=CurTime()
 for _,ent in ipairs(E.AllBeacons()) do
  if now>=ent:GetExpires() then
   local owner=C.PlayerBySID(ent.OwnerSID)
   if IsValid(owner) then C.Notify(owner,"Маячок «"..ent:GetLabel().."» разрядился","info",5) end
   ent.Collected=true;ent:Remove()
  end
 end
end
