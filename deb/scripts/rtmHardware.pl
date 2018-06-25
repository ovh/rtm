#! /usr/bin/perl
$ENV{"LC_ALL"} = "POSIX";
use strict;
use utf8; # for \x{nnn} regex
use warnings;
use IPC::Open3;

# init server hash
my %server = ();
$server{'rtm.info.kernel.release'} = "Unknown";
$server{'rtm.info.kernel.version'} = "Unknown";
$server{'rtm.info.release.os'} = "Unknown";
$server{'rtm.info.bios_vendor'} = "Unknown";
$server{'rtm.info.bios_version'} = "Unknown";
$server{'rtm.info.bios_date'} = "Unknown";
$server{'rtm.hw.mb.manufacture'} = "Unknown";
$server{'rtm.hw.mb.name'} = "Unknown";
$server{'rtm.hw.mb.serial'} = "Unknown";
$server{'rtm.hw.cpu.name'} = "Unknown";
$server{'rtm.hw.cpu.number'} = "Unknown";
$server{'rtm.hw.cpu.cache'} = "Unknown";
$server{'rtm.hw.cpu.mhz'} = "Unknown";
$server{'rtm.info.check.vm'} = "False";
$server{'rtm.info.check.oops'} = "False";

my %globalSgPaths = ();
my @dmesg_lines = ();

rtmHardware();
hash_walk(\%server, [], \&print_keys_and_value);

# main
sub rtmHardware
{
    my $fnret = CPUInfo();
    if (ok($fnret))
    {
        # ok values in server hash
    }
    else
    {
        print "Error with CPUInfo \n";
    }
    $fnret = getSgPaths();
    if( ok($fnret) )
    {
        %globalSgPaths = %{$fnret->{value}};
    }
    $fnret = getDmesg();
    if( ok($fnret) )
    {
        @dmesg_lines = @{$fnret->{value}}
    }
    $fnret = kernel();
    if (ok($fnret))
    {   
        # ok values in server hash
    }
    else
    {
        print "Error with kernel_oops \n";
    }
    $fnret = os();
    if (ok($fnret))
    {   
        # ok values in server hash
    }
    else
    {
        print "Error with os \n";
    }
    $fnret = motherboard();
    if (ok($fnret))
    {
        # ok values in server hash
    }
    else
    {
        print "Error with motherboard \n";
    }
    $fnret = disk();
    if (ok($fnret))
    {   
        # ok values in server hash
    }
    else
    {
        print "Error with disk \n";
    }
    $fnret = lspci();
    if (ok($fnret))
    {
        # ok values in server hash
    }
    else
    {
        print "Error with lspci \n";
    }
}

# CPU info
sub CPUInfo
{
    my %cpu_info = ( 'cpu_no' => 0 );
    $server{'rtm.hw.cpu.number'} = 0;
    if (open(my $fh, '<' ,"/proc/cpuinfo"))
    {
        while( <$fh> )
        {
            chomp($_);
            if ($_ =~ /^model name\s+:\s(.*)/)
            {
                $server{'rtm.hw.cpu.name'} = $1;
                $server{'rtm.hw.cpu.number'} += 1;
            }
            if ($_ =~ /^cpu MHz/)
            {
                s/cpu MHz\s+:\s*//g;
                $server{'rtm.hw.cpu.mhz'} = $_;
            }
            if ($_ =~ /^cache size/)
            {
                s/cache size\s+:\s*//g;
                $server{'rtm.hw.cpu.cache'} = $_;
            }
        }
        close($fh);
        return {status =>100};
    }
    else
    {
        print "Cannot open /proc/cpuinfo";
        return {status => 500, msg => "Cannot open /proc/loadavg" };
    }
}

sub kernel
{
    # kernel release
    my $fnret = execute('uname -r');
    if ( $fnret->{status} != 100  or !defined($fnret->{value}[0]))
    {
        print $fnret->{msg}." \n";
        return { status => 500, msg => "uname error: ".$fnret->{msg}};
    }
    else
    {
        $server{'rtm.info.kernel.release'}=$fnret->{value}[0];
    }
    # kernel version
    $fnret = execute('uname -v');
    if ( $fnret->{status} != 100 or !defined($fnret->{value}[0]))
    {
        print $fnret->{msg}. "\n";
        return { status => 500, msg => "uname error: ".$fnret->{msg} };
    }
    else
    {
        $server{'rtm.info.kernel.version'}=$fnret->{value}[0];
    }
    return {status=>100};
}

sub os
{
    my $fnret =execute("lsb_release","-a");
    if ( $fnret->{status} != 100 )
    {
        print "Error ".$fnret->{msg}." \n";
        # maybe red hat:
        if (open(my $fh, '<', "/etc/redhat-release"))
        {
            # yes!
            my $os_release;
            chomp($os_release = <$fh>);
            close($fh);
            $server{'rtm.info.release.os'} = $os_release;
            return{status=>100};
        }
        else
        {
            print "Cannot open /etc/redhat-release";
            return {status => 500, msg => "Cannot open /etc/redhat-release" };
        }
    }
    else
    {
        foreach my $line (@{$fnret->{value}})
        {
            if ($line =~ /^Distributor ID:\s+(.*)/i)
            {
                $server{'rtm.info.release.os'} = $1;
            }
            if ($line =~ /^Release:\s+(.*)/i)
            {
                $server{'rtm.info.release.os'} = $server{'rtm.info.release.os'}." ".$1;
            }
            if ($line =~ /^Codename:\s+(.*)/i)
            {
                $server{'rtm.info.release.os'} = $server{'rtm.info.release.os'}." ".$1;
            }
        }
        return {status=>100};
    }
}

