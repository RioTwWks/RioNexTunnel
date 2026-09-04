# Цензуроустойчивость и пресеты транспорта

RioNexTunnel поддерживает обычные ссылки VLESS/VMess/Trojan от любого провайдера. **Режим цензуроустойчивости** добавляет пресеты и настройки клиента для обхода DPI (включая РКН/ТСПУ) без кастомных форков Xray.

## Когда какой стек использовать

| Ситуация | Рекомендуемый стек | Примечания |
|----------|-------------------|------------|
| Современный DPI в РФ (2026), сервер поддерживает | **VLESS + REALITY + XHTTP** (`mode: stream-one`) | Основная рекомендация |
| REALITY есть, XHTTP нет | **VLESS/Trojan + REALITY + TCP** | Работает; хуже по отпечатку, чем XHTTP |
| CDN или reverse proxy | **WebSocket + TLS** или **HTTPUpgrade + TLS** | Нормальный HTTPS на 443 |
| Разрешён gRPC | **gRPC + TLS** | Если WebSocket режут |
| Мобильный оператор, нет XHTTP | **VLESS + TLS + mux** (8 потоков) | Включите mux в мастере |
| Простой сервер | **Plain TLS (TCP)** | Легко детектируется; только если иначе нельзя |
| Trojan vs VLESS+REALITY | Предпочтительно **VLESS+REALITY** | Trojan+TLS уместен за CDN |

**Не используйте** неподдерживаемые форки REALITY. RioNexTunnel использует **официальный Xray-core** из `scripts/fetch_cores.sh`.

## Отпечаток uTLS

В мастере можно выбрать **fingerprint ClientHello**: `firefox`, `edge`, `chrome`, `safari`, `random`.

- По умолчанию: **firefox** (если в ссылке нет `fp`)
- В жёстких сетях часто лучше **firefox** или **edge**
- Параметр `fp` в ссылке сохраняется; при включённом режиме цензуры применяется профиль

## Мастер цензуроустойчивости

При добавлении или редактировании профиля (вкладка Profiles):

1. Вставьте ссылку или URL подписки → **Add profile**
2. Откроется мастер (можно **Skip**)
3. Автоопределение транспорта из метаданных ссылки
4. Пресет, fingerprint, mux, **RU sites direct**
5. Для ссылок параметры транспорта записываются в share link

## RU sites direct

Маршрутизация `geosite:ru` и `geoip:ru` в **direct** (российские сайты без зарубежного IP).

- Нужны **geo-файлы** для Xray — `scripts/fetch_cores.sh`
- При отсутствии geo приложение **не подключается** (fail closed)
- На **desktop proxy mode** ОС/браузер могут игнорировать часть правил

## Безопасность (без изменений)

- Локальный SOCKS/HTTP только на **127.0.0.1** с **паролем** на сессию
- Секреты транспорта и пароли **не логируются**
- RU direct не открывает неаутентифицированный localhost

## Подписка JSON (XHTTP)

Полные JSON-подписки (массив v2rayNG или один объект) используют разные поля в зависимости от движка. `ConfigParser.injectSecureSocksInbound` нормализует XHTTP при подключении:

| Движок | Где транспорт | Поле mode |
|--------|---------------|-----------|
| Xray | `outbounds[].streamSettings.network: "xhttp"` + `xhttpSettings` | `xhttpSettings.mode` |
| sing-box | `outbounds[].transport.type: "xhttp"` | `transport.mode` |

`path`, `host` и прочие ключи XHTTP из подписки сохраняются. Отсутствующий или `auto` mode приводится к **`stream-one`** (как у `vless://` через `LinkConfigBuilder`).

## Устранение неполадок

| Симптом | Что попробовать |
|---------|-----------------|
| Wi‑Fi ок, мобильный оператор нет | **mux**; узел XHTTP или AmneziaWG у провайдера |
| Ошибки XHTTP | На сервере `mode: stream-one`, не `auto` |
| Ошибки geo / RU direct | `scripts/fetch_cores.sh` или отключить пресет |
| iOS + XHTTP+REALITY | Узел TCP+REALITY+Vision из той же подписки |

## Политика платформы и движка

### Выбор транспорта на iOS

При **Automatic (best latency)** в подписке с узлами **XHTTP+REALITY** и **TCP+REALITY+Vision** клиент на **iOS понижает приоритет XHTTP** и предпочитает TCP+REALITY+Vision. На остальных платформах при доступности обоих стеков по умолчанию выбирается XHTTP.

Это **только ранжирование серверов** (§6), а не цепочка fallback при connect (§5). Если в подписке только XHTTP, iOS подключается к лучшему доступному XHTTP-узлу.

### Только официальный Xray-core

RioNexTunnel поставляет **официальные бинарники [Xray-core](https://github.com/XTLS/Xray-core)** через `scripts/fetch_cores.sh`. Мы **не** включаем кастомные сборки Xray для рандомизации REALITY-сертификатов и прочих патчей форков (например, неподдерживаемый [REALITY-rkn-fix](https://github.com/fwflunky/REALITY-rkn-fix)).

Защита от статического отпечатка REALITY — **выбор транспорта** (XHTTP где возможно), **uTLS** и **настройки сервера**, а не пропатченный клиентский core.

### Проверка версии core (XHTTP)

Версия bundled Xray сравнивается с пином в `scripts/fetch_cores.sh` (`DEFAULT_XRAY_VERSION`, сейчас **26.3.27**). При подключении с **XHTTP+REALITY** на более старом core:

- в лог пишется **некритичное предупреждение**
- в **Settings → Core engine** — напоминание запустить `scripts/fetch_cores.sh`

Обновление: `./scripts/fetch_cores.sh` из корня репозитория, затем пересборка приложения.

### Улучшения REALITY в upstream

Когда официальный Xray-core получит функции из community-форков (динамические REALITY-серты, фрагментация ServerHello и т.д.), RioNexTunnel подключает их через **обычное обновление core** в `fetch_cores.sh`, без приватного форка. Следите за:

- [релизами XTLS/Xray-core](https://github.com/XTLS/Xray-core/releases)
- [issues XTLS/Xray-core](https://github.com/XTLS/Xray-core/issues) (REALITY / XHTTP)

См. также [security.md](security.md) и [troubleshooting.md](troubleshooting.md).
