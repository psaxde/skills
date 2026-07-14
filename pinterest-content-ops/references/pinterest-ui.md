# Pinterest UI Runbook

This is provider-specific compatibility guidance. Labels and accessibility names can drift by language and release: take a fresh snapshot before every branch and prefer current accessible names over this reference.

## Safety preflight

1. Use the existing authenticated browser session.
2. Verify the visible Pinterest account matches the batch profile.
3. Open the Pin Builder and inspect the existing queue.
4. Confirm request mode authorizes scheduling or publishing.
5. Keep the offline batch and contact sheet as the source of truth.

## Critical board-first sequence

Pinterest board-picker rows may expose an immediate publish action. Selecting one for a filled pin can publish unintentionally.

Always:

1. create a new blank pin
2. wait for the default board to settle
3. open the current board dropdown
4. select the intended board while no image or copy is present
5. verify the intended board is visible
6. only then upload and fill the pin

If a pin was published accidentally, stop the batch, report it, and use only existing authority before deleting or changing live content.

## Field lookup

Locate these fields by current accessible role and name:

| Field | Expected control |
|---|---|
| New pin | create-new-pin button |
| Upload | file input |
| Title | title text field |
| Description | description text area |
| Alt text | alt-text toggle and field |
| Link | destination-link field |
| Schedule | publish-later option |
| Date | localized date field |
| Time | localized time selector |
| AI disclosure | AI-modified disclosure control |
| Final action | publish or schedule button |

Do not guess selectors or rely on stale positional indexes. Record language-specific names in the private batch run log when useful.

## Per-pin procedure

1. Create a blank pin and select the board first.
2. Upload exactly one final JPG.
3. Fill title, description, alt text, and destination link.
4. Set AI disclosure from `ai_modified`.
5. Select the publish-later option for scheduled mode.
6. Fill the date and dismiss the date picker.
7. Set and re-read the time.
8. Snapshot and verify board, title, description, alt, link, disclosure, date, and time.
9. Trigger the final Pinterest action once.
10. Wait until the editor closes and the planner card appears.

## Time selector fallback

If clicking time menu items is unreliable, use keyboard selection only after inspecting the current menu ordering and interval. Re-read the selected localized value before the final action. Stop if the menu behavior is ambiguous.

## Batch verification

- Count every intended title with an exact heading locator; each count must equal one.
- Confirm every card has the intended scheduled or published status and date.
- If time is absent from the card, preserve pre-action field verification in the run log.
- Record Pinterest IDs when visible.
- Leave the planner or finished account page as the browser deliverable.
