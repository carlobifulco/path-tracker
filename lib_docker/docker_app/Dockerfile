# This is a comment
# ruby compile options

FROM  ubuntu:latest

MAINTAINER carlobif@gmail.com

RUN apt-get update && apt-get upgrade -y --no-install-recommends
RUN apt-get install -y -qq \
  apt-utils \
  build-essential \
  ca-certificates \
  curl \
  emacs23-nox \
  git \
  libcurl4-openssl-dev \
  libffi-dev \
  libgdbm-dev \
  libpq-dev \
  libreadline6-dev \
  libssl-dev \
  libtool \
  libxml2-dev \
  libxslt-dev \
  libyaml-dev \
  locate \
  screen \
  software-properties-common \
  tree \
  wget \
  zlib1g-dev \
  libreadline-dev



## RUBY
#------------
ENV PATH $PATH:/opt/rubies/ruby-2.1.5/bin

# Install MRI ruby 2.1.2
RUN curl -O http://ftp.ruby-lang.org/pub/ruby/2.1/ruby-2.1.5.tar.gz && \
    tar -zxvf ruby-2.1.5.tar.gz && \
    cd ruby-2.1.5 && \
    ./configure --disable-install-doc && \
    make && \
    make install && \
    cd .. && \
    rm -rf ruby-2.1.5 ruby-2.1.5.tar.gz && \
    echo 'gem: --no-document' > /usr/local/etc/gemrc

# Install rubygems and bundler
RUN curl -O  http://production.cf.rubygems.org/rubygems/rubygems-2.3.0.tgz
RUN tar -zxf rubygems-2.3.0.tgz && \
    cd rubygems-2.3.0 && \
    ruby setup.rb && \
    /bin/bash -l -c 'gem install bundler --no-rdoc --no-ri' && \
    echo "gem: --no-ri --no-rdoc" > ~/.gemrc




### RUBY
RUN echo 'gem: --no-rdoc --no-ri' >> /root/.gemrc

RUN gem install bundler

RUN gem install pry


### ports mongo and mountable directories.
VOLUME ["/data/db"]
# mongo
EXPOSE 27017

# sinatra port
EXPOSE 4567
EXPOSE 9991
EXPOSE 9992
EXPOSE 9993
EXPOSE 9994
EXPOSE 9995
EXPOSE 9996
EXPOSE 9997
EXPOSE 9998
EXPOSE 9999

#mongo

RUN apt-get install -y mongodb-clients



#RUN mkdir /root/sendout-monitor
# install web-app
#WORKDIR /root/sendout-monitor
ADD ./latest.tar /root/path_tracker_docker
WORKDIR /root/path_tracker_docker
RUN ln -s /data/db  /root/path_tracker_docker/mongo_dump
RUN bundle update





# docker run -d -p 9999:9999

RUN ["/bin/bash"]
# "-c /root/supervisor.con"]
