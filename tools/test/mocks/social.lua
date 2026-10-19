-- Мок для STALKER Social (сценарий 36_social): константы GMod, которых нет в ядре мока (ACT_*, GESTURE_SLOT_*,
-- IN_*, KEY_G/KEY_H), анимационные методы игрока (жесты, повороты костей, последовательности), матрица кости,
-- векторное произведение и Vector:AngleEx. Значения ACT — из перечислений GMod; добавляются, только если их нет.
local M=TEST.M
local consts={ACT_MP_STAND_IDLE=1771,ACT_MP_CROUCH_IDLE=1773,ACT_HL2MP_SIT=1970,
 ACT_GMOD_GESTURE_AGREE=1610,ACT_GMOD_GESTURE_BECON=1611,ACT_GMOD_GESTURE_BOW=1612,ACT_GMOD_GESTURE_DISAGREE=1613,
 ACT_GMOD_TAUNT_SALUTE=1614,ACT_GMOD_GESTURE_WAVE=1615,ACT_GMOD_TAUNT_PERSISTENCE=1616,ACT_GMOD_TAUNT_MUSCLE=1617,
 ACT_GMOD_TAUNT_LAUGH=1618,ACT_GMOD_TAUNT_CHEER=1620,ACT_GMOD_GESTURE_ITEM_GIVE=1628,ACT_GMOD_GESTURE_ITEM_PLACE=1630,
 ACT_GMOD_TAUNT_DANCE=1642,ACT_SIGNAL_FORWARD=53,ACT_SIGNAL_GROUP=54,ACT_SIGNAL_HALT=55,
 GESTURE_SLOT_CUSTOM=6,IN_ATTACK=1,IN_JUMP=2,IN_DUCK=4,IN_FORWARD=8,IN_BACK=16,IN_ATTACK2=2048,KEY_G=17,KEY_H=18}
for k,v in pairs(consts) do if _G[k]==nil then _G[k]=v end end

local meta=FindMetaTable("Player")
M.gestures={}
meta.AnimRestartGesture=meta.AnimRestartGesture or function(self,slot,act,autokill) M.gestures[#M.gestures+1]={ply=self,slot=slot,act=act} end
meta.ManipulateBoneAngles=meta.ManipulateBoneAngles or function(self,bone,ang) self._boneAng=self._boneAng or {};self._boneAng[bone]=ang end
meta.GetManipulateBoneAngles=meta.GetManipulateBoneAngles or function(self,bone) return (self._boneAng and self._boneAng[bone]) or Angle(0,0,0) end
meta.SelectWeightedSequence=meta.SelectWeightedSequence or function() return 1 end
meta.SetPlaybackRate=meta.SetPlaybackRate or function(self,rate) self._playbackRate=rate end
meta.IsOnGround=meta.IsOnGround or function(self) return self._air~=true end
meta.GetNoDraw=meta.GetNoDraw or function() return false end
-- Имена в метатаблице Player (как в GMod): обёртка имени незнакомца подменяет их на время отрисовки DarkRP.
-- У игроков мока Nick лежит в прототипе, поэтому сценарий направляет Nick игрока сюда сам.
for _,k in ipairs({"Nick","Name","GetName"}) do meta[k]=meta[k] or function(self) return self._nick end end
-- Кости: плечо, локоть и грудь стоят так, чтобы рука висела вниз (расчёт плоскости нашивки). LookupBone ядра мока
-- всегда возвращает 1, поэтому сценарий ставит игроку M.socialLookupBone сам.
local bones={["ValveBiped.Bip01_L_UpperArm"]=11,["ValveBiped.Bip01_L_Forearm"]=12,["ValveBiped.Bip01_Spine2"]=13}
local offsets={[11]=Vector(0,8,56),[12]=Vector(0,9,44),[13]=Vector(0,0,56)}
local nextBone=20
function M.socialLookupBone(self,name)
 if not bones[name] then bones[name]=nextBone;nextBone=nextBone+1 end
 return bones[name]
end
meta.GetBoneMatrix=meta.GetBoneMatrix or function(self,bone)
 local pos=self:GetPos()+(offsets[bone] or Vector(0,0,40))
 return {GetTranslation=function() return pos end,GetAngles=function() return Angle(0,0,0) end}
end

local V=getmetatable(Vector(0,0,0))
V.Cross=V.Cross or function(a,b) return Vector(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) end
V.AngleEx=V.AngleEx or function(self,up) return Angle(0,math.deg(math.atan2(self.y,self.x)),0) end
