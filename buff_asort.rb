# No restrictions. Copy at will. Claim you wrote it. I don't care. #

# Basic data structure
# $irc = {server1 => [chan1,chan2,chan3], server2 => [chan1,chan2,pm1,pm2]} (server_name.short_name name should be unique)
# $plugins = [name1,name2,name3] (name should be unique)

SCRIPT_NAME = 'buff_asort'
SCRIPT_AUTHOR = 'torque'
SCRIPT_DESC = 'Automatic, case insensitive buffer sort by network.'
SCRIPT_VERSION = 'derp'
SCRIPT_LICENSE = 'Anything.'

def weechat_init
  Weechat.register(SCRIPT_NAME, SCRIPT_AUTHOR, SCRIPT_VERSION, SCRIPT_LICENSE, SCRIPT_DESC, "", "")
  Weechat.hook_signal("buffer_opened", "add_new_buf", "") # this hook occurs before the buffer is passed to its respective plugin for initialization of variables.
  Weechat.hook_signal("irc_server_opened", "add_new_serv", "")
  Weechat.hook_signal("irc_channel_opened", "add_new_chan", "")
  Weechat.hook_signal("irc_pv_opened", "add_new_chan", "") # no reason for these to be handled differently
  #Weechat.hook_signal("buffer_renamed", "move_buffer", "") # todo: actually make it handle renamed buffers (I wonder if this hook overlaps with buffer_opened and all three irc hooks)
  Weechat.hook_signal("buffer_closed","rebuild","") # todo: change this to buffer_closing and remove the buffer in question instead of regenerating the whole thing
  Weechat.hook_command("buff_sort","Sort buffers case insensitively.","","","","reorganize_all_buffers","")
  Weechat.hook_command("buff_debug","print shit.","","","","print_shit","")
  reorganize_all_buffers("",Weechat.current_buffer(),"") # sort on script load. Not sure how useful this is, though.
  return Weechat::WEECHAT_RC_OK
end

def print_shit(a,b,c)
  Weechat.print("","irc: #{$irc.to_s}")
  Weechat.print("","plugins: #{$plugins.to_s}")
end

def getnumber(item, term)
  return item.flatten.index(term)
end

def sort_chans(server)
  $irc[server].sort! {|a,b| a.downcase <=> b.downcase }
end

def sort_servers
  herp = $irc.sort_by {|k,v| k.downcase } # converts top level to array
  $irc = {}
  (0..herp.length-1).each {|i| $irc[herp[i][0]] = herp[i][1]} # rebuild organized hash
end

def sort_plugin_buffs
  $plugins.sort! {|a,b| a.downcase <=> b.downcase }
end

def add_new_buf(data, signal, buff_p)
  if Weechat.buffer_get_string(buff_p,"full_name").match(/^irc\./)
    #Weechat.print("","irc-related channel")
    return Weechat::WEECHAT_RC_OK
  else
    longname = Weechat.buffer_get_string(buff_p,"name")
    $plugins << longname
    sort_plugin_buffs()
    bufn = getnumber($plugins,longname) + $irc.flatten(2).length + 2
    #Weechat.print("","#{bufn}")
    Weechat.command("","/buffer #{longname}")
    Weechat.command("","/buffer move #{bufn}")
    return Weechat::WEECHAT_RC_OK
  end
end

def add_new_serv(data, signal, buff_p)
  server = Weechat.buffer_get_string(buff_p,"name")
  $irc[server] = [] # shouldn't need to check that 
  sort_servers()
  bufn = getnumber($irc.flatten,server) + 2
  Weechat.command("","/buffer #{server}")
  Weechat.command("","/buffer move #{bufn}")
  return Weechat::WEECHAT_RC_OK
end

def add_new_chan(data, signal, buff_p) # plugin will /always/ be irc
  longname = Weechat.buffer_get_string(buff_p,"name")
  obuff_p = Weechat.current_buffer()
  server = "server." + longname[0,longname.length - Weechat.buffer_get_string(buff_p,"short_name").length - 1]
  $irc[server] << longname # keep it unique.
  sort_chans(server)
  bufn = getnumber($irc.flatten,longname) + 2 # +2 to account for 0-index array and core being buffer 1
  Weechat.command("","/buffer #{longname}")
  Weechat.command("","/buffer move #{bufn}")
  if obuff_p != buff_p # return to original buffer if the new buffer opened in the background
    Weechat.command("","/buffer #{Weechat.buffer_get_string(obuff_p,"name")}")
  end
  return Weechat::WEECHAT_RC_OK
end

def reorganize_all_buffers(data, buff_p, signal)
  obuf = Weechat.buffer_get_string(buff_p,"name")
  get_cur_buffers
  i = 2
  $irc.each_key {|k| sort_chans(k) }
  sort_servers()
  $irc.flatten(2).each do |buf| # () unnecessary
    Weechat.command("","/buffer #{buf}")
    Weechat.command("","/buffer move #{i}")
    i += 1
  end
  sort_plugin_buffs()
  $plugins.each do |buf|
    Weechat.command("","/buffer #{buf}")
    Weechat.command("","/buffer move #{i}")
    i += 1
  end
  Weechat.command("","/buffer core.weechat") # move to the core buffer
  Weechat.command("","/buffer move 1") # move it to the first buffer
  Weechat.command("","/buffer #{obuf}") # return to original buffer
  return Weechat::WEECHAT_RC_OK
end

def rebuild(data, buff_p, signal)
  get_cur_buffers
  return Weechat::WEECHAT_RC_OK
end

def get_cur_buffers
  $irc = {}
  $plugins = [] # global variables are probably the most terrible way of handling this possible
  infolist = Weechat.infolist_get("buffer","","")
  if infolist then
    while Weechat.infolist_next(infolist) != 0 # 0 does not evaluate to false in ruby
      longname = Weechat.infolist_string(infolist,"name")
      if longname == "weechat" #only the core should match this.
        next
      end
      plugin = Weechat.infolist_string(infolist,"plugin_name")
      if plugin == "irc"
        if longname.match(/^server\./) # name.match(/^server\./) then
          $irc[longname] = [] if not $irc[longname]
        else
          server = "server." + longname[0,longname.length - Weechat.infolist_string(infolist,"short_name").length - 1]
          $irc[server] = [] if not $irc[server]
          $irc[server] << longname
        end
      else
        $plugins << longname
      end
    end
  end
  Weechat.infolist_free(infolist)
end