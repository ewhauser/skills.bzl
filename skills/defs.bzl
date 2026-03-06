"""Public macros for staging and syncing vendored skills."""

load("@bazel_lib//lib:copy_directory.bzl", "copy_directory")
load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//skills/private:stage.bzl", "customize_skill_tree")

def _normalize(name):
    return name.replace("-", "_").replace(".", "_").replace("/", "_")

def _label_in_this_package(name):
    pkg = native.package_name()
    if pkg:
        return "//%s:%s" % (pkg, name)
    return "//:%s" % name

def _skill_tree_label(skills_repo, skill):
    return "@%s//raw/%s:tree" % (skills_repo, skill)

def skill_sync(name, staged_tree, destination, skills_repo = "skills", skills = None, tags = None, visibility = None):
    """Create runnable sync targets for a staged install tree.

    Args:
        name: Target name prefix for the sync binary and test.
        staged_tree: Label for the staged install tree artifact.
        destination: Source-tree destination directory relative to the workspace root.
        skills_repo: External repo name created by the bzlmod extension.
        skills: Optional explicit list of managed skill names.
        tags: Optional tags propagated to generated targets.
        visibility: Optional visibility propagated to generated targets.
    """
    manifest_target = "@%s//:skill_names.txt" % skills_repo
    if skills != None:
        manifest_target = name.replace(".", "_") + "_manifest"
        native.genrule(
            name = manifest_target,
            outs = [manifest_target + ".txt"],
            cmd = "cat > $@ <<'EOF'\n%s\nEOF\n" % "\n".join(sorted(skills)),
            tags = ["manual"],
            visibility = ["//visibility:private"],
        )
        manifest_target = ":" + manifest_target

    sh_binary(
        name = name,
        srcs = [Label("//skills/private:sync_skills.sh")],
        args = [
            "$(location %s)" % staged_tree,
            destination,
            "$(location %s)" % manifest_target,
        ],
        data = [
            staged_tree,
            manifest_target,
        ],
        tags = tags,
        visibility = visibility,
    )

    sh_test(
        name = name + "_test",
        srcs = [Label("//skills/private:verify_sync.sh")],
        args = [
            "$(location %s)" % staged_tree,
            destination,
            "$(location %s)" % manifest_target,
            _label_in_this_package(name),
        ],
        data = [
            staged_tree,
            manifest_target,
        ],
        tags = tags,
        visibility = visibility,
    )

def skill_install(name, destination = None, skills = None, skills_repo = "skills", patches = {}, overlays = {}, tags = None, visibility = None):
    """Stage vendored skills as a single install tree.

    Args:
        name: target name for the aggregate install tree.
        destination: optional source-tree directory for generated `.sync` targets.
        skills: list of skill names. Required when `patches` or `overlays` are used.
        skills_repo: external repository name created by the bzlmod extension.
        patches: dict mapping skill name to patch labels.
        overlays: dict mapping skill name to overlay tree labels.
        tags: optional tags propagated to generated targets.
        visibility: optional visibility propagated to generated targets.
    """
    if not skills and (patches or overlays):
        fail("skill_install requires an explicit skills list when patches or overlays are used")

    if not skills:
        copy_directory(
            name = name,
            src = "@%s//:all_skills_tree" % skills_repo,
            out = name,
            visibility = visibility,
            tags = tags,
        )
    else:
        staged = []
        for skill in skills:
            target_name = "%s__%s" % (name, _normalize(skill))
            customize_skill_tree(
                name = target_name,
                src = _skill_tree_label(skills_repo, skill),
                skill_name = skill,
                overlays = overlays.get(skill, []),
                patches = patches.get(skill, []),
                tags = ["manual"],
                visibility = ["//visibility:private"],
            )
            staged.append(":" + target_name)

        copy_to_directory(
            name = name,
            srcs = staged,
            out = name,
            allow_overwrites = False,
            visibility = visibility,
            tags = tags,
        )

    if destination:
        skill_sync(
            name = name + ".sync",
            staged_tree = ":" + name,
            destination = destination,
            skills = skills,
            skills_repo = skills_repo,
            tags = tags,
            visibility = visibility,
        )
