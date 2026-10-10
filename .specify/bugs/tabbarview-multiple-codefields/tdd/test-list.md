# #26 — test list

| # | Test | What it pins |
|---|------|--------------|
| 1 | switching tabs between several CodeFields does not crash | the reported configuration, forward and back |
| 2 | a tab that is never shown still builds without crashing | `initialIndex` on the last tab — the fields the report blames |
| 3 | dropping a tab while another is on screen does not crash | a field unmounted under its own popup |
