#!/usr/bin/perl
use HTML::TableExtract;
use LWP::Simple;
use File::Basename;
use File::Slurp qw(edit_file);
use Scalar::Util qw(looks_like_number);

# ---
# Let's add CLI interface to those functions
use Getopt::Long qw(:config bundling gnu_compat);
GetOptions('help' => sub{ HelpMessage() });

my $verbose = '';
my $grb = '';
# my %h = ('grb' => \$grb);
GetOptions( 'grb' => \$grb
          );

$grb = $ARGV[0];
print "GRB $grb\n";

my $trigger = _grbTrigger($grb);
print "- Trigger number: $trigger\n";

# $h{'grb'} = $ARGV[0];
# if (ok) {
#   print "$_ $h{$_}\n" for (keys %h);
# }
# ---

# download XRT WT and PC spectra from website
# input: GRB name
# output: spectra related files
sub _downloadXrtSpec(){
    my $grb = shift;
    my $trigger = &_grbTrigger($grb);
    my $url = 'http://www.swift.ac.uk/xrt_spectra/00'."$trigger".'/interval0.tar.gz';
    my $file = $grb.'.tar.gz';
    print "Downloading XRT spectra of GRB $grb ...\n";
    getstore($url, $file);
    print "Extracting files ...\n";
    mkdir $grb unless (-e $grb);
    system "tar zxf $file -C $grb";
    return $grb.'/';
}


# download XRT late time (>4000 s) spectrum from website
# input: GRB name
# output: late time spectrum related files
sub _downloadXrtLateSpec(){
    my $grb = shift;
    my $trigger = &_grbTrigger($grb);
    my $url = 'http://www.swift.ac.uk/xrt_spectra/00'."$trigger".'/late_time.tar.gz';
    my $file = $grb.'.late.tar.gz';
    print "Downloading late time XRT spectrum of GRB $grb ...\n" unless (-e $file);
    getstore($url, $file) unless (-e $file);
    print "Extracting files ...\n";
    mkdir $grb.'.late' unless (-e $grb.'.late');
    system "tar zxf $file -C $grb\.late";
    return $grb.'.late/';
}

