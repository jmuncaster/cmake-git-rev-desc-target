cmake_minimum_required(VERSION 3.3)

if(__git_rev_desc_target)
	return()
endif()
set(__git_rev_desc_target YES)

# We must run the following at "include" time, not at function call time,
# to find the path to this module rather than the path to a calling list file
get_filename_component(_thismoduledir ${CMAKE_CURRENT_LIST_FILE} PATH)
#message("_thismoduledir: ${_thismoduledir}")

#----------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------
# The following was taken from https://github.com/rpavlik/cmake-modules
# License: Boost Software License

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

	configure_file("${_thismoduledir}/GitRevDescTarget.cmake.in"
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

#----------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------
# The following was inspired by:
# https://cmake.org/pipermail/cmake/2010-July/038015.html

function(create_version_header_template version_header_template)
  # Create template file
  #message("creating: ${version_header_template}")
  file(WRITE ${version_header_template}
    "
    \#define GIT_REFSPEC \"@GIT_REFSPEC@\"\n
    \#define GIT_HASH \"@GIT_HASH@\"\n
    \#define GIT_DESCRIBE \"@GIT_DESCRIBE@\"\n
    \#define GIT_TAG \"@GIT_TAG@\"\n
    \#define GIT_LOCAL_CHANGES \"@GIT_LOCAL_CHANGES@\"\n
    "
    )
endfunction()


function(create_version_cmake_script version_header_template version_header version_cmake_script)
  #message("creating: ${version_cmake_script}")
  file(WRITE ${version_cmake_script}
    "
    include(${_thismoduledir}/GitRevDescTarget.cmake)

    get_git_head_revision(GIT_REFSPEC GIT_HASH)
    git_describe(GIT_DESCRIBE)
    git_get_exact_tag(GIT_TAG)
    git_local_changes(GIT_LOCAL_CHANGES)

    #message(\"configuring: ${version_header}\")
    configure_file(${version_header_template} ${version_header} @ONLY)
    ")
endfunction()


function(add_git_revision_library target version_header)

  set(version_header_template ${CMAKE_CURRENT_BINARY_DIR}/${target}.h.in)
  set(version_cmake_script ${CMAKE_CURRENT_BINARY_DIR}/${target}.cmake)

  create_version_header_template(${version_header_template})
  create_version_cmake_script(${version_header_template} ${target}/${version_header} ${version_cmake_script})

  # This target is always out-of-date and will be regenerated every build, ensuring you have the
  # most up-to-date information. If the contents of the file do not change the file will not
  # be touched so unnecessary rebuilds of dependent targets won't occur.
  #message("adding: ${target}_header")
  add_custom_target(${target}_header ${CMAKE_COMMAND} -P ${version_cmake_script})

  # This is the libary target to which you will link.
  #message("adding: ${target} (${version_header})")
  add_library(${target} INTERFACE)
  target_include_directories(${target} INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/${target})
  add_dependencies(${target} ${target}_header)
endfunction()

