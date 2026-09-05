#!/usr/bin/env python3
"""Package every skill directory as a namespaced .skill ZIP archive.

Run from this repository, or pass --root explicitly:
    ./package-skills.py
    ./package-skills.py --output /tmp/skills
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import tempfile
import zipfile


SKILL_FILE = "SKILL.md"
IGNORED_DIRECTORY_NAMES = {".git", "__pycache__", "node_modules"}


def skill_directories(root: Path, output: Path) -> list[Path]:
    """Return skill roots without descending into generated or ignored paths."""
    skills: list[Path] = []
    for current, directories, files in os.walk(root):
        current_path = Path(current)
        directories[:] = [
            directory
            for directory in directories
            if directory not in IGNORED_DIRECTORY_NAMES
            and not directory.startswith(".")
            and current_path / directory != output
        ]
        if SKILL_FILE in files:
            skills.append(current_path)
            directories.clear()
    return sorted(skills)


def archive_name(root: Path, skill: Path) -> str:
    relative = skill.relative_to(root)
    if len(relative.parts) == 1:
        namespace = skill.name
        name = skill.name
    elif len(relative.parts) == 2:
        namespace, name = relative.parts
    else:
        raise ValueError(f"Skill must be one or two levels below {root}: {skill}")
    return f"{namespace}--{name}.skill"


def frontmatter_name(skill: Path) -> str:
    frontmatter, _, _ = (skill / SKILL_FILE).read_text().partition("\n---\n")
    match = re.search(r"^name:\s*(\S+)\s*$", frontmatter, re.MULTILINE)
    if not match:
        raise ValueError(f"Skill has no frontmatter name: {skill}")
    return match.group(1)


def package_skill(skill: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with zipfile.ZipFile(temporary_path, "w", zipfile.ZIP_DEFLATED) as archive:
            for file in sorted(skill.rglob("*")):
                if file.is_file() and not any(
                    part in IGNORED_DIRECTORY_NAMES or part.startswith(".")
                    for part in file.relative_to(skill).parts
                ):
                    archive.write(file, file.relative_to(skill).as_posix())
        with zipfile.ZipFile(temporary_path) as archive:
            if SKILL_FILE not in archive.namelist():
                raise ValueError(f"Archive has no root {SKILL_FILE}: {destination}")
        temporary_path.replace(destination)
        destination.chmod(0o644)
    finally:
        temporary_path.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).parent)
    parser.add_argument("--output", type=Path, default=Path("dist"))
    args = parser.parse_args()

    root = args.root.resolve()
    output = args.output.resolve()
    if not root.is_dir():
        parser.error(f"Skill root does not exist: {root}")
    if output == root:
        parser.error("Output directory cannot be the skill root")

    skills = skill_directories(root, output)
    if not skills:
        parser.error(f"No {SKILL_FILE} files found below {root}")

    names: set[str] = set()
    for skill in skills:
        name = archive_name(root, skill)
        expected_skill_name = name.removesuffix(".skill")
        if name in names:
            parser.error(f"Duplicate archive name: {name}")
        if frontmatter_name(skill) != expected_skill_name:
            parser.error(
                f"Frontmatter name must be {expected_skill_name}: {skill / SKILL_FILE}"
            )
        names.add(name)
        package_skill(skill, output / name)
        print(output / name)

    print(f"Packaged {len(skills)} skills in {output}")


if __name__ == "__main__":
    main()
