# PASS AI — model research (verified on your RunPod)

**Hardware verified:** NVIDIA RTX PRO 6000 Blackwell **97887 MiB** (~98 GB).  
**Typical load today:** **~84 GB** with **Qwen3-Coder-Next-FP8** alone (one model at a time).

---

## Why Coder Next FP8 feels slow and “not smart enough”

This is **not one bug** — it is the stack + model role:

| Cause | Effect |
|--------|--------|
| **Huge MoE in FP8** | ~84 GB weights + KV cache → less headroom, slower prefill/decode than 30B MoE |
| **Long agent prompts (Cline)** | System prompt + tools + history → many tokens **before** the model acts |
| **Model switch** | Changing model restarts SGLang (**2–5+ minutes**) |
| **PASS API tool rewrite** | When the request includes `tools`, streaming is **buffered until the full reply** so loose JSON/ChatML can become `tool_calls` → feels like “long thinking”, no visible stream |
| **Tool text leaks** | Sometimes `<\|im_start\|>` + JSON in chat → recovery may shorten or simplify edits (e.g. basic HTML) |
| **“Modern UI”** | Coder models optimize **code/tools**, not design — vague prompts → generic templates |

**What to do (in order):**

1. Set **main agent** to **Qwen3-Coder-30B-A3B-Instruct** (download + switch once).  
2. Keep **Coder Next FP8** only for very hard multi-file / long context jobs.  
3. Use **detailed prompts** for UI (fonts, colors, sections, references).  
4. Catalog now uses **32K context** for Next FP8 (was 64K) to reduce KV pressure after pod re-switch.

---

## Can you add these models?

### Qwen3-VL-30B-A3B-Instruct-FP8 — **Yes, with a plus (vision)**

| | |
|--|--|
| **VRAM** | ~31 GB weights + KV — **fits** your 98 GB card |
| **Plus** | Screenshots, mockups, diagrams in chat (when the IDE sends images) |
| **Cline today** | Mostly **text**; VL helps if you add image attachments / future PASS UI |
| **Tools** | SGLang: `--tool-call-parser qwen` (not `qwen3_coder`) |
| **Catch** | Needs **multimodal SGLang launch** (your pod script is text-only today); may need **newer SGLang** |

**Verdict:** Worth adding as **optional “Vision”** model, not as replacement for **Coder 30B MoE** for daily coding.

---

### GLM-4.7 (quantized) — **Not on this single GPU**

| Variant | VRAM | On your server? |
|---------|------|-----------------|
| **GLM-4.7-FP8** (full) | **~430 GB** minimum (official: TP=4–8 H200) | **No** |
| **GLM-4.7-Flash** (~30B MoE) | ~58 GB — **fits in theory** | **Do not deploy yet** on **Blackwell RTX PRO 6000**: open SGLang issues — loads but **garbage output** / Triton OOM |

**Verdict:** **No plus today** on this pod. Revisit when SGLang fixes Blackwell + MLA for GLM-4.7-Flash.

---

### DeepSeek-V3.2 — **Not on this single GPU**

| | |
|--|--|
| **Size** | ~685B MoE, **~642 GB FP8 weights alone** |
| **Minimum** | Multi-GPU datacenter (e.g. 8× H100/H200) |
| **Tools** | Speciale variant is reasoning-only, **no tool calling** |

**Verdict:** **Cannot install** on one 98 GB RunPod. Alternatives that **do** fit:

- **DeepSeek-Coder-V2** (smaller instruct checkpoints) — possible future catalog entry after size check  
- Keep **Qwen3 Coder** line as primary agent stack  

---

## Recommended PASS AI lineup (efficient + Cline tools)

| Priority | Model | Role |
|----------|--------|------|
| **1** | **Qwen3-Coder-30B-A3B-Instruct** | **Default Cline Act agent** (speed + native tools) |
| **2** | **Qwen3-Coder-Next-FP8** | Max quality when you accept slowness |
| **3** | **Qwen2.5-Coder-32B-Instruct** | Fast dense fallback |
| **4** | **Qwen3-VL-30B-A3B-Instruct-FP8** | Optional vision (after multimodal launch) |
| **—** | GLM-4.7 / DeepSeek-V3.2 | **Wait** (hardware or SGLang maturity) |

---

## Install optional models on pod

```bash
bash /workspace/pass-ai/scripts/download-models.sh
bash /workspace/pass-ai/scripts/switch-model.sh Qwen/Qwen3-Coder-30B-A3B-Instruct
```

From Windows (sync scripts + catalog):

```powershell
cd passconside\infra\runpod
.\deploy-runpod-scripts.ps1
```

Then refresh models in PASS AI settings.
