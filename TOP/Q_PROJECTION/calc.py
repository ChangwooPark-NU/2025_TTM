import struct
import numpy as np

hex_q = """bea3e800 bef42800 bf588000 bfc36400 bf816200 3f342c00 3fc8a400 befe3800
bf05bc00 bf1f1c00 3f997800 bf707c00 3f933c00 c009ef00 3f199400 3dd9a000
3e372000 bfe96a00 bf041800 3f280400 c0021300 bf178400 bea2b800 bf61a400
bee4c800 3dcf2000 3cd00000 3e65b000 3f8f1200 bf2f9000 bdde4000 bf106000"""

hex_k = """bf8e3a00 be8ba000 bfb32e00 be4b8000 be2c8000 bf6f5000 3c8a8000 3f335400
3f246000 3ed28800 be1d4000 3f24d800 be728000 3f082400 3ed20800 3f098000
bf6f5400 bf741c00 3d1fc000 3ed71800 bd7c4000 bd92a000 3f478000 be8a1000
bfd3b000 3e050000 bf3bc000 3fa99e00 bed60800 bea96000 3fb33e00 bf81ca00"""

def hex_fp32_list_to_array(s: str) -> np.ndarray:
    """Convert space/newline-separated big-endian fp32 hex words to np.float32 1D array."""
    words = s.split()
    floats = [struct.unpack(">f", bytes.fromhex(w))[0] for w in words]
    return np.array(floats, dtype=np.float32)

q = hex_fp32_list_to_array(hex_q)  # shape (32,)
k = hex_fp32_list_to_array(hex_k)  # shape (32,)

print("q shape:", q.shape)
print("k shape:", k.shape)

dot = float(np.dot(q, k))
print("dot (decimal):", dot)

# if you also want the result in fp32 hex:
def f32_to_hex(x: float) -> str:
    return ''.join(f"{b:02x}" for b in struct.pack(">f", np.float32(x)))

print("dot (fp32 hex):", f32_to_hex(dot))

