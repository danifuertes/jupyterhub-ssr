# Default values
IP_NFS_SERVER=$(ip -br a | awk '/eno1/{print $3}' | cut -d'/' -f1)  # IP of the NFS server (default is IP of current machine)

# Function to display usage
usage() {
    echo "Usage: $0 [--nfs_server <nfs-server-ip>] <worker-nodes...>"
    exit 1
}

# Parse arguments
if [[ $# -gt 0 ]]; then
    case $1 in
        --nfs_server)
            if [[ -z $2 ]]; then
                echo "Error: --nfs_server requires an argument."
                usage
            fi
            IP_NFS_SERVER=$2
            ;;
        *)
            break
            ;;
    esac
fi

# Create namespace
kubectl create namespace jupyterhub

# Create NFS provisioner and storage class
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --set nfs.server=$IP_NFS_SERVER --set nfs.path=/srv/nfs/kubernetes
kubectl apply -f storage.yaml -n jupyterhub

# Create Kubernetes secret with Let's Encrypt certificates
kubectl create secret tls jupyterhub-tls --cert=jupyter-crt.pem --key=jupyter-key.pem -n jupyterhub

# Launch JupyterHub
helm upgrade --cleanup-on-fail --install jupyterhub jupyterhub/jupyterhub --namespace jupyterhub --values config.yaml
