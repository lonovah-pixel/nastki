-- Характеристики предметов в понятном виде: подпись, значение со знаком «%», полоса.
-- Реестр S.StatFormat используют карточка предмета, подсказка, экипировка и окна других аддонов.
local S=STALKER_INV
S.StatFormat=S.StatFormat or {}
local F=S.StatFormat
--[[ def: label — подпись; kind — percent (10 → «10%»), fraction (0.25 → «25%»), number (число), speed (проценты со знаком);
 max — значение, при котором полоса заполнена; unit/decimals/prefix — оформление числа;
 cond=true — защита, которая падает с износом снаряжения (S.ConditionFactor);
 bad=true — чем больше, тем хуже (вес, радиация); order — порядок строк. ]]
function S.RegisterStatFormat(key,def)
 assert(type(key)=="string" and type(def)=="table","RegisterStatFormat: ключ и описание")
 def.kind=def.kind or "number";def.max=def.max or 100;def.order=def.order or 50
 F[key]=def
end
local reg=S.RegisterStatFormat
reg("armor",{label="Очки брони",kind="number",max=150,order=1})
reg("bulletResist",{label="Пулестойкость",kind="percent",max=40,order=2,cond=true})
reg("strikeResist",{label="Удары и разрыв",kind="percent",max=40,order=3,cond=true})
reg("burnResist",{label="Термозащита",kind="percent",max=50,order=4,cond=true})
reg("shockResist",{label="Электрозащита",kind="percent",max=50,order=5,cond=true})
reg("chemResist",{label="Химзащита",kind="percent",max=50,order=6,cond=true})
reg("blastResist",{label="Защита от взрыва",kind="percent",max=40,order=7,cond=true})
reg("radiationProtection",{label="Защита от радиации",kind="fraction",max=1,order=8,cond=true})
reg("headshot",{label="Защита головы",kind="percent",max=60,order=9,cond=true})
reg("protection",{label="Защита",kind="percent",max=50,order=10,cond=true})
reg("fallResist",{label="Защита при падении",kind="percent",max=50,order=11,cond=true})
reg("speed",{label="Скорость",kind="speed",max=30,order=12})
reg("weight",{label="Вес",kind="number",unit=" кг",decimals=1,max=15,order=13,bad=true})
reg("health",{label="Здоровье",kind="number",prefix="+",max=100,order=20})
reg("hunger",{label="Сытость",kind="number",prefix="+",max=100,order=21})
reg("thirst",{label="Вода",kind="number",prefix="+",max=100,order=22})
reg("rounds",{label="Патроны",kind="number",max=60,order=23})
reg("damage",{label="Урон",kind="number",max=60,order=24})
reg("radiation",{label="Радиация",kind="number",unit="/с",decimals=2,max=1,order=25,bad=true,signed=true})
reg("regen",{label="Регенерация",kind="number",unit=" HP/с",decimals=1,max=3,order=26})
reg("condition",{label="Состояние",kind="percent",max=100,order=27})

local function round(v,d) local m=10^(d or 0);return math.floor(v*m+.5)/m end
local function number(v,d)
 v=round(v,d or 0)
 if v%1==0 then return string.format("%d",v) end
 return (string.format("%."..(d or 2).."f",v):gsub("0+$",""))
end
-- Подпись неизвестной характеристики: реестр инвентаря, затем подписи Зоны (без хвоста «, %»).
local function fallbackLabel(key)
 if S.StatNames and S.StatNames[key] then return S.StatNames[key] end
 local Z=STALKER_ZONE;local name=Z and Z.StatNames and Z.StatNames[key]
 if name then return (tostring(name):gsub(",[^,]*$","")) end
 return key
end
--[[ Текст значения, подпись, доля полосы (0–1) и токен цвета темы. ]]
function S.FormatStat(key,value)
 local f=F[key];value=tonumber(value) or 0
 if not f then return number(value,2),fallbackLabel(key),nil,"text" end
 local text,ratio
 if f.kind=="fraction" then text=number(value*100,value*100<10 and 1 or 0).."%";ratio=value/f.max
 elseif f.kind=="percent" then text=number(value,math.abs(value)<10 and 1 or 0).."%";ratio=value/f.max
 elseif f.kind=="speed" then text=(value>0 and "+" or value<0 and "−" or "")..number(math.abs(value)).."%";ratio=math.abs(value)/f.max
 else
  local sign=f.prefix or ((f.signed and value>0) and "+" or "")
  text=sign..number(value,f.decimals or 0)..(f.unit or "");ratio=value/f.max
 end
 local token="accent"
 if f.kind=="speed" then token=value<0 and "danger" or "ok"
 elseif f.bad then token=value>0 and "warn" or "ok"
 elseif f.cond then token="ok" end
 return text,f.label,math.Clamp(ratio,0,1),token
end
--[[ Строки характеристик предмета (с учётом износа и остатка очков брони):
 {key,label,text,ratio,token,order,nominal} — nominal: текст номинала, если износ снизил значение. ]]
function S.ItemStats(item,d)
 d=d or (type(item)=="table" and S.Items[item.id]);if not d then return {} end
 local gear=S.WearCategories[d.category]
 local factor=gear and type(item)=="table" and S.ConditionFactor(item) or 1
 local rows={}
 local function add(key,shown,nominal)
  local text,label,ratio,token=S.FormatStat(key,shown)
  local f=F[key]
  local row={key=key,label=label,text=text,ratio=ratio,token=token,order=f and f.order or 99}
  if math.abs((nominal or shown)-shown)>1e-6 then row.nominal=(S.FormatStat(key,nominal)) end
  rows[#rows+1]=row
 end
 for key,value in pairs(d.stats or {}) do
  if type(value)=="number" then
   local f=F[key]
   if key=="armor" and type(item)=="table" and tonumber(item.armor) then add(key,math.min(value,tonumber(item.armor)),value)
   elseif f and f.cond and gear then add(key,value*factor,value)
   else add(key,value,value) end
  end
 end
 if gear then add("weight",d.weight,d.weight) end
 table.sort(rows,function(a,b) if a.order~=b.order then return a.order<b.order end;return a.key<b.key end)
 return rows
end
--[[ Сводная защита надетого снаряжения (с износом): {[ключ]=значение}. Только для показа игроку. ]]
function S.GearSummary(inv)
 local out={}
 if type(inv)~="table" or type(inv.equipment)~="table" then return out end
 for _,item in pairs(inv.equipment) do
  local d=S.Items[item.id]
  if d and (tonumber(item.durability) or 0)>0 then
   local factor=S.WearCategories[d.category] and S.ConditionFactor(item) or 1
   for key,value in pairs(d.stats or {}) do
    local f=F[key]
    if type(value)=="number" and f and f.cond then out[key]=(out[key] or 0)+value*factor end
   end
  end
 end
 return out
end
