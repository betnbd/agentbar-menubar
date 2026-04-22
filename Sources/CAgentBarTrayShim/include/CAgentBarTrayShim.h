#ifndef AGENTBAR_TRAY_SHIM_H
#define AGENTBAR_TRAY_SHIM_H

#include <gtk/gtk.h>
#include <libayatana-appindicator/app-indicator.h>

typedef void (*AgentBarSimpleCallback)(void *context);

int agentbar_gtk_init_check(void);

GtkWidget *agentbar_menu_new(void);
GtkWidget *agentbar_menu_item_new(const char *label);
GtkWidget *agentbar_separator_menu_item_new(void);
void agentbar_menu_append(GtkWidget *menu, GtkWidget *child);
GtkWidget *agentbar_box_new_vertical(gint spacing);
GtkWidget *agentbar_box_new_horizontal(gint spacing);
void agentbar_box_append(GtkWidget *box, GtkWidget *child, gboolean expand);
GtkWidget *agentbar_scrolled_window_new(void);
void agentbar_scrolled_window_set_child(GtkWidget *scrolled_window, GtkWidget *child);
GtkWidget *agentbar_label_new(const char *text);
void agentbar_label_set_text(GtkWidget *label, const char *text);
void agentbar_label_set_markup(GtkWidget *label, const char *markup);
void agentbar_label_set_xalign(GtkWidget *label, gfloat xalign);
void agentbar_label_set_line_wrap(GtkWidget *label, gboolean line_wrap);
GtkWidget *agentbar_button_new(const char *label);
void agentbar_button_set_label(GtkWidget *button, const char *label);
void agentbar_button_set_focus_on_click(GtkWidget *button, gboolean focus_on_click);
void agentbar_widget_show(GtkWidget *widget);
void agentbar_widget_show_all(GtkWidget *widget);
void agentbar_widget_set_sensitive(GtkWidget *widget, gboolean sensitive);
void agentbar_widget_set_margin_all(GtkWidget *widget, gint margin);
void agentbar_widget_set_name(GtkWidget *widget, const char *name);
void agentbar_widget_add_css_class(GtkWidget *widget, const char *class_name);
void agentbar_widget_remove_css_class(GtkWidget *widget, const char *class_name);
void agentbar_widget_set_hexpand(GtkWidget *widget, gboolean expand);
void agentbar_widget_set_vexpand(GtkWidget *widget, gboolean expand);
void agentbar_widget_set_can_focus(GtkWidget *widget, gboolean can_focus);
void agentbar_widget_destroy(GtkWidget *widget);
void agentbar_menu_item_set_label(GtkWidget *menu_item, const char *label);
GtkWidget *agentbar_window_new(const char *title, gint default_width, gint default_height);
void agentbar_window_set_child(GtkWidget *window, GtkWidget *child);
void agentbar_window_present(GtkWidget *window);
void agentbar_window_set_resizable(GtkWidget *window, gboolean resizable);
void agentbar_css_load(const char *css);

AppIndicator *agentbar_indicator_new(const char *identifier, const char *icon_name);
void agentbar_indicator_set_title(AppIndicator *indicator, const char *title);
void agentbar_indicator_set_status_active(AppIndicator *indicator);
void agentbar_indicator_set_status_passive(AppIndicator *indicator);
void agentbar_indicator_set_menu(AppIndicator *indicator, GtkWidget *menu);
void agentbar_indicator_set_label(AppIndicator *indicator, const char *label);
void agentbar_indicator_set_icon_full(AppIndicator *indicator, const char *icon_name, const char *icon_desc);
void agentbar_indicator_set_icon_theme_path(AppIndicator *indicator, const char *icon_theme_path);
void agentbar_indicator_set_secondary_activate_target(AppIndicator *indicator, GtkWidget *menu_item);

void agentbar_menu_item_connect_activate(
    GtkWidget *menu_item,
    AgentBarSimpleCallback callback,
    void *context);
void agentbar_button_connect_clicked(
    GtkWidget *button,
    AgentBarSimpleCallback callback,
    void *context);
void agentbar_window_connect_destroy(
    GtkWidget *window,
    AgentBarSimpleCallback callback,
    void *context);
void agentbar_invoke_on_main_thread(
    AgentBarSimpleCallback callback,
    void *context);

void agentbar_run_main_loop(void);
void agentbar_quit_main_loop(void);

#endif
