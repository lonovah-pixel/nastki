-- Связь с другими аддонами сборки (оба realm): репутация за мутантов и названия туш при разделке.
local Z=STALKER_ZONE
function Z.LinkMutants()
 for _,m in pairs(Z.Mutants) do
  if STFW and STFW.Config and STFW.Config.MutantClasses then STFW.Config.MutantClasses[m.class]=m.faction end
  local B=STALKER_BUTCHERING
  if B and B.Config and B.Config.Mutants and B.Config.Mutants[m.class] then B.Config.Mutants[m.class].name=m.name end
 end
end
Z.LinkMutants()
