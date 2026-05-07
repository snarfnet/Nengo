import os
import time

from asc_api import api, find_app_id, get_or_create_version, get_localization_id

APP_VERSION = os.environ.get("APP_VERSION", "1.1")
BUILD_NUMBER = os.environ.get("BUILD_NUMBER", "")
REVIEW_CONTACT = {
    "contactFirstName": "東京",
    "contactLastName": "なす",
    "contactEmail": "tokyonasu@yahoo.co.jp",
    "contactPhone": "+81 80-2368-9194",
}


def wait_for_build(app_id):
    print(f"Waiting for processed build (expecting build {BUILD_NUMBER or 'any'})...")
    for attempt in range(60):
        payload = api("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10")
        for item in payload.get("data", []):
            attrs = item["attributes"]
            version = attrs.get("version", "")
            state = attrs.get("processingState", "")
            print(f"  build {version}: {state}")
            if BUILD_NUMBER and version == BUILD_NUMBER and state == "VALID":
                return item["id"]
            elif not BUILD_NUMBER and version and state == "VALID":
                return item["id"]
        print(f"  attempt {attempt + 1}/60, waiting 30s")
        time.sleep(30)
    raise RuntimeError("No valid processed build found")


def main():
    app_id = find_app_id()
    version_id = get_or_create_version(app_id, APP_VERSION)
    build_id = wait_for_build(app_id)

    try:
        api("PATCH", f"/builds/{build_id}", json={
            "data": {"type": "builds", "id": build_id, "attributes": {"usesNonExemptEncryption": False}}
        })
    except RuntimeError as e:
        if "409" in str(e):
            print("usesNonExemptEncryption already set, skipping")
        else:
            raise
    try:
        api("PATCH", f"/apps/{app_id}", json={
            "data": {
                "type": "apps",
                "id": app_id,
                "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"},
            }
        })
    except RuntimeError as e:
        if "409" in str(e):
            print("contentRightsDeclaration already set, skipping")
        else:
            raise

    review_details = api("GET", f"/appStoreVersions/{version_id}/appStoreReviewDetail")
    attrs = {**REVIEW_CONTACT, "demoAccountRequired": False, "demoAccountName": "", "demoAccountPassword": ""}
    if review_details.get("data"):
        detail_id = review_details["data"]["id"]
        api("PATCH", f"/appStoreReviewDetails/{detail_id}", json={
            "data": {"type": "appStoreReviewDetails", "id": detail_id, "attributes": attrs}
        })
    else:
        api("POST", "/appStoreReviewDetails", json={
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": attrs,
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
            }
        })

    for attempt in range(5):
        try:
            api("PATCH", f"/appStoreVersions/{version_id}/relationships/build", json={
                "data": {"type": "builds", "id": build_id}
            })
            print("Build linked to version")
            break
        except RuntimeError as e:
            if "409" in str(e):
                print("Build already linked to version, skipping")
                break
            elif attempt < 4:
                print(f"Build link attempt {attempt + 1} failed, retrying in 30s...")
                time.sleep(30)
            else:
                raise

    # Set whatsNew on localization
    loc_id = get_localization_id(version_id)
    if loc_id:
        try:
            api("PATCH", f"/appStoreVersionLocalizations/{loc_id}", json={
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc_id,
                    "attributes": {
                        "whatsNew": "画面デザインを刷新し、履歴書向けの学歴テンプレート機能を追加しました。",
                    },
                }
            })
            print("whatsNew set")
        except RuntimeError as e:
            if "409" in str(e):
                print("whatsNew already set, skipping")
            else:
                raise

    # Strategy: find existing READY_FOR_REVIEW submission with items, or prepare one
    review_id = None
    payload = api("GET", f"/apps/{app_id}/reviewSubmissions?filter[state]=READY_FOR_REVIEW")
    for sub in payload.get("data", []):
        sid = sub["id"]
        # Check if this submission has items
        items = api("GET", f"/reviewSubmissions/{sid}/items")
        if items.get("data"):
            review_id = sid
            print(f"Found submission {sid} with items, using it")
            break

    if not review_id:
        # Try to add item to first available submission
        for sub in payload.get("data", []):
            sid = sub["id"]
            try:
                api("POST", "/reviewSubmissionItems", json={
                    "data": {
                        "type": "reviewSubmissionItems",
                        "relationships": {
                            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}},
                            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                        },
                    }
                })
                review_id = sid
                print(f"Added item to submission {sid}")
                break
            except RuntimeError as e:
                print(f"Could not add item to {sid}: {e}")

    if not review_id:
        # Last resort: create new
        try:
            review = api("POST", "/reviewSubmissions", json={
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": "IOS"},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            })
            review_id = review["data"]["id"]
            print(f"Created review submission {review_id}")
            api("POST", "/reviewSubmissionItems", json={
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": review_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                    },
                }
            })
        except RuntimeError as e:
            raise RuntimeError(f"Cannot create or find usable review submission: {e}")

    api("PATCH", f"/reviewSubmissions/{review_id}", json={
        "data": {"type": "reviewSubmissions", "id": review_id, "attributes": {"submitted": True}}
    })
    print("Submitted for review")


if __name__ == "__main__":
    main()
