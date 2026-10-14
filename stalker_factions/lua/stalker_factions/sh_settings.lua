-- Настройки группировок в общей админ-панели (STALKER_SETTINGS). Регистрируются в обоих realm:
-- клиенту нужны взнос, лимиты, стоимость способностей и радиус радара для подсказок и HUD.
local F=STFW
local S=STALKER_SETTINGS
if not S or not S.Bind then return end
local CAT="Группировки"
local order=0
local function bind(id,tbl,key,def)
 order=order+1
 def.category=CAT;def.realm="shared";def.order=def.order or order;def.type=def.type or "number"
 return S.Bind("factions."..id,tbl,key,def)
end
local cfg=F.Config

-- Вступление и состав.
bind("join_fee",cfg,"JoinFee",{label="Взнос за вступление, ₽",description="Одиночки вступают бесплатно; допуск или приглашение лидера освобождает от взноса.",min=0,max=10000000})
bind("max_members",cfg,"MaxMembers",{label="Лимит состава группировки",description="Сколько профилей может состоять в группировке (0 — без лимита). Полная группировка не принимает новых членов.",min=0,max=500})
local ids={};for id,f in pairs(F.Factions) do if f.playable then ids[#ids+1]=id end end;table.sort(ids)
for _,id in ipairs(ids) do
 bind("cap_"..id,cfg.JoinCaps,id,{label="Лимит состава: "..F.Name(id),description="0 — общий лимит состава.",min=0,max=500})
end
bind("invite_seconds",cfg,"InviteSeconds",{label="Время ответа на приглашение, с",min=10,max=600})
bind("ban_cost",cfg,"LeaderBanCost",{label="Цена запрета вступления от лидера, ₽",description="Списывается с кошелька лидера; запрет действует, пока лидер не сменится.",min=0,max=1000000000})

-- Захват территорий.
bind("capture_action",cfg,"CaptureActionSeconds",{label="Время действия на флаге для начала захвата, с",min=1,max=120})
bind("defend_action",cfg,"DefendActionSeconds",{label="Время сброса захвата защитником, с",min=1,max=120})
bind("capture_window",cfg,"CaptureWindow",{label="Окно захвата без атакующих на точке, с",description="Если все атакующие покинули точку дольше окна, захват сбрасывается.",min=10,max=3600})
bind("capture_seconds",cfg,"CaptureSeconds",{label="Время захвата точки одним бойцом, с",min=5,max=1800})
bind("max_contributors",cfg,"MaxContributors",{label="Максимум бойцов, ускоряющих захват",min=1,max=16})

-- Доход территорий.
bind("income_interval",cfg,"IncomeInterval",{label="Интервал дохода территорий, с",min=10,max=3600})
local kinds={{"base","База"},{"camp","Лагерь"},{"resource","Ресурсная точка"},{"checkpoint","Блокпост"}}
for _,row in ipairs(kinds) do bind("income_"..row[1],cfg.PointIncome,row[1],{label="Доход: "..row[2]..", ₽ за интервал",min=0,max=1000000}) end
bind("supply_per_point",cfg,"SupplyPerTerritory",{label="Очки снабжения с точки за интервал",min=0,max=1000})
bind("loner_free_income",cfg,"LonerIncomeFreeStalkers",{type="bool",label="Доход точек одиночек получают и вольные сталкеры",description="Выключено — делится только между вступившими одиночками."})

-- Война и защита.
bind("spawn_protection",cfg,"SpawnProtection",{label="Защита после возрождения, с",min=0,max=120})
bind("victory_score",cfg,"VictoryScore",{label="Очки победы в войне",min=10,max=100000})
bind("capture_score",cfg,"CaptureScore",{label="Очки войны за захват точки",min=0,max=10000})
bind("kill_score",cfg,"KillScore",{label="Очки войны за убийство",min=0,max=10000})
bind("control_score",cfg,"ControlScore",{label="Очки войны за точку за интервал",min=0,max=10000})
bind("radar_range",cfg,"RadarRange",{label="Радиус радара, units",min=500,max=10000})

-- Способности командования.
for _,id in ipairs(F.AbilityOrder) do
 local a=F.Abilities[id]
 bind("ability_"..id.."_cooldown",a,"cooldown",{label="«"..a.name.."»: перезарядка, с",min=10,max=86400})
 bind("ability_"..id.."_cost",a,"cost",{label="«"..a.name.."»: стоимость, очков снабжения",min=0,max=100000})
 bind("ability_"..id.."_rank",a,"minRank",{type="choice",label="«"..a.name.."»: кто применяет",choices={{"officer","Офицеры и лидер"},{"leader","Только лидер"}}})
end
