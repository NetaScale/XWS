#ifndef VM_HH_
#define VM_HH_

#include <cstring>
#include <stack>
#include <stdint.h>
#include <vector>

namespace VM {

class JSObject;

struct JSValue {
	enum Type {
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
	    : type(kDouble)
	    , obj(val) {};
};

class JSObject {
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
};

/**
 * An instantiated function object.
 */
class JSClosure : public JSObject {
	JSFunction *func;
};

class Environment {
	Environment *m_base;
};

class Interpreter {
	std::stack<JSValue> m_stack;

	Environment *m_env;

	/** base pointer: base of stack for current function */
	unsigned int m_bp;
};

};

#endif /* VM_HH_ */
