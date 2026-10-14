-- Реестр вкладок КПК. Аддоны регистрируют вкладки в любой момент загрузки; окно КПК (stalker_pda) строит их при открытии.
local C=STALKER_CORE
C.PDATabs=C.PDATabs or {}
--[[ def: title — подпись; order — порядок (меньше — левее); build(parent) — заполнить панель вкладки;
 badge() — число для значка (непрочитанное) или nil; visible() — false, чтобы скрыть вкладку ]]
function C.RegisterPDATab(id,def)
 assert(type(id)=="string" and type(def)=="table" and type(def.build)=="function","RegisterPDATab: нужен id и build")
 def.id=id;def.order=def.order or 100;def.title=def.title or id
 C.PDATabs[id]=def
 hook.Run("STALKER_PDATabsChanged")
end
function C.PDATabList()
 local list={}
 for _,def in pairs(C.PDATabs) do if not def.visible or def.visible()~=false then list[#list+1]=def end end
 table.sort(list,function(a,b) if a.order~=b.order then return a.order<b.order end;return a.id<b.id end)
 return list
end
-- Открыть КПК на вкладке (реализует аддон stalker_pda; без него — ничего не делает).
function C.OpenPDA(tab) if C.PDAOpen then C.PDAOpen(tab) end end
