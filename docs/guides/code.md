---
title: Code Guidance
parent: Guides
---

# Code Guidance

## General Principles

### Code should be correct, clear, and concise — in that order
Correct means _provably_ correct — backed by tests. Every bug fix and new feature should come with tests to catch regressions early.

Deeply nested loops, dynamic blocks, and complex ternaries make it harder to understand what’s going on. That slows down junior engineers, future-you, and anyone trying to get their head around the codebase. The goal isn't to write clever code — it's to write code your teammates can easily understand, use, and maintain.

### Use sensible names
Avoid being cute or cryptic when naming things. Good names carry intent — a well-chosen variable or function name can often replace the need for a comment. Skip vague names like `obj`, `result`, or `foo`.

Use single-letter variables only when they represent well-known concepts (like `e` in `e = mc²`) or when their meaning is immediately obvious in context.

### Don’t repeat yourself (unless it helps)
Avoid repeating code unless breaking it out would hurt readability. As a general rule, if you’ve written the same thing three times, it’s probably time to extract it into a function, variable, or reusable block — see the [Rule of Three](https://en.wikipedia.org/wiki/Rule_of_three_(computer_programming)).

### Use comments when they add value
Comments should explain _why_ something is done — not _how_.

If you find yourself writing a comment to explain how the code works, take a step back. The code itself should be clear enough to make that obvious. If it’s not, consider renaming things or refactoring before reaching for a comment.

### Use pre-commit hooks
Nobody wants a commit history full of “Fix linting”, “format”, and “oops, one more”.

Set up pre-commit hooks so you catch formatting, linting, and other issues before your code ever hits the repo. It saves you time, avoids noisy commits, and lets pipelines focus on real problems and not missing indentation.

### Fail fast and loudly
If something isn’t right, a required variable is missing or a resource isn't found, surface it early. Don’t let issues silently propagate and cause confusing failures later on.

### Keep outputs clean and useful
Only expose outputs that are needed by other systems or users. Don’t output secrets.