package jameson::plugin::github;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

use AnyEvent::HTTP;
use JSON;

my $ISSUE_BASE = "https://api.github.com/repos/pioneerspacesim/pioneer/issues";

my %shorturl_cache;

sub publicmsg {
    my ($self, $con, $channel, $from, $text, $direct) = @_;

    my @issues = $text =~ m/#(\d+)/g;
    for my $issue (@issues) {
        http_get("$ISSUE_BASE/$issue", sub {
            my ($body, $hdr) = @_;
            return unless $hdr->{Status} =~ m/^2/;

            my $data = decode_json($body);

            my $post = sub {
                my ($shorturl) = @_;

                my $type = $data->{pull_request}->{diff_url} ? "PR" : "Issue";

                my $msg = "$type #$issue: $data->{title}";
                $msg .= " $shorturl" if $shorturl;

                $con->send_srv(PRIVMSG => $channel, $msg);
            };

            my $url = $data->{html_url};

            if (exists $shorturl_cache{$url}) {
                $post->($shorturl_cache{$url});
            }
            else {
                http_get("http://is.gd/create.php?url=$data->{html_url}&format=simple", sub {
                    my ($body, $hdr) = @_;
                    if ($hdr->{Status} =~ m/^2/) {
                        $shorturl_cache{$url} = $body;
                        $post->($body);
                    }
                    else {
                        $post->();
                    }
                });
            }
        });
    }
}

1;
