
#include <iostream>
#include <string>
#include <sstream>

#define VERINFO "Xwin Script Host(tm) 1.0 beta " __DATE__ " " __TIME__ ""
#define CPYRIGHT "Copyright (c) 2021 NetaScale Systems Ltd. " \
    "All rights reserved."

#include "Driver.hh"
#include "Scanner.ll.hh"
#include "Parser.tab.i"

int
main(int argc, char *arg[])
{
	std::string tst("test\n    tester");
	Driver drv;
	YY_BUFFER_STATE yybuf;

	std::cout << VERINFO << "\n" << CPYRIGHT << "\n";

	jslex_init_extra(&drv, &drv.scanner);
	yybuf = js_scan_string(tst.c_str(), drv.scanner);
	yyparse(&drv);

	/* Now we can clean up the buffer. */
	js_delete_buffer(yybuf, drv.scanner);
	/* And, finally, destroy this scanner. */
	jslex_destroy(drv.scanner);

	return 0;
}