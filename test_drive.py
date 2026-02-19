"""Quick test to verify Google Drive API connectivity and find the rweb folder."""

from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from pathlib import Path
import json

SCOPES = ['https://www.googleapis.com/auth/drive']
CREDS_FILE = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io/client_secret_699840800313-3bouvfpnsumgr369se929ohgr244fatv.apps.googleusercontent.com.json")
TOKEN_FILE = Path("/Users/lleisman/Luke/github/ALFALFAsurvey.github.io/token.json")

def get_service():
    creds = None
    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
    if not creds or not creds.valid:
        flow = InstalledAppFlow.from_client_secrets_file(str(CREDS_FILE), SCOPES)
        creds = flow.run_local_server(port=0)
        TOKEN_FILE.write_text(creds.to_json())
    return build('drive', 'v3', credentials=creds)

service = get_service()
print("✅ Connected to Google Drive API successfully!")

# Find the ALFALFAweb folder
results = service.files().list(
    q="name='ALFALFAweb' and mimeType='application/vnd.google-apps.folder' and trashed=false",
    fields="files(id, name, parents)"
).execute()

folders = results.get('files', [])
if folders:
    for f in folders:
        print(f"✅ Found folder: {f['name']} (id: {f['id']})")
else:
    print("❌ ALFALFAweb folder not found on Drive — check the folder name")

# Find the rweb subfolder
if folders:
    parent_id = folders[0]['id']
    results2 = service.files().list(
        q=f"name='rweb' and mimeType='application/vnd.google-apps.folder' and '{parent_id}' in parents and trashed=false",
        fields="files(id, name)"
    ).execute()
    rweb_folders = results2.get('files', [])
    if rweb_folders:
        print(f"✅ Found rweb subfolder (id: {rweb_folders[0]['id']})")
        # Count files in rweb
        results3 = service.files().list(
            q=f"'{rweb_folders[0]['id']}' in parents and trashed=false",
            fields="files(id, name)",
            pageSize=10
        ).execute()
        items = results3.get('files', [])
        print(f"✅ Sample files in rweb: {[f['name'] for f in items]}")
    else:
        print("❌ rweb subfolder not found inside ALFALFAweb")
