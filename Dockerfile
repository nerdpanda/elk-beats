# Dockerfile for ELK stack
# Elasticsearch 2.2.0, Logstash 2.2.1-1, Kibana 4.4.1

# Build with:
# docker build -t <repo-user>/elk .

# Run with:
# docker run -p 5601:5601 -p 9200:9200 -p 5000:5000 -it --name elk <repo-user>/elk

FROM centos:7
MAINTAINER Raj Cherukuri
# Built on the original sebp/elk by Sebastien Pujadas http://pujadas.net and thomascooper/elk-beats Thomas Cooper http://www.rackdeploy.com
ENV REFRESHED_AT 2016-02-18


###############################################################################
#                                INSTALLATION
###############################################################################

### install Elasticsearch

RUN yum update \
 && yum -y install -y curl

RUN rpm --import https://packages.elastic.co/GPG-KEY-elasticsearch
RUN touch /etc/yum.repos.d/elasticsearch.repo
RUN cat `[elasticsearch-2.x]` >> /etc/yum.repos.d/elasticsearch.repo
RUN cat `name=Elasticsearch repository for 2.x packages` >> /etc/yum.repos.d/elasticsearch.repo
RUN cat `baseurl=http://packages.elastic.co/elasticsearch/2.x/centos` >> /etc/yum.repos.d/elasticsearch.repo
RUN cat `gpgcheck=1` >> /etc/yum.repos.d/elasticsearch.repo
RUN cat `gpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch` >> /etc/yum.repos.d/elasticsearch.repo
RUN cat `enabled=1` >> /etc/yum.repos.d/elasticsearch.repo

RUN yum update \
 && yum -y install \
		elasticsearch \
		openjdk-7-jdk \
 && yum clean


### install Logstash

ENV LOGSTASH_HOME /opt/logstash
ENV LOGSTASH_PACKAGE logstash-2.2.tar.gz

RUN mkdir ${LOGSTASH_HOME} \
 && curl -O https://download.elasticsearch.org/logstash/logstash/${LOGSTASH_PACKAGE} \
 && tar xzf ${LOGSTASH_PACKAGE} -C ${LOGSTASH_HOME} --strip-components=1 \
 && rm -f ${LOGSTASH_PACKAGE} \
 && groupadd -r logstash \
 && useradd -r -s /usr/sbin/nologin -d ${LOGSTASH_HOME} -c "Logstash service user" -g logstash logstash \
 && mkdir -p /var/log/logstash /etc/logstash/conf.d \
 && chown -R logstash:logstash ${LOGSTASH_HOME} /var/log/logstash

ADD ./logstash-init /etc/init.d/logstash
RUN sed -i -e 's#^LS_HOME=$#LS_HOME='$LOGSTASH_HOME'#' /etc/init.d/logstash \
 && chmod +x /etc/init.d/logstash


### install Kibana

ENV KIBANA_HOME /opt/kibana
ENV KIBANA_PACKAGE kibana-4.4.1-linux-x64.tar.gz

RUN mkdir ${KIBANA_HOME} \
 && curl -O https://download.elasticsearch.org/kibana/kibana/${KIBANA_PACKAGE} \
 && tar xzf ${KIBANA_PACKAGE} -C ${KIBANA_HOME} --strip-components=1 \
 && rm -f ${KIBANA_PACKAGE} \
 && groupadd -r kibana \
 && useradd -r -s /usr/sbin/nologin -d ${KIBANA_HOME} -c "Kibana service user" -g kibana kibana \
 && mkdir -p /var/log/kibana \
 && chown -R kibana:kibana ${KIBANA_HOME} /var/log/kibana

ADD ./kibana-init /etc/init.d/kibana
RUN sed -i -e 's#^KIBANA_HOME=$#KIBANA_HOME='$KIBANA_HOME'#' /etc/init.d/kibana \
 && chmod +x /etc/init.d/kibana


### install Beats

RUN yum -y install filebeat
RUN chkconfig filebeat defaults 95 10


###############################################################################
#                               CONFIGURATION
###############################################################################

### configure Elasticsearch

ADD ./elasticsearch.yml /etc/elasticsearch/elasticsearch.yml


### configure Logstash

# certs/keys for Beats and Lumberjack input
RUN mkdir -p /etc/pki/tls/certs && mkdir /etc/pki/tls/private
ADD ./logstash-forwarder.crt /etc/pki/tls/certs/logstash-forwarder.crt
ADD ./logstash-forwarder.key /etc/pki/tls/private/logstash-forwarder.key
ADD ./logstash-beats.crt /etc/pki/tls/certs/logstash-beats.crt
ADD ./logstash-beats.key /etc/pki/tls/private/logstash-beats.key

# filters
ADD ./01-lumberjack-input.conf /etc/logstash/conf.d/01-lumberjack-input.conf
ADD ./02-beats-input.conf /etc/logstash/conf.d/02-beats-input.conf
ADD ./10-syslog.conf /etc/logstash/conf.d/10-syslog.conf
ADD ./30-output.conf /etc/logstash/conf.d/30-output.conf

# filebeat
ADD ./filebeat.yml /etc/filebeat/filebeat.yml

# timezone fix
ADD ./timezone_fix /usr/local/bin/timezone_fix
RUN chmod +x /usr/local/bin/timezone_fix

###############################################################################
#                                   START
###############################################################################

ADD ./start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 5601 9200 9300 5000 5044
VOLUME /var/lib/elasticsearch

CMD [ "/usr/local/bin/start.sh" ]
