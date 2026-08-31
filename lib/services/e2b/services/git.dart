import 'commands.dart';
import '../models/process_models.dart';

/// E2B Git 操作封装服务 (对应 JS SDK Git)
class Git {
  final Commands commands;

  Git({required this.commands});

  /// 克隆仓库到指定目录
  Future<CommandResult> clone(
    String repoUrl, {
    String? targetDir,
    String? branch,
  }) async {
    final args = <String>['clone'];
    if (branch != null && branch.isNotEmpty) {
      args.addAll(['-b', branch]);
    }
    args.add(repoUrl);
    if (targetDir != null && targetDir.isNotEmpty) {
      args.add(targetDir);
    }

    final cmd = 'git ${args.join(" ")}';
    return commands.run(
      cmd,
      opts: const CommandOpts(
        envs: {'GIT_TERMINAL_PROMPT': '0'},
      ),
    );
  }

  /// 检出指定分支
  Future<CommandResult> checkout(String branch, {String? cwd}) async {
    return commands.run(
      'git checkout $branch',
      opts: CommandOpts(cwd: cwd),
    );
  }

  /// 获取当前 Git 状态 (简略格式)
  Future<String> status({String? cwd}) async {
    final result = await commands.run(
      'git status --porcelain',
      opts: CommandOpts(cwd: cwd),
    );
    return result.stdout.trim();
  }

  /// 提交变更
  Future<CommandResult> commit(String message, {String? cwd}) async {
    final escapedMsg = message.replaceAll('"', '\\"');
    return commands.run(
      'git add -A && git commit -m "$escapedMsg"',
      opts: CommandOpts(cwd: cwd),
    );
  }

  /// 推送至远端
  Future<CommandResult> push({String? remote = 'origin', String? branch, String? cwd}) async {
    final branchArg = (branch != null && branch.isNotEmpty) ? ' $branch' : '';
    return commands.run(
      'git push $remote$branchArg',
      opts: CommandOpts(
        cwd: cwd,
        envs: const {'GIT_TERMINAL_PROMPT': '0'},
      ),
    );
  }
}
