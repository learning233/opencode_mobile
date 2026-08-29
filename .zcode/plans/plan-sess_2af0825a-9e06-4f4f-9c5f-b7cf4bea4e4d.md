# 隐藏项目功能实现计划

**语义**：隐藏是纯本地行为——仅让项目从 drawer 列表消失，不影响激活状态/会话/SSE；隐藏激活项目时功能一切照旧。取消隐藏立即恢复显示。

## 1. 依赖
- `pubspec.yaml` dependencies 加 **`flutter_slidable: ^4.0.3`**，`flutter pub get`。

## 2. 持久层 `lib/utils/app_settings_store.dart`
- 新 key `_hiddenProjects = 'hidden_projects'`（stringList，存归一化 worktree 路径）。
- `getHiddenProjects()` / `setHiddenProjects(List<String>)`（写时 normalize + 去重），仿照 `hiddenModels`（:279-292）。

## 3. 控制器 `lib/controllers/project_controller.dart`
- 新增 `hiddenProjectKeys = <String>[].obs`，构造/onInit 时从 `Global.settings.getHiddenProjects()` 载入。
- `isProjectHidden(p)` = `hiddenProjectKeys.contains(normalizeDirectory(p.worktree))`（复用 :217-223 静态方法；不用 id，因本地项目 id 会被服务端哈希替换）。
- `hideProject(p)`：key 加入 Rx + 写库（用户主动操作，写库无争议）。
- `unhideProjectByKey(key)`：从 Rx 移除 + 写库。
- **不改 `fetchProjects()` 数据本体、不动 `_restoreLastProject()`**：过滤在 UI 层做（Obx 同时读 `projects` 与 `hiddenProjectKeys`，GetX 自动响应）。这样 localOnly 项目被拼回（:89-95）、隐藏项目被恢复为激活（:41-46）都不会破坏隐藏状态。

## 4. UI `lib/pages/left_drawer/left_panel_content.dart`
- `_buildProjectsMode`（:134-239）：
  - 列表数据改为 `projects.where((p) => !isProjectHidden(p))`；空态/错误态/下拉刷新逻辑不变。
  - 每条包 `Slidable(endToStart)`：左滑露出"隐藏"按钮（visibility_off 图标）→ 点按钮弹确认框（文案说明"仅从列表隐藏，可随时在已隐藏项目中恢复"）→ `hideProject`。`ProjectTile` 本体不动，包装在外层。
  - 列表尾部追加"已隐藏项目"分组（`hiddenProjectKeys` 为空时整块不渲染）：
    - 折叠头对齐 mode-switcher tile 样式（:312-343：dense ListTile、18px 图标、13px w600、trailing chevron 随展开旋转），标题"已隐藏项目 (N)"；
    - 展开区每行：项目名（匹配 `projects` 中的对象取 displayName，匹配不到则取路径末段）+ worktree 副标题 + trailing"取消隐藏"按钮 → `unhideProjectByKey`（恢复无破坏性，不需确认）。
- 需要一个局部 StatefulWidget 持有展开/收起状态。

## 5. 多语言 `lib/utils/translations.dart`（三处）
- LocaleKeys mobile 段（:840 附近）+ `_zhCN`（:1964-2030）+ `_enUS`（:3155-3228）：
  - `mobileHiddenProjects`：已隐藏项目 / Hidden projects
  - `mobileHideProject`：隐藏项目 / Hide project
  - `mobileHideProjectConfirm`：确定隐藏"{name}"吗？仅从列表隐藏，可随时恢复。/ Hide "{name}" from the list? You can restore it anytime.（`.trParams` 用法见 :2011）
  - `mobileUnhideProject`：取消隐藏 / Unhide

## 6. 验证
- `flutter analyze` 通过。
- 手动核对：隐藏/取消隐藏即时生效；隐藏当前激活项目后会话不中断；杀进程重启后隐藏保留；下拉刷新、localOnly 项目拼回后仍保持隐藏；隐藏列表为空时分组不显示。

## 明确不做
- 不加服务器隔离维度（全局按路径）；不碰后端接口；不提供 toast 撤销（`Snack` 不支持 action，恢复走已隐藏分组）。