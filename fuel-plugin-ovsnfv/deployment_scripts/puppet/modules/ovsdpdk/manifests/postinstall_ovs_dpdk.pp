# == Class ovsdpdk::postinstall_ovs_dpdk
#
# Postinstall configuration of ovs-dpdk service
#
class ovsdpdk::postinstall_ovs_dpdk (
  $plugin_dir               = $::ovsdpdk::params::plugin_dir,
  $nova_conf                = $::ovsdpdk::params::nova_conf,
  $openvswitch_service_name = $::ovsdpdk::params::openvswitch_service_name,
  $ml2_ovs_conf             = $::ovsdpdk::params::ml2_ovs_conf,
  $neutron_l3_conf          = $::ovsdpdk::params::neutron_l3_conf,
  $openvswitch_agent        = $::ovsdpdk::params::openvswitch_agent,
) inherits ovsdpdk {

  require ovsdpdk::install_ovs_dpdk

  package {'crudini': ensure => installed }

  if $compute == 'True' {
	  # adapt configuration files
	  exec {'adapt_nova_conf':
	    command => "${plugin_dir}/files/set_vcpu_pin.sh ${nova_conf}",
	    path    => ['/usr/bin','/bin'],
	    user    => root,
	    onlyif  => "test -f ${nova_conf}",
	    require => Package['crudini'],
	  }

	  exec {'adapt_ml2_conf':
	    command => "sudo crudini --set ${ml2_ovs_conf} ovs datapath_type ${ovs_datapath_type}",
	    path    => ['/usr/bin','/bin'],
	    user    => root,
	    onlyif  => "test -f ${ml2_ovs_conf}",
	    require => Package['crudini'],
	  }

	  exec {'adapt_neutron_l3':
	    command => "sudo crudini --set ${neutron_l3_conf} DEFAULT external_network_bridge br-ex",
	    path    => ['/usr/bin','/bin'],
	    user    => root,
	    onlyif  => "test -f ${neutron_l3_conf}",
	    require => Package['crudini'],
	  }


	  service {"${openvswitch_service_name}": ensure => 'running' }

	  # restart OVS to synchronize ovsdb-server with ovs-vswitchd needed
	  # due to several new --no-wait entries
	  exec {'restart_ovs':
	    command => "/usr/sbin/service ${openvswitch_service_name} restart",
	    user    => root,
	    require => Service["${openvswitch_service_name}"],
	  }

	  exec { "${plugin_dir}/files/configure_bridges.sh ${ovs_datapath_type}":
        user    => root,
        require => Exec['restart_ovs'],
      }
  }

  if $controller == 'True' {
    service {'neutron-server':
       ensure => 'running',
    }
  }

  if $compute == 'True' {
	  service {"${openvswitch_agent}":
	    ensure  => 'running',
	    require => [ Exec['restart_ovs'], Service["${openvswitch_service_name}"] ],
	  }
  }

}