# motherboard
sub motherboard
{
    my $fnret = execute('dmidecode');
    if ( $fnret->{status} != 100 )
    {
        print $fnret->{msg}." \n";
        return { status => 500, msg => "dmidecode error: ".$fnret->{msg}};
    }
    else
    {
        for (my $i = 0; $i < @{$fnret->{value}}; $i++)
        {
            # Bios
            if($fnret->{value}[$i] =~ /^\s*BIOS Information/i)
            {
                my $biosVendor = $fnret->{value}[$i+1];
                $biosVendor =~ /Vendor:\s+(.*)/;
                $server{'rtm.info.bios_vendor'} = $1;
                my $biosVersion = $fnret->{value}[$i+2];
                $biosVersion =~ /Version:\s+(.*)/;
                $server{'rtm.info.bios_version'} = $1;
                my $biosRelease = $fnret->{value}[$i+3];
                $biosRelease =~ /Release Date:\s+(.*)/;
                $server{'rtm.info.bios_date'} = $1;
            }
            # motherboard
            if($fnret->{value}[$i] =~ /^\s*Base Board Information/i)
            {
                my $manufacturer = $fnret->{value}[$i+1];
                $manufacturer =~ /Manufacturer:\s+(.*)/;
                $server{'rtm.hw.mb.manufacture'} = $1;
                my $mbName = $fnret->{value}[$i+2];
                $mbName =~ /Product Name:\s+(.*)/;
                $server{'rtm.hw.mb.name'} = $1;
                my $mbSerial = $fnret->{value}[$i+4];
                $mbSerial =~ /Serial Number:\s+(.*)/;
                $server{'rtm.hw.mb.serial'} = $1;
            }
            # memory
            if($fnret->{value}[$i] =~ /^\s*Memory Device/i)
            {
                my $bank = $fnret->{value}[$i+9];
                $bank =~ /Bank Locator:\s+(.*)/;
                $bank = $1;
                next if !$bank;
                $bank =~ s/\s//g;
                $bank =~ s/[\s\.\/\\_]/-/g;
                my $locator = $fnret->{value}[$i+8];
                $locator =~ /Locator:\s+(.*)/;
                $locator = $1;
                next if !$locator;
                $locator =~ s/\s//g;
                $locator =~ s![\s./\\_#]!-!g;
                my $size = $fnret->{value}[$i+5];
                $size =~ /Size:\s+(.*)/;
                $size = $1;
                next if !$size;
                $size =~ s/\s*MB\s*//g;
                chomp($size);
                if ($bank . $locator ne "")
                {
                    $server{'rtm.hw.mem.bank-'.$bank . '-' . $locator} = $size;
                }
            }
        }
        return {status=>100};
    }
}

# get disk
sub disk
{
    my $fnret = execute('lsblk -r --nodeps -o name 2>/dev/null');
    if ( $fnret->{status} != 100 )
    {
        print $fnret->{msg}." \n";
        return { status => 500, msg => "lsblk error: ".$fnret->{msg}};
    }
    else
    {
        my $lsblk = $fnret->{value};
        foreach my $line (@{$lsblk})
        {
            if ($line =~ /^(?!NAME)(?<disk>[\w]+)/)
            {
                my $disk = $1;
                $server{'rtm.info.hdd'}{$disk}{'model'}="Unknown";
                $server{'rtm.info.hdd'}{$disk}{'capacity'}="Unknown";
                $server{'rtm.info.hdd'}{$disk}{'serial'}="Unknown";
                $server{'rtm.info.hdd'}{$disk}{'temperature'}=0;
            }
        }
        # smart on all disk
        foreach my $disk (keys %{$server{'rtm.info.hdd'}})
        {
            my $diskSmart = "/dev/".$disk;
            my $before = time();
            if ($diskSmart =~ /dev\/nvme(\d+)n(\d+)/)
            {
                $diskSmart = "/dev/nvme".$1;
            }
            my $fnret =  execute("smartctl -a $diskSmart 2>/dev/null");
            if ( $fnret->{status} != 100 )
            {
                print $fnret->{msg}." \n";
                next;
            }
            else
            {
                my $after = time();
                my $smartTime = $after - $before;
                $server{'rtm.info.hdd'}->{$disk}->{'smart'}->{'time'} = $smartTime;
                $server{'rtm.info.hdd'}->{$disk}->{link_type} = 'sata';
                my $filename = "/sys/class/block/$disk/queue/rotational";
                my $fh;
                my $diskType = 'hdd';
                if( -e $filename and open($fh, '<', $filename) )
                {
                    my $rotational = <$fh>;
                    chomp($rotational);
                    close($fh);
                    if( "$rotational" eq "0" )
                    {
                        $diskType = "ssd";
                    }
                }

                if( $disk =~ /nvme/ )
                {
                    $server{'rtm.info.hdd'}->{$disk}->{link_type} = 'pcie';
                    $diskType = 'nvme';
                }

                $server{'rtm.info.hdd'}->{$disk}->{disk_type} = $diskType;
                my $smartctl = $fnret->{value};
                my $smart_other_error = 0;
                foreach my $line (@{$smartctl})
                {
                    if ( $line =~ /^Transport\s*protocol\s*:\s+SAS/i )
                    {
                        $server{'rtm.info.hdd'}->{$disk}->{link_type} = 'sas';
                        next;
                    }
                    if ($line =~ /^(?:Product|Device Model|Model Number):\s+(.*)$/i or $line =~ /Device:\s+([^\s].+)Version/i )
                    {
                        $server{'rtm.info.hdd'}{$disk}{'model'}=$1;
                        next;
                    }
                    if ($line =~ /^Serial Number:.(.*)$/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'serial'}=$1;
                        next;
                    }
                    if ($line =~ /.*Capacity:\s+.*\[(.*)\]/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'capacity'}=$1;
                        next;
                    }
                    if ($line =~ /^Firmware Version:.(.*)$/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'firmware'}=$1;
                        next;
                    }
                    if ($line =~ /^\s+5 Reallocated_Sector_Ct.*\s+(\d+)$/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'smart'}{'reallocated-sector-count'}=$1;
                        next;
                    }
                    if ($line =~ /^187 Reported_Uncorrect.*\s+(\d+)$/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'smart'}{'reported-uncorrect'}=$1;
                        next;
                    }
                    if ($line =~ /^196 Reallocated_Event_Count.*\s+(\d+)$/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'smart'}{'realocated-event-count'}=$1;
                        next;
                    }
                    if ($line =~ /^197 Current_Pending_Sector.*\s+(\d+)$/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'smart'}{'current-pending-sector'}=$1;
                        next;
                    }
                    if ($line =~ /^198 Offline_Uncorrectable.*\s+(\d+)$/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'smart'}{'offline-uncorrectable'}=$1;
                        next;
                    }
                    if ($line =~ /^199 UDMA_CRC_Error_Count.*\s+(\d+)$/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'smart'}{'udma-crc-error'}=$1;
                        next;
                    }
                    if ($line =~ /^200 Multi_Zone_Error_Rate.*\s+(\d+)$/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'smart'}{'multizone-error-rate'}=$1;
                        next;
                    }
                    if ($line =~ /^209 Offline_Seek_Performa?nce.*\s+(\d+)$/)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'smart'}{'offline-seek-performance'}=$1;
                        next;
                    }
                    if ($line =~ /^\s+9 Power_On_Hours.*\s+(\d+)$/)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'smart'}{'power-on-hours'}=$1;
                        next;
                    }
                    if ($line =~ /Error \d+ (occurred )?at /)
                    {
                        if ($line =~ /^read:.+(\d+)$/)
                        {
                            $server{'rtm.info.hdd'}{$disk}{'smart'}{'uncorrected-read-errors'}=$1;
                            next;
                        }
                        if ($line =~ /^write:.+(\d+)$/)
                        {
                            $server{'rtm.info.hdd'}{$disk}{'smart'}{'uncorrected-write-errors'}=$1;
                            next;
                        }
                    }
                    if ($line =~ /^temperature\s+:\s+([0-9]+)/i)
                    {
                        $server{'rtm.info.hdd'}{$disk}{'temperature'}=$1;
                        next;
                    }
                }

                if ($diskType ne 'nvme')
                {
                    my $fnret= execute("hddtemp $diskSmart 2>/dev/null");
                    if ( $fnret->{status} != 100 )
                    {
                        print $fnret->{msg}." \n";
                        next;
                    }
                    elsif (defined $fnret->{value}[0])
                    {
                        my $hddtemp=$fnret->{value}[0];
                        if ($hddtemp =~ m/.*:.*:\s(\d+)/)
                        {
                            $server{'rtm.info.hdd'}{$disk}{'temperature'}=$1;
                        }
                    }
                }
        
                # New way to gather stats
                my $linkType = $server{'rtm.info.hdd'}->{$disk}->{link_type};
                my $realDisk = $disk;
                if( $disk !~ /^\/dev\// )
                {
                    $realDisk = "/dev/$disk";
                }
                my $fnret = gatherStats( smartDisk => $realDisk, sgPaths => \%globalSgPaths, linkType => $linkType );
                if(ok($fnret) and $fnret->{value})
                {
                    my $smartUpdate = $fnret->{value};
                    my %smartInfo = defined $server{'rtm.info.hdd'}->{$disk}->{smart} ? %{$server{'rtm.info.hdd'}->{$disk}->{smart}} : ();
                    @smartInfo{keys %{$smartUpdate}} = values %{$smartUpdate};
                    $server{'rtm.info.hdd'}->{$disk}->{smart} = \%smartInfo;
                }
        
                # Get related dmesg errors
                $fnret = countDmesgErrors(
                    diskName => $disk,
                    lines => \@dmesg_lines,
                );
                if( ok($fnret) )
                {
                    $server{'rtm.info.hdd'}->{$disk}->{'dmesg.io.errors'} = $fnret->{value};
                }
                $fnret = iostatCounters(
                    diskName => $disk,
                );
                if( ok($fnret) )
                {
                    defined $fnret->{value}->{'r_await'} and $server{'rtm.info.hdd'}->{$disk}->{'iostat.read.avg.wait'} = $fnret->{value}->{'r_await'};
                    defined $fnret->{value}->{'w_await'} and $server{'rtm.info.hdd'}->{$disk}->{'iostat.write.avg.wait'} = $fnret->{value}->{'w_await'};
                    defined $fnret->{value}->{'rrqm/s'} and $server{'rtm.info.hdd'}->{$disk}->{'iostat.read.merged.per.sec'} = $fnret->{value}->{'rrqm/s'};
                    defined $fnret->{value}->{'wrqm/s'} and $server{'rtm.info.hdd'}->{$disk}->{'iostat.write.merged.per.sec'} = $fnret->{value}->{'wrqm/s'};
                    defined $fnret->{value}->{'r/s'} and $server{'rtm.info.hdd'}->{$disk}->{'iostat.read.per.sec'} = $fnret->{value}->{'r/s'};
                    defined $fnret->{value}->{'w/s'} and $server{'rtm.info.hdd'}->{$disk}->{'iostat.write.per.sec'} = $fnret->{value}->{'w/s'};
                    defined $fnret->{value}->{'%idle'} and $server{'rtm.info.hdd'}->{$disk}->{'iostat.busy'} = $fnret->{value}->{'%idle'};
                    defined $fnret->{value}->{'%util'} and $server{'rtm.info.hdd'}->{$disk}->{'iostat.busy'} = $fnret->{value}->{'%util'};
                    defined $fnret->{value}->{'rkB/s'} and $server{'rtm.info.hdd'}->{$disk}->{'iostat.readkb.per.sec'} = $fnret->{value}->{'rkB/s'};
                    defined $fnret->{value}->{'wkB/s'} and $server{'rtm.info.hdd'}->{$disk}->{'iostat.writekb.per.sec'} = $fnret->{value}->{'wkB/s'};
                }
            }
        }
        return {status=>100};
    }
}

