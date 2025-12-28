from pathlib import Path

import math
import torch


def export_inputs_to_mem(
    dataset: torch.utils.data.Dataset,
    num_images: int,
    log_dir: str,
    method: str = "concat",  # "concat", "single"
    m: int = 16,
    n: int = 16
):
    # first N samples
    x_list = []
    y_list = []
    for i in range(num_images):
        x, y = dataset[i]
        x_list.append(x)
        y_list.append(int(y) if torch.is_tensor(y) else y)

    if method == "concat":
        # nối N ảnh -> 1 vector dài N*784
        chunks = []
        for x in x_list:
            x = x if torch.is_tensor(x) else torch.as_tensor(x)
            x_flat = _flatten_784(x)
            x_q = float_to_qm_n(x_flat, m=m, n=n)
            chunks.append(x_q)

        x_concat = torch.cat(chunks, dim=0)  # [N*784]
        key = f"input_{num_images}_{m}_{n}"           # -> input_{k}_{m}_{n}.mem
        write_mem_tensor(x_concat, log_dir, key=key)

    else:  # mode == "single"
        for idx, x in enumerate(x_list, start=1):
            x = x if torch.is_tensor(x) else torch.as_tensor(x)
            x_flat = _flatten_784(x)
            x_q = float_to_qm_n(x_flat, m=m, n=n)
            write_mem_tensor(x_q, log_dir, key=f"single_{idx}")

    print(f"{num_images} labels: {y_list}")


def export_state_dict_to_mem(
    state_dict: dict,
    log_dir: str,
    m: int = 16,
    n: int = 16,
):
    for key, tensor in state_dict.items():
        if not isinstance(tensor, torch.Tensor):
            continue

        t_q = float_to_qm_n(tensor, m=m, n=n)
        write_mem_tensor(t_q, log_dir, key)


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
    x_flat = _flatten_784(x)
    # x = x.to(torch.float32)
    # if x.ndim == 3 and x.shape[0] == 1 and x.shape[1:] == (28, 28):
    #     # [1, 28, 28] -> [784]
    #     x_flat = x.reshape(-1)
    # elif x.ndim == 2 and x.shape == (28, 28):
    #     x_flat = x.reshape(-1)
    # elif x.ndim == 1 and x.numel() == 784:
    #     x_flat = x
    # else:
    #     raise ValueError(f"Input x có shape {tuple(x.shape)}")

    x_q = float_to_qm_n(x_flat, m=m, n=n)
    write_mem_tensor(x_q, log_dir, key="input")


@torch.no_grad()
def recommend_qmn_from_tensors(
    state_dict: dict,
    use_percentile=0.999,   # 0.999 (p99.9)
    radius=2,               # narrow sweep: 5 config
    clip_threshold=0.0,     # “no clip”
    n_min=0,
    n_max=30,
    verbose=True
):
    """
    Wrapper 1 phát:
    - stats
    - narrow candidates
    - sweep
    - trả best (m,n) + full results
    """
    stats_list = analyze_tensors_stats(state_dict, verbose=verbose)
    n0, A, cand = narrow_n_candidates_from_stats(
        stats_list,
        use_percentile=use_percentile,
        radius=radius,
        n_min=n_min,
        n_max=n_max
    )
    if verbose:
        print(f"\n[NARROW] use abs_p{use_percentile} global={A:.6g} -> anchor n0={n0} -> candidates={cand}")

    results = sweep_best_qmn(
        state_dict,
        n_candidates=cand,
        clip_threshold=clip_threshold,
        verbose=verbose
    )
    best = results[0]
    return best, results


@torch.no_grad()
def analyze_tensors_stats(state_dict: dict, keys=None, percentiles=(0.99, 0.999, 0.9999), verbose=True):
    """
    Mặc định phân tích đúng 4 tensor của bạn.
    """
    if keys is None:
        keys = ["fc1.weight", "fc1.bias", "fc2.weight", "fc2.bias"]

    stats_list = []
    for k in keys:
        if k not in state_dict:
            raise KeyError(f"Missing key in state_dict: {k}")
        stats_list.append(tensor_stats(state_dict[k], name=k, percentiles=percentiles))

    if verbose:
        for s in stats_list:
            print(f"\n[{s['name']}] shape={s['shape']}, numel={s['numel']}")
            print(f"  min/max      : {s['min']:.6g} / {s['max']:.6g}")
            print(f"  mean/std     : {s['mean']:.6g} / {s['std']:.6g}")
            print(f"  abs_max      : {s['abs_max']:.6g}")
            for p in percentiles:
                print(f"  abs_p{p}    : {s[f'abs_p{p}']:.6g}")

    return stats_list


def narrow_n_candidates_from_stats(stats_list, use_percentile=0.999, radius=2, n_min=0, n_max=30):
    """
    Dựa trên global max của abs_percentile để chọn n0, rồi sweep quanh n0.
    - use_percentile: 0.999 (p99.9) hoặc 0.9999 (p99.99)
    - radius=2 => thử ~5 cấu hình thay vì ~30
    """
    key = f"abs_p{use_percentile}"
    if key not in stats_list[0]:
        raise KeyError(f"Stats does not contain percentile key: {key}")

    # lấy mức "toàn cục" lớn nhất trong 4 tensor theo percentile đã chọn
    A = max(s[key] for s in stats_list)

    INT_MAX = (1 << 31) - 1  # vì m+n=32, signed int32
    eps = 1e-30
    if A < eps:
        n0 = 16
    else:
        n0 = int(math.floor(math.log2(INT_MAX / A)))

    # clamp n0 và tạo candidates
    n0 = max(n_min, min(n_max, n0))
    cand = list(range(max(n_min, n0 - radius), min(n_max, n0 + radius) + 1))

    return n0, A, cand


