#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

DOTNET_SDK_PACKAGE="${DOTNET_SDK_PACKAGE:-dotnet-sdk-10.0}"
INSTALL_NODEJS="${INSTALL_NODEJS:-false}"
NODEJS_MAJOR="${NODEJS_MAJOR:-22}"

log() {
  printf '[devbox-bootstrap] %s\n' "$*"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    printf 'This bootstrap script must run as root.\n' >&2
    exit 1
  fi
}

load_os_release() {
  # shellcheck disable=SC1091
  source /etc/os-release
  UBUNTU_CODENAME="${VERSION_CODENAME}"
  UBUNTU_VERSION_ID="${VERSION_ID}"
  ARCH="$(dpkg --print-architecture)"
}

apt_update() {
  apt-get update -y
}

install_packages() {
  apt-get install -y --no-install-recommends "$@"
}

install_keyring() {
  local url="$1"
  local destination="$2"

  if [[ ! -f "${destination}" ]]; then
    curl -fsSL "${url}" | gpg --dearmor -o "${destination}"
  fi

  chmod 0644 "${destination}"
}

install_base_packages() {
  log "Installing base packages"
  apt_update
  install_packages \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    lsb-release \
    software-properties-common \
    unzip \
    wget
}

install_docker() {
  log "Installing Docker Engine and Compose plugin"
  install -m 0755 -d /etc/apt/keyrings
  install_keyring "https://download.docker.com/linux/ubuntu/gpg" "/etc/apt/keyrings/docker.gpg"

  cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable
EOF

  apt_update
  install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

install_github_cli() {
  log "Installing GitHub CLI"
  install -m 0755 -d /etc/apt/keyrings
  install_keyring "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "/etc/apt/keyrings/githubcli.gpg"

  cat >/etc/apt/sources.list.d/github-cli.list <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main
EOF

  apt_update
  install_packages gh
}

install_google_cloud_cli() {
  log "Installing Google Cloud CLI"
  install -m 0755 -d /etc/apt/keyrings
  install_keyring "https://packages.cloud.google.com/apt/doc/apt-key.gpg" "/etc/apt/keyrings/google-cloud.gpg"

  cat >/etc/apt/sources.list.d/google-cloud-sdk.list <<EOF
deb [signed-by=/etc/apt/keyrings/google-cloud.gpg] https://packages.cloud.google.com/apt cloud-sdk main
EOF

  apt_update
  install_packages google-cloud-cli
}

install_terraform_cli() {
  log "Installing Terraform CLI"
  install -m 0755 -d /etc/apt/keyrings
  install_keyring "https://apt.releases.hashicorp.com/gpg" "/etc/apt/keyrings/hashicorp.gpg"

  cat >/etc/apt/sources.list.d/hashicorp.list <<EOF
deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com ${UBUNTU_CODENAME} main
EOF

  apt_update
  install_packages terraform
}

install_dotnet_sdk() {
  log "Installing .NET SDK package ${DOTNET_SDK_PACKAGE}"

  if ! dpkg -s packages-microsoft-prod >/dev/null 2>&1; then
    local package_file="/tmp/packages-microsoft-prod.deb"
    curl -fsSL -o "${package_file}" "https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION_ID}/packages-microsoft-prod.deb"
    dpkg -i "${package_file}"
    rm -f "${package_file}"
  fi

  apt_update
  install_packages "${DOTNET_SDK_PACKAGE}"
}

install_aspire_cli() {
  log "Installing Aspire CLI"

  if command -v aspire >/dev/null 2>&1; then
    log "Aspire CLI already installed"
    return
  fi

  mkdir -p /usr/local/share/dotnet-tools
  dotnet tool install Aspire.Cli --tool-path /usr/local/share/dotnet-tools --prerelease
  ln -sf /usr/local/share/dotnet-tools/aspire /usr/local/bin/aspire
}

install_nodejs_optional() {
  if [[ "${INSTALL_NODEJS}" != "true" ]]; then
    log "Skipping optional Node.js installation. Set INSTALL_NODEJS=true to enable."
    return
  fi

  log "Installing optional Node.js ${NODEJS_MAJOR}.x"
  install -m 0755 -d /etc/apt/keyrings
  install_keyring "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" "/etc/apt/keyrings/nodesource.gpg"

  cat >/etc/apt/sources.list.d/nodesource.list <<EOF
deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODEJS_MAJOR}.x nodistro main
EOF

  apt_update
  install_packages nodejs
}

main() {
  require_root
  load_os_release
  install_base_packages
  install_docker
  install_github_cli
  install_google_cloud_cli
  install_terraform_cli
  install_dotnet_sdk
  install_aspire_cli
  install_nodejs_optional

  log "Bootstrap complete. Authenticate GitHub and Google Cloud manually when required."
}

main "$@"
