import io
import sys
from contextlib import redirect_stdout
from pathlib import Path

# Ensure local package is imported (not stdlib antigravity)
PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from antigravity.core.hello import Greeter


def test_greeter_outputs_name():
    buf = io.StringIO()
    greeter = Greeter("Tester")
    with redirect_stdout(buf):
        greeter.say_hello()
        greeter.say_goodbye()

    out = buf.getvalue()
    assert "Hello, Tester!" in out
    assert "Goodbye, Tester!" in out
