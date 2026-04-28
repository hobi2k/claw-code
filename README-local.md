# claw-code 로컬 모델 실행 가이드

이 문서는 `claw-code` 전용입니다. `opencode` 설정은 `opencode` 저장소의 `README-local.md`에서 따로 관리합니다.

목표는 `claw-code` 본체와 upstream `README.md`를 건드리지 않고, Ollama, llama.cpp, vLLM, LM Studio, 직접 만든 OpenAI-compatible 서버에 붙여서 `claw`를 CLI처럼 실행하는 것입니다.

## 원칙

- Rust/Python 본체 코드를 수정하지 않습니다.
- 기존 `README.md`를 수정하지 않습니다.
- 로컬 전용 파일은 `local/`, `configs/`, `scripts/claw-local`에만 둡니다.
- 개인 설정은 `local/env.local`에 두고 git에 넣지 않습니다.
- 모델 파일은 `models/` 아래에 둘 수 있지만 git에 넣지 않습니다.

## 추가 파일

- `local/env.example`: 개인 설정 예시입니다.
- `configs/claw-local-models.json`: claw 전용 로컬 모델 프로필입니다.
- `scripts/local-model-common.sh`: macOS/Linux/WSL용 공통 profile 해석 코드입니다.
- `scripts/claw-local`: macOS/Linux/WSL에서 쓰는 `claw` 로컬 실행 CLI입니다.
- `scripts/claw-local.ps1`: Windows PowerShell에서 쓰는 `claw` 로컬 실행 CLI입니다.

## 지원 모델

| Profile | 기본 모델 id | 주 용도 |
| --- | --- | --- |
| `gemma-4-e4b` | `google/gemma-4-E4B-it` | Gemma 4 E4B 로컬 실험 |
| `gemma-4-e2b` | `google/gemma-4-E2B-it` | 더 가벼운 Gemma 4 실행 |
| `qwen-coder-7b` | Ollama는 `qwen2.5-coder:7b`, 그 외는 `Qwen/Qwen2.5-Coder-7B-Instruct` | 로컬 코딩 기본 추천 |
| `qwen-coder-3b` | Ollama는 `qwen2.5-coder:3b`, 그 외는 `Qwen/Qwen2.5-Coder-3B-Instruct` | 노트북용 빠른 코딩 |
| `qwen-coder-1.5b` | Ollama는 `qwen2.5-coder:1.5b`, 그 외는 `Qwen/Qwen2.5-Coder-1.5B-Instruct` | 가벼운 smoke test |

## 먼저 claw 빌드

처음 한 번은 Rust 본체를 빌드해야 합니다.

```bash
cd /path/to/claw-code
cd rust
cargo build --workspace
cd ..
```

빌드 후 binary는 `rust/target/debug/claw`에 생깁니다. `scripts/claw-local`은 이 binary를 기본값으로 사용합니다.

## Ollama로 실행

Ollama가 이미 설치되어 있고 서버가 켜져 있다고 가정합니다.

```bash
ollama pull qwen2.5-coder:7b
```

실행 전에 wrapper가 어떤 값을 사용할지 확인합니다.

```bash
LOCAL_MODEL_PROFILE=qwen-coder-7b LOCAL_BACKEND=ollama ./scripts/claw-local --print
```

한 번만 물어보는 prompt 모드:

```bash
LOCAL_MODEL_PROFILE=qwen-coder-7b LOCAL_BACKEND=ollama \
  ./scripts/claw-local prompt "이 저장소를 한 문장으로 설명해줘"
```

대화형 REPL:

```bash
LOCAL_MODEL_PROFILE=qwen-coder-7b LOCAL_BACKEND=ollama \
  ./scripts/claw-local
```

## llama.cpp로 실행

`llama-server`가 OpenAI-compatible `/v1/chat/completions`를 제공하도록 띄웁니다.

```bash
llama-server \
  -m models/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  --alias qwen-coder-7b \
  --host 127.0.0.1 \
  --port 8080
```

그다음 `claw`를 붙입니다.

```bash
LOCAL_MODEL_PROFILE=qwen-coder-7b LOCAL_BACKEND=llamacpp \
  ./scripts/claw-local prompt "reply with LOCAL_OK"
```

`LOCAL_BACKEND=llamacpp`의 기본 base URL은 `http://127.0.0.1:8080/v1`입니다. alias가 다르면 `LOCAL_MODEL_ID`로 덮어씁니다.

```bash
LOCAL_MODEL_PROFILE=qwen-coder-7b \
LOCAL_BACKEND=llamacpp \
LOCAL_MODEL_ID=my-qwen-alias \
  ./scripts/claw-local prompt "reply with LOCAL_OK"
```

