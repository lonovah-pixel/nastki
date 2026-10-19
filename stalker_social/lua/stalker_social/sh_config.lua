-- STALKER Social: настройки, каталоги нашивок, жестов и поз, общие функции знакомств (оба realm).
-- Все числа меняются без правки Lua: «Комендант» → «Настройки» → «Знакомства и нашивки»
-- (или консоль stalker_setting social.<параметр> <значение>).
local S=STALKER_SOCIAL
local C=STALKER_CORE
S.Version="1.0.0"
S.Config={
 HideNames=true,          -- чужие имена скрыты, пока игроки не познакомились
 AdminsSeeAll=true,       -- администраторы видят настоящие имена
 StrangerName="Незнакомец",
 InteractDistance=120,    -- меню взаимодействия (G), units
 ReplyDistance=300,       -- ответ на рукопожатие: собеседник мог отойти на пару шагов
 PatchDistance=300,       -- нашивки на плече видны не дальше, units
 MaxPatches=3,            -- сколько нашивок игрок показывает одновременно
 MaxTransfer=100000,      -- предел одного денежного перевода (0 — переводы выключены)
 RequestSeconds=30,       -- сколько ждёт ответа протянутая рука и ответное знакомство
 EmoteCooldown=1.5,       -- пауза между жестами, с
 RefreshSeconds=20,       -- пересчёт нашивок по статистике, с
}
local Cfg=S.Config
-- Жёсткие пределы (не настройки): защита базы и сети.
S.MaxKnown=500
S.MaxAwardsShown=8

--[[ Нашивки. Идентификаторы для отображения: faction_<id>, rank_<n>, ach_<id>, award_<id>.
 Выбор игрока хранится «жетонами»: faction и rank — текущие группировка и звание (меняются сами),
 ach_<id> и award_<id> — конкретные нашивки. ]]
S.Achievements={
 {id="hunter",name="Охотник",stat="mutants",goal=50},
 {id="seeker",name="Искатель",stat="artifacts",goal=10},
 {id="survivor",name="Выживший",stat="emissions",goal=10},
 {id="tracker",name="Следопыт",stat="stashes",goal=5},
 {id="veteran",name="Ветеран",stat="kills",goal=50},
 {id="executor",name="Исполнитель",stat="quests",goal=10},
 {id="cook",name="Повар",stat="cooked",goal=20},
 {id="master",name="Мастер",stat="crafted",goal=20},
}
S.AchievementByID={}
for _,a in ipairs(S.Achievements) do S.AchievementByID[a.id]=a end
-- Награды лидера: выдаёт лидер группировки своим членам; действуют, пока награждённый в той же группировке.
S.Awards={
 {id="excellent",name="Отличник службы",desc="Награда командира за безупречную службу."},
 {id="medic",name="Медик отряда",desc="Командир отметил помощь раненым товарищам."},
 {id="scout",name="Разведчик",desc="Командир отметил разведку и добытые сведения."},
 {id="assault",name="Штурмовик",desc="Командир отметил бойца штурмовой группы."},
}
S.AwardByID={}
for _,a in ipairs(S.Awards) do S.AwardByID[a.id]=a end
-- Звания по опыту (STFW.Ranks); без группировок — запасные подписи.
S.RankNames={"Новичок","Опытный","Ветеран","Мастер","Легенда"}
function S.RankName(n)
 local r=STFW and STFW.Ranks and STFW.Ranks[n]
 return r and r[2] or S.RankNames[n] or ("Звание "..tostring(n))
end
function S.RankCount() return STFW and STFW.Ranks and #STFW.Ranks or #S.RankNames end

-- Подписи счётчиков статистики (на клиенте C.StatNames нет — он заполняется на сервере).
S.StatLabels={mutants="Убито мутантов",artifacts="Найдено артефактов",emissions="Пережито выбросов",stashes="Найдено чужих тайников",
 kills="Убито сталкеров",quests="Выполнено заданий",cooked="Приготовлено блюд",crafted="Изготовлено предметов"}
