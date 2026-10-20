local B=STALKER_BUTCHERING
B.Sessions={}
for _,id in ipairs({'start','hit','cancel','state'}) do util.AddNetworkString('stb.'..id) end
function B.Send(p,data)
 if IsValid(p) then net.Start('stb.state');net.WriteString(util.TableToJSON(data));net.Send(p) end
end
local function reject(p,text) B.Send(p,{kind='message',text=text});return false,text end
local function access(p,ent)
 if not IsValid(p) or not p:IsPlayer() or not p:Alive() or p:InVehicle() or B.Unconscious(p) then return false end
 if not IsValid(ent) or p:GetShootPos():DistToSqr(ent:NearestPoint(p:GetShootPos()))>B.Config.Distance^2 then return false end
 local tr=util.TraceLine({start=p:GetShootPos(),endpos=ent:WorldSpaceCenter(),filter={p,ent},mask=MASK_SOLID})
 return not tr.Hit
end
function B.Release(p,s)
 local d=B.Corpses[s.ent];if d and d.owner==p then d.owner=nil end
 B.Sessions[p]=nil;if IsValid(p) then p:SetNW2Bool('stb_busy',false) end
end
function B.RemoveCorpse(ent)
 -- Сначала снимаем регистрацию: EntityRemoved не должен повторно отменить сессию.
 B.Corpses[ent]=nil
 if IsValid(ent) then ent:Remove() end
end
function B.Cancel(p,reason)
 local s=B.Sessions[p];if not s then return end
 -- Выбор расходует всю тушу: отмена не позволяет выбрать другую награду.
 B.Release(p,s);B.RemoveCorpse(s.ent);B.Send(p,{kind='end',text=(reason or 'Отменено')..'. Туша израсходована.'})
 hook.Run('STB_Cancelled',p,s.ent,reason)
end
function B.startButchering(mutant,p,tool,partIndex)
 if not IsValid(p) or not p:IsPlayer() then return false,'Нет игрока' end
 if B.Sessions[p] then return false,'Уже разделываете' end
 local d=B.Corpses[mutant];local part=B.Config.Parts[partIndex or 1]
 if not d or not part or not access(p,mutant) then return reject(p,'Туша недоступна') end
 if d.expires<=CurTime() or d.consumed or IsValid(d.owner) then return reject(p,'Туша уже использована или занята') end
 if not B.Ready or not B.InventoryReady(p) then return reject(p,'Нужен STALKER Inventory с SQLite') end
 if (p.StbAfter or 0)>CurTime() or B.Outbox[p:SteamID64()] then return reject(p,'Подождите завершения предыдущей операции') end
 local w,cfg=B.Tool(p);if not w or (tool~=nil and tool~=w and tool~=w:GetClass()) then return reject(p,'Возьмите подходящий инструмент') end
 for uid,owned in pairs(p.StalkerWeapons or {}) do if owned==w then
  local item=STALKER_INV.FindUID(p:GetInventory(),uid)
  if not item or item.durability<=0 then return reject(p,'Инструмент сломан') end
 end end
 local profile=B.Profile(p);if not profile then return reject(p,'Профиль не загружен') end
 local pending=B.Query('SELECT COUNT(*) AS n FROM stb_rewards WHERE steamid='..sql.SQLStr(p:SteamID64()))
 if not pending or tonumber(pending[1].n)>=64 then return reject(p,'Сначала получите накопленную добычу: stb_claim') end
 if hook.Run('STB_CanStart',p,mutant,w,part.id)==false then return reject(p,'Разделка запрещена') end
 local environment=0
 if ST_EMISSION and ST_EMISSION.State and ST_EMISSION.State.phase>0 then environment=.25 end
 local custom=hook.Run('STB_EnvironmentPenalty',p,mutant);if type(custom)=='number' and custom==custom then environment=math.Clamp(custom,0,1) end
 local diff=B.Difficulty(B.Config.Mutants[d.class],part,cfg,profile.xp,B.Fatigue(profile),environment)
 local rounds={}
 for i=1,B.Config.Rounds do rounds[i]={center=math.Rand(.25,.75),width=math.Clamp(.55/diff,.18,.72),speed=math.Rand(2.6,3.8)*math.sqrt(diff),offset=math.Rand(0,math.pi*2)} end
 local s={token=math.random(1,2147483646),ent=mutant,tool=w,part=part,mutant=B.Config.Mutants[d.class],rounds=rounds,hits={},start=CurTime()+B.Config.LeadIn,
  lag=math.Clamp(p:Ping()/2000,0,.15),profile=profile,seconds=B.Config.RoundSeconds}
 -- Число разрезов и их длительность фиксируются в сессии: правка butcher.* в панели посреди разделки
 -- не должна давать индекс без раунда (ошибка в stb.hit) и делить счёт на другое число разрезов.
 s.ends=s.start+#rounds*s.seconds
 d.owner=p;d.consumed=true;d.parts[part.id]=true;mutant:SetNW2Int('stb_parts',15)
 p.StbAfter=CurTime()+B.Config.Cooldown;B.Sessions[p]=s;p:SetNW2Bool('stb_busy',true)
 B.Wear(p,w,cfg)
 -- Последняя единица прочности может убрать SWEP через ApplyEquipment: попытка отменится без лута.
 B.Send(p,{kind='start',token=s.token,start=s.start,ends=s.ends,rounds=rounds,seconds=s.seconds,title=s.mutant.name..' / '..part.name})
 if B.Config.Debug then B.Log('start '..p:SteamID64()..' '..part.id) end
 hook.Run('STB_Started',p,mutant,part.id);return true
