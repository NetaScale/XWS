%top {
#include <sys/types.h>

#include <malloc.h>
#include <string.h>
#include <stdlib.h>

#ifdef _MSC_VER
#define YY_NO_UNISTD_H 1
#define isatty(x) 0
#endif
}

%option reentrant
%option noyywrap
%option stack
%option yylineno
%option extra-type = "Driver *"
%option prefix = "js"

%{
#include "Parser.tab.h"

#define YY_USER_INIT        \
	loc->last_line = 0; \
	loc->last_column = 0;

#define YY_USER_ACTION                            \
	loc->first_line = loc->last_line;         \
	loc->first_column = loc->last_column;     \
                                                  \
	for (int i = 0; yytext[i] != '\0'; i++) { \
		if (yytext[i] == '\n') {          \
			loc->last_line++;         \
			loc->last_column = 0;     \
		} else                            \
			loc->last_column++;       \
	}
%}

%%

"\n"	
" "
[^ \n]+	return YIELD;
