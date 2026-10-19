-- STALKER Social: жесты и позы. Поза — NW2 stsoc_pose (видна всем): последовательность через CalcMainActivity
-- (как HandlePlayerDriving в base/gamemode/animations.lua) или повороты костей. Поза снимается движением,
-- атакой, уроном, смертью; стрелять в позе нельзя (StartCommand снимает кнопки атаки и в предсказании клиента).
local S=STALKER_SOCIAL
local C=STALKER_CORE
local Cfg=S.Config

-- Последовательность позы для модели игрока (кэш по модели: LookupSequence не дёргается каждый кадр).
local seqCache={}
function S.PoseSequence(ply,def)
 if not def or not def.seq then return -1 end
 local model=tostring(ply:GetModel() or "")
 local key=model.."|"..def.id
 local seq=seqCache[key]
 if seq==nil then
  seq=-1
  for _,name in ipairs(def.seq) do local s=ply:LookupSequence(name);if s and s>=0 then seq=s;break end end
  seqCache[key]=seq
 end
 return seq
end

-- Основная активность: поза с последовательностью заменяет стойку (как CalcSeqOverride у транспорта).
hook.Add("CalcMainActivity","STALKER_SOCIAL.Pose",function(ply,velocity)
 local id=S.GetPose(ply);if id=="" then return end
 local def=S.PoseByID[id];if not def or not def.seq then return end
 local seq=S.PoseSequence(ply,def)
 if seq>=0 then return S.Act("ACT_MP_STAND_IDLE") or 0,seq end
 local fallback=def.fallback and S.Act(def.fallback)
 if fallback then return fallback,-1 end
end)

-- Скорость проигрывания: у последовательности позы нулевая скорость хода, и базовый UpdateAnimation (len/maxseqgroundspeed)
-- при лёгком толчке разогнал бы её вдвое. Держим 1 и сохраняем движение губ в голосовом чате (MouthMoveAnimation).
hook.Add("UpdateAnimation","STALKER_SOCIAL.Pose",function(ply,velocity,maxSeqGroundSpeed)
 local def=S.PoseByID[S.GetPose(ply)];if not def or not def.seq then return end
 ply:SetPlaybackRate(1)
 if CLIENT and GAMEMODE and GAMEMODE.MouthMoveAnimation then GAMEMODE:MouthMoveAnimation(ply) end
 return true
end)

-- В позе нельзя стрелять; движение и атака снимают позу (решает сервер). Клиент снимает кнопки атаки ещё до отправки
-- команды (StartCommand — общий CreateMove), поэтому о попытке выстрела он сам просит сервер «встать».
local standAsked=0
hook.Add("StartCommand","STALKER_SOCIAL.Pose",function(ply,cmd)
 if S.GetPose(ply)=="" then return end
 local attack=cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2)
 if attack then cmd:RemoveKey(IN_ATTACK);cmd:RemoveKey(IN_ATTACK2) end
 local moving=cmd:GetForwardMove()~=0 or cmd:GetSideMove()~=0 or cmd:KeyDown(IN_JUMP)
 if SERVER then
  if (attack or moving) and S.ClearPose then S.ClearPose(ply,attack and "attack" or "move") end
 elseif attack and ply==LocalPlayer() and RealTime()>standAsked and S.SendEmote then
  standAsked=RealTime()+.5;S.SendEmote("stand")
 end
end)

