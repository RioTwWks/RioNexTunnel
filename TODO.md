# RioNexTunnel — Roadmap / TODO

> Дорожная карта на основе внешнего фидбэка и текущего состояния репозитория.  
> Детальный бэклог агентов: [.cursor/tasks.md](.cursor/tasks.md)

**Приоритеты:** P0 (критично) → P1 (ключевые отличия) → P2 (продвинутые функции) → P3 (UX и полировка)

---

## Уже реализовано — сохранять и не ломать

Эти сильные стороны проекта — фундамент; любые новые функции не должны нарушать золотые правила безопасности (см. [.cursor/AGENTS.md](.cursor/AGENTS.md)).

- [x] **Кроссплатформенность** — Flutter: Android, iOS, Windows, Linux, macOS
- [x] **Два ядра** — Xray-core и sing-box, переключение в runtime + авто-выбор движка
- [x] **Безопасный локальный прокси** — `127.0.0.1` only, обязательная SOCKS5-аутентификация, per-session CSPRNG-учётные данные
- [x] **Уничтожение credentials** — не логируются, не пишутся на диск, стираются при disconnect
- [x] **Desktop proxy mode** — Linux: системный прокси (GNOME GSettings) + HTTP inbound `1081`
- [x] **Расширение браузера** — авто proxy-auth (`extensions/secure-vpn-proxy-auth/`)
- [x] **Подписки** — импорт по URL, engine-specific User-Agent, decoy-skipping, v2rayNG JSON array
- [x] **Выбор сервера** — server picker + авто-выбор по TCP latency
- [x] **Протоколы** — VLESS, VMess, Shadowsocks, Trojan, Hysteria/Hysteria2, TUIC, WireGuard, SSH (через ядра)
- [x] **Open Source** — GPLv3, без встроенной телеметрии
- [x] **Тесты безопасности** — `test/security_test.dart`, `scripts/security_probe.sh`
- [x] **Базовый DNS** — миграция legacy DNS sing-box, VPN-safe resolvers в `LinkConfigBuilder`
- [x] **Routing из подписок** — поддержка `geosite:` / `geoip:` при наличии geo-ассетов

---

## P0 — Фундамент: стабильность и паритет платформ

Без этого «тяжёлая артиллерия» (Kill Switch, Split Tunneling) не будет надёжной.

### Платформенный паритет

- [ ] **Android** — E2E connect на физическом устройстве (VPN/TUN mode)
- [ ] **iOS** — Network Extension + smoke test подключения
- [ ] **Windows** — desktop plugin по образцу Linux (`desktop_core.cc`, `system_proxy`)
- [ ] **macOS** — выровнять порты плагина с инжектированными inbound (1080/1081), проверить proxy mode
- [ ] **Windows/macOS** — `SystemProxy` (сейчас только Linux)

### Инженерная база

- [ ] **CI** — `flutter analyze` + `flutter test` на push
- [ ] **CI security probe** — автозапуск `security_probe.sh` при Linux integration test
- [ ] **Fail closed** — ошибка при отсутствии geo-ассетов, если конфиг содержит geosite/geoip rules
- [ ] **Аудит sing-box DNS** — deprecated/mixed paths в mobile VPN mode

### Стабильность соединения

- [ ] **Автопереподключение** — exponential backoff при обрыве VPN/ядра
- [ ] **Понятные статусы** — Connecting / Reconnecting / Error с причиной (не только Connected/Disconnected)
- [ ] **Статистика соединения** — upload/download, uptime в UI

---

## P1 — Ключевые отличия (главный фокус фидбэка)

Эти функции отсутствуют сегодня и являются основными точками роста относительно текущего RioNexTunnel.

### 1. Kill Switch

> Блокировка трафика при неожиданном обрыве VPN — критичная функция безопасности.

