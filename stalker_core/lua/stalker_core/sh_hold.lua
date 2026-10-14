-- «Удерживайте E»: общее действие с прогрессом (захват флага, вскрытие груза, чужой тайник, костёр).
-- Прерывается, если игрок отпустил E, отошёл, отвернулся, погиб или потерял сознание.
local C=STALKER_CORE
C.Hold=C.Hold or {}
local H=C.Hold

if SERVER then
 H.Active=H.Active or {}
 --[[ opts: range (units, 110), look (true — смотреть на цель), onCancel(ply,ent,reason), check(ply,ent) → false/строка-причина ]]
 function H.Start(ply,ent,seconds,label,onDone,opts)
  opts=opts or {}
  if not IsValid(ply) or not ply:Alive() or not IsValid(ent) or H.Active[ply] or C.Unconscious(ply) then return false end
  local now=CurTime()
  H.Active[ply]={ent=ent,start=now,ends=now+seconds,label=label or "",onDone=onDone,opts=opts}
  ply:SetNW2Float("stc_hold_start",now);ply:SetNW2Float("stc_hold_end",now+seconds);ply:SetNW2String("stc_hold_label",label or "")
  return true
 end
 local function clear(ply)
  H.Active[ply]=nil
  if IsValid(ply) then ply:SetNW2Float("stc_hold_end",0);ply:SetNW2String("stc_hold_label","") end
 end
 function H.Cancel(ply,reason)
  local a=H.Active[ply];if not a then return end
  clear(ply)
  if a.opts.onCancel then pcall(a.opts.onCancel,ply,a.ent,reason) end
 end
 function H.IsHolding(ply) return H.Active[ply]~=nil end
 local function valid(ply,a)
  if not IsValid(ply) or not ply:Alive() or not IsValid(a.ent) or C.Unconscious(ply) then return false,"Действие прервано" end
  if not ply:KeyDown(IN_USE) then return false,"Вы отпустили E" end
  local range=a.opts.range or 110
  local center=a.ent:WorldSpaceCenter()
  if ply:GetShootPos():DistToSqr(center)>(range+40)^2 then return false,"Слишком далеко" end
  if a.opts.look~=false then
   local dir=(center-ply:GetShootPos());dir:Normalize()
   if dir:Dot(ply:GetAimVector())<.55 then return false,"Смотрите на цель" end
  end
  if a.opts.check then local ok,res=pcall(a.opts.check,ply,a.ent);if ok and res~=nil and res~=true then return false,type(res)=="string" and res or "Условия изменились" end end
  return true
 end
 timer.Create("STALKER_Core.Hold",.1,0,function()
  local now=CurTime()
  -- Снимок: onDone может начать новое удержание, а таблицу нельзя расширять во время обхода.
  local list={};for ply,a in pairs(H.Active) do list[#list+1]={ply,a} end
  for _,row in ipairs(list) do
   local ply,a=row[1],row[2]
   local ok,reason=valid(ply,a)
   if not ok then H.Cancel(ply,reason);if IsValid(ply) and reason then C.Notify(ply,reason,"warn",3) end
   elseif now>=a.ends then
    clear(ply)
    local success,err=pcall(a.onDone,ply,a.ent)
    if not success then ErrorNoHalt("[STALKER Core] Hold: "..tostring(err).."\n") end
   end
  end
 end)
 hook.Add("PlayerDeath","STALKER_Core.Hold",function(ply) H.Cancel(ply,"Гибель") end)
 hook.Add("PlayerDisconnected","STALKER_Core.Hold",function(ply) H.Active[ply]=nil end)
end
