# Hiera lookup function for Onpassword
#
# This works by confining to a special key that encodes the parameters
# You then use lookup() to pull this in to another hiera key
#
# hierakey: "%{lookup('onepassword::secretname')}"
# hierakey: "%{lookup('onepassword::vaultname::secretname')}"
# hierakey: "%{lookup('onepassword::vaultname::secretname::false')}"
#
# "vaultname" can be "*" for Any.
#
# Define the lookup in the hiera/yaml.
# Set defaults for parameters, endpoint and api will normally come
# from the onepassword.yaml.
# Vault will be used if not specified (rather than checking all vaults)
#
# - name: 'OnePassword'
#    lookup_key: op::hiera
#    options:
#      keybase: onepassword
#      endpoint: 'https://onepassword-api.smxemail.com/'
#      apikey: 'taken-from-onepass.yaml'
#      vault: '*'
#      exact: true
#      cache: false
#

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))
require 'puppet/util/one_password'
require 'op_connect'

Puppet::Functions.create_function(:'op::hiera') do
  dispatch :lookup_key do
    param 'Variant[String, Numeric]', :secret_name
    param 'Struct[{
      keybase            => String,
      Optional[apikey]   => String,
      Optional[endpoint] => String,
      Optional[vault]    => String,
      Optional[exact]    => Boolean,
      Optional[cache]    => Boolean,
    }]', :options
    param 'Puppet::LookupContext', :context
    return_type 'Variant[String, Undef]'
  end

  def lookup_key(secret_name, options, context)
    # This is a reserved key name in hiera
    return context.not_found if secret_name == 'lookup_options'

    # Verify keybase is set and skip others
    key_base = options['key_base']
    if key_base
      # Skip keys outside the base
      begin
        regex_key_match = Regexp.new("^#{key_base}::")
      rescue StandardError => e
        raise ArgumentError, "creating regexp failed with: #{e}"
      end
      unless secret_name[regex_key_match] == secret_name
        context.explain { "Skipping op backend because secret_name '#{secret_name}' is not in namespace '#{key_base}'" }
        context.not_found
      end
    else
      raise ArgumentError, 'Need to specify keybase in the hiera options for op'
    end

    # Determine secret_key, splitting by ::
    keyarr = secret_name.split(/::/, -1)
    if keyarr.length < 2 
      raise ArgumentError, "Secret name #{secret_name} must match #{key_base}::[vaultname::]secretname[::exact]"
    end
    if keyarr.length < 3
      vault = options['vault']
      secret_title = keyarr[1]
    else
      if keyarr[1] == '*'
        vault = nil
      else
        vault = keyarr[1]
      end 
      secret_title = keyarr[2]
      if keyarr.length > 3
        if keyarr[3] == 'false'
          exact = false
        elsif keyarr[3] == 'true'
          exact = true
        else
          raise ArgumentError, "Secret name #{secret_name} final option can only be true or false"
        end
      end
    end

    # Handle cached secrets, if we have enabled caching
    if options['cache']
      return Puppet::Pops::Types::PStringType.new(context.cached_value(secret_name)) if context.cache_has_key(secret_name)
    end

    # Search
    if options['exact'].nil?
      exact = true
    else
      exact = options['exact']
    end
    # Obtain a onepassword object
    op = Puppet::Util::OnePassword.op_connect(options['apikey'],options['endpoint'])
    if op.nil? 
      raise ArgumentError, 'OP: Unable to connect to 1Password'
    end
    # scan all relevant vaults
    thisid = nil
    secretvalue = nil
    vaults = op.vaults
    vaults.each { |v|
      if !vault.nil? and vault != ''
        next if v.name != vault
      end
      items = op.items(
        vault_id: v.id,
        filter: ('title eq "' + secret_title + '"')
      )
      # maybe we should check all vaults for exact before we allow fuzzy
      if items.empty? && exact
        items = op.items(
          vault_id: v.id,
          filter: ('title co "' + secret_title + '"')
        )
      end
      # items is now an array of item objects
      unless items.empty?
        items.each { |i|
          if i.state.nil? || (i.state != 'DELETED' && i.state != 'ARCHIVED')
            unless thisid.nil?
              raise Puppet::Error, "OP: Multiple entries in 1password vault #{v.name} match #{secret_title}"
            end
            thisid = i.id
          end
        } #items
        unless thisid.nil?
          # retrieve complete item
          i = op.item(
            vault_id: v.id, 
            id: thisid
          )
          if i.nil?
            raise Puppet::Error, "OP: Item disappeared as we were reading it #{secret_title}" 
          end
          # identify the first PASSWORD purpose field
          i.fields.each { |f|
            if f.purpose == 'PASSWORD'
              secretvalue = f.value
              break
            end
          } # fields
          if secretvalue.nil?
            thisid = nil
          end
        end
      end
    } # vaults

    # not found
    if secretvalue.nil?
      context.explain { "OP: Unable to find secret #{secret_title}" }
      context.not_found
      return
    end

    # Return the secret, and cache it for next time
    Puppet::Pops::Types::PStringType.new(context.cache(secret_name, secretvalue))
  end
end
