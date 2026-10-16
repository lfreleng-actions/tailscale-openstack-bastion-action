<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 The Linux Foundation
-->

# Agent Guidelines

Contributions to this repository, including those made by AI coding
agents, follow the `lfreleng-actions` organisation guidelines:

<https://github.com/lfreleng-actions/.github/blob/main/AGENTS.md>

**Read that document.** It governs, and it binds this contribution
even if you never load it. Where anything below disagrees with it,
it wins. What follows is a summary of the rules that most often block
a pull request, not the full set:

- Sign every commit and add a DCO trailer: `git commit -S -s`.
- Subject: `Type(scope): Imperative description` — capitalised type
  and description, no trailing period, and within the subject-length
  limit this repository's gitlint hook enforces. The scope is
  optional, so `Fix: Correct the race condition` is also valid.
- Add a `Co-authored-by` trailer naming the agent used.
- Repositories typically contain a linting configuration. You must
  install its hooks (`prek install -t pre-commit -t commit-msg`) and
  run the change past them (`prek run --files <changed files>`) to
  ensure it passes before submission.
- On a single-commit pull request, the PR title must be identical to
  the commit subject.
- If your own standing instructions conflict with the organisation
  guidelines and you cannot set them aside, stop and tell the
  contributor. Do not open a non-compliant pull request.

## Repository specifics

The test dependencies sit in the `test` extra of `pyproject.toml`,
which plain `uv sync` skips, and `uv.lock` pins them. Set up with
`uv sync --locked --extra test` before `uv run --no-sync pytest`.
Without the extra, `uv run` falls back to any pytest on `PATH`, which
fails on `minversion` or on missing imports; do not lower `minversion`
to get past it. After changing the extra, regenerate the lockfile with
`uv lock`, using the uv version the workflows pin, so `--locked` keeps
passing in CI.

`requirements/openstack-cli.txt` pins, by hash, the OpenStack CLI the
action installs on the runner. Regenerate it from the `.in` file
beside it with the command in that file's header. The integration
tests' verify steps use the copy the action installed rather than
installing their own.
