-- NPC событий: мутанты из каталога STALKER Zone (без него — базовые NPC HL2), отряды военных,
-- награда DarkRP (KillValue) и её множитель во время «Гона».
local E=STALKER_EVENTS
local Cfg=E.Config
-- Без STALKER Zone: мутанты из базового HL2 с наградой по умолчанию.
E.FallbackMutants={
 zombie={class="npc_zombie",name="Зомбированный",reward=40},
 snork={class="npc_fastzombie",name="Снорк",reward=70},
 tushkan={class="npc_headcrab",name="Тушкан",reward=15},
 blinddog={class="npc_antlion",name="Слепой пёс",reward=45},
}
-- Сильные мутанты не охраняют грузы и выходят только в последней волне гона.
E.BossMutants={chimera=true}
E.RewardMult=1

function E.MutantCatalog()
 local Z=STALKER_ZONE
 if Z and type(Z.Mutants)=="table" and next(Z.Mutants) then return Z.Mutants end
 return E.FallbackMutants
end
-- Ключ мутанта: из allowed (набор ключей) или из всего каталога; boss — разрешить сильных.
function E.PickMutant(allowed,boss)
 local cat=E.MutantCatalog();local keys={}
 for key,def in pairs(cat) do
  if type(def)=="table" and def.class and (boss or not E.BossMutants[key]) and (not allowed or allowed[key]) then keys[#keys+1]=key end
 end
 if #keys==0 and allowed then return E.PickMutant(nil,boss) end
 table.sort(keys)
 return keys[math.random(#keys)]
end

function E.CountNPC()
 local n=0
 for _,ev in pairs(E.Active) do for _,npc in ipairs(ev.npcs) do if IsValid(npc) and npc:Health()>0 then n=n+1 end end end
 return n
end
function E.AliveNPC(ev)
 local out={}
 for _,npc in ipairs(ev.npcs) do if IsValid(npc) and npc:Health()>0 then out[#out+1]=npc end end
 ev.npcs=out
 return out
end

--[[ opts: model, keys={keyvalue=значение}, reward (KillValue), health (множитель), name (NW2 подпись), mutant (ключ каталога) ]]
function E.SpawnNPC(ev,class,pos,opts)
 opts=opts or {}
 if E.CountNPC()>=Cfg.MaxNPC or not pos then return end
 local npc=ents.Create(class);if not IsValid(npc) then return end
 if opts.model and util.IsValidModel(opts.model) then npc:SetModel(opts.model) end
 for k,v in pairs(opts.keys or {}) do npc:SetKeyValue(k,tostring(v)) end
 npc:SetPos(pos+Vector(0,0,6));npc:SetAngles(Angle(0,math.random(0,359),0))
 npc:Spawn();npc:Activate()
 if not IsValid(npc) then return end
 if opts.health and npc:Health()>0 then local hp=math.floor(npc:Health()*opts.health);npc:SetMaxHealth(hp);npc:SetHealth(hp) end
 npc.StalkerEvent=ev.id;npc.KillValue=opts.reward
 if opts.mutant then npc.StalkerMutant=opts.mutant end
 if opts.name then npc:SetNW2String("stz_mutant",opts.name) end
 ev.npcs[#ev.npcs+1]=npc
 return npc
end
function E.SpawnMutant(ev,pos,key)
 local def=E.MutantCatalog()[key or ""];if not def then return end
 return E.SpawnNPC(ev,def.class,pos,{reward=def.reward,health=def.health,name=def.name,mutant=key})
end

-- Отправить NPC бегом к точке (движок GMod: SetLastPosition + SCHED_FORCED_GO_RUN).
function E.Steer(npc,pos)
 local sched=rawget(_G,"SCHED_FORCED_GO_RUN")
 if not IsValid(npc) or not pos or not sched or not npc.SetLastPosition or not npc.SetSchedule then return false end
 if npc.GetEnemy and IsValid(npc:GetEnemy()) then return false end
 npc:SetLastPosition(pos);npc:SetSchedule(sched)
 return true
end
function E.NearestPlayer(pos,range)
 local best,bestD
 for _,p in ipairs(player.GetHumans()) do
  if p:Alive() then local d=p:GetPos():DistToSqr(pos);if d<=range*range and (not bestD or d<bestD) then best,bestD=p,d end end
 end
 return best
end
-- Отношение NPC к игроку (D_LI — союзник, D_HT — враг), если движок это поддерживает.
function E.Relate(npc,ply,disposition)
 local d=rawget(_G,disposition)
 if IsValid(npc) and IsValid(ply) and d and npc.AddEntityRelationship then npc:AddEntityRelationship(ply,d,99) end
end

-- DarkRP платит за NPC по KillValue (GM:calculateNPCKillPay); во время гона мутанты дороже.
hook.Add("calculateNPCKillPay","STALKER_EVENTS.Reward",function(ply,npc)
 if (E.RewardMult or 1)<=1 or not IsValid(npc) or not npc.StalkerMutant then return end
 local base=npc.KillValue or (GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.npckillpay) or 0
 return math.floor(base*E.RewardMult)
end)
hook.Add("OnNPCKilled","STALKER_EVENTS.Kill",function(npc,attacker)
 if not IsValid(npc) then return end
 local ev=npc.StalkerEvent and E.Active[npc.StalkerEvent]
 -- Во время гона участником считается любой охотник на мутантов, не только на мутантов события.
 if not ev and npc.StalkerMutant and E.Active.hunt then ev=E.Active.hunt end
 if not ev or not IsValid(attacker) or not attacker:IsPlayer() then return end
 -- Боец рейда, убитый союзником-«Военным», — не участие в событии (как и не награда, см. E.RaidAlly).
 if E.RaidAlly and E.RaidAlly(attacker,npc) then return end
 E.Participate(ev,attacker)
 ev.kills=(ev.kills or 0)+1
 if ev.def.onKill then pcall(ev.def.onKill,ev,npc,attacker) end
end)
