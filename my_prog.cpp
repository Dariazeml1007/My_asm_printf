#include <stdio.h>

// asm func
extern "C" void  my_printf(const char* format, ...);

int main()
{
    //  my_printf
    my_printf("%d %d %c \n", (long long)-30, (long long)25, 's');
    return 0;
}
