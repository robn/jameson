package jameson::plugin::karma;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

use Storable;
use Lingua::EN::Inflect qw(inflect);

my %karma;
my $karmafile = "karma.db";

sub init {
	%karma = eval { %{retrieve $karmafile} };
}

sub publicmsg {
    my ($self, $con, $channel, $from, $text, $direct) = @_;

    if ($direct) {
        my ($who) = $text =~ m/karma\s+(\w+)/i;
        return unless $who;

        my $karma = $karma{lc $who} // 0;

        $con->send_srv(PRIVMSG => $channel, inflect "$who has NUM($karma) PL_N(point)");
        return;
    }

    while (my ($who, $updown) = $text =~ m/\G.*?(\w+)\s*(\+\+|--)/gc) {
        $karma{lc $who} += $updown eq '++' ? 1 : -1;
		store \%karma, $karmafile;
    }
}

1;
