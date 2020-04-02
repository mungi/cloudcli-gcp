FROM docker:17.12.0-ce as static-docker-source

FROM alpine:3.11
### Set Terraform, Packer, HELM, GCP CLI Version
ARG TERRAFORM_VERSION=0.12.24
ARG PACKER_VERSION=1.5.4
ARG HELM_VERSION=3.1.2
ARG CLOUD_SDK_VERSION=287.0.0
ENV CLOUD_SDK_VERSION=$CLOUD_SDK_VERSION
ENV CLOUDSDK_PYTHON=python3
ENV HELM_FILE=https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz

ENV PATH /google-cloud-sdk/bin:$PATH

COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker
RUN apk --no-cache add \
        curl \
        python3 \
        py3-crcmod \
        bash \
        libc6-compat \
        openssh-client \
        git \
        gnupg \
        jq \
    && curl -sLO https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    gcloud config set core/disable_usage_reporting true && \
    gcloud config set component_manager/disable_update_check true && \
    gcloud config set metrics/environment github_docker_image && \
    apk -uv add --no-cache --virtual .build-deps gcc build-base libffi-dev openssl-dev python3-dev && \
    pip3 install --upgrade --no-cache-dir pip ansible openshift && \
    apk del --no-network --no-cache .build-deps && \
    rm -rf /var/cache/apk/*


# Install Terraform, Packer
RUN curl -sL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o temp1.zip && \
    unzip temp1.zip -d /usr/local/bin/ && rm -f temp*.zip && \
    KUBECTL_VERSION=$(wget --no-cache -qO- https://storage.googleapis.com/kubernetes-release/release/stable.txt) && \
    curl -sL https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl && \
    curl -sL ${HELM_FILE} | tar xz && mv linux-amd64/helm /usr/local/bin/ && rm -rf linux-amd64  && \
    helm repo add stable https://kubernetes-charts.storage.googleapis.com/ && helm repo update

# Just describe the versions at log
RUN LINES=$(printf -- '-%.0s' $(seq 80); echo "") && echo $LINES && \
    terraform --version && echo $LINES && \
    gcloud version && echo $LINES && \
    kubectl version -o yaml --short --client && echo $LINES && \
    helm version --short && echo $LINES && \
    ansible --version

VOLUME ["/root/.config"]
