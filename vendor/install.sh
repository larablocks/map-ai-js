#!/usr/bin/env bash
# install.sh — copy MAP template files into an existing project
# Usage: ./install.sh <target-project-path> [--force]
# Run from the map-ai repo root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

TARGET=""
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -*) echo "Unknown option: $arg"; exit 1 ;;
    *) TARGET="$arg" ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target-project-path> [--force]"
  echo ""
  echo "  --force   Overwrite SCAFFOLD_FILES that already exist (backed up to <file>.bak first)"
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "Error: '$TARGET' is not a directory"
  exit 1
fi

# ---------------------------------------------------------------------------
# Copy files
# ---------------------------------------------------------------------------
# MANAGED_FILES, SCAFFOLD_FILES, GITIGNORE_GROUP_*, and GITATTRIBUTES_BLOCK
# come from lib.sh (shared with doctor.sh).
echo "Installing MAP into: $TARGET"
echo ""

COPIED=0
SKIPPED=0
MISSING=0
IDENTICAL=0
SYMLINKS=0

# normalize_lines() comes from lib.sh — shared by the .gitignore and
# .gitattributes merge steps below.

# Sets SRC/DST for $1 and returns 1 (after counting MISSING) if the stub
# source doesn't exist, or returns 1 (after counting SYMLINKS) if the
# destination is a symlink — never write through a symlink, since cp follows
# it and could silently write outside the target directory entirely.
# Shared by copy_managed() and copy_scaffold().
resolve_source() {
  local file="$1"
  SRC="$SCRIPT_DIR/stubs/$file"
  DST="$TARGET/$file"

  if [[ ! -f "$SRC" ]]; then
    echo "  [WARN]   source not found — $file"
    ((MISSING++)) || true
    return 1
  fi

  if [[ -L "$DST" ]]; then
    echo "  [WARN]   $file is a symlink — skipped to avoid writing through it"
    ((SYMLINKS++)) || true
    return 1
  fi

  return 0
}

copy_managed() {
  local file="$1"
  resolve_source "$file" || return 0

  if [[ -f "$DST" ]] && cmp -s "$SRC" "$DST"; then
    echo "  [SAME]   $file  (matches template already)"
    ((IDENTICAL++)) || true
    return
  fi

  local existed=0
  [[ -f "$DST" ]] && existed=1

  mkdir -p "$(dirname "$DST")"
  cp "$SRC" "$DST"

  if [[ $existed -eq 1 ]]; then
    echo "  [UPDATE] $file"
  else
    echo "  [COPY]   $file"
  fi
  ((COPIED++)) || true
}

copy_scaffold() {
  local file="$1"
  local src dst
  resolve_source "$file" || return 0
  src="$SRC"
  dst="$DST"

  if [[ -f "$dst" ]]; then
    if [[ $FORCE -eq 0 ]]; then
      echo "  [SKIP]   $file  (already exists — use --force to overwrite)"
      ((SKIPPED++)) || true
      return
    fi

    if cmp -s "$src" "$dst"; then
      echo "  [SAME]   $file  (matches template already, no backup needed)"
      ((IDENTICAL++)) || true
      return
    fi

    cp "$dst" "$dst.bak"
    cp "$src" "$dst"
    echo "  [UPDATE] $file  (backed up to $file.bak)"
    ((COPIED++)) || true
    return
  fi

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "  [COPY]   $file"
  ((COPIED++)) || true
}

for file in "${MANAGED_FILES[@]}"; do
  copy_managed "$file"
done

for file in "${SCAFFOLD_FILES[@]}"; do
  copy_scaffold "$file"
done

# ---------------------------------------------------------------------------
# Merge .gitignore
# ---------------------------------------------------------------------------
echo ""
echo "Merging .gitignore..."

GITIGNORE_FILE="$TARGET/.gitignore"
touch "$GITIGNORE_FILE"
# Normalize CRLF and trailing whitespace before matching, so a line that's
# already present but byte-different (e.g. CRLF line endings) isn't treated
# as missing and re-appended as a duplicate.
GITIGNORE_EXISTING="$(normalize_lines "$GITIGNORE_FILE")"

