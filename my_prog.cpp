#include <stdio.h>

// asm func
extern "C" void  my_printf(const char* format, ...);

int main()
{
    //  my_printf
    my_printf("%d %d %x \n",  (long long)7, (long long)-101, (long long)11);
    return 0;
}
