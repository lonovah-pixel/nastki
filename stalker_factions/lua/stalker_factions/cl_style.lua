-- Общий стиль КПК. Материалы каждого аддона загружаются независимо.
STALKER_STYLE=STALKER_STYLE or {}
local U=STALKER_STYLE
U.Materials=U.Materials or {}
function U.Texture(path,x,y,w,h,alpha)
 local mat=U.Materials[path];if not mat then mat=Material(path,"smooth");U.Materials[path]=mat end
 if mat:IsError() then return end
 surface.SetMaterial(mat);surface.SetDrawColor(255,255,255,alpha or 255);surface.DrawTexturedRect(x,y,w,h)
end
function U.Panel(prefix,x,y,w,h,active,metal)
 surface.SetDrawColor(25,27,22,255);surface.DrawRect(x,y,w,h)
 U.Texture(prefix.."/"..(metal and "metal" or "panel")..".png",x,y,w,h,255)
 surface.SetDrawColor(active and Color(191,174,116) or Color(91,91,71));surface.DrawOutlinedRect(x,y,w,h,1)
 surface.SetDrawColor(8,10,8,220);surface.DrawOutlinedRect(x+2,y+2,w-4,h-4,1)
 surface.SetDrawColor(144,139,107,75);surface.DrawLine(x+3,y+3,x+w-4,y+3)
end
function U.Frame(prefix,w,h)
 U.Panel(prefix,0,0,w,h,true,true)
 U.Panel(prefix,10,10,w-20,h-20,false,false)
 U.Texture(prefix.."/vignette.png",0,0,w,h,175)
 for _,x in ipairs({6,w-7}) do for _,y in ipairs({6,h-7}) do
  surface.SetDrawColor(15,17,13);surface.DrawRect(x-2,y-2,5,5);surface.SetDrawColor(121,113,83);surface.DrawLine(x-1,y,x+1,y)
 end end
end
function U.Bar(x,y,w,h,ratio,col)
 ratio=math.Clamp(ratio or 0,0,1);surface.SetDrawColor(9,12,8,240);surface.DrawRect(x,y,w,h)
 surface.SetDrawColor(col);surface.DrawRect(x+1,y+1,(w-2)*ratio,h-2)
 surface.SetDrawColor(164,175,128,60);surface.DrawLine(x+1,y+1,x+1+(w-2)*ratio,y+1)
end
function U.Entry(e,prefix)
 e:SetFont("DermaDefault");e:SetTextColor(Color(217,207,176));e:SetCursorColor(Color(217,207,176));e:SetHighlightColor(Color(96,101,68))
 e.Paint=function(self,w,h) U.Panel(prefix,0,0,w,h,self:HasFocus());self:DrawTextEntryText(Color(217,207,176),Color(95,105,71),Color(217,207,176)) end
end
function U.Combo(c,prefix,font)
 c:SetTextColor(Color(217,207,176,0));c:SetFont(font or "DermaDefault")
 c.Paint=function(self,w,h) U.Panel(prefix,0,0,w,h,self:IsHovered());draw.SimpleText(self:GetValue(),font or "DermaDefault",8,h/2,Color(217,207,176),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
 if IsValid(c.DropButton) then c.DropButton.Paint=function(_,w,h) draw.SimpleText("▾",font or "DermaDefault",w/2,h/2,Color(177,168,132),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER) end end
end
function U.Scroll(scroll)
 local bar=scroll:GetVBar();bar:SetWide(8);bar:SetHideButtons(true)
 bar.Paint=function(_,w,h) surface.SetDrawColor(13,17,11);surface.DrawRect(0,0,w,h) end
 bar.btnGrip.Paint=function(_,w,h) surface.SetDrawColor(111,119,82);surface.DrawRect(1,0,w-2,h);surface.SetDrawColor(161,165,119);surface.DrawLine(2,2,w-3,2) end
end
