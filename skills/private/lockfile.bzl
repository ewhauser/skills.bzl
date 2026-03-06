"""Helpers for decoding and merging skills lockfiles."""

def _require(mapping, key, context):
    if key not in mapping:
        fail("%s is missing required field %r" % (context, key))
    return mapping[key]

def _normalize_entry(entry_name, entry, context):
    if type(entry) != type({}):
        fail("%s entry %r must be an object" % (context, entry_name))
    normalized = {
        "path": _require(entry, "path", "%s entry %r" % (context, entry_name)),
        "type": entry.get("type", "skill"),
    }
    if normalized["type"] not in ["bundle", "skill"]:
        fail("%s entry %r has unsupported type %r" % (context, entry_name, normalized["type"]))
    return normalized

def _normalize_repo(repo_name, repo, context):
    if type(repo) != type({}):
        fail("%s repository %r must be an object" % (context, repo_name))
    kind = repo.get("kind", "github_archive")
    if kind != "github_archive":
        fail("%s repository %r has unsupported kind %r" % (context, repo_name, kind))

    entries = _require(repo, "entries", "%s repository %r" % (context, repo_name))
    if type(entries) != type({}):
        fail("%s repository %r field %r must be an object" % (context, repo_name, "entries"))

    normalized_entries = {}
    for entry_name in sorted(entries.keys()):
        normalized_entries[entry_name] = _normalize_entry(entry_name, entries[entry_name], context)

    return {
        "commit": _require(repo, "commit", "%s repository %r" % (context, repo_name)),
        "entries": normalized_entries,
        "kind": kind,
        "owner": _require(repo, "owner", "%s repository %r" % (context, repo_name)),
        "repo": _require(repo, "repo", "%s repository %r" % (context, repo_name)),
        "sha256": _require(repo, "sha256", "%s repository %r" % (context, repo_name)),
        "strip_prefix": _require(repo, "strip_prefix", "%s repository %r" % (context, repo_name)),
    }

def decode_lockfile_text(lockfile_text, context = "lockfile"):
    """Decode and validate one lockfile payload.

    Args:
        lockfile_text: JSON lockfile contents.
        context: Human-readable context for validation errors.

    Returns:
        A normalized repository mapping keyed by repository name.
    """
    data = json.decode(lockfile_text)
    if type(data) != type({}):
        fail("%s must decode to an object" % context)
    repositories = _require(data, "repositories", context)
    if type(repositories) != type({}):
        fail("%s field %r must be an object" % (context, "repositories"))

    normalized = {}
    for repo_name in sorted(repositories.keys()):
        normalized[repo_name] = _normalize_repo(repo_name, repositories[repo_name], context)
    return normalized

def merge_lockfile_texts(lockfile_texts):
    """Merge lockfiles with last-write-wins semantics by repository key.

    Args:
        lockfile_texts: Sequence of JSON lockfile payloads to merge.

    Returns:
        A JSON string containing the merged lockfile payload.
    """
    repositories = {}
    for idx, lockfile_text in enumerate(lockfile_texts):
        for repo_name, repo in decode_lockfile_text(lockfile_text, context = "lockfile %d" % idx).items():
            repositories[repo_name] = repo
    return json.encode({
        "repositories": repositories,
    })
