#include "CAgentBarTrayShim.h"

#include <glib.h>
#include <stdlib.h>

typedef struct {
    AgentBarSimpleCallback callback;
    void *context;
} AgentBarCallbackContext;

static GLogFunc agentbar_previous_default_log_handler = NULL;
static gpointer agentbar_previous_default_log_user_data = NULL;

static void agentbar_log_filter(
    const gchar *log_domain,
    GLogLevelFlags log_level,
    const gchar *message,
    gpointer user_data)
{
    if (message != NULL) {
        if (g_strstr_len(message, -1, "Theme parsing error: gtk.css:") != NULL) {
            return;
        }

        if (g_strstr_len(message, -1, "deprecated. Please use libayatana-appindicator-glib") != NULL) {
            return;
        }
    }

    if (agentbar_previous_default_log_handler != NULL) {
        agentbar_previous_default_log_handler(
            log_domain,
            log_level,
            message,
            agentbar_previous_default_log_user_data);
        return;
    }

    g_log_default_handler(log_domain, log_level, message, user_data);
}

static void agentbar_install_warning_filters(void) {
    static gsize installed = 0;
    if (g_once_init_enter(&installed)) {
        agentbar_previous_default_log_handler = g_log_set_default_handler(
            agentbar_log_filter,
            NULL);
        g_once_init_leave(&installed, 1);
    }
}

static void agentbar_callback_context_free(gpointer user_data, GClosure *closure) {
    (void)closure;

    AgentBarCallbackContext *callback_context = (AgentBarCallbackContext *)user_data;
    free(callback_context);
}

static void agentbar_activate_trampoline(GtkMenuItem *menu_item, gpointer user_data) {
    (void)menu_item;

    AgentBarCallbackContext *callback_context = (AgentBarCallbackContext *)user_data;
    if (callback_context == NULL || callback_context->callback == NULL) {
        return;
    }
    callback_context->callback(callback_context->context);
}

static gboolean agentbar_idle_trampoline(gpointer user_data) {
    AgentBarCallbackContext *callback_context = (AgentBarCallbackContext *)user_data;
    if (callback_context == NULL || callback_context->callback == NULL) {
        return G_SOURCE_REMOVE;
    }
    callback_context->callback(callback_context->context);
    free(callback_context);
    return G_SOURCE_REMOVE;
}

static void agentbar_connect_simple_signal(
    GtkWidget *widget,
    const char *signal_name,
    AgentBarSimpleCallback callback,
    void *context)
{
    AgentBarCallbackContext *callback_context =
        (AgentBarCallbackContext *)calloc(1, sizeof(AgentBarCallbackContext));
    if (callback_context == NULL) {
        return;
    }

    callback_context->callback = callback;
    callback_context->context = context;

    g_signal_connect_data(
        widget,
        signal_name,
        G_CALLBACK(agentbar_activate_trampoline),
        callback_context,
        agentbar_callback_context_free,
        0);
}

int agentbar_gtk_init_check(void) {
    agentbar_install_warning_filters();
    return gtk_init_check(NULL, NULL);
}

GtkWidget *agentbar_menu_new(void) {
    return gtk_menu_new();
}

GtkWidget *agentbar_menu_item_new(const char *label) {
    return gtk_menu_item_new_with_label(label);
}

GtkWidget *agentbar_separator_menu_item_new(void) {
    return gtk_separator_menu_item_new();
}

void agentbar_menu_append(GtkWidget *menu, GtkWidget *child) {
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), child);
}

GtkWidget *agentbar_box_new_vertical(gint spacing) {
    return gtk_box_new(GTK_ORIENTATION_VERTICAL, spacing);
}

GtkWidget *agentbar_box_new_horizontal(gint spacing) {
    return gtk_box_new(GTK_ORIENTATION_HORIZONTAL, spacing);
}

void agentbar_box_append(GtkWidget *box, GtkWidget *child, gboolean expand) {
    gtk_box_pack_start(GTK_BOX(box), child, expand, expand, 0);
}

GtkWidget *agentbar_scrolled_window_new(void) {
    return gtk_scrolled_window_new(NULL, NULL);
}

void agentbar_scrolled_window_set_child(GtkWidget *scrolled_window, GtkWidget *child) {
    gtk_container_add(GTK_CONTAINER(scrolled_window), child);
}

GtkWidget *agentbar_label_new(const char *text) {
    return gtk_label_new(text);
}

void agentbar_label_set_text(GtkWidget *label, const char *text) {
    gtk_label_set_text(GTK_LABEL(label), text);
}

void agentbar_label_set_markup(GtkWidget *label, const char *markup) {
    gtk_label_set_markup(GTK_LABEL(label), markup);
}

void agentbar_label_set_xalign(GtkWidget *label, gfloat xalign) {
    gtk_label_set_xalign(GTK_LABEL(label), xalign);
}

void agentbar_label_set_line_wrap(GtkWidget *label, gboolean line_wrap) {
    gtk_label_set_line_wrap(GTK_LABEL(label), line_wrap);
}

GtkWidget *agentbar_button_new(const char *label) {
    return gtk_button_new_with_label(label);
}

void agentbar_button_set_label(GtkWidget *button, const char *label) {
    gtk_button_set_label(GTK_BUTTON(button), label);
}

void agentbar_button_set_focus_on_click(GtkWidget *button, gboolean focus_on_click) {
    gtk_widget_set_focus_on_click(button, focus_on_click);
}

void agentbar_widget_show(GtkWidget *widget) {
    gtk_widget_show(widget);
}

void agentbar_widget_show_all(GtkWidget *widget) {
    gtk_widget_show_all(widget);
}

