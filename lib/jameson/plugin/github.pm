package jameson::plugin::github;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

use AnyEvent::HTTP;
use JSON;

my $ISSUE_BASE = "https://api.github.com/repos/pioneerspacesim/pioneer/issues";

sub publicmsg {
    my ($self, $con, $channel, $from, $text, $direct) = @_;

    my @issues = $text =~ m/#(\d+)/g;
    for my $issue (@issues) {
        http_get("$ISSUE_BASE/$issue", sub {
            my ($body, $hdr) = @_;
            return unless $hdr->{Status} =~ m/^2/;

            my $data = decode_json($body);

            my $type = $data->{pull_request}->{diff_url} ? "PR" : "Issue";

            $con->send_srv(PRIVMSG => $channel, "$type #$issue: $data->{title}");
        });
    }
}

1;
