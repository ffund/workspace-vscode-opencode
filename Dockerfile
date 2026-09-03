FROM prairielearn/workspace-vscode-python:latest

ENV PATH="/opt/node/bin:/usr/local/bin:${PATH}"
ENV XDG_CACHE_HOME="/tmp/opencode-cache"

# Tell PrairieLearn to strip its container URL prefix before proxying to code-server.
EXPOSE 8080
LABEL com.prairielearn.workspace.port="8080" \
      com.prairielearn.workspace.rewrite-url="true" \
      com.prairielearn.workspace.home="/home/coder/workspace"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends xz-utils && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt && curl -fsSL https://nodejs.org/dist/v22.19.0/node-v22.19.0-linux-x64.tar.xz | tar -xJ -C /opt \
    && mv /opt/node-v22.19.0-linux-x64 /opt/node \
    && npm install -g --ignore-scripts @earendil-works/pi-coding-agent

RUN mkdir -p /opt/opencode && export HOME=/opt/opencode && curl -fsSL https://opencode.ai/install | bash
RUN mkdir -p /tmp/opencode-cache && chmod 1777 /tmp/opencode-cache

COPY opencode.json /opt/opencode-config/opencode.json
COPY opencode-wrapper /usr/local/bin/opencode
COPY workspace-entrypoint /usr/local/bin/workspace-entrypoint
RUN chmod 0755 /usr/local/bin/opencode /usr/local/bin/workspace-entrypoint

ENTRYPOINT ["/usr/bin/pl-gosu-helper.sh", "/usr/local/bin/workspace-entrypoint"]

USER coder

RUN uv pip install --python /home/coder/.venv/bin/python jupyter ipykernel

RUN code-server --disable-telemetry --force --install-extension sst-dev.opencode \
    --install-extension ms-python.python \
    --install-extension ms-python.vscode-python-envs \
    --install-extension ms-toolsai.jupyter \
    && rm -rf /home/coder/.local/share/code-server/CachedExtensionVSIXs

RUN python -c 'import json; from pathlib import Path; p = Path("/home/coder/.local/share/code-server/User/settings.json"); settings = json.loads(p.read_text()); settings.update({"workbench.browser.dataStorage": "workspace", "workbench.browser.enableRemoteProxy": True, "workbench.browser.openLocalhostLinks": True, "workbench.browser.showInTitleBar": True, "python.defaultInterpreterPath": "/home/coder/.venv/bin/python"}); p.write_text(json.dumps(settings, indent=2) + "\n")'

WORKDIR "/home/coder/workspace"
