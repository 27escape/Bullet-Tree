#!/usr/bin/perl -w

=head1 NAME

01_basic.t

=head1 DESCRIPTION

test Bullet::Tree

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=cut

use v5.10;
use strict;
use warnings;
use Try::Tiny;
use Test::More tests => 15;

BEGIN { use_ok('Bullet::Tree'); }

my $bullets = "* first post" ;

my $tree = Bullet::Tree->new() ;
my $path = $tree->add($bullets) ;
ok( $path && $path eq '1.0', 'got first point') ;
$path = $tree->add('* second', { hello => 'friend'}) ;
ok( $path && $path eq '2.0', 'got second point') ;
$path = $tree->add('    * two point 1') ;
ok( $path && $path eq '2.1', 'got third point') ;

my @kids = $tree->children( '1.0') ;
ok( scalar( @kids) == 0, 'no kids on first point') ;
@kids = $tree->children( '2.0') ;
ok( scalar( @kids) == 1, 'one kid on second point') ;

my @traverse = $tree->traverse() ;
ok( scalar( @traverse) == 3, '3 nodes so far') ;
ok( $traverse[0]->{path} eq '1.0' && $traverse[1]->{path} eq '2.0' && $traverse[2]->{path} eq '2.1' , 'all nodes in right order') ;

$tree->add( "        * fouth point");
$tree->add( "* fifth point");

my @decendants= $tree->decendants( '2.0') ;
ok( $decendants[0]->{path} eq '2.1' && $decendants[1]->{path} eq '2.1.1', 'decendants seem OK') ;

my $count = 0 ;
my $string = $tree->to_string() ;
$count++ if( $string =~ /^\* first post/sm) ;
$count++ if( $string =~ /^\s{4}\* two point 1/sm) ;
ok( $count == 2, 'rebuilt tree OK') ;

ok( $tree->is_parent( '1.0') == 0, '1.0 is not a parent') ;
ok( $tree->is_parent( '2.0'), '2.0 is a parent') ;
ok( $tree->is_leaf( '2.0') == 0, '2.0 is not a leaf ') ;
ok( $tree->is_leaf( '2.1.1'), '2.1.1 is a leaf') ;

my $meta = $tree->meta( '2.0') ;
ok( $meta->{data}->{hello} eq 'friend', 'valid meta data') ;
