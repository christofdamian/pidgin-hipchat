#!/usr/bin/perl

use Purple;
use Data::Dumper;
use HTML::Entities;

%PLUGIN_INFO = (
    perl_api_version => 2,
    name => "Hipchat Helper Plugin",
    version => "0.1",
    summary => "Hipchat support plugin",
    description => "Currently just decodes html.",
    author => "Christof Damian <christof@damian.net>",
    url => "http://christof.damian.net/",
    load => "plugin_load",
    unload => "plugin_unload"
);

sub plugin_init {
    return %PLUGIN_INFO;
}

sub plugin_load {
    my $plugin = shift;
    Purple::Debug::info('hipchat-helper-plugin',"Hipchat Helper Plugin loaded\n");

    foreach my $account (Purple::Accounts::get_all()) {
	my $conversation_handle = Purple::Conversations::get_handle();
	Purple::Signal::connect(
	    $conversation_handle, 
	    "receiving-chat-msg", 
	    $plugin, 
	    \&received_chat_msg_cb, 
	    "receivedd chat message"
	    );
	
	Purple::Debug::info('hipchat-helper-plugin',"connected to ".$account->get_username()."\n");
    }
}

sub received_chat_msg_cb {
    my ($account, $sender, $message, $conv, $flag, $data) = @_;

    if ($sender !~ m|chat.hipchat.com/xmpp$|) {
	Purple::Debug::info(
	    'hipchat-helper-plugin',
	    sprintf(
		"Skipped message: %s from %s on account %s\n", 
		$message,  
		$sender, 
		$account->get_username()
	    )
	);
	return 0;
    }
    
    my $stripped_message = decode_entities($message);

    Purple::Debug::info(
	'hipchat-helper-plugin',
	sprintf(
	    "Got message: %s from %s on account %s, stripped to: %s\n", 
	    $message,  
	    $sender, 
	    $account->get_username(),
	    $stripped_message
	)
    );

    $_[2] = $stripped_message;
}

sub plugin_unload {
    my $plugin = shift;
    Purple::Debug::info('hipchat-helper-plugin', "plugin_unload() - Hipchat Helper Plugin Unloaded.\n");
}


