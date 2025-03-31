#include <stdio.h>

// asm func
extern "C" void  my_printf(const char* format, ...);

int main()
{
    //  my_printf
  printf("%d\n%d %s %x %d%%%c%b\n%d %s %x %d%%%c%b\n", (long long)-1,(long long) -1, "love", (long long)3802, (long long)100, (long long)33, (long long)127, (long long)1, "love", (long long)3802, (long long)100, (long long)33, (long long)127);
    return 0;
}
