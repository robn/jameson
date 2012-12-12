package jameson::plugin::url;

use 5.016;
use warnings;
use strict;

use base 'jameson::plugin';

use AnyEvent::HTTP;
use URI::Find;
use HTML::TreeBuilder 5 -weak;

sub publicmsg {
    my ($self, $con, $channel, $from, $text, $direct) = @_;

    my @urls;
    return unless URI::Find->new(sub { push @urls, pop @_ })->find(\$text);

    for my $url (grep { m{^https?://} } @urls) {
        $self->log("requesting $url");

        my $chunk;
        http_get($url, on_body => sub {
            my ($body, $hdr)  = @_;
            $chunk = $body;
            $self->log(sprintf "received %d bytes", length $chunk);
            return 0;
        }, sub {
            my ($body, $hdr) = @_;
            return unless $hdr->{Status} =~ m/^598/;

            my $title = $hdr->{Title};
            unless ($title) {
                my $elem = HTML::TreeBuilder->new_from_content($chunk)->find_by_tag_name("title");
                $title = $elem->as_trimmed_text if $elem;
            }

            if ($title) {
                $self->log("extracted title: $title");
                $con->send_srv(PRIVMSG => $channel, "[ $title ]");
            }
            else {
                $self->log("no title found");
            }
        });
    }
}

sub enabled { 1 }

1;
