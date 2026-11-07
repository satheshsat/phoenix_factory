#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <gio/gio.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Automatically integrates desktop entry and icons into ~/.local/share
// when the application is launched from an extracted portable zip or directory.
static void register_desktop_entry_if_needed(const gchar* exe_path, const gchar* exe_dir) {
  if (exe_path == nullptr || exe_dir == nullptr) {
    return;
  }

  const gchar* data_dir = g_get_user_data_dir();
  g_autofree gchar* apps_dir = g_build_filename(data_dir, "applications", nullptr);
  g_autofree gchar* desktop_path = g_build_filename(apps_dir, APPLICATION_ID ".desktop", nullptr);

  gboolean needs_write = TRUE;
  if (g_file_test(desktop_path, G_FILE_TEST_EXISTS)) {
    g_autoptr(GKeyFile) key_file = g_key_file_new();
    if (g_key_file_load_from_file(key_file, desktop_path, G_KEY_FILE_NONE, nullptr)) {
      g_autofree gchar* exec_val = g_key_file_get_string(key_file, "Desktop Entry", "Exec", nullptr);
      if (exec_val != nullptr && g_str_has_prefix(exec_val, exe_path)) {
        needs_write = FALSE;
      }
    }
  }

  if (needs_write) {
    g_mkdir_with_parents(apps_dir, 0755);

    // Install hicolor icons to ~/.local/share/icons/hicolor/
    const gchar* icon_sizes[] = {"16x16", "24x24", "32x32", "48x48", "64x64", "128x128", "256x256", "512x512", nullptr};
    for (int i = 0; icon_sizes[i] != nullptr; ++i) {
      g_autofree gchar* src_icon = g_build_filename(
          exe_dir, "share", "icons", "hicolor", icon_sizes[i], "apps", APPLICATION_ID ".png", nullptr);
      if (g_file_test(src_icon, G_FILE_TEST_EXISTS)) {
        g_autofree gchar* target_icon_dir = g_build_filename(
            data_dir, "icons", "hicolor", icon_sizes[i], "apps", nullptr);
        g_mkdir_with_parents(target_icon_dir, 0755);
        g_autofree gchar* target_icon = g_build_filename(
            target_icon_dir, APPLICATION_ID ".png", nullptr);

        g_autoptr(GFile) src = g_file_new_for_path(src_icon);
        g_autoptr(GFile) dst = g_file_new_for_path(target_icon);
        g_file_copy(src, dst, G_FILE_COPY_OVERWRITE, nullptr, nullptr, nullptr, nullptr);
      }
    }

    // Fallback: If share/icons was not present, install from flutter_assets
    g_autofree gchar* fallback_asset_icon = g_build_filename(
        exe_dir, "data", "flutter_assets", "assets", "icon", "app_icon.png", nullptr);
    if (g_file_test(fallback_asset_icon, G_FILE_TEST_EXISTS)) {
      g_autofree gchar* target_icon_dir = g_build_filename(
          data_dir, "icons", "hicolor", "512x512", "apps", nullptr);
      g_mkdir_with_parents(target_icon_dir, 0755);
      g_autofree gchar* target_icon = g_build_filename(
          target_icon_dir, APPLICATION_ID ".png", nullptr);

      g_autoptr(GFile) src = g_file_new_for_path(fallback_asset_icon);
      g_autoptr(GFile) dst = g_file_new_for_path(target_icon);
      g_file_copy(src, dst, G_FILE_COPY_OVERWRITE, nullptr, nullptr, nullptr, nullptr);
    }

    // Prefer explicit absolute path to installed icon so all desktop environments
    // display it immediately without waiting for icon cache rebuilds
    g_autofree gchar* primary_icon_file = g_build_filename(
        data_dir, "icons", "hicolor", "256x256", "apps", APPLICATION_ID ".png", nullptr);
    const gchar* icon_val = g_file_test(primary_icon_file, G_FILE_TEST_EXISTS)
        ? primary_icon_file
        : APPLICATION_ID;

    // Write desktop entry with absolute Exec path, Path, and StartupWMClass
    g_autofree gchar* desktop_content = g_strdup_printf(
        "[Desktop Entry]\n"
        "Version=1.0\n"
        "Type=Application\n"
        "Name=Phoenix Factory\n"
        "GenericName=Media Converter\n"
        "Comment=Universal Media Converter Suite\n"
        "Exec=\"%s\" %%U\n"
        "Path=%s\n"
        "Icon=%s\n"
        "Terminal=false\n"
        "Categories=AudioVideo;AudioVideoEditing;Audio;Video;Graphics;Utility;\n"
        "Keywords=Converter;Video;Audio;Picture;Format;Factory;FFmpeg;Transcoder;\n"
        "StartupNotify=true\n"
        "StartupWMClass=%s\n",
        exe_path, exe_dir, icon_val, APPLICATION_ID);

    g_file_set_contents(desktop_path, desktop_content, -1, nullptr);

    // Refresh desktop database and icon cache if available
    const gchar* db_argv[] = {"update-desktop-database", apps_dir, nullptr};
    g_spawn_async(nullptr, (gchar**)db_argv, nullptr, G_SPAWN_SEARCH_PATH, nullptr, nullptr, nullptr, nullptr);

    g_autofree gchar* icons_dir = g_build_filename(data_dir, "icons", "hicolor", nullptr);
    const gchar* ic_argv[] = {"gtk-update-icon-cache", "-f", "-t", icons_dir, nullptr};
    g_spawn_async(nullptr, (gchar**)ic_argv, nullptr, G_SPAWN_SEARCH_PATH, nullptr, nullptr, nullptr, nullptr);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Phoenix Factory");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Phoenix Factory");
  }

  // Determine executable location to set window icons using absolute paths
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar* exe_dir = exe_path ? g_path_get_dirname(exe_path) : nullptr;

  if (exe_dir != nullptr) {
    // Add bundled share/icons to GTK Icon Theme search paths
    g_autofree gchar* bundle_icons = g_build_filename(exe_dir, "share", "icons", nullptr);
    if (g_file_test(bundle_icons, G_FILE_TEST_IS_DIR)) {
      gtk_icon_theme_append_search_path(gtk_icon_theme_get_default(), bundle_icons);
    }

    // Look for window icon from bundle assets or hicolor icons
    g_autofree gchar* asset_icon = g_build_filename(
        exe_dir, "data", "flutter_assets", "assets", "icon", "app_icon.png", nullptr);
    g_autofree gchar* hicolor_icon = g_build_filename(
        exe_dir, "share", "icons", "hicolor", "256x256", "apps", APPLICATION_ID ".png", nullptr);

    const gchar* chosen_icon = nullptr;
    if (g_file_test(asset_icon, G_FILE_TEST_EXISTS)) {
      chosen_icon = asset_icon;
    } else if (g_file_test(hicolor_icon, G_FILE_TEST_EXISTS)) {
      chosen_icon = hicolor_icon;
    }

    if (chosen_icon != nullptr) {
      gtk_window_set_icon_from_file(window, chosen_icon, nullptr);
      gtk_window_set_default_icon_from_file(chosen_icon, nullptr);
    }
  }

  // Fallbacks using relative paths and icon name
  if (!gtk_window_get_icon(window)) {
    if (!gtk_window_set_icon_from_file(window, "data/flutter_assets/assets/icon/app_icon.png", nullptr)) {
      gtk_window_set_icon_from_file(window, "assets/icon/app_icon.png", nullptr);
    }
  }
  gtk_window_set_default_icon_name(APPLICATION_ID);

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // Perform desktop entry and icon integration on startup if running from portable/extracted folder
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path != nullptr) {
    g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
    register_desktop_entry_if_needed(exe_path, exe_dir);
  }

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
