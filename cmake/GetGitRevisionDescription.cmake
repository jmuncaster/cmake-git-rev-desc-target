# The following was taken from https://github.com/rpavlik/cmake-modules
# License: Boost Software License

# - Returns a version string from Git
#
# These functions force a re-configure on each git commit so that you can
# trust the values of the variables in your build system.
#
#  get_git_head_revision(<refspecvar> <hashvar> [<additional arguments to git describe> ...])
#
# Returns the refspec and sha hash of the current head revision
#
#  git_describe(<var> [<additional arguments to git describe> ...])
#
# Returns the results of git describe on the source tree, and adjusting
# the output so that it tests false if an error occurs.
#
#  git_get_exact_tag(<var> [<additional arguments to git describe> ...])
#
# Returns the results of git describe --exact-match on the source tree,
# and adjusting the output so that it tests false if there was no exact
# matching tag.
#
#  git_local_changes(<var>)
#
# Returns either "CLEAN" or "DIRTY" with respect to uncommitted changes.
# Uses the return code of "git diff-index --quiet HEAD --".
# Does not regard untracked files.
#
# Requires CMake 2.6 or newer (uses the 'function' command)
#
# Original Author:
# 2009-2010 Ryan Pavlik <rpavlik@iastate.edu> <abiryan@ryand.net>
# http://academic.cleardefinition.com
# Iowa State University HCI Graduate Program/VRAC
#
# Copyright Iowa State University 2009-2010.
# Distributed under the Boost Software License, Version 1.0.
# (See accompanying file LICENSE_1_0.txt or copy at
# http://www.boost.org/LICENSE_1_0.txt)

if(__get_git_revision_description)
	return()
endif()
set(__get_git_revision_description YES)

set(MY_FILENAME ${_gitdescmoddir}/GetGitRevisionDescription.cmake)

# We must run the following at "include" time, not at function call time,
# to find the path to this module rather than the path to a calling list file
get_filename_component(_gitdescmoddir ${CMAKE_CURRENT_LIST_FILE} PATH)
message("_gitdescmoddir: ${_gitdescmoddir}")

