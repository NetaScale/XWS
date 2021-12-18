#ifndef DRIVER_HH_
#define DRIVER_HH_

namespace VM {
class JSFunction;
};

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

	union {
		ScriptNode *m_script;
	};

	enum Type {
		kScript,
		kModule,
	} m_resultType;

	VM::JSFunction *generateBytecode();
};

#endif /* DRIVER_HH_ */