local function statName(key) return C.StatNames and C.StatNames[key] or S.StatLabels[key] or key end
S.StatName=statName
-- Описание нашивки по идентификатору отображения: {kind,name,desc,icon,color}. nil — неизвестная нашивка.
function S.PatchInfo(id)
 if type(id)~="string" then return end
 local kind,rest=id:match("^(%a+)_([%w_]+)$")
 if kind=="faction" then
  if STFW and STFW.Factions and not STFW.Factions[rest] then return end
  return {kind="faction",token="faction",name="Группировка «"..C.FactionName(rest).."»",desc="Эмблема группировки на рукаве.",
   icon="stalker_factions/emblems/"..rest..".png",faction=rest,color=C.FactionColor(rest)}
 elseif kind=="rank" then
  local n=tonumber(rest);if not n or n%1~=0 or n<1 or n>S.RankCount() then return end
  return {kind="rank",token="rank",name="Звание: "..S.RankName(n),desc="Звание сталкера по опыту в Зоне.",icon="stalker_social/patches/rank_"..n..".png",rank=n}
 elseif kind=="ach" then
  local a=S.AchievementByID[rest];if not a then return end
  return {kind="ach",token=id,name=a.name,desc=statName(a.stat)..": "..a.goal,icon="stalker_social/patches/ach_"..a.id..".png",stat=a.stat,goal=a.goal}
 elseif kind=="award" then
  local a=S.AwardByID[rest];if not a then return end
  return {kind="award",token=id,name=a.name,desc=a.desc,icon="stalker_social/patches/award_"..a.id..".png"}
 end
end
-- Допустимые жетоны выбора (faction, rank, ach_<id>, award_<id>).
function S.ValidToken(t)
 if t=="faction" or t=="rank" then return true end
 return type(t)=="string" and S.PatchInfo(t)~=nil and (t:sub(1,4)=="ach_" or t:sub(1,6)=="award_")
end

-- Видимые нашивки игрока: сервер пишет их в NW2 строкой «id,id,id» (видно всем клиентам).
local parsed={}
function S.VisiblePatches(ply)
 if not IsValid(ply) then return {} end
 local raw=ply:GetNW2String("stsoc_patches","")
 if raw=="" then return {} end
 local list=parsed[raw]
 if not list then
  list={}
  for id in raw:gmatch("[^,]+") do if #list<8 and S.PatchInfo(id) then list[#list+1]=id end end
  if table.Count(parsed)>256 then parsed={} end
  parsed[raw]=list
 end
 return list
end
-- Группировка, чья нашивка видна на рукаве (её узнаёт и незнакомец), или nil.
function S.VisibleFaction(ply)
 for _,id in ipairs(S.VisiblePatches(ply)) do local f=id:match("^faction_(.+)$");if f then return f end end
end

--[[ Знакомства. Knows/DisplayName работают в обоих realm: сервер знает всех, клиент — свой список
 (на клиенте viewer — LocalPlayer(); для других зрителей клиент ответа не знает и имя не скрывает). ]]
S.MyKnown=S.MyKnown or {}
-- Знакомы ли без поправок на настройки (для логики знакомства и контактов).
function S.KnowsRaw(viewer,target)
 if not IsValid(viewer) or not IsValid(target) then return false end
 if viewer==target then return true end
 local tsid=C.SID(target);if not tsid then return true end
 if SERVER then local list=S.LoadKnown and S.LoadKnown(viewer);return list~=nil and list[tsid]~=nil end
 if viewer~=LocalPlayer() then return true end
 return S.MyKnown[tsid]~=nil
end
function S.Knows(viewer,target)
 if CLIENT and viewer==nil then viewer=LocalPlayer() end
 if not IsValid(target) or not target:IsPlayer() then return true end
 if not IsValid(viewer) or viewer==target or not Cfg.HideNames then return true end
 if Cfg.AdminsSeeAll and viewer:IsAdmin() then return true end
 return S.KnowsRaw(viewer,target)
end
-- Имя глазами зрителя и видимая группировка (вторым значением).
function S.DisplayName(viewer,target)
 if not IsValid(target) then return "" end
 local faction=S.VisibleFaction(target)
 if S.Knows(viewer,target) then return target:Nick(),faction end
 return Cfg.StrangerName~="" and Cfg.StrangerName or "Незнакомец",faction
end
-- Подпись для HUD и чата: незнакомец с видимой нашивкой группировки — «Незнакомец · Долг».
function S.Label(viewer,target)
 local name,faction=S.DisplayName(viewer,target)
 if faction and not S.Knows(viewer,target) then return name.." · "..C.FactionName(faction) end
 return name
end

