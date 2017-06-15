# git-rev-desc-target

This code exists to allow one to define a version file for your project based on output from git-describe.

The version file contains the git hash, git-describe message, last tag, and whether the working tree is dirty.

# Installation

Just copy the cmake files to your cmake modules directory and include the code.

# Example

`CMakeLists.txt`
```
cmake_minimum_required(VERSION 3.3)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} /usr/local/share/cmake/Modules)
include(GitRevDescTarget)

add_git_revision_library(my_app_git_rev my_app_git_rev.h)

add_executable(my_app main.cpp)
target_link_libraries(my_app my_app_git_rev)
```

`main.cpp`
```
#include "my_app_git_rev.h"

#include <iostream>

using namespace std;

int main() {
  cout << "GIT_HASH: " << GIT_HASH << endl;
  return 0;
}
```

# Credits

The revision parsing code is based on code from this excellent collection of cmake modules: https://github.com/rpavlik/cmake-modules
