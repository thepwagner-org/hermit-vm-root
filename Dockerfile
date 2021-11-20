FROM golang:1.17.3@sha256:4f0671cf24397b6f98013bfc47882d4299573639c3714825297ddbd4b621ee92 AS builder
WORKDIR /app
COPY . .
RUN go build -mod=vendor -o /guest ./cmd

FROM debian:bullseye-slim@sha256:a23887a2e830b815955e010f30d4c2430cd5ef82e93c130471024bc9f808d5d3

# Install an init system and minimize footprint:
RUN apt-get update && \
  apt-get install -y \
    curl \
    systemd-sysv \
    linux-image-amd64 \
  && \
  apt-get clean && \
  rm -Rf \
    /var/lib/apt/lists/* \
    /boot/* \
    /lib/modules
RUN systemctl mask getty@tty1.service && \
  systemctl mask getty@tty2.service && \
  systemctl mask getty@tty3.service && \
  systemctl mask getty@tty4.service && \
  systemctl mask getty@tty5.service && \
  systemctl mask getty@tty6.service && \
  systemctl mask systemd-timesyncd.service && \
  echo "hermit-sandbox" > /etc/hostname

# renovate: datasource=github-releases depName=opencontainers/runc versioning=semver
ARG RUNC_VERSION=v1.0.2
ARG RUNC_CHECKSUM=44d1ba01a286aaf0b31b4be9c6abc20deab0653d44ecb0d93b4d0d20eac3e0b6

RUN curl -Lo /usr/local/bin/runc "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.amd64" && \
    echo "${RUNC_CHECKSUM}  /usr/local/bin/runc" | sha256sum -c - && \
    chmod +x /usr/local/bin/runc

# renovate: datasource=github-releases depName=moby/buildkit versioning=semver
ARG BUILDKIT_VERSION=v0.9.2
ARG BUILDKIT_CHECKSUM=931d8bb6b461a396c54ed2ce4fa48a2d5eafeb6985a97823e39e549bc89bec27

RUN curl -Lo /tmp/buildkit.tgz "https://github.com/moby/buildkit/releases/download/${BUILDKIT_VERSION}/buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz" && \
    echo "${BUILDKIT_CHECKSUM}  /tmp/buildkit.tgz" | sha256sum -c - && \
    tar -xzvvf /tmp/buildkit.tgz -C "/usr/local/bin" --strip-components=1 \
      bin/buildkitd \
    && \
    rm -f /tmp/buildkit.tgz
COPY systemd/buildkit.service /etc/systemd/system/buildkit.service
COPY systemd/buildkit.socket /etc/systemd/system/buildkit.socket
RUN systemctl enable buildkit.service

# Install the guest:
COPY systemd/guestproxy.service /etc/systemd/system/guestproxy.service
COPY systemd/guestproxy-cert.service /etc/systemd/system/guestproxy-cert.service
COPY systemd/guestbuild.service /etc/systemd/system/guestbuild.service
COPY systemd/input.mount /etc/systemd/system/input.mount
COPY systemd/output.mount /etc/systemd/system/output.mount
RUN systemctl enable guestproxy.service && \
  systemctl enable guestproxy-cert.service && \
  mkdir -p /input && \
  systemctl enable input.mount && \
  mkdir -p /output && \
  systemctl enable output.mount

# Autostart guestbuild and disable login:
RUN systemctl enable guestbuild.service
RUN systemctl mask serial-getty@ttyS0.service

COPY --from=builder /guest /usr/local/bin/guest

