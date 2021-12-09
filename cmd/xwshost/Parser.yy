/*
 * These coded instructions, statements, and computer programs contain
 * software derived from the following specification:
 *
 * ECMA-262, 11th edition, June 2020: ECMAScript® 2020 Language Specification
 * https://262.ecma-international.org/11.0/
 * Draft ECMA-262, 13th edition, November 20, 2021: ECMAScript® 2022 Language
 * Specification
 * https://tc39.es/ecma262/
 */

%{
#include <cassert>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Driver.hh"
#include "AST.hh"

#define YYDEBUG 1
#define UNIMPLEMENTED printf("Sorry, this is unimplemented\n"); YYERROR

static int assign_merge (YYSTYPE pattern, YYSTYPE regular);
%}

%code requires {
#include "Driver.hh"

class ExprNode;
class StmtNode;

#define ASI printf(" -> ADDING AUTO SC\n");

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
%token OPTIONAL /* ?. */

%precedence PLAIN_IF
%precedence ELSE

%union {
	Operator::Op opVal;
	char * str;

	ExprNode * exprNode;
	StmtNode * stmtNode;
}

%type <str> IDENTIFIER IdentifierNotReserved

%type <exprNode> IdentifierReference BindingIdentifier LabelIdentifier

%type <exprNode> PrimaryExpression PrimaryExpression_NoBrace
%type <exprNode> Literal

%type <exprNode> MemberExpression MemberExpression_NoBrace
%type <exprNode> SuperProperty SuperCall
%type <exprNode> NewExpression NewExpression_NoBrace
%type <exprNode> CallExpression CallExpression_NoBrace
%type <exprNode> OptionalExpression OptionalExpression_NoBrace
%type <exprNode> LeftHandSideExpression LeftHandSideExpression_NoBrace
%type <exprNode> UpdateExpression UpdateExpression_NoBrace
%type <exprNode> UnaryExpression UnaryExpression_NoBrace
%type <exprNode> ExponentialExpression ExponentialExpression_NoBrace

%type <opVal> MultiplicativeOperator
%type <exprNode> MultiplicativeExpression MultiplicativeExpression_NoBrace
%type <exprNode> AdditiveExpression AdditiveExpression_NoBrace
%type <exprNode> ShiftExpression ShiftExpression_NoBrace
%type <exprNode> RelationalExpression RelationalExpression_NoBrace
%type <exprNode> EqualityExpression EqualityExpression_NoBrace
%type <exprNode> BitwiseANDExpression BitwiseANDExpression_NoBrace
%type <exprNode> BitwiseORExpression BitwiseORExpression_NoBrace
%type <exprNode> BitwiseXORExpression BitwiseXORExpression_NoBrace
%type <exprNode> LogicalANDExpression LogicalANDExpression_NoBrace
%type <exprNode> LogicalORExpression LogicalORExpression_NoBrace
%type <exprNode> CoalesceExpression CoalesceExpression_NoBrace
%type <exprNode> CoalesceExpressionHead CoalesceExpressionHead_NoBrace
%type <exprNode> ShortCircuitExpression ShortCircuitExpression_NoBrace
%type <exprNode> ConditionalExpression ConditionalExpression_NoBrace
%type <exprNode> AssignmentExpression AssignmentExpression_NoBrace
%type <exprNode> Expression Expression_NoBrace

%type <stmtNode> Block BlockStatement VariableStatement EmptyStatement
%type <stmtNode> ExpressionStatement IfStatement BreakableStatement
%type <stmtNode> ContinueStatement BreakStatement ReturnStatement WithStatement
%type <stmtNode> LabelledStatement ThrowStatement TryStatement DebuggerStatement
%type <stmtNode> Statement LabelledItem


%%

/* 11.8.5 Regular Expression Literals */
RegularExpressionLiteral:
	  '/' { printf("Matching Regex\n"); } REGEXBODY '/' REGEXFLAGS
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

/*
how a preprocessor grammar might look:
IdentifierReference(Yield, Await):
	  IdentifierNotReserved(?Yield, ?Await)
	| (~Yield) YIELD
	| (~Await) AWAIT
*/

IdentifierReference:
	  IdentifierNotReserved { $$ = new IdentifierNode(@1, $1); }
	;

BindingIdentifier:
	  IdentifierNotReserved { $$ = new IdentifierNode(@1, $1); }
	;

LabelIdentifier:
	  IdentifierNotReserved { $$ = new IdentifierNode(@1, $1); }
	;

/* 12.2 Primary Expression */

PrimaryExpression:
	  PrimaryExpression_NoBrace
	| ObjectLiteral
	| FunctionExpression
	/*| ClassExpression
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
	| MemberExpression '[' Expression ']' {
		$$ = new AccessorNode($1, $3);
	}
	| MemberExpression '.' IDENTIFIER {
		$$ = new AccessorNode($1, new IdentifierNode(@3, $3));
	}
	// | MemberExpression TemplateLiteral
	| SuperProperty
	| MetaProperty
	| NEW MemberExpression Arguments
	;

MemberExpression_NoBrace:
	  PrimaryExpression_NoBrace
	| MemberExpression_NoBrace '[' Expression ']' {
		$$ = new AccessorNode($1, $3);
	}
	| MemberExpression_NoBrace '.' IDENTIFIER {
		$$ = new AccessorNode($1, new IdentifierNode(@3, $3));
	}
	//| MemberExpression_NoBrace TemplateLiteral
	| SuperProperty
	| MetaProperty
	| NEW MemberExpression Arguments
	;

SuperProperty:
	  SUPER '[' Expression ']' {
		$$ = new AccessorNode(new SuperNode(@1), $3);
	}
	| SUPER '.' IDENTIFIER {
		$$ = new AccessorNode(new SuperNode(@1), new
		    IdentifierNode(@3, $3));
	}
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
	| NEW NewExpression {
		$$ = new NewExprNode(@1, $2);
	}
	;

NewExpression_NoBrace:
	  MemberExpression_NoBrace
	| NEW NewExpression {
		$$ = new NewExprNode(@1, $2);
	}
	;

CallExpression:
	  CallMemberExpression
	| SuperCall
	| CallExpression Arguments
	| CallExpression '[' Expression ']' {
		$$ = new AccessorNode($1, $3);
	}
	| CallExpression '.' IDENTIFIER {
		$$ = new AccessorNode($1, new IdentifierNode(@3, $3));
	}
	| CallExpression TemplateLiteral {
		UNIMPLEMENTED;
	}
	;

CallExpression_NoBrace:
	  CallMemberExpression_NoBrace
	| SuperCall
	| CallExpression_NoBrace Arguments
	| CallExpression_NoBrace '[' Expression ']' {
		$$ = new AccessorNode($1, $3);
	}
	| CallExpression_NoBrace '.' IDENTIFIER {
		$$ = new AccessorNode($1, new IdentifierNode(@3, $3));
	}
	| CallExpression_NoBrace TemplateLiteral {
		UNIMPLEMENTED;
	}
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
OptionalExpression:
	  MemberExpression OptionalChain
	| CallExpression OptionalChain
	| OptionalExpression OptionalChain
	;

OptionalExpression_NoBrace:
	  MemberExpression_NoBrace OptionalChain
	| CallExpression_NoBrace OptionalChain
	| OptionalExpression_NoBrace OptionalChain
	;

OptionalChain:
	  OPTIONAL Arguments
	| OPTIONAL '[' Expression ']'
	| OPTIONAL IDENTIFIER
	| OPTIONAL TemplateLiteral
	| OptionalChain Arguments
	| OptionalChain '[' Expression ']'
	| OptionalChain '.' IDENTIFIER
	| OptionalChain TemplateLiteral
	;

LeftHandSideExpression:
	  NewExpression
	| CallExpression
	| OptionalExpression
	;

LeftHandSideExpression_NoBrace:
	  NewExpression_NoBrace
	| CallExpression_NoBrace
	| OptionalExpression_NoBrace
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
	| UpdateExpression STARSTAR ExponentialExpression {
		$$ = new BinOpNode($1, $3, Operator::kExp);
	}
	;

ExponentialExpression_NoBrace:
	  UnaryExpression_NoBrace
	| UpdateExpression_NoBrace STARSTAR ExponentialExpression {
		$$ = new BinOpNode($1, $3, Operator::kExp);
	}
	;

/* 12.7 Multiplicative Operators */
MultiplicativeExpression:
	  ExponentialExpression
	| MultiplicativeExpression MultiplicativeOperator
	  ExponentialExpression {
		$$ = new BinOpNode($1, $3, $2);
	}
	;

MultiplicativeExpression_NoBrace:
	  ExponentialExpression_NoBrace
	| MultiplicativeExpression_NoBrace MultiplicativeOperator
	  ExponentialExpression {
		$$ = new BinOpNode($1, $3, $2);
	}
	;

MultiplicativeOperator:
	  '*' { $$ = Operator::kMul; }
	| '/' { $$ = Operator::kDiv; }
	| '%' { $$ = Operator::kMod; }
	;

/* 12.8 Additive Operators */
AdditiveExpression:
	  MultiplicativeExpression
	| AdditiveExpression '+' MultiplicativeExpression {
		$$ = new BinOpNode($1, $3, Operator::kAdd);
	}
	| AdditiveExpression '-' MultiplicativeExpression {
		$$ = new BinOpNode($1, $3, Operator::kSub);
	}
	;

AdditiveExpression_NoBrace:
	  MultiplicativeExpression_NoBrace
	| AdditiveExpression_NoBrace '+' MultiplicativeExpression {
		$$ = new BinOpNode($1, $3, Operator::kAdd);
	}
	| AdditiveExpression_NoBrace '-' MultiplicativeExpression {
		$$ = new BinOpNode($1, $3, Operator::kSub);
	}
	;

/* 12.9 Bitwise Shift Operators */
ShiftExpression:
	  AdditiveExpression
	| ShiftExpression LSHIFT AdditiveExpression{
		$$ = new BinOpNode($1, $3, Operator::kLShift);
	}
	| ShiftExpression RSHIFT AdditiveExpression {
		$$ = new BinOpNode($1, $3, Operator::kRShift);
	}
	| ShiftExpression URSHIFT AdditiveExpression {
		$$ = new BinOpNode($1, $3, Operator::kURShift);
	}
	;

ShiftExpression_NoBrace:
	  AdditiveExpression_NoBrace
	| ShiftExpression_NoBrace LSHIFT AdditiveExpression {
		$$ = new BinOpNode($1, $3, Operator::kLShift);
	}
	| ShiftExpression_NoBrace RSHIFT AdditiveExpression {
		$$ = new BinOpNode($1, $3, Operator::kRShift);
	}
	| ShiftExpression_NoBrace URSHIFT AdditiveExpression {
		$$ = new BinOpNode($1, $3, Operator::kURShift);
	}
	;

/* 12.10 Relational Operators */
RelationalExpression:
	  ShiftExpression
	| RelationalExpression '<' ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kLessThan);
	}
	| RelationalExpression '>' ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kGreaterThan);
	}
	| RelationalExpression LTE ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kLessThanOrEq);
	}
	| RelationalExpression GTE ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kGreaterThanOrEq);
	}
	| RelationalExpression INSTANCEOF ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kInstanceOf);
	}
	| RelationalExpression IN ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kAmong);
	}
	;

