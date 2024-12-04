#!/bin/bash
set -e  # Stop execution if any command fails

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --password)
            if [[ -z $2 ]]; then
                echo "Error: --password requires an argument."
            fi
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

# Define the command to reset the node
command="echo $PASSWORD | sudo -S kubeadm reset --cri-socket unix:///var/run/cri-dockerd.sock --force && sudo rm -rf \$HOME/.kube/config /etc/cni/net.d /var/lib/kubelet/* /etc/kubernetes/"

# Run the command on the control-plane node
eval "$command"
if [ $? -ne 0 ]; then
    echo
    echo "Failed to reset the control-plane node."
    echo
    exit 1
fi

# Cluster destroyed successfully
echo
echo "###############################"
echo "# Cluster reset successfully! #"
echo "###############################"
echo

# Get the node IPs as arguments
# nodes="$@"
if [ -z "$nodes" ]; then
    echo
    echo "No nodes provided to reset the cluster. Run this command manually on the worker nodes:"
    echo
    echo "      $command"
    echo
else
    echo
    echo "Resetting the following nodes of the cluster in parallel:"
    echo
    echo "      $nodes"
    echo

    # Connect to each node and reset in parallel
    for node in $nodes; do
        {
            echo
            echo "-----------------------------------"
            echo "Starting reset process for node $node..."
            
            # Reset each node in parallel with forced TTY allocation
            ssh -tt -o StrictHostKeyChecking=no $node "$command"
            if [ $? -ne 0 ]; then
                echo
                echo "Failed to reset node $node. Please check the node and try again."
                echo
            else
                # Node successfully reset
                node_length=${#node}
                line=$(printf '#%.0s' $(seq 1 $((node_length + 29)))) # Create a line of '#' based on the node length
                echo
                echo "$line"
                echo "# Node $node successfully reset! #"
                echo "$line"
                echo
            fi

            echo "Finished reset process for node $node."
            echo "-----------------------------------"
        } &
    done

    # Wait for all parallel jobs to finish
    wait
    echo
    echo "All nodes have been reset successfully!"
fi
