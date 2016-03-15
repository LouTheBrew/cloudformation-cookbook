require 'poise'
require 'chef/resource'
require 'chef/provider'

module Cloudformation
  class Resource < Chef::Resource
    include Poise
    provides  :cloudformation
    actions   :create, :destroy
    attribute :name, name_attribute: true, kind_of: String
    attribute :pip_packages, kind_of: Array, default: %w{boto3 docopt}
    attribute :venv, kind_of: String, default: '/chef/apps/virtualenvs/cloudformation/'
    attribute :template, kind_of: String, default: 'cfntools.py.erb'
    attribute :template_src_cookbook, kind_of: String, default: 'anaplan_dr'
    attribute :bucket, kind_of: String
    attribute :origin, kind_of: Symbol, default: :s3
    attribute :on_fail, kind_of: Symbol, default: :sticky
    attribute :wait_for, kind_of: Symbol, default: :success
    attribute :stack_name, kind_of: String
  end
  class Provider < Chef::Provider
    include Poise
    provides :cloudformation
    def access
      notifying_block do
        yield
      end
    end
    def venv
      access do
        return new_resource.venv
      end
    end
    def bucket
      access do
        return new_resource.bucket
      end
    end
    def cfnpythonbin
      "#{self.venv}bin/cfntools.py"
    end
    def python
      return "#{self.venv}bin/python"
    end
    def stack_name
      access do
        return new_resource.stack_name
      end
    end
    def mode
      ""
    end
    def cfntemplate
      access do
        return new_resource.name
      end
    end
    def key
      access do
        return new_resource.name
      end
    end
    def python_env(env)
      include_recipe 'python'
      python_virtualenv env
    end
    def given_the_givens
      python_env new_resource.venv
        new_resource.pip_packages.each do |pkg|
          python_pip pkg do
          virtualenv new_resource.venv
        end
      end
      template self.cfnpythonbin do
        source new_resource.template
        cookbook new_resource.template_src_cookbook
        variables :context => {
          :interpreter => self.python
        }
      end
      yield
    end
    def action_create
      given_the_givens do
        bash "create" do
          code <<-EOH
          touch /tmp/cmd.log
          echo "#{self.python} #{self.cfnpythonbin} create #{self.stack_name} #{self.bucket} #{self.key}" >> /tmp/cmd.log
          #{self.python} #{self.cfnpythonbin} create #{self.stack_name} #{self.bucket} #{self.key}
          EOH
        end
      end
    end
    def action_destroy
      given_the_givens do
        cmd = 'destroy'
        bash cmd do
          code <<-EOH
          touch /tmp/cmd.log
          echo "#{self.python} #{self.cfnpythonbin} #{cmd} #{self.stack_name} #{self.bucket} #{self.key}" >> /tmp/cmd.log
          #{self.python} #{self.cfnpythonbin} #{cmd} #{self.stack_name} #{self.bucket} #{self.key}
          EOH
        end
      end
    end
  end
end
