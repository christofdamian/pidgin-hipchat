#!/usr/bin/perl

use Purple;
use Data::Dumper;
use HTML::Entities;

%PLUGIN_INFO = (
    perl_api_version => 2,
    name => "Hipchat Helper Plugin",
    version => "0.1",
    summary => "Hipchat support plugin",
    description => "Decodes html, auto-replaces buddy names with @nicks.",
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

    my $conversation_handle = Purple::Conversations::get_handle();
    Purple::Signal::connect(
        $conversation_handle,
        "receiving-chat-msg",
        $plugin,
        \&received_chat_msg_cb,
        "received chat message"
        );

    Purple::Signal::connect(
        $conversation_handle,
        "sending-chat-msg",
        $plugin,
        \&sending_msg,
        $plugin);

    my $jabber = Purple::Find::prpl("prpl-jabber");
    if (!$jabber) {
        warn("No jabber protocol?, weird: $!\n");
    }
    Purple::Signal::connect($jabber, "jabber-receiving-iq",$plugin,\&got_iq, 0);
    Purple::Signal::connect($jabber, "jabber-receiving-presence",$plugin,\&got_presence, 0);

    Purple::Debug::info('hipchat-helper-plugin',"connected\n");
}

sub received_chat_msg_cb {
    my ($account, $sender, $message, $conv, $flag, $data) = @_;

    my $username = $account->get_username();

    if ($username !~ m|@chat\.hipchat\.com/| or $message !~ m/(&lt;|&gt;)/) {
        Purple::Debug::info(
            'hipchat-helper-plugin',
            sprintf(
                "Skipped message: %s from %s on account %s\n",
                $message,
                $sender,
                $username
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
            $username,
            $stripped_message
        )
    );

    $_[2] = $stripped_message;
}

## Cache of user ids (jids) to the info we need for generating @nicks
my %jids;

sub got_presence {
    my ($conn, $type, $from, $node) = @_;
    my $item = $node->get_child("x")->get_child("item");
    if($item) {
        my $jid = $item->get_attrib("jid");
        Purple::Debug::info('hipchat-helper-plugin', "XML PRES from: $from, jid: $jid\n");
        if($jid =~ /@chat\.hipchat\.com$/ && !$jids{$jid}) {
            # Request vCard for this jid
            my $id = "req-" . int(rand(100000));
            my $xml = "<iq type='get' id='$id' to='$jid'><vCard xmlns='vcard-temp'/></iq>";
            Purple::Debug::info('hipchat-helper-plugin', "SEND $xml via $conn\n");
            Purple::Prpl::send_raw($conn, $xml);
        }
    }
    return true;
}

sub got_iq {
    my ($conn, $type, $id, $from, $node, $soughtid) = @_;
    my $vcard = $node->get_child("vCard");
    if($vcard) {
        # Got a vCard -- add relevant entry to cache
        my $jid = $node->get_attrib("from");
        my $name = $vcard->get_child("FN")->get_data();
        my $at = $vcard->get_child("NICKNAME")->get_data();
        Purple::Debug::info('hipchat-helper-plugin', "XML IQ $from, $name, $at\n");
        if($name && $at) {
            $jids{$jid} = {'name'=>$name, 'at'=>$at};
        }
    }
    return true;
}

sub sending_msg {
    my ($account, $message, $id, $plugin) = @_;
    if ($account->get_username() =~ m|@chat\.hipchat\.com/|) {
        ## Replace name with @nick, for all cached names
        foreach my $jid (values(%jids)) {
            $name = $jid->{'name'};
            $at = '@' . $jid->{'at'};
            $_[1] =~ s|\b$name\b|$at|g;
        }
    }
}

sub plugin_unload {
    my $plugin = shift;
    Purple::Debug::info(
        'hipchat-helper-plugin',
        "plugin_unload() - Hipchat Helper Plugin Unloaded.\n"
    );
}


