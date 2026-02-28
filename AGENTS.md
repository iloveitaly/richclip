# General Instructions

Coding instructions for all programming languages:

- Never use emojis anywhere unless explicitly requested.
- If no language is specified, assume the latest version of python.
- If tokens or other secrets are needed, pull them from an environment variable
- Prefer early returns over nested if statements.
- Prefer `continue` within a loop vs nested if statements.
- Prefer smaller functions over larger functions. Break up logic into smaller chunks with well-named functions.
- Prefer constants with separators: `10_000` is preferred to `10000` (or `10_00` over `1000` in the case of a integer representing cents).
- Only add comments if the code is not self-explanatory. Do not add obvious code comments.
- Do not remove existing comments.
- When I ask you to write code, prioritize simplicity and legibility over covering all edge cases, handling all errors, etc.
- When a particular need can be met with a mature, reasonably adopted and maintained package, I would prefer to use that package rather than engineering my own solution.
- Never add error handling to catch an error without being asked to do so. Fail hard and early with assertions and allow exceptions to propagate.
- When naming variables or functions, use names that describe the effect. For example, instead of `function handleClaimFreeTicket` (a function which opens a dialog box) use `function openClaimFreeTicketDialog`.
- Do not install missing system packages! Instead, ask me to install them for you.
- If terminal commands are failing because of missing variables or commands which are unrelated to your current task, stop your work and let me know.
- Don't worry about fixing lint errors or running lint scripts unless I specifically ask you to.
- When implementing workarounds for tooling limitations (like using `Any` for unresolvable types) or handling non-obvious edge cases, always add a brief inline comment explaining the technical reasoning.

Use line breaks to organize code into logical groups. Instead of:

```python
if not client_secret_id:
    raise HTTPException(status.HTTP_400_BAD_REQUEST)
session_id = client_secret_id.split("_secret")[0]
```

Prefer:

```python
if not client_secret_id:
    raise HTTPException(status.HTTP_400_BAD_REQUEST)

session_id = client_secret_id.split("_secret")[0]
```

**DO NOT FORGET**: keep your responses short, dense, and without fluff. I am a senior, well-educated software engineer, and hate long explanations.

## Deeply Inspect Packages by Cloning Repository

You can clone any packages you may need to look closely at into `tmp/` in order to inspect the logic and functionality more closely. No need to cleanup, `tmp/` will be automatically cleaned up later.

## Expert Engineer With Limited Domain Knowledge, Add Comments

Assume the person reading this code is an expert software engineer, but is not familiar with the internals of every system. This means including concise one-line comments explaining key hooks / API usage, blocks of logic, etc are helpful to allow the reader to quickly understand what is going on in the code you've written.

Look at the code you've written and consider add one-line comments based on these instructions.
