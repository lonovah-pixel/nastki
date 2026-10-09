-- Единая проверка параметров новой и существующей точки.
local F=STFW
F.PointTypes={checkpoint={ru="Блокпост",en="Checkpoint"},base={ru="База",en="Base"},camp={ru="Лагерь",en="Camp"},resource={ru="Ресурсная точка",en="Resource point"}}
function F.PointFields(a)
 if type(a.name)~="string" then return nil,"point_name" end
 local name=a.name:match("^%s*(.-)%s*$")
 if #name<1 or #name>128 or name:find("[%c]") then return nil,"point_name" end
 if not F.PointTypes[a.pointType or "checkpoint"] or not F.Int(a.radius,100,1500) or not F.Int(a.height,64,512) or not F.Int(a.radiation,0,100) or not F.Int(a.anomaly,0,100) or type(a.base)~="boolean" then return nil,"point_values" end
 return {name=name,kind=a.pointType or "checkpoint",radius=a.radius,height=a.height,radiation=a.radiation,anomaly=a.anomaly,base=a.base or a.pointType=="base"}
end
