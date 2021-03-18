#! /usr/bin/perl
$ENV{"LC_ALL"} = "POSIX";
use strict;
use utf8; # for \x{nnn} regex
use warnings;
use IPC::Open3;

# init server hash
my %server = ();

systemInfo();
hash_walk(\%server, [], \&print_keys_and_value);

sub systemInfo
{
    $server{'rtm.info.rtm.version'} = "1.0.12";
   
    my $fnret = processes();
    if (ok($fnret))
    {
        $server{"os.load.processesactive"} = $fnret->{value}->{active};
        $server{"os.load.processesup"} = $fnret->{value}->{up};
    }
    else
    {
        print STDERR "Error with processes \n";
    }
    $fnret = _getTopProcess();
    if (ok($fnret))
    {
       # values in server hash
    }
    else
    {
        print STDERR "Error with getTopProcess \n";
    }
    $fnret = _getPortsAndInfos();
    if (ok($fnret))
    {
       # values in server hash
    }
    else
    {
        print STDERR "Error with getPortsAndInfos \n";
    }
    $fnret = uptime();
    if (ok($fnret))
    {
        $server{"rtm.info.uptime"} = $fnret->{value};
    }
    else
    {
        print STDERR "Error with uptime \n";
    }

    # hostname
    $fnret = execute('hostname');
    if (ok($fnret) and defined($fnret->{value}[0]))
    {
        $server{"rtm.hostname"}=$fnret->{value}[0];
    }
    else
    {
        $server{"rtm.hostname"}="Unknow";
    } 
}

# get processes running/count
sub processes
{
    my $fnret = execute('/bin/ps --no-headers -C noderig,beamium -o sess | sort -n | uniq');
    if ( $fnret->{status} != 100 )
    {
        print STDERR $fnret->{msg}." \n";
        return { status => 500, msg => "ps error: ".$fnret->{msg}." \n" };
    }
    else
    {
        my $rtm_sids = $fnret->{value};
        $fnret = execute('/bin/ps --no-headers -A -o sess,state,command');
        if( $fnret->{status} != 100 )
        {
            print STDERR "ps error: ".$fnret->{msg}."\n";
            return { status => 500, msg => "ps error: ".$fnret->{msg}." \n" };
        }
        else
        {
            my $active = 0;
            my $total = 0;
            my $ids = $fnret->{value};
            
            foreach my $line (@{$ids})
            {
                next if $line !~ /(\d+)\s+(\S+)/;
                my $sid = $1;
                my $state = $2;
                if (grep $sid == $_, @{$rtm_sids})
                {
                    next;
                }
                ++$total;
                ++$active if $state =~ /^R/;
            }
            return {status=>100, value => {up => $total, active=>$active}};
        }
    }
}

# top process
sub _getTopProcess
{
    my $fnret = execute('/bin/ps -A -o vsz,cmd --sort=-vsz --no-headers | head -n 7 | grep -vE "[0123456789]+[ ]/usr/bin/(noderig|beamium)"');
    if ( $fnret->{status} != 100 )
    {
        print STDERR "ps error: ".$fnret->{msg}." \n";
        return { status => 500, msg => "ps error: ".$fnret->{msg}."\n" };
    }
    else
    {
        for (my $i=1; $i <= 5; $i++)
        {
            $server{"rtm.info.mem.top_mem_".$i."_name"} = "Unknown";
            $server{"rtm.info.mem.top_mem_".$i."_size"} = "Unknown";
        }
        my $i=0;
        my @name;
        foreach (@{$fnret->{value}})
        {
            next unless m/\s*(\d+)\s+(.+)/;
            @name=split ' ', $2;
            $i++;
            $server{'rtm.info.mem.top_mem_'.$i.'_size'}=$1;
            $server{'rtm.info.mem.top_mem_'.$i.'_name'}=$name[0];
        }
        return {status=>100};
    }
}