RelationalExpression_NoBrace:
	  ShiftExpression_NoBrace
	| RelationalExpression_NoBrace '<' ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kLessThan);
	}
	| RelationalExpression_NoBrace '>' ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kGreaterThan);
	}
	| RelationalExpression_NoBrace LTE ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kLessThanOrEq);
	}
	| RelationalExpression_NoBrace GTE ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kGreaterThanOrEq);
	}
	| RelationalExpression_NoBrace INSTANCEOF ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kInstanceOf);
	}
	| RelationalExpression_NoBrace IN ShiftExpression {
		$$ = new BinOpNode($1, $3, Operator::kAmong);
	}
	;

/* 12.11 Equality Operators */
EqualityExpression:
	  RelationalExpression
	| EqualityExpression EQ RelationalExpression {
		$$ = new BinOpNode($1, $3, Operator::kEquals);
	}
	| EqualityExpression NEQ RelationalExpression {
		$$ = new BinOpNode($1, $3, Operator::kNotEquals);
	}
	| EqualityExpression STRICTEQ RelationalExpression {
		$$ = new BinOpNode($1, $3, Operator::kStrictEquals);
	}
	| EqualityExpression STRICTNEQ RelationalExpression {
		$$ = new BinOpNode($1, $3, Operator::kStrictNotEquals);
	}
	;

