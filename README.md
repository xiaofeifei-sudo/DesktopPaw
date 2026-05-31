<h1 align="center">🐾 MofuPaw · 萌爪</h1>
<p align="center">
  <strong>A fluffy AI desktop pet that lives on your Mac</strong>
</p>
<p align="center">
  <em>A smart, cute virtual pet powered by AI 🐱</em>
</p>
<p align="center">
  <a href="README_CN.md">🇨🇳 中文文档</a> ·
  <a href="#-what-is-mofupaw">🎮 What is MofuPaw</a> ·
  <a href="#-features">✨ Features</a> ·
  <a href="#-getting-started">🚀 Quick Start</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-green" alt="License: CC BY-NC-SA 4.0">
  <img src="https://img.shields.io/badge/Version-0.1.0-purple" alt="Version 0.1.0">
</p>

---

## 🎮 What is MofuPaw?

**MofuPaw（萌爪）** is a **native macOS desktop pet** — a tiny, animated companion that floats on your desktop, walks around, takes naps, reacts to your clicks, and even **chats with you** using AI.

> *Mofu = soft and fluffy, the feeling when you pet something adorable*
> *Paw = the little paw prints it leaves on your desktop*

It's a modern **virtual pet** built from scratch for macOS with full AI capabilities. No Electron. No web wrapper. Pure Swift, pixel-perfect on every Retina display.

<p align="center">
  <img src="Example/精灵图.png" alt="MofuPaw Sprite Sheet" width="500">
  <br>
  <em>The default cat sprite sheet — 7 states, 8 frames each</em>
</p>

<p align="center">
  <img src="Example/桌宠气泡示例.jpg" alt="MofuPaw Overview" width="500">
</p>

---

## ✨ Features

### 🧠 AI-Powered Companion

Your pet isn't just a sprite — it's a **thinking companion** powered by large language models.

- **Real-time Chat** — Talk to your pet via a built-in chat panel with streaming responses
- **Multiple AI Providers** — Supports OpenAI, Anthropic Claude, and any OpenAI-compatible API
- **Four Personality Types** — Choose from Gentle (温柔), Lively (活泼), Quiet (安静), or Playful (调皮)
- **Long-term Memory** — Your pet remembers your preferences, nicknames, and past conversations
- **Emotional Intelligence** — Tracks 8 emotional states and adapts its behavior accordingly
- **Proactive Conversations** — Your pet initiates chats based on milestones, mood changes, and daily routines

<p align="center">
  <img src="Example/AI开启确认.jpg" alt="AI Setup" width="450">
  <img src="Example/AI陪伴功能.jpg" alt="AI Companion" width="450">
</p>

### 🎨 AI Visual Generation

Give your pet a whole new look with AI image generation!

- **Multiple Providers** — MiniMax, Aliyun, SiliconFlow, Tencent, OpenAI-compatible APIs
- **Visual Overlays** — Generated images temporarily change your pet's appearance
- **Identity Consistency** — AI maintains your pet's character identity across generations
- **User Feedback Learning** — The system learns from your preferences over time

<p align="center">
  <img src="Example/桌宠形象自迭代.jpg" alt="AI Visual Generation" width="450">
</p>

### 💕 Companionship System

Your relationship with your pet grows over time through **five relationship levels**:

| Level | Name | Points | Unlock |
|-------|------|--------|--------|
| 1 | Acquaintance (初识) | 0 | Basic interactions |
| 2 | Familiar (熟悉) | 100 | More dialogue options |
| 3 | Close (亲近) | 250 | Deeper conversations |
| 4 | Trusted (信赖) | 500 | Special interactions |
| 5 | Bonded (默契) | 900 | Full companionship |

### 🫧 Interactive Bubble System

Your pet communicates through smart, contextual speech bubbles:

- **Context-Aware Phrases** — Different messages when happy, hungry, tired, or just woke up
- **Interactive Choices** — AI-generated multi-option prompts (feed, play, pet, chat)
- **Micro-Dialogs** — Quick contextual interactions with response options
- **Priority System** — Important messages (hungry!) always get through

<p align="center">
  <img src="Example/交互式气泡&关系.jpg" alt="Interactive Bubbles" width="450">
</p>

### 🎭 Pet Engine

A fully data-driven pet simulation engine:

- **7 States** — Idle, Walking, Sleeping, Happy, Eating, Jumping, Dragging
- **Mood Simulation** — Mood, hunger, and energy decay over time
- **Time-of-Day Awareness** — Behavior changes from morning to night
- **Auto-Sleep** — Your pet dozes off when you're away
- **Random Idle Actions** — Weighted behavior scheduling for natural-feeling life

<p align="center">
  <img src="Example/新增动作图1.png" alt="Custom Actions 1" width="450">
  <img src="Example/新增动作图2.png" alt="Custom Actions 2" width="450">
</p>

### 📦 Pet Library & Custom Pets

