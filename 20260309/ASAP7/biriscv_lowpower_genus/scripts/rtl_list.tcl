# RTL file list for biRISC-V with all 5 multipliers
# biriscv_defs.v MUST be first (contains macro definitions)

set rtl_all [list \
    $rtldir/biriscv_defs.v \
    $rtldir/biriscv_alu.v \
    $rtldir/biriscv_csr.v \
    $rtldir/biriscv_csr_regfile.v \
    $rtldir/biriscv_decode.v \
    $rtldir/biriscv_decoder.v \
    $rtldir/biriscv_divider.v \
    $rtldir/biriscv_exec.v \
    $rtldir/biriscv_fetch.v \
    $rtldir/biriscv_frontend.v \
    $rtldir/biriscv_issue.v \
    $rtldir/biriscv_lsu.v \
    $rtldir/biriscv_mmu.v \
    $rtldir/biriscv_multiplier.v \
    $rtldir/biriscv_multiplier_efficient.v \
    $rtldir/biriscv_multiplier_s.v \
    $rtldir/biriscv_multiplier_pipelined.v \
    $rtldir/biriscv_npc.v \
    $rtldir/biriscv_pipe_ctrl.v \
    $rtldir/biriscv_regfile.v \
    $rtldir/biriscv_trace_sim.v \
    $rtldir/biriscv_xilinx_2r1w.v \
    $rtldir/column_bypass_multiplier.v \
    $rtldir/riscv_core.v \
]
