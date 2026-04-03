add_library(pathfinding_lib STATIC
    Pathfinding.cpp
    Pathfinding.h
)

target_include_directories(pathfinding_lib PUBLIC .)
target_link_libraries(pathfinding_lib PRIVATE Qt6::Core)
