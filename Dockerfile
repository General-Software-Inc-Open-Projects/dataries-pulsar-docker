FROM openjdk:8-jre-slim
LABEL version="2.5.2"
LABEL maintainer="Gilberto Muñoz <gilberto@generalsoftwareinc.com>"


ENV PULSAR_VERION="2.5.2" \
    PULSAR_HOME="/opt/pulsar"

ARG PULSAR_URL=https://archive.apache.org/dist/pulsar/pulsar-${PULSAR_VERION}/apache-pulsar-${PULSAR_VERION}-bin.tar.gz

RUN set -eux; \
        useradd -lU pulsar

RUN  set -eux; \
        apt-get update; \
        apt-get install --yes --no-install-recommends \ 
            curl; \
        apt-get autoremove --yes; \
        apt-get clean

RUN set -eux; \
        curl ${PULSAR_URL} | tar -xz -C /opt; \
        mv /opt/apache-pulsar-${PULSAR_VERION} ${PULSAR_HOME}; \
        chown -R pulsar:pulsar ${PULSAR_HOME}

ENV PATH="${PATH}:${PULSAR_HOME}/bin"

USER pulsar

WORKDIR ${PULSAR_HOME}

COPY --chown=pulsar:pulsar healthcheck.sh entrypoint.sh /usr/bin/

ENTRYPOINT ["entrypoint.sh"]

HEALTHCHECK --interval=30s --timeout=15s --start-period=60s \
    CMD ["healthcheck.sh"]
