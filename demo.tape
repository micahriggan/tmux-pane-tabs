# tmux-pane-tabs demo
# Requirements: vhs (brew install vhs), tmux
# Prefix: Ctrl+A

Output demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 1400
Set Height 600
# Solarized Dark — matches your tmux airline colour palette
Set Theme {"name":"Solarized Dark","black":"#073642","red":"#dc322f","green":"#859900","yellow":"#b58900","blue":"#268bd2","magenta":"#d33682","cyan":"#2aa198","white":"#eee8d5","brightBlack":"#002b36","brightRed":"#cb4b16","brightGreen":"#586e75","brightYellow":"#657b83","brightBlue":"#839496","brightMagenta":"#6c71c4","brightCyan":"#93a1a1","brightWhite":"#fdf6e3","background":"#002b36","foreground":"#839496","selectionBackground":"#073642","cursorColor":"#839496"}
Set Padding 10
Set TypingSpeed 40ms
Set PlaybackSpeed 0.8

# ── Hidden setup: kill old session, create fresh one ─────────────────────────
Hide
Type "tmux kill-session -t vhs_demo 2>/dev/null; tmux new-session -d -s vhs_demo -x 210 -y 46 && tmux send-keys -t vhs_demo 'source ~/dev/tmux-pane-tabs/pane-tabs.tmux' Enter && sleep 1 && tmux split-window -h -t vhs_demo && tmux attach -t vhs_demo"
Enter
Sleep 4s
# Clear the left pane so it looks clean
Type "tmux send-keys -t vhs_demo:1.0 'clear' Enter"
Enter
Sleep 500ms
# Clear right pane (which we're attached to) too
Type "clear"
Enter
Sleep 300ms
Show

# ── We are now inside tmux with 2 panes (right pane is active) ───────────────
Type "echo '=== tmux-pane-tabs: tabs per pane slot ==='"
Enter
Sleep 800ms

# ── New Tab (Ctrl+A T) ───────────────────────────────────────────────────────
Type "echo '# Ctrl-A T  →  new tab in this pane'"
Enter
Sleep 600ms
Ctrl+A
Sleep 200ms
Type "T"
Sleep 1.5s

Type "echo 'Tab 2 — same slot, new shell. Border shows [2/2]'"
Enter
Sleep 900ms

Ctrl+A
Sleep 200ms
Type "T"
Sleep 1.5s

Type "echo 'Tab 3 — border now shows [3/3]'"
Enter
Sleep 900ms

# ── Prev Tab (Ctrl+A P) ──────────────────────────────────────────────────────
Type "echo '# Ctrl-A P  →  previous tab'"
Enter
Sleep 600ms
Ctrl+A
Sleep 200ms
Type "P"
Sleep 1.2s

Type "echo 'Tab 2 — border shows [2/3]'"
Enter
Sleep 800ms

# ── Next Tab (Ctrl+A N) ──────────────────────────────────────────────────────
Type "echo '# Ctrl-A N  →  next tab'"
Enter
Sleep 600ms
Ctrl+A
Sleep 200ms
Type "N"
Sleep 1.2s

Type "echo 'Tab 3 — cycled forward'"
Enter
Sleep 800ms

# ── Zoom + tab switch (zoom preserved) ───────────────────────────────────────
Type "echo '# Ctrl-A Z to zoom — zoom is preserved on tab switch!'"
Enter
Sleep 600ms
Ctrl+A
Sleep 200ms
Type "z"
Sleep 1s

Type "echo 'Zoomed on Tab 3...'"
Enter
Sleep 700ms

Ctrl+A
Sleep 200ms
Type "P"
Sleep 1.2s

Type "echo 'Switched to Tab 2 — still zoomed!'"
Enter
Sleep 900ms

Ctrl+A
Sleep 200ms
Type "z"
Sleep 900ms

# ── Close Tab (Ctrl+A X) ─────────────────────────────────────────────────────
Type "echo '# Ctrl-A X  →  close this tab'"
Enter
Sleep 600ms
Ctrl+A
Sleep 200ms
Type "X"
Sleep 1.5s

Type "echo 'Tab closed — border updates to [1/2]'"
Enter
Sleep 1s

# ── Show plain border on left pane ───────────────────────────────────────────
Ctrl+A
Sleep 200ms
Left
Sleep 800ms

Type "echo 'Left pane — no tabs, plain border'"
Enter
Sleep 800ms

# Back to tabbed pane
Ctrl+A
Sleep 200ms
Right
Sleep 700ms

Type "echo 'Right pane — border always shows current tab position'"
Enter
Sleep 2s
