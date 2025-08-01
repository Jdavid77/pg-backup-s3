FROM alpine:3.22.1
LABEL maintainer="Jdavid77 <johnynobrega17@gmail.com>"

ARG UID=1001
ARG GID=1001
ARG USER=nonroot

RUN apk --no-cache add \
        curl \
        ca-certificates \
        openssl \
        postgresql17-client \
        bash \
        aws-cli \
        coreutils

RUN addgroup -g $GID -S ${USER} && \
    adduser -u $UID -S ${USER} -G ${USER}


ENV POSTGRES_HOST **None**
ENV POSTGRES_PORT 5432
ENV POSTGRES_USER **None**
ENV POSTGRES_PASSWORD **None**
ENV POSTGRES_EXTRA_OPTS ''
ENV S3_ACCESS_KEY_ID **None**
ENV S3_SECRET_ACCESS_KEY **None**
ENV S3_BUCKET **None**
ENV S3_REGION us-west-1
ENV S3_PREFIX 'backup'
ENV S3_ENDPOINT **None**
ENV S3_S3V4 no
ENV SCHEDULE **None**
ENV ENCRYPTION_PASSWORD **None**
ENV REMOVE_BEFORE ''

COPY --chown=${UID}:${GID} run.sh /scripts/run.sh
COPY --chown=${UID}:${GID} backup.sh /scripts/backup.sh
RUN chmod 700 /scripts/run.sh /scripts/backup.sh

USER ${USER}

ENTRYPOINT []
CMD ["sh", "/scripts/run.sh"]
