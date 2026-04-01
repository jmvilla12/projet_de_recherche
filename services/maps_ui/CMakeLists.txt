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
        assets/images/app_icon.png
        assets/images/LogoIMT.png
        assets/images/LogoIMTInverso.png
        assets/images/Logo_Elegante.png
        assets/images/LogoFondoBlanco.png
        assets/images/LogoSinFondo.png
        assets/icons/wifi_off.svg
        assets/icons/Location_Searching.svg
        assets/icons/circulo_dibujar.svg
        assets/icons/restric_icon.svg
        assets/icons/sin_mision.png
        assets/icons/sin_restriccion.png
        assets/icons/icon_battery.svg
        assets/icons/cell5_bar.svg
        assets/icons/satellite_icon.svg
        assets/icons/location_icon.svg
        assets/icons/power_off_icon.svg
        assets/icons/globe_icon.svg
        assets/icons/delete_icon.svg
        assets/icons/delete_icon_white.svg
        assets/icons/area_icon.svg
        assets/icons/path_icon.svg
        assets/icons/time_icon.svg
        assets/icons/ruler_icon.svg
        assets/icons/share_icon.svg
        assets/icons/grid_icon.svg
    RESOURCES
        assets/fonts/Geist-Regular.ttf
        assets/fonts/Geist-Medium.ttf
        assets/fonts/Geist-Bold.ttf
        assets/fonts/Geist-SemiBold.ttf
        assets/fonts/Geist-Light.ttf
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
