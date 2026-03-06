# skills.bzl

Bazel 9+ rules for vendoring agent skills from pinned upstream repositories.

`skills.bzl` is built around a checked-in lockfile. A consumer repo pins upstream
archives in `skills.lock.json`, loads the module extension, and gets raw skill
tree targets like `@skills//raw/screenshot:tree`. Those raw trees can then be:

- consumed directly as Bazel artifacts
- patched or overlaid in the build graph
- staged into an install tree
- synced back into `.claude/skills` or another source-tree directory

## bzlmod

```starlark
bazel_dep(name = "skills.bzl", version = "...")

skills = use_extension("@skills.bzl//skills:extensions.bzl", "skills")
skills.hub(lockfile = "//:skills.lock.json")
use_repo(skills, "skills")
```

Stage a subset of skills:

```starlark
load("@skills.bzl//skills:defs.bzl", "skill_install")

skill_install(
    name = "claude_skills",
    destination = ".claude/skills",
    skills = ["screenshot"],
)
```

This creates:

- `:claude_skills` - staged install tree
- `:claude_skills.sync` - copy staged managed skills into the source tree
- `:claude_skills.sync_test` - fail if the source tree is missing or stale

Sync is additive-only. It refreshes the skills currently declared in Bazel and leaves
removed or renamed previously-synced skill directories in place until you delete them
manually.

## Lockfile

Example:

```json
{
  "$schema": "./skills.lock.schema.json",
  "repositories": {
    "openai_skills": {
      "kind": "github_archive",
      "owner": "openai",
      "repo": "skills",
      "commit": "ce2535c009ef92f4065be9626ae695c9ecd77e61",
      "sha256": "06e0b1b8934cb4ccdbad1f2efc4b21cb26f012333e0a68d791cdccc9236c1170",
      "strip_prefix": "skills-ce2535c009ef92f4065be9626ae695c9ecd77e61",
      "entries": {
        "screenshot": {
          "path": "skills/.curated/screenshot"
        }
      }
    }
  }
}
```

## Patch and overlay flow

`skill_install` accepts:

- `patches = {"skill-name": ["//path:change.diff"]}`
- `overlays = {"skill-name": ["//path:overlay_tree"]}`

Patch files are applied first with `patch -p1`. Overlay trees are copied last
and win on path conflicts.

Overlay labels must provide a single tree artifact rooted at the skill
directory. A simple way to build one is with `@bazel_lib//lib:copy_to_directory.bzl`.
