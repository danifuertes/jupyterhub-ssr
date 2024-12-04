#!/bin/bash
set -e  # Exit on any error

# Worker nodes
NODES=(pc{01..17})

# Function to run on failure
handle_failure() {

    # Capture the exit code
    local exit_code=$?

    # Define color codes
    local red="\033[0;31m"
    local reset="\033[0m"

    # Print the error
    echo
    echo -e "${red}Error:${reset} Command failed on line ${red}$1${reset} with exit code ${red}$exit_code${reset}."
    echo
    exit $exit_code  # Exit with the same error code
}


# Trap any script error and call the function
trap 'handle_failure $LINENO' ERR

# Function to run on success
handle_success() {

    # Define borders
    local package_name=$1
    local length=${#package_name}
    local border_length=$((length + 50))  # 50 is the static part of the message

    # Define color codes
    local green="\033[0;32m"
    local reset="\033[0m"

    # Create a dynamic border based on the package name length
    local border=$(printf '#%.0s' $(seq 1 $border_length))

    # Print the message
    echo
    echo "$border"
    echo -e "# Package ${green}$package_name${reset} installed and configured successfully #"
    echo "$border"
    echo
}

# Create student user
USERNAME="PIDS"
PASSWORD="PIDS"
GROUPS="users"
useradd -m -s /bin/bash -G $GROUPS $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd --crypt-method=SHA512

# Disable swap
swapoff -a

# Move to tmp to make the installation
cd /tmp

# Update and upgrade packages
apt update && apt upgrade -y

# Install aptitude
apt install -y aptitude
handle_success "aptitude"

# Install socat
apt install -y socat
handle_success "socat"

# Install Docker
apt-get update
apt-get install -y ca-certificates curl gpg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker.service
systemctl enable containerd.service
handle_success "docker"

# Install CUDA drivers
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt-get update
apt-get install -y cuda-toolkit-12-6
apt-get install -y cuda-drivers
handle_success "cuda-drivers"

# Install NVIDIA container runtime with Docker
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
	gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
	&& curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
	sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
	tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker
cat <<EOF > /etc/docker/daemon.json
{
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
EOF
handle_success "nvidia-container-toolkit"

# Install Docker CRI
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.14/cri-dockerd_0.3.14.3-0.ubuntu-jammy_amd64.deb ###### CAMBIAR JAMMY POR LO QUE TOQUE 
dpkg -i cri-dockerd_0.3.14.3-0.ubuntu-jammy_amd64.deb
handle_success "docker CRI"

# Install Kubectl, Kubeadm, and Kubelet v1.30
apt-get install -y apt-transport-https
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
	gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
	tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubectl kubelet kubeadm
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet
handle_success "kubectl"
handle_success "kubelet"
handle_success "kubeadm"

# Install SSH server
apt-get update
apt-get install -y openssh-server
handle_success "openssh-server"

# Install NFS client
apt-get install -y nfs-common
mkdir -p /mnt/nfs/kubernetes
chown nobody:nogroup /mnt/nfs/kubernetes
chmod 777 /mnt/nfs/kubernetes
# mount -t nfs4 master_ip:/srv/nfs/kubernetes /mnt/nfs/kubernetes
handle_success "nfs-common"

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/HEAD/scripts/get-helm-3 | bash
handle_success "helm"

# Install Jupyterhub
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update
handle_success "jupyterhub"

# Install NVITOP
apt-get update
apt-get install -y nvitop
handle_success "nvitop"

#################################################################################################################
# PIDS																											                                                    #
#################################################################################################################

# Install Python3.8
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt-get install -y python3.8 python3.8-venv
handle_success "python3.8"

# Instalar vscode (code) en cada nodo
sudo apt-get install -y wget gpg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
sudo apt install -y apt-transport-https
sudo apt update
sudo apt install code # or code-insiders