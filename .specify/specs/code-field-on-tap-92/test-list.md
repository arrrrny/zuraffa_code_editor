# Test list — tap callback on the editor (#92)

1. `a tap inside the field reaches the callback` — the headline request.
   RED without the forwarding: `onTap` is never called, so the host hears
   nothing, which is the issue verbatim.
2. `every tap reaches the callback, not just the first` — the callback is not a
   one-shot. RED without the forwarding (count stays 0); also red if the callback
   is ever wired to a one-shot gesture such as `onDoubleTap`.
3. `the tap still focuses the field` — guards the other half of the gesture:
   notifying the host must not cost the field its focus, which is what a hand
   rolled `GestureDetector` around the field would break.
4. `the tap still places the caret` — the caret still lands from the field's own
   recognizer, collapsed and inside the document, so the callback is additive
   rather than a replacement for placement.
5. `a field with no callback still accepts the tap` — the null path: leaving
   `onTap` out changes nothing. Stays green without the forwarding by design,
   so it guards the opposite regression (a field that refuses taps when the
   parameter is absent).
