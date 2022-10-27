#Build stage
FROM golang:1.19-alpine3.16 AS build-env

ARG GOPROXY
ENV GOPROXY ${GOPROXY:-direct}

ARG GITEA_VERSION
ARG TAGS="sqlite sqlite_unlock_notify"
ENV TAGS "bindata timetzdata $TAGS"
ARG CGO_EXTRA_CFLAGS

#Build deps
RUN apk --no-cache add build-base git nodejs npm

#Setup repo
COPY . ${GOPATH}/src/code.gitea.io/gitea
WORKDIR ${GOPATH}/src/code.gitea.io/gitea

#Checkout version if set
RUN if [ -n "${GITEA_VERSION}" ]; then git checkout "${GITEA_VERSION}"; fi \
 && make clean-all build

# Begin env-to-ini build
RUN go build contrib/environment-to-ini/environment-to-ini.go

FROM redhat/ubi8-minimal:latest

EXPOSE 2222 3000

RUN microdnf install \
    #bash \
    #ca-certificates \
    gettext \
    git \
    shadow-utils
    #Added above shadow utils for groupadd and useradd
    #curl \
    #gnupg

RUN groupadd \
    -g 1000 \
    git && \
  adduser \
    #-S -H -D \
    -d /var/lib/gitea/git \
    -s /bin/bash \
    -u 1000 \
    -g git \
    git

RUN mkdir -p /var/lib/gitea /etc/gitea
RUN chown git:git /var/lib/gitea /etc/gitea

COPY docker/rootless /
COPY --from=build-env --chown=root:root /go/src/code.gitea.io/gitea/gitea /app/gitea/gitea
COPY --from=build-env --chown=root:root /go/src/code.gitea.io/gitea/environment-to-ini /usr/local/bin/environment-to-ini
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-setup.sh /app/gitea/gitea /usr/local/bin/gitea /usr/local/bin/environment-to-ini

#git:git
USER 1000:1000
ENV GITEA_WORK_DIR /var/lib/gitea
ENV GITEA_CUSTOM /var/lib/gitea/custom
ENV GITEA_TEMP /tmp/gitea
ENV TMPDIR /tmp/gitea

#TODO add to docs the ability to define the ini to load (useful to test and revert a config)
ENV GITEA_APP_INI /etc/gitea/app.ini
ENV HOME "/var/lib/gitea/git"
VOLUME ["/var/lib/gitea", "/etc/gitea"]
WORKDIR /var/lib/gitea

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []
