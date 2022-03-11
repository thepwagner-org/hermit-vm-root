FROM golang:1.17.8@sha256:c7c94588b6445f5254fbc34df941afa10de04706deb330e62831740c9f0f2030 AS builder
WORKDIR /app
COPY . .
RUN go build -mod=vendor -o /guest ./cmd

FROM debian:bullseye-slim@sha256:d5cd7e54530a8523168473a2dcc30215f2c863bfa71e09f77f58a085c419155b

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
ARG RUNC_VERSION=v1.1.0
ARG RUNC_CHECKSUM=ab1c67fbcbdddbe481e48a55cf0ef9a86b38b166b5079e0010737fd87d7454bb

RUN curl -Lo /usr/local/bin/runc "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.amd64" && \
    echo "${RUNC_CHECKSUM}  /usr/local/bin/runc" | sha256sum -c - && \
    chmod +x /usr/local/bin/runc

# renovate: datasource=github-releases depName=moby/buildkit versioning=semver
ARG BUILDKIT_VERSION=v0.10.0
ARG BUILDKIT_CHECKSUM=ed9d3942ca3f1cbc4906577a2422e5084416dd2739f3d85b800a129d61557630

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