# get port and associated infos
sub _getPortsAndInfos
{
    my $maxListenPort = 50;
    my $fnret = execute('/bin/netstat -tlenp | grep LISTEN | grep -v \'tcp6\' | awk \'{print $4"|"$9}\'');
    if ( $fnret->{status} != 100 )
    {
        print STDERR $fnret->{msg}."\n";
        return { status => 500, msg => "netstat error: ".$fnret->{msg}."\n" };
    }
    else
    {
        my $netstatTable = $fnret->{value};
        if (open(my $fh, '<', '/etc/passwd'))
        {
            my @passwd;
            chomp(@passwd = <$fh>);
            close($fh);
            my %passwdHash;
            foreach my $passwdLine (@passwd)
            {
                $passwdLine =~ /^([^:]+):[^:+]:(\d+):/;
                $passwdHash{$2} = $1;
            }
            my $i = 0;
            foreach my $line (@{$netstatTable})
            {
                my @tempTable = split(/\|/, $line);
                my $socketInfo = $tempTable[0];
                my $procInfo = $tempTable[1];
                $socketInfo =~ /:(\d+)$/;
                my $port = $1;
                $socketInfo =~ /(.+):\d+$/;
                my $ip = $1;
                $ip =~ s/\./-/g;
                $ip =~ s/[^0-9\-]//g;
                if ($ip eq "")
                {
                    $ip = 0;
                }
                @tempTable = split(/\//, $procInfo);
                my $pid = $tempTable[0];
                if (open($fh, '<', "/proc/$pid/cmdline"))
                {
                    my $cmdline;
                    chomp($cmdline = <$fh>);
                    $cmdline =~ s/\x{0}/ /g;
                    my @cmdLine = split ' ', $cmdline;
                    $cmdline = $cmdLine[0];
                    close($fh);
                    if (open($fh, '<', "/proc/$pid/status"))
                    {
                        my @status;
                        chomp(@status = <$fh>);
                        close($fh);
                        my $statusLine = join("|", @status);
                        $statusLine =~ /Uid:\s(\d+)/;
                        my $uid = $1;
                        my $username = '';
                        if (defined $passwdHash{$uid})
                        {
                            $username = $passwdHash{$uid};
                        }
                        my $procName = $tempTable[1];
                        my $exe = readlink("/proc/$pid/exe");
                        $server{'rtm.info.tcp.listen.ip-' . $ip . '.port-' . $port . '.pid'} = $pid;
                        $server{'rtm.info.tcp.listen.ip-' . $ip . '.port-' . $port . '.procname'} = $procName;
                        $server{'rtm.info.tcp.listen.ip-' . $ip . '.port-' . $port . '.cmdline'} = $cmdline;
                        $server{'rtm.info.tcp.listen.ip-' . $ip . '.port-' . $port . '.exe'} = $exe;
                        $server{'rtm.info.tcp.listen.ip-' . $ip . '.port-' . $port . '.username'} = $username;
                        $server{'rtm.info.tcp.listen.ip-' . $ip . '.port-' . $port . '.uid'} = $uid;
                        $i++;
                        last if $i >= $maxListenPort;
                    }
                    else
                    {
                        print STDERR "Could not open /proc/$pid/status";
                        return {status=>500};
                    }
                }
                else
                {
                     print STDERR "Could not open /proc/$pid/cmdline";
                     return {status=>500};
                }
            }
            return {status=>100};
        }
        else
        {
            print STDERR "Could not open /etc/passwd";
            return {status=>500};
        }
    }
}

#uptime
sub uptime
{
    if (open(my $fh, '<', "/proc/uptime"))
    {
        my $uptime = <$fh>;
        close($fh);
        $uptime =~ /^(\d+)/;
        $uptime = $1;
        return {status=>100, value => $uptime};
    }
    else
    {
        print STDERR "Cannot open /proc/uptime";
        return {status => 500, msg => "Cannot open /proc/loadavg" };
    }
}

sub print_keys_and_value {
    my ($k, $v, $key_list) = @_;
    $v =~ s/^\s+|\s+$//g;
    my $key;
    foreach (@$key_list)
    {
        if ($key)
        {
            $key = $key.".".$_;
        }
        else
        {
            $key = $key || "";
            $key = $key.$_;
        }
    }
    if (defined($key))
    {
        print "{\"metric\":\"$key\",\"timestamp\":".time.",\"value\":\"".$v."\"}\n";
    }
}

sub hash_walk {
    my ($hash, $key_list, $callback) = @_;
    while (my ($key, $value) = each (%$hash))
    {
        $key =~ s/^\s+|\s+$//g;
        push @$key_list, $key;
        if (ref($value) eq 'HASH')
        {
            hash_walk($value,$key_list,$callback)
        }
        else
        {
            $callback->($key, $value, $key_list);
        }
        pop @$key_list;
    }
}

sub ok
{
    my $arg = shift;
    if ( ref $arg eq 'HASH' and $arg->{status} eq 100 )
    {
        return 1;
    }
    elsif (ref $arg eq 'HASH' and $arg->{status} eq 500 and defined($arg->{msg}))
    {
        print STDERR $arg->{msg};
    }
    return 0;
}

sub execute
{
    my ($bin, @args) = @_;
    defined($bin) or return { status => 201, msg => 'No binary specified (execute)' };

    #print("Executing : ".$bin." ".join(" ", @args".\n"));
    my ($in, $out);
    my $pid = IPC::Open3::open3($in, $out, $out, $bin, @args);
    $pid or return { status => 500, msg => 'Failed to fork : '.$! };

    local $/;

    my $stdout = <$out>;
    my $ret    = waitpid($pid, 0);
    my $status = ($? >> 8);

    close($in);
    close($out);
    my @stdout = split(/\n/, $stdout);
    if ($ret != $pid)
    {
        return { status => 500, msg => 'Invalid fork return (waitpid)', value => $stdout };
    }
    elsif ($status != 0 and $bin ne '/bin/ps')
    {
        return { status => 500, msg => 'Binary '.$bin.' exited on a non-zero status ('.$status.')', value => $stdout };
    }
    else
    {
        # Ok
    }
    return { status => 100, value => \@stdout };
}
