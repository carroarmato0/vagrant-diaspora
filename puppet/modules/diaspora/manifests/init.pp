class diaspora(
  $ca_certificates = '/etc/pki/tls/certs/ca-bundle.crt',
  $rails_environment = 'production',
  $req_ssl = 'false',
  $diaspora_home = '/var/lib/diaspora',
  $db_user ='diaspora',
  $db_password = 'diaspora',
) {
  class { 'postgresql::server': }
  class { '::rvm': }
  include '::gnupg'

  user { 'diaspora':
    ensure     => present,
    home       => $diaspora_home,
    managehome => true,
    system     => true,
  }
  rvm::system_user { 'diaspora': }
  rvm_system_ruby { 'ruby-2.1':
      ensure      => 'present',
      default_use => false,
  }
  package { 'git':
    ensure => installed,
  } ->
  vcsrepo { "${diaspora_home}/diaspora":
    ensure   => present,
    provider => git,
    source   => 'https://github.com/diaspora/diaspora.git',
    user     => 'diaspora',
  }
  file { "${diaspora_home}/diaspora/config/database.yml":
    ensure  => file,
    content => template('diaspora/database.yml.erb'),
  }
  file { "${diaspora_home}/diaspora/config/diaspora.yml":
    ensure  => file,
    content => template('diaspora/diaspora.yml.erb'),
  }
  rvm_gem { 'ruby-2.1/bundler':
      ensure  => present,
      require => Rvm_system_ruby['ruby-2.1'],
  }
  rvm_gem { 'ruby-2.1/rake':
      ensure  => present,
      require => Rvm_system_ruby['ruby-2.1'],
  }
  rvm_wrapper {'bundle':
    target_ruby => 'ruby-2.1',
    prefix      => 'diaspora',
    ensure      => present,
    require     => Rvm_gem['ruby-2.1/bundler'],
  }
  exec { 'diaspora_bundle install --without test development':
    path        => '/usr/local/rvm/bin/:/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    cwd         => "${diaspora_home}/diaspora",
    user        => 'diaspora',
    timeout     => 0,
    environment => [
      "RAILS_ENV=${rails_environment}",
      'DB=postgres',
    ],
    # refreshonly => true,
  }
}
