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
#include "Parser.tab.hh"

#define YYDEBUG 1

static int assign_merge (YYSTYPE pattern, YYSTYPE regular);
%}

%code requires {
#include "Driver.hh"

#define AUTO_SEMICOLON printf(" -> ADDING AUTO SC\n");

void
jserror(YYLTYPE * loc, Driver * driver, const char * msg);
void
print_highlight(const char * txt, int first_line, int first_col, int last_line,
    int last_col);

/*
#define YYLEX jslex(driver->scanner, &yylval, &yylloc)
#define YYERROR_CALL(message) yyerror(driver, yychar, yystate, &yylloc, message)

void
yyerror (Driver * driver, int yystate, YYLTYPE * loc, char *s);

*/
}

%code provides {
#define YY_DECL int \
	true_jslex(JSSTYPE *yylval, JSLTYPE *loc, yyscan_t yyscanner, \
	    Driver * driver)

YY_DECL;
int
jslex(JSSTYPE *yylval, JSLTYPE *loc, Driver * driver);
}

%define api.pure
%define api.prefix {js}
%define parse.trace
%define parse.error verbose
%param { Driver *driver }
%locations

%start Script

%token AS ASYNC AWAIT BREAK CASE CATCH CLASS CONST CONTINUE DEBUGGER DEFAULT
%token DELETE DO ELSE ENUM EVAL EXPORT EXTENDS FINALLY FOR FROM FUNCTION GET IF
%token IMPLEMENTS IMPORT IN INSTANCEOF INTERFACE LET NEW OF PACKAGE PRIVATE
%token PROTECETED PUBLIC RETURN SET STATIC SUPER SWITCH TARGET THIS THROW TRY
%token TYPEOF VAR VOID WHILE WITH YIELD 

%token ELLIPSIS /* ... */
%token REGEXBODY REGEXFLAGS UNMATCHABLE
%token NULLTOK BOOLLIT STRINGLIT NUMLIT
%token IDENTIFIER
%token META

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

/* 11.8.5 Regular Expression Literals */
RegularExpressionLiteral:
	  '/' { printf("Matching Ragex\n"); } REGEXBODY '/' REGEXFLAGS
	;

/*
 * 12 Expressions
 */

/* Lexical */

IdentifierNotReserved:
	  IDENTIFIER
	;

/* 12.1 Identifiers */

/* these ought to include yield/await in some instances */

IdentifierReference:
	  IdentifierNotReserved
	;

BindingIdentifier:
	  IdentifierNotReserved
	;

LabelIdentifier:
	  IdentifierNotReserved
	;

/* 12.2 Primary Expression */

PrimaryExpression:
	  PrimaryExpression_NoBrace
	| ObjectLiteral
	/*| FunctionExpression
	| ClassExpression
	| GeneratorExpression
	| AsyncFunctionExpression*/
	| RegularExpressionLiteral
	| TemplateLiteral
	;

PrimaryExpression_NoBrace:
	  THIS
	| IdentifierReference
	| Literal
	| ArrayLiteral
	| CoverParenthesisedExpressionAndArrowParameterList
	;

CoverParenthesisedExpressionAndArrowParameterList:
	  '(' Expression ')'
	| '(' Expression ',' ')'
	| '(' ')'
	| '(' ELLIPSIS BindingIdentifier ')'
	| '(' ELLIPSIS BindingPattern ')'
	| '(' Expression ',' ELLIPSIS BindingIdentifier ')'
	| '(' Expression ',' ELLIPSIS BindingPattern ')'
	;

/* 12.2.4 Literals */
Literal:
	  NULLTOK
	| BOOLLIT
	| NUMLIT
	| STRINGLIT
	;

/* 12.2.5. Array Initializer */
ArrayLiteral:
	  '[' ']'
	| '[' Elision ']'
	| '[' ElementList ']'
	| '[' ElementList ',' Elision ']'
	| '[' ElementList ',' ']'
	;

ElementList:
	  Elision AssignmentExpression
	| AssignmentExpression
	| Elision SpreadElement
	| SpreadElement
	| ElementList ',' Elision AssignmentExpression
	| ElementList ',' AssignmentExpression
	| ElementList ',' Elision SpreadElement
	| ElementList ',' SpreadElement
	;

Elision:
	  ','
	| Elision ','
	;

SpreadElement:
	  ELLIPSIS AssignmentExpression
	;

/* 12.2.6 Object Initialiser */
ObjectLiteral:
	  '{' '}'
	| '{' PropertyDefinitionList '}'
	| '{' PropertyDefinitionList ',' '}'
	;

