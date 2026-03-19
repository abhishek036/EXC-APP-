PS C:\Users\Admin\Pictures\COACHING APP> ^C
PS C:\Users\Admin\Pictures\COACHING APP> cd 'c:\Users\Admin\Pictures\COACHING APP\coachpro'
PS C:\Users\Admin\Pictures\COACHING APP\coachpro> python fix_toasts.py
Updated c:\Users\Admin\Pictures\COACHING APP\coachpro\lib\features\admin\presentation\pages\add_student_page.dart
Updated c:\Users\Admin\Pictures\COACHING APP\coachpro\lib\features\admin\presentation\pages\announcements_page.dart
Updated c:\Users\Admin\Pictures\COACHING APP\coachpro\lib\features\admin\presentation\pages\attendance_overview_page.dart
Updated c:\Users\Admin\Pictures\COACHING APP\coachpro\lib\features\admin\presentation\pages\batch_management_page.dart
Updated c:\Users\Admin\Pictures\COACHING APP\coachpro\lib\features\admin\presentation\pages\exam_management_page.dart
Updated c:\Users\Admin\Pictures\COACHING APP\coachpro\lib\features\admin\presentation\pages\fee_collection_page.dart
Updated c:\Users\Admin\Pictures\COACHING APP\coachpro\lib\features\admin\presentation\pages\student_profile_page.dart
PS C:\Users\Admin\Pictures\COACHING APP\coachpro> cd 'c:\Users\Admin\Pictures\COACHING APP\coachpro'
PS C:\Users\Admin\Pictures\COACHING APP\coachpro> flutter run -d chrome
Launching lib\main.dart on Chrome in debug mode...
Waiting for connection from debug service on Chrome...             67.7s

Flutter run key commands.
r Hot reload. 
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

