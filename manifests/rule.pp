# Add rules to the IPTables configuration file
#
# @example Add a TCP Allow Rule
#   iptables::rule { 'example':
#     content => '-A LOCAL-INPUT -m state --state NEW -m tcp -p tcp -s 1.2.3.4 --dport 1024:65535 -j ACCEPT'
#   }
#
#  ### Result:
#
#  *filter
#  :INPUT DROP [0:0]
#  :FORWARD DROP [0:0]
#  :OUTPUT ACCEPT [0:0]
#  :LOCAL-INPUT - [0:0]
#  -A INPUT -j LOCAL-INPUT
#  -A FORWARD -j LOCAL-INPUT
#  -A LOCAL-INPUT -p icmp --icmp-type 8 -j ACCEPT
#  -A LOCAL-INPUT -i lo -j ACCEPT
#  -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
#  -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp -s 1.2.3.4 --dport 1024:65535 -j ACCEPT
#  -A LOCAL-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
#  -A LOCAL-INPUT -j LOG --log-prefix "IPT:"
#  -A LOCAL-INPUT -j DROP
#  COMMIT
#
# @param content
#   The **exact** content of the rule that should be added
#
# @param table
#   The name of the table you are adding to
#
#   * Usual names include (but are not limited to):
#
#       * filter
#       * mangle
#       * nat
#       * raw
#       * security
#
# @param first
#   Prepend this rule to the rule set
#
# @param absolute
#   Make sure that this rule is absolutely first, or last, depending on the
#   setting of ``first``
#
#   * If ``first`` is true, this rule will be at the top of the list
#   * If ``first`` is false, this rule will be at the bottom of the list
#   * For all ``absolute`` rules, alphabetical sorting still takes place
#
# @param order
#   The order in which the rule should appear
#
#   * 1 is the minimum and 9999999 is the maximum
#
#   * The following ordering ranges are suggested (but not enforced):
#
#       * 1     -> ESTABLISHED,RELATED rules
#       * 2-5   -> Standard ACCEPT/DENY rules
#       * 6-10  -> Jumps to other rule sets
#       * 11-20 -> Pure accept rules
#       * 22-30 -> Logging and rejection rules
#
# @param comment
#   An informative comment to prepend to the rule
#
# @param header
#   Automatically add the line header ``-A LOCAL-INPUT``
#
# @param apply_to
#   The IPTables network type to which to apply this rule
#
#   * ipv4 -> iptables
#   * ipv6 -> ip6tables
#   * all  -> Both
#   * auto -> Try to figure it out from the rule, will **not** pick ``all``
#
define iptables::rule (
  String                           $content,
  String                           $table    = 'filter',
  Boolean                          $first    = false,
  Boolean                          $absolute = false,
  Integer[0]                       $order    = 11,
  String                           $comment  = '',
  Boolean                          $header   = true,
  Enum['ipv4','ipv6','all','auto'] $apply_to = 'auto'
) {
  if $iptables::use_firewalld {
    $_metadata = loadjson($content)

    if $_metadata['protocol'] == 'icmp' {
      $_icmp_xlat = join(Array($_metadata['icmp_types'], true), ',')
      $_icmp_block = "{${_icmp_xlat}}"
    }
    else {
      $_dports_a = Array($_metadata['dports'], true)
      $_dports = $_dports_a.map |$dport| {
        # Convert all IPTables range formats over to firewalld formats
        $_converted_port = regsubst("${dport}",':','-'),

        if $_metadata['protocol'] != 'all' {
          {
            'port' => $_converted_port,
            'protocol' => $_metadata['protocol']
          }
        }
        else {
          {
            'port' => $_converted_port,
          }
        }
      }
    }

    $_trusted_nets_a = Array($_metadata['trusted_nets'], true)
    $_trusted_nets = $_trusted_nets_a.map |$tnet| {
      $tnet ? { 'ALL' => '0.0.0.0/0', default => $tnet }
    }

    # Create a unique ipset based on every content collection
    #
    # This is done so that we do not end up with a million ipsets for every call
    #
    # The length is limited due to apparent limitations in the ipset name
    $_ipset_name = join(['simp',sha1(join(sort(unique($_trusted_nets_a)),''))], '_')[0,31]
    ensure_resource('firewalld_ipset', $_ipset_name, { 'entries' => $_trusted_nets })

    if $_metadata['protocol'] == 'icmp' {
      firewalld_rich_rule { "${order}_simp_${name}":
        ensure => 'present',
        source => { 'ipset' => $_ipset_name },
        icmp_block => $_icmp_block,
        action => 'accept'
      }
    }
    else {
      firewalld::custom_service { "simp_${name}":
        short => "simp_${name}",
        description => "SIMP ${name}",
        port => $_dports
      }

      firewalld_rich_rule { "${order}_simp_${name}":
        ensure => 'present',
        source => { 'ipset' => $_ipset_name },
        service => "simp_${name}",
        action => 'accept'
      }
    }
  }
  else {
    iptables_rule { $name:
      table    => $table,
      absolute => $absolute,
      first    => $first,
      order    => $order,
      header   => $header,
      content  => $content,
      apply_to => $apply_to
    }
  }
}
