#!/usr/bin/perl

use strict;

die "Usage: make-mutants.pl <path to assembly> [<function name>] [<debug>] or make-mutants.pl <path to assembly> [<debug>]"
  unless @ARGV >= 1;
my ($binary,$fn_name,$debug);
my $length = @ARGV;
$fn_name = "";

my $output;
if($length == 2) {
    ($binary, $debug) = @ARGV;
} elsif($length == 3) {
    ($binary, $fn_name, $debug) = @ARGV; 
}
my @past_mutations = ();
my $binary_mutants = "./mutants";
#`mkdir $binary_mutants`;
#`mkdir mutants`;
print "debug = $debug\n";
my $mutant_num = 0;
while(1) {
    open(F, $binary) or die;
    my $curr_fn_name = "";
    my $actual_fn_name = "";
    my ($mutant_1_assembly, $mutant_2_assembly) = ("", "");
    my ($mutant_1_name, $mutant_2_name) = ("", "");
    my $line_num = 0;
    my $mutated = 0;
    while (<F>) {
	$line_num += 1;
	# if($debug == 1) { print $_; }
	if($_ =~ /^.globl/){
		#if($debug == 1) { print $_; }
		$actual_fn_name = $_;
		chomp($actual_fn_name);
		$actual_fn_name = (split ' ', $_)[-1];
		if($debug == 1) {print "$actual_fn_name\n"; }
	}
	if(/^[_a-zA-Z0-9\.]+:/ && !/^\./) {
	    $curr_fn_name = $_;
	    chomp($curr_fn_name);
	    $curr_fn_name = substr($curr_fn_name, 0, index($curr_fn_name, ':'));
	    if ($debug == 1) { print "curr_fn_name = $curr_fn_name\n"; }
	}
	my ($new_insn_0, $new_insn_1) = ($_, $_);
	#if($fn_name eq "" || ($curr_fn_name =~ /$fn_name/)) {
	if($fn_name eq "" || ($actual_fn_name eq $fn_name)) {
	    if ($debug == 1){
	    print "NNNN $line_num\n$_\n";
	    print is_flag_use($_);
	    print "\n";}
	    my $curr_insn = $_;
	    chomp($curr_insn);
	    if($mutated == 0 && is_flag_use($_) && is_past_mutation(("$line_num: " . $curr_insn)) == 0) {
		if($debug == 1){ print "VVVV $line_num\n";}
		$new_insn_0 = mutate($_, 0);
		$new_insn_1 = mutate($_, 1);
		if($debug == 1) { print "new_insn_0 = $new_insn_0, new_insn_1 = $new_insn_1\n"; }
		push @past_mutations, ("$line_num: " . $curr_insn);
		$mutant_1_name = $curr_fn_name. "#" . $mutant_num. ".0.s";
		$mutant_2_name = $curr_fn_name. "#" . $mutant_num . ".1.s";
		$mutated = 1;
		$mutant_num++;
	    }
	}
	$mutant_1_assembly .= $new_insn_0;
	$mutant_2_assembly .= $new_insn_1;
    }
    close F;
    if ($mutated == 1) {
	open(M1, ">$binary_mutants/$mutant_1_name"); 
	#open(M1, ">mutants/$mutant_1_name"); 
	print M1 $mutant_1_assembly;
	close(M1);
	open(M2, ">$binary_mutants/$mutant_2_name"); 
	#open(M2, ">mutants/$mutant_2_name"); 
	print M2 $mutant_2_assembly;
	close(M2);
	print "Wrote to mutants/$mutant_1_name && mutants/$mutant_2_name\n";
    } else { last; }
}

sub is_past_mutation {
    my ($curr_insn) = (@_);
    foreach my $past_mut_str (@past_mutations) {
	if($debug == 1) {
	    print "past_mut_str = $past_mut_str, curr_insn = $curr_insn, " .
		($past_mut_str eq $curr_insn) . "\n";
	}
	if ($past_mut_str eq $curr_insn) {
	    return 1;
	}
    } 
    return 0;
}

sub is_flag_use {
    my ($insn) = (@_);
    #if($insn =~ /\scmov/ || $insn =~ /\sset.*/ || ($insn =~ /\sj.*/ && !($insn =~ /\sjmp.*/))) {
    if($insn =~ /cmov/ || $insn =~ /set.*/ || ($insn =~ /j.*/ && !($insn =~ /jmp.*/)) || $insn =~ /adc/ || $insn =~ /sbb/) {
	return 1;
    }
    return 0;
}

sub mutate {
    my($insn, $mutate_direction) = (@_);
    if($insn =~ /cmov/) {
	if($mutate_direction == 0) {
	    $insn =~ s/cmov. /mov /g;
	    $insn =~ s/cmov.. /mov /g;
	} elsif ($mutate_direction == 1) {
	    $insn = "  nop\n";
	}
    }
    if($insn =~ /set/) {
	$insn =~ s/set../movb \$$mutate_direction, /g;
    }
    if ($insn =~ /j.*/ && !($insn =~ /jmp.*/)) {
	if($mutate_direction == 0) {
	    $insn =~ s/j.. /jmp /g;
	    $insn =~ s/j. /jmp /g;
	} elsif ($mutate_direction == 1) {
	    $insn = "  nop\n";
	}
    }
    if($insn =~ /adc.*/ ){
	if ($mutate_direction == 0){
		$insn =~ s/adc/add/g;
		$insn .= "incl " . (split(',', $insn))[-1];
	}elsif ($mutate_direction == 1) {
		$insn =~ s/adc/add/g;		
	}
     }
     if($insn =~ /sbb/){
	if($mutate_direction == 0){
		$insn =~ s/sbb /sub /g;
		$insn .= "decl " . (split(',',$insn))[-1];
	}elsif ($mutate_direction == 1){
		$insn =~ s/sbb /sub /g;
        }
     }		
    return $insn;
}
