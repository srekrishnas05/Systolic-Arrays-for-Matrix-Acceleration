# 8×8 Systolic Array Matrix Multiplication Accelerator

A synthesizable, FPGA-ready 8×8 systolic array in SystemVerilog that accelerates
matrix multiplication at a target 100 MHz. Designed as a Tiny-Tapeout friendly
portfolio project.

## Dataflow

The per-PE recurrence is `acc += A_in * B_in`, and each PE has its own
accumulator (output-stationary at the tile level). For a single 8×8 tile
the control flow is:

| Edge  | Direction          | Skew                                  |
|-------|--------------------|---------------------------------------|
| West  | A flows left→right | row *r* delayed by *r* cycles         |
| North | B flows top→down   | column *c* delayed by *c* cycles      |

During `COMPUTE`, column *k* of A and row *k* of B are streamed in together
(one per cycle, k = 0..7). After the skew networks, PE *(i, j)* sees the
aligned pair `A[i][k]` and `B[k][j]` at cycle `t_0 + i + j + k`, so it
accumulates the full dot product `Σ_k A[i][k] · B[k][j] = C[i][j]`.

> Note on terminology: the original spec calls this "weight-stationary".
> The PE here accumulates per-PE (spec-compliant), and B is latched into a
> register in the PE each cycle — during `COMPUTE` the value at each PE
> changes with the stream, which is the dataflow that actually yields a
> correct 8×8 matmul with per-PE accumulators. The `LOAD_SKEW` phase still
> exists to clear accumulators and prime the skew pipelines.

## Modules

| File                       | Role                                        |
|----------------------------|---------------------------------------------|
| `rtl/pe.sv`                | Single MAC unit with per-PE accumulator     |
| `rtl/skew_injector.sv`     | N-stream programmable-depth shift register  |
| `rtl/systolic_array.sv`    | 8×8 grid of PEs                             |
| `rtl/controller_fsm.sv`    | IDLE → LOAD_SKEW → COMPUTE → DRAIN → STORE  |
| `rtl/bram_controller.sv`   | Inferred dual-port BRAM                     |
| `rtl/ping_pong_buffer.sv`  | Double-buffered BRAM pair                   |
| `rtl/tiling_controller.sv` | M×N×K tile scheduler                        |
| `rtl/accelerator_top.sv`   | FSM + skew + array glue                     |
| `tb/tb_systolic_array.sv`  | Self-checking testbench                     |

## Precision

Compile-time parameters `DATA_WIDTH` and `ACC_WIDTH` select precision:

- **INT8** (default): `DATA_WIDTH=8`, `ACC_WIDTH=32`
- **INT16**: `DATA_WIDTH=16`, `ACC_WIDTH=48`

All PE and bus widths scale automatically.

## Throughput

| Metric                         | Value            |
|--------------------------------|------------------|
| Single-tile latency            | ~31 cycles       |
| Steady-state (ping-pong)       | ~8 cycles/tile   |
| MACs / tile                    | 512              |
| Throughput @ 100 MHz           | ~6.4 GMAC/s      |

## Simulation

```sh
cd sim
make             # runs with Icarus Verilog (-g2012)
make verilator   # alternative path via Verilator
```

Expected output ends with `ALL 103 TESTS PASSED`.

## Directory

```
systolic_array/
├── rtl/
│   ├── pe.sv
│   ├── skew_injector.sv
│   ├── systolic_array.sv
│   ├── bram_controller.sv
│   ├── ping_pong_buffer.sv
│   ├── controller_fsm.sv
│   ├── tiling_controller.sv
│   └── accelerator_top.sv
├── tb/
│   └── tb_systolic_array.sv
├── sim/
│   └── Makefile
├── synth/
│   └── constraints.xdc
└── README.md
```
