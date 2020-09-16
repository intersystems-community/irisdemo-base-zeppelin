# Multi-build Dockerfile. This image will not be included into our final image. 
# We just need a reference to it. I will use that to extract IRIS jar files from it.
# Think of it as a parallel universe we just entered and it is called now "universe 0".
FROM intersystemsdc/iris-community:2020.3.0.200.0-zpm
#FROM intersystemsdc/irisdemo-base-irishealthint-community:version-1.5

FROM bitnami/spark:2.4.4

# Here is our real image. This is the universe we are going to stay on. 
FROM apache/zeppelin:0.9.0
LABEL maintainer="Amir Samary <amir.samary@intersystems.com>"

USER root

# Now we can extract those jar files from universe 0, and bring them into our universe... ;)
# Let's bring the ODBC driver as well
COPY --from=0 /usr/irissys/dev/java/lib/JDK18/*.jar /custom/lib/
COPY --from=0 /usr/irissys/bin/libirisodbc35.so /usr/lib/
COPY --from=1 /opt/bitnami/spark /opt/bitnami/spark

# JPMML
RUN cd /custom/lib && \
    curl -sLO --retry 3 https://github.com/jpmml/jpmml-sparkml/releases/download/1.5.9/jpmml-sparkml-executable-1.5.9.jar

# Zeppelin will be started on port:
EXPOSE 8080

# Zeppelin configurations:
ENV SPARK_HOME /opt/bitnami/spark
ENV PATH /opt/bitnami/java/bin:/opt/bitnami/spark/bin:/opt/bitnami/spark/sbin:$PATH
ENV ZEPPELIN_NOTEBOOK_DIR /shared/zeppelin/notebook
#ENV ZEPPELIN_CONF_DIR /shared/zeppelin/conf
ENV ZEPPELIN_LOG_DIR /shared/zeppelin/logs

# These configuration files have variables that need to be replaced before zeppelin or spark
# start. This substituion is done by /custom/bin/startservices.sh custom script that I
# built. 

# I added a new interpreter to the file, called irisjdbc. This interpreter allows us to 
# easily run SQL through JDBC on IRIS out of the box. It needs:
# - IRIS_MASTER_HOST        : This will set a default configuration for where the IRIS server is so that 
#                             our jdbc driver can connect to it. 
# - IRIS_MASTER_PORT        : The same as above for the iris port. This should be the super server port.
# - IRIS_MASTER_USERNAME    : The same as above for the iris username.
# - IRIS_MASTER_PASSWORD    : The same as above for the iris password.
# - IRIS_MASTER_NAMESPACE   : The same as above for the iris namespace.
#ADD ./image_build_files/zeppelin/conf/interpreter.json /zeppelin/conf/

# This file has nothing to be replaced. It only has only configured zeppelin.server.port=9090.
# This port used to be 8080 and this would collide with the Spark Master Portal port.
#ADD ./image_build_files/zeppelin/conf/zeppelin-site.xml /zeppelin/conf/

# HADOOP
#ENV HADOOP_VERSION 2.7.7
#ENV HADOOP_HOME /usr/hadoop-$HADOOP_VERSION
#ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
#ENV PATH $PATH:$HADOOP_HOME/bin
#RUN curl -sL --retry 3 \
#  "http://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" \
#  | gunzip \
#  | tar -x -C /usr/ \
# && rm -rf $HADOOP_HOME/share/doc \
# && chown -R root:root $HADOOP_HOME

# SPARK Version 2.1.1
# This is the same version that the zeppelin image uses and that InterSystems currently supports
#ENV SPARK_VERSION 2.1.1
#ENV SPARK_PACKAGE spark-${SPARK_VERSION}-bin-without-hadoop
#ENV SPARK_HOME /usr/spark-${SPARK_VERSION}
#ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"
#ENV PATH $PATH:${SPARK_HOME}/bin
#ENV SPARK_OPTS --driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info
#RUN curl -sL --retry 3 \
#  "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz" \
#  | gunzip \
#  | tar x -C /usr/ \
# && mv /usr/$SPARK_PACKAGE $SPARK_HOME \
# && chown -R root:root $SPARK_HOME

# SPARK Version 2.4.4
# This is the same version that the zeppelin image uses and that InterSystems currently supports
#ENV HADOOP_VERSION 2.7
#ENV SPARK_VERSION 2.4.4
#ENV SPARK_PACKAGE spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}
#ENV SPARK_PACKAGE spark-${SPARK_VERSION}-bin-without-hadoop
#ENV SPARK_HOME /usr/spark-${SPARK_VERSION}
#ENV PATH $PATH:${SPARK_HOME}/bin
ENV SPARK_OPTS --driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info
#RUN echo "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz" && \
#  curl -sL --retry 3 \
#  "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz" \
#  | tar -xz -C /usr/ \
# && mv /usr/$SPARK_PACKAGE $SPARK_HOME \
# && chown -R root:root $SPARK_HOME \
# && chown -R root:root /custom/lib/ \
# && chmod +x $SPARK_HOME/bin/load-spark-env.sh

RUN /bin/bash -c "conda install -y conda=4.8.3 && \
    conda install -y pyodbc scikit-learn pandas && \
    pip install tensorflow==2.3.0"

ADD ./image_build_files/sbin/startservices.sh /custom/sbin/
RUN chmod +x /custom/sbin/startservices.sh && \
    chmod +x /custom/lib/*
   
WORKDIR ${Z_HOME}

#ENTRYPOINT [ "/usr/bin/tini", "-s", "--", "/zeppelin/bin/zeppelin.sh" ]
ENTRYPOINT [ "/usr/bin/tini", "-s", "--", "/custom/sbin/startservices.sh" ]
