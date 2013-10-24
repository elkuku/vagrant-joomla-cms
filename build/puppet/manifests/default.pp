Exec {
	path => ['/bin', '/sbin', '/usr/bin', '/usr/sbin'],
}

exec { 'apt-get update':
	path => '/usr/bin',
}

#include joomla-release

class joomla-release {
	$dir = '/home/vagrant/server/htdocs/joomla-cms'
	$path = 'http://joomlacode.org/gf/download/frsrelease/18622/83486'
	$file = 'Joomla_3.1.5-Stable-Full_Package.tar.gz'
	exec { 'setup':
		creates => "${dir}",
		command => "mkdir ${dir} && cd ${dir} && wget ${path}/${file} && tar xzf ${file} && rm ${file} && chmod 0777 -R ${dir}",
		require => Package['php5', 'apache2'],
		notify  => Service['apache2'],
	}
}

include joomla-git

class joomla-git {
	$dir = '/home/vagrant/server'
	$repo = 'https://github.com/joomla/joomla-cms.git'
	package { ['git-core']:
		ensure => installed,
		require => Exec['apt-get update'],
	}

	file {
		[
			"/home/vagrant/server",
			"/home/vagrant/server/htdocs",
			"/home/vagrant/server/logs"
		]:
		ensure => "directory",
	}

	exec { 'setup':
		creates => "${dir}/htdocs/joomla-cms",
		command => "echo 'cloning...' && cd ${dir}/htdocs && git clone ${repo} && chown -R vagrant:vagrant ${dir}",
		require => Package['php5', 'apache2', 'git-core'],
		notify  => Service['apache2'],
		timeout => 0,
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

	exec { 'enable-required-modules':
		require => Package['apache2'],
		before => Service['apache2'],
		command => 'a2enmod rewrite php5'
	}

	file { 'joomla-cms-site':
		ensure => present,
		require => Package['apache2'],
		path => '/etc/apache2/sites-available/site-joomla-cms',
		source => '/vagrant/build/puppet/files/site-joomla-cms';
	}

	exec { 'copy-sites-available':
		require => [
			Package['apache2'],
			File['joomla-cms-site']
		],
		before => Service['apache2'],
		command => 'a2dissite 000-default && a2ensite site-joomla-cms'
	}

	exec { 'change-apache-user':
		require => [
			Package['apache2']
		],
		before => Service['apache2'],
		command => "sed -i 's/www-data/vagrant/g' /etc/apache2/envvars && chown vagrant:vagrant /var/lock/apache2"
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
	exec { 'modify-repos-for-php55':
		command => 'cat /vagrant/build/puppet/files/dotdeb-php55-sources.list >> /etc/apt/sources.list && wget http://www.dotdeb.org/dotdeb.gpg && cat dotdeb.gpg | apt-key add - && apt-get update && rm dotdeb.gpg',
	}

	package { [
		'php5',
		'php5-cli',
		'php5-curl',
		'php5-mysql',
		'php5-xdebug'
	]:
		ensure  => 'installed',
		require => [
			Package['apache2'],
			Exec[
				'apt-get update',
				'modify-repos-for-php55'
			]
		],
	}

#	file { '/etc/php5/apache2filter/conf.d/21-xdebug.ini':
	file { '/etc/php5/apache2/conf.d/21-xdebug.ini':
#	file { '/etc/php5/conf.d/21-xdebug.ini':
		ensure => present,
		require => Package['php5'],
		source => '/vagrant/build/puppet/files/21-xdebug.ini';
	}

#	file { '/etc/php5/apache2filter/conf.d/666-php.ini':
	file { '/etc/php5/apache2/conf.d/666-php.ini':
#	file { '/etc/php5/conf.d/666-php.ini':
		ensure => present,
		require => Package['php5'],
		source => '/vagrant/build/puppet/files/666-php.ini';
	}
}
