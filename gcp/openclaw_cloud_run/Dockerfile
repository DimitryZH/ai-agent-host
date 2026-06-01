FROM node:24-bookworm-slim

ARG OPENCLAW_VERSION=2026.4.21

ENV DEBIAN_FRONTEND=noninteractive \
    OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    OPENCLAW_HOME=/home/openclaw \
    OPENCLAW_STATE_DIR=/var/lib/openclaw/state \
    OPENCLAW_RUNTIME_DIR=/var/lib/openclaw/runtime \
    OPENCLAW_CONFIG_TEMPLATE=/opt/openclaw/config/openclaw.template.json \
    OPENCLAW_CONFIG_PATH=/var/lib/openclaw/runtime/openclaw.json \
    PORT=8080

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        jq \
        tini \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh \
    | bash -s -- --no-onboard --install-method npm --version "${OPENCLAW_VERSION}" \
    && openclaw --version

RUN groupadd --system --gid 10001 openclaw \
    && useradd --system --uid 10001 --gid openclaw --create-home --home-dir "${OPENCLAW_HOME}" --shell /usr/sbin/nologin openclaw \
    && install -d -o openclaw -g openclaw -m 0750 /var/lib/openclaw \
    && install -d -o openclaw -g openclaw -m 0750 "${OPENCLAW_STATE_DIR}" \
    && install -d -o openclaw -g openclaw -m 0750 "${OPENCLAW_RUNTIME_DIR}" \
    && install -d -o openclaw -g openclaw -m 0750 /opt/openclaw/config \
    && chown -R openclaw:openclaw /usr/local/lib/node_modules/openclaw/dist/extensions

COPY config/openclaw.template.json /opt/openclaw/config/openclaw.template.json
COPY entrypoint.sh /usr/local/bin/openclaw-cloud-run-entrypoint.sh

RUN chmod 0755 /usr/local/bin/openclaw-cloud-run-entrypoint.sh \
    && chown openclaw:openclaw /opt/openclaw/config/openclaw.template.json

USER openclaw
WORKDIR /var/lib/openclaw/runtime

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/openclaw-cloud-run-entrypoint.sh"]
