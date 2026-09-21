# VPN (TUN) на десктопе

<p align="right">
  <a href="../en/desktop_vpn.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>

## Обзор

**Режим работы → VPN** на Linux, Windows или macOS запускает ядро с **TUN inbound** (как полный туннель на телефоне). Системный HTTP-прокси **не** включается — трафик идёт через маршрутизацию ОС в туннель.

**Режим → Прокси** (по умолчанию для **Авто** на десктопе) — прежнее поведение: локальный SOCKS/HTTP с паролем и опциональный системный прокси.

## Требования

| Платформа | Права |
|-----------|--------|
| **Linux** | `CAP_NET_ADMIN` на бинарник `sing-box` или `xray`, либо запуск от root |
| **Windows** | Запуск **от имени администратора**; **`wintun.dll`** рядом с `xray.exe` (`scripts/fetch_cores.sh` копирует из Windows-архива sing-box) |
| **macOS** | **sudo** / администратор (Network Extension — в планах) |

### Linux: capabilities

После `./scripts/fetch_cores.sh`:

```bash
sudo setcap cap_net_admin+ep /path/to/sing-box
```

Проверка: `getcap /path/to/sing-box`

## Движки

- **sing-box** — TUN добавляется в Dart.
- **Xray** — на Windows/Linux: основное ядро без TUN; второй процесс Xray (**TUN bridge**) гонит трафик в локальный SOCKS с паролем (как на Android).
- **SkadiCore** — VPN на десктопе не поддерживается.

## Безопасность

Локальный SOCKS на `127.0.0.1:1080` остаётся **с паролем на сессию** и в режиме VPN.

## См. также

- [work_modes.md](work_modes.md)
- [linux_setup.md](linux_setup.md)
