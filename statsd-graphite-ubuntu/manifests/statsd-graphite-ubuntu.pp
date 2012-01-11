Exec {
  path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ]
}

class apache {
  package { "apache2":
    ensure => present,
  }

  service { "apache2":
    enable  => true,
    ensure  => running,
    require => Package["apache2"],
  }
}

class python::pip {
  package { "build-essential":
    ensure => present,
  }

  package { "python-dev":
    ensure  => present,
    require => Package["build-essential"],
  }

  package { "python-pip":
    ensure  => present,
    require => Package["python-dev"],
  }
}

class python::memcached {
  package { "memcached":
    ensure => present,
  }

  package { "python-memcache":
    ensure  => present,
    require => Package["memcached"],
  }
}

class python::django {
  package { "python-django":
    ensure => present,
  }

  package { "python-django-tagging":
    ensure  => present,
    require => Package["python-django"],
  }
}

class python::web {
  include apache

  package { "libapache2-mod-python":
    ensure  => present,
    require => Package["apache2"],
    notify  => Service["apache2"],
  }

  package { "libapache2-mod-wsgi":
    ensure  => present,
    require => Package["apache2"],
    notify  => Service["apache2"],
  }
}

class graphite {
  include python::pip
  include python::memcached
  include python::django
  include python::web

  package { ["python-cairo", "python-ldap"]:
    ensure => present,
  }

  package { "simplejson":
    ensure   => present,
    provider => "pip",
    require  => Package["python-pip"],
  }

  package { "carbon":
    ensure   => present,
    provider => "pip",
    require  => Package["python-pip"],
  }

  package { "whisper":
    ensure   => present,
    provider => "pip",
    require  => Package["carbon"],
  }

  package { "graphite-web":
    ensure   => present,
    provider => "pip",
    require  => [
      Package["whisper"],
      Package["simplejson"],
      Package["python-ldap"],
      Package["python-cairo"],
      Package["python-memcache"],
      Package["python-django-tagging"],
    ],
  }

  file { "/opt/graphite/conf/carbon.conf":
    ensure  => file,
    source  => "/opt/graphite/conf/carbon.conf.example",
    require => Package["graphite-web"],
  }

  file { "/opt/graphite/conf/storage-schemas.conf":
    ensure  => file,
    source  => "/vagrant/files/storage-schemas.conf",
    require => Package["graphite-web"],
  }

  file { "/opt/graphite/conf/graphite.wsgi":
    ensure  => file,
    source  => "/opt/graphite/conf/graphite.wsgi.example",
    mode    => 0755,
    require => Package["graphite-web"],
  }

  file { "/opt/graphite/webapp/graphite/initial_data.json":
    ensure  => file,
    source  => "/vagrant/files/initial_data.json",
    require => Package["graphite-web"],
  }

  exec { "setup-graphite-database":
    command   => "python manage.py syncdb --noinput",
    cwd       => "/opt/graphite/webapp/graphite",
    creates   => "/opt/graphite/storage/graphite.db",
    logoutput => on_failure,
    require   => [
      File["/opt/graphite/conf/carbon.conf"],
      File["/opt/graphite/conf/storage-schemas.conf"],
      File["/opt/graphite/webapp/graphite/initial_data.json"],
    ],
  }

  file { "/opt/graphite/storage":
    ensure  => directory,
    group   => "www-data",
    owner   => "www-data",
    recurse => true,
    require => [Package["apache2"], Exec["setup-graphite-database"]],
  }

  file { "/var/run/wsgi":
    ensure  => directory,
    group   => "www-data",
    owner   => "www-data",
    mode    => 0755,
    require => Package["apache2"],
  }

  file { "/etc/apache2/sites-available/graphite-vhost.conf":
    ensure  => file,
    source  => "/vagrant/files/graphite-vhost.conf",
    require => [
      File["/var/run/wsgi"],
      File["/opt/graphite/storage"],
      File["/opt/graphite/conf/graphite.wsgi"],
      Package["libapache2-mod-python"],
      Package["libapache2-mod-wsgi"],
    ],
  }

  file { "/etc/apache2/sites-enabled/graphite-vhost.conf":
    ensure  => link,
    target  => "/etc/apache2/sites-available/graphite-vhost.conf",
    require => File["/etc/apache2/sites-available/graphite-vhost.conf"],
    notify  => Service["apache2"],
  }

  file { "/etc/init/carbon-cache.conf":
    ensure  => file,
    source  => "/vagrant/files/carbon-cache.conf",
    mode    => 0644,
    require => [
      File["/opt/graphite/storage"],
      File["/etc/apache2/sites-enabled/graphite-vhost.conf"],
    ],
  }

  exec { "start-carbon-cache":
    command   => "service carbon-cache restart",
    require   => File["/etc/init/carbon-cache.conf"],
    logoutput => on_failure,
  }
}

class statsd {
  package { ["nodejs", "git"]:
    ensure => present,
  }

  file { "/opt":
    ensure => directory,
  }

  exec { "clone-statsd":
    command   => "git clone git://github.com/etsy/statsd.git",
    cwd       => "/opt",
    creates   => "/opt/statsd",
    require   => [Package["git"], File["/opt"]],
    logoutput => on_failure,
  }

  file { "/opt/statsd/local.js":
    ensure  => file,
    source  => "/vagrant/files/local.js",
    require => Exec["clone-statsd"],
  }

  file { "/etc/init/etsy-statsd.conf":
    ensure  => file,
    source  => "/vagrant/files/etsy-statsd.conf",
    mode    => 0644,
    require => [File["/opt/statsd/local.js"], Package["nodejs"]],
  }

  exec { "start-etsy-statsd":
    command   => "service etsy-statsd restart",
    require   => File["/etc/init/etsy-statsd.conf"],
    logoutput => on_failure,
  }
}

include graphite
include statsd
