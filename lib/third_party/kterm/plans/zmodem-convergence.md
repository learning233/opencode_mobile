# ✅ ZMODEM 收敛报告 — 计划已执行完毕

**状态**: 全部完成 (2025-07-16)
**执行者**: zmodem_lbp v0.0.10 + kterm.dart ZModemMux 38 tests
**架构**: parser/core 分离, 365 + 38 测试, CI 回归门禁

## 关键决策

- 计划中描述的内联实现架构已被 **zmodem_lbp v0.0.10** 替代
- Parser / Core / Mux 三层分离已在库层面实现
- 以下内容在 zmodem_lbp 中完成，kterm.dart 不重复实现

## 收敛对照表

| 计划要求 | 实现位置 | 状态 |
|----------|----------|------|
| 状态机显式化 | `ZModemCore` + `ZModemState` | ✅ |
| State Transition Table | `docs/zmodem_state_machine.md` | ✅ |
| Parser deterministic | `ZModemParser implements Iterator<ZFrame>` | ✅ |
| Fuzz Harness | `test/fuzz/` (5 files, 29 corpus entries) | ✅ |
| Random Byte Stream Fuzz | `fuzz_test.dart` (1M iterations) | ✅ |
| Fragmentation Fuzz | `fragmentation_fuzz_test.dart` | ✅ |
| Corrupted CRC Fuzz | `ZCrcErrorEvent` | ✅ |
| State Transition Fuzz | `state_transition_fuzz_test.dart` | ✅ |
| Replay System | 29 .bin corpus + `corpus_replay_test.dart` | ✅ |
| Timeout Testing | `timeout_test.dart` (30s/60s/10s) | ✅ |
| Memory Safety | 64KB `_maxDataSubpacketSize` | ✅ |
| Metrics | `lib/src/metrics.dart` (全部指标) | ✅ |
| Regression Gate | AGENTS.md "replay-first" 原则 | ✅ |
| Done checklist | 8项全部满足 | ✅ |

## kterm.dart 侧新增覆盖 (38 tests)

- 发送侧 onFileRequest 回调 + ZFILE 输出 (3 tests)
- 多会话顺序复用 (1 test: session→end→session→end)
- Dispose 清理 (2 tests: 普通/活跃中)
- Cancel 传播 (1 test: 5×CAN bytes 不崩溃)
- 原有 31 tests 保持不变

## 归档说明

此计划已被 zmodem_lbp v0.0.10 完整实现。未来 ZMODEM 协议相关改进应直接在 zmodem_lbp 仓库中提交，kterm.dart 侧仅维护集成层 (ZModemMux) 测试。

---

# 📄 ZMODEM 状态机验证 + Fuzz Harness 规范（原始内容，仅供参考）

## 🎯 目标

建立：

1. 可验证状态机
2. deterministic parser behavior
3. 自动 fuzz 系统
4. 自动 regression replay

目标不是增加测试数量。

目标是：

> 防止未来 refactor 再次引入协议级 bug

---

# 1. 状态机必须显式化（强制）

## 当前问题

当前状态机：

* 分散在 class
* transition 隐式存在
* parser/core/mux 相互影响

导致：

* impossible to verify
* impossible to fuzz correctly
* impossible to replay failures

---

# 2. 必须建立 State Transition Table

## 新建：

```text
docs/zmodem_state_machine.md
```

---

## 格式（强制）

每个 state：

```text
STATE: ZReceivingContentState

Allowed Inputs:
  - DataSubpacket(ZCRCG)
  - DataSubpacket(ZCRCQ)
  - DataSubpacket(ZCRCE)
  - ZEOF
  - ZFIN
  - Timeout

Transitions:
  DataSubpacket(ZCRCG) -> stay
  DataSubpacket(ZCRCQ) -> stay
  DataSubpacket(ZCRCE) -> stay
  ZEOF                  -> ZRinitState
  ZFIN                  -> ZFinState
  Timeout               -> ErrorRecoveryState

Forbidden:
  - ZFILE
  - ZSINIT
  - ZRINIT
```

---

# 3. Parser 必须 deterministic

## 定义

相同输入：

```text
same byte stream
```

必须：

```text
same frame sequence
```

无论：

* current state
* mux state
* user callback
* timing

---

## 强制规则

Parser：

```text
input bytes -> output frames only
```

不得：

* consume hidden flags
* branch on core state
* branch on application state

---

# 4. Fuzz Harness（核心）

## 新建：

```text
test/fuzz/
```

---

# 5. 必须实现的 fuzz 类型

---

## 5.1 Random Byte Stream Fuzz

### 目标

验证：

* no crash
* no infinite loop
* no unbounded allocation

---

### 示例

```dart
final random = Random();

for (int i = 0; i < 1000000; i++) {
  final bytes = Uint8List.fromList(
    List.generate(
      random.nextInt(512),
      (_) => random.nextInt(256),
    ),
  );

  parser.feed(bytes);
}
```

---

# 5.2 Fragmentation Fuzz（非常重要）

## 当前高风险区域

ZMODEM over:

* TCP
* PTY
* SSH

都可能：

```text
1 frame -> split into arbitrary chunks
```

---

## 必须测试：

```text
ZDATA
```

被拆成：

```text
Z
DA
TA
```

---

## 测试目标

Parser 行为必须完全一致：

```text
full packet == fragmented packet
```

---

# 5.3 Corrupted CRC Fuzz

必须：

* reject invalid CRC
* never silently accept

---

# 5.4 State Transition Fuzz（关键）

随机生成：

```text
valid but unexpected frame order
```

例如：

```text
ZEOF before ZDATA
ZFIN during DATA
ZRINIT during receive
```

---

## 目标

Core 必须：

* reject safely
* recover safely
* never deadlock

---

# 6. Replay System（非常重要）

## 每个 fuzz failure：

必须自动保存：

```text
test/fuzz/corpus/
```

格式：

```text
crash_0001.bin
hang_0002.bin
oom_0003.bin
```

---

# 7. Timeout Testing

必须新增：

```dart
fakeAsync(...)
```

测试：

* no response
* partial response
* stuck states

---

# 8. Memory Safety Rules

任何以下对象：

* BytesBuilder
* List<int>
* CSI params
* frame buffer

必须：

```text
bounded
```

---

# 9. 必须新增 Metrics

新增 debug metrics：

```dart
parser.framesParsed
parser.invalidCrcCount
parser.maxBufferSize
core.stateTransitions
core.timeoutCount
```

---

# 10. Regression Gate（关键）

任何 bug 修复：

必须：

```text
1. add failing testcase first
2. then fix
3. fuzz corpus must still pass
```

---

# 11. 成功标准（Definition of Done）

系统必须满足：

* [ ] parser deterministic
* [ ] no hidden parser state
* [ ] no infinite wait state
* [ ] CRC always enforced
* [ ] fuzz 1M iterations pass
* [ ] fragmented stream behavior stable
* [ ] replay corpus reproducible
* [ ] no unbounded memory growth

---

# 12. 最重要原则（必须遵守）

> 协议实现必须：
>
> 可验证
> 可重放
> 可恢复
> 可收敛

任何：

* hidden state
* silent discard
* implicit transition

都视为协议级 bug。
