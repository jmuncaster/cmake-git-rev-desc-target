cmake_minimum_required(VERSION 3.3)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} /usr/local/share/cmake/Modules)
include(GitRevDescTarget)

add_git_revision_library(my_app_git_rev my_app_git_rev.h)

add_executable(my_app main.cpp)
target_link_libraries(my_app my_app_git_rev)

