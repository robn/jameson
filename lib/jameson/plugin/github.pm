package jameson::plugin::github;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

use List::MoreUtils qw(uniq);
use AnyEvent::HTTP;
use JSON;
use DateTime::Format::ISO8601;

my $API_BASE    = "https://api.github.com/repos/pioneerspacesim/pioneer";
my $ISSUE_BASE  = "$API_BASE/issues";
my $COMMIT_BASE = "$API_BASE/commits";

my $USER_COMMIT_BASE = "https://github.com/pioneerspacesim/pioneer/commit";

my $timeout = 300;
my %last_issue_time;
my %last_ref_time;

sub publicmsg {
    my ($self, $con, $channel, $from, $text, $direct) = @_;

    my @issues = uniq map { 0+$_} $text =~ m/(?:\G|^|[\s\W])#(\d+)(?=$|[\s\W])/g;

    for my $issue (@issues) {
		my $now = time;
		my $time_left = $now - ($last_issue_time{$issue} // 0);
		if ($time_left < $timeout) {
			$self->log(sprintf "not refetching issue #$issue, %ds remaining", $timeout - $time_left);
			next;
		}
		$last_issue_time{$issue} = $now;

        $self->log("fetching issue #$issue");

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

                $self->log($msg);

                $con->send_srv(PRIVMSG => $channel, $msg);
            });
        });
    }

    my @refs = uniq map { lc } $text =~ m/(?:^|\s)\@([0-9a-fA-F]{7,})(?:\s|$)/g;

    for my $ref (@refs) {
		my $now = time;
		my $time_left = $now - ($last_ref_time{$ref} // 0);
		if ($time_left < $timeout) {
			$self->log(sprintf "not refetching ref \@$ref, %ds remaining", $timeout - $time_left);
			next;
		}
		$last_ref_time{$ref} = $now;

        $self->log("fetching ref \@$ref");

        http_get("$COMMIT_BASE/$ref", sub {
            my ($body, $hdr) = @_;
            return unless $hdr->{Status} =~ m/^2/;

            my $data = decode_json($body);

            # XXX can't get the user-facing url from the api, so construct it
            my $url = "$USER_COMMIT_BASE/$data->{sha}";

            jameson::util::shorten($url, sub {
                my ($shorturl) = @_;

                my $sha = substr $data->{sha}, 0, 8;
                my $author = $data->{commit}->{author}->{name};
                my $time = DateTime::Format::ISO8601->parse_datetime($data->{commit}->{author}->{date})->strftime("%d %b %Y %T UTC");
                my ($message) = $data->{commit}->{message} =~ m/^(.*)$/m;

                my $msg = "\@$sha: $time [$author] $message $shorturl";

                $self->log($msg);

                $con->send_srv(PRIVMSG => $channel, $msg);
            });
        });
    }
}

1;
