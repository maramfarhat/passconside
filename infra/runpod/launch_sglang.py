#!/usr/bin/env python3
"""Launch SGLang for PASS AI. Deploy to /workspace/pass-ai/scripts/launch_sglang.py on the pod."""
from __future__ import annotations

import os
import re
from pathlib import Path


def _expand(value: str) -> str:
    def repl(m: re.Match[str]) -> str:
        return os.environ.get(m.group(1), "")

    return re.sub(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?", repl, value)


def load_exports(path: str) -> None:
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("export "):
            line = line[len("export ") :]
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ[k.strip()] = _expand(v.strip().strip('"').strip("'"))


def main() -> None:
    load_exports("/workspace/pass-ai/config/env.sh")
    for raw in Path("/workspace/pass-ai/config/api-key.env").read_text(encoding="utf-8").splitlines():
        if "=" in raw and not raw.strip().startswith("#"):
            k, v = raw.split("=", 1)
            os.environ[k.strip()] = v.strip()

    cuda_home = os.environ.get("CUDA_HOME", "")
    if cuda_home:
        os.environ["PATH"] = f"{cuda_home}/bin:" + os.environ.get("PATH", "")
        os.environ["LD_LIBRARY_PATH"] = (
            f"{cuda_home}/lib64:{cuda_home}/lib:" + os.environ.get("LD_LIBRARY_PATH", "")
        )
        os.environ["LIBRARY_PATH"] = (
            f"{cuda_home}/lib64:{cuda_home}/lib:" + os.environ.get("LIBRARY_PATH", "")
        )

    from sglang.srt.entrypoints.http_server import launch_server
    from sglang.srt.server_args import ServerArgs

    tool_parser = os.environ.get("PASS_AI_TOOL_CALL_PARSER", "qwen3_coder").strip() or "qwen3_coder"

    args = ServerArgs(
        model_path=os.environ["PASS_AI_MODEL"],
        host=os.environ.get("PASS_AI_HOST", "0.0.0.0"),
        port=int(os.environ.get("PASS_AI_PORT", "30000")),
        context_length=int(os.environ.get("PASS_AI_CONTEXT_LENGTH", "65536")),
        mem_fraction_static=float(os.environ.get("PASS_AI_MEM_FRACTION_STATIC", "0.85")),
        max_running_requests=int(os.environ.get("PASS_AI_MAX_RUNNING_REQUESTS", "8")),
        tool_call_parser=tool_parser,
        api_key=os.environ["PASS_AI_API_KEY"],
        trust_remote_code=True,
        attention_backend="triton",
        fp8_gemm_runner_backend="triton",
        sampling_backend="pytorch",
        disable_cuda_graph=True,
        skip_server_warmup=True,
    )
    launch_server(args)


if __name__ == "__main__":
    main()
