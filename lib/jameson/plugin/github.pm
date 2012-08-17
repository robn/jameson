package jameson::plugin::github;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

use List::MoreUtils qw(uniq);
use AnyEvent::HTTP;
use JSON;

my $ISSUE_BASE = "https://api.github.com/repos/pioneerspacesim/pioneer/issues";

sub publicmsg {
    my ($self, $con, $channel, $from, $text, $direct) = @_;

    my @issues = uniq map { 0+$_} $text =~ m/(?:^|\s)#(\d+)(?:\s|$)/g;
    for my $issue (@issues) {
        http_get("$ISSUE_BASE/$issue", sub {
            my ($body, $hdr) = @_;
            return unless $hdr->{Status} =~ m/^2/;

            my $data = decode_json($body);

            jameson::util::shorten($data->{html_url}, sub {
                my ($shorturl) = @_;

                my $type = $data->{pull_request}->{diff_url} ? "PR" : "Issue";

                my $labels = join ' / ', map { $_->{name} } @{$data->{labels}};

                my $msg = "$type #$issue [$data->{state}]: $data->{title} $shorturl";
                $msg .= " [ $labels ]" if $labels;

                $con->send_srv(PRIVMSG => $channel, $msg);
            });
        });
    }
}

1;
