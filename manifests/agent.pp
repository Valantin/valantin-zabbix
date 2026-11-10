# @summary Installs and configures the classic Zabbix agent or Agent 2.
#
# The component includes zabbix::repo and can be used without the main class.
# Configure repository management independently through zabbix::repo::manage_repo.
# The package supplies the service account, runtime directory and service unit.
#
# @param variant
#   Agent implementation. Defaults come from Hiera (agent2, or agent on Fedora).
# @param settings
#   Native agent directives. Arrays repeat Alias, UserParameter or LoadModule;
#   undef removes a default. Use native strings for Server/ServerActive lists.
# @param access_rules
#   Ordered allow/deny rules. Their order is preserved in the configuration.
# @param manage_package
#   Whether to manage the agent package. False assumes a package is already installed.
# @param package_ensure
#   Package state or exact version. Removal is deliberately not supported.
# @param manage_config
#   Whether to own the main configuration and managed include directory.
# @param manage_service
#   Whether to manage and restart the agent service.
# @param service_ensure
#   Desired service state.
# @param service_enable
#   Whether to start the service at boot.
# @param package_name
#   Optional package name override.
# @param service_name
#   Optional service name override.
# @param config_file
#   Optional configuration path override; external service units must use this path.
# @param binary_path
#   Optional absolute path to the agent binary used for validation.
# @param variants
#   Internal platform data mapping variants to package, service and configuration defaults.
class zabbix::agent (
  Zabbix::AgentVariant $variant,
  Hash[String[1], Hash] $variants,
  Zabbix::ConfigSettings $settings = {},
  Array[Zabbix::AgentAccessRule] $access_rules = [],
  Boolean $manage_package = true,
  String[1] $package_ensure = 'present',
  Boolean $manage_config = true,
  Boolean $manage_service = true,
  Enum['running', 'stopped'] $service_ensure = 'running',
  Boolean $service_enable = true,
  Optional[String[1]] $package_name = undef,
  Optional[String[1]] $service_name = undef,
  Optional[Stdlib::Absolutepath] $config_file = undef,
  Optional[Stdlib::Absolutepath] $binary_path = undef,
) {
  if !($variant in $variants) {
    fail("Agent variant ${variant} is not available on ${facts['os']['name']}")
  }
  if $package_ensure in ['absent', 'purged'] {
    fail('The agent class does not remove packages; use manage_package to disable management')
  }
  if !$manage_config and ($settings != {} or $access_rules != []) {
    fail('Agent settings and access_rules require manage_config => true')
  }

  $platform = $variants[$variant]
  $_package_name = pick($package_name, $platform['package_name'])
  $_service_name = pick($service_name, $platform['service_name'])
  $_config_file = pick($config_file, $platform['config_file'])
  $_binary_path = pick($binary_path, $platform['binary_path'])
  $fragment_dir = "/etc/zabbix/${variant}.puppet.d"

  include zabbix::repo

  if $manage_package {
    package { $_package_name:
      ensure  => $package_ensure,
      require => Class['zabbix::repo'],
    }
  }

  if $manage_config {
    include zabbix::common

    file { $fragment_dir:
      ensure  => directory,
      owner   => 'root',
      group   => 'zabbix',
      mode    => '0750',
      require => Class['zabbix::common'],
      notify  => Exec['zabbix-agent-validate'],
    }

    file { $_config_file:
      ensure    => file,
      owner     => 'root',
      group     => 'zabbix',
      mode      => '0640',
      show_diff => false,
      content   => epp('zabbix/agent/config.epp', {
        'variant'      => $variant,
        'settings'     => $platform['settings'] + $settings,
        'access_rules' => $access_rules,
        'fragment_dir' => $fragment_dir,
      }),
      require   => [Class['zabbix::common'], File[$fragment_dir]],
      notify    => Exec['zabbix-agent-validate'],
    }
    if $manage_package {
      Package[$_package_name] -> File[$fragment_dir] -> File[$_config_file]
    }
  }

  if $manage_config or $manage_service {
    exec { 'zabbix-agent-validate':
      command     => [$_binary_path, '-T', '-c', $_config_file],
      refreshonly => true,
      logoutput   => on_failure,
    }
    if $manage_package {
      Package[$_package_name] ~> Exec['zabbix-agent-validate']
    }
  }

  if $manage_service {
    service { $_service_name:
      ensure  => $service_ensure,
      enable  => $service_enable,
      require => Exec['zabbix-agent-validate'],
    }
    Exec['zabbix-agent-validate'] ~> Service[$_service_name]
    if $manage_package {
      Package[$_package_name] -> Service[$_service_name]
    }
  }
}
