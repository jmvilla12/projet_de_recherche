# Coding Guidelines

## Overview
This document defines the coding standards for the Projet de Recherche codebase. Consistency in code style improves readability and maintainability.

## Code Formatting

### Automated Tools
- **clang-format**: Auto-formats C++ code (like Prettier for TypeScript)
- **clang-tidy**: Static analysis and linting (like ESLint for TypeScript)

Both tools are configured in `.clang-format` and `.clang-tidy` files.

### Running Tools Manually

```bash
# Format a single file
clang-format -i src/myfile.cpp

# Format all C++ files (handles spaces in paths)
find . \( -name "*.cpp" -o -name "*.h" \) -print0 | xargs -0 clang-format -i

# Run clang-tidy
clang-tidy src/myfile.cpp -- -std=c++17
```

## C++ Style Guidelines

### Naming Conventions

```cpp
// Classes: CamelCase
class MyClass {};

// Functions and variables: camelCase
void calculateTotal() {}
int itemCount = 0;

// Constants: UPPER_CASE
const int MAX_SIZE = 100;

// Private members: camelCase with m_ prefix (Qt convention)
class Widget {
private:
    int m_value;
    QString m_name;
};
```

### File Organization

```cpp
// Header files (.h)
#pragma once  // or #ifndef guards

#include <QWidget>  // Qt headers first
#include <string>   // STD headers second

class MyClass {
public:
    MyClass();
    ~MyClass();
    
    void publicMethod();
    
private:
    void privateMethod();
    int m_member;
};
```

### Indentation and Spacing
- 4 spaces (no tabs)
- 100 character line limit
- Space after control statements: `if (condition)`
- Opening braces on same line: `void func() {`

### Modern C++ Features

Use C++17 features:
```cpp
// Use auto when type is obvious
auto result = calculateValue();

// Range-based for loops
for (const auto& item : items) {
    process(item);
}

// nullptr instead of NULL
MyClass* ptr = nullptr;

// Smart pointers
auto widget = std::make_unique<QWidget>();
```

## Qt-Specific Guidelines

### Signal and Slots
```cpp
// Use new connection syntax
connect(button, &QPushButton::clicked, 
        this, &MyClass::onButtonClicked);

// Avoid old SIGNAL/SLOT macros
// connect(button, SIGNAL(clicked()), this, SLOT(onButtonClicked())); // Don't use
```

### Memory Management
```cpp
// Qt handles memory for QObject children
auto* button = new QPushButton(this); // 'this' is parent, no manual delete needed

// For non-QObject, use smart pointers
auto data = std::make_unique<MyData>();
```

### QML Best Practices
```qml
// Use property bindings
width: parent.width * 0.8

// Descriptive IDs
Rectangle {
    id: mainContainer
    // ...
}

// Group related properties
anchors {
    top: parent.top
    left: parent.left
    margins: 10
}
```

## Comments

Write comments only when code isn't self-explanatory:

```cpp
// Good: Explains WHY
// Timeout set to 5s to prevent hanging on slow networks
const int TIMEOUT_MS = 5000;

// Bad: Explains WHAT (code already shows this)
// Set x to 10
int x = 10;

// Use doxygen-style comments for public APIs
/**
 * @brief Calculates the total price including tax
 * @param basePrice The price before tax
 * @param taxRate Tax rate as decimal (e.g., 0.15 for 15%)
 * @return Total price with tax applied
 */
double calculateTotal(double basePrice, double taxRate);
```

## Git Commit Guidelines

### Commit Message Format
```
type(scope): subject

body (optional)

footer (optional)
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting changes
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Build process, tools

### Examples
```bash
feat(ui): add dark mode toggle button

fix(network): handle timeout in API requests

docs(readme): update build instructions
```

## Testing

### Unit Tests Structure
```cpp
#include <QTest>

class MyClassTest : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {}  // Run once before all tests
    void init() {}          // Run before each test
    void testSomething() {
        QCOMPARE(actual, expected);
    }
    void cleanup() {}       // Run after each test
    void cleanupTestCase() {} // Run once after all tests
};
```

## Pull Request Guidelines

Before submitting a PR:
1. Run clang-format on modified files
2. Run clang-tidy to check for issues
3. Ensure code compiles without warnings
4. Add tests for new features
5. Update documentation if needed

## Resources
- [Qt Coding Style](https://wiki.qt.io/Qt_Coding_Style)
- [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)
- [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html)
