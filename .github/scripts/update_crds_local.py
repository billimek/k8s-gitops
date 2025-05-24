import os
import re
import subprocess
import tempfile
# Get the GitHub workspace path, defaulting to current dir if not set (for local runs)
workspace_path = os.environ.get("GITHUB_WORKSPACE", os.getcwd())

kustomization_file_rel = "setup/crds/kustomization.yaml"
vendor_dir_rel = "setup/crds/vendor"

kustomization_file_abs = os.path.join(workspace_path, kustomization_file_rel)
vendor_dir_abs = os.path.join(workspace_path, vendor_dir_rel)

if not os.path.exists(vendor_dir_abs):
    os.makedirs(vendor_dir_abs)
    print(f"Created directory: {vendor_dir_abs}")

if not os.path.exists(kustomization_file_abs):
    print(f"Error: Kustomization file not found at {kustomization_file_abs}")
    exit(1)

with open(kustomization_file_abs, 'r') as f:
    content = f.read()

# Find all crd-url comments and their corresponding local paths
# The local path in kustomization.yaml is relative to kustomization.yaml itself (e.g., ./vendor/...)
crd_urls = re.findall(r"# (https?://[^\s]+)\n\s*- (./vendor/[^\s]+)", content)

if not crd_urls:
    print(f"No CRD URLs found in {kustomization_file_abs}. Check the file and regex pattern.")

def download_file_safely(url, destination_path):
    """Download a file using a temporary file first, then move to destination."""
    try:
        # Create destination directory if it doesn't exist
        dest_dir = os.path.dirname(destination_path)
        if not os.path.exists(dest_dir):
            os.makedirs(dest_dir)
            print(f"Created directory: {dest_dir}")
        
        # Use a temporary file in the same directory to avoid cross-device issues
        with tempfile.NamedTemporaryFile(dir=dest_dir, delete=False, suffix='.tmp') as tmp_file:
            temp_path = tmp_file.name
        
        print(f"Downloading from {url} to temporary file...")
        subprocess.run(["curl", "-sSL", "-o", temp_path, url], check=True)
        
        # Move the temporary file to the final destination
        os.rename(temp_path, destination_path)
        print(f"Successfully downloaded {url} to {destination_path}")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"Error downloading {url}: {e}")
        # Clean up temp file if it exists
        if 'temp_path' in locals() and os.path.exists(temp_path):
            os.remove(temp_path)
        return False
    except Exception as e:
        print(f"An unexpected error occurred with {url}: {e}")
        # Clean up temp file if it exists
        if 'temp_path' in locals() and os.path.exists(temp_path):
            os.remove(temp_path)
        return False

for url, local_path_rel_to_kustomization in crd_urls:
    print(f"Processing {url} -> {local_path_rel_to_kustomization}")
    
    # Skip GitHub tree URLs (not direct downloads)
    if "/tree/" in url:
        print(f"Skipping tree URL (not a direct download): {url}")
        continue
    
    # Construct the full local path for the CRD file
    # It's relative to the directory of kustomization_file_abs
    kustomization_dir = os.path.dirname(kustomization_file_abs)
    full_local_path = os.path.abspath(os.path.join(kustomization_dir, local_path_rel_to_kustomization.strip()))
    
    # Check if the local path is a directory (ends with /)
    if local_path_rel_to_kustomization.strip().endswith('/'):
        print(f"Skipping directory reference: {local_path_rel_to_kustomization}")
        continue
    
    download_file_safely(url, full_local_path)

print("CRD update process finished.")