end
local function finish(p,s)
 local score=0;for i=1,#s.rounds do score=score+(s.hits[i] or 0) end;score=score/#s.rounds
 local result=B.Roll(s.mutant,s.part,score);result.score=score
 local profile=table.Copy(s.profile);profile.xp=math.min(1000000,profile.xp+result.xp);profile.fatigue=math.min(100,B.Fatigue(profile)+8);profile.at=os.time()
 local job={id=STALKER_INV.UID(),owner=p:SteamID64(),result=result,profile=profile,player=p,ent=s.ent}
 B.Outbox[job.owner]=job;B.Release(p,s);B.RemoveCorpse(s.ent)
 B.Send(p,{kind='end',text=B.Config.Grades[result.grade].name..' / '..math.floor(score*100)..'%. Сохранение результата…'})
 if B.FlushResult then B.FlushResult(job) end
end
local function flush(job)
 if not B.StoreResult(job) then return end
 B.Outbox[job.owner]=nil
 local p=job.player;if IsValid(p) then
  local r=job.result
  if r.injury>0 and p:Alive() then local dmg=DamageInfo();dmg:SetDamage(r.injury);dmg:SetDamageType(DMG_SLASH);dmg:SetAttacker(game.GetWorld());dmg:SetInflictor(game.GetWorld());p:TakeDamageInfo(dmg) end
  local _,msg=B.Claim(p)
  B.Send(p,{kind='result',grade=r.grade,score=r.score,count=r.count,condition=r.durability,toxic=r.toxic,xp=r.xp,text=msg})
  if B.Config.Debug then B.Log('finish '..job.owner..' '..r.grade..' count='..r.count) end
  hook.Run('STB_Finished',p,job.ent,table.Copy(r))
 end
end
local function rate(p)
 if (p.StbNetAfter or 0)>CurTime() then return false end;p.StbNetAfter=CurTime()+.06;return true
end
net.Receive('stb.start',function(len,p)
 if len~=19 or not rate(p) then return end
 local ent=Entity(net.ReadUInt(16));local index=net.ReadUInt(3)
 B.startButchering(ent,p,nil,index)
end)
net.Receive('stb.hit',function(len,p)
 if len~=34 or not rate(p) then return end
 local token=net.ReadUInt(32);local index=net.ReadUInt(2);local s=B.Sessions[p]
 if not s or token~=s.token or index<1 or index>#s.rounds or s.hits[index]~=nil then return end
 if not access(p,s.ent) or p:GetActiveWeapon()~=s.tool then B.Cancel(p,'Условия разделки изменились');return end
 local t=CurTime()-s.lag-s.start-(index-1)*s.seconds
 if t<0 or t>s.seconds then return end
 local round=s.rounds[index];s.hits[index]=B.Score(B.Marker(t,round.speed,round.offset),round.center,round.width)
 B.Send(p,{kind='hit',index=index,score=s.hits[index]})
end)
net.Receive('stb.cancel',function(len,p)
 if len~=32 then return end
 local token=net.ReadUInt(32);local s=B.Sessions[p];if s and token==s.token then B.Cancel(p) end
end)
timer.Create('STB.Sessions',.1,0,function()
 for p,s in pairs(B.Sessions) do
  if not access(p,s.ent) or not IsValid(s.tool) or p:GetActiveWeapon()~=s.tool then B.Cancel(p,'Разделка прервана')
  elseif CurTime()>=s.ends+.2 then finish(p,s) end
 end
end)
B.FlushResult=flush
timer.Create('STB.SaveResults',1,0,function() for _,job in pairs(B.Outbox) do flush(job) end end)
for _,event in ipairs({'PlayerDeath','PlayerDisconnected','STEmissionUnconscious'}) do hook.Add(event,'STB.Cancel',function(p) B.Cancel(p,'Разделка прервана') end) end
hook.Add('PostCleanupMap','STB.CancelAll',function() for p in pairs(B.Sessions) do B.Cancel(p,'Очистка карты') end end)
hook.Add('ShutDown','STB.Flush',function() for _,job in pairs(B.Outbox) do B.StoreResult(job) end end)
hook.Add('PlayerUse','STB.Use',function(p,ent)
 if B.Sessions[p] or B.Corpses[ent] then return false end
end)
