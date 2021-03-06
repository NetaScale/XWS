#ifndef VM_HH_
#define VM_HH_

#include <cstdio>
#include <cstring>
#include <stack>
#include <stdint.h>
#include <vector>

#include "Object.h"

#include "ObjectMemory.hh"

namespace VM {

class Interpreter {
	ObjectMemoryOSThread &m_omemt;
	std::vector<Oop> m_stack;
	MemOop<Environment> m_env;
	MemOop<Closure> m_closure;
	mps_root_t m_mpsRoot;

	/** base pointer: base of stack for current function */
	unsigned int m_bp;
	/** program counter */
	unsigned int m_pc;

	inline Oop push(Oop oop);
	inline Oop pop();

    public:
	Interpreter(ObjectMemoryOSThread &omemt, MemOop<Closure> closure);

	void interpret();
};

};

#endif /* VM_HH_ */
