"""FastAPI entry point for the Inefficient Sorter demo service."""

from __future__ import annotations

import logging
import os
import time
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Query

from app.sorters import bubble_sort, fast_sort, make_dataset

DEFAULT_N = int(os.getenv("SORTER_DEFAULT_N", "5000"))

logger = logging.getLogger("sorter")


def _init_pyroscope() -> None:
    server = os.getenv("PYROSCOPE_SERVER_ADDRESS")
    if not server:
        logger.info("PYROSCOPE_SERVER_ADDRESS not set; profiling disabled.")
        return
    try:
        import pyroscope  # type: ignore[import-not-found]
    except ImportError:
        logger.warning("pyroscope-io is not installed; profiling disabled.")
        return

    pyroscope.configure(
        application_name=os.getenv("PYROSCOPE_APPLICATION_NAME", "flame-ai.sorter"),
        server_address=server,
        tags={
            "env": os.getenv("PYROSCOPE_ENV", "dev"),
            "service": "sorter",
        },
        oncpu=True,
        enable_logging=False,
    )
    logger.info("Pyroscope profiler started, pushing to %s", server)


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    _init_pyroscope()
    yield


app = FastAPI(title="Inefficient Sorter", version="0.1.0", lifespan=lifespan)


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/fast")
def fast(n: int = Query(default=DEFAULT_N, ge=1, le=200_000)) -> dict[str, float | int | str]:
    data = make_dataset(n)
    start = time.perf_counter()
    fast_sort(data)
    elapsed = time.perf_counter() - start
    return {"endpoint": "fast", "n": n, "elapsed_s": round(elapsed, 4)}


@app.get("/slow")
def slow(n: int = Query(default=DEFAULT_N, ge=1, le=20_000)) -> dict[str, float | int | str]:
    data = make_dataset(n)
    start = time.perf_counter()
    bubble_sort(data)
    elapsed = time.perf_counter() - start
    return {"endpoint": "slow", "n": n, "elapsed_s": round(elapsed, 4)}
