# Multi-build Dockerfile. This image will not be included into our final image. 
# We just need a reference to it. I will use that to extract IRIS jar files from it.
# Think of it as a parallel universe we just entered and it is called now "universe 0".
FROM intersystemsdc/irisdemo-base-irisdb-community:iris-community.2019.3.0.309.0

# Here is our real image. This is the universe we are going to stay on. 
FROM apache/zeppelin:0.7.3
LABEL maintainer="Amir Samary <amir.samary@intersystems.com>"

# Now we can extract those jar files from universe 0, and bring them into our universe... ;)
# Let's bring the ODBC driver as well
COPY --from=0 /usr/irissys/dev/java/lib/JDK18/*.jar /custom/lib/
COPY --from=0 /usr/irissys/bin/libirisodbc35.so /usr/lib/

# JPMML
RUN cd /custom/lib && \
    curl -sLO --retry 3 https://github.com/jpmml/jpmml-sparkml/releases/download/1.2.12/jpmml-sparkml-executable-1.2.12.jar

# Zeppelin will be started on port:
EXPOSE 9090

# Zeppelin configurations:
ENV ZEPPELIN_NOTEBOOK_DIR /shared/zeppelin/notebook
ENV ZEPPELIN_CONF_DIR /shared/zeppelin/conf
ENV ZEPPELIN_LOG_DIR /shared/zeppelin/logs

RUN pip install --upgrade pip && \
    pip install pandas && \
    pip install seaborn && \
    pip install sklearn

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
ADD ./image_build_files/zeppelin/conf/interpreter.json /zeppelin/conf/

# This file has nothing to be replaced. It only has only configured zeppelin.server.port=9090.
# This port used to be 8080 and this would collide with the Spark Master Portal port.
ADD ./image_build_files/zeppelin/conf/zeppelin-site.xml /zeppelin/conf/

# HADOOP
ENV HADOOP_VERSION 2.7.7
ENV HADOOP_HOME /usr/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH $PATH:$HADOOP_HOME/bin
RUN curl -sL --retry 3 \
  "http://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" \
  | gunzip \
  | tar -x -C /usr/ \
 && rm -rf $HADOOP_HOME/share/doc \
 && chown -R root:root $HADOOP_HOME

# SPARK 2.1.3
# ENV SPARK_VERSION 2.1.3
# ENV SPARK_PACKAGE spark-${SPARK_VERSION}-bin-without-hadoop
# ENV SPARK_HOME /usr/spark-${SPARK_VERSION}
# ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"
# ENV PATH $PATH:${SPARK_HOME}/bin
# ENV SPARK_OPTS --driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info
# COPY --from=0 $SPARK_HOME/ $SPARK_HOME/
# RUN chown -R root:root $SPARK_HOME

# SPARK Version 2.1.1
# This is the same version that the zeppelin image uses and that InterSystems currently supports
ENV SPARK_VERSION 2.1.1
ENV SPARK_PACKAGE spark-${SPARK_VERSION}-bin-without-hadoop
ENV SPARK_HOME /usr/spark-${SPARK_VERSION}
ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"
ENV PATH $PATH:${SPARK_HOME}/bin
ENV SPARK_OPTS --driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info
RUN curl -sL --retry 3 \
  "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz" \
  | gunzip \
  | tar x -C /usr/ \
 && mv /usr/$SPARK_PACKAGE $SPARK_HOME \
 && chown -R root:root $SPARK_HOME

# R version 3.4.4 (2018-03-15) -- "Someone to Lean On"
# This is already being done by the Zeppelin image. But 0.8.0 is broken and 0.7.3
# brings an older version of R. So I am running this again to get R version 3.4.4 that
# is the same that the Spark Images are using.
RUN echo "$LOG_TAG Install R related packages" && \
    echo "deb http://cloud.r-project.org/bin/linux/ubuntu xenial/" | tee -a /etc/apt/sources.list && \
    echo "deb http://archive.ubuntu.com/ubuntu xenial-backports main restricted universe" | tee -a /etc/apt/sources.list && \
    echo "deb-src http://security.ubuntu.com/ubuntu trusty-security restricted main universe multiverse" | tee -a /etc/apt/sources.list && \
    gpg --keyserver keyserver.ubuntu.com --recv-key 51716619E084DAB9 && \
    gpg -a --export 51716619E084DAB9 | apt-key add - && \
    apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install software-properties-common && \
    apt-get -y build-dep libcurl4-gnutls-dev && \
    apt-get -y build-dep libxml2-dev && \
    apt-get -y install libcurl4-gnutls-dev libssl-dev libxml2-dev && \
    apt-get -y install libxml2 r-cran-xml r-base-core r-recommended r-cran-kernsmooth r-cran-nnet r-base r-base-dev && \
    R -e "install.packages('knitr', repos='http://cloud.r-project.org')" && \
    R -e "install.packages('ggplot2', repos='http://cloud.r-project.org')" && \
    R -e "install.packages('googleVis', repos='http://cloud.r-project.org')" && \
    R -e "install.packages('data.table', repos='http://cloud.r-project.org')" && \
    # for devtools, Rcpp
    apt-get -y install libssl-dev && \
    Rscript -e 'install.packages("devtools", repos="https://cloud.r-project.org")' && \
    R -e "install.packages('Rcpp', repos='http://cloud.r-project.org')" && \
    Rscript -e "library('devtools'); library('Rcpp'); install_github('ramnathv/rCharts')"
    
RUN /bin/bash -c "conda install -y conda=4.3.30 && \
    conda create -y -n py3 python=3.7 && \
    source activate py3 && \
    conda install -y pyodbc numpy pandas scikit-learn && \
    pip install tensorflow==2.0.0-beta1"

ADD ./image_build_files/sbin/startservices.sh /custom/sbin/
RUN chmod +x /custom/sbin/startservices.sh
   
WORKDIR ${Z_HOME}

ENTRYPOINT [ "/usr/bin/tini", "-s", "--", "/custom/sbin/startservices.sh" ]
