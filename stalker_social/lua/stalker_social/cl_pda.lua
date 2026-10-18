-- STALKER Social: вкладки КПК «Контакты» (контакты и знакомые, в сети ли, «Написать» через КПК, удалить)
-- и «Нашивки» (что получено, прогресс достижений, выбор видимых на рукаве).
local S=STALKER_SOCIAL
local C=STALKER_CORE
local T=STALKER_THEME
local U=STALKER_STYLE
local function px(n) return T.Px(n) end
local UI=S.MenuUI

local function when(at)
 at=tonumber(at) or 0;if at<=0 then return "" end
 return os.date("%d.%m.%Y",at)
end
-- Строки контактов: в сети — выше, затем по имени.
function S.KnownRows(contacts)
 local out={}
 for sid,row in pairs(S.MyKnown or {}) do
  if (row.contact==true)==(contacts==true) then
   local p=C.PlayerBySID(sid)
   out[#out+1]={sid=sid,name=IsValid(p) and p:Nick() or row.name,online=IsValid(p),at=row.at}
  end
 end
 table.sort(out,function(a,b) if a.online~=b.online then return a.online end;return a.name<b.name end)
 return out
end
local function personCard(parent,row)
 return UI.card(parent,50,function(_,w,h)
  U.Text(U.Fit(row.name~="" and row.name or row.sid,"STALKER.Body",w-px(280)),"STALKER.Body",px(6),px(6),"text")
  U.Text((row.online and "в сети" or "не в сети")..(row.at and row.at>0 and ("   ·   знакомы с "..when(row.at)) or ""),"STALKER.Small",px(6),px(26),row.online and "ok" or "muted")
 end)
end
function S.FillContacts(root)
 if not root then return end
 root:Clear()
 local sc=UI.scroll(root)
 UI.head(sc,"Контакты КПК")
 local contacts=S.KnownRows(true)
 if #contacts==0 then UI.note(sc,"Контактов нет. Подойдите к знакомому сталкеру, нажмите G и выберите «В контакты КПК».") end
 local pda=STALKER_PDA
 for _,row in ipairs(contacts) do
  local c=personCard(sc,row)
  local del=U.Button(c,"Удалить",function() S.Request("uncontact",{sid=row.sid}) end,"danger");del:Dock(RIGHT);del:SetWide(px(100));del:DockMargin(px(6),0,0,0)
  local write=U.Button(c,"Написать",function() if pda and pda.OpenMessages then pda.OpenMessages(row.sid) end end,"accent")
  write:Dock(RIGHT);write:SetWide(px(110));write:SetEnabled(pda~=nil and pda.OpenMessages~=nil)
 end
 local known=S.KnownRows(false)
 UI.head(sc,"Знакомые ("..#known..")")
 UI.note(sc,"Вы знаете их имена. Своё имя вы показываете сами: G → «Представиться».")
 for _,row in ipairs(known) do
  local c=personCard(sc,row)
  local forget=U.Button(c,"Забыть",function() S.Request("forget",{sid=row.sid}) end);forget:Dock(RIGHT);forget:SetWide(px(100))
 end
end
function S.BuildContacts(parent)
 local root=vgui.Create("DPanel",parent);root:Dock(FILL);root.Paint=function() end
 S.ContactsPanel=root
 S.FillContacts(root)
 S.Request("known")
 return root
end
hook.Add("STALKER_SOCIAL_KnownUpdated","STALKER_SOCIAL.PDA",function() if IsValid(S.ContactsPanel) then S.FillContacts(S.ContactsPanel) end end)

--[[ Нашивки ]]
-- Что написать под нашивкой: на рукаве, как получить, прогресс.
function S.PatchHint(it,visible)
 if it.owned then
  if visible then return "На рукаве","accent" end
  if it.by then return "Выдал: "..it.by,"muted" end
  return "Получена","ok"
 end
 if it.token=="faction" then return "Вступите в группировку","muted" end
 if it.token=="rank" then return "Звание появится с профилем группировки","muted" end
 if it.goal then return (it.value or 0).." / "..it.goal,"muted" end
 if it.token:sub(1,6)=="award_" then return "Выдаёт лидер вашей группировки","muted" end
 return "","muted"
end
local function title(it)
 local info=it.id and S.PatchInfo(it.id)
 if info then return info.name,info.desc end
 if it.token=="faction" then return "Нашивка группировки","Эмблема вашей группировки." end
 if it.token=="rank" then return "Звание","Звание по опыту." end
 info=S.PatchInfo(it.token)
 if info then return info.name,info.desc end
 return it.token,""
end
function S.ToggleVisible(token)
 local st=S.PatchState;if not st then return end
 local list,found={},false
 for _,t in ipairs(st.visible) do if t==token then found=true else list[#list+1]=t end end
 if not found then
  if #list>=(st.max or 3) then if C.Toast then C.Toast("Можно показывать не больше "..(st.max or 3).." нашивок","warn",4) end;return end
  list[#list+1]=token
 end
 S.Request("visible",{ids=list})
end
function S.FillPatches(root)
 if not root then return end
 root:Clear()
 local st=S.PatchState
 if not st then UI.note(root,"Загрузка нашивок…");return end
 local sc=UI.scroll(root)
 UI.head(sc,"Нашивки на рукаве")
 UI.note(sc,"Выберите до "..(st.max or 3).." нашивок: их видят все рядом — на плече и в меню взаимодействия. Нашивку группировки видит и незнакомец.")
 local shown={};for _,t in ipairs(st.visible) do shown[t]=true end
 UI.card(sc,64,function(_,w,h)
  local list=S.VisiblePatches(LocalPlayer())
  if #list==0 then U.Text("Сейчас на рукаве ничего нет","STALKER.Body",px(6),h/2,"muted",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);return end
  for i,id in ipairs(list) do S.DrawPatch(id,px(4)+(i-1)*px(54),h/2-px(24),px(48)) end
 end)
 for _,it in ipairs(st.items) do
  if type(it)=="table" and type(it.token)=="string" then
   local name,desc=title(it)
   local c=UI.card(sc,58,function(_,w,h)
    if it.id then S.DrawPatch(it.id,px(2),h/2-px(21),px(42),255,not it.owned)
    else surface.SetDrawColor(T.C.track);surface.DrawRect(px(2),h/2-px(21),px(42),px(42)) end
    U.Text(U.Fit(name,"STALKER.Body",w-px(300)),"STALKER.Body",px(56),px(6),it.owned and "text" or "muted")
    U.Text(U.Fit(desc,"STALKER.Small",w-px(300)),"STALKER.Small",px(56),px(25),"muted")
    local hint,token=S.PatchHint(it,shown[it.token])
    U.Text(hint,"STALKER.Small",w-px(150),h/2,token,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
    if it.goal and not it.owned then U.Bar(px(56),h-px(10),w-px(220),px(4),(it.value or 0)/math.max(1,it.goal),T.C.accent) end
   end)
   if it.owned then
    local b=U.Button(c,shown[it.token] and "Снять" or "Показывать",function() S.ToggleVisible(it.token) end,shown[it.token] and nil or "accent")
    b:Dock(RIGHT);b:SetWide(px(130))
   end
  end
 end
end
function S.BuildPatchesTab(parent)
 local root=vgui.Create("DPanel",parent);root:Dock(FILL);root.Paint=function() end
 S.PatchesPanel=root
 S.FillPatches(root)
 S.Request("patches")
 return root
end
hook.Add("STALKER_SOCIAL_PatchesUpdated","STALKER_SOCIAL.PDA",function() if IsValid(S.PatchesPanel) then S.FillPatches(S.PatchesPanel) end end)

if C.RegisterPDATab then
 C.RegisterPDATab("contacts",{title="Контакты",order=70,build=function(parent) S.BuildContacts(parent) end,
  -- Значок: живые предложения (протянутая рука, ответное знакомство).
  badge=function() local n=#S.ActiveOffers();return n>0 and n or nil end})
 C.RegisterPDATab("patches",{title="Нашивки",order=75,build=function(parent) S.BuildPatchesTab(parent) end})
end
