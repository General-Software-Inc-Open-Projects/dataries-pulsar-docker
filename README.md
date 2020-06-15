# Description

This image was created with the intention of adding extra configuration options to the deployment of Apache Pulsar component on Docker. We are not associated with Apache or Pulsar in anyway. You can find the official image [here](https://hub.docker.com/r/apachepulsar/pulsar).

# Quick reference

- Maintained by: [General Software Inc Open Projects](https://github.com/General-Software-Inc-Open-Projects/pulsar-docker)
- Where to file issues: [GitHub Issues](https://github.com/General-Software-Inc-Open-Projects/pulsar-docker/issues)

# What is Apache Pulsar?

[Apache Pulsar](https://pulsar.apache.org/)  is a highly scalable, low latency messaging platform running on commodity hardware. It provides simple pub-sub semantics over topics, guaranteed at-least-once delivery of messages, automatic cursor management for subscribers, and cross-datacenter replication.

# How to use this image

## Start a single node Pulsar server

~~~bash
docker run -itd --name pulsar -e "STANDALONE=true" -p 8080:8080 -p 6650:6650 -p 8443:8443 -p 6651:6651 --restart on-failure gsiopen/pulsar:2.5.2
~~~

## Persist data

> This image is runned using a non root user `pulsar` who owns the `/opt/pulsar` folder.

By default, pulsar's data is stored in `/opt/pulsar/data`. You can bind a local volume as follows:

~~~bash
docker run -itd --name pulsar -v /path/to/store/data:/opt/pulsar/data -e "STANDALONE=true" -p 8080:8080 -p 6650:6650 -p 8443:8443 -p 6651:6651 --restart on-failure gsiopen/pulsar:2.5.2
~~~
 
## Connect to Pulsar from the command line client

All `CLI` scripts are contained in `PATH`, so you can invoke them using their respective commands and arguments as follows: 

~~~bash
docker exec -it pulsar pulsar-admin brokers healthcheck
~~~

## Logging

You can find out if something went wrong while initializing the container using the next command:

~~~bash
docker logs pulsar
~~~

The rest can be found in the `logs` folder with format `pulsar-[service]-[hostname].log` 

# Deploy a cluster

Although Pulsar can start an internal zookeeper server when launched `standalone`, the recommendend deployment for Pulsar cluster is to use an external zookeeper cluster. Therefore, the environment variables below are mandatory to indicate where the zookeeper servers are.

### `ZOO_SERVERS`

> A comma separated list of `hostname:port` where the zookeper servers that will coordinate the Pulsar cluster are.

### `CONFIG_STORE_SERVERS`

> A comma separated list of `hostname:port` where the zookeper servers that will coordinate the whole Pulsar instance are. If you intend to deploy a single cluster you can use the same value of `ZOO_SERVERS`.

The next variable will be important as well since it coordinates you cluster when launched along other clusters.  

### `CLUSTER_NAME`

> How you want to name you Pulsar cluster.

Before runnig Pusar services, you must intialize some cluster metada in the external zookeeper server. So, one of your cluster's nodes must also set this variables. 

### `INITIALIZE_METADATA`

> Marks this container as the responsable of initializing you clusters metadata in the zookeeper servers.

### `METADATA_WEB_SERVICE_URL`

> Web `URL` of your cluster, by default we will use the container's `hostname` and the default port `8080`.

### `METADATA_WEB_SERVICE_URL_TLS`

> Web `URL` with TLS of your cluster, by default we will use the container's `hostname` and the default port `8443`.

### `METADATA_BROKER_SERVICE_URL`

> Broker `URL` of your cluster, by default we will use the container's `hostname` and the default port `6650`.

### `METADATA_BROKER_SERVICE_URL_TLS`

> Broker `URL` with TLS of your cluster, by default we will use the container's `hostname` and the default port `6651`.

Example using `docker-compose`:

~~~yaml
version: "3.7"

networks:
  private-net:
    name: private-net
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.1.0/24

services:
  zoo-1:
    image: gsiopen/zookeeper:3.6.1
    container_name: zoo-1
    hostname: zoo-1
    environment:
      - ZOO_MY_ID=1
      - ZOO_SERVERS=server.1=0.0.0.0:2888:3888;2181 server.2=zoo-2:2888:3888;2181 server.3=zoo-3:2888:3888;2181
    restart: on-failure
    networks:
      private-net:
        ipv4_address: 192.168.1.2

  zoo-2:
    image: gsiopen/zookeeper:3.6.1
    container_name: zoo-2
    hostname: zoo-2
    environment:
      - ZOO_MY_ID=2
      - ZOO_SERVERS=server.1=zoo-1:2888:3888;2181 server.2=0.0.0.0:2888:3888;2181 server.3=zoo-3:2888:3888;2181
    restart: on-failure
    networks:
      private-net:
        ipv4_address: 192.168.1.3

  zoo-3:
    image: gsiopen/zookeeper:3.6.1
    container_name: zoo-3
    hostname: zoo-3
    environment:
      - ZOO_MY_ID=3
      - ZOO_SERVERS=server.1=zoo-1:2888:3888;2181 server.2=zoo-2:2888:3888;2181 server.3=0.0.0.0:2888:3888;2181
    restart: on-failure
    networks:
      private-net:
        ipv4_address: 192.168.1.4

  pulsar-1:
    image: gsiopen/pulsar:2.5.2
    container_name: pulsar-1
    hostname: pulsar-1
    environment:
      - CLUSTER_NAME=pulsar
      - ZOO_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
      - CONFIG_STORE_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
      - INITIALIZE_METADATA=true
    depends_on:
      - zoo-1
      - zoo-2
      - zoo-3
    restart: on-failure
    networks:
      private-net:
        ipv4_address: 192.168.1.5

  pulsar-2:
    image: gsiopen/pulsar:2.5.2
    container_name: pulsar-2
    hostname: pulsar-2
    environment:
      - CLUSTER_NAME=pulsar
      - ZOO_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
      - CONFIG_STORE_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
    depends_on:
      - pulsar-1
    restart: on-failure
    networks:
      private-net:
        ipv4_address: 192.168.1.6

  pulsar-3:
    image: gsiopen/pulsar:2.5.2
    container_name: pulsar-3
    hostname: pulsar-3
    environment:
      - CLUSTER_NAME=pulsar
      - ZOO_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
      - CONFIG_STORE_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
    depends_on:
      - pulsar-1
    restart: on-failure
    networks:
      private-net:
        ipv4_address: 192.168.1.7
~~~

# Configuration

## Volumes

Pulsar uses default configuration files in the `/opt/pulsar/conf` folder. You can bind an external folder with your configuration files as follows:

~~~bash
docker run -itd --name pulsar -v /path/to/store/conf:/opt/pulsar/conf -e "STANDALONE=true" -p 8080:8080 -p 6650:6650 -p 8443:8443 -p 6651:6651 --restart on-failure gsiopen/pulsar:2.5.2
~~~

## Environment variables

The environment configuration is controlled via the following environment variable groups or PREFIX:

    CONF_ZOO: affects zookeeper.conf
    CONF_GLOBAL_ZOO: affects global_zookeeper.conf
    CONF_BOOKKEEPER: affects bookkeeper.conf
    CONF_BROKER: affects broker.conf
    CONF_CLIENT: affects client.conf
    CONF_DISCOVERY: affects discovery.conf
    CONF_PROXY: affects proxy.conf
    CONF_WEBSOCKET: affects websocket.conf
    CONF_STANDALONE: affects standalone.conf
    
    YAML_LOG4J2: affects log4j2.yml
    YAML_FUNCTIONS_WORKER: affects functions_worker.yml

Set environment variables with the appropriated group in the form PREFIX_PROPERTY.

Due to restriction imposed by docker and docker-compose on environment variable names the following substitution are applied to PROPERTY names:

    _ => .
    __ => _
    ___ => -

Following are some illustratory examples:

    CONF_BROKER_functionsWorkerEnabled=true: sets the functionsWorkerEnabled property in broker.conf
    YAML_FUNCTIONS_WORKER_pulsarFunctionsCluster=pulsar: sets the pulsarFunctionsCluster property in functions_worker.yml

# Connectors

To use Pulsar's connectors you must first configure the next parameters on all the nodes you want to participate as function workers.

    CONF_BROKER_functionsWorkerEnabled=true
    YAML_FUNCTIONS_WORKER_pulsarFunctionsCluster=`cluster's name`

Each function worker assigned by Pulsar to run a specific connector will search the connector's file under the `connectors` folder. You can either bind a local volume with the connectors you want or set the next environment variable:

### `CONNECTORS_URL`

> A space separated list of `URL`s pointing to the connectors files you want to download into the `connectors` folder. 

You will also need a configuration `YAML`, with options and parameters as requiered by each connector, inside the container that will launch the connector. So, bind a local volume with the `YAML` file inside the `/home/pulsar/` folder.

Let's see a full example of how a `docker-compose.yml` would look like if you want to run the [Cassandra example](https://pulsar.apache.org/docs/en/io-quickstart/#connect-pulsar-to-cassandra):

~~~yaml
  # (Previous configuration remains untouched)

  pulsar-1:
    image: gsiopen/pulsar:2.5.2
    container_name: pulsar-1
    hostname: pulsar-1
    environment:
      - CLUSTER_NAME=pulsar
      - ZOO_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
      - CONFIG_STORE_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
      - INITIALIZE_METADATA=true
      - CONF_BROKER_functionsWorkerEnabled=true
      - YAML_FUNCTIONS_WORKER_pulsarFunctionsCluster=pulsar
      - CONNECTORS_URL=https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=pulsar/pulsar-2.5.2/connectors/pulsar-io-cassandra-2.5.2.nar
    command: "/bin/bash -c 'pulsar-admin sinks create --tenant public --namespace default --name cassandra-test-sink --sink-type cassandra --sink-config-file /home/pulsar/cassandra-sink.yml --inputs test_cassandra && tail -f /dev/null'"
    volumes:
      - /path/to/cassandra-sink.yml:/home/pulsar/cassandra-sink.yml
    depends_on:
      - zoo-1
      - zoo-2
      - zoo-3
    restart: on-failure
    networks:
      private-net:
        ipv4_address: 192.168.1.5

  pulsar-2:
    image: gsiopen/pulsar:2.5.2
    container_name: pulsar-2
    hostname: pulsar-2
    environment:
      - CLUSTER_NAME=pulsar
      - ZOO_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
      - CONFIG_STORE_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
      - CONF_BROKER_functionsWorkerEnabled=true
      - YAML_FUNCTIONS_WORKER_pulsarFunctionsCluster=pulsar
      - CONNECTORS_URL=https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=pulsar/pulsar-2.5.2/connectors/pulsar-io-cassandra-2.5.2.nar
    depends_on:
      - pulsar-1
    restart: on-failure
    networks:
      private-net:
        ipv4_address: 192.168.1.6

  pulsar-3:
    image: gsiopen/pulsar:2.5.2
    container_name: pulsar-3
    hostname: pulsar-3
    environment:
      - CLUSTER_NAME=pulsar
      - ZOO_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
      - CONFIG_STORE_SERVERS=zoo-1:2181,zoo-2:2181,zoo-3:2181
      - CONF_BROKER_functionsWorkerEnabled=true
      - YAML_FUNCTIONS_WORKER_pulsarFunctionsCluster=pulsar
      - CONNECTORS_URL=https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=pulsar/pulsar-2.5.2/connectors/pulsar-io-cassandra-2.5.2.nar
    depends_on:
      - pulsar-1
    restart: on-failure
    networks:
      private-net:
        ipv4_address: 192.168.1.7
~~~

> Notice the use of `command` to submit the sink connector as soon as the broker is ready, add `tail -f /dev/null` to maintain the container runnig. 

# License

View [license information](https://github.com/apache/pulsar/blob/master/LICENSE) for the software contained in this image.

As with all Docker images, these likely also contain other software which may be under other licenses (such as Bash, etc from the base distribution, along with any direct or indirect dependencies of the primary software being contained).

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.
