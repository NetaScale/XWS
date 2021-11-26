/*
 * These coded instructions, statements, and computer programs contain
 * software derived from the following specification:
 *
 * ECMA-262, 11th edition, June 2020: ECMAScript® 2020 Language Specification
 * https://262.ecma-international.org/11.0/
 */

%{
#include <cassert>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Driver.hh"

#define YYDEBUG 1
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

#define YYLEX jslex(driver->scanner, &yylval, &yylloc)
#define YYERROR_CALL(message) yyerror(driver, yychar, yystate, &yylloc, message)

void
yyerror (Driver * driver, int yystate, YYLTYPE * loc, char *s);
void
print_highlight(const char * txt, int first_line, int first_col, int last_line, int last_col);



#define YYERROR_DECL()
}

%code provides {
#define YY_DECL int jslex(yyscan_t yyscanner, int * const lval, YYLTYPE * loc)
YY_DECL;
}

%pure-parser
%parse-param { Driver *driver }

%start main

%token ELLIPSIS /* ... */
%token REGEXBODY REGEXFLAGS UNMATCHABLE
%token THIS NUL BOOLLIT STRINGLIT NUMLIT
%token IDENTIFIER YIELD AWAIT DELETE VOID TYPEOF NEW SUPER
%token IMPORT META TARGET INSTANCEOF IN

%token /* ~, ! */ PLUSPLUS MINUSMINUS /* ++, -- */
%token STARSTAR /* ** */
%token LSHIFT RSHIFT URSHIFT /*  <<, >>, >>> */
%token LTE GTE /* <=, >= */
%token EQ NEQ STRICTEQ STRICTNEQ  /* ==, !=, ===, !== */
%token LOGAND /* && */
%token LOGOR /* || */
%token QUESTIONQUESTION /* ?? */
/* ?, : */
%token /* = */ ASSIGNOP /* *=, /=, ... */

%%

main: Expression;

/* 11.8.5 Regular Expression Literals */
RegularExpressionLiteral
	: '/' { printf("Matching Ragex\n"); } REGEXBODY '/' REGEXFLAGS
	;

/*
 * 12 Expressions
 */

/* Lexical */

IdentifierNotReserved
	: IDENTIFIER
	;

/* 12.1 Identifiers */

/* these ought to include yield/await in some instances */

IdentifierReference
	: IdentifierNotReserved
	;

BindingIdentifier
	: IdentifierNotReserved
	;

LabelIdentifier
	: IdentifierNotReserved
	;

/* 12.2 Primary Expression */

PrimaryExpression
	: THIS
	| IdentifierReference
	| Literal
	| ArrayLiteral
	| ObjectLiteral
	/*| FunctionExpression
	| ClassExpression
	| GeneratorExpression
	| AsyncFunctionExpression*/
	| RegularExpressionLiteral
	| TemplateLiteral
	| CoverParenthesisedExpressionAndArrowParameterList
	;

CoverParenthesisedExpressionAndArrowParameterList
	: '(' Expression ')'
	| '(' Expression ',' ')'
	| '(' ')'
	| '(' ELLIPSIS BindingIdentifier ')'
	| '(' ELLIPSIS BindingPattern ')'
	| '(' Expression ',' ELLIPSIS BindingIdentifier ')'
	| '(' Expression ',' ELLIPSIS BindingPattern ')'
	;

/* 12.2.4 Literals */
Literal
	: NUL
	| BOOLLIT
	| NUMLIT
	| STRINGLIT
	;

/* 12.2.5. Array Initializer */
ArrayLiteral
	: '[' ']'
	| '[' Elision ']'
	| '[' ElementList ']'
	| '[' ElementList ',' Elision ']'
	| '[' ElementList ',' ']'
	;

ElementList
	: Elision AssignmentExpression
	| AssignmentExpression
	| Elision SpreadElement
	| SpreadElement
	| ElementList ',' Elision AssignmentExpression
	| ElementList ',' AssignmentExpression
	| ElementList ',' Elision SpreadElement
	| ElementList ',' SpreadElement
	;

Elision
	: ','
	| Elision ','
	;

SpreadElement
	: ELLIPSIS AssignmentExpression
	;

