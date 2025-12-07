# Golden model. Read csv files generated from TB and compute result

import csv
import numpy as np
import struct 

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
OUT = Q @ W   # shape (4, 128), dtype int32

# 2) Tile OUT into 32 tiles of shape 4x4 (along columns)
tiles = []
num_tiles = 32
tile_w = 4

for t in range(num_tiles):
    c0 = t * tile_w
    c1 = c0 + tile_w
    tile = OUT[:, c0:c1]          # shape (4,4)
    tiles.append(tile-1)

tiles = np.array(tiles)          # shape (32, 4, 4)

# 3) Write tiles to file: one tile per line, 16 values, signed decimal
out_path = "golden_out_tiles.txt"

with open(out_path, "w") as f:
    for tile in tiles:
        flat = tile.reshape(-1)   # 16 ints
        line = "".join(f"{v:11d}" for v in flat)
        f.write(line + "\n")

print("DONE: Wrote golden reference result to golden_out_tiles.txt")


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
print("DONE: Wrote FP32 golden output to", out_path)

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

OUT = Q32 @ W32   # shape (4,128), dtype=int32

OUT_topleft = OUT[:, 0:4].copy()

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

