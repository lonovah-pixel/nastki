-- Панель «Комендант» → «Зона» (STALKER_ZONE.BuildAdminPanel): сводка аномалий, артефактов и мутантов,
-- быстрые действия и списки полей и логов с телепортом. Данные и проверка прав — канал stz.* (sv_editor.lua):
-- сервер проверяет право zone на каждое действие, а не только при открытии вкладки.
local Z=STALKER_ZONE
Z.AdminViews=Z.AdminViews or {}
local px=Z.Px or function(n) return n end

function Z.PaintAdminSummary(w,h)
 local U=STALKER_STYLE;local st=Z.EditorState or {};local s=st.stats or {}
 U.Panel("",0,0,w,h,false)
 U.Text("Зона · "..tostring(s.map or game.GetMap()),"STALKER.Head",px(12),px(8),"accent")
 if s.anomalies==nil then U.Text("Загрузка сводки…","STALKER.Small",px(12),px(36),"muted");return end
 U.Text(U.Fit(string.format("Поля аномалий: %d / %d · аномалий %d · артефактов %d / %d",s.fields or 0,s.maxFields or 0,s.anomalies or 0,s.artifacts or 0,s.maxArtifacts or 0),
  "STALKER.Body",w-px(24)),"STALKER.Body",px(12),px(32),"text")
 U.Text(U.Fit(string.format("Логова: %d / %d · мутантов %d / %d",s.zones or 0,s.maxZones or 0,s.mutants or 0,s.maxMutants or 0),"STALKER.Body",w-px(24)),
  "STALKER.Body",px(12),px(52),"text")
 local line,token
 local errs=type(st.errors)=="table" and st.errors or {}
 if st.ready==false then line,token="Файл Зоны повреждён — правка заблокирована. Подробности: stz_status","danger"
 elseif #errs>0 then local e=errs[#errs];line,token="Последняя ошибка: "..tostring(e.source)..": "..tostring(e.text).." (всего "..#errs..", stz_status)","warn"
 else
  line,token="Ошибок нет · артефакты досыпаются "..((tonumber(s.refresh) or 0)>0 and ("каждые "..s.refresh.." мин.") or "только после выброса")..
   (s.traders and ((tonumber(s.restock) or 0)>0 and (" · склады — каждые "..s.restock.." мин.") or " · склады вручную") or ""),"muted"
 end
 U.Text(U.Fit(line,"STALKER.Small",w-px(24)),"STALKER.Small",px(12),h-px(24),token)
end

-- Строка записи: сводка слева, кнопка «Телепорт» справа. Двойной щелчок — тоже телепорт.
function Z.AdminRow(list,kind,row)
 local U=STALKER_STYLE
 local line=vgui.Create("DButton",list);line:SetText("");line:Dock(TOP);line:SetTall(px(48));line:DockMargin(0,0,px(4),px(4))
 line.Row=row;line.Kind=kind
 line.Paint=function(self,w,h) Z.PaintEntryRow(self.Kind,self.Row,w,h,self:IsHovered(),px(112)) end
 line.DoDoubleClick=function() Z.EditorSend({op="goto",kind=kind,id=row.id}) end
 local tp=U.Button(line,"Телепорт",function() Z.EditorSend({op="goto",kind=kind,id=row.id}) end)
 tp:Dock(RIGHT);tp:SetWide(px(104));tp:DockMargin(0,px(8),px(8),px(8))
 return line
end

function Z.FillAdminLists(v)
 local U=STALKER_STYLE;local st=Z.EditorState or {}
 for _,spec in ipairs({{v.fields,"field",st.fields},{v.zones,"zone",st.zones}}) do
  local list,kind,rows=spec[1],spec[2],type(spec[3])=="table" and spec[3] or {}
  if list then
   list:Clear()
   for _,row in ipairs(rows) do Z.AdminRow(list,kind,row) end
   if #rows==0 then
    local empty=U.Label(list,kind=="field" and "Полей нет. Разметьте поле в редакторе Зоны (!zone)." or "Логов нет. Создайте логово в редакторе Зоны (!zone).","STALKER.Small","muted")
    empty:Dock(TOP);empty:DockMargin(px(4),px(6),px(4),0)
   end
  end
 end
end
function Z.RefreshAdminViews()
 for v in pairs(Z.AdminViews) do if IsValid(v.root) then Z.FillAdminLists(v) else Z.AdminViews[v]=nil end end
end

local function column(parent,title,getCount)
 local U=STALKER_STYLE
 local box=vgui.Create("DPanel",parent);box.Paint=nil
 local head=vgui.Create("DPanel",box);head:Dock(TOP);head:SetTall(px(26))
 head.Paint=function(_,w,h) U.Text(title.." ("..getCount()..")","STALKER.Head",0,h/2,"accent",TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
 local list=vgui.Create("DScrollPanel",box);list:Dock(FILL);U.Scroll(list)
 return box,list,head
end

function Z.BuildAdminPanel(parent)
 local U=STALKER_STYLE
 if not U or not U.Button or not STALKER_THEME then
  local l=vgui.Create("DLabel",parent);l:Dock(TOP);l:SetText("Панель Зоны требует STALKER Core");return l
 end
 local v={}
 local root=vgui.Create("DPanel",parent);root:Dock(FILL);root.Paint=nil;v.root=root
 local head=vgui.Create("DPanel",root);head:Dock(TOP);head:SetTall(px(100));head:DockMargin(0,0,0,px(8))
 head.Paint=function(_,w,h) Z.PaintAdminSummary(w,h) end
 v.head=head
 local _,buttons=Z.ButtonRow(root,{
  {"Открыть редактор Зоны",function() if Z.OpenEditor then Z.OpenEditor() end end,"accent"},
  {"Перестроить",function() Z.EditorSend({op="regen",kind="field"}) end,nil,true},
  {"Досыпать артефакты",function() Z.EditorSend({op="artifacts",kind="field"}) end},
  {"Пополнить склады",function() Z.EditorSend({op="restock"}) end},
  {"Убрать мутантов",function() Z.EditorSend({op="mutants_clear"}) end,"danger",true},
 })
 v.buttons=buttons
 local status=vgui.Create("DPanel",root);status:Dock(BOTTOM);status:SetTall(px(26));status:DockMargin(0,px(6),0,0)
 status.Paint=function(_,w,h) Z.PaintReply(w,h) end
 local body=vgui.Create("DPanel",root);body:Dock(FILL);body.Paint=nil
 local left,fields=column(body,"ПОЛЯ АНОМАЛИЙ",function() return #(Z.EditorState.fields or {}) end)
 left:Dock(LEFT);left:DockMargin(0,0,px(10),0)
 local right,zones=column(body,"ЛОГОВА МУТАНТОВ",function() return #(Z.EditorState.zones or {}) end)
 right:Dock(FILL)
 body.PerformLayout=function(_,w) if IsValid(left) then left:SetWide(math.floor((w-px(10))/2)) end end
 v.fields,v.zones,v.body=fields,zones,body
 Z.AdminViews[v]=true
 Z.FillAdminLists(v)
 if Z.TrackView then Z.TrackView(root) end
 return root,v
end