#lspci
sub lspci
{
    my $fnret = execute("lspci -n 2>/dev/null");
    if ( $fnret->{status} != 100 )
    {
        print $fnret->{msg}." \n";
        return { status => 500, msg => "lspci error: ".$fnret->{msg}};
    }
    else
    {
        my %lspci_info = ();
        foreach my $line (@{$fnret->{value}})
        {
                if ($line =~ /^(\S+).+:\s+(.+:.+)\s+\(/i)
                {
                    $lspci_info{$1} = $2;
                }
                elsif ($line =~ /^(\S+).+:\s+(.+:.+$)/i)
                {
                    $lspci_info{$1} = $2;
                }
        }
        foreach my $tempKey (keys %lspci_info)
        {
            my $temp = $tempKey;
            $temp =~ s/\:|\.|\_/-/g;
            $server{'rtm.hw.lspci.pci.'.$temp}=$lspci_info{$tempKey};
        }
        return {status=>100};
    }
}

sub getSectorSize {
    my %params = @_;
    my $disk = $params{disk};
    my $fnret = execute("blockdev --getss $disk");
    if ( $fnret->{status} != 100 )
    {
        print $fnret->{msg}." \n";
        return { status => 500, msg => "Error: unable to get sector size for device $disk"};
    }
    elsif (defined($fnret->{value}[0]))
    {
        my $sectorSize = $fnret->{value}[0];
        if( $sectorSize !~ /\d+/ )
        {
            return { status => 500, msg => "Error: unexpected format for sectorSize; $sectorSize" };
        }
        return { status => 100, value => $sectorSize };
    }
    else
    {
        return { status => 500};
    }
}

sub getSmartOverallHealthStatus
{
    my %params = @_;
    my $smartDisk = $params{smartDisk};
    my @lines = `smartctl -H $smartDisk 2>/dev/null`;
    my $last_status = $? >> 8;
    $last_status = $last_status & 7;
    if( $last_status != 0 )
    {
        return { status => 500, msg => "Error: unable to get overall health for device $smartDisk" };
    }
    foreach my $line (@lines)
    {
        if( $line =~ /SMART\s+Health\s+Status:\s+OK|SMART\s+overall-health\s+self-assessment\s+test\s+result:\s+PASSED/ )
        {
            return { status => 100, value => { status => 'success' } };
        }
    }
    return { status => 100, value => { status => 'failed' } };
}

sub getSmartCommonInfo
{
    my %params = @_;
    my $smartDisk = $params{smartDisk};
    my $health = -1;
    my $loggedErrorCount = -1;

    if ($smartDisk =~ /dev\/nvme(\d+)n(\d+)/)
    {
        $smartDisk = "/dev/nvme".$1;
    }

    # overall health as boolean 0 -> KO, 1 -> OK
    my $fnret = getSmartOverallHealthStatus(smartDisk => $smartDisk);
    if(ok($fnret))
    {
        $health = $fnret->{value}->{status} eq 'success' ? 1 : 0;
    }

    # any logged error count
    $fnret = getSmartLoggedError(smartDisk => $smartDisk);
    if( ok($fnret) )
    {
        $loggedErrorCount = $fnret->{value}->{logged_error_count};
    }

    return {
        status => 100,
        value => {
            "global-health" => $health,
            "logged-error-count" => $loggedErrorCount
        }
    };
}

sub gatherStats
{
    my %params = @_;
    my $linkType = $params{linkType};
    my %sgPaths = %{$params{sgPaths} || {} };
    my $smartDisk  = $params{smartDisk}  || return { status => 201, msg => 'Missing argument' };
    my $fnret;
    if( $linkType and $linkType eq 'sas' )
    {
        my $sgDisk = $sgPaths{$smartDisk}->{sgDrive};
        if( ! $sgDisk )
        {
            return { status => 500, msg => "Unable to get sg path for $smartDisk" };
        }
        $fnret = getSmartStatsSAS( sgDisk => $sgDisk, smartDisk => $smartDisk );
    }
    elsif( $linkType and $linkType eq 'pcie' )
    {
        $fnret = getSmartStatsNvme( smartDisk => $smartDisk );
    }
    else
    {
        $fnret = getSmartStatsATA(smartDisk => $smartDisk);
    }
    return $fnret;
}

sub getSmartStatsATA
{
    my %params = @_;
    my $smartDisk  = $params{smartDisk}  || return { status => 201, msg => 'Missing argument' };
    my $sectorSize = getSectorSize( disk => $smartDisk );
    ok($sectorSize) or return $sectorSize;
    $sectorSize = $sectorSize->{value};

    my $fnret = getSmartStatsAndAttributes(smartDisk => $smartDisk);
    my $smartStats     = $fnret->{value};
    my $bytesWritten   = undef;
    my $bytesRead      = undef;
    my $percentageUsed = undef;
    my $powerOnHours   = undef;
    my $powerCycles    = undef;
    my $linkFailures       = -1;
    my $eccCorrectedErrs = -1;
    my $eccUncorrectedErrs = -1;
    my $reallocSectors = -1;
    my $uncorrectedEccPage = -1;
    my $commandTimeout = -1;
    my $offlineUncorrectable = -1;
    my $temperature = -1;
    my $highestTemperature = -1;
    my $lowestTemperature = -1;
    my $pendingSectors = -1;

    ##
    ## Gather bytesWritten information
    ##

    # Expressed in logical sectors : more precise, use it when possible
    if ( my ($gplPage) = grep { $_->{page} eq '0x01' and $_->{offset} eq '0x018' } @{$smartStats->{statistics}} )
    {
        $gplPage->{value} =~ /^\d+\z/ or return { status => 500, msg => 'Unconsistent ATA write counter' };
        $bytesWritten = $gplPage->{value}*$sectorSize;
    }

    # For Samsung SSD, expressed in LBA
    if ( my ($attr) = grep { $_->{name} eq 'Total_LBAs_Written' } @{$smartStats->{attributes}} )
    {
        $attr->{raw_value} =~ /^\d+\z/ or return { status => 500, msg => 'Unconsistent ATA write counter' };
        $attr->{raw_value} *= $sectorSize;
        $attr->{raw_value} >= ($bytesWritten||0) and $bytesWritten = $attr->{raw_value};
    }

    # 32MB blocks, less precise but better than nothing
    # Seems to be expressed in MB and not in MiB as stated, or maybe a firmware bug on some models ?
    if ( my ($attr) = grep { $_->{name} eq 'Host_Writes_32MiB' } @{$smartStats->{attributes}} )
    {
        $attr->{raw_value} =~ /^\d+\z/ or return { status => 500, msg => 'Unconsistent ATA write counter' };
        $attr->{raw_value} *= 32*(2**20);
        $attr->{raw_value} >= ($bytesWritten||0) and $bytesWritten = $attr->{raw_value};
    }

    ##
    ## Gather BytesRead information
    ##
    # Expressed in logical sectors : more precise, use it when possible
    if ( my ($gplPage) = grep { $_->{page} eq '0x01' and $_->{offset} eq '0x028' and $_->{value}  =~ /^\d+\z/ } @{$smartStats->{statistics}} )
    {
        $bytesRead = $gplPage->{value}*$sectorSize;
    }
    elsif ( my ($attr) = grep { ( ( $_->{id} eq 242 ) or ( $_->{name} eq 'Total_LBAs_Read' )) and $_->{raw_value} =~ /^\d+\z/ } @{$smartStats->{attributes}} )
    {
        $attr->{raw_value} *= $sectorSize;
        $attr->{raw_value} >= ($bytesRead||0) and $bytesRead = $attr->{raw_value};
    }
    # 32MB blocks, less precise but better than nothing
    # Seems to be expressed in MB and not in MiB as stated, or maybe a firmware bug on some models ?
    elsif ( my ($smartAttr) = grep { $_->{name} eq 'Host_Reads_32MiB' and $_->{raw_value} =~ /^\d+\z/ } @{$smartStats->{attributes}} )
    {
        $smartAttr->{raw_value} *= 32*(2**20);
        $smartAttr->{raw_value} >= ($bytesRead||0) and $bytesRead = $smartAttr->{raw_value};
    }

    ##
    ## Gather percentageUsed information
    ##

    # From 0 to 255 (Yup, a percentage from 0 to 255, no problem)
    # Note that some SSD have a MWI reported as less than 100 in attribute pages, while statistics page return 0
    if ( my ($gplPage) = grep { $_->{page} eq '0x07' and $_->{offset} eq '0x008' } @{$smartStats->{statistics}} )
    {
        $gplPage->{value} =~ /^\d+\z/ or return { status => 500, msg => 'Unconsistent ATA MWI counter' };
        $percentageUsed = $gplPage->{value};
    }

    # From 0 to 100. Raw value has no meaning AFAIK
    if ( my ($attr) = grep { $_->{name} eq 'Media_Wearout_Indicator' } @{$smartStats->{attributes}} )
    {
        $attr->{value} =~ /^\d+\z/ or return { status => 500, msg => 'Unconsistent ATA MWI counter' };
        $attr->{value} = 100-$attr->{value};
        $attr->{value} >= ($percentageUsed||0) and $percentageUsed = $attr->{value};
    }

    # For Samsung SSD, rated from 0 to 100. For other brands, may not mean the same thing
    # Raw value is Program/Erase cycles. Disk is considered "used" when TLC > 1000 or MLC > 3000
    if ( my ($attr) = grep { $_->{name} eq 'Wear_Leveling_Count' } @{$smartStats->{attributes}} )
    {
        $attr->{value} =~ /^\d+\z/ or return { status => 500, msg => 'Unconsistent ATA MWI counter' };
        $attr->{value} = 100-$attr->{value};
        $attr->{value} >= ($percentageUsed||0) and $percentageUsed = $attr->{value};
    }

    ##
    ## Gather powerOnHours information
    ##

    # For ATA devices, should be nearly always known
    if ( my ($attr) = grep { $_->{name} eq 'Power_On_Hours' } @{$smartStats->{attributes}} )
    {
        $attr->{raw_value} =~ /^\d+\z/ or return { status => 500, msg => 'Unconsistent ATA POH counter' };
        $powerOnHours = $attr->{raw_value};
    }

    ##
    ## Gather powerCycles information
    ##
    # For ATA devices, should be nearly always known
    if ( my ($attr) = grep { ( ($_->{id} eq 12) or ($_->{name} eq 'Power_Cycle_Count') ) and $_->{raw_value} =~ /^\d+\z/ } @{$smartStats->{attributes}} )
    {
        $powerCycles = $attr->{raw_value};
    }

    ##
    ## Gather eccCorrectedErrs information
    ##

    if ( my ($attr) = grep { $_->{id} eq 195 } @{$smartStats->{attributes}} )
    {
        if( $attr->{raw_value} =~ /^\d+\z/ )
        {
            $eccCorrectedErrs = $attr->{raw_value};
        }
        else
        {
            $eccCorrectedErrs = -1;
        }
    }

    ##
    ## Gather eccUncorrectedErrs information (187)
    ##

    # Prefer the statistics section when available
    if ( my ($uncorrectedEccPage) = grep { $_->{page} eq '0x04' and $_->{offset} eq '0x008' } @{$smartStats->{statistics}} )
    {
        if( $uncorrectedEccPage->{value} !~ /^\d+\z/ )
        {
            $eccUncorrectedErrs = -1;
        }
        else
        {
            $eccUncorrectedErrs = $uncorrectedEccPage->{value};
        }
    }
    elsif ( my ($attr) = grep { $_->{id} eq 187 } @{$smartStats->{attributes}} )
    {
        if( $attr->{raw_value} =~ /^\d+\z/ )
        {
            $eccUncorrectedErrs = $attr->{raw_value};
        }
        else
        {
            $eccUncorrectedErrs = -1;
        }
    }

    #
    # Reallocated sectors (5)
    #
    if ( my ($reallocSectorPage) = grep { $_->{page} eq '0x03' and $_->{offset} eq '0x020' } @{$smartStats->{statistics}} )
    {
        if( $reallocSectorPage->{value} =~ /^\d+\z/ )
        {
            $reallocSectors = $reallocSectorPage->{value};
        }
        else
        {
            $reallocSectors = -1;
        }
    }
    elsif ( my ($attr) = grep {
                (($_->{id} eq 5) or $_->{name} =~ /^(Reallocate_NAND_Blk_Cnt|Reallocated_Sector_Ct|Total_Bad_Block_Count)$/)
                    and $_->{raw_value} =~ /^\d+\z/ } @{$smartStats->{attributes}} )
    {
        $reallocSectors = $attr->{raw_value};
    }

    #
    # Current_Pending_Sector_Count (197)
    #

    if ( my ($attr) = grep { $_->{id} eq 197 } @{$smartStats->{attributes}} )
    {
        if( $attr->{raw_value} =~ /^\d+\z/ )
        {
            $pendingSectors = $attr->{raw_value};
        }
        else
        {
            $pendingSectors = -1;
        }
    }

    #
    # Offline_Uncorrectable (198)
    #

    if ( my ($attr) = grep { $_->{id} eq 198 and $_->{raw_value} =~ /^\d+\z/ } @{$smartStats->{attributes}} )
    {
        $offlineUncorrectable = $attr->{raw_value};
    }

    #
    # Command_Timeout (188)
    #
    if ( my ($attr) = grep { $_->{id} eq 188 and $_->{raw_value} =~ /^\d+\z/ } @{$smartStats->{attributes}} )
    {
        $commandTimeout = $attr->{raw_value};
    }

    #
    # Temperature (194)
    #
    if( my ($tempStat) = grep { $_->{page} eq '0x05' and $_->{offset} eq '0x008' and $_->{value} =~ /^\d+\z/ } @{$smartStats->{statistics}} )
    {
        $temperature = $tempStat->{value};
    }
    elsif ( my ($attr) = grep { $_->{id} eq 194 and $_->{raw_value} =~ /^\d+\z/ } @{$smartStats->{attributes}} )
    {
        $temperature = $attr->{raw_value};
    }

    if( my ($tempStat) = grep { $_->{page} eq '0x05' and $_->{offset} eq '0x020' and $_->{value} =~ /^\d+\z/ } @{$smartStats->{statistics}})
    {
        $highestTemperature = $tempStat->{value};
    }

    if( my ($tempStat) = grep { $_->{page} eq '0x05' and $_->{offset} eq '0x028' and $_->{value} =~ /^\d+\z/ } @{$smartStats->{statistics}})
    {
        $lowestTemperature = $tempStat->{value};
    }

    $fnret = getSataPhyErrorCounters(smartDisk => $smartDisk);
    if( ok($fnret) )
    {
        ##
        ## Gather failures information
        ##
        ## SATA Phy Event Counters (GP Log 0x11)
        ## ID      Size     Value  Description
        ## 0x000b  4            0  CRC errors within host-to-device FIS
        if ( my ($attr) = grep { $_->{id} eq '0x000b' and $_->{value} =~ /^\d+\z/ } @{$fnret->{value}})
        {
            $linkFailures = $attr->{value};
        }
    }

    $fnret = getSmartCommonInfo(smartDisk => $smartDisk);
    my %commonInfo = ();
    if( ok($fnret) )
    {
        %commonInfo = %{$fnret->{value}}
    }

    return {
        status => 100,
        value  => {
            "bytes-written"   => $bytesWritten,
            "bytes-read"      => $bytesRead,
            "percentage-used" => $percentageUsed || 0,
            "power-on-hours"   => $powerOnHours,
            "power-cycles" => $powerCycles,
            "reported-corrected" => $eccCorrectedErrs,
            "reported-uncorrect" => $eccUncorrectedErrs,
            "reallocated-sector-count" => $reallocSectors,
            "current-pending-sector" => $pendingSectors,
            "offline-uncorrectable" => $offlineUncorrectable,
            "command-timeout" => $commandTimeout,
            "link-failures" => $linkFailures,
            "temperature" => $temperature,
            "highest-temperature" => $highestTemperature,
            "lowest-temperature" => $lowestTemperature,
            #"logged-error-count" => $loggedErrorCount, # in commonInfo
            #"global-health" => $health, # in commonInfo
            #rawReport => $rawReport, # in commonInfo
            %commonInfo
        },
    };
}

sub getSmartStatsAndAttributes
{
    my %params = @_;
    my $smartDisk = $params{smartDisk};

    if ($smartDisk =~ /dev\/nvme(\d+)n(\d+)/)
    {
        $smartDisk = "/dev/nvme".$1;
    }
    my $cmd = "timeout 15 smartctl -l devstat -A ".$smartDisk." 2>/dev/null";
    my @smartctl =  `$cmd`;
    my $status = $? >> 8;
    my $smart_filtered_status = $status & 7;
    if( $smart_filtered_status != 0 )
    {
        return { status => 201, msg => "Unable to gather smart stats correctly. status: $smart_filtered_status" };
    }

    my %result = (attributes => [], statistics => []);
    my %in     = ();

    foreach my $line ( @smartctl )
    {
        $line =~ s/\s+$//g;
        $line eq '' and next;

        if ( !$in{smart} and $line eq '=== START OF READ SMART DATA SECTION ===' )
        {
            $in{smart} = 1;
            next;
        }
        $in{smart} or next;

        # Vendor Specific SMART Attributes with Thresholds:
        # ID# ATTRIBUTE_NAME          FLAG     VALUE WORST THRESH TYPE      UPDATED  WHEN_FAILED RAW_VALUE
        if ( $line eq 'Vendor Specific SMART Attributes with Thresholds:' or $line =~ /^ID#\sATTRIBUTE_NAME/ )
        {
            $in{statistics} = 0;
            $in{attributes} = 1;
        }
        # Device Statistics (GP Log 0x04)
        # Page Offset Size         Value  Description
        elsif ( $line eq 'Device Statistics (GP Log 0x04)' or $line =~ /^Page\s+Offset\sSize/ )
        {
            $in{attributes} = 0;
            $in{statistics} = 1;
        }
        elsif (
            $in{attributes} and
            $line =~ /^\s*
                (\d+)\s
                (\S+)\s+
                (0x[0-9a-f]{4})\s+
                (\d{3})\s+
                (\d{3})\s+
                (\d{3}|-{3})\s+
                (\S+)\s+
                (\S+)\s+
                (-|FAILING_NOW|In_the_past)\s+
                (.+)
            $/x
        )
        {
            push(@{$result{attributes}}, {
                id        => $1,
                name      => $2,
                flag      => $3,
                value     => $4,
                worst     => $5,
                thresh    => $6,
                type      => $7,
                updated   => $8,
                when      => $9,
                raw_value => $10,
            });
        }
        elsif ( $in{statistics} and $line =~ /^\s*(\d+|0x[\da-f]{2})\s+={5}\s{2}=\s+=\s{2}==(?:=\s{2}==)?\s(.+)\s==$/ )
        {
            # Ok
        }
        elsif ( $in{statistics} and $line =~ /^\s*(\d+|0x[\da-f]{2})\s+(0x[0-9a-f]{3})\s+(\d+)\s+(-?\d+|-)\s*([CDN-]{3}|~|)\s+(.+)$/ )
        {
            if (length($5) <= 1)
            {
                # Smartctl 6.4
                push(@{$result{statistics}}, {
                    page       => sprintf('0x%02d', $1),
                    offset     => $2,
                    size       => $3,
                    value      => $4,
                    normalized => ($5 eq '~') ? 1 : 0,
                    desc       => $6,
                });
            }
            else
            {
                my @flags = split('', $5);

                push(@{$result{statistics}}, {
                    page                    => $1,
                    offset                  => $2,
                    size                    => $3,
                    value                   => $4,
                    monitored_condition_met => ($flags[0] ne '-') ? 1 : 0,
                    supports_dsn            => ($flags[1] ne '-') ? 1 : 0,
                    normalized              => ($flags[2] ne '-') ? 1 : 0,
                    desc                    => $6,
                });
            }
        }
        # SMART Attributes Data Structure revision number: 1
        elsif ( $line =~ /SMART Attributes Data Structure revision number: \d+$/ )
        {
            # Don't care for now
        }
        elsif ( $line eq 'Device Statistics (GP/SMART Log 0x04) not supported' )
        {
            # Sad, but ok
        }
        #                               |_ ~ normalized value
        #                                |||_ C monitored condition met
        elsif ( $line =~ /^\s+\|+_+\s[CDN~]\s[a-zA-Z\s]+$/ )
        {
            # Device statistics footer (optional)
        }
        else
        {
            return { status => 500, msg => 'Unhandled line in smartctl return' };
        }
    }
    return { status => 100, value => \%result };
}

sub getSmartLoggedError
{
    my %params = @_;
    my $smartDisk = $params{smartDisk};
    my $cmd = "timeout 15 smartctl -l error,256 $smartDisk 2>/dev/null";
    my @smartLines = `$cmd`;
    my $last_status = $? >> 8;
    my $smart_status = $last_status & 7;
    if( $smart_status != 0 )
    {
        $cmd = "timeout 15 smartctl -l error $smartDisk 2>/dev/null";
        @smartLines = `$cmd`;
        $last_status = $? >> 8;
        $smart_status = $last_status & 7;
        if( $smart_status != 0 )
        {
            return { status => 500, msg => 'Unable to get smartctl logged errors' };
        }
    }
    my $smartReport = join( "\n", @smartLines );

    my %details = ();
    if ($smartReport =~ /^ATA Error Count:\s*(\d+)/m)
    {
        # SATA with ata error
        $details{logged_error_count} = $1;
        $details{disk_type}          = 'ata';
    }
    elsif ($smartReport =~ /^No Errors Logged/m)
    {
        # SATA/NVME without logged error
        $details{logged_error_count} = 0;
        $details{disk_type}          = ($smartReport =~ /\(NVMe Log/) ? 'nvme' : 'ata';
    }
    elsif ($smartReport =~ /^Non-medium\s+error\s+count\s*:\s*(\d+)/m)
    {
        # SAS (and probably SCSI)
        $details{logged_error_count} = $1;
        $details{disk_type}          = 'sas';
    }
    elsif ($smartReport =~ /\(NVMe Log/)
    {
        # "No Errors Logged" flag is not present, error have been logged
        my ($filtered) = $smartReport =~ /Num\s+ErrCount\s+SQId\s+CmdId\s+Status\s+PELoc\s+LBA\s+NSID\s+VS\n(.+)$/s;

        # ... (17 entries not shown
        if (defined($filtered) and ($filtered =~ /^(.+)\n\.{3} \(\d+ entries not shown\)(?:\r?\n)*$/s))
        {
            $filtered = $1;
        }
        assert(defined($filtered) and ($filtered ne ''));

        $details{logged_error_count} = 0;
        $details{disk_type}          = 'nvme';
        $details{logged_errors}      = [];

        foreach my $line (split(/[\n\r]+/, $filtered))
        {
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;

            #   0          1     0  0x0000  0x4212  0x028            0   255     -
            my @elems = split(/\s+/, $line);
            @elems == 9 or return {status => 500, msg => 'Failed to parse "smartctl -l" return'};

            push(@{$details{logged_errors}}, {
                id        => $elems[0],
                err_count => $elems[1],
                sq_id     => $elems[2],
                cmd_id    => $elems[3],
                status    => $elems[4],
                pe_loc    => $elems[5],
                lba       => $elems[6],
                nsid      => $elems[7],
                vs        => $elems[8],
            });
            $details{logged_error_count} += 1;
        }
        assert($details{logged_error_count} > 0);
    }
    else
    {
        return { status => 200, msg => 'Unhandled smartct -l error return' };
    }
    return { status => 100, value => \%details, details => $smartReport };
}

sub getSataPhyErrorCounters
{
    my %params = @_;
    my $smartDisk = $params{smartDisk};

    if ($smartDisk =~ /dev\/nvme(\d+)n(\d+)/)
    {
        $smartDisk = "/dev/nvme".$1;
    }
    my $cmd = "timeout 15 smartctl -l sataphy $smartDisk 2>/dev/null";
    my @smartLines = `$cmd`;
    my $last_status = $? >> 8;
    my $smart_status = $last_status & 7;
    if( $smart_status != 0 )
    {
        return { status => 500, msg => 'Unable to get smart phy error counters' };
    }
    my $smartReport = join( "\n", @smartLines );

    my @counters = ();
    foreach my $line (split(/[\n\r]+/, $smartReport))
    {
        $line =~ s/\s+$//;
        $line eq '' and next;

        if (($line =~ /^(smartctl|Copyright|SATA Phy|ID\s+Size)/) and !@counters)
        {
            # Header
        }
        elsif ($line =~ /^(0x[0-9a-f]{4})\s+(\d+)\s+(\d+)\s+(.+)$/)
        {
            push(@counters, {
                id    => $1,
                size  => $2,
                value => $3,
                desc  => $4,
            });
        }
        else
        {
            return { status => 500, msg => 'Unhandled line in smartctl return' };
        }
    }
    return { status => 100, value => \@counters };
}

sub getSgPaths
{
    my $fnret = execute("lsscsi -tg 2>/dev/null");
    if ( $fnret->{status} != 100 )
    {
        print $fnret->{msg}." \n";
        return { status => 500, msg => "Unable to gather sg paths ".$fnret->{msg}};
    }
    else
    {
        my %drives;
        foreach my $line ( @{$fnret->{value}} )
        {
            if ( $line =~ /
                disk\s+
                sas:0x([0-9a-f]+)\s+
                (\/dev\/sd[a-z]+|-)\s+
                (\/dev\/sg\d+|)
                /x)
            {
                ( $2 eq '-' ) and next;
                $drives{$2} = {
                    sasAddress  => $1,
                    sdDrive     => $2,
                    sgDrive     => $3,
                };
            }
        }
        return { status => 100, value => \%drives };
    }
}

# ##################################
# Sg logs subs
sub getSupportedLogPages
{
    my %params = @_;
    my $devPath = $params{devPath};

    my $fnret = execute("sg_logs -x $devPath 2>/dev/null");
    if ( $fnret->{status} != 100 )
    {
        print $fnret->{msg}." \n";
        return { status => 500, msg => "Unable to get sg logs pages ".$fnret->{msg}};
    }
    else
    {
        my @pages = ();
        foreach my $i ( 0 .. @{$fnret->value} )
        {
            my $line = $fnret->{value}[$i];
            $line    =~ s/^\s+$//;
            # Supported log pages  [0x0]:
            if ( $i == 0 )
            {
                # Page name
            }
            #     0x00        Supported log pages
            #     0x0d        Temperature
            elsif ( $line =~ /^\s{4}(0x[\da-f]{2})\s+(.+)$/ )
            {
                push(@pages, {code => $1, desc => $2});
            }
            else
            {
                return { status => 500, msg => 'Unhandled sg_logs return' };
            }
        }
        return { status => 100, value => \@pages };
    }
}

sub getGenericLogPage
{
    my %params = @_;
    my $devPath     = $params{devPath};
    my $page        = $params{page};
    my $stopOnValue = $params{stopOnValue};

    my $fnret = execute("sg_logs -x --page $page $devPath");
    if ( $fnret->{status} != 100 )
    {
        print $fnret->{msg}." \n";
        return { status => 500, msg => "Unable to get sg logs requested page ".$fnret->{msg}};
    }
    else
    {
        my @lines = @{$fnret->{value}};
        my $category   = '';
        my %details    = ();
        my $headerSeen = 0;

        foreach my $i ( 0 .. $#lines )
        {
            my $line = $lines[$i];
            $line    =~ s/^\s+$//;

            # Read error counter page  [0x3]
            if ( substr($line, 0, 1) ne ' ' and $line =~ /\[0x[0-9a-f]{1,2}\]$/ )
            {
                # Header
                $headerSeen and return { status => 200, msg => 'Can not parse specified log page ('.$page.')' };
                $headerSeen++;
            }
            elsif ( defined($stopOnValue) and ($line =~ $stopOnValue) )
            {
                # Stop on value reached, stop here
                last;
            }
            #   Total times correction algorithm processed = 1418
            #   Percentage used endurance indicator: 2%
            elsif ( $line =~ /^\s{2}([^\s][^=:]+)(?:\s=|:)\s(.+)$/ )
            {
                $details{$1} = $2;
            }
            #   Status parameters:
            elsif ( $line =~ /^\s{2}([^\s][^=:]+):$/ )
            {
                $category = $1;
                $details{$category} ||= {};
            }
            #     Accumulated power on minutes: 939513 [h:m  15658:33]
            elsif ( $category and $line =~ /^\s{4}([^\s][^=:]+)(?:\s=|:)\s(.+)$/ )
            {
                $details{$category}{$1} = $2;
            }
            else
            {
                return { status => 500, msg => 'Unhandled sg_logs return' };
            }
        }

        # Sanity check
        if ( !$headerSeen )
        {
            return { status => 500, msg => 'sg_logs return may have not been properly handled' };
        }

        return { status => 100, value => \%details };
    }
}

sub getBackgroundScanResultsLogPage
{
    my %params = @_;
    my $devPath = $params{devPath};

    my $fnret = execute("sg_logs -x --page 0x15 $devPath 2>/dev/null");
    if ( $fnret->{status} != 100 )
    {
        print $fnret->{msg}." \n";
        return { status => 500, msg => "Unable to get background scan page: ".$fnret->{msg}."\n"};
    }
    else
    {
        my @lines = @{$fnret->{value}};
        my $category   = '';
        my %details    = ();
        my $headerSeen = 0;

        foreach my $i ( 0 .. $#lines )
        {
            my $line = $lines[$i];
            $line    =~ s/^\s+$//;

            # Read error counter page  [0x3]
            if ( substr($line, 0, 1) ne ' ' and $line =~ /\[0x[0-9a-f]{1,2}\]$/ )
            {
                # Header
                $headerSeen and return { status => 200, msg => 'Can not parse specified log page (0x15)' };
                $headerSeen++;
            }
            #   Total times correction algorithm processed = 1418
            #   Percentage used endurance indicator: 2%
            elsif ( $line =~ /^\s{2}([^\s][^=:]+)(?:\s=|:)\s(.+)$/ )
            {
                $details{$1} = $2;
            }
            #   Status parameters:
            elsif ( $line =~ /^\s{2}([^\s][^=:]+):$/ )
            {
                $category = $1;
                $details{$category} ||= {};
            }
            #     Accumulated power on minutes: 939513 [h:m  15658:33]
            elsif ( $category and $line =~ /^\s{4}([^\s][^=:]+)(?:\s=|:)\s(.+)$/ )
            {
                $details{$category}{$1} = $2;
            }
            #   Medium scan parameter # 1 [0x1]
            elsif ( $line =~ /^\s{2}Medium scan parameter #\s*(\d+)\s*\[0x[0-9a-f]+\]$/ )
            {
                # Start of scan results, not handled for now
                last;
            }
            else
            {
                return { status => 500, msg => 'Unhandled sg_logs return' };
            }
        }

        # Sanity check
        if ( !$headerSeen )
        {
            return { status => 500, msg => 'sg_logs return may have not been properly handled' };
        }

        if ( $details{'Status parameters'} and my $pohLine = $details{'Status parameters'}{'Accumulated power on minutes'} )
        {
            # 939513 [h:m  15658:33]
            my ($poh) = $pohLine =~ /^\d+\s\[h:m\s+(\d+):(\d+)\]$/;
            $details{'Status parameters'}{'Accumulated power on hours'} = $poh;
        }
        return { status => 100, value => \%details };
    }
}

sub getDmesg
{
    my $fnret = execute('/bin/dmesg -T | tail -n 15000');
    if ( $fnret->{status} != 100 )
    {   
        print $fnret->{msg}." \n";
        return { status => 500, msg => "dmesg error: ".$fnret->{msg}};
    }
    else
    {
        my $dmesg = $fnret->{value};
        # 2 checks
        # check for allocation failed or kernel oops
        my $results = $fnret->{value};
    my @filtered = ();
        foreach my $line (@{$dmesg})
        {
            chomp $line;
            if ( $line =~ /(I\/O|critical medium) error/
                    or $line =~ /Buffer I\/O error on device/
                    or $line =~ /Unhandled (error|sense) code/ )
            {
                push @filtered, $line;
            }
            if ($line =~ /allocation failed/i)
            {
                $server{'rtm.info.check.vm'}="True";
            }
            if ($line =~ /Oops/i)
            {
                $server{'rtm.info.check.oops'}="True";
            }
        }
        return { status => 100, value => \@filtered };
    }
}

sub countDmesgErrors
{
    my %params = @_;
    my $diskName = $params{diskName};
    my @lines = @{$params{lines}};
    my $counter = 0;

    foreach my $line (@lines)
    {
        if ( $line =~ /(I\/O|critical medium) error, dev $diskName, sector/
                or $line =~ /Buffer I\/O error on device $diskName,/
                or $line =~ /\[$diskName\]\s+Unhandled (error|sense) code/ )
        {
            $counter++;
        }
    }
    return { status => 100, value => $counter };
}

sub iostatCounters
{
    my %params = @_;
    my $diskName = $params{diskName} || return { status => 500, msg => "Missing diskName" };
    my $devPath = "/dev/".$diskName;

    my $fnret = execute("/usr/bin/iostat -d -x $devPath");
    if ( $fnret->{status} != 100 )
    {
        print $fnret->{msg}." \n";
        return { status => 500, msg => "iostat error: ".$fnret->{msg}};
    }
    else
    {
        my $counterLabelsLine = undef;
        my $countersLine = undef;
        my @lines = @{$fnret->{value}};

        foreach my $line (@lines)
        {
            chomp $line;
            if( $line =~ /^\s*device(?:\s*:|\s)(.*)$/i )
            {
                $counterLabelsLine = $1;
                chomp( $counterLabelsLine );
                $counterLabelsLine =~ s/^\s*//;
                $counterLabelsLine =~ s/\s*$//;
            }
            elsif( $line =~ /^\s*$diskName\s(.*)$/ )
            {
                $countersLine = $1;
                chomp( $countersLine );
                $countersLine =~ s/^\s*//;
                $countersLine =~ s/\s*$//;
            }
        }

        if( !defined($counterLabelsLine) or !defined($countersLine) )
        {
            return { status => 500, msg => 'Unable to parse iostat' };
        }

        my @fields = split /\s+/, $counterLabelsLine;
        my @values = split /\s+/, $countersLine;

        if( scalar(@fields) != scalar(@values) )
        {
            return { status => 500, msg => 'Unexpected iostat parsing: '.scalar(@fields).' != '.scalar(@values) };
        }

        my $counters = {};
        for( my $i=0; $i<scalar(@fields); $i++)
        {
            $counters->{$fields[$i]} = $values[$i];
        }

        return { status => 100, value => $counters };
    }
}

sub getSmartStatsSAS
{
    my %params = @_;
    my $device = $params{sgDisk} || return { status => 201, msg => 'Missing argument' };
    my $smartDisk = $params{smartDisk} || return { status => 201, msg => 'Missing argument' };

    my $fnret = getSupportedLogPages(devPath => $device);
    ok($fnret) or return $fnret;

    my @supportedPages = @{$fnret->{value}};
    # Attempt to gather the same subset of information as via smart for sata drives
    my $bytesWritten   = undef;
    my $bytesRead      = -1;
    my $percentageUsed = undef;
    my $powerOnHours   = undef;
    my $linkFailures = -1;
    my $powerCycles = -1;
    my $eccCorrectedErrs = -1;
    my $eccUncorrectedErrs = -1;
    my $reallocSectors = -1;
    my $commandTimeout = -1;
    my $offlineUncorrectable = -1;
    my $temperature = -1;
    my $highestTemperature = -1;
    my $lowestTemperature = -1;
    my $pendingSectors = -1;

    # Write counter
    if ( grep { $_->{code} eq '0x02' } @supportedPages )
    {
        my $fnret = getGenericLogPage(devPath => $device, page => '0x02');
        ok($fnret) or return $fnret;

        $bytesWritten = $fnret->{value}->{'Total bytes processed'};
        $bytesWritten =~ /^\d+\z/ or return { status => 500, msg => 'Unconsistent SCSI write counter' };

        my $eccErrsU = $fnret->{value}->{'Total uncorrected errors'};
        my $eccErrsC = $fnret->{value}->{'Total errors corrected'};

        if( defined($eccErrsU) and $eccErrsU =~ /^\d+\z/ )
        {
            $eccUncorrectedErrs = $eccErrsU;
        }
        
        if( defined($eccErrsC) and $eccErrsC =~ /^\d+\z/  )
        {
            $eccCorrectedErrs = $eccErrsC;
        }
    }

    # SSD specific page
    if ( grep { $_->{code} eq '0x11' } @supportedPages )
    {
        # Note : STEC drives have additional log pages, but not interpreted by sg_logs as of version 1.24 20140523
        # We only care about MWI here, ignore them for now
        my $fnret = getGenericLogPage(
            devPath     => $device,
            page        => '0x11',
            stopOnValue => qr/^\s{2}Reserved\s\[parameter_code=0x[0-9a-f]{4}\]:$/,
        );
        ok($fnret) or return $fnret;

        $percentageUsed = $fnret->{value}->{'Percentage used endurance indicator'};
        $percentageUsed =~ s/%$//;
        $percentageUsed =~ /^\d+\z/ or return { status => 500, msg => 'Unconsistent SCSI MWI counter' };
    }

    # Power On Hours, hidden in 'Background scan results' page
    if ( grep { $_->{code} eq '0x15' } @supportedPages )
    {
        my $fnret = getBackgroundScanResultsLogPage(devPath => $device);
        ok($fnret) or return $fnret;

        $powerOnHours = $fnret->{value}->{'Status parameters'}->{'Accumulated power on hours'};
        $powerOnHours =~ /^\d+\z/ or return { status => 500, msg => 'Unconsistent SCSI POH counter' };
    }

    # Read counter
    if ( grep { $_->{code} eq '0x03' } @supportedPages )
    {
        my $fnret = getGenericLogPage(devPath => $device, page => '0x03');
        if ( ok($fnret) )
        {
            if( defined( $fnret->{value}->{'Total bytes processed'} ) and $fnret->{value}->{'Total bytes processed'} =~ /^\d+\z/ )
            {
                $bytesRead = $fnret->{value}->{'Total bytes processed'};
            }

            my $eccErrsU = $fnret->{value}->{'Total uncorrected errors'};
            my $eccErrsC = $fnret->{value}->{'Total errors corrected'};

            if( defined($eccErrsU) and $eccErrsU =~ /^\d+\z/ )
            {
                if( $eccUncorrectedErrs == -1 )
                {
                    $eccUncorrectedErrs = $eccErrsU;
                }
                else
                {
                    $eccUncorrectedErrs += $eccErrsU;
                }
            }

            if( defined($eccErrsC) and $eccErrsC =~ /^\d+\z/  )
            {
                if( $eccCorrectedErrs == -1 )
                {
                    $eccCorrectedErrs = $eccErrsC;
                }
                else
                {
                    $eccCorrectedErrs += $eccErrsC;
                }
            }
        }
    }

    # Power cycle count
    if ( grep { $_->{code} eq '0x0e' } @supportedPages )
    {
        my $fnret = getGenericLogPage(devPath => $device, page => '0x0e');
        if ( ok($fnret) )
        {
            $powerCycles = $fnret->{value}->{'Accumulated start-stop cycles'};
            if( $powerCycles !~ /^\d+\z/ )
            {
                $powerCycles = -1;
            }
        }
    }

    # Link failure errors
    if ( grep { $_->{code} eq '0x06' } @supportedPages )
    {
        my $fnret = getGenericLogPage(devPath => $device, page => '0x06');
        if ( ok($fnret) )
        {
            $linkFailures = $fnret->{value}->{'Non-medium error count'};
            if( $linkFailures !~ /^\d+\z/ )
            {
                $linkFailures = -1;
            }
        }
    }

    # Temperature
    if ( grep { $_->{code} eq '0x0d' } @supportedPages )
    {
        my $fnret = getGenericLogPage(devPath => $device, page => '0x0d');
        if ( ok($fnret) )
        {
            $temperature = $fnret->{value}->{'Current temperature'};
            if( $temperature =~ /^(\d+)\s*C/ )
            {
                $temperature = $1;
            }
            else
            {
                $temperature = -1;
            }
        }
    }

    my %commonInfo = ();
    if( $smartDisk )
    {
        $fnret = getSmartCommonInfo(smartDisk => $smartDisk);
        if( ok($fnret) )
        {
            %commonInfo = %{$fnret->{value}}
        }
    }

    return {
        status => 100,
        value  => {
            "bytes-written"   => $bytesWritten,
            "bytes-read"      => $bytesRead,
            "percentage-used" => $percentageUsed || 0,
            "power-on-hours"   => $powerOnHours,
            "power-cycles" => $powerCycles,
            "reported-corrected" => $eccCorrectedErrs,
            "reported-uncorrect" => $eccUncorrectedErrs,
            "reallocated-sector-count" => $reallocSectors,
            "current-pending-sector" => $pendingSectors,
            "offline-uncorrectable" => $offlineUncorrectable,
            "command-timeout" => $commandTimeout,
            "link-failures" => $linkFailures,
            "temperature" => $temperature,
            "highest-temperature" => $highestTemperature,
            "lowest-temperature" => $lowestTemperature,
            %commonInfo
        },
    };
}

sub getNvmeSmartStatistics
{
    my %params = @_;
    my $smartDisk = $params{smartDisk} || return { status => 201, msg => "Missing smartDisk param" };
    if ($smartDisk =~ /nvme(\d+)n(\d+)/)
    {
        $smartDisk = "/dev/nvme".$1;
    }
    my $cmd = "timeout 15 smartctl -A $smartDisk 2>/dev/null";
    my @smartLines = `$cmd`;
    my $last_status = $? >> 8;
    my $smart_status = $last_status & 7;
    if( $smart_status != 0 )
    {
        return { status => 500, msg => 'Unable to get smartctl info for nvme disk '.$smartDisk };
    }

    my %result = ();
    my $in     = 0;

    foreach my $line (@smartLines)
    {
        $line =~ s/\s+$//g;
        $line =~ s/^\s+//g;
        $line eq '' and next;

        if ($line eq '=== START OF SMART DATA SECTION ===')
        {
            $in++;
        }
        # SMART/Health Information (NVMe Log 0x02, NSID 0xffffffff)
        # SMART/Health Information (NVMe Log 0x02)
        elsif ($line =~ /^SMART\/Health Information \(NVMe Log 0x02(?:, NSID (0x[a-f0-9]+))?\)$/)
        {
            # Not used
        }
        # Temperature:                        45 Celsius
        # Power On Hours:                     7,262
        elsif ($in and $line =~ /^([^:]+):\s+([^\s].*)$/)
        {
            $result{$1} = $2;
        }
        elsif (!$in)
        {
            # Header
        }
        else
        {
            Logger::debug($line);
            return { status => 500, msg => 'Unhandled line in smartctl return' };
        }
    }

    $in or return {
        status => 500,
        msg    => 'Failed to parse smartctl return',
    };

    return { status => 100, value => \%result };
}

sub getSmartStatsNvme {
    my %params = @_;
    my $smartDisk = $params{smartDisk}  || return { status => 201, msg => 'Missing argument' };

    my $bytesWritten   = undef;
    my $bytesRead      = -1;
    my $percentageUsed = undef;
    my $powerOnHours   = undef;
    my $linkFailures       = -1;
    my $powerCycles    = -1;
    my $eccCorrectedErrs = -1;
    my $eccUncorrectedErrs = -1;
    my $reallocSectors = -1;
    my $commandTimeout = -1;
    my $offlineUncorrectable = -1;
    my $temperature = -1;
    my $highestTemperature = -1;
    my $lowestTemperature = -1;
    my $pendingSectors = -1;
    my $unsafeShutdowns = -1;
    my $criticalStatus = -1;

    my $fnret = getNvmeSmartStatistics(smartDisk => $smartDisk);
    ok($fnret) or return $fnret;

    my $smartStats     = $fnret->{value};

    if ( defined($smartStats->{'Data Units Written'}) )
    {
        $bytesWritten = $smartStats->{'Data Units Written'};

        # 27,745,697 [14.2 TB]
        # last part is optional when drive is brand new
        $bytesWritten =~ s/\s+\[[^\]]+\]$//;
        $bytesWritten =~ s/,//g;
        $bytesWritten =~ /^\d+\z/ or return {status => 500, msg => 'Unconsistent NVME write counter'};
        $bytesWritten *= (512*1000);
    }

    ## Not mandatory value, so if no value found, leave it undef
    if (defined($smartStats->{'Data Units Read'}))
    {
        $bytesRead = $smartStats->{'Data Units Read'};

        # 27,745,697 [14.2 TB]
        # last part is optional when drive is brand new
        $bytesRead =~ s/\s+\[[^\]]+\]$//;
        $bytesRead =~ s/,//g;
        if( $bytesRead !~ /^\d+\z/ )
        {
            $bytesRead = -1;
        }
        else
        {
            # According to smartctl source, always 512k and see here too:
            # https://www.seagate.com/www-content/product-content/ssd-fam/nvme-ssd/_shared/docs/100765362c.pdf
            # note, 1000, not 2**10
            $bytesRead *= (512*1000);
        }
    }

    if (defined($smartStats->{'Percentage Used'}))
    {
        $percentageUsed = $smartStats->{'Percentage Used'};
        $percentageUsed =~ s/%$//;
        $percentageUsed =~ /^\d+$/ or return {status => 500, msg => 'Unconsistent NVME MWI counter'};
    }

    if (defined($smartStats->{'Power On Hours'}))
    {
        $powerOnHours = $smartStats->{'Power On Hours'};
        $powerOnHours =~ s/,//g;
        $powerOnHours =~ /^\d+$/ or return {status => 500, msg => 'Unconsistent NVME POH counter'};
    }

    if (defined($smartStats->{'Power Cycles'}))
    {
        $powerCycles = $smartStats->{'Power Cycles'};
        $powerCycles =~ s/,//g;
        if( $powerCycles !~ /^\d+$/ )
        {
            $powerCycles = -1;
        }
    }

    if (defined($smartStats->{'Media and Data Integrity Errors'}))
    {
        $eccUncorrectedErrs = $smartStats->{'Media and Data Integrity Errors'};
        $eccUncorrectedErrs =~ s/,//g;
        if( $eccUncorrectedErrs !~ /^\d+$/ )
        {
            $eccUncorrectedErrs = -1;
        }
    }

    if ( defined($smartStats->{'Critical Warning'}))
    {
        $criticalStatus = $smartStats->{'Critical Warning'};
        $criticalStatus = hex $criticalStatus;
    }

    if ( defined($smartStats->{'Temperature'}))
    {
        $temperature = $smartStats->{'Temperature'};
        $temperature =~ s/,//g;
        if( $temperature =~ /(\d+)\s*C/ )
        {
            $temperature = $1;
        }
        else
        {
            $temperature = -1;
        }
    }

    if ( defined($smartStats->{'Unsafe Shutdowns'}))
    {
        $unsafeShutdowns = $smartStats->{'Unsafe Shutdowns'};
        $unsafeShutdowns =~ s/,//g;
        if( $unsafeShutdowns !~ /\d+/ )
        {
            $unsafeShutdowns = -1;
        }
    }

    my %commonInfo = ();
    if( $smartDisk )
    {
        $fnret = getSmartCommonInfo(smartDisk => $smartDisk);
        if( ok($fnret) )
        {
            %commonInfo = %{$fnret->{value}}
        }
    }

    return {
        status => 100,
        value  => {
            "bytes-written"   => $bytesWritten,
            "bytes-read"      => $bytesRead,
            "percentage-used" => $percentageUsed || 0,
            "power-on-hours"   => $powerOnHours,
            "power-cycles" => $powerCycles,
            "reported-corrected" => $eccCorrectedErrs,
            "reported-uncorrect" => $eccUncorrectedErrs,
            "reallocated-sector-count" => $reallocSectors,
            "current-pending-sector" => $pendingSectors,
            "offline-uncorrectable" => $offlineUncorrectable,
            "command-timeout" => $commandTimeout,
            "link-failures" => $linkFailures,
            "temperature" => $temperature,
            "highest-temperature" => $highestTemperature,
            "lowest-temperature" => $lowestTemperature,
            #"logged-error-count" => $loggedErrorCount,
            #"global-health" => $health,
            #rawReport => $rawReport,
            %commonInfo,
            # specific to nvme
            "critical-warning" => $criticalStatus,
            "unsafe-shutdowns" => $unsafeShutdowns
        },
    };
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
        print $arg->{msg};
    }
    return 0;
}

sub execute
{
    my ($bin, @args) = @_;
    defined($bin) or return { status => 201, msg => 'No binary specified (execute)' };

    my ($in, $out, $pid);
    eval { $pid = IPC::Open3::open3($in, $out, $out, $bin, @args)}; warn $@ if $@;
    
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
    elsif ($status != 0)
    {
        return { status => 500, msg => "Binary ".$bin." exited on a non-zero status (".$status.")\n", value => $stdout };
    }
    else
    {
        # Ok
    }
    return { status => 100, value => \@stdout };
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

sub print_keys_and_value {
    my ($k, $v, $key_list) = @_;
    if (defined($v))
    {
        $v =~ s/^\s+|\s+$//g;
    }
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
    if (defined($key) and defined($v))
    {
        print "{\"metric\":\"$key\",\"timestamp\":".time.",\"value\":\"".$v."\"}\n";
    }
}

