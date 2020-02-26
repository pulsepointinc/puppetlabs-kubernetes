
class kubernetes::container_runtime(
  String $container_runtime = $kubernetes::container_runtime,
  Boolean $manage_docker = $kubernetes::manage_docker,
  Optional[String] $docker_version             = $kubernetes::docker_version,
  Optional[String] $docker_package_name        = $kubernetes::docker_package_name,
  Optional[String] $docker_storage_driver      = $kubernetes::docker_storage_driver,
  Optional[Array] $docker_storage_opts         = $kubernetes::docker_storage_opts,
  Optional[String] $docker_extra_daemon_config = $kubernetes::docker_extra_daemon_config,
  String $docker_log_max_file                  = $kubernetes::docker_log_max_file,
  String $docker_log_max_size                  = $kubernetes::docker_log_max_size,
  Optional[String] $containerd_archive = $kubernetes::containerd_archive,
  Optional[String] $runc_source = $kubernetes::runc_source,
  Boolean $create_repos = $kubernetes::create_repos,

) {

  if $container_runtime == 'docker' and $manage_docker == true {

    # procedure: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
    case $facts['os']['family'] {
      'Debian': {
        if $create_repos and $manage_docker {
          package { $docker_package_name:
            ensure  => $docker_version,
            require => Class['Apt::Update'],
          }
        }
        else {
          package { $docker_package_name:
            ensure => $docker_version,
          }
        }

        file{ '/etc/docker':
          ensure => 'directory',
          mode   => '0644',
          owner  => 'root',
          group  => 'root',
        }

        file { '/etc/docker/daemon.json':
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          mode    => '0644',
          content => template('kubernetes/docker/daemon_debian.json.erb'),
          require => [ File['/etc/docker'], Package[$docker_package_name] ],
          notify  => Service['docker'],
        }
      }
      'RedHat': {
        package { $docker_package_name:
            ensure  => $docker_version,
        }

        file{ '/etc/docker':
          ensure => 'directory',
          mode   => '0644',
          owner  => 'root',
          group  => 'root',
        }

        file { '/etc/docker/daemon.json':
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          mode    => '0644',
          content => template('kubernetes/docker/daemon_redhat.json.erb'),
          require => [ File['/etc/docker'], Package[$docker_package_name] ],
          notify  => Service['docker'],
        }
      }
      default: { notify { "The OS family ${facts['os']['family']} is not supported by this module": } }
    }

    file { '/etc/systemd/system/docker.service':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => template('kubernetes/docker/docker.service.erb'),
      require => File['/etc/docker/daemon.json'],
      before  => Service['docker'],
      notify  => [Exec['kubernetes-systemd-reload'], Service['docker']],
    }

    service { 'docker':
      ensure => running,
      enable => true,
    }

  }

  elsif $container_runtime == 'cri_containerd' {
    archive { '/usr/bin/runc':
      source  => $runc_source,
      extract => false,
      cleanup => false,
      creates => '/usr/bin/runc',
    }
    -> file { '/usr/bin/runc':
      mode => '0700'
    }

    archive { $containerd_archive:
      path            => "/${containerd_archive}",
      source          => $containerd_source,
      extract         => true,
      extract_command => 'tar xfz %s --strip-components=1 -C /usr/bin/',
      extract_path    => '/',
      cleanup         => true,
      creates         => '/usr/bin/containerd'
    }
  } else {
    fail(translate('Please specify a valid container runtime'))
  }
}
