###############################################################################
#
# SiteAdmin module event handlers
#
###############################################################################

#
# This is the namespace in which all functions and variables below will exist.
# The name must match the configuration variable "NAME" in the
# [ModuleTcl] section in the configuration file. The name may be changed
# but it must be changed in both places.
#
namespace eval SiteAdmin {

#
# Check if this module is loaded in the current logic core
#
if {![info exists CFG_ID]} {
  return
}


#
# Extract the module name from the current namespace
#
set module_name [namespace tail [namespace current]]


#
# An "overloaded" playMsg that eliminates the need to write the module name
# as the first argument.
#
#   msg - The message to play
#
proc playMsg {msg} {
  variable module_name
  ::playMsg $module_name $msg
}


#
# A convenience function for printing out information prefixed by the
# module name.
#
#   msg - The message to print
#
proc printInfo {msg} {
  variable module_name
  puts "$module_name: $msg"
}


#
# Executed when this module is being activated
#
proc activating_module {} {
  variable module_name
  Module::activating_module $module_name
  playMsg "login"
}

#
# Executed when this module is being deactivated.
#
proc deactivating_module {} {
  variable module_name
  Module::deactivating_module $module_name
}


#
# Executed when the inactivity timeout for this module has expired.
#
proc timeout {} {
  variable module_name
  Module::timeout $module_name
}


#
# Executed when playing of the help message for this module has been requested.
#
proc play_help {} {
  variable module_name
  Module::play_help $module_name
}


#
# Executed when the state of this module should be reported on the radio
# channel. The rules for when this function is called are:
#
# When a module is active:
# * At manual identification the status_report function for the active module is
#   called.
# * At periodic identification no status_report function is called.
#
# When no module is active:
# * At both manual and periodic (long variant) identification the status_report
#   function is called for all modules.
#
proc status_report {} {
  printInfo "status_report called..."
}

#
# Called when a fatal module error ocurrs after which the module is deactivated
#
proc module_error {} {
  playMsg "operation_failed"
}

#
# Executed when playing of the help message for this module has been requested and the user is logged in.
#
proc play_loggedin_help {} {
  playMsg "help_logged_in"
  playSilence 500
}

#
# Called when the login procedure is aborted.
#
proc login_aborted {} {
  playMsg "aborted"
  playSilence 500
}

#
# Called when login is approved.
#
#   call - User callsign
#
proc login_successful {call} {
  spellWord $call
  playSilence 500
  playMsg "login_successful"
  playSilence 500
}

#
# Called when login is not approved.
#
#
#
proc login_unsuccessful {} {
  playMsg "login_unsuccessful"
  playSilence 500
  playMsg "login"
}

#
# Spell out OS info
#
#   os - OS name
#   os_codename - OS code name
#   os_version - OS version
#
proc play_os_info {os os_codename os_version} {
  spellWord $os
  playSilence 250
  spellWord $os_codename
  playSilence 250
  spellWord $os_version
  playSilence 500
}

#
# Spell IP address
#
#   ip - IP address to spell
#
proc play_ip_address {ip} {
  spellWord $ip
  playSilence 250
}

#
# Called when login fails due to entering an invalid user ID
#
#   userid - The entered, invalid, user ID
#
proc login_failed_unknown_userid {userid} {
  playMsg "wrong_userid_or_password"
  playSilence 500
  playMsg "login"
}


#
# Called when login fails due to entering the wrong password
#
#   call     - User callsign
#   userid   - User ID
#   password - The entered password
#
proc login_failed_wrong_password {call userid password} {
  playMsg "wrong_userid_or_password"
  playSilence 500
  playMsg "login"
}

#
# Called when an illegal command has been entered
#
#   cmd - The received command
#
proc unknown_command {cmd} {
  playNumber $cmd
  playMsg "unknown_command"
}



# end of namespace
}


#
# This file has not been truncated
#
