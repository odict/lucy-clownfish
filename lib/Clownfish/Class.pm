# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

package Clownfish::Class;
use base qw( Clownfish::Symbol );
use Carp;
use Config;
use Clownfish::Function;
use Clownfish::Method;
use Clownfish::Util qw(
    verify_args
    a_isa_b
);
use Clownfish::Dumpable;
use File::Spec::Functions qw( catfile );
use Scalar::Util qw( reftype );

our %cnick;
our %struct_sym;
our %parent_class_name;
our %source_class;
our %docucomment;
our %children;
our %inert;
our %final;
our %attributes;
our %meth_by_name;
our %func_by_name;
our %functions;
our %methods;
our %member_vars;
our %inert_vars;
our %overridden;

our %create_PARAMS = (
    source_class      => undef,
    class_name        => undef,
    cnick             => undef,
    parent_class_name => undef,
    methods           => undef,
    functions         => undef,
    member_vars       => undef,
    inert_vars        => undef,
    docucomment       => undef,
    inert             => undef,
    final             => undef,
    parcel            => undef,
    attributes        => undef,
    exposure          => 'parcel',
);

my $dumpable = Clownfish::Dumpable->new;

our %registry;

# Testing only.
sub _zap { delete $registry{ +shift } }

our %fetch_singleton_PARAMS = (
    parcel     => undef,
    class_name => undef,
);

sub fetch_singleton {
    my ( undef, %args ) = @_;
    verify_args( \%fetch_singleton_PARAMS, %args ) or confess $@;

    # Start with the class identifier.
    my $class_name = $args{class_name};
    confess("Missing required param 'class_name'") unless defined $class_name;
    $class_name =~ /(\w+)$/ or confess("Invalid class name: '$class_name'");
    my $key = $1;

    # Maybe prepend parcel prefix.
    my $parcel = $args{parcel};
    if ( defined $parcel ) {
        if ( !a_isa_b( $parcel, "Clownfish::Parcel" ) ) {
            $parcel = Clownfish::Parcel->singleton( name => $parcel );
        }
        $key = $parcel->get_prefix . $key;
    }

    return $registry{$key};
}

sub new { confess("The constructor for Clownfish::Class is create()") }

sub create {
    my ( $either, %args ) = @_;
    verify_args( \%create_PARAMS, %args ) or confess $@;
    $args{class_cnick} = delete $args{cnick};
    my $class_name = $args{class_name};
    confess("Missing required param 'class_name'") unless $class_name;
    my $parent_class_name = delete $args{parent_class_name};
    my $docucomment       = delete $args{docucomment};
    my $inert             = delete $args{inert};
    my $final             = delete $args{final};

    # Derive struct name.
    $class_name =~ /(\w+)$/ or confess("Invalid class_name: '$class_name'");
    my $struct_sym = $1;

    # Assume that Foo::Bar should be found in Foo/Bar.h.
    my $source_class
        = defined $args{source_class}
        ? delete $args{source_class}
        : $class_name;

    # Verify that members of supplied arrays meet "is a" requirements.
    my $functions   = delete $args{functions}   || [];
    my $methods     = delete $args{methods}     || [];
    my $member_vars = delete $args{member_vars} || [];
    my $inert_vars  = delete $args{inert_vars}  || [];
    for (qw( functions methods member_vars inert_vars )) {
        next unless defined $args{$_};
        next if reftype( $args{$_} ) eq 'ARRAY';
        confess("Supplied parameter '$_' is not an arrayref");
    }
    for (@$functions) {
        confess("Not a Clownfish::Function")
            unless a_isa_b( $_, 'Clownfish::Function' );
    }
    for (@$methods) {
        confess("Not a Clownfish::Method")
            unless a_isa_b( $_, 'Clownfish::Method' );
    }
    for ( @$member_vars, @$inert_vars ) {
        confess("Not a Clownfish::Variable")
            unless a_isa_b( $_, 'Clownfish::Variable' );
    }

    # Make it possible to look up methods and functions by name.
    my %methods_by_name   = map { ( $_->micro_sym => $_ ) } @$methods;
    my %functions_by_name = map { ( $_->micro_sym => $_ ) } @$functions;

    # Validate attributes.
    my $attributes = delete $args{attributes} || {};
    confess("Param 'attributes' not a hashref")
        unless reftype($attributes) eq 'HASH';

    # Validate inert param.
    confess("Inert classes can't have methods")
        if ( $inert and scalar @$methods );

    my $package = ref($either) || $either;
    $args{parcel} = Clownfish::Parcel->acquire( $args{parcel} );
    $args{exposure}  ||= 'parcel';
    $args{micro_sym} ||= 'class';
    my $self = $either->_new(
        @args{qw( parcel exposure class_name class_cnick micro_sym )} );

    $struct_sym{$self}        = $struct_sym;
    $parent_class_name{$self} = $parent_class_name;
    $source_class{$self}      = $source_class;
    $docucomment{$self}       = $docucomment;
    $children{$self}          = [];
    $inert{$self}             = $inert;
    $final{$self}             = $final;
    $attributes{$self}        = $attributes;
    $meth_by_name{$self}      = \%methods_by_name;
    $func_by_name{$self}      = \%functions_by_name;
    $functions{$self}         = $functions;
    $methods{$self}           = $methods;
    $member_vars{$self}       = $member_vars;
    $inert_vars{$self}        = $inert_vars;
    $overridden{$self}        = {};

    # Store in registry.
    my $key      = $self->full_struct_sym;
    my $existing = $registry{$key};
    if ($existing) {
        my $existing_class_name = $existing->get_class_name;
        confess(  "New class $class_name conflicts with previously "
                . "compiled class $existing_class_name" );
    }
    $registry{$key} = $self;

    return $self;
}

