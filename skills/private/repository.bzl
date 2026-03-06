"""Repository rule that materializes a vendored skills hub."""

load("//skills/private:lockfile.bzl", "decode_lockfile_text")

def _root_build(skill_names):
    lines = [
        "load(\"@bazel_lib//lib:copy_to_directory.bzl\", \"copy_to_directory\")",
        "",
        "package(default_visibility = [\"//visibility:public\"])",
        "",
        "exports_files([\"skill_names.txt\", \"skills_manifest.json\"])",
        "",
        "filegroup(",
        "    name = \"all_skill_trees\",",
        "    srcs = [%s]," % ", ".join(["\"//raw/%s:tree\"" % skill_name for skill_name in skill_names]),
        ")",
        "",
        "copy_to_directory(",
        "    name = \"all_skills_tree\",",
        "    srcs = [%s]," % ", ".join(["\"//raw/%s:tree\"" % skill_name for skill_name in skill_names]),
        "    out = \"all_skills_tree\",",
        "    root_paths = [\"raw\"],",
        "    replace_prefixes = {%s}," % ", ".join([
            "\"%s/tree\": \"%s\"" % (skill_name, skill_name)
            for skill_name in skill_names
        ]),
        ")",
        "",
    ]
    for skill_name in skill_names:
        alias_name = skill_name.replace("-", "_").replace(".", "_") + "_tree"
        lines.extend([
            "alias(",
            "    name = \"%s\"," % alias_name,
            "    actual = \"//raw/%s:tree\"," % skill_name,
            ")",
            "",
        ])
    return "\n".join(lines)

def _skill_build():
    return """load("@bazel_lib//lib:copy_directory.bzl", "copy_directory")

package(default_visibility = ["//visibility:public"])

copy_directory(
    name = "tree",
    src = "src",
    out = "tree",
)
"""

def _archive_url(repo):
    return "https://codeload.github.com/{owner}/{repo}/tar.gz/{commit}".format(
        owner = repo["owner"],
        repo = repo["repo"],
        commit = repo["commit"],
    )

def _skills_hub_repository_impl(repository_ctx):
    lockfile_text = repository_ctx.attr.lockfile_json
    if not lockfile_text:
        lockfile_text = repository_ctx.read(repository_ctx.attr.lockfile)

    repositories = decode_lockfile_text(lockfile_text, context = "%s lockfile" % repository_ctx.name)

    repository_ctx.file("WORKSPACE.bazel", "workspace(name = %r)\n" % repository_ctx.name)

    manifest_entries = []
    skill_names = []
    for repo_name in sorted(repositories.keys()):
        repo = repositories[repo_name]
        extract_dir = "_sources/%s" % repo_name
        repository_ctx.download_and_extract(
            output = extract_dir,
            sha256 = repo["sha256"],
            stripPrefix = repo["strip_prefix"],
            type = "tar.gz",
            url = _archive_url(repo),
        )

        for skill_name in sorted(repo["entries"].keys()):
            entry = repo["entries"][skill_name]
            skill_dir = "raw/%s" % skill_name
            repository_ctx.file("%s/BUILD.bazel" % skill_dir, _skill_build())
            repository_ctx.symlink(
                repository_ctx.path("%s/%s" % (extract_dir, entry["path"])),
                "%s/src" % skill_dir,
            )
            skill_names.append(skill_name)
            manifest_entries.append({
                "name": skill_name,
                "path": entry["path"],
                "repo": repo_name,
                "type": entry["type"],
            })

    repository_ctx.file("skill_names.txt", "\n".join(skill_names) + ("\n" if skill_names else ""))
    repository_ctx.file("skills_manifest.json", json.encode({"skills": manifest_entries}))
    repository_ctx.file("BUILD.bazel", _root_build(skill_names))

skills_hub_repository = repository_rule(
    implementation = _skills_hub_repository_impl,
    attrs = {
        "lockfile": attr.label(allow_single_file = True),
        "lockfile_json": attr.string(),
    },
)
