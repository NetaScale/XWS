#include "AST.hh"

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

ExprNode *
CoverParenthesisedExprAndArrowParameterListNode::toExpr()
{
	if (m_expr == NULL || m_restIdentifier != NULL)
		return NULL;
	else
		return m_expr;
}