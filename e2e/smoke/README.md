# smoke test

This e2e exercises `skills.bzl` from an end-user Bazel module.

It verifies that:

- a lockfile can materialize the `@skills` repo under bzlmod
- a raw skill tree target can be built from that repo
- `skill_install` can stage and sync an install tree
