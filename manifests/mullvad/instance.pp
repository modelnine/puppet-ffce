# Class: ffce::mullvad::instance
# ===========================
#
# Set up mullvad openvpn tunnel for a server node. This receives a list
# of tunnel IDs to use, downloads the corresponding certificates, and
# sets up the server instances for connection.
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
define ffce::mullvad::instance (
  String $ifip,
  String $ifip6,
  String $mullvadif = 'mullvad',
  String $id = $title,
) {
  # Includes.
  include ffce::mullvad
  include ffce::params

  # Set up files for mullvad instance.
  file { "/etc/openvpn/mullvad${id}/ca.crt":
    ensure => file,
    owner => root,
    group => nogroup,
    mode => '0644',
    source => 'puppet:///modules/ffce/mullvad/ca.crt',
    require => File["/etc/openvpn/mullvad${id}"],
  } ->
  file { "/etc/openvpn/mullvad${id}/crl.pem":
    ensure => file,
    owner => root,
    group => nogroup,
    mode => '0644',
    source => 'puppet:///modules/ffce/mullvad/crl.pem',
  } ->
  file { "/etc/openvpn/mullvad${id}/keys/server.key":
    ensure => file,
    owner => root,
    group => nogroup,
    mode => '0600',
    source => "puppet:///modules/ffce/mullvad/${id}.key",
  } ->
  file { "/etc/openvpn/mullvad${id}/keys/server.crt":
    ensure => file,
    owner => root,
    group => nogroup,
    mode => '0644',
    source => "puppet:///modules/ffce/mullvad/${id}.crt",
  } ->
  file { "/etc/openvpn/mullvad${id}/up":
    ensure => file,
    owner => root,
    group => nogroup,
    mode => '0755',
    content => epp('ffce/mullvad-up.epp', {
      ifip => $ifip,
      ifip6 => $ifip6,
    }),
    notify => Service["openvpn@mullvad${id}"],
  }

  # Enable the service.
  openvpn::server { "mullvad${id}":
    # Base configuration for uplink.
    dev => $mullvadif,
    proto => 'udp',
    remote => ['de.mullvad.net 1194'],

    # Encryption.
    cipher => 'BF-CBC',
    tls_cipher => 'TLS-DHE-RSA-WITH-AES-256-CBC-SHA:TLS-DHE-RSA-WITH-CAMELLIA-256-CBC-SHA:TLS-DHE-RSA-WITH-3DES-EDE-CBC-SHA:TLS-DHE-RSA-WITH-AES-128-CBC-SHA:TLS-DHE-RSA-WITH-SEED-CBC-SHA:TLS-DHE-RSA-WITH-CAMELLIA-128-CBC-SHA',

    # Tunnel options.
    keepalive => '10 60',
    nobind => true,
    persist_key => true,
    persist_tun => false,
    local => '',
    topology => '',
    custom_options => {
      'dev-type' => tun,
      'resolv-retry' => infinite,
      'auth-retry' => nointeract,
      'remote-cert-tls' => server,
      'route-noexec' => '',
      'ifconfig-noexec' => '',
    },

    # Bind the certificates.
    extca_enabled => true,
    extca_ca_cert_file => "/etc/openvpn/mullvad${id}/ca.crt",
    extca_ca_crl_file => "/etc/openvpn/mullvad${id}/crl.pem",
    extca_server_key_file => "/etc/openvpn/mullvad${id}/keys/server.key",
    extca_server_cert_file => "/etc/openvpn/mullvad${id}/keys/server.crt",
    up => "/etc/openvpn/mullvad${id}/up",
  }
}
