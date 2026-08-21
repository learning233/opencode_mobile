#!/usr/bin/env bash
set -euo pipefail

# ─── kterm 测试执行体系 ──────────────────────────────────────────────
# 用法:
#   ./run_test.sh               # 全量 (flutter test)
#   ./run_test.sh smoke         # 纯 Dart 烟雾测试 (无需 Flutter SDK)
#   ./run_test.sh golden        # golden 文件测试
#   ./run_test.sh fuzz [N]      # 随机种子重跑 N 次 (默认 5)
#   ./run_test.sh <file/dir>    # 指定路径
#
# 环境变量:
#   SEED                    # 随机种子 (默认 42)
#   UPDATE_GOLDENS          # true = 更新 golden
# ====================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

SEED="${SEED:-42}"
UPDATE_GOLDENS="${UPDATE_GOLDENS:-false}"

# ─── 静态文件清单 ───────────────────────────────────────────────────

# 可用 dart test 执行的文件（纯净 Dart，无 flutter 依赖）
SMOKE_FILES=(
  test/src/utils/byte_consumer_test.dart
  test/src/utils/debugger_test.dart
  test/src/utils/debugger_extended_test.dart
  test/src/utils/lookup_table_test.dart
)

GOLDEN_FILE="test/src/terminal_view_test.dart"

# ─── 函数 ────────────────────────────────────────────────────────────

run_flutter() {
  local label="$1" && shift
  echo "═══ ${label} ═══"
  set -x
  flutter test \
    ${UPDATE_GOLDENS:+--update-goldens} \
    --test-randomize-ordering-seed="$SEED" \
    "$@"
}

run_smoke() {
  echo "═══ SMOKE TEST (dart test, ${#SMOKE_FILES[@]} files) ═══"
  for f in "${SMOKE_FILES[@]}"; do
    printf '  %-65s … ' "$f"
    if dart test "$f" >/dev/null 2>&1; then
      echo 'PASS'
    else
      echo 'FAIL'
      dart test "$f" 2>&1 | tail -10
      exit 1
    fi
  done
  echo "═══ All PASS ═══"
}

run_fuzz() {
  local n="${1:-5}"
  echo "═══ FUZZ: ${n} random seeds ═══"
  local overall=true
  for ((i=0; i<n; i++)); do
    s=$((RANDOM % 100000 + 1))
    printf '[%2d/%d] seed=%5d … ' $((i+1)) "$n" "$s"
    if flutter test --test-randomize-ordering-seed="$s" >/dev/null 2>&1; then
      echo 'PASS'
    else
      echo 'FAIL'
      overall=false
    fi
  done
  if [ "$overall" = false ]; then
    echo "⚠️  部分种子失败" >&2
    exit 1
  fi
  echo "═══ 全部 ${n} 个种子 PASS ═══"
}

# ─── 入口 ────────────────────────────────────────────────────────────

mode="${1:-full}"

case "$mode" in
  smoke)  run_smoke ;;
  golden) run_flutter "GOLDEN TEST" "$GOLDEN_FILE" ;;
  fuzz)   run_fuzz "${2:-5}" ;;
  full)   run_flutter "FULL TEST (seed=${SEED})" ;;
  *)      run_flutter "CUSTOM: ${mode}" "$mode" ;;
esac
