#!/usr/bin/env ruby

require 'tempfile'
require 'typhoeus'
require 'json'
require 'set'

module K8s
  API_SERVER = 'https://kubernetes.default.svc'
  SERVICE_ACCOUNT = '/var/run/secrets/kubernetes.io/serviceaccount'
  TOKEN = File.read("#{SERVICE_ACCOUNT}/token")
  NAMESPACE = File.read("#{SERVICE_ACCOUNT}/namespace")
end

class HelmRelease
  PREFIX = 'operb-'
  attr_reader :name, :chart_url, :chart_version, :helm_pull_flags, :values
  def initialize(obj)
    @name = "#{PREFIX}#{obj['metadata']['name']}"
    @chart_url = obj['spec']['chartURL']
    @chart_version = obj['spec']['chartVersion']
    @helm_pull_flags = obj['spec']['helmPullFlags']
    @values = obj['spec']['values']
  end
end

class Helm

  def run(cmd)
    $logger.info cmd
    response = `#{cmd}`
    raise "command failed status=#{$?.exitstatus}" unless $?.success?
    response
  end

  def pull(release)
    pkg = "/tmp/#{File.basename(release.chart_url)}-#{release.chart_version}.tgz"
    if File.exist?(pkg)
      $logger.info "already pulled #{pkg}"
    else
      cmd = "helm pull #{release.chart_url} --version #{release.chart_version} #{release.helm_pull_flags} --destination /tmp/"
      run(cmd)
      raise "cannot find pkg=#{pkg}" unless File.exist?(pkg)
    end
    pkg
  end

  def install(release)
    pkg = pull(release)
    values_file = Tempfile.new("#{release.name}.values.yaml")
    begin
      values_file.write(release.values)
      cmd = "helm upgrade --install --wait -f #{values_file.path} #{release.name} #{pkg}"
      run(cmd)
    ensure
       values_file.close
       values_file.unlink
    end

  end

  def delete(releaseName)
    cmd = "helm delete #{releaseName}"
    run(cmd)
  end

  def list
    cmd = "helm list --output json"
    response = run(cmd)
    JSON.parse(response)
  end
end

class HelmOperator

  def initialize
    @base_url = "#{K8s::API_SERVER}/apis/operb.example.io/v1/namespaces/#{K8s::NAMESPACE}/helmreleases"
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
    release_listed = Set.new(@helm.list.map{|r| r['name']})
    release_wanted = Set.new
    request = Typhoeus::Request.new(@base_url, @req_opts)
    request.run # non-blocking
    response = request.response
    raise "#{__method__} request failed response.code=#{response.code}" if response.code != 200
    obj_list = JSON.parse(response.body)
    # $logger.debug "#{__method__} response=#{JSON.pretty_generate(obj_list)}"
    obj_list['items'].each do |obj|
      release = HelmRelease.new(obj)
      $logger.info "#{__method__} item=#{release.name}"
      release_wanted.add(release.name)
      @helm.install(release) unless release_listed.include?(release.name)
    end
    (release_listed - release_wanted).each do |releaseName|
      $logger.info "remove unwanted release #{releaseName}"
      @helm.delete(releaseName)
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
        release = HelmRelease.new(event['object'])
        @helm.install(release)
      elsif event['type'] == 'DELETED'
        release = HelmRelease.new(event['object'])
        @helm.delete(release.name)
      end
    end
  end

end

require 'logger'
$logger = Logger.new(STDOUT)
$logger.info 'starting'
$stdout.sync = true # no buffering, for kubectl logs

ho = HelmOperator.new()
ho.reconcile # blocking