@torch.no_grad()
def sweep_best_qmn(
    state_dict: dict,
    keys=None,
    n_candidates=None,
    clip_threshold=0.0,
    verbose=True
):
    """
    Sweep trên danh sách n_candidates (đã được narrow).
    Error metric: RMSE + MAE global (weighted theo numel) + max_abs_err + clip_ratio global.
    Chọn best: ưu tiên clip_ratio <= clip_threshold, rồi RMSE nhỏ nhất.
    """
    if keys is None:
        keys = ["fc1.weight", "fc1.bias", "fc2.weight", "fc2.bias"]
    if n_candidates is None or len(n_candidates) == 0:
        raise ValueError("n_candidates is empty. Call narrow_n_candidates_from_stats first.")

    results = []
    for n in n_candidates:
        total = 0
        se_sum = 0.0
        ae_sum = 0.0
        clip_sum = 0.0
        max_abs_err = 0.0

        for k in keys:
            x = state_dict[k]
            x_hat, clip_r = _quant_dequant_with_clip(x, n=n)
            err = (x_hat - x.to(torch.float32))

            se_sum += float((err * err).sum().item())
            ae_sum += float(err.abs().sum().item())
            total += int(err.numel())
            clip_sum += clip_r * int(err.numel())
            max_abs_err = max(max_abs_err, float(err.abs().max().item()))

        rmse = math.sqrt(se_sum / max(total, 1))
        mae = ae_sum / max(total, 1)
        clip_ratio = clip_sum / max(total, 1)

        m = 32 - n
        results.append({
            "m": int(m),
            "n": int(n),
            "rmse": float(rmse),
            "mae": float(mae),
            "max_abs_err": float(max_abs_err),
            "clip_ratio": float(clip_ratio),
            "pass_clip": bool(clip_ratio <= clip_threshold),
        })

    # sort: pass_clip trước, rồi rmse nhỏ
    results.sort(key=lambda r: (not r["pass_clip"], r["rmse"], r["clip_ratio"]))

    if verbose:
        print("\n[SWEEP RESULTS] (sorted)")
        for r in results:
            print(f"  Q{r['m']}.{r['n']}  rmse={r['rmse']:.6g}  mae={r['mae']:.6g}  "
                  f"max|e|={r['max_abs_err']:.6g}  clip={r['clip_ratio']:.3g}  pass={r['pass_clip']}")

        best = results[0]
        print(f"\n[BEST] Q{best['m']}.{best['n']}  (rmse={best['rmse']:.6g}, clip={best['clip_ratio']:.3g})")

    return results


# quantize
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


# export mem
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


def _key_to_filename(key: str) -> str:
    """
    'fc1.weight' -> 'fc1_weight.mem'
    """
    return key.replace('.', '_') + ".mem"


# flatten input
def _flatten_784(x: torch.Tensor) -> torch.Tensor:
    x = x.to(torch.float32)
    if x.ndim == 3 and x.shape[0] == 1 and tuple(x.shape[1:]) == (28, 28):
        return x.reshape(-1)
    elif x.ndim == 2 and tuple(x.shape) == (28, 28):
        return x.reshape(-1)
    elif x.ndim == 1 and x.numel() == 784:
        return x
    else:
        raise ValueError(f"Input x có shape {tuple(x.shape)}")


# stats & sweep
@torch.no_grad()
def _quant_dequant_with_clip(x: torch.Tensor, n: int):
    """
    Quantize theo int32 signed (m+n=32), trả lại x_hat và clip_ratio.
    Lưu ý: m = 32 - n (không cần truyền m riêng).
    """
    x = x.to(torch.float32)
    scale = 1 << n

    q = torch.round(x * scale)
    INT_MIN = -(1 << 31)
    INT_MAX = (1 << 31) - 1

    clipped = (q < INT_MIN) | (q > INT_MAX)
    clip_ratio = float(clipped.to(torch.float32).mean().item())

    q = torch.clamp(q, INT_MIN, INT_MAX).to(torch.int32)
    x_hat = q.to(torch.float32) / scale
    return x_hat, clip_ratio


@torch.no_grad()
def tensor_stats(t: torch.Tensor, name: str, percentiles=(0.99, 0.999, 0.9999)):
    """
    Stats + percentile of |t|.
    """
    x = t.detach().to(torch.float32).flatten()
    ax = x.abs()

    out = {
        "name": name,
        "shape": tuple(t.shape),
        "numel": int(x.numel()),
        "min": float(x.min().item()),
        "max": float(x.max().item()),
        "mean": float(x.mean().item()),
        "std": float(x.std(unbiased=False).item()),
        "abs_max": float(ax.max().item()),
    }
    for p in percentiles:
        out[f"abs_p{p}"] = float(torch.quantile(ax, torch.tensor(p, device=ax.device)).item())
    return out
