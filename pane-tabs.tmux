#!/usr/bin/env bash

# tmux entry point. Source this file directly or load it with TPM.
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
printf -v SCRIPT '%q' "$PLUGIN_DIR/pane-tabs.sh"

# --- Pane border status (powerline-styled to match tmux-airline) -----------
# colour0   = black (bg)
# colour11  = grey  (inactive border / secondary bg)
# colour14  = cyan  (active accent)
# colour7   = white (text)
# colour15  = bright white (bold text)
# colour10  = dim green (inactive text)
#
# pane-border-format uses #{?pane_active,...} to style active vs inactive:
#   Active   + no tabs → bright white pane index
#   Active   + tabs    → cyan powerline pill: ▐ [1/3] bash ▌
#   Inactive + no tabs → dim pane index
#   Inactive + tabs    → grey pill: [1/3] bash

tmux set -g pane-border-status top
tmux set -g pane-border-style        "fg=colour11,bg=colour0"
tmux set -g pane-active-border-style "fg=colour14,bg=colour0"
# #{m:[[]*,#{pane_title}} matches tab-style titles like "[1/2] bash"
# Non-tabbed panes show their hostname as pane_title, which won't match.
tmux set -g pane-border-format \
  "#{?pane_active,#{?#{m:[[]*,#{pane_title}},#[fg=colour0 bg=colour14]#[fg=colour15 bg=colour14 bold] #{pane_title} #[fg=colour14 nobold bg=colour0],#[fg=colour15 bold] #{pane_index} #[fg=colour14 nobold bg=colour0]},#{?#{m:[[]*,#{pane_title}},#[fg=colour0 bg=colour11]#[fg=colour7 bg=colour11] #{pane_title} #[fg=colour11 bg=colour0],#[fg=colour10] #{pane_index} }}"
# --------------------------------------------------------------------------

# Pass the invoking pane explicitly. run-shell may execute after focus has moved.
tmux bind-key T run-shell "$SCRIPT new '#{pane_id}'"
tmux bind-key N run-shell "$SCRIPT next '#{pane_id}'"
tmux bind-key P run-shell "$SCRIPT prev '#{pane_id}'"
tmux bind-key X run-shell "$SCRIPT close '#{pane_id}'"

# remain-on-exit makes tmux emit pane-died (not pane-exited). At that point the
# dead pane still exists, so it can be replaced with the next tab before it is
# removed.
tmux set-hook -gu pane-exited 2>/dev/null || true
tmux set-hook -g pane-died "run-shell \"$SCRIPT exited '#{pane_id}'\""
