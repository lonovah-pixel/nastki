# STALKER Core

Общие системы сборки. Загружается первым (`lua/autorun/00_stalker_core.lua`) и даёт остальным
аддонам единые контракты: тему оформления, реестр настроек для админ-панели, метки мира, ленту
новостей, статистику, действие «удерживайте E» и реестр вкладок КПК.

## Тема оформления (клиент)

* `STALKER_THEME.C.<токен>` — текущая палитра: `bg`, `panel`, `panel2`, `line`, `lineHi`, `text`, `muted`,
  `accent`, `accent2`, `ok`, `warn`, `danger`, `info`, `track`, `shadow`, `highlight`.
* `STALKER_THEME.Color(token, alpha)`, `STALKER_THEME.Px(n)` — масштаб под высоту экрана.
* Темы: `zone` (по умолчанию, графит и янтарь), `classic` (латунь первого выпуска), `pda` (зелёный монохром),
  `frost` (сталь и бирюза). Игрок: `stalker_theme <тема|auto>`; тема сервера — настройка `core.theme`.
* Хук `STALKER_ThemeChanged(theme, name)`.
* Шрифты: `STALKER.Title`, `STALKER.Head`, `STALKER.Body`, `STALKER.Small`, `STALKER.Mono`, `STALKER.Big`.
* `STALKER_STYLE`: `Panel`, `Frame`, `Bar`, `Entry`, `Combo`, `Scroll`, `Texture` (совместимы со старыми аддонами)
  и новые `Text`, `Fit`, `Wrap`, `Button(parent,label,onClick,kind)`, `Label`, `Window{title,w,h,look,onClose}`.

## Настройки (`STALKER_SETTINGS`, оба realm)

```lua
STALKER_SETTINGS.Bind("zone.max_artifacts", Z.Config, "MaxArtifacts",
  {category="Артефакты", label="Лимит артефактов на карте", type="number", min=0, max=200})
STALKER_SETTINGS.Register("id", {category, label, description, type="number|bool|string|choice",
  min, max, step, decimals, choices={{value,"подпись"}}, default, get, set, realm="server|shared", order, onChange})
```

Регистрируйте в общем (shared) файле, если значение нужно клиенту (`realm="shared"`). Переопределения
хранятся в SQLite `stalker_settings` и применяются при регистрации. Сервер: `Set(id, value, ply)`
(nil — сброс), `Get(id)`, `List()`. Клиент: `RequestList(cb)`, `RequestSet(id, value)`, `RequestReset(id)`.
Консоль: `stalker_setting [id] [значение|default]`. Хук `STALKER_SettingChanged(id, new, old, ply)`.
Право доступа — `settings`.

## Метки (`STALKER_MARKERS`)

Сервер: `Set(id, {pos, label, kind, color, icon, world, edge, map, hud, range, visible, expires, owner, radius})`
(`hud=false` — только на карте КПК, без значка на экране),
`Remove(id)`, `Get(id)`, `Clear(prefix)`, `VisibleTo(marker, ply)`.
`visible`: `"all"` или `{players={[sid]=true}, faction="duty", factions={duty=true}, admins=true, check=function(ply) end}`.
Типы (`kind`): `poi`, `flag`, `beacon`, `cargo`, `event`, `quest`, `stash`, `rally`, `enemy`, `trader`.
Клиент: `All()`, `SetLocal(id, data)`, `RemoveLocal(id)`; хук `STALKER_MarkersUpdated(list)`.
Клиент сам рисует значки и расстояние на экране, стрелки у края (`edge`) и флажки в мире (`world`).

## Удержание E (`STALKER_CORE.Hold`, сервер)

`Hold.Start(ply, ent, seconds, label, onDone(ply, ent), {range, look, onCancel, check})` — прерывается,
если игрок отпустил E, отошёл, отвернулся, погиб или потерял сознание. Полосу прогресса рисует ядро.

## Новости, уведомления, статистика

* Сервер: `STALKER_CORE.News(text, kind, targets)` — лента КПК (kind: info, emission, event, war, capture,
  quest, trade, danger); `STALKER_CORE.Notify(target, text, kind, seconds)` — всплывающее уведомление.
* Статистика: `STALKER_CORE.AddStat(ply, key, amount)`, `GetStats(ply)`; ключи и подписи — `STALKER_CORE.StatNames`.
  Ядро само считает убийства, смерти, мутантов, артефакты, пережитые выбросы и время в Зоне.
* Клиент: `STALKER_CORE.NewsFeed`, `Toast(text, kind, seconds)`, `RequestStats(topKey, cb)`.

## Вкладки КПК (клиент)

`STALKER_CORE.RegisterPDATab(id, {title, order, build(parent), badge(), visible()})`,
`STALKER_CORE.OpenPDA(tabID)`. Окно КПК реализует аддон `stalker_pda`.

## Помощники

`STALKER_CORE.Send(name, target, tbl)` / `Read(len, maxBytes)` — сжатый JSON по сети; `Rate(ply, key, perSecond, burst)`;
`CanAdmin(ply, permission)` («Комендант» → ULX `stalker_<право>` → суперадмин); `SID(ply)`; `PlayerBySID(sid)`;
`Faction(ply)`, `FactionName(id)`, `FactionColor(id)`; `Unconscious(ply)`; `Meters(units)`.

Хук сервера `STALKER_PlayerReady(ply)` — клиент загрузил Lua (первая настоящая команда ввода): досылайте сюда
начальные данные. Сообщения из `PlayerInitialSpawn` (даже по таймеру в 1–3 с) медленный клиент теряет.
