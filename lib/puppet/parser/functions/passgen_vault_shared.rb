require 'yaml'
# passgen_vault_shared($name, $expire, $pwd, $facts, $shared)
module Puppet::Parser::Functions
  newfunction(:passgen_vault_shared, :type => :rvalue) do |args|
    require 'chronic_duration'
    require 'vault'
    ChronicDuration.raise_exceptions = true

    name = args[0]

    expire = nil
    if args[1]
      expire = ChronicDuration.parse(args[1])
    end

    if args[2] and args[2] != ''
      gen_value = args[2]
    else
      gen_value = `pwgen -s -1 14`.chomp
    end

    facts = "__common"
    keys = []
    if args[3] then
      if not args[3].is_a?(Array) then
        raise "4th argument must be array of facts"
      end
      keys = args[3]
      facts_array = args[3].sort.map do |fact|
        value = lookupvar(fact)
        "#{fact}_#{value}"
      end
      facts = facts_array.join("/")
    end

    shared = []
    if args[4] then
      if not args[3].is_a?(Array) then
        raise "5th argument must be array of arrays of values"
      end
      shared = args[4].map.with_index do |values, idx|
        if keys[idx] then
          values.map.with_index do |value|
            "#{keys[idx]}_#{value}"
          end.sort.join('/')
        end
      end
    end

    options_file = '/srv/puppet/vault/passgen_vault_options'

    options = YAML::load_file options_file
    if not options.is_a?(Hash) then raise "Config options is not a hash!" end
    options.each do |key, value|
      Vault.client.instance_variable_set(:"@#{key}", value)
    end

    store = {}
    Vault.with_retries(Vault::HTTPConnectionError) do
      # with probability 10% self-renew token
      if Random.rand <= 0.1
        begin
          Vault.client.auth_token.renew_self
        rescue
        end
      end
      secret = Vault.logical.read("secret/shared/#{facts}/#{name}")
      if secret
        if secret.data
          store = secret.data
        end
      end
    end
    pass = store[:value]
    stored_expire = store[:expire]
    expire_duration = store[:expire_duration]
    owner = store[:owner]
    oldshared = store[:shared]
    if not pass or (expire and stored_expire ? Time.now.to_i > stored_expire : false) or expire_duration != args[1]
      if not pass or ( pass and owner == facts )
        Vault.with_retries(Vault::HTTPConnectionError) do
          Vault.logical.write("secret/shared/#{facts}/#{name}",
                              value: gen_value,
                              expire: expire ? Time.now.to_i + expire : expire,
                              expire_duration: args[1],
                              owner: facts,
                              shared: shared,
                              ttl: expire)
          pass = gen_value
        end
      end
    end
    # for each other owner(s) if expired or not shared
    if oldshared != shared or not pass or (expire and stored_expire ? Time.now.to_i > stored_expire : false) or expire_duration != args[1]
      shared.each do |path|
        Vault.with_retries(Vault::HTTPConnectionError) do
          Vault.logical.write("secret/shared/#{path}/#{name}",
                              value: pass,
                              expire: expire ? Time.now.to_i + expire : expire,
                              expire_duration: args[1],
                              owner: facts,
                              shared: shared,
                              ttl: expire)
        end
      end
    end
    pass
  end
end
