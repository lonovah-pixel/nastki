-- Настройки самого ядра (регистрируются в обоих realm, чтобы сервер хранил их, а клиенты получали значения).
local C=STALKER_CORE
local S=C.Settings
C.Config=C.Config or {NewsToast=true,MarkersHUD=true}
S.Register("core.theme",{category="Интерфейс",label="Тема интерфейса по умолчанию",type="choice",realm="shared",order=1,
 choices={{"zone","Зона — графит и янтарь"},{"classic","Классика — латунь КПК"},{"pda","КПК — зелёный монохром"},{"frost","Чистое Небо — сталь и бирюза"}},
 default="zone",description="Игрок может выбрать свою тему консольной командой stalker_theme.",
 get=function() return C.ThemeSetting or "zone" end,
 set=function(v) C.ThemeSetting=v;if CLIENT and STALKER_THEME and STALKER_THEME.Apply then STALKER_THEME.Apply() end end})
S.Bind("core.news_toast",C.Config,"NewsToast",{category="Интерфейс",label="Всплывающие новости КПК",type="bool",realm="shared",order=2})
S.Bind("core.markers_hud",C.Config,"MarkersHUD",{category="Интерфейс",label="Метки на экране (флаги, маячки, грузы)",type="bool",realm="shared",order=3})
