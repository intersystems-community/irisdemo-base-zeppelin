This Zeppelin image brings everything we need to:
- Connect directly to IRIS using JDBC
- Connect to IRIS using a Spark Cluster

This image is meant to be used on a docker-compose with IRIS and a Spark cluster. 

It has IRIS JDBC driver and Spark Connector. It also is configured to connect to a spark master on a host called *sparkmaster*. 

You can see an example of a docker-compose.yml file that you can copy and paste on any folder on your PC and just run it with:

```bash
docker-compose up
```

Here is the Dockerfile:

```Dockerfile
version: '2.4'

services:

  myIRISDB:
    build:
      context: ./myIRISDB
    image: store/intersystems/iris-community:2019.3.0.309.0
    hostname: myIRISDB
    init: true
    ports:
    - "51773:51773" # 51773 is the superserver default port
    - "52773:52773" # 52773 is the webserver/management portal port

  zeppelin:
    depends_on: 
      myIRISDB:
        condition: service_healthy
    image: intersystemsdc/irisdemo-base-zeppelin:latest
    init: true
    ports:
    - "9090:9090"     # Zeppelin
    - "4040:4040"     # Zeppelin Spark UI
    volumes:
    - type: bind
      source: ./zeppelin_config/
      target: /shared
    - type: bind
      source: ./common_shared/      # - common_shared:/common_shared   # Shared between all spark nodes. Good place to place a file we are working with.
      target: /common_shared

    environment:
    - IRIS_MASTER_HOST=RRLACESrv # DNS based on the name of the service!
    - IRIS_MASTER_PORT=51773 
    - IRIS_MASTER_USERNAME=SuperUser 
    - IRIS_MASTER_PASSWORD=sys          # Make sure to change your password on myIRISDB to "sys"
    - IRIS_MASTER_NAMESPACE=USER

  sparkmaster:
    image: intersystemsdc/irisdemo-base-spark-iris:latest
    hostname: sparkmaster # Must be always sparkmaster so that the zeppelin image can find it
    init: true
    environment:
      SPARK_NODE_TYPE: Master
      SPARK_PUBLIC_DNS: localhost
      IRIS_MASTER_HOST: myIRISDB
      IRIS_MASTER_PORT: 51773
      IRIS_MASTER_USERNAME: SuperUser
      IRIS_MASTER_PASSWORD: sys         # Make sure to change your password on myIRISDB to "sys"
      IRIS_MASTER_NAMESPACE: USER
    ports:
      - 4040:4040
      - 6066:6066
      - 7077:7077
      - 8080:8080   # Spark Master Portal
    volumes:
    - type: bind
      source: ./common_shared/      # - common_shared:/common_shared   # Shared between all spark nodes. Good place to place a file we are working with.
      target: /common_shared

  worker1:
    depends_on: 
      - sparkmaster
    image: intersystemsdc/irisdemo-base-spark-iris:latest
    hostname: worker1
    init: true
    environment:
      IRIS_MASTER_HOST: myIRISDB
      IRIS_MASTER_PORT: 51773
      IRIS_MASTER_USERNAME: SuperUser
      IRIS_MASTER_PASSWORD: sys
      IRIS_MASTER_NAMESPACE: USER

      SPARK_NODE_TYPE: Worker
      SPARK_WORKER_CORES: 1
      SPARK_WORKER_MEMORY: 1g   # You can give more memory to your work if you are getting errors when using Spark
      SPARK_WORKER_PORT: 8881
      SPARK_WORKER_WEBUI_PORT: 8081
      SPARK_PUBLIC_DNS: localhost
    ports:
      - 8081:8081   # Spark Worker Portal
    volumes: 
    - type: bind
      source: ./common_shared/  # - common_shared:/common_shared   # Shared between all spark nodes. Good place to place a file we are working with. 
      target: /common_shared

  worker2:
    depends_on: 
      - sparkmaster
    image: intersystemsdc/irisdemo-base-spark-iris:latest
    hostname: worker2
    init: true
    environment:
      IRIS_MASTER_HOST: myIRISDB
      IRIS_MASTER_PORT: 51773
      IRIS_MASTER_USERNAME: SuperUser
      IRIS_MASTER_PASSWORD: sys
      IRIS_MASTER_NAMESPACE: USER

      SPARK_NODE_TYPE: Worker
      SPARK_WORKER_CORES: 1
      SPARK_WORKER_MEMORY: 1g   # You can give more memory to your work if you are getting errors when using Spark
      SPARK_WORKER_PORT: 8882
      SPARK_WORKER_WEBUI_PORT: 8082
      SPARK_PUBLIC_DNS: localhost
    ports:
      - 8082:8082   # Spark Worker Portal
    volumes:
    - type: bind
      source: ./common_shared/      # - common_shared:/common_shared   # Shared between all spark nodes. Good place to place a file we are working with.
      target: /common_shared
```

After you start this composition, you will find IRIS, Zeppelin and the Spark portals on the following URLs:
* IRIS:
* Zeppelin:
* Spark Cluster
    - 
    - 