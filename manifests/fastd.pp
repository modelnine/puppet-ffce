# Class: ffce::fastd
# ===========================
#
# Setup of a fastd instance with a specified name; the instance is
# configured with a default config file and can attach up and down
# scripts which come from a separate template. The public keys
# of the instances are collected as remote resources.
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
class ffce::fastd (
  String $package_ensure = 'installed',
  String $service_ensure = 'running',
  Boolean $service_enable = true,
) inherits ffce::params {
  # Require repositories.
  include ffce::apt

  # Set up package for fastd; this is used by the instance of a fastd
  # tunnel to reference the installed package. This package is loaded
  # from the ffce package repositories, normally coming from backports.
  package {
    'fastd': ensure => $package_ensure;
    'batctl': ensure => $package_ensure;
  }

  # Create the service to bind config file and key to.
  service { 'fastd':
    ensure => $service_ensure,
    enable => $service_enable,
    hasrestart => true,
    hasstatus => true,
  }
}
