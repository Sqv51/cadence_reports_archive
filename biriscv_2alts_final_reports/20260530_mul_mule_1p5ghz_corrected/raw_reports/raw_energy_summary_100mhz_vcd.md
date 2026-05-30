# Multiplier Energy Summary

Clock period: 10 ns (100.000 MHz)

## Core Scope

| Name | Pass | Ops | Cycles | Total Power (mW) | Unit Power (mW) | Core Energy/Op (pJ) | Unit Energy/Op (pJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| mul | yes | 1024 | 12350 | 13.9049 | 2.2740 | 1677.0011 | 274.2568 |
| mule | yes | 1024 | 12350 | 13.5765 | 0.9766 | 1637.4007 | 117.7833 |
| mula | yes | 1024 | 12350 | 19.7907 | 1.5530 | 2386.8634 | 187.3003 |
| mulx | yes | 1024 | 12350 | 19.7932 | 0.7309 | 2387.1641 | 88.1505 |
| mulb | yes | 1024 | 12350 | 19.7939 | 0.9137 | 2387.2490 | 110.1972 |
| mulr | yes | 1024 | 12350 | 19.7939 | 2.3330 | 2387.2476 | 281.3726 |
| mulp | yes | 1024 | 12350 | 19.7914 | 0.9427 | 2386.9488 | 113.6948 |
| cbm | yes | 1024 | 27699 | 14.4501 | 0.5445 | 3908.7131 | 147.2862 |

## Standalone Units

> **Energy model (dual-issue stall-free):** E/op = P_unit × latency\_cycles × T\_clock.
> For `mule` (iterative, 5-cycle latency) the compiler schedules independent
> instructions in the second issue slot of the dual-issue biRISC-V core to
> cover the latency; no stall penalty is added beyond the 5 compute cycles.
> `other_slot_ops` = independent instructions that execute in parallel per multiply.

| Name | Pass | Ops | Latency (cyc) | Throughput (cyc) | Other-slot ops | Power (mW) | E/op latency-bound (pJ) | E/op throughput-bound (pJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| mul | yes | 1024 | 3 | 1 | 3 | 3.6839 | 110.5184 | 36.8395 |
| mule | yes | 1024 | 5 | 5 | 5 | 1.6744 | 83.7183 | 83.7183 |
| mula | yes | 1024 | 1 | 1 | 1 | 4.1419 | 41.4189 | 41.4189 |
| mulx | yes | 1024 | 1 | 1 | 1 | 0.4404 | 4.4040 | 4.4040 |
| mulb | yes | 1024 | 1 | 1 | 1 | 0.4175 | 4.1755 | 4.1755 |
| mulr | yes | 1024 | 1 | 1 | 1 | 1.4633 | 14.6331 | 14.6331 |
| mulp | yes | 1024 | 1 | 1 | 1 | 0.9091 | 9.0915 | 9.0915 |
| cbm | no | 1024 | 5 | 5 | 5 | NA | NA | NA |

