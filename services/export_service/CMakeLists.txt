add_library(export_service_lib STATIC
    CoordinateExporter.cpp
    CoordinateExporter.h
)

target_include_directories(export_service_lib PUBLIC .)
target_link_libraries(export_service_lib PRIVATE Qt6::Core)
