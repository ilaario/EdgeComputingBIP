
#include <iostream>
#include <string>
#include <fstream>
#include <cassert>

#include <unistd.h>
#include <termios.h>

#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vtop.h"
#include "Vtop__Dpi.h"

#include "rvtarget.h"

// Short typenames
using i64 = int64_t;
using u64 = uint64_t;
using i32 = int32_t;
using u32 = uint32_t;
using i8 = int8_t;
using u8 = uint8_t;

// Simulation context globals

#ifdef TRACE_WAVE
    VerilatedVcdC* m_trace;
#endif

Vtop *dut;
u64 sim_time = 0;

void simulation_exit(i32 exit_code) {

    #ifdef TRACE_WAVE
        m_trace->close();
    #endif

    std::cout << '\n';
    std::cout << "exit_status: " << exit_code << '\n';
    std::cout << "sim_ticks: " << sim_time / 2 << '\n';

    exit(exit_code);
}

// Simulate peripherals

const u32 dpi_mem_size = 1 * 1024 * 1024; // 1 MB of memory
u8 dpi_mem_array [dpi_mem_size];

void load_bin(const std::string& filename) {
    std::ifstream file(filename, std::ios::binary | std::ios::ate);

    if (!file.is_open()) {
        std::cerr << "ERROR: Could not open binary file: " << filename << std::endl;
        exit(-1);
    }

    // 2. Determine file size and reset position to beginning
    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    if (size > dpi_mem_size) {
        std::cerr << "ERROR: Binary file " << filename << " (" << size << " bytes) exceeds memory size (" << dpi_mem_size << " bytes)" << std::endl;
        exit(-1);
    }

    file.read(reinterpret_cast<char*>(dpi_mem_array), size);
    file.close();
}

i32 mem_dpi (i32 addr, i32 data, i32 op) {
    bool is_store = (op >= 8);

    u32 uaddr = u32(addr);
    u32 udata = u32(data);

    if (is_store) {
        // Support byte leve write
        // Create wstrbs
        bool wstrbs[4] = {false, false, false, false};
        
        u8 bytes[4];
        for (int i = 0; i < 4; i++) bytes[i] = u8((udata >> (8 * i)) & 0xFF);
        u32 byte_addr = uaddr & 0b11;
        
        
        if (uaddr == EXIT_STATUS_ADDR) {
            simulation_exit(data);
        }
        else if (uaddr == SERIAL_TX_DATA_ADDR) {
            std::cout << char(data & 0xFF);
        }
        else if ((uaddr & 0x80000000) == DRAM_START_ADDR) {
            // SB
            if (op == 8) {
                wstrbs[byte_addr] = true;
                bytes[byte_addr] = bytes[0];
            }
            // SH
            else if (op == 9) {
                if (byte_addr == 0 || byte_addr == 2) {
                    wstrbs[byte_addr] = true;
                    wstrbs[byte_addr + 1] = true;
                    bytes[byte_addr] = bytes[0];
                    bytes[byte_addr + 1] = bytes[1];
                }
            }
            // SW
            else {
                for (int i = 0; i < 4; i++) wstrbs[i] = true;
            }
            
            uaddr -= DRAM_START_ADDR; // Align to 0
            uaddr = (uaddr >> 2) << 2; // Align to 4B
            for (int i = 0; i < 4; i++) {
                if (wstrbs[i]) dpi_mem_array[uaddr + i] = bytes[i];
            }
        }
    }

    if (uaddr >= DRAM_START_ADDR) {
        uaddr -= DRAM_START_ADDR;
        return ((u32*) dpi_mem_array)[uaddr >> 2];
    } 

    return 0;

}

int main(int argc, char** argv) {
    // Evaluate Verilator comand args
    Verilated::commandArgs(argc, argv);

    std::string elf_path;
    u64 max_sim_time = 0;

    // Evaluate our command args
    for(i32 i = 1; i < argc; i++) {
        std::string arg = argv[i];
        
        if (arg == "-e") {
            i++;
            if (i == argc) break;
            elf_path = argv[i];
        }
        else if (arg == "--max-time") {
            i++;
            if (i == argc) break;
            max_sim_time = std::stoi(argv[i]);
        }
    }

    dut = new Vtop;
    load_bin(elf_path);

    #ifdef TRACE_WAVE
        // trace signals 5 levels under dut
        Verilated::traceEverOn(true);
        m_trace = new VerilatedVcdC;
        dut->trace(m_trace, 100);
        m_trace->open("waveform.vcd");
    #endif

    while (max_sim_time == 0 || sim_time < max_sim_time) {
        
        // Clk Toggle
        dut->clk ^= 1;
        // Reset signal
        bool reset_on = sim_time <= 4;
        dut->resetn = u8(!reset_on);

        dut->eval();
        
        #ifdef TRACE_WAVE
            // Trace signals
            m_trace->dump(sim_time);
        #endif

        sim_time++;
    }

    simulation_exit(-1);

}
