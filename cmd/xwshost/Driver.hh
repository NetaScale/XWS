#ifndef DRIVER_HH_
#define DRIVER_HH_

#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void* yyscan_t;
#endif

struct YYLTYPE;

class Driver {
	public:
	yyscan_t scanner;
	const char * txt;
};

#endif /* DRIVER_HH_ */