# Golden model. Read csv files generated from TB and compute result

import csv
import numpy as np
import struct 

def load_biases(path):
    vals = []
    with open(path) as f:
        for line in f:
            #print(line)
            s = line.strip()
            if not s:
                continue
            # parse hex, wrap to signed int32
            v = int(s, 16)
            v = np.int32(v)
            #print(v)
            vals.append(v)
    bias = np.array(vals, dtype=np.int32)
    assert bias.shape == (128,), f"Expected 128 bias values, got {bias.shape}"
    return bias

bias = load_biases("Wq_bias_int32.hex")

bias_k = load_biases("Wk_bias_int32.hex")

bias_v = load_biases("Wv_bias_int32.hex")

csv_path = "sram_dump_rows0_31.csv"

tiles = []  # each will be a 4x4 np.array(int8)

with open(csv_path, newline="") as f:
    reader = csv.reader(f)
    header = next(reader)  # skip header: row,tile,c0,word_hex,byte0..byte15

    for row in reader:
        if not row:
            continue

        # columns: [0]=row, [1]=tile, [2]=c0, [3]=word_hex, [4..19]=byte0..byte15
        byte_vals = [int(v) for v in row[4:20]]  # already signed ints in CSV

        if len(byte_vals) != 16:
            raise ValueError(f"Expected 16 bytes, got {len(byte_vals)} in row: {row}")

        tile = np.array(byte_vals, dtype=np.int8).reshape(4, 4)
        tiles.append(tile)

tiles = np.stack(tiles, axis=0)  # shape: (num_tiles, 4, 4)

# 32 tiles horizontally → 4 x (32*4) = 4 x 128 matrix
full_matrix = np.hstack(tiles)

csv_path = "wq_dump_rows0_1023.csv"

TILES_R = 32   # tile rows
TILES_C = 32   # tile cols
TILE_H  = 4
TILE_W  = 4

H = TILES_R * TILE_H   # 128
W = TILES_C * TILE_W   # 128

# Full 128x128 matrix of int8
Wq = np.zeros((H, W), dtype=np.int8)

with open(csv_path, newline="") as f:
    reader = csv.DictReader(f)  # header: row,tr,tc,word_hex,byte0..byte15
    for r in reader:
        tr = int(r["tr"])   # tile row index (0..31)
        tc = int(r["tc"])   # tile col index (0..31)

        # 16 bytes per tile (already signed decimals in the CSV)
        bytes16 = [int(r[f"byte{i}"]) for i in range(16)]
        tile = np.array(bytes16, dtype=np.int8).reshape(TILE_H, TILE_W)

        # Drop the tile into the big 128x128 matrix
        row_start = tr * TILE_H
        col_start = tc * TILE_W
        Wq[row_start:row_start + TILE_H,
           col_start:col_start + TILE_W] = tile

np.set_printoptions(linewidth=10_000)

# q: 4x128 int8
# Wq: 128x128 int8
Q = full_matrix.astype(np.int32)
W = Wq.astype(np.int32)
# 1) Compute matrix multiply: 4x128 @ 128x128 -> 4x128
OUT = Q @ W + bias   # shape (4, 128), dtype int32
gold_q = np.load("Q_out_int32_B1T4C128.npy")
gold_k = np.load("K_out_int32_B1T4C128.npy")
#print(OUT)
#print(gold)
gold_q = gold_q.reshape(4,128)
gold_k = gold_k.reshape(4,128)

# ---- Multi-head slicing ----
# We split the 128-dimensional vector into 4 heads → each head gets 32 dims
# Head h uses dims [h*32 : (h+1)*32]

HEADS = 4
D_PER_HEAD = 32

# Output: scores[h][q_row][k_row] = scalar
scores = np.zeros((HEADS, 4, 4), dtype=np.float32)
h = 0 


def f32_to_hex(x):
    """Convert float32 → 8-char big-endian IEEE754 hex."""
    return ''.join(f"{b:02x}" for b in struct.pack(">f", float(x)))

# Load your tensors
# gold_q  : shape (4,128) int16 or int32 values representing q14
# gold_k  : shape (4,128)
# scores_m: fp32 reference

scale_q14 = 1.0 / (2**14)
h = 0
print("\n==========================")
print(f"========= HEAD {h} =========")
print("==========================\n")

d0 = h * D_PER_HEAD
d1 = (h + 1) * D_PER_HEAD

