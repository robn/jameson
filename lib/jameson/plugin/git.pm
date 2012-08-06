package jameson::plugin::git;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

use FindBin;
use List::MoreUtils qw(uniq);
use Git::Repository;
use Try::Tiny;

my $GIT_PATH = "$FindBin::Bin/git/pioneer";

my $r = Git::Repository->new(work_tree => $GIT_PATH);

sub publicmsg {
    my ($self, $con, $channel, $from, $text, $direct) = @_;

    my @refs = uniq map { lc } $text =~ m/\@([0-9a-fA-F]+)\b/g;

    for my $ref (@refs) {
        my $line = try { $r->run("log", $ref, "-n1", "--pretty=format:%h,%H,%cn,%s") };
        if ($line) {
            my @bits = split ',', $line, 4;
            next if grep { not defined } @bits;
            my ($shorthash, $hash, $name, $subject) = @bits;
            $con->send_srv(PRIVMSG => $channel, "$shorthash  $name  $subject");
        }
    }
}

1;
