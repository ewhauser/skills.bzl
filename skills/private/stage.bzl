"""Rules for customizing vendored skill trees."""

def _single_directory(target, attr_name):
    files = target[DefaultInfo].files.to_list()
    if len(files) != 1 or not files[0].is_directory:
        fail("%s must provide exactly one directory artifact" % attr_name)
    return files[0]

def _customize_skill_tree_impl(ctx):
    src = _single_directory(ctx.attr.src, "src")
    overlays = [_single_directory(overlay, "overlays") for overlay in ctx.attr.overlays]
    out = ctx.actions.declare_directory(ctx.attr.name)

    inputs = [src] + overlays + ctx.files.patches
    patch_count = len(ctx.files.patches)
    overlay_count = len(overlays)

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = [out],
        arguments = [out.path, src.path, str(patch_count), str(overlay_count)] + [f.path for f in ctx.files.patches] + [d.path for d in overlays],
        command = """set -euo pipefail
out="$1"
src="$2"
patch_count="$3"
overlay_count="$4"
shift 4

tmp="$(mktemp -d)"
work="${tmp}/work"
mkdir -p "${work}"
cp -R "${src}/." "${work}" 2>/dev/null || true
chmod -R u+w "${work}" 2>/dev/null || true

for ((i = 0; i < patch_count; i++)); do
  patch_file="$1"
  shift
  patch -d "${work}" -p1 < "${patch_file}"
done

for ((i = 0; i < overlay_count; i++)); do
  overlay_dir="$1"
  shift
  cp -R "${overlay_dir}/." "${work}"
done

mkdir -p "${out}/%s"
cp -R "${work}/." "${out}/%s"
""" % (ctx.attr.skill_name, ctx.attr.skill_name),
        progress_message = "Customizing vendored skill %s" % ctx.attr.skill_name,
        mnemonic = "CustomizeSkillTree",
    )

    return [DefaultInfo(files = depset([out]))]

customize_skill_tree = rule(
    implementation = _customize_skill_tree_impl,
    attrs = {
        "overlays": attr.label_list(
            doc = "Overlay tree artifacts rooted at the skill directory.",
        ),
        "patches": attr.label_list(
            allow_files = True,
            doc = "Unified diff patch files applied with patch -p1.",
        ),
        "skill_name": attr.string(mandatory = True),
        "src": attr.label(mandatory = True),
    },
)