PropertyDefinitionList:
	  PropertyDefinition
	| PropertyDefinitionList ',' PropertyDefinition
	;

PropertyDefinition:
	  IdentifierReference
	| CoverInitializedName
	| PropertyName ':' AssignmentExpression
	/*| MethodDefinition*/
	| ELLIPSIS AssignmentExpression
	;

PropertyName:
	  LiteralPropertyName
	| ComputedPropertyName
	;

LiteralPropertyName:
	  IDENTIFIER
	| STRINGLIT
	| NUMLIT
	;

ComputedPropertyName:
	  '[' AssignmentExpression ']'
	;

CoverInitializedName:
	  IdentifierReference Initialiser
	;

Initialiser:
	  '=' AssignmentExpression
	;

TemplateLiteral:
	  UNMATCHABLE /* todo */
	;

/* 12.3 Left-Hand-Side Expressions */
MemberExpression:
	  PrimaryExpression
	| MemberExpression '[' Expression ']'
	| MemberExpression '.' IDENTIFIER
	| MemberExpression TemplateLiteral
	| SuperProperty
	| MetaProperty
	| NEW MemberExpression Arguments
	;

MemberExpression_NoBrace:
	  PrimaryExpression_NoBrace
	| MemberExpression_NoBrace '[' Expression ']'
	| MemberExpression_NoBrace '.' IDENTIFIER
	| MemberExpression_NoBrace TemplateLiteral
	| SuperProperty
	| MetaProperty
	| NEW MemberExpression Arguments
	;

SuperProperty:
	  SUPER '[' Expression ']'
	| SUPER '.' IDENTIFIER
	;

MetaProperty:
	  NewTarget
	| ImportMeta
	;

NewTarget:
	  NEW '.' TARGET
	;

ImportMeta:
	  IMPORT '.' META
	;

NewExpression:
	  MemberExpression
	| NEW NewExpression
	;

NewExpression_NoBrace:
	  MemberExpression_NoBrace
	| NEW NewExpression
	;

CallExpression:
	  CallMemberExpression
	| SuperCall
	| CallExpression Arguments
	| CallExpression '[' Expression ']'
	| CallExpression '.' IDENTIFIER
	| CallExpression TemplateLiteral
	;

CallExpression_NoBrace:
	  CallMemberExpression_NoBrace
	| SuperCall
	| CallExpression_NoBrace Arguments
	| CallExpression_NoBrace '[' Expression ']'
	| CallExpression_NoBrace '.' IDENTIFIER
	| CallExpression_NoBrace TemplateLiteral
	;

CallMemberExpression:
	  MemberExpression Arguments
	;

CallMemberExpression_NoBrace:
	  MemberExpression_NoBrace Arguments
	;

SuperCall:
	  SUPER Arguments
	;

ImportCall:
	  IMPORT '(' AssignmentExpression ')'
	;

Arguments:
	  '(' ')'
	| '(' ArgumentList ')'
	;

ArgumentList:
	  AssignmentExpression
	| ELLIPSIS AssignmentExpression
	| ArgumentList ',' AssignmentExpression
	| ArgumentList ',' ELLIPSIS AssignmentExpression
	;

/* todo OptionalExpression */

LeftHandSideExpression:
	  NewExpression
	| CallExpression
	/* | OptionalExpression */
	;

LeftHandSideExpression_NoBrace:
	  NewExpression_NoBrace
	| CallExpression_NoBrace
	/* | OptionalExpression */
	;

/* 12.4 Update Expressions */
UpdateExpression:
	  LeftHandSideExpression
	| LeftHandSideExpression PLUSPLUS
	| LeftHandSideExpression MINUSMINUS
	| PLUSPLUS UnaryExpression
	| MINUSMINUS UnaryExpression
	;

UpdateExpression_NoBrace:
	  LeftHandSideExpression_NoBrace
	| LeftHandSideExpression_NoBrace PLUSPLUS
	| LeftHandSideExpression_NoBrace MINUSMINUS
	| PLUSPLUS UnaryExpression
	| MINUSMINUS UnaryExpression
	;

/* 12.5 Unary Operators */
UnaryExpression:
	  UpdateExpression
	| DELETE UnaryExpression
	| VOID UnaryExpression
	| TYPEOF UnaryExpression
	| '+' UnaryExpression
	| '-' UnaryExpression
	| '~' UnaryExpression
	| '!' UnaryExpression
	/* | AwaitExpression */
	;

