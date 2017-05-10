# Class: ffce::security
# ===========================
#
# Basic configuration of the security parameters for the system. Defines
# some defaults for the services that are running on a system, always, and
# sets up the corresponding basic states.
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
#    class { 'security':
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
class ffce::security (
) inherits ffce::params {
  # Require package sources.
  include ffce::apt

  # Configure network time protocol for hosts in the Freifunk network.
  # Currently, this synchronizes to outside hosts, but generally, the
  # NTP synchronization should also be done between hosts that are
  # managed by the puppet freifunk.
  class { ntp:
    servers => ['0.debian.pool.ntp.org', '1.debian.pool.ntp.org'],
    driftfile => '/var/lib/ntp/ntp.drift',
    package_ensure => latest,
    restrict => [
      'default kod nomodify notrap nopeer noquery',
      '-6 default kod nomodify notrap nopeer noquery',
      '127.0.0.1',
      '::1'
    ],
  }

  # Enable standard configuration for OpenSSH which allows management
  # accesses to the current host.
  class { ssh:
    version => latest,
    server_options => {
      'PermitRootLogin' => no,
    },
  }
}
