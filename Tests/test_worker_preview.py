"""Regression: each day's rendered wallpaper must get a fresh system cache identity."""
from pathlib import Path
import os
import plistlib
import subprocess
import sys
import tempfile

worker = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='daywallpaper-preview-regression.') as folder:
    root = Path(folder).resolve()
    settings = {'startDate': '2024-01-01', 'playerName': 'PreviewPlayer', 'backgroundMode': 'default'}
    (root / 'settings.plist').write_bytes(plistlib.dumps(settings))
    def render(day):
        env = dict(os.environ, DAYWALLPAPER_PREVIEW_ROOT=str(root), DAYWALLPAPER_PREVIEW_DATE=day)
        result = subprocess.run([str(worker), '--preview'], env=env, capture_output=True, text=True, check=True)
        output = Path(result.stdout.strip().splitlines()[-1]).resolve()
        assert output.is_file(), 'Rendered image must exist'
        assert output.parent == root, 'Preview must remain inside the isolated root'
        assert 'PreviewPlayer' not in output.name and settings['startDate'] not in output.name, 'File names must not disclose player or start date'
        return output
    old = render('2026-11-10')
    new = render('2026-11-13')
    assert old != new, 'STALE-CACHE REGRESSION: two dates three days apart use the same wallpaper URL'
    assert render('2026-11-13') == new, 'Same content must have a stable URL within the day'
    settings['playerName'] = 'ChangedPlayer'
    (root / 'settings.plist').write_bytes(plistlib.dumps(settings))
    assert render('2026-11-13') != new, 'Same-day settings changes must invalidate system image caches'
    assert not (root / 'last-date.txt').exists(), 'Preview must never mark a real application successful'
    print('Passed worker preview regression: dates, settings, identity, privacy, and preview isolation.')
