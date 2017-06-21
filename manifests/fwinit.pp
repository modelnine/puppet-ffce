# Class: ffce::fwinit
# ===========================
#
# Default firewall configuration for a host in the Freifunk Celle domain;
# this sets up the generic firewall rules which allow SSH management but
# nothing else.
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
class ffce::fwinit (
) inherits ffce::params {
  # Enable firewall config.
  Firewall {
    require => undef,
  }

  # Default firewall rules for all hosts for IPv4.
  firewall { '000 accept all v4 to lo interface':
    proto => all,
    iniface => lo,
    action => accept,
  } ->
  firewall { '001 accept all v4 icmp':
    proto => icmp,
    action => accept,
  } ->
  firewall { '002 accept v4 related established rules':
    proto => all,
    state => ['RELATED', 'ESTABLISHED'],
    action => accept,
  } ->
  firewall { '003 accept ssh on all v4 interfaces':
    proto => tcp,
    dport => 22,
    state => ['NEW'],
    action => accept,
  } ->
  firewall { '004 accept established related v4':
    chain => 'FORWARD',
    proto => all,
    state => ['RELATED', 'ESTABLISHED'],
    action => accept,
  }

  # Configure default policy for generic chains.
  firewallchain { 'INPUT:filter:IPv4':
    ensure => present,
    policy => drop,
    before => undef,
  }
  firewallchain { 'FORWARD:filter:IPv4':
    ensure => present,
    policy => drop,
    before => undef,
  }

  # Default firewall rules for all hosts for IPv4.
  firewall { '000 accept all v6 to lo interface':
    proto => all,
    iniface => lo,
    action => accept,
    provider => ip6tables,
  } ->
  firewall { '001 accept all v6 icmp':
    proto => 'ipv6-icmp',
    action => accept,
    provider => ip6tables,
  } ->
  firewall { '002 accept v6 related established rules':
    proto => all,
    state => ['RELATED', 'ESTABLISHED'],
    action => accept,
    provider => ip6tables,
  } ->
  firewall { '003 accept ssh on all v6 interfaces':
    proto => tcp,
    dport => 22,
    state => ['NEW'],
    action => accept,
    provider => ip6tables,
  } ->
  firewall { '004 accept established related v6':
    chain => 'FORWARD',
    proto => all,
    state => ['RELATED', 'ESTABLISHED'],
    action => accept,
    provider => ip6tables,
  }

  # Configure default policy for generic IPv6 chains.
  firewallchain { 'INPUT:filter:IPv6':
    ensure => present,
    policy => drop,
    before => undef,
  }
  firewallchain { 'FORWARD:filter:IPv6':
    ensure => present,
    policy => drop,
    before => undef,
  }
}
