import re
import sys
from collections import Counter, defaultdict

if len(sys.argv) != 2:
    print("Usage: python3 mul_centric_analysis.py <kernel_log>")
    sys.exit(1)

LOG = sys.argv[1]

insn_re = re.compile(r"core\s+\d+:\s+(0x[0-9a-fA-F]+)\s+\(0x[0-9a-fA-F]+\)\s+(.*)$")

abi_to_x = {
    "zero":"x0","ra":"x1","sp":"x2","gp":"x3","tp":"x4",
    "t0":"x5","t1":"x6","t2":"x7",
    "s0":"x8","fp":"x8","s1":"x9",
    "a0":"x10","a1":"x11","a2":"x12","a3":"x13","a4":"x14","a5":"x15","a6":"x16","a7":"x17",
    "s2":"x18","s3":"x19","s4":"x20","s5":"x21","s6":"x22","s7":"x23","s8":"x24","s9":"x25","s10":"x26","s11":"x27",
    "t3":"x28","t4":"x29","t5":"x30","t6":"x31",
}

reg_tok = re.compile(r"\b(x(?:[12]?\d|3[01])|zero|ra|sp|gp|tp|t[0-6]|s(?:1[01]|[0-9])|fp|a[0-7])\b")

def norm(r: str) -> str:
    return r if r.startswith("x") else abi_to_x.get(r, r)

def split_tokens(disasm: str):
    return disasm.replace(",", " ").replace("(", " ").replace(")", " ").split()

def classify_op(op: str) -> str:
    if op in ("lw","lh","lb","lbu","lhu","ld","lwu","flw","fld","c.lw","c.ld","c.lwsp","c.ldsp","c.lwsp"):
        return "load"
    if op in ("sw","sh","sb","sd","fsw","fsd","c.sw","c.sd","c.swsp","c.sdsp"):
        return "store"
    if op in ("mul","mulh","mulhu","mulhsu","mulw"):
        return "mul"
    if op in ("add","addw","addi","addiw","c.add","c.addw","c.addi","c.addiw",
              "sub","subw","c.sub","c.subw"):
        return "add"
    if op in ("sll","slli","slliw","srl","srli","srliw","sra","srai","sraiw",
              "c.slli","c.srli","c.srai"):
        return "shift"
    if op.startswith("b") or op in ("beq","bne","blt","bge","bltu","bgeu",
                                    "c.beqz","c.bnez","jal","jalr","c.j","c.jal"):
        return "branch"
    return "other"

def guess_rd_reads(disasm: str):
    toks = split_tokens(disasm)
    if not toks:
        return None, [], "?", "other"
    op = toks[0]
    regs = [norm(r) for r in reg_tok.findall(disasm)]
    cls = classify_op(op)

    # no rd
    if cls in ("store", "branch"):
        return None, regs, op, cls

    if op in ("jal", "c.jal"):
        rd = regs[0] if regs else None
        return rd, [], op, "branch"

    if op == "jalr":
        rd = regs[0] if len(regs) >= 1 else None
        reads = regs[1:2] if len(regs) >= 2 else []
        return rd, reads, op, "branch"

    rd = regs[0] if regs else None
    reads = regs[1:] if len(regs) > 1 else []
    # Compressed R-type (c.add, c.addw, c.sub, c.subw, c.and, c.or, c.xor)
    # and addw/subw have rd as both source and destination
    if op in ("c.add","c.addw","c.sub","c.subw","c.and","c.or","c.xor",
             "add","addw","sub","subw","mul","mulw","mulh","mulhu","mulhsu",
             "sll","srl","sra","and","or","xor","slt","sltu"):
        pass  # rd != implicit source for R-type; reads already correct
    if op in ("c.add","c.addw","c.sub","c.subw","c.and","c.or","c.xor"):
        # compressed format: rd/rs1 is both dest and source
        if rd and rd not in reads:
            reads = [rd] + reads
    return rd, reads, op, cls


def stats(arr):
    if not arr:
        return {"n": 0}
    a = sorted(arr)
    n = len(a)
    return {
        "n": n,
        "avg": sum(a) / n,
        "p50": a[int(0.50 * (n - 1))],
        "p90": a[int(0.90 * (n - 1))],
        "max": a[-1],
    }


