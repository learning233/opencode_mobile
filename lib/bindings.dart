import 'package:get/get.dart';
import 'controllers/project_controller.dart';
import 'controllers/pty_controller.dart';
import 'controllers/session_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/tablet_tool_controller.dart';
import 'services/app_feedback_service.dart';

class GlobalBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ProjectController>(ProjectController(), permanent: true);
    Get.put<SessionController>(SessionController(), permanent: true);
    Get.put<SettingsController>(SettingsController(), permanent: true);
    Get.put<PtyController>(PtyController(), permanent: true);
    Get.put<TabletToolController>(TabletToolController(), permanent: true);
    Get.put<AppFeedbackService>(AppFeedbackService(), permanent: true);
  }
}
