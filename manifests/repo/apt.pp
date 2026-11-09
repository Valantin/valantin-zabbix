# @summary Configures the official Zabbix APT repository.
# @api private
class zabbix::repo::apt {
  $version  = $zabbix::repo::version
  $os_name  = $facts['os']['name'].downcase()
  $codename = $facts['os']['distro']['codename']

  contain apt

  apt::source { 'zabbix':
    ensure   => present,
    comment  => "Zabbix stable repo ${version}",
    location => "https://repo.zabbix.com/zabbix/${version}/stable/${os_name}",
    release  => [$codename],
    repos    => ['main'],
    key      => {
      'name'   => 'zabbix.gpg',
      'source' => 'https://repo.zabbix.com/zabbix-official-repo-apr2024.gpg',
    },
  }
}
