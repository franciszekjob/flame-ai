"""Sorting implementations used by the /fast and /slow endpoints.

bubble_sort is deliberately a pure-Python O(n^2) implementation so the CPU
profile shows it as the dominant frame on the flame graph.
"""

from __future__ import annotations

import random


def make_dataset(n: int, seed: int = 0) -> list[int]:
    rng = random.Random(seed)
    return [rng.randint(0, 10_000_000) for _ in range(n)]


def fast_sort(data: list[int]) -> list[int]:
    return sorted(data)


def bubble_sort(data: list[int]) -> list[int]:
    arr = list(data)
    n = len(arr)
    for i in range(n):
        swapped = False
        for j in range(0, n - i - 1):
            if arr[j] > arr[j + 1]:
                arr[j], arr[j + 1] = arr[j + 1], arr[j]
                swapped = True
        if not swapped:
            break
    return arr
