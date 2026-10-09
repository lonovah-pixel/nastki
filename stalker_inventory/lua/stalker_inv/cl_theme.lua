local S=STALKER_INV
S.C=S.Config.Colors
S.Scale=1
function S.Px(v) return math.Round(v*S.Scale) end
function S.CreateFonts()
    local mono=S.CVFont:GetString();local heading=S.CVHeading:GetString()
    surface.CreateFont("SI.Small",{font=mono,size=S.Px(11),weight=400,extended=true})
    surface.CreateFont("SI.Body",{font="Tahoma",size=S.Px(14),weight=400,extended=true})
    surface.CreateFont("SI.Mono",{font=mono,size=S.Px(15),weight=500,extended=true})
    surface.CreateFont("SI.Title",{font=heading,size=S.Px(22),weight=500,extended=true})
end
S.CreateFonts()
S.PaintPanel=function(x,y,w,h,active,metal) STALKER_STYLE.Panel("stalker_inv",x,y,w,h,active,metal) end
S.Noise=Material("stalker_inv/noise.png","noclamp smooth")
S.Gradient=Material("vgui/gradient-d")
function S.DrawRoundedBoxEx(r,x,y,w,h,c,tl,tr,bl,br) draw.RoundedBoxEx(r,x,y,w,h,c,tl,tr,bl,br) end
function S.DrawNoise(x,y,w,h)
    if S.Noise:IsError() then return end
    surface.SetMaterial(S.Noise);surface.SetDrawColor(255,255,255,13)
    surface.DrawTexturedRectUV(x,y,w,h,0,0,w/128,h/128)
end
function S.DrawBrassFrame(x,y,w,h,active)
    surface.SetDrawColor(active and S.C.accent or S.C.brass);surface.DrawOutlinedRect(x,y,w,h,1)
    surface.SetMaterial(S.Gradient);surface.SetDrawColor(200,169,81,active and 28 or 12)
    surface.DrawTexturedRect(x+1,y+1,w-2,h-2)
    surface.SetDrawColor(0,0,0,90);surface.DrawOutlinedRect(x+2,y+2,w-4,h-4,1)
end
function S.DrawVignette(w,h)
    for i=0,S.Px(14) do
        surface.SetDrawColor(0,0,0,math.max(0,25-i));surface.DrawOutlinedRect(i,i,w-i*2,h-i*2,1)
    end
    surface.SetDrawColor(107,93,63,50)
    for i=1,20 do local x=(i*97)%math.max(1,w-40);surface.DrawLine(x,3,x+10+i%19,3) end
end
function S.Text(text,font,x,y,col,ax,ay) draw.SimpleText(text,font,x,y,col or S.C.text,ax or 0,ay or 0) end
function S.FitText(text,font,width)
    surface.SetFont(font)
    if surface.GetTextSize(text)<=width then return text end
    local chars=utf8.len(text) or #text
    for n=chars,1,-1 do local s=utf8.sub(text,1,n).."…";if surface.GetTextSize(s)<=width then return s end end
    return "…"
end
function S.Wrap(text,font,width)
    surface.SetFont(font);local lines={};local line=""
    for word in tostring(text):gmatch("%S+") do
        local nextLine=line=="" and word or line.." "..word
        if surface.GetTextSize(nextLine)>width and line~="" then lines[#lines+1]=line;line=word else line=nextLine end
    end
    if line~="" then lines[#lines+1]=line end
    return lines
end
local icons={}
function S.DrawItemIcon(item,x,y,w,h)
    if not item then return end
    local d=S.Items[item.id];if not d then return end
    if d.icon~="" then
        icons[d.icon]=icons[d.icon] or Material(d.icon,"smooth")
        if not icons[d.icon]:IsError() then surface.SetMaterial(icons[d.icon]);surface.SetDrawColor(255,255,255);local mat=icons[d.icon];local ratio=mat:Width()/math.max(1,mat:Height());local iw=math.min(w,h*ratio);local ih=iw/ratio;surface.DrawTexturedRect(x+(w-iw)/2,y+(h-ih)/2,iw,ih);return end
    end
    S.Text("?","SI.Title",x+w/2,y+h/2,S.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
end
function S.Button(parent,text,x,y,w,h,fn)
    local b=vgui.Create("DButton",parent);b:SetText("");b:SetPos(S.Px(x),S.Px(y));b:SetSize(S.Px(w),S.Px(h))
    b.Paint=function(self,bw,bh)
        S.PaintPanel(0,0,bw,bh,self:IsHovered());S.DrawBrassFrame(0,0,bw,bh,self:IsHovered())
        S.Text(text,"SI.Body",bw/2,bh/2,self:IsEnabled() and S.C.text or S.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end
    b.DoClick=fn;return b
end
local TAB={}
function TAB:Init() self:SetText("");self.Label="" end
function TAB:Paint(w,h)
    S.PaintPanel(0,0,w,h,self.Active or self:IsHovered());S.DrawBrassFrame(0,0,w,h,self.Active or self:IsHovered())
    S.Text(self.Label,"SI.Body",w/2,h/2,self.Active and S.C.accent or S.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
end
vgui.Register("DToggleTab",TAB,"DButton")
-- Радиация берётся из сетевых переменных сервера (обновляются каждую секунду), а не из снимка инвентаря.
function S.RadiationDose(ply) ply=ply or LocalPlayer();return IsValid(ply) and ply:GetNW2Float("stalker_dose",0) or 0 end
function S.RadiationRate(ply) ply=ply or LocalPlayer();return IsValid(ply) and ply:GetNW2Float("stalker_rad_rate",0) or 0 end
function S.RadiationDanger() return STALKER_RAD and STALKER_RAD.Config and STALKER_RAD.Config.DamageThreshold or 30 end
local warn=Color(214,170,64)
function S.RadiationColor(dose)
    if dose>=S.RadiationDanger() then return S.C.danger end
    return dose>=1 and warn or S.C.ok
end
