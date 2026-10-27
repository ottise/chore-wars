import sys
import time
from urllib.request import urlopen

for attempt in range(60):
    try:
        with urlopen(sys.argv[1], timeout=2) as response:
            if response.status == 200:
                raise SystemExit(0)
    except OSError:
        pass
    time.sleep(1)
raise SystemExit("Local test fixture did not start")
