-- Клиент: окно мастерской (крафт, готовка, ремонт), вкладка КПК «Крафт» (книга рецептов), подсказки у верстака
-- и костра, полоса текущей работы. Окно только показывает и просит: всё проверяет сервер.
local CR=STALKER_CRAFT
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local UI=CR.UI
local px=UI.px
CR.Modes={{"craft","Мастерская"},{"cook","Готовка"},{"repair","Ремонт"}}
CR.ModeNames={craft="Мастерская",cook="Готовка у костра",repair="Ремонт снаряжения"}
CR.Selected=CR.Selected or {}
CR.Amount=CR.Amount or {craft=1,cook=1}
CR.State=CR.State or {crafted=0,cooked=0}

--[[ Запросы серверу ]]
function CR.RequestStart(id,count) C.Send("stalker_craft.start",nil,{id=id,count=count or 1}) end
function CR.RequestCancel() net.Start("stalker_craft.cancel");net.SendToServer() end
function CR.RequestRepair(kit,slot) C.Send("stalker_craft.repair",nil,{kit=kit,slot=slot}) end

--[[ Состояние рецепта для окна: можно ли сделать, строки ингредиентов, причина, станция, на сколько хватит.
 Кэш на полсекунды: карточки перерисовываются каждый кадр. ]]
local statusCache={}
function CR.RecipeStatus(r,counts)
 local now=CurTime();local c=statusCache[r.id]
 if c and c.counts==counts and c.expires>now then return c.can,c.rows,c.why,c.station,c.possible end
 local take,rows=CR.Resolve(r,counts)
 local station,why=CR.StationFor(LocalPlayer(),r,counts)
 if not take then why="Не хватает: "..CR.MissingText(rows) end
 local possible=take and CR.Possible(r,counts) or 0
 local can=take~=nil and station~=nil
 statusCache[r.id]={counts=counts,expires=now+.5,can=can,rows=rows,why=why,station=station,possible=possible}
 return can,rows,why,station,possible
end
-- Где игрок может работать сейчас (подпись и токен цвета).
function CR.StationText(kind)
 local lp=LocalPlayer();if not IsValid(lp) then return "","muted" end
 if kind=="cook" then
  local fire=CR.FindStation(lp,"stalker_campfire")
  if not fire then return "Костра рядом нет — разожгите «Походный костёр» из инвентаря","warn" end
  local left=fire:TimeLeft()
  return left and ("Костёр рядом · догорит через "..CR.FormatTime(left)) or "Костёр рядом · горит постоянно","ok"
 end
 if CR.FindStation(lp,"stalker_workbench") then return "Верстак рядом: доступны все рецепты","ok" end
 if not CR.Config.NeedToolkit or (CR.ClientCounts().toolkit or 0)>0 then return "Без верстака: только простые рецепты","info" end
 return "Нет верстака и набора инструментов: рецепты недоступны","warn"
