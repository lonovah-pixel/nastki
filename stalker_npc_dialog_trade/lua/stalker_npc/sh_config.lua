local N=STALKER_NPC
N.Config={
    Economy="darkrp", -- Основной кошелёк DarkRP; dummy — только для тестов Sandbox.
    DummyStart=5000, MaxBalance=100000000, Distance=160, SessionSeconds=120,
    QuoteSeconds=15, MaxLines=12, MaxStockSlots=40, EnforceWeight=true, Debug=false,
    SoundOpen="buttons/button14.wav",SoundClick="buttons/button15.wav",SoundTrade="buttons/button9.wav",
    Traders={
        sidor={name={ru="Сидорович",en="Sidorovich"}, role={ru="Торговец • Кордон",en="Trader • Cordon"},
            model="models/Humans/Group01/male_07.mdl", root="greeting",
            info={ru="Еда, медикаменты, снаряжение. Цены зависят от состояния. Покупаю только товары своего ассортимента.",en="Food, medicine and equipment. Prices reflect condition. I only buy listed goods."},
            prices={antirad={buy=800,sell=300},hazmat={buy=8000,sell=3000},medkit={buy=500,sell=250},bandage={buy=100,sell=40},water={buy=120,sell=50},food={buy=150,sell=65},
                ammo_pistol={buy=80,sell=30},pistol={buy=1500,sell=600},rifle={buy=4000,sell=1700},jacket={buy=2200,sell=900},scrap={buy=25,sell=10}},
            stock={{"antirad",10},{"hazmat",2},{"medkit",10},{"bandage",20},{"water",10},{"food",10},{"ammo_pistol",30},{"pistol",1},{"rifle",1},{"jacket",1}},
            nodes={
                greeting={text={ru="Заходи, сталкер. Если есть товар — выкладывай. Если нужны припасы — договоримся.",en="Come in, stalker. Got something to sell? Put it on the table. Need supplies? Let's deal."},choices={
                    {id="trade",text={ru="Покажи, что у тебя есть.",en="Show me your goods."},action="trade"},
                    {id="news",text={ru="Что слышно в Зоне?",en="Any news from the Zone?"},next="news"},
                    {id="scrap",text={ru="У меня есть детали на продажу.",en="I have scrap to sell."},action="trade",requires={item="scrap",count=1}},
                    {id="bye",text={ru="Бывай.",en="See you."},action="close"}}},
                news={text={ru="После выброса тропы изменились. Не ходи один и держи аптечку под рукой. Остальное узнаешь сам.",en="The paths changed after the emission. Don't travel alone. Keep a medkit close. You'll learn the rest out there."},choices={
                    {id="back",text={ru="Понятно. Вернёмся к делу.",en="Understood. Back to business."},next="greeting"}}}
            }
        }
    }
}
-- Размещённые NPC сохраняются админ-командой stnpc_save в data/stalker_npc/.
