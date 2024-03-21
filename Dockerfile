ARG ALPINE_VERSION="3.19"

ARG BASH_VERSION="5.2.26-r0"

FROM alpine:${ALPINE_VERSION}

WORKDIR /scripts

RUN apk update --no-cache; \
    apk upgrade --no-cache; \
    apk add --no-cache bash=${BASH_VERSION}; \
    rm -rf /var/cache/apk/*

ENV LOG_LEVEL "INFO"
ENV LOG_TIMESTAMPED "true"
ENV DEBUG_MODE "false"

COPY scripts/utils.sh .
COPY scripts/script.sh .

ENTRYPOINT ["/scripts/script.sh"]
