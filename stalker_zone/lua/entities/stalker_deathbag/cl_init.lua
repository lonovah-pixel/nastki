include("shared.lua")
function ENT:Draw() self:DrawModel() end

-- Имя владельца глазами зрителя: незнакомца не выдаёт даже его сумка.
function ENT:OwnerLabel()
 local name=self:GetOwnerName();local SO=STALKER_SOCIAL
 if type(SO)~="table" then return name end
 local sid=self.GetOwnerSID and self:GetOwnerSID() or ""
 local C=STALKER_CORE;local owner=sid~="" and C and C.PlayerBySID and C.PlayerBySID(sid)
 if IsValid(owner) and SO.Label then return SO.Label(LocalPlayer(),owner) end
 local cfg=type(SO.Config)=="table" and SO.Config or {}
 if cfg.HideNames==false or sid=="" or (type(SO.MyKnown)=="table" and SO.MyKnown[sid]~=nil) then return name end
 local lp=LocalPlayer()
 if cfg.AdminsSeeAll and IsValid(lp) and lp:IsAdmin() then return name end
 return (type(cfg.StrangerName)=="string" and cfg.StrangerName~="") and cfg.StrangerName or "Незнакомец"
end

hook.Add("HUDPaint","STALKER_ZONE.BagHint",function()
 local p=LocalPlayer();if not IsValid(p) then return end
 local tr=p:GetEyeTrace();local e=tr.Entity
 local Z=STALKER_ZONE;local dd=Z and Z.Config and Z.Config.DeathDrop
 local range=(dd and tonumber(dd.UseRange) or 110)+20
 if not IsValid(e) or e:GetClass()~="stalker_deathbag" or tr.HitPos:DistToSqr(p:EyePos())>range*range then return end
 local T=STALKER_THEME;local U=STALKER_STYLE
 local text="E — обыскать рюкзак: "..e:OwnerLabel().." ("..e:GetItemCount().." пр.)"
 local sub=e.GetHasIntel and e:GetHasIntel() and "В сумке записи КПК — возможна наводка на тайник" or nil
 if U and U.Text and T and T.Px then
  U.Text(text,"STALKER.Body",ScrW()/2,ScrH()/2+T.Px(30),"text",TEXT_ALIGN_CENTER)
  if sub then U.Text(sub,"STALKER.Small",ScrW()/2,ScrH()/2+T.Px(50),"accent",TEXT_ALIGN_CENTER) end
 else
  draw.SimpleText(text,"DermaDefaultBold",ScrW()/2,ScrH()/2+30,color_white,TEXT_ALIGN_CENTER)
 end
end)
