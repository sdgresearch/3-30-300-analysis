"""
Module: src/utils/logging_config.py
Description: Utility functions for logging configuration.
Author: Andrés C. Zúñiga-González
Date: 2025-07-16
"""

import logging
from pathlib import Path

def setup_logger(log_path: str|Path, log_level: str = logging.WARNING) -> None:
    """
    Sets up the logging configuration for the application.
    Args:
        log_path (str | Path): The file path where the log file will be saved.
        log_level (str): The logging level to be used. Default is logging.WARNING.
    Returns:
        None
    """
    
    logging.basicConfig(filename=log_path,
                        encoding="utf-8",
                        filemode="a",
                        format="%(asctime)s - %(levelname)s - %(message)s",
                        style="%",
                        datefmt="%Y-%m-%d %H:%M",
                        level=log_level)
    
    