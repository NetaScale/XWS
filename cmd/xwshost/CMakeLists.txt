BisonComp(Parser.yy)
FlexComp(Scanner.ll)

add_executable(xwshost AST.cc Bytecode.cc BytecodeGen.cc Interpreter.cc Main.cc
    MPS.cc Object.cc ObjectMemory.cc
    ${CMAKE_CURRENT_BINARY_DIR}/Parser.tab.cc
    ${CMAKE_CURRENT_BINARY_DIR}/Scanner.ll.cc)
target_include_directories(xwshost PUBLIC ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${PROJECT_SOURCE_DIR}/vendor/flex)
target_link_libraries(xwshost mps)

set_property(TARGET xwshost PROPERTY CXX_STANDARD 98)
