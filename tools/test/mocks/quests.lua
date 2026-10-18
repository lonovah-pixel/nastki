-- STALKER Quests в общих сценариях: обучение «Путь новичка» выключено (как будто администратор выключил его в настройках),
-- чтобы награды за шаги не меняли деньги и рюкзаки игроков чужих проверок. Сценарий 37_quests включает его сам.
if SERVER then
 sql.Query("CREATE TABLE IF NOT EXISTS stalker_settings (id TEXT PRIMARY KEY, value TEXT NOT NULL)")
 sql.Query("REPLACE INTO stalker_settings VALUES('quests.tutorial','{\"v\":false}')")
end
