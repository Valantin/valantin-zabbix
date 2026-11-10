# @summary Adds repeatable user checks, aliases or Agent 2 plugin settings.
#
# Includes the agent component automatically and validates the whole configuration
# before notifying its service. Singleton directives and access rules belong in
# zabbix::agent instead. Include files are not processed in alphabetical order.
#
# @param ensure
#   Whether to keep or remove this managed fragment.
# @param settings
#   UserParameter, Alias or Plugins.* directives; arrays repeat supported options.
define zabbix::agent::fragment (
  Enum['present', 'absent'] $ensure = 'present',
  Zabbix::ConfigSettings $settings = {},
) {
  if $title !~ /\A[A-Za-z0-9][A-Za-z0-9_-]*\z/ {
    fail('Invalid agent fragment name; use letters, digits, underscores and hyphens')
  }

  include zabbix::agent

  if !$zabbix::agent::manage_config {
    fail('Agent fragments require manage_config => true')
  }
  $settings.each |$key, $value| {
    unless $key in ['Alias', 'UserParameter'] or $key =~ /^Plugins\./ {
      fail("${key} must be configured in the main agent settings")
    }
  }

  $content = $ensure ? {
    'present' => zabbix::agent::render_settings($zabbix::agent::variant, $settings),
    'absent'  => undef,
  }
  $file_ensure = $ensure ? { 'present' => 'file', 'absent' => 'absent' }
  file { "${zabbix::agent::fragment_dir}/${title}.conf":
    ensure    => $file_ensure,
    owner     => 'root',
    group     => 'zabbix',
    mode      => '0640',
    show_diff => false,
    content   => $content,
    require   => File[$zabbix::agent::fragment_dir],
    notify    => Exec['zabbix-agent-validate'],
  }
}
