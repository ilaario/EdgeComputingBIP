# Hands-on Lab on Energy/Power Aware-Programming

## Preliminaries: 

To run the experiments, we will use the socarrat.unizar.es machine that belongs to the Computer Architecture Group at the University of Zaragoza. Your user id is the same for all the machines in the [DIIS](https://diis.unizar.es/es), _letter "a" followed by your NIP_, and the password will be provided at the beginning of the session.

### Measuring Energy and Power on linux

To measure total power (dynamic + static), we are going to rely on the Intel power hardware counters, [RAPL](https://01.org/blogs/2014/running-average-power-limit-%E2%80%93-rapl), of an Intel Skylake processor (4 cores, 2 threads/core) and read them with the `perf` tool. Since these counters are global and not per application, the results may be incorrect with multiple users. You can run the tool with:

    $ perf stat -a -e "power/energy-cores/" <cmd>

Also, before continuing with the lab, please take a quick look to the man page of perf
[command](https://man7.org/linux/man-pages/man1/perf.1.html) and
[manual](https://perf.wiki.kernel.org/index.php/Main_Page) to learn the the basics of the tool.

As said, since the counters are not replicated for every core, if several of you run an
experiment at the same time, the measured energy will correspond to the sum of
the energies of all the running experiments. To get accurate results, please
share a token on a chat. Also, you can perform the lab in couples to reduce the total number of runs.

Intel RAPL offers readings from multiple power domains. The `power/energy-cores/` domain measures only the energy of the cores. The `power/energy-pkg/` returns the energy consumption of the whole package; this domain manages the entire CPU socket, which includes all the processor cores as well as the uncore components (e.g., the last-level cache, integrated GPU, and memory controller). Finally,  the `power/energy-ram/` reports the DRAM energy consumption. 

### Building the examples

Once you are able to measure energy and power and to compile code, it is time to clone the repo and build the example programs. To do so, please login again with your account into socarrat and run the following commands:

    git clone https://github.com/universidad-zaragoza/designing-modern-processors.git
    
    cd designing-modern-processors
    
    mkdir build-release
    
    cd build-release
    
    cmake -DCMAKE_BUILD_TYPE=Release ../
    
    make -j$(nproc)

The repo uses [cmake](https://cmake.org/) as build system that encourages to keep your binary files separated from the source code.

Now, you are ready to start analyzing how different aspects affects the energy and consumption of your code. 

## Effect of Parallelism in Performance and Energy consumption on CPU

The first experiment of the lab analyzes a simple C++ code that approximates &pi; with a Taylor series.

The &pi; number represents the ratio of a circle's circumference to its
diameter, and its value was already approximated before the Common Era. The
ancient Greek Archimedes already devised a [&pi; approximation
algorithm](https://en.wikipedia.org/wiki/Approximations_of_%CF%80).

With a Taylor series, &pi; can be approximated as

<img src=figures/pi_taylor.png width=300 height=100>

The C++ source code of the program is located in the pi-taylor directory of this repository and is named [pi_taylor_parallel.cc](https://github.com/universidad-zaragoza/designing-modern-processors/blob/main/pi-taylor/pi_taylor_parallel.cc).

Within the source code, the `pi_taylor_chunk` functions computes and accumulates a chunk of steps from the approximation, so multiple threads can share the work because the steps are independent among them.

```C++
void
pi_taylor_chunk(std::vector<my_float> &output,
        size_t thread_id, size_t start_step, size_t stop_step)
{

    my_float acc = 0.0f;
    int sign = start_step & 0x1 ? -1 : 1;

    for (size_t i = start_step; i < stop_step; ++i) {
        my_float divider = 2.0f * i + 1.0f;
        acc += static_cast<my_float>(sign) / divider;
        sign = -sign;
    }
    output[thread_id] = acc;
}
```

Then, the main program launches a number of threads, waits for their completion, and performs the final addition and division to estimate &pi;.

```C++
    thread_vector.reserve(threads);
    for(size_t i = 0; i < threads; ++i) {
        auto begin = i * steps_per_thread;
        auto end = std::min(begin + steps_per_thread, steps);
        thread_vector.push_back(std::thread(save_times, begin, end, i));
    }

    for(auto &t: thread_vector) {
        t.join();
    }

    my_float pi = 4.0L * std::accumulate(partial_results.begin(),
        partial_results.end(), 0.0L);
```

Please do not hesitate to ask about the code if you have any question. Inside your `build-release/pi-taylor` directory, there should be a `pi_taylor_parallel` binary. Two arguments control its execution, the number of steps and the number of threads. During the lab, the number of steps can be set to 100000000 to run the program just long enough.

First, please run the program with perf (the -r 5 argument repeats the experiment 5 times) and a single thread.

    $ perf stat -a -e power/energy-cores/ -r 5 ./pi_taylor_parallel 100000000 1

Then, run the program with 2, 4, 8, and 16 threads, and plot the results with the number of threads in the X axe and the execution time and
total energy in the Y axe. You can use an online service such as [colab](https://colab.research.google.com/), [jupyter](https://jupyter.org/try), your favorite spreadsheet, or your preferred tool for plotting.

### Questions

1. Do total energy and execution time correlate? Why? 
1. Does average power increases when the number of threads does so? Why?
1. Is the total amount of work done very similar between runs with different number of threads?
If yes, why energy may depend on the number of threads ?
1. Based on the responses to the previous questions, do you think that the control parts of the processors such as clock distribution, instruction fetch, decode and control can represent an important part of the energy consumed?


## Effect of locality on power and energy in Matrix Multiplication on CPU

One key programming optimization to save energy is locality. In general, when a program reuses data, there are fewer data movements between the memory hierarchy and the execution units, saving energy and reducing execution time. Matrix Multiplication is a problem where locality plays a significant role. The access pattern of each input matrix is opposite, while one matrix is traversed by rows, the other one is traversed by columns. Assuming a [row-major](https://en.wikipedia.org/wiki/Row-_and_column-major_order) order as C++ does, traversing by rows will ensure good spatial locality, while the stride access of the column-based traversing will probably trash the cache and waste a lot of energy bringing unused data to the on-chip caches.

To check the effect of locality, in this exercise, you will compare a naive matrix multiplication implementation with a highly optimized version from the [Eigen](https://eigen.tuxfamily.org/index.php?title=Main_Page) library <sup>[1](#footnote1)</sup>. The code of both versions is located inside the [matrix-multiplication](https://github.com/universidad-zaragoza/designing-modern-processors/tree/main/matrix-multiplication) directory. Please check both versions and try to make a mental model of the cache accesses to assess their locality (both spatial and temporal).

### Questions

1. Please run both versions and compare execution time, average power, and total energy. Are the energy gains for the package equal to the core gains? 

<a name="footnote1">1</a>: _Besides using tiling, transposing matrices, ... Eigen also can vectorize the code, so the comparison is not entirely fair._

## Effect of device selection on performance and power

Continuing with the matrix multiplication example, the next step consist on comparing the Eigen optimized CPU version with their GPU counterpart based on the [cuBLAS](https://developer.nvidia.com/cublas) library. This library provides a highly optimized version of [Basic Linear Algebra Subprograms](https://en.wikipedia.org/wiki/Basic_Linear_Algebra_Subprograms), BLAS, on GPU. On the socarrat system, the GPU is a Nvidia GeForce RTX 3090 Ti. To estimate the GPU power consumption, Nvidia provides the `nvidia-smi` tool that queries the GPU and prints the power drawn, among other things. In our particular case, the following command prints the power drawn every second during ten seconds:

    $ nvidia-smi dmon -s p -c 10

Since the execution time of the code and the period of the tool is large, to estimate the power and energy, we are going to assume that the maximum value read represents the average power for the whole execution. For example, for the following output, the assumed average power will be 96 W.

    [dariosg@socarrat man]$ nvidia-smi dmon -s p -c 10                                                                                                                                                                        
    # gpu   pwr gtemp mtemp
    # Idx     W     C     C
        0    15    51     -
        0    15    51     -
        0    15    51     -
        0    15    51     -
        0    62    53     -
        0    95    53     -
        0    96    53     -
        0    96    52     -
        0    60    53     -
        0    95    54     -

Now, please run the eigen_matrix_multiplication, CPU, and cublas_matrix_multiplication, GPU, applications and collect the execution time and energy of both executions for matrices of the same size.

### Questions

1. Open the [cublas_matrix_multiplication.cc](https://github.com/universidad-zaragoza/designing-modern-processors/blob/main/matrix-multiplication/cublas_matrix_multiplication.cc) file and find where the time measurement process starts and stops. Does the measured time
includes the data transfer time between CPU and GPU or only the execution time on the GPU? Why?
1. How many FLOPS operations perform the program, only in the matrix multiplication? Please compute the energy efficiency (in terms of FLOPS/Jules) of the CPU and the GPU? Which device is more efficient if we only account for the device themselves?
1. While the GPU performs the matrix multiplication, the CPU is also active? What is the energy efficiency when the host CPU energy is included?
1. Based on the previous results? Are GPUs a good accelerator for heavy computing tasks? 

## Evaluation

Fill your answers in the moodle questionnaire.

--------------------------------------------------

# Answers

## Effect of Parallelism in Performance and Energy Consumption on CPU

Measured results for `./pi_taylor_parallel 100000000 <threads>`:

| Threads | Time (s) | Core energy (J) | Average core power (W) | Speedup |
|---:|---:|---:|---:|---:|
| 1 | 0.28229 | 13.45 | 47.65 | 1.00x |
| 2 | 0.16773 | 8.49 | 50.62 | 1.68x |
| 4 | 0.11404 | 6.09 | 53.40 | 2.48x |
| 8 | 0.10974 | 5.84 | 53.22 | 2.57x |
| 16 | 0.07935 | 4.48 | 56.46 | 3.56x |

1. Total energy and execution time correlate in these measurements. As the number of threads grows, execution time falls from 0.28229 s to 0.07935 s, and core energy falls from 13.45 J to 4.48 J. The reason is that energy is power multiplied by time. Average core power increases with more threads, but the runtime reduction is larger, so total energy still goes down.

2. Average core power mostly increases with the number of threads. It rises from about 47.65 W with one thread to about 56.46 W with sixteen threads. More threads keep more cores or hardware threads active at the same time, so the processor uses more execution units, cache resources, clocked logic, and control circuitry. The increase is not linear because cores share resources, turbo or frequency limits can change, and eight or sixteen software threads may use simultaneous multithreading or oversubscribe the available physical cores.

3. The useful work is almost the same in every run. The program always computes 100,000,000 Taylor-series terms and then reduces the partial sums. Energy still depends on the number of threads because the same arithmetic work runs with a different processor state: more active cores, different idle time, thread creation and join overhead, cache and coherence activity, and possible frequency changes. The processor also pays static energy for less time when the parallel run finishes sooner.

4. Yes. These results suggest that processor control parts can represent an important share of the consumed energy. The arithmetic work stays almost constant, but energy and average power change when the thread count changes. The processor also spends energy in the rest of the core machinery, including clock distribution, instruction fetch, decode, scheduling, control logic, and cache-related control. The RAPL counter does not isolate each block, so the result is evidence for the idea rather than a direct measurement of those parts.

## Effect of Locality on Power and Energy in Matrix Multiplication on CPU

The matrix size was kept at the default value in `constants.h`, `8192 x 8192`.

Measured results:

| Version | Status | Matrix multiplication time printed by the program | Perf elapsed time | Core energy | Package energy | Average core power | Average package power |
|---|---|---:|---:|---:|---:|---:|---:|
| Naive | Did not complete one full run in a reasonable time | N/A | N/A | N/A | N/A | N/A | N/A |
| Eigen | Completed 5 runs | 42.557 s average | 46.62 s average | 3049.22 J | 3615.62 J | 65.41 W | 77.56 W |

For Eigen, average power was computed from the `perf` elapsed time:

```text
average core power = 3049.22 J / 46.62 s = 65.41 W
average package power = 3615.62 J / 46.62 s = 77.56 W
```

The naive version did not finish a full measurement at `8192 x 8192`. This is expected because the naive algorithm performs `8192^3`, or about 549.8 billion, inner-loop iterations. With the simple `i, j, k` loop order, one of the two input matrices is traversed with a large stride instead of contiguous accesses. That access pattern has poor spatial locality and causes many cache misses.

Eigen completed the same matrix size because it uses an optimized multiplication strategy. It improves locality by reusing blocks of data in cache, and it may also use vectorized instructions. As a result, it performs the same mathematical operation with less wasted data movement.

Because the naive version did not complete, the exact energy gain cannot be computed from these measurements. The qualitative result is still clear: for this matrix size, Eigen is practical while the naive implementation is not. The energy gains for package and cores should not be expected to be equal. Core energy measures mainly the CPU cores, while package energy also includes uncore components such as shared caches, memory-controller activity, and other socket logic. Locality affects both computation and data movement, so core energy and package energy can change by different percentages.

## Effect of Device Selection on Performance and Power

The experiment uses the default matrix size, `8192 x 8192`.

Measured results:

| Version | Time printed by the program | `perf` elapsed time | Device energy used for efficiency | Host CPU package energy from `perf` | Device efficiency |
|---|---:|---:|---:|---:|---:|
| CPU Eigen | 42.557 s average | 46.62 s average | 3615.62 J CPU package | 3615.62 J | 0.304 GFLOP/J |
| GPU cuBLAS | 0.946 s | 58.2727 s | 93.65 J GPU estimate | 3575.66 J | 11.740 GFLOP/J |

For the GPU run, `nvidia-smi dmon` reported a maximum power of 99 W, so the estimated GPU energy is:

```text
GPU energy = 99 W * 0.946 s = 93.65 J
```

The matrix multiplication performs:

```text
FLOPs = 2 * 8192^3 = 1,099,511,627,776 FLOPs
```

The CPU device efficiency, using CPU package energy, is:

```text
CPU efficiency = 1,099,511,627,776 / 3615.62 J
               = 0.304 GFLOP/J
```

The GPU device efficiency, using only GPU energy, is:

```text
GPU efficiency = 1,099,511,627,776 / 93.65 J
               = 11.740 GFLOP/J
```

1. In `cublas_matrix_multiplication.cc`, the timer starts immediately before the `cublasSetVector` calls and stops after `cublasGetVector`. The measured time printed by the program includes the transfers from CPU memory to GPU memory, the `cublasSgemm` execution, and the transfer of the result back to CPU memory. It does not include matrix initialization, `cudaMalloc`, or the Eigen reference multiplication used for validation.

2. The matrix multiplication performs about 1.10 trillion floating-point operations. Counting only device energy, cuBLAS on the GPU reaches about 11.740 GFLOP/J, while Eigen on the CPU package reaches about 0.304 GFLOP/J. The GPU is about 38.6 times more efficient in this device-only comparison.

3. The CPU is still active during the GPU run: it launches CUDA/cuBLAS work, manages transfers, runs the driver/runtime path, and waits for completion. `perf` measured 3575.66 J for the CPU package, but this covers the whole command, including the Eigen reference multiplication before the timed GPU section.

Using the whole-process host energy:

```text
total energy = 93.65 + 3575.66 = 3669.31 J
efficiency = 1,099,511,627,776 / 3669.31 = 0.300 GFLOP/J
```

Estimating host energy only during the 0.946 s GPU-timed region:

```text
host energy = (3575.66 / 58.2727) * 0.946 = 58.06 J
total energy = 93.65 + 58.06 = 151.71 J
efficiency = 1,099,511,627,776 / 151.71 = 7.247 GFLOP/J
```

4. GPUs are good accelerators for heavy computing tasks like matrix multiplication. Matrix multiplication has massive data parallelism, and cuBLAS uses the GPU better than the CPU Eigen run uses the CPU package in this experiment. The GPU-only efficiency is 11.740 GFLOP/J, against 0.304 GFLOP/J for the CPU package. Even with a rough estimate of host CPU energy during the timed GPU phase, the GPU remains more efficient. The whole-process `perf` result is less favorable because the benchmark also runs a full CPU Eigen multiplication to check the result.
