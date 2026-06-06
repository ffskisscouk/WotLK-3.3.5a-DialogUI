📜 DialogUI Enhanced
A beautiful, extended fork of the original DialogUI addon

DialogUI Enhanced is an improved fork of the original DialogUI addon that transforms the quest and dialogue windows in World of Warcraft by adding a stunning parchment-themed interface to them. This version adds powerful new features while maintaining the beautiful aesthetic that made the original so popular.

🌟 What's new in this fork
This improved version builds on the foundation of the original DialogUI and adds:

🎯 Movable windows — drag and drop tasks and dialog windows anywhere on the screen
💾 Save Positions - Window positions are saved between game sessions
⚙️ Advanced Settings Panel – A beautiful in-game settings window with the ability to:
Zoom adjustments (0.5x to 2.0x)
Transparency settings (10% to 100%)
Font scale changes (from 0.5x to 2.0x)
🎥 Dynamic Camera System - Smooth camera transitions when interacting with NPCs:
Customizable distance and angle
Separate settings for dialogs, traders, trainers, and quests
Smooth transitions with customizable speed
Multiple Presets (Cinematic, Close, Normal, Wide)
📜🎨 Single theme "parchment" - all windows use the same papyrus style
⌨️ ESC key support - press ESC or Reject to close job windows correctly
🖼️ Improved icon system — native icons of dialogs with proper processing in case of their absence

📸 Gallery

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
something like this

⚡ Quick start
Installation: Unzip to folder Interface/AddOns/
Enablement: Activate "DialogUI" in the addon list
Setting: Use in chat to open settings/dialogui
Delight: Take advantage of beautiful movable quest and dialogue windows!

## 🎮 Commands

| Team | Description |
|---------|-------------|
| `/dialogui` | Open the settings window |
| `/resetdialogs` | Reset all windows |
| `/debugdialogs` | Show debugging information |
| `/togglecamera` | Turn on/off the dynamic camera |
| `/testcamera` | Test camera positioning |
| `/cameradebug` | Show debug information about the camera and frames |
| `/camerapreset [Name]` | Apply camera preset (cinematic, close, normal, wide)) |

🔧 Compatibility
✅ WOW WOTLK (3.3.5)

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
