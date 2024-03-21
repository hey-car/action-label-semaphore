ARG ALPINE_VERSION="3.19"

FROM alpine:${ALPINE_VERSION}


ARG BASH_VERSION="5"
ARG GIT_VERSION="2"
ARG JQ_VERSION="1"
ARG YQ_VERSION="4"
ARG CURL_VERSION="8"
ARG GITHUB_CLI_VERSION="2"

WORKDIR /scripts

RUN apk update --no-cache; \
    apk upgrade --no-cache; \
    apk add --no-cache  \
    git~="${GIT_VERSION}" \
    bash~=${BASH_VERSION} \
    jq~=${JQ_VERSION} \
    yq~=${YQ_VERSION} \
    curl~=${CURL_VERSION} \
    github-cli~=${GITHUB_CLI_VERSION}; \
    rm -rf /var/cache/apk/*

ENV LOG_LEVEL "INFO"
ENV LOG_TIMESTAMPED "true"
ENV DEBUG_MODE "false"

COPY scripts/utils.sh .
COPY scripts/script.sh .
COPY scripts/gh-utils.sh .
COPY scripts/label-semaphore ./label-semaphore

ENTRYPOINT ["/scripts/script.sh"]