EqualityExpression_NoBrace:
	  RelationalExpression_NoBrace
	| EqualityExpression_NoBrace EQ RelationalExpression {
		$$ = new BinOpNode($1, $3, Operator::kEquals);
	}
	| EqualityExpression_NoBrace NEQ RelationalExpression {
		$$ = new BinOpNode($1, $3, Operator::kNotEquals);
	}
	| EqualityExpression_NoBrace STRICTEQ RelationalExpression {
		$$ = new BinOpNode($1, $3, Operator::kStrictEquals);
	}
	| EqualityExpression_NoBrace STRICTNEQ RelationalExpression {
		$$ = new BinOpNode($1, $3, Operator::kStrictNotEquals);
	}
	;

/* 12.12 Binary Bitwise Operators */
BitwiseANDExpression:
	  EqualityExpression
	| BitwiseANDExpression '&' EqualityExpression {
		$$ = new BinOpNode($1, $3, Operator::kBitAnd);
	}
	;

BitwiseANDExpression_NoBrace:
	  EqualityExpression_NoBrace
	| BitwiseANDExpression_NoBrace '&' EqualityExpression {
		$$ = new BinOpNode($1, $3, Operator::kBitAnd);
	}
	;

BitwiseXORExpression:
	  BitwiseANDExpression
	| BitwiseXORExpression '^' BitwiseANDExpression {
		$$ = new BinOpNode($1, $3, Operator::kBitXor);
	}
	;

