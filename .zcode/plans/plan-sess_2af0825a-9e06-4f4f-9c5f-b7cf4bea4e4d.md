决策：**暂不从 v1 迁移到 v2，维持"v1 主干 + v2 补丁"现状，不做任何代码改动。**

理由摘要：
1. v1 无移除风险：仍是官方文档（server.mdx）记载的主 API、SDK 主入口唯一来源、e2e 测试强制覆盖对象，无 deprecation 时间表；唯一标注 deprecated 的 v1 端点（`POST /session/{id}/permissions/{permissionID}`）本客户端未使用。
2. v2 是基于新领域模型的并行 API（响应信封、prompt 准入语义、SSE 事件格式与事件名全部不同），迁移是重写级成本，非换前缀。
3. v2 缺口过大：移动端依赖的 /file、/vcs/diff、/mcp、/config/providers、/project、/lsp、/formatter、session fork/summarize 等 v2 均无对应，完整迁移路径尚不存在。
4. v2 仍是 beta，wire contract 近期有多次破坏性调整，现在迁移成本最高。

后续动作：
- 唯一可选的小修正：更新 `docs_my/endpoint_comparison.md:21`，该行写"Flutter 用 GET /api/event"与代码不符（实际为 v1 `GET /event`，见 session_controller.dart:2140），属文档过期，顺手修正。
- 建立跟踪信号（无需立即行动）：当 server.mdx 出现 /api 章节、@opencode-ai/sdk 主入口被 sdk-next 替换、"until removal" 措辞蔓延到 session/file handler、或 v2 补齐 /file /vcs /mcp /config /project 时，重新评估迁移。