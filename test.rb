#!/usr/bin/env ruby

require 'typhoeus'
require 'json'

module K8s
  API_SERVER = 'https://kubernetes.default.svc'
  SERVICE_ACCOUNT = '/var/run/secrets/kubernetes.io/serviceaccount'
  TOKEN = File.read("#{SERVICE_ACCOUNT}/token")
end

class DeployWatcher

  def initialize(namespace, resource)
    @base_url = "#{K8s::API_SERVER}/apis/operb.example.io/v1/namespaces/#{namespace}/#{resource}"
    @req_opts = {
      cainfo: "#{K8s::SERVICE_ACCOUNT}/ca.crt",
      headers: { Authorization: "Bearer #{K8s::TOKEN}" }
    }
  end

  def watch
    resource_version = list
    $logger.info "watch resource_version=#{resource_version}"
    request = Typhoeus::Request.new("#{@base_url}?watch=1&resourceVersion=#{resource_version}", @req_opts)
    request.on_headers do |response|
      raise "watch request failed response.code=#{response.code}" if response.code != 200
      $logger.info "watch on_headers response.code=#{response.code}"
    end
    request.on_body do |chunk|
      on_body(chunk)
    end
    $logger.info 'watching...'
    request.run # blocking
    $logger.info 'done watching'
  end

  def list
    request = Typhoeus::Request.new(@base_url, @req_opts)
    request.run # non-blocking
    response = request.response
    raise "list request failed response.code=#{response.code}" if response.code != 200
    obj_list = JSON.parse(response.body)
    # $logger.debug "list response=#{JSON.pretty_generate(obj_list)}"
    obj_list['items'].each do |item|
      $logger.info "list item=#{item['metadata']['name']}"
    end
    resource_version = obj_list['metadata']['resourceVersion']
    $logger.info "list resource_version=#{resource_version}"
    resource_version
  end

  def on_body(chunk)
    # $logger.debug "watch chunk.size=#{chunk.size}"
    # $logger.debug "watch chunk: ---#{chunk}---"
    chunk.each_line do |line|
      event = JSON.parse(line)
      $logger.info "watch event=#{event['type']} #{event['object']['metadata']['name']}"
    end
  end

end

require 'logger'
$logger = Logger.new(STDOUT)
$logger.info 'starting'

d = DeployWatcher.new('operb', 'foos')

# trick to force typhoeus exit on Ctrl-C
request_thread = Thread.new { d.watch } # run watch in a separate thread
begin
  request_thread.join # wait for the watch thread to complete
rescue Interrupt
  $logger.info 'watch interrupted by user, exiting...'
  exit!
end
