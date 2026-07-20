import urllib.request
import json
import os

def upload_to_r2(file_path, worker_endpoint, auth_key):
    """
    Upload a file to Cloudflare R2 via a Worker

    Args:
        file_path: Path to the file to upload
        worker_endpoint: Your Worker's endpoint URL
        auth_key: Your authentication key
    """

    # Get the file name from the path
    file_name = os.path.basename(file_path)

    # Read the file in binary mode
    with open(file_path, 'rb') as f:
        file_data = f.read()

    # Create the request
    url = f"{worker_endpoint}/{file_name}"
    headers = {
        'X-Custom-Auth-Key': auth_key,
        'Content-Type': 'application/octet-stream'
    }

    # Create a PUT request
    request = urllib.request.Request(
        url,
        data=file_data,
        method='PUT',
        headers=headers
    )

    try:
        with urllib.request.urlopen(request) as response:
            if response.status == 200:
                print(f"Successfully uploaded {file_name}")
                return True
            else:
                print(f"Upload failed with status: {response.status}")
                return False
    except urllib.error.HTTPError as e:
        print(f"Upload failed: {e.reason} (Status code: {e.code})")
        return False
    except urllib.error.URLError as e:
        print(f"Connection failed: {e.reason}")
        return False

# Usage example
if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        print("Usage: python script.py <file_to_upload>")
        sys.exit(1)

    # Replace these with your actual values
    WORKER_ENDPOINT = "https://your-worker.your-zone.workers.dev"
    AUTH_KEY = "your-auth-key"

    file_path = sys.argv[1]
    upload_to_r2(file_path, WORKER_ENDPOINT, AUTH_KEY)





def upload_large_file(file_path, worker_endpoint, auth_key, chunk_size=8388608):  # 8MB chunks
    file_name = os.path.basename(file_path)
    url = f"{worker_endpoint}/{file_name}"

    with open(file_path, 'rb') as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break

            request = urllib.request.Request(
                url,
                data=chunk,
                method='PUT',
                headers={
                    'X-Custom-Auth-Key': auth_key,
                    'Content-Type': 'application/octet-stream'
                }
            )

            try:
                with urllib.request.urlopen(request) as response:
                    if response.status != 200:
                        print(f"Chunk upload failed with status: {response.status}")
                        return False
            except urllib.error.HTTPError as e:
                print(f"Chunk upload failed: {e.reason}")
                return False

    print(f"Successfully uploaded {file_name}")
    return True
