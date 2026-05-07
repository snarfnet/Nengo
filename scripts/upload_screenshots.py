import hashlib
from pathlib import Path

import requests

from asc_api import api, find_app_id, get_localization_id, get_or_create_version
import os

APP_VERSION = os.environ.get("APP_VERSION", "1.1")


def get_or_create_screenshot_set(localization_id, display_type):
    payload = api("GET", f"/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")
    for item in payload.get("data", []):
        if item["attributes"].get("screenshotDisplayType") == display_type:
            return item["id"]

    payload = api("POST", "/appScreenshotSets", json={
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display_type},
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": localization_id}
                }
            },
        }
    })
    return payload["data"]["id"]


def delete_existing(set_id):
    payload = api("GET", f"/appScreenshotSets/{set_id}/appScreenshots")
    for item in payload.get("data", []):
        api("DELETE", f"/appScreenshots/{item['id']}")


def upload_file(set_id, path):
    data = path.read_bytes()
    checksum = hashlib.md5(data).hexdigest()
    payload = api("POST", "/appScreenshots", json={
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": len(data), "fileName": path.name},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
        }
    })
    screenshot = payload["data"]
    for op in screenshot["attributes"]["uploadOperations"]:
        headers = {item["name"]: item["value"] for item in op.get("requestHeaders", [])}
        offset = op.get("offset", 0)
        length = op.get("length", len(data))
        response = requests.request(op["method"], op["url"], headers=headers, data=data[offset:offset + length])
        response.raise_for_status()

    api("PATCH", f"/appScreenshots/{screenshot['id']}", json={
        "data": {
            "type": "appScreenshots",
            "id": screenshot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
        }
    })


def main():
    app_id = find_app_id()
    version_id = get_or_create_version(app_id, APP_VERSION)
    localization_id = get_localization_id(version_id)

    screenshot_root = Path("AppStoreAssets") / "Screenshots"
    groups = {
        "APP_IPHONE_67": screenshot_root / "iphone-6.9-1290x2796",
        "APP_IPHONE_65": screenshot_root / "iphone-6.5-1242x2688",
        "APP_IPHONE_55": screenshot_root / "iphone-5.5-1242x2208",
        "APP_IPHONE_47": screenshot_root / "iphone-4.7-750x1334",
    }

    for display_type, folder in groups.items():
        files = sorted(folder.glob("*.png"))
        if not files:
            print(f"{display_type}: no screenshots")
            continue
        print(f"{display_type}: uploading {len(files)} screenshots")
        try:
            set_id = get_or_create_screenshot_set(localization_id, display_type)
            delete_existing(set_id)
            for file in files:
                upload_file(set_id, file)
                print(f"  uploaded {file.name}")
        except Exception as exc:
            print(f"{display_type}: skipped ({exc})")


if __name__ == "__main__":
    main()
