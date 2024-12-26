#!/usr/bin/env ruby

require 'open-uri'
require 'logger'

$logger = Logger.new(STDOUT)
$logger.info 'starting'

K8S_APISERVER = 'https://kubernetes.default.svc'
K8S_SERVICEACCOUNT = '/var/run/secrets/kubernetes.io/serviceaccount'
K8S_TOKEN = File.read("#{K8S_SERVICEACCOUNT}/token")

response = URI.open("#{K8S_APISERVER}/api/v1/namespaces/operb/pods?watch=1&resourceVersion=7069965",
    :ssl_ca_cert => "#{K8S_SERVICEACCOUNT}/ca.crt",
    'Authorization' => "Bearer #{K8S_TOKEN}" )
$logger.info response
$logger.info 'done'
