include("shared.lua")
function ENT:Draw() self:DrawModel() end
hook.Add("HUDPaint","STALKER_ZONE.BagHint",function()
 local p=LocalPlayer();if not IsValid(p) then return end
 local tr=p:GetEyeTrace();local e=tr.Entity
 if IsValid(e) and e:GetClass()=="stalker_deathbag" and tr.HitPos:DistToSqr(p:EyePos())<130*130 then
  draw.SimpleText("E — обыскать рюкзак: "..e:GetOwnerName().." ("..e:GetItemCount().." пр.)","DermaDefaultBold",ScrW()/2,ScrH()/2+30,Color(217,207,176),TEXT_ALIGN_CENTER)
 end
end)
