require 'op_connect'

module Puppet::Util
 class Onepassword

  def op_connect(apikey=nil,endpoint=nil)
    # Check local 1password.yaml file for defaults, if not set
    configdir = Puppet.settings[:confdir]
    defconfigfile = configdir + '/1password.yml'
    configfile = call_function( 'lookup', 'op::configfile' )
    if configfile.nil?
      configfile = defconfigfile
    end
    if File.exists?(configfile)
      begin
        defaults = Puppet::Util::Yaml.safe_load_file(configfile)
      rescue
        return nil
      end
    else
      defaults = {
        :endpoint => call_function( 'lookup', 'op::endpoint' ),
        :apikey   => call_function( 'lookup', 'op::apikey' ),
      }
    end
    if endpoint.nil?
      endpoint = defaults['endpoint']
    end
    if apikey.nil?
      apikey = defaults['apikey']
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

  def op_default_vault()
    configdir = Puppet.settings[:confdir]
    defconfigfile = configdir + '/1password.yml'
    configfile = call_function( 'lookup', 'op::configfile' )
    if configfile.nil?
      configfile = defconfigfile
    end
    if File.exists?(configfile)
      begin
        defaults = Puppet::Util::Yaml.safe_load_file(configfile)
      rescue
        raise("Unable to load YAML file #{configfile}")
      end
    else
      defaults = {
        :default_vault => call_function( 'lookup', 'op::default_vault' ),
      }
    end
    if defaults['default_vault']
      return defaults['default_vault']
    else
      return 'Default Vault'
    end
  end
  
 end
end
