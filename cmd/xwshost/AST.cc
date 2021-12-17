#include "AST.hh"

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