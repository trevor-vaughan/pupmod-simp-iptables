# Returns ``true`` if the client can/should use firewalld
#
# @param enable
#   The type of enablement to use
#
#   * true      => Do the right thing based on the underlying OS
#   * false     => Return `false`
#   * firewalld => Force `firewalld` if available
#
# @return [Boolean]
#
function iptables::use_firewalld(
  Variant[String[1], Boolean] $enable = true
) {

  $_firewalld_os_list = {
    'RedHat'      => '8',
    'CentOS'      => '8',
    'OracleLinux' => '8'
  }

  if $enable {
    if 'firewalld' in fact('simplib__firewalls') {
      if ($enable == 'firewalld') or
         ($_firewalld_os_list[fact('os.name')] and ($_firewalld_os_list[fact('os.name')] <= fact('os.release.major')))
      {
        $_retval = true
      }
    }
  }

  unless defined('$_retval') {
    $_retval = false
  }

  $_retval
}
