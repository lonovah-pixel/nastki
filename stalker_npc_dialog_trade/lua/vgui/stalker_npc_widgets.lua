local N=STALKER_NPC
N.Colors={bg=Color(28,26,20),panel=Color(42,38,32),brass=Color(107,93,63),accent=Color(200,169,81),text=Color(217,207,176),muted=Color(138,127,99),green=Color(102,151,81),red=Color(162,43,31)}
function N.P(v) return math.Round(v*(N.Scale or 1)) end
function N.Fonts()
    surface.CreateFont("STNPC.Title",{font="Trebuchet MS",size=N.P(25),weight=500,extended=true})
    surface.CreateFont("STNPC.Body",{font="Tahoma",size=N.P(17),weight=400,extended=true})
    surface.CreateFont("STNPC.Small",{font="Consolas",size=N.P(12),weight=400,extended=true})
end
function N.Label(p,text,x,y,w,h,font,color)
    local l=vgui.Create("DLabel",p);l:SetPos(N.P(x),N.P(y));l:SetSize(N.P(w),N.P(h));l:SetText(text)
    l:SetFont(font or "STNPC.Body");l:SetTextColor(color or N.Colors.text);l:SetWrap(true);return l
end
function N.Panel(p,x,y,w,h)
    local v=vgui.Create("DPanel",p);v:SetPos(N.P(x),N.P(y));v:SetSize(N.P(w),N.P(h))
    v.Paint=function(_,pw,ph) STALKER_STYLE.Panel("stalker_npc",0,0,pw,ph) end;return v
end
local B={}
function B:Init() self:SetText("");self.Caption="";self.Hover=0 end
function B:Paint(w,h)
    local c=N.Colors;self.Hover=Lerp(math.min(FrameTime()*12,1),self.Hover,self:IsHovered() and 1 or 0)
    STALKER_STYLE.Panel("stalker_npc",0,0,w,h,self.Active or self:IsHovered())
    surface.SetDrawColor(200,169,81,30*self.Hover);surface.DrawRect(0,0,w,h)
    STALKER_INV.DrawBrassFrame(0,0,w,h,self.Active or self:IsHovered())
    local lines=STALKER_INV.Wrap(self.Caption,"STNPC.Body",w-N.P(24))
    for i=1,math.min(2,#lines) do draw.SimpleText(lines[i],"STNPC.Body",w/2,h/2+(i-(math.min(2,#lines)+1)/2)*N.P(19),self:IsEnabled() and (self.Active and c.accent or c.text) or c.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER) end
end
vgui.Register("STNPCButton",B,"DButton")
function N.Button(p,text,x,y,w,h,fn)
    local b=vgui.Create("STNPCButton",p);b.Caption=text;b:SetPos(N.P(x),N.P(y));b:SetSize(N.P(w),N.P(h))
    b.DoClick=function() surface.PlaySound(N.Config.SoundClick);fn() end;return b
end
local ROW={}
function ROW:Init() self:SetText("");self:SetTall(N.P(72));self:SetCursor("hand") end
function ROW:Setup(item,price,fn)
    self.Item=item;self.Price=price;self.DoClick=fn;local d=STALKER_INV.Items[item.id]
    self:SetTooltip(d.name.."\n"..d.description.."\n"..d.weight.." kg • "..item.durability.."%")
end
function ROW:Paint(w,h)
    if not self.Item then return end
    local c=N.Colors;local item=self.Item;local d=STALKER_INV.Items[item.id]
    surface.SetDrawColor(c.panel);surface.DrawRect(0,0,w,h);STALKER_INV.DrawBrassFrame(0,0,w,h,self:IsHovered())
    if d.icon~="" then self.Material=self.Material or Material(d.icon,"smooth") end
    if self.Material and not self.Material:IsError() then
        surface.SetMaterial(self.Material);surface.SetDrawColor(255,255,255);surface.DrawTexturedRect(N.P(8),N.P(8),N.P(48),N.P(48))
    else draw.SimpleText("[ICON]","STNPC.Small",N.P(9),N.P(26),c.muted) end
    draw.SimpleText(STALKER_INV.FitText(d.name,"STNPC.Body",w-N.P(90)),"STNPC.Body",N.P(68),N.P(8),c.text)
    draw.SimpleText("x"..item.count.."  •  "..item.durability.."%  •  "..d.weight.." kg","STNPC.Small",N.P(68),N.P(32),c.muted)
    draw.SimpleText(self.Price and (self.Price.." ₽ / 1") or N.L("notrade"),"STNPC.Small",N.P(68),N.P(51),self.Price and c.accent or c.muted)
    surface.SetDrawColor(c.green);surface.DrawRect(N.P(8),h-N.P(7),N.P(48)*item.durability/100,N.P(2))
end
vgui.Register("STNPCItemRow",ROW,"DButton")
function N.Scroll(parent,x,y,w,h)
    local s=vgui.Create("DScrollPanel",parent);s:SetPos(N.P(x),N.P(y));s:SetSize(N.P(w),N.P(h))
    local bar=s:GetVBar();bar:SetWide(N.P(6));bar:SetHideButtons(true)
    bar.Paint=function(_,bw,bh) surface.SetDrawColor(N.Colors.bg);surface.DrawRect(0,0,bw,bh) end
    bar.btnGrip.Paint=function(_,bw,bh) draw.RoundedBox(0,0,0,bw,bh,N.Colors.brass) end
    return s
end

-- Сетки обмена: клиенты выбирают экземпляры, цена и сделка остаются серверными.
function N.ItemGrid(parent,inv,side,width,height,profile)
 local scroll=N.Scroll(parent,0,0,width,height)
 local layout=vgui.Create("DIconLayout",scroll);layout:Dock(TOP);layout:SetSpaceX(N.P(6));layout:SetSpaceY(N.P(6))
 local columns=side and 5 or 8;local size=math.floor((width-12-(columns-1)*6)/columns)
 layout:SetWide(N.P(width-12))
 for index=1,40 do local item=inv.grid[index];local slot=index
  local cell=layout:Add("DButton");cell:SetText("");cell:SetSize(N.P(size),N.P(size+(side and 18 or 0)));cell:SetCursor(item and "hand" or "arrow")
  local price=item and side and N.DisplayPrice(profile,item,side) or nil
  if item then
   local def=STALKER_INV.Items[item.id];cell:SetTooltip(def.name.."\n"..def.description.."\n"..item.count.." шт. / "..def.weight.." kg / "..item.durability.."%"..(price and ("\n"..price.." ₽ / 1") or ""))
  end
  cell.Paint=function(self,w,h)
   local selected=side and N.Cart and N.Cart[side..":"..slot]
   STALKER_STYLE.Panel("stalker_npc",0,0,w,h,self:IsHovered() or selected~=nil)
   if not item then return end
   STALKER_INV.DrawItemIcon(item,N.P(4),N.P(5),w-N.P(8),h-N.P(side and 27 or 13))
   draw.SimpleText("x"..item.count,"STNPC.Small",w-N.P(4),N.P(4),N.Colors.text,TEXT_ALIGN_RIGHT)
   STALKER_STYLE.Bar(N.P(4),h-N.P(side and 24 or 6),w-N.P(8),N.P(3),item.durability/100,item.durability<25 and N.Colors.red or N.Colors.green)
   if side then draw.SimpleText(price and tostring(price) or "—","STNPC.Small",w/2,h-N.P(17),price and N.Colors.accent or N.Colors.muted,TEXT_ALIGN_CENTER) end
  end
  cell.DoClick=function() if item and side and price then N.Quantity(side,slot,item) end end
 end
 return scroll
end
