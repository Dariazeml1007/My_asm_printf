#include <iostream>

// asm func
extern "C" void  my_printf(const char* format, ...);

int main()
{
    //  my_printf
    my_printf("%c %d %c", 'b', 498, 'b');
    return 0;
}
