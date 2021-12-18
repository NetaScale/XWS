#include <cstring>
#include <stack>
#include <stdio.h>

#include "AST.hh"
#include "Bytecode.hh"
#include "Parser.tab.hh"
#include "VM.hh"

class GenerationContext {
    public:
	enum Type { kGlobal, kFunction, kBlock };

    protected:
	bool m_isGlobal;
	Type m_type;
	std::vector<char *> m_locals;

    public:
	GenerationContext(Type type)
	    : m_type(type)
	{
		printf("--> BEGIN %s\n",
		    type == kGlobal	  ? "Global" :
			type == kFunction ? "Function" :
						  "Block");
	}

	~GenerationContext()
	{
		printf("--> END %s\n",
		    m_type == kGlobal	    ? "Global" :
			m_type == kFunction ? "Function" :
						    "Block");
	}
};

class BytecodeGenerator : public Visitor {
	friend class DestructuringVisitor;

	std::stack<GenerationContext *> m_ctx;
	std::stack<VM::JSFunction *> m_funcs;
	std::stack<VM::BytecodeEncoder *> m_gens;
	VM::JSFunction *m_script;

	inline VM::BytecodeEncoder *coder() { return m_gens.top(); }

	VM::JSFunction *enterNewFunction();
	VM::JSFunction *exitFunction(DeclEnv *env);

	void emitSingleNameDestructuring(const char *txt,
	    ExprNode *ifUndefined);

	int visitIdentifier(IdentifierNode *node, const char *ident);
	int visitNumber(NumberNode *node, double val);
	int visitFunCall(FunCallNode *node, ExprNode *expr,
	    ExprNode::Vec *args);
	int visitFunExpr(FunctionExprNode *node, const char *name,
	    std::vector<DestructuringNode *> *formals,
	    std::vector<StmtNode *> *body);
	int visitBinOp(BinOpNode *node, ExprNode *lhs, BinOp::Op op,
	    ExprNode *rhs);

	int visitExprStmt(ExprStmtNode *node, ExprNode *expr);
	int visitReturn(ReturnNode *node, ExprNode *expr);

	int visitSingleDecl(SingleDeclNode *node, DestructuringNode *lhs,
	    ExprNode *rhs);
	int visitDecl(DeclNode *node, DeclNode::Type type,
	    SingleDeclNode::Vec *&decls);

	int visitScript(ScriptNode *node, StmtNode::Vec *stmts);

    public:
	BytecodeGenerator();

	VM::JSFunction *script() { return m_script; }
};

class DestructuringVisitor : public Visitor {
    public:
	std::stack<int> m_destructuring;
	BytecodeGenerator &m_gen;
	unsigned int m_idx;

	enum Kind {
		kParam,
		kExpr,
	} kind;

	DestructuringVisitor(BytecodeGenerator &gen)
	    : m_gen(gen)
	    , kind(kExpr) {};
	DestructuringVisitor(BytecodeGenerator &gen, unsigned int paramIdx)
	    : m_gen(gen)
	    , kind(kParam)
	    , m_idx(paramIdx) {};

	int visitSingleNameDestructuring(SingleNameDestructuringNode *node,
	    IdentifierNode *ident, ExprNode *initialiser);
};

class Hoister : public Visitor {
	int m_inArgs;
	std::stack<int> m_destr;
	std::stack<DeclEnv *> m_envs;

	int visitFunExpr(FunctionExprNode *node, const char *name,
	    std::vector<DestructuringNode *> *formals,
	    std::vector<StmtNode *> *body);

	int visitSingleNameDestructuring(SingleNameDestructuringNode *node,
	    IdentifierNode *ident, ExprNode *initialiser);

	int visitSingleDecl(SingleDeclNode *node, DestructuringNode *lhs,
	    ExprNode *rhs);
	int visitDecl(DeclNode *node, DeclNode::Type type,
	    SingleDeclNode::Vec *&decls);

