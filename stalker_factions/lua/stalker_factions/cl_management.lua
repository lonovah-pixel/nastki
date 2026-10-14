local F=STFW
local function btn(parent,label,fn) local b=F.Button(parent,label,fn);b:Dock(TOP);b:DockMargin(0,0,0,8);return b end
local function columns()
 local left=vgui.Create('DScrollPanel',F.Body);left:Dock(LEFT);left:SetWide(300);left:DockMargin(0,0,18,0);STALKER_STYLE.Scroll(left)
 local right=vgui.Create('DScrollPanel',F.Body);right:Dock(FILL);STALKER_STYLE.Scroll(right);return left,right
end
function F.RelationBar(x,y,w,h,points,war)
 local colors={F.C.red,F.C.warn,F.C.green}
 surface.SetDrawColor(colors[1]);surface.DrawRect(x,y,w*.25,h)
 surface.SetDrawColor(colors[2]);surface.DrawRect(x+w*.25,y,w*.5,h)
 surface.SetDrawColor(colors[3]);surface.DrawRect(x+w*.75,y,w*.25,h)
 local marker=x+math.Clamp((points+100)/200,0,1)*(w-3)
 surface.SetDrawColor(F.C.text);surface.DrawRect(marker,y-3,3,h+6)
 surface.SetDrawColor(war and F.C.red or F.C.brass);surface.DrawOutlinedRect(x-1,y-1,w+2,h+2)
end
function F.RelationCard(parent,from,to)
 local p=vgui.Create('DPanel',parent);p:Dock(TOP);p:DockMargin(0,0,0,10);p:SetTall(90)
 p.Paint=function(_,w,h)
  local a=type(from)=='function' and from() or from;local b=type(to)=='function' and to() or to
  local relation,score=F.Relation(a,b,F.State)
  F.Box(0,0,w,h);draw.SimpleText(F.Name(b),'STFW.Body',12,10,F.C.text)
  draw.SimpleText(F.L(relation)..'  '..string.format('%+d',score),'STFW.Small',w-12,12,relation=='war' and F.C.red or F.C.accent,TEXT_ALIGN_RIGHT)
  F.RelationBar(12,43,w-24,9,score,relation=='war')
  draw.SimpleText('−100   ВРАЖДА','STFW.Small',12,65,F.C.muted)
  draw.SimpleText('НЕЙТРАЛИТЕТ','STFW.Small',w/2,65,F.C.muted,TEXT_ALIGN_CENTER)
  draw.SimpleText('СОЮЗ   +100','STFW.Small',w-12,65,F.C.muted,TEXT_ALIGN_RIGHT)
 end
 return p
end
function F.DiplomacySlider(parent,value)
 local slider=F.Slider(parent,'Отношения после соглашения',-100,100,value or 0)
 slider:SetTall(58)
 slider.Slider.Paint=function(_,w,h) F.RelationBar(0,h/2-4,w,8,math.Round(slider:GetValue()),false) end
 return slider
end
local function memberPicker(parent,s)
 local c=vgui.Create('DComboBox',parent);c:Dock(TOP);c:SetTall(36);c:DockMargin(0,0,0,10);F.StyleCombo(c);c:SetValue('Выберите игрока онлайн')
 for _,m in ipairs(s.members or {}) do c:AddChoice(m.name..' / '..F.Name(m.faction),m.sid) end
 c.OnSelect=function(_,_,_,sid) c.SID=sid end;return c
