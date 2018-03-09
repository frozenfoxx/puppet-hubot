# == Class: hubot::config
#
# Configures hubot
# Private class
#
#
# === Authors
#
# * Foxx Block <mailto:siliconfoxx@gmail.com>
# * Justin Lambert <mailto:jlambert@letsevenup.com>
#
#
# === Copyright
#
# Copyright 2013 EvenUp.
#
class hubot::config {

  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }

  $dependencies     = $::hubot::dependencies
  $exports          = $::hubot::env_export
  $external_scripts = $::hubot::external_scripts
  $hubotversion     = $::hubot::hubot_version
  $scripts          = $::hubot::scripts

  case $hubot::init_style {
    'upstart': {
      file { '/etc/init.d/hubot':
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
        content => template("hubot/${hubot::params::hubot_init}"),
        notify  => Class['hubot::service'],
      }
      file { 'hubot upstart':
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        path    => '/etc/init/hubot.conf',
        content => template('hubot/hubot.upstart.erb'),
      }
    }
    'systemd': {
      file { '/lib/systemd/system/hubot.service':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('hubot/hubot.systemd.erb'),
      }
      ~> exec { 'hubot-systemd-reload':
        command     => 'systemctl daemon-reload',
        path        => [ '/usr/bin', '/bin', '/usr/sbin' ],
        refreshonly => true,
      }
    }
    default: {
      fail("init_style was not specified: ${hubot::init_style}!")
    }
  }

  if $::hubot::git_source {
    require 'git'

    if !defined(File["${::hubot::root_dir}/.ssh"]) {
      file { "${::hubot::root_dir}/.ssh":
        ensure => 'directory',
        owner  => 'hubot',
        group  => 'hubot',
        mode   => '0700',
      }
    }

    if !defined(File["${::hubot::root_dir}/.ssh/id_rsa"]) {
      file { "${::hubot::root_dir}/.ssh/id_rsa":
        ensure  => 'file',
        owner   => 'hubot',
        group   => 'hubot',
        mode    => '0600',
        content => $::hubot::ssh_privatekey,
        source  => $::hubot::ssh_privatekey_file,
      }
    }

    if $::hubot::auto_accept_host_key {
      file { "${::hubot::root_dir}/.ssh/config":
        owner   => 'hubot',
        group   => 'hubot',
        mode    => '0440',
        content => "Host *\n\tStrictHostKeyChecking no\n",
        before  => Vcsrepo["${::hubot::root_dir}/${::hubot::bot_name}"],
      }
    }

    # If your hubot config is stored in git (it is, right?), this will clone
    # it to this machine.  This assumes you have already accepted any ssh keys
    # and access needed.  Alternatively, most config can be done through puppet
    vcsrepo { "${::hubot::root_dir}/${::hubot::bot_name}":
      ensure   => latest,
      provider => git,
      source   => $::hubot::git_source,
      user     => 'hubot',
      revision => 'master',
      notify   => Class['hubot::service'],
    }

    unless empty($::hubot::env_export) {
      file { "${::hubot::root_dir}/${::hubot::bot_name}/hubot.env":
        ensure  => 'file',
        owner   => 'hubot',
        group   => 'hubot',
        mode    => '0440',
        content => template('hubot/hubot.env.erb'),
        notify  => Class['hubot::service'],
        require => Vcsrepo["${::hubot::root_dir}/${::hubot::bot_name}"],
      }
    }

  } else {
    file { "${::hubot::root_dir}/${::hubot::bot_name}":
      ensure  => 'directory',
      owner   => 'hubot',
      group   => 'hubot',
      mode    => '0750',
      require => File[$::hubot::root_dir],
    }

    exec { 'Hubot init':
      command   => 'yo hubot --defaults --no-insight',
      cwd       => "${::hubot::root_dir}/${::hubot::bot_name}/",
      creates   => "${::hubot::root_dir}/${::hubot::bot_name}/bin/hubot",
      path      => '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
      user      => 'hubot',
      group     => 'hubot',
      logoutput => 'on_failure',
      require   => File["${::hubot::root_dir}/${::hubot::bot_name}"],
    }

    file { "${::hubot::root_dir}/${::hubot::bot_name}/debug.sh":
      ensure  => 'file',
      owner   => 'hubot',
      group   => 'hubot',
      mode    => '0755',
      content => template('hubot/debug.sh.erb'),
      require => Exec['Hubot init'],
    }

    file { "${::hubot::root_dir}/${::hubot::bot_name}/hubot.env":
      ensure  => 'file',
      owner   => 'hubot',
      group   => 'hubot',
      mode    => '0440',
      content => template('hubot/hubot.env.erb'),
      notify  => Class['hubot::service'],
      require => Exec['Hubot init'],
    }

    file { "${::hubot::root_dir}/${::hubot::bot_name}/hubot-scripts.json":
      ensure  => 'file',
      owner   => 'hubot',
      group   => 'hubot',
      mode    => '0444',
      content => template('hubot/hubot-scripts.erb'),
      notify  => Class['hubot::service'],
      require => Exec['Hubot init'],
    }

    file { "${::hubot::root_dir}/${::hubot::bot_name}/external-scripts.json":
      ensure  => 'file',
      owner   => 'hubot',
      group   => 'hubot',
      mode    => '0444',
      content => template('hubot/external-scripts.erb'),
      notify  => Class['hubot::service'],
      require => Exec['Hubot init'],
    }

    file { "${::hubot::root_dir}/${::hubot::bot_name}/package.json":
      ensure  => 'file',
      owner   => 'hubot',
      group   => 'hubot',
      mode    => '0444',
      source => "puppet:///modules/${module_name}/package.json",
      notify  => Class['hubot::service'],
      require => Exec['Hubot init'],
    }
  }
}
