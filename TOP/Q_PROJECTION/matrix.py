import numpy as np
import struct

hex_path = "OV_fp32_B1T4C128.hex"  # <-- change to your filename

# 1) Read hex lines
with open(hex_path) as f:
    hex_lines = [line.strip() for line in f if line.strip()]

if len(hex_lines) != 512:
    raise ValueError(f"Expected 512 lines, got {len(hex_lines)}")

# 2) Convert each 8-char hex word (big-endian FP32) to float
floats = []
for hx in hex_lines:
    if len(hx) != 8:
        raise ValueError(f"Bad hex word '{hx}' (len={len(hx)})")
    b = bytes.fromhex(hx)
    val = struct.unpack(">f", b)[0]
    floats.append(val)

arr = np.array(floats, dtype=np.float32).reshape(4, 128)

# 3) Print as 4×128 with NO scientific notation, NO truncation
np.set_printoptions(
    suppress=True,          # no scientific notation
    linewidth=200,          # wider lines so more fits per row
    threshold=np.inf,       # don't truncate the array
    formatter={"float_kind": lambda x: f"{x: .7f}"}  # fixed 7 decimals
)

print("Shape:", arr.shape)
print(arr)

