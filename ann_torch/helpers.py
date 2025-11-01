import torch
import torchmetrics
import os
import numpy as np
from torch import nn
from torch import optim


def train_loop(model, epochs, train_dataloader, test_dataloader, device):
    model.to(device)
    loss_fn = take_loss()
    optimizer = take_optimizer(model)
    accuracy_fn = take_accuracy(device)

    # LR scheduler
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode='min', factor=0.5, patience=3, min_lr=1e-5
    )
    best_acc = 0.0
    model_name = model.__class__.__name__

    for epoch in range(epochs):
        print(f"{epoch + 1}/{epochs}:")
        train_loss, train_acc = train_step(
            data_loader=train_dataloader,
            model=model,
            loss_fn=loss_fn,
            optimizer=optimizer,
            accuracy_fn=accuracy_fn,
            device=device
        )
        test_loss, test_acc = test_step(
            data_loader=test_dataloader,
            model=model,
            loss_fn=loss_fn,
            accuracy_fn=accuracy_fn,
            device=device
        )
        scheduler.step(test_loss)

        if test_acc > best_acc:
            best_acc = test_acc
            torch.save(model.state_dict(), f"{model.__class__.__name__}_best.pth")

    print(f"\nSaved at best test accuracy: {best_acc*100:.4f}%")
    return model_name, best_acc

def save_model_params(model: torch.nn.Module, outdir="weights"):
    """
    Save model parameters

    Returns:
        weight & bias as .txt and model.state_dict() as .pth file
    """
    os.makedirs(outdir, exist_ok=True)
    model_name = model.__class__.__name__
    outpath = os.path.join(outdir, model_name)
    os.makedirs(outpath, exist_ok=True)

    for name, param in model.named_parameters():
        np.savetxt(os.path.join(outpath, f"{name.replace('.', '_')}.txt"),
                   param.detach().cpu().numpy(), fmt="%.6f")

    torch.save(model.state_dict(), os.path.join(outpath, f"{model_name}.pth"))
    print(f"Saved weights for {model_name} to '{outpath}/'")


def train_step(model: torch.nn.Module,
               data_loader: torch.utils.data.DataLoader,
               loss_fn: torch.nn.Module,
               optimizer: torch.optim.Optimizer,
               accuracy_fn,
               device: torch.device):
    """
    Train by step.

    Returns:
        (tuple): avg_loss, avg_acc
    """
    train_loss, train_acc = 0, 0
    model.to(device)
    for batch, (X, y) in enumerate(data_loader):
        # Send data to GPU
        X, y = X.to(device), y.to(device)

        y_pred = model(X)

        loss = loss_fn(y_pred, y)
        train_loss += loss.item()
        train_acc += accuracy_fn(y_pred.argmax(dim=1), y).item()  # logits -> pred labels

        optimizer.zero_grad()

        loss.backward()

        optimizer.step()

    train_loss /= len(data_loader)
    train_acc /= len(data_loader)
    print(f"Train loss: {train_loss:.5f} | Train accuracy: {train_acc*100:.4f}%")
    return train_loss, train_acc


def test_step(data_loader: torch.utils.data.DataLoader,
              model: torch.nn.Module,
              loss_fn: torch.nn.Module,
              accuracy_fn: torchmetrics,
              device: torch.device):
    """
    Test by step.

    Returns:
        (tuple): avg_loss, avg_acc
    """
    test_loss, test_acc = 0, 0
    model.to(device)

    model.eval()
    with torch.inference_mode():
        for X, y in data_loader:
            X, y = X.to(device), y.to(device)

            test_pred = model(X)

            test_loss += loss_fn(test_pred, y)
            test_acc += accuracy_fn(test_pred.argmax(dim=1), y).item()

        test_loss /= len(data_loader)
        test_acc /= len(data_loader)
        print(f"Test loss: {test_loss:.5f} | Test accuracy: {test_acc*100:.4f}%\n")
    return test_loss, test_acc


def eval_model(model: torch.nn.Module,
               data_loader: torch.utils.data.DataLoader,
               loss_fn: torch.nn.Module,
               accuracy_fn,
               device: torch.device):
    """Evaluates a given model on a given dataset.
    Returns:
        (dict): Results of model making predictions on data_loader.
    """
    loss, acc = 0, 0
    model.eval()
    with torch.inference_mode():
        for X, y in data_loader:
            X, y = X.to(device), y.to(device)
            y_pred = model(X)
            loss += loss_fn(y_pred, y)
            acc += accuracy_fn(y_pred.argmax(dim=1), y)

        loss /= len(data_loader)
        acc /= len(data_loader)
    return {"model_name": model.__class__.__name__,  # only works when model was created with a class
            "model_loss": loss.item(),
            "model_acc": acc.item()}


def take_loss():
    """Cross Entropy Loss"""
    return nn.CrossEntropyLoss()


def take_optimizer(model, lr: float = 0.01):
    """AdamW optimizer"""
    return optim.AdamW(model.parameters(), lr=lr)


def take_accuracy(device):
    """torchmetrics.Accuracy return acc in range of [0, 1]"""
    class_names = [str(i) for i in range(10)]
    return torchmetrics.Accuracy(task='multiclass', num_classes=len(class_names)).to(device)
