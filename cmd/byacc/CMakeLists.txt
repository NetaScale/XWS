set(SRC ${PROJECT_SOURCE_DIR}/vendor/byacc)
add_executable(byacc ${SRC}/closure.c ${SRC}/error.c ${SRC}/graph.c
    ${SRC}/lalr.c ${SRC}/lr0.c ${SRC}/main.c ${SRC}/mkpar.c ${SRC}/mstring.c
    ${SRC}/output.c ${SRC}/reader.c ${SRC}/symtab.c ${SRC}/verbose.c
    ${SRC}/warshall.c ${SRC}/yaccpar.c)