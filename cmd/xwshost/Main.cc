
#include <iostream>

#define VERINFO "Xwin Script Host(tm) 1.0 beta " __DATE__ " " __TIME__ ""
#define CPYRIGHT "Copyright (c) 2021 NetaScale Systems Ltd. " \
    "All rights reserved."

int main(int argc, char * arg[])
{
	std::cout << VERINFO << "\n" << CPYRIGHT << "\n";
	return 0;
}