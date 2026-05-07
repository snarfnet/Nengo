import os
import time

from asc_api import api, find_app_id, get_or_create_version

APP_VERSION = os.environ.get("APP_VERSION", "1.1")
REVIEW_CONTACT = {
    "contactFirstName": "東京",
    "contactLastName": "なす",
    "contactEmail": "tokyonasu@yahoo.co.jp",
    "contactPhone": "+81 80-2368-9194",
}


def wait_for_build(app_id):
    print("Waiting for processed build...")
    for attempt in range(50):
        payload = api("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=5")
        for item in payload.get("data", []):
            attrs = item["attributes"]
            version = attrs.get("version", "")
            state = attrs.get("processingState", "")
            print(f"  build {version}: {state}")
            if version and state == "VALID":
                return item["id"]
        print(f"  attempt {attempt + 1}/50, waiting 30s")
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

    try:
        api("PATCH", f"/appStoreVersions/{version_id}/relationships/build", json={
            "data": {"type": "builds", "id": build_id}
        })
    except RuntimeError as e:
        if "409" in str(e):
            print("Build already linked to version, skipping")
        else:
            raise

    review = api("POST", "/reviewSubmissions", json={
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    })
    review_id = review["data"]["id"]
    api("POST", "/reviewSubmissionItems", json={
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": review_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
            },
        }
    })
    api("PATCH", f"/reviewSubmissions/{review_id}", json={
        "data": {"type": "reviewSubmissions", "id": review_id, "attributes": {"submitted": True}}
    })
    print("Submitted for review")


if __name__ == "__main__":
    main()
