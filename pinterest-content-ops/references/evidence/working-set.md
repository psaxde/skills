# Working Design Examples

## EX-001: Approved three-template comparison

- Label: positive
- Kind: true-positive
- Origin: human-verified
- Source: anonymized local template comparison
- Status: resolved
- Expected behavior: preserve the three approved compositions as reusable families.
- Observed behavior: the reviewer approved the comparison and requested it as the future standard.
- Skill delta: add `editorial`, `bold_photo`, and `recipe_card` templates plus batch-mix rules.
- Anonymization: account, domain, local path, and source identity removed.

### Content

One authentic source image rendered in three materially different layouts with one palette.

## EX-002: Right-edge metadata collision

- Label: negative
- Kind: fix
- Origin: human-verified
- Source: anonymized batch review
- Status: resolved
- Expected behavior: every pill and metadata card has balanced internal spacing.
- Observed behavior: right-aligned copy ended at the component edge because the right inset was zero.
- Skill delta: require and implement at least 28 px horizontal padding on both sides.
- Anonymization: account, domain, local path, and private content removed.

### Content

A legacy metadata rectangle and its text shared the same right boundary despite a left inset.
