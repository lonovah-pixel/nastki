-- Памятка сталкера: окно (первый вход, !help, stz_help), вкладка КПК «Памятка», раздел «Зона» справочника КПК
-- и список сталкеров онлайн во вкладке PDA инвентаря. Всё оформление — тема STALKER_THEME.
local Z=STALKER_ZONE
local function px(n) local T=STALKER_THEME;return T and T.Px and T.Px(n) or math.Round(n) end
local function minutes(sec) return math.max(1,math.floor((tonumber(sec) or 600)/60+.5)) end

--[[ Содержимое. Строка — абзац, функция — абзац с числами из настроек, {"Клавиша","что делает"} — строка таблицы. ]]
Z.Help={
 {"Клавиши и команды",{
  {"TAB","Инвентарь: рюкзак, экипировка, быстрые слоты, тайники"},
  {"F4 / !кпк","КПК: сводка, карта с метками, сообщения, задания, события, справочник и эта памятка"},
  {"E","Торговцы, вербовщики и квестодатели, подбор предметов, обыск сумок"},
  {"Удерживать E","Захват флага территории, вскрытие груза, обыск тайника по наводке"},
  {"G","Смотрите на игрока: представиться, передать деньги или предмет, обыскать"},
  {"H / !emote","Жесты и позы: помахать, отдать честь, сесть у костра"},
  {"F6","Группировки: территории, отношения, звание; лидер — «Командование»"},
  {"ALT + 1–9","Быстрые слоты"},
  {"F1","Справка DarkRP и чат-команды"},
  {"!help","Эта памятка (или КПК → «Памятка»)"},
 }},
 {"Как выжить",{
  function() local s=Z.Config.Survival;return "Голод и жажда на нуле отнимают здоровье — носите еду и воду. После возрождения сытость и вода не ниже "..tostring(s.RespawnMinimum).."%." end,
  "Радиация копится в радиационных зонах и от фонящих артефактов. Антирад, водка, научная аптечка и артефакт «Пузырь» снижают дозу; костюм и противогаз защищают.",
  "Выброс: услышав сирену, бегите под крышу. На пике незащищённых сталкеров валит с ног; после выброса аномалии смещаются.",
  "Аномалии выдают себя искажением воздуха, искрами, пламенем, пылью или зелёным паром. Обходите их.",
  "Броня, шлем и обувь изнашиваются от попаданий: защита падает до половины номинала. Состояние — в карточке предмета.",
 }},
 {"Заработок",{
  "Артефакты лежат у аномалий и видны только с детектором в рюкзаке. Детектор пищит чаще, когда артефакт рядом.",
  "Мутантов разделывают монтировкой (E по туше) и продают части торговцам. Добыча, не влезшая в рюкзак: stb_claim.",
  "Торговцы скупают хабар; учёные и экологи платят за артефакты больше. Торговцы, вербовщики, поля аномалий и логова мутантов отмечены на карте КПК.",
  "Крафт: вещи собираются по рецептам из деталей, хабара и трофеев мутантов; детали дают разборкой (ПКМ по предмету → «Разобрать»).",
  "Готовка: сырое мясо мутантов готовят у огня — у костра можно присесть (H → «Сидеть»). За изделия и блюда дают нашивки «Мастер» и «Повар».",
 }},
 {"Задания и события",{
  "Квестодатели — Бармен, Профессор, Охотник и Связной: подойдите и нажмите E. Журнал — F4 → «Задания» или !quests.",
  "«Путь новичка» проведёт по первым шагам в Зоне. Скрыть подсказки линии: stq_guideline 0 в консоли.",
  "События — сбитый груз, гон мутантов, артефактный шторм, военный рейд, охота за головой — объявляются в новостях КПК; идущие события — КПК → «События».",
  "Маячок покупается у торговцев и ставится из инвентаря («Использовать»): метка видна вам или всей группировке.",
 }},
 {"Группировки",{
  "Вступление — у вербовщика группировки (E) или по приглашению лидера. Профессия группировки выдаётся сама при вступлении; меню профессий F4 отключено.",
  "Территории захватывают, удерживая E на флаге точки. Они пополняют казну и очки снабжения группировки.",
  "Казна, приглашения и способности — F6 → «Командование» (лидер и офицеры, !leader). Сводка группировки — КПК → «Группировка».",
  "Имя незнакомца скрыто, пока он не представится (G). Нашивки — КПК → «Нашивки».",
 }},
 {"Смерть и тайники",{
  function() return "Экипировка остаётся при вас, содержимое рюкзака падает в сумке на месте гибели и лежит "..minutes(Z.Config.DeathDrop.Lifetime).." мин." end,
  "В сумке погибшего бывают записи КПК: обыскавший её получает наводку на тайник погибшего — метку на карте и во вкладке КПК «Тайники».",
  "Свои тайники: TAB → «Тайники» или !stash. У тайника по наводке удерживайте E, чтобы обыскать его.",
  "Запас патронов сохраняется при выходе с сервера, но не при смерти.",
 }},
}

