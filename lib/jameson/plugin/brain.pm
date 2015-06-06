package jameson::plugin::tell;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

use Storable;

my %brain;
my $brainfile = "brain.db";

sub init {
    %brain = eval { %{retrieve $brainfile} };
}

sub publicmsg {
    my ($self, $con, $channel, $from, $text, $direct) = @_;
    return if not $direct;

    $text =~ s{^\s*(.*)\s*$}{$1};
    $text =~ s{\s+}{ }g;

    my ($k, $v, $who);

    if (($k, $v) = $text =~ m{^(\S+)\s+is\s+(.+)$}) {
        $k = lc $k;
        $brain{$k} = $v;
        store \%brain, $brainfile;
        $con->send_srv(PRIVMSG => $channel, "$from: Ok, I'll remember that $k is: $v");
    }
    elsif (($k) = $text =~ m{^forget\s+(\S+)}) {
        $k = lc $k;
        delete $brain{$k};
        store \%brain, $brainfile;
        $con->send_srv(PRIVMSG => $channel, "$from: Ok, I've forgotten about $k.");
    }
    elsif (($who, $k) = $text =~ m{^tell\s+(\S+)\s+(\S+)}) {
        $k = lc $k;
        if (exists $brain{$k}) {
            $con->send_srv(PRIVMSG => $channel, "$who: $brain{$k}");
        }
        else {
            $con->send_srv(PRIVMSG => $channel, "$from: I don't know what $k is.");
        }
    }
    elsif (($k) = $text =~ m{^(\S+)\s*\?}) {
        $k = lc $k;
        if (exists $brain{$k}) {
            $con->send_srv(PRIVMSG => $channel, "$from: $brain{$k}");
        }
        else {
            $con->send_srv(PRIVMSG => $channel, "$from: I don't know what $k is.");
        }
    }
}

1;
