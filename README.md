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

## Agent

`zabbix::agent` installs and configures either the classic agent (`agent`) or
Agent 2 (`agent2`). It works independently of `zabbix` and includes
`zabbix::repo` using that component's Hiera settings. Including the main class
does not install the agent automatically.

```puppet
class { 'zabbix::agent':
  variant  => 'agent2',
  settings => {
    'Server'       => '192.0.2.10,192.0.2.11',
    'ServerActive' => 'zabbix.example.net:10051',
    'HostnameItem' => 'system.hostname',
    'DebugLevel'   => 3,
  },
}
```

The default is Agent 2, except on Fedora, where the distribution packages
provide the classic agent. Selecting Agent 2 on Fedora fails explicitly.
Arch Linux uses its distribution packages and `/usr/bin` binaries; Fedora 41
uses `/usr/sbin/zabbix_agentd` and `/etc/zabbix_agentd.conf`. Other supported systems
use the official packages with configuration under `/etc/zabbix`.
See the upstream [agent differences](https://www.zabbix.com/documentation/8.0/en/manual/concepts/agent2)
and [Arch package files](https://archlinux.org/packages/extra/x86_64/zabbix-agent2/files/).
Fedora 41 paths follow its [distribution packaging](https://src.fedoraproject.org/rpms/zabbix/blob/f41/f/zabbix.spec).

Defaults log through syslog (`LogType=system`) and allow passive checks from
`127.0.0.1` (`Server=127.0.0.1`), without configuring active checks. `settings`
overrides those defaults. `undef` omits a default directive, for example
`'Server' => undef` for an active-only Agent 2. Classic-agent active-only
setups also need `'StartAgents' => 0`.

Hiera can configure the component without declaring the main class:

```yaml
zabbix::agent::variant: agent2
zabbix::agent::settings:
  Server: '192.0.2.10'
  ServerActive: zabbix.example.net
  HostnameItem: system.hostname
```

Settings use native Zabbix directive names. Strings and numbers are rendered
as `Name=value`; arrays repeat only `Alias`, `UserParameter` and the classic
agent's `LoadModule`. Server address lists remain native strings. Unknown
directives and version-specific details are checked by the installed agent;
known v1/v2 incompatibilities are also rejected during catalog compilation.
Keys, values and access rules cannot inject new configuration lines.

### Item access rules

Use ordered `access_rules` instead of `AllowKey` or `DenyKey` in `settings`:

```puppet
class { 'zabbix::agent':
  access_rules => [
    { 'action' => 'allow', 'pattern' => 'system.run[/usr/bin/uptime]' },
    { 'action' => 'deny', 'pattern' => 'system.run[*]' },
  ],
}
```

Rules preserve their relative order. Do not apply Hiera merges that reorder
this array. Regexp rules and the deprecated `EnableRemoteCommands` setting
are not exposed by this interface.

### Managed fragments

```puppet
zabbix::agent::fragment { 'application':
  settings => {
    'UserParameter' => ['app.ping,echo 1', 'app.version,echo 2'],
  },
}
```

Fragments automatically include `zabbix::agent`. They support `UserParameter`,
`Alias` and Agent 2 `Plugins.*` settings; singleton settings and access rules
belong in the main class. A fragment title is a basename using letters, digits,
underscores and hyphens. `ensure => 'absent'` removes that managed fragment.

The main file includes `/etc/zabbix/agent.puppet.d/*.conf` or
`/etc/zabbix/agent2.puppet.d/*.conf`. The module does not purge unmanaged files
or modify package-provided plugin configuration directories. Installing and
enabling separate loadable-plugin packages is not part of this interface.

### Lifecycle and overrides

| Parameter | Default | Purpose |
| --- | --- | --- |
| `manage_package` | `true` | Manage the package; otherwise it must already be installed |
| `package_ensure` | `present` | Package state or exact version; `latest` is opt-in |
| `manage_config` | `true` | Own the main file and managed include directory |
| `manage_service` | `true` | Manage the service and restart after validated changes |
| `service_ensure` | `running` | `running` or `stopped` |
| `service_enable` | `true` | Start at boot |
| `package_name`, `service_name` | Platform/variant default | Override resource names |
| `config_file`, `binary_path` | Platform/variant default | Override paths |

The package supplies the `zabbix` account, service unit and runtime directory.
Changing `config_file` does not rewrite that unit: the external unit must
already use the selected path.

Package, main-file and fragment changes trigger an aggregate validation with
the installed binary's `-T -c` before restarting the service. An invalid
configuration makes the Puppet run fail without restarting the service; the
managed files must then be corrected. Configuration files are root-owned,
readable by group `zabbix`, mode `0640`, with diffs disabled.

`manage_config => false` cannot be combined with settings, access rules or
managed fragments. Disabling management does not uninstall packages or delete
files; `package_ensure => 'absent'` and `purged` are rejected. Repository
management remains controlled by `zabbix::repo::manage_repo` in Hiera.

TLS directives such as `TLSCAFile`, `TLSCertFile`, `TLSKeyFile`, `TLSPSKFile`
and `TLSPSKIdentity` can reference externally provisioned files through
`settings`. Certificate issuance and PSK content provisioning remain external.
Switching between agent variants does not stop or remove the previous variant:
plan that migration explicitly to avoid competing listeners on port 10050.

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