if SERVER then
 util.AddNetworkString("stalker_social.gesture")
 util.AddNetworkString("stalker_social.emote")

 --[[ Жест всем клиентам рядом: act — номер ACT_* или id жеста из каталога (wave, salute…). Для других аддонов. ]]
 function S.Gesture(ply,act)
  if type(act)=="string" then local g=S.GestureByID[act];act=g and S.Act(g.act) end
  if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not C.Int(act,0,65535) then return false end
  local slot=GESTURE_SLOT_CUSTOM or 6
  ply:AnimRestartGesture(slot,act,true)
  net.Start("stalker_social.gesture");net.WriteEntity(ply);net.WriteUInt(act,16);net.SendPVS(ply:GetPos())
  hook.Run("STALKER_SOCIAL_Gesture",ply,act)
  return true
 end

 local zero=Angle(0,0,0)
 local function restoreBones(ply)
  local prev=ply.StsocBones;ply.StsocBones=nil
  if not prev then return end
  for bone,ang in pairs(prev) do ply:ManipulateBoneAngles(bone,ang or zero) end
 end
 -- Включить позу. Возвращает true или false и причину для игрока.
 function S.SetPose(ply,id)
  local def=S.PoseByID[id]
  if not def then return false,"Неизвестная поза" end
  if not IsValid(ply) or not ply:Alive() then return false,"Сейчас нельзя" end
  if C.Unconscious(ply) then return false,"Вы без сознания" end
  if ply:InVehicle() or ply:GetMoveType()~=MOVETYPE_WALK then return false,"Сейчас нельзя" end
  if ply.IsOnGround and not ply:IsOnGround() then return false,"Встаньте на землю" end
  if ply:GetVelocity():Length()>40 then return false,"Остановитесь" end
  if hook.Run("STALKER_SOCIAL_CanPose",ply,id)==false then return false,"Сейчас нельзя" end
  local old=S.GetPose(ply)
  if old~="" then restoreBones(ply) end
  if def.bones then
   local prev={}
   for name,a in pairs(def.bones) do
    local bone=ply:LookupBone(name)
    if bone then
     prev[bone]=ply.GetManipulateBoneAngles and ply:GetManipulateBoneAngles(bone) or zero
     ply:ManipulateBoneAngles(bone,Angle(a[1],a[2],a[3]))
    end
   end
   ply.StsocBones=prev
  end
  ply:SetNW2String("stsoc_pose",id)
  hook.Run("STALKER_SOCIAL_PoseChanged",ply,id,old)
  return true
 end
 -- Снять позу (reason: move, attack, damage, death, spawn, stand, toggle, vehicle).
 function S.ClearPose(ply,reason)
  if not IsValid(ply) then return end
  local old=S.GetPose(ply)
  restoreBones(ply)
  if old=="" then return end
  ply:SetNW2String("stsoc_pose","")
  hook.Run("STALKER_SOCIAL_PoseChanged",ply,"",old,reason)
 end

 -- Эмоция из меню (H), чата (!emote <id>) или консоли (stsoc_emote <id>).
 function S.Emote(ply,id)
  if not IsValid(ply) or not ply:Alive() then return false,"Сейчас нельзя" end
  if id=="stand" then S.ClearPose(ply,"stand");return true end
  if C.Unconscious(ply) then return false,"Вы без сознания" end
  local now=CurTime()
  if (ply.StsocEmoteAt or 0)>now then return false end
  if S.GestureByID[id] then
   if not S.Act(S.GestureByID[id].act) then return false,"Этот жест недоступен" end
   ply.StsocEmoteAt=now+Cfg.EmoteCooldown
   return S.Gesture(ply,id)
  end
  if S.PoseByID[id] then
   if S.GetPose(ply)==id then S.ClearPose(ply,"toggle");return true end
   ply.StsocEmoteAt=now+Cfg.EmoteCooldown
   return S.SetPose(ply,id)
  end
  return false,"Неизвестная эмоция"
 end
 net.Receive("stalker_social.emote",function(len,ply)
  if not C.Rate(ply,"social.emote",2,4) then return end
  local a=C.Read(len,200);if not a or not C.Str(a.id,24) then return end
  local ok,err=S.Emote(ply,a.id)
  if not ok and err then C.Notify(ply,err,"warn",4) end
 end)
 concommand.Add("stsoc_emote",function(ply,_,args)
  if not IsValid(ply) or not C.Rate(ply,"social.emote",2,4) then return end
  local id=tostring(args[1] or "")
  local ok,err=S.Emote(ply,id);if not ok and err then C.Notify(ply,err,"warn",4) end
 end)
 -- Чат: !emote — меню эмоций, !emote <id> — сразу жест или поза (id из каталога: wave, salute, sit…).
 hook.Add("PlayerSay","STALKER_SOCIAL.Emote",function(ply,text)
  local word,arg=string.Trim(tostring(text or "")):lower():match("^([!/]%a+)%s*(%S*)")
  if word~="!emote" and word~="/emote" then return end
  if arg=="" then ply:ConCommand("stsoc_emotes");return "" end
  local ok,err=S.Emote(ply,arg);if not ok and err then C.Notify(ply,err,"warn",4) end
  return ""
 end)

 -- Урон, смерть, возрождение и транспорт снимают позу.
 hook.Add("EntityTakeDamage","STALKER_SOCIAL.Pose",function(ent,dmg)
  if IsValid(ent) and ent:IsPlayer() and dmg:GetDamage()>0 and S.GetPose(ent)~="" then S.ClearPose(ent,"damage") end
 end)
 hook.Add("PlayerDeath","STALKER_SOCIAL.Pose",function(ply) S.ClearPose(ply,"death") end)
 hook.Add("PlayerSpawn","STALKER_SOCIAL.Pose",function(ply) S.ClearPose(ply,"spawn") end)
 hook.Add("PlayerEnteredVehicle","STALKER_SOCIAL.Pose",function(ply) S.ClearPose(ply,"vehicle") end)
else
 net.Receive("stalker_social.gesture",function()
  local ent=net.ReadEntity();local act=net.ReadUInt(16)
  if IsValid(ent) and ent:IsPlayer() and act then ent:AnimRestartGesture(GESTURE_SLOT_CUSTOM or 6,act,true) end
 end)
 function S.SendEmote(id) return C.Send("stalker_social.emote",nil,{id=id}) end
end
