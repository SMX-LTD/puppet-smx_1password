require 'op_connect'

# Note: send_log levels :debug :info :notice :warning :err :alert :emerg :crit
# Logs go to puppetserver:/var/log/puppet/puppetserver/puppetserver.log

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
    defaults = {}
    if @@c_endpoint.nil?
      # Puppet.send_log(:info,"OP: Reading configuration")
      # Check local 1password.yaml file for defaults, if not set
      configdir = Puppet.settings[:confdir]
      defconfigfile = configdir + '/1password.yaml'
      configfile = defconfigfile
      if File.exists?(configfile)
        begin
          Puppet.send_log(:info,"OP: Reading configfile #{configfile}")
          defaults = Puppet::Util::Yaml.safe_load_file(configfile)
        rescue => error
          raise("OP: Unable to parse YAML file: #{configfile} - #{eror.message}")
          return nil
        end
        if defaults['endpoint'].nil?
          Puppet.send_log(:warning,"OP: No endpoint configured in #{configfile}")
        end
      else
        Puppet.send_log(:warning,"OP: Missing config file! #{configfile}")
        defaults = {
          'endpoint' => nil,
          'apikey'   => nil,
        }
      end
      if defaults['endpoint'].nil?
        Puppet.send_log(:err,"OP: Empty endpoint in config #{configfile}")
      end
      @@c_endpoint = defaults['endpoint'] unless defaults['endpoint'].nil?
      @@c_apikey = defaults['apikey'] unless defaults['apikey'].nil?
    else
      defaults = {
        'endpoint' => @@c_endpoint,
        'apikey' => @@c_apikey
      } 
    end
    if endpoint.nil? 
      endpoint = defaults['endpoint']
    end
    if apikey.nil? 
      apikey = defaults['apikey']
    end
    if endpoint.nil?
      raise("OP: Unable to identify the endpoint for 1Password API : #{Puppet.settings[:confdir]}/1password.yaml configfile(#{configfile}) endpoint(#{endpoint}) c_endpoint(#{@@c_endpoint}) defaults: " + defaults.keys.join(','))
      return nil
    end
    # set options
    OpConnect.api_endpoint = "https://" + endpoint + "/v1"
    OpConnect.access_token = apikey

    # Puppet.send_log(:info,"OP: Creating new client to #{endpoint}")
    begin
      op = OpConnect::Client.new()
    rescue => e
      raise("OP: ERROR: Cannot open API at https://#{endpoint}/v1 : #{e.message}")
      return nil
    end
    # Puppet.send_log(:info,"OP: New client object created!")
    op
  end

  def self.op_default_vault()
    defaults = {}
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
          'default_vault' => nil,
        }
      end
      @@c_defaultvault = defaults['default_vault']
    else
      defaults = {
        'default_vault' => @@c_defaultvault
      }
    end
    if defaults['default_vault'].nil?
      Puppet.send_log(:warning,"OP: Default vaultname was not supplied, picking one myself")
      @@c_defaultvault = 'Default'
      return 'Default'
    else
      return defaults['default_vault']
    end
  end
  
  # Any instance methods?

  # Any private methods?
  
 end
end
