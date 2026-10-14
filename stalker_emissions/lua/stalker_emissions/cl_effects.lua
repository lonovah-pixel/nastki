local E=ST_EMISSION
E.State={phase=0,started=0,ends=0,next=0}
local effects=CreateClientConVar("stem_effects","1",true,false)
local hud=CreateClientConVar("stem_hud","1",true,false)
local volume=CreateClientConVar("stem_volume","0.8",true,false,"Громкость выброса",0,1)
local strength=0
surface.CreateFont("Emission.Title",{font="Trebuchet MS",size=23,weight=700,extended=true})
surface.CreateFont("Emission.Body",{font="Tahoma",size=15,extended=true})
local metal=Material("stalker_emissions/metal.png","smooth")
local panel=Material("stalker_emissions/panel.png","smooth")
-- Цвета HUD выброса — из общей темы; без ядра остаётся прежняя латунь.
local function tc(token,r,g,b,a)
 local T=STALKER_THEME;local c=T and T.C and T.C[token]
 if c then return Color(c.r,c.g,c.b,a or c.a) end
 return Color(r,g,b,a or 255)
end
local function box(x,y,w,h)
 if STALKER_STYLE and STALKER_STYLE.Core then STALKER_STYLE.Panel("stalker_emissions",x,y,w,h,true);return end
 surface.SetDrawColor(24,29,20,230);surface.DrawRect(x,y,w,h);surface.SetMaterial(metal);surface.SetDrawColor(255,255,255,210);surface.DrawTexturedRect(x,y,w,h);surface.SetMaterial(panel);surface.DrawTexturedRect(x+3,y+3,w-6,h-6);surface.SetDrawColor(130,129,91,220);surface.DrawOutlinedRect(x,y,w,h)
end
E.Box=box

local channel,fallback;local generation=0
local function stopSound()
 generation=generation+1
 if IsValid(channel) then channel:Stop() end;channel=nil
 if fallback then fallback:Stop() end;fallback=nil
end
local function phaseSound()
 stopSound()
 local phase=E.Config.Phases[E.State.phase];if not phase then return end
 local token=generation
 local function reserve()
  if token~=generation or not IsValid(LocalPlayer()) then return end
  fallback=CreateSound(LocalPlayer(),E.Config.FallbackSounds[phase.id]);if fallback then fallback:PlayEx(math.Clamp(volume:GetFloat(),0,1),100) end
 end
 local path="sound/"..E.Config.Sounds[phase.id]
 if not file.Exists(path,"GAME") then reserve();return end
 sound.PlayFile(path,"noplay",function(ch)
  if token~=generation then if IsValid(ch) then ch:Stop() end;return end
  if not IsValid(ch) then reserve();return end
  channel=ch;ch:SetVolume(math.Clamp(volume:GetFloat(),0,1));ch:EnableLooping(true);ch:Play()
 end)
