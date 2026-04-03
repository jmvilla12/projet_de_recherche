cmake_minimum_required(VERSION 3.16)

project(pdr_microservices VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Location Positioning)

qt_standard_project_setup(REQUIRES 6.8)

# Add subdirectories for each service
add_subdirectory(services/maps_ui)
add_subdirectory(services/pathfinding)
add_subdirectory(services/export_service)
