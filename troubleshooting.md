Since you are running the installer script directly on the target node (master01), the script is trying to establish an SSH connection to itself via its local IP address (192.168.146.135).Because you are connecting locally, you just need to allow the node's root user to SSH into itself. Run the following command on this machine to add its own public key to its authorized keys list:1. Authorize the Key Locallybashcat /root/.ssh/id_ed25519.pub >> /root/.ssh/authorized_keys
Use code with caution.2. Set the Correct PermissionsSSH will reject keys if the file permissions are too open. Ensure they are locked down:bashchmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
Use code with caution.3. Verify the Local ConnectionTest that the local SSH connection works without asking for a password:bashssh root@192.168.146.135
Use code with caution.If successful, type exit to return to your installer prompt.4. Run the Installer AgainOnce the manual connection succeeds, rerun your validation command:bash./install.sh cluster.yaml --validate




Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.146.135:6443 --token 9shdwe.c8qvb0mikvmjmk3p \
        --discovery-token-ca-cert-hash sha256:8cbfd464da5a007831e2cbddb7bc0a2322f4e7d03ed42062af6de1029b9a2e59


The problem is that your control-plane node and your new worker node are both named "debian".When you ran kubectl get nodes, you can see that your single control-plane node is using the name debian and the IP 192.168.146.135. When you ran kubeadm join on the second machine, it also tried to register itself using its own local hostname (debian). Kubernetes blocked this because it thought the control-plane node was trying to overwrite itself.To successfully add your second node and see both in the list, you must give the second machine a unique name.Solution: Join the second node with a unique nameGo back to your second machine (the worker node you are trying to add) and run the kubeadm join command again, but add the --node-name flag at the very end to give it a distinct name (like debian-worker):bashkubeadm join 192.168.146.135:6443 --token 9shdwe.c8qvb0mikvmjmk3p \
--discovery-token-ca-cert-hash sha256:8cbfd464da5a007831e2cbddb7bc0a2322f4e7d03ed42062af6de1029b9a2e59 \
--node-name debian-worker
Use code with caution.Once that command completes successfully, go back to your control plane node and run kubectl get nodes -o wide again. You will now see two nodes listed.



rm -rf /etc/kubernetes/
rm -rf /var/lib/kubelet/
rm -rf /var/lib/etcd/