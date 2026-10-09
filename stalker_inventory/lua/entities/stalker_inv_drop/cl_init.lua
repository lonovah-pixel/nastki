include("shared.lua")
function ENT:Draw() self:DrawModel() end
hook.Add("HUDPaint","STALKER_INV.PickupHint",function()
    local ply=LocalPlayer();if not IsValid(ply) then return end
    local tr=ply:GetEyeTrace();local ent=tr.Entity
    if IsValid(ent) and ent:GetClass()=="stalker_inv_drop" and tr.HitPos:DistToSqr(ply:EyePos())<150*150 then
        draw.SimpleText("E — "..ent:GetItemTitle(),"DermaDefaultBold",ScrW()/2,ScrH()/2+30,Color(217,207,176),TEXT_ALIGN_CENTER)
    end
end)
