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
ENV ZEPPELIN_CONF_DIR /shared/zeppelin/conf
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
ADD ./image_build_files/zeppelin/interpreter/interpreters.zip /zeppelin/interpreter/

# This file has nothing to be replaced. It only has only configured zeppelin.server.port=9090.
# This port used to be 8080 and this would collide with the Spark Master Portal port.
ADD ./image_build_files/zeppelin/conf/interpreter.json /shared/zeppelin/conf/

#RUN /bin/bash -c "conda install -y conda=4.8.3 && \
#    conda install -y pyodbc scikit-learn pandas && \
#    pip install tensorflow==2.3.0"

ADD ./image_build_files/sbin/startservices.sh /custom/sbin/
RUN chmod +x /custom/sbin/startservices.sh && \
    chmod +x /custom/lib/*
   
WORKDIR ${Z_HOME}

#ENTRYPOINT [ "/usr/bin/tini", "-s", "--", "/zeppelin/bin/zeppelin.sh" ]
ENTRYPOINT [ "/usr/bin/tini", "-s", "--", "/custom/sbin/startservices.sh" ]
