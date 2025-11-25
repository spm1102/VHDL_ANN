import cv2
import matplotlib.pyplot as plt
import numpy as np
import torch
from skimage.filters import threshold_sauvola

from ann_torch.load_data import take_dataset
from binarization import FixedThreshold, OtsuThreshold, SauvolaThreshold


def print_gray_matrix(arr, to_int=False, title=""):
    arr = np.array(arr)
    if to_int: arr = arr.astype(np.uint8)
    if arr.dtype.kind in ['f']: # float
        for row in arr:
            print("".join(f"{v:4.2f}" for v in row))
    else: # int/uint
        for row in arr:
            print("".join(f"{int(v):3d}" for v in row))

def to_binary_matrix(arr, threshold=0.5):
    arr = np.array(arr, dtype=float)
    bin_arr = (arr > threshold).astype(int) # to 0 or 1
    return bin_arr


def validate_with_real_mnist():
    dataset = take_dataset(download=True)
    idx = torch.randint(0, len(dataset), size=(1,)).item()

    img_tensor, label = dataset[idx][0] # img_tensor shape [1, 28, 28]

    print(f"Checking Image Index: {idx} | Label: {label}")

    img_np = img_tensor.squeeze().numpy() # [28, 28], float [0..1]
    img_uint8 = (img_np * 255).astype(np.uint8) # [28, 28], uint8 [0..255]

    print("Original image (float [0..1])")
    print_gray_matrix(img_np)
    print("Original image (uint8 [0..255])")
    print_gray_matrix(img_uint8)

    # 1. Fixed
    algo_fixed = FixedThreshold(0.5)
    res_fixed_custom = algo_fixed(img_tensor).squeeze().numpy()
    print("Fixed threshold")
    print_gray_matrix(res_fixed_custom, to_int=True)
    _, res_fixed_lib = cv2.threshold(img_uint8, 127, 1, cv2.THRESH_BINARY)

    # 2. Otsu
    algo_otsu = OtsuThreshold()
    res_otsu_custom = algo_otsu(img_tensor).squeeze().numpy()
    print(f"Otsu")
    print_gray_matrix(res_otsu_custom, to_int=True)
    val_otsu, res_otsu_lib = cv2.threshold(
        img_uint8, 0, 1, cv2.THRESH_BINARY + cv2.THRESH_OTSU
    )

    # 3. Sauvola
    algo_sauvola = SauvolaThreshold(window_size=15, k=0.2)
    res_sauvola_custom = algo_sauvola(img_tensor).squeeze().numpy()
    print("Sauvola")
    print_gray_matrix(res_sauvola_custom, to_int=True)
    thresh_sauvola_val = threshold_sauvola(img_np, window_size=15, k=0.2, r=0.5)
    res_sauvola_lib = (img_np > thresh_sauvola_val).astype(float)

    match_fixed = np.mean(res_fixed_custom == res_fixed_lib) * 100
    match_otsu = np.mean(res_otsu_custom == res_otsu_lib) * 100

    # match_sauvola = np.mean(
    #     res_sauvola_custom[2:-2, 2:-2] == res_sauvola_lib[2:-2, 2:-2]
    # ) * 100

    match_sauvola = np.mean(res_sauvola_custom == res_sauvola_lib) * 100
    print(f"\n[Validation Result]")
    print(f"Fixed Threshold Match: {match_fixed:.2f}%")
    print(f"Otsu Threshold Match: {match_otsu:.2f}% (Threshold value found: {val_otsu})")
    # print(f"Sauvola Match (Center): {match_sauvola:.2f}%")
    print(f"Sauvola Match: {match_sauvola:.2f}%")

    center = (slice(2, -2), slice(2, -2))

    fixed_c    = res_fixed_custom[center]
    otsu_c     = res_otsu_custom[center]
    sauvola_c  = res_sauvola_custom[center]

    match_fixed_otsu     = np.mean(fixed_c == otsu_c) * 100
    match_fixed_sauvola  = np.mean(fixed_c == sauvola_c) * 100
    match_otsu_sauvola   = np.mean(otsu_c == sauvola_c) * 100

    print("\n[Cross comparison - CUSTOM (center region)]")
    print(f"Fixed  vs Otsu    : {match_fixed_otsu:.2f}%")
    print(f"Fixed  vs Sauvola : {match_fixed_sauvola:.2f}%")
    print(f"Otsu   vs Sauvola : {match_otsu_sauvola:.2f}%")

    orig_bin = to_binary_matrix(img_np, threshold=0.5) # fixed threshold = 0.5
    fixed_bin = to_binary_matrix(res_fixed_custom, threshold=0.5)
    otsu_bin = to_binary_matrix(res_otsu_custom, threshold=0.5)
    sauvola_bin = to_binary_matrix(res_sauvola_custom, threshold=0.5)

    fig, axes = plt.subplots(2, 4, figsize=(12, 6))

    # Custom
    axes[0, 0].imshow(img_np, cmap='gray')
    axes[0, 0].set_title("Original (Gray)")
    axes[0, 1].imshow(res_fixed_custom, cmap='gray')
    axes[0, 1].set_title("Custom Fixed")
    axes[0, 2].imshow(res_otsu_custom, cmap='gray')
    axes[0, 2].set_title(f"Custom Otsu")
    axes[0, 3].imshow(res_sauvola_custom, cmap='gray')
    axes[0, 3].set_title("Custom Sauvola")

    # Library
    axes[1, 0].axis('off')
    axes[1, 0].text(0.5, 0.5, "LIBRARY RESULT", ha='center', va='center', fontsize=12)

    axes[1, 1].imshow(res_fixed_lib, cmap='gray')
    axes[1, 1].set_title("OpenCV Fixed")
    axes[1, 2].imshow(res_otsu_lib, cmap='gray')
    axes[1, 2].set_title(f"OpenCV Otsu")
    axes[1, 3].imshow(res_sauvola_lib, cmap='gray')
    axes[1, 3].set_title("Skimage Sauvola")

    for ax in axes.flatten():
        ax.axis('off')

    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    validate_with_real_mnist()
