FROM docker.io/ruby:3
RUN gem install typhoeus
COPY --chmod=755 operator.rb /opt/operb/
CMD /opt/operb/operator.rb
