local B=STALKER_BUTCHERING
-- Палитра берётся из общей темы (STALKER_THEME) при каждой отрисовке; без ядра — исходные цвета полевого набора.
local fallback={bg=Color(20,21,17),panel=Color(32,34,27),raised=Color(41,44,33),brass=Color(95,91,61),text=Color(222,216,188),muted=Color(143,149,119),gold=Color(204,177,101),green=Color(119,167,96),red=Color(190,85,64),track=Color(12,15,11),edge=Color(52,55,40)}
local tokens={bg='bg',panel='panel',raised='panel2',brass='line',text='text',muted='muted',gold='accent',green='ok',red='danger',track='track',edge='shadow'}
local C=setmetatable({},{__index=function(_,k)
 local T=STALKER_THEME;local token=tokens[k]
 if T and T.C and token and T.C[token] then return T.C[token] end
 return fallback[k]
end})
local function alpha(col,a) return Color(col.r,col.g,col.b,a) end
local active,window,pressed,escape=false,nil,false,false
local scale=1
local function px(v) return math.floor(v*scale+.5) end
local function fonts()
 for name,d in pairs({Title={'Trebuchet MS',25,800},Body={'Tahoma',16,500},Small={'Tahoma',13,400},Number={'Trebuchet MS',36,800}}) do
  surface.CreateFont('STB.'..name,{font=d[1],size=px(d[2]),weight=d[3],extended=true})
 end
end
local function text(t,x,y,c,font) draw.SimpleText(t,'STB.'..(font or 'Body'),px(x),px(y),c or C.text) end
local function rect(x,y,w,h,c) surface.SetDrawColor(c);surface.DrawRect(px(x),px(y),px(w),px(h)) end
local function border(x,y,w,h,c) surface.SetDrawColor(c or C.brass);surface.DrawOutlinedRect(px(x),px(y),px(w),px(h),1) end
local function play(id) local s=B.Config.Sounds[id];if s and s~='' then surface.PlaySound(s) end end
local function cancel()
 if active then net.Start('stb.cancel');net.WriteUInt(active.token,32);net.SendToServer();active=false end
end
local function close(silent)
 if silent then active=false else cancel() end
 if IsValid(window) then window:Remove() end;window=nil
