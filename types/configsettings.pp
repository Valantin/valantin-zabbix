# @summary Native single-line settings; arrays repeat a directive and undef omits it.
type Zabbix::ConfigSettings = Hash[
  Pattern[/\A[A-Za-z][A-Za-z0-9.]*\z/],
  Variant[String, Numeric, Array[String, 1], Undef],
]
