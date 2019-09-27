# These items mimic components in the actual `firewalld` module but set them to
# safer defaults per the usual "authoritative control" idea of SIMP.
#
# Since the `firewalld` module is designed to be Hiera-driven, this was more
# understandable and safer than encapsulating the entire module in the
# `iptables` module directly.
class iptables::firewalld_shim (
  Boolean                                              $enable          = true,
  Boolean                                              $complete_reload = true,
  Boolean                                              $lockdown        = true,
  String[1]                                            $default_zone    = 'simp',
  Enum['off', 'all','unicast','broadcast','multicast'] $log_denied      = 'unicast'
) {

  if $enable {
    include firewalld

    Exec { path => '/usr/bin:/bin' }

    if $complete_reload {
      # This breaks all firewall connections and should never be done unless forced
      Exec <| command == 'firewall-cmd --complete-reload' |> { onlyif => '/bin/false' }
    }

    firewalld_zone { 'simp':
      ensure           => 'present',
      purge_rich_rules => true,
      purge_services   => true,
      purge_ports      => true,
      require          => Service['firewalld']
    }

    exec { 'firewalld::set_default_zone':
      command => "firewall-cmd --set-default-zone ${default_zone}",
      unless  => "[ \$(firewall-cmd --get-default-zone) = ${default_zone} ]",
      require => [
        Service['firewalld'],
        Exec['firewalld::reload']
      ]
    }

    if $default_zone == 'simp' {
      Firewalld_zone['simp'] -> Exec['firewalld::set_default_zone']
    }

    ensure_resource('exec', 'firewalld::set_log_denied', {
      'command' => "firewall-cmd --set-log-denied ${log_denied} && firewall-cmd --reload",
      'unless'  => "[ $(firewall-cmd --get-log-denied) = ${log_denied} ]",
      require => [
        Service['firewalld'],
        Exec['firewalld::reload']
      ]
    })

    if $lockdown {
      exec { 'lockdown_firewalld':
        command => 'firewall-cmd --lockdown-on',
        unless  => 'firewall-cmd --query-lockdown',
        require => [
          Service['firewalld'],
          Exec['firewalld::reload']
        ]
      }
    }
    else {
      exec { 'unlock_firewalld':
        command => 'firewall-cmd --lockdown-off',
        onlyif  => 'firewall-cmd --query-lockdown',
        require => [
          Service['firewalld'],
          Exec['firewalld::reload']
        ]
      }
    }
  }
}
