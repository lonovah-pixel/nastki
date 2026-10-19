-- Двухпанельный справочник: слева поиск и статьи по разделам, справа текст статьи. Общий для «Энциклопедии» и «Справочника».
local P=STALKER_PDA
local T=STALKER_THEME
local U=STALKER_STYLE
local W=P.UI
local function px(n) return T.Px(n) end

--[[ groups: {{title="Аномалии", items={{id, title, subtitle, color, blocks={…}}}}}
 Блоки статьи: "строка" — абзац; {head="…"} — подзаголовок; {"Ключ","значение",token} — строка таблицы;
 {bar="Подпись",value=0..1,text="…",token="danger"} — полоса; {note="…"} — приглушённая сноска. ]]
local function index(item)
 if item.Index then return item.Index end
 local parts={item.title or "",item.subtitle or ""}
 for _,b in ipairs(item.blocks or {}) do
  if type(b)=="string" then parts[#parts+1]=b
  elseif type(b)=="table" then parts[#parts+1]=tostring(b.head or b.note or b.bar or b[1] or "").." "..tostring(b.text or b[2] or "") end
 end
 item.Index=P.Lower(table.concat(parts," "));return item.Index
end
function P.CatalogMatch(item,query)
 if not query or query=="" then return true end
 return string.find(index(item),query,1,true)~=nil
end

local function kvRow(parent,b)
 local r=vgui.Create("DPanel",parent);r:Dock(TOP);r:SetTall(px(26));r:DockMargin(0,0,0,px(2));r.Row=b
 r.Paint=function(self,w,h)
  local row=self.Row
  U.Text(U.Fit(tostring(row[1]),"STALKER.Body",w*.55),"STALKER.Body",px(4),h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  U.Text(U.Fit(tostring(row[2]),"STALKER.Body",w*.43),"STALKER.Body",w-px(4),h/2,row[3] or "text",TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
  surface.SetDrawColor(T.C.line.r,T.C.line.g,T.C.line.b,80);surface.DrawRect(0,h-1,w,1)
 end
 return r
end
local function barRow(parent,b)
 local r=vgui.Create("DPanel",parent);r:Dock(TOP);r:SetTall(px(36));r:DockMargin(0,0,0,px(4));r.Row=b
 r.Paint=function(self,w,h)
  local row=self.Row
  U.Text(tostring(row.bar),"STALKER.Small",px(4),px(2),"muted")
  if row.text then U.Text(tostring(row.text),"STALKER.Small",w-px(4),px(2),row.token or "text",TEXT_ALIGN_RIGHT) end
  U.Bar(px(4),px(22),w-px(8),px(8),tonumber(row.value) or 0,T.C[row.token or "accent"] or T.C.accent)
 end
 return r
end

function P.ShowArticle(article,item)
 article:Clear()
 if not item then W.Text(article,"Выберите статью слева.","muted");return end
 local title=U.Label(article,item.title or "","STALKER.Big","accent");title:Dock(TOP);title:DockMargin(0,0,0,px(2))
 if item.color then title:SetTextColor(item.color) end
 if item.subtitle and item.subtitle~="" then local s=U.Label(article,item.subtitle,"STALKER.Small","muted");s:Dock(TOP);s:DockMargin(0,0,0,px(8)) end
 local line=vgui.Create("DPanel",article);line:Dock(TOP);line:SetTall(px(8))
 line.Paint=function(_,w) surface.SetDrawColor(T.C.accent);surface.DrawRect(0,0,math.min(w,px(80)),2) end
 for _,b in ipairs(item.blocks or {}) do
  if type(b)=="string" then W.Text(article,b,"text")
  elseif type(b)=="table" then
   if b.head then local h=W.Head(article,b.head);h:DockMargin(0,px(10),0,px(4))
   elseif b.note then W.Text(article,b.note,"muted","STALKER.Small")
   elseif b.bar then barRow(article,b)
   elseif b[1]~=nil then kvRow(article,b) end
  end
 end
end

local function itemPaint(self,w,h)
 local item=self.Item;local active=self.Catalog.selected==item.id
 U.Panel("",0,0,w,h,active or self:IsHovered())
 if item.color then surface.SetDrawColor(item.color);surface.DrawRect(px(2),px(4),px(3),h-px(8)) end
 local x=px(12)
 U.Text(U.Fit(item.title or "","STALKER.Body",w-x-px(8)),"STALKER.Body",x,px(4),active and "accent" or "text")
 if item.subtitle then U.Text(U.Fit(item.subtitle,"STALKER.Small",w-x-px(8)),"STALKER.Small",x,px(22),"muted") end
end

--[[ Строит каталог в parent. opts: placeholder, listWidth, selected (id статьи). Возвращает состояние {select(id), fill()}. ]]
function P.Catalog(parent,groups,opts)
 opts=opts or {}
 local state={groups=groups or {},selected=opts.selected}
 local left=vgui.Create("DPanel",parent);left:Dock(LEFT);left:SetWide(px(opts.listWidth or 270));left:DockMargin(0,0,px(10),0)
 left:DockPadding(px(6),px(6),px(6),px(6))
 left.Paint=function(_,w,h) U.Panel("",0,0,w,h,false) end
 local search=vgui.Create("DTextEntry",left);search:Dock(TOP);search:SetTall(px(30));search:DockMargin(0,0,0,px(6))
 U.Entry(search);search:SetPlaceholderText(opts.placeholder or "Поиск…")
 local list=W.Scroll(left)
 local right=vgui.Create("DPanel",parent);right:Dock(FILL);right:DockPadding(px(16),px(12),px(8),px(12))
 right.Paint=function(_,w,h) U.Panel("",0,0,w,h,false) end
 local article=W.Scroll(right)
 state.list,state.article,state.search=list,article,search

 function state.find(id)
  for _,g in ipairs(state.groups) do for _,item in ipairs(g.items or {}) do if item.id==id then return item end end end
 end
 function state.select(id)
  local item=state.find(id);state.selected=item and item.id or nil
  P.ShowArticle(article,item)
 end
 function state.fill()
  list:Clear()
  local value=search:GetValue();local query=P.Lower(type(value)=="string" and string.Trim(value) or "")
  local shown=0
  for _,g in ipairs(state.groups) do
   local matched={}
   for _,item in ipairs(g.items or {}) do if P.CatalogMatch(item,query) then matched[#matched+1]=item end end
   if #matched>0 then
    if g.title then local h=U.Label(list,g.title,"STALKER.Small","muted");h:Dock(TOP);h:DockMargin(px(4),px(8),0,px(4)) end
    for _,item in ipairs(matched) do
     local b=vgui.Create("DButton",list);b:Dock(TOP);b:SetTall(px(item.subtitle and 42 or 30));b:DockMargin(0,0,0,px(3));b:SetText("")
     b.Item=item;b.Catalog=state;b.Paint=itemPaint
     b.DoClick=function(self) surface.PlaySound("buttons/lightswitch2.wav");state.select(self.Item.id) end
     shown=shown+1
    end
   end
  end
  if shown==0 then W.Text(list,"Ничего не найдено.","muted","STALKER.Small") end
  state.shown=shown
 end
 search.OnChange=function() state.fill() end
 state.fill()
 local first=state.groups[1] and state.groups[1].items and state.groups[1].items[1]
 state.select(state.find(opts.selected or "") and opts.selected or (first and first.id))
 return state
end
