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
  
  [![Read in Russian](https://img.shields.io/badge/Language-Русский-red?style=for-the-badge)](README.ru.md)
  
  <br>
  
  <a href="https://boosty.to/"> <!-- Впиши сюда свою ссылку на Boosty! / Put your Boosty link here! -->
    <img src="https://img.shields.io/badge/Support_on-Boosty-F15F2C?style=for-the-badge&logo=boosty&logoColor=white" alt="Boosty">
  </a>
</div>

---

## 🎯 What It Is

**Qddons Manager** is a Flutter desktop application designed to manage World of Warcraft addons seamlessly on **Windows, Linux, and macOS**.

The core idea is simple:
- 🔍 **Detect** and work with different WoW client versions.
- 🕰️ **Support** legacy, private-server, classic, and modern retail-era clients.
- 📦 **Search** addons from multiple sources.
- 📥 **Install** them directly into the correct `Interface/AddOns` folder.
- 🗂️ **Organize** local addon state visibly from one place.

In short: **one manager for any client, not one manager for one blessed patch.**

---

## 🌍 Why It Exists

Most addon tools are comfortable only when the universe is clean: one launcher, one supported branch, one modern metadata model, one happy little ecosystem. 

WoW players know better. Qddons Manager is designed for the cursed timeline where:
- one folder is `3.3.5`
- another is `5.4.8`
- another is `7.3.5`
- another is Retail
- **and all of them still want addons right now.**

---

## ✨ Highlights

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

---

## 🔌 Sources

The app is built around a multi-source model. Depending on availability and verification rules, the current codebase works with source integrations such as:
- **CurseForge**
- **GitHub**
- **Wowskill**

Source quality varies by era. That is exactly why the app is designed around *source flexibility*, instead of betting the farm on one provider remembering every addon from every expansion ever made.

---

## 💻 Tech Stack

- **Flutter / Dart**
- **Material 3 Expressive**
- Desktop targets:
  - Windows
  - Linux
  - macOS

---

## 📈 Project Status

This project is approaching its **first pilot release**.

It already covers the core workflows: client detection, addon search, verified installs, local addon visibility, multi-era handling, and desktop UX polish. 

There's still room for refinement (icon uniqueness across eras, source coverage depth, packaging), but the core thing is here:
**It works, and it works with the weird clients too.**

---

## 🚀 Quick Start

Ensure you have Flutter installed, then run:

```bash
flutter pub get

# Run on your desktop platform
flutter run -d windows
# Or:
# flutter run -d linux
# flutter run -d macos
```

---

## 🤝 Repository & Links

- **GitHub:** [QurieGLord/WoW-QAddOns-Manager](https://github.com/QurieGLord/WoW-QAddOns-Manager)

> **Final Note:** If your WoW setup looks like a museum, a laboratory accident, and a private-server graveyard all at once, this app was made with you in mind.