UnaryExpression_NoBrace:
	  UpdateExpression_NoBrace
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
ExponentialExpression:
	  UnaryExpression
	| UpdateExpression STARSTAR ExponentialExpression
	;

ExponentialExpression_NoBrace:
	  UnaryExpression_NoBrace
	| UpdateExpression_NoBrace STARSTAR ExponentialExpression
	;

/* 12.7 Multiplicative Operators */
MultiplicativeExpression:
	  ExponentialExpression
	| MultiplicativeExpression MultiplicativeOperator ExponentialExpression
	;

MultiplicativeExpression_NoBrace:
	  ExponentialExpression_NoBrace
	| MultiplicativeExpression_NoBrace MultiplicativeOperator ExponentialExpression
	;

MultiplicativeOperator:
	  '*'
	| '/'
	| '%'
	;

/* 12.8 Additive Operators */
AdditiveExpression:
	  MultiplicativeExpression
	| AdditiveExpression '+' MultiplicativeExpression
	| AdditiveExpression '-' MultiplicativeExpression
	;

AdditiveExpression_NoBrace:
	  MultiplicativeExpression_NoBrace
	| AdditiveExpression_NoBrace '+' MultiplicativeExpression
	| AdditiveExpression_NoBrace '-' MultiplicativeExpression
	;

/* 12.9 Bitwise Shift Operators */
ShiftExpression:
	  AdditiveExpression
	| ShiftExpression LSHIFT AdditiveExpression
	| ShiftExpression RSHIFT AdditiveExpression
	| ShiftExpression URSHIFT
	;

ShiftExpression_NoBrace:
	  AdditiveExpression_NoBrace
	| ShiftExpression_NoBrace LSHIFT AdditiveExpression
	| ShiftExpression_NoBrace RSHIFT AdditiveExpression
	| ShiftExpression_NoBrace URSHIFT
	;

/* 12.10 Relational Operators */
RelationalExpression:
	  ShiftExpression
	| RelationalExpression '<' ShiftExpression
	| RelationalExpression '>' ShiftExpression
	| RelationalExpression LTE ShiftExpression
	| RelationalExpression GTE ShiftExpression
	| RelationalExpression INSTANCEOF ShiftExpression
	| RelationalExpression IN ShiftExpression
	;

RelationalExpression_NoBrace:
	  ShiftExpression_NoBrace
	| RelationalExpression_NoBrace '<' ShiftExpression
	| RelationalExpression_NoBrace '>' ShiftExpression
	| RelationalExpression_NoBrace LTE ShiftExpression
	| RelationalExpression_NoBrace GTE ShiftExpression
	| RelationalExpression_NoBrace INSTANCEOF ShiftExpression
	| RelationalExpression_NoBrace IN ShiftExpression
	;

/* 12.11 Equality Operators */
EqualityExpression:
	  RelationalExpression
	| EqualityExpression EQ RelationalExpression
	| EqualityExpression NEQ RelationalExpression
	| EqualityExpression STRICTEQ RelationalExpression
	| EqualityExpression STRICTNEQ RelationalExpression
	;

EqualityExpression_NoBrace:
	  RelationalExpression_NoBrace
	| EqualityExpression_NoBrace EQ RelationalExpression
	| EqualityExpression_NoBrace NEQ RelationalExpression
	| EqualityExpression_NoBrace STRICTEQ RelationalExpression
	| EqualityExpression_NoBrace STRICTNEQ RelationalExpression
	;

/* 12.12 Binary Bitwise Operators */
BitwiseANDExpression:
	  EqualityExpression
	| BitwiseANDExpression '&' EqualityExpression
	;

BitwiseANDExpression_NoBrace:
	  EqualityExpression_NoBrace
	| BitwiseANDExpression_NoBrace '&' EqualityExpression
	;

BitwiseXORExpression:
	  BitwiseANDExpression
	| BitwiseXORExpression '^' BitwiseANDExpression
	;

BitwiseXORExpression_NoBrace:
	  BitwiseANDExpression_NoBrace
	| BitwiseXORExpression_NoBrace '^' BitwiseANDExpression
	;

BitwiseORExpression:
	  BitwiseXORExpression
	| BitwiseORExpression '|' BitwiseXORExpression
	;

BitwiseORExpression_NoBrace:
	  BitwiseXORExpression_NoBrace
	| BitwiseORExpression_NoBrace '|' BitwiseXORExpression
	;

