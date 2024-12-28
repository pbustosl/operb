#!/usr/bin/env ruby

require 'typhoeus'
require 'json'
require 'logger'
$logger = Logger.new(STDOUT)
$logger.info 'starting'

K8S_APISERVER = 'https://kubernetes.default.svc'
K8S_SERVICEACCOUNT = '/var/run/secrets/kubernetes.io/serviceaccount'
K8S_TOKEN = File.read("#{K8S_SERVICEACCOUNT}/token")

resource_path = "/apis/operb.example.io/v1/namespaces/operb/foos"
req_opts = {
  cainfo: "#{K8S_SERVICEACCOUNT}/ca.crt",
  headers: { Authorization: "Bearer #{K8S_TOKEN}" }
}

url = "#{K8S_APISERVER}#{resource_path}"
request = Typhoeus::Request.new(url, req_opts)
request.run
response = request.response
raise "Request failed response.code=#{response.code}" if response.code != 200
pod_list = JSON.parse(response.body)
resourceVersion = pod_list['metadata']['resourceVersion']
$logger.info "resourceVersion=#{resourceVersion}"

url = "#{K8S_APISERVER}#{resource_path}?watch=1&resourceVersion=#{resourceVersion}"
request = Typhoeus::Request.new(url, req_opts)
request.on_headers do |response|
  $logger.info "on_headers response.code=#{response.code}"
  raise "Request failed response.code=#{response.code}" if response.code != 200
end
request.on_body do |chunk|
    $logger.info "chunk.size=#{chunk.size}"
    $logger.info "chunk: ---#{chunk}---"
    JSON.parse(chunk)
end
request.on_complete do |response|
  $logger.info 'on_complete'
end
$logger.info 'watch'
request.run
$logger.info 'done'
