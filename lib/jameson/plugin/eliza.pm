package jameson::plugin::eliza;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

use Chatbot::Eliza;

my $eliza = Chatbot::Eliza->new;

sub enabled { 0 }

sub publicmsg {
    my ($self, $con, $channel, $from, $text, $direct) = @_;
    return if not $direct;

    my $out = $eliza->transform($text);
    $con->send_srv(PRIVMSG => $channel, "$from: $out");
}

1;
