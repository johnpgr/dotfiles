/*
 * herdr-smart-nav <left|down|up|right>
 *
 * vim-tmux-navigator for herdr. Bound to ctrl+h/j/k/l as a herdr plugin action:
 *   - if the focused pane's foreground process is (n)vim, forward the chord to
 *     it (nvim then moves between its own splits, or asks herdr to focus the
 *     neighbouring pane itself when it hits the edge of its layout -- see
 *     nvim/lua/config/herdr_nav.lua);
 *   - otherwise focus the neighbouring herdr pane directly.
 *
 * Talks to the herdr server over its unix socket (NDJSON, one request per
 * connection) so the whole thing is a single process spawn with no shell.
 * Two round trips, ~0.5ms of socket time, ~2ms wall including the spawn.
 * POSIX only (Linux, macOS).
 *
 * Set HERDR_SMART_NAV_APPS="nvim,vim,lazygit" to change which foreground
 * process names get the chord forwarded instead of being navigated away from.
 * Set HERDR_SMART_NAV_DEBUG=1 to log each decision (visible in
 * `herdr plugin log list`). Both must be in the herdr *server's* environment.
 *
 * ---------------------------------------------------------------------------
 * WHY THIS IS A COMPILED C PROGRAM AND NOT CONFIG, LUA, OR A SHELL SCRIPT
 * ---------------------------------------------------------------------------
 *
 * The goal: ctrl+h/j/k/l moves between herdr panes from ANY pane (shell,
 * agent TUI, nvim), and inside nvim the same chords first move between nvim's
 * own splits, only crossing into a herdr pane at the edge of nvim's layout.
 * That is exactly what tmux users get from vim-tmux-navigator / tmux.nvim.
 *
 * The problem splits in two, and only one half can live in nvim:
 *
 *   1. Inside nvim: nvim decides "split or edge?" with vim.fn.winnr(dir) and
 *      at the edge calls herdr's pane.focus_direction over the socket. Pure
 *      Lua, no process spawn. Done in herdr_nav.lua.
 *
 *   2. Outside nvim: the key never reaches nvim, so someone in herdr has to
 *      act on ctrl+h. But if herdr simply binds ctrl+h -> focus_pane_left,
 *      it swallows the chord in EVERY pane, including nvim's, and half (1)
 *      breaks: nvim never sees ctrl+h again. Something between herdr and the
 *      pane has to look at what is running there and choose.
 *
 * Verified against herdr 0.8.x (config reference, `herdr --default-config`,
 * the socket schema from `herdr api schema --json`, and the plugin docs):
 *
 *   - Key bindings are unconditional. There is no `when =` / passthrough /
 *     "unless the pane runs X" field on [keys] or [[keys.command]]. The only
 *     per-pane input routing that exists (pane.input.set) is for right-click.
 *   - The socket API has no "focus neighbour, else forward key" primitive.
 *     It has the pieces: pane.process_info (foreground processes of a pane),
 *     pane.focus_direction, and pane.send_keys (accepts "ctrl+h" chords).
 *     Composing them is up to the client.
 *   - Plugins cannot hook keys in-process. A plugin is a manifest plus argv
 *     commands that herdr spawns per invocation; there is no long-lived
 *     plugin process, no Lua/JS host, no event that fires on a keypress.
 *   - Therefore every ctrl+hjkl outside nvim -- and, because the binding is
 *     global, every one inside nvim too -- MUST spawn a process. That is
 *     unavoidable given herdr's extension surface; the only lever left is
 *     how much that process costs.
 *
 * Costing the options for that one spawn (ctrl+hjkl is a hot path, and the
 * user specifically objected to process-spawn latency, which is much worse
 * on macOS than Linux):
 *
 *   - [[keys.command]] type = "shell": herdr wraps the command in
 *     `/bin/sh -lc` (a LOGIN shell, so it sources profiles), and the script
 *     would then spawn the herdr CLI twice (process-info, then focus or
 *     send-keys). Three-plus processes plus profile sourcing per keypress.
 *   - Plugin action running a bash/python script: plugin argv arrays are
 *     exec'd directly (no shell), but the interpreter is still a spawn plus
 *     startup (python ~20ms), and it still needs the herdr CLI or a socket
 *     tool (nc/socat) as further spawns to reach the server.
 *   - Plugin action running the herdr CLI directly: cannot express the
 *     conditional in one invocation; still two spawns minimum.
 *   - Plugin action exec'ing a small native binary that speaks the socket
 *     protocol itself: exactly ONE spawn, no shell, no interpreter, no CLI,
 *     ~2ms wall on Linux including exec. This is the floor herdr allows.
 *
 * Why C specifically: the protocol is trivial (connect to a unix socket,
 * write one JSON line, read one JSON line) so the program needs nothing
 * beyond libc and POSIX sockets. That means no toolchain or dependency
 * management -- `cc` exists on every Linux box and ships with macOS's
 * developer tools -- and a ~13KB binary with the smallest possible startup.
 * Rust/Go would work equally well but add a toolchain requirement for no
 * gain here. The JSON handling is deliberately string-search based: the
 * responses are small and generated by a known server, and pulling in a
 * parser would be more code than this whole file.
 *
 * Rejected alternatives that avoid the spawn but fail the goal:
 *   - Bind herdr to a different chord (ctrl+alt+hjkl, as herdr's docs
 *     suggest) and keep ctrl+hjkl for nvim: zero spawns, but now the key to
 *     move panes depends on which pane you are in. That is the exact
 *     annoyance being removed.
 *   - Bind ctrl+hjkl in each shell (fish/bash) to `herdr pane focus`: covers
 *     shell prompts only; agent TUIs (Claude Code etc.) would eat the chord.
 *   - Have nvim report "I am here" via pane.report_metadata so herdr can
 *     route around it: herdr has nothing that reads metadata when deciding a
 *     key binding, so there is still nothing to consume the flag.
 *
 * Known trade-off: ctrl+h/j/k/l are now intercepted in every pane, so
 * shells lose ctrl+l (clear), ctrl+k (kill-line), ctrl+j (newline) and
 * terminals that send ^H for Backspace lose that too. Same trade-off
 * vim-tmux-navigator users accept; kitty/WezTerm distinguish ctrl+h from
 * Backspace via the kitty keyboard protocol, so Backspace itself survives.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

#define RESP_CAP (256 * 1024)

static const char* socket_path(void) {
    const char* p = getenv("HERDR_SOCKET_PATH");
    if(p && *p)
        return p;
    static char buf[sizeof(((struct sockaddr_un*)0)->sun_path)];
    const char* home = getenv("HOME");
    if(!home)
        return NULL;
    snprintf(buf, sizeof buf, "%s/.config/herdr/herdr.sock", home);
    return buf;
}

/* One request/response exchange. Returns bytes read, or -1. */
static ssize_t rpc(const char* req, char* out, size_t cap) {
    const char* path = socket_path();
    if(!path)
        return -1;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof addr);
    addr.sun_family = AF_UNIX;
    if(strlen(path) >= sizeof addr.sun_path)
        return -1;
    strcpy(addr.sun_path, path);

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if(fd < 0)
        return -1;
    if(connect(fd, (struct sockaddr*)&addr, sizeof addr) < 0) {
        close(fd);
        return -1;
    }
    size_t len = strlen(req), off = 0;
    while(off < len) {
        ssize_t n = write(fd, req + off, len - off);
        if(n <= 0) {
            close(fd);
            return -1;
        }
        off += (size_t)n;
    }
    size_t got = 0;
    while(got < cap - 1) {
        ssize_t n = read(fd, out + got, cap - 1 - got);
        if(n <= 0)
            break;
        got += (size_t)n;
        if(memchr(out + got - (size_t)n, '\n', (size_t)n))
            break;
    }
    close(fd);
    out[got] = '\0';
    return (ssize_t)got;
}

