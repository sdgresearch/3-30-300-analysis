
def translate_tile_name(tile_name: str) -> str:
    
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