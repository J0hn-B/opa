#!/usr/bin/env bash

# Bash color parameters
GREEN='\033[0;32m'
NC='\033[0m'

# Parameters
CLUSTER=$(k3d cluster list | grep dev-cluster)
KUBECTL_VERSION=$(kubectl version --short)
HELM_VERSION=$(helm version --short)
YQ_VERSION=$(yq --version)
YQ_DOWNLOAD_VERSION="v4.9.8"
YQ_DOWNLOAD_BINARY="yq_linux_amd64"
REPO=$(git config --local remote.origin.url)

# Install Yq
if [ "$YQ_VERSION" ]; then
    echo -e "${GREEN}==> Yq:${NC} $YQ_VERSION"
else
    echo -e "==> Installing Yq..."
    sudo wget https://github.com/mikefarah/yq/releases/download/${YQ_DOWNLOAD_VERSION}/${YQ_DOWNLOAD_BINARY}.tar.gz -O - |
        tar xz && sudo mv ${YQ_DOWNLOAD_BINARY} /usr/bin/yq
fi

# Install Kubectl
if [ "$KUBECTL_VERSION" ]; then
    echo -e "${GREEN}==> Kubectl:${NC} $KUBECTL_VERSION"
else
    echo -e "==> Installing Kubectl..."
    sudo curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    kubectl version --client
fi

# Install Helm
if [ "$HELM_VERSION" ]; then
    echo -e "${GREEN}==> Helm:${NC} $HELM_VERSION"
else
    echo -e "==> Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
fi

# Prepare the k3d cluster
if [ "$CLUSTER" ]; then
    echo -e "${GREEN}==> Cluster:${NC} $CLUSTER"
else
    echo -e "==>  Cluster does not exist"
    wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
    k3d cluster create dev-cluster --agents 2
fi

echo
# update opa-constraint-templates.yaml repoURL
OPA_CONSTRAINT_TEMPLATES=$(repo=${REPO%.*} yq e '.spec.source.repoURL == env(repo)' argocd/applications/opa-constraint-templates.yaml)

if [ -f "argocd/applications/opa-constraint-templates.yaml" ]; then
    if [ "$OPA_CONSTRAINT_TEMPLATES" = true ]; then
        echo -e "The opa-constraint-templates.yaml repoURL in ${GREEN}argocd/applications/opa-constraint-templates.yaml${NC} is up to date: ${GREEN}${REPO%.*}${NC}"
    else
        repo=${REPO%.*} yq e '.spec.source.repoURL = env(repo)' -i argocd/applications/opa-constraint-templates.yaml
        echo -e "${GREEN}Updating the opa-constraint-templates.yaml repoURL with your git repo url:${NC} $REPO"
    fi
fi

echo
# update opa-constraints.yaml repoURL

OPA_CONSTRAINTS=$(repo=${REPO%.*} yq e '.spec.source.repoURL == env(repo)' argocd/applications/opa-constraints.yaml)

if [ -f "argocd/applications/opa-constraints.yaml" ]; then
    if [ "$OPA_CONSTRAINTS" = true ]; then
        echo -e "The opa-constraints.yaml repoURL in ${GREEN}argocd/applications/opa-constraints.yaml${NC} is up to date: ${GREEN}${REPO%.*}${NC}"
    else
        repo=${REPO%.*} yq e '.spec.source.repoURL = env(repo)' -i argocd/applications/opa-constraint-templates.yaml
        echo -e "${GREEN}Updating the opa-constraints.yaml repoURL with your git repo url:${NC} $REPO"
    fi
fi

echo
