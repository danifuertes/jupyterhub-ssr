
# Stop JupyterHub
helm delete jupyterhub -n jupyterhub

# Remove NFS provisioner
kubectl delete sc nfs-sc -n jupyterhub

# Remove Kubernetes secret with Let's Encrypt certificates
kubectl delete secret/jupyterhub-tls -n jupyterhub

# Remove namespace
kubectl delete namespace jupyterhub
