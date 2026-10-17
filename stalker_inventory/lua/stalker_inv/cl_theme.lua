local S=STALKER_INV
-- Цвета инвентаря — токены общей темы (STALKER_THEME.C). Старые имена (background, brass…) сохранены:
-- на них опираются окна торговца и других аддонов. Без ядра — запасная палитра S.Config.Colors.
local TOKENS={background="bg",panel="panel",panel2="panel2",brass="line",lineHi="lineHi",accent="accent",accent2="accent2",
    text="text",muted="muted",danger="danger",ok="ok",warn="warn",info="info",track="track",shadow="shadow",highlight="highlight"}
S.C=S.C or {}
function S.ApplyTheme()
    local T=STALKER_THEME;local fallback=S.Config.Colors
    for key,token in pairs(TOKENS) do
        local c=T and T.C and T.C[token] or fallback[key] or fallback.text
        S.C[key]=Color(c.r,c.g,c.b,c.a)
    end
    -- Токены темы доступны и под своими именами: S.C.bg, S.C.line.
    S.C.bg=S.C.background;S.C.line=S.C.brass
end
S.ApplyTheme()
hook.Add("STALKER_ThemeChanged","STALKER_INV.Theme",function() S.ApplyTheme() end)
-- Цвет с другой прозрачностью (для подсветок и теней поверх панелей).
function S.Alpha(c,alpha) return Color(c.r,c.g,c.b,alpha) end
function S.SetColor(c,alpha) surface.SetDrawColor(c.r,c.g,c.b,alpha or c.a or 255) end
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
-- Рамка ячейки/кнопки: обводка в цвет линии темы (акцент при наведении) и мягкий градиент акцента.
function S.DrawBrassFrame(x,y,w,h,active)
    S.SetColor(active and S.C.accent or S.C.brass);surface.DrawOutlinedRect(x,y,w,h,1)
    surface.SetMaterial(S.Gradient);S.SetColor(S.C.accent,active and 28 or 12)
    surface.DrawTexturedRect(x+1,y+1,w-2,h-2)
    S.SetColor(S.C.shadow,90);surface.DrawOutlinedRect(x+2,y+2,w-4,h-4,1)
end
function S.DrawVignette(w,h)
    for i=0,S.Px(14) do
        S.SetColor(S.C.shadow,math.max(0,25-i));surface.DrawOutlinedRect(i,i,w-i*2,h-i*2,1)
    end
    S.SetColor(S.C.brass,50)
    for i=1,20 do local x=(i*97)%math.max(1,w-40);surface.DrawLine(x,3,x+10+i%19,3) end
end
function S.Text(text,font,x,y,col,ax,ay) draw.SimpleText(text,font,x,y,col or S.C.text,ax or 0,ay or 0) end
function S.FitText(text,font,width)
    surface.SetFont(font);text=tostring(text)
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
    local b=vgui.Create("DButton",parent);b:SetText("");b:SetPos(S.Px(x),S.Px(y));b:SetSize(S.Px(w),S.Px(h));b.Label=text
    b.Paint=function(self,bw,bh)
        local hover=self:IsHovered() and self:IsEnabled()
        S.PaintPanel(0,0,bw,bh,hover);S.DrawBrassFrame(0,0,bw,bh,hover)
        S.Text(S.FitText(self.Label,"SI.Body",bw-S.Px(8)),"SI.Body",bw/2,bh/2,self:IsEnabled() and S.C.text or S.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end
    b.DoClick=function(self) if self:IsEnabled() and fn then fn(self) end end;return b
end
local TAB={}
function TAB:Init() self:SetText("");self.Label="" end
function TAB:Paint(w,h)
    S.PaintPanel(0,0,w,h,self.Active or self:IsHovered());S.DrawBrassFrame(0,0,w,h,self.Active or self:IsHovered())
    S.Text(self.Label,"SI.Body",w/2,h/2,self.Active and S.C.accent or S.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
end
vgui.Register("DToggleTab",TAB,"DButton")
-- Полоса характеристики: подпись слева, значение справа, тонкая шкала снизу. Номинал (до износа) — приглушённо.
function S.DrawStatRow(row,x,y,w,font)
    font=font or "SI.Small"
    S.Text(S.FitText(row.label,font,w*.62),font,x,y,S.C.muted)
    local value=row.nominal and (row.text.." / "..row.nominal) or row.text
    S.Text(value,font,x+w,y,S.C[row.token] or S.C.text,TEXT_ALIGN_RIGHT)
    if row.ratio then
        local by=y+S.Px(13)
        S.SetColor(S.C.track);surface.DrawRect(x,by,w,S.Px(2))
        S.SetColor(S.C[row.token] or S.C.accent);surface.DrawRect(x,by,math.floor(w*row.ratio),S.Px(2))
    end
end
-- Радиация берётся из сетевых переменных сервера (обновляются каждую секунду), а не из снимка инвентаря.
function S.RadiationDose(ply) ply=ply or LocalPlayer();return IsValid(ply) and ply:GetNW2Float("stalker_dose",0) or 0 end
function S.RadiationRate(ply) ply=ply or LocalPlayer();return IsValid(ply) and ply:GetNW2Float("stalker_rad_rate",0) or 0 end
function S.RadiationDanger() return STALKER_RAD and STALKER_RAD.Config and STALKER_RAD.Config.DamageThreshold or 30 end
function S.RadiationColor(dose)
    if dose>=S.RadiationDanger() then return S.C.danger end
    return dose>=1 and S.C.warn or S.C.ok
end
-- Цвет состояния предмета: целый — ok, потрёпанный — warn, изношенный — danger.
function S.ConditionColor(durability)
    durability=tonumber(durability) or 100
    if durability<25 then return S.C.danger end
    return durability<50 and S.C.warn or S.C.ok
end
