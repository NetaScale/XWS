project(XwinScript)
cmake_minimum_required(VERSION 3.9)

function(FlexCXXComp path)
GET_FILENAME_COMPONENT(file ${path} NAME_WE)
    add_custom_command(
      OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${file}.l.h
          ${CMAKE_CURRENT_BINARY_DIR}/${file}.l.cc
      COMMAND ${FLEX_EXECUTABLE}
      ARGS -o${CMAKE_CURRENT_BINARY_DIR}/${file}.l.cc
          --header-file=${CMAKE_CURRENT_BINARY_DIR}/${file}.l.h
          ${CMAKE_CURRENT_SOURCE_DIR}/${path}
      DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${path})
endfunction(FlexCXXComp)

function(ByaccComp path)
  GET_FILENAME_COMPONENT(file ${path} NAME_WE)
  add_custom_command(
      OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${file}.tab.cc
          ${CMAKE_CURRENT_BINARY_DIR}/${file}.tab.h
	  ${CMAKE_CURRENT_BINARY_DIR}/${file}.output
      COMMAND $<TARGET_FILE:byacc>
      ARGS -b ${CMAKE_CURRENT_BINARY_DIR}/${file}
          -d -v -i -L -o ${CMAKE_CURRENT_BINARY_DIR}/${file}.tab.cc ${path}
      DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${path}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
endfunction(ByaccComp)

add_subdirectory(cmd/byacc)
add_subdirectory(cmd/xwshost)