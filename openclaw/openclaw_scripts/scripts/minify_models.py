#!/usr/bin/env python3
"""精简 models.json，按 created_time 倒序排序后只保留必要字段。

model.tf 实际引用：
- id
- name
- architecture.input_modalities
- architecture.reasoning.supported
- model_constraints.context_length
- model_constraints.max_tokens

额外保留（人工审查/未来用）：
- created_time
"""

import json
import sys
from pathlib import Path

EXPECTED_MODEL_KEYS = {"id", "name", "created_time", "architecture", "model_constraints"}
EXPECTED_ARCH_KEYS = {"input_modalities", "reasoning"}
EXPECTED_CONSTRAINT_KEYS = {"context_length", "max_tokens"}


def slim_model(m: dict) -> dict:
    arch = m.get("architecture", {}) or {}
    constraints = m.get("model_constraints", {}) or {}
    return {
        "id": m["id"],
        "name": m["name"],
        "created_time": m.get("created_time"),
        "architecture": {
            "input_modalities": arch.get("input_modalities", []),
            "reasoning": {"supported": arch.get("reasoning", {}).get("supported", False)},
        },
        "model_constraints": {
            "context_length": constraints.get("context_length", 0),
            "max_tokens": constraints.get("max_tokens", 0),
        },
    }


def sort_key(m: dict):
    ct = m.get("created_time")
    # None 排到末尾，其余按 ISO 8601 字符串字典序（=时间序）
    return (ct is None, ct or "")


def is_already_slim(data: dict) -> bool:
    """检查 data 是否已是精简形态：字段集匹配 + 已按 created_time 倒序。"""
    items = data.get("data") or []
    if not items:
        return True
    sample = items[0]
    if set(sample.keys()) != EXPECTED_MODEL_KEYS:
        return False
    arch = sample.get("architecture") or {}
    if set(arch.keys()) != EXPECTED_ARCH_KEYS:
        return False
    cons = sample.get("model_constraints") or {}
    if set(cons.keys()) != EXPECTED_CONSTRAINT_KEYS:
        return False
    times = [m.get("created_time") for m in items]
    if any(t is None for t in times):
        return False
    return times == sorted(times, reverse=True)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <models.json>", file=sys.stderr)
        return 1
    path = Path(sys.argv[1])
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    if is_already_slim(data):
        print(f"already slim, skip: {path} ({len(data.get('data', []))} models)")
        return 0
    items_sorted = sorted(data.get("data", []), key=sort_key, reverse=True)
    slim = {
        "status": data.get("status", True),
        "data": [slim_model(m) for m in items_sorted],
    }
    with path.open("w", encoding="utf-8") as f:
        json.dump(slim, f, ensure_ascii=False, indent=2)
    print(f"slimmed {path}: {len(slim['data'])} models")
    return 0


if __name__ == "__main__":
    sys.exit(main())
