FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

USER vscode
ENV ELAN_HOME=/home/vscode/.elan
ENV PATH="${ELAN_HOME}/bin:${PATH}"

RUN curl --fail --show-error --location --connect-timeout 15 --max-time 120 \
      https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh \
      --output /tmp/elan-init.sh \
    && timeout 180 sh /tmp/elan-init.sh -y --default-toolchain none \
    && rm /tmp/elan-init.sh
