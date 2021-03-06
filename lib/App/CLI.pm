package App::CLI;

use strict;
use warnings;
use 5.006;
use Class::Load qw( load_class );

our $VERSION = '0.45';

=head1 NAME

App::CLI - Dispatcher module for command line interface programs

=head1 SYNOPSIS

    package MyApp;
    use base 'App::CLI';        # the DISPATCHER of your App
                                # it's not necessary putting the dispatcher
                                # on the top level of your App

    package main;

    MyApp->dispatch;            # call dispatcher in where you want


    package MyApp::List;
    use base qw(App::CLI::Command); # any (SUB)COMMAND of your App

    use constant options => (
        "h|help"   => "help",
        "verbose"  => "verbose",
        'n|name=s'  => 'name',
    );

    use constant subcommands => qw(User Nickname type); # if you want subcommands
                                                        # automatically dispatch to subcommands
                                                        # when invoke $ myapp list [user|nickname|--type]
                                                        # note 'type' is not capitalized
                                                        # it is a deprecated subcommand

    sub run {
        my ($self, @args) = @_;

        print "verbose" if $self->{verbose};
        my $name = $self->{name}; # get arg following long option --name

        if ($self->{help}) {
            # if $ myapp list --help or $ myapp list -h
            # just only output PODs
        } else {
            # do something when imvoking $ my app list
            # without subcommand and --help
        }
    }


    package MyApp::List::User;
    use base qw(App::CLI::Command);
    use constant options => (
        "h|help"  =>  "help",
    );

    sub run {
        my ($self,@args) = @_;
        # code for listing user
    }


    pakcage MyApp::List::Nickname;
    use base qw(App::CLI::Command);
    use constant options => (
        "sort=s"  =>  "sort",
    );

    sub run {
        my ($self,@args) = @_;
        # code for listing nickname
    }

    package MyApp::List::type;   # old genre of subcommand could not cascade infinitely
    use base qw(MyApp::List);    # should inherit its parent's command

    sub run {
        my ($self, @args);
        # run to here when invoking $ myapp list --type
    }


    package MyApp::Help;
    use base 'App::CLI::Command::Help';

    use constant options => (
        'verbose' => 'verbose',
    );

    sub run {
        my ($self, @arg) = @_;
        # do something
        $self->SUPER(@_); # App::CLI::Command::Help would output POD of each command
    }

=head1 DESCRIPTION

C<App::CLI> dispatches CLI (command line interface) based commands
into command classes.  It also supports subcommand and per-command
options.

=cut


use App::CLI::Helper;
use Getopt::Long ();

use constant alias => ();
use constant global_options => ();
use constant options => ();

sub new {
    my ($class, @args) = @_;
    my $self = bless {@args}, $class;
    $self->{'app_argv'} = undef;

    return $self;
}

sub app_argv {
    my $self = shift;

    if (@_) {
        $self->{'app_argv'} = shift;
    }

    return $self->{'app_argv'};
}

sub prepare {
    my $self = shift;
    my $data = {};

    $self->get_opt(
        [qw(no_ignore_case bundling pass_through)],
        opt_map($data, $self->global_options)
    );

    my $command_name = shift @ARGV;
    my $cmd = $self->get_cmd($command_name, @_, $data);

    while ($cmd->cascadable) {
      $cmd = $cmd->cascading;
    }

    $self->get_opt(
        [qw(no_ignore_case bundling)],
        opt_map($cmd, $cmd->command_options)
    );

    $cmd = $cmd->subcommand;

    return $cmd;
}

=head3 get_opt([@config], %opt_map)

Give options map, processed by L<Getopt::Long::Parser>.

=cut

sub get_opt {
    my ($self, $config, @app_options) = @_;
    my $p = Getopt::Long::Parser->new;
    $p->configure(@$config);
    my $err = '';
    local $SIG{__WARN__} = sub {
        my $msg = shift;
        $err .= "$msg"
    };
    my @current_argv = @ARGV;
    $self->app_argv(\@current_argv);
    die $self->error_opt($err) unless $p->getoptions(@app_options);
}


sub opt_map {
    my ($self, %opt) = @_;
    return map { $_ => ref($opt{$_}) ? $opt{$_} : \$self->{$opt{$_}}} keys %opt;
}


=head3

Interface of dispatcher

=cut

sub dispatch {
    my ($self, @args) = @_;
    $self = $self->new unless ref $self;

    $self->app($self) if $self->can('app');

    my $cmd = $self->prepare(@args);
    $cmd->run_command(@ARGV);
}


=head3 cmd_map($cmd)

Find package name of subcommand in constant C<%alias>.

If it's found, return C<ucfirst> of the package name, otherwise, return
C<ucfirst> of C<$cmd> itself.

=cut

sub cmd_map {
    my ($pkg, $cmd) = @_;
    my %alias = $pkg->alias;
    $cmd = $alias{$cmd} if exists $alias{$cmd};
    return ucfirst($cmd);
}

sub error_cmd {
    my ($self, $pkg) = @_;

    my $cmd;
    if (defined($pkg)) {
        $cmd = ref($pkg) || $pkg;
    }
    else {
        $cmd = ${$self->app_argv}[0];
    }

    return "Command '$cmd' not recognized, try $0 --help.\n";
}

sub error_opt { $_[1] }

=head3 get_cmd($cmd, @arg)

Return subcommand of first level via C<$ARGV[0]>.

=cut

sub get_cmd {
    my ($self, $cmd, $data) = @_;
    die $self->error_cmd($cmd) unless $cmd && $cmd eq lc($cmd);

    my $base = ref $self;
    my $pkg = join('::', $base, $self->cmd_map($cmd));
    load_class $pkg;

    die $self->error_cmd($cmd) unless $pkg->can('run');

    my @arg = %$data;
    $cmd = $pkg->new(@arg);
    $cmd->app($self);
    return $cmd;
}


=head1 SEE ALSO

=over 4

=item *

L<App::CLI::Command>

=item *

L<Getopt::Long>

=back

=head1 MODULES USE App::CLI

L<Jifty::Script>, L<App::gh>, L<App::I18N>

=head1 AUTHORS

Chia-liang Kao E<lt>clkao@clkao.orgE<gt>

Yo-An Lin      E<lt>cornelius.howl@gmail.comE<gt>

Shelling       E<lt>navyblueshellingford@gmail.comE<gt>

Paul Cochrane  E<lt>paul@liekut.deE<gt> (current maintainer)

=head1 COPYRIGHT

Copyright 2005-2006 by Chia-liang Kao E<lt>clkao@clkao.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

1;
