#!/bin/bash

# Password
PASSWORD=<your-sudo-password>
read -sp 'Enter sudo password: ' PASSWORD

# Wait 30 seconds to ensure all nodes are working
echo "Waiting 30 seconds..."
sleep 30

# Launch Kubernetes cluster
cd cluster
./reset-ssh.sh --password "$PASSWORD" pc01 pc02 pc03 pc04 pc05 pc06 pc07 pc08 pc09 pc10 pc11 pc12 pc13 pc14 pc15 pc16
./create-ssh.sh --password "$PASSWORD" pc01 pc02 pc03 pc04 pc05 pc06 pc07 pc08 pc09 pc10 pc11 pc12 pc13 pc14 pc15 pc16

# Launch JupyterHub
cd ../jupyterhub
./create.sh