BitwiseXORExpression_NoBrace:
	  BitwiseANDExpression_NoBrace
	| BitwiseXORExpression_NoBrace '^' BitwiseANDExpression {
		$$ = new BinOpNode($1, $3, Operator::kBitXor);
	}
	;

BitwiseORExpression:
	  BitwiseXORExpression
	| BitwiseORExpression '|' BitwiseXORExpression {
		$$ = new BinOpNode($1, $3, Operator::kBitOr);
	}
	;

BitwiseORExpression_NoBrace:
	  BitwiseXORExpression_NoBrace
	| BitwiseORExpression_NoBrace '|' BitwiseXORExpression {
		$$ = new BinOpNode($1, $3, Operator::kBitOr);
	}
	;

/* 12.13 Binary Logical Operators */
LogicalANDExpression:
	  BitwiseORExpression
	| LogicalANDExpression LOGAND BitwiseORExpression {
		$$ = new BinOpNode($1, $3, Operator::kAnd);
	}
	;

LogicalANDExpression_NoBrace:
	  BitwiseORExpression_NoBrace
	| LogicalANDExpression_NoBrace LOGAND BitwiseORExpression {
		$$ = new BinOpNode($1, $3, Operator::kAnd);
	}
	;

LogicalORExpression:
	  LogicalANDExpression
	| LogicalORExpression LOGOR LogicalANDExpression {
		$$ = new BinOpNode($1, $3, Operator::kOr);
	}
	;

LogicalORExpression_NoBrace:
	  LogicalANDExpression_NoBrace
	| LogicalORExpression_NoBrace LOGOR LogicalANDExpression {
		$$ = new BinOpNode($1, $3, Operator::kOr);
	}
	;

CoalesceExpression:
	  CoalesceExpressionHead QUESTIONQUESTION BitwiseORExpression {
		$$ = new BinOpNode($1, $3, Operator::kCoalesce);
	}
	;

CoalesceExpressionHead:
	  CoalesceExpression
	| BitwiseORExpression
	;

CoalesceExpression_NoBrace:
	  CoalesceExpressionHead_NoBrace QUESTIONQUESTION BitwiseORExpression {
		$$ = new BinOpNode($1, $3, Operator::kCoalesce);
	}
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
	| IfStatement
	| BreakableStatement
	| ContinueStatement
	| BreakStatement
	/* +Return */ | ReturnStatement
	| WithStatement
	| LabelledStatement
	| ThrowStatement
	| TryStatement
	| DebuggerStatement
	;

