import os
import re
import subprocess
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

for url, local_path_rel_to_kustomization in crd_urls:
    print(f"Processing {url} -> {local_path_rel_to_kustomization}")
    
    # Construct the full local path for the CRD file
    # It's relative to the directory of kustomization_file_abs
    kustomization_dir = os.path.dirname(kustomization_file_abs)
    full_local_path = os.path.abspath(os.path.join(kustomization_dir, local_path_rel_to_kustomization.strip()))
    
    # Ensure the directory for the local file exists
    local_file_dir = os.path.dirname(full_local_path)
    if not os.path.exists(local_file_dir):
        os.makedirs(local_file_dir)
        print(f"Created directory: {local_file_dir}")

    try:
        # Download the CRD
        print(f"Downloading from {url} to {full_local_path}...")
        subprocess.run(["curl", "-sSL", "-o", full_local_path, url], check=True)
        print(f"Successfully downloaded {url} to {full_local_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error downloading {url}: {e}")
    except Exception as e:
        print(f"An unexpected error occurred with {url}: {e}")

print("CRD update process finished.")