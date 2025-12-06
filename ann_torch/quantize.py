import os
from pathlib import Path
import torch

def float_to_qm_n(t: torch.Tensor, m: int = 24, n: int = 8) -> torch.Tensor:
    total_bits = m + n
    if total_bits > 32:
        raise ValueError(f"Q{m}.{n} có {total_bits} bit > 32, không vừa int32")

    scale = 1 << n
    scaled = torch.round(t * scale)   # float * 2^n

    int_min = - (1 << (total_bits - 1))
    int_max =   (1 << (total_bits - 1)) - 1
    scaled = torch.clamp(scaled, int_min, int_max)

    return scaled.to(torch.int32)


def qm_n_to_float(t_int: torch.Tensor, m: int = 24, n: int = 8) -> torch.Tensor:
    scale = 1 << n   # 2^n
    return t_int.to(torch.float32) / scale


def _key_to_filename(key: str) -> str:
    """
    'fc1.weight' -> 'fc1_weight.mem'
    """
    return key.replace('.', '_') + ".mem"


def write_mem_tensor(t_int: torch.Tensor, log_dir: str, key: str):
    """
    Ghi tensor int32 (1D hoặc 2D) ra file .mem trong thư mục log_dir,
    tên file dựa theo key trong state_dict.
    """
    log_path = Path(log_dir)
    log_path.mkdir(parents=True, exist_ok=True)

    filename = _key_to_filename(key)      # fc1.weight -> fc1_weight.mem
    fpath = log_path / filename

    t_cpu = t_int.cpu()

    if t_cpu.ndim == 1:
        with open(fpath, "w") as f:
            for v in t_cpu:
                v32 = int(v.item()) & 0xFFFFFFFF
                f.write(f"{v32:08x}\n")

    elif t_cpu.ndim == 2:
        rows, cols = t_cpu.shape
        with open(fpath, "w") as f:
            for i in range(rows):
                for j in range(cols):
                    v32 = int(t_cpu[i, j].item()) & 0xFFFFFFFF
                    f.write(f"{v32:08x}\n")
    else:
        raise ValueError(f"Chỉ hỗ trợ tensor 1D/2D, key={key}, shape={tuple(t_cpu.shape)}")

    print(f"Saved {key} -> {fpath}")


def export_state_dict_and_input_to_mem(
    state_dict: dict,
    x: torch.Tensor,          # [1,28,28] hoặc [28,28] hoặc [784]
    log_dir: str,
    m: int = 16,
    n: int = 16,
):
    # 1) Export tất cả tham số trong state_dict
    for key, tensor in state_dict.items():
        if not isinstance(tensor, torch.Tensor):
            continue

        t_q = float_to_qm_n(tensor, m=m, n=n)
        write_mem_tensor(t_q, log_dir, key)

    # 2) Export input 784-dim
    x = x.to(torch.float32)
    if x.ndim == 3 and x.shape[0] == 1 and x.shape[1:] == (28, 28):
        # [1, 28, 28] -> [784]
        x_flat = x.reshape(-1)
    elif x.ndim == 2 and x.shape == (28, 28):
        x_flat = x.reshape(-1)
    elif x.ndim == 1 and x.numel() == 784:
        x_flat = x
    else:
        raise ValueError(f"Input x có shape {tuple(x.shape)}")

    x_q = float_to_qm_n(x_flat, m=m, n=n)
    write_mem_tensor(x_q, log_dir, key="input")


