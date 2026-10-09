local E=ST_EMISSION
function E.Admin(data)
 local text=util.TableToJSON(data);if not text or #text>480 then return end
 net.Start("stem.admin");net.WriteUInt(#text,16);net.WriteData(text,#text);net.SendToServer()
end
function E.SyncMenu()
 local f=E.Menu;if not IsValid(f) or not E.Settings then return end
 f.Auto:SetValue(E.Settings.auto and 1 or 0);f.Min:SetValue(E.Settings.min);f.Max:SetValue(E.Settings.max)
end
function E.OpenMenu()
 if not E.IsAdmin(LocalPlayer()) then return end
 if IsValid(E.Menu) then E.Menu:Remove() end
 local f=vgui.Create("DFrame");E.Menu=f;f:SetSize(math.min(620,ScrW()-30),math.min(540,ScrH()-30));f:Center();f:SetTitle("КПК / УПРАВЛЕНИЕ ВЫБРОСАМИ");f:MakePopup();f:DockPadding(18,40,18,18)
 f.Paint=function(_,w,h) E.Box(0,0,w,h) end
 local scroll=vgui.Create("DScrollPanel",f);scroll:Dock(FILL)
 local function label(text)
  local l=vgui.Create("DLabel",scroll);l:Dock(TOP);l:SetTall(35);l:SetText(text);l:SetWrap(true)
 end
 f.Auto=vgui.Create("DCheckBoxLabel",scroll);f.Auto:Dock(TOP);f.Auto:SetTall(32);f.Auto:SetText("Автоматические выбросы")
 for _,row in ipairs({{"Min","Минимальный интервал, минут"},{"Max","Максимальный интервал, минут"}}) do
  local s=vgui.Create("DNumSlider",scroll);s:Dock(TOP);s:SetTall(45);s:SetText(row[2]);s:SetMin(1);s:SetMax(1440);s:SetDecimals(0);f[row[1]]=s
 end
 local function button(text,fn)
  local b=vgui.Create("DButton",scroll);b:Dock(TOP);b:SetTall(36);b:DockMargin(0,4,0,4);b:SetText(text);b.DoClick=fn
 end
 label("Интервал отсчитывается от завершения выброса. Настройки сохраняются.")
 button("Сохранить настройки",function()
  local a={op="settings",auto=f.Auto:GetChecked(),min=math.Round(f.Min:GetValue()),max=math.Round(f.Max:GetValue())}
  if not E.ValidSettings(a) then notification.AddLegacy("Минимум должен быть не больше максимума",NOTIFY_ERROR,4);return end
  E.Admin(a)
 end)
 button("Начать выброс",function() E.Admin({op="start"}) end)
 button("Остановить выброс",function() E.Admin({op="stop"}) end)
 label("Следующий автоматический выброс:")
 local status=vgui.Create("DLabel",scroll);status:Dock(TOP);status:SetTall(25)
 status.Think=function(self) self:SetText(E.State.phase>0 and "Выброс активен" or E.State.next>0 and (math.max(0,math.ceil((E.State.next-CurTime())/60)).." мин.") or "Отключён") end
 local vol=vgui.Create("DNumSlider",scroll);vol:Dock(TOP);vol:SetTall(45);vol:SetText("Громкость (для вас)");vol:SetMin(0);vol:SetMax(1);vol:SetDecimals(2);vol:SetConVar("stem_volume")
 E.SyncMenu();net.Start("stem.request");net.SendToServer()
end
concommand.Add("stem_menu",E.OpenMenu)
concommand.Add("stem_editor",E.OpenMenu)
hook.Add("PopulateToolMenu","STEmission.Menu",function()
 spawnmenu.AddToolMenuOption("Utilities","Admin","STEmission","Выбросы","","",function(panel)
  panel:Button("Открыть управление выбросами","stem_menu")
  panel:CheckBox("Эффекты и тряска (для вас)","stem_effects")
  panel:CheckBox("Показывать фазу выброса","stem_hud")
 end)
end)
