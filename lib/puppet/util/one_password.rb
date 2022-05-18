require 'op_connect'

module Puppet::Util
  class OnePassword

  # class attributes
  @@c_endpoint = nil
  @@c_apikey = nil
  @@c_defaultvault = nil

  def initialize(apikey=nil,endpoint=nil,defaultvault=nil)
    @@c_endpoint = endpoint
    @@c_apikey = apikey
    @@c_defaultvault = defaultvault
  end

  # Define class method
  def self.op_connect(apikey=nil,endpoint=nil)
#    if @@c_endpoint.nil?
      # Check local 1password.yaml file for defaults, if not set
      configdir = Puppet.settings[:confdir]
      defconfigfile = configdir + '/1password.yaml'
      configfile = defconfigfile
      if File.exists?(configfile)
        begin
          defaults = Puppet::Util::Yaml.safe_load_file(configfile)
        rescue
          raise("Unable to parse YAML file: #{configfile}")
          return nil
        end
        if defaults['endpoint'].nil?
          warn("No endpoint configured in #{configfile}")
        end
      else
        warn("Missing config file! #{configfile}")
        defaults = {
          :endpoint => nil,
          :apikey   => nil,
        }
      end
      if defaults['endpoint'].nil?
        raise("Endpoint in config file is nil?! #{configfile}")
      end
      @@c_endpoint = defaults['endpoint']
      @@c_apikey = defaults['apikey']
#    else
#      defaults = {
#        :endpoint => @@c_endpoint,
#        :apikey => @@c_apikey
#      } 
#    end
    if endpoint.nil?
      endpoint = defaults['endpoint']
    end
    if apikey.nil?
      apikey = defaults['apikey']
    end
    if endpoint.nil?
      raise("Unable to identify the endpoint for 1Password API : #{Puppet.settings[:confdir]}/1password.yaml")
      return nil
    end
    # set options
    OpConnect.api_endpoint = "https://" + endpoint + "/v1"
    OpConnect.access_token = apikey

    begin
      op = OpConnect::Client.new()
    rescue => e
      raise("1Password: ERROR: Cannot open API at https://#{endpoint}/v1 : #{e.message}")
      return nil
    end
    op
  end

  def self.op_default_vault()
    if @@c_defaultvault.nil?
      configdir = Puppet.settings[:confdir]
      defconfigfile = configdir + '/1password.yaml'
      configfile = defconfigfile
      if File.exists?(configfile)
        begin
          defaults = Puppet::Util::Yaml.safe_load_file(configfile)
        rescue => error
          raise("Unable to load YAML file #{configfile} : #{error.message}")
          return nil
        end
      else
        defaults = {
          :default_vault => nil,
        }
      end
      @@c_defaultvault = defaults['default_vault']
    else
      defaults = {
        :default_vault => @@c_defaultvault
      }
    end
    if defaults['default_vault'].nil?
      @@c_defaultvault = 'Default Vault'
      return 'Default Vault'
    else
      return defaults['default_vault']
    end
  end
  
  # Any instance methods?

  # Any private methods?
  
 end
end
