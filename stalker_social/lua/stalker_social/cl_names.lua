-- STALKER Social: имя незнакомца над головой и в локальном чате DarkRP.
-- Над головой: обёртка над plyMeta.drawPlayerInfo/drawWantedInfo DarkRP (modules/hud/cl_hud.lua) — на время
-- отрисовки Nick() цели возвращает «Незнакомец · <группировка>», остальное (здоровье, профессия) рисует DarkRP.
-- Чат: DarkRP шлёт DarkRP_Chat с префиксом (пусто — обычная речь, «(Шёпот) Имя», «(Крик) Имя», «Имя действие» для /me),
-- клиент зовёт OnPlayerChat (или ChatText для /me). Подменяем только эти локальные IC-сообщения:
-- OOC, PM, группа, объявления и сообщения администрации не трогаем.
local S=STALKER_SOCIAL
local T=STALKER_THEME
local meta=FindMetaTable("Player")

-- Нужно ли скрывать имя этого игрока от меня.
function S.Hidden(ply)
 local me=LocalPlayer()
 return IsValid(ply) and ply:IsPlayer() and ply~=me and not S.Knows(me,ply)
end

--[[ Над головой ]]
local nameKeys={"Nick","Name","GetName"}
function S.WithStrangerName(ply,fn,...)
 if not S.Hidden(ply) then return fn(...) end
 local label=S.Label(LocalPlayer(),ply)
 local saved={}
 for _,k in ipairs(nameKeys) do
  local orig=meta[k];saved[k]=orig
  if orig then meta[k]=function(p,...) if p==ply then return label end;return orig(p,...) end end
 end
 local ok,err=pcall(fn,...)
 for _,k in ipairs(nameKeys) do meta[k]=saved[k] end
 if not ok then ErrorNoHalt("[STALKER Social] "..tostring(err).."\n") end
end
S.Wrapped=S.Wrapped or {}
-- Ставится после загрузки режима: DarkRP объявляет функции как plyMeta.x = plyMeta.x or function, и обёртка
-- из autorun (он грузится раньше режима) отменила бы стандартную отрисовку.
function S.InstallNameHooks()
 for _,key in ipairs({"drawPlayerInfo","drawWantedInfo"}) do
  local current=meta[key]
  if type(current)=="function" and current~=S.Wrapped[key] then
   local orig=current
   local wrapped=function(self,...) return S.WithStrangerName(self,orig,self,...) end
   S.Wrapped[key]=wrapped;meta[key]=wrapped
  end
 end
end
hook.Add("Initialize","STALKER_SOCIAL.Names",S.InstallNameHooks)
hook.Add("InitPostEntity","STALKER_SOCIAL.Names",S.InstallNameHooks)

--[[ Чат ]]
local function phrase(key)
 if DarkRP and DarkRP.getPhrase then local ok,v=pcall(DarkRP.getPhrase,key);if ok and type(v)=="string" and v~="" then return v end end
end
-- Новый префикс для локальной речи или nil, если сообщение не локальное (OOC, PM, группа…).
function S.ChatPrefix(ply,prefix)
 local nick=ply:Nick();local label=S.Label(LocalPlayer(),ply)
 if prefix==nil or prefix=="" or prefix==nick then return label end
 for _,key in ipairs({"whisper","yell"}) do
  local p=phrase(key)
  if p and prefix=="("..p..") "..nick then return "("..p..") "..label end
 end
end
hook.Add("OnPlayerChat","STALKER_SOCIAL.Chat",function(ply,text,teamChat,dead,prefix,col1,col2)
 if not S.Hidden(ply) or teamChat then return end
 local newPrefix=S.ChatPrefix(ply,prefix);if not newPrefix then return end
 local nameCol=col1 or team.GetColor(ply:Team())
 local textCol=col2 or T.C.text
 if prefix==nil and not DarkRP then
  -- Базовый режим GMod: повторяем его формат (*DEAD* Имя: текст).
  if dead then chat.AddText(T.C.danger,"*DEAD* ",nameCol,newPrefix,textCol,": "..tostring(text)) else chat.AddText(nameCol,newPrefix,textCol,": "..tostring(text)) end
  return true
 end
 chat.AddNonParsedText(nameCol,newPrefix,textCol,": "..tostring(text))
 return true
end)
-- /me DarkRP приходит без отправителя: «Имя действие». Ищем самое длинное имя скрытого игрока в начале строки.
function S.MeLine(text)
 if type(text)~="string" then return end
 local best,bestLen
 for _,p in ipairs(player.GetAll()) do
  if S.Hidden(p) then
   local nick=p:Nick()
   if nick~="" and text:sub(1,#nick+1)==nick.." " and (not bestLen or #nick>bestLen) then best,bestLen=p,#nick end
  end
 end
 if best then return best,S.Label(LocalPlayer(),best)..text:sub(bestLen+1) end
end
hook.Add("ChatText","STALKER_SOCIAL.Me",function(_,_,text,kind)
 if kind~="darkrp" then return end
 local ply,line=S.MeLine(text);if not ply then return end
 chat.AddNonParsedText(team.GetColor(ply:Team()),line)
 return true
end)
