<div align="center">
  <img src="icon.png" width="180" alt="Qddons Manager Logo">
  
  # Qddons Manager
  
  **One addon manager for the entire WoW zoo.** 🐺

  [![Flutter](https://img.shields.io/badge/Built_with-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Language-Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  <br>
  [![Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)](#)
  [![macOS](https://img.shields.io/badge/Platform-macOS-000000?style=for-the-badge&logo=apple&logoColor=white)](#)
  [![Linux](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](#)
  
  <br>
  
  [![Read in Russian](https://img.shields.io/badge/Language-Русский-red?style=for-the-badge)](#russian)
  
  <br>
  
  <a href="https://boosty.to/"> <!-- Впиши сюда свою ссылку на Boosty! / Put your Boosty link here! -->
    <img src="https://img.shields.io/badge/Support_on-Boosty-F15F2C?style=for-the-badge&logo=boosty&logoColor=white" alt="Boosty">
  </a>
</div>

---

<h2 id="english">🇬🇧 English</h2>

### 🎯 What It Is

**Qddons Manager** is a Flutter desktop application designed to manage World of Warcraft addons seamlessly on **Windows, Linux, and macOS**.

The core idea is simple:
- 🔍 **Detect** and work with different WoW client versions.
- 🕰️ **Support** legacy, private-server, classic, and modern retail-era clients.
- 📦 **Search** addons from multiple sources.
- 📥 **Install** them directly into the correct `Interface/AddOns` folder.
- 🗂️ **Organize** local addon state visibly from one place.

In short: **one manager for any client, not one manager for one blessed patch.**

### 🌍 Why It Exists

Most addon tools are comfortable only when the universe is clean: one launcher, one supported branch, one modern metadata model, one happy little ecosystem. 

WoW players know better. Qddons Manager is designed for the cursed timeline where:
- one folder is `3.3.5`
- another is `5.4.8`
- another is `7.3.5`
- another is Retail
- **and all of them still want addons right now.**

### ✨ Highlights

- 🎭 **Works with any WoW client family**
  Detects client version/profile and adapts search, matching, install, and local addon handling accordingly.
- 🌐 **Multi-source addon search**
  Built to aggregate addons from more than one source instead of pretending a single catalog has every historical version forever.
- ✅ **Verified install flow**
  Search and install paths are focused on confirmed, installable results instead of noisy false positives.
- 🖼️ **Search details popup**
  Addon cards expose richer metadata like title, artwork, description, gallery, provider, and version.
- 📂 **Local addon management**
  See what is installed, manage addon groups, and keep track of managed installs versus manual content.
- 🚀 **Launch the game from the app**
  If the client executable is known, you can jump straight into the game from the UI.
- 🎨 **Client-aware visual system**
  Era banners, icons, client cards, and themed details views make different expansions feel distinct instead of all being the same beige spreadsheet.
- 💫 **Smooth desktop UX**
  Improved scrolling, better card behavior, cleaner layouts, and polished desktop interaction patterns.

### 🔌 Sources

The app is built around a multi-source model. Depending on availability and verification rules, the current codebase works with source integrations such as:
- **CurseForge**
- **GitHub**
- **Wowskill**

Source quality varies by era. That is exactly why the app is designed around *source flexibility*, instead of betting the farm on one provider remembering every addon from every expansion ever made.

### 💻 Tech Stack

- **Flutter / Dart**
- **Material 3 Expressive**
- Desktop targets: Windows, Linux, macOS.

### 📈 Project Status

This project is approaching its **first pilot release**. It already covers the core workflows: client detection, addon search, verified installs, local addon visibility, multi-era handling, and desktop UX polish. 

There's still room for refinement (icon uniqueness across eras, source coverage depth, packaging), but the core thing is here:
**It works, and it works with the weird clients too.**

### 🚀 Quick Start

Ensure you have Flutter installed, then run:

```bash
flutter pub get

# Run on your desktop platform
flutter run -d windows
# Or:
# flutter run -d linux
# flutter run -d macos
```

### 🤝 Repository & Links

- **GitHub:** [QurieGLord/WoW-QAddOns-Manager](https://github.com/QurieGLord/WoW-QAddOns-Manager)

> **Final Note:** If your WoW setup looks like a museum, a laboratory accident, and a private-server graveyard all at once, this app was made with you in mind.

---

<h2 id="russian">🇷🇺 Русский</h2>

<div align="center">
  [![Read in English](https://img.shields.io/badge/Language-English-blue?style=for-the-badge)](#english)
</div>

<br>

### 🎯 Что Это

**Qddons Manager** — это десктопное приложение на Flutter для управления аддонами World of Warcraft на **Windows, Linux и macOS**.

Главная идея простая:
- 🔍 **Определять** и работать с разными версиями клиента WoW.
- 🕰️ **Поддерживать** старые, пиратские, classic и retail-ветки.
- 📦 **Искать** аддоны по нескольким источникам.
- 📥 **Устанавливать** их прямо в нужную папку `Interface/AddOns`.
- 🗂️ **Управлять** локально установленными аддонами из одного места.

Коротко: **один менеджер для любого клиента, а не только для одной "правильной" версии.**

### 🌍 Зачем Он Нужен

Большинство менеджеров аддонов чувствуют себя хорошо только в стерильной вселенной: один лаунчер, одна поддерживаемая ветка, одна экосистема и каталог, который якобы хранит вообще всё.

У игроков WoW реальность обычно куда веселее. Qddons Manager рассчитан как раз на ситуацию, где рядом живут:
- `3.3.5`
- `5.4.8`
- `7.3.5`
- Retail
- **и всем им нужны аддоны. Желательно без шаманства.**

### ✨ Основные Плюсы

- 🎭 **Работа с любым семейством WoW-клиентов**
  Приложение определяет версию/эпоху клиента и подстраивает поиск, матчинг, установку и локальную обработку аддонов под конкретную ветку.
- 🌐 **Мульти-источниковый поиск**
  Архитектура не завязана на один каталог и не делает вид, будто один источник хранит все версии всех аддонов за всю историю WoW.
- ✅ **Проверяемая установка**
  Поиск и установка ориентированы на реальные installable-результаты, а не на шумные ложные совпадения.
- 🖼️ **Попап с подробностями аддона**
  Карточка поиска может открывать название, картинку, описание, галерею, источник и версию.
- 📂 **Управление локальными аддонами**
  Можно видеть установленные аддоны, их группы и отличать managed-установки от вручную добавленного контента.
- 🚀 **Запуск игры прямо из интерфейса**
  Если исполняемый файл клиента известен, игру можно запускать прямо с экрана клиента.
- 🎨 **Визуал, завязанный на эпоху клиента**
  Баннеры, иконки, карточки и шапки клиентов различаются по дополнениям и не выглядят как одна и та же безликая таблица.
- 💫 **Нормальный desktop UX**
  Более плавная прокрутка, аккуратные карточки, улучшенные детали и в целом более взрослое взаимодействие.

### 🔌 Источники

Приложение строится как мульти-источниковая система. В зависимости от доступности и правил верификации кодовая база уже умеет работать с интеграциями вроде:
- **CurseForge**
- **GitHub**
- **Wowskill**

Качество покрытия по эпохам у источников разное. Именно поэтому упор сделан на *гибкость по источникам*, а не на наивную веру в то, что один каталог помнит каждый аддон с каждой версии WoW навсегда.

### 💻 Технологии

- **Flutter / Dart**
- **Material 3 Expressive**
- Платформы: Windows, Linux, macOS.

### 📈 Статус Проекта

Проект подходит к своей **первой пилотной версии**. Базовые сценарии уже закрыты: определение клиентов, поиск аддонов, verified install, отображение локальных аддонов, работа с разными эпохами клиента и серьёзно улучшенный desktop UI.

Ещё есть, что допиливать (бóльшую уникальность иконок эпох, дальнейшее расширение источников, дополнительную UI-полировку, релизный контур), но главное уже есть:
**оно работает, и работает даже с теми клиентами, на которые обычно все забивают.**

### 🚀 Быстрый Старт

Убедитесь, что у вас установлен Flutter, и выполните:

```bash
flutter pub get

# Запуск на вашей десктопной платформе
flutter run -d windows
# Или:
# flutter run -d linux
# flutter run -d macos
```

### 🤝 Репозиторий и Ссылки

- **GitHub:** [QurieGLord/WoW-QAddOns-Manager](https://github.com/QurieGLord/WoW-QAddOns-Manager)

> **Финальная Ремарка:** Если твоя коллекция WoW-клиентов больше похожа на музей, полевой архив и техноколдовской ритуал одновременно — значит, Qddons Manager делался не зря.
