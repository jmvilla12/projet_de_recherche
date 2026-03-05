cmake_minimum_required(VERSION 3.16)

project(projet_de_recherche VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Location Positioning)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appprojet_de_recherche
    src/main.cpp
)

qt_add_qml_module(appprojet_de_recherche
    URI projet_de_recherche
    QML_FILES
        qml/Main.qml
        qml/MapView.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appprojet_de_recherche PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appprojet_de_recherche
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appprojet_de_recherche
    PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Location Qt6::Positioning
)

include(GNUInstallDirs)
install(TARGETS appprojet_de_recherche
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