- [ ] **Дизайн архитектуры** — разделение поведения для Proxy mode (desktop) и TUN mode (mobile)
- [ ] **Strict mode** — полная блокировка исходящего интернет-трафика при падении ядра / потере туннеля
- [ ] **Adaptive mode** — блокировка только для выбранного списка приложений (per-app)
- [ ] **Linux** — iptables/nftables или NetworkManager firewall rules; снятие правил при корректном disconnect
- [ ] **Android/iOS** — интеграция с VPNService / NEPacketTunnelProvider (block non-VPN traffic)
- [ ] **Windows/macOS** — WFP / pf / аналог для proxy-mode fallback
- [ ] **UI** — переключатель Strict / Adaptive / Off в Settings
- [ ] **Тесты** — симуляция обрыва ядра, проверка отсутствия утечки (integration test)
- [ ] **Документация** — ограничения kill switch в proxy mode vs TUN mode

### 2. Split Tunneling (раздельное туннелирование)

> Трафик выбранных приложений через VPN, остальные — напрямую. Требует строгой изоляции (см. `.cursorrules`).

- [ ] **Дизайн модели** — whitelist (только эти через VPN) vs blacklist (все кроме этих)
- [ ] **Android** — per-app routing через `VpnService.Builder.addAllowedApplication` / `addDisallowedApplication`
- [ ] **iOS** — ограничения NE: per-app split tunneling ограничен; документировать fallback
- [ ] **Desktop proxy mode** — явно документировать, что split tunneling на уровне ОС/приложений, не TUN
- [ ] **Linux TUN (если появится)** — policy routing / cgroup + изоляция от bypass через localhost scan
- [ ] **UI** — список установленных приложений с переключателями (mobile) или предупреждение для desktop
- [ ] **Безопасность** — запрет bypass через неаутентифицированный localhost; тест на утечку при split tunnel
- [ ] **Тесты** — unit + platform smoke для whitelist/blacklist

### 3. Обфускация трафика (DPI bypass)

> Протоколы поддерживаются ядрами, но нет удобного UX и пресетов для обхода DPI.

- [ ] **Пресеты транспорта** — WebSocket+TLS, gRPC, HTTPUpgrade, REALITY (xray), uTLS fingerprint
- [ ] **UI мастер** — «режим цензуры» / obfuscation wizard при импорте или редактировании профиля
- [ ] **Авто-детект** — подсказка транспорта из subscription metadata (если доступно)
- [ ] **Документация** — когда использовать Trojan/VLESS+REALITY vs plain TLS
- [ ] **Тесты** — валидация генерируемого JSON для xray/sing-box (без реального DPI)

---

## P2 — Продвинутые функции безопасности и маршрутизации

### Мультихоп (Double VPN / цепочки)

- [ ] **Модель цепочки** — 2+ outbound в конфиге (xray `chain` / sing-box `detour`)
- [ ] **UI** — выбор второго (и далее) hop из списка серверов подписки
- [ ] **Валидация** — несовместимые протоколы, таймауты, порядок detour
- [ ] **Документация** — компромисс latency vs анонимность

### Продвинутый DNS

- [ ] **Защита от DNS-утечек** — принудительный DNS через туннель в TUN mode; тест утечки
- [ ] **DoH / DoT** — настраиваемые encrypted DNS upstream в UI
- [ ] **Кастомные DNS** — пользовательские резолверы (IP, DoH URL, DoT host)
- [ ] **DNS leak test** — встроенная проверка или ссылка на ручной тест из Settings
- [ ] **Desktop proxy mode** — документировать отличия DNS-поведения от full VPN

### Кастомный Routing

- [ ] **UI правил** — домены, IP/CIDR, гео (geosite/geoip) без ручного JSON
- [ ] **Импорт/экспорт** — правила маршрутизации как отдельный профиль
- [ ] **Пресеты** — «только заблокированные сайты», «RU direct / остальное proxy»
- [ ] **Синхронизация** — merge пользовательских rules с routing из subscription

---

## P3 — UX, прозрачность и конкурентные преимущества

Избегать перегруженного UI (антипаттерн PIA); расширенные настройки — в отдельном разделе.

### Минималистичный интерфейс

- [ ] **Connect в 1–2 клика** — главный экран: профиль + большая кнопка Connect
- [ ] **Продвинутые настройки** — отдельный экран/секция (routing, DNS, kill switch, split tunnel)
- [ ] **Полная локализация** — RU/EN для всего приложения (сейчас частично)
- [ ] **Тёмная/светлая тема** — согласованность с системной темой ОС