	int visitScript(ScriptNode *node, StmtNode::Vec *stmts);

    public:
	Hoister()
	    : m_inArgs(-1) {};
};

/*
 * hoisting
 */

int
Hoister::visitFunExpr(FunctionExprNode *node, const char *name,
    std::vector<DestructuringNode *> *formals, std::vector<StmtNode *> *body)
{
	node->m_parent = m_envs.top();
	m_envs.push(node);

	m_inArgs = 0;
	FOR_EACH (std::vector<DestructuringNode *>, it, *formals) {
		(*it)->accept(*this);
		m_inArgs++;
	}
	m_inArgs = -1;

	FOR_EACH (StmtNode::Vec, it, *body) {
		(*it)->accept(*this);
	}

	m_envs.pop();

	return 0;
}

int
Hoister::visitSingleDecl(SingleDeclNode *node, DestructuringNode *lhs,
    ExprNode *rhs)
{
	lhs->accept(*this);
	rhs->accept(*this);
	return 0;
}

int
Hoister::visitDecl(DeclNode *node, DeclNode::Type type,
    SingleDeclNode::Vec *&decls)
{
	FOR_EACH (SingleDeclNode::Vec, it, *decls)
		(*it)->accept(*this);
	return 0;
}

int
Hoister::visitScript(ScriptNode *node, StmtNode::Vec *stmts)
{
	m_envs.push(node);
	for (StmtNode::Vec::iterator it = stmts->begin(); it != stmts->end();
	     it++)
		(*it)->accept(*this);
	m_envs.pop();
	return 0;
}

int
Hoister::visitSingleNameDestructuring(SingleNameDestructuringNode *node,
    IdentifierNode *ident, ExprNode *initialiser)
{
	if (m_inArgs != -1 && m_destr.empty()) {
		/* simply defining an argument name */
		m_envs.top()->defineArg(ident->value(), m_inArgs);
	} else {
		m_envs.top()->defineLocal(ident->value());
	}

	return 0;
}

/*
 * bytecode generation
 */

BytecodeGenerator::BytecodeGenerator()
{
	m_ctx.push(new GenerationContext(GenerationContext::kGlobal));
}

VM::JSFunction *
BytecodeGenerator::enterNewFunction()
{
	VM::JSFunction *jsf = new VM::JSFunction;
	VM::BytecodeEncoder *encoder = new VM::BytecodeEncoder(jsf);

	m_funcs.push(jsf);
	m_gens.push(encoder);

	return jsf;
}

VM::JSFunction *
BytecodeGenerator::exitFunction(DeclEnv *env)
{
	VM::JSFunction *jsf = m_funcs.top();

	for (std::map<std::string, Decl *>::iterator it = env->m_decls.begin();
	     it != env->m_decls.end(); it++)
		if (it->second->m_type == Decl::kLocal)
			m_funcs.top()->m_localNames.push_back(
			    strdup(it->first.c_str()));
		else if (it->second->m_type == Decl::kArg) {
			m_funcs.top()->m_paramNames[it->second->m_idx] = strdup(
			    it->first.c_str());
		}

	m_gens.top()->emit0(VM::kPushUndefined);
	m_gens.top()->emit0(VM::kReturn);
	delete m_gens.top();
	m_gens.pop();
	m_funcs.pop();
	return jsf;
}

int
BytecodeGenerator::visitIdentifier(IdentifierNode *node, const char *ident)
{
	m_gens.top()->emit1(VM::kResolve, m_gens.top()->litStr(ident));
	return 0;
}

int
BytecodeGenerator::visitNumber(NumberNode *node, double val)
{
	m_gens.top()->emit1(VM::kPushLiteral, m_gens.top()->litNum(val));
	return 0;
}

int
BytecodeGenerator::visitFunCall(FunCallNode *node, ExprNode *expr,
    ExprNode::Vec *args)
{
	FOR_EACH (ExprNode::Vec, it, *args)
		(*it)->accept(*this);
	expr->accept(*this);

	m_gens.top()->emit1(VM::kCall, args->size());
	return 0;
}

