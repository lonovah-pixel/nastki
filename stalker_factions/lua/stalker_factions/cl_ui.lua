local F=STFW
function F.Request() net.Start("stfw.request");net.SendToServer() end
F.RequestID=0
function F.Action(a)
 if not F.State or F.Pending then return end
 F.RequestID=F.RequestID%2147483646+1;a.requestID=F.RequestID;a.revision=a.revision or F.State.revision
 local raw=util.TableToJSON(a);if not raw or #raw>1000 then return end
 F.Pending={id=a.requestID,at=RealTime(),kind=a.kind,op=a.op}
 net.Start("stfw.action");net.WriteUInt(#raw,16);net.WriteData(raw,#raw);net.SendToServer()
end
net.Receive("stfw.state",function()
 local n=net.ReadUInt(16);if n>60000 then return end;local raw=util.Decompress(net.ReadData(n),524288);local state=raw and util.JSONToTable(raw)
 if not state or not state.me then return end;F.State=state;F.StateAt=CurTime()
 hook.Run("STFW_StateUpdated",state)
 -- Периодический снимок не завершает запрос и не уничтожает набранные поля.
 if state.reply and F.Pending and state.reply.id==F.Pending.id then
  local pending=F.Pending;F.Pending=nil
  if state.reply.ok and pending.kind=="editor" and ({create=true,edit=true,move=true,delete=true,capture=true})[pending.op] then F.SaveEditorDraft=nil;F.EditorSelected=state.reply.pointID or F.EditorSelected;F.EditorDraft=nil end
  if IsValid(F.Body) then F.ShowPage(F.Tab or "status") end
 elseif F.RefreshPage and IsValid(F.Body) then F.RefreshPage=false;F.ShowPage(F.Tab or "status") end
end)
local function button(parent,text,fn) local b=F.Button(parent,text,fn);b:Dock(TOP);b:DockMargin(0,0,0,8);return b end
local function entry(parent,text)
 local e=vgui.Create("DTextEntry",parent);e:Dock(TOP);e:DockMargin(0,0,0,8);e:SetTall(34);e:SetText(text or "");F.StyleEntry(e);return e
end
local function split(parent)
 local left=vgui.Create("DScrollPanel",parent);left:Dock(LEFT);left:SetWide(300);left:DockMargin(0,0,16,0)
 local right=vgui.Create("DScrollPanel",parent);right:Dock(FILL);STALKER_STYLE.Scroll(left);STALKER_STYLE.Scroll(right);return left,right
end
function F.ShowPage(tab)
 if not IsValid(F.Body) or not F.State then return end
 if F.SaveEditorDraft then F.SaveEditorDraft();F.SaveEditorDraft=nil end
 local mode=F.Mode or "member"
 local permitted=({member={status=true,map=true,rank=true},admin={admin=true,people=true,diplomacy_admin=true,traders=true}})[mode]
 if not permitted or not permitted[tab] or (mode=="admin" and not F.State.admin) then tab="status";F.Mode="member" end
 F.Tab=tab;for id,b in pairs(F.TabButtons or {}) do b.Active=id==tab end;F.Body:Clear();local s=F.State;local me=s.me
 local function act(a) F.Action(a) end
 if F.ManagementPage(tab,s) then return end
 if tab=="status" then
  local left,right=split(F.Body);local cfg=F.Factions[me.faction];local _,rank=F.Rank(me.xp)
  F.Label(left,"[ "..cfg.tag.." ]  "..F.Name(me.faction),44);F.Label(left,F.Config.Language=="ru" and rank[2] or rank[3])
  if me.joined then F.Label(left,"Звание: "..(me.role=="leader" and "Лидер" or F.FRankName(me.frank))..(s.count and ("  /  состав "..s.count..(s.cap and s.cap>0 and (" из "..s.cap) or "")) or "")) end
  F.Label(left,F.Text(cfg.description),64);F.Label(left,F.Text(cfg.ideology),64);F.Label(left,F.L("nojoin"),70)
  F.Label(right,"XP "..me.xp.."  /  ● "..me.captures.."  /  ⚔ "..me.kills,30)
  F.Label(right,F.L("diplomacy"),36)
  local keys=table.GetKeys(F.Factions);table.sort(keys)
  for _,id in ipairs(keys) do local relation,points=F.Relation(me.faction,id,s);F.RelationCard(right,me.faction,id) end
  F.Label(right,"TOP 10",32);for i,p in ipairs(s.top) do F.Label(right,i..". "..p.name.."   XP "..p.xp.."   ● "..p.captures) end
 elseif tab=="rank" then
  local panel=vgui.Create("DScrollPanel",F.Body);panel:Dock(FILL);local index=F.Rank(me.xp)
  for i,r in ipairs(F.Ranks) do F.Label(panel,(i==index and "▸ " or "  ")..(F.Config.Language=="ru" and r[2] or r[3]).."  —  "..r[1].." XP") end
  F.Label(panel,"XP "..me.xp.." / "..(F.Ranks[index+1] and F.Ranks[index+1][1] or "MAX"));F.Label(panel,F.L("task"),64)
  for _,pt in pairs(s.points) do if pt.owner~="" and F.Relation(me.faction,pt.owner,s)=="war" then F.Label(panel,"● "..pt.name.." — "..F.Name(pt.owner)) end end
 elseif tab=="map" then
  local left,right=split(F.Body);F.Label(left,F.Config.Language=="ru" and "Схема XY / не спутниковая карта" or "XY schematic / not a satellite map",50)
  for _,pt in pairs(s.points) do local point=pt;button(left,point.name,function() F.FocusPoint=point.id end) end
  local map=vgui.Create("DPanel",right);map:Dock(TOP);map:SetTall(380)
  map.Paint=function(_,w,h)
   F.Box(0,0,w,h);local points=F.State.points;local minx,maxx,miny,maxy=math.huge,-math.huge,math.huge,-math.huge
   for _,pt in pairs(points) do minx=math.min(minx,pt.pos.x);maxx=math.max(maxx,pt.pos.x);miny=math.min(miny,pt.pos.y);maxy=math.max(maxy,pt.pos.y) end
   if minx==math.huge then return end
   surface.SetDrawColor(F.C.line.r,F.C.line.g,F.C.line.b,90);for x=20,w,32 do surface.DrawLine(x,0,x,h) end;for y=20,h,32 do surface.DrawLine(0,y,w,y) end
   for id,pt in pairs(points) do local x=40+(maxx==minx and .5 or (pt.pos.x-minx)/(maxx-minx))*(w-80);local y=h-50-(maxy==miny and .5 or (pt.pos.y-miny)/(maxy-miny))*(h-90)
    local c=F.Factions[pt.owner];c=c and Color(unpack(c.color)) or F.C.muted;surface.SetDrawColor(c);surface.DrawRect(x-5,y-5,10,10);local align=x<100 and TEXT_ALIGN_LEFT or (x>w-100 and TEXT_ALIGN_RIGHT or TEXT_ALIGN_CENTER)
    -- Paint каждый кадр для каждой точки: U.Fit ядра без квадратичного utf8.sub GMod.
    local text=pt.name;local U=STALKER_STYLE
    if U.Fit then text=U.Fit(text,"STFW.Small",180) else surface.SetFont("STFW.Small");if surface.GetTextSize(text)>180 then text=utf8.sub(text,1,20).."…" end end
    draw.SimpleText(text,"STFW.Small",x,y+10,F.FocusPoint==id and F.C.accent or F.C.text,align)
   end
  end
  local details=vgui.Create("DPanel",right);details:Dock(TOP);details:SetTall(100)
  details.Paint=function(_,w,h)
   local pt=F.State.points[F.FocusPoint or ""]
   F.Box(0,0,w,h);if not pt then draw.SimpleText(F.L("select_territory"),"STFW.Body",12,14,F.C.muted);return end
   draw.SimpleText((pt.owner~="" and F.Name(pt.owner) or "Ничья точка").." / "..math.floor((pt.progress or 0)*100).."%"..(pt.armed and (" / захват: "..F.Name(pt.armed)) or ""),"STFW.Body",12,12,F.C.accent)
   draw.SimpleText(F.L(F.TerritoryStatus(pt,F.State.me.faction,F.State.me.joined,F.State)),"STFW.Small",12,40,F.C.text)
   draw.SimpleText(F.L("point_radius")..": "..pt.radius.." / "..F.L("base_spawn")..": "..(pt.base and "✓" or "—"),"STFW.Small",12,66,F.C.muted)
  end
  for key,r in pairs(s.relations) do if r.war then F.Label(right,F.L("war").." / "..key.."  "..util.TableToJSON(r.scores or {}),44) end end
  F.Label(right,F.L("history"),30)
  for i=#s.history,math.max(1,#s.history-9),-1 do local h=s.history[i];F.Label(right,F.Name(h.winner).." → "..F.Name(h.loser).."  /  "..os.date("%d.%m %H:%M",h.time),32) end
 elseif tab=="admin" and s.admin then
  local left,right=split(F.Body)
  F.Label(left,F.L("point_settings"),34)
  local selected=vgui.Create("DComboBox",left);selected:Dock(TOP);selected:SetTall(34);selected:DockMargin(0,0,0,8);F.StyleCombo(selected)
  selected:AddChoice(F.L("new_point"),"")
  for id,pt in SortedPairs(s.points) do selected:AddChoice(pt.name,id) end
  local current=F.EditorSelected and s.points[F.EditorSelected]
  local draft=F.EditorDraft or current or {name="",kind="checkpoint",radius=300,height=180,radiation=0,anomaly=0,base=false,owner=""}
  selected:SetValue(current and current.name or F.L("new_point"));selected.StfwID=current and current.id or nil
  F.Label(left,F.L("point_name"),22);local name=entry(left,draft.name);name:SetPlaceholderText(F.L("point_name_example"));F.StyleEntry(name)
  local kind=vgui.Create("DComboBox",left);kind:Dock(TOP);kind:SetTall(34);kind:DockMargin(0,0,0,8);F.StyleCombo(kind);kind.StfwValue=draft.kind or "checkpoint"
  for id,label in SortedPairs(F.PointTypes) do kind:AddChoice(F.Text(label),id) end
  kind:SetValue(F.Text(F.PointTypes[kind.StfwValue]));kind.OnSelect=function(_,_,_,id) kind.StfwValue=id end
  local radius=F.Slider(left,F.L("point_radius"),100,1500,draft.radius);local height=F.Slider(left,F.L("point_height"),64,512,draft.height)
  local radiation=F.Slider(left,F.L("radiation"),0,100,draft.radiation);local anomaly=F.Slider(left,F.L("anomaly"),0,100,draft.anomaly)
  local base=vgui.Create("DCheckBoxLabel",left);base:Dock(TOP);base:SetTall(30);base:SetText(F.L("base_spawn"));base.Label:SetWrap(true);base.Label:SetAutoStretchVertical(true);base:SetTall(42);base:SetTextColor(F.C.text);base:SetValue(draft.base)
  local owner=F.Combo(left,draft.owner or "",true)
  local function fields(op)
   return {kind="editor",op=op,id=selected.StfwID,name=name:GetValue(),pointType=kind.StfwValue,radius=math.Round(radius:GetValue()),height=math.Round(height:GetValue()),radiation=math.Round(radiation:GetValue()),anomaly=math.Round(anomaly:GetValue()),base=base:GetChecked(),owner=owner.StfwValue}
  end
  F.SaveEditorDraft=function()
   if not IsValid(name) then return end
   local data=fields("create");data.kind=kind.StfwValue;F.EditorDraft=data
  end
  selected.OnSelect=function(_,_,_,id) F.SaveEditorDraft=nil;F.EditorDraft=nil;F.EditorSelected=id~="" and id or nil;F.ShowPage("admin") end
  local save=button(left,F.L("edit"),function() act(fields("edit")) end);save:SetEnabled(current~=nil)
  F.Label(right,F.L("placement"),34)
  F.Label(right,F.L("placement_help"),66)
  button(right,F.L("create_feet"),function() local data=fields("create");data.placement="feet";act(data) end)
  button(right,F.L("create"),function() F.BeginPlacement(fields("create"),s.revision) end)
  local move=button(right,F.L("move"),function() F.BeginPlacement({kind="editor",op="move",id=selected.StfwID},s.revision) end);move:SetEnabled(current~=nil)
  local del=button(right,F.L("delete"),function() Derma_Query(F.L("delete").."?",F.L("admin"),F.L("accept"),function() act({kind="editor",op="delete",id=selected.StfwID});F.EditorSelected=nil end,F.L("close")) end);del:SetEnabled(current~=nil)
  local assign=button(right,F.L("point_owner"),function() act({kind="editor",op="capture",id=selected.StfwID,faction=owner.StfwValue}) end);assign:SetEnabled(current~=nil)
  F.Label(right,F.L("recruit"),32);local faction=F.Combo(right,"loner",true)
  button(right,F.L("recruiter"),function() F.BeginPlacement({kind="editor",op="recruiter",faction=faction.StfwValue},s.revision) end)
  button(right,F.L("delete").." / "..F.L("recruit"),function() F.BeginPlacement({kind="editor",op="remove_recruiter"},s.revision) end)

 end
end
function F.Open(initialTab,mode)
 mode=mode or "member"
 if mode=="leader" then return F.OpenCommand and F.OpenCommand() end
 if mode=="admin" and not ((F.State and F.State.admin) or LocalPlayer():IsSuperAdmin()) then F.Request();return end
 if F.SaveEditorDraft then F.SaveEditorDraft();F.SaveEditorDraft=nil end
 F.Request();if IsValid(F.Frame) then F.Frame:Remove() end
 if IsValid(F.CommandFrame) then F.CommandFrame:Remove() end
 F.Mode=mode
 local U=STALKER_STYLE;local frame
 local title=mode=="admin" and "КПК / АДМИНИСТРИРОВАНИЕ ГРУППИРОВОК" or "КПК / ГРУППИРОВКА"
 if U.Window then
  -- Общее окно КПК из ядра: тема, заголовок, закрытие по Escape.
  frame=U.Window({title=title,w=1180,h=760,onClose=function() if F.SaveEditorDraft then F.SaveEditorDraft();F.SaveEditorDraft=nil end end})
  frame.Close=frame.Remove
 else
  frame=vgui.Create("DFrame");frame:SetSize(math.min(ScrW()-48,1180),math.min(ScrH()-48,760));frame:Center();frame:SetTitle("");frame:MakePopup();frame:SetSizable(false)
  frame.Paint=function(_,w,h) STALKER_STYLE.Frame("stalker_factions",w,h);draw.SimpleText(title,"STFW.Title",22,28,F.C.accent) end
  frame:DockPadding(20,76,20,38)
  frame.OnClose=function() if F.SaveEditorDraft then F.SaveEditorDraft();F.SaveEditorDraft=nil end end
 end
 F.Frame=frame
 local tabs=vgui.Create("DPanel",frame);tabs:Dock(LEFT);tabs:SetWide(190);tabs:DockMargin(0,0,18,0);tabs.Paint=nil
 F.TabButtons={}
 local pages=mode=="admin" and {{"admin","Точки и базы"},{"people","Игроки и лидеры"},{"diplomacy_admin","Дипломатия"},{"traders","Торговцы"}}
  or {{"status","Группировка"},{"map","Территории"},{"rank","Ранг и задачи"}}
 for _,v in ipairs(pages) do local tab=v[1];local b=button(tabs,v[2],function() F.ShowPage(tab) end);F.TabButtons[tab]=b end
 button(tabs,"Обновить данные",function() F.RefreshPage=true;F.Request() end)
 if mode=="member" then
  if F.State and F.State.command then button(tabs,"Командование →",function() F.OpenCommand() end) end
  if (F.State and F.State.admin) or LocalPlayer():IsSuperAdmin() then button(tabs,"Админ-панель →",function() F.Open("admin","admin") end) end
 else button(tabs,"Личное меню →",function() F.Open("status","member") end) end
 F.Body=vgui.Create("DPanel",frame);F.Body:Dock(FILL);F.Body.Paint=nil
 frame.Think=function() if not frame.initialized and F.State then frame.initialized=true;frame:InvalidateLayout(true);F.Body:InvalidateLayout(true);F.ShowPage(initialTab or (mode=="admin" and "admin" or "status")) end end
end
concommand.Add("stfw_menu",function() F.Open() end)
concommand.Add("stfw_leader",function() if F.OpenCommand then F.OpenCommand() end end)
concommand.Add("stfw_admin",function() F.Open("admin","admin") end)
local key=CreateClientConVar("stfw_key",tostring(KEY_F6),true,false)
local wasDown=false
hook.Add("Think","STFW.Toggle",function()
 local down=input.IsKeyDown(key:GetInt())
 local open=IsValid(F.Frame) or IsValid(F.CommandFrame)
 if down and not wasDown and IsValid(LocalPlayer()) and not gui.IsGameUIVisible() and (open or not IsValid(vgui.GetKeyboardFocus())) then
  if open then if IsValid(F.Frame) then F.Frame:Remove() end;if IsValid(F.CommandFrame) then F.CommandFrame:Remove() end else F.Open() end
 end
 wasDown=down
end)

-- Размещение подтверждается следующим кликом в игровом мире, а не кликом по меню.
function F.BeginPlacement(data,revision,returnTab)
 if F.Pending then return end
 if F.SaveEditorDraft then F.SaveEditorDraft();F.SaveEditorDraft=nil end
 F.Placement={data=data,revision=revision,released=false,returnTab=returnTab or "admin"}
 if IsValid(F.Frame) then F.Frame:Remove() end
end
hook.Add("Think","STFW.Placement",function()
 if F.Pending and RealTime()-F.Pending.at>8 then F.Pending=nil;notification.AddLegacy(F.L("request_timeout"),NOTIFY_ERROR,5) end
 local place=F.Placement;if not place then return end
 if input.IsKeyDown(KEY_ESCAPE) or input.IsMouseDown(MOUSE_RIGHT) then F.Placement=nil;return end
 if not input.IsMouseDown(MOUSE_LEFT) then place.released=true end
 if place.released and input.IsMouseDown(MOUSE_LEFT) then
  F.Placement=nil;place.data.revision=place.revision;F.Action(place.data);F.Open(place.returnTab,"admin")
 end
end)
hook.Add("HUDPaint","STFW.PlacementHint",function()
 if not F.Placement then return end
 F.Box(ScrW()/2-240,ScrH()-120,480,64,true)
 draw.SimpleText(F.L("placement_click"),"STFW.Body",ScrW()/2,ScrH()-98,F.C.accent,TEXT_ALIGN_CENTER)
 draw.SimpleText(F.L("placement_cancel"),"STFW.Small",ScrW()/2,ScrH()-76,F.C.text,TEXT_ALIGN_CENTER)
end)
