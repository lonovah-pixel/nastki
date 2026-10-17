include("shared.lua")
function ENT:Draw() self:DrawModel() end
-- Подсказка подбора — в цветах и шрифте общей темы.
hook.Add("HUDPaint","STALKER_INV.PickupHint",function()
    local ply=LocalPlayer();if not IsValid(ply) then return end
    local tr=ply:GetEyeTrace();local ent=tr.Entity
    if IsValid(ent) and ent:GetClass()=="stalker_inv_drop" and tr.HitPos:DistToSqr(ply:EyePos())<150*150 then
        local S=STALKER_INV;local T=STALKER_THEME
        local col=(T and T.C and T.C.text) or (S and S.C and S.C.text) or color_white
        draw.SimpleText("E — "..ent:GetItemTitle(),T and "STALKER.Body" or "DermaDefaultBold",ScrW()/2,ScrH()/2+30,col,TEXT_ALIGN_CENTER)
    end
end)
