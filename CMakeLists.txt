project(XwinScript)
cmake_minimum_required(VERSION 3.9)

#
# functions
#

function(FlexComp path)
GET_FILENAME_COMPONENT(file ${path} NAME_WE)
    add_custom_command(
      OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${file}.ll.hh
          ${CMAKE_CURRENT_BINARY_DIR}/${file}.ll.cc
      COMMAND ${FLEX_EXECUTABLE}
      ARGS -o${CMAKE_CURRENT_BINARY_DIR}/${file}.ll.cc
          --header-file=${CMAKE_CURRENT_BINARY_DIR}/${file}.ll.hh
          ${CMAKE_CURRENT_SOURCE_DIR}/${path}
      DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${path})
endfunction(FlexComp)

function(BisonComp path)
  GET_FILENAME_COMPONENT(file ${path} NAME_WE)
  add_custom_command(
      OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${file}.tab.cc
          ${CMAKE_CURRENT_BINARY_DIR}/${file}.tab.hh
	  ${CMAKE_CURRENT_BINARY_DIR}/${file}.output
      COMMAND ${BISON_EXECUTABLE}
      ARGS --verbose -Wall
          -o ${CMAKE_CURRENT_BINARY_DIR}/${file}.tab.cc -d ${path}
      DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${path}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
endfunction(BisonComp)

#
# feature checks
#

find_package(FLEX)
find_package(BISON)

if (NOT FLEX_FOUND)
	set(FLEX_FOUND true)
	set(FLEX_EXECUTABLE ${PROJECT_SOURCE_DIR}/vendor/flex/win_flex.exe)
	message(STATUS "Flex for Windows used: " ${FLEX_EXECUTABLE})
endif ()

if (NOT BISON_FOUND)
	set(BISON_FOUND TRUE)
	set(BISON_EXECUTABLE ${PROJECT_SOURCE_DIR}/vendor/flex/win_bison.exe)
	message(STATUS "Bison for Windows used: " ${BISON_EXECUTABLE})
endif ()

add_subdirectory(lib/mps)
add_subdirectory(cmd/xwshost)