local function lineText(line)
 if type(line)=="function" then local ok,res=pcall(line);return ok and tostring(res) or "" end
 return tostring(line)
end

-- Строка «клавиша — действие»: перенос текста по ширине, высота подстраивается.
local function keyRow(parent,key,text)
 local U=STALKER_STYLE
 local row=vgui.Create("DPanel",parent);row:Dock(TOP);row:DockMargin(px(6),0,px(6),px(4));row.Key=key;row.Text=text;row.Lines={text}
 row.PerformLayout=function(self,w)
  self.Lines=U.Wrap(self.Text,"STALKER.Body",math.max(px(80),w-px(150)))
  local h=math.max(1,#self.Lines)*px(18)+px(8);if self:GetTall()~=h then self:SetTall(h) end
 end
 row.Paint=function(self,w,h)
  U.Panel("",0,0,w,h,false)
  U.Text(self.Key,"STALKER.Head",px(10),px(4),"accent")
  for i,l in ipairs(self.Lines or {}) do U.Text(l,"STALKER.Body",px(140),px(4)+(i-1)*px(18),"text") end
 end
 return row
end

-- Заполнить панель памяткой (окно и вкладка КПК строятся одной функцией).
function Z.BuildHelp(parent)
 local U=STALKER_STYLE
 local scroll=vgui.Create("DScrollPanel",parent);scroll:Dock(FILL)
 if U and U.Scroll then U.Scroll(scroll) end
 if not U or not U.Label then return scroll end
 for _,section in ipairs(Z.Help) do
  local head=U.Label(scroll,section[1],"STALKER.Head","accent");head:Dock(TOP);head:DockMargin(0,px(8),0,px(4))
  for _,line in ipairs(section[2]) do
   if type(line)=="table" then keyRow(scroll,line[1],line[2])
   else local l=U.Label(scroll,"• "..lineText(line),"STALKER.Body","text");l:Dock(TOP);l:DockMargin(px(10),0,px(6),px(4)) end
  end
 end
 local note=U.Label(scroll,"Открыть снова: !help в чате, stz_help в консоли или КПК → «Памятка». Подробности — КПК → «Справочник» и «Энциклопедия».","STALKER.Small","muted")
 note:Dock(TOP);note:DockMargin(0,px(12),0,0)
 return scroll
end

function Z.OpenHelp()
 if IsValid(Z.HelpFrame) then Z.HelpFrame:Remove() end
 local U=STALKER_STYLE
 if not U or not U.Window then print("[STALKER Zone] Памятка требует STALKER Core");return end
 local f;f=U.Window({title="Памятка сталкера",w=800,h=660,onClose=function() if Z.HelpFrame==f then Z.HelpFrame=nil end end})
 Z.HelpFrame=f
 Z.BuildHelp(f)
 return f
end
concommand.Add("stz_help",function() Z.OpenHelp() end)

-- Первый вход на этот сервер: памятка открывается сама один раз.
hook.Add("InitPostEntity","STALKER_ZONE.Help",function()
 timer.Simple(8,function()
  if cookie.GetNumber("stz_help_seen",0)==1 then return end
  cookie.Set("stz_help_seen","1");Z.OpenHelp()
 end)
end)

-- Вкладка КПК «Памятка» (в дополнение к окну).
local C=STALKER_CORE
if C and C.RegisterPDATab then
 C.RegisterPDATab("memo",{title="Памятка",order=90,build=function(parent) Z.BuildHelp(parent) end})
end

-- Раздел справочника КПК «Зона»: числа берутся из текущих настроек сервера.
function Z.GuideBlocks()
 local cfg=Z.Config;local out={{head="Поля аномалий"}}
 out[#out+1]="Администрация размечает поля аномалий; на карте КПК они отмечены кругом «Аномальное поле», логова — «Логово мутантов». После каждого выброса аномалии смещаются и рождаются новые артефакты"..
  ((tonumber(cfg.ArtifactRefreshMinutes) or 0)>0 and (", без выброса — досыпаются раз в "..cfg.ArtifactRefreshMinutes.." мин.") or ".")
 for _,kind in ipairs(Z.AnomalyOrder) do
  local a=Z.Anomalies[kind]
  out[#out+1]={a.name,string.format("радиус %d · урон %s",a.radius,tostring(math.Round(a.damage*(tonumber(cfg.AnomalyDamageScale) or 1),1)))}
 end
 out[#out+1]={head="Детекторы"}
 for _,id in ipairs({"det_echo","det_bear","det_veles"}) do
  local d=Z.Detectors[id];local item=STALKER_INV and STALKER_INV.Items and STALKER_INV.Items[id]
  if d then out[#out+1]={item and item.name or id,string.format("%.0f м · %s",d.range*.01905,d.mode=="signal" and "сила сигнала" or d.mode=="arrow" and "стрелка на артефакт" or "метки всех артефактов")} end
 end
 out[#out+1]={head="Смерть"}
 out[#out+1]="Сумка погибшего лежит "..minutes(cfg.DeathDrop.Lifetime).." мин. Записи КПК в ней дают наводку на тайник погибшего."
 out[#out+1]={note="Памятка целиком — вкладка КПК «Памятка» или !help."}
 return out
end
function Z.RegisterGuide()
 local P=STALKER_PDA
 if Z.GuideAdded or type(P)~="table" or type(P.AddGuide)~="function" then return end
 Z.GuideAdded=true
 P.AddGuide("zone",{title="Зона",subtitle="Поля аномалий, детекторы, сумка погибшего",order=5,blocks=function() return Z.GuideBlocks() end})
end
Z.RegisterGuide()
hook.Add("STALKER_PDA_Ready","STALKER_ZONE.Guide",function() Z.RegisterGuide() end)

-- PDA инвентаря: кто сейчас в сети КПК. Имена — глазами игрока (знакомства STALKER_SOCIAL).
function Z.OnlineLabel(p)
 local SO=STALKER_SOCIAL;local lp=LocalPlayer()
 if SO and SO.Label then
  local name=SO.Label(lp,p)
  if SO.Knows and not SO.Knows(lp,p) then return name end
  local faction=STFW and p:GetNW2Bool("stfw_joined",false) and STFW.Name(p:GetNW2String("stfw_faction","loner"))
  return name.." · "..(faction or "одиночка")
 end
 local faction=STFW and p:GetNW2Bool("stfw_joined",false) and STFW.Name(p:GetNW2String("stfw_faction","loner")) or "одиночка"
 return p:Nick().." · "..faction
end
hook.Add("STALKER_INV_DrawPDA","STALKER_ZONE.Online",function(panel,w,h)
 local S=STALKER_INV;local U=STALKER_STYLE
 if not S or not S.Px or not U or not U.Text then return end
 local players=player.GetAll()
 local labels={};for _,p in ipairs(players) do labels[p]=Z.OnlineLabel(p) end
 table.sort(players,function(a,b) return labels[a]<labels[b] end)
 local y=h-S.Px(96)
 U.Text("СЕТЬ КПК / В СЕТИ: "..#players,"SI.Small",S.Px(16),y,"accent")
 local shown=0
 for _,p in ipairs(players) do
  if shown>=8 then U.Text("… и ещё "..(#players-shown),"SI.Small",w-S.Px(16),y,"muted",TEXT_ALIGN_RIGHT);break end
  local column,row=(shown%2),math.floor(shown/2)
  local fit=S.FitText or U.Fit
  U.Text(fit(labels[p],"SI.Small",w/2-S.Px(24)),"SI.Small",S.Px(16)+column*(w/2),y+S.Px(18)+row*S.Px(18),"text")
  shown=shown+1
 end
end)