int
BytecodeGenerator::visitFunExpr(FunctionExprNode *node, const char *name,
    std::vector<DestructuringNode *> *formals, std::vector<StmtNode *> *body)
{
	int nParams = 0;
	VM::JSFunction *jsf;

	m_ctx.push(new GenerationContext(GenerationContext::kFunction));
	jsf = enterNewFunction();
	jsf->m_paramNames.resize(formals->size(), NULL);

	FOR_EACH (std::vector<DestructuringNode *>, it, *formals) {
		DestructuringVisitor destr(*this, nParams++);
		(*it)->accept(destr);
	}

	FOR_EACH (StmtNode::Vec, it, *body) {
		(*it)->accept(*this);
	}

	exitFunction(node);
	delete (m_ctx.top());
	m_ctx.pop();

	m_gens.top()->emit1(VM::kPushLiteral, m_gens.top()->litObj(jsf));
	m_gens.top()->emit0(VM::kCreateClosure);

	return 0;
}

int
BytecodeGenerator::visitBinOp(BinOpNode *node, ExprNode *lhs, BinOp::Op op,
    ExprNode *rhs)
{
	lhs->accept(*this);
	rhs->accept(*this);
	m_gens.top()->emit0(VM::kAdd);
	return 0;
}

int
BytecodeGenerator::visitExprStmt(ExprStmtNode *node, ExprNode *expr)
{
	expr->accept(*this);
	m_gens.top()->emit0(VM::kPop);
	return 0;
}

int
BytecodeGenerator::visitReturn(ReturnNode *node, ExprNode *expr)
{
	expr->accept(*this);
	m_gens.top()->emit0(VM::kReturn);
	return 0;
}

int
DestructuringVisitor::visitSingleNameDestructuring(
    SingleNameDestructuringNode *node, IdentifierNode *ident,
    ExprNode *initialiser)
{
	if (m_destructuring.empty()) {
		if (initialiser != NULL) {
			if (kind == kParam)
				m_gen.m_gens.top()->emit1(VM::kPushArg, m_idx);
			printf("JUMP +3 IF NOT UNDEFINED\n");
			printf("/* undefined case */\n");
			initialiser->accept(m_gen);
			if (kind == kParam)
				printf("STORE ARG %d\n", m_idx);
			else
				printf("STORE SLOT $%s\n", ident->value());
			printf("POP\n");
			printf("/* not undefined */\n");
		}
		if (kind != kParam)
			m_gen.coder()->emit1(VM::kResolvedStore,
			    m_gen.coder()->litStr(ident->value()));
	} else {
		printf("UNIMPLEMENTED!\n");
		throw 0;
	}

	return 0;
}

int
BytecodeGenerator::visitSingleDecl(SingleDeclNode *node, DestructuringNode *lhs,
    ExprNode *rhs)
{
	DestructuringVisitor visitor(*this);
	rhs->accept(*this);
	lhs->accept(visitor);
	m_gens.top()->emit0(VM::kPop);
	return 0;
}

int
BytecodeGenerator::visitDecl(DeclNode *node, DeclNode::Type type,
    SingleDeclNode::Vec *&decls)
{
	FOR_EACH (SingleDeclNode::Vec, it, *decls)
		(*it)->accept(*this);

	return 0;
}

int
BytecodeGenerator::visitScript(ScriptNode *node, StmtNode::Vec *stmts)
{
	enterNewFunction();
	for (StmtNode::Vec::iterator it = stmts->begin(); it != stmts->end();
	     it++)
		(*it)->accept(*this);
	m_script = exitFunction(node);
	return 0;
}

VM::JSFunction *
Driver::generateBytecode()
{
	Hoister hoister;
	BytecodeGenerator visitor;
	m_script->accept(hoister);
	m_script->accept(visitor);
	return visitor.script();
}