sub DESTROY {
    my $self = shift;
    delete $struct_sym{$self};
    delete $parent_class_name{$self};
    delete $source_class{$self};
    delete $docucomment{$self};
    delete $children{$self};
    delete $inert{$self};
    delete $final{$self};
    delete $attributes{$self};
    delete $meth_by_name{$self};
    delete $func_by_name{$self};
    delete $functions{$self};
    delete $methods{$self};
    delete $member_vars{$self};
    delete $inert_vars{$self};
    delete $overridden{$self};
    $self->_destroy;
}

sub file_path {
    my ( $self, $base_dir, $ext ) = @_;
    my @components = split( '::', $self->get_source_class );
    unshift @components, $base_dir
        if defined $base_dir;
    $components[-1] .= $ext;
    return catfile(@components);
}

sub include_h {
    my $self = shift;
    my @components = split( '::', $self->get_source_class );
    $components[-1] .= '.h';
    return join( '/', @components );
}

sub has_attribute { exists $_[0]->_get_attributes->{ $_[1] } }

sub get_struct_sym        { $struct_sym{ +shift } }
sub get_parent_class_name { $parent_class_name{ +shift } }
sub get_source_class      { $source_class{ +shift } }
sub get_docucomment       { $docucomment{ +shift } }
sub inert                 { $inert{ +shift } }
sub final                 { $final{ +shift } }
sub _get_attributes       { $attributes{ +shift } }
sub _meth_by_name         { $meth_by_name{ +shift } }
sub _func_by_name         { $func_by_name{ +shift } }

sub _set_methods    { $methods{ $_[0] }    = $_[1] }

sub full_struct_sym  { $_[0]->get_prefix . $_[0]->get_struct_sym }
sub short_vtable_var { uc( shift->get_struct_sym ) }
sub full_vtable_var  { $_[0]->get_PREFIX . $_[0]->short_vtable_var }
sub full_vtable_type { shift->full_vtable_var . '_VT' }

sub functions   { $functions{ +shift } }
sub methods     { $methods{ +shift } }
sub member_vars { $member_vars{ +shift } }
sub inert_vars  { $inert_vars{ +shift } }
sub children    { $children{ +shift } }

sub novel_methods {
    my $self    = shift;
    my $cnick   = $self->get_cnick;
    my @methods = grep { $_->get_class_cnick eq $cnick } @{ $self->methods };
    return \@methods;
}

sub novel_member_vars {
    my $self  = shift;
    my $cnick = $self->get_cnick;
    my @novel
        = grep { $_->get_class_cnick eq $cnick } @{ $self->member_vars };
    return \@novel;
}

sub function {
    my ( $self, $micro_sym ) = @_;
    return $self->_func_by_name->{ lc($micro_sym) };
}

sub method {
    my ( $self, $micro_sym ) = @_;
    return $self->_meth_by_name->{ lc($micro_sym) };
}

