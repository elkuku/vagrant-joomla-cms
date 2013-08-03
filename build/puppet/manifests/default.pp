Exec {
path => ['/bin', '/sbin', '/usr/bin', '/usr/sbin'],
}

exec { 'apt-get update':
	path => '/usr/bin',
}

include joomla

class joomla {
$dir = '/var/www/joomla-cms'
$path = 'http://joomlacode.org/gf/download/frsrelease/18622/83486'
$file = 'Joomla_3.1.5-Stable-Full_Package.tar.gz'
exec { 'setup':
	creates => "${dir}",
	command => "mkdir ${dir} && cd ${dir} && wget ${path}/${file} && tar xzf ${file} && rm ${file} && chmod 0777 -R ${dir}",
	require => Package['php5', 'apache2'],
	notify  => Service['apache2'],
}
}

include system

class system {
	package { ['vim', 'curl']:
		ensure => installed,
		require => Exec['apt-get update'],
	}
}

include apache

class apache {
	package { 'apache2':
		name => 'apache2-mpm-prefork',
		ensure => installed,
		require => Exec['apt-get update'],
	}

	service { 'apache2':
		ensure  => running,
		require => Package['apache2'],
	}

	exec { 'enable-mod_rewrite':
		require => Package['apache2'],
		before => Service['apache2'],
		command => '/usr/sbin/a2enmod rewrite'
	}

	# OK, this is ugly... wtf
	exec { 'copy-sites-enabled':
		require => Package['apache2'],
		before => Service['apache2'],
		command => 'rm /etc/apache2/sites-enabled/000-default && cp /vagrant/build/puppet/files/000-default /etc/apache2/sites-enabled/'
	}
}

include mysql

class mysql {
	package {
		['mysql-server', 'mysql-client']:
		ensure  => installed,
		require => Exec['apt-get update'],
	}

	service { 'mysql':
		ensure  => 'running',
		require => Package['mysql-server'],
	}
}

include php

class php {
	package { [
		'php5',
		'php5-mysql',
		'php5-curl'
	]:
		ensure  => 'installed',
		require => Exec['apt-get update'],
	}
}
