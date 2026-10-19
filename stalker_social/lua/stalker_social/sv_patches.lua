-- STALKER Social: какие нашивки есть у игрока и какие он показывает. Группировка и звание — из STALKER Factions,
-- достижения — из статистики STALKER Core, награды — от лидера группировки. Видимые — NW2 stsoc_patches.
local S=STALKER_SOCIAL
local C=STALKER_CORE
local Cfg=S.Config

local function profile(ply)
 if not (STFW and STFW.Load) then return end
 local ok,d=pcall(STFW.Load,ply)
 if ok and type(d)=="table" then return d end
end
-- Звание по опыту (номер в STFW.Ranks) или nil без группировок.
function S.RankOf(ply)
 local d=profile(ply)
 if not d or not STFW.Rank then return end
 local n=STFW.Rank(tonumber(d.xp) or 0)
 if C.Int(n,1,S.RankCount()) then return n end
end

--[[ Все нашивки игрока: список {token, id, owned, value, goal, by} в порядке показа в КПК. ]]
function S.Collect(ply)
 local out={}
 local faction=C.Faction(ply)
 out[#out+1]={token="faction",id=faction and ("faction_"..faction) or nil,owned=faction~=nil}
 local rank=S.RankOf(ply)
 out[#out+1]={token="rank",id=rank and ("rank_"..rank) or nil,owned=rank~=nil}
 local data=S.LoadData(ply) or {awards={}}
 for _,a in ipairs(S.Awards) do
  local got=data.awards[a.id]
  out[#out+1]={token="award_"..a.id,id="award_"..a.id,owned=got~=nil and got.faction==faction,by=got and got.by or nil,faction=got and got.faction or nil}
 end
 local stats=C.GetStats and C.GetStats(ply) or {}
 for _,a in ipairs(S.Achievements) do
  local value=math.floor(tonumber(stats[a.stat]) or 0)
  out[#out+1]={token="ach_"..a.id,id="ach_"..a.id,owned=value>=a.goal,value=value,goal=a.goal}
 end
 return out
end
local function ownedMap(ply)
 local map={}
 for _,row in ipairs(S.Collect(ply)) do if row.owned then map[row.token]=row.id end end
 return map
end
-- Видимые нашивки: выбор игрока (только имеющиеся) или, пока он не выбирал, группировка, звание и награды.
function S.Visible(ply)
 local map=ownedMap(ply);local data=S.LoadData(ply)
 local list,seen={},{}
 local function add(t) if #list<Cfg.MaxPatches and map[t] and not seen[t] then seen[t]=true;list[#list+1]=map[t] end end
 if data and data.chosen then
  for _,t in ipairs(data.visible) do add(t) end
 else
  add("faction");add("rank")
  for _,a in ipairs(S.Awards) do add("award_"..a.id) end
  for _,a in ipairs(S.Achievements) do add("ach_"..a.id) end
 end
 return list
end
function S.RefreshPatches(ply)
 if not IsValid(ply) or not ply:IsPlayer() then return end
 local raw=table.concat(S.Visible(ply),",")
 if ply:GetNW2String("stsoc_patches","")~=raw then ply:SetNW2String("stsoc_patches",raw) end
 return raw
end

-- Состояние для вкладки КПК «Нашивки».
function S.SendPatchState(ply)
 local data=S.LoadData(ply)
 local visible={}
 for _,id in ipairs(S.Visible(ply)) do local info=S.PatchInfo(id);if info then visible[#visible+1]=info.token end end
 C.Send("stalker_social.patches",ply,{items=S.Collect(ply),visible=visible,chosen=data and data.chosen or false,max=Cfg.MaxPatches})
end
-- Выбор видимых нашивок (жетоны). Пустой список — ничего не показывать.
function S.SetVisible(ply,tokens)
 if type(tokens)~="table" or #tokens>Cfg.MaxPatches then return false,"Можно выбрать не больше "..Cfg.MaxPatches end
 local data=S.LoadData(ply);if not data then return false,"Профиль нашивок недоступен" end
 local map=ownedMap(ply);local list,seen={},{}
 for _,t in ipairs(tokens) do
  if not S.ValidToken(t) or not map[t] then return false,"Этой нашивки у вас нет" end
  if not seen[t] then seen[t]=true;list[#list+1]=t end
 end
 local copy=table.Copy(data);copy.visible=list;copy.chosen=true
 if not S.SaveData(ply,copy) then return false,"Ошибка записи" end
 S.DataCache[C.SID(ply)]=copy
 S.RefreshPatches(ply)
 return true
end

--[[ Награды лидера: лидер выдаёт или снимает награду члену своей группировки. ]]
function S.LeaderFaction(ply)
 if not (STFW and STFW.IsLeader) then return end
 local ok,leader=pcall(STFW.IsLeader,ply)
 if not ok or not leader then return end
 return C.Faction(ply)
end
function S.ToggleAward(leader,target,id)
 local award=S.AwardByID[id or ""];if not award then return false,"Неизвестная награда" end
 local faction=S.LeaderFaction(leader)
 if not faction then return false,"Награждать может только лидер группировки" end
 if target==leader then return false,"Себя наградить нельзя" end
 if not (STFW.IsMember and STFW.IsMember(target,faction)) then return false,"Сталкер не состоит в вашей группировке" end
 local data=S.LoadData(target);if not data then return false,"Профиль нашивок недоступен" end
 local copy=table.Copy(data)
 local had=copy.awards[id]~=nil and copy.awards[id].faction==faction
 if had then copy.awards[id]=nil
 else copy.awards[id]={faction=faction,by=leader:Nick():sub(1,64),bySid=C.SID(leader) or "",at=os.time()} end
 if not S.SaveData(target,copy) then return false,"Ошибка записи" end
 S.DataCache[C.SID(target)]=copy
 S.RefreshPatches(target)
 hook.Run("STALKER_SOCIAL_Awarded",leader,target,id,not had)
 return true,not had
end

-- Смена группировки и звания, возрождение, периодический пересчёт достижений.
local function later(ply) timer.Simple(0,function() if IsValid(ply) then S.RefreshPatches(ply) end end) end
hook.Add("STFW_FactionChanged","STALKER_SOCIAL.Patches",later)
hook.Add("STFW_FactionLeft","STALKER_SOCIAL.Patches",later)
hook.Add("PlayerSpawn","STALKER_SOCIAL.Patches",later)
timer.Create("STALKER_SOCIAL.Patches",Cfg.RefreshSeconds,0,function()
 for _,p in ipairs(player.GetHumans()) do S.RefreshPatches(p) end
end)
