class diaspora(
  $public_url = 'diaspora.example.com',
  $ca_certificates = '/etc/pki/tls/certs/ca-bundle.crt',
  $rails_environment = 'production',
  $req_ssl = 'false',
  $diaspora_home = '/var/lib/diaspora',
  $db_user ='diaspora',
  $db_password = 'diaspora',
  $db_name = 'diaspora',
) {
  class { 'postgresql::server': }
  postgresql::server::db {$db_name:
    user     => $db_user,
    password => postgresql_password($db_user, $db_password),
  }

  class { 'redis':;
  }


  class { '::rvm': }
  include '::gnupg'

  # needed for some rvm shit
  yumrepo { 'epel':
    descr => 'Extra Packages for Enterprise Linux 7 - $basearch',
    mirrorlist => 'https://mirrors.fedoraproject.org/metalink?repo=epel-7&arch=$basearch',
    enabled => '1',
  } ->
  package { 'nodejs':
    ensure => installed,
  }

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
      require     => Package['nodejs'],
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
  Rvm_gem <| |> -> Rvm_wrapper <| |>
  rvm_wrapper {'bundle':
    target_ruby => 'ruby-2.1',
    prefix      => 'diaspora',
    ensure      => present,
  }
  rvm_wrapper {'rake':
    target_ruby => 'ruby-2.1',
    prefix      => 'diaspora',
    ensure      => present,
  }
  package{'postgresql-devel':
    ensure => installed,
  } ->
  exec { 'diaspora_bundle install --without test development --with postgresql':
    path        => '/usr/local/rvm/bin/:/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    cwd         => "${diaspora_home}/diaspora",
    user        => 'diaspora',
    timeout     => 0,
    environment => [
      "RAILS_ENV=${rails_environment}",
      'DB=postgres',
    ],
    # refreshonly => true,
    require     => Rvm_wrapper['bundle'],
  } ->
  exec { 'diaspora_rake db:schema:load':
    path        => '/usr/local/rvm/bin/:/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    cwd         => "${diaspora_home}/diaspora",
    user        => 'diaspora',
    timeout     => 0,
    environment => [
      "RAILS_ENV=${rails_environment}",
      'DB=postgres',
    ],
    # refreshonly => true,
    require     => [
      Rvm_wrapper['rake'],
      Postgresql::Server::Db[$db_name],
    ],
  }
  exec { 'diaspora_rake assets:precompile':
    path        => '/usr/local/rvm/bin/:/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    cwd         => "${diaspora_home}/diaspora",
    user        => 'diaspora',
    timeout     => 0,
    environment => [
      "RAILS_ENV=${rails_environment}",
      'DB=postgres',
    ],
    # refreshonly => true,
    require     => Rvm_wrapper['rake'],
  }


}
