-- STALKER Social: значки нашивок (меню, КПК) и нашивки на левом плече модели (PostPlayerDraw, не дальше PatchDistance).
local S=STALKER_SOCIAL
local T=STALKER_THEME
local Cfg=S.Config

local mats={}
function S.PatchMaterial(path)
 local m=mats[path]
 if m==nil then
  m=Material(path,"smooth")
  if not m or m:IsError() then m=false end
  mats[path]=m
 end
 return m or nil
end
-- Короткая подпись для запасного значка (если иконки нет на клиенте).
local roman={"I","II","III","IV","V","VI","VII"}
function S.PatchShort(info)
 if info.kind=="faction" then
  local f=STFW and STFW.Factions and STFW.Factions[info.faction]
  return f and f.tag or utf8.sub(info.name,1,2)
 end
 if info.kind=="rank" then return roman[info.rank] or tostring(info.rank) end
 return utf8.sub(info.name,1,1)
end
-- Значок нашивки в 2D (панели, HUD, cam.Start3D2D). dim — приглушить (нашивка ещё не получена).
function S.DrawPatch(id,x,y,size,alpha,dim)
 local info=S.PatchInfo(id);if not info then return end
 alpha=alpha or 255
 local mat=S.PatchMaterial(info.icon)
 if mat then
  local k=dim and .35 or 1
  surface.SetMaterial(mat);surface.SetDrawColor(255*k,255*k,255*k,alpha);surface.DrawTexturedRect(x,y,size,size)
  return
 end
 local line=info.color or T.C.accent
 local back=T.C.panel2
 surface.SetDrawColor(back.r,back.g,back.b,alpha);surface.DrawRect(x,y,size,size)
 surface.SetDrawColor(line.r,line.g,line.b,dim and alpha*.4 or alpha)
 surface.DrawOutlinedRect(x,y,size,size,math.max(1,math.floor(size/14)))
 local text=dim and T.C.muted or T.C.text
 draw.SimpleText(S.PatchShort(info),size>=40 and "STALKER.Head" or "STALKER.Small",x+size/2,y+size/2,Color(text.r,text.g,text.b,alpha),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
end

--[[ Нашивки на плече. Плоскость строится по костям ValveBiped (плечо → локоть и наружу от груди),
 поэтому не зависит от того, как в модели повёрнуты оси кости. ]]
S.Shoulder={upper="ValveBiped.Bip01_L_UpperArm",lower="ValveBiped.Bip01_L_Forearm",chest="ValveBiped.Bip01_Spine2",
 along=2.2,out=2.9,scale=.05,size=56,gap=6}
local function bonePos(ply,name)
 local bone=ply:LookupBone(name);if not bone then return end
 local m=ply:GetBoneMatrix(bone);if not m then return end
 return m:GetTranslation()
end
function S.ShoulderFrame(ply)
 local sh=S.Shoulder
 local shoulder,elbow,chest=bonePos(ply,sh.upper),bonePos(ply,sh.lower),bonePos(ply,sh.chest)
 if not shoulder or not elbow or not chest then return end
 local down=(elbow-shoulder):GetNormalized()
 local out=shoulder-chest;out=(out-down*out:Dot(down)):GetNormalized()
 if down:IsZero() or out:IsZero() then return end
 -- 3D2D (матрица с масштабом y=-scale): X — Forward, Y — Right, лицевая сторона — Up.
 -- Right = вниз по руке, Up = наружу; Forward = Up × Right (базис Source: Right = Forward × Up).
 local forward=out:Cross(down)
 local ang=forward:AngleEx(out)
 return shoulder+down*sh.along+out*sh.out,ang
end
hook.Add("PostPlayerDraw","STALKER_SOCIAL.Patches",function(ply)
 if not IsValid(ply) or not ply:Alive() or ply:GetNoDraw() then return end
 local list=S.VisiblePatches(ply);if #list==0 then return end
 local maxd=Cfg.PatchDistance
 if ply:GetPos():DistToSqr(EyePos())>maxd*maxd then return end
 local pos,ang=S.ShoulderFrame(ply);if not pos then return end
 local sh=S.Shoulder
 cam.Start3D2D(pos,ang,sh.scale)
 for i,id in ipairs(list) do S.DrawPatch(id,-sh.size/2,(i-1)*(sh.size+sh.gap),sh.size) end
 cam.End3D2D()
end)
