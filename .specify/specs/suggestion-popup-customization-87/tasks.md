# Tasks: suggestion-popup-customization (#87)

Spec: `.specify/specs/suggestion-popup-customization-87/spec.md`
Contract: `contracts/suggestion-item-builder.md`

Ordered. TDD: every task that changes behaviour writes its test RED first and
pastes the failure into the task's evidence before implementing.

## Phase 0 — verify the premise

- [ ] **T001** Re-read `popup.dart:72-74` and `popup_placement_test.dart` and
      confirm the flip uses needed height and placement is pinned. Record the
      line numbers in `research.md`. *Do not re-implement either.*

## Phase 1 — RED

- [ ] **T002** Write `test/src/wip/autocomplete/popup_item_builder_test.dart`
      with the six contract tests, RED:
  - [ ] T002a no builder → the built-in row is the `Material`/`InkWell` chain
  - [ ] T002b builder set → called once per suggestion, with the text
  - [ ] T002c `isSelected` tracks `selectedIndex`
  - [ ] T002d `onSelect` commits the right suggestion and returns focus
  - [ ] T002e a builder that ignores `isSelected` still commits correctly
  - [ ] T002f `show` resets selection to 0 and `hide` clears `shouldShow`
- [ ] **T003** Run RED and paste the compile/first failure into `tdd/`.

## Phase 2 — GREEN

- [ ] **T004** Add `suggestionItemBuilder` to `CodeField` with the doc comment
      from the contract, beside `autocompleteBackground`.
- [ ] **T005** Add the same field to `Popup`, and dispatch in `_buildListItem`
      so the built-in chain runs when it is null.
- [ ] **T006** Pass `widget.suggestionItemBuilder` from
      `_buildSuggestionOverlay`.
- [ ] **T007** Run the new suite green, then the full suite.

## Phase 3 — document the coupling

- [ ] **T008** Document the `CodeController` → `PopupController` contract on
      the `popupController` field (`code_controller.dart:128`), naming every
      call site: `generateSuggestions` show/hide, `hide` on selection change
      and IME end, `scrollByArrow` on arrows, `insertSelectedWord` on
      enter/tab, `enabled` in `_dismissSuggestions`.
- [ ] **T009** Add the pin test for the observable sequence (T002f).

## Phase 4 — gates

- [ ] **T010** `dart analyze --fatal-infos` clean.
- [ ] **T011** `dart format --output=none --set-exit-if-changed .` clean.
- [ ] **T012** Coverage gate 100%: generate the helper, `flutter test
      --coverage --concurrency=2`, `python3 tool/coverage_gate.py --min 100`,
      then remove the helper and `coverage/`. Check `EXEMPT_LINES` by **line
      number** before adding anything.
- [ ] **T013** Mutation audit on the dispatch: make `_buildListItem` ignore the
      builder and confirm T002b/T002e fail. Record in `tdd/verification.md`.
- [ ] **T014** CHANGELOG entry above the #86 entry.
- [ ] **T015** PR body naming which of #87's four acceptance criteria this
      change satisfies and which were already met.

## Note for whoever edits `popup.dart` next

`tool/coverage_gate.py` pins `EXEMPT_LINES` by line number. The dispatch adds
lines above the built-in row chain; if the gate reports a stale line
exemption, renumber rather than adding a new entry.
