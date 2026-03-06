"""Bzlmod extension for vendored skills hubs."""

load("//skills/private:lockfile.bzl", "merge_lockfile_texts")
load("//skills/private:repository.bzl", "skills_hub_repository")

_DEFAULT_HUB_NAME = "skills"

hub = tag_class(attrs = {
    "hub_name": attr.string(default = _DEFAULT_HUB_NAME),
    "lockfile": attr.label(mandatory = True, allow_single_file = True),
})

def _skills_extension(module_ctx):
    if not module_ctx.modules:
        fail("skills.bzl requires bzlmod and Bazel 9+")

    hubs = {}
    root_module_direct_deps = {}
    root_module_direct_dev_deps = {}

    for mod in reversed(module_ctx.modules):
        for tag in mod.tags.hub:
            if tag.hub_name not in hubs:
                hubs[tag.hub_name] = []
            hubs[tag.hub_name].append(module_ctx.read(tag.lockfile))
            if mod.is_root:
                deps = root_module_direct_dev_deps if module_ctx.is_dev_dependency(tag) else root_module_direct_deps
                deps[tag.hub_name] = True

    for hub_name, lockfile_texts in hubs.items():
        skills_hub_repository(
            name = hub_name,
            lockfile_json = merge_lockfile_texts(lockfile_texts),
        )

    return module_ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = root_module_direct_deps.keys(),
        root_module_direct_dev_deps = root_module_direct_dev_deps.keys(),
    )

skills = module_extension(
    doc = "Vendored skills hub extension. Bazel 9+ and bzlmod only.",
    implementation = _skills_extension,
    tag_classes = {"hub": hub},
    arch_dependent = False,
    os_dependent = False,
)
