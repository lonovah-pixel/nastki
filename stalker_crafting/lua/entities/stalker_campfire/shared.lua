ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Костёр"
ENT.Spawnable=false
ENT.RenderGroup=RENDERGROUP_BOTH
-- PlaceID — постоянный костёр администратора (data/stalker_craft/<карта>.json); пусто — походный костёр игрока.
-- Expires — CurTime() угасания (0 — горит всегда). Style: ring — камни и огонь, barrel — бочка с огнём.
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"PlaceID")
 self:NetworkVar("String",1,"OwnerSID")
 self:NetworkVar("String",2,"OwnerName")
 self:NetworkVar("String",3,"Style")
 self:NetworkVar("Float",0,"Expires")
end
function ENT:IsLit() local e=self:GetExpires() or 0;return e<=0 or e>CurTime() end
function ENT:IsPermanent() return (self:GetPlaceID() or "")~="" end
function ENT:TimeLeft() local e=self:GetExpires() or 0;if e<=0 then return nil end;return math.max(0,e-CurTime()) end
-- Высота огня над точкой отсчёта: у бочки пламя над краем.
function ENT:FireHeight() return self:GetStyle()=="barrel" and 46 or 6 end
