package Ingres::Utility::IIMonitor;

use warnings;
use strict;
use Carp;
use Expect::Simple;
use Data::Dump qw(dump);

=head1 NAME

Ingres::Utility::IIMonitor - API to IIMONITOR, the Ingres utility for IIDBMS servers control


=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Ingres::Utility::IIMonitor;
    
    # create a connection to an IIDBMS server
    # (server id can be obtained through Ingres::Utility::IIName)
    $foo = Ingres::Utility::IIMonitor->new($serverid);
    
    # showServer() - shows server status
    #
    # is the server listening to new connections? (OPEN/CLOSED)
    $status =$foo->showServer('LISTEN');
    #
    # is the server being shut down?
    $status =$foo->showServer('SHUTDOWN');
    
    # setServer() - sets server status
    #
    # stop listening to new connections
    $status =$foo->setServer('CLOSED');
    #
    # start shutting down (wait for connections to close)
    $status =$foo->setServer('SHUT');
    
    # stop() - stops IIDBMS server (transactions rolled back)
    #
    $ret = $foo->stop();

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

This module provides an API to the iimonitor utility for
Ingres RDBMS, which provides local control of IIDBMS servers
and sessions (system and user conections).

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 FUNCTIONS

=head2 new($serverId)
Connects to an IIDBMS server.

Takes the server id as argument to identify which server
to control.

The server id can be obtained through Ingres::Utility::IIName module.

=cut

sub new {
	my $class = shift;
	my $this = {};
	$class = ref($class) || $class;
	bless $this, $class;
	if (! defined($ENV{'II_SYSTEM'})) {
		die $class . ": Ingres environment variable II_SYSTEM not set";
	}
	my $iimonitor_file = $ENV{'II_SYSTEM'} . '/ingres/bin/iimonitor';
	
	if (! -x $iimonitor_file) {
		die $class . ": Ingres utility cannot be executed: $iimonitor_file";
	}
	$this->{cmd} = $iimonitor_file;
	$this->{xpct} = new Expect::Simple {
				Cmd => $iimonitor_file,
				Prompt => [ -re => 'IIMONITOR>\s+' ],
				DisconnectCmd => 'QUIT',
				Verbose => 0,
				Debug => 0,
				Timeout => 10
        } or die $this . ": Module Expect::Simple cannot be instanciated.";
	return $this;
}

=head2 showServer($serverStatus)

Returns the server status.

Takes the server status to query:

 LISTEN = server listening to new connections
 
 SHUTDOWN = server waiting for connections to close to
end process.

Returns 'OPEN', 'CLOSED' or 'PENDING' (for shutdown).

=cut

sub showServer {
	my $this = shift;
	my $server_status = uc (@_ ? shift : '');
	if ($server_status) {
		if ($server_status != 'LISTEN') {
			if ($server_status != 'SHUTDOWN') {
				die $this . ": invalid status: $server_status";
			}
		}
	}
	#print $this . ": cmd = $cmd";
	my $obj = $this->{xpct};
	$obj->send( 'SHOW SERVER ' . $server_status );
	my $before = $obj->before;
	while ($before =~ /\ \ /) {
		$before =~ s/\ \ /\ /g;
	}
	my @antes = split(/\r\n/,$before);
	return join($RS,@antes);
}

=head2 setServer

Changes the server status to the state indicated by the argument:

 SHUT = server will shutdown after all connections are closed

 CLOSED = stops listening to new connections

 OPEN = reestablishes listening to new connections

=cut

sub setServer {
	my $this = shift;
	my $server_status = uc (shift);
	if (! $server_status) {
		die $this . ': no status given';
	}
	if ($server_status != 'SHUT') {
		if ($server_status != 'CLOSED') {
			if ($server_status != 'OPEN') {
				die $this . ": invalid status: $server_status";
			}
		}
	}
	#print $this . ": cmd = $cmd";
	my $obj = $this->{xpct};
	$obj->send( 'SET ' . $server_status );
	my $before = $obj->before;
	while ($before =~ /\ \ /) {
		$before =~ s/\ \ /\ /g;
	}
	my @antes = split(/\r\n/,$before);
	print "\@antes: " . join(":",@antes);
	print 'before: ' . $obj->before . "\n";
	print 'after: ' . $obj->after . "\n";
	print 'match_str: ' . $obj->match_str, "\n";
	print 'match_idx: ' . $obj->match_idx, "\n";
	#print 'error_expect: ' . $obj->error_expect . "\n";
	#print 'error: ' . $obj->error . "\n";

	my   $expect_object = $obj->expect_handle;
	return;
	
}

=head2 stopServer

Stops server immediatly, rolling back transactions and closing all connections.

=cut

sub stopServer {
	my $this = shift;
	my $obj = $this->{xpct};
	$obj->send( 'STOP');
	my $before = $obj->before;
	while ($before =~ /\ \ /) {
		$before =~ s/\ \ /\ /g;
	}
	my @antes = split(/\r\n/,$before);
	return;
	
}

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Ingres environment variable II_SYSTEM not set >>

Ingres environment variables should be set on the user session running
this module.
II_SYSTEM provides the root install dir (the one before 'ingres' dir).
LD_LIBRARY_PATH also. See Ingres RDBMS docs.

=item C<< Ingres utility cannot be executed: _COMMAND_FULL_PATH_ >>

The IIMONITOR command could not be found or does not permits execution for
the current user.

=item C<< invalid status: _SERVER_STATUS_PARAM_ >>

The setServer() method received an invalid argument.
Should be LISTEN, SHUTDOWN or let void.

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Requires Ingres environment variables, such as II_SYSTEM and LD_LIBRARY_PATH.
See Ingres RDBMS documentation.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

Expect::Simple


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-ingres-utility-iimonitor at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Ingres::Utility::IIMonitor

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Ingres-Utility-IIMonitor>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Ingres-Utility-IIMonitor>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Ingres-Utility-IIMonitor>

=item * Search CPAN

L<http://search.cpan.org/dist/Ingres-Utility-IIMonitor>

=back


=head1 ACKNOWLEDGEMENTS

Thanks to Computer Associates (CA) for licensing Ingres as
open source, and let us hope for Ingres Corp to keep it that way.

=head1 AUTHOR

Joner Cyrre Worm  C<< <FAJCNLXLLXIH at spammotel.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Joner Cyrre Worm C<< <FAJCNLXLLXIH at spammotel.com>. All rights reserved.


Ingres is a registered brand of Ingres Corporation.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1; # End of Ingres::Utility::IIMonitor
__END__
