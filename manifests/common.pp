# @summary Owns the configuration directory shared by Zabbix components.
# @api private
class zabbix::common {
  file { '/etc/zabbix':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
}