end
net.Receive("stem.state",function()
 local size=net.ReadUInt(16);if size>60000 then return end
 local packet=util.JSONToTable(net.ReadData(size));if not packet or type(packet.state)~="table" then return end
 local old=E.State.phase;E.State=packet.state;E.Settings=packet.settings
 if old~=E.State.phase then phaseSound() end
 if E.SyncMenu then E.SyncMenu() end
end)
local nextShake=0
hook.Add("Think","STEmission.Shake",function()
 local p=LocalPlayer();if not IsValid(p) then return end
 if IsValid(channel) then channel:SetVolume(math.Clamp(volume:GetFloat(),0,1)) end
 if fallback then fallback:ChangeVolume(math.Clamp(volume:GetFloat(),0,1),0) end
 if not effects:GetBool() or E.State.phase==0 or not p:Alive() or CurTime()<nextShake then return end
 nextShake=CurTime()+.6
 local amplitudes={.25,1.5,4,.6};local phase=E.Config.Phases[E.State.phase]
 local progress=math.Clamp((CurTime()-E.State.started)/phase.duration,0,1)
 util.ScreenShake(p:GetPos(),amplitudes[E.State.phase]*(.5+progress*.5),8,.7,0)
end)
hook.Add("RenderScreenspaceEffects","STEmission.Effects",function()
 local targets={.08,.5,1,.25};strength=Lerp(math.min(1,FrameTime()*2),strength,targets[E.State.phase] or 0)
 if not effects:GetBool() or strength<.005 then return end
 DrawColorModify({["$pp_colour_addr"]=.07*strength,["$pp_colour_addg"]=.008*strength,["$pp_colour_addb"]=0,["$pp_colour_brightness"]=-.035*strength,["$pp_colour_contrast"]=1+.17*strength,["$pp_colour_colour"]=1-.45*strength,["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0})
end)
hook.Add("HUDPaint","STEmission.HUD",function()
 if not hud:GetBool() or E.State.phase==0 then return end
 local p=LocalPlayer();if IsValid(p) and E.IsUnconscious(p) then return end
 local phase=E.Config.Phases[E.State.phase];if not phase then return end
 -- Ниже плашки территории группировок (она занимает верх экрана по центру).
 local w=math.min(510,ScrW()-40);local y=math.Round(math.max(150,ScrH()*.16))
 E.Box(ScrW()/2-w/2,y,w,65)
 draw.SimpleText("ВЫБРОС / "..phase.name,"Emission.Title",ScrW()/2,y+10,tc("accent",204,175,111),TEXT_ALIGN_CENTER)
 local sheltered=IsValid(p) and p:GetNW2Bool("stem_sheltered",false)
 draw.SimpleText(math.max(0,math.ceil(E.State.ends-CurTime())).." сек.  /  "..(sheltered and "В УКРЫТИИ" or "ИЩИТЕ УКРЫТИЕ"),"Emission.Body",ScrW()/2,y+40,sheltered and tc("ok",130,170,105) or tc("danger",214,120,90),TEXT_ALIGN_CENTER)
end)
-- Обморок: камера из глаз упавшего тела, затемнение с «пульсом», затем размытое пробуждение.
surface.CreateFont("Emission.Faint",{font="Trebuchet MS",size=26,weight=700,extended=true})
local wakeUntil,wasOut,nextBeat=0,false,0
local function faintAlpha(p)
 local now=CurTime();local untilTime=p:GetNW2Float("stem_unconscious",0);if untilTime<=now then return 0 end
 local start=p:GetNW2Float("stem_unconscious_start",now)
 return math.min(math.Clamp((now-start)/1.2,0,1),math.Clamp((untilTime-now)/2,0,1))
end
hook.Add("CalcView","STEmission.Faint",function(p,origin,angles,fov)
 if not E.IsUnconscious(p) then return end
 local rag=p:GetNW2Entity("stem_ragdoll");if not IsValid(rag) then return end
 if not rag.StemHeadHidden then
  local head=rag:LookupBone("ValveBiped.Bip01_Head1");if head then rag:ManipulateBoneScale(head,Vector(0,0,0)) end
  rag.StemHeadHidden=true
 end
 local att=rag:LookupAttachment("eyes");local eyes=att and att>0 and rag:GetAttachment(att)
 if eyes then return {origin=eyes.Pos,angles=eyes.Ang,fov=fov,znear=1,drawviewer=false} end
 return {origin=rag:WorldSpaceCenter()+Vector(0,0,8),angles=angles,fov=fov,drawviewer=false}
end)
hook.Add("Think","STEmission.Faint",function()
 local p=LocalPlayer();if not IsValid(p) then return end
 local out=E.IsUnconscious(p)
 if out and CurTime()>nextBeat then nextBeat=CurTime()+1.1;surface.PlaySound("player/heartbeat1.wav") end
 if wasOut and not out and p:Alive() then wakeUntil=CurTime()+4 end
 if out and not wasOut then surface.PlaySound("player/pl_pain"..math.random(5,7)..".wav") end
 wasOut=out
end)
hook.Add("RenderScreenspaceEffects","STEmission.FaintFX",function()
 local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
 local k=E.IsUnconscious(p) and 1 or math.Clamp((wakeUntil-CurTime())/4,0,1)
 if k<=0 then return end
 DrawMotionBlur(.15,.85*k,.01);DrawToyTown(math.ceil(6*k),ScrH()*.5)
end)
hook.Add("DrawOverlay","STEmission.Blackout",function()
 local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
 local a=faintAlpha(p);if a<=0 then return end
 local pulse=.9+.1*math.sin(CurTime()*5.5)
 surface.SetDrawColor(0,0,0,255*a*pulse);surface.DrawRect(0,0,ScrW(),ScrH())
 draw.SimpleText("ВЫ ПОТЕРЯЛИ СОЗНАНИЕ","Emission.Faint",ScrW()/2,ScrH()*.62,tc("danger",170,60,45,220*a),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
end)
hook.Add("ShutDown","STEmission.SoundStop",stopSound)
hook.Add("InitPostEntity","STEmission.Request",function() net.Start("stem.request");net.SendToServer() end)
