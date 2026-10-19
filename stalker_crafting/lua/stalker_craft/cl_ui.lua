-- Общие элементы окон крафта: строятся только из STALKER_STYLE и цветов темы (STALKER_THEME.C).
local CR=STALKER_CRAFT
local T=STALKER_THEME
local U=STALKER_STYLE
local function px(n) return T.Px(n) end
local UI={}
CR.UI=UI
UI.px=px

function UI.Scroll(parent) local sc=vgui.Create("DScrollPanel",parent);sc:Dock(FILL);U.Scroll(sc);return sc end
function UI.Head(parent,text)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(30));p:DockMargin(0,px(8),0,px(4))
 p.Text=text
 p.Paint=function(self,w,h) U.Text(self.Text,"STALKER.Head",0,h/2,"accent",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);surface.SetDrawColor(T.C.line);surface.DrawRect(0,h-1,w,1) end
 return p
end
function UI.Note(parent,text,token)
 local l=U.Label(parent,text,"STALKER.Small",token or "muted");l:Dock(TOP);l:DockMargin(0,0,0,px(6))
 return l
end
function UI.Card(parent,h,paint)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(h));p:DockMargin(0,0,0,px(6))
 p:DockPadding(px(8),px(8),px(8),px(8))
 p.Paint=function(self,w,hh) U.Panel("",0,0,w,hh,self.Active or self.Hover);if paint then paint(self,w,hh) end end
 return p
end
function UI.Row(parent,h)
 local p=vgui.Create("DPanel",parent);p:Dock(TOP);p:SetTall(px(h or 32));p:DockMargin(0,0,0,px(6))
 p.Paint=function() end
 return p
end
-- Кнопка у края строки (dock — RIGHT по умолчанию).
function UI.Button(parent,label,fn,kind,wide,dock)
 local b=U.Button(parent,label,fn,kind);b:Dock(dock or RIGHT);b:SetWide(px(wide or 130))
 if (dock or RIGHT)==RIGHT then b:DockMargin(px(6),0,0,0) else b:DockMargin(0,0,px(6),0) end
 return b
end
function UI.Entry(parent,placeholder,value,onChange)
 local e=vgui.Create("DTextEntry",parent);U.Entry(e);e:Dock(FILL)
 e:SetPlaceholderText(placeholder or "");e:SetValue(value or "")
 e.OnChange=function(self) if onChange then onChange(self:GetValue()) end end
 return e
end
-- Иконка предмета инвентаря (без инвентаря — первая буква названия).
function UI.Icon(id,x,y,w,h)
 local S=STALKER_INV
 if S and S.DrawItemIcon and S.Items and S.Items[id or ""] and S.Items[id].icon~="" then S.DrawItemIcon({id=id},x,y,w,h);return end
 surface.SetDrawColor(T.C.track);surface.DrawRect(x,y,w,h)
 local name=CR.ItemName(id or "?")
 U.Text(utf8.sub(name,1,1),"STALKER.Head",x+w/2,y+h/2,"muted",TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
end
-- Цвет состояния: целый — ok, потрёпанный — warn, изношенный — danger.
function UI.ConditionToken(d) d=tonumber(d) or 100;if d<25 then return "danger" end;return d<50 and "warn" or "ok" end

-- Снимок рюкзака клиента: количество предметов пересчитывается только при новой ревизии инвентаря.
local cache={}
function CR.ClientInventory() local S=STALKER_INV;return S and S.Inventory end
function CR.ClientCounts()
 local inv=CR.ClientInventory()
 if not inv then return {} end
 if cache.inv~=inv or cache.rev~=inv.revision then cache.inv=inv;cache.rev=inv.revision;cache.counts=CR.Counts(inv) end
 return cache.counts or {}
end
-- Текущая работа игрока (по сетевым переменным сервера).
function CR.ClientJob(ply)
 ply=ply or LocalPlayer();if not IsValid(ply) then return end
 local ends=ply:GetNW2Float("stcraft_end",0);if ends<=CurTime() then return end
 local start=ply:GetNW2Float("stcraft_start",0)
 return {recipe=ply:GetNW2String("stcraft_recipe",""),label=ply:GetNW2String("stcraft_label",""),start=start,ends=ends,left=ply:GetNW2Int("stcraft_left",0),
  ratio=math.Clamp((CurTime()-start)/math.max(.01,ends-start),0,1)}
end
