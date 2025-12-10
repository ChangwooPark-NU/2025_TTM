import os
import numpy as np

BASE = "/vlsi/users/wmcgarry/ttm_model_outputs"


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


def main():
    # ---------- 1) Load quantized int8 input (B1T4C128) -> reshape to (4,128) ----------
    x_path = os.path.join(BASE, "input_q_int8_B1T4C128.hex")
    X_int8 = load_int8_hex(x_path, expected_len=4 * 128, shape=(4, 128))
    print("X_int8 shape:", X_int8.shape, "min/max:", X_int8.min(), X_int8.max())

    # ---------- 2) Load int8 weights (128x128, row-major: [out, in]) ----------
    w_path = os.path.join(BASE, "Wv_weight_int8.hex")
    W_int8 = load_int8_hex(w_path, expected_len=128 * 128, shape=(128, 128))
    print("W_int8 shape:", W_int8.shape, "min/max:", W_int8.min(), W_int8.max())

    # ---------- 3) Load int32 bias (128) ----------
    b_path = os.path.join(BASE, "Wv_bias_int32.hex")
    b_int32 = load_int32_hex(b_path, expected_len=128, shape=(128,))
    print("b_int32 shape:", b_int32.shape, "min/max:", b_int32.min(), b_int32.max())

    # ---------- 4) Compute Y = X_int8 @ W_int8.T + b_int32 ----------
    X32 = X_int8.astype(np.int32)          # (4,128)
    W32 = W_int8.astype(np.int32)         # (128,128)

    # forward_int does: acc = x32 @ w32.t()
    Y = X32 @ W32.T                       # (4,128)
    Y = Y + b_int32                       # bias broadcast across rows

    print("Y shape:", Y.shape)

    # ---------- 5) Load reference Q_out_int32_B1T4C128.npy ----------
    qref_path = os.path.join(BASE, "V_out_int32_B1T4C128.npy")
    Q_ref = np.load(qref_path)
    print("Q_ref raw shape:", Q_ref.shape, "dtype:", Q_ref.dtype)

    # Expect shape [1,4,128]; reshape to (4,128)
    if Q_ref.ndim == 3:
        Q_ref = Q_ref.reshape(-1, Q_ref.shape[-1])  # (4,128)
    elif Q_ref.ndim == 2:
        pass
    else:
        raise RuntimeError(f"Unexpected Q_ref shape {Q_ref.shape}")

    print("Q_ref reshaped shape:", Q_ref.shape)

    # ---------- 6) Compare ----------
    diff = Y - Q_ref
    max_abs_err = np.max(np.abs(diff))
    print("Max abs diff:", max_abs_err)
    print(Y)
    frac_out = 14
    scale = 2.0 ** (-frac_out)   # 1 / 16384

    Y_fp = Y.astype(np.float32) * scale

    for row in Y_fp:
        print(" ".join(f"{v:11.7f}" for v in row))
    if np.array_equal(Y, Q_ref):
        print("✅ EXACT MATCH: integer matmul + bias reproduces Q_out.")
    else:
        print("❌ NOT EXACT. Check some differences below:")
        print("First row Y[0,:8]:     ", Y[0, :8])
        print("First row Q_ref[0,:8]:", Q_ref[0, :8])
        print("First row diff[0,:8]: ", diff[0, :8])

if __name__ == "__main__":
    main()

