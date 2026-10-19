-- STALKER PDA: настройки и общие помощники (оба realm). Числа и флаги — в реестре «Коменданта», категория «КПК».
local P=STALKER_PDA
P.Config=P.Config or {}
local cfg=P.Config
local defaults={
 MessageLength=300,     -- максимум символов в сообщении (UTF-8, а не байты)
 MessageDays=30,        -- сколько дней хранить переписку
 MessageInterval=2,     -- пауза между отправками одного игрока, с
 UnreadLimit=50,        -- столько непрочитанных от одного отправителя — дальше адресат «заглушён» до прочтения
 HistoryLimit=80,       -- сколько последних сообщений переписки загружается в КПК
 MessageToast=true,     -- всплывающее уведомление о новом сообщении
 F4Key=true,            -- F4 открывает КПК (меню F4 DarkRP отключено)
 EmissionForecast=true, -- прогноз выброса в сводке (время следующего выброса известно клиенту и так)
 WaypointReach=150,     -- на таком расстоянии (units) своя метка снимается автоматически
 RulesLink="",          -- ссылка на правила/Discord сервера в «Справочнике»
 -- Подложка карты КПК (вид сверху, север +Y вверху): материал и границы мира, которые охватывает картинка.
 -- Пример: MapMaterials={rp_zone="stalker_pda/maps/rp_zone.png"}, MapBounds={rp_zone={x1=-15000,y1=-15000,x2=15000,y2=15000}}.
 -- Можно задать и в STALKER_INV.Config (MapMaterials + MapBounds) — тогда карта общая с картой тайников.
 MapMaterials={},
 MapBounds={},
}
for k,v in pairs(defaults) do if cfg[k]==nil then cfg[k]=v end end

local S=STALKER_SETTINGS
if S and S.Bind then
 local cat="КПК"
 S.Bind("pda.message_length",cfg,"MessageLength",{category=cat,label="Длина сообщения, символов",type="number",min=20,max=1000,realm="shared",order=1,
  description="Максимальная длина личного сообщения КПК."})
 S.Bind("pda.message_days",cfg,"MessageDays",{category=cat,label="Хранить сообщения, дней",type="number",min=1,max=365,realm="shared",order=2,
  description="Старые сообщения удаляются из базы раз в час."})
 S.Bind("pda.message_interval",cfg,"MessageInterval",{category=cat,label="Пауза между сообщениями, с",type="number",min=0,max=120,step=.5,decimals=1,realm="shared",order=3,
  description="Частота отправки: не чаще одного сообщения за это время."})
 S.Bind("pda.unread_limit",cfg,"UnreadLimit",{category=cat,label="Непрочитанных от одного отправителя",type="number",min=5,max=1000,order=4,
  description="Защита от спама: пока адресат не прочитает, больше сообщений от этого игрока не принимается."})
 S.Bind("pda.history_limit",cfg,"HistoryLimit",{category=cat,label="Сообщений в открытой переписке",type="number",min=10,max=200,order=5})
 S.Bind("pda.message_toast",cfg,"MessageToast",{category=cat,label="Уведомлять о новых сообщениях",type="bool",realm="shared",order=6})
 S.Bind("pda.f4",cfg,"F4Key",{category=cat,label="Открывать КПК клавишей F4",type="bool",realm="shared",order=7})
 S.Bind("pda.emission_forecast",cfg,"EmissionForecast",{category=cat,label="Прогноз выброса в сводке",type="bool",realm="shared",order=8})
 S.Bind("pda.waypoint_reach",cfg,"WaypointReach",{category=cat,label="Снимать свою метку на расстоянии, units",type="number",min=0,max=2000,realm="shared",order=9,
  description="0 — метка остаётся, пока игрок не уберёт её сам."})
 S.Bind("pda.rules_link",cfg,"RulesLink",{category=cat,label="Ссылка на правила сервера",type="string",realm="shared",order=10,
  description="Показывается в разделе «Правила» справочника (сайт, Discord)."})
end

-- Текст сообщения: управляющие символы → пробелы, края обрезаются. nil и ключ ошибки — пусто, длинно или битый UTF-8.
function P.CleanText(text,limit)
 if type(text)~="string" then return nil,"empty" end
 limit=limit or cfg.MessageLength
 if #text>limit*4+64 then return nil,"long" end
 text=text:gsub("[%c]"," "):gsub("^%s+",""):gsub("%s+$","")
 if text=="" then return nil,"empty" end
 local n=utf8.len(text)
 if not n then return nil,"encoding" end
 if n>limit then return nil,"long" end
 return text
end
P.TextErrors={empty="Пустое сообщение",long="Слишком длинное сообщение",encoding="Недопустимые символы в сообщении"}
-- Первые n символов UTF-8 за один проход. utf8.sub GMod для каждого символа пересчитывает всю строку (O(n²)):
-- список из 80 переписок с длинными сообщениями собирался на сервере больше полсекунды.
function P.Head(text,n)
 text=tostring(text or "");if #text<=n then return text end
 local count=0
 for at in text:gmatch("()[%z\1-\127\194-\244][\128-\191]*") do
  count=count+1;if count>n then return text:sub(1,at-1) end
 end
 return text
end

-- SteamID64 собеседника или служебный отправитель «sys.<ключ>» (торговцы, задания, события).
function P.ValidSID(sid) return type(sid)=="string" and #sid>=5 and #sid<=20 and sid:match("^%d+$")~=nil end
function P.IsSystem(sid) return type(sid)=="string" and sid:match("^sys%.[%w_]+$")~=nil and #sid<=40 end

-- Имя собеседника, как его видит viewer: модуль знакомств может скрывать имена незнакомцев.
function P.NameFor(viewer,target)
 if not IsValid(target) then return end
 local Soc=STALKER_SOCIAL
 if Soc and Soc.DisplayName then
  local ok,name=pcall(Soc.DisplayName,viewer,target)
  if ok and type(name)=="string" and name~="" then return name end
 end
 return target:Nick()
end

-- Нижний регистр с кириллицей (string.lower GMod меняет только латиницу) — для поиска в справочнике.
function P.Lower(s)
 s=string.lower(tostring(s or ""))
 s=s:gsub("\208([\144-\159])",function(c) return "\208"..string.char(c:byte()+32) end)
 s=s:gsub("\208([\160-\175])",function(c) return "\209"..string.char(c:byte()-32) end)
 return (s:gsub("\208\129","\209\145"))
end
