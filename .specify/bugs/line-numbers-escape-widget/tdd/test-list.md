# #19 — test list

| # | Test | Why it pins #19 |
|---|------|-----------------|
| 1 | the gutter keeps pace with the editor while dragging | a real user scroll, asserted end-to-end on both scroll positions |
| 2 | the gutter follows a jump to the very bottom | the extreme end of the range, where "escaped the widget" would show |
| 3 | the gutter also keeps pace when the field wraps | the wrap path measures its own row heights, the one place the two views could disagree |
