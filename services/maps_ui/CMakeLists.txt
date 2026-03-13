set(MAPS_UI_SOURCES
    src/main.cpp
    src/AreaController.cpp
    src/AreaController.h
)

qt_add_executable(app_maps_ui
    ${MAPS_UI_SOURCES}
)

qt_add_qml_module(app_maps_ui
    URI projet_de_recherche
    QML_FILES
        Main.qml
        MapView.qml
        app_icon.png
        LogoIMT.png
        LogoIMTInverso.png
)

target_link_libraries(app_maps_ui
    PRIVATE 
        Qt6::Quick 
        Qt6::QuickControls2 
        Qt6::Location 
        Qt6::Positioning
        pathfinding_lib
        export_service_lib
)

# Deployment and Install
set_target_properties(app_maps_ui PROPERTIES
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)
