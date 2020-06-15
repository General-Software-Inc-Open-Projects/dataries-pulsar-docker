# Description

This image was created with the intention of adding extra configuration options to the deployment of Apache Zookeeper component on Docker. We are not associated with Apache or Zookeeper in anyway. You can find the official docker image [here](https://hub.docker.com/r/_/zookeeper).

# Quick reference

- Maintained by: [General Software Inc Open Projects](https://github.com/General-Software-Inc-Open-Projects/dataries-zookeeper-docker)
- Where to file issues: [GitHub Issues](https://github.com/General-Software-Inc-Open-Projects/dataries-zookeeper-docker/issues)

# What is Apache Zookeeper?

[Apache ZooKeeper](https://zookeeper.apache.org/) is a software project of the Apache Software Foundation, providing an open source distributed configuration service, synchronization service, and naming registry for large distributed systems. ZooKeeper was a sub-project of Hadoop but is now a top-level project in its own right.

# How to use this image

## Start a single node Zookeeper server

~~~bash
docker run -itd --name zookeeper -p 2181:2181 -p 2888:2888 -p 3888:3888 -p 8080:8080 --restart on-failure gsiopen/zookeeper:3.6.1
~~~

## Persist data

> This image is runned using a non root user `zookeeper` who owns the `/opt/zookeeper` folder.

By default, zookeeper's data and datalog are stored in `/opt/zookeeper/data` and `/opt/zookeeper/datalog`. You can bind local volumes to each as follows:

~~~bash
docker run -itd --name zookeeper -v /path/to/store/data:/opt/zookeeper/data -v /path/to/store/datalog:/opt/zookeeper/datalog -p 2181:2181 -p 2888:2888 -p 3888:3888 -p 8080:8080 --restart on-failure gsiopen/zookeeper:3.6.1
~~~
 
## Connect to Zookeeper from the command line client

~~~bash
docker exec -it zookeeper zkCli.sh
~~~

## Logging

By default, ZooKeeper redirects stdout/stderr outputs to the console so you can run the next command to find logs:

~~~bash
docker logs zookeeper
~~~

However you can redirect logs to files in `/opt/zookeeper/logs` by passing the environment variable ZOO_LOG4J_PROP as follows:

~~~bash
docker run -itd --name zookeeper -e ZOO_LOG4J_PROP="INFO,ROLLINGFILE" -p 2181:2181 -p 2888:2888 -p 3888:3888 -p 8080:8080 --restart on-failure gsiopen/zookeeper:3.6.1
~~~

Check [ZooKeeper Logging](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_logging) for more details.

# Deploy a cluster

Environment variables below are mandatory if you want to run Zookeeper in replicated mode.

### `ZOO_MY_ID`

The id must be unique within the ensemble and should have a value between 1 and 255.

### `ZOO_SERVERS`

This variable allows you to specify a list of machines of the Zookeeper ensemble. Each entry has the form of `server.id=<address1>:<port1>:<port2>[:role];[<client port address>:]<client port>` and are separated by spaces.

Check [Zookeeper Dynamic Reconfiguration](https://zookeeper.apache.org/doc/current/zookeeperReconfig.html) for more details.

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
~~~

# Configuration

## Volumes

Zookeeper uses default configuration files in the `/opt/zookeeper/conf` folder. You can bind an external folder with your configuration files as follows:

~~~bash
docker run -itd --name zookeeper -v /path/to/conf:/opt/zookeeper/conf -p 2181:2181 -p 2888:2888 -p 3888:3888 -p 8080:8080 --restart on-failure gsiopen/zookeeper:3.6.1
~~~

## Environment variables

The environment configuration is controlled via the following environment variable groups or PREFIX:

    CONF_ZOO: affects zoo.cfg
    CONF_LOG4J: affects log4j.properties
    
Set environment variables with the appropriated group in the form PREFIX_PROPERTY.

Due to restriction imposed by docker and docker-compose on environment variable names the following substitution are applied to PROPERTY names:

    _ => .
    __ => _
    ___ => -

Following are some illustratory examples:

    CONF_ZOO_dataLogDir=/opt/zookeeper/datalog: sets the dataLogDir property in zoo.cfg
    CONF_ZOO_admin_enableServer=true: sets the admin.enableServer property in zoo.cfg
    
## Java

Another option would be using `JVMFLAGS` environment variable. Many of the Zookeeper advanced configuration options can be set there using Java system properties in the form of `-Dproperty=value`. For example, you can use Netty instead of NIO (default option) as a server communication framework:

~~~bash
docker run -itd --name zookeeper -e JVMFLAGS="-Dzookeeper.serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory" -p 2181:2181 -p 2888:2888 -p 3888:3888 -p 8080:8080 --restart on-failure gsiopen/zookeeper:3.6.1
~~~

See [Advanced Configuration](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_advancedConfiguration) for the full list of supported Java system properties.

Another example use case for the JVMFLAGS is setting a maximum JVM heap size of 1 GB:

~~~bash
docker run -itd --name zookeeper -e JVMFLAGS="-Xmx1024m" -p 2181:2181 -p 2888:2888 -p 3888:3888 -p 8080:8080 --restart on-failure gsiopen/zookeeper:3.6.1
~~~

# License

View [license information](https://github.com/apache/zookeeper/blob/master/LICENSE.txt) for the software contained in this image.

As with all Docker images, these likely also contain other software which may be under other licenses (such as Bash, etc from the base distribution, along with any direct or indirect dependencies of the primary software being contained).

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.
