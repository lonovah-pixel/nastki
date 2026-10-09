local F=STFW
F.C={bg=Color(22,24,19),panel=Color(35,39,30),brass=Color(107,93,63),text=Color(217,207,176),muted=Color(138,143,115),accent=Color(200,169,81),green=Color(112,158,91),red=Color(179,68,48)}
surface.CreateFont("STFW.Title",{font="Roboto Condensed",size=26,weight=700,extended=true})
surface.CreateFont("STFW.Body",{font="Tahoma",size=16,weight=500,extended=true})
surface.CreateFont("STFW.Small",{font="Tahoma",size=13,weight=500,extended=true})
local noise=Material("stalker_factions/noise.png","smooth")
function F.Box(x,y,w,h,active) STALKER_STYLE.Panel("stalker_factions",x,y,w,h,active) end
function F.StyleEntry(e) STALKER_STYLE.Entry(e,"stalker_factions") end
function F.StyleCombo(c) STALKER_STYLE.Combo(c,"stalker_factions","STFW.Body") end
function F.Button(parent,label,click)
 local b=vgui.Create("DButton",parent);b:SetText("");b:SetTall(36);b.StfwText=label;b.fade=0
 b.Paint=function(self,w,h) self.fade=Lerp(math.min(1,FrameTime()*12),self.fade,self:IsHovered() and 1 or 0);F.Box(0,0,w,h,self.Active or self.fade>.2);draw.SimpleText(self.StfwText,"STFW.Body",10,h/2,self:IsEnabled() and F.C.text or F.C.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
 b.DoClick=function() surface.PlaySound("buttons/lightswitch2.wav");click() end;return b
end
function F.Label(parent,text,height)
 local l=vgui.Create("DLabel",parent);l:SetFont("STFW.Body");l:SetTextColor(F.C.text);l:SetText(text);l:SetWrap(true);l:SetTall(height or 30);l:Dock(TOP);l:DockMargin(0,0,0,8);return l
end
function F.Combo(parent,selected,neutral)
 local c=vgui.Create("DComboBox",parent);c:SetTall(32);c:Dock(TOP);c:DockMargin(0,0,0,8);c.StfwValue=selected or "loner"
 if neutral then c:AddChoice("—","") end
 local keys=table.GetKeys(F.Factions);table.sort(keys)
 for _,id in ipairs(keys) do if F.Factions[id].playable then c:AddChoice(F.Name(id),id) end end
 c:SetValue(selected=="" and "—" or F.Name(c.StfwValue));F.StyleCombo(c);c.OnSelect=function(_,_,_,v) c.StfwValue=v end;return c
end
function F.Slider(parent,title,min,max,value)
 local s=vgui.Create("DNumSlider",parent);s:Dock(TOP);s:SetTall(40);s:SetText(title);s:SetMin(min);s:SetMax(max);s:SetDecimals(0);s:SetValue(value);s.Label:SetTextColor(F.C.text);s.TextArea:SetTextColor(F.C.text);s.Slider.Paint=function(_,w,h) STALKER_STYLE.Bar(0,h/2-2,w,4,(s:GetValue()-min)/math.max(1,max-min),F.C.brass) end;return s
end
