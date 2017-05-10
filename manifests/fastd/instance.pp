# Resource: ffce::fastd::instance
# ===========================
#
# Definition of a fastd instance which sets up the corresponding files for
# the VPN configuration of a fastd host.
#
# Parameters
# ----------
#
# Document parameters here.
#
# * `sample parameter`
# Explanation of what this parameter affects and what it defaults to.
# e.g. "Specify one or more upstream ntp servers as an array."
#
# Variables
# ----------
#
# Here you should define a list of variables that this module would require.
#
# * `sample variable`
#  Explanation of how this variable affects the function of this class and if
#  it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#  External Node Classifier as a comma separated list of hostnames." (Note,
#  global variables should be avoided in favor of class parameters as
#  of Puppet 2.6.)
#
# Examples
# --------
#
# @example
#    class { 'mail':
#      servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#    }
#
# Authors
# -------
#
# Heiko Wundram <heiko.wundram@ffce.de>.
#
# Copyright
# ---------
#
# Copyright 2017 Freifunk Celle.
#
define ffce::fastd::instance (
  Integer $port,
  String $ifname = $title,
  Array[String] $methods = ['salsa2012+umac'],
  Integer $mtu = 1500,
  String $upscript = nil,
  String $downscript = nil,
) {
  # Include the fastd default configuration.
  include ffce::fastd
  include ffce::params

  # Set up directory structure for fastd instance and create config
  # files based on the fastd template.
  file { "/etc/fastd/${title}":
    ensure => directory,
    owner => root,
    group => root,
    mode => '0755',
    require => Package['fastd'],
  } ->
  file { "/etc/fastd/${title}/peers":
    ensure => directory,
    owner => root,
    group => root,
    mode => '0755',
  }

  # When there is an up-script, write that out.
  if $upscript != nil {
    file { "/etc/fastd/${title}/fastd-up":
      ensure => file,
      owner => root,
      group => root,
      mode => '0755',
      content => $upscript,
      require => File["/etc/fastd/${title}"],
      notify => Service['fastd'],
    }
  }
  if $downscript != nil {
    file { "/etc/fastd/${title}/fastd-down":
      ensure => file,
      owner => root,
      group => root,
      mode => '0755',
      content => $downscript,
      require => File["/etc/fastd/${title}"],
      notify => Service['fastd'],
    }
  }

  # Create the actual configuration.
  file { "/etc/fastd/${title}/fastd.conf":
    ensure => file,
    owner => root,
    group => root,
    mode => '0644',
    content => epp('ffce/fastd.conf.epp', {
      title => $title,
      port => $port,
      ifname => $ifname,
      methods => $methods,
      mtu => $mtu,
      upscript => $upscript,
      downscript => $downscript,
    }),
    require => File["/etc/fastd/${title}"],
    notify => Service['fastd'],
  } ->
  exec { "fastd_${title}_keygen":
    command => "key=`fastd --generate-key --machine-readable`; echo \"secret \\\"\$key\\\";\" > /etc/fastd/${title}/fastd.secret.conf",
    provider => shell,
    creates => "/etc/fastd/${title}/fastd.secret.conf",
    timeout => 1800,
    notify => Service['fastd'],
  }
}