Declaration:
	  HoistableDeclaration
	//| ClassDeclaration
	| LexicalDeclaration
	//| ExportDeclaration
	;

HoistableDeclaration:
	  FunctionDeclaration
	//| GeneratorDeclaration
	//| AsyncFunctionDeclaration
	//| AsyncGeneratorDeclaration
	;

BreakableStatement:
	  IterationStatement
	//| SwitchStatement
	;


BlockStatement:
	  Block
	;

Block:
	  '{' StatementList '}'
	| '{' '}'
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
	| LetOrConst BindingList error { ASI; }
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
	| VAR VariableDeclarationList error { ASI; }
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
	| Expression_NoBrace error { ASI; }
	;

IfStatement:
	  IF '(' Expression ')' Statement ELSE Statement
	| IF '(' Expression ')' Statement %prec PLAIN_IF
	;

IterationStatement:
	  DoWhileStatement
	| WhileStatement
	| ForStatement
	//| ForInOfStatement
	;

DoWhileStatement: /* [Yield, Await, Return] */
	  DO Statement /* [?Yield, ?Await, ?Return] */ WHILE '('
	  Expression /* [+In, ?Yield, ?Await] */ ')' ';'
	;

WhileStatement: /* [Yield, Await, Return] */
	  WHILE '(' Expression /* [+In, ?Yield, ?Await] */ ')'
	  Statement /* [?Yield, ?Await, ?Return] */
	;

/*
ForStatement[Yield, Await, Return] :
	for ( [lookahead ≠ let [] Expression[~In, ?Yield, ?Await]opt ;
	    Expression[+In, ?Yield, ?Await]opt ;
	    Expression[+In, ?Yield, ?Await]opt )
	    Statement[?Yield, ?Await, ?Return]
	for ( var VariableDeclarationList[~In, ?Yield, ?Await] ;
	    Expression[+In, ?Yield, ?Await]opt ;
	    Expression[+In, ?Yield, ?Await]opt )
	    Statement[?Yield, ?Await, ?Return]
	for ( LexicalDeclaration[~In, ?Yield, ?Await]
	    Expression[+In, ?Yield, ?Await]opt ;
	    Expression[+In, ?Yield, ?Await]opt )
	    Statement[?Yield, ?Await, ?Return]
*/

ForStatement: /* [Yield, Await, Return] */
	  FOR '(' ExpressionOpt ';' ExpressionOpt ';' ExpressionOpt ')'
	  Statement
	| FOR '(' VAR VariableDeclarationList ';' ExpressionOpt ';'
	  ExpressionOpt ')' Statement
	| FOR '(' LexicalDeclaration ExpressionOpt ';' ExpressionOpt ')'
	  Statement
	;

ExpressionOpt:
	  Expression
	| %empty
	;

/*
ForInOfStatement[Yield, Await, Return] :
	for ( [lookahead ≠ let [] LeftHandSideExpression[?Yield, ?Await] in
	    Expression[+In, ?Yield, ?Await] ) Statement[?Yield, ?Await, ?Return]
	for ( var ForBinding[?Yield, ?Await] in Expression[+In, ?Yield, ?Await]
	    ) Statement[?Yield, ?Await, ?Return]
	for ( ForDeclaration[?Yield, ?Await] in Expression[+In, ?Yield, ?Await]
	    ) Statement[?Yield, ?Await, ?Return]
	for ( [lookahead ∉ { let, async of }]
	    LeftHandSideExpression[?Yield, ?Await] of
	    AssignmentExpression[+In, ?Yield, ?Await] )
	    Statement[?Yield, ?Await, ?Return]
	for ( var ForBinding[?Yield, ?Await] of
	    AssignmentExpression[+In, ?Yield, ?Await]
	    ) Statement[?Yield, ?Await, ?Return]
	for ( ForDeclaration[?Yield, ?Await] of
	    AssignmentExpression[+In, ?Yield, ?Await] )
	    Statement[?Yield, ?Await, ?Return]
	[+Await] for await ( [lookahead ≠ let]
	    LeftHandSideExpression[?Yield, ?Await] of
	    AssignmentExpression[+In, ?Yield, ?Await] )
	    Statement[?Yield, ?Await, ?Return]
	[+Await] for await ( var ForBinding[?Yield, ?Await] of
	    AssignmentExpression[+In, ?Yield, ?Await] )
	    Statement[?Yield, ?Await, ?Return]
	[+Await] for await ( ForDeclaration[?Yield, ?Await] of
	    AssignmentExpression[+In, ?Yield, ?Await] )
	    Statement[?Yield, ?Await, ?Return]
*/

