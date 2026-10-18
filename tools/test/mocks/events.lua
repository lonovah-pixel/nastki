-- STALKER Events в общих сценариях: планировщик выключен (как будто администратор выключил его в настройках),
-- чтобы случайное событие не вмешивалось в чужие проверки. Сценарий 34_events включает его сам и возвращает выключенным.
if SERVER then
 sql.Query("CREATE TABLE IF NOT EXISTS stalker_settings (id TEXT PRIMARY KEY, value TEXT NOT NULL)")
 sql.Query("REPLACE INTO stalker_settings VALUES('events.scheduler','{\"v\":false}')")
end