# ---- Slice per-head matrices ----
Qh = gold_q[:, d0:d1].astype(np.float32) * scale_q14   # (4×32)
Kh = gold_k[:, d0:d1].astype(np.float32) * scale_q14   # (4×32)

# ---- Compute score ----
score = Qh @ Kh.T                         # (4×4)
scaled = score / np.sqrt(32.0)

# ---------------------------
# PRINT Qh / Kh (decimal + hex)
# ---------------------------
print("Qh (decimal):")
print(Qh)

print("\nQh (hex fp32):")
Qh_hex = np.vectorize(f32_to_hex)(Qh)
for row in Qh_hex:
    print(" ".join(row))

print("\nKh (decimal):")
print(Kh)

print("\nKh (hex fp32):")
Kh_hex = np.vectorize(f32_to_hex)(Kh)
for row in Kh_hex:
    print(" ".join(row))

# ---------------------------
# PRINT SCORE
# ---------------------------
print("\nScore (decimal, unscaled):")
print(score)

print("\nScore (decimal, scaled = score / sqrt(32)):")
print(scaled)

print("\nScore (hex fp32, unscaled):")
score_hex = np.vectorize(f32_to_hex)(score)
for row in score_hex:
    print(" ".join(row))

print("\nScore (hex fp32, scaled):")
scaled_hex = np.vectorize(f32_to_hex)(scaled)
for row in scaled_hex:
    print(" ".join(row))


diff = OUT.astype(np.int64) - gold_q.astype(np.int64)
print("max |diff| =", np.max(np.abs(diff)))

# 2) Tile OUT into 32 tiles of shape 4x4 (along columns)
tiles = []
num_tiles = 32
tile_w = 4

for t in range(num_tiles):
    c0 = t * tile_w
    c1 = c0 + tile_w
    tile = OUT[:, c0:c1]          # shape (4,4)
    tiles.append(tile)

tiles = np.array(tiles)          # shape (32, 4, 4)

# 3) Write tiles to file: one tile per line, 16 values, signed decimal
out_path = "golden_out_tiles.txt"

with open(out_path, "w") as f:
    for tile in tiles:
        flat = tile.reshape(-1)   # 16 ints
        line = "".join(f"{v:11d}" for v in flat)
        f.write(line + "\n")

#print("DONE: Wrote golden reference result to golden_out_tiles.txt")


# frac_out from your quantized layer (Q14)
frac_out = 14
scale = 2.0 ** (-frac_out)   # = 1 / 16384

out_path = "golden_out_tiles_fp32.txt"

with open(out_path, "w") as f:
    for tile in tiles:
        flat_int = tile.reshape(-1).astype(np.int32)  # 16 int32 values
        flat_fp  = flat_int.astype(np.float32) * scale  # convert to float32

        # format: same spacing as before but with float instead of int
        line = "".join(f"{v:11.7f}\n" for v in flat_fp)
        f.write(line)
#print("DONE: Wrote FP32 golden output to", out_path)

csv_path = "output.csv"          # <- your CSV
out_path = "fp32.txt"   # <- output text file

floats = []

