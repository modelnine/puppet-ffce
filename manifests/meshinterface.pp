# Class: ffce::meshinterface
# ===========================
#
# Mesh interface for a Freifunk Celle node, specified with a corresponding
# fastd tunnel and an IP address to assign to the specific interface.
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
define ffce::meshinterface (
  String $ipaddress,
  String $netmask,
  String $ip6address,
  String $net6mask,
  Integer $vpnport,
  String $ifname = $title,
  String $localif = 'none',
  Integer $mtu = 1500,
  String $meshvpnmac = nil,
  String $meshserver = '20mbit/20mbit',
  Integer $meshmtu = 1406,
) {
  # Load parameters.
  include ffce::params

  # Set up local network interface if appropriate.
  if $localif != 'none' {
    network::interface { $localif:
      method => manual,
    }
  }

  # Create network interface for the corresponding mesh interface,
  # setting up the bridge and defining the corresponding internal
  # state.
  network::interface { "${ifname}_4":
    interface => $ifname,
    ipaddress => $ipaddress,
    netmask => $netmask,
    bridge_stp => off,
    bridge_waitport => 0,
    bridge_fd => 0,
    bridge_ports => [$localif],
    require => Package['bridge-utils'],
  } ->
  network::interface { "${ifname}_6":
    interface => $ifname,
    family => 'inet6',
    ipaddress => $ip6address,
    netmask => $net6mask,
  }

  # When there is a mesh VPN interface to be attached to this
  # bridge interface, create the appropriate VPN instance with the
  # specific config pull up file.
  if $meshvpnmac != nil {
    # Create fastd tunnel for the corresponding interface and
    # attach the corresponding bridge interface.
    ffce::fastd::instance { "${ifname}vpn":
      port => $vpnport,
      methods => ['salsa2012+umac', 'null'],
      mtu => $meshmtu,
      upscript => epp('ffce/fastd-mesh-up', {
        ifname => $ifname,
        meshvpnmac => $meshvpnmac,
        meshserver => $meshserver,
      }),
      require => Package['batctl'],
    }
  } else {
    # Create fastd tunnel for the corresponding interface and
    # attach the corresponding bridge interface to it, without
    # a mesh interface in the middle. This always forces encryption
    # on the VPN interface.
    ffce::fastd::instance { "${ifname}vpn":
      port => $vpnport,
      methods => ['salsa2012+umac'],
      mtu => $mtu,
      upscript => epp('ffce/fastd-bridge-up', {
        ifname => $ifname,
      }),
    }
  }
}
