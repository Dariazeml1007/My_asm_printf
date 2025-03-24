#include <stdio.h>

// asm func
extern "C" void  my_printf(const char* format, ...);

int main()
{
    //  my_printf
    my_printf("%s \n",  "aaaaa" );
    return 0;
}