/* 12.2.6 Object Initialiser */
ObjectLiteral
	: '{' '}'
	| '{' PropertyDefinitionList '}'
	| '{' PropertyDefinitionList ',' '}'
	;

PropertyDefinitionList
	: PropertyDefinition
	| PropertyDefinitionList ',' PropertyDefinition
	;

PropertyDefinition
	: IdentifierReference
	| CoverInitializedName
	| PropertyName ':' AssignmentExpression
	/*| MethodDefinition*/
	| ELLIPSIS AssignmentExpression
	;

PropertyName
	: LiteralPropertyName
	| ComputedPropertyName
	;

LiteralPropertyName
	: IDENTIFIER
	| STRINGLIT
	| NUMLIT
	;

ComputedPropertyName
	: '[' AssignmentExpression ']'
	;

CoverInitializedName
	: IdentifierReference Initialiser
	;

Initialiser
	: '=' AssignmentExpression
	;

TemplateLiteral
	: UNMATCHABLE /* todo */
	;

/* 12.3 Left-Hand-Side Expressions */
MemberExpression
	: PrimaryExpression
	| MemberExpression '[' Expression ']'
	| MemberExpression '.' IDENTIFIER
	| MemberExpression TemplateLiteral
	| SuperProperty
	| MetaProperty
	| NEW MemberExpression Arguments
	;

SuperProperty
	: SUPER '[' Expression ']'
	| SUPER '.' IDENTIFIER
	;

MetaProperty
	: NewTarget
	| ImportMeta
	;

NewTarget
	: NEW '.' TARGET
	;

ImportMeta
	: IMPORT '.' META
	;

NewExpression
	: MemberExpression
	| NEW NewExpression
	;

CallExpression
	: CallMemberExpression
	| SuperCall
	| CallExpression Arguments
	| CallExpression '[' Expression ']'
	| CallExpression '.' IDENTIFIER
	| CallExpression TemplateLiteral
	;

CallMemberExpression
	: MemberExpression Arguments
	;

SuperCall
	: SUPER Arguments
	;

ImportCall
	: IMPORT '(' AssignmentExpression ')'
	;

Arguments
	: '(' ')'
	| '(' ArgumentList ')'
	;

ArgumentList
	: AssignmentExpression
	| ELLIPSIS AssignmentExpression
	| ArgumentList ',' AssignmentExpression
	| ArgumentList ',' ELLIPSIS AssignmentExpression
	;

/* todo OptionalExpression */

LeftHandSideExpression
	: NewExpression
	| CallExpression
	/* | OptionalExpression */
	;

/* 12.4 Update Expressions */
UpdateExpression
	: LeftHandSideExpression
	| LeftHandSideExpression PLUSPLUS
	| LeftHandSideExpression MINUSMINUS
	| PLUSPLUS UnaryExpression
	| MINUSMINUS UnaryExpression
	;

/* 12.5 Unary Operators */
UnaryExpression
	: UpdateExpression
	| DELETE UnaryExpression
	| VOID UnaryExpression
	| TYPEOF UnaryExpression
	| '+' UnaryExpression
	| '-' UnaryExpression
	| '~' UnaryExpression
	| '!' UnaryExpression
	/* | AwaitExpression */
	;

/* 12.6 Exponential Operator */
ExponentialExpression
	: UnaryExpression
	| UpdateExpression STARSTAR ExponentialExpression
	;

/* 12.7 Multiplicative Operators */
MultiplicativeExpression
	: ExponentialExpression
	| MultiplicativeExpression MultiplicativeOperator ExponentialExpression
	;

MultiplicativeOperator
	: '*'
	| '/'
	| '%'
	;

/* 12.8 Additive Operators */
AdditiveExpression
	: MultiplicativeExpression
	| AdditiveExpression '+' MultiplicativeExpression
	| AdditiveExpression '-' MultiplicativeExpression
	;

/* 12.9 Bitwise Shift Operators */
ShiftExpression
	: AdditiveExpression
	| ShiftExpression LSHIFT AdditiveExpression
	| ShiftExpression RSHIFT AdditiveExpression
	| ShiftExpression URSHIFT
	;

