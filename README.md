# Projet de Recherche

## Description
[Add your project description here]

## Requirements
- Qt 6.8+
- CMake 3.16+
- C++17
- Python 3.x (for scripts)

## Project Structure
```
src/        - C++ source code
qml/        - QML interface files
resources/  - Assets (images, icons, etc.)
tests/      - Unit tests
docs/       - Documentation
scripts/    - Utility scripts
build/      - Build directory (ignored by git)
```

## Building and Running

### Option 1: Qt Creator (Recommended)
1. Open `CMakeLists.txt` in Qt Creator
2. Configure project (select kit if prompted)
3. Press **Build** (Ctrl+B)
4. Press **Run** (Ctrl+R)

Qt Creator handles all dependencies and paths automatically. This is the easiest way.

### Option 2: Command Line

**Important:** Regular bash/cmd won't work. You need Qt's environment with CMake and tools in PATH.

**Windows:** Open "Qt 6.x.x (MinGW)" terminal from Start Menu  
**Linux/Mac:** Qt tools are usually in PATH after installation

```bash
# Build
mkdir build
cd build
cmake ..
cmake --build .

# Run (Qt Creator users can skip this)
# Windows: Run from Qt Creator or the .exe won't find Qt DLLs
# Linux/Mac: ./appprojet_de_recherche
```

## Code Quality

This project uses automated tools to maintain code quality:

### Formatting (clang-format)
Auto-formats C++ code. Configuration in `.clang-format`.

```bash
# Format a file
clang-format -i src/myfile.cpp

# Format all C++ files
find . -name "*.cpp" -o -name "*.h" | xargs clang-format -i
```

VS Code users: Install "Clang-Format" extension for auto-format on save.

### Linting (clang-tidy)
Static analysis tool. Configuration in `.clang-tidy`.

```bash
# Analyze a file
clang-tidy src/myfile.cpp -- -std=c++17
```

### Pre-commit Hooks (Optional)
Auto-formats code before each commit.

```bash
# Install hooks
bash scripts/setup-hooks.sh

# Skip temporarily
git commit --no-verify
```

### Coding Guidelines
See [docs/CODING_GUIDELINES.md](docs/CODING_GUIDELINES.md) for detailed style guide.

## Resources
- [Qt Documentation](https://doc.qt.io/qt-6.8/gettingstarted.html)
- [CMake with Qt](https://doc.qt.io/qt-6/cmake-get-started.html)
- [Coding Guidelines](docs/CODING_GUIDELINES.md)

## License
MIT License - See [LICENSE.txt](LICENSE.txt)