include("shared.lua")
function ENT:Draw() self:DrawModel() end
hook.Add("HUDPaint","STNPC.UseHint",function()
    local p=LocalPlayer();if not IsValid(p) then return end
    local tr=p:GetEyeTrace();local e=tr.Entity
    if IsValid(e) and e:GetClass()=="stalker_npc_trader" and p:GetPos():DistToSqr(e:GetPos())<STALKER_NPC.Config.Distance^2 then
        draw.SimpleText(STALKER_NPC.L("use"),STALKER_THEME and "STALKER.Head" or "DermaDefaultBold",ScrW()/2,ScrH()/2+30,STALKER_NPC.Colors and STALKER_NPC.Colors.accent or Color(200,169,81),TEXT_ALIGN_CENTER)
    end
end)
