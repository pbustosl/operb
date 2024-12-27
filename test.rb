#!/usr/bin/env ruby

require 'typhoeus'

require 'logger'
$logger = Logger.new(STDOUT)
$logger.info 'starting'

K8S_APISERVER = 'https://kubernetes.default.svc'
K8S_SERVICEACCOUNT = '/var/run/secrets/kubernetes.io/serviceaccount'
K8S_TOKEN = File.read("#{K8S_SERVICEACCOUNT}/token")

url = "#{K8S_APISERVER}/api/v1/namespaces/operb/pods"
url = "#{K8S_APISERVER}/api/v1/namespaces/operb/pods?watch=1&resourceVersion=7829819"
request = Typhoeus::Request.new(url,
  cainfo: "#{K8S_SERVICEACCOUNT}/ca.crt",
  headers: { Authorization: "Bearer #{K8S_TOKEN}" }
  )
request.on_headers do |response|
  $logger.info "response.code: #{response.code}"
  if response.code != 200
    raise "Request failed"
  end
end
request.on_body do |chunk|
    $logger.info chunk.size
    $logger.info chunk
end
request.on_complete do |response|
  $logger.info 'on_complete'
  $logger.info "response.code: #{response.code}"
  $logger.info "response.body: #{response.body}"
end
request.run
response = request.response
$logger.info "response.code: #{response.code}"
$logger.info "response.body: #{response.body}"
$logger.info response
sleep 300
$logger.info 'done'
