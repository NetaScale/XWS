#ifndef VM_HH_
#define VM_HH_

#include <cstdio>
#include <cstring>
#include <stack>
#include <stdint.h>
#include <vector>

#include "ObjectMemory.hh"

namespace VM {

/**
 * An underlying JavaScript function object.
 */
class JSFunction : public JSObject, public EnvironmentMap {
    public:
	std::vector<char> m_bytecode;
	std::vector<JSValue> m_literals;

	void disassemble(); /* bytecode.cc */
	void print() { printf("func"); }
};

/**
 * An instantiated function object.
 */
class JSClosure : public JSObject {
    public:
	JSFunction *m_func;
	Environment *m_baseEnv;

	JSClosure(JSFunction *func, Environment *baseEnv = NULL)
	    : m_func(func)
	    , m_baseEnv(baseEnv)
	{
	}

	void print() { printf("closure"); }
};

class Interpreter {
	std::stack<JSValue> m_stack;

	Environment *m_env;
	JSClosure *m_closure;

	/** base pointer: base of stack for current function */
	unsigned int m_bp;
	/** program counter */
	unsigned int m_pc;

	JSValue pop();

    public:
	Interpreter(JSClosure *closure);

	void interpret();
};

};

#endif /* VM_HH_ */