with open(csv_path, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        # get 16 signed bytes and convert to 0..255
        raw_bytes = []
        for i in range(16):
            b = int(row[f"byte{i}"])
            if b < 0:
                b += 256
            raw_bytes.append(b)

        # 4 FP32 values per row (bytes 0–3, 4–7, 8–11, 12–15)
        for j in range(15, 0, -4):
            chunk = bytes(raw_bytes[j-3:j+1])
            # big-endian float32
            val = struct.unpack('>f', chunk)[0]
            floats.append(val)

# write as plain text, one float per line (whitespace-separated)
with open(out_path, "w") as f:
    for v in floats:
        f.write(f"{v:11.7f}\n")   # scientific notation; use {v} if you want raw repr


Q32 = full_matrix.astype(np.int32)
W32 = Wq.astype(np.int32)


acc = np.zeros((4, 4), dtype=np.int64)   # bigger dtype to be safe
partials = []

for t in range(32):
    k0 = 4 * t
    k1 = k0 + 4

    Q_block = Q32[:, k0:k1]        # 4 x 4
    W_block = W32[k0:k1, 0:4]      # 4 x 4

    step = Q_block @ W_block       # 4 x 4, int32
    acc = acc + step               # accumulate

    partials.append(acc.copy())


# ---- 3) Pack each 4x4 partial tile into a 512-bit hex word ----
#  - row-major order
#  - each element → signed 32-bit two's complement
#  - LSB (rightmost 8 hex digits) = top-left element (acc[0,0])

def pack_tile_512hex(tile):
    """
    tile: 4x4 array of signed ints
    Returns: string like "512'h<128 hex digits>",
    where tile[0,0] is the least-significant 32-bit word (LSB).
    """
    flat = tile.reshape(-1).astype(np.int64)   # 16 elements, row-major

    # Convert each element to 32-bit unsigned (two's complement)
    words = [(int(v) & 0xFFFFFFFF) for v in flat]   # index 0 = tile[0,0]

    # Make 8-hex-digit chunks
    hex_words = [f"{w:08X}" for w in words]

    # For 512'h big-endian literal: MSB on the left, LSB on the right.
    packed = "512'h" + "".join(reversed(hex_words))

    return packed

for t, tile in enumerate(partials):
    packed = pack_tile_512hex(tile)


import os
import numpy as np



def load_int8_hex(path, expected_len=None, shape=None):
    vals = []
    with open(path, "r") as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            v = int(s, 16)          # 0..255
            if v & 0x80:            # sign bit for 8-bit
                v -= 0x100          # convert to signed
            vals.append(v)
    arr = np.array(vals, dtype=np.int8)
    if expected_len is not None:
        assert arr.size == expected_len, f"{path}: expected {expected_len}, got {arr.size}"
    if shape is not None:
        arr = arr.reshape(shape)
    return arr


def load_int32_hex(path, expected_len=None, shape=None):
    vals = []
    with open(path, "r") as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            v = int(s, 16)              # 0..0xFFFFFFFF
            if v & 0x80000000:          # sign bit for 32-bit
                v -= 0x100000000        # convert to signed
            vals.append(v)
    arr = np.array(vals, dtype=np.int32)
    if expected_len is not None:
        assert arr.size == expected_len, f"{path}: expected {expected_len}, got {arr.size}"
    if shape is not None:
        arr = arr.reshape(shape)
    return arr


# ---------- 1) Load quantized int8 input (B1T4C128) -> reshape to (4,128) ----------
x_path = "input_q_int8_B1T4C128.hex"
X_int8 = load_int8_hex(x_path, expected_len=4 * 128, shape=(4, 128))
#print("X_int8 shape:", X_int8.shape, "min/max:", X_int8.min(), X_int8.max())


# ---------- 2) Load int8 weights (128x128, row-major: [out, in]) ----------
w_path = "Wq_weight_int8.hex"
W_int8 = load_int8_hex(w_path, expected_len=128 * 128, shape=(128, 128))
#print("W_int8 shape:", W_int8.shape, "min/max:", W_int8.min(), W_int8.max())
wk_path = "Wk_weight_int8.hex"
Wk_int8 = load_int8_hex(wk_path, expected_len=128 * 128, shape=(128, 128))

# ---------- 3) Load int32 bias (128) ----------
b_path = "Wq_bias_int32.hex"
b_int32 = load_int32_hex(b_path, expected_len=128, shape=(128,))
#print("b_int32 shape:", b_int32.shape, "min/max:", b_int32.min(), b_int32.max())
bk_path = "Wk_bias_int32.hex"
bk_int32 = load_int32_hex(b_path, expected_len=128, shape=(128,))

# ---------- 4) Compute Y = X_int8 @ W_int8.T + b_int32 ----------
X32 = X_int8.astype(np.int32)          # (4,128)
W32 = W_int8.astype(np.int32)         # (128,128)

# forward_int does: acc = x32 @ w32.t()
Y = X32 @ W32.T                       # (4,128)
Y = Y + b_int32                       # bias broadcast across rows
#print(OUT==Y)
WT = W32.T.astype(np.int8, copy=False)   # shape (128, 128)

# Flatten row-major so WT[row, col] maps to Verilog matrix_q[row][col]
flat = WT.reshape(-1)

with open("Q_weights.hex", "w") as f:
    for v in flat:
        f.write(f"{int(v) & 0xFF:02X}\n")   # one byte per line, 2 hex chars

#print("VERILOG")
#print(OUT)
#print("Q")
#print(Y)

# ---- read back and verify ----
vals = []
with open("Q_weights.hex", "r") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        vals.append(int(line, 16))

vt_flat_u8 = np.array(vals, dtype=np.uint8)
assert vt_flat_u8.size == WT.size

Vt = vt_flat_u8.view(np.int8).reshape(WT.shape)

#print("Vt == W32.T ?", np.array_equal(Vt, W))
#print(Vt)
#print(W)