/* Copy the string value following `"key":"` into dst. Returns 1 on success. */
static int json_str(const char* hay, const char* key, char* dst, size_t cap) {
    char pat[64];
    snprintf(pat, sizeof pat, "\"%s\":\"", key);
    const char* p = strstr(hay, pat);
    if(!p)
        return 0;
    p += strlen(pat);
    size_t i = 0;
    while(*p && *p != '"' && i < cap - 1) {
        if(*p == '\\' && p[1])
            p++;
        dst[i++] = *p++;
    }
    dst[i] = '\0';
    return 1;
}

static int name_in_list(const char* name, const char* list) {
    size_t nlen = strlen(name);
    const char* p = list;
    while(*p) {
        const char* end = strchr(p, ',');
        size_t len = end ? (size_t)(end - p) : strlen(p);
        if(len == nlen && strncmp(p, name, len) == 0)
            return 1;
        if(!end)
            break;
        p = end + 1;
    }
    return 0;
}

/* Does any foreground process in a pane.process_info reply match the app list?
 */
static int wants_the_chord(const char* resp) {
    const char* apps = getenv("HERDR_SMART_NAV_APPS");
    if(!apps || !*apps)
        apps = "nvim,vim,vi";
    const char* p = resp;
    char name[256];
    while((p = strstr(p, "\"name\":\"")) != NULL) {
        if(json_str(p, "name", name, sizeof name) && name_in_list(name, apps))
            return 1;
        p += 8;
    }
    return 0;
}

int main(int argc, char** argv) {
    if(argc != 2) {
        fprintf(stderr, "usage: %s <left|down|up|right>\n", argv[0]);
        return 2;
    }
    const char *dir = argv[1], *chord;
    if(!strcmp(dir, "left"))
        chord = "ctrl+h";
    else if(!strcmp(dir, "down"))
        chord = "ctrl+j";
    else if(!strcmp(dir, "up"))
        chord = "ctrl+k";
    else if(!strcmp(dir, "right"))
        chord = "ctrl+l";
    else {
        fprintf(stderr, "bad direction: %s\n", dir);
        return 2;
    }

    static char resp[RESP_CAP];
    char req[512];

    /* No pane_id: the server resolves the focused pane, i.e. the one that got
     * the keypress. */
    if(rpc("{\"id\":\"1\",\"method\":\"pane.process_info\",\"params\":{}}\n",
           resp,
           sizeof resp) < 0)
        return 1;

    char pane_id[128] = "?";
    json_str(resp, "pane_id", pane_id, sizeof pane_id);
    int forward = wants_the_chord(resp) && pane_id[0] != '?';
    if(forward) {
        snprintf(
            req,
            sizeof req,
            "{\"id\":\"2\",\"method\":\"pane.send_keys\",\"params\":{\"pane_"
            "id\":\"%s\",\"keys\":[\"%s\"]}}\n",
            pane_id,
            chord
        );
    } else {
        snprintf(
            req,
            sizeof req,
            "{\"id\":\"2\",\"method\":\"pane.focus_direction\",\"params\":{"
            "\"direction\":\"%s\"}}\n",
            dir
        );
    }
    /* HERDR_SMART_NAV_DEBUG=1: one line per keypress in `herdr plugin log
     * list`. */
    if(getenv("HERDR_SMART_NAV_DEBUG"))
        fprintf(
            stderr,
            "smart-nav: pane=%s dir=%s -> %s\n",
            pane_id,
            dir,
            forward ? "forward chord to (n)vim" : "herdr focus_direction"
        );
    return rpc(req, resp, sizeof resp) < 0 ? 1 : 0;
}
