#!/usr/bin/env ruby

require 'uri'
require 'net/http'

require 'logger'
$logger = Logger.new(STDOUT)
$logger.info 'starting'

K8S_APISERVER = 'https://kubernetes.default.svc'
K8S_SERVICEACCOUNT = '/var/run/secrets/kubernetes.io/serviceaccount'
K8S_TOKEN = File.read("#{K8S_SERVICEACCOUNT}/token")

url = URI.parse("#{K8S_APISERVER}/api/v1/namespaces/operb/pods?watch=1&resourceVersion=7069965")
http = Net::HTTP.new(url.host, url.port)
http.ca_file = "#{K8S_SERVICEACCOUNT}/ca.crt"
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_PEER
request = Net::HTTP::Get.new(url.path)
request.add_field 'Authorization', "Bearer #{K8S_TOKEN}"
http.request(request) do |response|
  response.read_body do |chunk|
    $logger.info chunk.size
    $logger.info chunk
  end
end
# $logger.info response.body if response.is_a?(Net::HTTPSuccess)
$logger.info 'done'
