#include <stdio.h>

// asm func
extern "C" void  my_printf(const char* format, ...);

int main()
{
    //  my_printf
    my_printf("%% %c %s %x %o %d %b \n", 'v', "abcd", (long long) 13, (long long) 8, (long long) 123, (long long) 5 );
    return 0;
}
