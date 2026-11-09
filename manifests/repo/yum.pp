# @summary Configures the official Zabbix YUM/DNF repository.
# @api private
class zabbix::repo::yum {
  $version  = $zabbix::repo::version
  $os_major = $facts['os']['release']['major']

  $os_name = $facts['os']['name'] ? {
    'AlmaLinux'   => 'alma',
    'Amazon'      => 'amazonlinux',
    'CentOS'      => 'centos',
    'OracleLinux' => 'oracle',
    'RedHat'      => 'rhel',
    'Rocky'       => 'rocky',
    default     => fail("Unsupported RPM distribution: ${facts['os']['name']}"),
  }

  yumrepo { 'zabbix':
    ensure   => present,
    descr    => "Zabbix ${version}",
    baseurl  => "https://repo.zabbix.com/zabbix/${version}/stable/${os_name}/${os_major}/\$basearch/",
    enabled  => '1',
    gpgcheck => '1',
    gpgkey   => 'https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX-B5333005',
  }
}
