import torch
import torch.nn.functional as F


class BaseThresholdTransform:
    """
    Input:  img_tensor [C, H, W], range [0, 1]
    Output: tensor [C, H, W], thường là 0/1 (float)
    """
    def __call__(self, img_tensor: torch.Tensor) -> torch.Tensor:
        raise NotImplementedError


class FixedThreshold(BaseThresholdTransform):
    def __init__(self, threshold=0.5):
        self.threshold = threshold

    def __call__(self, img_tensor):
        # Input: [C, H, W] range [0, 1]
        return (img_tensor > self.threshold).float()


class OtsuThreshold(BaseThresholdTransform):
    def __init__(self, bins=256):
        self.bins = bins

    def __call__(self, img_tensor):
        img_int = (img_tensor * 255).long() # [0, 255] for histogram

        img_flat = img_int.view(-1).float()

        # Histogram (normalized)
        hist = torch.histc(img_flat, bins=self.bins, min=0, max=255)
        hist = hist / (hist.sum() + 1e-6)

        # Vectorized Otsu
        arange = torch.arange(self.bins, device=img_tensor.device)
        omega = torch.cumsum(hist, dim=0)
        mu = torch.cumsum(hist * arange, dim=0)

        mu_t = mu[-1]
        eps = 1e-6
        sigma_b_squared = (mu_t * omega - mu) ** 2 / (omega * (1 - omega) + eps)

        best_threshold_idx = torch.argmax(sigma_b_squared).item()
        final_threshold = best_threshold_idx / 255.0

        return (img_tensor > final_threshold).float()


class SauvolaThreshold(BaseThresholdTransform):
    def __init__(self, window_size=25, k=0.2, R=0.5):
        self.window_size = window_size
        self.k = k
        self.R = R
        self.padding = window_size // 2

    def __call__(self, img_tensor):
        x = img_tensor.unsqueeze(0)  # [1, 1, H, W]

        # Pad reflect
        x_padded = F.pad(
            x,
            (self.padding, self.padding, self.padding, self.padding),
            mode='reflect'
        )

        # Local mean
        mean = F.avg_pool2d(
            x_padded, kernel_size=self.window_size, stride=1, padding=0
        )

        # Local mean of squares
        mean_sq = F.avg_pool2d(
            x_padded ** 2, kernel_size=self.window_size, stride=1, padding=0
        )

        # Std
        var = mean_sq - mean ** 2
        std = torch.sqrt(F.relu(var))

        threshold = mean * (1 + self.k * ((std / self.R) - 1))

        # Compare with x (no pad, shape [1, 1, H, W])
        return (x > threshold).float().squeeze(0)  # [1, H, W]
