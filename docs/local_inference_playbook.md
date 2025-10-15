# Local AI Inference Playbook

This playbook captures the core operational practices for running AI inference workloads consistently across developer machines, CI runners, and edge devices. Each section can map directly to a checklist in runbooks or onboarding guides.

## 1. Make the environment reproducible
- Package every runtime dependency in a container pinned by digest rather than tags.
- Maintain lockfiles for each language environment (e.g., `requirements.txt` from `pip-tools`, `uv.lock`, `poetry.lock`, or `conda-lock`).
- Pin CUDA, cuDNN, and your chosen BLAS/LAPACK implementation (MKL, OpenBLAS, Accelerate, etc.) to prevent subtle numeric drift across hosts.
- Enable determinism switches: set global seeds for Python, NumPy, and your ML framework; prefer deterministic kernels.
- PyTorch-specific flags: `torch.use_deterministic_algorithms(True)`, `torch.backends.cudnn.deterministic = True`, `torch.backends.cudnn.benchmark = False`.
- TensorFlow-specific flag: export `TF_DETERMINISTIC_OPS=1`.
- Store models and datasets as immutable artifacts with SHA256 hashes and verify their integrity on load.

## 2. Standardize the inference layer
- Convert models to a portable IR such as ONNX (or TorchScript for PyTorch-only stacks).
- Use ONNX Runtime with provider fallbacks (CUDA → DirectML → CoreML → CPU) to cover heterogeneous hardware.
- When accelerators exist, generate engines from the same ONNX export using TensorRT (NVIDIA), OpenVINO (Intel), or CoreML (Apple) to keep numerics aligned.
- Maintain a golden input set; assert maximum absolute/relative errors after every conversion.

## 3. Performance tuning that travels
- Apply quantization intentionally: start with INT8/FP8 (with calibration on a held-out set) or FP16/BF16 for GPUs, and ensure a CPU INT8 path is available for parity.
- Cache compilation artifacts: build TensorRT/OpenVINO engines ahead of time per hardware family (e.g., "Turing GPU", "AVX2 CPU", "Apple M-series") and name them clearly.
- Tune batching and concurrency (batch size, number of threads, intra/inter-op settings) per hardware tier; keep defaults in configuration rather than code.
- Optimize I/O and memory: memory-map weights, use page-locked buffers for GPU transfers, and run warmup passes at service start.

## 4. Reliability patterns for local inference
- Expose a `/healthz` endpoint that confirms the model is loaded and can execute a lightweight inference; integrate watchdogs to restart on failure.
- Protect callers with timeouts, retries, and circuit breakers to mitigate hung kernels or thermal throttling.
- Define graceful degradation: supply a smaller or CPU-only fallback model and optionally a rules-based path when accelerators are unavailable.
- Enforce backpressure with bounded queues and explicit error codes when devices saturate.
- Guard resources: set explicit GPU/CPU memory caps, detect OOM events, and automatically drop to lower precision or smaller models when required.

## 5. Consistency across many devices
- Track provenance in a model registry: version every artifact (model, tokenizer, calibration set, engine build) with metadata such as Git SHA, data snapshot ID, metrics, and converter/tool versions.
- Centralize tunables in declarative config files that ship with the model (providers, threads, batch sizes, precision).
- Run golden numerical tests for each release across target device classes, comparing metrics against thresholds.
- Keep device clocks in sync (NTP) and enforce fixed locales/time zones for any time-sensitive logic.

## 6. Monitoring and QA (offline-friendly)
- Emit local telemetry: latency distribution (p50/p95/p99), throughput, memory usage, and error codes to rotating logs; optionally batch-export when connectivity exists.
- Maintain a small evaluation set to run on boot or daily to catch driver or model regressions.
- Capture device temperature and throttling events; adapt concurrency limits when hardware overheats.

## 7. Secure and safe updates
- Sign artifacts (models, engines) and verify signatures before loading them.
- Roll out updates in stages: canary one device class first, keep last-known-good artifacts ready for instant rollback.
- Validate schema contracts for inputs/outputs (shapes, dtypes, normalization) and fail fast when clients drift.

## 8. Data lifecycle and drift management
- Ensure feature parity by centralizing preprocessing/postprocessing; distribute the same code or a generated specification to all devices.
- Track data drift via summary statistics (means, ranges, sparsity, token lengths) and compare with training-time baselines.
- Re-run quantization calibration when input distributions shift and bump the model version to reflect recalibration.

## 9. Practical defaults for runbooks
- Use digest-pinned containers that already include CUDA/cuDNN when required.
- Export models to ONNX and run them with ONNX Runtime (CUDA with CPU fallback).
- Provide TensorRT/OpenVINO/CoreML engines for each target hardware class and store them alongside ONNX artifacts with checksums.
- Enable determinism flags and set global seeds by default.
- Ship a golden input pack with tolerance thresholds; execute it on startup and inside CI pipelines.
- Log latency, memory, and error metrics locally; expose `/metrics` for on-demand scraping.
- Bundle a fallback CPU model plus the last-known-good release for instant rollback.
- Document each release in a model card covering versions, datasets, metrics, supported devices, and configuration defaults.

## 10. Tooling suggestions
- Packaging: Docker/Podman with digest pins, or Nix for stronger reproducibility guarantees.
- Runtime: ONNX Runtime, TensorRT, OpenVINO, CoreML, or Triton Inference Server for dynamic batching and unified metrics.
- Testing: `pytest` with golden vectors, plus `pytest-benchmark` (or similar) for performance budgets.
- Registry: host models in MLflow Registry, S3 with an index, Git LFS with JSON manifests, or any system that enforces versioning and checksums.

---

Tailor this checklist by adding hardware-specific defaults, per-device config templates, and automation scripts that match your deployment pipeline.
