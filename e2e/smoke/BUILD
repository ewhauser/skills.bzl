load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@skills.bzl//skills:defs.bzl", "skill_install")

skill_install(
    name = "smoke_skills",
    destination = ".claude/skills",
    skills = ["screenshot"],
)

build_test(
    name = "smoke_test",
    targets = [
        "@skills//raw/screenshot:tree",
        ":smoke_skills",
        ":smoke_skills.sync",
        ":smoke_skills.sync_test",
    ],
)
