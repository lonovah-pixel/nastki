local B=STALKER_BUTCHERING
B.Corpses={}
function B.RegisterCorpse(rag,class)
 if not IsValid(rag) or not B.Config.Mutants[class] or B.Corpses[rag] then return false end
 if table.Count(B.Corpses)>=B.Config.MaxCorpses then return false end
 local d={class=class,parts={},expires=CurTime()+B.Config.CorpseLifetime}
 B.Corpses[rag]=d;rag:SetNW2String('stb_mutant',class);rag:SetNW2Int('stb_parts',0)
 return true
end
local function serverRagdoll(ent)
 if IsValid(ent) and ent:IsNPC() and B.Config.Mutants[ent:GetClass()] then ent:SetShouldServerRagdoll(true) end
end
hook.Add('OnEntityCreated','STB.RagdollMode',function(ent) timer.Simple(0,function() serverRagdoll(ent) end) end)
hook.Add('InitPostEntity','STB.ExistingNPCs',function() for _,ent in ipairs(ents.GetAll()) do serverRagdoll(ent) end end)
hook.Add('EntityTakeDamage','STB.DeathPreparation',function(ent,dmg)
 serverRagdoll(ent)
 if ent:IsPlayer() and B.Config.CancelOnDamage and dmg:GetDamage()>0 and B.Cancel then B.Cancel(ent,'Разделка прервана уроном') end
end)
hook.Add('CreateEntityRagdoll','STB.NativeCorpse',function(npc,rag)
 if IsValid(npc) and npc:IsNPC() then B.RegisterCorpse(rag,npc:GetClass()) end
end)
hook.Add('OnNPCKilled','STB.Kill',function(npc)
 -- Не начисляем повторно фракционную репутацию за убийство.
 if B.Config.Mutants[npc:GetClass()] then hook.Run('STB_MutantKilled',npc) end
end)
hook.Add('EntityRemoved','STB.CorpseRemoved',function(ent)
 local d=B.Corpses[ent];if not d then return end
 if IsValid(d.owner) and B.Cancel then B.Cancel(d.owner,'Туша удалена') end
 B.Corpses[ent]=nil
end)
timer.Create('STB.CorpseExpiry',5,0,function()
 for ent,d in pairs(B.Corpses) do
  if not IsValid(ent) then B.Corpses[ent]=nil
  elseif CurTime()>=d.expires and not IsValid(d.owner) then
   -- Отключаем лут; удаление тела остаётся за движком/аддоном мутантов.
   ent:SetNW2String('stb_mutant','');B.Corpses[ent]=nil
  end
 end
end)
