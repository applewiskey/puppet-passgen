# this must be included in master manifest
#
#   include passgen
#
class passgen {
  unless versioncmp($::clientversion, '4') < 0 {
    package { 'ps-gem-chronic_duration':
      ensure   => present,
      name     => 'chronic_duration',
      provider => puppetserver_gem,
    }
  }
  package { 'gem-chronic_duration':
    ensure   => present,
    name     => 'chronic_duration',
    provider => gem,
  }
  file { '/srv/passgen':
    ensure  => directory,
    recurse => true,
    owner   => 'puppet',
    group   => 'puppet',
    mode    => '0700',
  }
}

class passgen::vault (
  $vault_options = {},
) {
  unless versioncmp($::clientversion, '4') < 0 {
    package { 'ps-gem-vault':
      ensure   => '0.6.0',
      name     => 'vault',
      provider => puppetserver_gem,
    }
  }
  file { '/srv/puppet/vault':
    ensure => directory,
    mode   => '0600',
    owner  => 'puppet',
    group  => 'puppet'
  }
  file { '/srv/puppet/vault/passgen_vault_options':
    ensure    => present,
    mode      => '0600',
    owner     => 'puppet',
    group     => 'puppet',
    content   => inline_template('<%= @vault_options.to_yaml %>'),
    show_diff => false,
  }
}
