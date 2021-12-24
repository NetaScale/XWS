#ifndef DRIVER_HH_
#define DRIVER_HH_

#include "Object.h"

class ObjectMemoryOSThread;

#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void *yyscan_t;
#endif

struct YYLTYPE;
class ScriptNode;

class Driver {
    public:
	yyscan_t scanner;
	const char *txt;
	ObjectMemoryOSThread & m_omemt;

	union {
		ScriptNode *m_script;
	};

	enum Type {
		kScript,
		kModule,
	} m_resultType;

	Driver(ObjectMemoryOSThread & omemt) : m_omemt(omemt) {}

	MemOop<Function> generateBytecode();
};

#endif /* DRIVER_HH_ */