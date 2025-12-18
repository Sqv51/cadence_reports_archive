# RTL file list for biRISC-V
# Important: biriscv_defs.v must be read first (contains macro definitions)
# Note: dcache_core.v and icache.v temporarily commented - they have signal declaration order issues
# that need fixing. We'll synthesize the core logic first.

# Use list command to build the list with variable expansion
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
    $rtldir/biriscv_npc.v \
    $rtldir/biriscv_pipe_ctrl.v \
    $rtldir/biriscv_regfile.v \
    $rtldir/biriscv_trace_sim.v \
    $rtldir/biriscv_xilinx_2r1w.v \
    $rtldir/column_bypass_multiplier.v \
    $rtldir/dcache.v \
    $rtldir/dcache_axi.v \
    $rtldir/dcache_axi_axi.v \
    $rtldir/dcache_mux.v \
    $rtldir/dcache_pmem_mux.v \
    $rtldir/dport_axi.v \
    $rtldir/dport_mux.v \
    $rtldir/icache.v \
    $rtldir/icache_data_ram.v \
    $rtldir/icache_tag_ram.v \
    $rtldir/riscv_core.v \
    $rtldir/riscv_tcm_top.v \
    $rtldir/riscv_top.v \
    $rtldir/tcm_mem.v \
    $rtldir/tcm_mem_pmem.v \
    $rtldir/tcm_mem_ram.v \
]