### Управление профилями

- [ ] **Импорт из буфера / QR** — быстрое добавление `vless://` / `trojan://` ссылок
- [ ] **Автообновление подписок** — по расписанию + ручной refresh
- [ ] **Группы серверов** — теги, избранное, последний использованный

### Прозрачность (антипаттерн: закрытый код и телеметрия)

- [ ] **Политика конфиденциальности** — явный документ: zero telemetry, что хранится локально
- [ ] **Понятные логи** — пользовательский log viewer (без credentials); уровни Info / Debug
- [ ] **Открытый roadmap** — синхронизация этого файла с релизами / GitHub Issues

### Режимы работы (документировать и унифицировать)

- [ ] **VPN Mode (TUN)** — mobile: полный туннель, kill switch, split tunnel
- [ ] **Proxy Mode** — desktop: системный прокси + расширение браузера; ограничения kill switch
- [ ] **Единый переключатель** — auto-detect по платформе с override для power users

### Прочее UX

- [ ] **Публикация расширения** — Chrome Web Store / Firefox AMO
- [ ] **Certificate pinning** — опционально для fetch подписок (P2 security hardening)

---

## Антипаттерны — чего избегать

Уроки из популярных VPN-клиентов; не повторять в RioNexTunnel:

| Антипаттерн | Наша позиция |
|-------------|--------------|
| Нестабильный kill switch | Тестировать обрыв ядра; fail closed |
| Перегруженный UI | Минимализм на Home; Advanced — отдельно |
| Телеметрия и закрытый код | GPLv3, zero telemetry by design |
| Неаутентифицированный localhost proxy | **Никогда** — золотое правило проекта |
| Агрессивный маркетинг в приложении | Нет рекламы, нет upsell в UI |
| Непрозрачные статусы | Детальные состояния + логи без секретов |

---

## Матрица: фидбэк → статус

| Функция из фидбэка | Статус | Приоритет |
|--------------------|--------|-----------|
| Кроссплатформенность (Flutter) | ✅ Готово | — |
| Xray + sing-box | ✅ Готово | — |
| Безопасный SOCKS5 (auth, 127.0.0.1) | ✅ Готово | — |
| Desktop proxy mode | ✅ Linux; ⏳ Win/macOS | P0 |
| Подписки + выбор сервера | ✅ Готово | — |
| Автовыбор лучшего сервера | ✅ Готово | — |
| Open Source, zero telemetry | ✅ Готово | — |
| Kill Switch | ❌ Нет | **P1** |
| Split Tunneling | ❌ Нет | **P1** |
| Обфускация / DPI (UX) | ⚠️ Через протоколы, без UI | **P1** |
| Double VPN / Multihop | ❌ Нет | P2 |
| DNS leak protection, DoH/DoT | ⚠️ Базовый DNS | P2 |
| Custom routing UI | ⚠️ Только из subscription JSON | P2 |
| Автопереподключение | ❌ Нет | P0 |
| Минималистичный UI | ⚠️ Частично | P3 |
| Статистика соединения | ❌ Нет | P0 |

---

## Рекомендуемый порядок работ

```
P0 Платформы + CI + reconnect
    ↓
P1 Kill Switch → Split Tunneling → Obfuscation UX
    ↓
P2 DNS advanced → Routing UI → Multihop
    ↓
P3 UI polish → localization → extension store
```

---

## Связанные документы

| Документ | Назначение |
|----------|------------|
| [.cursor/tasks.md](.cursor/tasks.md) | Текущий бэклог агентов (чеклисты) |
| [.cursor/AGENTS.md](.cursor/AGENTS.md) | Золотые правила безопасности |
| [docs/en/security.md](docs/en/security.md) | Модель SOCKS-аутентификации |
| [docs/en/architecture.md](docs/en/architecture.md) | Компоненты и data flow |
| [.cursorrules](.cursorrules) | Требования проекта для AI |

---

*Последнее обновление: 2026-09-02 — на основе внешнего фидбэка и аудита репозитория.*
