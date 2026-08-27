#!/usr/bin/env bash
set -eu

DEFAULT_STORE="__pane_tabs"
GROUP_OPTION="@pane_tabs_group"
INDEX_OPTION="@pane_tabs_index"

message() {
    tmux display-message "$1"
}

update_pane_title() {
    local pane="$1" group index count position tab_name
    group="$(get_option "$pane" "$GROUP_OPTION")"
    if [ -z "$group" ]; then
        # No tabs — clear to default (pane_title will show shell/command)
        tmux select-pane -t "$pane" -T ""
        return
    fi
    index="$(get_option "$pane" "$INDEX_OPTION")"
    count="$(tab_count "$group")"
    position="$(tab_position "$group" "$index")"
    tab_name="$(tmux display-message -p -t "$pane" '#{pane_current_command}')"
    tmux select-pane -t "$pane" -T "[$position/$count] $tab_name"
}

update_all_pane_titles() {
    local group="$1"
    # Refresh titles for all visible panes that belong to this group
    while IFS='|' read -r g idx pane_id; do
        [ "$g" = "$group" ] || continue
        tmux display-message -p -t "$pane_id" '#{pane_id}' >/dev/null 2>&1 || continue
        update_pane_title "$pane_id"
    done < <(all_tabs)
}

get_option() {
    tmux show-options -p -qv -t "$1" "$2"
}

set_option() {
    tmux set-option -p -q -t "$1" "$2" "$3"
}

store_name() {
    local configured
    configured="$(tmux show-options -gqv @pane_tabs_store)"
    printf '%s\n' "${configured:-$DEFAULT_STORE}"
}

ensure_store() {
    local store="$1"
    if ! tmux has-session -t "=$store" 2>/dev/null; then
        # The first window keeps the backing session alive. Tabs are created as
        # additional one-pane windows and swapped into visible layout slots.
        tmux new-session -d -s "$store" -n __parking
    fi
}

all_tabs() {
    tmux list-panes -a -F "#{${GROUP_OPTION}}|#{${INDEX_OPTION}}|#{pane_id}"
}

ensure_group() {
    local pane="$1" group
    group="$(get_option "$pane" "$GROUP_OPTION")"
    if [ -z "$group" ]; then
        group="${pane#%}-$(date +%s)-${RANDOM}"
        set_option "$pane" "$GROUP_OPTION" "$group"
        set_option "$pane" "$INDEX_OPTION" 0
    fi
    # Enable remain-on-exit so the pane stays alive when the shell exits,
    # allowing the pane-died hook to do tab-close instead of killing the pane.
    tmux set-option -p -q -t "$pane" remain-on-exit on
    printf '%s\n' "$group"
}

tab_count() {
    all_tabs | awk -F '|' -v group="$1" '$1 == group { count++ } END { print count + 0 }'
}

tab_position() {
    all_tabs | awk -F '|' -v group="$1" -v current="$2" '$1 == group && $2 + 0 < current + 0 { before++ } END { print before + 1 }'
}

max_index() {
    all_tabs | awk -F '|' -v group="$1" '
        BEGIN { max = -1 }
        $1 == group && $2 + 0 > max { max = $2 + 0 }
        END { print max }
    '
}

next_target() {
    all_tabs | awk -F '|' -v group="$1" -v current="$2" '
        $1 == group {
            tab_index = $2 + 0
            if (minimum == "" || tab_index < minimum) {
                minimum = tab_index
                first = $3
            }
            if (tab_index > current + 0 && (next_index == "" || tab_index < next_index)) {
                next_index = tab_index
                next_pane = $3
            }
        }
        END { print (next_pane != "" ? next_pane : first) }
    '
}

prev_target() {
    all_tabs | awk -F '|' -v group="$1" -v current="$2" '
        $1 == group {
            tab_index = $2 + 0
            if (maximum == "" || tab_index > maximum) {
                maximum = tab_index
                last = $3
            }
            if (tab_index < current + 0 && (prev_index == "" || tab_index > prev_index)) {
                prev_index = tab_index
                prev_pane = $3
            }
        }
        END { print (prev_pane != "" ? prev_pane : last) }
    '
}

