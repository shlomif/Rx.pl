package Reactive::Observable::HttpClient::HttpResponse;

use Moose;
use Scalar::Util qw(weaken);
use AnyEvent::HTTP;
use aliased 'Reactive::Disposable::Wrapper' => 'DisposableWrapper';

has [qw(url args method)] => (is => 'ro', required => 1);

extends 'Reactive::Observable';

sub _Event() { 'Reactive::Observable::HttpClient::HttpResponse::Event' }

=head1 METHODS

=head2 $class->new( url => $url, args => $args, method => $method)

Construct a new class from $url, $args, and $method .

=head2 $self->run($observer)

Attach to the $observer.

=cut

sub run {
    my ($self, $observer) = @_;
    my $disposable = DisposableWrapper->new;
    weaken (my $weak_disposable = $disposable);
    my $handle = http_get $self->url, %{$self->args}, sub {
        my ($body, $headers) = @_;
        $weak_disposable->unwrap if $weak_disposable;
        if (defined $body) {
            $observer->on_next(_Event->new($body, $headers));
            $observer->on_complete;
        } else {
            my $error = "Error at '$headers->{URL}' ".
                        "[$headers->{Status}]: ".
                        "$headers->{Reason}";
            $observer->on_error($error);
        }
    };
    $disposable->wrap($handle);
    return $disposable;
}

package Reactive::Observable::HttpClient::HttpResponse::Event;

use strict;
use warnings;

sub new {
    my $class = shift;
    return bless [@_], $class;
}

sub body    { shift->[0] }
sub headers { shift->[1] }


1;

