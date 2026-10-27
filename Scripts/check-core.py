#!/usr/bin/env python3
"""Run real Swift Testing tests; do not rewrite or weaken test assertions."""
from pathlib import Path
import subprocess
subprocess.run(['swift', 'test', '--filter', 'NestCoreTests'], cwd=Path(__file__).resolve().parents[1], check=True)
