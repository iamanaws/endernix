#!/usr/bin/env python3
"""
Resolve Modrinth mods and generate a Nix lockfile.

Usage:
    update-mods mods.nix [output.lock.nix]
"""

import json
import subprocess
import sys
import urllib.request
import urllib.error
import urllib.parse
import hashlib
import base64
from pathlib import Path

API_BASE = "https://api.modrinth.com/v2"
USER_AGENT = "endernix/1.0 (github.com/iamanaws/endernix)"


def api_get(endpoint: str) -> dict:
    """Make a GET request to the Modrinth API."""
    url = f"{API_BASE}{endpoint}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        print(f"Error fetching {url}: {e.code} {e.reason}", file=sys.stderr)
        sys.exit(1)


def get_project(slug: str) -> dict:
    """Get project info by slug."""
    return api_get(f"/project/{slug}")


def get_versions(project_id: str, loader: str = None, game_version: str = None) -> list:
    """Get all versions for a project, optionally filtered."""
    params = {}
    if loader:
        params["loaders"] = json.dumps([loader])
    if game_version:
        params["game_versions"] = json.dumps([game_version])
    
    endpoint = f"/project/{project_id}/version"
    if params:
        endpoint += "?" + urllib.parse.urlencode(params)
    
    return api_get(endpoint)


def find_version(versions: list, version_number: str = None) -> dict:
    """Find a specific version or return the latest."""
    if version_number:
        for v in versions:
            if v["version_number"] == version_number:
                return v
        print(f"Version {version_number} not found", file=sys.stderr)
        sys.exit(1)
    
    if not versions:
        print("No versions found", file=sys.stderr)
        sys.exit(1)
    return versions[0]


def get_primary_file(version: dict) -> dict:
    """Get the primary file from a version."""
    files = version.get("files", [])
    if not files:
        print(f"No files in version {version['version_number']}", file=sys.stderr)
        sys.exit(1)
    
    for f in files:
        if f.get("primary", False):
            return f
    return files[0]


def compute_sri_hash(url: str) -> str:
    """Download file and compute SRI hash."""
    print(f"  Downloading to compute hash...", file=sys.stderr)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    
    with urllib.request.urlopen(req) as resp:
        data = resp.read()
    
    sha256 = hashlib.sha256(data).digest()
    b64 = base64.b64encode(sha256).decode()
    return f"sha256-{b64}"


def resolve_mod(name: str, spec) -> dict:
    """Resolve a mod specification to a lockfile entry."""
    if isinstance(spec, str):
        spec = {"version": spec}
    
    project_slug = spec.get("project", name)
    version_number = spec.get("version")
    loader = spec.get("loader", "fabric")
    game_version = spec.get("gameVersion")
    
    print(f"Resolving {name}...", file=sys.stderr)
    
    project = get_project(project_slug)
    project_id = project["id"]
    
    versions = get_versions(project_id, loader, game_version)
    version = find_version(versions, version_number)
    file_info = get_primary_file(version)
    
    url = file_info["url"]
    sri_hash = compute_sri_hash(url)
    
    return {
        "projectId": project_id,
        "versionId": version["id"],
        "version": version["version_number"],
        "filename": file_info["filename"],
        "url": url,
        "hash": sri_hash,
    }


def read_nix_file(path: Path) -> dict:
    """Read a Nix file and return as Python dict."""
    result = subprocess.run(
        ["nix", "eval", "--json", "--file", str(path)],
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        print(f"Error reading {path}:", file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        sys.exit(1)
    
    return json.loads(result.stdout)


def to_nix_value(value, indent=2) -> str:
    """Convert a Python value to Nix syntax."""
    spaces = " " * indent
    
    if value is None:
        return "null"
    elif isinstance(value, bool):
        return "true" if value else "false"
    elif isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    elif isinstance(value, (int, float)):
        return str(value)
    elif isinstance(value, list):
        if not value:
            return "[ ]"
        items = " ".join(to_nix_value(v, indent) for v in value)
        return f"[ {items} ]"
    elif isinstance(value, dict):
        if not value:
            return "{ }"
        lines = []
        for k, v in value.items():
            if k.isidentifier() and not k.startswith("-"):
                key = k
            else:
                key = f'"{k}"'
            lines.append(f"{spaces}{key} = {to_nix_value(v, indent + 2)};")
        inner = "\n".join(lines)
        return f"{{\n{inner}\n{' ' * (indent - 2)}}}"
    else:
        return str(value)


def write_nix_lockfile(lock: dict, path: Path):
    """Write the lockfile as a Nix expression."""
    with open(path, "w") as f:
        f.write("# Auto-generated by update-mods. Do not edit.\n")
        f.write(to_nix_value(lock))
        f.write("\n")


def main():
    if len(sys.argv) < 2:
        print("Usage: update-mods <mods.nix> [output.lock.nix]", file=sys.stderr)
        sys.exit(1)
    
    input_file = Path(sys.argv[1])
    
    if len(sys.argv) > 2:
        output_file = Path(sys.argv[2])
    else:
        stem = input_file.stem
        output_file = input_file.with_name(f"{stem}.lock.nix")
    
    mods = read_nix_file(input_file)
    
    lock = {}
    for name, spec in mods.items():
        lock[name] = resolve_mod(name, spec)
    
    write_nix_lockfile(lock, output_file)
    
    print(f"\nWrote {output_file}", file=sys.stderr)


if __name__ == "__main__":
    main()
