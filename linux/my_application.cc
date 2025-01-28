#include "my_application.h"
#include <url_launcher_linux/url_launcher_plugin.h>

// ... 其他代码保持不变 ...

static void my_application_init(MyApplication* self) {
  g_autoptr(FlUrlLauncherPlugin) url_launcher_plugin = fl_url_launcher_plugin_new();
} 