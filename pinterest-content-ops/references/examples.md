# Transformed Examples

## Happy path: product-category batch

Request: “Create six seasonal pins from this shop category and schedule them after the current queue.”

Expected behavior:

1. verify account, category, queue, and relevant existing boards
2. choose six visually distinct products
3. capture authentic images and exact product URLs
4. write six search-focused entries and render coherent visual variants
5. validate and inspect the contact sheet
6. map to an existing relevant board rather than creating a duplicate
7. schedule after the queue and verify six unique planner cards

## Robust variant: preview before approval

Request: “Make a dozen pins from these articles, but show me everything before anything goes live.”

Expected behavior:

1. create a batch-local account profile and add UTMs when required
2. preserve the source article images
3. render and validate all creatives
4. return contact sheet, titles, descriptions, links, boards, and proposed schedule
5. stop with statuses at `ready_for_preview`
6. perform no Pinterest writes until explicit approval arrives

## Anti-pattern and correction

Anti-pattern:

- upload image and copy
- open the board picker
- click a row that immediately publishes
- publish unintentionally

Correction:

- create a blank pin
- select the board before image or copy exists
- verify the board
- fill and schedule the pin
- verify date and time before the single final action

## Should trigger

- “Create Pinterest pins from these product pages and show me a preview.”
- “Fill next week's Pinterest queue with two posts per day.”
- “Schedule the approved Pinterest batch in the logged-in account.”

## Should not trigger

- “Give me ten general short-form video ideas.”
- “Resize this image to 1000 x 1500 without Pinterest copy or scheduling.”
- “What were yesterday's Pinterest impressions?”
