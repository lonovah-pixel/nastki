-- Ревью ядра и КПК: распаковка с пределом, досылка данных загрузившемуся клиенту, поле hud у меток, топ статистики,
-- превью сообщений и U.Fit без квадратичного utf8.sub GMod, сообщения КПК без сознания, повтор истории новостей.
-- Область мира: X 10 000 000…10 400 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local C,P,MK,S=STALKER_CORE,STALKER_PDA,STALKER_MARKERS,STALKER_SETTINGS
local X=10000000

local function lastTo(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function allTo(name,to)
 local out={};for _,s in ipairs(M.netSent or {}) do if s.name==name and (to==nil or s.to==to) then out[#out+1]=s end end;return out
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end
-- Счётчик вызовов utf8.sub: в GMod он O(n²) на вызов (includes/modules/utf8.lua: sub → GetChar → len + offset на каждый символ).
local function countSub(fn,...)
 local real,n=utf8.sub,0
 utf8.sub=function(...) n=n+1;return real(...) end
 local ok,a,b=pcall(fn,...)
 utf8.sub=real
 return n,ok,a,b
end

section("Ревью ядра и КПК ("..M.Realm..")")
-- C.Read: предел распаковки передаётся в util.Decompress (иначе LZMA-бомба в 8 КБ разворачивается в десятки МБ).
do
 -- «Бомба» — 4 байта, которые разворачиваются в 2 МБ (как LZMA из нулей); подмена ведёт себя как util.Decompress GMod с maxSize.
 local realDec=util.Decompress;local asked
 util.Decompress=function(s,max)
  asked=max;local out=s=="BOMB" and string.rep("a",2000000) or realDec(s)
  if out and max and #out>max then return nil end;return out
 end
 local data=C.Pack({op="inbox"})
 M.netRead={#data,data};local okRead=C.Read(16+#data*8,8000)
 asked=nil;M.netRead={4,"BOMB"};local bad=C.Read(16+4*8,8000)
 util.Decompress=realDec;M.netRead=nil
 check(okRead and okRead.op=="inbox","обычный пакет читается")
 check(type(asked)=="number" and asked<=1000000,"C.Read передаёт предел распаковки в util.Decompress: "..tostring(asked))
 check(bad==nil,"слишком большой распакованный пакет отклонён")
end
-- Эталон: первые n символов UTF-8.
local function head(text,n) local out,k={},0;for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do k=k+1;if k>n then break end;out[k]=ch end;return table.concat(out) end
check(type(P.Head)=="function" and P.Head("абвгд",3)=="абв" and P.Head("abc",5)=="abc" and P.Head("",3)=="" and P.Head(string.rep("я",100),90)==string.rep("я",90),
 "P.Head: первые n символов UTF-8")

if SERVER then
 local function req(name,ply,tbl) local l,v=packet(tbl);return M.netReceive(name,l,ply,v) end
 local function cmd(forced) return {IsForced=function() return forced end,KeyDown=function() return false end,GetForwardMove=function() return 0 end,
  GetSideMove=function() return 0 end,RemoveKey=function() end,ClearButtons=function() end,ClearMovement=function() end,SetImpulse=function() end} end

 section("Ревью: метки — поле hud")
 local a=TEST.join({nick="Ревью А",pos=Vector(X,0,0)})
 MK.Set("rv.maponly",{pos=Vector(X+100,0,0),label="Только карта",kind="poi",hud=false})
 MK.Set("rv.plain",{pos=Vector(X+200,0,0),label="Обычная",kind="poi"})
 M.netSent={};MK.SyncPlayer(a,true)
 local list=(decode(lastTo("stalker_markers.sync",a)) or {}).list or {}
 local rows={};for _,m in ipairs(list) do rows[m.id]=m end
 check(rows["rv.maponly"] and rows["rv.maponly"].hud==false,"hud=false доходит до клиента (метка только на карте)")
 check(rows["rv.plain"] and rows["rv.plain"].hud==nil,"без hud — поле не передаётся (совместимость)")
 MK.Clear("rv.")

 section("Ревью: досылка данных загрузившемуся клиенту")
 local sidB="76561198090000001"
 check(P.SystemMessage(sidB,"Офлайн-весточка для ревью",{key="rv",name="Ревью"}),"служебное сообщение офлайн-адресату")
 MK.Set("rv.ready",{pos=Vector(X+300,0,0),label="Для входа",kind="poi"})
 local b=TEST.join({nick="Ревью Б",pos=Vector(X+500,0,0),sid=sidB})
 M.netSent={}
 hook.Run("StartCommand",b,cmd(true))
 check(#allTo("stalker_settings.sync",b)==0 and #allTo("stalker_markers.sync",b)==0,"повторённая сервером команда (клиент ещё грузится) ничего не досылает")
 hook.Run("StartCommand",b,cmd(false))
 check(lastTo("stalker_settings.sync",b)~=nil,"настройки досланы загрузившемуся клиенту")
 local mk=decode(lastTo("stalker_markers.sync",b));local hasReady=false
 for _,m in ipairs(mk and mk.list or {}) do if m.id=="rv.ready" then hasReady=true end end
 check(hasReady,"снимок меток дослан (иначе до изменения меток не повторится)")
 local hist=decode(lastTo("stalker_core.news",b))
 check(hist and hist.history==true,"история новостей дослана")
 local un=decode(lastTo("stalker_pda.data",b))
 check(un and un.kind=="unread" and un.n==1,"значок непрочитанных КПК дослан: "..tostring(un and un.n))
 local note=decode(lastTo("stalker_core.notify",b))
 check(note and tostring(note.text):find("Непрочитанных сообщений в КПК: 1",1,true),"уведомление об офлайн-сообщениях дослано")
 M.netSent={}
 hook.Run("StartCommand",b,cmd(false))
 check(#allTo("stalker_settings.sync",b)==0 and #allTo("stalker_core.news",b)==0,"досылка — один раз за вход")
 M.advance(3)
 local dup=0;for _,x in ipairs(allTo("stalker_core.notify",b)) do local d=decode(x);if d and tostring(d.text):find("Непрочитанных сообщений",1,true) then dup=dup+1 end end
 check(dup==0,"запасной таймер КПК не дублирует уведомление")
 MK.Clear("rv.")

 section("Ревью: превью переписки без utf8.sub")
 local long=string.rep("Привет сталкер ",20)
 local okLong=P.SendMessage(a,sidB,long)
 check(okLong,"длинное сообщение отправлено")
 local n,okInbox,inbox=countSub(P.Inbox,b)
 local conv;for _,c in ipairs(okInbox and inbox or {}) do if c.sid==a:SteamID64() then conv=c end end
 check(conv and conv.last==head(long,90) and utf8.len(conv.last)==90,"превью — первые 90 символов")
 check(n==0,"список переписок собирается без utf8.sub (O(n²) в GMod): вызовов "..n)

 section("Ревью: сообщения КПК без сознания")
 M.advance(2.1)
 a:SetNW2Float("stem_unconscious_until",CurTime()+60)
 local okU,errU=P.SendMessage(a,sidB,"пишу из обморока")
 a:SetNW2Float("stem_unconscious_until",0)
 check(not okU and tostring(errU):find("без сознания",1,true),"без сознания сообщение не уходит: "..tostring(errU))

 section("Ревью: топ статистики")
 sql.Query("WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<2000) "..
  "INSERT OR IGNORE INTO stalker_stats (sid,payload) SELECT 'rvfake'||i,'{\"kills\":5}' FROM n")
 check((tonumber(sql.QueryValue("SELECT COUNT(*) FROM stalker_stats WHERE sid LIKE 'rvfake%'")) or 0)==2000,"2000 старых профилей в базе")
 C.AddStat(a,"kills",100000)
 if C.StatTop then C.StatTop.kills=nil end
 M.netSent={};a.StalkerRate=nil
 req("stalker_core.stats",a,{top="kills"})
 local top=decode(lastTo("stalker_core.stats",a))
 local first=top and top.top and top.top.list and top.top.list[1]
 check(first and first.sid==a:SteamID64() and first.value==100000,"активный игрок попадает в топ при большой базе: "..tostring(first and first.sid))
 local realQuery,scans=sql.Query,0
 sql.Query=function(q) if tostring(q):find("FROM stalker_stats",1,true) then scans=scans+1 end;return realQuery(q) end
 a.StalkerRate=nil;M.netSent={}
 req("stalker_core.stats",a,{top="kills"})
 sql.Query=realQuery
 local again=decode(lastTo("stalker_core.stats",a))
 check(again and again.top and again.top.list[1].sid==a:SteamID64() and again.mine.kills==100000,"повторный запрос: топ и свои счётчики")
 check(scans==0,"топ не пересчитывается на каждый запрос: чтений базы "..scans)
 sql.Query("DELETE FROM stalker_stats WHERE sid LIKE 'rvfake%'")
 if C.StatTop then C.StatTop={} end
 for _,p in ipairs({a,b}) do hook.Run("PlayerDisconnected",p);M.removePlayer(p) end
else
 section("Ревью: U.Fit без квадратичного utf8.sub")
 local U=STALKER_STYLE
 local realSize,calls=surface.GetTextSize,0
 surface.GetTextSize=function(s) calls=calls+1;return utf8.len(s)*7,10 end
 local function reference(text,width)
  if utf8.len(text)*7<=width then return text end
  local chars={};for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars+1]=ch end
  for i=#chars,1,-1 do local s=table.concat(chars,"",1,i).."…";if utf8.len(s)*7<=width then return s end end
  return "…"
 end
 local text=string.rep("Тайник ",30)
 local n,ok,res=countSub(U.Fit,text,"STALKER.Small",100)
 local fitCalls=calls
 check(ok and res==reference(text,100),"U.Fit обрезает как раньше: "..tostring(res))
 check(n==0,"U.Fit не зовёт utf8.sub (O(n²) в GMod, а в Paint — каждый кадр): вызовов "..n)
 check(fitCalls<=12,"U.Fit измеряет текст O(log n) раз: "..fitCalls)
 check(U.Fit("Коротко","STALKER.Small",1000)=="Коротко" and U.Fit(text,"STALKER.Small",3)=="…" and U.Fit("abcdef","STALKER.Small",30)==reference("abcdef",30),
  "короткий текст без изменений, узкое поле — многоточие")
 surface.GetTextSize=realSize

 section("Ревью: история новостей приходит один раз")
 local l,v=packet({items={{t=1700000000,text="РВ: выброс прошёл",kind="emission"},{t=1700000001,text="РВ: торговец вернулся",kind="trade"}},history=true})
 M.netReceive("stalker_core.news",l,nil,v)
 l,v=packet({items={{t=1700000000,text="РВ: выброс прошёл",kind="emission"},{t=1700000001,text="РВ: торговец вернулся",kind="trade"}},history=true})
 M.netReceive("stalker_core.news",l,nil,v)
 local copies=0;for _,e in ipairs(C.NewsFeed) do if e.text=="РВ: выброс прошёл" then copies=copies+1 end end
 check(copies==1,"повторная история (вход + загрузка клиента) не дублирует ленту: "..copies)

 section("Ревью: превью сообщения на клиенте")
 local long=string.rep("Привет сталкер ",20)
 local nSub=countSub(P.HandleData,{kind="msg",msg={id=901,from="76561198090000077",to="1",text=long,t=os.time()},name="Ревью",unread=1})
 local conv=P.FindConversation("76561198090000077")
 check(conv and conv.last==head(long,90),"превью нового сообщения — 90 символов")
 check(nSub==0,"превью без utf8.sub: вызовов "..nSub)
 for i,c in ipairs(P.Inbox) do if c.sid=="76561198090000077" then table.remove(P.Inbox,i);break end end
end
