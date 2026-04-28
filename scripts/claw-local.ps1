param(
  [string]$Profile,
  [string]$Backend,
  [switch]$Print,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ClawArgs
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

function Resolve-LocalProfile {
  param([string]$Name)
  switch ($Name) {
    "gemma-4-e4b" { @{ Display = "Gemma 4 E4B IT"; Alias = "gemma-4-e4b"; Hf = "google/gemma-4-E4B-it"; Ollama = "" } }
    "gemma-4-e2b" { @{ Display = "Gemma 4 E2B IT"; Alias = "gemma-4-e2b"; Hf = "google/gemma-4-E2B-it"; Ollama = "" } }
    "qwen-coder-7b" { @{ Display = "Qwen2.5 Coder 7B Instruct"; Alias = "qwen-coder-7b"; Hf = "Qwen/Qwen2.5-Coder-7B-Instruct"; Ollama = "qwen2.5-coder:7b" } }
    "qwen-coder-3b" { @{ Display = "Qwen2.5 Coder 3B Instruct"; Alias = "qwen-coder-3b"; Hf = "Qwen/Qwen2.5-Coder-3B-Instruct"; Ollama = "qwen2.5-coder:3b" } }
    "qwen-coder-1.5b" { @{ Display = "Qwen2.5 Coder 1.5B Instruct"; Alias = "qwen-coder-1.5b"; Hf = "Qwen/Qwen2.5-Coder-1.5B-Instruct"; Ollama = "qwen2.5-coder:1.5b" } }
    default { throw "Unknown LOCAL_MODEL_PROFILE: $Name" }
  }
}

$LocalEnv = Join-Path $Root "local/env.local"
if (Test-Path $LocalEnv) {
  Get-Content $LocalEnv | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+?)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
    }
  }
}

if (-not $Profile) { $Profile = if ($env:LOCAL_MODEL_PROFILE) { $env:LOCAL_MODEL_PROFILE } else { "qwen-coder-7b" } }
if (-not $Backend) { $Backend = if ($env:LOCAL_BACKEND) { $env:LOCAL_BACKEND } else { "ollama" } }

$ProfileData = Resolve-LocalProfile $Profile
$BaseUrl = $env:LOCAL_OPENAI_BASE_URL
$Model = $env:LOCAL_MODEL_ID

switch ($Backend) {
  "ollama" {
    if (-not $BaseUrl) { $BaseUrl = "http://127.0.0.1:11434/v1" }
    if (-not $Model) { $Model = if ($ProfileData.Ollama) { $ProfileData.Ollama } else { $ProfileData.Hf } }
  }
  "llamacpp" {
    if (-not $BaseUrl) { $BaseUrl = "http://127.0.0.1:8080/v1" }
    if (-not $Model) { $Model = $ProfileData.Alias }
  }
  "vllm" {
    if (-not $BaseUrl) { $BaseUrl = "http://127.0.0.1:8000/v1" }
    if (-not $Model) { $Model = $ProfileData.Hf }
  }
  "lmstudio" {
    if (-not $BaseUrl) { $BaseUrl = "http://127.0.0.1:1234/v1" }
    if (-not $Model) { $Model = $ProfileData.Hf }
  }
  "openai-compatible" {
    if (-not $BaseUrl) { $BaseUrl = "http://127.0.0.1:8000/v1" }
    if (-not $Model) { $Model = $ProfileData.Hf }
  }
  default { throw "Unknown LOCAL_BACKEND: $Backend" }
}

if ($Print) {
  "profile=$Profile"
  "name=$($ProfileData.Display)"
  "backend=$Backend"
  "base_url=$BaseUrl"
  "model=$Model"
  exit 0
}

$env:OPENAI_BASE_URL = $BaseUrl
$env:OPENAI_API_KEY = if ($env:LOCAL_API_KEY) { $env:LOCAL_API_KEY } else { "local-dev-token" }
$ClawBin = if ($env:LOCAL_CLAW_BIN) { $env:LOCAL_CLAW_BIN } else { "rust/target/debug/claw" }
$ClawPath = if ([IO.Path]::IsPathRooted($ClawBin)) { $ClawBin } else { Join-Path $Root $ClawBin }
if (-not (Test-Path $ClawPath)) {
  throw "claw binary not found: $ClawPath. Build it first: cd rust; cargo build --workspace"
}

$PermissionMode = if ($env:LOCAL_CLAW_PERMISSION_MODE) { $env:LOCAL_CLAW_PERMISSION_MODE } else { "workspace-write" }
Push-Location (Join-Path $Root "rust")
try {
  & $ClawPath --permission-mode $PermissionMode --model $Model @ClawArgs
} finally {
  Pop-Location
}
