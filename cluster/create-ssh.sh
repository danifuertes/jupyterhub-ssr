#!/bin/bash
set -e  # Stop execution if any command fails

# Default values
IP_NFS_SERVER=""

# Function to display usage
usage() {
    echo "Usage: $0 [--nfs_server <nfs-server-ip>] <worker-nodes...>"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --nfs_server)
            if [[ -z $2 ]]; then
                echo "Error: --nfs_server requires an argument."
                usage
            fi
            IP_NFS_SERVER=$2
            shift 2
            ;;
       --password)
            PASSWORD=$2
            shift 2
            ;;
        *)
            nodes="$@"
            break
            ;;
    esac
done

# Prompt for the sudo password
if [ -z "$PASSWORD" ]; then
    read -sp 'Enter your sudo password: ' PASSWORD
    echo
fi

# Get master node IP address
IP_MASTER=$(ip -br a | awk '/eno1/{print $3}' | cut -d'/' -f1)

# Set IP_NFS_SERVER to IP_MASTER if not provided
if [[ -z "$IP_NFS_SERVER" ]]; then
    IP_NFS_SERVER="$IP_MASTER"
fi

# Create cluster
echo
echo "Initializing Kubernetes cluster..."
echo $PASSWORD | sudo -S sudo kubeadm init --kubernetes-version=v1.30.2 --cri-socket unix:///var/run/cri-dockerd.sock --pod-network-cidr=192.168.0.0/16
if [ $? -ne 0 ]; then
    echo
    echo "Failed to initialize the Kubernetes cluster."
    echo
    exit 1
fi
echo

# Prepare permissions for kubectl
echo
echo "Setting up kubectl permissions..."
mkdir -p $HOME/.kube && \
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config
if [ $? -ne 0 ]; then
    echo
    echo "Failed to configure kubectl."
    echo
    exit 1
fi
echo


# Apply Calico networking manifest
echo
echo "Applying Calico network configuration..."
kubectl apply -f calico.yaml
if [ $? -ne 0 ]; then
    echo
    echo "Failed to apply Calico network configuration."
    echo
    exit 1
fi
echo

# Apply NVIDIA manifest to allow GPU usage
echo
echo "Applying NVIDIA device plugin for GPU..."
kubectl create -f nvidia-device-plugin.yml
if [ $? -ne 0 ]; then
    echo
    echo "Failed to apply NVIDIA device plugin configuration."
    echo
    exit 1
fi
echo

# Get join (join to the cluster) and mount (mount NFS) commands
token=$(kubeadm token create --print-join-command)
join_command="$token --cri-socket unix:///var/run/cri-dockerd.sock"
mount_command="if [ ! -d /mnt/nfs/kubernetes ]; then echo $PASSWORD | sudo -S mkdir -p /mnt/nfs/kubernetes; fi && echo $PASSWORD | sudo -S mount -t nfs4 $IP_NFS_SERVER:/srv/nfs/kubernetes /mnt/nfs/kubernetes"
echo
echo "#################################"
echo "# Cluster created successfully! #"
echo "#################################"
echo

# Get the node IPs as arguments
nodes="$@"
if [ -z "$nodes" ]; then
    echo
    echo "No worker nodes provided to join the cluster. Run these commands manually on the worker nodes:"
    echo
    echo "      mount_command"
    echo
    echo "      sudo $join_command"
    echo
else
    echo
    echo "Joining the following nodes to the cluster in parallel:"
    echo
    echo "      $nodes"
    echo

    # Connect to each node in parallel
    for node in $nodes; do
        {
            # Mount NFS on each node
            echo
            echo "Mounting NFS on node $node..."
            ssh -t -o StrictHostKeyChecking=no $node "$mount_command"
            if [ $? -ne 0 ]; then
                echo
                echo "Failed to mount NFS on node $node."
                echo
                exit 1
            fi
            echo

            # Join each node to the cluster
            echo
            echo "Joining node $node to the cluster..."
            ssh -t -o StrictHostKeyChecking=no $node "echo $PASSWORD | sudo -S $join_command"
            if [ $? -ne 0 ]; then
                echo
                echo "Failed to join node $node to the cluster."
                echo
                exit 1
            fi
            echo

            # Label each node as a worker
            kubectl label node $node node-role.kubernetes.io/worker=worker
            if [ $? -ne 0 ]; then
                echo
                echo "Failed to label node $node as a worker."
                echo
                exit 1
            fi
            echo

            # Node successfully joined
            node_length=${#node}
            line=$(printf '#%.0s' $(seq 1 $((node_length + 42)))) # Create a line of '#' based on the node length
            echo
            echo "$line"
            echo "# Node $node successfully joined the cluster! #"
            echo "$line"
            echo
        } &
    done

    # Wait for all parallel jobs to finish
    wait
fi

echo
echo "Check if your nodes have successfully joined the cluster:"
echo
echo "        kubectl get nodes"
echo
