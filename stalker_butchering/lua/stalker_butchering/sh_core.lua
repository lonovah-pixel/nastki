local B=STALKER_BUTCHERING
-- Не все версии выбросов экспортируют функцию в клиентский realm.
-- Проверяем API при обращении: порядок загрузки аддонов может отличаться.
function B.Unconscious(p)
 if not IsValid(p) then return false end
 if type(ST_EMISSION)=="table" and type(ST_EMISSION.IsUnconscious)=="function" then
  return ST_EMISSION.IsUnconscious(p)==true
 end
 -- Поддержка ранее используемого серверного сетевого дедлайна блэкаута.
 return p:Alive() and p:GetNW2Float("stem_unconscious_until",0)>CurTime()
end
function B.Marker(t,speed,offset) return .5+.46*math.sin(t*speed+offset) end
function B.Score(marker,center,width)
 return math.Clamp(1-math.abs(marker-center)/(width*.5),0,1)
end
function B.Grade(score)
 for _,id in ipairs(B.Order) do if score>=B.Config.Grades[id].threshold then return id end end
 return 'fail'
end
function B.ItemID(part,grade,toxic) return 'stb_'..part..'_'..grade..(toxic and '_toxic' or '_clean') end
function B.Difficulty(mutant,part,tool,xp,fatigue,environment)
 local skill=math.min(1,math.max(0,xp)/1000)
 return math.Clamp(mutant.difficulty*part.difficulty/tool.precision*(1+fatigue/150+environment)/(1+skill*.4),.55,2.8)
end
function B.Roll(mutant,part,score,random)
 random=random or math.Rand
 local grade=B.Grade(score);local g=B.Config.Grades[grade]
 local toxic=random(0,1)<mutant.toxicity*g.toxin
 local count=g.quantity>0 and math.max(1,math.floor(part.base*mutant.yield*g.quantity)) or 0
 if part.id=='rare' and random(0,1)>g.rare then count=0 end
 return {grade=grade,id=B.ItemID(part.id,grade,toxic),count=count,durability=g.condition,toxic=toxic,xp=g.xp,injury=g.injury}
end
-- Состояние input одинаково в обоих realms. Чужие Freeze/WalkSpeed не меняются.
hook.Add('StartCommand','STB.Input',function(p,cmd)
 if p:GetNW2Bool('stb_busy',false) then cmd:ClearButtons();cmd:ClearMovement();cmd:SetImpulse(0) end
end)
