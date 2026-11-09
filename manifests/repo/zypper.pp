# @summary Configures the official Zabbix Zypper repository.
# @api private
class zabbix::repo::zypper {
  $version  = $zabbix::repo::version
  $os_major = $facts['os']['release']['major']

  if $facts['os']['name'] != 'SLES' {
    fail("Unsupported SUSE distribution: ${facts['os']['name']}")
  }

  $baseurl = "https://repo.zabbix.com/zabbix/${version}/stable/sles/${os_major}/\$basearch/"

  zypprepo { 'zabbix':
    ensure      => present,
    autorefresh => '1',
    baseurl     => $baseurl,
    enabled     => '1',
    gpgcheck    => '1',
    gpgkey      => 'https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX-B5333005',
    type        => 'rpm-md',
  }
}
