require 'op_connect'

module Puppet::Util
  class OnePassword

  # class attributes
  @@c_endpoint = nil
  @@c_apikey = nil
  @@c_defaultvault = nil

  def initialize()
  end
  def initialize(apikey,endpoint,defaultvault)
    @@c_endpoint = endpoint
    @@c_apikey = apikey
    @@c_defaultvault = defaultvault
  end

  # Define class method
  def self.op_connect(apikey=nil,endpoint=nil)
    if @@c_endpoint.nil?
      # scope = closure_scope
      # Check local 1password.yaml file for defaults, if not set
      configdir = Puppet.settings[:confdir]
      defconfigfile = configdir + '/1password.yml'
      # configfile = scope.call_function( 'lookup', 'op::configfile' )
      # if configfile.nil?
        configfile = defconfigfile
      # end
      if File.exists?(configfile)
        begin
          defaults = Puppet::Util::Yaml.safe_load_file(configfile)
        rescue
          return nil
        end
      else
        defaults = {
          # :endpoint => scope.call_function( 'lookup', 'op::endpoint' ),
          # :apikey   => scope.call_function( 'lookup', 'op::apikey' ),
          :endpoint => nil,
          :apikey   => nil,
        }
      end
      @@c_endpoint = defaults['endpoint']
      @@c_apikey = defaults['apikey']
    else
      defaults = {
        :endpoint => @@c_endpoint,
        :apikey => @@c_apikey
      } 
    end
    if endpoint.nil?
      endpoint = defaults['endpoint']
    end
    if apikey.nil?
      apikey = defaults['apikey']
    end
    if endpoint.nil?
      raise("Unable to identify the endpoint for 1Password API - check #{configfile}")
    end
    # set options
    OpConnect.api_endpoint = "https://" + endpoint
    OpConnect.access_token = apikey

    begin
      op = OpConnect::Client.new()
    rescue
      op = nil
      raise("1Password: ERROR: Cannot open API at https://#{endpoint}")
    end
    op
  end

  def self.op_default_vault()
    if @@c_defaultvault.nil?
      # scope = closure_scope
      configdir = Puppet.settings[:confdir]
      defconfigfile = configdir + '/1password.yml'
      # configfile = scope.call_function( 'lookup', 'op::configfile' )
      # if configfile.nil?
        configfile = defconfigfile
      # end
      if File.exists?(configfile)
        begin
          defaults = Puppet::Util::Yaml.safe_load_file(configfile)
        rescue
          raise("Unable to load YAML file #{configfile}")
        end
      else
        defaults = {
          # :default_vault => scope.call_function( 'lookup', 'op::default_vault' ),
          :default_vault => nil,
        }
      end
      @@c_defaultvault = defaults['default_vault']
    else
      defaults = {
        :default_vault => @@c_defaultvault
      }
    end
    if defaults['default_vault']
      return defaults['default_vault']
    else
      @@c_defaultvault = 'Default Vault'
      return 'Default Vault'
    end
  end
  
  # Any instance methods?

  # Any private methods?
  
 end
end