sub novel_method {
    my ( $self, $micro_sym ) = @_;
    my $method = $self->_meth_by_name->{ lc($micro_sym) };
    if ( defined $method
        and $method->get_class_cnick eq $self->get_class_cnick )
    {
        return $method;
    }
    else {
        return;
    }
}

sub add_child {
    my ( $self, $child ) = @_;
    confess("Can't call add_child after grow_tree") if $self->_tree_grown;
    push @{ $self->children }, $child;
}

sub add_method {
    my ( $self, $method ) = @_;
    confess("Not a Method") unless a_isa_b( $method, "Clownfish::Method" );
    confess("Can't call add_method after grow_tree") if $self->_tree_grown;
    confess("Can't add_method to an inert class")    if $self->inert;
    push @{ $self->methods }, $method;
    $self->_meth_by_name->{ $method->micro_sym } = $method;
}

# Create dumpable functions unless hand coded versions were supplied.
sub _create_dumpables {
    my $self = shift;
    $dumpable->add_dumpables($self) if $self->has_attribute('dumpable');
}

sub grow_tree {
    my $self = shift;
    confess("Can't call grow_tree more than once") if $self->_tree_grown;
    $self->_establish_ancestry;
    $self->_bequeath_member_vars;
    $self->_generate_automethods;
    $self->_bequeath_methods;
    $self->_set_tree_grown(1);
}

# Let the children know who their parent class is.
sub _establish_ancestry {
    my $self = shift;
    for my $child ( @{ $self->children } ) {
        # This is a circular reference and thus a memory leak, but we don't
        # care, because we have to have everything in memory at once anyway.
        $child->set_parent($self);
        $child->_establish_ancestry;
    }
}

# Pass down member vars to from parent to children.
sub _bequeath_member_vars {
    my $self = shift;
    for my $child ( @{ $self->children } ) {
        unshift @{ $child->member_vars }, @{ $self->member_vars };
        $child->_bequeath_member_vars;
    }
}

# Create auto-generated methods.  This must be called after member vars are
# passed down but before methods are passed down.
sub _generate_automethods {
    my $self = shift;
    $self->_create_dumpables;
    for my $child ( @{ $self->children } ) {
        $child->_generate_automethods;
    }
}

sub _bequeath_methods {
    my $self = shift;

    for my $child ( @{ $self->children } ) {
        # Pass down methods, with some being overridden.
        my @common_methods;    # methods which child inherits or overrides
        for my $method ( @{ $self->methods } ) {
            if ( exists $child->_meth_by_name->{ $method->micro_sym } ) {
                my $child_method
                    = $child->_meth_by_name->{ $method->micro_sym };
                $child_method->override($method);
                push @common_methods, $child_method;
            }
            else {
                $child->_meth_by_name->{ $method->micro_sym } = $method;
                push @common_methods, $method;
            }
        }

        # Create array of methods, preserving exact order so vtables match up.
        my @new_method_set;
        my %seen;
        for my $meth ( @common_methods, @{ $child->methods } ) {
            next if $seen{ $meth->micro_sym };
            $seen{ $meth->micro_sym } = 1;
            if ( $child->final ) {
                $meth = $meth->finalize if $child->final;
                $child->_meth_by_name->{ $meth->micro_sym } = $meth;
            }
            push @new_method_set, $meth;
        }
        $child->_set_methods(\@new_method_set);

        # Pass it all down to the next generation.
        $child->_bequeath_methods;
        $child->_set_tree_grown(1);
    }
}

sub tree_to_ladder {
    my $self   = shift;
    my @ladder = ($self);
    for my $child ( @{ $self->children } ) {
        push @ladder, @{ $child->tree_to_ladder };
    }
    return \@ladder;
}

1;

__END__

__POD__

=head1 NAME

Clownfish::Class - An object representing a single class definition.

=head1 CONSTRUCTORS

Clownfish::Class objects are stored as quasi-singletons, one for each
unique parcel/class_name combination.

=head2 fetch_singleton 

    my $class = Clownfish::Class->fetch_singleton(
        parcel     => 'Crustacean',
        class_name => 'Crustacean::Lobster::LobsterClaw',
    );

Retrieve a Class, if one has already been created.

