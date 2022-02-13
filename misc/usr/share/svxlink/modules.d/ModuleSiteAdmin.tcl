###############################################################################
#
# SiteAdmin module implementation
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
  return;
}

#
# Extract the module name from the current namespace
#
set module_name [namespace tail [namespace current]]

#
# The user id of the currently logged in user
#
set userid "";

#
# The current state of the SiteAdmin module
#
set state "idle";

#
# Configuration file names
#
set cfg_etc "/etc/svxlink/SiteAdmin.conf";
set cfg_home ""
if {[info exists ::env(HOME)]} {
  set cfg_home "$env(HOME)/.svxlink/SiteAdmin.conf";
}

#
# A convenience function for printing out information prefixed by the
# module name
#
#   msg - The message to print
#
proc printInfo {msg} {
  variable module_name
  puts "$module_name: $msg"
}


#
# A convenience function for calling an event handler
#
#   ev - The event string to execute
#
proc processEvent {ev} {
  variable module_name
  ::processEvent "$module_name" "$ev"
}

#
# Read configuration file
#
if {$cfg_home != "" && [file exists $cfg_home]} {
  source $cfg_home;
} elseif [file exists $cfg_etc] {
  source $cfg_etc;
} else {
  set info_str "*** ERROR: Could not find a configuration file in module \"$module_name\". Tried "
  if {$cfg_home != ""} {
    set info_str "$info_str \"$cfg_home\" and"
  }
  set info_str "$info_str \"$cfg_etc\""
  printInfo "$info_str"
  exit 1;
}

#
# Read the specified user configuration variable for the specified user ID
#
#   id  - User ID
#   var - The name of the user variable to read
#
proc id2var {id var} {
  variable users;
  array set user [split $users($id) " ="];
  if {[array names user -exact $var] != ""} {
    return $user($var);
  } else {
    return "";
  }
}

#
# Executed when this module is being activated
#
proc activateInit {} {
  setState "login"
  printInfo "Module activated"
}


#
# Executed when this module is being deactivated.
#
proc deactivateCleanup {} {
  variable userid
  set userid ""
  setState "idle"
  printInfo "Module deactivated"
}


#
# Executed when a DTMF digit (0-9, A-F, *, #) is received
#
#   char - The received DTMF digit
#   duration - The duration of the received DTMF digit
#
proc dtmfDigitReceived {char duration} {
  printInfo "DTMF digit $char received with duration $duration milliseconds"
}


#
# Executed when a DTMF command is received
#
#   cmd - The received DTMF command
#
proc dtmfCmdReceived {cmd} {
  printInfo "DTMF command received: $cmd"
  variable state;
  
  if {$state == "login"} {
      if {$cmd == "0"} {
        processEvent "play_help"
      } else {
        cmdLogin $cmd;
      }
  } elseif {$state == "logged_in"} {
    if {$cmd == ""} {
      deactivateModule;
    } elseif {$cmd == "0"} {
      processEvent "play_loggedin_help"
    } elseif {$cmd == "10"} {
      #Power off
      printInfo "Powering off"
      exec sudo /usr/sbin/poweroff
    } elseif {$cmd == "69"} {
      #Restart svxlink
      printInfo "Restarting SvxLink"
      exec sudo /usr/sbin/service svxlink restart      
    } elseif {$cmd == "73"} {
      #Reboot
      printInfo "Rebooting"
      exec sudo /usr/sbin/reboot
    } elseif {$cmd == "77"} {
      #Kill svxlink
      printInfo "Killing SvxLink"
      exec sudo /usr/sbin/service svxlink stop
    } elseif {$cmd == "87"} {
      # Say IP address
      printInfo "Saying IP address"
      set ip_address [getIp]
      printInfo "IP address is $ip_address"
      processEvent "play_ip_address $ip_address"
    } elseif {$cmd == "88"} {
      # Say host and os and os version
      printInfo "Saying host, os and os version"
      set os [exec /usr/bin/lsb_release -i | cut -f2]
      set os_codename [exec /usr/bin/lsb_release -c | cut -f2]
      set os_version [exec /usr/bin/lsb_release -r | cut -f2]
      printInfo $os
      printInfo $os_codename
      printInfo $os_version
      processEvent "play_os_info $os $os_codename $os_version"
    } elseif {[regexp {^22} $cmd]} {
      # run command that is prefixed with 22
      printInfo "Command is $cmd"
      processCommand $cmd;
    } else {
      processEvent "unknown_command $cmd"
    }
  } else {
    printInfo "*** ERROR: Encountered unknown state \"$state\""
    processEvent "module_error"
    deactivateModule
  }
}

#
# Executed when a DTMF command is received in idle mode. That is, a command is
# received when this module has not been activated first.
#
#   cmd - The received DTMF command
#
proc dtmfCmdReceivedWhenIdle {cmd} {
  setState "idle"
  printInfo "DTMF command received when idle: $cmd"
  printInfo "*** ERROR: DTMF in idle is not supported due to the dangerous nature of the plugin!"
  processEvent "module_error"
  deactivateModule
}

#
# Executed when the squelch open or close.
#
#   is_open - Set to 1 if the squelch is open otherwise it's set to 0
#
proc squelchOpen {is_open} {
  if {$is_open} {set str "OPEN"} else { set str "CLOSED"}
  printInfo "The squelch is $str"
}

#
# Executed when all announcement messages has been played.
# Note that this function also may be called even if it wasn't this module
# that initiated the message playing.
#
proc allMsgsWritten {} {
  printInfo "allMsgsWritten called..."
}

#
# Set a new state
#
#   new_state - The new state to set
#
proc setState {new_state} {
  variable state $new_state
}


#
# State "login" command handler
#
#   cmd - The received command
#
proc cmdLogin {cmd} {
  variable userid;
  variable users;
  variable state;

  if {$cmd == ""} {
    printInfo "Aborting login"
    processEvent "login_aborted"
    deactivateModule
    return;
  }

  set userid [string range $cmd 0 2];
  if {[array names users -exact "$userid"] != ""} {
    array set user [split $users($userid) ",="];
    set passwd [string range $cmd 3 end];
    if {$passwd == $user(pass)} {
      printInfo "User $user(call) logged in with password $user(pass)";
      processEvent "login_successful $user(call)"
      setState "logged_in";
    } else {
      printInfo "Wrong password ($passwd) for user $user(call)";
      processEvent "login_unsuccessful"
    }
  } else {
    printInfo "Could not find user id $userid"
    processEvent "login_unsuccessful"
  }
}

#
# Command processor
#
#   cmd - The received command
#
proc processCommand {cmd} {
  variable userid;
  variable state;
  variable commands;
  variable commandid;

  set commandid [string range $cmd 2 end];
  printInfo "Command truncated is $commandid"

  if {[array names commands -exact "$commandid"] != ""} {
    array set command [split $commands($commandid) ",="];
    set command_to_run "$command(command)";
    if {$command_to_run != ""} {
      printInfo "Running command $command(description) as $command(command) by $userid"
      exec $command_to_run 
   } else {
      printInfo "Empty command!"
      processEvent "unknown_command $cmd"
   }
  } else {
    printInfo "Could not find command id $commandid"
    processEvent "unknown_command $cmd"
  }
}

#
#   Get IP address
#

proc getIp {{target www.google.com} {port 80}} {
     set s [socket $target $port]
     set res [fconfigure $s -sockname]
     close $s
     lindex $res 0
}

# end of namespace
}


#
# This file has not been truncated
#
