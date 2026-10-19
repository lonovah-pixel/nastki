-- STALKER Social: меню эмоций (H, чат !emote, консоль stsoc_emotes). Жесты играют все клиенты рядом,
-- позы держатся, пока вы не двинетесь, не выстрелите или не получите урон.
local S=STALKER_SOCIAL
local T=STALKER_THEME
local U=STALKER_STYLE
local function px(n) return T.Px(n) end

local function grid(parent,list,current)
 local layout=vgui.Create("DIconLayout",parent);layout:Dock(TOP);layout:SetSpaceX(px(6));layout:SetSpaceY(px(6));layout:DockMargin(0,0,0,px(10))
 for _,e in ipairs(list) do
  local b=U.Button(layout,e.name,function()
   S.SendEmote(e.id)
   if IsValid(S.EmoteMenu) then S.EmoteMenu:Remove() end
  end,current==e.id and "accent" or nil)
  b:SetSize(px(150),px(34));b.EmoteID=e.id
  if e.act and not S.Act(e.act) then b:SetEnabled(false) end
  layout:Add(b)
 end
 -- Высота сетки: DIconLayout растёт сам после раскладки, но вкладке нужна высота до неё.
 local rows=math.ceil(#list/3);layout:SetTall(rows*px(34)+(rows-1)*px(6))
 return layout
end
function S.OpenEmotes()
 if IsValid(S.EmoteMenu) then S.EmoteMenu:Remove();return end
 local f=U.Window({title="Эмоции",w=520,h=440,onClose=function() S.EmoteMenu=nil end})
 S.EmoteMenu=f
 local current=S.GetPose(LocalPlayer())
 local menu=S.MenuUI
 menu.head(f,"Жесты")
 grid(f,S.Gestures)
 menu.head(f,"Позы")
 grid(f,S.Poses,current)
 menu.note(f,"Поза снимается, когда вы двигаетесь, стреляете или получаете урон. В позе нельзя стрелять. «Руки вверх» позволяет другим обыскать вас.")
 local stand=U.Button(f,"Встать",function() S.SendEmote("stand");f:Remove() end,current~="" and "accent" or nil)
 stand:Dock(BOTTOM);stand:SetEnabled(current~="")
 f.Stand=stand
 return f
end
concommand.Add("stsoc_emotes",function() S.OpenEmotes() end)
-- stsoc_emote <id> (для бинда) — серверная команда: клиент без своей команды передаёт её серверу.

local keyCV=CreateClientConVar("stsoc_emote_key",tostring(KEY_H or 18),true,false,"Клавиша меню эмоций (код KEY_*)")
local held=false
hook.Add("Think","STALKER_SOCIAL.EmoteKey",function()
 local down=input.IsKeyDown(keyCV:GetInt())
 if down and not held and IsValid(LocalPlayer()) and S.KeyAllowed(S.EmoteMenu) then S.OpenEmotes() end
 held=down
end)
