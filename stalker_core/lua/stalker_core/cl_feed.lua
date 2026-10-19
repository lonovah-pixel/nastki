-- Уведомления КПК, лента новостей, полоса «удерживайте E» и запрос статистики.
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
C.NewsFeed=C.NewsFeed or {}
C.Toasts=C.Toasts or {}
local kinds={info="info",ok="ok",warn="warn",danger="danger",emission="danger",event="accent",war="danger",capture="accent",quest="accent2",trade="ok"}
local titles={info="КПК",ok="КПК",warn="ВНИМАНИЕ",danger="ОПАСНОСТЬ",emission="ВЫБРОС",event="СОБЫТИЕ",war="ВОЙНА",capture="ТЕРРИТОРИЯ",quest="ЗАДАНИЕ",trade="ТОРГОВЛЯ"}

function C.Toast(text,kind,seconds)
 table.insert(C.Toasts,{text=text,kind=kind or "info",ends=CurTime()+(seconds or 6),start=CurTime()})
 while #C.Toasts>5 do table.remove(C.Toasts,1) end
 surface.PlaySound("buttons/button17.wav")
end
net.Receive("stalker_core.notify",function(len)
 local d=C.Read(len);if d and type(d.text)=="string" then C.Toast(d.text,d.kind,d.seconds) end
end)
net.Receive("stalker_core.news",function(len)
 local d=C.Read(len);if not d then return end
 local items=d.items or {}
 -- История приходит при входе и ещё раз, когда клиент загрузился (первая могла потеряться): уже известные записи пропускаем.
 local have={};if d.history then for _,e in ipairs(C.NewsFeed) do have[tostring(e.t).."|"..tostring(e.text)]=true end end
 for i=#items,1,-1 do
  local e=items[i]
  if type(e)=="table" and not have[tostring(e.t).."|"..tostring(e.text)] then
   table.insert(C.NewsFeed,1,e)
   if not d.history and C.Config.NewsToast~=false then C.Toast(e.text,e.kind,7) end
  end
 end
 while #C.NewsFeed>60 do table.remove(C.NewsFeed) end
 hook.Run("STALKER_NewsUpdated",C.NewsFeed)
end)

hook.Add("HUDPaint","STALKER_Core.Toasts",function()
 local now=CurTime();local px=T.Px
 for i=#C.Toasts,1,-1 do if C.Toasts[i].ends<now then table.remove(C.Toasts,i) end end
 local w=px(340);local x=ScrW()-w-px(24);local y=ScrH()*.30
 for _,t in ipairs(C.Toasts) do
  local lines=U.Wrap(t.text,"STALKER.Small",w-px(20))
  local h=px(26)+math.min(3,#lines)*px(16)
  local alpha=math.Clamp(math.min(now-t.start,t.ends-now)*4,0,1)
  local slide=(1-math.Clamp((now-t.start)*5,0,1))*px(40)
  surface.SetAlphaMultiplier(alpha)
  U.Panel("",x+slide,y,w,h,true)
  local col=T.C[kinds[t.kind] or "info"] or T.C.info
  surface.SetDrawColor(col);surface.DrawRect(x+slide,y,px(3),h)
  draw.SimpleText(titles[t.kind] or "КПК","STALKER.Mono",x+slide+px(10),y+px(5),col)
  for j=1,math.min(3,#lines) do draw.SimpleText(lines[j],"STALKER.Small",x+slide+px(10),y+px(6)+j*px(16),T.C.text) end
  surface.SetAlphaMultiplier(1)
  y=y+h+px(6)
 end
end)

-- Полоса удержания E (данные — из сетевых переменных сервера).
hook.Add("HUDPaint","STALKER_Core.Hold",function()
 local ply=LocalPlayer();if not IsValid(ply) then return end
 local ends=ply:GetNW2Float("stc_hold_end",0);if ends<=CurTime() then return end
 local start=ply:GetNW2Float("stc_hold_start",0);local px=T.Px
 local ratio=math.Clamp((CurTime()-start)/math.max(.01,ends-start),0,1)
 local w,h=px(300),px(44);local x,y=ScrW()/2-w/2,ScrH()*.62
 U.Panel("",x,y,w,h,true)
 draw.SimpleText(ply:GetNW2String("stc_hold_label",""),"STALKER.Small",x+px(10),y+px(6),T.C.text)
 draw.SimpleText(string.format("%.1f с",math.max(0,ends-CurTime())),"STALKER.Mono",x+w-px(10),y+px(6),T.C.muted,TEXT_ALIGN_RIGHT)
 U.Bar(x+px(10),y+px(26),w-px(20),px(8),ratio,T.C.accent)
end)

-- Статистика: C.RequestStats("mutants", function(data) ... end) — свои счётчики и топ по ключу.
function C.RequestStats(top,cb) C.StatsCallback=cb;C.Send("stalker_core.stats",nil,{top=top}) end
net.Receive("stalker_core.stats",function(len)
 local d=C.Read(len);if not d then return end
 C.MyStats=d.mine;C.StatNames=d.names or C.StatNames
 if C.StatsCallback then local cb=C.StatsCallback;C.StatsCallback=nil;cb(d) end
 hook.Run("STALKER_StatsUpdated",d)
end)
