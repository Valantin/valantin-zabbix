# valantin-zabbix
Puppet module for creating and maintaining zabbix components with puppet.

## Configuration

The module's `hiera.yaml` loads defaults from `data/common.yaml`, where
`zabbix::version` is set to the string `'8.0'`. The class uses this default
through automatic parameter lookup:

```puppet
include zabbix
```

To override the version, set `zabbix::version` in your environment's Hiera data
or pass the `version` class parameter explicitly. Quote version values in YAML
to keep them as strings.