/*
ForDeclaration[Yield, Await] :
	LetOrConst ForBinding[?Yield, ?Await]

ForBinding[Yield, Await] :
	BindingIdentifier[?Yield, ?Await]
	BindingPattern[?Yield, ?Await]
*/

ContinueStatement:
	  CONTINUE ';'
	| CONTINUE /* [no LineTerminator here] */ LabelIdentifier ';'
	;

BreakStatement:
	  BREAK ';'
	| BREAK /* [no LineTerminator here] */ LabelIdentifier ';'
	;

ReturnStatement:
	  RETURN ';'
	| RETURN /* [no LineTerminator here] */ Expression ';'
	;

WithStatement:
	  WITH '(' Expression ')' Statement
	;

/*
SwitchStatement[Yield, Await, Return] :
switch ( Expression[+In, ?Yield, ?Await] ) CaseBlock[?Yield, ?Await, ?Return]

CaseBlock[Yield, Await, Return] :
{ CaseClauses[?Yield, ?Await, ?Return]opt }
{ CaseClauses[?Yield, ?Await, ?Return]opt DefaultClause[?Yield, ?Await, ?Return] CaseClauses[?Yield, ?Await, ?Return]opt }

CaseClauses[Yield, Await, Return] :
CaseClause[?Yield, ?Await, ?Return]
CaseClauses[?Yield, ?Await, ?Return] CaseClause[?Yield, ?Await, ?Return]

CaseClause[Yield, Await, Return] :
case Expression[+In, ?Yield, ?Await] : StatementList[?Yield, ?Await, ?Return]opt

DefaultClause[Yield, Await, Return] :
default : StatementList[?Yield, ?Await, ?Return]opt
*/

LabelledStatement:
	LabelIdentifier ':' LabelledItem {
		//$$ = new LabelNode($1, $3);
		UNIMPLEMENTED;
	}
	;

LabelledItem:
	  Statement
	//| FunctionDeclaration
	;

ThrowStatement:
	  THROW /* [no LineTerminator here] */ Expression ';'
	;

TryStatement:
	  TRY Block Catch
	| TRY Block Finally
	| TRY Block Catch Finally
	;

Catch:
	  CATCH '(' CatchParameter ')' Block
	| CATCH Block
	;

Finally:
	  FINALLY Block
	;

CatchParameter:
	  BindingIdentifier
	| BindingPattern
	;

DebuggerStatement:
	  DEBUGGER ';'
	;

/* 15 Functions and Classes */

/* 15.1 Parameter Lists */

UniqueFormalParameters:
	  FormalParameters
	;

FormalParameters:
	  %empty
	| FunctionRestParameter
	| FormalParameterList
	| FormalParameterList ','
	| FormalParameterList ',' FunctionRestParameter
	;


FormalParameterList:
	  FormalParameter
	| FormalParameterList ',' FormalParameter
	;

FunctionRestParameter:
	BindingRestElement
	;

FormalParameter:
	BindingElement
	;

/* 15.2 Function Definitions */

FunctionDeclaration:
	  FUNCTION BindingIdentifier '(' FormalParameters ')' '{' FunctionBody
	  '}'
	| FUNCTION '(' FormalParameters ')' '{' FunctionBody '}'
	;

FunctionExpression:
	  FUNCTION BindingIdentifier '(' FormalParameters ')' '{' FunctionBody
	  '}'
	| FUNCTION '(' FormalParameters ')' '{' FunctionBody '}'
	;

FunctionBody:
	FunctionStatementList
	;

FunctionStatementList:
	  StatementList
	| %empty
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