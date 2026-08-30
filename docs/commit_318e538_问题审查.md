# Commit 318e538 问题审查报告

- **目标 Commit**：`318e5383b37ea0a260c6e9226afe2ecb061b0b16`
- **提交信息**：`9、10`
- **审查日期**：2026-08-30
- **核实日期**：2026-08-30（对照代码与本地 `clone/opencode` 后端源码逐条核实，6 条中 5 条属实、1 条属实但后果夸大；已全部修复）

---

## 审查问题清单

### 1. [P1 · 严重缺陷] `_doUpdateGlobalConfig` 响应未解包 `data`，导致全部全局配置 Getter 瘫痪

> **核实结论：部分属实。** 代码不一致确实存在（同文件其他方法均走 `_configMapFromResponse` 解包），但"全部 getter 瘫痪"的后果在当前后端下**不会发生**：v1 `/global/config` 的 handler 直接返回裸 `ConfigV1.Info`（`clone/opencode/.../handlers/global.ts` 中 `return result.info`），`{data: ...}` 包装仅出现在 v2 handler 中，`docs/api_endpoints.md` 亦标注 v1 裸返回。实际定级应为 P3 潜在隐患（后端若改为包装返回即触发）。
> **已修复**：改用 `_configMapFromResponse` 解包，失败回退 `fetchGlobalConfig()`。

