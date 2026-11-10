# @summary Validates and renders native Zabbix agent settings without reordering rules.
# @api private
function zabbix::agent::render_settings (
  Zabbix::AgentVariant $variant,
  Zabbix::ConfigSettings $settings,
) >> String {
  $reserved = ['Include', 'AllowKey', 'DenyKey', 'AllowKeyRegexp', 'DenyKeyRegexp', 'EnableRemoteCommands']
  $classic_only = ['AllowRoot', 'User', 'StartAgents', 'ListenBacklog', 'LoadModule', 'LoadModulePath', 'MaxLinesPerSecond', 'LogRemoteCommands']
  $agent2_only = ['ControlSocket', 'EnablePersistentBuffer', 'PersistentBufferFile', 'PersistentBufferPeriod', 'ForceActiveChecksOnStart', 'StatusPort', 'PluginSocket', 'PluginTimeout']

  $lines = $settings.keys.sort.map |$key| {
    $value = $settings[$key]
    if $key in $reserved {
      fail("${key} must be configured through the structured agent parameters")
    }
    if $value != undef {
      if ($variant == 'agent2' and $key in $classic_only) or ($variant == 'agent' and ($key in $agent2_only or $key =~ /^Plugins\./)) {
        fail("${key} is not supported by ${variant}")
      }
      if $value =~ Array and !($key in ['Alias', 'UserParameter', 'LoadModule']) {
        fail("${key} is not a repeatable agent setting")
      }
      $values = $value ? { Array => $value, default => [$value] }
      $values.map |$entry| {
        if String($entry) =~ /[\r\n\x00]/ {
          fail("${key} must contain only single-line values without NUL bytes")
        }
        "${key}=${entry}\n"
      }.join('')
    } else {
      ''
    }
  }
  $lines.join('')
}
