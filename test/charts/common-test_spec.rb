# frozen_string_literal: true
require_relative '../test_helper'

class Test < ChartTest
  @@chart = Chart.new('charts/common-test')
  
  describe @@chart.name do
    describe 'controller type' do
      it 'defaults to "Deployment"' do
        assert_nil(resource('StatefulSet'))
        assert_nil(resource('DaemonSet'))
        refute_nil(resource('Deployment'))
      end
  
      it 'accepts "statefulset"' do
        chart.value controllerType: 'statefulset'
        assert_nil(resource('Deployment'))
        assert_nil(resource('DaemonSet'))
        refute_nil(resource('StatefulSet'))
      end
  
      it 'accepts "daemonset"' do
        chart.value controllerType: 'daemonset'
        assert_nil(resource('Deployment'))
        assert_nil(resource('StatefulSet'))
        refute_nil(resource('DaemonSet'))
      end
    end
  
    describe 'pod replicas' do
      it 'defaults to 1' do
        jq('.spec.replicas', resource('Deployment')).must_equal 1
      end
  
      it 'accepts integer as value' do
        chart.value replicas: 3
        jq('.spec.replicas', resource('Deployment')).must_equal 3
      end
    end

    describe 'Environment settings' do
      it 'Check no environment variables' do
        values = {}
        chart.value values
        jq('.spec.template.spec.containers[0].env', resource('Deployment')).must_equal nil)
      end

      it 'set "static" environment variables' do
        values = {
          env: {
            STATIC_ENV: 'value_of_env'
          }
        }
        chart.value values
        jq('.spec.template.spec.containers[0].env[0].name', resource('Deployment')).must_equal 'STATIC_ENV'
        jq('.spec.template.spec.containers[0].env[0].value', resource('Deployment')).must_equal 'value_of_env'
      end

      it 'set "Dynamic/Tpl" environment variables' do
        values = {
          envTpl: {
            DYN_ENV: '{{ .Release.Name }}-admin'
          }
        }
        chart.value values
        jq('.spec.template.spec.containers[0].env[0].name', resource('Deployment')).must_equal 'DYN_ENV'
        jq('.spec.template.spec.containers[0].env[0].value', resource('Deployment')).must_equal 'template-admin'
      end
    end

    describe 'ports settings' do
      default_name = 'http'
      default_port = 8080

      it 'defaults to name "http" on port 8080' do
        jq('.spec.ports[0].port', resource('Service')).must_equal default_port
        jq('.spec.ports[0].targetPort', resource('Service')).must_equal default_name
        jq('.spec.ports[0].name', resource('Service')).must_equal default_name
        jq('.spec.template.spec.containers[0].ports[0].containerPort', resource('Deployment')).must_equal default_port
        jq('.spec.template.spec.containers[0].ports[0].name', resource('Deployment')).must_equal default_name
      end
  
      it 'port name can be overridden' do
        values = {
          service: {
            port: {
              name: 'server'
            }
          }
        }
        chart.value values
        jq('.spec.ports[0].port', resource('Service')).must_equal default_port
        jq('.spec.ports[0].targetPort', resource('Service')).must_equal values[:service][:port][:name]
        jq('.spec.ports[0].name', resource('Service')).must_equal values[:service][:port][:name]
        jq('.spec.template.spec.containers[0].ports[0].containerPort', resource('Deployment')).must_equal default_port
        jq('.spec.template.spec.containers[0].ports[0].name', resource('Deployment')).must_equal values[:service][:port][:name]
      end

      it 'targetPort can be overridden' do
        values = {
          service: {
            port: {
              targetPort: 80
            }
          }
        }
        chart.value values
        jq('.spec.ports[0].port', resource('Service')).must_equal default_port
        jq('.spec.ports[0].targetPort', resource('Service')).must_equal values[:service][:port][:targetPort]
        jq('.spec.ports[0].name', resource('Service')).must_equal default_name
        jq('.spec.template.spec.containers[0].ports[0].containerPort', resource('Deployment')).must_equal values[:service][:port][:targetPort]
        jq('.spec.template.spec.containers[0].ports[0].name', resource('Deployment')).must_equal default_name
      end

      it 'targetPort cannot be a named port' do
        values = {
          service: {
            port: {
              targetPort: 'test'
            }
          }
        }
        chart.value values
        exception = assert_raises HelmCompileError do
          chart.execute_helm_template!
        end
        assert_match("Our charts do not support named ports for targetPort. (port name #{default_name}, targetPort #{values[:service][:port][:targetPort]})", exception.message)
      end
    end
  end
end