# routine to download and parse online table
# input: link, headers
# output: table
sub _readHtmlTable(){
	my $url = shift;
	my $headers_ref = shift;
	my $file = (split /\//, $url)[-1];
	getstore($url,$file) unless (-e $file);
	my $te = HTML::TableExtract->new( headers => $headers_ref);
	$te->parse_file($file);
	return $te;
}

# iput: GRB and redshift online table
# output: hash of redshift to grb
sub _redshift(){
    my $grb = shift;
    # parse online table
    my $urlGrb = 'http://www.mpe.mpg.de/~jcg/grbgen.html';
    my @headersGrb = qw(GRB z);
    my $teGrb = &_readHtmlTable($urlGrb,\@headersGrb);

    # generate GRB and Trigger hashes
    my %grbRedshift;
    foreach ($teGrb -> rows){
    	@$_[0] =~ tr/SX//d; 	#remove X and S in the name indicating X-ray flash and Short GRB
        @$_[1] =~ tr/\<\>ph\?//d; 	#remove >, <, ph, and ? in the redshift
        $grbRedshift{@$_[0]} = @$_[1];
    }
    my $redshift = $grbRedshift{$grb};

    # missing or with A
    unless ($redshift) {
        my $lastLetter = chop $grb;
        if (looks_like_number($lastLetter)) {
            $grb = $grb.$lastLetter.'A';
            print "Change to search GRB $grb \n";
            $redshift = $grbRedshift{$grb};
        }elsif($lastLetter ne 'A'){
            return 0;
        }else{
            print "Change to search GRB $grb \n";
            $redshift = $grbRedshift{$grb};
            return $redshift;
        }
    }

    # find and output
    looks_like_number($redshift) ? return $redshift : return 0;
}


## input: trigger Number or GRB name
## output: GRB name or trigger Number
## by looking for website
sub _grbTrigger(){
#    my $grb = shift;
#    # parse online table
#    my $urlGrb = 'http://www.swift.ac.uk/grb_region/';
#    my @headersGrb = qw(Trigger name);
#    my $teGrb = &_readHtmlTable($urlGrb,\@headersGrb);
#
#    # generate GRB and Trigger hashes
#    my %grbToTrigger;
#    my %triggerToGrb;
#    foreach ($teGrb -> rows){
#    	@$_[1] =~ s/GRB //g; 	#remove X and S in the name indicating X-ray flash and Short GRB
#        $grbToTrigger{@$_[1]} = @$_[0];
#        $triggerToGrb{@$_[0]} = @$_[1];
#    }
#
#    # missing or with A for above method
#    unless ($grbToTrigger{$grb}) {
#        my $lastLetter = chop $grb;
#        if (looks_like_number($lastLetter)) {
#            $grb = $grb.$lastLetter.'A';
#            print "Change to search GRB $grb \n";
#        }elsif($lastLetter ne 'A'){
#            $grb = $grb.$lastLetter;
#        }else{
#            print "Change to search GRB $grb \n";
#        }

    # if GRB is not triggered by Swift (also work for Swift trigger), try to find the tigger number from swift product page
    my $grb = shift;

    my %grbToTrigger;

    use LWP::UserAgent qw();
    my $ua = LWP::UserAgent->new;
    my $url = 'http://www.swift.ac.uk/burst_analyser/getBurst.php?name='.$grb;
    my $response = $ua->get($url);
    my $finalLink = $response->request->uri;
    $grbToTrigger{$grb} = substr((split(/\//, $finalLink))[-1], 2);

    # missing or with A for above method
    if ($grbToTrigger{$grb} =~ m/name/){
        my $lastLetter = chop $grb;
        if (looks_like_number($lastLetter)) {
            $grb = $grb.$lastLetter.'A';
            print "Change to search GRB $grb \n";
            $url = 'http://www.swift.ac.uk/burst_analyser/getBurst.php?name='.$grb;
            $response = $ua->get($url);
            $finalLink = $response->request->uri;
            $grbToTrigger{$grb} = substr((split(/\//, $finalLink))[-1], 2);
        }elsif($lastLetter ne 'A'){
            $grb = $grb.$lastLetter;
        }else{
            print "Change to search GRB $grb \n";
            $url = 'http://www.swift.ac.uk/burst_analyser/getBurst.php?name='.$grb;
            $response = $ua->get($url);
            $finalLink = $response->request->uri;
            $grbToTrigger{$grb} = substr((split(/\//, $finalLink))[-1], 2);
        }
    }

    return $grbToTrigger{$grb};

    # convert and output, all the trigger numbers are bigger than 200000
#    if (looks_like_number($grb) && $grb>200000){
#        return $triggerToGrb{$$grb};
#    }else{
#        return $grbToTrigger{$$grb};
#    }

}


## input: trigger Number
## output: H density
## by looking for website
sub _nH(){
    my $trigger = shift;
    my $nH;
    my $doc = get('http://www.swift.ac.uk/grb_region/'.$trigger) || warn "GET failed";
    foreach my $line (split("\n", $doc)) {
        if ($line =~ m/Galactic N/){
            print $line
            $line =~/<td>(.+)&times;10<sup>(.+)<\/sup>\scm/;
            $line =~/<td>(.+)E(.+)\scm/ unless $1;
            $nH = $1*10**$2;
            last if $nH;
        }
    }
    return $nH if $nH;

    $doc = get('http://www.swift.ac.uk/xrt_spectra/00'.$trigger) || die "GET failed";
    foreach my $line (split("\n", $doc)) {
        if ($line =~ m/Galactic/){
            $line =~/<td>(.+)\s&times;.*10<sup>(.+)<\/sup>\scm/;
            $nH = $1*10**$2;
            last;
        }
    }
    print $nH;
    return $nH if $nH;

}

## input: trigger Number
## output: best RA, best Dec
## by looking for website
sub _bestPos(){
    my $trigger = shift;
    my $bestRa;
    my $bestDec;
    my $doc = get('http://www.swift.ac.uk/grb_region/'.$trigger) || die "GET failed";

    foreach my $line (split("\n", $doc)) {

        if ($line =~ m/Best RA/){
            $line =~/=\s(.*)\sd/;
            $bestRa = $1;
        }
        if ($line =~ m/Best Dec/){
            $line =~/=\s(.*)\sd/;
            $bestDec = $1;
            last;
        }
    }
    return ($bestRa, $bestDec);
}


## input: grb name, .pi filename, .rmf filename, .arf filename
## output: data points for plot, spectral figure, fitted parameters
sub _fitPLWithRedshift(){
    my $grb = shift;
    my $dataFilename = shift;
    my $respFilename = shift;
    my $arfFilename = shift;

    #my $path = dirname $dataFilename;
    my ($file,$path,$ext) = fileparse($dataFilename, qr/\.[^.]*/);

    ## search websites to find trigger, redshift and nH
    print "Searching for redshift ...\n";
    my $redshift = &_redshift($grb);
    unless($redshift){
        print "Cannot find redshift automatically.\n";
        print "Please input redshift manually (eg. 1.8):\n";
        chomp($redshift = <STDIN>);
    }
    print "Redshift: $redshift\n";
    print "Searching for trigger number ...\n";
    my $trigger = &_grbTrigger($grb);
    unless($trigger){
        print "Cannot find trigger number automatically.\n";
        print "Please input trigger number manually (eg. 716127):\n";
        chomp($trigger = <STDIN>);
    }
    print "Trigger Number: $trigger\n";
    print "Searching for Galaxy H density ...\n";
    my $nH = &_nH($trigger);
    unless($nH){
        print "Cannot find Galaxy H density automatically.\n";
        print "Please input Galaxy H density manually (eg. 1.2e21):\n";
        chomp($nH = <STDIN>);
    }
    print "nH: $nH\n";
    my $nH = $nH/1e22;

    ## names of output files
    my $plotDataFilename = "$path\/$file.plot.pl.txt";
    my $plotFigFilename = "$path\/$file.pl.eps";
    my $paramsFilename = "$path\/$file.params.pl.txt";
    my $paramsFitsFilename = "$path\/$file.params.pl.fits";

    unlink $plotDataFilename if (-e $plotDataFilename);
    unlink $plotFigFilename if (-e $plotFigFilename);
    unlink $paramsFilename if (-e $paramsFilename);
    unlink $paramsFitsFilename if (-e $paramsFitsFilename);

    ### generate XSPEC script
    my $xcmFilename = "$path\/$file.xcm";
    unlink $xcmFilename if (-e $xcmFilename);

    open my $xcmFile, '>', "$xcmFilename";
    print $xcmFile "data $dataFilename\n";
    print $xcmFile "resp $respFilename\n";
    print $xcmFile "arf $arfFilename\n";
    print $xcmFile "ign bad\n";
    print $xcmFile "ign **-0.3 10.-**\n";
    print $xcmFile "setplot energy\n";
    print $xcmFile "method leven 100 0.5\n";
    print $xcmFile "abund wilm\n";
    print $xcmFile "xsect vern\n";
    print $xcmFile "cosmo 70 0 0.73\n";
    print $xcmFile "xset delta -1\n";
    print $xcmFile "systematic 0\n";
    print $xcmFile "statistic cstat\n";
    print $xcmFile "setplot rebin 6 1024\n";
    print $xcmFile "model phabs*zphabs*po\n";
    print $xcmFile "$nH\n";
    print $xcmFile "0.1\n";
    print $xcmFile "$redshift\n";
    print $xcmFile "1.6\n";
    print $xcmFile "1\n";
    print $xcmFile "freeze 1\n";
    print $xcmFile "fit 10000 1e-1\n";
    print $xcmFile "fit\n";
    print $xcmFile "tclout plot euf x\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot euf xerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot euf y\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot euf yerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot res y\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot res yerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot ratio y\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot ratio yerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "setplot device $plotFigFilename /cps\n";
    print $xcmFile "plot euf residuals\n";
    print $xcmFile "log $paramsFilename\n";
    print $xcmFile "show rate; show parameters; show fit; parallel error 3; error 2.706 2,4,5\n";
    print $xcmFile "log none\n";
    print $xcmFile "writefits $paramsFitsFilename\n";
    print $xcmFile "exit\n";
    close $xcmFile;

    ### run xspec
    system "xspec - $xcmFilename";

    ### finish work
    # delete { } # symbols in output files
    edit_file { tr/{}//d } $plotDataFilename;
    edit_file { tr/#//d } $paramsFilename;
    system "clear";
    print "\n### Done ###\n";
    print "exported data point: $plotDataFilename \n";
    print "units: energy energyErr euf eufErr res resErr ratio ratioErr\n";
    print "exported fitted parameters: $paramsFilename \n";
    print "exported spectrum figure: $plotFigFilename \n\n";
}



## input: grb name, .pi filename, .rmf filename, .arf filename
## output: data points for plot, spectral figure, fitted parameters
sub _fitPL(){
    my $grb = shift;
    my $dataFilename = shift;
    my $respFilename = shift;
    my $arfFilename = shift;

    my ($file,$path,$ext) = fileparse($dataFilename, qr/\.[^.]*/);

    ## search websites to find trigger, redshift and nH
    print "Searching for trigger number ...\n";
    my $trigger = &_grbTrigger($grb);
    die "No Trigger Number Found" unless $trigger;
    print "Trigger Number: $trigger\n";
    print "Searching for Galaxy H density ...\n";
    my $nH = &_nH($trigger)/1e22;
    die "No Trigger Number Found" unless $nH;
    print "nH: $nH\n";

    ## names of output files
    my $plotDataFilename = "$path\/$grb.plot.pl.txt";
    my $plotFigFilename = "$path\/$grb.pl.eps";
    my $paramsFilename = "$path\/$grb.params.pl.txt";
    my $paramsFitsFilename = "$path\/$grb.params.pl.fits";

    unlink $plotDataFilename if (-e $plotDataFilename);
    unlink $plotFigFilename if (-e $plotFigFilename);
    unlink $paramsFilename if (-e $paramsFilename);
    unlink $paramsFitsFilename if (-e $paramsFitsFilename);

    ### generate XSPEC script
    my $xcmFilename = "$path\/$grb.xcm";
    unlink $xcmFilename if (-e $xcmFilename);

    open my $xcmFile, '>', "$xcmFilename";
    print $xcmFile "data $dataFilename\n";
    print $xcmFile "resp $respFilename\n";
    print $xcmFile "arf $arfFilename\n";
    print $xcmFile "ign bad\n";
    print $xcmFile "ign **-0.3 10.-**\n";
    print $xcmFile "setplot energy\n";
    print $xcmFile "method leven 100 0.5\n";
    print $xcmFile "abund wilm\n";
    print $xcmFile "xsect vern\n";
    print $xcmFile "cosmo 70 0 0.73\n";
    print $xcmFile "xset delta -1\n";
    print $xcmFile "systematic 0\n";
    print $xcmFile "statistic cstat\n";
    print $xcmFile "setplot rebin 6 1024\n";
    print $xcmFile "model phabs*po\n";
    print $xcmFile "$nH\n";
    print $xcmFile "1.6\n";
    print $xcmFile "1\n";
    print $xcmFile "freeze 1\n";
    print $xcmFile "fit 10000 1e-1\n";
    print $xcmFile "fit\n";
    print $xcmFile "tclout plot euf x\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot euf xerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot euf y\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot euf yerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot res y\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot res yerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot ratio y\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot ratio yerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "setplot device $plotFigFilename /cps\n";
    print $xcmFile "plot euf residuals\n";
    print $xcmFile "log $paramsFilename\n";
    print $xcmFile "show rate; show parameters; show fit; parallel error 3; error 2.706 2,4,5\n";
    print $xcmFile "log none\n";
    print $xcmFile "writefits $paramsFitsFilename\n";
    print $xcmFile "exit\n";
    close $xcmFile;

    ### run xspec
    system "xspec - $xcmFilename";

    ### finish work
    # delete { } # symbols in output files
    edit_file { tr/{}//d } $plotDataFilename;
    edit_file { tr/#//d } $paramsFilename;
    system "clear";
    print "\n### Done ###\n";
    print "exported data point: $plotDataFilename \n";
    print "units: energy energyErr euf eufErr res resErr ratio ratioErr\n";
    print "exported fitted parameters: $paramsFilename \n";
    print "exported spectrum figure: $plotFigFilename \n\n";
}

sub _fitPLBBWithRedshift(){
    my $grb = shift;
    my $dataFilename = shift;
    my $respFilename = shift;
    my $arfFilename = shift;

    #my $path = dirname $dataFilename;
    my ($file,$path,$ext) = fileparse($dataFilename, qr/\.[^.]*/);

    ## search websites to find trigger, redshift and nH
    print "Searching for redshift ...\n";
    my $redshift = &_redshift($grb);
    unless($redshift){
        print "Cannot find redshift automatically.\n";
        print "Please input redshift manually (eg. 1.8):\n";
        chomp($redshift = <STDIN>);
    }
    print "Redshift: $redshift\n";
    print "Searching for trigger number ...\n";
    my $trigger = &_grbTrigger($grb);
    unless($trigger){
        print "Cannot find trigger number automatically.\n";
        print "Please input trigger number manually (eg. 716127):\n";
        chomp($trigger = <STDIN>);
    }
    print "Trigger Number: $trigger\n";
    print "Searching for Galaxy H density ...\n";
    my $nH = &_nH($trigger);
    unless($nH){
        print "Cannot find Galaxy H density automatically.\n";
        print "Please input Galaxy H density manually (eg. 1.2e21):\n";
        chomp($nH = <STDIN>);
    }
    print "nH: $nH\n";
    my $nH = $nH/1e22;

    ## names of output files
    my $plotDataFilename = "$path\/$file.plot.plbb.txt";
    my $plotFigFilename = "$path\/$file.plbb.eps";
    my $paramsFilename = "$path\/$file.params.plbb.txt";
    my $paramsFitsFilename = "$path\/$file.params.plbb.fits";

    unlink $plotDataFilename if (-e $plotDataFilename);
    unlink $plotFigFilename if (-e $plotFigFilename);
    unlink $paramsFilename if (-e $paramsFilename);
    unlink $paramsFitsFilename if (-e $paramsFitsFilename);

    ### generate XSPEC script
    my $xcmFilename = "$path\/$file.xcm";
    unlink $xcmFilename if (-e $xcmFilename);

    open my $xcmFile, '>', "$xcmFilename";
    print $xcmFile "data $dataFilename\n";
    print $xcmFile "resp $respFilename\n";
    print $xcmFile "arf $arfFilename\n";
    print $xcmFile "ign bad\n";
    print $xcmFile "ign **-0.3 10.-**\n";
    print $xcmFile "setplot energy\n";
    print $xcmFile "method leven 100 0.5\n";
    print $xcmFile "abund wilm\n";
    print $xcmFile "xsect vern\n";
    print $xcmFile "cosmo 70 0 0.73\n";
    print $xcmFile "xset delta -1\n";
    print $xcmFile "systematic 0\n";
    print $xcmFile "statistic cstat\n";
    print $xcmFile "setplot rebin 6 1024\n";
    print $xcmFile "model phabs*zphabs*(po+bb)\n";
    print $xcmFile "$nH\n";
    print $xcmFile "0.1\n";
    print $xcmFile "$redshift\n";
    print $xcmFile "1.6\n";
    print $xcmFile "1\n";
    print $xcmFile "0.8\n";
    print $xcmFile "1\n";
    print $xcmFile "freeze 1\n";
    print $xcmFile "fit 10000 1e-1\n";
    print $xcmFile "fit\n";
    print $xcmFile "tclout plot euf x\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot euf xerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot euf y\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot euf yerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot res y\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot res yerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot ratio y\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "tclout plot ratio yerr\n";
    print $xcmFile "syscall echo \$xspec_tclout >> $plotDataFilename\n";
    print $xcmFile "setplot device $plotFigFilename /cps\n";
    print $xcmFile "plot euf residuals\n";
    print $xcmFile "log $paramsFilename\n";
    print $xcmFile "show rate; show parameters; show fit; parallel error 5; error 2.706 2,4,5,6,7\n";
    print $xcmFile "log none\n";
    print $xcmFile "writefits $paramsFitsFilename\n";
    print $xcmFile "exit\n";
    close $xcmFile;

    ### run xspec
    system "xspec - $xcmFilename";

    ### finish work
    # delete { } # symbols in output files
    edit_file { tr/{}//d } $plotDataFilename;
    edit_file { tr/#//d } $paramsFilename;
    system "clear";
    print "\n### Done ###\n";
    print "exported data point: $plotDataFilename \n";
    print "units: energy energyErr euf eufErr res resErr ratio ratioErr\n";
    print "exported fitted parameters: $paramsFilename \n";
    print "exported spectrum figure: $plotFigFilename \n\n";
}

1;
