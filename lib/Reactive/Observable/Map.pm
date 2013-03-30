package Reactive::Observable::Map;

use Moose;

extends 'Reactive::Observable::Wrapper';

has projection => (is => 'ro', required => 1);

augment observer_args => sub {
    my ($self, $observer, $disposable_parent) = @_;
    return (projection => $self->projection, inner(@_));
};

package Reactive::Observable::Map::Observer;

use Moose;

has projection => (is => 'ro', required => 1);

extends 'Reactive::Observer::Wrapper';

sub on_next {
    my ($self, $value) = @_;
    local $_ = $value;
    my @new_values;
    eval { @new_values = $self->projection->($_) };
    my $err = $@;
    return $self->on_error($err) if $err;
    my $wrap = $self->wrap;
    $wrap->on_next($_) for @new_values;
}

before unwrap => sub { delete shift->{projection} };

1;

