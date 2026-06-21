DialogUI

Fork of Russian https://github.com/Kolorado1976/DialogUI_3.3.5 translated into english.  some updated assets taken from  https://github.com/Jslquintero/DialogUI

RENAME FOLDER TO "DialogUI"  and place it in the Addons folder


📜 DialogUI Enhanced
A beautiful, expanded fork of the original DialogUI addon

DialogUI Enhanced is an improved fork of the original DialogUI addon, which transforms World of Warcraft quest and dialogue windows, giving them a stunning parchment‑style thematic interface.
This version adds powerful new features while preserving the gorgeous aesthetic that made the original so popular.


🌟 What’s new in this fork
This enhanced version is built on the foundation of the original DialogUI and adds:

🎯 Movable windows — drag quest and dialogue windows anywhere on your screen

💾 Position saving — window positions persist between game sessions

⚙️ Expanded settings panel — a beautiful in‑game settings window with:

Scale adjustment (0.5x to 2.0x)

Transparency control (10% to 100%)

Font scaling (0.5x to 2.0x)

🎥 Dynamic camera system — smooth camera transitions when interacting with NPCs:

Adjustable distance and angle

Separate settings for dialogues, vendors, trainers, and quests

Smooth transitions with customizable speed

Multiple presets (Cinematic, Close, Normal, Wide)

📜🎨 Unified “parchment” theme — all windows use a consistent papyrus style

⌨️ ESC key support — press ESC or “Decline” to properly close quest windows

🖼️ Improved icon system — native dialogue icons with proper fallback handling



## 📸 Gallery

<div style="display: flex; flex-wrap: wrap; gap: 10px; justify-content: center;">
  <img src="https://raw.githubusercontent.com/Jslquintero/DialogUI/main/src/preview/Screenshot%20From%202025-06-18%2000-34-14.png" style="width: 30%; min-width: 200px;" />
  <img src="https://raw.githubusercontent.com/Jslquintero/DialogUI/main/src/preview/Screenshot%20From%202025-06-18%2000-34-24.png" style="width: 30%; min-width: 200px;" />
  <img src="https://raw.githubusercontent.com/Jslquintero/DialogUI/main/src/preview/Screenshot%20From%202025-06-18%2000-34-35.png" style="width: 30%; min-width: 200px;" />
  <img src="https://raw.githubusercontent.com/Jslquintero/DialogUI/main/src/preview/Screenshot%20From%202025-06-18%2000-35-57.png" style="width: 30%; min-width: 200px;" />
  <img src="https://raw.githubusercontent.com/Jslquintero/DialogUI/main/src/preview/Screenshot%20From%202025-06-18%2000-37-32.png" style="width: 30%; min-width: 200px;" />
  <img src="https://raw.githubusercontent.com/Jslquintero/DialogUI/main/src/preview/Screenshot%20From%202025-06-18%2000-37-38.png" style="width: 30%; min-width: 200px;" />
  <img src="https://raw.githubusercontent.com/Jslquintero/DialogUI/main/src/preview/Screenshot%20From%202025-06-18%2000-41-14.png" style="width: 30%; min-width: 200px;" />
  <img src="https://raw.githubusercontent.com/Jslquintero/DialogUI/main/src/preview/Screenshot%20From%202025-06-18%2000-42-06.png" style="width: 30%; min-width: 200px;" />
</div>


## ⚡Quick Start
Install: Extract into Interface/AddOns/

Enable: Activate “DialogUI” in the addons list

Configure: Use /dialogui in chat to open settings

Enjoy: Use beautiful movable quest and dialogue windows!

## 🎮 Команды

| Commands |
|---------|-------------|
| `/dialogui` |  Open settings window |
| `/resetdialogs` |  Open settings window |
| `/debugdialogs` | Show debug information |
| `/togglecamera` | Enable/disable dynamic camera |
| `/testcamera` | Test camera positioning |
| `/cameradebug` | Show debug info about camera and frames |
| `/camerapreset [name]` | Apply camera preset (cinematic, close, normal, wide) |

## 🔧 Совместимость

- ✅ **WOW WOTLK** (3.3.5)
- ⚠️ Создан для русскоязычного клиента 

## 🎨 Оригинальное вдохновение

