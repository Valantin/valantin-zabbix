# @summary Configures Zabbix components.
#
# @param version
#   Zabbix major/minor release to configure.
class zabbix (
  String[1] $version,
) {
  contain zabbix::repo
}