end
local function button(parent,x,y,w,h,label,action)
 local p=vgui.Create('DButton',parent);p:SetPos(px(x),px(y));p:SetSize(px(w),px(h));p:SetText('')
 p.Paint=function(s)
  rect(0,0,w,h,s:IsHovered() and C.raised or C.panel);border(0,0,w,h,s:IsHovered() and C.gold or C.brass)
  draw.SimpleText(label,'STB.Body',px(w/2),px(h/2),s:IsEnabled() and C.gold or C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
 p.DoClick=action;return p
end
local function frame(title,step)
 close(true);scale=math.Clamp(math.min(ScrW()/1000,ScrH()/760),.7,1.7);fonts()
 window=vgui.Create('DFrame');window:SetSize(px(820),px(560));window:Center();window:SetTitle('');window:ShowCloseButton(false);window:MakePopup();window:SetDraggable(false)
 window.Paint=function()
  rect(0,0,820,560,C.bg);border(0,0,820,560);border(5,5,810,550,C.edge)
  rect(6,6,808,81,C.panel);rect(24,26,3,39,C.gold)
  text('ПОЛЕВОЙ НАБОР',40,21,C.gold,'Title');text(title,40,54,C.muted,'Small')
  text('КПК / ОБРАБОТКА ОБРАЗЦОВ',26,102,C.muted,'Small');text(step or '',577,102,C.gold,'Small')
  rect(24,126,772,1,C.brass)
  -- Редкие статичные царапины, без покадрового шума и мерцания.
  for i=1,12 do rect(8+(i*113)%794,7,4+i%8,1,alpha(C.gold,30)) end
  text('ЗОНА  /  ПОЛЕВАЯ ЛАБОРАТОРИЯ',24,531,C.muted,'Small')
 end
 window.OnRemove=function() cancel() end
 window.OnKeyCodePressed=function(_,key) if key==KEY_ESCAPE then close(false) elseif key==KEY_SPACE and B.Hit then B.Hit() end end
 button(window,757,24,38,38,'×',function() close(false) end)
 return window
end
local function selector(ent)
 local cfg=B.Config.Mutants[ent:GetNW2String('stb_mutant','')];if not cfg then return end
 local f=frame(cfg.name..' / доступна одна разделка','01 / ВЫБОР ТРОФЕЯ')
 local selected=1;local mask=ent:GetNW2Int('stb_parts',0);local unavailable=mask~=0
 local descriptions={meat='Провизия и сырьё для торговцев',hide='Целостность влияет на стоимость',organ='Точность сохраняет ткани образца',rare='Ценный образец. Выпадение не гарантировано'}
 for i,part in ipairs(B.Config.Parts) do
  local x=24+((i-1)%2)*392;local y=146+math.floor((i-1)/2)*125
  local p=vgui.Create('DButton',f);p:SetPos(px(x),px(y));p:SetSize(px(380),px(111));p:SetText('');p:SetEnabled(not unavailable)
  local hover=0
  p.Paint=function(s)
   hover=Lerp(math.min(1,FrameTime()*12),hover,s:IsHovered() and 1 or 0)
   rect(0,0,380,111,selected==i and C.raised or C.panel);border(0,0,380,111,selected==i and C.gold or C.brass)
   if selected==i then rect(0,0,3,111,C.gold) end
   rect(13,16,49,51,C.track);text(string.format('%02d',i),21,26,selected==i and C.gold or C.muted,'Title')
   text(part.name,77,15,unavailable and C.muted or C.text)
   text(descriptions[part.id] or 'Полевой образец',77,43,C.muted,'Small')
   text('СЛОЖНОСТЬ  ×'..part.difficulty,15,83,C.muted,'Small')
   text(selected==i and 'ВЫБРАНО' or 'ВЫБРАТЬ',273,83,selected==i and C.gold or C.muted,'Small')
   if hover>.01 then rect(1,109,378,1,alpha(C.gold,math.floor(hover*200))) end
  end
  p.DoClick=function() selected=i;play('hit') end
 end
 local note=vgui.Create('DPanel',f);note:SetPos(px(24),px(400));note:SetSize(px(772),px(53))
 note.Paint=function()
  rect(0,0,772,53,C.raised);rect(0,0,3,53,C.gold);text('ОДНА ТУША — ОДИН ВЫБРАННЫЙ ТРОФЕЙ',14,8,C.gold,'Small')
  text(unavailable and 'Эта туша уже занята или использована.' or 'После попытки тело исчезнет. Отмена также расходует тушу.',14,29,C.muted,'Small')
 end
 button(f,24,468,222,43,'ЗАКРЫТЬ',function() close(true) end)
 local start=button(f,262,468,534,43,'НАЧАТЬ РАЗДЕЛКУ',function()
  if not IsValid(ent) then close(true);return end
  net.Start('stb.start');net.WriteUInt(ent:EntIndex(),16);net.WriteUInt(selected,3);net.SendToServer();close(true)
 end);start:SetEnabled(not unavailable)
 play('open')
end
B.Hit=function()
 if not active then return end
 local elapsed=CurTime()-active.start;local i=math.floor(elapsed/active.seconds)+1
 if elapsed<0 or i>#active.rounds or active.sent[i] then return end
 active.sent[i]=true
 net.Start('stb.hit');net.WriteUInt(active.token,32);net.WriteUInt(i,2);net.SendToServer();play('hit')
end
local function result(data)
 local g=B.Config.Grades[data.grade];if not g then return end
 local f=frame('Образец обработан / туша израсходована','03 / РЕЗУЛЬТАТ')
 local p=vgui.Create('DPanel',f);p:SetPos(px(24),px(147));p:SetSize(px(772),px(305))
 p.Paint=function()
  rect(0,0,772,93,C.panel);rect(0,0,4,93,data.grade=='fail' and C.red or C.green)
  text(string.upper(g.name),23,19,data.grade=='fail' and C.red or C.gold,'Title')
  text('Точность '..math.floor((data.score or 0)*100)..'%   /   Опыт +'..(data.xp or 0),23,57,C.muted)
  local labels={'ПОЛУЧЕНО','СОСТОЯНИЕ','ЗАГРЯЗНЕНИЕ'}
  local values={tostring(data.count)..' шт.',tostring(data.condition)..'%',data.toxic and 'ТОКСИЧНО' or 'ЧИСТО'}
  for i=1,3 do local x=(i-1)*261
   rect(x,110,250,95,C.panel);text(labels[i],x+14,124,C.muted,'Small');text(values[i],x+14,157,i==3 and data.toxic and C.red or C.text,'Title')
  end
 end
 local message=vgui.Create('DLabel',f);message:SetPos(px(38),px(375));message:SetSize(px(738),px(73));message:SetFont('STB.Body');message:SetTextColor(C.muted);message:SetWrap(true);message:SetText(data.text or '')
 button(f,24,468,772,43,'ГОТОВО',function() close(true) end);play('finish')
end
net.Receive('stb.state',function()
 local data=util.JSONToTable(net.ReadString());if type(data)~='table' then return end
 if data.kind=='message' then notification.AddLegacy(data.text,NOTIFY_GENERIC,7);return end
 if data.kind=='result' then result(data);return end
 if data.kind=='end' then close(true);notification.AddLegacy(data.text,NOTIFY_GENERIC,7);return end
 if data.kind=='hit' then if active then active.scores[data.index]=data.score end;return end
 if data.kind~='start' then return end
 local f=frame(data.title,'02 / ТОЧНЫЙ РАЗРЕЗ');active=data;active.sent={};active.scores={}
 local game=vgui.Create('DPanel',f);game:SetPos(px(24),px(147));game:SetSize(px(772),px(305));game:SetMouseInputEnabled(true)
 game.OnMousePressed=function(_,key) if key==MOUSE_LEFT then B.Hit() end end
 game.Paint=function()
  local a=active;if not a then return end
  local elapsed=CurTime()-a.start;local i=math.Clamp(math.floor(elapsed/a.seconds)+1,1,#a.rounds)
  local t=math.max(0,elapsed-(i-1)*a.seconds);local r=a.rounds[i]
  text(elapsed<0 and 'ПРИГОТОВЬТЕСЬ' or elapsed>=#a.rounds*a.seconds and 'ЗАВЕРШЕНИЕ' or ('РАЗРЕЗ 0'..i),0,0,C.gold,'Title')
  text('Нажмите в центре светлой области',0,39,C.muted)
  text(string.format('%04.1f c',math.max(0,a.ends-CurTime())),645,1,C.text,'Title')
  rect(0,94,772,96,C.track);border(0,94,772,96)
  for tick=0,20 do rect(12+tick*37.4,167,1,tick%5==0 and 15 or 7,C.brass) end
  local w=748;local left=12
  rect(left+(r.center-r.width/2)*w,105,r.width*w,48,alpha(C.green,70))
  rect(left+(r.center-r.width*.075)*w,105,r.width*.15*w,48,C.green)
  local marker=B.Marker(t,r.speed,r.offset)
  rect(left+marker*w-2,99,4,64,C.gold)
  text(a.sent[i] and 'Нажатие отправлено. Ожидайте следующего разреза.' or 'ЛКМ / ПРОБЕЛ — сделать разрез',0,205,a.sent[i] and C.green or C.text)
  for k=1,#a.rounds do
   local val=a.scores[k];local label=val and math.floor(val*100)..'%' or a.sent[k] and '…' or '—'
   rect((k-1)*261,244,250,41,C.panel);text('0'..k..'   /   '..label,(k-1)*261+14,255,val and C.gold or C.muted)
  end
  rect(0,300,772,3,C.panel);rect(0,300,772*math.Clamp(elapsed/(#a.rounds*a.seconds),0,1),3,C.gold)
 end
 button(f,24,468,772,43,'ПРЕРВАТЬ — ТУША БУДЕТ ПОТЕРЯНА',function() close(false) end)
end)
hook.Add('Think','STB.Interact',function()
 local key=input.GetKeyCode(input.LookupBinding('+use') or 'e');local down=key and input.IsKeyDown(key)
 if down and not pressed and not IsValid(window) and not gui.IsGameUIVisible() and not vgui.CursorVisible() then
  local p=LocalPlayer();if IsValid(p) and p:Alive() and not B.Unconscious(p) then
   local tr=p:GetEyeTrace();if IsValid(tr.Entity) and tr.Entity:GetNW2String('stb_mutant','')~='' and tr.HitPos:DistToSqr(p:GetShootPos())<=B.Config.Distance^2 then selector(tr.Entity) end
  end
 end
 pressed=down
 local esc=input.IsKeyDown(KEY_ESCAPE);if esc and not escape and IsValid(window) then close(false) end;escape=esc
 if IsValid(window) then local p=LocalPlayer();if not IsValid(p) or not p:Alive() or B.Unconscious(p) then close(false) end end
end)
-- Для подсказки шрифты нужны ещё до первого открытия окна.
fonts()
hook.Add('HUDPaint','STB.Hint',function()
 if IsValid(window) then return end
 local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
 local tr=p:GetEyeTrace();if not IsValid(tr.Entity) or tr.HitPos:DistToSqr(p:GetShootPos())>B.Config.Distance^2 then return end
 local mutant=B.Config.Mutants[tr.Entity:GetNW2String('stb_mutant','')];if not mutant then return end
 draw.SimpleText('['..string.upper(input.LookupBinding('+use') or 'E')..'] '..mutant.name..' / одна разделка','STB.Body',ScrW()/2,ScrH()/2+40,C.gold,TEXT_ALIGN_CENTER)
end)