# --------------------------------------------------
# load kernel trace
# --------------------------------------------------
pcs = []
ops = []
classes = []
rd_list = []
reads_list = []

with open(LOG, errors="ignore") as f:
    for line in f:
        m = insn_re.match(line)
        if not m:
            continue
        pc = int(m.group(1), 16)
        dis = m.group(2)
        rd, reads, op, cls = guess_rd_reads(dis)
        pcs.append(pc)
        ops.append(op)
        classes.append(cls)
        rd_list.append(rd)
        reads_list.append(reads)

N = len(ops)

print(f"Kernel trace loaded: {LOG}")
print(f"Dynamic instructions: {N}")

# --------------------------------------------------
# build producer/consumer graph
# --------------------------------------------------
producer_of_read = defaultdict(list)   # consumer idx -> list of (producer idx, reg)
consumers_of_inst = defaultdict(list)  # producer idx -> list of (consumer idx, reg)

last_writer = {}

for i in range(N):
    for r in reads_list[i]:
        if r in last_writer:
            p = last_writer[r]
            producer_of_read[i].append((p, r))
            consumers_of_inst[p].append((i, r))
    rd = rd_list[i]
    if rd:
        last_writer[rd] = i

# --------------------------------------------------
# 1) nearest producer -> mul
# --------------------------------------------------
nearest_prod_dist = []
nearest_prod_type = Counter()

# --------------------------------------------------
# 2) mul -> nearest consumer
# --------------------------------------------------
nearest_cons_dist = []
nearest_cons_type = Counter()

# --------------------------------------------------
# 3) full chain from mul to final arithmetic consumer
# --------------------------------------------------
chain_lengths = []
final_cons_types = Counter()

arith_like = {"add", "shift", "other"}   # we will track arithmetic-ish downstream steps
# note: "other" is included because some meaningful ops may fall there
MAX_CHAIN = 64  # cap to prevent loop-carried recurrence inflation

mul_indices = [i for i, c in enumerate(classes) if c == "mul"]

for m in mul_indices:
    # nearest producer feeding this mul
    preds = producer_of_read.get(m, [])
    if preds:
        best_p = max(preds, key=lambda x: x[0])   # closest previous producer
        p_idx, reg = best_p
        nearest_prod_dist.append(m - p_idx)
        nearest_prod_type[classes[p_idx]] += 1

    # nearest consumer of this mul result
    cons = consumers_of_inst.get(m, [])
    if cons:
        best_c = min(cons, key=lambda x: x[0])    # closest next consumer
        c_idx, reg = best_c
        nearest_cons_dist.append(c_idx - m)
        nearest_cons_type[classes[c_idx]] += 1

    # full chain length:
    # follow the closest dependent consumer repeatedly
    # until no more consumer exists, or chain stops being arithmetic-related
    cur = m
    steps = 0
    last_type = None
    visited = set([m])

    while True:
        cons_cur = consumers_of_inst.get(cur, [])
        if not cons_cur:
            break

        next_c, reg = min(cons_cur, key=lambda x: x[0])
        if next_c in visited:
            break

        visited.add(next_c)
        ctype = classes[next_c]
        last_type = ctype

        # count only meaningful arithmetic-like dependent hops
        if ctype in ("add", "shift", "other"):
            steps += 1
            cur = next_c
            if steps >= MAX_CHAIN:
                break
        else:
            break

    if steps > 0:
        chain_lengths.append(steps)
        # Record the type that terminated the chain (store/branch/load/mul)
        # or the last arithmetic type if chain ended due to no consumers/cap
        final_cons_types[last_type] += 1

print("\n=== MUL-CENTRIC RESULTS ===")
print("Total mul instructions:", len(mul_indices))

print("\nNearest producer -> mul distance stats:")
print(stats(nearest_prod_dist))
print("Nearest producer types:", nearest_prod_type.most_common(10))

print("\nMul -> nearest consumer distance stats:")
print(stats(nearest_cons_dist))
print("Nearest consumer types:", nearest_cons_type.most_common(10))

print("\n=== MUL FULL CHAIN RESULTS ===")
print("Total mul analyzed:", len(chain_lengths))
print("Chain length stats:", stats(chain_lengths))
print("Final consumer types:", final_cons_types.most_common(10))
