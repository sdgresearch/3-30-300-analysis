"""
Module: src/utils/constants.py
Description: Constants for the project.
Author: Andrés C. Zúñiga-González
Date: 2025-07-16
"""

import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()  # take environment variables from .env

if os.getenv("DATA_DIR") is None:
    raise EnvironmentError(
        "DATA_DIR is not set. Copy .env.example to .env and fill in the values."
    )

DATA_DIR = Path(os.getenv("DATA_DIR"))
INPUT_DIR = DATA_DIR / "input"
OUTPUT_DIR = DATA_DIR / "output"
_jdk_home = os.getenv("JDK_HOME")
JAVA_HOME = _jdk_home if os.path.isabs(_jdk_home) else str(DATA_DIR.parent / ".jdk" / _jdk_home)
GEE_PROJECT_NAME = os.getenv("GEE_PROJECT_NAME")
GEE_BOUNDARIES_ASSET = os.getenv("GEE_BOUNDARIES_ASSET")

PROJECT_CRS = "EPSG:27700"  # OSGB 1936 / British National Grid
