"""Check real mouse input after dismissing and reopening the GTK tour."""
import json
from pathlib import Path
import subprocess
import sys
import time

import pyatspi


def wait_for(check, description, timeout=15):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        result = check()
        if result:
            return result
        time.sleep(.15)
    raise AssertionError(description)


def buttons():
    result = {}

    def visit(node):
        try:
            if node.getRoleName() == 'push button' and node.getState().contains(pyatspi.STATE_SHOWING):
                result[node.name] = node
            for child in node:
                visit(child)
        except Exception:
            pass

    visit(pyatspi.Registry.getDesktop(0))
    return result


def click_at(x, y):
    subprocess.run(['xdotool', 'mousemove', '--sync', str(x), str(y), 'click', '1'], check=True)
    time.sleep(.3)


def click_button(name):
    node = wait_for(lambda: buttons().get(name), 'Button missing: ' + name)
    bounds = node.queryComponent().getExtents(pyatspi.DESKTOP_COORDS)
    print('Mouse click', name, tuple(bounds), flush=True)
    assert bounds.width > 0 and bounds.height > 0
    click_at(bounds.x + bounds.width // 2, bounds.y + bounds.height // 2)


qa, library, data, *command = sys.argv[1:]
qa, library, data = map(Path, (qa, library, data))
qa.mkdir(parents=True, exist_ok=True)
library.mkdir(parents=True, exist_ok=True)
(library / 'preferences.json').write_text(json.dumps({'theme': 'Dark', 'tour_seen': False}))
canvas = data / 'canvas.life.json'


def population():
    try:
        return sum(sum(row) for row in json.loads(canvas.read_text())['grid'])
    except (FileNotFoundError, json.JSONDecodeError):
        return -1


with (qa / 'pointer-app.log').open('w') as log:
    app = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
    try:
        click_button('Skip')
        wait_for(lambda: 'Skip' not in buttons(), 'Tour did not close')
        click_button('Clear')
        wait_for(lambda: population() == 0, 'Clear ignored mouse click after closing tour')
        click_button('Generate')
        wait_for(lambda: population() > 1, 'Generate ignored mouse click after closing tour')
        click_button('Clear')
        wait_for(lambda: population() == 0, 'Clear ignored mouse click after Generate')
        # The fixed 1400x900 test window places this point inside the board.
        win = subprocess.check_output(['xdotool', 'search', '--onlyvisible', '--name', '^Conway.*Game of Life Lab$'], text=True).splitlines()[-1]
        geometry = subprocess.check_output(['xdotool', 'getwindowgeometry', '--shell', win], text=True)
        origin = dict(line.split('=', 1) for line in geometry.splitlines() if '=' in line)
        click_at(int(origin['X']) + 800, int(origin['Y']) + 450)
        wait_for(lambda: population() == 1, 'Canvas ignored mouse click after closing tour')
        click_button('Help')
        click_button('Next')
        click_button('Skip')
        wait_for(lambda: 'Skip' not in buttons(), 'Reopened tour did not close')
        click_button('Clear')
        wait_for(lambda: population() == 0, 'Clear ignored mouse click after reopening tour')
        click_button('Edit Rules')
        click_button('Cancel')
        wait_for(lambda: 'Cancel' not in buttons(), 'Rules dialog ignored Cancel click')
        print('Mouse input passed: tour Skip/Next, Clear, Generate, canvas painting, Help and rules dialog.', flush=True)
    finally:
        subprocess.run(['scrot', str(qa / 'pointer-final.png')], check=False)
        app.terminate()
        try:
            app.wait(timeout=5)
        except subprocess.TimeoutExpired:
            app.kill()
