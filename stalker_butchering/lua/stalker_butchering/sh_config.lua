local B=STALKER_BUTCHERING
B.Config={Distance=120,CorpseLifetime=300,MaxCorpses=64,Cooldown=3,Rounds=3,RoundSeconds=2.2,LeadIn=.8,
 CancelOnDamage=true,MaxWeight=50,Debug=false,TraderIDs={sidor=true},
 Sounds={open='buttons/button14.wav',hit='buttons/button15.wav',finish='buttons/button9.wav'},
 -- Классы из базового HL2. Не распознаём произвольный ragdoll по одной модели.
 Mutants={
  npc_zombie={name='Зомби',difficulty=1.05,toxicity=.55,yield=1},
  npc_fastzombie={name='Быстрый зомби',difficulty=1.3,toxicity=.65,yield=1},
  npc_poisonzombie={name='Ядовитый зомби',difficulty=1.5,toxicity=.95,yield=1.2},
  npc_headcrab={name='Хедкраб',difficulty=.85,toxicity=.35,yield=.65},
  npc_headcrab_fast={name='Быстрый хедкраб',difficulty=1.05,toxicity=.4,yield=.65},
  npc_headcrab_black={name='Ядовитый хедкраб',difficulty=1.4,toxicity=.95,yield=.75},
  npc_antlion={name='Муравьиный лев',difficulty=1.15,toxicity=.25,yield=1.4},
  npc_antlionguard={name='Страж муравьиных львов',difficulty=1.6,toxicity=.35,yield=2}},
 Tools={weapon_crowbar={name='Монтировка',precision=.75,wear=7}},
 Parts={
  {id='meat',name='Мясо',difficulty=.8,base=3,weight=.35,price=65,model='models/Gibs/Antlion_gib_small_2.mdl'},
  {id='hide',name='Шкура',difficulty=1.1,base=1,weight=.65,price=180,model='models/props_junk/cardboard_box004a.mdl'},
  {id='organ',name='Орган',difficulty=1.3,base=1,weight=.25,price=240,model='models/Gibs/HGIBS.mdl'},
  {id='rare',name='Редкий компонент',difficulty=1.6,base=1,weight=.15,price=650,model='models/Gibs/Antlion_gib_small_3.mdl'}},
 Grades={
  perfect={name='Идеально',threshold=.85,quantity=1.4,condition=100,toxin=.2,rare=.8,xp=18,injury=0},
  success={name='Успех',threshold=.60,quantity=1,condition=80,toxin=.5,rare=.35,xp=12,injury=0},
  partial={name='Частично',threshold=.30,quantity=.5,condition=45,toxin=.8,rare=.08,xp=5,injury=3},
  fail={name='Провал',threshold=0,quantity=0,condition=0,toxin=1,rare=0,xp=1,injury=8}}
}
B.Order={'perfect','success','partial','fail'}
