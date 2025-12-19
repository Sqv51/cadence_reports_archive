################################################################################
#
# Genus(TM) Synthesis Solution setup file
# Created by Genus(TM) Synthesis Solution 23.13-s073_1
#   on 12/18/2025 18:57:37
#
# This file can only be run in Genus Common UI mode.
#
################################################################################


# This script is intended for use with Genus(TM) Synthesis Solution version 23.13-s073_1


# Remove Existing Design
################################################################################
if {[::legacy::find -design design:riscv_core] ne ""} {
  puts "** A design with the same name is already loaded. It will be removed. **"
  delete_obj design:riscv_core
}


# To allow user-readonly attributes
################################################################################
::legacy::set_attribute -quiet force_tui_is_remote 1 /

phys::read_script syn_handoff/riscv_core.root.g


# Libraries
################################################################################
::legacy::set_attribute library {/home/ziyx/cadence-bitirme/Flows/ASAP7/biriscv/scripts/cadence/../../../../../Enablements/ASAP7/lib/sram_asap7_64x256_1rw.lib /home/ziyx/cadence-bitirme/Flows/ASAP7/biriscv/scripts/cadence/../../../../../Enablements/ASAP7/lib/asap7sc7p5t_OA_RVT_FF_nldm_201020.lib /home/ziyx/cadence-bitirme/Flows/ASAP7/biriscv/scripts/cadence/../../../../../Enablements/ASAP7/lib/asap7sc7p5t_SEQ_RVT_FF_nldm_201020.lib /home/ziyx/cadence-bitirme/Flows/ASAP7/biriscv/scripts/cadence/../../../../../Enablements/ASAP7/lib/sram_asap7_16x256_1rw.lib /home/ziyx/cadence-bitirme/Flows/ASAP7/biriscv/scripts/cadence/../../../../../Enablements/ASAP7/lib/sram_asap7_64x64_1rw.lib /home/ziyx/cadence-bitirme/Flows/ASAP7/biriscv/scripts/cadence/../../../../../Enablements/ASAP7/lib/asap7sc7p5t_AO_RVT_FF_nldm_201020.lib /home/ziyx/cadence-bitirme/Flows/ASAP7/biriscv/scripts/cadence/../../../../../Enablements/ASAP7/lib/asap7sc7p5t_INVBUF_RVT_FF_nldm_201020.lib /home/ziyx/cadence-bitirme/Flows/ASAP7/biriscv/scripts/cadence/../../../../../Enablements/ASAP7/lib/asap7sc7p5t_SIMPLE_RVT_FF_nldm_201020.lib /home/ziyx/cadence-bitirme/Flows/ASAP7/biriscv/scripts/cadence/../../../../../Enablements/ASAP7/lib/sram_asap7_32x256_1rw.lib} /


# Design
################################################################################
read_netlist -top riscv_core syn_handoff/riscv_core.v
read_metric -id current syn_handoff/riscv_core.metrics.json

phys::read_script syn_handoff/riscv_core.g

phys::read_lec_taf syn_handoff/riscv_core.lec.taf.gz
phys::read_taf syn_handoff/riscv_core.safety.taf.gz
puts "\n** Restoration Completed **\n"


# Data Integrity Check
################################################################################
# program version
if {"[string_representation [::legacy::get_attribute program_version /]]" != "23.13-s073_1"} {
   mesg_send [::legacy::find -message /messages/PHYS/PHYS-91] "golden program_version: 23.13-s073_1  current program_version: [string_representation [::legacy::get_attribute program_version /]]"
}
# license
if {"[string_representation [::legacy::get_attribute startup_license /]]" != "Genus_Synthesis"} {
   mesg_send [::legacy::find -message /messages/PHYS/PHYS-91] "golden license: Genus_Synthesis  current license: [string_representation [::legacy::get_attribute startup_license /]]"
}
# slack
set _slk_ [::legacy::get_attribute slack design:riscv_core]
if {[regexp {^-?[0-9.]+$} $_slk_]} {
  set _slk_ [format %.1f $_slk_]
}
if {$_slk_ != "0.0"} {
   mesg_send [::legacy::find -message /messages/PHYS/PHYS-92] "golden slack: 0.0,  current slack: $_slk_"
}
unset _slk_
# multi-mode slack
# tns
set _tns_ [::legacy::get_attribute tns design:riscv_core]
if {[regexp {^-?[0-9.]+$} $_tns_]} {
  set _tns_ [format %.0f $_tns_]
}
if {$_tns_ != "0"} {
   mesg_send [::legacy::find -message /messages/PHYS/PHYS-92] "golden tns: 0,  current tns: $_tns_"
}
unset _tns_
# cell area
set _cell_area_ [::legacy::get_attribute cell_area design:riscv_core]
if {[regexp {^-?[0-9.]+$} $_cell_area_]} {
  set _cell_area_ [format %.0f $_cell_area_]
}
if {$_cell_area_ != "6348"} {
   mesg_send [::legacy::find -message /messages/PHYS/PHYS-92] "golden cell area: 6348,  current cell area: $_cell_area_"
}
unset _cell_area_
# net area
set _net_area_ [::legacy::get_attribute net_area design:riscv_core]
if {[regexp {^-?[0-9.]+$} $_net_area_]} {
  set _net_area_ [format %.0f $_net_area_]
}
if {$_net_area_ != "0"} {
   mesg_send [::legacy::find -message /messages/PHYS/PHYS-92] "golden net area: 0,  current net area: $_net_area_"
}
unset _net_area_
