-- Памятка новичка (первый вход, !help, stz_help) и список сталкеров онлайн во вкладке PDA.
local Z=STALKER_ZONE
local C={text=Color(217,207,176),muted=Color(138,143,115),accent=Color(200,169,81)}
surface.CreateFont("STZ.HelpTitle",{font="Trebuchet MS",size=22,weight=700,extended=true})
surface.CreateFont("STZ.HelpHead",{font="Tahoma",size=16,weight=700,extended=true})
surface.CreateFont("STZ.HelpBody",{font="Tahoma",size=14,weight=500,extended=true})

Z.Help={
 {"Управление",{
  "TAB — инвентарь (КПК). ALT + 1–9 — быстрые слоты.",
  "E — говорить с торговцем/вербовщиком, подбирать предметы, обыскивать рюкзаки.",
  "F4 — профессии. F6 — сеть группировок: территории, дипломатия, ранг.",
  "F1 — справка DarkRP и чат-команды. !stash — личные тайники.",
 }},
 {"Как выжить",{
  "Следите за голодом и жаждой: на нуле они отнимают здоровье.",
  "Радиация копится в зонах заражения и от артефактов. Антирад, водка и научная аптечка снижают дозу.",
  "Выброс: при сирене ищите укрытие под крышей. На пике незащищённых сталкеров валит с ног.",
  "Аномалии выдают себя искажением воздуха, искрами, пламенем или зелёным паром. Обходите их.",
 }},
 {"Заработок",{
  "Артефакты лежат у аномалий и видны только с детектором в рюкзаке. Детектор пищит чаще, когда артефакт рядом.",
  "После каждого выброса аномалии смещаются и появляются новые артефакты.",
  "Мутантов можно разделать монтировкой (E по туше) и продать части торговцу. Добыча: stb_claim.",
  "Торговцы группировок продают снаряжение и скупают хабар. Учёные платят за артефакты больше.",
 }},
 {"Группировки",{
  "Вступление — у вербовщика группировки (E). Нужен взнос или допуск от лидера.",
  "После вступления в F4 открывается профессия группировки с её снаряжением и цветом.",
  "Во время войны группировки захватывают точки и получают очки снабжения.",
 }},
 {"Смерть",{
  "Экипировка остаётся при вас, а содержимое рюкзака падает на месте гибели в сумке.",
  "Сумку может забрать кто угодно, пока она не исчезнет (10 минут).",
 }},
}

function Z.OpenHelp()
 if IsValid(Z.HelpFrame) then Z.HelpFrame:Remove() end
 local f=vgui.Create("DFrame");Z.HelpFrame=f
 f:SetSize(math.min(760,ScrW()-40),math.min(600,ScrH()-40));f:Center();f:SetTitle("");f:MakePopup();f:DockPadding(18,48,18,18)
 f.Paint=function(_,w,h)
  if STALKER_STYLE and STALKER_STYLE.Frame then STALKER_STYLE.Frame("stalker_inv",w,h) else surface.SetDrawColor(22,24,19);surface.DrawRect(0,0,w,h) end
  draw.SimpleText("ПАМЯТКА СТАЛКЕРА","STZ.HelpTitle",20,16,C.accent)
 end
 local scroll=vgui.Create("DScrollPanel",f);scroll:Dock(FILL)
 if STALKER_STYLE and STALKER_STYLE.Scroll then STALKER_STYLE.Scroll(scroll) end
 for _,section in ipairs(Z.Help) do
  local head=vgui.Create("DLabel",scroll);head:Dock(TOP);head:SetTall(28);head:SetFont("STZ.HelpHead");head:SetTextColor(C.accent);head:SetText(section[1])
  for _,line in ipairs(section[2]) do
   local l=vgui.Create("DLabel",scroll);l:Dock(TOP);l:DockMargin(10,0,6,4);l:SetFont("STZ.HelpBody");l:SetTextColor(C.text)
   l:SetWrap(true);l:SetAutoStretchVertical(true);l:SetText("• "..line)
  end
 end
 local note=vgui.Create("DLabel",f);note:Dock(BOTTOM);note:SetTall(20);note:SetFont("STZ.HelpBody");note:SetTextColor(C.muted)
 note:SetText("Открыть снова: !help в чате или stz_help в консоли.")
end
concommand.Add("stz_help",Z.OpenHelp)

-- Первый вход на этот сервер: памятка открывается сама один раз.
hook.Add("InitPostEntity","STALKER_ZONE.Help",function()
 timer.Simple(8,function()
  if cookie.GetNumber("stz_help_seen",0)==1 then return end
  cookie.Set("stz_help_seen","1");Z.OpenHelp()
 end)
end)

-- PDA: кто сейчас в сети КПК.
hook.Add("STALKER_INV_DrawPDA","STALKER_ZONE.Online",function(panel,w,h)
 local S=STALKER_INV;if not S or not S.Px then return end
 local players=player.GetAll()
 table.sort(players,function(a,b) return a:Nick()<b:Nick() end)
 local y=h-S.Px(96)
 draw.SimpleText("СЕТЬ КПК / В СЕТИ: "..#players,"SI.Small",S.Px(16),y,C.accent)
 local shown=0
 for i,p in ipairs(players) do
  if shown>=8 then draw.SimpleText("… и ещё "..(#players-shown),"SI.Small",w-S.Px(16),y,C.muted,TEXT_ALIGN_RIGHT);break end
  local col,row=(shown%2),math.floor(shown/2)
  local faction=STFW and p:GetNW2Bool("stfw_joined",false) and STFW.Name(p:GetNW2String("stfw_faction","loner")) or "одиночка"
  local text=S.FitText(p:Nick().." · "..faction,"SI.Small",w/2-S.Px(24))
  draw.SimpleText(text,"SI.Small",S.Px(16)+col*(w/2),y+S.Px(18)+row*S.Px(18),C.text)
  shown=shown+1
 end
end)
