SCRIPT_NAME = 'autosort_buffers'
SCRIPT_AUTHOR = 'torque'
SCRIPT_DESC = 'Automatic, case insensitive irc buffer sort by network.' # horribly overengineered, too.
SCRIPT_VERSION = '0.1'
SCRIPT_LICENSE = 'WTFPL' # http://www.wtfpl.net/

class Core
	def initialize()
		@buffers = Hash.new
		@prepend_names = Array.new
		@buffer_names = Array.new
		@append_names = Array.new
	end

	attr_accessor :buffers, :prepend_names, :buffer_names, :append_names
end

class IRC
	def initialize()
		@servers = Hash.new
		@server_names = Array.new
		@channels = Hash.new
		@length = 0
	end

	# Add a new server, find its position, and move it there.
	def add_server( server )
		@servers[server.name] = server
		@server_names << server.name
		@server_names.sort! { |a,b| a.downcase <=> b.downcase }
		server.number = @server_names.index( server.name )
		before = 0
		@server_names[0, server.number].each { |server_name| # iterate through all of the servers before
			before += @servers[server_name].channel_names.length + 1
		}
		shift_server_pos( server.number, 1 )
		shift_server_num( server.number, 1 )
		server.set_position( before + 2 ) # + 2 to compensate for 0-index arrays and core being buffer 1
		@length += 1
	end
	
	# adding channels requires shifting servers, too
	def add_channel( channel )
		server = @servers[channel.server_name]
		@channels[channel.name] = channel
		server.add_channel( channel )
		shift_server_pos( server.number, 1 )
		@length += 1
	end

	def remove_server( server )
		# server.channel_names.each { |channel_name| @channels.delete( channel_name ) }
		shift_server_pos( server.number, -1 )
		shift_server_num( server.number, -1 )
		if server.channel_names.length == 0
			@servers.delete( server.name )
			@server_names.delete_at( server.number )
		else
			server.closed = true
		end
	end

	def remove_channel( channel )
		server = @servers[channel.server_name]
		@channels.delete( channel.name )
		shift_server_pos( server.number, -1 )
		server.remove_channel( channel )
		if server.closed && server.channel_names.length == 0
			@servers.delete( server.name )
			@server_names.delete_at( server.number )
		end
	end

	# shift all servers after the given server by NUM spaces.
	def shift_server_pos( server_number, num )
		@server_names[server_number + 1, @server_names.length - 1 - server_number].each { |server_name| 
			@servers[server_name].position += num
		}
	end

	# shift servers to keep alignment with server_names indices. num should always be +/-1
	def shift_server_num( server_number, num )
		@server_names[server_number + 1, @server_names.length - 1 - server_number].each { |server_name| 
			@servers[server_name].number += num
		}
	end

	def loggan()
		@servers.each { |name, server|
			log( "#{name}:")
			log( server.channel_names.join( ", " ) )
			log( server.position.to_s )
			log( server.number.to_s )
		}
	end

	def log( msg )
		Weechat.print( "", msg )
	end

	attr_accessor :servers, :server_names, :channels
end

class Server
	def initialize( buffer_pointer )
		@pointer = buffer_pointer
		@name = Weechat.buffer_get_string( @pointer, "name" )
		@position = Weechat.buffer_get_integer( @pointer, "number" )
		@number = 0
		@channels = Hash.new
		@channel_names = Array.new
		@closed = false
	end

	def add_channel( channel )
		@channels[channel.name] = channel
		@channel_names << channel.name
		@channel_names.sort! { |a,b| a.downcase <=> b.downcase }
		channel.number = channel_names.index( channel.name )
		@channel_names[channel.number,]
		channel.set_position( @position + channel.number + 1 )
		shift_channels( channel.number, 1 )
	end

	def remove_channel( channel )
		shift_channels( channel.number, -1 )
		@channels.delete( channel.name )
		@channel_names.delete_at( channel.number )
	end

	def shift_channels( channel_number, num )
		@channel_names[channel_number + 1, @channel_names.length - 1 - channel_number].each { |channel_name| 
			@channels[channel_name].number += num
		}
	end

	def set_position( new_position )
		Weechat.command( @pointer, "/buffer move #{new_position}" )
		@position = new_position
	end

	attr_reader :name, :pointer
	attr_accessor :position, :channels, :channel_names, :number, :closed
end

class Channel
	def initialize( buffer_pointer )
		@pointer = buffer_pointer
		@name = Weechat.buffer_get_string( @pointer, "name" )
		@server_name = "server.#{Weechat.buffer_get_string( @pointer, "localvar_server" )}"
		@number = 0
	end

	def set_position( new_position )
		Weechat.command( @pointer, "/buffer move #{new_position}" )
	end

	attr_reader :name, :pointer, :server_name
	attr_accessor :number
end

def add_new_server( _, __, buffer )
	$irc.add_server( Server.new( buffer ) )
	return Weechat::WEECHAT_RC_OK
end

def add_new_channel( _, __, buffer )
	$irc.add_channel( Channel.new( buffer ) )
	return Weechat::WEECHAT_RC_OK
end

def destroy_closed_buffer( _, __, buffer )
	case Weechat.buffer_get_string( buffer, "plugin" )
	when "irc"
		case Weechat.buffer_get_string( buffer, "localvar_type" )
		when "server"
			$irc.remove_server( $irc.servers[Weechat.buffer_get_string( buffer, "name" )] )
		else
			$irc.remove_channel( $irc.channels[Weechat.buffer_get_string( buffer, "name" )] )
		end
	else
		# handle things besides irc eventually
	end
	return Weechat::WEECHAT_RC_OK
end

def load_reload()
	infolist = Weechat.infolist_get("buffer","","")
	while Weechat.infolist_next(infolist) != 0 # 0 does not evaluate to false in ruby
		case Weechat.infolist_string( infolist, "plugin_name" )
		when "irc"
			case Weechat.infolist_string( infolist, "localvar_type" )
			when "server"
				add_new_server( "", "", Weechat.infolist_string( infolist, "pointer" ) )
			else
				add_new_channel( "", "", Weechat.infolist_string( infolist, "pointer" ) )
			end
		else
			# handle things besides irc eventually
		end
	end
	Weechat.infolist_free(infolist)
end

def dologgan( a,c,b )
	$irc.loggan()
	return Weechat::WEECHAT_RC_OK
end

def weechat_init
	Weechat.register( SCRIPT_NAME, SCRIPT_AUTHOR, SCRIPT_VERSION, SCRIPT_LICENSE, SCRIPT_DESC, "", "" )
	$irc = IRC.new # I need to think about how to do this without global variables. Maybe I need more namespaces in my life?
	# Weechat.hook_signal( "buffer_opened", "add_new_buf", "" )
	Weechat.hook_signal( "irc_server_opened", "add_new_server", "" )
	Weechat.hook_signal( "irc_channel_opened", "add_new_channel", "" )
	Weechat.hook_signal( "irc_pv_opened", "add_new_channel", "" ) # no reason for these to be handled differently
	Weechat.hook_signal( "buffer_closing","destroy_closed_buffer","" ) # called before the buffer is destroyed.
	Weechat.hook_command( "loggit","Sort buffers case insensitively.","","","","dologgan","" )
	return Weechat::WEECHAT_RC_OK
end
