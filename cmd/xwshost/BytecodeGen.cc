#include <cstring>
#include <stack>
#include <stdio.h>
#include "Object.h"

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

	ObjectMemoryOSThread & m_omemt;
	std::stack<GenerationContext *> m_ctx;
	//std::stack<MemOop<Function> > m_funcs;
	std::stack<VM::BytecodeEncoder *> m_gens;
	MemOop<Function> m_script;

	struct LabelDescriptor {
		const char *m_ident;
		StmtNode *m_stmt;
		size_t begin;
		size_t end;
		/** Jump instructions created by breaks to set offset to end. */
		std::vector<size_t> m_breaks;
	};

	/**
	 * Stack of labels. Later we will also push sentinels to indicate we
	 * need to pop a block scope; when we reverse iterate over the stack to
	 * find the label to jump to, we can count those sentinels.
	 */
	std::vector<LabelDescriptor *> m_labelDescs;
	/** Labels to be bound to the next statement */
	std::vector<IdentifierNode *> m_nextStmtLabels;

	inline VM::BytecodeEncoder *coder() { return m_gens.top(); }

	void enterNewFunction();
	MemOop<Function>exitFunction(DeclEnv *env);

	/** Sets up label stack for a statement. */
	void enterStmt(StmtNode *stmt, size_t beginPos);
	void exitStmt(StmtNode *stmt, size_t endPos);

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
	int visitIf(IfNode *node, ExprNode *cond, StmtNode *ifCode,
	    StmtNode *elseCode);
	// int visitContinue(BreakNode *node, IdentifierNode *label);
	int visitBreak(BreakNode *node, IdentifierNode *label);
	int visitReturn(ReturnNode *node, ExprNode *expr);
	int visitLabel(LabelNode *node, IdentifierNode *label, StmtNode *stmt);

	int visitSingleDecl(SingleDeclNode *node, DestructuringNode *lhs,
	    ExprNode *rhs);
	int visitDecl(DeclNode *node, DeclNode::Type type,
	    SingleDeclNode::Vec *&decls);

	int visitScript(ScriptNode *node, StmtNode::Vec *stmts);

    public:
	BytecodeGenerator(ObjectMemoryOSThread & omemt);

	MemOop<Function> script() { return m_script; }
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

void disassemble(char * code, int siz);

MemOop<Function>
VM::BytecodeEncoder::makeFun(std::vector<char *> &localNames,
    std::vector<char *> &paramNames)
{
	MemOop<CharArray> bytecode = m_omemt.makeCharArray(m_bytecode);
	MemOop<EnvironmentMap> envMap = m_omemt.makeEnvironmentMap(paramNames,
	    localNames);
	MemOop<PlainArray> literals = m_omemt.makeArray(m_literals.size());
	memcpy(literals->m_elements, m_literals.data(), m_literals.size() * sizeof(Oop));

	return m_omemt.makeFunction(envMap, bytecode, literals);
}

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

BytecodeGenerator::BytecodeGenerator(ObjectMemoryOSThread &omemt)
    : m_omemt(omemt)
{
	m_ctx.push(new GenerationContext(GenerationContext::kGlobal));
}

void
BytecodeGenerator::enterNewFunction()
{
	VM::BytecodeEncoder *encoder = new VM::BytecodeEncoder(m_omemt);
	m_gens.push(encoder);
}

MemOop<Function>
BytecodeGenerator::exitFunction(DeclEnv *env)
{
	MemOop<Function> jsf;
	std::vector<char*> localNames;
	std::vector<char*> paramNames;

	m_gens.top()->emit0(VM::kPushUndefined);
	m_gens.top()->emit0(VM::kReturn);

	for (std::map<std::string, Decl *>::iterator it = env->m_decls.begin();
	     it != env->m_decls.end(); it++)
		if (it->second->m_type == Decl::kLocal)
			localNames.push_back(
			    strdup(it->first.c_str()));
		else if (it->second->m_type == Decl::kArg) {
			if (it->second->m_idx + 1 > paramNames.size())
				paramNames.resize(it->second->m_idx + 1, NULL);
			paramNames[it->second->m_idx] = strdup(
			    it->first.c_str());
		}


	jsf = m_gens.top()->makeFun(localNames, paramNames);
	delete m_gens.top();
	m_gens.pop();

	return jsf;
}