new_tab() {
    local current="$1" group store cwd index new count position
    group="$(ensure_group "$current")"
    store="$(store_name)"
    ensure_store "$store"
    cwd="$(tmux display-message -p -t "$current" '#{pane_current_path}')"
    index=$(( $(max_index "$group") + 1 ))

    new="$(tmux new-window -dP -F '#{pane_id}' -t "=${store}:" -c "$cwd")"
    set_option "$new" "$GROUP_OPTION" "$group"
    set_option "$new" "$INDEX_OPTION" "$index"
    # Keep the pane alive after the shell exits so the hook can do tab-close.
    tmux set-option -p -q -t "$new" remain-on-exit on
    zoomed="$(tmux display-message -p -t "$current" '#{window_zoomed_flag}')"
    tmux swap-pane -d -s "$new" -t "$current"

    count="$(tab_count "$group")"
    update_all_pane_titles "$group"
    position="$(tab_position "$group" "$index")"
    update_all_pane_titles "$group"
    [ "$zoomed" = "1" ] && tmux resize-pane -Z -t "$new"
    message "tab $position/$count"
}

switch_tab() {
    local direction="$1" current="$2" group index count target target_index position
    group="$(get_option "$current" "$GROUP_OPTION")"
    if [ -z "$group" ]; then
        message "No pane tabs yet — use prefix + T"
        return
    fi

    index="$(get_option "$current" "$INDEX_OPTION")"
    count="$(tab_count "$group")"
    if [ "$count" -le 1 ]; then
        message "Only one pane tab"
        return
    fi

    if [ "$direction" = next ]; then
        target="$(next_target "$group" "$index")"
    else
        target="$(prev_target "$group" "$index")"
    fi
    [ -n "$target" ] || { message "Could not find pane tab"; return; }

    target_index="$(get_option "$target" "$INDEX_OPTION")"
    position="$(tab_position "$group" "$target_index")"
    zoomed="$(tmux display-message -p -t "$current" '#{window_zoomed_flag}')"
    tmux swap-pane -d -s "$target" -t "$current"
    [ "$zoomed" = "1" ] && tmux resize-pane -Z -t "$target"
    message "pane tab $position/$count"
}

close_tab() {
    local current="$1" group count index target target_index position
    group="$(get_option "$current" "$GROUP_OPTION")"
    if [ -z "$group" ]; then
        message "This pane has no tabs"
        return
    fi

    count="$(tab_count "$group")"
    if [ "$count" -le 1 ]; then
        message "Can't close the only pane tab"
        return
    fi

    index="$(get_option "$current" "$INDEX_OPTION")"
    target="$(next_target "$group" "$index")"
    [ -n "$target" ] || { message "Could not find pane tab"; return; }
    target_index="$(get_option "$target" "$INDEX_OPTION")"

    tmux swap-pane -d -s "$target" -t "$current"
    tmux kill-pane -t "$current"
    position="$(tab_position "$group" "$target_index")"
    update_all_pane_titles "$group"
    message "Closed tab; now $position/$((count - 1))"
}

# Called by the pane-died hook when a pane's shell exits naturally.
# If the pane has tabs, perform a tab-close instead of letting tmux kill
# the pane. If it is the only tab (or has no tabs), do nothing and let
# tmux handle cleanup normally.
exited_tab() {
    local current="$1" group count index target target_index position
    group="$(get_option "$current" "$GROUP_OPTION")"
    if [ -z "$group" ]; then
        # No tabs — let tmux kill the pane normally.
        return
    fi

    count="$(tab_count "$group")"
    if [ "$count" -le 1 ]; then
        # Last tab — clear remain-on-exit so tmux can close the pane normally.
        tmux set-option -p -q -t "$current" remain-on-exit off
        tmux kill-pane -t "$current"
        return
    fi

    index="$(get_option "$current" "$INDEX_OPTION")"
    target="$(next_target "$group" "$index")"
    [ -n "$target" ] || { tmux kill-pane -t "$current"; return; }
    target_index="$(get_option "$target" "$INDEX_OPTION")"

    tmux swap-pane -d -s "$target" -t "$current"
    tmux kill-pane -t "$current"
    position="$(tab_position "$group" "$target_index")"
    update_all_pane_titles "$group"
    message "Tab exited; now $position/$((count - 1))"
}

command="${1:-}"
pane="${2:-}"

# For the 'exited' command the pane's shell has already died; tmux still knows
# about the pane (remain-on-exit keeps it) but display-message may fail on some
# versions. Skip the liveness check and let exited_tab handle it gracefully.
if [ "$command" != "exited" ]; then
    if [ -z "$pane" ] || ! tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1; then
        message "Pane tabs: invoking pane no longer exists"
        exit 0
    fi
fi

case "$command" in
    new)   new_tab "$pane" ;;
    next)  switch_tab next "$pane" ;;
    prev)  switch_tab prev "$pane" ;;
    close) close_tab "$pane" ;;
    exited) exited_tab "$pane" ;;
    *)
        printf 'usage: %s {new|next|prev|close} pane-id\n' "$0" >&2
        exit 2
        ;;
esac