# Takes a group's header followed by its entries as plain positional args
# (not indirect variable-name expansion, which is unreliable across bash
# versions) and appends to GITIGNORE_ADDITIONS only what's actually missing.
add_gitignore_group_if_missing() {
  local header="$1"
  shift
  local entries=("$@")

  local missing=()
  for line in "${entries[@]}"; do
    if ! grep -qxF "$line" <<< "$GITIGNORE_EXISTING"; then
      missing+=("$line")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return
  fi

  if [[ ${#missing[@]} -eq ${#entries[@]} ]]; then
    GITIGNORE_ADDITIONS+=("$header
$(printf '%s\n' "${entries[@]}")")
  else
    GITIGNORE_ADDITIONS+=("$(printf '%s\n' "${missing[@]}")")
  fi
}

GITIGNORE_ADDITIONS=()
add_gitignore_group_if_missing "$GITIGNORE_GROUP_1_HEADER" "${GITIGNORE_GROUP_1[@]}"
add_gitignore_group_if_missing "$GITIGNORE_GROUP_2_HEADER" "${GITIGNORE_GROUP_2[@]}"
add_gitignore_group_if_missing "$GITIGNORE_GROUP_3_HEADER" "${GITIGNORE_GROUP_3[@]}"

if [[ ${#GITIGNORE_ADDITIONS[@]} -eq 0 ]]; then
  echo "  [SKIP]   .gitignore — MAP entries already present"
else
  {
    for addition in "${GITIGNORE_ADDITIONS[@]}"; do
      echo ""
      echo "$addition"
    done
  } >> "$GITIGNORE_FILE"
  echo "  [UPDATE] .gitignore — MAP entries appended"
fi

# ---------------------------------------------------------------------------
# Merge .gitattributes
# ---------------------------------------------------------------------------
echo ""
echo "Merging .gitattributes..."

GITATTRIBUTES_FILE="$TARGET/.gitattributes"
touch "$GITATTRIBUTES_FILE"
GITATTRIBUTES_EXISTING="$(normalize_lines "$GITATTRIBUTES_FILE")"

MISSING_ATTRS=()
for line in "${GITATTRIBUTES_BLOCK[@]}"; do
  if ! grep -qxF "$line" <<< "$GITATTRIBUTES_EXISTING"; then
    MISSING_ATTRS+=("$line")
  fi
done

if [[ ${#MISSING_ATTRS[@]} -eq 0 ]]; then
  echo "  [SKIP]   .gitattributes — MAP entries already present"
elif [[ ${#MISSING_ATTRS[@]} -eq ${#GITATTRIBUTES_BLOCK[@]} ]]; then
  {
    echo ""
    echo "# MAP — merge-friendly append-only logs"
    for line in "${GITATTRIBUTES_BLOCK[@]}"; do
      echo "$line"
    done
  } >> "$GITATTRIBUTES_FILE"
  echo "  [UPDATE] .gitattributes — MAP entries appended"
else
  # Some entries already present — append only the missing ones so existing
  # lines aren't duplicated.
  {
    echo ""
    for line in "${MISSING_ATTRS[@]}"; do
      echo "$line"
    done
  } >> "$GITATTRIBUTES_FILE"
  echo "  [UPDATE] .gitattributes — MAP entries appended"
fi

# ---------------------------------------------------------------------------
# Initialize personal files — gitignored, bootstrapped from their tracked
# *.example.md counterpart, never overwritten if already present. Mirrors
# Installer::bootstrapPersonalFiles(); PERSONAL_FILES comes from lib.sh.
# ---------------------------------------------------------------------------
echo ""
echo "Initializing personal files..."
echo ""

for pair in "${PERSONAL_FILES[@]}"; do
  example="${pair%%:*}"
  personal="${pair#*:}"
  src="$TARGET/$example"
  dst="$TARGET/$personal"

  if [[ ! -f "$src" ]]; then
    echo "  [WARN]   source not found — $example"
    continue
  fi

  if [[ -f "$dst" ]]; then
    echo "  [EXISTS] $personal"
    continue
  fi

  cp "$src" "$dst"
  echo "  [INIT]   $personal"
done

# ---------------------------------------------------------------------------
# Summary and next steps
# ---------------------------------------------------------------------------
echo ""
echo "Done. $COPIED file(s) copied/updated, $SKIPPED skipped, $IDENTICAL already up to date, $MISSING missing from source, $SYMLINKS symlinked destination(s) left untouched."
echo ""
echo "Next steps:"
echo "  1. Edit AGENTS.md line 2 — set project name and stack"
echo "  2. Edit AGENTS.md line 3 — set today's date"
echo "  3. Fill in the Commands section of AGENTS.md (test, build, start)"
echo ""
echo "MAP install complete."
