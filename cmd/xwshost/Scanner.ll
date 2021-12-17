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
#include "AST.hh"

#define YY_USER_INIT        \
	loc->last_line = 0; \
	loc->last_column = 0;

#define YY_USER_ACTION {                          \
	loc->first_line = loc->last_line;         \
	loc->first_column = loc->last_column;     \
                                                  \
	for (int i = 0; yytext[i] != '\0'; i++) { \
		if (yytext[i] == '\n') {          \
			loc->last_line++;         \
			loc->last_column = 0;     \
		} else                            \
			loc->last_column++;       \
	}                                         \
	}
%}

/* todo NBSP, ZWNBSP, USP */
WhiteSpace	([\t\v\f ])
/* todo LS, PS */
LineTerminator	([\n\r])
LineTerminatorSequence	((\r\n)|{LineTerminator}) /* needs also LS, PS */

/* todo unicode ID_START, \UnicodeEscapeSequence */
IdentifierStart ([a-zA-Z$_])
/* todo unicode ID_Continue */
IdentifierPart ([a-zA-Z0-9$_])

IdentifierName {IdentifierStart}{IdentifierPart}*

DecimalIntegerLiteral	0|([1-9][0-9]*)

DecimalLiteral {DecimalIntegerLiteral}
%%

{WhiteSpace}+		{}
{LineTerminator}	{}

"null"			{ return NULLTOK; }
"true"			{ return BOOLLIT; }
"false"			{ return BOOLLIT; }

"as"		return AS;
"async"		return ASYNC;
"await"		return AWAIT;
"break"		return BREAK;
"case"		return CASE;
"catch"		return CATCH;
"class"		return CLASS;
"const"		return CONST;
"continue"	return CONTINUE;
"debugger"	return DEBUGGER;
"default"	return DEFAULT;
"delete"	return DELETE;
"do"		return DO;
"else"		return ELSE;
"enum"		return ENUM;
"eval"		return EVAL;
"export"	return EXPORT;
"extends"	return EXTENDS;
"finally"	return FINALLY;
"for"		return FOR;
"from"		return FROM;
"function"	return FUNCTION;
"get"		return GET;
"if"		return IF;
"implements"	return IMPLEMENTS;
"import"	return IMPORT;
"in"		return IN;
"instanceof"	return INSTANCEOF;
"interface"	return INTERFACE;
"let"		return LET;
"new"		return NEW;
"of"		return OF;
"package"	return PACKAGE;
"private"	return PRIVATE;
"protected"	return PROTECTED;
"public"	return PUBLIC;
"return"	return RETURN;
"set"		return SET;
"static"	return STATIC;
"super"		return SUPER;
"switch"	return SWITCH;
"target"	return TARGET;
"this"		return THIS;
"throw"		return THROW;
"try"		return TRY;
"typeof"	return TYPEOF;
"var"		return VAR;
"void"		return VOID;
"while"		return WHILE;
"with"		return WITH;
"yield"		return YIELD;

"++"		return PLUSPLUS;
"--"		return MINUSMINUS;
"**"		return STARSTAR;
"<<"		return LSHIFT;
">>"		return RSHIFT;
">>>"		return URSHIFT;
"<="		return LTE;
">="		return GTE;
"=="		return EQ;
"!="		return NEQ;
"==="		return STRICTEQ;
"!=="		return STRICTNEQ;
"&&"		return LOGAND;
"||"		return LOGOR;
"??"		return QUESTIONQUESTION;
"=>"		return FARROW;
"..."		return ELLIPSIS;

{IdentifierName}	{
	yylval->str = strdup(yytext);
	return IDENTIFIER;
}

{DecimalLiteral}	{
	yylval->exprNode = new NumberNode(*loc, strtod(yytext, 0));
	return NUMLIT;
}

.	return (int)yytext[0];
