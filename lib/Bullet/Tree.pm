=head1 overview

convert lines of bullets into a tree structure to make things easy
any sequence of 4 empty spaces will create a new node, this allows an incorrect
sparse tree to be built

* root
    * roots child
                * bad indent, but gets empty node above

nodes are kept track of in the order they are presented; you cannot add a child
to a node out of sequence as you can with some tree modules

    my $tree = Bullet::Tree()->new() ;

    $tree->add( '* fred', $data) ;  # child of root
    $tree->add( '* fred2', $more_data) ; # child of root
    $tree->add( '    * child of fred2', $extra_data) ;
    $tree->add( '       * child of child of fred2', $extra_data2) ;
    $tree->add( '    * child of fred2', $extra_data3) ;

=cut

package Bullet::Tree ;

use strict;
use warnings;
# use Data::Printer ;
use Moo ;
use namespace::clean ;

use constant INDENT      => '    ' ;
use constant INDENT_SIZE => length(INDENT) ;

my $BULLETS = '[\*\+-]' ;       # allow any of these as bullets

# -----------------------------------------------------------------------------

has _nodes => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { { root => {} } },    # hashref of paths -> data
) ;

# order in which everything was added
has _order => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [] },                # arrayref of paths
) ;

# path of things being added
has _path => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [] },                # arrayref of paths
) ;

has _last_indent => (
    is       => 'ro',
    init_arg => undef,
    default  => 0,
) ;

# init data we want to put into root
has data => (
    is      => 'ro',
    default => sub { {} },
) ;

# -----------------------------------------------------------------------------
sub BUILD
{
    my $self = shift ;

    # use the data to set up node 0 aka root
    # we add the data to the nodes but not to the ordering
    # this data is a bit hidden!

    $self->{_nodes}->{'root'} = {
        indent => 0,
        path   => 'root',
        data   => $self->{data},
    } ;
}

sub _parent_path {
    my $self = shift ;
    my ($path) = @_ ;

    if( $path =~ /^\d+\.0$/) {
        $path = 'root' ;
    } else {
        $path =~ s/\.\d+$// ;
        if( $path =~ /^\d+/) {
            $path .= '.0' ;
        }
    }
}

# -----------------------------------------------------------------------------
# add a bullet line to the tree

sub add
{
    my $self = shift ;
    my ( $line, $data ) = @_ ;
    my $path ;

    my ( $spaces, $comment ) ;
    if ( $line =~ /^(\s*)?$BULLETS\s?(.*)\s?$/ ) {
        ( $spaces, $comment ) = ( $1, $2 ) ;
    } else {
        die "bad line $line" ;
    }
    my $indent
        = ( ( length($spaces) / INDENT_SIZE )
        + ( length($spaces) % INDENT_SIZE ? 1 : 0 ) ) ;

    if ( $indent == $self->{_last_indent} ) {
        # sibling
        $self->{_path}->[$indent]++ ;
    } elsif ( $indent < $self->{_last_indent} ) {
        # go up a level or so
        my @p = @{ $self->{_path} }[ 0 .. $indent ] ;
        $p[$indent]++ ;
        $self->{_path} = \@p ;
    } else {
        # this is a child
        push @{ $self->{_path} }, 1 ;
        # which means the one above is a parent,lets make that so
        my $p = join( '.', @{ $self->{_path} }[ 0 .. $indent - 1 ] ) ;
        $p =~ s/^(\d+)$/$1.0/ ;
        $self->{_nodes}->{$p}->{isparent} = 1 ;
    }
    $self->{_last_indent} = $indent ;
    $path = join( '.', @{ $self->{_path} } ) ;
    $path =~ s/^(\d+)$/$1.0/ ;

    my $meta = {
        line    => $line,
        comment => $comment,
        indent  => $indent,
        data    => $data,
        path    => $path,
        tree    => $self,      # can always get the tree object itself
        # parent => $self->_parent_path( $path),
    } ;
    $self->{_nodes}->{$path} = $meta ;
    push @{ $self->{_order} }, $path ;

    return $path ;
}

# -----------------------------------------------------------------------------
# attempt to make the path valid, otherwise makes path undef
sub _valid_path
{
    my $self = shift ;
    my ($path) = @_ ;

    return undef if( !$path) ;
    $path .= '.0' if ( !$self->{_nodes}->{$path} ) ;
    return $self->{_nodes}->{$path} ? $path : undef ;
}

