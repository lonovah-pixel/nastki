-- Параметры торговцев в общей админ-панели (STALKER_SETTINGS, раздел «Торговля»).
local N=STALKER_NPC
local S=STALKER_SETTINGS;if not S then return end
local cat="Торговля"
S.Bind("trade.distance",N.Config,"Distance",{category=cat,label="Дистанция разговора с торговцем, юниты",type="number",min=80,max=400,realm="shared",order=50})
S.Bind("trade.session_seconds",N.Config,"SessionSeconds",{category=cat,label="Сессия торговли без действий, сек",type="number",min=30,max=900,order=51})
S.Bind("trade.quote_seconds",N.Config,"QuoteSeconds",{category=cat,label="Срок действия цены сделки, сек",type="number",min=5,max=120,order=52})
S.Bind("trade.max_lines",N.Config,"MaxLines",{category=cat,label="Позиций в одной сделке",type="number",min=1,max=40,realm="shared",order=53})
S.Bind("trade.enforce_weight",N.Config,"EnforceWeight",{category=cat,label="Покупка ограничена весом рюкзака",type="bool",realm="shared",order=54})
