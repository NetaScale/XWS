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

function(ByaccComp path)
  GET_FILENAME_COMPONENT(file ${path} NAME_WE)
  add_custom_command(
      OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${file}.tab.cc
          ${CMAKE_CURRENT_BINARY_DIR}/${file}.tab.h
	  ${CMAKE_CURRENT_BINARY_DIR}/${file}.output
      COMMAND $<TARGET_FILE:byacc>
      ARGS -b ${CMAKE_CURRENT_BINARY_DIR}/${file}
          -d -v -i -l -L -o ${CMAKE_CURRENT_BINARY_DIR}/${file}.tab.cc ${path}
      DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${path}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
endfunction(ByaccComp)

#
# feature checks
#

find_package(FLEX)

if (NOT FLEX_FOUND)
	set(FLEX_FOUND true)
	set(FLEX_EXECUTABLE ${PROJECT_SOURCE_DIR}/vendor/flex/win_flex.exe)
	message(STATUS "Flex for Windows used: " ${FLEX_EXECUTABLE})
endif()

add_subdirectory(cmd/byacc)
add_subdirectory(cmd/xwshost)