end
-- Рецепты по категориям вида; рецепты неизвестных категорий — в «Прочее».
function CR.Grouped(kind)
 local list=CR.List(kind);local groups,known={},{}
 for _,cat in ipairs(CR.Categories[kind] or {}) do
  known[cat[1]]=true
  local rows={};for _,r in ipairs(list) do if r.cat==cat[1] then rows[#rows+1]=r end end
  if #rows>0 then groups[#groups+1]={name=cat[2],list=rows} end
 end
 local other={};for _,r in ipairs(list) do if not known[r.cat] then other[#other+1]=r end end
 if #other>0 then groups[#groups+1]={name="Прочее",list=other} end
 return groups,list
end

--[[ Окно ]]
function CR.Open(mode)
 if IsValid(CR.Frame) then CR.Frame:Remove() end
 if CR.ModeNames[mode or ""] then CR.Mode=mode end
 CR.Mode=CR.Mode or "craft"
 local f=U.Window({title=CR.ModeNames[CR.Mode],w=1040,h=680,look=true,onClose=function() CR.Frame=nil;CR.Body=nil;CR.Details=nil end})
 CR.Frame=f
 local top=UI.Row(f,34)
 for _,m in ipairs(CR.Modes) do
  local id=m[1]
  local b=UI.Button(top,m[2],function() CR.Mode=id;CR.Fill() end,nil,150,LEFT)
  b.Active=CR.Mode==id
  b.Think=function(self) self.Active=CR.Mode==id end
 end
 local status=vgui.Create("DPanel",top);status:Dock(FILL)
 status.Paint=function(_,w,h)
  local text,token=CR.StationText(CR.Mode=="cook" and "cook" or "craft")
  U.Text(U.Fit(text,"STALKER.Small",w-px(8)),"STALKER.Small",w-px(4),h/2,token,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
 end
 local body=vgui.Create("DPanel",f);body:Dock(FILL);body.Paint=function() end
 CR.Body=body
 CR.Fill(body)
 return f
end
function CR.Fill(body)
 body=body or CR.Body;if not body then return end
 body:Clear()
 if CR.Frame then CR.Frame.Title=CR.ModeNames[CR.Mode] or "Мастерская" end
 if CR.Mode=="repair" then CR.BuildRepair(body) else CR.BuildRecipes(body,CR.Mode) end
end

function CR.RecipeCard(parent,r,kind)
 local card=UI.Card(parent,58,function(self,w,h)
  local counts=CR.ClientCounts()
  local can,_,why,_,possible=CR.RecipeStatus(r,counts)
  self.Active=CR.Selected[kind]==r.id
  self.Hover=self:IsHovered()
  UI.Icon(r.give[1][1],px(6),px(6),px(66),h-px(12))
  local x=px(80)
  local count=r.give[1][2] or 1
  U.Text(U.Fit(r.name..(count>1 and (" ×"..count) or ""),"STALKER.Body",w-x-px(64)),"STALKER.Body",x,px(8),can and "text" or "muted")
  U.Text(CR.Seconds(CR.Duration(r)),"STALKER.Mono",w-px(8),px(10),"muted",TEXT_ALIGN_RIGHT)
  local line=can and ("Можно сделать: "..possible..(possible>=CR.Config.MaxRepeat and "+" or "")) or (why or "")
  U.Text(U.Fit(line,"STALKER.Small",w-x-px(8)),"STALKER.Small",x,px(32),can and "ok" or "muted")
 end)
 card:SetCursor("hand")
 card.Recipe=r
 card.OnMousePressed=function()
  CR.Selected[kind]=r.id;surface.PlaySound("buttons/lightswitch2.wav")
  if CR.Details then CR.Details.Recipe=r end
 end
 return card
end

function CR.BuildRecipes(body,kind)
 local groups,list=CR.Grouped(kind)
 if #list==0 then
  local sc=UI.Scroll(body)
  UI.Note(sc,kind=="cook" and "Рецептов готовки нет: нужны трофеи разделки туш (мясо мутантов) и провизия Зоны."
   or "Рецептов нет: на сервере не установлены нужные предметы (инвентарь STALKER).","warn")
  return sc
 end
 local sel=CR.ByID[CR.Selected[kind] or ""]
 if not sel or sel.kind~=kind or not CR.Available(sel) then sel=list[1];CR.Selected[kind]=sel.id end
 local left=vgui.Create("DScrollPanel",body);left:Dock(LEFT);left:SetWide(px(400));left:DockMargin(0,0,px(10),0);U.Scroll(left)
 CR.RecipeList=left
 for _,g in ipairs(groups) do
  UI.Head(left,g.name)
  for _,r in ipairs(g.list) do CR.RecipeCard(left,r,kind) end
 end
 return CR.BuildDetails(body,kind,sel)
end

function CR.BuildDetails(body,kind,sel)
 local d=vgui.Create("DPanel",body);d:Dock(FILL);d:DockPadding(px(14),px(14),px(14),px(14))
 d.Recipe=sel
 CR.Details=d
 local controls=vgui.Create("DPanel",d);controls:Dock(BOTTOM);controls:SetTall(px(38));controls.Paint=function() end
 local function amount() return CR.Amount[kind] or 1 end
 local function setAmount(n) CR.Amount[kind]=math.Clamp(math.floor(n),1,math.max(1,math.floor(CR.Config.MaxRepeat))) end
 UI.Button(controls,"−",function() setAmount(amount()-1) end,nil,38,LEFT)
 local box=vgui.Create("DPanel",controls);box:Dock(LEFT);box:SetWide(px(56));box:DockMargin(0,0,px(6),0)
 box.Paint=function(_,w,h) U.Panel("",0,0,w,h,false);U.Text("×"..amount(),"STALKER.Head",w/2,h/2,"text",TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER) end
 UI.Button(controls,"+",function() setAmount(amount()+1) end,nil,38,LEFT)
 UI.Button(controls,"На все",function() local r=d.Recipe;if r then local _,_,_,_,n=CR.RecipeStatus(r,CR.ClientCounts());setAmount(math.max(1,n)) end end,nil,96,LEFT)
 local verb=kind=="cook" and "Приготовить" or "Изготовить"
 local go=U.Button(controls,verb,function()
  if CR.ClientJob() then CR.RequestCancel();return end
  local r=d.Recipe;if r then CR.RequestStart(r.id,amount()) end
 end,"accent")
 go:Dock(FILL)
 go.Think=function(self)
  local job=CR.ClientJob()
  self.Label=job and "Отменить работу" or (verb..(amount()>1 and (" ×"..amount()) or ""))
  self.Kind=job and "danger" or "accent"
  local r=d.Recipe;local can=r and CR.RecipeStatus(r,CR.ClientCounts())
  self:SetEnabled(job~=nil or can==true)
 end
 CR.GoButton=go
 d.Paint=function(self,w,h) CR.PaintDetails(self,w,h,kind) end
 return d
end

function CR.PaintDetails(self,w,h,kind)
 U.Panel("",0,0,w,h,false)
 local r=self.Recipe
 if not r then U.Text("Выберите рецепт слева","STALKER.Body",w/2,h/2,"muted",TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER);return end
 local counts=CR.ClientCounts()
 local _,_,why,station,possible=CR.RecipeStatus(r,counts)
 local times=CR.Amount[kind] or 1
 local _,rows=CR.Resolve(r,counts,times)
 local pad=px(14);local y=pad
 -- Результат: иконка, название, место и время, пояснение.
 local iw,ih=px(144),px(96)
 U.Panel("",pad,y,iw,ih,true)
 UI.Icon(r.give[1][1],pad+px(4),y+px(4),iw-px(8),ih-px(8))
 local x=pad+iw+px(14);local tw=math.max(10,w-x-pad)
 U.Text(U.Fit(r.name,"STALKER.Title",tw),"STALKER.Title",x,y,"accent")
 U.Text(U.Fit("Результат: "..CR.GiveText(r),"STALKER.Body",tw),"STALKER.Body",x,y+px(28),"text")
 U.Text(U.Fit((CR.Stations[r.station] or "").."  ·  "..CR.Seconds(CR.Duration(r)).." на изделие","STALKER.Small",tw),"STALKER.Small",x,y+px(52),"muted")
 local def=STALKER_INV and STALKER_INV.Items and STALKER_INV.Items[r.give[1][1]]
 local lines=U.Wrap(r.note or (def and def.description) or "","STALKER.Small",tw)
 for i=1,math.min(2,#lines) do U.Text(lines[i],"STALKER.Small",x,y+px(70)+(i-1)*px(15),"muted") end
 y=y+ih+px(16)
 -- Ингредиенты: есть / нужно на выбранное количество.
 U.Text(times>1 and ("Ингредиенты на "..times.." шт.") or "Ингредиенты","STALKER.Head",pad,y,"text");y=y+px(24)
 for _,row in ipairs(rows) do
  local rh=px(34)
  U.Panel("",pad,y,w-pad*2,rh,false)
  UI.Icon(row.id,pad+px(4),y+px(3),px(42),rh-px(6))
  U.Text(U.Fit(row.label,"STALKER.Body",math.max(10,w-pad*2-px(170))),"STALKER.Body",pad+px(54),y+rh/2,"text",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  U.Text(row.have.." / "..row.need,"STALKER.Mono",w-pad-px(10),y+rh/2,row.ok and "ok" or "danger",TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
  y=y+rh+px(4)
 end
 y=y+px(6)
 local place=station==true and "набор инструментов в рюкзаке" or (r.station=="fire" and "костёр рядом" or "верстак рядом")
 U.Text(U.Fit(station and ("Место: "..place) or (why or ""),"STALKER.Small",w-pad*2),"STALKER.Small",pad,y,station and "ok" or "warn")
 y=y+px(18)
 U.Text(possible>0 and ("Ингредиентов хватит на "..possible..(possible>=CR.Config.MaxRepeat and "+" or "").." шт.") or "Ингредиентов не хватает","STALKER.Small",pad,y,possible>0 and "text" or "danger")
 -- Текущая работа: полоса прогресса над кнопками.
 local job=CR.ClientJob()
 if job then
  local by=h-pad-px(38)-px(54)
  U.Panel("",pad,by,w-pad*2,px(46),true)
  U.Text(U.Fit(job.label,"STALKER.Small",w-pad*2-px(90)),"STALKER.Small",pad+px(10),by+px(6),"text")
  U.Text(string.format("%.1f с",math.max(0,job.ends-CurTime())),"STALKER.Mono",w-pad-px(10),by+px(6),"muted",TEXT_ALIGN_RIGHT)
  U.Bar(pad+px(10),by+px(27),w-pad*2-px(20),px(8),job.ratio,T.C.accent)
 end
end

--[[ Ремонт: наборы к слотам экипировки ]]
function CR.BuildRepair(body)
 local sc=UI.Scroll(body)
 UI.Note(sc,"Ремкомплект брони чинит надетый костюм или шлем, оружейный набор — экипированное оружие. Наборы делаются в мастерской или "..
  "покупаются у торговцев. Набор можно применить и прямо из инвентаря («Использовать») — к самому изношенному предмету.","text")
 local S=STALKER_INV
 local any=false
 for _,kitID in ipairs({"armor_kit","weapon_kit"}) do
  local kit=CR.Kits[kitID]
  if S and S.Items and S.Items[kitID] then
   any=true
   local head=UI.Head(sc,CR.ItemName(kitID))
   head.Think=function(self) self.Text=CR.ItemName(kitID).."  ·  в рюкзаке: "..(CR.ClientCounts()[kitID] or 0).."  ·  +"..CR.KitAmount(kitID).."% состояния" end
   head:Think()
   for _,slot in ipairs(kit.slots) do
    local slotDef=S.EquipmentByID and S.EquipmentByID[slot]
    local function equipped() local inv=CR.ClientInventory();return inv and inv.equipment and inv.equipment[slot] end
    local card=UI.Card(sc,58,function(_,w,h)
     local item=equipped()
     U.Text(slotDef and slotDef.title or slot,"STALKER.Small",px(12),px(4),"muted")
     if not item then U.Text("Слот пуст","STALKER.Body",px(12),px(24),"muted");return end
     local dur=tonumber(item.durability) or 100
     U.Text(U.Fit(CR.ItemName(item.id),"STALKER.Body",math.max(10,w-px(400))),"STALKER.Body",px(12),px(24),"text")
     local bx=w-px(380)
     U.Bar(bx,px(28),px(160),px(8),dur/100,T.C[UI.ConditionToken(dur)])
     U.Text(dur.."%","STALKER.Mono",bx+px(168),px(23),UI.ConditionToken(dur))
    end)
    local b=UI.Button(card,"Починить",function() CR.RequestRepair(kitID,slot) end,"accent",130)
    b.Think=function(self)
     local item=equipped()
     self:SetEnabled(item~=nil and (tonumber(item.durability) or 100)<100 and (CR.ClientCounts()[kitID] or 0)>0 and not CR.ClientJob())
    end
   end
  end
 end
 if not any then UI.Note(sc,"Ремонт недоступен: инвентарь STALKER не загружен.","warn") end
 return sc
end

--[[ Вкладка КПК «Крафт»: книга рецептов ]]
-- Строка ингредиентов: «Детали 2/4 · Шкура 0/1», каждый — своим цветом.
local function ingredientLine(rows,x,y,w)
 surface.SetFont("STALKER.Small")
 local cx=x
 for i,row in ipairs(rows) do
  local text=(i>1 and "  ·  " or "")..row.label.." "..row.have.."/"..row.need
  local tw=surface.GetTextSize(text)
  if cx+tw>x+w then U.Text("…","STALKER.Small",cx,y,"muted");return end
  U.Text(text,"STALKER.Small",cx,y,row.ok and "ok" or "danger")
  cx=cx+tw
 end
end
function CR.BuildPDATab(parent)
 CR.PDAPanel=parent
 parent:Clear()
 local sc=UI.Scroll(parent)
 UI.Head(sc,"Книга рецептов")
 UI.Card(sc,54,function(_,w,h)
  local st=CR.State or {}
  U.Text("Изготовлено предметов: "..(st.crafted or 0),"STALKER.Body",px(12),px(6),"text")
  U.Text("Приготовлено блюд: "..(st.cooked or 0),"STALKER.Body",px(12),px(26),"text")
  local text,token=CR.StationText("craft")
  U.Text(U.Fit(text,"STALKER.Small",w*.5),"STALKER.Small",w-px(12),px(10),token,TEXT_ALIGN_RIGHT)
  local job=CR.ClientJob()
  if job then U.Text(U.Fit(job.label,"STALKER.Small",w*.5),"STALKER.Small",w-px(12),px(28),"accent",TEXT_ALIGN_RIGHT) end
 end)
 local row=UI.Row(sc,32)
 UI.Button(row,"Открыть мастерскую",function() CR.Open("craft") end,"accent",200,LEFT)
 UI.Button(row,"Ремонт снаряжения",function() CR.Open("repair") end,nil,190,LEFT)
 UI.Note(sc,"Простые рецепты делаются где угодно, если в рюкзаке есть набор инструментов; сложные — только у верстака (верстаки отмечены "..
  "на карте КПК). Готовят у костра: разожгите «Походный костёр» из инвентаря и нажмите E по огню. У огня раны медленно заживают.")
 for _,kind in ipairs({"craft","cook"}) do
  local groups=CR.Grouped(kind)
  for _,g in ipairs(groups) do
   UI.Head(sc,(kind=="cook" and "Готовка · " or "")..g.name)
   for _,r in ipairs(g.list) do
    local recipe=r
    UI.Card(sc,66,function(_,w,h)
     local counts=CR.ClientCounts()
     local can,rows=CR.RecipeStatus(recipe,counts)
     UI.Icon(recipe.give[1][1],px(6),px(6),px(72),h-px(12))
     local x=px(88)
     U.Text(U.Fit(recipe.name.."  →  "..CR.GiveText(recipe),"STALKER.Body",w-x-px(180)),"STALKER.Body",x,px(6),can and "accent" or "text")
     U.Text(CR.Stations[recipe.station] or "","STALKER.Small",w-px(10),px(8),recipe.station=="tool" and "muted" or "info",TEXT_ALIGN_RIGHT)
     ingredientLine(rows,x,px(28),w-x-px(10))
     U.Text(CR.Seconds(CR.Duration(recipe)),"STALKER.Mono",x,px(46),"muted")
    end)
   end
  end
 end
 if #CR.List()==0 then UI.Note(sc,"Рецептов нет: на сервере не установлены нужные предметы.","warn") end
 return sc
end
if C.RegisterPDATab then
 C.RegisterPDATab("craft",{title="Крафт",order=65,build=function(parent) CR.BuildPDATab(parent) end,
  badge=function() if CR.ClientJob() then return 1 end end})
end

--[[ Сеть ]]
net.Receive("stalker_craft.open",function(len)
 local d=C.Read(len,300);if not d then return end
 CR.Open(d.mode)
end)
net.Receive("stalker_craft.state",function(len)
 local d=C.Read(len,300);if not d then return end
 CR.State={crafted=tonumber(d.crafted) or 0,cooked=tonumber(d.cooked) or 0}
end)
concommand.Add("stcraft_menu",function(_,_,args) CR.Open(args[1]) end)

--[[ Экран: подсказка у станции и полоса работы ]]
function CR.HintFor(ent)
 if not IsValid(ent) then return end
 local class=ent:GetClass()
 if class=="stalker_workbench" then return "E — верстак: крафт и ремонт" end
 if class=="stalker_campfire" then
  if not ent:IsLit() then return "Костёр погас" end
  local left=ent:TimeLeft();local owner=ent:GetOwnerName() or ""
  return "E — готовить у костра"..(left and ("  ·  догорит через "..CR.FormatTime(left)) or "")..(owner~="" and ("  ·  "..owner) or "")
 end
end
hook.Add("HUDPaint","STALKER_CRAFT.HUD",function()
 local lp=LocalPlayer();if not IsValid(lp) then return end
 local job=CR.ClientJob(lp)
 if job then
  local w,h=px(340),px(46);local x,y=ScrW()/2-w/2,ScrH()*.78
  U.Panel("",x,y,w,h,true)
  U.Text(U.Fit(job.label,"STALKER.Small",w-px(80)),"STALKER.Small",x+px(10),y+px(6),"text")
  U.Text(string.format("%.1f с",math.max(0,job.ends-CurTime()))..(job.left>0 and ("  +"..job.left) or ""),"STALKER.Mono",x+w-px(10),y+px(6),"muted",TEXT_ALIGN_RIGHT)
  U.Bar(x+px(10),y+px(27),w-px(20),px(8),job.ratio,T.C.accent)
 end
 if CR.Frame then return end
 local tr=lp:GetEyeTrace()
 if tr and tr.HitPos and tr.HitPos:DistToSqr(lp:EyePos())<150*150 then
  local text=CR.HintFor(tr.Entity)
  if text then
   surface.SetFont("STALKER.Body")
   local tw=math.max(px(220),surface.GetTextSize(text)+px(28));local th=px(32)
   local hx,hy=ScrW()/2-tw/2,ScrH()/2+px(40)
   U.Panel("",hx,hy,tw,th,true)
   U.Text(text,"STALKER.Body",ScrW()/2,hy+th/2,"text",TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
  end
 end
end)