# -----------------------------------------------------------------------------

sub meta
{
    my $self   = shift ;
    my ($path) = @_ ;
    my $res    = {} ;

    $path = $self->_valid_path($path) ;
    if ($path) {
        $res = $self->{_nodes}->{$path} ;
    }
    return $res ;
}

# -----------------------------------------------------------------------------
# get the list of children from a node down or all the children
# if called in a scalar content will list the number of matching children
# returns arrayref of the childrens data

sub children
{
    my $self = shift ;
    my ($from) = @_ ;
    my @meta ;

    $from ||= "" ;
    $from =~ s/\.0$// ;
    $from .= '\b' ;

    # this is not optimal as it checks every single node, rather than bailing
    # out when we have passed something that matches
    # may be good enough for my use case however - small set of data
    my $c = 0 ;
    foreach my $path ( @{ $self->{_order} } ) {
        next if ( $from && $path !~ /^$from/ ) ;

        # first child should not be the path we are matching on
        push @meta, $self->{_nodes}->{$path} if ($c) ;
        $c++ ;
    }

    return wantarray ? @meta : scalar(@meta) ;
}

# -----------------------------------------------------------------------------
# walk the tree in order
# returns arrayref of the metadata

sub traverse
{
    my $self = shift ;
    my ($from) = @_ ;
    my @meta ;

    $from ||= "" ;
    $from =~ s/\.0$// ;
    $from .= '\b' ;

    # this is not optimal as it checks every single node, rather than bailing
    # out when we have passed something that matches
    # may be good enough for my use case however - small set of data
    foreach my $path ( @{ $self->{_order} } ) {
        next if ( $from && $path !~ /^$from/ ) ;

        push @meta, $self->{_nodes}->{$path}  ;
    }

    return wantarray ? @meta : scalar(@meta) ;
}

# -----------------------------------------------------------------------------
# walk the tree and find the children and childrens children etc of this path
# returns arrayref of the metadata

sub decendants {
    my $self = shift ;
    my ($from) = @_ ;

    my $orig = $from ;
    my @meta ;
    my $indent = -1 ; # 'root'

    $from =~ s/^root$// ;
    if( $from) {
        my $meta = $self->meta( $from);
        $indent = $meta->{indent} if( $meta);
    }

    $from ||= "" ;
    $from =~ s/\.0$// ;
    $from .= '\b' ;

    foreach my $path ( @{ $self->{_order} } ) {
        next if ( $from && $path !~ /^$from/ ) ;
        next if( $path eq $orig) ;
        my $meta = $self->{_nodes}->{$path};
        last if( $indent >= $meta->{indent}) ;

        push @meta, $self->{_nodes}->{$path}  ;
    }

    return wantarray ? @meta : scalar(@meta) ;
}

# -----------------------------------------------------------------------------

sub is_parent
{
    my $self = shift ;
    my ($from) = @_ ;

    return $self->{_nodes}->{$from}->{isparent} ? 1 : 0 ;
}

# -----------------------------------------------------------------------------
# just need to check that its not a parent to be a leaf
sub is_leaf
{
    my $self = shift ;
    my ($from) = @_ ;

    return $self->{_nodes}->{$from}->{isparent} ? 0 : 1 ;
}

# -----------------------------------------------------------------------------
# walk the node list, calling the passed function

sub walk
{
    my $self = shift ;
    my ( $from, $func ) = @_ ;

    die "Missing or bad function" if ( !$func ) ;

    foreach my $meta ( $self->children($from) ) {
        $func->($meta) ;
    }
}

# -----------------------------------------------------------------------------

sub to_string {
    my $self = shift ;
    my ($bullet, $indent) = @_ ;

    $bullet ||= '*' ;
    $indent ||= INDENT ;

    my $out = "" ;
    foreach my $path ( @{ $self->{_order} } ) {
        my $meta = $self->{_nodes}->{$path};
        $out .= $indent x ($meta->{indent} || 0) . $bullet . " " . ($meta->{comment} || '')  . "\n" ;
    }

    return $out ;
}

# -----------------------------------------------------------------------------

1;
