FROM docker.io/ruby:3
RUN gem install typhoeus

RUN /bin/sh -c 'set -ex; \
    [ "$(arch)" == "x86_64" ] && a=amd64 || a=arm64; \
     curl -L "https://get.helm.sh/helm-v3.17.0-linux-${a}.tar.gz" | tar -zx'
RUN install --mode=755 linux-*/helm /usr/local/bin/helm
RUN rm -r linux-*/

COPY --chmod=755 operator.rb /opt/operb/
CMD /opt/operb/operator.rb
