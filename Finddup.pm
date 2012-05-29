package Finddup;
use strict;
use warnings;
use File::Basename;
use Exporter 'import';
our @EXPORT_OK = qw(frame_find_cmd content_duplicate filename_duplicate dirname_duplicate);
our $VERSION = 1.02;
my $Debug = 0; # change it to 1, to enable debug.

#Finding files which has content duplication
sub content_duplicate
{
    my ($find_cmd, $s) = @_;
	my ($output_fh, $size, $filename, $md5sum, %file_details, %dup_details, $cur_key_tmp);
	# execute the framed find command, identify sizes and file names.
	open ($output_fh, '-|', $find_cmd) || die "Failed: $!\n";
	while (<$output_fh>)  {
		# $1: size of file # $2: name of file.
		$_ =~  m/^(\d+)\s(.*)$/s;
		$size = $1; $filename = $2;
		chomp($filename);
	
		# store the size of file as key, and filenames as the values.
		push ( @{$file_details{$size}}, $filename);
	}
    close ($output_fh);
	
	foreach ( keys %file_details )  {
        $cur_key_tmp = $_;	

		# no use of calculating md5sum if more than one file not having same size
        next unless ( $#{$file_details{$cur_key_tmp}} );

	    # Efficient: Find md5sum for all files which has same size.
		for ( 0 .. $#{$file_details{$cur_key_tmp}} )  {
			$md5sum = (split /\s+/, `md5sum "$file_details{$cur_key_tmp}->[$_]"`)[0];	 
            next unless defined $md5sum;  # skip if unable to find md5sum for any reason. 
			$filename = $file_details{$cur_key_tmp}->[$_];
	
			# store the md5sum as the hash key, and value is anonymous array
				# 0 : size of the file # 1 .. N : names of the files.
			push ( @{$dup_details{$md5sum}}, $cur_key_tmp) unless ( exists $dup_details{$md5sum} );
			push ( @{$dup_details{$md5sum}}, $filename);
		}
    }	
    undef %file_details;
	
	
	# statistics: find the number of duplicates, blocks occupied by duplicates.
	if ( $s )  {
		my ( $num_of_duplicates, $blk_of_duplicates );
		
		foreach ( keys %dup_details )  {
			unless ( $#{$dup_details{$_}} == 1 )  { 
			    # count the number of duplicates, and the block occupied by it.
				$num_of_duplicates++;
				$blk_of_duplicates += ($#{$dup_details{$_}}-1) * $dup_details{$_}->[0];
			}
		}
		
		# print the duplication details.
		unless ( $num_of_duplicates )  {
			print "No duplicates..\n";
            return 1;
		}
		print "Number of Duplications available: $num_of_duplicates\n";
		print "Total number of Blocks occupied by duplicates: $blk_of_duplicates\n\n";
	}
	
	#  print the file names along with size which has the same md5sum, those are all duplicate content files.
	foreach ( sort { $dup_details{$b}->[0] <=> $dup_details{$a}->[0] } keys %dup_details )  {
		if ( $#{$dup_details{$_}} > 1 )  {
			print "Blocks occupied by each file: " , (shift @{$dup_details{$_}}) , "\n";
			print join "\n", @{$dup_details{$_}}, '', '';
		}
    }	
    
    return 1;
}

#Finding files which has filename duplication, and ignore extensions optionally.
sub filename_duplicate
{
    my ($find_cmd, $extn, $s) = @_;
	my ($output_fh, $size, $filename, @extns, %filename_hash, $filebasename, $dirname, $c_extn, $tmp);
	
	if ( defined $extn )  {
		die "Give extensions to be ignored sepearted by comma like this -e='bkup,org,bk'\n" if ( $extn == 1 );
		@extns = split ",", $extn;
		print join "\nExtensions: ", @extns if $Debug;
	}

	open ($output_fh, '-|', $find_cmd) || die "Failed: $!\n";
	while (<$output_fh>)  {
		$_ =~  /^(\d+)\s(.*)$/;
		$size = $1; $filename = $2;
		($filebasename, $dirname, $c_extn) = fileparse $filename,@extns;
		
		# Use the name of the file as hash key.
		push ( @{$filename_hash{$filebasename}}, ($size, $filename) );
	}
    close ($output_fh);

	# calculate and print the statistics only if -s option is given.
	if ( $s )  {
		my ( $num_of_duplicates, $blk_of_duplicates );
		foreach ( keys %filename_hash )  {
			if ( $#{$filename_hash{$_}} > 1 )  {
				$num_of_duplicates++;
				$tmp = (($#{$filename_hash{$_}}+1)/2);
				$blk_of_duplicates += ($tmp>1 ? $tmp-1 : 1) * $filename_hash{$_}->[0];
			}
		}

		unless ( $num_of_duplicates )  {
			print "No duplicates..\n";
		}
		print "Number of Duplications available: $num_of_duplicates\n";
		print "Total number of Blocks occupied by duplicates (approx): $blk_of_duplicates\n\n";
	}

	# print all the filenames which are duplicate
	foreach ( keys %filename_hash )  {
		if ( $#{$filename_hash{$_}} > 1 )  {
			my $i;
			print "\nFilename: $_\nLocations:\n\t";
			print join "\n\t", grep { $i++ % 2 } @{$filename_hash{$_}};
            print "\n\n";
		}
	}
    return 1;
}

#Finding directories which has duplication in name
sub dirname_duplicate 
{
    my ($find_cmd) = @_; 
	my ($output_fh, $dirname, $dirpath, %dir_hash, $duplicates_available);

	# find out the directory names, and push it into hash.
    open ($output_fh, '-|', $find_cmd) || die "Failed: $!\n";
    while (<$output_fh>)  {
		chomp($_);
		($dirname, $dirpath, undef) = fileparse $_;

		# Use the name of the directory as hash key.
		push ( @{$dir_hash{$dirname}}, $dirpath );
	}
    close ($output_fh);

	foreach ( keys %dir_hash )  {
		# print all the directories which occurs more than once.
		if ( $#{$dir_hash{$_}} > 0 )  {
			print "\nDirname: $_\nPath:\n  ";
			print join "\n  ", @{$dir_hash{$_}};
			print "\n";
			$duplicates_available = 1;
		}
	}

	print "No duplicates..\n" unless $duplicates_available;
    return 1;
}


# Frame the find command 
sub frame_find_cmd
{
    my ( $path, $d, $a ) = @_;
	my $find_cmd = "find $path -not -empty"; # By default, exclude the empty files. 

	# If -a option is not given then exclude hidden files.
	$find_cmd .= ' \( ! -regex ".*/\..*" \)' unless ( defined $a ); 
	
	if ( $d )  {
		$find_cmd .= ' -type d'; # only directories with -d option
	} else {
		#  "-type f" to process only files,"ls -s" to get the size of the files.
		$find_cmd .= ' -type f -exec ls -s {} \;';
	}
	print "Find command to be used: $find_cmd\n" if $Debug;
    return $find_cmd;
}


1;
