#include <stdint.h>
#include <rvtarget.h>

void print(char* str) {
    int i = 0;
    while (str[i] != 0) {
        SERIAL_TX_DATA = str[i];
        i++;
    }
}

int main() {
    print("Hello from RISC-V C!");
    return 0;
}
