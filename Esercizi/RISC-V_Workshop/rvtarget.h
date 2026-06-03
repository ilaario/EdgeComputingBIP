#ifndef RV_TARGET_H
#define RV_TARGET_H

#define DRAM_START_ADDR       0x80000000

// Exit status
#define EXIT_STATUS_ADDR        0x10010000
#define EXIT_STATUS_REG         *((volatile uint32_t *) EXIT_STATUS_ADDR)

// Serial emulator
#define SERIAL_TX_DATA_ADDR     0x10020000
#define SERIAL_TX_DATA          *((volatile uint32_t *) SERIAL_TX_DATA_ADDR)

#endif