Debug service listening on ws://127.0.0.1:64297/YQmlwQQHwiU=/ws
A Dart VM Service on Chrome is available at: http://127.0.0.1:64297/YQmlwQQHwiU=
The Flutter DevTools debugger and profiler on Chrome is available at:
http://127.0.0.1:64297/YQmlwQQHwiU=/devtools/?uri=ws://127.0.0.1:64297/YQmlwQQHwiU=/ws
Starting application from main method in: org-dartlang-app:/web_entrypoint.dart.
Firebase initialization skipped: Assertion failed:
file:///C:/Users/Admin/AppData/Local/Pub/Cache/hosted/pub.dev/firebase_core_web-2.24.1/lib/src/firebase_core_web.dart:288:11
options != null
"FirebaseOptions cannot be null when creating the default app."
══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══════════════════════════════════════════════════════════
The following FirebaseException was thrown building BlocBuilder<AuthBloc, AuthState>(bloc: null, has
builder, dirty, dependencies: [InheritedCupertinoTheme, _InheritedProviderScope<AuthBloc?>,
_InheritedTheme, _LocalizationsScope-[GlobalKey#8d96c]], state: _BlocBuilderBaseState<AuthBloc,
AuthState>#e92c0):
[firebase_core/not-initialized] Firebase is not initialized. Configure Firebase for this platform
and restart the app.

The relevant error-causing widget was:
  BlocBuilder<AuthBloc, AuthState>
  BlocBuilder:file:///C:/Users/Admin/Pictures/COACHING%20APP/coachpro/lib/features/shared/presentation/pages/role_live_dashboard_page.dart:1
  05:12

When the exception was thrown, this was the stack:
dart-sdk/lib/_internal/js_dev_runtime/private/ddc_runtime/errors.dart 274:3               throw_
package:coachpro/core/services/firebase_auth_service.dart 25:7                            [_ensureFirebaseReady]
package:coachpro/core/services/firebase_auth_service.dart 192:5                           streamRoleDashboard
package:coachpro/features/shared/presentation/pages/role_live_dashboard_page.dart 118:30  <fn>
package:flutter_bloc/src/bloc_builder.dart 91:57                                          build
package:flutter_bloc/src/bloc_builder.dart 188:21                                         build
package:flutter/src/widgets/framework.dart 5931:27                                        build
package:flutter/src/widgets/framework.dart 5817:15                                        performRebuild
package:flutter/src/widgets/framework.dart 5982:11                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 5799:5                                         [_firstBuild]
package:flutter/src/widgets/framework.dart 5973:11                                        [_firstBuild]
package:flutter/src/widgets/framework.dart 5793:5                                         mount
...     Normal element mounting (180 frames)
package:flutter/src/widgets/framework.dart 4587:19                                        inflateWidget
package:flutter/src/widgets/framework.dart 7264:36                                        inflateWidget
package:flutter/src/widgets/framework.dart 7279:32                                        mount
...     Normal element mounting (168 frames)
package:flutter/src/widgets/framework.dart 4587:19                                        inflateWidget
package:flutter/src/widgets/framework.dart 7264:36                                        inflateWidget
package:flutter/src/widgets/framework.dart 7279:32                                        mount
...     Normal element mounting (45 frames)
package:flutter/src/widgets/framework.dart 4587:19                                        inflateWidget
package:flutter/src/widgets/framework.dart 7264:36                                        inflateWidget
package:flutter/src/widgets/framework.dart 7279:32                                        mount
...     Normal element mounting (142 frames)
package:flutter/src/widgets/framework.dart 4587:19                                        inflateWidget
package:flutter/src/widgets/framework.dart 7264:36                                        inflateWidget
package:flutter/src/widgets/framework.dart 7279:32                                        mount
...     Normal element mounting (194 frames)
package:flutter/src/widgets/framework.dart 4587:19                                        inflateWidget
package:flutter/src/widgets/framework.dart 7264:36                                        inflateWidget
package:flutter/src/widgets/framework.dart 4059:18                                        updateChild
package:flutter/src/widgets/framework.dart 4255:32                                        updateChildren
package:flutter/src/widgets/framework.dart 7295:17                                        update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5982:11                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6007:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6149:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6149:5                                         update
package:flutter/src/widgets/inherited_notifier.dart 108:11                                update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5982:11                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6007:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6149:5                                         update
package:flutter/src/widgets/inherited_notifier.dart 108:11                                update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5982:11                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6007:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5982:11                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6007:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 7122:14                                        update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 7122:14                                        update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6149:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6149:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5982:11                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6007:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6149:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6149:5                                         update
package:flutter/src/widgets/inherited_notifier.dart 108:11                                update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5982:11                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6007:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6149:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 5895:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6149:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 6149:5                                         update
package:flutter/src/widgets/framework.dart 4037:14                                        updateChild
package:flutter/src/widgets/framework.dart 5841:16                                        performRebuild
package:flutter/src/widgets/framework.dart 5982:11                                        performRebuild
package:flutter/src/widgets/framework.dart 5529:7                                         rebuild
package:flutter/src/widgets/framework.dart 2750:14                                        [_tryRebuild]
package:flutter/src/widgets/framework.dart 2807:11                                        [_flushDirtyElements]
package:flutter/src/widgets/framework.dart 3111:17                                        buildScope
package:flutter/src/widgets/binding.dart 1302:9                                           drawFrame
package:flutter/src/rendering/binding.dart 495:5                                          [_handlePersistentFrameCallback]
dart-sdk/lib/_internal/js_dev_runtime/private/ddc_runtime/operations.dart 118:77          tear
package:flutter/src/scheduler/binding.dart 1430:7                                         [_invokeFrameCallback]
package:flutter/src/scheduler/binding.dart 1345:9                                         handleDrawFrame
package:flutter/src/scheduler/binding.dart 1198:5                                         [_handleDrawFrame]
dart-sdk/lib/_internal/js_dev_runtime/private/ddc_runtime/operations.dart 118:77          tear
lib/_engine/engine/platform_dispatcher.dart 1689:5                                        invoke
lib/_engine/engine/platform_dispatcher.dart 265:5                                         invokeOnDrawFrame
lib/_engine/engine/frame_service.dart 209:32                                              [_renderFrame]
lib/_engine/engine/frame_service.dart 117:9                                               <fn>
dart-sdk/lib/async/zone.dart 962:54                                                       runUnary
dart-sdk/lib/async/zone.dart 917:26                                                       <fn>
dart-sdk/lib/_internal/js_dev_runtime/patch/js_allow_interop_patch.dart 224:27            _callDartFunctionFast1
dart-sdk/lib/_internal/js_dev_runtime/patch/js_allow_interop_patch.dart 84:15             ret

════════════════════════════════════════════════════════════════════════════════════════════════════