- **涉及文件**：[`lib/controllers/settings_controller.dart`](file:///d:/project/FlutterProject/opencode_mobile/lib/controllers/settings_controller.dart#L550-L554)
- **代码位置**：
  ```dart
  if (response.statusCode == 200 || response.statusCode == 204) {
    if (response.statusCode == 200 && response.data is Map) {
      globalConfig.value = Map<String, dynamic>.from(response.data as Map);
    } else {
      await fetchGlobalConfig();
    }
    return true;
  }
  ```
- **问题分析**：
  在 `fetchGlobalConfig()`、`fetchProjectConfig()` 以及 `patchProjectConfig()` 中，均使用 `_configMapFromResponse(res.data)` 来解包后端可能返回的 `{ "data": { ... } }` 格式。
  `_doUpdateGlobalConfig` 在 PATCH 成功返回 200 时，直接将 `response.data` 强转为 `globalConfig.value`。若服务端返回的是 `{ "data": { "agent": ..., "mcp": ... } }` 包装，`globalConfig.value` 就会变成包含 `data` 外壳的 Map。
- **引发后果**：
  所有依赖 `globalConfig.value` 的 getter（如 `permission`、`compaction`、`shareMode`、`username`、`shell`、`logLevel`、`smallModel`、`skillsConfig`、`instructionPaths`、`mcp` 等）全部读取为 `null` 或空，直至下次触发全量 `fetchGlobalConfig`。
- **建议修复**：
  ```dart
  if (response.statusCode == 200 && response.data != null) {
    final updated = _configMapFromResponse(response.data);
    if (updated != null) {
      globalConfig.value = updated;
    } else {
      await fetchGlobalConfig();
    }
  } else {
    await fetchGlobalConfig();
  }
  ```

---

### 2. [P1 · 状态破坏] `_doUpdateGlobalConfig` 乐观更新使用浅层 Map 覆盖，清空同级其他配置

> **核实结论：属实。** `Map.addAll` 顶层浅覆盖，patch 的 `agent`/`permission`/`mcp` 等二级命名空间子集会替换整个命名空间，在途窗口内相关 getter 读到残缺数据（成功后由响应回填恢复，故为短暂破坏）。
> **已修复**：乐观更新改为与服务端 `mergeDeep` 语义一致的递归深合并（`_deepMergeConfig`）。

- **涉及文件**：[`lib/controllers/settings_controller.dart`](file:///d:/project/FlutterProject/opencode_mobile/lib/controllers/settings_controller.dart#L538-L542)
- **代码位置**：
  ```dart
  final originalConfig = globalConfig.value;
  if (originalConfig != null) {
    globalConfig.value = Map<String, dynamic>.from(originalConfig)
      ..addAll(patch);
  }
  ```
- **问题分析**：
  `Map.addAll(patch)` 是顶层 key 的浅覆盖。
  当提交的是子命名空间变更（例如 `patch = {'agent': {'my_agent': {'hidden': true}}}` 或 `patch = {'permission': {'bash': 'deny'}}` 或 `patch = {'mcp': {'foo': {'enabled': false}}}`）时，`..addAll(patch)` 会将原本的整个 `agent` / `permission` / `mcp` Map 替换成只含有该子项的 Map。
- **引发后果**：
  在网络请求在途期间，其余所有的 Agent、权限规则或 MCP 配置项在本地内存中被短暂清空，导致监听相关状态的 UI 组件出现剧烈闪烁或误判为空态。
- **建议修复**：
  乐观更新需要做深合并（Deep Merge），或在没有深合并工具时，仅在 PATCH 成功后由响应回填 `globalConfig.value`，避免在网络请求前进行破坏性的浅覆盖。

---

### 3. [P2 · 逻辑闭环缺陷] Agent 软删除后重新创建同名 Agent 失败（`hidden: true` 残留）

> **核实结论：属实。** 全链路已验证：后端 `Config.updateGlobal` 使用 `mergeDeep`（`clone/opencode/.../config/config.ts`），`hidden: true` 持久保留；`_NewAgentSheet` 构造的 `AgentDetailInfo` 的 `raw` 为 `const {}`，`toJson()` 不含 `hidden` 键；`fetchAgents` 过滤 `hidden == true`；名称校验用 `availableAgents`（不含隐藏项）故校验通过。
> **已修复**：新建与保存（含重命名路径）提交时显式带 `'hidden': false`。

- **涉及文件**：
  - [`lib/controllers/settings_controller.dart`](file:///d:/project/FlutterProject/opencode_mobile/lib/controllers/settings_controller.dart#L905-L909)
  - [`lib/pages/settings/opencode/agent_page.dart`](file:///d:/project/FlutterProject/opencode_mobile/lib/pages/settings/opencode/agent_page.dart#L97-L100)
- **问题分析**：
  1. 服务端 PATCH `/global/config` 底层是 `mergeDeep` 深度合并。客户端为了删除 Agent，在 `deleteAgent` 中提交了 `{'agent': {name: {'hidden': true}}}`，使得服务端配置持久化了 `"hidden": true`。
  2. 客户端在 `fetchAgents()` 中过滤掉了 `hidden == true` 的条目。
  3. 当用户在 `_NewAgentSheet` 重新创建同名 Agent 时，名称校验通过（`availableAgents` 中已无此名称）。
  4. 新建提交时执行 `_settings.setAgentConfig({result.name: result.toJson()})`。然而 `AgentDetailInfo.toJson()` **不包含** `'hidden': false`。
  5. 服务端深合并后，原本旧配置中的 `"hidden": true` **依然保留**。随后 `fetchAgents()` 拉取列表，该新 Agent 再次因为 `hidden == true` 被直接过滤掉。
  *(注：MCP 模块在 `createMcpServer` 中显式包含了 `'enabled': true` 来重置软删除状态，但 Agent 模块遗漏了此处理)*。
- **建议修复**：
  在新建/保存 Agent 提交时，显式带上 `'hidden': false`：
  ```dart
  final ok = await _settings.setAgentConfig({
    result.name: {
      ...result.toJson(),
      'hidden': false,
    },
  });
  ```
  同理在 `_AgentExpansionTile.onSave` 中：
  ```dart
  return _settings.setAgentConfig({
    if (updated.name != agent.name) agent.name: {'hidden': true},
    updated.name: {
      ...updated.toJson(),
      'hidden': false,
    },
  });
  ```

---

### 4. [P2 · 交互文案错误] 多个设置页面失败提示误用操作按钮文本

> **核实结论：属实，且范围更大。** 报告列出的调用点全部核实存在（general_page 实际在第 50 行）；另发现报告漏列的同类点：agent_page `_AgentExpansionTile._save`、developer_page 2 处 save、permissions_page 1 处 delete、advanced_page 4 处、experimental_page 3 处。细节修正：`Snack.error` 自带"出错"标题（`snackbar_error`），实际显示为「出错：保存」，并非纯按钮文案。
> **已修复**：新增 `saveFailed`（保存失败/Save failed）、`deleteFailed`（删除失败/Delete failed）键并替换全部误用点。

- **涉及文件与行号**：
  - [`lib/pages/settings/opencode/models_page.dart:124`](file:///d:/project/FlutterProject/opencode_mobile/lib/pages/settings/opencode/models_page.dart#L124) (`Snack.error(LocaleKeys.save.tr)`)
  - [`lib/pages/settings/opencode/permissions_page.dart:82, 121`](file:///d:/project/FlutterProject/opencode_mobile/lib/pages/settings/opencode/permissions_page.dart#L82) (`Snack.error(LocaleKeys.save.tr)`)
  - [`lib/pages/settings/opencode/rules_page.dart:236, 264`](file:///d:/project/FlutterProject/opencode_mobile/lib/pages/settings/opencode/rules_page.dart#L236) (`Snack.error(LocaleKeys.save.tr)`)
  - [`lib/pages/settings/opencode/general_page.dart:49`](file:///d:/project/FlutterProject/opencode_mobile/lib/pages/settings/opencode/general_page.dart#L49) (`Snack.error(LocaleKeys.save.tr)`)
  - [`lib/pages/settings/opencode/lsp_page.dart:85, 123`](file:///d:/project/FlutterProject/opencode_mobile/lib/pages/settings/opencode/lsp_page.dart#L85) (`Snack.error(LocaleKeys.save.tr)`)
  - [`lib/pages/settings/opencode/agent_page.dart:132`](file:///d:/project/FlutterProject/opencode_mobile/lib/pages/settings/opencode/agent_page.dart#L132) (`Snack.error(LocaleKeys.delete.tr)`)
  - [`lib/pages/settings/opencode/developer_page.dart:92, 131, 147`](file:///d:/project/FlutterProject/opencode_mobile/lib/pages/settings/opencode/developer_page.dart#L92) (`Snack.error(LocaleKeys.save.tr)` / `Snack.error(LocaleKeys.delete.tr)`)
- **问题分析**：
  控制器方法在由抛出异常改为返回 `Future<bool>` 后，UI 侧将 `catch (e)` 改为了判断 `!ok`。但错误反馈文案直接传入了 `LocaleKeys.save.tr`（翻译为 **“保存” / “Save”**）或 `LocaleKeys.delete.tr`（翻译为 **“删除” / “Delete”**）。
- **引发后果**：
  当网络断开或服务端返回 4xx/5xx 时，弹出的红色错误 Toast 标题/内容直接显示为 **“保存”** 或 **“删除”**，完全无法起到“失败”提示的作用。
- **建议修复**：
  在 `translations.dart` 中使用明确的失败文案（如 `saveFailed` / `deleteFailed`，或页面专属 key）。

---

### 5. [P3 · UI 细节] 关于页面版本号异常时回退为 `"v未知"`

> **核实结论：属实。** fallback 时 `_version` 为「未知」文案，`displayVersion` 无条件拼 `'v'` 前缀，最终显示「v未知」。
> **已修复**：版本为未知文案时不拼前缀。

- **涉及文件**：[`lib/pages/settings/about_page.dart`](file:///d:/project/FlutterProject/opencode_mobile/lib/pages/settings/about_page.dart#L96-L117)
- **代码位置**：
  ```dart
  _version = LocaleKeys.mobileUnknown.tr; // "未知" / "Unknown"
  _buildNumber = '';
  ...
  final displayVersion = _buildNumber.isNotEmpty
      ? 'v$_version+$_buildNumber'
      : 'v$_version';
  ```
- **问题分析**：
  当 PackageInfo 读取失败进入 fallback 时，`_version` 被设为 `"未知"`，但 `displayVersion` 统一拼装了前缀 `'v'`，最终界面显示为 **`v未知`** 或 **`vUnknown`**。
- **建议修复**：
  若 `_version == LocaleKeys.mobileUnknown.tr`，直接展示 `_version`，不拼接 `'v'` 前缀。

---

### 6. [P3 · 竞态隐患] `custom_provider_page.dart` 异步拉取配置时可能先构建空 JSON

> **核实结论：属实。** 补充：除 initState 末尾的 `_onFieldChanged()` 外，`_providerIdCtrl.text` 赋值本身也会同步触发监听提前启动防抖，仅删一处不足以根治。
> **已修复**：编辑模式且配置拉取在途期间抑制字段→JSON 重建（`_loadingInitialConfig` 标志），回填（或失败）后解除抑制并显式重建一次。

- **涉及文件**：[`lib/pages/settings/opencode/custom_provider_page.dart`](file:///d:/project/FlutterProject/opencode_mobile/lib/pages/settings/opencode/custom_provider_page.dart#L86-L97)
- **问题分析**：
  在编辑模式进入且 `globalConfig` 尚未拉取时，`initState` 触发了异步方法 `_loadProviderConfig()`。但在 `initState` 结束前（第 96 行）同步调用了 `_onFieldChanged()`。
  `_onFieldChanged` 会启动 300ms 防抖定时器并执行 `_rebuildJsonFromFields()`。由于此时字段尚未从网络拉取回填，模型列表与名称均为空，会先行构建出一个空的 JSON 填入 JSON 编辑框，待网络返回后再被覆盖。

---

## 验证无误的改动汇总

1. **`sendPrompt` 失败回填**：`sendPrompt` 改为返回 `Future<bool>`，`prompt_input.dart` 在发送失败后回填输入框与附件栏，保证在异常时输入不丢失。
2. **后台 Isolate 批量压缩与 Base64 编码**：`compressAndEncodeImagesSync` 整合在同一后台 isolate 一次性完成，有效避免大图 base64 阻塞 UI 线程。
3. **`normalizeServerUrl` 规范化**：正确补齐 `http://` 并在根路径服务架构下剥离多余路径，防止健康检查 404。
4. **模型可见性写入串行化**：`AppSettingsStore.setModelVisibility` 加入 `_enqueuePrefsWrite` 串行锁，彻底杜绝快速连续切换可见性时的写覆盖并发竞争。
