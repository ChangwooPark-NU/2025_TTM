import numpy as np, struct

# ---- READ RTL HEX FILE ----
with open("yout.txt") as f:
    hex_vals = [line.strip() for line in f if line.strip()]

# ---- CONVERT RTL HEX → FP32 ----
rtl_fp = np.array(
    [struct.unpack("!f", bytes.fromhex(h.zfill(8)))[0] for h in hex_vals],
    np.float32
)

# ---- LOAD GOLDEN FP32 ----
ref_fp = np.load("softmax_fp32_Bh4x4.npy").astype(np.float32).flatten()[:16]

# ---- CONVERT GOLDEN FP32 → HEX ----
def fp32_to_hex(x):
    return struct.pack("!f", np.float32(x)).hex()

ref_hex = [fp32_to_hex(x) for x in ref_fp]

# ---- HEADER ----
print(f"{'RTL_HEX':>12}  {'RTL_FP32':>12}    {'REF_HEX':>12}  {'REF_FP32':>12}")
print("="*60)

# ---- PRINT 16 ROWS ----
for i in range(16):
    rtl_hex = hex_vals[i].zfill(8)
    rtl_float = rtl_fp[i]
    golden_hex = ref_hex[i]
    golden_float = ref_fp[i]

    print(f"{rtl_hex:>12}  {rtl_float:12.7f}    {golden_hex:>12}  {golden_float:12.7f}")

# ---- TOLERANCE ----
tol = np.max(np.abs(rtl_fp[:16] - ref_fp[:16]))
print("\nMin tolerance (max |rtl - ref|):", f"{tol:.10f}")