/* 12.13 Binary Logical Operators */
LogicalANDExpression:
	  BitwiseORExpression
	| LogicalANDExpression LOGAND BitwiseORExpression
	;

LogicalANDExpression_NoBrace:
	  BitwiseORExpression_NoBrace
	| LogicalANDExpression_NoBrace LOGAND BitwiseORExpression
	;

LogicalORExpression:
	  LogicalANDExpression
	| LogicalORExpression LOGOR LogicalANDExpression
	;

LogicalORExpression_NoBrace:
	  LogicalANDExpression_NoBrace
	| LogicalORExpression_NoBrace LOGOR LogicalANDExpression
	;

CoalesceExpression:
	  CoalesceExpressionHead QUESTIONQUESTION BitwiseORExpression
	;

CoalesceExpressionHead:
	  CoalesceExpression
	| BitwiseORExpression
	;

CoalesceExpression_NoBrace:
	  CoalesceExpressionHead_NoBrace QUESTIONQUESTION BitwiseORExpression
	;

CoalesceExpressionHead_NoBrace:
	  CoalesceExpression_NoBrace
	| BitwiseORExpression_NoBrace
	;

ShortCircuitExpression:
	  LogicalORExpression
	| CoalesceExpression
	;

ShortCircuitExpression_NoBrace:
	  LogicalORExpression_NoBrace
	| CoalesceExpression_NoBrace
	;

/* 12.14 Conditional Operator */
ConditionalExpression:
	  ShortCircuitExpression
	| ShortCircuitExpression '?' AssignmentExpression ':'
	    AssignmentExpression
	;

ConditionalExpression_NoBrace:
	  ShortCircuitExpression_NoBrace
	| ShortCircuitExpression_NoBrace '?' AssignmentExpression ':'
	    AssignmentExpression
	;

/* 12.15 Assignment Operator */
AssignmentExpression:
	  ConditionalExpression
	// | ObjectAssignmentPattern '=' AssignmentExpression
	// | ArrayAssignmentPattern '=' AssignmentExpression
	/* | YieldExpression
	| ArrowFunction
	| AsyncArrowFunction */
	| LeftHandSideExpression '=' AssignmentExpression
	| LeftHandSideExpression ASSIGNOP AssignmentExpression
	;

AssignmentExpression_NoBrace:
	  ConditionalExpression_NoBrace
	// | ArrayAssignmentPattern '=' AssignmentExpression
	/* | YieldExpression
	| ArrowFunction
	| AsyncArrowFunction */
	| LeftHandSideExpression_NoBrace '=' AssignmentExpression
	| LeftHandSideExpression_NoBrace ASSIGNOP AssignmentExpression
	;

/* 12.15.5 Destructuring Assignment */
/*
 * This grammar is 'covered' by the ObjectLiteral and ArrayLiteral nonterminals.
 * It is therefore not actually parsed. This is why it is commented out.
 */

/*
ObjectAssignmentPattern:
	  '{' '}'
	| '{' AssignmentRestProperty '}'
	| '{' AssignmentPropertyList '}'
	| '{' AssignmentPropertyList ',' '}'
	| '{' AssignmentPropertyList ',' AssignmentRestProperty '}'
	;

ArrayAssignmentPattern:
	  '[' ']'
	| '[' AssignmentRestElement ']'
	| '[' Elision AssignmentRestElement ']'
	| '[' AssignmentElementList ']'
	| '[' AssignmentElementList ',' ']'
	| '[' AssignmentElementList ',' AssignmentRestElement ']'
	| '[' AssignmentElementList ',' Elision ']'
	| '[' AssignmentElementList ',' Elision ',' AssignmentRestElement ']'
	;

AssignmentRestProperty:
	  ELLIPSIS DestructuringAssignmentTarget
	  ;

AssignmentPropertyList:
	  AssignmentProperty
	| AssignmentPropertyList ',' AssignmentProperty
	;

AssignmentElementList:
	  AssignmentElisionElement
	| AssignmentElementList ',' AssignmentElisionElement
	;

AssignmentElisionElement:
	  AssignmentElement
	| Elision AssignmentElement
	;

AssignmentProperty:
	  IdentifierReference Initialiser
	| PropertyName ':' AssignmentElement
	;

AssignmentElement:
	  DestructuringAssignmentTarget Initialiser
	;

AssignmentRestElement:
	  ELLIPSIS DestructuringAssignmentTarget
	;

DestructuringAssignmentTarget:
	  LeftHandSideExpression
	;
*/

/* 12.16 ',' Operator */
Expression:
	  AssignmentExpression
	| Expression ',' AssignmentExpression
	;

