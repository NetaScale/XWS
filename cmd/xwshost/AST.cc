#include <cstdio>
#include <iostream>
#include <typeinfo>

#include "AST.hh"
#include "Parser.tab.hh"

void
DeclEnv::defineArg(const char *name, unsigned int idx)
{
	m_decls[name] = new Decl(Decl::kArg, idx);
}

void
DeclEnv::defineLocal(const char *name)
{
	m_decls[name] = new Decl(Decl::kLocal);
}

int
Visitor::visitIdentifier(IdentifierNode *node, const char *ident)
{
	return 0;
}

int
IdentifierNode::accept(Visitor &visitor)
{
	return visitor.visitIdentifier(this, m_value);
}

//	int visitNull(NullNode *node);
//	int visitBool(BoolNode *node);

int
Visitor::visitNumber(NumberNode *node, double val)
{
	return 0;
}

int
NumberNode::accept(Visitor &visitor)
{
	return visitor.visitNumber(this, m_value);
}

int
Visitor::visitFunCall(FunCallNode *node, ExprNode *expr, ExprNode::Vec *args)
{
	expr->accept(*this);
	FOR_EACH (ExprNode::Vec, it, *args)
		(*it)->accept(*this);
	return 0;
}

int
FunCallNode::accept(Visitor &visitor)
{
	return visitor.visitFunCall(this, m_fun, m_args);
}

int
Visitor::visitFunExpr(FunctionExprNode *node, const char *name,
    std::vector<DestructuringNode *> *formals, std::vector<StmtNode *> *body)
{
	FOR_EACH (StmtNode::Vec, it, *body)
		(*it)->accept(*this);

	return 0;
}

int
FunctionExprNode::accept(Visitor &visitor)
{
	return visitor.visitFunExpr(this, m_name.c_str(), m_formals, m_body);
}

int
Visitor::visitBinOp(BinOpNode *node, ExprNode *lhs, BinOp::Op op, ExprNode *rhs)
{
	lhs->accept(*this);
	rhs->accept(*this);
	return 0;
}

int
BinOpNode::accept(Visitor &visitor)
{
	return visitor.visitBinOp(this, m_lhs, m_op, m_rhs);
}

/*
 * Statements
 */

int
Visitor::visitExprStmt(ExprStmtNode *node, ExprNode *expr)
{
	expr->accept(*this);
	return 0;
}

int
ExprStmtNode::accept(Visitor &visitor)
{
	return visitor.visitExprStmt(this, m_expr);
}

/** If statements */
int
Visitor::visitIf(IfNode *node, ExprNode *cond, StmtNode *ifCode,
    StmtNode *elseCode)
{
	cond->accept(*this);
	ifCode->accept(*this);
	if (elseCode)
		elseCode->accept(*this);
	return 0;
}

int
IfNode::accept(Visitor &visitor)
{
	return visitor.visitIf(this, m_cond, m_if, m_else);
}

/** Labelled statements */
int
Visitor::visitLabel(LabelNode *node, IdentifierNode *label, StmtNode *stmt)
{
	stmt->accept(*this);
	return 0;
}

int
LabelNode::accept(Visitor &visitor)
{
	return visitor.visitLabel(this, m_label, m_stmt);
}

int
Visitor::visitContinue(ContinueNode *node, IdentifierNode *label)
{
	return 0;
}

int
ContinueNode::accept(Visitor &visitor)
{
	return visitor.visitContinue(this, m_label);
}

int
Visitor::visitBreak(BreakNode *node, IdentifierNode *label)
{
	return 0;
}

int
BreakNode::accept(Visitor &visitor)
{
	return visitor.visitBreak(this, m_label);
}

/** Return Statements */
int
ReturnNode::accept(Visitor &visitor)
{
	return visitor.visitReturn(this, m_expr);
}

int
Visitor::visitReturn(ReturnNode *node, ExprNode *expr)
{
	expr->accept(*this);
	return 0;
}

/*
 * Declarations
 */

int
Visitor::visitSingleDecl(SingleDeclNode *node, DestructuringNode *lhs,
    ExprNode *rhs)
{
	lhs->accept(*this);
	rhs->accept(*this);
	return 0;
}

int
Visitor::visitDecl(DeclNode *node, DeclNode::Type type,
    SingleDeclNode::Vec *&decls)
{
	FOR_EACH (SingleDeclNode::Vec, it, *decls)
		(*it)->accept(*this);

	return 0;
}

int
SingleDeclNode::accept(Visitor &visitor)
{
	return visitor.visitSingleDecl(this, m_lhs, m_rhs);
}

int
DeclNode::accept(Visitor &visitor)
{
	return visitor.visitDecl(this, m_type, m_decls);
}

int
Visitor::visitSingleNameDestructuring(SingleNameDestructuringNode *node,
    IdentifierNode *ident, ExprNode *initialiser)
{
	ident->accept(*this);
	initialiser->accept(*this);
	return 0;
}

int
SingleNameDestructuringNode::accept(Visitor &visitor)
{
	return visitor.visitSingleNameDestructuring(this, m_ident,
	    m_initialiser);
}

int
Visitor::visitScript(ScriptNode *node, StmtNode::Vec *stmts)
{
	for (StmtNode::Vec::iterator it = stmts->begin(); it != stmts->end();
	     it++)
		(*it)->accept(*this);
	return 0;
}

int
ScriptNode::accept(Visitor &visitor)
{
	return visitor.visitScript(this, m_stmts);
}

DestructuringNode *
IdentifierNode::toDestructuringNode()
{
	return new SingleNameDestructuringNode(this, NULL);
}

DestructuringNode *
AssignNode::toDestructuringNode()
{
	DestructuringNode *node = m_lhs->toDestructuringNode();
	node->m_initialiser = m_rhs;
	return node;
}

ExprNode *
CoverParenthesisedExprAndArrowParameterListNode::toExpr()
{
	if (m_expr == NULL || m_restIdentifier != NULL)
		return NULL;
	else
		return m_expr;
}

std::vector<DestructuringNode *> *
CommaNode::toDestructuringVec(std::vector<DestructuringNode *> *vec)
{
	CommaNode *prev;
	DestructuringNode *node;

	node = m_expr->toDestructuringNode();
	if (!node) {
		std::cout << "FAILED TO TURN NODE " << typeid(*m_expr).name()
			  << "into destructuring\n";
		return NULL;
	}
	vec->push_back(node);

	prev = dynamic_cast<CommaNode *>(m_prev);
	if (prev)
		prev->toDestructuringVec(vec);
	else {
		node = m_prev->toDestructuringNode();
		if (!node) {
			std::cout << "FAILED TO TURN NODE "
				  << typeid(*m_prev).name()
				  << "into destructuring\n";
			return NULL;
		}
		vec->push_back(node);
	}

	return vec;
}

std::vector<DestructuringNode *> *
CoverParenthesisedExprAndArrowParameterListNode::toDestructuringVec()
{
	std::vector<DestructuringNode *> *vec =
	    new std::vector<DestructuringNode *>;
	CommaNode *comma;

	if ((comma = dynamic_cast<CommaNode *>(m_expr))) {
		vec = comma->toDestructuringVec(vec);
	} else {
		DestructuringNode *node = m_expr->toDestructuringNode();
		vec->push_back(node);
	}

	return vec;
}