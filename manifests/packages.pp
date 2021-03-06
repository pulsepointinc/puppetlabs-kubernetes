# Class kubernetes packages

class kubernetes::packages (
  String $kubernetes_package_version           = $kubernetes::kubernetes_package_version,
  String $container_runtime                    = $kubernetes::container_runtime,
  Boolean $manage_docker                       = $kubernetes::manage_docker,
  Boolean $manage_etcd                         = $kubernetes::manage_etcd,
  Boolean $controller                          = $kubernetes::controller,
  Optional[String] $containerd_archive         = $kubernetes::containerd_archive,
  Optional[String] $containerd_source          = $kubernetes::containerd_source,
  String $etcd_archive                         = $kubernetes::etcd_archive,
  String $etcd_version                         = $kubernetes::etcd_version,
  String $etcd_source                          = $kubernetes::etcd_source,
  String $etcd_package_name                    = $kubernetes::etcd_package_name,
  String $etcd_install_method                  = $kubernetes::etcd_install_method,
  Optional[String] $runc_source                = $kubernetes::runc_source,
  Boolean $disable_swap                        = $kubernetes::disable_swap,
  Boolean $manage_kernel_modules               = $kubernetes::manage_kernel_modules,
  Boolean $manage_sysctl_settings              = $kubernetes::manage_sysctl_settings,
  Boolean $create_repos                        = $kubernetes::repos::create_repos,
) {


  $kube_packages = ['kubelet', 'kubectl', 'kubeadm']

  if $disable_swap {
    exec { 'disable swap':
      path    => ['/usr/sbin/', '/usr/bin', '/bin', '/sbin'],
      command => 'swapoff -a',
      unless  => "awk '{ if (NR > 1) exit 1}' /proc/swaps",
    }
  }

  if $manage_kernel_modules and $manage_sysctl_settings {
    kmod::load { 'br_netfilter':
      before => Sysctl['net.bridge.bridge-nf-call-iptables'],
    }
    sysctl { 'net.bridge.bridge-nf-call-iptables':
      ensure => present,
      value  => '1',
      before => Sysctl['net.ipv4.ip_forward'],
    }
    sysctl { 'net.ipv4.ip_forward':
      ensure => present,
      value  => '1',
    }
  } elsif $manage_kernel_modules {

    kmod::load { 'br_netfilter': }

  } elsif $manage_sysctl_settings {
    sysctl { 'net.bridge.bridge-nf-call-iptables':
      ensure => present,
      value  => '1',
      before => Sysctl['net.ipv4.ip_forward'],
    }
    sysctl { 'net.ipv4.ip_forward':
      ensure => present,
      value  => '1',
    }
  }

  if $controller and $manage_etcd {
    if $etcd_install_method == 'wget' {
      archive { $etcd_archive:
        path            => "/${etcd_archive}",
        source          => $etcd_source,
        extract         => true,
        extract_command => 'tar xfz %s --strip-components=1 -C /usr/local/bin/',
        extract_path    => '/usr/local/bin',
        cleanup         => true,
        creates         => ['/usr/local/bin/etcd', '/usr/local/bin/etcdctl']
      }
    } elsif $etcd_install_method == 'package' {
      package { $etcd_package_name:
        ensure => $etcd_version,
      }
    }
  }

  if $create_repos and $facts['os']['family'] == 'Debian' {
        package { $kube_packages:
          ensure  => $kubernetes_package_version,
          require => Class['Apt::Update'],
        }
  }else {
    package { $kube_packages:
      ensure => $kubernetes_package_version,
    }
  }

}
