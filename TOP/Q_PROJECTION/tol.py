import numpy as np, struct

# ---- READ HEX FILE ----
with open("yout.txt") as f:
    hex_vals = [line.strip() for line in f if line.strip()]

# ---- CONVERT HEX → FLOAT32 ----
rtl = np.array(
    [struct.unpack("!f", bytes.fromhex(h.zfill(8)))[0] for h in hex_vals],
    np.float32
)

# ---- LOAD NUMPY GOLDEN ----
ref = np.load("softmax_fp32_Bh4x4.npy").astype(np.float32).flatten()[:16]

# ---- TOLERANCE ----
tol = np.max(np.abs(rtl - ref))
print(f"Min tolerance: {tol:.6f}")
