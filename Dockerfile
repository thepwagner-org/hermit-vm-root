FROM golang:1.17.2@sha256:124966f5d54a41317ee81ccfe5f849d4f0deef4ed3c5c32c20be855c51c15027 AS builder
WORKDIR /app
ARG GONOSUMDB=*
COPY go.mod go.sum /app/
RUN update-ca-certificates && \
  go mod download
COPY . .
RUN go build -o /guest ./cmd

FROM debian:bullseye-slim@sha256:dddc0f5f01db7ca3599fd8cf9821ffc4d09ec9d7d15e49019e73228ac1eee7f9

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
ARG BUILDKIT_VERSION=v0.9.0
ARG BUILDKIT_CHECKSUM=1b307268735c8f8e68b55781a6f4c03af38acc1bc29ba39ebaec6d422bccfb25

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
