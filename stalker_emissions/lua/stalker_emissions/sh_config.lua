local E=ST_EMISSION
E.Config={IntervalMin=1800,IntervalMax=3600,AutoStart=true,AutoRoof=true,RoofDistance=4096,
 RoofCheckInterval=1,DamageInterval=1,DamagePlayers=true,DamageNPCs=false,DamageNextBots=false,
 AdminSuperOnly=true,KnockoutSeconds=8,
 Phases={{id="warning",name="ПРЕДВЕСТНИК",duration=60,damage=0.1,damageEnd=0.6},
 {id="onset",name="НАЧАЛО ВЫБРОСА",duration=30,damage=0.6,damageEnd=2},
 {id="peak",name="ПИК ВЫБРОСА",duration=45,damage=4,damageEnd=8},
 {id="fade",name="СПАД",duration=25,damage=1,damageEnd=0.1}},
 Sounds={warning="stalker_emissions/warning.ogg",onset="stalker_emissions/onset.ogg",peak="stalker_emissions/peak.ogg",fade="stalker_emissions/fade.ogg"},
 FallbackSounds={warning="ambient/alarms/klaxon1.wav",onset="ambient/levels/citadel/portal_beam_shoot5.wav",peak="ambient/explosions/explode_4.wav",fade="ambient/levels/citadel/portal_beam_shoot6.wav"}}
function E.IsAdmin(p) return IsValid(p) and (E.Config.AdminSuperOnly and p:IsSuperAdmin() or not E.Config.AdminSuperOnly and p:IsAdmin()) end
function E.Int(n,a,b) return type(n)=="number" and n==math.floor(n) and n>=a and n<=b end
function E.ValidSettings(a)
 return type(a)=="table" and type(a.auto)=="boolean" and E.Int(a.min,1,1440) and E.Int(a.max,1,1440) and a.min<=a.max
end

-- Общий API для инвентаря, торговли, разделки и войны группировок.
function E.IsUnconscious(p)
 return IsValid(p) and p:Alive() and math.max(p:GetNW2Float("stem_unconscious",0),p:GetNW2Float("stem_unconscious_until",0))>CurTime()
end
-- Блокировка управления в обмороке выполняется и на клиенте, чтобы предсказание не дёргало камеру.
hook.Add("StartCommand","STEmission.Unconscious",function(p,cmd)
 if E.IsUnconscious(p) then cmd:ClearButtons();cmd:ClearMovement() end
end)
hook.Add("SetupMove","STEmission.Unconscious",function(p,mv)
 if E.IsUnconscious(p) then mv:SetForwardSpeed(0);mv:SetSideSpeed(0);mv:SetUpSpeed(0);mv:SetMaxSpeed(0);mv:SetMaxClientSpeed(0) end
end)
