#ifndef OBJECTMEMORY_HH_
#define OBJECTMEMORY_HH_

#include "Object.h"

namespace VM {

class ObjectMemory {
	static UndefinedDesc s_undefinedDesc;
	static NullDesc s_nullDesc;
	static BooleanDesc s_trueDesc, s_falseDesc;

	public:
	static Oop s_undefined, s_null, s_true, s_false;
};

};

#endif /* OBJECTMEMORY_HH_ */
