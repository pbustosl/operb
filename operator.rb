#!/usr/bin/env ruby

require 'typhoeus'
require 'json'

module K8s
  API_SERVER = 'https://kubernetes.default.svc'
  SERVICE_ACCOUNT = '/var/run/secrets/kubernetes.io/serviceaccount'
  TOKEN = File.read("#{SERVICE_ACCOUNT}/token")
end

class Helm

    def install(obj)
      $logger.info "helm install chart=#{obj['metadata']['name']}"
      $logger.info obj
    end

    def delete(obj)
      $logger.info "helm delete chart=#{obj['metadata']['name']}"
    end
end

class HelmOperator

  def initialize(namespace, resource)
    @base_url = "#{K8s::API_SERVER}/apis/operb.example.io/v1/namespaces/#{namespace}/#{resource}"
    @req_opts = {
      cainfo: "#{K8s::SERVICE_ACCOUNT}/ca.crt",
      headers: { Authorization: "Bearer #{K8s::TOKEN}" }
    }
    @helm = Helm.new
  end

  def reconcile
    resource_version = reconcileOnce
    reconcileOngoing(resource_version)
  end

  def reconcileOnce
    request = Typhoeus::Request.new(@base_url, @req_opts)
    request.run # non-blocking
    response = request.response
    raise "#{__method__} request failed response.code=#{response.code}" if response.code != 200
    obj_list = JSON.parse(response.body)
    # $logger.debug "#{__method__} response=#{JSON.pretty_generate(obj_list)}"
    obj_list['items'].each do |obj|
      $logger.info "#{__method__} item=#{obj['metadata']['name']}"
      @helm.install(obj)
    end
    resource_version = obj_list['metadata']['resourceVersion']
    $logger.info "#{__method__} resource_version=#{resource_version}"
    resource_version
  end

  def reconcileOngoing(resource_version)
    $logger.info "#{__method__} resource_version=#{resource_version}"
    request = Typhoeus::Request.new("#{@base_url}?watch=1&resourceVersion=#{resource_version}", @req_opts)
    request.on_headers do |response|
      raise "#{__method__} request failed response.code=#{response.code}" if response.code != 200
      $logger.info "#{__method__} on_headers response.code=#{response.code}"
    end
    request.on_body do |chunk|
      on_body(chunk)
    end
    $logger.info "#{__method__} watching..."
    request.run # blocking
  end

  def on_body(chunk)
    # $logger.debug "watch chunk.size=#{chunk.size}"
    # $logger.debug "watch chunk: ---#{chunk}---"
    chunk.each_line do |line|
      event = JSON.parse(line)
      $logger.info "watch event=#{event['type']} #{event['object']['metadata']['name']}"
      if ['ADDED', 'MODIFIED'].include?(event['type'])
        @helm.install(event['object'])
      elsif event['type'] == 'DELETED'
        @helm.delete(event['object'])
      end
    end
  end

end

require 'logger'
$logger = Logger.new(STDOUT)
$logger.info 'starting'
$stdout.sync = true # no buffering, for kubectl logs

ho = HelmOperator.new('operb', 'helmcharts')
ho.reconcile # blocking