void agentbar_widget_set_sensitive(GtkWidget *widget, gboolean sensitive) {
    gtk_widget_set_sensitive(widget, sensitive);
}

void agentbar_widget_set_margin_all(GtkWidget *widget, gint margin) {
    gtk_widget_set_margin_top(widget, margin);
    gtk_widget_set_margin_bottom(widget, margin);
    gtk_widget_set_margin_start(widget, margin);
    gtk_widget_set_margin_end(widget, margin);
}

void agentbar_widget_set_name(GtkWidget *widget, const char *name) {
    gtk_widget_set_name(widget, name);
}

void agentbar_widget_add_css_class(GtkWidget *widget, const char *class_name) {
    GtkStyleContext *style_context = gtk_widget_get_style_context(widget);
    gtk_style_context_add_class(style_context, class_name);
}

void agentbar_widget_remove_css_class(GtkWidget *widget, const char *class_name) {
    GtkStyleContext *style_context = gtk_widget_get_style_context(widget);
    gtk_style_context_remove_class(style_context, class_name);
}

void agentbar_widget_set_hexpand(GtkWidget *widget, gboolean expand) {
    gtk_widget_set_hexpand(widget, expand);
}

void agentbar_widget_set_vexpand(GtkWidget *widget, gboolean expand) {
    gtk_widget_set_vexpand(widget, expand);
}

void agentbar_widget_set_can_focus(GtkWidget *widget, gboolean can_focus) {
    gtk_widget_set_can_focus(widget, can_focus);
}

void agentbar_widget_destroy(GtkWidget *widget) {
    gtk_widget_destroy(widget);
}

void agentbar_menu_item_set_label(GtkWidget *menu_item, const char *label) {
    gtk_menu_item_set_label(GTK_MENU_ITEM(menu_item), label);
}

GtkWidget *agentbar_window_new(const char *title, gint default_width, gint default_height) {
    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), title);
    gtk_window_set_default_size(GTK_WINDOW(window), default_width, default_height);
    return window;
}

void agentbar_window_set_child(GtkWidget *window, GtkWidget *child) {
    gtk_container_add(GTK_CONTAINER(window), child);
}

void agentbar_window_present(GtkWidget *window) {
    gtk_window_present(GTK_WINDOW(window));
}

void agentbar_window_set_resizable(GtkWidget *window, gboolean resizable) {
    gtk_window_set_resizable(GTK_WINDOW(window), resizable);
}

void agentbar_css_load(const char *css) {
    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider, css, -1, NULL);

    GdkScreen *screen = gdk_screen_get_default();
    if (screen != NULL) {
        gtk_style_context_add_provider_for_screen(
            screen,
            GTK_STYLE_PROVIDER(provider),
            GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    g_object_unref(provider);
}

AppIndicator *agentbar_indicator_new(const char *identifier, const char *icon_name) {
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#endif
    return app_indicator_new(identifier, icon_name, APP_INDICATOR_CATEGORY_APPLICATION_STATUS);
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

void agentbar_indicator_set_title(AppIndicator *indicator, const char *title) {
    app_indicator_set_title(indicator, title);
}

void agentbar_indicator_set_status_active(AppIndicator *indicator) {
    app_indicator_set_status(indicator, APP_INDICATOR_STATUS_ACTIVE);
}

void agentbar_indicator_set_status_passive(AppIndicator *indicator) {
    app_indicator_set_status(indicator, APP_INDICATOR_STATUS_PASSIVE);
}

void agentbar_indicator_set_menu(AppIndicator *indicator, GtkWidget *menu) {
    app_indicator_set_menu(indicator, GTK_MENU(menu));
}

void agentbar_indicator_set_label(AppIndicator *indicator, const char *label) {
    app_indicator_set_label(indicator, label, "");
}

void agentbar_indicator_set_icon_full(AppIndicator *indicator, const char *icon_name, const char *icon_desc) {
    app_indicator_set_icon_full(indicator, icon_name, icon_desc);
}

void agentbar_indicator_set_icon_theme_path(AppIndicator *indicator, const char *icon_theme_path) {
    app_indicator_set_icon_theme_path(indicator, icon_theme_path);
}

void agentbar_indicator_set_secondary_activate_target(AppIndicator *indicator, GtkWidget *menu_item) {
    app_indicator_set_secondary_activate_target(indicator, GTK_WIDGET(menu_item));
}

void agentbar_menu_item_connect_activate(
    GtkWidget *menu_item,
    AgentBarSimpleCallback callback,
    void *context)
{
    agentbar_connect_simple_signal(menu_item, "activate", callback, context);
}

void agentbar_button_connect_clicked(
    GtkWidget *button,
    AgentBarSimpleCallback callback,
    void *context)
{
    agentbar_connect_simple_signal(button, "clicked", callback, context);
}

void agentbar_window_connect_destroy(
    GtkWidget *window,
    AgentBarSimpleCallback callback,
    void *context)
{
    agentbar_connect_simple_signal(window, "destroy", callback, context);
}

void agentbar_invoke_on_main_thread(
    AgentBarSimpleCallback callback,
    void *context)
{
    AgentBarCallbackContext *callback_context =
        (AgentBarCallbackContext *)calloc(1, sizeof(AgentBarCallbackContext));
    if (callback_context == NULL) {
        return;
    }

    callback_context->callback = callback;
    callback_context->context = context;
    g_idle_add(agentbar_idle_trampoline, callback_context);
}

void agentbar_run_main_loop(void) {
    gtk_main();
}

void agentbar_quit_main_loop(void) {
    gtk_main_quit();
}
