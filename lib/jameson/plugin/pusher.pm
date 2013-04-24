package jameson::plugin::pusher;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

use AnyEvent::Socket;
use AnyEvent::Handle;
use Protocol::WebSocket::Handshake::Client;
use Protocol::WebSocket::Frame;
use JSON;

my $app_key = "81dfb713cde92b7ab8a1";

my $json = JSON->new;

my $con;
my %channels;

my $running = 0;

my $h;
sub init {
    my ($self) = @_;

    my $hc = Protocol::WebSocket::Handshake::Client->new(url => "ws://ws.pusherapp.com:80/app/$app_key?protocol=6");
    my $f = Protocol::WebSocket::Frame->new;

    $h = AnyEvent::Handle->new(connect => ["ws.pusherapp.com", 80],

        on_connect => sub {
            my ($h) = @_;
            $self->log("connected to pusher");
            $h->push_write($hc->to_string);
        },

        on_read => sub {
            my ($h) = @_;

            my $chunk = $h->{rbuf};
            $h->{rbuf} = undef;

            if (!$hc->is_done) {
                $hc->parse($chunk);
            }

            $running = 1;

            $f->append($chunk);
            while (my $msg = $f->next) {
                my $d = $json->decode($msg);
                given ($d->{event}) {
                    when ("pusher:error") {
                        $self->log("pusher error: $d->{data}->{message}");
                    }

                    when ("pusher:connection_established") {
                        $self->subscribe($_) for keys %channels;
                    }

                    when ("pusher_internal:subscription_succeeded") {
                        $self->log("subscribed to $d->{channel}");
                    }

                    when (/jameson:/) {
                        my ($event) = $d->{event} =~ m/:(.+)$/;
                        my $channel = "#$d->{channel}";

                        $self->log("got $event event for $channel, forwarding");

                        unless ($channels{$channel}) {
                            $self->log("not in channel, dropping");
                            return;
                        }

                        my $finished_cb = sub {
                            my ($text) = @_;
                            $con->send_srv(PRIVMSG => $channel, "$event: $text");
                        };

                        my @urls = do {
                            my @u;
                            my $text = $d->{data};
                            URI::Find->new(sub { push @u, pop @_ })->find(\$text);
                            @u;
                        };

                        my $text = $d->{data};

                        if (!@urls) {
                            $finished_cb->($text);
                        }

                        else {
                            my %shortened;
                            for my $url (@urls) {
                                my $shorten_cb = sub {
                                    my ($shorturl) = @_;
                                    $shortened{$url} = $shorturl;
                                    if (keys %shortened == @urls) {
                                        $text =~ s/$_/$shortened{$_}/ge for @urls;
                                        $finished_cb->($text);
                                    }
                                };
                                jameson::util::shorten($url, $shorten_cb);
                            }
                        }
                    }

                    default {
                        $self->log("got unrecognised $d->{event}: ".$msg);
                    }
                }
            }
        },

        on_eof => sub {
            my ($h) = @_;
            $self->log("lost connection, reconnecting");
            $running = 0;
            $h->destroy;
            $self->init;
        }
    );
}

sub joined {
    my ($self, $irccon, $channel) = @_;
    $con = $irccon;
    $channels{$channel} = 1;
    $self->subscribe($channel) if $running;
}

sub subscribe {
    my ($self, $channel) = @_;
    $channel =~ s/^#//;
    $self->log("subscribing to $channel");
    $h->push_write(
        Protocol::WebSocket::Frame->new($json->encode({
            event => "pusher:subscribe",
            data => {
                channel => $channel,
            },
        }))->to_bytes
    );
}

1;
