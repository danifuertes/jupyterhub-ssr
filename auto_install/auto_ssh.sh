#!/bin/bash
set -e  # Stop execution if any command fails

# Prompt for the sudo password
read -sp 'Enter your sudo password: ' PASSWORD
echo

# Variables
USERNAME="administrator"  # Change this to the user you are using on the target machines
MACHINES=(pc{01..17})

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/id_rsa ]; then
    echo
    echo "Generating SSH key..."
    echo
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    if [ $? -ne 0 ]; then
        echo
        echo "Failed to generate SSH key."
        echo
        exit 1
    fi
else
    echo
    echo "SSH key already exists."
    echo
fi

# Install sshpass if not already installed (optional)
if ! command -v sshpass &> /dev/null; then
    echo
    echo "Installing sshpass..."
    echo
    sudo apt-get install -y sshpass
    if [ $? -ne 0 ]; then
        echo
        echo "Failed to install sshpass."
        echo
        exit 1
    fi
fi

# Copy SSH key to all target machines
for machine in "${MACHINES[@]}"; do
    echo
    echo "Copying SSH key to $machine..."
    echo
    sshpass -p "$PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no "$USERNAME@$machine"
    if [ $? -ne 0 ]; then
        echo
        echo "Failed to copy SSH key to $machine."
        echo
        exit 1
    fi
done

echo
echo "################################################"
echo "# SSH key successfully copied to all machines! #"
echo "################################################"
echo
