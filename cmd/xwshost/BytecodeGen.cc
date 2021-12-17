#include "AST.hh"

class BytecodeGeneratorVisitor: public Visitor {

};


	int Driver::generateBytecode()
	{
		BytecodeGeneratorVisitor visitor;
		return m_script->accept(visitor);
	}
