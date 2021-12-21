#ifndef VM_HH_
#define VM_HH_

#include <cstdio>
#include <cstring>
#include <stack>
#include <stdint.h>
#include <vector>

#include "ObjectMemory.hh"

namespace VM {

class JSObject;

struct JSValue {
	enum Type {
		kUndefined,
		kInt32,
		kString,
		kDouble,
		kObject,
	} type;

	union {
		int32_t i32;
		char *str;
		double dbl;
		JSObject * obj;
	};

	JSValue() : type(kUndefined), obj(0) {};
	JSValue(int32_t val)
	    : type(kInt32)
	    , i32(val) {};
	JSValue(const char *val)
	    : type(kDouble)
	    , str(strdup(val)) {};
	JSValue(double val)
	    : type(kDouble)
	    , dbl(val) {};
	JSValue(JSObject *val)
	    : type(kObject)
	    , obj(val) {};

	bool JS_ToBoolean();

	void print();
};

class JSObject {
	public:
	virtual void print() { return; }
};

struct ScopeMap {
	std::vector<char *> m_localNames;
	std::vector<char *> m_paramNames;
};

/**
 * An underlying JavaScript function object.
 */
class JSFunction : public JSObject, public ScopeMap {
    public:
	std::vector<char> m_bytecode;
	std::vector<JSValue> m_literals;

	void disassemble(); /* bytecode.cc */
	void print() { printf("func"); }
};

struct Environment : public JSObject {
	ScopeMap *m_map;
	Environment *m_prev;
		std::vector<JSValue> m_params;
			std::vector<JSValue> m_locals;

	Environment(ScopeMap *map, Environment * prev = NULL);

	JSValue resolve(const char *id);
	void resolveStore(const char * id, JSValue val);
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
