# This is a comment
# ruby compile options

FROM  mongo:latest

MAINTAINER carlobif@gmail.com

VOLUME ["/data/db"]

ADD ./mongod.conf /etc/mongod.conf

EXPOSE 27017
EXPOSE 28017

RUN touch /var/log/mongod.log
RUN chown mongodb  /var/log/mongod.log

USER root

CMD ["/usr/bin/mongod --smallfiles --config /etc/mongod.conf"]
