#!/usr/bin/env python3
"""Export source, documentation and approved bonus images; exclude originals and binary releases."""
from pathlib import Path
import argparse
import shutil

PROJECT = Path(__file__).resolve().parents[1]
FILES = [
    'README.md', 'LICENSE', 'docs/ASSETS.md', 'docs/PRIVACY.md', 'SECURITY.md',
    'docs/CONTRIBUTING.md', 'docs/CHANGELOG.md', '.gitignore', 'Resources/Info.plist',
    'Sources/WallpaperApp.swift', 'Sources/DayWallpaper.swift', 'Sources/Shared.swift',
    'scripts/build.sh', 'scripts/open-app.command', 'Resources/使用说明.txt',
    'scripts/test.sh', 'scripts/strip_photo_metadata.py',
    'scripts/make_example_background.swift', 'scripts/make_icon.swift', 'scripts/export_public_source.py',
    'Tests/main.swift', 'Tests/test_metadata.py', 'Tests/test_worker_preview.py',
    'docs/INSTALL.md', 'docs/DEVELOPMENT.md', 'docs/UNINSTALL.md', 'docs/RELEASING.md', 'docs/VALIDATION.md', 'docs/LICENSE-MIT.proposed',
    'docs/images/interface.svg', 'docs/images/example-wallpaper.png', 'docs/images/lion-wallpaper.jpg',
    'bonus/README.md', 'bonus/lion.jpg',
    '.github/workflows/macos.yml', '.github/ISSUE_TEMPLATE/bug_report.md',
    '.github/pull_request_template.md',
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    destination = parser.parse_args().destination.resolve()
    if destination == PROJECT or PROJECT in destination.parents:
        raise ValueError('Destination must be outside the project')
    if destination.exists():
        raise ValueError('Destination already exists; choose a new empty destination')
    # Validate before creating the export; do not copy symlinks or unknown files.
    for relative in FILES:
        path = PROJECT / relative
        if path.is_symlink() or not path.is_file():
            raise ValueError(f'Missing or unsafe source: {relative}')
    destination.mkdir(parents=True)
    for relative in FILES:
        source = PROJECT / relative
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    print(f'Exported {len(FILES)} source/documentation files. Original photos, logs, user settings, apps and DMGs excluded; approved bonus images included.')


if __name__ == '__main__':
    main()
