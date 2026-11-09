# @summary Configures the official Zabbix package repository.
#
# Selects the appropriate repository implementation from the operating system
# family. The class supports Debian-based, Red Hat-based, and SUSE systems.
# Unsupported operating systems must use their distribution repository or set
# `manage_repo` to `false`.
#
# @param version
#   Zabbix major/minor release to install from, for example `8.0`.
# @param manage_repo
#   Whether this class manages the official Zabbix repository.
class zabbix::repo (
  String[1] $version,
  Boolean $manage_repo = true,
) {
  if $manage_repo {
    case $facts['os']['family'] {
      'Debian': {
        contain zabbix::repo::apt
      }
      'RedHat': {
        contain zabbix::repo::yum
      }
      'Suse': {
        contain zabbix::repo::zypper
      }
      default: {
        fail("Unsupported OS family: ${facts['os']['family']}")
      }
    }
  }
}