=head2 create

    my $class = Clownfish::Class->create(
        parcel     => 'Crustacean',                        # default: special
        class_name => 'Crustacean::Lobster::LobsterClaw',  # required
        cnick      => 'LobClaw',                           # default: special
        exposure   => 'public',                            # default: 'parcel'
        source_class      => undef,              # default: same as class_name
        parent_class_name => 'Crustacean::Claw', # default: undef
        inert             => undef,              # default: undef
        methods           => \@methods,          # default: []
        functions         => \@funcs,            # default: []
        member_vars       => \@members,          # default: []
        inert_vars        => \@inert_vars,       # default: []
        docucomment       => $documcom,          # default: undef,
        attributes        => \%attributes,       # default: {}
    );

Create and register a quasi-singleton.  May only be called once for each
unique parcel/class_name combination.

=over

=item * B<parcel>, B<class_name>, B<cnick>, B<exposure> - see
L<Clownfish::Symbol>.

=item * B<source_class> - The name of the class that owns the file in which
this class was declared.  Should be "Foo" if "Foo::FooJr" is defined in
C<Foo.cfh>.

=item * B<parent_class_name> - The name of this class's parent class.  Needed
in order to establish the class hierarchy.

=item * B<inert> - Should be true if the class is inert, i.e. cannot be
instantiated.

=item * B<methods> - An array where each element is a Clownfish::Method.

=item * B<functions> - An array where each element is a Clownfish::Method.

=item * B<member_vars> - An array where each element is a
Clownfish::Variable and should be a member variable in each instantiated
object.

=item * B<inert_vars> - An array where each element is a
Clownfish::Variable and should be a shared (class) variable.

=item * B<docucomment> - A Clownfish::DocuComment describing this Class.

=item * B<attributes> - An arbitrary hash of attributes.

=back

=head1 METHODS

=head2 get_cnick get_struct_sym get_parent_class_name get_source_class
get_docucomment get_parent get_autocode inert final

Accessors.

=head2 set_parent

    $class->set_parent($ancestor);

Set the parent class.

=head2 add_child

    $class->add_child($child_class);

Add a child class. 

=head2 add_method

    $class->add_method($method);

Add a Method to the class.  Valid only before grow_tree() is called.

=head2 function 

    my $do_stuff_function = $class->function("do_stuff");

Return the inert Function object for the supplied C<micro_sym>, if any.

=head2 method

    my $pinch_method = $class->method("Pinch");

Return the Method object for the supplied C<micro_sym> / C<macro_sym>, if any.

=head2 novel_method

    my $pinch_method = $class->novel_method("Pinch");

Return a Method object if the Method corresponding to the supplied string is
novel.

=head2 children 

    my $child_classes = $class->children;

Return an array of all child classes.

=head2 functions

    my $functions = $class->functions;

Return an array of all (inert) functions.

=head2 methods

    my $methods = $class->methods;

Return an array of all methods.

=head2 inert_vars

    my $inert_vars = $class->inert_vars;

Return an array of all inert (shared, class) variables.

=head2 member_vars

    my $members = $class->member_vars;

Return an array of all member variables.

=head2 novel_methods

    my $novel_methods = $class->novel_methods;

Return an array of all novel methods.

=head2 novel_member_vars

    my $new_members = $class->novel_member_vars;

Return an array of all novel member variables.

=head2 grow_tree

    $class->grow_tree;

Bequeath all inherited methods and members to children.

=head2 tree_to_ladder

    my $ordered = $class->tree_to_ladder;

Return this class and all its child classes as an array, where all children
appear after their parent nodes.

=head2 file_path

    # /path/to/Foo/Bar.c, if source class is Foo::Bar.
    my $path = $class->file_path( '/path/to', '.c' );

Provide an OS-specific path for a file relating to this class could be found,
by joining together the components of the C<source_class> name.

=head2 include_h

    my $relative_path = $class->include_h;

Return a relative path to a C header file, appropriately formatted for a
pound-include directive.

=head2 append_autocode

    $class->append_autocode($code);

Append auxiliary C code.

=head2 short_vtable_var

The short name of the global VTable object for this class.

=head2 full_vtable_var

Fully qualified vtable variable name, including the parcel prefix.

=head2 full_vtable_type

The fully qualified C type specifier for this class's vtable, including the
parcel prefix.  Each vtable needs to have its own type because each has a
variable number of methods at the end of the struct, and it's not possible to
initialize a static struct with a flexible array at the end under C89.

=head2 full_struct_sym

Fully qualified struct symbol, including the parcel prefix.

=cut
