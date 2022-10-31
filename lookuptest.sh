#!/usr/bin/bash
# vim:ts=4
#
# NOTE - this test will ensure a valid lookup function
# If the lookup is not valid, then all sorts of horrible stuff will happen as
# ALL OF HEIRA stops working

# %{lookup('onepassword::sjs@test1')}
# %{lookup('onepassword::Playpen::sjs@test1')}
# %{lookup('onepassword::*::sjs@test1')}
# %{lookup('onepassword::Playpen::fuzzy match::false')}

HIERADATA=/home/steves/puppet/hiera
TESTHOST=xmdwfd01
TESTROLE=hosting_wfd
TESTSITE=xmd
TESTKEY="onepassword::sjs@test1"
# BASE=/etc/puppetlabs
BASE=/home/steves/.puppetlabs
ENVDIR=$BASE/etc/code/environments
ENVIRONMENT=test
HIERAFILE=$ENVDIR/$ENVIRONMENT/hiera.yaml
MODDIR=$ENVDIR/$ENVIRONMENT/modules
PKCSPUB=/home/steves/config/puppet-public.pem
PKCSPVT=/home/steves/config/puppet-private.pem
LIBCACHEDIR=/opt/puppetlabs/puppet/cache
OPCONFIG=$BASE/etc/puppet/1password.yaml

FACTS=/tmp/facts.$$
PUPPET=/opt/puppetlabs/puppet/bin/puppet
GEM=/opt/puppetlabs/puppet/bin/gem

makefacts()
{
  cat  >$FACTS <<_END_
fqdn: $TESTHOST.smxemail.com
domain: smxemail.com
hostname: $TESTHOST
clientcert: $TESTHOST.smxemail.com
role: $TESTROLE
site: $TESTSITE
os:
  name: CentOS
  release:
    major: 7
test: true
_END_
  
}
rmfacts()
{
  rm -f $FACTS
}
makehieraconfig()
{
  echo Making hieraconfig
  cat >$HIERAFILE <<_END_
version: 5
defaults:
  datadir: $HIERADATA
  data_hash: yaml_data
hierarchy:
  - name: "Test data"
    datadir: "/tmp"
    paths:
      - "test.yaml"
  - name: "YAML data"
    paths:
      - "hosts/%{::fqdn}.yaml"
      - "sites/%{::site}/roles/%{::role}.yaml"
      - "roles/%{::role}.yaml"
      - "sites/%{::site}/os/%{facts.os.name}%{facts.os.release.major}.yaml"
      - "sites/%{::site}/%{::site}.yaml"
      - "os/%{facts.os.name}%{facts.os.release.major}.yaml"
      - "common.yaml"
  - name: "eYAML data (encrypted)"
    paths:
      - "hosts/%{::fqdn}.eyaml"
      - "sites/%{::site}/roles/%{::role}.eyaml"
      - "roles/%{::role}.eyaml"
      - "sites/%{::site}/os/%{facts.os.name}%{facts.os.release.major}.eyaml"
      - "sites/%{::site}/%{::site}.eyaml"
      - "os/%{facts.os.name}%{facts.os.release.major}.eyaml"
      - "common.eyaml"
    lookup_key: eyaml_lookup_key
    options:
      pkcs7_private_key: $PKCSPVT
      pkcs7_public_key: $PKCSPUB
  - name: "OnePassword integration"
    lookup_key: "op::hiera"
    options:
      keybase: "onepassword"
      exact: true
      cache: false
_END_
cat >/tmp/test.yaml <<_END_
testkeya: testvalue
testkeyb: "%{lookup('onepassword::sjs@test1')}"
_END_
}
makeopconfig()
{
  echo Making onepassword config
  cat >$OPCONFIG <<_END_
# Test key for Playpen only
# Replace with real key if you want to test against production vaults
apikey: eyJhbGciOiJFUzI1NiIsImtpZCI6IjJ4Y3FvdmF6cTNyZmltbzZnbWRzZnB5MnFtIiwidHlwIjoiSldUIn0.eyIxcGFzc3dvcmQuY29tL2F1dWlkIjoiRkJJREdPVUVKNUdBTkFXVFZSS0RHRjNPNk0iLCIxcGFzc3dvcmQuY29tL3Rva2VuIjoickVNSUlzRUdXQW9GSjd6ZjZwWnNmdmprU0daZ1RSVXEiLCIxcGFzc3dvcmQuY29tL2Z0cyI6WyJ2YXVsdGFjY2VzcyJdLCIxcGFzc3dvcmQuY29tL3Z0cyI6W3sidSI6Im50dW01dGhiY29mdGNrYng1bGhtbW4yNzZxIiwiYSI6NDk2fV0sImF1ZCI6WyJjb20uMXBhc3N3b3JkLmNvbm5lY3QiXSwic3ViIjoiTU9CT1lNMkVOSkZVWkFKTDVRV1FOR0dGTkUiLCJpYXQiOjE2NTI5Mjg2OTgsImlzcyI6ImNvbS4xcGFzc3dvcmQuYjUiLCJqdGkiOiJyd3Ztdmp5Znhoejc1d2Vwb3p3ZWxmcGNqdSJ9.OdGwlQnbadUw0s9mmdl9kDoghGgQdQsgn7kIL3PEK1uEG4SEIv_H8m7fys-8zxgZk-Jx2JxxvxEpaWA7xizlNw

endpoint: onepassword.az1.smxk8s.net
default_vault: Playpen
_END_
}

if [ "$1" != "" ]; then
  TESTKEY=$1
fi

if [ `$GEM list | egrep -c op_connect` -lt 1 ]
then
  echo installing op_connect gem
  sudo $GEM install op_connect
fi

echo Copying module
[ -d $MODDIR/op ] || mkdir -p $MODDIR/op
cp -r * $MODDIR/op/
if [ -w $LIBCACHEDIR ]; then
  echo Updating local cached functions
  cp -r lib $LIBCACHEDIR
  chmod -R a+w $LIBCACHEDIR
else
  echo Unable to write to $LIBCACHEDIR
#  exit 1
fi
[ -d `dirname $OPCONFIG` ] || mkdir -p `dirname $OPCONFIG`
[ -f $OPCONFIG ] || makeopconfig
[ -w `dirname $HIERAFILE` ] && makehieraconfig
makefacts

for TESTKEY in \
 'puppet::version' \
 'onepassword::sjs@test1' \
 'onepassword::Playpen::sjs@test1' \
 'onepassword::*::sjs@test1' \
 'onepassword::Playpen::fuzzy match::false' \
 'testkeya' 'testkeyb'
do

echo Retrieving $TESTKEY for $TESTHOST
export SSL_NO_VERIFY=1
$PUPPET lookup  --environment $ENVIRONMENT \
  --node $TESTHOST --facts $FACTS  $TESTKEY
rv=$?
if [ $rv -ne 0 ]; then
  echo "EXIT STATUS: $rv"
  exit 1
fi

done

rmfacts

exit 0