Expression_NoBrace:
	  AssignmentExpression_NoBrace
	| Expression_NoBrace ',' AssignmentExpression
	;

Statement:
	  BlockStatement
	| VariableStatement
	| EmptyStatement
	| ExpressionStatement
	;

Declaration:
	/*  HoistableDeclaration
	| ClassDeclaration 
	| */ LexicalDeclaration
	// | ExportDeclaration
	;

/*
HoistableDeclaration:
	  FunctionDeclaration
	| GeneratorDeclaration
	| AsyncFunctionDeclaration
	| AsyncGeneratorDeclaration
	;

BreakableStatement:
	  IterationStatement
	| SwitchStatement
	;
*/

BlockStatement:
	  Block
	;

Block:
	  '{' StatementList '}'
	/* | '{' '}' */ /* disabled until TODO #1 is fixed. */ 
	;

StatementList:
	  StatementListItem
	| StatementList StatementListItem
	;

StatementListItem:
	  Statement { printf("statement parsed\n"); }
	| Declaration
	;

LexicalDeclaration:
	  LetOrConst BindingList ';'
	;

LetOrConst:
	  LET
	| CONST
	;

BindingList:
	  LexicalBinding
	| BindingList ',' LexicalBinding
	;

LexicalBinding:
	  BindingIdentifier Initialiser
	| BindingPattern Initialiser
	;

VariableStatement:
	  VAR VariableDeclarationList ';'
	;

VariableDeclarationList:
	  VariableDeclaration
	| VariableDeclarationList ',' VariableDeclaration
	;

VariableDeclaration:
	  BindingIdentifier
	| BindingIdentifier Initialiser
	;

/* 13.3.3 Destructuring Binding Patterns */
BindingPattern:
	  ObjectBindingPattern
	| ArrayBindingPattern
	;

ObjectBindingPattern:
	  '{' '}'
	| '{' BindingPropertyList '}'
	| '{' BindingPropertyList ',' '}'
	| '{' BindingPropertyList ',' BindingRestProperty '}'
	;

ArrayBindingPattern:
	  '[' ']'
	| '[' BindingRestElement ']'
	| '[' Elision ']'
	| '[' Elision BindingRestElement ']'
	| '[' BindingElementList ']'
	| '[' BindingElementList ',' BindingRestElement ']'
	| '[' BindingElementList ',' Elision ']'
	| '[' BindingElementList ',' Elision BindingRestElement ']'
	;

BindingRestProperty:
	  ELLIPSIS BindingIdentifier
	;

BindingPropertyList:
	 BindingProperty
	| BindingPropertyList ',' BindingProperty
	;

BindingElementList:
	  BindingElisionElement
	| BindingElementList ',' BindingElisionElement
	;

BindingElisionElement:
	  BindingElement
	| Elision BindingElement
	;

BindingProperty:
	  SingleNameBinding
	| PropertyName ':' BindingElement
	;

BindingElement:
	  SingleNameBinding
	| BindingPattern
	| BindingPattern Initialiser
	;

SingleNameBinding:
	  BindingIdentifier
	| BindingIdentifier Initialiser
	;

BindingRestElement:
	  ELLIPSIS BindingIdentifier
	| ELLIPSIS BindingPattern
	;

EmptyStatement:
	  ';'
	;

/*
 * "An ExpressionStatement cannot start with a U+007B (LEFT CURLY BRACKET)
 * because that might make it ambiguous with a Block"
 * We therefore need a "no left curly bracket start" alternative of Expression.
 */
ExpressionStatement:
	  Expression_NoBrace ';'
	| Expression_NoBrace error { printf(" -> Absent Semicolon Inserted\n"); }
	;

Script:
	  ScriptBody
	| %empty
	;

ScriptBody:
	  StatementList
	;


%%

#if 0
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
#endif

void jserror(JSLTYPE * loc, Driver * driver, const char * msg)
{
	printf("%d:%d: %s\n", loc->first_line + 1, loc->first_column,
	    msg);
	print_highlight(driver->txt, loc->first_line, loc->first_column,
	    loc->last_line, loc->last_column);
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

int
jslex(JSSTYPE *yylval, JSLTYPE *loc, Driver * driver)
{
	return true_jslex(yylval, loc, driver->scanner, driver);
}

static YYSTYPE
assign_merge (YYSTYPE pattern, YYSTYPE regular)
{
	printf("\n\nWANT TO CHIOOSE BETWEEN!!\n\n");
	return regular;
}