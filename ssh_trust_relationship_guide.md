# SSH TRUST RELATIONSHIP GUIDE

say you have two debian nodes.

1. Check whether you already have an SSH key

On the machine where you will run the installer:

```bash
ls -la ~/.ssh/
```

Look for something like:

```text
id_ed25519
id_ed25519.pub
```

If you don't have one, create it:

```bash
ssh-keygen -t ed25519 -C "k8s-installer"
```

You can simply press Enter through the prompts if you don't want a passphrase for this lab.

2. Copy your key to both Debian machines

For your master:

```bash
ssh-copy-id root@192.168.56.10
```

Enter the password one final time.

Then:

```bash
ssh-copy-id root@192.168.56.11
```

Again, enter the password one final time.

Test:

```bash
ssh root@192.168.56.10
```

and:

```bash
ssh root@192.168.56.11
```

You should now get in without a password.

Exit:

```bash
exit
```

3. If you're using a normal Debian user

For example:

```bash
ssh-copy-id jagk@192.168.56.10
ssh-copy-id jagk@192.168.56.11
```

However, the user needs passwordless sudo for the current v1 implementation, because the remote installation performs privileged operations.

For a lab, you can configure:

```bash
sudo visudo
```

and add:

```bash
jagk ALL=(ALL) NOPASSWD:ALL
```

Then test:

```bash
ssh jagk@192.168.56.10 "sudo -n true && echo SUDO_OK"
```

You should see:

```bash
SUDO_OK
```



The intended workflow is:

unzip k8s-cluster-installer-v1.zip
cd k8s-cluster-installer-v1

cp examples/cluster.yaml cluster.yaml
vi cluster.yaml

./install.sh cluster.yaml --validate
./install.sh cluster.yaml --dry-run
./install.sh cluster.yaml

Then:

./install.sh cluster.yaml --status

And to reset Kubernetes across the configured nodes:

./reset.sh cluster.yaml

chmod 777 install.sh reset.sh
apt update && apt install -y python3 python3-pip python3-yaml
