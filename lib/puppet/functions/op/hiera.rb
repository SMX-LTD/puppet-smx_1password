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
    return_type 'Variant[String,Undef]'
  end

  def lookup_key(secret_name, options, context)
    msg = ''
    # This is a reserved key name in hiera
    context.not_found if secret_name == 'lookup_options'

    # Verify keybase is set and skip others
    key_base = options['keybase']
    if key_base
      # Skip keys outside the base
      begin
        regex_key_match = Regexp.new("^#{key_base}::")
      rescue StandardError => e
        raise ArgumentError, "creating regexp failed with: #{e}"
      end
      unless regex_key_match.match(secret_name)
        context.explain { "OP: Skipping op backend because secret_name '#{secret_name}' is not in namespace '#{key_base}'" }
        context.not_found
      end
    else
      raise ArgumentError, 'OP: Need to specify keybase in the hiera options for op'
    end

    # Determine secret_key, splitting by ::
    if options['exact'].nil?
      exact = true
    else
      exact = options['exact']
    end
    create = false
    keyarr = secret_name.split(/::/, -1)
    if keyarr.length < 2 
      context.explain { "OP: Secret name #{secret_name} must match #{key_base}::[vaultname::]secretname[::exact]" }
      return "BAD-FORMAT-IDENTIFIER"

      raise ArgumentError, "OP: Secret name #{secret_name} must match #{key_base}::[vaultname::]secretname[::exact]"
    end
    if keyarr.length < 3
      vault = options['vault']
      secret_title = context.interpolate(keyarr[1])
    else
      if keyarr[1] == '*'
        vault = nil
      else
        vault = keyarr[1]
      end 
      secret_title = context.interpolate(keyarr[2])
      if keyarr.length > 3
        if keyarr[3] == 'false'
          exact = false
        elsif keyarr[3] == 'true'
          exact = true
        elsif keyarr[3] == 'create'
          exact = true
          create = true
        else
          context.explain { "OP: Secret name #{secret_name} final option can only be true, false, or create" }
          return "BAD-FORMAT-IDENTIFIER"
          raise ArgumentError, "OP: Secret name #{secret_name} final option can only be true, false, or create"
        end
      end
    end

    # Handle cached secrets, if we have enabled caching
    if options['cache']
      return context.cached_value(secret_name) if context.cache_has_key(secret_name)
    end

    # Search
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
      # msg = msg + ":vault #{v.name}:title eq \"#{secret_title}\""
      items = op.items(
        vault_id: v.id,
        filter: "title eq \"#{secret_title}\""
      )
      # maybe we should check all vaults for exact before we allow fuzzy
      if items.empty? && exact
        # msg = msg + ":title co \"#{secret_title}\""
        items = op.items(
          vault_id: v.id,
          filter: "title co \"#{secret_title}\""
        )
      end
      # items is now an array of item objects
      unless items.empty?
        items.each { |i|
          if i.state.nil? || (i.state != 'DELETED' && i.state != 'ARCHIVED')
            unless thisid.nil?
              context.explain { "OP: Multiple entries in 1password vault #{v.name} match #{secret_title}" }
              return "MULTIPLE-MATCHES-FOUND"
              raise Puppet::Error, "OP: Multiple entries in 1password vault #{v.name} match #{secret_title}"
            end
            thisid = i.id
          # else
          #   msg = msg + ":Skipping item #{i.state}"
          end
        } #items
        unless thisid.nil?
          # msg = msg + ":retrieving #{thisid}"
          # retrieve complete item
          i = op.item(
            vault_id: v.id, 
            id: thisid
          )
          if i.nil?
            context.explain { "OP: Item disappeared as we were reading it #{secret_title}" }
            context.not_found
            raise Puppet::Error, "OP: Item disappeared as we were reading it #{secret_title}" 
          end
          # identify the first PASSWORD purpose field
          i.fields.each { |f|
            if f.purpose == 'PASSWORD'
              # msg = msg + ":found password"
              secretvalue = f.value
              break
            end
          } # fields
          if secretvalue.nil?
            thisid = nil
            # msg = msg + ":No password"
          end
        end
      # else
      #   msg = msg + ":No items"
      end
    } # vaults

    # not found
    if secretvalue.nil?
      if create
        # create the secret and return it
        secretvalue = rand.to_s  + $$.to_s + Time.now.to_s 
        secretvalue.crypt(Time.now.sec.to_s*2)[-16,16]

        vault = Puppet::Util::OnePassword.op_default_vault() if vault.nil?
        vaultid = nil
        op.vaults.each { |v|
          if v.name == vault
            vaultid = v.id
          end
        }

        if vaultid.nil?
          Puppet.send_log(:err,"OP: Cannot identify vault '#{vault}'")
          context.not_found
        end
         
        # Identify username, if we can
        username = secret_name.sub( /@.*/, "" ).sub( /^.*:\/*/, "" )

        # Create the item
        begin
          item = op.create_item(vault_id: vaultid, 
            category: 'LOGIN', tags: [ 'puppet' ],
            title: secret_name,
            fields: [
              {
                id: "username",
                purpose: "USERNAME",
                value: username,
              },
              {
                id: "password",
                purpose: "PASSWORD",
                value: secretvalue,
              },
              {
                id: "notesPlain",
                purpose: "NOTES",
                value: "Created by puppet module"
              }
            ]
          )
        rescue => error
          Puppet.send_log(:err, "OP: Failed to create item #{secretname} - #{error.message}" )
          raise ArgumentError, "OP: Unable to create new item in vault #{vault}"
          context.not_found
        end
        if item.nil?
          Puppet.send_log(:err, "OP: Failed to create item #{secretname} in #{vault}" )
          raise( "unknown: 1Password item create ERROR for #{secretname} in #{vault}" )
          context.not_found
        else
          Puppet.send_log(:info, "OP: Created new secret #{secretname}" )
          context.explain { "OP: Created new #{secret_title} #{msg}" }
          return context.cache(secret_name, secretvalue)
        end

      else
        # error out
        context.explain { "OP: Unable to find secret #{secret_title} in vault #{vault}#{msg}" }
        context.not_found
      end
    end

    # Return the secret, and cache it for next time
    context.explain { "OP: Found #{secret_title} #{msg}" }
    return context.cache(secret_name, secretvalue)
  end
end
