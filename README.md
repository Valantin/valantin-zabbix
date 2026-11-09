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

## Official package repository

`zabbix::repo` configures the official stable Zabbix package repository for a
specific Zabbix major/minor release. It supports Debian and Ubuntu through APT,
the Red Hat family distributions published by Zabbix through YUM/DNF, and SLES
through Zypper.

```puppet
class { 'zabbix::repo':
  version => '8.0',
}
```

Set `manage_repo` to `false` when the repository is managed outside this
module. Arch Linux and unsupported distributions are not configured by this
class; use the distribution repository instead.

The main `zabbix` class contains `zabbix::repo`; configure repository
management independently with the `zabbix::repo::manage_repo` Hiera key.

```puppet
include zabbix
```