## vLLM 또는 직접 만든 OpenAI-compatible 서버

`/v1/chat/completions`를 제공하는 서버를 먼저 띄웁니다.

```bash
python -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen2.5-Coder-7B-Instruct \
  --host 127.0.0.1 \
  --port 8000
```

그다음:

```bash
LOCAL_MODEL_PROFILE=qwen-coder-7b LOCAL_BACKEND=vllm \
  ./scripts/claw-local prompt "reply with LOCAL_OK"
```

Gemma 4 E2B:

```bash
LOCAL_MODEL_PROFILE=gemma-4-e2b LOCAL_BACKEND=openai-compatible \
  ./scripts/claw-local prompt "reply with LOCAL_OK"
```

Gemma 4 E4B:

```bash
LOCAL_MODEL_PROFILE=gemma-4-e4b LOCAL_BACKEND=openai-compatible \
  ./scripts/claw-local prompt "reply with LOCAL_OK"
```

서버가 다른 모델 id를 노출하면 `LOCAL_MODEL_ID`를 지정합니다.

```bash
LOCAL_MODEL_PROFILE=gemma-4-e4b \
LOCAL_BACKEND=openai-compatible \
LOCAL_OPENAI_BASE_URL=http://127.0.0.1:8000/v1 \
LOCAL_MODEL_ID=gemma-4-e4b \
  ./scripts/claw-local prompt "reply with LOCAL_OK"
```

## LM Studio

LM Studio에서 OpenAI-compatible server를 켠 뒤 기본값으로 붙일 수 있습니다.

```bash
LOCAL_MODEL_PROFILE=qwen-coder-7b LOCAL_BACKEND=lmstudio \
  ./scripts/claw-local prompt "reply with LOCAL_OK"
```

LM Studio 기본 URL은 `http://127.0.0.1:1234/v1`입니다.

## 개인 설정 고정

매번 환경변수를 쓰기 싫으면:

```bash
cp local/env.example local/env.local
```

예시:

```env
LOCAL_MODEL_PROFILE=qwen-coder-3b
LOCAL_BACKEND=ollama
LOCAL_API_KEY=local-dev-token
LOCAL_CLAW_PERMISSION_MODE=workspace-write
```

이후에는 이렇게 실행하면 됩니다.

```bash
./scripts/claw-local prompt "현재 git diff를 요약해줘"
```

## Windows PowerShell

PowerShell에서는:

```powershell
$env:LOCAL_MODEL_PROFILE = "qwen-coder-7b"
$env:LOCAL_BACKEND = "ollama"
.\scripts\claw-local.ps1 -Print
.\scripts\claw-local.ps1 prompt "reply with LOCAL_OK"
```

대화형으로 쓰려면:

```powershell
.\scripts\claw-local.ps1
```

## CLI처럼 쓰기

macOS/Linux/WSL에서는 repo 안에서 바로:

```bash
./scripts/claw-local
```

전역 명령처럼 쓰고 싶으면 shell alias를 두면 됩니다.

```bash
alias claw-local="/path/to/claw-code/scripts/claw-local"
```

그러면 어디서든:

```bash
claw-local prompt "이 파일을 설명해줘"
```

## 동작 방식

`scripts/claw-local`은 profile과 backend를 읽어 다음 값을 만듭니다.

- `OPENAI_BASE_URL`
- `OPENAI_API_KEY`
- `--model`
- `--permission-mode`

그 후 `rust/target/debug/claw`를 실행합니다. 즉 `claw-code` 본체는 그대로 두고, wrapper가 실행 환경만 준비합니다.

## backend 기본값

| Backend | 기본 URL | 모델 id 선택 |
| --- | --- | --- |
| `ollama` | `http://127.0.0.1:11434/v1` | Qwen은 Ollama tag, Gemma는 HF id |
| `llamacpp` | `http://127.0.0.1:8080/v1` | profile alias |
| `vllm` | `http://127.0.0.1:8000/v1` | HF id |
| `lmstudio` | `http://127.0.0.1:1234/v1` | HF id |
| `openai-compatible` | `http://127.0.0.1:8000/v1` | HF id |

## 확인 명령

설정만 확인:

```bash
./scripts/claw-local --print
```

Qwen 1.5B Ollama 확인:

```bash
LOCAL_MODEL_PROFILE=qwen-coder-1.5b LOCAL_BACKEND=ollama ./scripts/claw-local --print
```

Gemma 4 E4B custom server 확인:

```bash
LOCAL_MODEL_PROFILE=gemma-4-e4b LOCAL_BACKEND=openai-compatible ./scripts/claw-local --print
```