void
BytecodeGenerator::enterStmt(StmtNode *stmt, size_t beginPos)
{
	LabelDescriptor *desc = NULL;

	while (!m_nextStmtLabels.empty()) {
		IdentifierNode *id = m_nextStmtLabels.back();

		m_nextStmtLabels.pop_back();

		if (!desc) {
			desc = new LabelDescriptor;
			desc->m_stmt = stmt;
			desc->m_ident = id->value();
			desc->begin = beginPos;
		}

		m_labelDescs.push_back(desc);
	}
}

void
BytecodeGenerator::exitStmt(StmtNode *stmt, size_t emdPos)
{
	while (!m_labelDescs.empty() && m_labelDescs.back()->m_stmt == stmt) {
		LabelDescriptor *desc = m_labelDescs.back();
		m_labelDescs.pop_back();
		printf("May rewrite label <%s>\n", desc->m_ident);
		for (std::vector<size_t>::iterator it = desc->m_breaks.begin();
		     it != desc->m_breaks.end(); it++) {
			/* patch break statements to the end of the statement */
			coder()->replaceJumpTarget(*it, emdPos);
		}
		delete desc;
	}
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
	MemOop<Function> jsf;

	m_ctx.push(new GenerationContext(GenerationContext::kFunction));
	enterNewFunction();
	//jsf = enterNewFunction();
	//jsf->m_paramNames.resize(formals->size(), NULL);

	FOR_EACH (std::vector<DestructuringNode *>, it, *formals) {
		DestructuringVisitor destr(*this, nParams++);
		(*it)->accept(destr);
	}

	FOR_EACH (StmtNode::Vec, it, *body) {
		(*it)->accept(*this);
	}

	jsf = exitFunction(node);
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
BytecodeGenerator::visitIf(IfNode *node, ExprNode *cond, StmtNode *ifCode,
    StmtNode *elseCode)
{
	/** Location of conditional jump instruction to jump to else-case */
	size_t jumpPastIfCode;
	/*
	 * Location of jump instruction within if-case body to skip the
	 * else-case.
	 */
	size_t jumpPastElseCode;

	enterStmt(node, coder()->pos());

	cond->accept(*this);
	/* jump past the if-code if false; 0 is a placeholder */
	coder()->emit1i16(VM::kJumpIfFalse, 0);

	jumpPastIfCode = coder()->pos();
	ifCode->accept(*this);

	if (elseCode) {
		/* jump past the else-case code; 0 is a placeholder */
		coder()->emit1i16(VM::kJump, 0);
		jumpPastElseCode = coder()->pos();
	}

	/* patch jump target to after if-case */
	coder()->replaceJumpTarget(jumpPastIfCode, coder()->pos());

	if (elseCode) {
		elseCode->accept(*this);
		/* patch jump target to after else-case  */
		coder()->replaceJumpTarget(jumpPastElseCode, coder()->pos());
	}

	exitStmt(node, coder()->pos());

	return 0;
}

int
BytecodeGenerator::visitBreak(BreakNode *node, IdentifierNode *label)
{
	int nScopesToPop = 0;

	for (std::vector<LabelDescriptor *>::reverse_iterator it =
		 m_labelDescs.rbegin();
	     it != m_labelDescs.rend(); it++) {
		if ((*it)->m_stmt == 0) {
			/* null statement is a block scope sentinel */
			nScopesToPop++;
		} else if (!label || !strcmp((*it)->m_ident, label->value())) {

			coder()->emit1i16(VM::kJump, 0);
			(*it)->m_breaks.push_back(coder()->pos());
			return 0;
		}
	}

	printf("Syntax error: undefined label <%s>", label->value());
	throw "error";
}

int
BytecodeGenerator::visitReturn(ReturnNode *node, ExprNode *expr)
{
	expr->accept(*this);
	m_gens.top()->emit0(VM::kReturn);
	return 0;
}

int
BytecodeGenerator::visitLabel(LabelNode *node, IdentifierNode *label,
    StmtNode *stmt)
{
	m_nextStmtLabels.push_back(label);
	stmt->accept(*this);
	return 0;
}

int
DestructuringVisitor::visitSingleNameDestructuring(
    SingleNameDestructuringNode *node, IdentifierNode *ident,
    ExprNode *initialiser)
{
	if (m_destructuring.empty()) {
#if 0
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
#endif
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
	m_script->disassemble();
	return 0;
}

MemOop<Function>
Driver::generateBytecode()
{
	Hoister hoister;
	BytecodeGenerator visitor(m_omemt);
	m_script->accept(hoister);
	m_script->accept(visitor);
	return visitor.script();
}