end
function F.ManagementPage(tab,s)
 local function act(data) F.Action(data) end
 if tab=='people' and F.Mode=='admin' and s.admin then
  local left,right=columns();F.Label(left,'ИГРОК И ГРУППИРОВКА',36)
  local picker=memberPicker(left,s);local faction=F.Combo(left,'loner')
  local function memberAction(op,extra)
   if not picker.SID then notification.AddLegacy('Сначала выберите игрока',NOTIFY_ERROR,4);return end
   local a=extra or {};a.kind='editor';a.op=op;a.sid=picker.SID;a.faction=faction.StfwValue;act(a)
  end
  btn(left,'Включить в группировку',function() memberAction('member') end)
  btn(left,'Назначить лидером',function() memberAction('leader') end)
  btn(left,'Снять лидера группировки',function() act({kind='editor',op='leader',faction=faction.StfwValue,sid=''}) end)
  btn(left,'Исключить игрока',function() memberAction('expel') end)
  local rep=F.Slider(left,'Репутация: изменение',-1000,1000,10)
  btn(left,'Применить репутацию',function() memberAction('rep',{amount=math.Round(rep:GetValue())}) end)
  F.Label(right,'ЛИДЕРЫ ГРУППИРОВОК',36)
  for id,sid in SortedPairs(s.leaders or {}) do
   local name=sid;for _,m in ipairs(s.members or {}) do if m.sid==sid then name=m.name end end
   F.Label(right,F.Name(id)..' / '..name,52)
  end
  F.Label(right,'Лидер должен состоять в выбранной группировке. Его отдельное меню: !leader или stfw_leader.',86)
  return true
 elseif tab=='diplomacy_admin' and F.Mode=='admin' and s.admin then
  local left,right=columns();F.Label(left,'УПРАВЛЕНИЕ ОТНОШЕНИЯМИ',40)
  local a=F.Combo(left,'duty');local b=F.Combo(left,'freedom')
  F.RelationCard(right,function() return a.StfwValue end,function() return b.StfwValue end)
  local delta=F.Slider(left,'Изменить на',-100,100,5)
  btn(left,'Применить + / −',function() act({kind='diplomacy',op='adjust',from=a.StfwValue,to=b.StfwValue,points=math.Round(delta:GetValue())}) end)
  for _,op in ipairs({'war','stop'}) do local operation=op
   btn(left,op=='war' and 'Объявить войну' or 'Остановить войну',function()
    Derma_Query('Изменить отношения '..F.Name(a.StfwValue)..' / '..F.Name(b.StfwValue)..'?','Дипломатия','Подтвердить',function() act({kind='diplomacy',op=operation,from=a.StfwValue,to=b.StfwValue}) end,'Отмена')
   end)
  end
  F.Label(right,'Красная зона: −100…−50. Жёлтая: −49…49. Зелёная: 50…100. Война — отдельное состояние; изменение очков само по себе её не отменяет.',105)
  return true
 elseif tab=='traders' and F.Mode=='admin' and s.admin then
  local left,right=columns();F.Label(left,'ТОРГОВЦЫ ГРУППИРОВОК',40)
  if not (STALKER_NPC and STALKER_NPC.Config and STALKER_NPC.Config.Traders) then F.Label(left,'Аддон торговцев (stalker_npc_dialog_trade) не установлен.',60);return true end
  local c=vgui.Create('DComboBox',left);c:Dock(TOP);c:SetTall(38);F.StyleCombo(c);c.Profile='sidor';c:SetValue('Сидорович / Одиночки')
  for id,p in SortedPairs(STALKER_NPC.Config.Traders) do c:AddChoice(STALKER_NPC.Text(p.name)..' / '..F.Name(p.Faction),id) end
  c.OnSelect=function(_,_,_,id) c.Profile=id end
  btn(left,'Поставить торговца под прицел',function() F.BeginPlacement({kind='trader',op='spawn',profile=c.Profile},F.State.revision,'traders') end)
  btn(left,'Удалить торговца под прицелом',function() F.BeginPlacement({kind='trader',op='remove'},F.State.revision,'traders') end)
  btn(left,'Сохранить расстановку',function() act({kind='trader',op='save'}) end)
  F.Label(right,'РАЗМЕЩЕНО НА КАРТЕ',36)
  for _,t in ipairs(s.traders or {}) do local cfg=STALKER_NPC.Config.Traders[t.profile]
   F.Label(right,(cfg and STALKER_NPC.Text(cfg.name) or t.profile)..' / #'..t.entity,38)
  end
  F.Label(right,'Создание и удаление сохраняются автоматически для текущей карты. Склад каждого профиля общий для его копий.',90)
  return true
 end
 return false
end
