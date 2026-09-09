#!/usr/bin/env bash
# Called only after the fork release tests pass. Never publish upstream crates.
set -euo pipefail
version=$(python3 -c 'import tomllib; print(tomllib.load(open("Cargo.toml", "rb"))["package"]["version"])')
name=$(python3 -c 'import tomllib; print(tomllib.load(open("Cargo.toml", "rb"))["package"]["name"])')
test "$GITHUB_REF_NAME" = "release-$version"
commit=$(git rev-parse HEAD)
test "$(git rev-parse --verify "refs/tags/$GITHUB_REF_NAME^{commit}")" = "$commit"
state=$(gh api --paginate --slurp "repos/$GITHUB_REPOSITORY/releases" --jq 'flatten | map({tag_name,draft})' | python3 -c 'import json,os,sys; item=next((r for r in json.load(sys.stdin) if r["tag_name"]==os.environ["GITHUB_REF_NAME"]),None); print("missing" if item is None else "draft" if item["draft"] else "published")')
case "$state" in
  published)
    echo 'Published fork releases are not replaced; use a new version.' >&2
    exit 1
    ;;
  draft)
    echo "Existing draft $GITHUB_REF_NAME remains unpublished."
    ;;
  missing)
    notes="$RUNNER_TEMP/canoe-fork-release-notes.md"
    printf '%s\n' "$name $version — fork release of $GITHUB_REPOSITORY" '' "Source: $commit" '' 'This draft records the tested fork source and any separately uploaded CLI artifacts. It does not publish the upstream crate on crates.io.' 'Review the source and CI results before publishing.' > "$notes"
    gh release create "$GITHUB_REF_NAME" --repo "$GITHUB_REPOSITORY" --verify-tag --draft --title "$name $version (fork)" --notes-file "$notes"
    ;;
  *) echo 'Unexpected release state' >&2; exit 1 ;;
esac
