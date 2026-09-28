#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/EventManager.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>
#include <hyprland/src/xwayland/XSurface.hpp>

#include <cstdint>
#include <format>
#include <string>
#include <unordered_map>

HANDLE PHANDLE = nullptr;

struct SWinHooks {
    CHyprSignalListener state;
};

static std::unordered_map<uintptr_t, SWinHooks> g_hooks;
static CHyprSignalListener                      g_onCreate;
static CHyprSignalListener                      g_onDestroy;

static bool alreadyMinimized(PHLWINDOW w) {
    if (!w || !w->m_workspace)
        return false;
    return w->m_workspace->m_isSpecialWorkspace && w->m_workspace->m_name.find("minimized") != std::string::npos;
}

static void hideWindow(PHLWINDOW w) {
    if (!w || !w->m_isMapped || alreadyMinimized(w))
        return;

    const auto addr = rc<uintptr_t>(w.get());
    g_pEventManager->postEvent(SHyprIPCEvent{.event = "minimized", .data = std::format("{:x},1", addr)});
    HyprlandAPI::invokeHyprctlCommand("dispatch",
        std::format("hl.dsp.window.move({{ workspace = \"special:minimized\", follow = false, window = \"address:0x{:x}\" }})", addr));
}

static void hookWindow(PHLWINDOW w) {
    if (!w)
        return;

    const auto id = rc<uintptr_t>(w.get());
    if (g_hooks.contains(id))
        return;

    const PHLWINDOWREF ref = w;
    SWinHooks          hooks;

    if (!w->m_isX11 && w->m_xdgSurface && w->m_xdgSurface->m_toplevel) {
        hooks.state = w->m_xdgSurface->m_toplevel->m_events.stateChanged.listen([ref] {
            const auto win = ref.lock();
            if (!win || !win->m_xdgSurface || !win->m_xdgSurface->m_toplevel)
                return;
            if (win->m_xdgSurface->m_toplevel->m_state.requestsMinimize.value_or(false))
                hideWindow(win);
        });
    } else if (w->m_isX11 && w->m_xwaylandSurface) {
        hooks.state = w->m_xwaylandSurface->m_events.stateChanged.listen([ref] {
            const auto win = ref.lock();
            if (!win || !win->m_xwaylandSurface)
                return;
            if (win->m_xwaylandSurface->m_state.requestsMinimize.value_or(false))
                hideWindow(win);
        });
    }

    g_hooks.emplace(id, std::move(hooks));
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    g_onCreate = Event::bus()->m_events.window.create.listen([](PHLWINDOW w) { hookWindow(w); });
    g_onDestroy = Event::bus()->m_events.window.destroy.listen([](PHLWINDOWREF ref) {
        if (const auto w = ref.lock())
            g_hooks.erase(rc<uintptr_t>(w.get()));
    });

    for (auto const& w : Desktop::windowState()->windows())
        hookWindow(w);

    return {"hypr-minimize", "Honor CSD/X11 minimize requests by hiding the window", "tirbofish", "1.2"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_onCreate.reset();
    g_onDestroy.reset();
    g_hooks.clear();
}