--[[ Жесты: ACT_* задаются именем, чтобы аддон не падал, если константы нет в этой версии игры. ]]
S.Gestures={
 {id="wave",name="Помахать",act="ACT_GMOD_GESTURE_WAVE"},
 {id="salute",name="Отдать честь",act="ACT_GMOD_TAUNT_SALUTE"},
 {id="agree",name="Согласие",act="ACT_GMOD_GESTURE_AGREE"},
 {id="disagree",name="Несогласие",act="ACT_GMOD_GESTURE_DISAGREE"},
 {id="becon",name="Подозвать",act="ACT_GMOD_GESTURE_BECON"},
 {id="halt",name="Стоп",act="ACT_SIGNAL_HALT"},
 {id="forward",name="Вперёд",act="ACT_SIGNAL_FORWARD"},
 {id="group",name="Сбор",act="ACT_SIGNAL_GROUP"},
 {id="laugh",name="Смех",act="ACT_GMOD_TAUNT_LAUGH"},
 {id="bow",name="Поклон",act="ACT_GMOD_GESTURE_BOW"},
 {id="dance",name="Танец",act="ACT_GMOD_TAUNT_DANCE"},
}
S.GestureByID={}
for _,g in ipairs(S.Gestures) do S.GestureByID[g.id]=g end
function S.Act(name) local v=_G[name];if type(v)=="number" then return v end end
-- Позы с циклом. seq — последовательности моделей игроков (первая найденная), иначе fallback-активность;
-- bones — повороты костей ValveBiped (сервер ставит ManipulateBoneAngles, клиенты получают их сами).
S.Poses={
 {id="sit",name="Сидеть",seq={"sit_zen","sit_ground"},fallback="ACT_MP_CROUCH_IDLE"},
 {id="surrender",name="Руки вверх",bones={
  ["ValveBiped.Bip01_L_UpperArm"]={-77,-46,4},["ValveBiped.Bip01_L_Forearm"]={-28,-29,44},["ValveBiped.Bip01_L_Hand"]={-12,12,90},
  ["ValveBiped.Bip01_R_UpperArm"]={73,35,128},["ValveBiped.Bip01_R_Forearm"]={-22,1,15},["ValveBiped.Bip01_R_Hand"]={33,39,-21}}},
 {id="crossarms",name="Скрестить руки",bones={
  ["ValveBiped.Bip01_R_UpperArm"]={20,-57,-6},["ValveBiped.Bip01_R_Forearm"]={-44,-107,16},["ValveBiped.Bip01_R_Hand"]={14,-33,-7},
  ["ValveBiped.Bip01_L_UpperArm"]={-29,-59,1},["ValveBiped.Bip01_L_Forearm"]={51,-120,-19},["ValveBiped.Bip01_L_Hand"]={26,32,-15}}},
 {id="kneel",name="Присесть на колено",seq={"pose_ducking_01","pose_ducking_02"},fallback="ACT_MP_CROUCH_IDLE"},
}
S.PoseByID={}
for _,p in ipairs(S.Poses) do S.PoseByID[p.id]=p end
function S.GetPose(ply) return IsValid(ply) and ply:GetNW2String("stsoc_pose","") or "" end

-- Деньги: формат DarkRP, если он есть.
function S.Money(n)
 if DarkRP and DarkRP.formatMoney then return DarkRP.formatMoney(n) end
 return (string.Comma and string.Comma(n) or tostring(n)).." ₽"
end

--[[ Настройки (категория «Знакомства и нашивки») ]]
local SET=STALKER_SETTINGS
local CAT="Знакомства и нашивки"
local function bind(id,tbl,key,def)
 def.category=CAT;def.type=def.type or "number";def.realm=def.realm or "shared"
 SET.Bind("social."..id,tbl,key,def)
end
bind("hide_names",Cfg,"HideNames",{label="Скрывать имена незнакомцев",type="bool",order=1,
 description="Над головой и в локальном чате вместо имени — «Незнакомец» (и видимая нашивка группировки), пока игроки не представились друг другу."})
bind("admins_see_all",Cfg,"AdminsSeeAll",{label="Администраторы видят настоящие имена",type="bool",order=2})
bind("stranger_name",Cfg,"StrangerName",{label="Как называть незнакомца",type="string",maxLength=32,order=3})
bind("interact_distance",Cfg,"InteractDistance",{label="Дистанция взаимодействия (G), units",min=60,max=400,order=4})
bind("reply_distance",Cfg,"ReplyDistance",{label="Дистанция ответа на рукопожатие, units",min=100,max=1000,order=5,realm="server"})
bind("request_seconds",Cfg,"RequestSeconds",{label="Ожидание ответа на рукопожатие, с",min=5,max=120,order=6})
bind("patch_distance",Cfg,"PatchDistance",{label="Нашивки на плече видны с расстояния, units",min=100,max=2000,order=7})
bind("max_patches",Cfg,"MaxPatches",{label="Максимум видимых нашивок",min=1,max=5,order=8})
bind("max_transfer",Cfg,"MaxTransfer",{label="Предел денежного перевода, ₽ (0 — выключено)",min=0,max=10000000,step=100,order=9})
bind("emote_cooldown",Cfg,"EmoteCooldown",{label="Пауза между жестами, с",min=0,max=10,step=.5,decimals=1,order=10,realm="server"})
for i,a in ipairs(S.Achievements) do
 bind("ach_"..a.id,a,"goal",{label="Нашивка «"..a.name.."»: "..statName(a.stat),min=1,max=100000,order=20+i})
end
