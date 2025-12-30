import os
import sys
import requests
import getpass

ZBX_URL = "https://zabbix.forus.ee/api_jsonrpc.php"


def get_token():
    """
    Return the Zabbix API token.
    If the ZABBIX_TOKEN environment variable is missing, prompt the user and save it to os.environ.
    """
    token = os.environ.get("ZABBIX_TOKEN")
    if not token:
        token = getpass.getpass("Enter the Zabbix token: ").strip()
        if not token:
            print("❌ No token provided.")
            sys.exit(1)
        os.environ["ZABBIX_TOKEN"] = token
        print("✅ Token set.")
    else:
        print("ℹ️ Token already set.")
    return token


def make_headers(token: str):
    """Construct headers for Zabbix API."""
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }


def zbx_request(url, headers, payload, timeout=15):
    """
    Perform a safe request to the Zabbix API with error handling.
    Returns the 'result' field or exits on failure.
    """
    try:
        resp = requests.post(url, headers=headers, json=payload, timeout=timeout)
    except requests.exceptions.RequestException as e:
        print(f"❌ Network error: {e}")
        sys.exit(1)

    if resp.status_code != 200:
        preview = resp.text[:200].replace("\n", " ")
        print(f"❌ HTTP {resp.status_code}: {preview}")
        sys.exit(1)

    try:
        data = resp.json()
    except ValueError:
        print("❌ Invalid JSON in response")
        sys.exit(1)

    if "error" in data:
        err = data["error"]
        print(f"❌ Zabbix API error {err.get('code')}: {err.get('message')} — {err.get('data')}")
        sys.exit(1)

    if "result" not in data:
        print(f"❌ Unexpected JSON: {data}")
        sys.exit(1)

    return data["result"]


def get_hosts(headers: dict):
    """Return a list of active hosts (including IPs and parent templates)."""
    payload = {
        "jsonrpc": "2.0",
        "method": "host.get",
        "params": {
            "output": ["hostid", "host","name"],
            # "output": "extend",
            "selectInterfaces": ["ip"],
            "selectParentTemplates": ["name"],
            # "filter": {"status": "0"}
        },
        "id": 1
    }
    return zbx_request(ZBX_URL, headers, payload)


def get_items_for_host(headers: dict, hostid: str, keys: list):
    """Return metric values for the specified keys on a host."""
    payload = {
        "jsonrpc": "2.0",
        "method": "item.get",
        "params": {
            "output": ["key_", "lastvalue"],
            "hostids": hostid,
            "filter": {"key_": keys}
        },
        "id": 2
    }
    return zbx_request(ZBX_URL, headers, payload)


def get_cpu_item(headers, hostid):
    """Return the 'system.cpu.util' item for the host or None."""
    payload = {
        "jsonrpc": "2.0",
        "method": "item.get",
        "params": {
            "hostids": hostid,
            "filter": {"key_": "system.cpu.util"},
            "output": ["itemid", "name", "key_"]
        },
        "id": 2
    }
    items = zbx_request(ZBX_URL, headers, payload)
    return items[0] if items else None


# ============================================================
# 🔁 Additional helper functions for bulk operations
# ============================================================


def get_itemids_for_keys(headers: dict, hostids, keys):
    """
    Returns a dictionary of the form:
    {
        "10105": {
            "system.cpu.util": "25001",
            "vm.memory.size[total]": "25002",
            ...
        },
        ...
    }

    :param headers: headers containing the token
    :param hostids: list of hostids (or single hostid)
    :param keys: iterable with the item.key_ values to look up
    """
    if not keys:
        return {}

    payload = {
        "jsonrpc": "2.0",
        "method": "item.get",
        "params": {
            "output": ["itemid", "hostid", "key_"],
            "hostids": hostids,
            "filter": {"key_": list(keys)},
            "sortfield": "itemid"
        },
        "id": 2
    }

    items = zbx_request(ZBX_URL, headers, payload)
    result = {}

    for it in items:
        hid = it.get("hostid")
        key_ = it.get("key_")
        itemid = it.get("itemid")
        if not (hid and key_ and itemid):
            continue
        if hid not in result:
            result[hid] = {}
        # if the same key_ is duplicated, take the first one
        if key_ not in result[hid]:
            result[hid][key_] = itemid

    return result


def get_trends_bulk(headers: dict, itemids, time_from: int, time_till: int):
    """
    Return trends for a list of itemids over a period.
    Lightweight wrapper around trend.get.

    Result is a list of dicts:
    [
        {"itemid": "...", "value_avg": "...", "value_max": "...", "clock": "..."},
        ...
    ]
    """
    if not itemids:
        return []

    payload = {
        "jsonrpc": "2.0",
        "method": "trend.get",
        "params": {
            "output": ["itemid", "value_avg", "value_max"],
            "itemids": list(itemids),
            "time_from": time_from,
            "time_till": time_till,
            "sortfield": "itemid"
        },
        "id": 3
    }
    return zbx_request(ZBX_URL, headers, payload)
