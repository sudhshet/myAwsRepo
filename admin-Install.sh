#!/usr/bin/bash

# Install eksctl
echo "Installing eksctl..."
curl "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
    --silent --location \
    | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/

# Install eksctl-anywhere
echo "Installing eksctl-anywhere..."

RELEASE_VERSION=$(curl https://anywhere-assets.eks.amazonaws.com/releases/eks-a/manifest.yaml --silent --location | yq ".spec.latestVersion")
EKS_ANYWHERE_TARBALL_URL=$(curl https://anywhere-assets.eks.amazonaws.com/releases/eks-a/manifest.yaml --silent --location | yq ".spec.releases[] | select(.version==\"$RELEASE_VERSION\").eksABinary.$(uname -s | tr A-Z a-z).uri")
curl $EKS_ANYWHERE_TARBALL_URL \
    --silent --location \
    | tar xz ./eksctl-anywhere
sudo mv ./eksctl-anywhere /usr/local/bin/

# Install kubectl
export OS="$(uname -s | tr A-Z a-z)" ARCH=$(test "$(uname -m)" = 'x86_64' && echo 'amd64' || echo 'arm64')
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/${OS}/${ARCH}/kubectl"
sudo mv ./kubectl /usr/local/bin
sudo chmod +x /usr/local/bin/kubectl

# Enable kubectl bash_completion
kubectl completion bash >>  ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion

# Download the artifacts and images that will be used by the cluster nodes to the Admin machine using the following command:, A compressed file eks-anywhere-downloads.tar.gz will be downloaded.
eksctl anywhere download artifacts

# To decompress this file, use the following command:
tar -xvf eks-anywhere-downloads.tar.gz

# Installation of Docker CE - https://computingforgeeks.com/how-to-install-docker-on-ubuntu/?expand_article=1
echo "Installing Docker Pre-requisites..."
sudo apt -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg
# Add Docker CE repository to Ubuntu
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "Installing Docker CE..."
sudo apt -y update
sudo apt -y install docker-ce docker-ce-cli containerd.io
sudo docker version

# Download Hook OS files
mkdir -p eksa/hook/
EKSA_RELEASE_VERSION=$(curl -sL https://anywhere-assets.eks.amazonaws.com/releases/eks-a/manifest.yaml | yq ".spec.latestVersion")
BUNDLE_MANIFEST_URL=$(curl -sL https://anywhere-assets.eks.amazonaws.com/releases/eks-a/manifest.yaml | yq ".spec.releases[] | select(.version==\"$EKSA_RELEASE_VERSION\").bundleManifestUrl")
cd ./eksa/hook
wget `curl -s $BUNDLE_MANIFEST_URL | yq ".spec.versionsBundles[0].tinkerbell.tinkerbellStack.hook.vmlinuz.amd.uri"`
wget `curl -s $BUNDLE_MANIFEST_URL | yq ".spec.versionsBundles[0].tinkerbell.tinkerbellStack.hook.initramfs.amd.uri"`

# In order for the next command to run smoothly, ensure that Docker has been pre-installed and is running. Then run the following:
eksctl anywhere download images -o images.tar

# Run docker Registry
mkdir auth
docker run --entrypoint htpasswd httpd:2 -Bbn testuser testpassword > auth/htpasswd
docker run -d -p 5000:5000 --restart=always --name registry -v "$(pwd)"/auth:/auth -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd registry:2

# Setup Environment variable for Registry - 
export REGISTRY_ENDPOINT=localhost:5000
export REGISTRY_USERNAME=testuser
export REGISTRY_PASSWORD=testpassword

# Import images in Local Docker registry
eksctl anywhere import images -i images.tar -r localhost:5000  --bundles ./eks-anywhere-downloads/bundle-release.yaml
