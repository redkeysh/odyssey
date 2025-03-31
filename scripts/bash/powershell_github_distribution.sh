#!/bin/bash
# Install the latest stable PowerShell RPM on the RH-based system

# Enable strict mode (exit on errors, unset variables, etc.)
set -euo pipefail
IFS=$'\n\t'

#########################
# Configuration Section
#########################
GITHUB_API_URL="https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
DOWNLOAD_DIR="/var/www/unix/stig/zip"
LOCAL_DIR="/tmp"
LOCAL_SERVER_URL="http://webserver.com/stig/zip"
RPM_PERMISSIONS=755

# Define the specific IP on which the script will only download from GitHub
TARGET_IP="<REPO_SERVER_IP>"

#########################
# Logging Function (logs to stderr)
#########################
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $*" >&2
}

#########################
# Fetch the latest stable PowerShell release JSON data
#########################
fetch_latest_release_json() {
    log "Fetching latest PowerShell release information from GitHub API..."
    json=$(curl --silent "$GITHUB_API_URL")
    if [[ -z "$json" ]]; then
        log "ERROR: Failed to fetch release information from GitHub."
        exit 1
    fi
    echo "$json"
}

#########################
# Extract the latest stable release (Ignores pre-release and preview builds)
#########################
extract_version() {
    local json="$1"
    tag=$(echo "$json" | jq -r '.tag_name')
    version=${tag#v}  # Remove a leading "v", if present
    if [[ -z "$version" ]]; then
        log "ERROR: Unable to extract the version from the release data."
        exit 1
    fi
    echo "$version"
}

#########################
# Download via GitHub RPM asset
#########################
download_rpm_from_github() {
    local json="$1"
    local version
    version=$(extract_version "$json")
    log "Determined latest version as: ${version}"

    asset_match="powershell-${version}-1.rh.x86_64.rpm"
    log "Looking for asset: ${asset_match}"

    download_url=$(echo "$json" | jq -r --arg NAME "$asset_match" '.assets[] | select(.name == $NAME) | .browser_download_url')
    if [[ -z "$download_url" ]]; then
        log "ERROR: Asset for ${asset_match} not found in the release data."
        exit 1
    fi
    log "Found download URL: ${download_url}"

    log "Downloading PowerShell RPM version ${version} from GitHub..."
    wget --quiet --no-check-certificate "$download_url"

    if [[ ! -f "$asset_match" ]]; then
        log "ERROR: Failed to download ${asset_match}"
        exit 1
    fi

    log "Moving ${asset_match} to ${DOWNLOAD_DIR}..."
    mv "$asset_match" "$DOWNLOAD_DIR/"
    local destination="${DOWNLOAD_DIR}/${asset_match}"

    log "Restoring SELinux context on ${destination}..."
    restorecon -v "$destination"

    log "Setting file permissions (${RPM_PERMISSIONS}) on ${destination}..."
    chmod "$RPM_PERMISSIONS" "$destination"

    echo "$destination"
}

#########################
# Download via local repository rpm
#########################
download_rpm_from_local() {
    # For this function, we are not calling GitHub so we need to get version via external method.
    # One approach is to get the version from the file name on the local server.
    # Here, we call the GitHub API to get the version info, then retrieve RPM from local server.
    json=$(fetch_latest_release_json)
    local version
    version=$(extract_version "$json")
    asset_name="powershell-${version}-1.rh.x86_64.rpm"
    local file_url="${LOCAL_SERVER_URL}/${asset_name}"

    log "Detected non-TARGET_IP machine. Downloading ${asset_name} from local repository (${file_url})..."
    wget --quiet --no-check-certificate "$file_url" -O "$asset_name"

    if [[ ! -f "$asset_name" ]]; then
        log "ERROR: Failed to download ${asset_name} from local repository"
        exit 1
    fi

    log "Moving ${asset_name} to ${LOCAL_DIR}..."
    mv "$asset_name" "$LOCAL_DIR/"
    local destination="${LOCAL_DIR}/${asset_name}"

    log "Restoring SELinux context on ${destination}..."
    restorecon -v "$destination"

    log "Setting file permissions (${RPM_PERMISSIONS}) on ${destination}..."
    chmod "$RPM_PERMISSIONS" "$destination"

    echo "$destination"
}

#########################
# Install the downloaded RPM locally
#########################
install_rpm() {
    local rpm_path="$1"
    local rpm_filename
    rpm_filename=$(basename "$rpm_path")
    local rpm_url="${LOCAL_SERVER_URL}/${rpm_filename}"
    
    log "Installing PowerShell via localinstall from ${rpm_url}..."
    dnf localinstall "$rpm_url" -y --nogpgcheck
}

#########################
# Determine if the current IP matches TARGET_IP 
#########################
is_target_ip() {
    # Get the list of IP addresses on this machine. Adjust this logic as needed.
    # This example uses hostname -I and checks if TARGET_IP is part of the returned string.
    local ips
    ips=$(hostname -I 2>/dev/null || echo "")
    if [[ "$ips" == *"$TARGET_IP"* ]]; then
        return 0
    else
        return 1
    fi
}

#########################
# Main execution flow
#########################
main() {
    if is_target_ip; then
        log "Current machine IP matches TARGET_IP (${TARGET_IP}). Using GitHub for download."
	# Ensure target directory exists for file/repository server.
        if [[ ! -d "$DOWNLOAD_DIR" ]]; then
            log "Creating download directory at ${DOWNLOAD_DIR}..."
            mkdir -p "$DOWNLOAD_DIR"
        fi

        release_json=$(fetch_latest_release_json)
        rpm_file_path=$(download_rpm_from_github "$release_json")
    else
	log "Current machine IP does not match TARGET_IP. Using local repository for download."
	# Ensure target directory exists for non-file/repository server.
        if [[ ! -d "$LOCAL_DIR" ]]; then
            log "Creating download directory at ${LOCAL_DIR}..."
            mkdir -p "$LOCAL_DIR"
        fi
        rpm_file_path=$(download_rpm_from_local)
    fi

    # Install the RPM file using dnf localinstall
    install_rpm "$rpm_file_path"

    log "PowerShell installation complete."
}

main