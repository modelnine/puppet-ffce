# Class: ffce::apt
# ===========================
#
# Default list of package sources and packages to install for a host in
# the Freifunk Celle space. This is highly adapted for Debian (i.e. the
# apt-sources are Debian specific), and will not work on another base
# system.
#
# Parameters
# ----------
#
# Parameters which control the setup of the apt repositories for the
# configured system.
#
# * `distribution`
# Debian distribution (i.e., version) to use for the base system,
# defaults to Jessie.
#
# * `zabbixver`
# Zabbix version to use, is retrieved from the Zabbix central repository
# and defaults to 3.2.
#
# * `backports`
# Packages to always pull from backports by setting a corresponding pin.
# The dependencies might have to be manually added here, too.
#
# * `testing`
# Packages to always pull from testing by setting a corresponding pin.
# The dependencies might have to be manually added here, too.
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
#    class { 'packages':
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
class ffce::apt (
  String $distribution = $ffce::params::distribution,
  String $zabbixver = $ffce::params::zabbixver,
  Array[String] $backports = $ffce::params::backports,
  Array[String] $testing = $ffce::params::testing,
) inherits ffce::params {
  # Define generic apt resources; this makes sure that the apt repositories
  # are appropriately updated for the system.
  class { apt:
    update => {
      frequency => 'daily',
    },
    purge => {
      'sources.list' => true,
      'sources.list.d' => true,
      'preferences' => true,
      'preferences.d' => true,
    },
  }

  # Pins for the distributions added here. Testing is lower priority than stable,
  # but auto-updates. Stable is preferred except for zabbix in the default case,
  # where we use the repositories by Zabbix inc.
  apt::pin { "${distribution}":
    ensure => present,
    priority => 900,
    originator => 'Debian',
    codename => "${distribution}",
  }
  apt::pin { "${distribution}-backports":
    ensure => present,
    priority => 800,
    originator => 'Debian Backports',
    codename => "${distribution}-backports",
  }
  apt::pin { "${distribution}-updates":
    ensure => present,
    priority => 900,
    originator => 'Debian',
    codename => "${distribution}-updates",
  }
  apt::pin { "${distribution}-security":
    ensure => present,
    priority => 900,
    originator => 'Debian',
    codename => "${distribution}",
    label => 'Debian-Security',
  }
  apt::pin { 'testing':
    ensure => present,
    priority => 700,
    originator => 'Debian',
    release => 'testing',
  }
  apt::pin { 'testing-security':
    ensure => present,
    priority => 700,
    originator => 'Debian',
    release => 'testing',
    label => 'Debian-Security',
  }
  apt::pin { 'zabbix':
    ensure => present,
    packages => 'zabbix-agent zabbix-server-pgsql zabbix-sender zabbix-proxy-pgsql zabbix-java-gateway zabbix-get zabbix-frontend-php',
    priority => 1000,
    originator => 'Zabbix',
    codename => "${distribution}",
  }

  # Set up pins for the backports and testing packages that are supposed to
  # be pulled in for the current host.
  if !empty($backports) {
    apt::pin { 'backports-packages':
      ensure => present,
      packages => join($backports, ' '),
      priority => 1000,
      originator => 'Debian Backports',
      codename => "${distribution}-backports",
    }
  }
  if !empty($testing) {
    apt::pin { 'testing-packages':
      ensure => present,
      packages => join($testing, ' '),
      priority => 1000,
      originator => 'Debian',
      release => 'testing',
    }
  }

  # Distributions to load.
  apt::source { "${distribution}":
    location => 'http://ftp.de.debian.org/debian/',
    release => "${distribution}",
    repos => 'main contrib non-free',
    include => {
      'src' => true,
      'deb' => true,
    },
  }
  apt::source { "${distribution}-backports":
    location => 'http://ftp.de.debian.org/debian/',
    release => "${distribution}-backports",
    repos => 'main contrib non-free',
    include => {
      'src' => true,
      'deb' => true,
    },
  }
  apt::source { "${distribution}-updates":
    location => 'http://ftp.de.debian.org/debian/',
    release => "${distribution}-updates",
    repos => 'main contrib non-free',
    include => {
      'src' => true,
      'deb' => true,
    },
  }
  apt::source { "${distribution}-security":
    location => 'http://security.debian.org/',
    release => "${distribution}/updates",
    repos => 'main contrib non-free',
    include => {
      'src' => true,
      'deb' => true,
    },
  }
  apt::source { 'testing':
    location => 'http://ftp.de.debian.org/debian/',
    release => 'testing',
    repos => 'main contrib non-free',
    include => {
      'src' => true,
      'deb' => true,
    },
  }
  apt::source { 'testing-security':
    location => 'http://security.debian.org/',
    release => 'testing/updates',
    repos => 'main contrib non-free',
    include => {
      'src' => true,
      'deb' => true,
    },
  }
  apt::source { 'zabbix':
    location => "http://repo.zabbix.com/zabbix/${zabbixver}/debian",
    release => "${distribution}",
    repos => 'main contrib non-free',
    include => {
      'deb' => true,
    },
  }

  # Load external signing keys for repos where required. Currently,
  # this only affects the Zabbix repository.
  apt::key { 'zabbix':
    id => 'A1848F5352D022B9471D83D0082AB56BA14FE591',
    server => 'keys.gnupg.net',
  }

  # Bind all updates to happen after apt update has run. This can build
  # circular dependencies, so make sure that you test for that.
  Class['apt::update'] -> Package <| ensure != 'purged' |>

  # Update package manager system on the current host, and also allow
  # packages to be retrieved over https.
  package {
    'apt': ensure => latest;
    'aptitude': ensure => latest;
    'apt-show-versions': ensure => latest;
    'apt-transport-https': ensure => latest;
  }

  # Load some default packages which are supposed to be installed on all
  # Freifunk Celle hosts and/or which should be kept at latest version
  # on all systems.
  package {
    'linux-image-amd64': ensure => latest;
    'firmware-linux-free': ensure => latest;
    'mtr': ensure => latest;
    'tcpdump': ensure => latest;
    'emacs': ensure => latest;
    'sudo': ensure => latest;
    'logwatch': ensure => latest;
    'bridge-utils': ensure => installed;
    'vlan': ensure => installed;
    'ifenslave': ensure => installed;
    'git': ensure => installed;
    'screen': ensure => installed;
  }

  # Remove unnecessary default packages for Debian installations;
  # we offer no UNIX-RPC services, and rdnssd is only required for
  # dynamic uplinks, which there are none.
  package {
    'rndssd': ensure => purged;
    'rpcbind': ensure => purged;
  }
}