/* 12.10 Relational Operators */
RelationalExpression
	: ShiftExpression
	| RelationalExpression '<' ShiftExpression
	| RelationalExpression '>' ShiftExpression
	| RelationalExpression LTE ShiftExpression
	| RelationalExpression GTE ShiftExpression
	| RelationalExpression INSTANCEOF ShiftExpression
	| RelationalExpression IN ShiftExpression
	;

/* 12.11 Equality Operators */
EqualityExpression
	: RelationalExpression
	| EqualityExpression EQ RelationalExpression
	| EqualityExpression NEQ RelationalExpression
	| EqualityExpression STRICTEQ RelationalExpression
	| EqualityExpression STRICTNEQ RelationalExpression
	;

/* 12.12 Binary Bitwise Operators */
BitwiseANDExpression
	: EqualityExpression
	| BitwiseANDExpression '&' EqualityExpression
	;

BitwiseXORExpression
	: BitwiseANDExpression
	| BitwiseXORExpression '^' BitwiseANDExpression
	;

BitwiseORExpression
	: BitwiseXORExpression
	| BitwiseORExpression '|' BitwiseXORExpression
	;

/* 12.13 Binary Logical Operators */
LogicalANDExpression
	: BitwiseORExpression
	| LogicalANDExpression LOGAND BitwiseORExpression
	;
LogicalORExpression
	: LogicalANDExpression
	| LogicalORExpression LOGOR LogicalANDExpression
	;

CoalesceExpression
	: CoalesceExpressionHead QUESTIONQUESTION BitwiseORExpression
	;

CoalesceExpressionHead
	: CoalesceExpression
	| BitwiseORExpression
	;

ShortCircuitExpression
	: LogicalORExpression
	| CoalesceExpression
	;

/* 12.14 Conditional Operator */
ConditionalExpression
	: ShortCircuitExpression
	| ShortCircuitExpression '?' AssignmentExpression ':'
	    AssignmentExpression
	;

/* 12.15 Assignment Operator */
AssignmentExpression
	: ConditionalExpression
	| YieldExpression
	| ArrowFunction
	| AsyncArrowFunction
	| LeftHandSideExpression '=' AssignmentExpression
	| LeftHandSideExpression ASSIGNOP AssignmentExpression
	;

/* todo 12.15.5 Destructuring Assignment */

/* 12.16 Comma Operator */
Expression
	: AssignmentExpression
	| Expression ',' AssignmentExpression
	;

%%


void
yyerror(Driver *driver, int yychar, int yystate, YYLTYPE *loc, char *text)
{
	register int yyn, count = 0;
	if (((yyn = yysindex[yystate]) != 0) && (yyn < YYTABLESIZE)) {
		printf("%d:%d: %s\n", loc->first_line + 1, loc->first_column,
		    text);
		print_highlight(driver->txt, loc->first_line, loc->first_column,
		    loc->last_line, loc->last_column);
		printf("got %s, but expected one of:\n\t", yyname[yychar]);
		for (int i = ((yyn > 0) ? yyn : 0); i <= YYTABLESIZE; ++i) {
			int tok = i - yyn;
			/*printf("i %d, tok %d, yycheck[i] %d, %s\n",
				   i, tok, yycheck[i], yyname[tok]);*/
			if ((yycheck[i] == tok) && (tok != YYERRCODE))
				printf("%s%s", count++ > 0 ? ", " : "",
				    yyname[tok]);
		}
	}
	printf("\n");
}

void print_highlight(const char * txt, int first_line, int first_col, int last_line, int last_col)
{
	int i;
	char fmt[9] = "";
	const char* lineend = txt;

	/* advance to the relevant line number */
	for (i = first_line ; i > 0; i--) {
		/* advance to next line */
		txt = strchr(txt, '\n');
		assert (txt != NULL);
		txt++;
		assert(*txt != '\0');
	}

	/* limit printing to not include line-terminal \n if present */
	lineend = strchr(txt, '\n');
	if (lineend != NULL)
		sprintf(fmt, "%%.%ds\n", lineend - txt);
	else
		sprintf(fmt, "%%s\n");

	printf(fmt, txt);
	for (i = 0; i < first_col; i++)
		putchar(' ');
	for (i; i < last_col; i++)
		putchar('^');

	printf("\n");
}