function(get_git_head_revision _refspecvar _hashvar)
	set(GIT_PARENT_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
	set(GIT_DIR "${GIT_PARENT_DIR}/.git")
	while(NOT EXISTS "${GIT_DIR}")	# .git dir not found, search parent directories
		set(GIT_PREVIOUS_PARENT "${GIT_PARENT_DIR}")
		get_filename_component(GIT_PARENT_DIR ${GIT_PARENT_DIR} PATH)
		if(GIT_PARENT_DIR STREQUAL GIT_PREVIOUS_PARENT)
			# We have reached the root directory, we are not in git
			set(${_refspecvar} "GITDIR-NOTFOUND" PARENT_SCOPE)
			set(${_hashvar} "GITDIR-NOTFOUND" PARENT_SCOPE)
			return()
		endif()
		set(GIT_DIR "${GIT_PARENT_DIR}/.git")
	endwhile()
	# check if this is a submodule
	if(NOT IS_DIRECTORY ${GIT_DIR})
		file(READ ${GIT_DIR} submodule)
		string(REGEX REPLACE "gitdir: (.*)\n$" "\\1" GIT_DIR_RELATIVE ${submodule})
		get_filename_component(SUBMODULE_DIR ${GIT_DIR} PATH)
		get_filename_component(GIT_DIR ${SUBMODULE_DIR}/${GIT_DIR_RELATIVE} ABSOLUTE)
	endif()
	set(GIT_DATA "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/git-data")
	if(NOT EXISTS "${GIT_DATA}")
		file(MAKE_DIRECTORY "${GIT_DATA}")
	endif()

	if(NOT EXISTS "${GIT_DIR}/HEAD")
		return()
	endif()
	set(HEAD_FILE "${GIT_DATA}/HEAD")
	configure_file("${GIT_DIR}/HEAD" "${HEAD_FILE}" COPYONLY)

	configure_file("${_gitdescmoddir}/GetGitRevisionDescription.cmake.in"
		"${GIT_DATA}/grabRef.cmake"
		@ONLY)
	include("${GIT_DATA}/grabRef.cmake")

	set(${_refspecvar} "${HEAD_REF}" PARENT_SCOPE)
	set(${_hashvar} "${HEAD_HASH}" PARENT_SCOPE)
endfunction()

function(git_describe _var)
	if(NOT GIT_FOUND)
		find_package(Git QUIET)
	endif()
	get_git_head_revision(refspec hash)
	if(NOT GIT_FOUND)
		set(${_var} "GIT-NOTFOUND" PARENT_SCOPE)
		return()
	endif()
	if(NOT hash)
		set(${_var} "HEAD-HASH-NOTFOUND" PARENT_SCOPE)
		return()
	endif()

	# TODO sanitize
	#if((${ARGN}" MATCHES "&&") OR
	#	(ARGN MATCHES "||") OR
	#	(ARGN MATCHES "\\;"))
	#	message("Please report the following error to the project!")
	#	message(FATAL_ERROR "Looks like someone's doing something nefarious with git_describe! Passed arguments ${ARGN}")
	#endif()

	#message(STATUS "Arguments to execute_process: ${ARGN}")

	execute_process(COMMAND
		"${GIT_EXECUTABLE}"
		describe
		${hash}
		${ARGN}
		WORKING_DIRECTORY
		"${CMAKE_CURRENT_SOURCE_DIR}"
		RESULT_VARIABLE
		res
		OUTPUT_VARIABLE
		out
		ERROR_QUIET
		OUTPUT_STRIP_TRAILING_WHITESPACE)
	if(NOT res EQUAL 0)
		set(out "${out}-${res}-NOTFOUND")
	endif()

	set(${_var} "${out}" PARENT_SCOPE)
endfunction()

function(git_get_exact_tag _var)
	git_describe(out --exact-match ${ARGN})
	set(${_var} "${out}" PARENT_SCOPE)
endfunction()

function(git_local_changes _var)
	if(NOT GIT_FOUND)
		find_package(Git QUIET)
	endif()
	get_git_head_revision(refspec hash)
	if(NOT GIT_FOUND)
		set(${_var} "GIT-NOTFOUND" PARENT_SCOPE)
		return()
	endif()
	if(NOT hash)
		set(${_var} "HEAD-HASH-NOTFOUND" PARENT_SCOPE)
		return()
	endif()

	execute_process(COMMAND
		"${GIT_EXECUTABLE}"
		diff-index --quiet HEAD --
		WORKING_DIRECTORY
		"${CMAKE_CURRENT_SOURCE_DIR}"
		RESULT_VARIABLE
		res
		OUTPUT_VARIABLE
		out
		ERROR_QUIET
		OUTPUT_STRIP_TRAILING_WHITESPACE)
	if(res EQUAL 0)
		set(${_var} "CLEAN" PARENT_SCOPE)
	else()
		set(${_var} "DIRTY" PARENT_SCOPE)
	endif()
endfunction()

# The following was inspired by:
# https://cmake.org/pipermail/cmake/2010-July/038015.html

function(create_version_header_template VERSION_HEADER_TEMPLATE)
  # Create template file
  message("creating: ${VERSION_HEADER_TEMPLATE}")
  file(WRITE ${VERSION_HEADER_TEMPLATE}
    "
    \#define GIT_REFSPEC \"@GIT_REFSPEC@\"\n
    \#define GIT_HASH \"@GIT_HASH@\"\n
    \#define GIT_DESCRIBE \"@GIT_DESCRIBE@\"\n
    \#define GIT_TAG \"@GIT_TAG@\"\n
    \#define GIT_LOCAL_CHANGES \"@GIT_LOCAL_CHANGES@\"\n
    "
    )
endfunction()

function(create_version_cmake_script)
  set(VERSION_CMAKE_SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/version.cmake)
  message("creating: ${VERSION_CMAKE_SCRIPT}")
  set(VERSION_HEADER_TEMPLATE ${CMAKE_CURRENT_BINARY_DIR}/version.h.in)
  set(VERSION_HEADER ${CMAKE_CURRENT_BINARY_DIR}/version.h)
  file(WRITE ${VERSION_CMAKE_SCRIPT}
    "
    include(${_gitdescmoddir}/GetGitRevisionDescription.cmake)

    get_git_head_revision(GIT_REFSPEC GIT_HASH)
    git_describe(GIT_DESCRIBE)
    git_get_exact_tag(GIT_TAG)
    git_local_changes(GIT_LOCAL_CHANGES)

    message(\"configuring: ${VERSION_HEADER}\")
    configure_file(${VERSION_HEADER_TEMPLATE} ${VERSION_HEADER} @ONLY)
    ")
endfunction()

function(add_git_version_library VERSION_TARGET)
  create_version_header_template(${CMAKE_CURRENT_BINARY_DIR}/version.h.in)
  create_version_cmake_script()

  # This target is always out-of-date and will be regenerated every build.
  set(VERSION_CUSTOM_TARGET ${VERSION_TARGET}_generated)
  message("adding: ${VERSION_CUSTOM_TARGET}")
  add_custom_target(
      ${VERSION_CUSTOM_TARGET}
      ${CMAKE_COMMAND}
      -P ${CMAKE_CURRENT_BINARY_DIR}/version.cmake
  )

  # This is the libary target to which you will link
  # This libarary should be header-only. But cmake <3.3 doesn't let you propagate dependencies correctly. See https://stackoverflow.com/questions/35630755
  # So we create a dummy.cpp file to the library target.
  message("adding: ${VERSION_TARGET}")
  file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${VERSION_TARGET}_dummy.cpp "int ${VERSION_TARGET}_dummy_version_function_12345() { return 0; }")
  add_library(${VERSION_TARGET} ${VERSION_TARGET}_dummy.cpp ${VERSION_HEADER})
  add_dependencies(${VERSION_TARGET} ${VERSION_CUSTOM_TARGET})
  target_include_directories(${VERSION_TARGET} INTERFACE ${CMAKE_CURRENT_BINARY_DIR})
endfunction()

