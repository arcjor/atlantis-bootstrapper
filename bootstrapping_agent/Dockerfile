
FROM ubuntu:22.04
WORKDIR /

RUN apt-get update && apt-get install -y --no-install-recommends curl=7.81.0-1ubuntu1.6 jq=1.6-2.1ubuntu3 unzip=6.0-26ubuntu3.1 \ 
    ca-certificates=20211016 gnupg=2.2.27-3ubuntu2.1 lsb-release=11.1.0ubuntu4 apt-transport-https=2.4.8

# Install Azure CLI
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
RUN AZ_REPO=$(lsb_release -cs) && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list
RUN apt-get update && apt-get install -y --no-install-recommends azure-cli=2.42.0-1~jammy

# Install Terraform
ARG TERRAFORM_VERSION="1.3.3"
RUN curl -sL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o /tmp/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip /tmp/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/bin && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /var/tmp/*

# Install GH CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg;
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null;
RUN apt-get update && apt-get install -y --no-install-recommends gh=2.19.0;
RUN apt-get clean

# Copy the contents of this repo into the container to make scripts available
COPY . .

# Make the container run forever
ENTRYPOINT ["/bin/bash"]
