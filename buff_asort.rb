# No restrictions. Copy at will. Claim you wrote it. I don't care. #
SCRIPT_NAME = 'buff_asort'
SCRIPT_AUTHOR = 'torque'
SCRIPT_DESC = 'Automatic, case insensitive buffer sort by network.'
SCRIPT_VERSION = '1'
SCRIPT_LICENSE = 'Anything.'

def weechat_init
  Weechat.register(SCRIPT_NAME, SCRIPT_AUTHOR, SCRIPT_VERSION, SCRIPT_LICENSE, SCRIPT_DESC, "", "")
  sort_cur_buffers() # sort on script load. Not sure how useful this is, though.
  Weechat.hook_signal("buffer_opened", "add_new_buf", "")
  return Weechat::WEECHAT_RC_OK
end

def sort_and_stuff(names)
  names.each do |name|
    $buffers.each do |key,val|
      #Weechat.print("","server.#{name[0,key.length-7]} == #{key}")
      if "server.#{name[0,key.length-7]}" == key then # not sure this check is necessary: name[0,n.length-name[1].length-1] should resolve to a known key... but we can't use short name because buffer_get_string doesn't work right.
        $buffers[key] << name
        $buffers[key].sort! {|a,b| a.downcase <=> b.downcase} # problem with this: two identical strings will not change position, so ["A","a"] and ["a","A"] will be sorted differently. Not sure this matters.
      end
    end
  end
  newbarray = $buffers.sort_by {|k,v| k.downcase} # sort it
  return newbarray.flatten
end

def move_buffers(order_a)
  #Weechat.print("",order_a.to_s)
  order_a.each_with_index do |buf,i|
    Weechat.command("","/buffer #{buf}")
    Weechat.command("","/buffer move #{i+2}")
  end
end

def sort_cur_buffers
  $buffers = {}
  names = [] # initialize it early for scope reasons
  infolist = Weechat.infolist_get("buffer","","")
  if infolist then
    while Weechat.infolist_next(infolist) != 0 # 0 does not evaluate to false in ruby
      name = Weechat.infolist_string(infolist,"name")
      n = Weechat.infolist_string(infolist,"short_name")
      if name == "weechat" #only the core should match this.
        next
      end
      if name.match(/^server\./) then
        $buffers[name] = []
      else
        names << name
      end
    end
  end
  move_buffers(sort_and_stuff(names))
  Weechat.command("","/buffer core.weechat") #move to the core buffer
  Weechat.command("","/buffer move 1") # move it to the first buffer.
  Weechat.command("","/buffer 1") # I don't think there's a way of determining which buffer you're on when you load the script. Always move to buffer 1
end

def add_new_buf(data, signal, buffer_p)
  name = Weechat.buffer_get_string(buffer_p,"name") # and short_name doesn't work. Fabulous.
  names = []
  if name.match(/^server\./) and not $buffers[name] then # idk if it'd be possible to overwrite this anyway.
    $buffers[name] = []
  else
    names << name
  end # shouldn't need to worry about the new window being 
  move_buffers(sort_and_stuff(names))
  Weechat.command("","/buffer #{name}")
  return Weechat::WEECHAT_RC_OK
end