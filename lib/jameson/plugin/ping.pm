package jameson::plugin::ping;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

sub publicmsg {
    my ($self, $con, $channel, $from, $text, $direct) = @_;
    return if not $direct;

    return unless $text =~ m/^\s*ping\s*$/;

    $self->log("replying to $from");

    $con->send_srv(PRIVMSG => $channel, "$from: pong");
}

1;
