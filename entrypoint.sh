#!/bin/bash

#set -e

function upsertProperty() {
    local path="$1"
    local name="$2"
    local value="$3"
    local sep="$4"

    if grep -q "^$name$sep" "$path"; then
        sed -i "s|^\($name$sep\).*|\1$value|" "$path"
    else
        echo "$name$sep$value" >> "$path"
    fi
}

function configure() {
    local path="$1"
    local envPrefix="$2"
    local sep="$3"
    
    local var
    local value

    for c in `printenv | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- -envPrefix=$envPrefix`; do
        name=`echo ${c} | perl -pe 's/___/-/g; s/__/_/g; s/_/./g'`
        var="${envPrefix}_${c}"
        value="${!var}"
        upsertProperty "$path" "$name" "$value" "$sep"
    done
}

# Sensitive conf
if [[ ! $STANDALONE ]]; then
    if [[ ! -z $CLUSTER_NAME ]]; then
        export CONF_BROKER_clusterName=$CLUSTER_NAME
    else 
        echo "Missing CLUSTER_NAME parameter"
        exit 1
    fi
    if [[ ! -z $ZOO_SERVERS ]]; then
        export CONF_BOOKKEEPER_zkServers=$ZOO_SERVERS
        export CONF_BROKER_zookeeperServers=$ZOO_SERVERS
    else 
        echo "Missing ZOO_SERVERS parameter"
        exit 1
    fi
    if [[ ! -z $CONFIG_STORE_SERVERS ]]; then
        export CONF_BROKER_configurationStoreServers=$CONFIG_STORE_SERVERS
    else 
        echo "Missing CONFIG_STORE_SERVERS parameter"
        exit 1
    fi

    if [[ -z $METADATA_WEB_SERVICE_URL ]]; then
        export METADATA_WEB_SERVICE_URL="http://$(hostname):8080"
    fi
    if [[ -z $METADATA_WEB_SERVICE_URL_TLS ]]; then
        export METADATA_WEB_SERVICE_URL_TLS="https://$(hostname):8443"
    fi
    if [[ -z $METADATA_BROKER_SERVICE_URL ]]; then
        export METADATA_BROKER_SERVICE_URL="pulsar://$(hostname):6650"
    fi
    if [[ -z $METADATA_BROKER_SERVICE_URL_TLS ]]; then
        export METADATA_BROKER_SERVICE_URL_TLS="pulsar+ssl://$(hostname):6651"
    fi
fi

# Add env to conf
config="$PULSAR_HOME/conf"
configure "$config/zookeeper.conf" "CONF_ZOO" "="
configure "$config/global_zookeeper.conf" "CONF_GLOBAL_ZOO" "="
configure "$config/bookkeeper.conf" "CONF_BOOKKEEPER" "="
configure "$config/broker.conf" "CONF_BROKER" "="
configure "$config/client.conf" "CONF_CLIENT" "="
configure "$config/discovery.conf" "CONF_DISCOVERY" "="
configure "$config/proxy.conf" "CONF_PROXY" "="
configure "$config/websocket.conf" "CONF_WEBSOCKET" "="
configure "$config/standalone.conf" "CONF_STANDALONE" "="

configure "$config/log4j2.yml" "YAML_LOG4J2" ": "
configure "$config/functions_worker.yml" "YAML_FUNCTIONS_WORKER" ": "

# Download connectors
if [[ ! -z $CONNECTORS_URL ]]; then
    mkdir -p $PULSAR_HOME/connectors
    for url in $CONNECTORS_URL; do
        (cd $PULSAR_HOME/connectors && curl -LO $url)
    done
fi

# Start servers
if [[ $STANDALONE ]]; then
    pulsar-daemon start standalone
else
    if [[ $INITIALIZE_METADATA ]]; then   
        pulsar initialize-cluster-metadata \
            --cluster "$CLUSTER_NAME" \
            --zookeeper "$ZOO_SERVERS" \
            --configuration-store "$CONFIG_STORE_SERVERS" \
            --web-service-url "$METADATA_WEB_SERVICE_URL" \
            --web-service-url-tls "$METADATA_WEB_SERVICE_URL_TLS" \
            --broker-service-url "$METADATA_BROKER_SERVICE_URL" \
            --broker-service-url-tls "$METADATA_BROKER_SERVICE_URL_TLS"
    fi
    pulsar-daemon start bookie
    pulsar-daemon start broker
fi

if [[ -z $@ ]]; then
    tail -f /dev/null
else
    url=$(grep "^webServiceUrl" $PULSAR_HOME/conf/client.conf | cut -d '=' -f 2)
    echo "Waiting for healthcheck..."
    until [[ $(curl -I ${url}admin/v2/brokers/healthcheck -s -o /dev/null -w "%{http_code}") -eq 200 ]]; do
        sleep 1
    done

    exec "$@"
fi

exit 1
