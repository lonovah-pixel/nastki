local A=STALKER_ADMIN
A.C={bg=Color(16,19,16),panel=Color(25,29,24),raised=Color(35,40,32),edge=Color(66,72,52),accent=Color(202,177,99),text=Color(217,219,198),muted=Color(139,151,125),red=Color(199,95,70),green=Color(157,180,104)}
surface.CreateFont("STA.Title",{font="Trebuchet MS",size=28,weight=800})
surface.CreateFont("STA.Body",{font="Trebuchet MS",size=17,weight=500})
surface.CreateFont("STA.Small",{font="Consolas",size=13,weight=500})
surface.CreateFont("STA.Code",{font="Consolas",size=17,weight=700})
function A.Panel(parent,dock)
 local p=vgui.Create("DPanel",parent);p:Dock(dock or FILL);p:DockPadding(12,12,12,12)
 p.Paint=function(_,w,h) surface.SetDrawColor(A.C.panel);surface.DrawRect(0,0,w,h);surface.SetDrawColor(A.C.edge);surface.DrawOutlinedRect(0,0,w,h) end
 return p
end
function A.Label(parent,text,height,color)
 local p=vgui.Create("DLabel",parent);p:Dock(TOP);p:SetTall(height or 28);p:SetFont("STA.Body");p:SetTextColor(color or A.C.text);p:SetText(text);p:SetWrap(true);return p
end
function A.Button(parent,text,fn)
 local p=vgui.Create("DButton",parent);p:Dock(TOP);p:DockMargin(0,0,0,6);p:SetTall(36);p:SetText("")
 p.Paint=function(self,w,h)
  surface.SetDrawColor(self:IsHovered() and A.C.edge or A.C.raised);surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(self.Active and A.C.accent or A.C.edge);surface.DrawRect(0,0,3,h)
  draw.SimpleText(text,"STA.Body",12,h/2,self:IsEnabled() and (self.Active and A.C.accent or A.C.text) or A.C.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 p.DoClick=function() surface.PlaySound("buttons/lightswitch2.wav");fn() end;return p
end
function A.Entry(parent,label,default)
 A.Label(parent,label,24,A.C.muted)
 local e=vgui.Create("DTextEntry",parent);e:Dock(TOP);e:DockMargin(0,0,0,10);e:SetTall(34);e:SetFont("STA.Code");e:SetText(default or "");e:SetTextColor(A.C.text);e:SetCursorColor(A.C.accent);e:SetHighlightColor(A.C.edge)
 e.Paint=function(self,w,h) surface.SetDrawColor(A.C.bg);surface.DrawRect(0,0,w,h);surface.SetDrawColor(A.C.edge);surface.DrawOutlinedRect(0,0,w,h);self:DrawTextEntryText(A.C.text,A.C.edge,A.C.accent) end
 return e
end
function A.Combo(parent,label,values)
 A.Label(parent,label,24,A.C.muted)
 local c=vgui.Create("DComboBox",parent);c:Dock(TOP);c:DockMargin(0,0,0,10);c:SetTall(34);c:SetFont("STA.Body");c:SetValue("Выберите…")
 for _,v in ipairs(values or {}) do c:AddChoice(v.name.." / "..v.id,v.id) end
 c.OnSelect=function(_,_,_,value) c.Value=value end;return c
end
