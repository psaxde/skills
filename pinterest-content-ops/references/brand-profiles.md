# Account Profiles

Copy `assets/brand-profiles/generic.json` into the batch as `brand-profile.json`, adapt it from verified current information, and keep account-specific profiles outside this public skill.

## Required intake

Record these fields before production:

1. account name and expected Pinterest profile
2. language and market
3. source domains and preferred destination channel
4. palette, typography, tone, and forbidden claims
5. whether UTMs are required and the campaign naming convention
6. allowed generative treatment and disclosure policy
7. existing boards and preferred cadence
8. batch output root

Verify drift-prone fields such as account identity, board names, queue state, destination availability, and current campaign dates live before use.

## Safe defaults

- Use the most specific valid source page as the destination.
- Use no hashtags unless the account's current strategy explicitly requires them.
- Preserve products, food, people, pets, and source article imagery.
- Allow generated decorative backgrounds only when they do not misrepresent the destination.
- Use neutral styling when palette or typography is missing.
- Keep prices, discounts, shipping promises, health claims, and urgency out unless verified for the scheduled period.
- Treat `preview` as the default authority mode.

If a missing field affects only styling, use the neutral profile and continue. If it changes claims, account identity, destination, measurement, or publication authority, ask one direct question.

## Privacy boundary

Store credentials, cookies, customer data, private messages, and browser state nowhere in the profile. Keep reusable private account profiles in a private workspace and copy only the fields required for the current batch.
