#!/bin/bash

RED_COLOR="\033[1;31m"
RESET_COLOR="\033[0m"
GREEN_COLOR="\033[1;32m"
BLUE_COLOR="\033[1;34m"
YELLOW_COLOR="\033[1;33m"
MAGENTA_COLOR="\033[1;35m"

USB_MNT=$1
NUM_ARG=$#

# Function Usage
usage()
{
    if [ "${NUM_ARG}" -ne 1 ];then
        echo -e "${RED_COLOR}$: Usage: $(basename $0) <patition> ${RESET_COLOR}"
        exit 1
    fi
}
# Function require sudo
require_sudo_privilege() 
{
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED_COLOR}$: This script requires sudo privileges.${RESET_COLOR}"
        exit 1
    fi
}
# Function to read password securely
require_password() {
  echo -e "${YELLOW_COLOR}$: Please enter a secure password:${RESET_COLOR}"
  PASSWORD=$(systemd-ask-password "") 

  if [ -z "${PASSWORD}" ]; then
    echo -e "${RED_COLOR}$: Error Password is empty${RESET_COLOR}"
    exit 1
  fi
}

# Function to generate SHA256 challenge
generate_challenge() {
  CHALLENGE=$(printf "%s" "${PASSWORD}" | sha256sum | awk '{print $1}')

  if [ -z "$CHALLENGE" ]; then
    echo -e "${RED_COLOR}$: Error Failed to generate the challenge${RESET_COLOR}"
    exit 1
  fi
}

# Function to get response from YubiKey
get_yubikey_response() {
  echo -e "${YELLOW_COLOR}$: Please touch the YubiKey when it flashes...${RESET_COLOR}"
  RESPONSE=$(ykchalresp -2 "${CHALLENGE}")

  if [ -z "${RESPONSE}" ]; then
    echo -e "${RED_COLOR}$: Error Failed to get a response from the YubiKey${RESET_COLOR}"
    exit 1
  fi
}

# Function to decrypt the Streamcaster partition
decrypt_partition() {
    local KEY=$1
    # Check if the key is provided
    if [ -z "$KEY" ]; then
        echo -e "${RED_COLOR}$: Error: No decryption key provided${RESET_COLOR}"
        return 1
    fi
    echo -e "${YELLOW_COLOR}$: Start decrypting ...${RESET_COLOR}"
    # Open the LUKS partition
    if ! echo "${KEY}" | cryptsetup open /dev/${USB_MNT}1 streamcaster; then
        echo -e "${RED_COLOR}$: Error: Failed to open the LUKS partition${RESET_COLOR}"
        return 1
    fi
    # Mount the decrypted partition
    if ! mount /dev/mapper/streamcaster /mnt/; then
        echo -e "${RED_COLOR}$: Error: Failed to mount the decrypted partition${RESET_COLOR}"
        return 1
    fi
    echo -e "${GREEN_COLOR}$: Decryption and mounting successful!${RESET_COLOR}"
    return 0
}

usage
require_sudo_privilege
require_password
generate_challenge
get_yubikey_response
decrypt_partition ${CHALLENGE}${RESPONSE}


