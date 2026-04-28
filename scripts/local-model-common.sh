#!/usr/bin/env sh
set -eu

local_model_root() {
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  CDPATH= cd -- "$script_dir/.." && pwd
}

local_model_load_env() {
  root=$1
  env_file=${LOCAL_ENV_FILE:-"$root/local/env.local"}
  if [ -f "$env_file" ]; then
    # shellcheck disable=SC1090
    . "$env_file"
  fi
}

local_model_profile() {
  profile=${LOCAL_MODEL_PROFILE:-qwen-coder-7b}
  case "$profile" in
    gemma-4-e4b)
      LOCAL_PROFILE_NAME="Gemma 4 E4B IT"
      LOCAL_PROFILE_ALIAS="gemma-4-e4b"
      LOCAL_PROFILE_HF_MODEL="google/gemma-4-E4B-it"
      LOCAL_PROFILE_OLLAMA_MODEL=""
      ;;
    gemma-4-e2b)
      LOCAL_PROFILE_NAME="Gemma 4 E2B IT"
      LOCAL_PROFILE_ALIAS="gemma-4-e2b"
      LOCAL_PROFILE_HF_MODEL="google/gemma-4-E2B-it"
      LOCAL_PROFILE_OLLAMA_MODEL=""
      ;;
    qwen-coder-7b)
      LOCAL_PROFILE_NAME="Qwen2.5 Coder 7B Instruct"
      LOCAL_PROFILE_ALIAS="qwen-coder-7b"
      LOCAL_PROFILE_HF_MODEL="Qwen/Qwen2.5-Coder-7B-Instruct"
      LOCAL_PROFILE_OLLAMA_MODEL="qwen2.5-coder:7b"
      ;;
    qwen-coder-3b)
      LOCAL_PROFILE_NAME="Qwen2.5 Coder 3B Instruct"
      LOCAL_PROFILE_ALIAS="qwen-coder-3b"
      LOCAL_PROFILE_HF_MODEL="Qwen/Qwen2.5-Coder-3B-Instruct"
      LOCAL_PROFILE_OLLAMA_MODEL="qwen2.5-coder:3b"
      ;;
    qwen-coder-1.5b)
      LOCAL_PROFILE_NAME="Qwen2.5 Coder 1.5B Instruct"
      LOCAL_PROFILE_ALIAS="qwen-coder-1.5b"
      LOCAL_PROFILE_HF_MODEL="Qwen/Qwen2.5-Coder-1.5B-Instruct"
      LOCAL_PROFILE_OLLAMA_MODEL="qwen2.5-coder:1.5b"
      ;;
    *)
      printf 'Unknown LOCAL_MODEL_PROFILE: %s\n' "$profile" >&2
      printf 'Supported: gemma-4-e4b, gemma-4-e2b, qwen-coder-7b, qwen-coder-3b, qwen-coder-1.5b\n' >&2
      exit 2
      ;;
  esac
}

local_model_resolve_backend() {
  backend=${LOCAL_BACKEND:-ollama}
  case "$backend" in
    ollama)
      LOCAL_RESOLVED_BASE_URL=${LOCAL_OPENAI_BASE_URL:-http://127.0.0.1:11434/v1}
      if [ -n "${LOCAL_MODEL_ID:-}" ]; then
        LOCAL_RESOLVED_MODEL=$LOCAL_MODEL_ID
      elif [ -n "$LOCAL_PROFILE_OLLAMA_MODEL" ]; then
        LOCAL_RESOLVED_MODEL=$LOCAL_PROFILE_OLLAMA_MODEL
      else
        LOCAL_RESOLVED_MODEL=$LOCAL_PROFILE_HF_MODEL
      fi
      ;;
    llamacpp)
      LOCAL_RESOLVED_BASE_URL=${LOCAL_OPENAI_BASE_URL:-http://127.0.0.1:8080/v1}
      LOCAL_RESOLVED_MODEL=${LOCAL_MODEL_ID:-$LOCAL_PROFILE_ALIAS}
      ;;
    vllm)
      LOCAL_RESOLVED_BASE_URL=${LOCAL_OPENAI_BASE_URL:-http://127.0.0.1:8000/v1}
      LOCAL_RESOLVED_MODEL=${LOCAL_MODEL_ID:-$LOCAL_PROFILE_HF_MODEL}
      ;;
    lmstudio)
      LOCAL_RESOLVED_BASE_URL=${LOCAL_OPENAI_BASE_URL:-http://127.0.0.1:1234/v1}
      LOCAL_RESOLVED_MODEL=${LOCAL_MODEL_ID:-$LOCAL_PROFILE_HF_MODEL}
      ;;
    openai-compatible)
      LOCAL_RESOLVED_BASE_URL=${LOCAL_OPENAI_BASE_URL:-http://127.0.0.1:8000/v1}
      LOCAL_RESOLVED_MODEL=${LOCAL_MODEL_ID:-$LOCAL_PROFILE_HF_MODEL}
      ;;
    *)
      printf 'Unknown LOCAL_BACKEND: %s\n' "$backend" >&2
      printf 'Supported: ollama, llamacpp, vllm, lmstudio, openai-compatible\n' >&2
      exit 2
      ;;
  esac
  LOCAL_RESOLVED_BACKEND=$backend
  LOCAL_RESOLVED_API_KEY=${LOCAL_API_KEY:-local-dev-token}
}

local_model_json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

local_model_print() {
  printf 'profile=%s\n' "${LOCAL_MODEL_PROFILE:-qwen-coder-7b}"
  printf 'name=%s\n' "$LOCAL_PROFILE_NAME"
  printf 'backend=%s\n' "$LOCAL_RESOLVED_BACKEND"
  printf 'base_url=%s\n' "$LOCAL_RESOLVED_BASE_URL"
  printf 'model=%s\n' "$LOCAL_RESOLVED_MODEL"
}
