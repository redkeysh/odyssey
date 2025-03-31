#!/bin/bash
# Evaluate STIG Automation Script

# IMPORTANT: This script must be run as the ROOT user.
if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: STIG Automation Script must be run as the ROOT user to execute properly."
    exit 1
fi

# Clear the terminal screen
clear

# Enable strict mode (Exit on any error, treat unset variables as errors, etc.)
set -euo pipefail
IFS=$'\n\t'

#####################
# Configuration
#####################
USERNAME="<CHANGEME>"
REMOTE_HOST="<CHANGEME>"
REMOTE_PATH="/path/to/remote/output"
ROOT_STIG="/path/to/stig/dir"
REMOTE_SCRIPT_BASE="https://webserver.com/stig"
SSH_KEY_PATH="$HOME/.ssh/ssh"
PASSPHRASE_FILE="$HOME/.ssh_ph"

LOCAL_HOSTNAME=$(hostname -f)
DATESTAMP=$(date +"%d-%m-%Y-%H_%M")

#####################
# Logging Function
#####################
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $*"
}

#####################
# Install a package if it is not already installed
#####################
install_pkg() {
    local pkg="$1"
    if ! rpm -q --quiet "$pkg"; then
        log "Installing package: $pkg"
        dnf install "$pkg" -y -q
    else
        log "Package $pkg is already installed."
    fi
}

#####################
# Setup remote resources for Evaluate-STIG
#####################
setup_eval_stig() {
    mkdir -p "$ROOT_STIG"
    cd "$ROOT_STIG" || { log "ERROR: Failed to change directory to $ROOT_STIG"; exit 1; }

    if [[ ! -d "$ROOT_STIG/Evaluate-STIG" ]]; then
        log "Downloading Evaluate-STIG archive..."
        curl -s -O "$REMOTE_SCRIPT_BASE/zip/Evaluate-STIG.zip"
        log "Extracting Evaluate-STIG.zip..."
        unzip -q "Evaluate-STIG.zip"
        rm -f "Evaluate-STIG.zip"
    fi
}

#####################
# Decrypt and prepare SSH key for SCP/SSH operations.
#####################
setup_ssh_key() {
    # Ensure the .ssh directory exists
    mkdir -p "$(dirname "$SSH_KEY_PATH")"

    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        log "Downloading encrypted SSH key..."
        local key_gpg="$HOME/.ssh/key.gpg"
        curl -s "$REMOTE_SCRIPT_BASE/conf/key.gpg" --output "$key_gpg"
        log "Decrypting SSH key..."
        gpg --decrypt --batch --no-tty --passphrase-file "$PASSPHRASE_FILE" -o "$SSH_KEY_PATH" "$key_gpg"
        chmod 600 "$SSH_KEY_PATH"
        rm -f "$key_gpg"
    else
        log "SSH key already exists at $SSH_KEY_PATH."
    fi
}

#####################
# Run Evaluate STIG and capture output in combined formats.
#####################
run_eval_stig() {
    cd "$ROOT_STIG/Evaluate-STIG" || { log "ERROR: Failed to change directory to $ROOT_STIG/Evaluate-STIG"; exit 1; }

    # Create output directory if missing
    local output_dir="$ROOT_STIG/$LOCAL_HOSTNAME"
    mkdir -p "$output_dir"

    # Optionally, if you want to update before output, uncomment the following lines:
    # log "Updating Evaluate-STIG repository..."
    # sh Evaluate-STIG_Bash.sh --Update

    # Clear screen before running the output command (if desired)
    clear
    log "Generating combined outputs [CKL, CombinedCKLB, CKLB]..."
    sh Evaluate-STIG_Bash.sh --Output CKL,CombinedCKLB,CKLB --OutputPath "$output_dir"
    clear
}

#####################
# Archive results and send them to the remote server.
#####################
archive_and_send() {
    local output_dir="$ROOT_STIG/$LOCAL_HOSTNAME"
    local zip_file="$ROOT_STIG/${LOCAL_HOSTNAME}.zip"
    local archive_dir="$ROOT_STIG/archive"
    local dated_zip="$archive_dir/${LOCAL_HOSTNAME}-${DATESTAMP}.zip"

    log "Zipping results from ${output_dir} into ${zip_file}..."
    zip -r -q "$zip_file" "$output_dir"

    log "Sending zip file to remote server..."
    scp -i "$SSH_KEY_PATH" "$zip_file" "${USERNAME}@${REMOTE_HOST}:${REMOTE_PATH}/stig/ckl-output"

    # Print download location for the user
    echo "Done. The zip file can be downloaded at:"
    echo "http://${REMOTE_HOST}/stig/ckl-output/${LOCAL_HOSTNAME}.zip"

    log "Setting remote permissions..."
    ssh -i "$SSH_KEY_PATH" "${USERNAME}@${REMOTE_HOST}" "chmod -R 755 ${REMOTE_PATH}/stig/ckl-output"

    mkdir -p "$archive_dir"
    mv "$zip_file" "$dated_zip"
    log "Archived results: $dated_zip"
}

#####################
# Main Execution Flow
#####################
main() {
    # Install required packages
    install_pkg "pinentry"
    install_pkg "sshpass"
    if ! rpm -q --quiet powershell ; then
        log "Installing powershell via remote script..."
        curl -s -L "$REMOTE_SCRIPT_BASE/scripts/ps.sh" | bash
    fi

    setup_eval_stig
    setup_ssh_key
    run_eval_stig
    archive_and_send

    log "STIG Evaluation and archive complete!"
}

main
