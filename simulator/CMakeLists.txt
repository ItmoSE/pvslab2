cmake_minimum_required(VERSION 3.20)

project(simulator C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(simulator
    main.c
    uart_driver.c
    command_parser.c
    traffic_light.c
    led.c
)

target_compile_definitions(simulator PRIVATE _DEFAULT_SOURCE)

target_compile_options(simulator PRIVATE
    -Wall
    -Wextra
)
