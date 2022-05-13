MANIFESTS=manifests/cert.pp manifests/init.pp manifests/password.pp
PLUGINS=lib/puppet/parser/functions/op_fetch_key.rb lib/puppet/parser/functions/password_age.rb lib/puppet/parser/functions/op_fetch_cert.rb lib/puppet/parser/functions/op_setpass.rb lib/puppet/parser/functions/op_check.rb lib/puppet/parser/functions/generate_password.rb lib/facter/passwords.rb

all: $(MANIFESTS) $(PLUGINS) 1password.rb
	@puppet-module build
	@echo Done
