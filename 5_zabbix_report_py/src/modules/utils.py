# zbx/utils.py
# Helper functions for processing data from the Zabbix API
import os
import time

PERIOD_DAYS = 7

def safe_mb(val):
    """
    Convert bytes to megabytes, rounded to 2 decimals.
    Return None if the input is None or invalid.
    """
    try:
        return round(float(val) / (1024 * 1024), 2)
    except (TypeError, ValueError):
        return None


def safe_gb(val):
    """
    Convert bytes to gigabytes, rounded to 2 decimals.
    Return None if the input is None or invalid.
    """
    try:
        return round(float(val) / (1024 * 1024 * 1024), 2)
    except (TypeError, ValueError):
        return None


def get_val(items, key):
    """
    Return the item.lastvalue for a given Zabbix item.key_.
    If the key is not found or the value is empty, return None.
    """
    for i in items:
        if i.get("key_") == key and i.get("lastvalue") not in ("", None):
            return i["lastvalue"]
    return None

def is_file_locked(path: str) -> bool:
    """Check whether a file is open (for example, by Excel).
       Returns True if the file exists and is locked for writing."""
    if not os.path.exists(path):
        return False
    try:
        with open(path, "a"):
            return False
    except PermissionError:
        return True
    
def check_output_file(path: str, retries: int = 0, delay: int = 5) -> bool:
    """
    Check whether it is safe to write to a file.
    If the file is open, notify the user and optionally wait before retrying.

    :param path: path to the file
    :param retries: how many times to retry (0 = do not wait)
    :param delay: pause between retries in seconds
    :return: True if the file is writable, False if the file is locked
    """
    if not os.path.exists(path):
        # file doesn't exist — safe to create
        return True

    # if the file exists, check whether it's locked
    for i in range(retries + 1):
        if not is_file_locked(path):
            return True

        print(f"⚠️ File '{path}' is open in Excel. "
              f"Close it and retrying ({i+1}/{retries})..." if retries else
              f"❌ File '{path}' is open in Excel. Please close it.")
        if i < retries:
            time.sleep(delay)
    return False



def safe_comma(val):
    """
    Convert numeric values to strings with a comma as decimal separator (for Excel / RU locale).
    Leaves IP addresses and non-numeric strings unchanged.
    """
    if val is None:
        return None
        
    # Check if the value is an IP address (contains 3 dots and only digits)
    if isinstance(val, str) and val.count('.') == 3 and all(p.isdigit() for p in val.split('.')):
        return val  # Leave IP address as is

    # Try to convert to string and replace dot with comma
    try:
        # First, ensure it's a floating-point number
        float(val)
        # If successful, format as string and replace dot with comma
        return str(val).replace('.', ',')
    except (ValueError, TypeError):
        # If it's not a number or a string (e.g., '-' or 'no data'), return as is
        return val