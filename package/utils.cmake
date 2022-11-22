# ~~~
# Usage Sample:
#   include(package/utils.cmake)
#   conan_install() # conan_install([conanfile_dir] [output_dir])
#   include(${CONAN_BUILD_INFO_CMAKE})
#   conan_basic_setup()
#
#   configure_version_h()
#   configure_output_directories()
#
#   print_include_directories()
#   print_all_linked_libraries(<your_lib/exe>)
#   print_all_variables()
# ~~~

set(PACKAGE_UTILS_CMAKE_DIRNAME
    ${CMAKE_CURRENT_LIST_DIR}
    CACHE INTERNAL "")

macro(activate_common_configuration)
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
    set(CMAKE_CXX_STANDARD 14)
endmacro()

macro(conan_install)
    set(variadic_args ${ARGN})
    list(LENGTH variadic_args variadic_count)
    if(${variadic_count} GREATER 0)
        list(
            GET
            variadic_args
            0
            CONANFILE_DIR)
    else()
        set(CONANFILE_DIR ${PROJECT_SOURCE_DIR})
    endif()
    if(${variadic_count} GREATER 1)
        list(
            GET
            variadic_args
            1
            OUTPUT_DIR)
    else()
        set(OUTPUT_DIR ${PROJECT_BINARY_DIR})
    endif()
    if(NOT CONAN_INSTALL_ARGS)
        if(CMAKE_SYSTEM_NAME STREQUAL "QNX")
            set(CONAN_INSTALL_ARGS "--generator cmake --profile qnx")
        else()
            set(CONAN_INSTALL_ARGS "--generator cmake")
        endif()
    endif()
    set(CONAN_INSTALL_CMD "conan install ${CONANFILE_DIR} ${CONAN_INSTALL_ARGS}")
    file(MAKE_DIRECTORY "${OUTPUT_DIR}")
    set(CONAN_INSTALL_LOG "${OUTPUT_DIR}/conan_install.log")
    message(STATUS "$ cd ${OUTPUT_DIR} && ${CONAN_INSTALL_CMD} 2>&1 | tee ${CONAN_INSTALL_LOG}")
    execute_process(
        COMMAND bash -c ${CONAN_INSTALL_CMD}
        WORKING_DIRECTORY ${OUTPUT_DIR}
        OUTPUT_FILE ${CONAN_INSTALL_LOG}
        RESULT_VARIABLE CONAN_INSTALL_RET
        ERROR_FILE ${CONAN_INSTALL_LOG})
    set(CONAN_BUILD_INFO_CMAKE ${OUTPUT_DIR}/conanbuildinfo.cmake)
    if(NOT EXISTS ${CONAN_BUILD_INFO_CMAKE}
       OR NOT
          CONAN_INSTALL_RET
          EQUAL
          "0")
        file(READ ${CONAN_INSTALL_LOG} CONAN_INSTALL_LOG_TEXT)
        message(WARNING ${CONAN_INSTALL_LOG_TEXT})
        message(FATAL_ERROR "`conan install` failed! See above for cmd & log.")
    endif()
endmacro()

# https://devops.momenta.works/Momenta/public/_git/topbind-cmake?path=%2FUtilities.cmake
macro(setup_git_branch)
    execute_process(
        COMMAND git rev-parse --abbrev-ref HEAD
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_BRANCH
        OUTPUT_STRIP_TRAILING_WHITESPACE)
endmacro()

macro(setup_git_commit_hash)
    execute_process(
        COMMAND git log -1 --format=%h --abbrev=8
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_COMMIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE)
endmacro()

macro(setup_git_commit_count)
    execute_process(
        COMMAND git rev-list --count HEAD
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_COMMIT_COUNT
        OUTPUT_STRIP_TRAILING_WHITESPACE)
endmacro()

macro(setup_git_commit_date)
    execute_process(
        COMMAND bash "-c" "git log -1 --date='format:%Y/%m/%d %H:%M:%S' --format='%cd'"
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_COMMIT_DATE
        OUTPUT_STRIP_TRAILING_WHITESPACE)
endmacro()

macro(setup_git_diff_name_only)
    execute_process(
        COMMAND bash "-c" "git diff --name-only | tr '\n' ','"
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_DIFF_NAME_ONLY
        OUTPUT_STRIP_TRAILING_WHITESPACE)
endmacro()

macro(setup_username_hostname)
    execute_process(
        COMMAND bash "-c" "echo $(id -u -n)@$(hostname) | tr '\n' ' '"
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE USERNAME_HOSTNAME
        OUTPUT_STRIP_TRAILING_WHITESPACE)
endmacro()

# same logic as in utils.mk:VERSION_FULL
macro(extract_version_from_changelog)
    execute_process(
        COMMAND bash "-c" "grep -m1 -E '^# v[0-9]+\.[0-9]+\.[0-9]+.*' CHANGELOG.md | cut -c 4-"
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE VERSION_FULL
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(VERSION_FULL STREQUAL "")
        set(VERSION_FULL "0.0.1_invalid_version")
    endif()
    string(
        REGEX MATCH
              "^([0-9]+)\\.([0-9]+)\\.([0-9]+)(.*)"
              VERSION_MATCHED
              ${VERSION_FULL})
    set(VERSION_MAJOR ${CMAKE_MATCH_1})
    set(VERSION_MINOR ${CMAKE_MATCH_2})
    set(VERSION_PATCH ${CMAKE_MATCH_3})
    set(VERSION_SUFFIX ${CMAKE_MATCH_4})
endmacro()

macro(print_include_directories)
    get_property(
        dirs
        DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        PROPERTY INCLUDE_DIRECTORIES)
    message(STATUS "all include directories:")
    foreach(dir ${dirs})
        message(STATUS "-   ${dir}")
    endforeach()
endmacro()

macro(print_all_linked_libraries target)
    get_target_property(libs ${target} LINK_LIBRARIES)
    message(STATUS "all linked libraries: (against ${target})")
    foreach(lib ${libs})
        message(STATUS "-   ${lib}")
    endforeach()
endmacro()

macro(print_all_variables)
    get_cmake_property(vars VARIABLES)
    list(SORT vars)
    message(STATUS "all variables:")
    foreach(var ${vars})
        message(STATUS "-   ${var}=${${var}}")
    endforeach()
endmacro()

macro(configure_version_h)
    setup_username_hostname()
    setup_git_branch()
    setup_git_commit_hash()
    setup_git_commit_count()
    setup_git_commit_date()
    setup_git_diff_name_only()
    extract_version_from_changelog()
    string(TOUPPER ${PROJECT_NAME} PROJECT_NAME_UPPERCASE)
    set(VERSION_H "${CMAKE_BINARY_DIR}/${PROJECT_NAME}/version.h")
    configure_file(${PACKAGE_UTILS_CMAKE_DIRNAME}/version.h.in ${VERSION_H} @ONLY)
    install(FILES ${VERSION_H} DESTINATION "include/${PROJECT_NAME}")
endmacro()

macro(configure_output_directories)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)
endmacro()
