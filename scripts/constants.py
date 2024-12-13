import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()  # take environment variables from .env.
DATA_DIR = Path(os.getenv("DATA_DIR")) 
INPUT_DIR = DATA_DIR / "input"
OUTPUT_DIR = DATA_DIR / "output"
RASTER_IN_DIR = INPUT_DIR / "raster"
RASTER_OUT_DIR = OUTPUT_DIR / "raster"
VECTOR_IN_DIR = INPUT_DIR / "vector"
VECTOR_OUT_DIR = OUTPUT_DIR / "vector"
TABULAR_IN_DIR = INPUT_DIR / "tabular"
TABULAR_OUT_DIR = OUTPUT_DIR / "tabular"
GBG_IN_DIR = VECTOR_IN_DIR / "gbg"
GBG_OUT_DIR = VECTOR_OUT_DIR / "gbg"
PCH_IN_DIR = RASTER_IN_DIR / "pch"
PCH_OUT_DIR = RASTER_OUT_DIR / "pch"
BHF_IN_DIR = VECTOR_IN_DIR / "bhf" / "gdb"
BHF_OUT_DIR = VECTOR_OUT_DIR / "bhf"
BUA_IN_DIR = VECTOR_IN_DIR / "bua"
BUA_OUT_DIR = VECTOR_OUT_DIR / "bua"
OGS_IN_DIR = VECTOR_IN_DIR / "ogs"
OGS_OUT_DIR = VECTOR_OUT_DIR / "ogs"
IMD_IN_DIR = VECTOR_IN_DIR / "imd"
IMD_OUT_DIR = VECTOR_OUT_DIR / "imd"
JAVA_HOME = str(DATA_DIR.parent / ".jdk" / os.getenv("JDK_HOME"))
GEE_PROJECT_NAME = os.getenv("GEE_PROJECT_NAME")