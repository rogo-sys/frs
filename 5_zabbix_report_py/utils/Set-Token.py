import os
import getpass

token = os.environ.get("ZABBIX_TOKEN")

if not token:
    token = getpass.getpass("Enter Zabbix token: ")
    os.environ["ZABBIX_TOKEN"] = token
    print("✅ Token set for this session")
else:
    print("ℹ️ Token already set")

# Example usage
print("Token:", os.environ.get("ZABBIX_TOKEN"))