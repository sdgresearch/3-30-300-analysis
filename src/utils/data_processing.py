
"""
Module: file_operations.py
Description: Utility functions for file handling in My Project.
Author: Your Name
Date: YYYY-MM-DD
"""

import re

def extract_grid_reference(filename: str) -> str|None:
    """
    Extracts a grid reference from a given filename.
    The function searches for a pattern in the filename that matches 'VOM' or 'VOM_HS'
    followed by an underscore, a two-letter code, a four-digit number, and another underscore.
    If such a pattern is found, it returns the grid reference (the two-letter code and the four-digit number).
    If no match is found, it returns None.
    Parameters:
        filename (str | Path): The name of the file from which to extract the grid reference.
    Returns:
        str | None: The extracted grid reference if a match is found, otherwise None.
    """

    match = re.search(r'VOM_([A-Z]{2}\d{4})_', filename)
    if match:
        return match.group(1)
    return None

def translate_tile_name(tile_name: str) -> str:
    """
    Translates a tile name between two formats:
    - Format 1: TL0045 (where '0045' represents coordinates)
    - Format 2: TL04NW (where 'NW' represents directions)
    The function converts:
    - From Format 1 to Format 2 by interpreting the numeric coordinates and converting them to directional codes.
    - From Format 2 to Format 1 by interpreting the directional codes and converting them to numeric coordinates.
    Parameters:
        tile_name (str): The tile name to be translated. It should be a string of length 6.
    Returns:
        str: The translated tile name in the opposite format.
    Raises:
        AssertionError: If the input tile_name is not of length 6.
        ValueError: If the numeric part of the tile name cannot be converted to an integer when expected.
    """
    
    NS_dict = {'S': '0', 'N': '5'}
    EW_dict = {'W': '0', 'E': '5'} 

    assert len(tile_name) == 6
    
    code = tile_name[2:6].upper()
    try: # If input is like TL0045
        int(code)
        NS_dict = {v: k for k, v in NS_dict.items()}
        EW_dict = {v: k for k, v in EW_dict.items()}
        ns_id = code[3]
        ew_id = code[1]
        direction_code = code[0] + code[2] + NS_dict[ns_id] + EW_dict[ew_id]
        trans_tile_name = tile_name[:2].upper() + direction_code
    except ValueError: # If input is like TL04NW
        ns_id = code[2]
        ew_id = code[3]
        number_code = code[0] + EW_dict[ew_id] + code[1] + NS_dict[ns_id]
        trans_tile_name = tile_name[:2].lower() + number_code

    return trans_tile_name
