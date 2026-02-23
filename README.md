# Lumeño 📖✨

Lumeño is a premium, macOS-styled EPUB reader and language learning app built entirely with **SwiftUI** and native iOS frameworks. 

By combining the elegant reading experience of Apple Books with the powerful spaced-repetition learning of Anki, Lumeño allows users to read foreign language books, effortlessly translate unknown words using DeepL or Apple's native dictionary, and instantly generate interactive flashcards.

## ✨ Features

- **Beautiful EPUB Rendering**: A fully custom `WKWebView` engine that supports strict exact-multiple column pagination for a flawless, iOS-native swiping experience.
- **Deep Customization**: Adjust fonts, spacing (line, word, character), margins, and text alignment through a premium, Apple Books-inspired appearance menu.
- **Integrated Translation**: Bypasses the native iOS selection menu for an instant, distraction-free translation experience powered by the **DeepL Pro API** (or Apple's offline translation fallback).
- **Spaced Repetition (SRS)**: Auto-generated flashcards from the words you highlight in your books, organized into custom decks with reading context attached.
- **Smart Analytics**: Tracks your reading progress, vocabulary frequency ranks (1-5000+ most common words), and personalized learning difficulty curves.
- **Seamless Backup Integration**: All flashcard decks are automatically saved as `.tsv` files to the iOS Files app, making it trivial to drag-and-drop your vocabulary directly into Anki.

## 🛠️ Technology Stack

- **SwiftUI & SwiftData**: Built exclusively for iOS 18 with modern declarative UI and persistence.
- **WebKit (`WKWebView`)**: Heavily customized with Javascript bridging to interact with the EPUB DOM, disabling native hit-testing, menus, and scroll-bouncing to mimic native text rendering.
- **XcodeGen**: Project files (`.xcodeproj`) are not committed to source control. Instead, the project is generated deterministically using a `project.yml` file.

## 🚀 Building the Project

Lumeño uses **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** to generate the Xcode project. This prevents merge conflicts in the `.xcodeproj` file and ensures a clean build environment.

### Prerequisites

1.  **Xcode 16+** (iOS 18 SDK required)
2.  **Homebrew**
3.  **XcodeGen**:
    ```bash
    brew install xcodegen
    ```

### Setup

1.  Clone the repository:
    ```bash
    git clone https://github.com/YOUR_USERNAME/Lumeño.git
    cd Lumeño
    ```

2.  Generate the Xcode project:
    ```bash
    xccodegen generate 
    # Or simply: xcodegen
    ```

3.  Open the newly generated `Lumeño.xcodeproj`.
4.  Select a simulator (iPhone 15 Pro recommended) and press **Run (Cmd+R)**.

## 🔑 API Configuration

To use the inline translation feature, you will need a DeepL API key (Free or Pro tier works).
1. Go to the app's **Settings > Translation**.
2. Paste your DeepL API key.
3. If no key is provided, the app gracefully falls back to the native iOS offline translation popover.

## 📂 Project Structure

*   **/Sources**: All Swift source code.
    *   **`/Models`**: SwiftData models (`Book`, `Chapter`, `Flashcard`, `Deck`).
    *   **`/ViewModels`**: State management and business logic.
    *   **`/Views`**: SwiftUI views (Reader, Library, Flashcards, Settings).
    *   **`/Utilities`**: Helpers (EPUB parsing, Backup Manager, DeepL API).
*   **/Resources**: Assets, colors (LumeñoPastel palette), and required fonts.
*   `project.yml`: The XcodeGen specification file.

## 📜 License
*MIT License*