Этот аддон вдохновлен [DialogueUI](https://www.curseforge.com/wow/addons/dialogueui) и использует улучшенный оригинальный код Blizzard с нативной обработкой иконок.

## 📋 Об этом форке

Это **улучшенный форк** оригинального [DialogUI от Jslquintero](https://github.com/Jslquintero/DialogUI). Оригинальный автор создал отличную основу для изучения разработки аддонов WoW. Цель этого форка — внести новые функции и улучшения в проект, поддерживая сообщество, и сохранить прекрасную эстетику пергамента, которая делает DialogUI особенным.

**Оригинальный автор**: [Jslquintero](https://github.com/Jslquintero)  
**Сопровождающий форка**: [Velord]  
**Оригинальный репозиторий**: https://github.com/Jslquintero/DialogUI

## 🐛 Сообщение о проблемах

**Перед сообщением о любой проблеме:**
1. Отключите все остальные аддоны
2. Оставьте активным только DialogUI
3. Проверьте, сохраняется ли проблема
4. Если да, пожалуйста, сообщите о ней!

### Как сообщить

- **Проблемы оригинального DialogUI**: [Раздел Issues оригинального репозитория](https://github.com/Jslquintero/DialogUI/issues/new)
- **Проблемы этого форка**: [Раздел Issues этого форка](https://github.com/jucsp/DialogUI/issues/new)

Пожалуйста, укажите, какую версию вы используете, и приложите сообщения об ошибках или скриншоты.

## 🎨 Кастомизация

Не стесняйтесь полностью изменять внешний вид! Каждое изображение теперь в формате **TGA** для удобного редактирования.

### 🖼️ Изменение иконок
Редактируйте иконки диалогов здесь:
```
DialogUI/src/assets/art/icons/GossipIcons.xcf
```

### 🎨 Изменение стиля фреймов
Редактируйте стили кнопок и фона здесь:
```
DialogUI/src/assets/art/parchment/ParchmentLayout.xcf
```

### 🛠️ Как редактировать

1. **Добавление/Удаление иконок**: Все иконки диалогов — отдельные TGA-файлы в `/src/assets/art/icons/`
2. **Изменение фона фреймов**: Отредактируйте текстуры пергамента и стили кнопок
3. **Процесс экспорта**: Используйте GIMP 3 с плагином [Batcher](https://kamilburda.github.io/batcher/) для быстрого пакетного экспорта в TGA

**Рекомендуемые инструменты:**
- **GIMP 3** с плагином [Batcher](https://kamilburda.github.io/batcher/) для пакетного экспорта в TGA
- Любой редактор изображений, поддерживающий формат TGA

**Формат файлов**: Все изображения должны быть в формате **Truevision Graphics Adapter (TGA)**, чтобы корректно работать в WoW.

---

## � TODO - Планируемые улучшения

### 🎥 Улучшения динамической системы камеры
- [ ] **Настраиваемые предустановки камеры**: Сделать каждую предустановку (Кинематографичная, Близко, Обычная, Широкая) полностью настраиваемой пользователями.
- [ ] **Расширенная интеграция камеры**: Реализовать использование нативных функций WoW SaveView() и SetView() для:
  - Точного сохранения позиции камеры (точный угол, расстояние, наклон, поворот)
  - Идеального восстановления с использованием родной системы камеры WoW
  - Бесшовной интеграции с системой управления состоянием камеры игры
- [ ] **Расширенное управление предустановками**:
  - Позволить пользователям создавать свои предустановки, помимо 4 стандартных
  - Сохранять/загружать конфигурации предустановок в/из сохраненных переменных
  - Экспортировать/импортировать конфигурации предустановок между персонажами
- [ ] **Улучшение плавности переходов**:
  - Улучшенные алгоритмы интерполяции для движения камеры
  - Настраиваемое время перехода и функции сглаживания
  - Учет состояния игрока (движение, бой) во время переходов

---

## 📄 Лицензия

Этот улучшенный форк сохраняет тот же дух обучения и обмена, что и оригинальный проект DialogUI.

# Персонализация!

Не стесняйтесь добавлять/изменять иконки или менять фон панели полностью. Теперь каждое изображение находится в формате Truevision Graphics Adapter (TGA).

Рекомендую использовать Gimp 3 с плагином [Batcher](https://kamilburda.github.io/batcher/) для быстрого экспорта файлов.

Чтобы изменить иконки диалогов, перейдите по адресу:

> DialogUI/src/assets/art/icons/GossipIcons.xcf

Чтобы изменить стиль кнопок, перейдите по адресу:

> DialogUI/src/assets/art/parchment/ParchmentLayout.xcf
