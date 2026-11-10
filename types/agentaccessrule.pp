# @summary An ordered agent item access rule.
type Zabbix::AgentAccessRule = Struct[{
  'action'  => Enum['allow', 'deny'],
  'pattern' => Pattern[/\A[^\r\n\x00]+\z/],
}]
