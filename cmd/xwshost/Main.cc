
#include <iostream>
#include <string>
#include <sstream>

#define VERINFO "Xwin Script Host(tm) 1.0 beta " __DATE__ " " __TIME__ ""
#define CPYRIGHT "Copyright (c) 2021 NetaScale Systems Ltd. " \
    "All rights reserved."
#define USE "Use is subject to licence terms."

#include "Driver.hh"
#include "Scanner.ll.hh"
#include "AST.hh"
#include "VM.hh"

std::ostream& ital(std::ostream& os)
{
    return os << "\e[3m";
}

std::ostream& def(std::ostream& os)
{
    return os << "\e[0m";
}


int main2(int argc, char * argv[], ObjectMemoryOSThread& omemt)
{
	/*std::string tst("const y = 40;\n"
			"const fn = function fn(a, b) { return a + b + y; }\n"
			"return fn(1, 2);");*/
	std::string tst("const fn = (a = 1, b) => a + b;\n"
	    "return fn(1, 2);");
	Driver drv(omemt);
	YY_BUFFER_STATE yybuf;

	std::cout << VERINFO << "\n" << CPYRIGHT << "\n" << USE << "\n";

	jslex_init_extra(&drv, &drv.scanner);
	yybuf = js_scan_string(tst.c_str(), drv.scanner);
	drv.txt =tst.c_str();
	//jsdebug = 1;
	jsparse(&drv);

	/* Now we can clean up the buffer. */
	js_delete_buffer(yybuf, drv.scanner);
	/* And, finally, destroy this scanner. */
	jslex_destroy(drv.scanner);

	VM::Interpreter interp(omemt, omemt.makeClosure(drv.generateBytecode(),
	    *(MemOop<Environment> *)&ObjectMemory::s_undefined));
	std::cout << "Evaluating bytecode corresponding to JS source:\n";
	std::cout << ital << tst << def << "\n";

	interp.interpret();

	return 0;
}

int
main(int argc, char *argv[])
{
	void * marker = &marker;
	ObjectMemory omem;
	ObjectMemoryOSThread omemt(omem, marker);
	return main2(argc, argv, omemt);
}
