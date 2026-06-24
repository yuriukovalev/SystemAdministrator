# System Administration Toolkit

Подборка рабочих скриптов и конфигураций, которые я использую в повседневном
администрировании инфраструктуры: управление Active Directory, развёртывание
сервисов в Docker, автоматизация через Ansible, настройка сети на MikroTik и
обслуживание Proxmox.

Репозиторий — это «полевые заметки» практикующего системного администратора:
каждый скрипт решает конкретную задачу, с которой я сталкивался на реальных
доменах и серверах.

> ⚠️ Все хосты, домены, IP и учётные данные в примерах — плейсхолдеры.
> Перед использованием подставьте свои значения.

---

## 📁 Структура

### `Powershell/` — администрирование Active Directory

PowerShell для типовых операций с доменом, пользователями и компьютерами.

| Скрипт | Назначение |
| --- | --- |
| `Get-AdUsersPasswordExpired.ps1` | Отчёт по пользователям с истёкшим паролем (UTC, OU, давность входа) |
| `PasswordNeverExpires.ps1` | Поиск учёток с флагом «пароль не истекает» |
| `AccountExpirationDate.ps1` | Управление датой окончания действия учётной записи |
| `AddGroupCSV.ps1` | Массовое добавление пользователей в группу из CSV с логированием |
| `LastLogonComputers.ps1` | Аудит ПК по дате последнего входа: активные / простаивающие |
| `LoginLastYear.ps1` | Выборка объектов, не входивших в домен более года |
| `ComputerCountUL.ps1` | Инвентаризация количества компьютеров по OU |
| `SerialNumberDuplicateAD.ps1` | Поиск дублей серийных номеров в описаниях компьютеров AD |
| `SearchComputer.ps1` | Быстрый поиск компьютера в домене |
| `BlockUserFile.ps1` | Массовая блокировка пользователей по списку из файла |
| `BlockComputerFile.ps1`, `BlockComputerFileList.ps1` | Блокировка компьютеров по списку |
| `UnlockUserFile.ps1` | Массовая разблокировка пользователей |
| `GPO Description/` | Заметки по описаниям объектов групповой политики |

### `Docker/` — развёртывание сервисов

Готовые `docker-compose` для self-hosted инфраструктуры:

- **traefik** — реверс-прокси с автоматическим выпуском TLS (Let's Encrypt)
- **Nginx Proxy Manager** — управление прокси через web-UI
- **Nextcloud** — облачное хранилище
- **Guacamole** — клиентский шлюз удалённого доступа (RDP/SSH/VNC) в браузере
- **n8n** — автоматизация рабочих процессов (low-code)
- **Postgres** — БД + pgAdmin

### `Ansible/` — автоматизация

- `install_LAPS.yaml` — развёртывание Microsoft LAPS (управление паролями локальных админов)
- `migration_domain.yaml` — задачи миграции домена

### `Mikrotik/` — сетевое оборудование

- `Mikrotik Backup Script.scr` — автоматический бэкап конфигурации с отправкой по почте
- `MultiWAN` — балансировка и резервирование нескольких каналов WAN

### `Proxmox/` — виртуализация

- `rename VM` — переименование виртуальных машин

### `Dynamic Group/` — динамические группы AD

`.ldf`-импорт и `.bat`-обёртка для создания динамических групп в Active Directory.

### `Google Chrome App/` — браузерное расширение

Небольшое расширение «Stop Page load» для остановки загрузки страницы.

---

## 🛠 Технологии

`PowerShell` · `Active Directory` · `Docker` · `Ansible` · `MikroTik RouterOS`
· `Proxmox VE` · `Nginx` · `Traefik`

## ⚙️ Использование

PowerShell-скрипты рассчитаны на запуск с правами администратора домена и
установленным модулем `ActiveDirectory` (RSAT):

```powershell
Import-Module ActiveDirectory
.\Powershell\Get-AdUsersPasswordExpired.ps1
```

`docker-compose`-файлы запускаются из своей папки:

```bash
cd Docker/traefik
docker compose up -d
```

## 📄 Лицензия

MIT — используйте свободно. Замечания и pull request'ы приветствуются.
