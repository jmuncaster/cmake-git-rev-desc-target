cmake_minimum_required(VERSION 3.3)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} /usr/local/share/cmake/Modules)
include(GetGitRevisionDescription)

add_git_version_library(my_test_version)

add_executable(my_test main.cpp)
target_link_libraries(my_test my_test_version)
