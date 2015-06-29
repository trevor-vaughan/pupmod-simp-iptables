[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-iptables.svg)](https://travis-ci.org/simp/pupmod-simp-iptables) [![SIMP compatibility](https://img.shields.io/badge/SIMP%20compatibility-4.2.*%2F5.1.*-orange.svg)](https://img.shields.io/badge/SIMP%20compatibility-4.2.*%2F5.1.*-orange.svg)

## Work in Progress

Please excuse us as we transition this code into the public domain.

Downloads, discussion, and patches are still welcome!


#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with iptables](#setup)
    * [What iptables affects](#what-iptables-affects)
    * [Beginning with iptables](#beginning-with-iptables)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
    * [Classes](#classes)
      * [iptables](#iptables)
    * [Defined Types](#defined-types)
      * [add_all_listen](#add_all_listen)
      * [add_icmp_listen](#add_icmp_listen)
      * [add_rules](#add_rules)
      * [add_tcp_stateful_listen](#add_tcp_stateful_listen)
      * [add_udp_stateful_listen](#add_udp_stateful_listen)

6. [Limitations - OS compatibility, etc.](#limitations)
7. [Development - Guide for contributing to the module](#development)

## Overview

This sets the system up in a way that will maximally utilize the iptables native types.  Works with EL6 and EL7.

**NOTE**: To be as safe as possible, this module will only apply changes in one 'flush' call. This avoids issues where individual rules would be applied prior to an entire ruleset, potentially harming the integrity of the system.


## This is a SIMP module
This module is a component of the [https://github.com/NationalSecurityAgency/SIMP](System Integrity Management Platform), a managed security compliance framework built on Puppet.

This module is optimally designed for use within a larger SIMP ecosystem.  When included within the SIMP ecosystem, security compliance settings will be managed from the Puppet server.


## Module Description

**FIXME:** The text below is boilerplate copy.  Ensure that it is correct and remove this message!

If applicable, this section should have a brief description of the technology the module integrates with and what that integration enables. This section should answer the questions: "What does this module *do*?" and "Why would I use it?"

If your module has a range of functionality (installation, configuration, management, etc.) this is the time to mention it.

## Setup

### What iptables affects

iptables manages the `iptables` package, service, and rules.  On EL7+, it will disabled the `firewalld` service.

**FIXME:** The text below is boilerplate copy.  Ensure that it is correct and remove this message!

* A list of files, packages, services, or operations that the module will alter, impact, or execute on the system it's installed on.
* This is a great place to stick any warnings.
* Can be in list or paragraph form.

### Beginning with iptables

**NOTE** simp-iptables is not yet on Puppet Forge

Ensure simp-iptables is installed somewhere within your modulepath as `iptables`.

## Usage

**FIXME:** The text below is boilerplate copy.  Ensure that it is correct and remove this message!

Put the classes, types, and resources for customizing, configuring, and doing the fancy stuff with your module here.

## Reference

### Classes

#### `iptables`

This sets the system up in a way that will maximally utilize the iptables native types.

##### Parameters

* `authoritative`: If true, only iptables rules set by Puppet may be present on the system. Otherwise, only manage the *chains* that Puppet is managing.  Default: true

**WARNING:**  Be *extremely* careful with this option. If you don't match all of your rules that you want left around, but you also don't have something to clean up the various tables, you will get continuous warnings that IPTables rules are being optimized.

* `class_debug`: If true, the system will print messages regarding rule comparisons.  Default: false
* `optimize_rules`: If true, the inbuilt iptables rule optimizer will be run to collapse the rules down to as small as is reasonably possible without reordering. IPsets will be used eventually.  Default: true
* `ignore`: Set this to an Array of regular expressions that you would like to match in order to preserve running rules. This modifies the behavior of the optimize type.  Do not include the beginning and ending '/' but do include an end or beginning of word marker if appropriate.  Default: []
* `enable_default_rules`: If true, enable the usual set of default deny rules that you would expect to see on most systems.  Default: true

  This uses the following expectations of rule ordering (not enforced):
    * 1 -> ESTABLISHED,RELATED rules.
    * 2-5 -> Standard ACCEPT/DENY rules.
    * 6-10 -> Jumps to other rule sets.
    * 11-20 -> Pure accept rules.
    * 22-30 -> Logging and rejection rules.

* `enable_scanblock`: If true, enable a technique for setting up port-based triggers that will block anyone connecting to the system for an hour after connection to a forbidden port.  Default: false
* `disable`: If true, disable iptables management completely. The build will still happen but nothing will be enforced.  Default: false


### Defined Types

#### `add_all_listen`

This define provides a simple way to allow all protocols to all ports on the target system from a select set of networks.

##### Example

Command

       iptables::add_all_listen { 'example':
         client_nets => [ '1.2.3.4', '5.6.7.8' ],
       }

Output (to /`etc/sysconfig/iptables`)

       *filter
       :INPUT DROP [0:0]
       :FORWARD DROP [0:0]
       :OUTPUT ACCEPT [0:0]
       :LOCAL-INPUT - [0:0]
       -A INPUT -j LOCAL-INPUT
       -A FORWARD -j LOCAL-INPUT
       -A LOCAL-INPUT -p icmp --icmp-type 8 -j ACCEPT
       -A LOCAL-INPUT -i lo -j ACCEPT
       -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
       -A LOCAL-INPUT -s 1.2.3.4 -j ACCEPT
       -A LOCAL-INPUT -s 5.6.7.8 -j ACCEPT
       -A LOCAL-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
       -A LOCAL-INPUT -j LOG --log-prefix "IPT:"
       -A LOCAL-INPUT -j DROP
       COMMIT



#### `add_icmp_listen`
This provides a simple way to allow ICMP ports into the system.

##### Example

Command

    iptables::add_icmp_listen { "example":
        client_nets => [ "1.2.3.4", "5.6.7.8" ],
        icmp_type => '8'
    }

Output (to /`etc/sysconfig/iptables`)

    *filter
    :INPUT DROP [0:0]
    :FORWARD DROP [0:0]
    :OUTPUT ACCEPT [0:0]
    :LOCAL-INPUT - [0:0]
    -A INPUT -j LOCAL-INPUT
    -A FORWARD -j LOCAL-INPUT
    -A LOCAL-INPUT -p icmp --icmp-type 8 -j ACCEPT
    -A LOCAL-INPUT -i lo -j ACCEPT
    -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
    -A LOCAL-INPUT -p icmp -s 1.2.3.4 --icmp-type 8 -j ACCEPT
    -A LOCAL-INPUT -p icmp -s 5.6.7.8 --icmp-type 8 -j ACCEPT
    -A LOCAL-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    -A LOCAL-INPUT -j LOG --log-prefix "IPT:"
    -A LOCAL-INPUT -j DROP
    COMMIT


#### `add_rules`

This function allows you to add rules to the iptables configuration file.  These rules should be uniquely named.  Rules are added to `/etc/sysconfig/iptables`.

##### Parameters
All parameters are optional, unless otherwise noted.

* `content`: **Required.** The content of the rules that should be added.
* `table`:  Should be the name of the table you are adding to.  Default: 'filter'.
* `first`: Should be set to 'true' if you want to prepend your custom rules.
* `absolute`: Should be set to 'true' if you want the section to be absolutely first or last, depending on the setting of $first.  This is relative and basically places items in alphabetical order.
* `order`: The order in which the rule should appear.  1 is the minimum, 11 is the mean, and 9999999 is the max.

   The following ordering ranges are suggested:
     - **1**     --> ESTABLISHED,RELATED rules.
     - **2-5**   --> Standard ACCEPT/DENY rules.
     - **6-10**  --> Jumps to other rule sets.
     - **11-20** --> Pure accept rules.
     - **22-30** --> Logging and rejection rules.
   These are suggestions and are not enforced.

* `comment`: A comment to prepend to the rule.  Default: ''.
* `header`:  Whether or not to include the line header `'-A LOCAL-INPUT'`.  Default: true.
* `apply_to`: iptables target.  Default: 'auto'.
     - **ipv4** -> iptables
     - **ipv6** -> ip6tables
     - **all**  -> Both
     - **auto** -> Try to figure it out from the rule, will not pick `all`.

##### Example

Command

       iptables::add_rules { 'example':
           content => '-A LOCAL-INPUT -m state --state NEW -m tcp -p tcp\
           -s 1.2.3.4 --dport 1024:65535 -j ACCEPT'
       }

Output (to /`etc/sysconfig/iptables`)

      *filter
      :INPUT DROP [0:0]
      :FORWARD DROP [0:0]
      :OUTPUT ACCEPT [0:0]
      :LOCAL-INPUT - [0:0]
      -A INPUT -j LOCAL-INPUT
      -A FORWARD -j LOCAL-INPUT
      -A LOCAL-INPUT -p icmp --icmp-type 8 -j ACCEPT
      -A LOCAL-INPUT -i lo -j ACCEPT
      -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
      -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp -s 1.2.3.4 --dport 1024:65535 -j ACCEPT
      -A LOCAL-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
      -A LOCAL-INPUT -j LOG --log-prefix "IPT:"
      -A LOCAL-INPUT -j DROP
      COMMIT


#### `add_tcp_stateful_listen`

This provides a simple way to allow TCP ports into the system.

##### Parameters
All parameters are optional, unless otherwise noted.

* `dports`: **Required.** The ports to which to allow entry.  Single ports and port ranges (1:100) are both allowed.  Set the string to 'any' to allow all ports.
* `first`: Should be set to 'true' if you want to prepend your custom rules.
* `absolute`: Should be set to 'true' if you want the section to be absolutely first or last, depending on the setting of $first.  This is relative and basically places items in alphabetical order.
* `order`: The order in which the rule should appear.  1 is the minimum, 11 is the mean, and 9999999 is the max.

   The following ordering ranges are suggested:
     - **1**     --> ESTABLISHED,RELATED rules.
     - **2-5**   --> Standard ACCEPT/DENY rules.
     - **6-10**  --> Jumps to other rule sets.
     - **11-20** --> Pure accept rules.
     - **22-30** --> Logging and rejection rules.
   These are suggestions and are not enforced.

* `apply_to`: iptables target.  Default: 'auto'.
     - **ipv4** -> iptables
     - **ipv6** -> ip6tables
     - **all**  -> Both
     - **auto** -> Try to figure it out from the rule, will not pick `all`.
* `client_nets`: Client networks that should be allowed by this rule.  Set the string to `any` to allow all networks

##### Example

Command

       iptables::add_tcp_stateful_listen { 'example':
           client_nets => [ '1.2.3.4', '5.6.7.8' ],
           dports => [ '5', '1024:65535' ]
       }

Output (to /`etc/sysconfig/iptables`)

       *filter
       :INPUT DROP [0:0]
       :FORWARD DROP [0:0]
       :OUTPUT ACCEPT [0:0]
       :LOCAL-INPUT - [0:0]
       -A INPUT -j LOCAL-INPUT
       -A FORWARD -j LOCAL-INPUT
       -A LOCAL-INPUT -p icmp --icmp-type 8 -j ACCEPT
       -A LOCAL-INPUT -i lo -j ACCEPT
       -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
       -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp -s 1.2.3.4 --dport 5 -j ACCEPT
       -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp -s 5.6.7.8 --dport 5 -j ACCEPT
       -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp -s 1.2.3.4 --dport 1024:65535 -j ACCEPT
       -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp -s 5.6.7.8 --dport 1024:65535 -j ACCEPT
       -A LOCAL-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
       -A LOCAL-INPUT -j LOG --log-prefix "IPT:"
       -A LOCAL-INPUT -j DROP
       COMMIT

#### `add_udp_stateful_listen`

This provides a simple way to allow UDP ports into the system.

##### Parameters

* `dports`: **Required.** The ports to which to allow entry.  Single ports and port ranges (1:100) are both allowed.  Set the string to 'any' to allow all ports.
* `first`: Should be set to 'true' if you want to prepend your custom rules.
* `absolute`: Should be set to 'true' if you want the section to be absolutely first or last, depending on the setting of $first.  This is relative and basically places items in alphabetical order.
* `order`: The order in which the rule should appear.  1 is the minimum, 11 is the mean, and 9999999 is the max.

   The following ordering ranges are suggested:
     - **1**     --> ESTABLISHED,RELATED rules.
     - **2-5**   --> Standard ACCEPT/DENY rules.
     - **6-10**  --> Jumps to other rule sets.
     - **11-20** --> Pure accept rules.
     - **22-30** --> Logging and rejection rules.
   These are suggestions and are not enforced.

* `apply_to`: iptables target.  Default: 'auto'.
     - **ipv4** -> iptables
     - **ipv6** -> ip6tables
     - **all**  -> Both
     - **auto** -> Try to figure it out from the rule, will not pick `all`.
* `client_nets`: Client networks that should be allowed by this rule.  Set the string to `any` to allow all networks

##### Example

Command

       iptables::add_udp_stateful_listen { 'example':
           client_nets => [ '1.2.3.4', '5.6.7.8' ],
           dports => [ '5', '1024:65535' ]
       }

Output (to /`etc/sysconfig/iptables`)

      *filter
      :INPUT DROP [0:0]
      :FORWARD DROP [0:0]
      :OUTPUT ACCEPT [0:0]
      :LOCAL-INPUT - [0:0]
      -A INPUT -j LOCAL-INPUT
      -A FORWARD -j LOCAL-INPUT
      -A LOCAL-INPUT -p icmp --icmp-type 8 -j ACCEPT
      -A LOCAL-INPUT -i lo -j ACCEPT
      -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
      -A LOCAL-INPUT -s 1.2.3.4/32 -p udp -m state --state NEW -m multiport --dports 1024:65535,5 -j ACCEPT
      -A LOCAL-INPUT -s 5.6.7.8/32 -p udp -m state --state NEW -m multiport --dports 1024:65535,5 -j ACCEPT
      -A LOCAL-INPUT -p udp -s 1.2.3.4 --dport 5 -j ACCEPT
      -A LOCAL-INPUT -p udp -s 5.6.7.8 --dport 5 -j ACCEPT
      -A LOCAL-INPUT -p udp -s 1.2.3.4 --dport 1024:65535 -j ACCEPT
      -A LOCAL-INPUT -p udp -s 5.6.7.8 --dport 1024:65535 -j ACCEPT
      -A LOCAL-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
      -A LOCAL-INPUT -j LOG --log-prefix "IPT:"
      -A LOCAL-INPUT -j DROP
      COMMIT



## Limitations
* IPv6 support has never been tested properly and probably doesn't work.
* `firewalld` must be disabled.  The module will disable `firewalld` if it is present.
* This module is intended to be used on a Redhat Enterprise Linux-compatible distribution such as EL6 and EL7.

## Development

Please see the [SIMP Contribution Guidelines](https://simp-project.atlassian.net/wiki/display/SD/Contributing+to+SIMP).

## Release Notes/Contributors/Etc **Optional**

If you aren't using changelog, put your release notes here (though you should consider using changelog). You may also add any additional sections you feel are necessary or important to include here. Please use the `## ` header.

## Acceptance tests

To run the system tests, you need [Vagrant](https://www.vagrantup.com/) installed. Then, run:

    bundle exec rake acceptance

Some environment variables may be useful:

    BEAKER_debug=true
    BEAKER_provision=no
    BEAKER_destroy=no
    BEAKER_use_fixtures_dir_for_modules=yes
    BEAKER_skip_unsolved_mysteries=yes

* The `BEAKER_debug` variable shows the commands being run on the STU and their output.
* `BEAKER_destroy=no` prevents the machine destruction after the tests finish so you can inspect the state.
* `BEAKER_provision=no` prevents the machine from being recreated. This can save a lot of time while you're writing the tests.
* `BEAKER_use_fixtures_dir_for_modules=yes` causes all module dependencies to be loaded from the `spec/fixtures/modules` directory, based on the contents of `.fixtures.yml`.  The contents of this directory are usually populated by `bundle exec rake spec_prep`.  This can be used to run acceptance tests to run on isolated networks.
* `BEAKER_skip_unsolved_mysteries=yes` skips mysterious problems we haven't solved but are "tolerated" prior to release.  *TODO*: This variable should go away by the release of SIMP 6.

