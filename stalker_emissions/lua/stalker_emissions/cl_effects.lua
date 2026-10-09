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
local function box(x,y,w,h)
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
 local phase=E.Config.Phases[E.State.phase];if not phase then return end
 local w=math.min(510,ScrW()-40);E.Box(ScrW()/2-w/2,108,w,65)
 draw.SimpleText("ВЫБРОС / "..phase.name,"Emission.Title",ScrW()/2,118,Color(204,175,111),TEXT_ALIGN_CENTER)
 draw.SimpleText(math.max(0,math.ceil(E.State.ends-CurTime())).." сек.","Emission.Body",ScrW()/2,148,Color(214,207,171),TEXT_ALIGN_CENTER)
end)
hook.Add("DrawOverlay","STEmission.Blackout",function()
 local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
 local remaining=p:GetNW2Float("stem_unconscious",0)-CurTime();if remaining<=0 then return end
 surface.SetDrawColor(0,0,0,255*math.min(1,remaining));surface.DrawRect(0,0,ScrW(),ScrH())
end)
hook.Add("ShutDown","STEmission.SoundStop",stopSound)
hook.Add("InitPostEntity","STEmission.Request",function() net.Start("stem.request");net.SendToServer() end)
