import torch
from torchvision import datasets
from torchvision.transforms import ToTensor
from torch.utils.data import DataLoader
import matplotlib.pyplot as plt

def take_dataset(download: bool = False):
    """Only ToTensor() transform to """
    train_data = datasets.MNIST(
        root="data",
        train=True,
        download=download, # download if not on disk
        transform=ToTensor(),
        target_transform=None
    )
    test_data = datasets.MNIST(
        root="data",
        train=False,
        download=download,
        transform=ToTensor()
    )
    return train_data, test_data


def take_dataloader(train_data, test_data, batch_size: int = 32):
    train_dataloader = DataLoader(train_data,
                                  batch_size=batch_size,
                                  shuffle=True
                                  )

    test_dataloader = DataLoader(test_data,
                                 batch_size=batch_size,
                                 shuffle=False
                                 )
    return train_dataloader, test_dataloader


def plot_data(dataset):
    class_names = [str(i) for i in range(10)]

    fig = plt.figure(figsize=(9, 9))
    rows, cols = 4, 4
    for i in range(1, rows * cols + 1):
        random_idx = torch.randint(0, len(dataset), size=[1]).item()
        img, label = dataset[random_idx]
        fig.add_subplot(rows, cols, i)
        plt.imshow(img.squeeze(), cmap="gray")
        plt.title(class_names[label])
        plt.axis("off")
    plt.show()
