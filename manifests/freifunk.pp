# Class: ffce::freifunk
# ===========================
#
# Basic configuration for the freifunk network, which sets up the appropriate
# network settings and installs the corresponding basic networking setup.
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
class ffce::freifunk (
  Integer $gwid,
  String $meship,
  String $meship6,
  String $meshvpnmac,
  String $meshserver,
  Array[String] $mullvad,
  String $meshmask = '255.255.240.0',
  String $meshmask6 = '64',
  Integer $meshvpnport = 10000,
  String $mgmtlocalif = 'none',
  String $ffnet = '10.252.0.0',
  String $ffmask = '18',
  String $ff6net = 'fd92:2dff:d232::',
  String $ff6mask = '48',
) inherits ffce::params {
  # Mesh interface for the client mesh. This interface has a BATMAN MAC
  # address, and as such the VPN interface is put into BATMAN for the
  # mesh; there is no local interface for the mesh attached.
  ffce::meshinterface { 'mesh':
    ipaddress => $meship,
    netmask => $meshmask,
    ip6address => $meship6,
    net6mask => $meshmask6,
    vpnport => $meshvpnport,
    meshserver => $meshserver,
    meshvpnmac => $meshvpnmac,
  }
  firewall { '110 mesh vpn in v4':
    proto => udp,
    dport => $meshvpnport,
    state => ['NEW'],
    action => accept,
  }
  firewall { '110 mesh vpn in v6':
    proto => udp,
    dport => $meshvpnport,
    state => ['NEW'],
    action => accept,
    provider => ip6tables,
  }
  firewall { '100 allow mesh to mesh v4':
    chain => 'FORWARD',
    proto => all,
    source => "${ffnet}/${ffmask}",
    destination => "${ffnet}/${ffmask}",
    action => accept,
  }
  firewall { '100 allow mesh to mesh v6':
    chain => 'FORWARD',
    proto => all,
    source => "${ff6net}/${ff6mask}",
    destination => "${ff6net}/${ff6mask}",
    action => accept,
    provider => ip6tables,
  }

  # Mesh interface for the management mesh. On gateway1, there is a local
  # interface attached which receives the internal management traffic for
  # the hosting system and additional VMs on it.
  $mgmtip = $gwid + 192
  $mgmtip6 = sprintf('%x', $gwid)
  ffce::meshinterface { 'mgmt':
    ipaddress => "10.252.63.${mgmtip}",
    netmask => '255.255.255.192',
    ip6address => "fd92:2dff:d232:3fc0::${mgmtip6}",
    net6mask => '64',
    vpnport => 9999,
    localif => $mgmtlocalif,
  }
  firewall { '110 mgmt vpn in v4':
    proto => udp,
    dport => 9999,
    state => ['NEW'],
    action => accept,
  }
  firewall { '110 mgmt vpn in v6':
    proto => udp,
    dport => 9999,
    state => ['NEW'],
    action => accept,
    provider => ip6tables,
  }

  # General routing table for freifunk network; this table is always set
  # up for any gateway, independent of the mullvad routes.
  network::routing_table { 'freifunk':
    table_id => '252',
  }

  # Mullvad instances.
  $mullvad.each |$idx, $mullvadid| {
    # Mullvad interface chains, required for OpenVPN.
    $ifidx = $idx + 1
    firewallchain { "mullvad${ifidx}:nat:IPv4":
    } ->
    firewall { "050 mullvad${ifidx} chain jump v4":
      table => nat,
      chain => 'POSTROUTING',
      proto => all,
      outiface => "mullvad${ifidx}",
      jump => "mullvad${ifidx}",
      before => Ffce::Mullvad::Instance[$mullvadid],
    }

    # IPv6 firewall chains required for Mullvad.
    firewallchain { "mullvad${ifidx}:nat:IPv6":
    } ->
    firewall { "050 mullvad${ifidx} chain jump v6":
      table => nat,
      chain => 'POSTROUTING',
      proto => all,
      outiface => "mullvad${ifidx}",
      jump => "mullvad${ifidx}",
      provider => ip6tables,
      before => Ffce::Mullvad::Instance[$mullvadid],
    }

    # Create mullvad instance with the specified interface. The instance
    # connects one tunnel to the mullvad servers to have an exit tunnel.
    ffce::mullvad::instance { $mullvadid:
      mullvadif => "mullvad${ifidx}",
      ifip => $meship,
      ifip6 => $meship6,
    }

    # Routing table for the mullvad tunnel, dependent on the interface.
    network::routing_table { "mullvad${ifidx}":
      table_id => "${ifidx}",
    }

    # Attach firewall rule for outgoing mullvad traffic from Freifunk network.
    firewall { "200 mullvad${ifidx} out v4":
      chain => 'FORWARD',
      proto => all,
      source => "${ffnet}/${ffmask}",
      outiface => "mullvad${ifidx}",
      action => accept,
    }
    firewall { "200 mullvad${ifidx} in v4":
      chain => 'FORWARD',
      proto => all,
      destination => "${ffnet}/${ffmask}",
      iniface => "mullvad${ifidx}",
      action => accept,
    }
    firewall { "200 mullvad${ifidx} out v6":
      chain => 'FORWARD',
      proto => all,
      source => "${ff6net}/${ff6mask}",
      outiface => "mullvad${ifidx}",
      action => accept,
      provider => ip6tables,
    }
    firewall { "200 mullvad${ifidx} in v6":
      chain => 'FORWARD',
      proto => all,
      destination => "${ff6net}/${ff6mask}",
      iniface => "mullvad${ifidx}",
      action => accept,
      provider => ip6tables,
    }
  }

  # Set up routing for marks.
  $ipmarks = $mullvad.map |$idx, $mullvadid| { $idx + 1 }
  $ip6marks = $mullvad.map |$idx, $mullvadid| { $idx + 1 }

  # Network routing rules for Freifunk.
  network::rule { 'mesh':
    iprule => $ipmarks.map |$ifidx| {
      "fwmark ${ifidx} table mullvad${ifidx} pref 99"
    } + [
      "from 10.252.63.192/26 table main pref 10",
      "from ${ffnet}/${ffmask} table freifunk pref 100",
    ],
    ip6rule => $ip6marks.map |$ifidx| {
      "fwmark ${ifidx} table mullvad${ifidx} pref 99"
    } + [
      "from fd92:2dff:d232:3fc0::/64 table main pref 10",
      "from ${ff6net}/${ff6mask} table freifunk pref 100",
    ],
  }

  # Set up rules to decide for outgoing packets where they
  # should be destined for freifunk network.
  firewall { '001 mullvad decide outgoing interface v4':
    table => mangle,
    chain => 'PREROUTING',
    source => "${ffnet}/${ffmask}",
    destination => "! ${ffnet}/${ffmask}",
    proto => all,
    jump => 'HMARK',
    hmark_src_prefix => 32,
    hmark_rnd => '0xffceffce',
    hmark_offset => 1,
    hmark_mod => length($mullvad),
  }
  firewall { '001 mullvad decide outgoing interface v6':
    table => mangle,
    chain => 'PREROUTING',
    source => "${ff6net}/${ff6mask}",
    destination => "! ${ff6net}/${ff6mask}",
    proto => all,
    jump => 'HMARK',
    hmark_src_prefix => 128,
    hmark_rnd => '0xffceffce',
    hmark_offset => 1,
    hmark_mod => length($mullvad),
    provider => ip6tables,
  }

  # Enable routing daemons for routing in the management network.
  # This sets up the corresponding bird routing protocol daemon
  # configuration for the routes in the different tables, set up
  # by the rules above.
  class { 'bird':
    # Default adaptations (testing has both in one package, see apt).
    package_ensure_v4 => latest,
    package_ensure_v6 => latest,
    package_name_v6 => 'bird',

    # v4 configuration.
    config_v4 => epp('ffce/bird4.conf.epp', {
      routerid => "10.252.63.${mgmtip}",
      ipmarks => $ipmarks,
      basetable => 252,
      ffnet => $ffnet,
      ffmask => $ffmask,
    }),
    config_v6 => epp('ffce/bird6.conf.epp', {
      routerid => "10.252.63.${mgmtip}",
      ip6marks => $ip6marks,
      basetable => 252,
      ff6net => $ff6net,
      ff6mask => $ff6mask,
    }),
  }
  firewall { '002 mgmt ospf in v4':
    proto => ospf,
    iniface => mgmt,
    action => accept,
  }
  firewall { '002 mgmt ospf in v6':
    proto => ospf,
    iniface => mgmt,
    action => accept,
    provider => ip6tables,
  }
  firewall { '101 mgmt outgoing routes from ospf v4':
    chain => 'FORWARD',
    proto => all,
    source => "${ffnet}/${ffmask}",
    outiface => mgmt,
    action => accept,
  }
  firewall { '101 mgmt outgoing routes from ospf v6':
    chain => 'FORWARD',
    proto => all,
    source => "${ff6net}/${ff6mask}",
    outiface => mgmt,
    action => accept,
    provider => ip6tables,
  }
}
