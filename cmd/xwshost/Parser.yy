/*
 * These coded instructions, statements, and computer programs contain
 * software derived from the following specification:
 *
 * ECMA-262, 11th edition, June 2020
 * ECMAScript® 2020 Language Specification
 * https://262.ecma-international.org/11.0/
 */

%{
#include <stdio.h>
#include <stdlib.h>

#include "Driver.hh"
%}

%code requires {
#include "Driver.hh"

#ifdef yylex
#undef yylex

#endif
#ifdef YYERROR_DECL
#undef YYERROR_DECL
#endif
#ifdef YYERROR_CALL
#undef YYERROR_CALL
#endif
#ifdef YYLEX
#undef YYLEX
#endif

//#define yylex driver->yylex

#define YYLEX jslex(driver->scanner, &yylval, &yylloc)
#define YYERROR_CALL(message) yyerror(&yylloc, message)
#define YYERROR_DECL()
}

%code provides {
#define YY_DECL int jslex(yyscan_t yyscanner, int * const lval, YYLTYPE * loc)
YY_DECL;
}

%pure-parser
%parse-param { Driver *driver }

%token MAIN

%%

main: MAIN;

%%

void
yyerror (YYLTYPE * loc, char *s)
{
	fprintf (stderr, "%d:%d: %s\n", loc->first_line, loc->first_column, s);
}