- **Import Any Image** — Turn any sprite into a desktop pet
- **Petdex Format** — A standardized pet package format for sharing
- **.pet Packages** — Export and share complete pet packages
- **Action Packs** — Modular content packs that add new animations
- **Content Packs** — Extend pets with dialogue packs and personality packs

<p align="center">
  <img src="Example/自定义桌宠资源.jpg" alt="Custom Pets" width="450">
  <img src="Example/基础配置&自定义宠物.jpg" alt="Pet Settings" width="450">
</p>

### 🖥️ Desktop Integration

- **Always on Top** — Floats above all windows without stealing focus
- **Transparent Hit-Test** — Clicks pass through except on the pet itself
- **Draggable** — Drag your pet anywhere on screen
- **Position Memory** — Remembers where you left it
- **Multi-Display** — Works across multiple monitors
- **Menu Bar Control** — Full control from the 🐾 menu bar icon

<p align="center">
  <img src="Example/桌宠菜单.jpg" alt="Context Menu" width="300">
</p>

### ⌨️ Advanced Features

- **Desktop Space Awareness** — Pet reacts to nearby windows and screen edges
- **Input Sync** — Optionally reacts to your keyboard/mouse activity
- **External API** — Unix socket IPC for external tool integration
- **Sound Effects** — Audio feedback for interactions (click, pet, feed)
- **Launch at Login** — Start with macOS

---

## 🚀 Getting Started

### Prerequisites

- **macOS 13.0** (Ventura) or later
- **Xcode 15+** with Swift 6 toolchain
- (Optional) An AI API key for chat and visual features

### Build from Source

```bash
# Clone the repository
git clone https://github.com/Estellanini/MofuPaw.git
cd MofuPaw

# Build
swift build

# Run
swift run MofuPaw
```

### Package a Release

```bash
./Scripts/package_release.sh
```

This creates a standalone `.app` bundle you can move to `/Applications`.

---

## ⚙️ Configuration

### AI Setup

1. Open the 🐾 menu bar icon → **Settings**
2. Go to **AI Settings** panel
3. Choose your provider (OpenAI / Anthropic / Custom)
4. Enter your API key (stored securely in macOS Keychain)
5. Select a personality for your pet

### Image Generation Setup

1. Settings → **AI Visual** panel
2. Choose an image generation provider
3. Configure API credentials
4. Your pet can now transform with AI-generated visuals!

---

## 🏗️ Architecture

MofuPaw is built with a clean, protocol-oriented architecture in pure Swift:

```
MofuPaw/
├── App/                 # App lifecycle, coordinator, commands
├── PetCore/             # State machine, mood engine, behavior scheduling
├── PetRendering/        # Sprite sheet rendering, animation player
├── PetAssets/           # Pet definitions, animation clips
├── PetWindow/           # Floating panel, drag, hit-test
├── Bubble/              # Speech bubble engine, scheduling
├── InteractiveBubble/   # AI-powered interactive prompts
├── AICompanion/         # Chat engine, memory, personality, emotions
├── AIVisualAction/      # Visual action mediation
├── AIVisualGeneration/  # Image generation providers
├── Companionship/       # Relationship system, micro-dialogs
├── PetLibrary/          # Pet import/export, custom pets
├── Petdex/              # Petdex format support
├── ActionPacks/         # Modular animation packs
├── AdvancedFeatures/    # Desktop space, external API, input sync
├── Sound/               # Audio feedback
├── Preferences/         # User settings persistence
└── MenuBar/             # Status bar UI
```

**Key patterns:**
- **Coordinator Pattern** — Central `AppCoordinator` routes all commands
- **MVVM + SwiftUI** — Views bound to `ObservableObject` view models
- **Dependency Injection** — `AppDependencyContainer` wires everything; no singletons
- **Event-Driven** — `PetEvent`, `CompanionEvent`, `BubbleTrigger` drive behavior
- **Pluggable Providers** — AI, image generation, and content packs via registries

---

## 🧪 Testing

```bash
# Run all tests
swift test

# Run specific test suites
swift test --filter DesktopPetUnitTests
swift test --filter DesktopPetValidation
```

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Ideas for Contributions

- 🎨 New pet designs and sprite sheets
- 🗣️ Additional personality profiles
- 🌍 Localization / internationalization
- 🧩 New content packs (action, dialogue, personality)
- 🐛 Bug fixes and performance improvements
- 📖 Documentation improvements

---

## 🙏 Acknowledgments

- **[Petdex](https://github.com/crafter-station/petdex)** — A community-driven pet sprite gallery ([petdex.crafter.run](https://petdex.crafter.run)). MofuPaw supports importing Petdex packages (`.zip`), but does not bundle, modify, or redistribute any Petdex assets. All Petdex resources are downloaded by users at runtime and remain subject to their original license.

---

## 📄 License

This project is licensed under the **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International** License — see the [LICENSE](LICENSE) file for details.

This means you are free to share and adapt this project, but **commercial use is not permitted**. Any derivative works must be shared under the same license.

---

<p align="center">
  Made with ❤️ and Swift<br>
  <sub>If you like MofuPaw, give it a ⭐!</sub>
</p>
